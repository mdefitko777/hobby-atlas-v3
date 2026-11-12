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
//   · 좋아요 · 구매함 상품의 재판매(change_reasons 'restock', 규칙 '재판매') — "재판매 · 「이름」 YYYY.MM"
//   · 예약한 상품의 도착 달 · 도착 날 (기기에 적은 예약, 규칙 '예약 도착')
//   · 내 채널 공식 라이브: 처음 보인 라이브 · 시작 30분 전 (규칙 '라이브 시작 전' — live_reminders.dart)
// 이 파일은 Flutter 위젯을 쓰지 않는다 (백그라운드 isolate · 단위 테스트).
import '../data/gunpula.dart' show correctedCode, lineLabel, pickName, unescapeHtml;
import '../l10n/l10n.dart';
import '../logic/lego_scope.dart';
import 'live_reminders.dart';
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
    this.restockDate = '',
    this.restockKind = '',
    this.restockQuiet = false,
    this.gradeCode = '',
    this.subline = '',
    this.nameJa = '',
    this.groups = const [],
    this.nameKo = '',
    this.nameZh = '',
    this.seriesKo = '',
    this.seriesZh = '',
  });

  final String kitId;

  /// added · changed
  final String changeType;
  final String franchise;

  /// 지금 화면 언어의 이름 (휴대폰 알림)
  final String name;

  /// 한국어 · 중국어 순서로 고른 이름 · 작품 — 알림함 줄은 보일 때 화면 언어로 고른다 ([NoticePart.value])
  final String nameKo;
  final String nameZh;
  final String seriesKo;
  final String seriesZh;
  final String seriesKey;
  final String seriesLabel;
  final String releaseDate;
  final int? priceJpy;
  final bool isLimited;
  final bool isPb;
  final List<String> watchTags;
  final List<String> interestTags;
  final List<String> reasons;

  /// 재판매 날짜 'YYYY-MM'(발송 달) · 'YYYY-MM-DD' — 피드 changed[] 의 restock: {date, kind, url, announced_at}.
  /// release_date 는 원래 발매일 그대로라 쓰지 않는다
  final String restockDate;

  /// pb_resale · retail_resale · tamashii_resale · lottery
  final String restockKind;

  /// restock.quiet — 지난 것 · 쌓인 것 (알리지 않는다)
  final bool restockQuiet;

  bool get isRestock => reasons.contains('restock') && !restockQuiet;

  /// Gunpula 등급 코드 (HG · NENDOROID …) — 알림 조건의 종류
  final String gradeCode;

  /// 피드의 subline · 일본어 이름 (2026-11-06 부터) — 앱의 종류(Kit.line)와 같은 계산에 쓴다
  final String subline;
  final String nameJa;

  /// 앱 상품의 종류 이름과 같은 값 (gunpula.dart correctedCode → lineLabel)
  String get line => lineLabel(correctedCode(gradeCode, nameJa), subline, kitId);

  /// 이 상품이 든 atlas 묶음 id (마도카 캐릭터 · Fate 작품 · 포켓몬 세대 …) — 알림 조건의 작품 · 캐릭터
  final List<String> groups;

  static FeedItem? fromJson(Object? json, String changeType) {
    final j = jMap(json);
    final id = jStr(j['kit_id']);
    if (id.isEmpty) return null;
    final restock = _restockOf(j);
    // 휴대폰 알림 제목 · 둘째 줄의 이름도 고른 화면 언어로 (Kit.name 과 같은 순서 — lib/data/gunpula.dart).
    // 이름에 남은 HTML 엔티티(Pok&eacute;mon)는 상품 목록처럼 푼다
    String named(List<String> order) {
      final n = unescapeHtml(pickName(j['names'], order));
      return n.isEmpty ? id : n;
    }

    final nameKo = named(const ['ko', 'ja', 'en', 'zh']);
    final nameZh = named(const ['zh', 'ja', 'en', 'ko']);
    final seriesKo = pickName(j['series_labels']);
    final seriesZh = jStr(jMap(j['series_labels'])['zh']);
    return FeedItem(
      kitId: id,
      changeType: jStr(j['change_type']).isEmpty ? changeType : jStr(j['change_type']),
      franchise: jStr(j['franchise']),
      name: L10n.isZh ? nameZh : nameKo,
      nameKo: nameKo,
      nameZh: nameZh,
      seriesKo: seriesKo,
      seriesZh: seriesZh,
      seriesKey: jStr(j['series_key']),
      seriesLabel: L10n.isZh && seriesZh.isNotEmpty ? seriesZh : trData(seriesKo),
      releaseDate: jStr(j['release_date']),
      priceJpy: j['price_jpy'] is num ? (j['price_jpy']! as num).toInt() : null,
      isLimited: j['is_limited'] == true,
      isPb: itemIsPremiumBandai(j),
      watchTags: jList(j['watch_tags']).whereType<String>().toList(),
      interestTags: jList(j['interest_tags']).whereType<String>().toList(),
      reasons: jList(j['change_reasons']).whereType<String>().toList(),
      restockDate: _ymd(jStr(restock['date']).isEmpty ? j['restock_date'] : restock['date']),
      restockKind: jStr(restock['kind']).isEmpty ? jStr(j['restock_kind']) : jStr(restock['kind']),
      restockQuiet: restock['quiet'] == true,
      gradeCode: jStr(j['grade_code']),
      subline: jStr(j['subline']),
      nameJa: jStr(j['name_ja']),
      groups: jList(j['groups']).whereType<String>().toList(),
    );
  }

  /// 피드의 restock: {date, kind} 하나 또는 목록 (첫 것)
  static Map<String, Object?> _restockOf(Map<String, Object?> j) {
    final r = j['restock'];
    return r is List ? jMap(r.firstOrNull) : jMap(r);
  }

  /// 알릴 만한 변화인가 — 새로 수록 · 가격 · 발매일 · 한정 · 판매처 (사진 · 이름 · 분류만 바뀐 것은 빼고)
  bool get meaningful => changeType == 'added' || reasons.any((r) => !quietReasons.contains(r));

  bool get isSeed00 =>
      franchise == 'gundam' &&
      (seriesKey == 'seed' || seriesKey == 'double_o' || (seriesKey.isEmpty && watchTags.isNotEmpty));

  bool get isBbx => franchise == 'beyblade' || interestTags.contains('bbx');
}

/// 알리지 않는 변화 이유 (Gunpula scripts/build_update_feed.mjs changeReasons)
/// release_found = 발매일이 처음 생긴 것 (나중에 상품 페이지에서 읽어 채운 날짜 — 바뀐 게 아니라 몰랐던 것)
/// archive = 출처가 웹 보관본(Wayback)으로만 바뀐 것 (원래 페이지가 사라졌을 뿐, 상품은 그대로)
const quietReasons = {'image', 'name', 'series', 'product_line', 'metadata', 'release_found', 'archive'};

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

/// 내가 만든 조건에 맞는가 — 채널 · 작품(캐릭터) · 종류, 빈 칸은 전부
bool conditionMatches(NotifyCondition x, FeedItem it) {
  if (x.franchise != it.franchise) return false;
  if (x.scope.startsWith('series:') && it.seriesKey != x.scope.substring(7)) return false;
  if (x.scope.startsWith('group:') && !it.groups.contains(x.scope.substring(6))) return false;
  if (x.line.isNotEmpty && it.line != x.line) {
    // 2026-11-06 전 피드엔 subline · 일본어 이름이 없어 figma 는 액션 피규어 라인 전체로 본다
    final oldFeed = it.subline.isEmpty && it.nameJa.isEmpty;
    if (!(oldFeed && x.line == 'figma' && it.gradeCode.endsWith('_ACTION'))) return false;
  }
  return true;
}

/// 레고 범위가 "최근 정식 세트"면 그 밖의 레고(굿즈 · 책 · 옛 세트)는 규칙 · 조건으로 알리지 않는다 (좋아요한 것은 알린다)
bool legoFeedInScope(FeedItem it) {
  // kit_id lego-75192-1 → 세트 번호 75192 (Gunpula import_lego_rebrickable.mjs: number = set_num 에서 "-1" 뺀 것)
  final number = it.kitId.replaceFirst('lego-', '').replaceFirst(RegExp(r'-1$'), '');
  return legoRecentSet({
    'date': it.releaseDate,
    'seriesKey': it.seriesKey,
    'gradeCode': it.gradeCode,
    'number': number,
  });
}

/// 이 상품이 걸린 규칙 (좋아요 제외). 내 채널 소식만이면 내 채널 밖은 내가 만든 조건만.
Set<String> ruleHits(FeedItem it, NotifyConfig c) {
  if (it.franchise == 'lego' && !c.legoAll && !legoFeedInScope(it)) return const {};
  final mine = {
    for (final x in c.conditions)
      if (conditionMatches(x, it)) 'cond:${x.id}',
  };
  if (c.onlyMine && !c.channels.contains(it.franchise)) return mine;
  return {
    ...mine,
    if (c.rule('premium_bandai') && it.isPb) 'premium_bandai',
    if (c.rule('seed_00') && it.isSeed00) 'seed_00',
    if (c.rule('bbx') && it.isBbx) 'bbx',
    if (notifyWorldRules.contains(it.franchise) && c.rule(it.franchise)) it.franchise,
  };
}

/// 좋아요한 상품인가 (채널과 상관없이)
bool wantedHit(FeedItem it, NotifyConfig c) => c.rule('wanted') && c.wanted.contains(it.kitId);

/// 좋아요 · 구매함 상품의 재판매인가 (규칙 '재판매', 채널과 상관없이)
bool restockHit(FeedItem it, NotifyConfig c) =>
    it.isRestock && c.rule('restock') && (c.wanted.contains(it.kitId) || c.owned.contains(it.kitId));

/// 재판매 종류 → 글자 (lib/logic/restock.dart restockKindLabels 와 같음 — 이 파일은 백그라운드에서도 돈다). 쓸 때 tr
const _restockKinds = {'pb_resale': 'PB 재판매', 'retail_resale': '일반 재판매', 'tamashii_resale': '혼 재판매', 'lottery': '추첨'};

/// 짧은 종류 (변경 이유 글자 "재판매 2027.01 · PB")
const _restockShort = {'pb_resale': 'PB', 'retail_resale': '일반', 'tamashii_resale': '혼', 'lottery': '추첨'};

/// 피드 한 줄 → 알림함 한 줄 (규칙에 안 걸리면 null)
NoticeRecord? recordForItem(FeedItem it, FeedEntry e, NotifyConfig c, {bool seen = false}) {
  if (!it.meaningful) return null;
  if (restockHit(it, c)) {
    final owned = c.owned.contains(it.kitId);
    final parts = [
      const NoticePart.key('재판매'),
      if (it.restockDate.isNotEmpty) NoticePart.value(_ymDot(it.restockDate)),
      NoticePart.key(owned ? '구매함 상품' : '좋아요한 상품'),
      if (_restockKinds[it.restockKind] case final k?) NoticePart.key(k),
    ];
    return NoticeRecord(
      id: 'feed-${e.date}-${it.kitId}',
      kind: 'restock',
      kitId: it.kitId,
      title: it.name,
      body: _shown(parts),
      titlePart: _titleOf(it),
      bodyParts: parts,
      at: e.generatedAt ?? DateTime.parse('${e.date}T00:00:00Z'),
      franchise: it.franchise,
      // 재판매 날짜 (휴대폰 알림 제목의 YYYY.MM) — 모르면 피드 날짜
      date: it.restockDate.isEmpty ? e.date : it.restockDate,
      reasons: it.reasons,
      pb: it.isPb,
      wanted: true, // 채널과 상관없이 보인다
      seen: seen,
    );
  }
  final wanted = wantedHit(it, c);
  final hits = ruleHits(it, c);
  if (!wanted && hits.isEmpty) return null;
  final parts = itemBodyParts(it, wanted: wanted);
  return NoticeRecord(
    id: 'feed-${e.date}-${it.kitId}',
    kind: it.changeType,
    kitId: it.kitId,
    title: it.name,
    body: _shown(parts),
    titlePart: _titleOf(it),
    bodyParts: parts,
    at: e.generatedAt ?? DateTime.parse('${e.date}T00:00:00Z'),
    franchise: it.franchise,
    date: e.date,
    reasons: it.reasons,
    pb: it.isPb,
    wanted: wanted,
    watched: hits.contains('seed_00'), // SEED / 00 규칙을 켜서 걸린 것만
    seen: seen,
  );
}

/// 알림 둘째 줄: "좋아요한 상품 · 가격 변경 ¥5,940 · 프리미엄 반다이 · SEED"
String itemBody(FeedItem it, {bool wanted = false}) => _shown(itemBodyParts(it, wanted: wanted));

/// [itemBody] 의 조각 — 알림함에는 이것을 두고 보일 때 화면 언어로 만든다
List<NoticePart> itemBodyParts(FeedItem it, {bool wanted = false}) => [
  if (wanted) const NoticePart.key('좋아요한 상품'),
  if (it.changeType == 'added')
    const NoticePart.key('새로 수록')
  else
    for (final r in it.reasons)
      if (!quietReasons.contains(r)) ..._reasonParts(r, it),
  if (it.isPb) const NoticePart.key('프리미엄 반다이'),
  if (it.seriesLabel.isNotEmpty && it.franchise != 'pokemon')
    it.seriesKo.isEmpty && it.seriesZh.isEmpty
        ? NoticePart.value(it.seriesLabel)
        : NoticePart.value(it.seriesKo, it.seriesZh),
  if (it.changeType == 'added' && it.releaseDate.isNotEmpty) NoticePart.key('{date} 발매', {'date': it.releaseDate}),
];

List<NoticePart> _reasonParts(String r, FeedItem it) => switch (r) {
  'price' => [
    it.priceJpy == null
        ? const NoticePart.key('가격 변경')
        : NoticePart.key('가격 변경 {price}', {'price': '¥${_comma(it.priceJpy!)}'}),
  ],
  'release' => [
    it.releaseDate.isEmpty ? const NoticePart.key('발매일 변경') : NoticePart.key('발매일 {date}', {'date': it.releaseDate}),
  ],
  'limited' => [NoticePart.key(it.isLimited ? '한정 표시' : '한정 해제')],
  'source' => const [NoticePart.key('판매처 · 출처 변경')],
  'restock' => [
    it.restockDate.isEmpty
        ? const NoticePart.key('재판매')
        : NoticePart.key('재판매 {date}', {'date': _ymDot(it.restockDate)}),
    if (_restockShort[it.restockKind] case final k?) NoticePart.key(k),
  ],
  _ => const [NoticePart.key('정보 변경')],
};

/// 조각 → 지금 화면 언어의 글 (휴대폰 알림 · 옛 앱이 읽는 body 칸)
String _shown(List<NoticePart> parts, [String sep = ' · ']) => parts.map((p) => p.shown).join(sep);

/// 상품 이름 조각 — 피드에서 읽은 줄은 한국어 · 중국어 이름이 다 있다 (직접 만든 FeedItem 은 [FeedItem.name] 하나)
NoticePart _titleOf(FeedItem it) =>
    it.nameKo.isEmpty && it.nameZh.isEmpty ? NoticePart.value(it.name) : NoticePart.value(it.nameKo, it.nameZh);

/// PB 예약 기간 알림에 붙는 말 (Wayback 에서 읽은 날짜라)
String get pbStaleNote => tr('Wayback 기록이라 바뀌었을 수 있어요');

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
        final when = d == 1
            ? NoticePart.key('내일 예약 시작 ({date})', {'date': _md(w.opens)})
            : (d == 0 ? const NoticePart.key('오늘 예약 시작') : NoticePart.key('예약 중 ({date} 시작)', {'date': _md(w.opens)}));
        out.add(_pbRecord(id, 'pb_open', w, w.opens, when, now));
      }
    }
    if (cl != null) {
      final d = cl.difference(today).inDays;
      final id = 'pb-close-${w.id}-${w.closes}';
      if (d >= 0 && d <= 3 && !known.contains(id)) {
        final when = d == 0
            ? const NoticePart.key('오늘 예약 마감')
            : NoticePart.key('예약 마감 D-{n} ({date})', {'n': d, 'date': _md(w.closes)});
        out.add(_pbRecord(id, 'pb_close', w, w.closes, when, now));
      }
    }
  }
  return out;
}

NoticeRecord _pbRecord(String id, String kind, PbWindow w, String date, NoticePart when, DateTime now) {
  final parts = [when, const NoticePart.key('Wayback 기록이라 바뀌었을 수 있어요')];
  return NoticeRecord(
    id: id,
    kind: kind,
    kitId: w.id,
    title: w.name,
    body: _shown(parts),
    bodyParts: parts,
    at: now.toUtc(),
    franchise: w.franchise,
    date: date,
    pb: true,
    wanted: true,
  );
}

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
      0 => ('d0', const NoticePart.key('오늘 발매')),
      1 => ('d1', NoticePart.key('내일 발매 ({date})', {'date': _md(r.date)})),
      >= 2 && <= 7 => ('d7', NoticePart.key('D-{n} · {date} 발매', {'n': d, 'date': _md(r.date)})),
      _ => ('', const NoticePart.value('')),
    };
    if (stage.isEmpty) continue;
    final id = 'rel-${r.id}-${r.date}-$stage';
    if (known.contains(id)) continue;
    final parts = [const NoticePart.key('좋아요한 상품'), body];
    out.add(
      NoticeRecord(
        id: id,
        kind: 'release',
        kitId: r.id,
        title: r.name,
        body: _shown(parts),
        bodyParts: parts,
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

/// 예약한 상품의 도착: 도착 달이 되면 한 번(month) · 하루까지 정한 예약은 그날 한 번 더(d0). 이미 알린 것([known])은 빼고.
List<NoticeRecord> preorderRecords(NotifyConfig c, Set<String> known, DateTime now) {
  if (!c.rule('preorder_arrival')) return const [];
  final today = DateTime.utc(now.year, now.month, now.day).toIso8601String().substring(0, 10);
  final ym = today.substring(0, 7);
  final out = <NoticeRecord>[];
  for (final p in c.preorders) {
    if (!p.arrival.startsWith(ym)) continue;
    final exact = p.arrival.length == 10;
    final money = p.due > 0 ? NoticePart.key('낼 돈 {n}원', {'n': _comma(p.due)}) : const NoticePart.key('결제 완료');
    for (final (stage, label) in [
      ('month', exact ? NoticePart.key('{date} 도착 예정', {'date': _md(p.arrival)}) : const NoticePart.key('이번 달 도착 예정')),
      if (exact && p.arrival == today) ('d0', const NoticePart.key('오늘 도착 예정')),
    ]) {
      final id = 'pre-${p.id}-${p.arrival}-$stage';
      if (known.contains(id)) continue;
      final parts = [const NoticePart.key('예약'), label, if (p.shop.isNotEmpty) NoticePart.value(p.shop), money];
      out.add(
        NoticeRecord(
          id: id,
          kind: 'preorder',
          kitId: p.id,
          title: p.name,
          body: _shown(parts),
          bodyParts: parts,
          at: now.toUtc(),
          franchise: p.franchise,
          date: p.arrival,
          wanted: true,
        ),
      );
    }
  }
  return out;
}

// ── 알림 받는 공식 예고 ──────────────────────────────────────────────────────
/// announcements.json status → 화면 글자 (순서 = 단계 순서). 한국어 값은 비교에도 쓴다(annStageKey) — 보일 때 tr
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
            body: _shown(_annParts(e.value.stage, stage), ' → '),
            bodyParts: _annParts(e.value.stage, stage),
            bodySep: ' → ',
            at: now,
            franchise: e.value.franchise,
            reasons: [stage],
            wanted: true, // 채널과 상관없이 보인다
          ),
  ];
}

/// 예고 단계 줄의 둘째 줄: "공식 발표 → 예약 시작"
List<NoticePart> _annParts(String from, String to) => [
  NoticePart.key(annStageLabels[from] ?? '공식 발표'),
  NoticePart.key(annStageLabels[to] ?? to),
];

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
    this.liveKey = '',
    this.liveStreams = const [],
    this.reminders = const LiveReminderPlan(),
  }) : liveScheduled = {...reminders.scheduled};

  /// 라이브: 읽은 예고 파일의 지문 · 그때의 라이브 (NotifyState.liveKey · liveStreams)
  final String liveKey;
  final List<LiveStream> liveStreams;

  /// 시작 전 알림 — 걸 것 · 거둘 것 (확인하는 쪽이 LocalNotifier.applyLive 로 한다)
  final LiveReminderPlan reminders;

  /// 걸려 있는 것으로 적을 표 — 걸지 못한 것은 확인하는 쪽이 빼서 다음 확인에서 다시 걸게 한다
  final Map<String, String> liveScheduled;

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
      liveKey: liveKey,
      liveStreams: liveStreams,
      liveScheduled: liveScheduled,
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
/// [streams] = 이번에 예고 파일에서 읽은 라이브 (안 읽었으면 null → 지난번 것으로 계획만 다시), [liveKey] = 그 파일의 지문
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
  List<LiveStream>? streams,
  String? liveKey,
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
  records.addAll(preorderRecords(config, known, now));
  records.addAll(annStageRecords(config, announcements, known, now));
  // 라이브: 지난번에 본 것은 알림함 줄이 지워졌어도 다시 넣지 않는다. 처음 읽는 날은 조용히
  final live = streams ?? state.liveStreams;
  records.addAll(
    liveRecords(
      config,
      live,
      {...known, for (final s in state.liveStreams) 'stream-${s.id}'},
      now,
      quiet: state.liveKey.isEmpty,
    ),
  );
  return CheckPlan(
    records: records,
    lastSeen: lastSeen,
    lastManifest: manifestSig.isEmpty ? state.lastManifest : manifestSig,
    checkedAt: now,
    seenFeed: seenFeed,
    error: error,
    source: source,
    pending: pending,
    liveKey: liveKey ?? state.liveKey,
    liveStreams: live,
    reminders: planLiveReminders(
      streams: live,
      scheduled: state.liveScheduled,
      channels: config.channels,
      enabled: config.enabled && config.rule(liveRule), // 휴대폰 알림이라 새 소식 알림 스위치도 본다
      now: now,
      lang: L10n.current.name,
    ),
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

  /// 같은 id 면 앞의 알림을 바꿔 쓴다 — 상품마다 · 요약마다 다른 id 라 앞 알림을 지우지 않는다
  final int id;

  /// catalog · wanted · pb · restock · preorder · ann · live
  final String channel;
  final String title;
  final String body;

  /// `kit:<kit_id>` → 상품 상세 / `ann:<franchise>:<예고 id>` → 예고 / `inbox` → 알림 화면
  final String payload;
}

/// 새 상품 · 변경을 하나씩 보내는 최대 개수 (넘으면 요약 하나)
const catalogAlertsEach = 5;

/// 요약 알림 제목: 「새 상품 6개 · 변경 2개」 (없는 쪽은 뺀다)
String catalogSummaryTitle({required int added, required int changed}) => [
  if (added > 0) trf('새 상품 {n}개', {'n': added}),
  if (changed > 0) trf('변경 {n}개', {'n': changed}),
].join(' · ');

/// 새로 들어온 줄 → 휴대폰 알림. 새 상품은 5개까지 하나씩(넘으면 요약), 좋아요 · PB 는 3개까지 하나씩(넘으면 요약).
List<SystemAlert> buildAlerts(Iterable<NoticeRecord> fresh) {
  final live = [
    for (final r in fresh)
      if (!r.seen) r,
  ];
  final out = <SystemAlert>[];
  final cat = live.where((r) => r.channel == 'catalog').toList();
  if (cat.isNotEmpty && cat.length <= catalogAlertsEach) {
    for (final r in cat) {
      out.add(
        SystemAlert(
          id: stableId('catalog:${r.id}'),
          channel: 'catalog',
          title: r.kind == 'added' ? trf('새 상품 · {name}', {'name': r.title}) : r.title,
          body: r.body,
          payload: 'kit:${r.kitId}',
        ),
      );
    }
  } else if (cat.isNotEmpty) {
    // 제목 = 무엇이 몇 개인지 (옛 건담 앱의 「SEED / 00 업데이트 · 모델 DB 업데이트」는 섞인 묶음과 맞지 않았다)
    final dates = {for (final r in cat) r.date}.toList()..sort();
    final added = cat.where((r) => r.kind == 'added').length;
    final changed = cat.length - added;
    final title = catalogSummaryTitle(added: added, changed: changed);
    final when = dates.length == 1 ? _md(dates.first) : '${_md(dates.first)}–${_md(dates.last)}';
    out.add(
      SystemAlert(
        // 요약마다 다른 id (같은 id 면 아직 안 본 앞 요약을 덮어써 버린다)
        id: stableId('catalog:${cat.first.id}:${cat.length}'),
        channel: 'catalog',
        title: title,
        body: '$when · ${_names(cat)}',
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
        title: trf('좋아요한 상품 {n}개가 바뀌었어요', {'n': wanted.length}),
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
        title: trf('좋아요한 PB 상품 {n}개 예약 소식', {'n': pb.length}),
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
          title: r.kind == 'pb_open'
              ? trf('PB 예약 시작 · {name}', {'name': r.title})
              : trf('PB 예약 마감 임박 · {name}', {'name': r.title}),
          body: r.body,
          payload: 'kit:${r.kitId}',
        ),
      );
    }
  }
  final restock = live.where((r) => r.channel == 'restock').toList();
  if (restock.length > 3) {
    out.add(
      SystemAlert(
        id: stableId('restock'),
        channel: 'restock',
        title: trf('재판매 소식 {n}개', {'n': restock.length}),
        body: _names(restock),
        payload: 'inbox',
      ),
    );
  } else {
    for (final r in restock) {
      out.add(
        SystemAlert(
          id: stableId(r.id),
          channel: 'restock',
          title: restockTitle(r),
          body: r.body,
          payload: 'kit:${r.kitId}',
        ),
      );
    }
  }
  for (final r in live.where((r) => r.channel == 'preorder')) {
    out.add(
      SystemAlert(
        id: stableId(r.id),
        channel: 'preorder',
        title: trf('예약 도착 · 「{name}」', {'name': r.title}),
        body: r.body,
        payload: 'kit:${r.kitId}',
      ),
    );
  }
  final ann = live.where((r) => r.channel == 'ann').toList();
  if (ann.length > 3) {
    out.add(
      SystemAlert(
        id: stableId('ann'),
        channel: 'ann',
        title: trf('알림 받는 공식 예고 {n}개가 다음 단계로', {'n': ann.length}),
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
          title: '${tr(annStageLabels[r.reasons.firstOrNull] ?? '다음 단계')} · ${r.title}',
          body: r.body,
          payload: 'ann:${r.franchise}:${r.annId}',
        ),
      );
    }
  }
  // 처음 보인 라이브: 제목 = 때 ("라이브 예정 · 11.14 21:00"), 둘째 줄 = 방송 이름. 누르면 그 예고
  for (final r in live.where((r) => r.channel == 'live')) {
    out.add(
      SystemAlert(
        id: stableId(r.id),
        channel: 'live',
        title: r.bodyParts.firstOrNull?.shown ?? r.body,
        body: r.title,
        payload: 'ann:${r.franchise}:${r.annId}',
      ),
    );
  }
  return out;
}

/// 재판매 휴대폰 알림 제목: "재판매 · 「이름」 2027.03"
String restockTitle(NoticeRecord r) {
  final ym = RegExp(r'^\d{4}-\d{2}').hasMatch(r.date) ? ' ${_ymDot(r.date)}' : '';
  return trf('재판매 · 「{name}」{ym}', {'name': r.title, 'ym': ym});
}

/// '2027-03-15' · '2027-03' → '2027.03'
String _ymDot(String d) => d.length >= 7 ? d.substring(0, 7).replaceAll('-', '.') : d;

/// 'YYYY-MM' · 'YYYY-MM-DD' 만 (그 밖은 빈 글자)
String _ymd(Object? v) => RegExp(r'^\d{4}-\d{2}(-\d{2})?').firstMatch(jStr(v))?.group(0) ?? '';

/// 「A」 · 「B」 외 3
String _names(List<NoticeRecord> rs) {
  final head = rs.take(2).map((r) => '「${r.title}」').join(' · ');
  return rs.length > 2 ? trf('{names} 외 {n}', {'names': head, 'n': rs.length - 2}) : head;
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
