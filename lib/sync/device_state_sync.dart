// 기기 기록 동기화 — 베이 부품 · 베이 연결 · 조합 · 덱 · 도감 손으로 켜기 · 태그 · 특별 관심 · 채널 · 휴지통 …
// 다른 기기 · 다시 설치해도 그대로 (docs/supabase-v3-sync.sql).
//
// 서버 = 계정마다 한 줄 gunpula_v3_device_state (data jsonb + revision). 옛 앱과 같이 쓰는 v2/v3 payload 에는 넣지 않는다
// (옛 앱이 모르는 키를 지울 수 있어서). data 모양: {schema: 1, sections: {local_state 키: {항목: {t, v?, d?}}}}
// 어느 키를 맞추나 · 합치는 규칙은 device_state.dart (항목마다 늦은 쪽, 지운 것은 지움 표시).
//
// 한 번 돌 때 (syncNow):
//   1) get_device_state → 2) 기기 기록을 장부에 적기(바뀐 항목 = 지금 시각) → 3) 항목마다 합침 → 기기에 반영
//   4) 서버와 달라졌으면 save_device_state(p_base_revision) — 40001(다른 기기가 먼저 씀)이면 다시 받아 합치고 재시도 (최대 3번)
// 언제: 로그인 직후 · 앱으로 돌아올 때 · 기록을 바꾸고 [debounce] 뒤(바뀐 게 있을 때만 서버를 부른다).
// 오프라인 · 실패면 장부의 dirty 를 남겨 두고 다음에 다시. 서버에 함수가 없으면(옛 SQL) 아무것도 안 한다.
// 계정: 장부의 주인 = 처음 맞춘 계정. 다른 계정으로 로그인하면 앞 계정 장부를 새 계정에 섞지 않고,
//   맞추는 키들을 새 계정 것으로 바꾼다 (서버 함수가 없으면 기기 것을 그대로 둔다 — 그때는 지킬 원본이 기기뿐).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/user_store.dart';
import '../json_util.dart';
import '../l10n/l10n.dart';
import 'device_state.dart';
import 'rpc.dart';

enum DeviceSyncPhase { off, syncing, synced, offline, missing, error }

class DeviceStateSync extends ChangeNotifier {
  DeviceStateSync({
    required this.auth,
    required RpcClient Function() rpc,
    required this.store,
    this.debounce = const Duration(milliseconds: 1500),
    this.retryEvery = const Duration(minutes: 1),
    DateTime Function()? clock,
    Future<void> Function()? before,
    bool Function()? accountSwitched,
  }) : _rpc = rpc,
       _clock = clock ?? DateTime.now,
       _before = before,
       _accountSwitched = accountSwitched;

  final AuthService auth;
  final RpcClient Function() _rpc;
  final UserStore store;
  final Duration debounce;

  /// 오프라인이면 이만큼 뒤에 한 번 더
  final Duration retryEvery;
  final DateTime Function() _clock;

  /// 돌기 전에 기다릴 것 (구매함 · 좋아요 동기화가 계정 주인을 먼저 정하게)
  final Future<void> Function()? _before;

  /// 이번 로그인에서 구매함 · 좋아요 동기화가 다른 계정이라 기기 기록을 비웠나
  final bool Function()? _accountSwitched;

  DeviceSyncPhase phase = DeviceSyncPhase.off;
  String message = '';

  /// 40001 로 부딪힌 횟수 (진단용)
  int conflicts = 0;

  bool _started = false;
  bool _wasSignedIn = false;
  bool _running = false;
  bool _again = false;
  Timer? _debounceTimer;
  Timer? _retryTimer;
  Future<void>? _current;

  static const _get = 'gunpula_v3_get_device_state';
  static const _save = 'gunpula_v3_save_device_state';

  /// 지금 도는 것이 끝날 때
  Future<void> get idle => _current ?? Future.value();

  bool get dirty => store.deviceSync['dirty'] == true;

  void start() {
    if (_started) return;
    _started = true;
    store.addListener(_onStore);
    auth.addListener(_onAuth);
    _onAuth();
  }

  void _onAuth() {
    final now = auth.signedIn;
    if (now && !_wasSignedIn) {
      _wasSignedIn = true;
      if (phase == DeviceSyncPhase.missing) phase = DeviceSyncPhase.off; // 새 로그인 = 서버를 다시 물어본다
      syncNow(reason: 'sign-in').ignore();
    } else if (!now && _wasSignedIn) {
      _wasSignedIn = false;
      _debounceTimer?.cancel();
      _retryTimer?.cancel();
      _set(DeviceSyncPhase.off, '');
    }
  }

  /// 앱으로 돌아왔다 (SyncService 가 알려 준다)
  void onResume() {
    if (auth.signedIn) syncNow(reason: 'resume').ignore();
  }

  void _onStore() {
    // 장부가 있거나 로그인했을 때만 적는다 (로그인을 안 하는 사람의 저장 파일을 키우지 않게)
    // 서버에 함수가 없으면 적지도 않는다 (다음 로그인 때 다시 물어본다)
    if ((!auth.signedIn && store.deviceSync.isEmpty) || phase == DeviceSyncPhase.missing) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () {
      if (_running) {
        _again = true; // 도는 중에 바꾼 것은 끝난 뒤 한 번 더 돌며 적는다
        return;
      }
      final changed = _stampLocal();
      if (changed && auth.signedIn) syncNow(reason: 'edit').ignore();
    });
  }

  void _set(DeviceSyncPhase p, String m) {
    if (phase == p && message == m) return;
    phase = p;
    message = m;
    notifyListeners();
  }

  int get _now => _clock().millisecondsSinceEpoch;

  Ledger get _ledger => ledgerFrom(store.deviceSync['sections']);

  /// 기기 기록을 장부에 적는다 — 바뀐 게 있으면 true (dirty 로 남김)
  bool _stampLocal() {
    final local = store.localStateJson();
    final ledger = _ledger;
    final now = _now;
    var changed = false;
    for (final s in deviceSections) {
      final before = ledger[s.key];
      final after = stampSection(s, before, local[s.key], now);
      if (!identical(after, before)) {
        ledger[s.key] = after;
        changed = true;
      }
    }
    if (changed) _writeLedger(ledger, dirty: true);
    return changed;
  }

  void _writeLedger(Ledger sections, {required bool dirty, int? revision, String? account}) {
    store.setDeviceSync({
      ...store.deviceSync,
      'account': ?account,
      'revision': ?revision,
      'dirty': dirty,
      'sections': sections,
    });
  }

  /// 지금 한 번 (도는 중이면 끝난 뒤 한 번 더)
  Future<void> syncNow({String reason = 'manual'}) {
    if (!auth.signedIn) return Future.value();
    if (_running) {
      _again = true;
      return _current ?? Future.value();
    }
    return _current = _run(reason);
  }

  Future<void> _run(String reason) async {
    _running = true;
    _retryTimer?.cancel();
    _set(DeviceSyncPhase.syncing, '');
    try {
      await store.load();
      await _before?.call();
      do {
        _again = false;
        await _cycle();
      } while (_again && auth.signedIn);
      _set(DeviceSyncPhase.synced, '');
    } on _Missing {
      _set(DeviceSyncPhase.missing, '');
    } on OfflineException catch (e) {
      _set(DeviceSyncPhase.offline, e.message);
      _retryTimer = Timer(retryEvery, () => syncNow(reason: 'retry').ignore());
    } on RpcException catch (e) {
      _set(DeviceSyncPhase.error, e.code == '54000' ? tr('기기 기록이 너무 커서 올리지 못했어요') : e.toString());
    } on Object catch (e) {
      _set(DeviceSyncPhase.error, '$e');
    } finally {
      _running = false;
      _current = null;
    }
  }

  Future<({Map<String, Object?> data, int revision})> _fetch(RpcClient rpc) async {
    try {
      final m = jMap(await rpc(_get));
      return (data: {...jMap(m['data'])}, revision: jInt(m['revision']));
    } on RpcException catch (e) {
      if (e.isMissingFunction) throw const _Missing();
      rethrow;
    }
  }

  Future<void> _cycle() async {
    final uid = auth.userId;
    if (uid.isEmpty) return;
    final rpc = _rpc();
    var remote = await _fetch(rpc);
    if (auth.userId != uid) return; // 기다리는 사이 로그아웃 · 계정 바뀜
    final owner = jStr(store.deviceSync['account']);
    // 다른 계정의 장부 → 앞 계정 것을 새 계정에 섞지 않는다 (맞추는 키를 서버 것으로 바꾼다)
    var switching = owner.isNotEmpty ? owner != uid : (_accountSwitched?.call() ?? false);
    for (var attempt = 0; ; attempt++) {
      final now = _now;
      final remoteSections = ledgerFrom(remote.data['sections']);
      final Ledger local;
      if (switching) {
        // 서버에 없는 키는 빈 장부 → 기기 것도 비운다 (통째로 하나인 값 = 채널 · 취향 태그는 그대로)
        local = {for (final s in deviceSections) s.key: remoteSections[s.key] ?? {}};
      } else {
        _stampLocal(); // 기다리는 사이 바꾼 것도 (지금 시각으로)
        local = _ledger;
      }
      var merged = mergeLedger(local, remoteSections, now);
      // 기기에 반영
      final cur = store.localStateJson();
      final apply = <String, Object?>{};
      for (final s in deviceSections) {
        final sec = merged[s.key];
        if (sec == null) continue;
        final next = rebuildSection(s, sec, cur[s.key]);
        if (next != null) apply[s.key] = next;
      }
      store.applyLocalState(apply);
      // 읽으면서 정리된 것(덱 3칸 · 오래된 휴지통 …)도 장부에 — 그래야 다음에 또 올리지 않는다
      final after = store.localStateJson();
      merged = {
        for (final s in deviceSections)
          if (merged[s.key] != null || after[s.key] != null) s.key: stampSection(s, merged[s.key], after[s.key], now),
      };
      switching = false;
      final out = {
        ...remote.data,
        'schema': 1,
        'sections': {...jMap(remote.data['sections']), ...merged},
      };
      if (sameJson(out, remote.data)) {
        _writeLedger(merged, dirty: false, revision: remote.revision, account: uid);
        return;
      }
      _writeLedger(merged, dirty: true, revision: remote.revision, account: uid);
      try {
        final r = jMap(await rpc(_save, {'p_data': out, 'p_base_revision': remote.revision}));
        // 저장하는 사이 바꾼 것은 다음 적기에서 다시 잡힌다 (장부는 저장한 그대로)
        _writeLedger(ledgerFrom(store.deviceSync['sections']), dirty: false, revision: jInt(r['revision']));
        return;
      } on RpcException catch (e) {
        if (e.isMissingFunction) throw const _Missing();
        if (!e.isRevisionConflict || attempt >= 3) rethrow;
        conflicts++;
        remote = await _fetch(rpc);
      }
    }
  }

  /// 설정 화면 한 줄 (없으면 '')
  String get statusLine => switch (phase) {
    DeviceSyncPhase.syncing => tr('기기 기록 맞추는 중…'),
    DeviceSyncPhase.synced => '',
    DeviceSyncPhase.offline => tr('오프라인 — 베이 · 도감 기록은 연결되면 맞춰요'),
    DeviceSyncPhase.missing => tr('서버에 기기 기록 함수가 없어 베이 · 도감 기록은 이 기기에만 있어요'),
    DeviceSyncPhase.error => trf('기기 기록을 맞추지 못했어요: {message}', {'message': message}),
    DeviceSyncPhase.off => '',
  };

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _retryTimer?.cancel();
    if (_started) {
      store.removeListener(_onStore);
      auth.removeListener(_onAuth);
    }
    super.dispose();
  }
}

/// 서버에 기기 기록 함수가 없음 (docs/supabase-v3-sync.sql 을 안 돌림)
class _Missing implements Exception {
  const _Missing();
}
