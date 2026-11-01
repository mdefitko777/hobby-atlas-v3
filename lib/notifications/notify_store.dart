// 알림 — 앱 전체가 함께 보는 한 벌: 🔔 안 읽은 수 · 알림 화면(읽음 · 지움) · 설정 스위치 · 새 소식 확인.
// 저장: notify_config.json(설정 + 확인할 대상) · notify_state.json(알림함). 모양은 notify_models.dart.
// 확인은 lib/background/catalog_check_worker.dart 의 runCatalogCheck — 앱을 열 때 · 돌아올 때(20분에 한 번) + 12시간마다 백그라운드.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../background/catalog_check_worker.dart';
import '../channels.dart' show defaultMyChannels;
import '../data/blob_store.dart';
import '../data/catalog.dart';
import '../data/user_store.dart';
import '../models.dart';
import 'local_notifier.dart';
import 'notify_models.dart';

class NotifyStore extends ChangeNotifier {
  NotifyStore._() : persist = true;

  /// 테스트용: 파일에 쓰지 않고, 확인도 하지 않는다
  NotifyStore.memory({List<NoticeRecord> records = const [], NotifyConfig? config}) : persist = false {
    state = NotifyState(inbox: [...records])..sortInbox();
    if (config != null) this.config = config;
  }

  static final instance = NotifyStore._();

  final bool persist;

  NotifyConfig config = NotifyConfig(channels: defaultMyChannels);
  NotifyState state = NotifyState();

  /// 알림함 줄이 늘거나 줄 때마다 +1 (알림 화면이 목록을 다시 부른다)
  int inboxRevision = 0;

  /// 지금 확인 중 (설정의 "지금 확인" 버튼)
  bool checking = false;

  Future<void>? _loading;
  Future<void> _writes = Future<void>.value();
  Timer? _configTimer;
  UserStore? _me;
  bool _started = false;
  // ignore: unused_field
  AppLifecycleListener? _life;

  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    if (!persist) return;
    config = NotifyConfig.fromJson(_decode(await BlobStore.read(notifyConfigKey)));
    state = NotifyState.fromJson(_decode(await BlobStore.read(notifyStateKey)));
    inboxRevision++;
    notifyListeners();
  }

  /// main.dart 에서 한 번: 파일 읽기 → 알림 준비 → 12시간 확인 등록 → 카탈로그가 준비되면 첫 확인
  Future<void> start({required UserStore me, required Future<void> meLoaded}) async {
    if (_started || !persist) return;
    _started = true;
    _me = me;
    await load();
    await meLoaded;
    me.addListener(_scheduleConfig);
    Catalog.instance.addListener(_scheduleConfig);
    await LocalNotifier.init();
    await _writeConfig();
    await scheduleCatalogCheck(enabled: config.enabled);
    // 백그라운드에서 다녀온 사이 생긴 알림을 읽고, 오래됐으면 한 번 더 확인
    _life = AppLifecycleListener(onResume: () => unawaited(_onResume()));
    // 좋아요한 PB 상품의 예약 기간은 카탈로그에서 오므로 카탈로그가 준비된 뒤 첫 확인 (못 받아도 확인은 한다)
    unawaited(Catalog.instance.ensureLoaded().then((_) {}, onError: (Object _) {}).whenComplete(() => checkNow()));
  }

  Future<void> _onResume() async {
    await reloadFromDisk();
    await checkNow();
  }

  // ── 알림함 ──
  bool isRead(String id, {bool fallback = false}) => state.isRead(id, fallback: fallback);
  bool isDismissed(String id) => state.isDismissed(id);

  /// 내 채널 범위 (좋아요한 상품 · PB 예약은 채널과 상관없이)
  bool inScope(NoticeRecord r, List<String> channels) => r.wanted || !config.onlyMine || channels.contains(r.franchise);

  /// 보여 줄 줄: 지우지 않은 것 · 범위 안 · 새것부터
  List<NoticeRecord> visible(List<String> channels) => [
    for (final r in state.inbox)
      if (!isDismissed(r.id) && inScope(r, channels)) r,
  ];

  /// 🔔 숫자
  int unreadCount(List<String> channels) => visible(channels).where((r) => !isRead(r.id)).length;

  void setRead(Iterable<String> ids, bool read) {
    final u = DateTime.now().millisecondsSinceEpoch;
    var changed = false;
    for (final id in ids) {
      final old = state.flags[id];
      state.flags[id] = NoticeFlag(read: read, dismissed: old?.dismissed, u: u);
      changed = true;
    }
    if (changed) _saveState();
  }

  void setDismissed(String id, bool dismissed) {
    final old = state.flags[id];
    state.flags[id] = NoticeFlag(
      read: old?.read ?? (dismissed ? true : null),
      dismissed: dismissed,
      u: DateTime.now().millisecondsSinceEpoch,
    );
    _saveState();
  }

  /// 휴대폰 알림을 눌러 상품을 열었을 때 그 상품 줄을 읽음으로
  void markKitRead(String kitId) => setRead([
    for (final r in state.inbox)
      if (r.kitId == kitId && !isRead(r.id)) r.id,
  ], true);

  /// 읽음 · 지움을 파일에 — 쓰기 직전에 파일을 다시 읽어 합친다 (백그라운드 확인이 그 사이 썼을 수 있다)
  void _saveState() {
    notifyListeners();
    if (!persist) return;
    _writes = _writes
        .then((_) async {
          final disk = NotifyState.fromJson(_decode(await BlobStore.read(notifyStateKey)));
          final next = NotifyState.merge(disk, state);
          await BlobStore.write(notifyStateKey, jsonEncode(next.toJson()));
          _adopt(next);
        })
        .catchError((Object e) => debugPrint('[notify] 알림함 저장 실패: $e'));
  }

  /// 파일(백그라운드가 쓴 것)과 합쳐 다시 읽기
  Future<void> reloadFromDisk() async {
    if (!persist) return;
    await _writes;
    final disk = NotifyState.fromJson(_decode(await BlobStore.read(notifyStateKey)));
    _adopt(NotifyState.merge(disk, state));
  }

  void _adopt(NotifyState next) {
    String sig(NotifyState s) => '${s.inbox.length}|${s.inbox.firstOrNull?.id}|${s.inbox.lastOrNull?.id}';
    if (sig(next) != sig(state)) inboxRevision++;
    state = next;
    notifyListeners();
  }

  // ── 확인 ──
  /// [force] = 바로 (당겨서 새로 고침 · "지금 확인"), 아니면 마지막 확인에서 20분이 지났을 때만
  Future<CheckOutcome?> checkNow({bool force = false}) async {
    if (!persist || checking) return null;
    final last = DateTime.tryParse(state.lastCheckAt);
    if (!force && last != null && DateTime.now().difference(last) < const Duration(minutes: 20)) return null;
    checking = true;
    notifyListeners();
    try {
      await _writeConfig();
      await _writes; // 읽음 표시를 먼저 파일로
      final r = await runCatalogCheck();
      await reloadFromDisk();
      return r;
    } on Object catch (e) {
      debugPrint('[notify] 확인 실패: $e');
      return null;
    } finally {
      checking = false;
      notifyListeners();
    }
  }

  /// "마지막 확인 11.01 13:20 · 피드 2026-10-23 · 새 알림 2"
  String get statusLine {
    final at = DateTime.tryParse(state.lastCheckAt)?.toLocal();
    if (at == null) return '아직 확인하지 않았어요';
    String two(int n) => n.toString().padLeft(2, '0');
    final t = '${at.month}.${two(at.day)} ${two(at.hour)}:${two(at.minute)}';
    if (state.lastError.isNotEmpty) return '마지막 확인 $t · ${state.lastError}';
    return '마지막 확인 $t · 피드 ${state.lastSeen.isEmpty ? '-' : state.lastSeen} · 새 알림 ${state.lastNew}';
  }

  // ── 설정 ──
  /// 켜기: 안드로이드 13+ 은 권한 창. 허용하지 않으면 false (꺼진 채로 둔다)
  Future<bool> setEnabled(bool on) async {
    if (on && LocalNotifier.supported && !await LocalNotifier.requestPermission()) {
      config.enabled = false;
      _configChanged();
      return false;
    }
    config.enabled = on;
    _configChanged();
    await scheduleCatalogCheck(enabled: on);
    return true;
  }

  void setOnlyMine(bool v) {
    config.onlyMine = v;
    _configChanged();
  }

  void setRule(String key, bool v) {
    config.rules[key] = v;
    _configChanged();
  }

  void markHintShown() {
    config.hintShown = true;
    _configChanged();
  }

  /// 처음 실행 때 한 번만: 알림 권한 창. 거절하면 알림을 끈다. 허용되면 true.
  Future<bool> askPermissionOnce() async {
    await load();
    if (!LocalNotifier.supported || config.permissionAsked) return false;
    config.permissionAsked = true;
    if (!config.enabled) {
      _configChanged();
      return false;
    }
    final ok = await LocalNotifier.requestPermission();
    if (!ok) {
      config.enabled = false;
      await scheduleCatalogCheck(enabled: false);
    }
    _configChanged();
    return ok;
  }

  void _configChanged() {
    notifyListeners();
    _scheduleConfig();
  }

  void _scheduleConfig() {
    if (!persist) return;
    _configTimer?.cancel();
    _configTimer = Timer(const Duration(milliseconds: 600), () => unawaited(_writeConfig()));
  }

  /// 설정 + 내 채널 · 좋아요 id · 좋아요한 PB 상품의 예약 기간 → notify_config.json (백그라운드 확인이 읽는다)
  Future<void> _writeConfig() async {
    _configTimer?.cancel();
    if (!persist) return;
    final me = _me ?? UserStore.instance;
    final wanted = me.idsWith(const {CollectStatus.wanted});
    config
      ..channels = [...me.myChannels]
      ..wanted = wanted.toSet()
      ..pb = pbWindowsFor(wanted, Catalog.instance.byId, DateTime.now());
    await BlobStore.write(notifyConfigKey, jsonEncode(config.toJson()));
  }
}

/// 좋아요한 상품 중 PB 예약 기간이 아직 지나지 않은 것 (마감일이 없으면 시작일이 사흘 안쪽인 것)
List<PbWindow> pbWindowsFor(Iterable<String> wantedIds, Map<String, Kit> byId, DateTime now) {
  String ymd(DateTime d) => DateTime.utc(d.year, d.month, d.day).toIso8601String().substring(0, 10);
  final today = ymd(now);
  final recent = ymd(now.subtract(const Duration(days: 3)));
  return [
    for (final id in wantedIds)
      if (byId[id] case final k?
          when (k.pbOpens.isNotEmpty || k.pbCloses.isNotEmpty) &&
              (k.pbCloses.isEmpty ? k.pbOpens.compareTo(recent) >= 0 : k.pbCloses.compareTo(today) >= 0))
        PbWindow(id: k.id, name: k.name, franchise: k.franchiseId, opens: k.pbOpens, closes: k.pbCloses),
  ];
}

Object? _decode(String? text) {
  if (text == null) return null;
  try {
    return jsonDecode(text);
  } on FormatException {
    return null;
  }
}
