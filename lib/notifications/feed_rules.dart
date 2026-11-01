// "내 채널의 새 소식" 계산 — Gunpula 의 새 소식 파일을 지난번 본 날짜와 비교해 알림함에 넣을 줄을 만든다.
//   data/atlas/notify-feed.json : 날짜마다 알릴 만한 변화 전부 (kits.json 의 git 판끼리 비교, 개수 제한 없음 · 사진만 바뀐 것은 뺌)
//   data/update-feed-lite.json  : 위 파일이 아직 없거나 늦을 때만. 날짜마다 추가 20 · 변경 20개까지라 바쁜 날엔 PB · SEED/00 ·
//                                 좋아요한 상품의 가격 변경이 잘려 나간다 (2026-11-01: 새 상품 312개 중 20개만)
//   두 파일 모두 entries[].added[] · changed[] 의 상품 모양이 같아 parseFeed 하나로 읽는다.
// 규칙은 옛 Gunpula 앱(app/main.js updateEntryMatchesNotificationFilters · app/update-feed.js itemIsPremiumBandai)과 같고,
// v3 에서 바꾼 점:
//   · 피드 날짜 하나를 통째로가 아니라 상품 하나씩 거른다 (내 채널 · 규칙 · 좋아요)
//   · 사진만 바뀐 것 · 이름 · 분류만 바뀐 것은 알리지 않는다 (피드의 "changed" 대부분이 사진)
//   · SEED / 00 은 series_key 로 본다 (watch_tags 의 '00' 은 BBX 의 BX-00 · CX-00 에도 붙는다)
//   · 좋아요한 PB 상품의 예약 시작 · 마감 임박 (Wayback 기록이라 "바뀌었을 수 있어요" 를 붙인다)
//   · 좋아요한 상품의 발매 D-7 · D-1 · 당일 (발매일이 하루까지 정해진 것만, 기기 안에서 날짜만 비교)
// 이 파일은 Flutter 위젯을 쓰지 않는다 (백그라운드 isolate · 단위 테스트).
import '../data/gunpula.dart' show pickName;
import 'notify_models.dart';
import '../json_util.dart';

/// 피드 상품 한 줄 (entries[].added[] · changed[])
class FeedItem {
  const FeedItem({
    required this.kitId,
    required this.changeType,
    required this.franchise,
    required this.name,
    this.seriesKey = '',
    this.seriesLabel = '',
    this.releaseDate = '',
    this.priceJpy,
    this.isLimited = false,
    this.isPb = false,
    this.watchTags = const [],
    this.interestTags = const [],
    this.reasons = const [],
  });

  final String kitId;

  /// added · changed
  final String changeType;
  final String franchise;
  final String name;
  final String seriesKey;
  final String seriesLabel;
  final String releaseDate;
  final int? priceJpy;
  final bool isLimited;
  final bool isPb;
  final List<String> watchTags;
  final List<String> interestTags;
  final List<String> reasons;

  static FeedItem? fromJson(Object? json, String changeType) {
    final j = jMap(json);
    final id = jStr(j['kit_id']);
    if (id.isEmpty) return null;
    return FeedItem(
      kitId: id,
      changeType: jStr(j['change_type']).isEmpty ? changeType : jStr(j['change_type']),
      franchise: jStr(j['franchise']),
      name: pickName(j['names']).isEmpty ? id : pickName(j['names']),
      seriesKey: jStr(j['series_key']),
      seriesLabel: pickName(j['series_labels']),
      releaseDate: jStr(j['release_date']),
      priceJpy: j['price_jpy'] is num ? (j['price_jpy']! as num).toInt() : null,
      isLimited: j['is_limited'] == true,
      isPb: itemIsPremiumBandai(j),
      watchTags: jList(j['watch_tags']).whereType<String>().toList(),
      interestTags: jList(j['interest_tags']).whereType<String>().toList(),
      reasons: jList(j['change_reasons']).whereType<String>().toList(),
    );
  }

  /// 알릴 만한 변화인가 — 새로 수록 · 가격 · 발매일 · 한정 · 판매처 (사진 · 이름 · 분류만 바뀐 것은 빼고)
  bool get meaningful => changeType == 'added' || reasons.any((r) => !quietReasons.contains(r));

  bool get isSeed00 =>
      franchise == 'gundam' &&
      (seriesKey == 'seed' || seriesKey == 'double_o' || (seriesKey.isEmpty && watchTags.isNotEmpty));

  bool get isBbx => franchise == 'beyblade' || interestTags.contains('bbx');
}

/// 알리지 않는 변화 이유 (Gunpula scripts/build_update_feed.mjs changeReasons)
const quietReasons = {'image', 'name', 'series', 'product_line', 'metadata'};

/// 옛 앱 app/update-feed.js itemIsPremiumBandai 와 같은 판정
bool itemIsPremiumBandai(Map<String, Object?> j) {
  if (j['is_premium_bandai'] == true) return true;
  final text = [
    jStr(j['kit_id']),
    jStr(j['grade_code']),
    jStr(j['subline']),
    ...jMap(j['names']).values.whereType<String>(),
    ...jList(j['source_urls']).whereType<String>(),
  ].join(' ');
  return _pbRe.hasMatch(text);
}

final _pbRe = RegExp(r'p-bandai\.jp|premium\s*bandai|p-?bandai|プレミアムバンダイ|プレバン|pb\s*限定|pb限定', caseSensitive: false);

/// 피드 날짜 하나 (entries[])
class FeedEntry {
  const FeedEntry({
    required this.date,
    required this.items,
    this.generatedAt,
    this.addedCount = 0,
    this.changedCount = 0,
    this.totalAfter,
  });

  /// YYYY-MM-DD
  final String date;
  final DateTime? generatedAt;

  /// 그날 전체 수 (사진만 바뀐 것 포함 — lite 파일의 items 는 앞의 20개씩뿐)
  final int addedCount;
  final int changedCount;

  /// 그날 데이터를 다 만든 뒤의 상품 수 (가장 새 날짜는 split/manifest.json 의 total 과 같아야 한다)
  final int? totalAfter;
  final List<FeedItem> items;
}

/// update-feed-lite.json → 날짜 새것부터
List<FeedEntry> parseFeed(Object? json) {
  final out = <FeedEntry>[];
  for (final raw in jList(jMap(json)['entries'])) {
    final e = jMap(raw);
    final date = jStr(e['date']);
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) continue;
    out.add(
      FeedEntry(
        date: date,
        generatedAt: DateTime.tryParse(jStr(e['generated_at'])),
        addedCount: e['added_count'] is num ? (e['added_count']! as num).toInt() : 0,
        changedCount: e['changed_count'] is num ? (e['changed_count']! as num).toInt() : 0,
        totalAfter: e['total_after'] is num ? (e['total_after']! as num).toInt() : null,
        items: [
          for (final it in jList(e['added'])) ?FeedItem.fromJson(it, 'added'),
          for (final it in jList(e['changed'])) ?FeedItem.fromJson(it, 'changed'),
        ],
      ),
    );
  }
  out.sort((a, b) => b.date.compareTo(a.date));
  return out;
}

/// 피드가 이 manifest 와 같은 판인가 — 가장 새 날짜 = manifest.updated_at, 그날 상품 수 = manifest.total.
/// Pages(CDN)가 manifest 는 새것 · 피드는 옛것을 줄 때가 있어, 같은 판을 받았을 때만 "이 manifest 는 다 봤다"고 적는다.
bool feedMatches(List<FeedEntry> entries, Object? manifest) {
  final m = jMap(manifest);
  if (entries.isEmpty) return false;
  final top = entries.first;
  final total = m['total'];
  return top.date == jStr(m['updated_at']) && total is num && top.totalAfter == total.toInt();
}

/// 두 피드를 날짜별로 합친다 ([a] 의 상품이 앞 — 같은 상품은 planCheck 가 id 로 한 번만 넣는다)
List<FeedEntry> combineFeeds(List<FeedEntry> a, List<FeedEntry> b) {
  final byDate = <String, FeedEntry>{for (final e in a) e.date: e};
  for (final e in b) {
    final x = byDate[e.date];
    byDate[e.date] = x == null
        ? e
        : FeedEntry(
            date: e.date,
            generatedAt: x.generatedAt ?? e.generatedAt,
            addedCount: x.addedCount > e.addedCount ? x.addedCount : e.addedCount,
            changedCount: x.changedCount > e.changedCount ? x.changedCount : e.changedCount,
            totalAfter: x.totalAfter ?? e.totalAfter,
            items: [...x.items, ...e.items],
          );
  }
  return byDate.values.toList()..sort((x, y) => y.date.compareTo(x.date));
}

/// 이 상품이 걸린 규칙 (좋아요 제외). 내 채널 소식만이면 내 채널 밖은 빈 집합.
Set<String> ruleHits(FeedItem it, NotifyConfig c) {
  if (c.onlyMine && !c.channels.contains(it.franchise)) return const {};
  return {
    if (c.rule('premium_bandai') && it.isPb) 'premium_bandai',
    if (c.rule('seed_00') && it.isSeed00) 'seed_00',
    if (c.rule('bbx') && it.isBbx) 'bbx',
    if (notifyWorldRules.contains(it.franchise) && c.rule(it.franchise)) it.franchise,
  };
}

/// 좋아요한 상품인가 (채널과 상관없이)
bool wantedHit(FeedItem it, NotifyConfig c) => c.rule('wanted') && c.wanted.contains(it.kitId);

/// 피드 한 줄 → 알림함 한 줄 (규칙에 안 걸리면 null)
NoticeRecord? recordForItem(FeedItem it, FeedEntry e, NotifyConfig c, {bool seen = false}) {
  if (!it.meaningful) return null;
  final wanted = wantedHit(it, c);
  if (!wanted && ruleHits(it, c).isEmpty) return null;
  return NoticeRecord(
    id: 'feed-${e.date}-${it.kitId}',
    kind: it.changeType,
    kitId: it.kitId,
    title: it.name,
    body: itemBody(it, wanted: wanted),
    at: e.generatedAt ?? DateTime.parse('${e.date}T00:00:00Z'),
    franchise: it.franchise,
    date: e.date,
    reasons: it.reasons,
    pb: it.isPb,
    wanted: wanted,
    watched: it.isSeed00,
    seen: seen,
  );
}

/// 알림 둘째 줄: "좋아요한 상품 · 가격 변경 ¥5,940 · 프리미엄 반다이 · SEED"
String itemBody(FeedItem it, {bool wanted = false}) {
  final reasons = it.changeType == 'added'
      ? ['새로 수록']
      : [
          for (final r in it.reasons)
            if (!quietReasons.contains(r)) _reasonLabel(r, it),
        ];
  return [
    if (wanted) '좋아요한 상품',
    ...reasons,
    if (it.isPb) '프리미엄 반다이',
    if (it.seriesLabel.isNotEmpty && it.franchise != 'pokemon') it.seriesLabel,
    if (it.changeType == 'added' && it.releaseDate.isNotEmpty) '${it.releaseDate} 발매',
  ].join(' · ');
}

String _reasonLabel(String r, FeedItem it) => switch (r) {
  'price' => it.priceJpy == null ? '가격 변경' : '가격 변경 ¥${_comma(it.priceJpy!)}',
  'release' => it.releaseDate.isEmpty ? '발매일 변경' : '발매일 ${it.releaseDate}',
  'limited' => it.isLimited ? '한정 표시' : '한정 해제',
  'source' => '판매처 · 출처 변경',
  _ => '정보 변경',
};

/// PB 예약 기간 알림에 붙는 말 (Wayback 에서 읽은 날짜라)
const pbStaleNote = 'Wayback 기록이라 바뀌었을 수 있어요';

/// 좋아요한 PB 상품: 예약 시작(하루 전 ~ 이틀 뒤) · 마감 임박(3일 안). 이미 알린 것([known])은 빼고.
List<NoticeRecord> pbWindowRecords(NotifyConfig c, Set<String> known, DateTime now) {
  if (!c.rule('pb_window')) return const [];
  final today = DateTime.utc(now.year, now.month, now.day);
  final out = <NoticeRecord>[];
  for (final w in c.pb) {
    if (!c.wanted.contains(w.id)) continue;
    final o = _utcDay(w.opens);
    final cl = _utcDay(w.closes);
    if (o != null) {
      final d = o.difference(today).inDays;
      final id = 'pb-open-${w.id}-${w.opens}';
      if (d <= 1 && d >= -2 && (cl == null || !today.isAfter(cl)) && !known.contains(id)) {
        final when = d == 1 ? '내일 예약 시작 (${_md(w.opens)})' : (d == 0 ? '오늘 예약 시작' : '예약 중 (${_md(w.opens)} 시작)');
        out.add(_pbRecord(id, 'pb_open', w, w.opens, '$when · $pbStaleNote', now));
      }
    }
    if (cl != null) {
      final d = cl.difference(today).inDays;
      final id = 'pb-close-${w.id}-${w.closes}';
      if (d >= 0 && d <= 3 && !known.contains(id)) {
        final when = d == 0 ? '오늘 예약 마감' : '예약 마감 D-$d (${_md(w.closes)})';
        out.add(_pbRecord(id, 'pb_close', w, w.closes, '$when · $pbStaleNote', now));
      }
    }
  }
  return out;
}

NoticeRecord _pbRecord(String id, String kind, PbWindow w, String date, String body, DateTime now) => NoticeRecord(
  id: id,
  kind: kind,
  kitId: w.id,
  title: w.name,
  body: body,
  at: now.toUtc(),
  franchise: w.franchise,
  date: date,
  pb: true,
  wanted: true,
);

/// 좋아요한 상품의 발매 알림: 7–2일 전 한 번(D-7) · 하루 전(D-1) · 당일. 이미 알린 것([known])은 빼고.
/// 12시간마다 확인하니, 휴대폰이 꺼져 있던 날은 다음 확인 때 그 단계로 한 번만.
List<NoticeRecord> releaseRecords(NotifyConfig c, Set<String> known, DateTime now) {
  if (!c.rule('release_soon')) return const [];
  final today = DateTime.utc(now.year, now.month, now.day);
  final out = <NoticeRecord>[];
  for (final r in c.releases) {
    if (!c.wanted.contains(r.id)) continue;
    final day = _utcDay(r.date);
    if (day == null) continue;
    final d = day.difference(today).inDays;
    final (stage, body) = switch (d) {
      0 => ('d0', '오늘 발매'),
      1 => ('d1', '내일 발매 (${_md(r.date)})'),
      >= 2 && <= 7 => ('d7', 'D-$d · ${_md(r.date)} 발매'),
      _ => ('', ''),
    };
    if (stage.isEmpty) continue;
    final id = 'rel-${r.id}-${r.date}-$stage';
    if (known.contains(id)) continue;
    out.add(
      NoticeRecord(
        id: id,
        kind: 'release',
        kitId: r.id,
        title: r.name,
        body: '좋아요한 상품 · $body',
        at: now.toUtc(),
        franchise: r.franchise,
        date: r.date,
        reasons: const ['release'],
        wanted: true,
      ),
    );
  }
  return out;
}

// ── 알림 받는 공식 예고 ──────────────────────────────────────────────────────
/// announcements.json status → 화면 글자 (순서 = 단계 순서)
const annStageLabels = {
  'announced': '공식 발표',
  'product_confirmed': '상품화 확정',
  'preorder_open': '예약 시작',
  'released': '발매',
};

/// 화면 글자 → status (없으면 announced)
String annStageKey(String label) =>
    annStageLabels.entries.where((e) => e.value == label).firstOrNull?.key ?? 'announced';

int annRank(String stage) => annStageLabels.keys.toList().indexOf(stage);

/// 알림 받는 예고 중 단계가 앞으로 넘어간 것 → 알림함 줄 (`ann-<id>-<단계>`, 이미 있는 줄은 [known] 으로 건너뛴다).
/// [announcements] = announcements.json 을 푼 값 (못 받았으면 null → 없음)
List<NoticeRecord> annStageRecords(NotifyConfig config, Object? announcements, Set<String> known, DateTime now) {
  if (config.followed.isEmpty) return const [];
  final byId = {
    for (final a in jList(jMap(announcements)['announcements']))
      if (jMap(a) case final m when jStr(m['id']).isNotEmpty) jStr(m['id']): m,
  };
  return [
    for (final e in config.followed.entries)
      if (byId[e.key] case final m?)
        if (jStr(m['status']) case final stage
            when annRank(stage) > annRank(e.value.stage) && !known.contains('ann-${e.key}-$stage'))
          NoticeRecord(
            id: 'ann-${e.key}-$stage',
            kind: 'ann_stage',
            kitId: '',
            annId: e.key,
            title: e.value.title,
            body: '${annStageLabels[e.value.stage] ?? '공식 발표'} → ${annStageLabels[stage]}',
            at: now,
            franchise: e.value.franchise,
            reasons: [stage],
            wanted: true, // 채널과 상관없이 보인다
          ),
  ];
}

/// 처음 실행 때 채우는 지난 소식 · 오래 꺼져 있다 켜졌을 때 조용히 넣는 범위 (가장 새 피드 날짜 기준)
const catchUpDays = 7;

/// 확인 한 번의 결과 (아직 파일에 쓰기 전)
class CheckPlan {
  CheckPlan({
    required this.records,
    required this.lastSeen,
    required this.lastManifest,
    required this.checkedAt,
    this.seenFeed = const {},
    this.error = '',
    this.source = '',
    this.pending = '',
  });

  /// 새로 알림함에 들어갈 줄 (seen = 조용히 넣는 지난 소식)
  final List<NoticeRecord> records;
  final String lastSeen;
  final String lastManifest;
  final DateTime checkedAt;

  /// [lastSeen] 날짜에서 본 상품 줄 id 전부 (NotifyState.seenFeed)
  final Set<String> seenFeed;
  final String error;

  /// 이번에 읽은 피드 (atlas · lite · atlas+lite, 받지 않았으면 빈 글자 → 지난 값 그대로)
  final String source;

  /// 아직 다 보지 못한 manifest (NotifyState.pending)
  final String pending;

  int get liveCount => records.where((r) => !r.seen).length;

  /// [state] 에 이 결과를 합친 새 상태
  NotifyState applyTo(NotifyState state) => NotifyState.merge(
    state,
    NotifyState(
      lastSeen: lastSeen,
      lastManifest: lastManifest,
      lastCheckAt: checkedAt.toUtc().toIso8601String(),
      lastError: error,
      lastNew: liveCount,
      lastSource: source.isEmpty ? state.lastSource : source,
      pending: pending,
      seenFeed: seenFeed,
      inbox: records,
    ),
  );
}

/// 피드([entries], 날짜 새것부터) · PB 기간을 지난 상태와 비교한다.
///  - 처음(lastSeen 없음): 가장 새 날짜에서 [catchUpDays] 일 안의 것만 "읽음"으로 채운다 → 휴대폰 알림 없음
///  - 다음부터: lastSeen 날짜 이후(같은 날짜 포함 — 하루에 두 번 돌면 같은 날짜에 상품이 늘어난다)에서 아직 없는 줄만
///  - 오래 꺼져 있었으면 [catchUpDays] 일보다 오래된 날짜는 조용히(읽음으로) 넣는다
/// 피드를 받지 못했거나 manifest 가 그대로라 받지 않았으면 [entries] 는 비어 있다 (PB 기간만 본다).
CheckPlan planCheck({
  required NotifyConfig config,
  required NotifyState state,
  required List<FeedEntry> entries,
  required String manifestSig,
  required DateTime now,
  String error = '',
  String source = '',
  String pending = '',
  Object? announcements,
}) {
  final known = {for (final r in state.inbox) r.id, ...state.seenFeed};
  final first = state.lastSeen.isEmpty;
  final newest = entries.isEmpty ? '' : entries.first.date;
  final lastSeen = newest.compareTo(state.lastSeen) > 0 ? newest : state.lastSeen;
  final quietBefore = newest.isEmpty ? '' : _shiftDay(newest, -catchUpDays);
  final records = <NoticeRecord>[];
  final seenFeed = <String>{if (lastSeen == state.lastSeen) ...state.seenFeed};
  for (final e in entries) {
    if (first ? e.date.compareTo(quietBefore) < 0 : e.date.compareTo(state.lastSeen) < 0) continue;
    final seen = first || e.date.compareTo(quietBefore) < 0;
    for (final it in e.items) {
      final id = 'feed-${e.date}-${it.kitId}';
      if (e.date == lastSeen) seenFeed.add(id);
      // 이미 본 줄 · 같은 날짜에 added · changed 둘 다 있는 상품은 한 번만
      if (!known.add(id)) continue;
      final r = recordForItem(it, e, config, seen: seen);
      if (r != null) records.add(r);
    }
  }
  records.addAll(pbWindowRecords(config, known, now));
  records.addAll(releaseRecords(config, known, now));
  records.addAll(annStageRecords(config, announcements, known, now));
  return CheckPlan(
    records: records,
    lastSeen: lastSeen,
    lastManifest: manifestSig.isEmpty ? state.lastManifest : manifestSig,
    checkedAt: now,
    seenFeed: seenFeed,
    error: error,
    source: source,
    pending: pending,
  );
}

/// 휴대폰 알림 한 개
class SystemAlert {
  const SystemAlert({
    required this.id,
    required this.channel,
    required this.title,
    required this.body,
    required this.payload,
  });

  /// 같은 id 면 앞의 알림을 바꿔 쓴다 (새 상품 요약은 늘 하나)
  final int id;

  /// catalog · wanted · pb · ann
  final String channel;
  final String title;
  final String body;

  /// `kit:<kit_id>` → 상품 상세 / `ann:<franchise>:<예고 id>` → 예고 / `inbox` → 알림 화면
  final String payload;
}

/// 새로 들어온 줄 → 휴대폰 알림. 새 상품은 요약 하나, 좋아요 · PB 는 3개까지 하나씩(넘으면 요약).
List<SystemAlert> buildAlerts(Iterable<NoticeRecord> fresh) {
  final live = [
    for (final r in fresh)
      if (!r.seen) r,
  ];
  final out = <SystemAlert>[];
  final cat = live.where((r) => r.channel == 'catalog').toList();
  if (cat.isNotEmpty) {
    // 제목: 옛 앱 maybeShowUpdateNotification 과 같은 순서
    final title = cat.any((r) => r.watched)
        ? 'SEED / 00 업데이트'
        : cat.any((r) => r.pb || r.franchise == 'beyblade')
        ? '관심 항목 업데이트'
        : '모델 DB 업데이트';
    final dates = {for (final r in cat) r.date}.toList()..sort();
    final added = cat.where((r) => r.kind == 'added').length;
    final changed = cat.length - added;
    final when = dates.length == 1 ? _md(dates.first) : '${_md(dates.first)}–${_md(dates.last)}';
    out.add(
      SystemAlert(
        id: stableId('catalog'),
        channel: 'catalog',
        title: title,
        body: '$when · 신규 $added · 변경 $changed · ${_names(cat)}',
        payload: cat.length == 1 ? 'kit:${cat.first.kitId}' : 'inbox',
      ),
    );
  }
  final wanted = live.where((r) => r.channel == 'wanted').toList();
  if (wanted.length > 3) {
    out.add(
      SystemAlert(
        id: stableId('wanted'),
        channel: 'wanted',
        title: '좋아요한 상품 ${wanted.length}개가 바뀌었어요',
        body: _names(wanted),
        payload: 'inbox',
      ),
    );
  } else {
    for (final r in wanted) {
      out.add(
        SystemAlert(
          id: stableId('wanted:${r.kitId}'),
          channel: 'wanted',
          title: r.title,
          body: r.body,
          payload: 'kit:${r.kitId}',
        ),
      );
    }
  }
  final pb = live.where((r) => r.channel == 'pb').toList();
  if (pb.length > 3) {
    out.add(
      SystemAlert(
        id: stableId('pb'),
        channel: 'pb',
        title: '좋아요한 PB 상품 ${pb.length}개 예약 소식',
        body: '${_names(pb)} · $pbStaleNote',
        payload: 'inbox',
      ),
    );
  } else {
    for (final r in pb) {
      out.add(
        SystemAlert(
          id: stableId(r.id),
          channel: 'pb',
          title: r.kind == 'pb_open' ? 'PB 예약 시작 · ${r.title}' : 'PB 예약 마감 임박 · ${r.title}',
          body: r.body,
          payload: 'kit:${r.kitId}',
        ),
      );
    }
  }
  final ann = live.where((r) => r.channel == 'ann').toList();
  if (ann.length > 3) {
    out.add(
      SystemAlert(
        id: stableId('ann'),
        channel: 'ann',
        title: '알림 받는 공식 예고 ${ann.length}개가 다음 단계로',
        body: _names(ann),
        payload: 'inbox',
      ),
    );
  } else {
    for (final r in ann) {
      out.add(
        SystemAlert(
          id: stableId(r.id),
          channel: 'ann',
          title: '${annStageLabels[r.reasons.firstOrNull] ?? '다음 단계'} · ${r.title}',
          body: r.body,
          payload: 'ann:${r.franchise}:${r.annId}',
        ),
      );
    }
  }
  return out;
}

/// 「A」 · 「B」 외 3
String _names(List<NoticeRecord> rs) {
  final head = rs.take(2).map((r) => '「${r.title}」').join(' · ');
  return rs.length > 2 ? '$head 외 ${rs.length - 2}' : head;
}

/// '2026-10-23' → '10.23'
String _md(String day) {
  final m = RegExp(r'^\d{4}-(\d{2})-(\d{2})').firstMatch(day);
  if (m == null) return day;
  return '${int.parse(m.group(1)!)}.${m.group(2)}';
}

String _comma(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

DateTime? _utcDay(String day) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(day);
  if (m == null) return null;
  return DateTime.utc(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
}

String _shiftDay(String day, int days) {
  final d = _utcDay(day);
  if (d == null) return '';
  return d.add(Duration(days: days)).toIso8601String().substring(0, 10);
}
