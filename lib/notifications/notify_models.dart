// 알림 저장 모양 — 기기 파일 두 개 (안드로이드: 앱 전용 폴더 / 웹 미리보기: localStorage)
//   notify_config.json : 설정 + 확인할 대상(내 채널 · 좋아요 id · PB 예약 기간). 앱 화면만 쓰고, 백그라운드 확인은 읽기만 한다.
//   notify_state.json  : 알림함 · 읽음/지움 · 마지막으로 본 피드. 앱과 백그라운드(WorkManager) 둘 다 쓴다 →
//                        쓰기 직전에 파일을 다시 읽어 합친다. 알림은 id 로 합치고, 읽음 · 지움은 나중에 바꾼 쪽이 이긴다.
// 이 파일은 Flutter 위젯을 쓰지 않는다 (백그라운드 isolate · 단위 테스트에서 그대로 돈다).

import '../json_util.dart';

const notifyConfigKey = 'notify_config.json';
const notifyStateKey = 'notify_state.json';

/// 알림 규칙 (옛 Gunpula main.js DEFAULT_NOTIFICATION_FILTERS + v3 의 좋아요 · PB 예약 기간)
const notifyRuleDefaults = <String, bool>{
  'premium_bandai': true,
  'seed_00': true,
  'bbx': true,
  'wanted': true,
  'pb_window': true,
  'release_soon': true,
  // 좋아요 · 구매함 상품의 재판매(再販) 소식 (Gunpula 피드 change_reasons 'restock')
  'restock': true,
  // 예약한 상품의 도착 달 · 도착 날 (기기에 적은 예약 — lib/logic/preorder.dart)
  'preorder_arrival': true,
  'gundam': false,
  'armored_core': false,
  'pokemon': false,
  'fate': false,
  'madoka': false,
};

/// 관심 항목 (켜 두면 그 항목만) · 세계관 전체 (그 채널의 새 상품 전부)
const notifyInterestRules = [
  'premium_bandai',
  'seed_00',
  'bbx',
  'wanted',
  'pb_window',
  'release_soon',
  'restock',
  'preorder_arrival',
];
const notifyWorldRules = ['gundam', 'armored_core', 'pokemon', 'fate', 'madoka'];

const notifyRuleLabels = <String, String>{
  'premium_bandai': 'PB (프리미엄 반다이)',
  'seed_00': 'SEED / 00',
  'bbx': 'BBX',
  'wanted': '좋아요한 상품',
  'pb_window': 'PB 예약 기간',
  'release_soon': '발매 D-7 · D-1',
  'restock': '재판매',
  'preorder_arrival': '예약 도착',
  'gundam': '건담 전체',
  'armored_core': '아머드 코어 전체',
  'pokemon': '포켓몬 전체',
  'fate': 'Fate 전체',
  'madoka': '마도카 마기카 전체',
};

/// 좋아요한 PB 상품의 예약 기간 (kits 의 premium_bandai.order_opens_at · order_closes_at, Wayback 에서 읽은 값)
class PbWindow {
  const PbWindow({required this.id, required this.name, this.franchise = '', this.opens = '', this.closes = ''});

  final String id;
  final String name;
  final String franchise;

  /// YYYY-MM-DD (없으면 빈 글자)
  final String opens;
  final String closes;

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'franchise': franchise, 'opens': opens, 'closes': closes};

  static PbWindow? fromJson(Object? json) {
    final j = jMap(json);
    final id = jStr(j['id']);
    if (id.isEmpty) return null;
    return PbWindow(
      id: id,
      name: jStr(j['name']),
      franchise: jStr(j['franchise']),
      opens: _day(j['opens']),
      closes: _day(j['closes']),
    );
  }
}

/// 좋아요한 상품의 정확한 발매일 (kits 의 release_date 가 YYYY-MM-DD 인 것만) — D-7 · D-1 · 당일 알림
class ReleaseDay {
  const ReleaseDay({required this.id, required this.name, required this.date, this.franchise = ''});

  final String id;
  final String name;
  final String franchise;

  /// YYYY-MM-DD
  final String date;

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'franchise': franchise, 'date': date};

  static ReleaseDay? fromJson(Object? json) {
    final j = jMap(json);
    final id = jStr(j['id']);
    final date = _day(j['date']);
    if (id.isEmpty || date.isEmpty) return null;
    return ReleaseDay(id: id, name: jStr(j['name']), franchise: jStr(j['franchise']), date: date);
  }
}

/// 예약한 상품의 도착 예정 (기기 local_state 'preorders' 에서 앱 화면이 옮겨 적는다) — 도착 달 · 도착 날 알림
class PreorderDue {
  const PreorderDue({
    required this.id,
    required this.name,
    required this.arrival,
    this.franchise = '',
    this.due = 0,
    this.shop = '',
  });

  final String id;
  final String name;
  final String franchise;

  /// 'YYYY-MM' 또는 'YYYY-MM-DD'
  final String arrival;

  /// 아직 낼 돈 (원, 결제 완료면 0)
  final int due;
  final String shop;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'franchise': franchise,
    'arrival': arrival,
    if (due > 0) 'due': due,
    if (shop.isNotEmpty) 'shop': shop,
  };

  static PreorderDue? fromJson(Object? json) {
    final j = jMap(json);
    final id = jStr(j['id']);
    final arrival = RegExp(r'^\d{4}-\d{2}(-\d{2})?$').hasMatch(jStr(j['arrival'])) ? jStr(j['arrival']) : '';
    if (id.isEmpty || arrival.isEmpty) return null;
    return PreorderDue(
      id: id,
      name: jStr(j['name']),
      franchise: jStr(j['franchise']),
      arrival: arrival,
      due: j['due'] is num ? (j['due']! as num).toInt() : 0,
      shop: jStr(j['shop']),
    );
  }
}

/// 설정 + 확인할 대상. 앱 화면이 만들어 저장하고, 백그라운드 확인이 읽는다.
class NotifyConfig {
  NotifyConfig({
    this.enabled = true,
    this.onlyMine = true,
    Map<String, bool>? rules,
    this.permissionAsked = false,
    List<String>? channels,
    Set<String>? wanted,
    Set<String>? owned,
    List<PreorderDue>? preorders,
    List<PbWindow>? pb,
    List<ReleaseDay>? releases,
    Map<String, FollowedAnn>? followed,
  }) : rules = {...notifyRuleDefaults, ...?rules},
       channels = channels ?? const ['gundam', 'beyblade', 'pokemon'],
       wanted = wanted ?? const {},
       owned = owned ?? const {},
       preorders = preorders ?? const [],
       pb = pb ?? const [],
       releases = releases ?? const [],
       followed = followed ?? {};

  /// 휴대폰 알림을 보낼지 (알림함은 꺼도 채워진다)
  bool enabled;

  /// 내 채널의 상품만 (좋아요한 상품은 채널과 상관없이)
  bool onlyMine;
  final Map<String, bool> rules;

  /// 처음 실행 때 알림 권한을 한 번 물어봤는지
  bool permissionAsked;

  List<String> channels;
  Set<String> wanted;

  /// 구매함 id — 재판매 알림만 본다 (좋아요한 상품의 다른 알림과 섞지 않는다)
  Set<String> owned;

  /// 기다리는 예약 중 도착 예정이 있는 것
  List<PreorderDue> preorders;
  List<PbWindow> pb;

  /// 좋아요한 상품 중 발매일이 아직 안 지난 것 (D-7 · D-1 · 당일 알림)
  List<ReleaseDay> releases;

  /// 알림 받는 공식 예고 (예고 id → 누를 때의 단계). 단계가 넘어가면 알림 (채널 · 규칙과 상관없이)
  final Map<String, FollowedAnn> followed;

  bool rule(String key) => rules[key] ?? notifyRuleDefaults[key] ?? false;

  Map<String, Object?> toJson() => {
    'schema': 1,
    'enabled': enabled,
    'only_mine': onlyMine,
    'rules': rules,
    'permission_asked': permissionAsked,
    'channels': channels,
    'wanted': wanted.toList(),
    'pb': [for (final w in pb) w.toJson()],
    if (owned.isNotEmpty) 'owned': owned.toList(),
    if (preorders.isNotEmpty) 'preorders': [for (final p in preorders) p.toJson()],
    if (releases.isNotEmpty) 'releases': [for (final r in releases) r.toJson()],
    if (followed.isNotEmpty) 'followed': {for (final e in followed.entries) e.key: e.value.toJson()},
  };

  static NotifyConfig fromJson(Object? json) {
    final j = jMap(json);
    return NotifyConfig(
      enabled: j['enabled'] is bool ? j['enabled']! as bool : true,
      onlyMine: j['only_mine'] is bool ? j['only_mine']! as bool : true,
      rules: {
        for (final e in jMap(j['rules']).entries)
          if (e.value is bool) e.key: e.value! as bool,
      },
      permissionAsked: j['permission_asked'] == true,
      channels: j['channels'] is List ? jList(j['channels']).whereType<String>().toList() : null,
      wanted: jList(j['wanted']).whereType<String>().toSet(),
      owned: jList(j['owned']).whereType<String>().toSet(),
      preorders: jList(j['preorders']).map(PreorderDue.fromJson).nonNulls.toList(),
      pb: jList(j['pb']).map(PbWindow.fromJson).nonNulls.toList(),
      releases: jList(j['releases']).map(ReleaseDay.fromJson).nonNulls.toList(),
      followed: {for (final e in jMap(j['followed']).entries) e.key: ?FollowedAnn.fromJson(e.value)},
    );
  }
}

/// 알림 받는 공식 예고 한 개 — [stage] 는 announcements.json 의 status (announced · product_confirmed …)
class FollowedAnn {
  const FollowedAnn({required this.stage, required this.title, required this.franchise});
  final String stage;
  final String title;
  final String franchise;

  Map<String, Object?> toJson() => {'stage': stage, 'title': title, 'franchise': franchise};

  static FollowedAnn? fromJson(Object? json) {
    final j = jMap(json);
    final stage = jStr(j['stage']);
    if (stage.isEmpty) return null;
    return FollowedAnn(stage: stage, title: jStr(j['title']), franchise: jStr(j['franchise']));
  }
}

/// 알림함 한 줄 — 만들어진 뒤 바뀌지 않는다 (읽음 · 지움은 [NoticeFlag] 로 따로)
class NoticeRecord {
  const NoticeRecord({
    required this.id,
    required this.kind,
    required this.kitId,
    required this.title,
    required this.body,
    required this.at,
    this.franchise = '',
    this.date = '',
    this.reasons = const [],
    this.pb = false,
    this.wanted = false,
    this.watched = false,
    this.seen = false,
    this.annId = '',
  });

  /// `feed-<피드 날짜>-<kit_id>` · `pb-open-<kit_id>-<날짜>` · `pb-close-<kit_id>-<날짜>` · `ann-<예고 id>-<단계>` ·
  /// `rel-<kit_id>-<발매일>-d7|d1|d0` · `pre-<kit_id>-<도착 예정>-month|d0`
  final String id;

  /// added · changed · pb_open · pb_close · ann_stage · release · restock(재판매) · preorder(예약 도착)
  final String kind;

  /// ann_stage: 공식 예고 id (단계는 [reasons] 첫 칸)
  final String annId;
  final String kitId;
  final String title;
  final String body;

  /// 알림 시각 (피드: 피드를 만든 시각, PB: 확인한 시각)
  final DateTime at;
  final String franchise;

  /// 피드 날짜 또는 예약 시작 · 마감 날짜 (YYYY-MM-DD)
  final String date;

  /// change_reasons (new · price · release · limited · source …)
  final List<String> reasons;
  final bool pb;

  /// 좋아요한 상품 → 채널과 상관없이 보인다
  final bool wanted;

  /// SEED / 00
  final bool watched;

  /// 처음 설치 때 채운 지난 소식 = 읽은 것으로 시작 (휴대폰 알림도 보내지 않는다)
  final bool seen;

  bool get isPbWindow => kind == 'pb_open' || kind == 'pb_close';
  bool get isAnnStage => kind == 'ann_stage';
  bool get isRestock => kind == 'restock';
  bool get isPreorder => kind == 'preorder';

  /// 휴대폰 알림 채널 — catalog(새 상품 · 변경) · wanted(좋아요한 상품) · pb(PB 예약) · ann(알림 받는 공식 예고) ·
  /// restock(재판매) · preorder(예약 도착)
  String get channel => isAnnStage
      ? 'ann'
      : isPbWindow
      ? 'pb'
      : isRestock
      ? 'restock'
      : isPreorder
      ? 'preorder'
      : (wanted ? 'wanted' : 'catalog');

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind,
    'kit': kitId,
    'title': title,
    'body': body,
    'at': at.toUtc().toIso8601String(),
    if (franchise.isNotEmpty) 'franchise': franchise,
    if (date.isNotEmpty) 'date': date,
    if (reasons.isNotEmpty) 'reasons': reasons,
    if (pb) 'pb': true,
    if (wanted) 'wanted': true,
    if (watched) 'watched': true,
    if (seen) 'seen': true,
    if (annId.isNotEmpty) 'ann': annId,
  };

  static NoticeRecord? fromJson(Object? json) {
    final j = jMap(json);
    final id = jStr(j['id']);
    final at = DateTime.tryParse(jStr(j['at']));
    if (id.isEmpty || at == null) return null;
    return NoticeRecord(
      id: id,
      kind: jStr(j['kind']),
      kitId: jStr(j['kit']),
      title: jStr(j['title']),
      body: jStr(j['body']),
      at: at,
      franchise: jStr(j['franchise']),
      date: jStr(j['date']),
      reasons: jList(j['reasons']).whereType<String>().toList(),
      pb: j['pb'] == true,
      wanted: j['wanted'] == true,
      watched: j['watched'] == true,
      seen: j['seen'] == true,
      annId: jStr(j['ann']),
    );
  }
}

/// 읽음 · 지움 — [u] (바꾼 시각, ms) 가 큰 쪽이 이긴다. 되돌리기(false)도 같은 방식.
class NoticeFlag {
  const NoticeFlag({this.read, this.dismissed, required this.u});
  final bool? read;
  final bool? dismissed;
  final int u;

  Map<String, Object?> toJson() => {'r': ?read, 'd': ?dismissed, 'u': u};

  static NoticeFlag? fromJson(Object? json) {
    final j = jMap(json);
    final u = j['u'];
    if (u is! num) return null;
    return NoticeFlag(
      read: j['r'] is bool ? j['r']! as bool : null,
      dismissed: j['d'] is bool ? j['d']! as bool : null,
      u: u.toInt(),
    );
  }
}

/// 알림함 + 마지막 확인 기록
class NotifyState {
  NotifyState({
    this.lastSeen = '',
    this.lastManifest = '',
    this.lastCheckAt = '',
    this.lastError = '',
    this.lastNew = 0,
    this.lastSource = '',
    this.pending = '',
    Set<String>? seenFeed,
    List<NoticeRecord>? inbox,
    Map<String, NoticeFlag>? flags,
  }) : seenFeed = seenFeed ?? {},
       inbox = inbox ?? [],
       flags = flags ?? {};

  /// 마지막으로 처리한 피드 날짜 (YYYY-MM-DD). 비어 있으면 처음 실행.
  String lastSeen;

  /// 마지막으로 본 manifest 의 "updated_at|total" — 같으면 피드를 다시 받지 않는다
  String lastManifest;

  /// 마지막 확인 시각 (UTC ISO)
  String lastCheckAt;

  /// 마지막 확인이 실패했으면 그 이유
  String lastError;

  /// 마지막 확인에서 새로 들어온 알림 수
  int lastNew;

  /// 마지막으로 읽은 피드: atlas(data/atlas/notify-feed.json, 전부) · lite(update-feed-lite, 날짜마다 20개까지) · atlas+lite
  String lastSource;

  /// `<manifest 서명>|<처음 본 시각>` — manifest 는 바뀌었는데 같은 판의 피드를 아직 못 받았다 (Pages 가 늦거나
  /// Gunpula 의 Atlas 작업이 아직 안 돌았다). 다음 확인에서 다시 받고, 오래 지나면 그만 기다린다. 다 받았으면 빈 글자.
  String pending;

  /// [lastSeen] 날짜에서 이미 본 상품 줄 id (규칙에 안 걸린 것도). 같은 날짜를 다시 볼 때 늘어난 상품만 보려고 —
  /// 그 사이 규칙을 켜거나 좋아요를 눌러도 이미 지나간 소식으로 휴대폰이 울리지 않게.
  final Set<String> seenFeed;

  final List<NoticeRecord> inbox;
  final Map<String, NoticeFlag> flags;

  /// 알림함 크기 — 오래된 것 · 넘치는 것은 버린다
  static const maxInbox = 300;
  static const keepDays = 120;

  NoticeRecord? record(String id) => inbox.where((r) => r.id == id).firstOrNull;

  bool isRead(String id, {bool fallback = false}) => flags[id]?.read ?? record(id)?.seen ?? fallback;
  bool isDismissed(String id) => flags[id]?.dismissed ?? false;

  Map<String, Object?> toJson() => {
    'schema': 1,
    'last_seen': lastSeen,
    'last_manifest': lastManifest,
    'last_check_at': lastCheckAt,
    if (lastError.isNotEmpty) 'last_error': lastError,
    'last_new': lastNew,
    if (lastSource.isNotEmpty) 'last_source': lastSource,
    if (pending.isNotEmpty) 'pending': pending,
    'seen_feed': seenFeed.toList(),
    'inbox': [for (final r in inbox) r.toJson()],
    'flags': {for (final e in flags.entries) e.key: e.value.toJson()},
  };

  static NotifyState fromJson(Object? json) {
    final j = jMap(json);
    return NotifyState(
      lastSeen: _day(j['last_seen']),
      lastManifest: jStr(j['last_manifest']),
      lastCheckAt: jStr(j['last_check_at']),
      lastError: jStr(j['last_error']),
      lastNew: j['last_new'] is num ? (j['last_new']! as num).toInt() : 0,
      lastSource: jStr(j['last_source']),
      pending: jStr(j['pending']),
      seenFeed: jList(j['seen_feed']).whereType<String>().toSet(),
      inbox: jList(j['inbox']).map(NoticeRecord.fromJson).nonNulls.toList(),
      flags: {for (final e in jMap(j['flags']).entries) e.key: ?NoticeFlag.fromJson(e.value)},
    );
  }

  NotifyState copy() => NotifyState.fromJson(toJson());

  /// 두 벌 합치기 (파일에 있던 것 [a] + 이쪽에서 바꾼 것 [b]).
  /// 알림은 id 로 모으고, 읽음 · 지움은 나중에 바꾼 쪽, 확인 기록은 나중에 확인한 쪽.
  static NotifyState merge(NotifyState a, NotifyState b) {
    final newer = b.lastCheckAt.compareTo(a.lastCheckAt) >= 0 ? b : a;
    final byId = <String, NoticeRecord>{for (final r in a.inbox) r.id: r};
    for (final r in b.inbox) {
      byId.putIfAbsent(r.id, () => r);
    }
    final flags = Map.of(a.flags);
    for (final e in b.flags.entries) {
      final old = flags[e.key];
      if (old == null || e.value.u >= old.u) flags[e.key] = e.value;
    }
    final lastSeen = _maxStr(a.lastSeen, b.lastSeen);
    return NotifyState(
      lastSeen: lastSeen,
      lastManifest: newer.lastManifest,
      lastCheckAt: newer.lastCheckAt,
      lastError: newer.lastError,
      lastNew: newer.lastNew,
      lastSource: newer.lastSource,
      pending: newer.pending,
      seenFeed: {if (a.lastSeen == lastSeen) ...a.seenFeed, if (b.lastSeen == lastSeen) ...b.seenFeed},
      inbox: byId.values.toList(),
      flags: flags,
    )..sortInbox();
  }

  void sortInbox() => inbox.sort((x, y) {
    final c = y.at.compareTo(x.at);
    return c != 0 ? c : x.id.compareTo(y.id);
  });

  /// [keepDays] 일보다 오래된 것 · [maxInbox] 개를 넘는 것을 버린다.
  /// 읽음 · 지움 표시: 알림함 줄(feed- · pb-)의 것은 줄이 없어지면 같이, 알림함 밖 줄(친구 요청 req- 처럼 화면이 따로
  /// 만드는 것)의 것은 바꾼 지 [keepDays] 일이 지나면 — 확인할 때마다 지우면 수락 · 거절한 요청이 다시 나타난다.
  void prune(DateTime now) {
    sortInbox();
    final cutoff = now.subtract(const Duration(days: keepDays));
    inbox.removeWhere((r) => r.at.isBefore(cutoff));
    if (inbox.length > maxInbox) inbox.removeRange(maxInbox, inbox.length);
    final ids = {for (final r in inbox) r.id};
    final oldMs = cutoff.millisecondsSinceEpoch;
    flags.removeWhere((id, f) => isInboxId(id) ? !ids.contains(id) : f.u < oldMs);
  }

  /// 알림함(이 파일)이 만드는 줄의 id 인가
  static bool isInboxId(String id) =>
      id.startsWith('feed-') ||
      id.startsWith('pb-') ||
      id.startsWith('ann-') ||
      id.startsWith('rel-') ||
      id.startsWith('pre-');
}

/// 32비트 FNV-1a — 휴대폰 알림 id 가 isolate · 실행마다 같도록 (String.hashCode 는 보장되지 않음)
int stableId(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h & 0x7fffffff;
}

String _maxStr(String a, String b) => a.compareTo(b) >= 0 ? a : b;

/// '2026-10-31T00:00:00+09:00' → '2026-10-31'
String _day(Object? v) {
  final s = jStr(v).trim();
  return RegExp(r'^\d{4}-\d{2}-\d{2}').firstMatch(s)?.group(0) ?? '';
}
