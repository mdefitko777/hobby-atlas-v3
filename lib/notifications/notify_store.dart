// 알림 — 앱 전체가 함께 보는 한 벌: 🔔 안 읽은 수 · 알림 화면(읽음 · 지움) · 설정 스위치 · 새 소식 확인.
// 저장: notify_config.json(설정 + 확인할 대상) · notify_state.json(알림함). 모양은 notify_models.dart.
// 확인은 lib/background/catalog_check_worker.dart 의 runCatalogCheck — 앱을 열 때 · 돌아올 때(20분에 한 번) + 12시간마다 백그라운드.
import '../format.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../background/catalog_check_worker.dart';
import '../channels.dart' show defaultMyChannels;
import '../data/blob_store.dart';
import '../data/catalog.dart';
import '../data/user_store.dart';
import '../l10n/l10n.dart';
import '../logic/announcement_match.dart' show annReplacedOf, moveAnnIds;
import '../logic/lego_scope.dart';
import '../logic/preorder.dart' show Preorder;
import '../models.dart';
import 'feed_rules.dart' show annRank, annStageKey;
import 'live_reminders.dart' show liveRule;
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
    Catalog.instance.addListener(_onCatalog);
    L10n.notifier.addListener(_onLanguage);
    await LocalNotifier.init();
    await _writeConfig();
    await scheduleCatalogCheck(enabled: config.enabled);
    // 백그라운드에서 다녀온 사이 생긴 알림을 읽고, 오래됐으면 한 번 더 확인
    _life = AppLifecycleListener(onResume: () => unawaited(_onResume()));
    // 좋아요한 PB 상품의 예약 기간은 카탈로그에서 오므로 카탈로그가 준비된 뒤 첫 확인 (못 받아도 확인은 한다)
    // 그 확인이 간격 때문에 건너뛰어졌어도, 받아 둔 예고 파일이 라이브 알림을 건 판보다 새것이면 한 번 본다 (_onCatalog)
    unawaited(
      Catalog.instance.ensureLoaded().then((_) {}, onError: (Object _) {}).whenComplete(() async {
        await checkNow();
        _onCatalog();
      }),
    );
  }

  /// 화면 언어를 바꾸면: notify_config.json 의 상품 이름(PB 예약 · 발매 D-n · 예약 도착 알림 제목)을 새 언어로 다시 쓰고,
  /// 안드로이드 설정 › 알림의 채널 이름도 바꾼다 — 안 하면 다음 저장(보통 다음 실행)까지 백그라운드 알림이 옛 언어
  void _onLanguage() {
    _scheduleConfig();
    unawaited(LocalNotifier.renameChannels());
  }

  /// 앱이 받아 둔 예고 파일이 라이브 알림을 건 판보다 새것이다 (홈에서 당겨서 새로 고침 …) → 20분을 기다리지 않고 바로 확인해
  /// 오늘 잡힌 라이브도 시작 전 알림이 걸리게 한다. 그 지문 하나에 한 번만 (확인이 실패해도 되풀이하지 않는다)
  void _onCatalog() {
    _scheduleConfig();
    unawaited(_readReplaced());
    final hash = Catalog.auxHashes(Catalog.instance.manifest)['announcements.json'];
    if (hash == null || hash == state.liveKey || hash == _liveAsked || !config.rule(liveRule)) return;
    _liveAsked = hash;
    _checkLive();
  }

  String _liveAsked = '';
  bool _liveAgain = false;

  /// [_readReplaced] 가 본 예고 파일 지문 — 카탈로그가 알릴 때마다 파일을 다시 풀지 않게
  String? _replacedSeen;

  /// 앱이 받아 둔 예고 파일의 `replaced` 로 알림 받는 예고를 옮겨 적는다 ([adoptReplaced]). 알림 받는 예고가 없으면 읽지 않는다
  Future<void> _readReplaced() async {
    final hash = Catalog.auxHashes(Catalog.instance.manifest)['announcements.json'] ?? '';
    if (config.followed.isEmpty || hash == _replacedSeen) return;
    try {
      final anns = await Catalog.instance.aux('announcements.json');
      if (anns == null) return; // 못 읽었으면 다음 알림에서 다시
      _replacedSeen = hash;
      adoptReplaced(annReplacedOf(anns));
    } on Object catch (e) {
      debugPrint('[notify] 예고 파일을 읽지 못함: $e');
    }
  }

  /// 라이브 알림 계획을 지금 다시 (규칙 · 새 소식 알림 스위치를 바꿨을 때도 — 꺼 놓고 걸린 알림이 뜨면 안 된다).
  /// 확인 중이면 끝난 뒤에 한 번 더
  void _checkLive() {
    if (checking) {
      _liveAgain = true;
    } else {
      unawaited(checkNow(force: true));
    }
  }

  Future<void> _onResume() async {
    await reloadFromDisk();
    // 오래 뒤에 있던 앱: 상품 목록도 새 데이터가 있는지 본다 (알림 확인과 같은 [checkInterval] · manifest 가 같으면
    // 안 받는다 · 뒤 작업이 새 manifest 를 봤으면 바로) — 「새 상품」 알림을 누르면 그 상품이 이 기기 목록에 있게
    unawaited(Catalog.instance.checkForNewData(maxAge: checkInterval));
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

  /// 읽음 · 지움을 파일에 — 잠그고, 쓰기 직전에 파일을 다시 읽어 합친다 (백그라운드 확인이 그 사이 썼을 수 있다)
  void _saveState() {
    notifyListeners();
    if (!persist) return;
    _writes = _writes
        .then((_) async {
          final next = await BlobStore.locked(notifyStateKey, () async {
            final disk = NotifyState.fromJson(_decode(await BlobStore.read(notifyStateKey)));
            final next = NotifyState.merge(disk, state);
            await BlobStore.write(notifyStateKey, jsonEncode(next.toJson()));
            return next;
          });
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
    _catchUpFollowed();
    notifyListeners();
    // 알림 확인(뒤 작업 · 앱)이 상품 목록보다 새 manifest 를 봤다 → 상품 목록도 받는다 (그 manifest 하나에 한 번)
    if (persist && Catalog.instance.noteManifestSeen(next.lastManifest)) {
      unawaited(Catalog.instance.checkForNewData(maxAge: checkInterval));
    }
  }

  // ── 확인 ──
  /// 앱을 열 때 · 돌아올 때 확인하는 간격 (상품 목록의 새 데이터 확인도 이 간격)
  static const checkInterval = Duration(minutes: 20);

  /// [force] = 바로 (당겨서 새로 고침 · "지금 확인"), 아니면 마지막 확인에서 [checkInterval] 이 지났을 때만
  Future<CheckOutcome?> checkNow({bool force = false}) async {
    if (!persist || checking) return null;
    final last = DateTime.tryParse(state.lastCheckAt);
    if (!force && last != null && DateTime.now().difference(last) < checkInterval) return null;
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
      if (_liveAgain) {
        _liveAgain = false;
        unawaited(checkNow(force: true));
      }
    }
  }

  /// 설정 줄: "11.01 13:20 확인" 또는 오류 (오류 글은 파일에 한국어로 남고, 보일 때 번역)
  String get shortStatus {
    final at = DateTime.tryParse(state.lastCheckAt)?.toLocal();
    if (at == null) return tr('아직 확인하지 않았어요');
    if (state.lastError.isNotEmpty) return tr(state.lastError);
    return trf('{time} 확인', {'time': shortDateTime(at)});
  }

  /// "마지막 확인 11.01 13:20 · 피드 2026-10-23 · 새 알림 2" (+ 요약 피드만 읽었으면 그렇다고)
  String get statusLine {
    final at = DateTime.tryParse(state.lastCheckAt)?.toLocal();
    if (at == null) return tr('아직 확인하지 않았어요');
    final t = shortDateTime(at);
    if (state.lastError.isNotEmpty) return trf('마지막 확인 {time} · {error}', {'time': t, 'error': tr(state.lastError)});
    final src = switch (state.lastSource) {
      'lite' => ' · ${tr('요약 피드(날짜마다 20개까지)')}',
      'atlas+lite' => ' · ${tr('새 소식 파일 기다리는 중')}',
      _ => '',
    };
    final feed = state.lastSeen.isEmpty ? '-' : state.lastSeen;
    return trf('마지막 확인 {time} · 피드 {feed} · 새 알림 {n}', {'time': t, 'feed': feed, 'n': state.lastNew}) + src;
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
    _checkLive(); // 걸어 둔 라이브 알림을 거두거나 다시 건다
    return true;
  }

  void setOnlyMine(bool v) {
    config.onlyMine = v;
    _configChanged();
  }

  void setRule(String key, bool v) {
    config.rules[key] = v;
    _configChanged();
    if (key == liveRule) _checkLive();
  }

  /// 내가 만든 알림 조건 — 같은 조건은 한 번만
  void addCondition(NotifyCondition x) {
    if (config.conditions.any((y) => y.id == x.id)) return;
    config.conditions.add(x);
    _configChanged();
  }

  void removeCondition(String id) {
    config.conditions.removeWhere((x) => x.id == id);
    _configChanged();
  }

  // ── 예고 알림 받기 ──
  bool isFollowing(String annId) => config.followed.containsKey(annId);

  /// 공식 쪽이 이어받아 빠진 예고(announcements.json `replaced`: 옛 id → 새 id)를 알림 받는 목록에서 새 id 로.
  /// 걸 때의 단계는 그대로 두어 「공식 발표 → 예약 시작」이 한 번 울린다. 옮긴 것이 있을 때만 저장하고 true —
  /// 옮긴 뒤로는 옛 id 가 없어 같은 지도를 다시 받아도 쓰지 않는다
  bool adoptReplaced(Map<String, String> replaced) {
    final moved = moveAnnIds(config.followed, replaced);
    if (moved == null) return false;
    config.followed
      ..clear()
      ..addAll(moved);
    _catchUpFollowed(); // 옮기기 전에 뒤 작업이 새 id 로 넣은 단계 줄이 있으면 그만큼 올린다
    _configChanged();
    return true;
  }

  /// [stage] = 지금 단계 (화면 글자). 이 단계보다 앞으로 넘어가면 알림
  void setFollow(String annId, bool on, {required String stage, String title = '', String franchise = ''}) {
    if (on) {
      config.followed[annId] = FollowedAnn(stage: annStageKey(stage), title: title, franchise: franchise);
    } else {
      config.followed.remove(annId);
    }
    _configChanged();
  }

  /// 알림함에 들어온 예고 단계 줄 → 알림 받는 예고의 단계를 그만큼 올린다 (알림함 줄이 오래돼 지워져도 다시 울리지 않게)
  void _catchUpFollowed() {
    var changed = false;
    for (final r in state.inbox) {
      final f = config.followed[r.annId];
      final stage = r.reasons.firstOrNull;
      if (!r.isAnnStage || f == null || stage == null) continue;
      if (annRank(stage) > annRank(f.stage)) {
        config.followed[r.annId] = FollowedAnn(stage: stage, title: f.title, franchise: f.franchise);
        changed = true;
      }
    }
    if (changed) _scheduleConfig();
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

  /// 설정 + 내 채널 · 좋아요 · 구매함 id · 좋아요한 PB 상품의 예약 기간 · 예약 도착 → notify_config.json (백그라운드 확인이 읽는다)
  Future<void> _writeConfig() async {
    _configTimer?.cancel();
    if (!persist) return;
    final me = _me ?? UserStore.instance;
    final wanted = me.idsWith(const {CollectStatus.wanted});
    final byId = Catalog.instance.byId;
    config
      ..channels = [...me.myChannels]
      ..legoAll = me.legoScope == LegoScope.all
      ..wanted = wanted.toSet()
      ..owned = me
          .idsWith(const {CollectStatus.owned})
          .toSet() // 재판매 알림만
      ..preorders = byId.isEmpty ? config.preorders : preorderDuesFor(me.activePreorders, byId)
      // 카탈로그를 아직 못 읽었으면(앱을 막 켰을 때 · 오프라인 첫 실행) 지난번 예약 기간을 그대로 둔다 —
      // 빈 목록으로 덮으면 그 사이 백그라운드 확인이 PB 예약 알림을 놓친다. 좋아요를 뺀 상품은 확인할 때 걸러진다.
      ..pb = byId.isEmpty ? config.pb : pbWindowsFor(wanted, byId, DateTime.now())
      ..releases = byId.isEmpty ? config.releases : releaseDaysFor(wanted, byId, DateTime.now());
    await BlobStore.write(notifyConfigKey, jsonEncode(config.toJson()));
  }
}

/// 알림 한 벌을 위젯 트리에 (AGENTS.md: 위쪽 Host(InheritedWidget) + 저장소 객체 — MarksHost 와 같은 모양).
/// main.dart 의 MaterialApp.builder 가 NotifyStore.instance 로 감싼다. 🔔 · 알림 화면 · 설정이 같은 값을 본다.
class NotifyScope extends InheritedNotifier<NotifyStore> {
  const NotifyScope({super.key, required NotifyStore store, required super.child}) : super(notifier: store);

  /// 그리는 중(build)에 — 알림함 · 설정이 바뀌면 다시 그려진다. 위에 없으면(단독 위젯 테스트) 앱 전체 한 벌.
  static NotifyStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NotifyScope>()?.notifier ?? NotifyStore.instance;

  /// 누를 때 · initState 에 (다시 그리지 않는다)
  static NotifyStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<NotifyScope>()?.notifier ?? NotifyStore.instance;
}

/// 기다리는 예약 중 도착 예정을 적은 것 (도착 달 · 도착 날 알림)
List<PreorderDue> preorderDuesFor(Map<String, Preorder> active, Map<String, Kit> byId) => [
  for (final e in active.entries)
    if (e.value.arrival.isNotEmpty)
      PreorderDue(
        id: e.key,
        name: byId[e.key]?.name ?? e.key,
        franchise: byId[e.key]?.franchiseId ?? '',
        arrival: e.value.arrival,
        due: e.value.due,
        shop: e.value.shop,
      ),
];

/// 좋아요한 상품 중 발매일이 하루까지 정해져 있고 아직 안 지난 것 (D-7 · D-1 · 당일 알림)
List<ReleaseDay> releaseDaysFor(Iterable<String> wantedIds, Map<String, Kit> byId, DateTime now) {
  final today = DateTime.utc(now.year, now.month, now.day).toIso8601String().substring(0, 10);
  final exact = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  return [
    for (final id in wantedIds)
      if (byId[id] case final k? when exact.hasMatch(k.date) && k.date.compareTo(today) >= 0)
        ReleaseDay(id: k.id, name: k.name, franchise: k.franchiseId, date: k.date),
  ];
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
