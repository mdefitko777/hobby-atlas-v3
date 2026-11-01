// 내 컬렉션 동기화 — 옛 Gunpula 앱과 같은 Supabase 데이터를 같이 쓴다 (설계 §1.5 약속).
//
// 한 번 돌 때 (syncNow):
//   1) v2 get_state (옛 앱이 쓰는 공유 공간 = 진짜 원본) + v3 get_me (친구 · 요청 · v3 리비전)
//   2) 내 버킷만 상품별로 합친다 (updated_at 늦은 쪽, 지움 = deleted 기록). 다른 멤버 버킷 · overrides ·
//      series_label_overrides · appearance · custom_items · 모르는 키는 서버 것 그대로.
//   3) 서버와 달라졌으면 v2 save_state → 같은 payload 를 v3 save_state(base revision) 에 복사.
//      v3 가 40001(리비전 충돌)이면 get_me → 다시 합침 → 재시도 (최대 3번).
//   · v2 공유 공간이 없는 계정(동생 · 친구)은 v3 내 행이 원본이다.
// 언제: 로그인 직후 · 앱으로 돌아올 때 · 앞에 있는 동안 15초마다 · 기록을 바꾸고 0.7초 뒤.
// 오프라인이면 바꾼 것은 기기에 남고(cloudDirty), 다음 번에 다시 올린다.
// 기기의 기록은 처음 로그인한 계정 것이다(UserStore.syncedAccount). 로그아웃 뒤 다른 계정으로 로그인하면
// 앞 계정 기록을 새 계정에 합치지 않고 비운 뒤 새 계정 것을 받는다 (형 폰에서 동생이 로그인해도 섞이지 않게).
// Hobby Atlas 에만 있는 값(베이 부품 · 도감 손으로 켜기)은 아직 기기에만 둔다.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/user_store.dart';
import 'collection_merge.dart';
import 'friends_service.dart';
import 'rpc.dart';

enum SyncPhase { off, syncing, synced, offline, error }

class WorkspaceMember {
  const WorkspaceMember({required this.name, required this.role, required this.isSelf});
  final String name;
  final String role;
  final bool isSelf;
}

/// v2 공유 공간 (옛 앱 「계정 · 동기화」)
class Workspace {
  const Workspace({
    required this.name,
    required this.revision,
    required this.canEdit,
    required this.members,
    required this.payload,
    required this.updatedBy,
  });

  final String name;
  final int revision;
  final bool canEdit;
  final List<WorkspaceMember> members;
  final Map<String, Object?> payload;
  final String updatedBy;

  /// 서버가 아는 내 이름 (members[is_self].name)
  String get selfName => members.where((m) => m.isSelf).firstOrNull?.name ?? '';

  static Workspace? parse(Object? raw) {
    final r = raw is List ? (raw.isEmpty ? null : raw.first) : raw;
    if (r is! Map) return null;
    final m = {for (final e in r.entries) '${e.key}': e.value};
    final rev = m['revision'];
    return Workspace(
      name: '${m['workspace_name'] ?? ''}',
      revision: rev is num ? rev.toInt() : int.tryParse('$rev') ?? 0,
      canEdit: m['can_edit'] != false,
      members: [
        for (final x in (m['members'] is List ? m['members']! as List : const []))
          if (x is Map)
            WorkspaceMember(name: '${x['name'] ?? ''}', role: '${x['role'] ?? ''}', isSelf: x['is_self'] == true),
      ],
      payload: m['payload'] is Map ? {for (final e in (m['payload']! as Map).entries) '${e.key}': e.value} : {},
      updatedBy: '${m['updated_by'] ?? ''}',
    );
  }
}

class SyncService extends ChangeNotifier with WidgetsBindingObserver {
  SyncService({
    required this.auth,
    required RpcClient Function() rpc,
    required this.store,
    required this.friends,
    this.debounce = const Duration(milliseconds: 700),
    this.pollEvery = const Duration(seconds: 15),
    this.mergeOnlyEvery = const Duration(minutes: 5),
    DateTime Function()? clock,
  }) : _rpc = rpc,
       _clock = clock ?? DateTime.now;

  final AuthService auth;
  final RpcClient Function() _rpc;
  final UserStore store;
  final FriendsService friends;

  /// 기록을 바꾼 뒤 이만큼 조용하면 올린다 (옛 앱 SYNC_SAVE_DEBOUNCE_MS)
  final Duration debounce;

  /// 앞에 있는 동안 이 간격으로 받는다 (옛 앱 SYNC_POLL_INTERVAL_MS)
  final Duration pollEvery;

  /// 내가 바꾼 것 없이 "정리만" 달라서 올리는 저장의 최소 간격 — 두 앱의 내 이름이 달라
  /// 'member' 버킷을 서로 접었다 폈다 하더라도 15초마다 덮어쓰는 싸움이 되지 않게
  final Duration mergeOnlyEvery;
  final DateTime Function() _clock;

  SyncPhase phase = SyncPhase.off;
  String message = '';
  DateTime? lastSyncedAt;

  /// v2 공유 공간 (없는 계정이면 null → v3 내 행에만 저장)
  Workspace? workspace;

  /// 마지막으로 쓴 내 버킷 이름
  String selfName = '';

  /// v3 save_state 가 40001 로 부딪힌 횟수 (진단용)
  int v3Conflicts = 0;

  /// 이번 로그인에서 앞 계정의 기기 기록을 비우고 이 계정 것으로 바꿨음 (설정 화면 안내용)
  bool accountSwitched = false;

  bool _started = false;
  bool _wasSignedIn = false;
  bool _running = false;
  bool _again = false;
  bool _foreground = true;
  int _polls = 0;
  int _seenShared = 0;
  DateTime? _lastMergeOnlySave;
  Timer? _debounceTimer;
  Timer? _pollTimer;
  Future<void>? _current;

  bool get running => _running;

  /// 지금 도는 동기화가 끝날 때 (없으면 바로)
  Future<void> get idle => _current ?? Future.value();

  /// 로그인 상태 · 내 기록 변경을 듣기 시작 (앱에서 한 번)
  void start() {
    if (_started) return;
    _started = true;
    _seenShared = store.sharedRevision;
    store.addListener(_onStore);
    auth.addListener(_onAuth);
    _onAuth();
  }

  /// 앱 앞/뒤 전환을 듣는다 (main.dart 에서만 — 테스트는 직접 부른다)
  void attachLifecycle() => WidgetsBinding.instance.addObserver(this);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _foreground = true;
        if (auth.signedIn) {
          syncNow(reason: 'resume');
          _startPoll();
        }
      case AppLifecycleState.paused || AppLifecycleState.hidden || AppLifecycleState.detached:
        _foreground = false;
        _stopPoll();
        // 바꾼 게 남아 있으면 뒤로 가기 전에 한 번 더
        if (auth.signedIn && (store.cloudDirty || _debounceTimer?.isActive == true)) {
          _debounceTimer?.cancel();
          syncNow(reason: 'pause');
        }
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _onAuth() {
    final now = auth.signedIn;
    if (now && !_wasSignedIn) {
      _wasSignedIn = true;
      syncNow(reason: 'sign-in');
      _startPoll();
    } else if (!now && _wasSignedIn) {
      _wasSignedIn = false;
      _stopPoll();
      _debounceTimer?.cancel();
      workspace = null;
      selfName = '';
      accountSwitched = false;
      friends.clear();
      _set(SyncPhase.off, '');
    } else if (!now && phase != SyncPhase.off) {
      _set(SyncPhase.off, '');
    }
  }

  void _onStore() {
    if (store.sharedRevision == _seenShared) return;
    _seenShared = store.sharedRevision;
    if (!auth.signedIn) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () => syncNow(reason: 'edit'));
  }

  void _startPoll() {
    _pollTimer?.cancel();
    if (!_foreground) return;
    _pollTimer = Timer.periodic(pollEvery, (_) {
      if (auth.signedIn && !_running) syncNow(reason: 'poll');
    });
  }

  void _stopPoll() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _set(SyncPhase p, String msg) {
    phase = p;
    message = msg;
    notifyListeners();
  }

  /// 지금 한 번 (이미 도는 중이면 끝난 뒤 한 번 더)
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
    if (phase != SyncPhase.synced) _set(SyncPhase.syncing, '');
    try {
      await store.load();
      // 15초 받기는 v2 만 (payload 에 집 사진 data URL 이 있어 무겁다). v3 get_me(친구 요청 · 복사본 확인)는
      // 로그인 · 돌아옴 · 직접 · 저장할 때, 그리고 받기 4번에 1번(약 1분).
      var full = reason != 'poll' || (++_polls % 4 == 0);
      do {
        _again = false;
        // 기다리는 사이 다른 계정으로 바뀌었을 수 있다 → 돌 때마다 주인 확인, 도는 중 바뀌면 한 번 더
        _bindAccount();
        final who = auth.userId;
        await _cycle(full: full);
        if (auth.userId != who) _again = true;
        full = true;
      } while (_again && auth.signedIn);
      lastSyncedAt = _clock();
      _set(SyncPhase.synced, '');
    } on OfflineException catch (e) {
      _set(SyncPhase.offline, e.message);
    } on RpcException catch (e) {
      _set(SyncPhase.error, e.isAuth ? '로그인이 풀렸어요. 다시 로그인해 주세요' : e.toString());
    } on Object catch (e) {
      _set(SyncPhase.error, '$e');
    } finally {
      _running = false;
      _current = null;
    }
  }

  /// 기기 기록의 주인 계정 확인 — 처음이면 지금 계정으로 정하고, 다른 계정이면 앞 계정 기록을 비운다
  void _bindAccount() {
    final id = auth.userId;
    if (id.isEmpty || store.syncedAccount == id) return;
    if (store.syncedAccount.isEmpty) {
      store.bindAccount(id); // 처음 로그인: 로그인 전에 모은 기록도 이 계정에 올린다
      return;
    }
    _debounceTimer?.cancel();
    store.resetForAccount(id);
    _seenShared = store.sharedRevision;
    accountSwitched = true;
  }

  /// v3 get_me — 함수가 없는 프로젝트면 null (친구 기능 없이 계속)
  Future<MeState?> _getMe(RpcClient rpc) async {
    try {
      final raw = await rpc('gunpula_v3_get_me');
      friends.applyMe(raw);
      return MeState.parse(raw);
    } on RpcException catch (e) {
      if (!e.isMissingFunction) rethrow;
      friends.unavailable = true;
      return null;
    }
  }

  Future<void> _cycle({required bool full}) async {
    final rpc = _rpc();
    Workspace? ws;
    try {
      ws = Workspace.parse(await rpc('gunpula_v2_get_state'));
    } on RpcException catch (e) {
      if (!e.isMissingFunction) rethrow;
      ws = null; // v2 SQL 이 없는 프로젝트 → v3 만
    }
    workspace = ws;

    if (ws != null) {
      // ── v2 공유 공간이 원본 ──
      final self = resolveSelfBucket(
        ws.payload,
        ws.selfName,
        notMine: {
          for (final m in ws.members)
            if (!m.isSelf) m.name,
        },
      );
      final startRev = store.sharedRevision;
      final merged = _merge(ws.payload, self);
      final needSave = ws.canEdit && _shouldSave(merged, ws.payload);
      if (needSave) {
        final saved = Workspace.parse(
          await rpc('gunpula_v2_save_state', {
            'p_payload': merged,
            'p_base_revision': ws.revision,
            'p_reason': 'hobby-atlas',
          }),
        );
        workspace = saved ?? ws;
        store.markSynced(startRev);
      } else if (samePayload(merged, ws.payload)) {
        store.markSynced(startRev);
      }
      // v3 = 친구가 읽는 복사본. v2 와 다르면 맞춰 둔다 (실패해도 v2 저장은 이미 끝남).
      if (!(needSave || full)) return;
      final me = await _getMe(rpc);
      final current = needSave ? merged : ws.payload;
      if (me != null && ws.canEdit && !samePayload(current, me.payload)) {
        try {
          await _saveV3(current, me, self);
        } on RpcException catch (e) {
          if (!e.isRevisionConflict) rethrow;
        }
      }
      return;
    }
    final me = await _getMe(rpc);
    if (me != null) {
      // ── 공유 공간이 없는 계정: v3 내 행이 원본 ──
      final preferred = store.member != 'member'
          ? store.member
          : (me.displayName.isNotEmpty ? me.displayName : (me.handle.isNotEmpty ? me.handle : _emailName()));
      final self = resolveSelfBucket(me.payload, preferred);
      final startRev = store.sharedRevision;
      final merged = _merge(me.payload, self);
      if (_shouldSave(merged, me.payload)) {
        final finalPayload = await _saveV3(merged, me, self);
        _apply(finalPayload, self); // 충돌로 다시 합쳤으면 그 결과도 기기에
        store.markSynced(startRev);
      } else if (samePayload(merged, me.payload)) {
        store.markSynced(startRev);
      }
    } else {
      throw const RpcException('PGRST202', '서버에 동기화 함수(Gunpula v2/v3 SQL)가 없어요');
    }
  }

  String _emailName() {
    final e = auth.email;
    final at = e.indexOf('@');
    return at > 0 ? e.substring(0, at) : '';
  }

  /// 서버 payload + 지금 기기의 내 기록 → 새 payload, 그리고 기기에도 그 결과를 넣는다
  Map<String, Object?> _merge(Map<String, Object?> remote, String self) {
    final merged = buildSyncPayload(
      remote: remote,
      self: self,
      localSelf: store.items,
      localExtras: store.payloadExtra,
      localCollectionExtras: store.collectionExtra,
      extrasDirty: store.extrasDirty,
    );
    _apply(merged, self);
    return merged;
  }

  /// 기기에 반영 — 기다리는 사이 내가 또 바꾼 것이 있으면 그것도 살린다 (상품별로 늦은 쪽)
  void _apply(Map<String, Object?> payload, String self) {
    selfName = safeMemberName(self);
    final options = CollectionOptions.forSelf(selfName);
    final mine = mergeCollectionState(
      {
        'member_items': {selfName: store.items},
      },
      payload['collection'],
      options,
    );
    store.applyCloud(
      member: selfName,
      selfItems: selfItemsOf({'collection': mine}, selfName),
      payloadExtra: {
        for (final e in payload.entries)
          if (e.key != 'collection' && e.key != 'appearance') e.key: e.value,
      },
      collectionExtra: collectionExtrasOf(payload),
    );
    _seenShared = store.sharedRevision; // 받아 온 것은 "내가 바꾼 것"이 아니다
  }

  bool _shouldSave(Map<String, Object?> merged, Map<String, Object?> remote) {
    if (samePayload(merged, remote)) return false;
    if (store.cloudDirty || store.extrasDirty) return true;
    // 내가 바꾼 것 없이 정리만 달라짐 → 처음 한 번, 그 뒤로는 [mergeOnlyEvery] 마다만
    final now = _clock();
    final last = _lastMergeOnlySave;
    if (last != null && now.difference(last) < mergeOnlyEvery) return false;
    _lastMergeOnlySave = now;
    return true;
  }

  /// v3 save_state — 40001 이면 get_me → 합침 → 다시 (재시도 최대 3번). 마지막으로 보낸 payload 를 돌려준다.
  Future<Map<String, Object?>> _saveV3(Map<String, Object?> payload, MeState me, String self) async {
    final rpc = _rpc();
    var body = payload;
    var base = me.revision;
    for (var attempt = 0; ; attempt++) {
      try {
        friends.applyMe(await rpc('gunpula_v3_save_state', {'p_payload': body, 'p_base_revision': base}));
        return body;
      } on RpcException catch (e) {
        if (!e.isRevisionConflict || attempt >= 3) rethrow;
        v3Conflicts++;
        final raw = await rpc('gunpula_v3_get_me');
        friends.applyMe(raw);
        final fresh = MeState.parse(raw);
        if (fresh == null) rethrow;
        body = mergeCloudPayload(body, fresh.payload, CollectionOptions.forSelf(self));
        base = fresh.revision;
      }
    }
  }

  /// 설정 화면 한 줄
  String get statusLine {
    final dirty = store.cloudDirty;
    return switch (phase) {
      SyncPhase.off => auth.signedIn ? '곧 동기화해요' : '로그인하지 않음',
      SyncPhase.syncing => '동기화 중…',
      SyncPhase.synced => [
        '동기화됨${lastSyncedAt == null ? '' : ' · ${_ago(lastSyncedAt!)}'}',
        if (workspace case final w?) '공유 공간 「${w.name}」 · $selfName${w.canEdit ? '' : ' (읽기 전용)'}' else '내 계정에 저장',
        if (accountSwitched) '다른 계정이라 이 기기의 구매함 · 좋아요를 이 계정 것으로 바꿨어요',
      ].join('\n'),
      SyncPhase.offline => dirty ? '오프라인 — 바꾼 것은 기기에 있고, 연결되면 올려요' : '오프라인 — 연결되면 다시 받아요',
      SyncPhase.error => '동기화하지 못했어요: $message${dirty ? '\n바꾼 것은 기기에 남아 있어요' : ''}',
    };
  }

  String _ago(DateTime t) {
    final d = _clock().difference(t);
    if (d.inSeconds < 60) return '방금';
    if (d.inMinutes < 60) return '${d.inMinutes}분 전';
    return '${d.inHours}시간 전';
  }

  @override
  void dispose() {
    _stopPoll();
    _debounceTimer?.cancel();
    if (_started) {
      store.removeListener(_onStore);
      auth.removeListener(_onAuth);
    }
    super.dispose();
  }
}
