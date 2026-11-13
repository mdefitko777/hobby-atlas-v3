// 데이터 레코드 → Dart 객체. 모양이 맞지 않는 레코드는 null로 버린다(화면이 죽지 않게).
// 레코드 종류: kits · worlds · guideWorks · guideUnits · bbxTops · bbxParts · announcements · profile
import 'json_util.dart';
import 'l10n/l10n.dart';

enum CollectStatus { owned, wanted, none }

CollectStatus parseCollectStatus(Object? v) => switch (v) {
  'owned' => CollectStatus.owned,
  'wanted' => CollectStatus.wanted,
  _ => CollectStatus.none,
};

int _i(Map<String, Object?> j, String k) => j[k] is num ? (j[k]! as num).toInt() : 0;
int? _iOrNull(Map<String, Object?> j, String k) => j[k] is num ? (j[k]! as num).toInt() : null;
bool _b(Map<String, Object?> j, String k) => j[k] == true;
List<String> _strs(Object? v) => v is List ? v.whereType<String>().toList() : const [];

/// 시장가 예시 (원화, 미리 적어 둔 값)
class Market {
  const Market({required this.normalKrw, required this.conservativeKrw, required this.samples});
  final int normalKrw;
  final int conservativeKrw;
  final int samples;

  static Market? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    return Market(
      normalKrw: _i(json, 'normalKrw'),
      conservativeKrw: _i(json, 'conservativeKrw'),
      samples: _i(json, 'samples'),
    );
  }
}

/// 상품(키트·피규어·굿즈)
class Kit {
  const Kit({
    required this.id,
    required this.franchiseId,
    required String name,
    required this.nameJa,
    required this.series,
    required this.line,
    required this.type,
    required this.scale,
    required this.universe,
    required this.date,
    required this.priceJpy,
    required this.image,
    required this.gallery,
    required this.limited,
    required this.pb,
    required this.status,
    required this.wantedQty,
    required this.recent,
    required this.month,
    required this.market,
    required this.keywords,
    this.purchaseKrw,
    this.seriesKey = '',
    this.priceKrw,
    this.pbOpens = '',
    this.pbCloses = '',
    this.officialUrl = '',
    this.jan = '',
    this.brands = const [],
    this.firstSeen = '',
    this.blob = '',
    this.goodsKind = '',
    this.sourceUrls = const [],
    this.imageRef = false,
    this.subline = '',
    this.manualId = 0,
    this.nameZh = '',
    this.seriesZh = '',
    this.zhKeywordsFrom = -1,
  }) : nameKo = name;

  final String id;
  final String franchiseId;

  /// 한국어 이름 (Gunpula names.ko …). 화면에는 [name] — 중국어 화면이면 [nameZh] 가 있을 때 그것
  final String nameKo;

  /// 중국어(간체) 이름 (Gunpula names.zh — data/i18n/names-zh.json · 용어집 번역). 없으면 빈 글자
  final String nameZh;

  /// 화면에 보이는 이름 — 고른 언어(lib/l10n/l10n.dart)를 따른다
  String get name => L10n.isZh && nameZh.isNotEmpty ? nameZh : nameKo;

  /// 작품(시리즈) 이름의 중국어판 (Gunpula series.labels.zh). [series] 는 한국어 그대로 — 묶기 · 비교에 쓰인다,
  /// 화면에는 [seriesLabel] — zh 가 없으면 번역 표('포켓몬' · '한정' 같은 이름표)를 거친다
  final String seriesZh;
  String get seriesLabel => L10n.isZh && seriesZh.isNotEmpty ? seriesZh : trData(series);
  final String nameJa;
  final String series;
  final String line;
  final String type;
  final String scale;
  final String universe;

  /// 'yyyy-mm' 또는 'yyyy-mm-dd'
  final String date;
  final int? priceJpy;
  final String image;
  final List<String> gallery;
  final bool limited;

  /// 프리미엄 반다이 한정
  final bool pb;
  final CollectStatus status;
  final int wantedQty;

  /// 최근 3일 신규 수록
  final bool recent;

  /// 이번 달 발매
  final bool month;
  final Market? market;
  final List<String> keywords;

  /// [keywords] 중 이 자리부터는 중국어 (names.zh · labels.zh · search_zh). -1 = 나누지 않음 (가짜 상품 · 옛 캐시).
  /// 설명으로 찾기가 중국어 이름의 일부(水伊布 · 正义女神)를 한국어 · 일본어 낱말로 잘못 맞추지 않게 따로 본다
  final int zhKeywordsFrom;

  /// 구매함일 때 내가 실제로 낸 돈(원). 없으면 null
  final int? purchaseKrw;

  // ── Gunpula 실제 데이터에만 있는 값 ──
  final String seriesKey;

  /// 한국 포켓몬스토어 상품의 원화 가격
  final int? priceKrw;

  /// 프리미엄 반다이 예약 기간 (Wayback 사본이라 오래됐을 수 있음)
  final String pbOpens;
  final String pbCloses;

  /// 공식 상품 페이지 (source_urls 첫 번째)
  final String officialUrl;

  /// 바코드 13자리 (kit_id · 주소 · 품번에서 찾은 것, 약 40%만 있음)
  final String jan;

  /// 출처 사이트로 추정한 브랜드
  final List<String> brands;

  /// Gunpula 에 처음 들어온 날 (kit-first-seen.json)
  final String firstSeen;

  /// 검색용 소문자 한 줄 (이름 4개 언어 · 작품 · 라인 · JAN …)
  final String blob;

  /// 굿즈 세부 종류 (티켓 · 의류 · 블루레이 …, 한국어). 굿즈가 아니면 빈 글자
  final String goodsKind;

  /// 출처 페이지 전부 (source_urls — 공유로 받은 주소 찾기, lib/logic/url_lookup.dart).
  /// 이 칸이 생기기 전 기기 캐시에는 없다 → 다음 새 데이터 때 채워진다 (그동안은 [officialUrl] 만)
  final List<String> sourceUrls;

  /// [image] 가 이 상품 사진이 아니라 같은 기체의 다른 상품 사진 (lib/data/gunpula.dart fillReferenceImages)
  final bool imageRef;

  /// 라인 안의 세부 시리즈 (HGUC · HGCE · HGBF · ROBOT魂 ver. A.N.I.M.E. …). 라인과 같거나 모르면 빈 글자
  final String subline;

  /// 공식 조립 설명서 (manual.bandai-hobby.net 의 번호, 0 = 없음 — Gunpula import_bandai_manuals.mjs 가 이름으로 이은 것)
  final int manualId;

  /// lib/data/gunpula.dart mapKitsJob 의 결과 → Kit.
  /// [recentSince] 이후에 처음 들어온 상품 = 최근 추가, [monthPrefix]('yyyy-mm')에 발매 = 이번 달
  static Kit fromSlim(Map<String, Object?> j, {required String recentSince, required String monthPrefix}) {
    final firstSeen = jStr(j['firstSeen']);
    final date = jStr(j['date']);
    return Kit(
      id: jStr(j['id']),
      franchiseId: jStr(j['franchiseId']),
      name: jStr(j['name']),
      nameZh: jStr(j['nameZh']),
      nameJa: jStr(j['nameJa']),
      series: jStr(j['series']),
      seriesZh: jStr(j['seriesZh']),
      line: jStr(j['line']),
      type: jStr(j['type']),
      scale: jStr(j['scale']),
      universe: jStr(j['universe']),
      date: date,
      priceJpy: _iOrNull(j, 'priceJpy'),
      image: jStr(j['image']),
      gallery: _strs(j['gallery']),
      limited: _b(j, 'limited'),
      pb: _b(j, 'pb'),
      status: CollectStatus.none, // 내 기록은 UserStore 에서 (lib/marks.dart)
      wantedQty: 0,
      recent: firstSeen.isNotEmpty && recentSince.isNotEmpty && firstSeen.compareTo(recentSince) >= 0,
      month: date.startsWith(monthPrefix),
      market: null,
      keywords: _strs(j['keywords']),
      zhKeywordsFrom: _iOrNull(j, 'zhKeywordsFrom') ?? -1,
      seriesKey: jStr(j['seriesKey']),
      priceKrw: _iOrNull(j, 'priceKrw'),
      pbOpens: jStr(j['pbOpens']),
      pbCloses: jStr(j['pbCloses']),
      officialUrl: jStr(j['officialUrl']),
      jan: jStr(j['jan']),
      brands: _strs(j['brands']),
      firstSeen: firstSeen,
      blob: jStr(j['blob']),
      goodsKind: jStr(j['goodsKind']),
      sourceUrls: _strs(j['sourceUrls']),
      imageRef: _b(j, 'imageRef'),
      subline: jStr(j['subline']),
      manualId: _iOrNull(j, 'manualId') ?? 0,
    );
  }

  static Kit? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final id = json['id'];
    if (id is! String) return null;
    return Kit(
      id: id,
      franchiseId: jStr(json['franchiseId']),
      name: jStr(json['name']),
      nameJa: jStr(json['nameJa']),
      series: jStr(json['series']),
      line: jStr(json['line']),
      type: jStr(json['type']),
      scale: jStr(json['scale']),
      universe: jStr(json['universe']),
      date: jStr(json['date']),
      priceJpy: _iOrNull(json, 'priceJpy'),
      image: jStr(json['image']),
      gallery: _strs(json['gallery']),
      limited: _b(json, 'limited'),
      pb: _b(json, 'pb'),
      status: parseCollectStatus(json['status']),
      wantedQty: _i(json, 'wantedQty'),
      recent: _b(json, 'recent'),
      month: _b(json, 'month'),
      market: Market.fromJson(json['market']),
      keywords: _strs(json['keywords']),
      purchaseKrw: _iOrNull(json, 'purchaseKrw'),
    );
  }
}

/// 세계관 묶음 (건담 우주세기 · 포켓몬 세대 · Fate 작품 · AC 세대 · BBX 라인)
class World {
  const World({
    required this.id,
    required this.franchiseId,
    required this.label,
    required this.subtitle,
    required this.image,
    required this.total,
    required this.owned,
    this.kitIds = const [],
  });

  final String id;
  final String franchiseId;
  final String label;
  final String subtitle;
  final String image;
  final int total;
  final int owned;

  /// 이 묶음의 상품 (도감 카드 → 상품 목록)
  final List<String> kitIds;

  static World? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final id = json['id'];
    if (id is! String) return null;
    return World(
      id: id,
      franchiseId: jStr(json['franchiseId']),
      label: jStr(json['label']),
      subtitle: jStr(json['subtitle']),
      image: jStr(json['image']),
      total: _i(json, 'total'),
      owned: _i(json, 'owned'),
      kitIds: _strs(json['kitIds']),
    );
  }
}

/// 도감의 작품 (건담)
class GuideWork {
  const GuideWork({
    required this.id,
    required this.section,
    required this.name,
    required this.image,
    required this.total,
    required this.owned,
    this.keywords = '',
    this.liked = 0,
    this.grades = const [],
    this.types = const [],
    this.kits = 0,
    this.boughtAt = '',
    this.imageSource = '',
  });

  final String id;

  /// 시대 묶음 이름 (우주세기 · 코즈믹 에라 …)
  final String section;
  final String name;
  final String image;
  final int total;
  final int owned;

  /// 찾기용: 이 작품 기체들의 이름 · 형식번호 (소문자) — 기체 이름으로도 작품을 찾는다
  final String keywords;

  // 도감 필터 재료
  /// 좋아요 단계 기체 수
  final int liked;

  /// 기체들의 상품 등급 · 라인 (HG · MG · ROBOT魂 …)
  final List<String> grades;

  /// 기체 종류 (MS · MA · 전함 …)
  final List<String> types;

  /// 칸을 켜는 상품 수
  final int kits;

  /// 마지막으로 구매함에 넣은 때 (updated_at, 없으면 '')
  final String boughtAt;

  /// [image] 출처 (공식 작품 로고)
  final String imageSource;

  static GuideWork? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final id = json['id'];
    if (id is! String) return null;
    return GuideWork(
      id: id,
      section: jStr(json['section']),
      name: jStr(json['name']),
      image: jStr(json['image']),
      total: _i(json, 'total'),
      owned: _i(json, 'owned'),
      keywords: jStr(json['keywords']),
      liked: _i(json, 'liked'),
      grades: _strs(json['grades']),
      kits: _i(json, 'kits'),
    );
  }
}

/// 건담 도감 찾아보기 표 — 도감 탭 검색의 작품 · 기체 줄, 결과를 기체별로 묶기, 상품 상세의 "도감에서 보기"
class GuideIndex {
  const GuideIndex({this.works = const [], this.units = const {}, this.unitsByKit = const {}});
  static const empty = GuideIndex();

  final List<GuideWork> works;

  /// 기체 id → 칸 ([GuideUnit.workId] = 처음 나온 작품, 없으면 첫 작품)
  final Map<String, GuideUnit> units;

  /// 상품 → 연결된 기체 (역할 main 먼저 — 부품 · SD 도 들어간다)
  final Map<String, List<String>> unitsByKit;

  GuideWork? work(String id) => works.where((w) => w.id == id).firstOrNull;

  /// 이 상품의 대표 기체 (없으면 null)
  GuideUnit? unitOf(String kitId) => switch (unitsByKit[kitId]) {
    final ids? when ids.isNotEmpty => units[ids.first],
    _ => null,
  };
}

/// 도감의 기체 칸 — 구매함이면 "점등" (칸 그림은 늘 컬러, 리본 표시)
class GuideUnit {
  const GuideUnit({
    required this.id,
    required this.workId,
    required this.name,
    required this.nameEn,
    required this.image,
    required this.status,
    required this.kitIds,
    this.kitRoles = const {},
    this.ggetIds = const [],
    this.type = '',
    this.keywords = '',
  });

  /// 기체 id — Atlas MS id (예: "RX-78-2 Gundam")
  final String id;
  final String workId;
  final String name;

  /// 둘째 줄 (형식번호 · 영어 이름)
  final String nameEn;
  final String image;

  /// 상품 + 손으로 켜기로 정한 상태 (불러온 때 기준)
  final CollectStatus status;

  /// 연결된 상품 전부 (그 기체 → 세트 → 완성품 → 부품 · SD 순)
  final List<String> kitIds;

  /// kit_id → 연결 역할 (main · set_member · figure · accessory_for · sd_character). 없으면 main
  final Map<String, String> kitRoles;

  /// 옛 gget unit_id — 도감 손으로 켜기 기록의 키 (없으면 손으로 켤 수 없고 상품으로만 켜진다)
  final List<int> ggetIds;

  /// 기체 종류 (MS · MA · 전함 · 전투기 · 차량 · 기타, 모르면 '')
  final String type;

  /// 찾기용 (모든 언어 이름 · 형식번호, 소문자)
  final String keywords;

  String roleOf(String kitId) => kitRoles[kitId] ?? 'main';

  /// 구매하면 칸이 켜지는 상품 (부품 · SD 캐릭터 연결은 제외)
  List<String> get litKitIds => [
    for (final k in kitIds)
      if (roleOf(k) != 'accessory_for' && roleOf(k) != 'sd_character') k,
  ];

  static GuideUnit? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final id = json['id'];
    if (id is! String) return null;
    return GuideUnit(
      id: id,
      workId: jStr(json['workId']),
      name: jStr(json['name']),
      nameEn: jStr(json['nameEn']),
      image: jStr(json['image']),
      status: parseCollectStatus(json['status']),
      kitIds: _strs(json['kitIds']),
      type: jStr(json['type']),
    );
  }
}

/// 작품 안 묶음 — 화수 범위(장) 또는 한 화 (data/atlas/gundam-chapters.json)
class GuideChapter {
  const GuideChapter({required this.name, required this.episodes, required this.unitIds});

  final String name;

  /// "1–3화" · "12화" (없으면 '')
  final String episodes;

  /// 이 장에 나오는 기체 (도감 칸이 있는 것만)
  final List<String> unitIds;
}

/// 베이블레이드 부품 (블레이드 · 래칫 · 비트)
class BbxPart {
  const BbxPart({
    required this.id,
    required this.typeLabel,
    required this.name,
    required this.image,
    required this.have,
    required this.topId,
    required this.stats,
  });

  final String id;
  final String typeLabel;
  final String name;
  final String image;
  final bool have;
  final String topId;

  /// 공격 · 방어 · 지구력 … (부품 대화상자에서만 씀)
  final Map<String, int> stats;

  static BbxPart? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final id = json['id'];
    if (id is! String) return null;
    final raw = json['stats'];
    return BbxPart(
      id: id,
      typeLabel: jStr(json['typeLabel']),
      name: jStr(json['name']),
      image: jStr(json['image']),
      have: _b(json, 'have'),
      topId: jStr(json['topId']),
      stats: raw is Map<String, Object?>
          ? {
              for (final e in raw.entries)
                if (e.value is num) e.key: (e.value! as num).toInt(),
            }
          : const {},
    );
  }
}

/// 베이블레이드 (완성 베이 = 부품 3개)
class BbxTop {
  const BbxTop({
    required this.id,
    required this.line,
    required this.name,
    required this.image,
    required this.owned,
    required this.total,
    required this.parts,
    required this.kitIds,
  });

  final String id;
  final String line;
  final String name;
  final String image;
  final int owned;
  final int total;
  final List<BbxPart> parts;
  final List<String> kitIds;

  static BbxTop? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final id = json['id'];
    if (id is! String) return null;
    final parts = json['parts'];
    return BbxTop(
      id: id,
      line: jStr(json['line']),
      name: jStr(json['name']),
      image: jStr(json['image']),
      owned: _i(json, 'owned'),
      total: _i(json, 'total'),
      parts: parts is List ? parts.map(BbxPart.fromJson).nonNulls.toList() : const [],
      kitIds: _strs(json['kitIds']),
    );
  }
}

/// 예고 — 공식(반다이 방송·공지) + 비공식(취미 매체 · 팬 사이트, [unofficial])
class Announcement {
  const Announcement({
    required this.id,
    required this.franchiseId,
    required this.title,
    required this.status,
    required this.date,
    required this.source,
    required this.image,
    required this.hero,
    this.url = '',
    this.video = '',
    this.liveAt,
    this.liveState = '',
    this.unofficial = false,
    this.preorderAt,
    this.preorderDay = '',
    this.preorderEndAt,
    this.preorderEndDay = '',
    this.linkedKitId = '',
  });

  /// 원문 (뉴스 · 유튜브)
  final String url;

  /// 유튜브 영상 id (영상 예고만)
  final String video;

  final String id;
  final String franchiseId;
  final String title;
  final String status;
  final String date;
  final String source;
  final String image;

  /// 가로로 넓은 고화질 배너 — 홈 맨 위 큰 사진에 쓴다
  final bool hero;

  /// 라이브(방송) 예고만: 시작 시각 (기기 시간대, 시간 미정이면 null)
  final DateTime? liveAt;

  /// 라이브 예고만: 데이터의 live_state — upcoming · live · ended (하루 한 번 적힌 값. 지금 단계는 lib/logic/live_stream.dart)
  final String liveState;

  bool get isStream => liveState.isNotEmpty;

  /// 공식이 아닌 곳(취미 매체 · 팬 사이트)의 소식 — 데이터의 unofficial: true, [source] 가 그 사이트 이름.
  /// 화면마다 「비공식」 꼬리표로 공식 예고와 가른다 (lib/logic/announcement_match.dart annStageText)
  final bool unofficial;

  /// 예약이 열리는 시각 (데이터의 preorder_at, 기기 시간대). 출처가 시각을 준 것만 — 날짜만 알면 null 이고 [preorderDay]
  final DateTime? preorderAt;

  /// 예약이 열리는 날 (일본 날짜 'YYYY-MM-DD', 데이터의 preorder_date). 시각을 모르면 이것만 — 00:00 으로 치지 않는다
  final String preorderDay;

  /// 예약 마감 시각 · 마감일 (preorder_end_at · preorder_end_date, 드물다)
  final DateTime? preorderEndAt;
  final String preorderEndDay;

  /// 이 예고의 상품 (데이터의 linked_kit_id, 합쳐진 옛 id 는 남은 id 로). 없으면 빈 글자 → 제목 「」 으로만 찾는다
  final String linkedKitId;

  /// 홈 배너에 올릴 예고로 (줄을 세운 뒤에 정한다 — lib/data/derive/announcements.dart)
  Announcement asHero() => Announcement(
    id: id,
    franchiseId: franchiseId,
    title: title,
    status: status,
    date: date,
    source: source,
    image: image,
    hero: true,
    url: url,
    video: video,
    liveAt: liveAt,
    liveState: liveState,
    unofficial: unofficial,
    preorderAt: preorderAt,
    preorderDay: preorderDay,
    preorderEndAt: preorderEndAt,
    preorderEndDay: preorderEndDay,
    linkedKitId: linkedKitId,
  );

  static Announcement? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final id = json['id'];
    if (id is! String) return null;
    return Announcement(
      id: id,
      franchiseId: jStr(json['franchiseId']),
      title: jStr(json['title']),
      status: jStr(json['status']),
      date: jStr(json['date']),
      source: jStr(json['source']),
      image: jStr(json['image']),
      hero: _b(json, 'hero'),
      liveAt: DateTime.tryParse(jStr(json['liveAt']))?.toLocal(),
      liveState: jStr(json['liveState']),
      unofficial: _b(json, 'unofficial'),
      preorderAt: DateTime.tryParse(jStr(json['preorderAt']))?.toLocal(),
      preorderDay: jStr(json['preorderDay']),
      preorderEndAt: DateTime.tryParse(jStr(json['preorderEndAt']))?.toLocal(),
      preorderEndDay: jStr(json['preorderEndDay']),
      linkedKitId: jStr(json['linkedKitId']),
    );
  }
}

/// 내 정보 — 이름 · 아이디 · 친구는 계정에서, 숫자는 기기 기록에서 (lib/data/derive/profile.dart)
class Profile {
  const Profile({
    required this.name,
    required this.handle,
    required this.avatarText,
    required this.tags,
    required this.spendKrw,
    required this.workspace,
    required this.friends,
  });

  final String name;
  final String handle;
  final String avatarText;
  final List<String> tags;
  final int spendKrw;
  final String workspace;

  /// 친구 목록 (친구 서랍 · 친구 프로필)
  final List<Member> friends;

  static Profile? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final friends = json['friends'];
    return Profile(
      name: jStr(json['name']),
      handle: jStr(json['handle']),
      avatarText: jStr(json['avatarText']),
      tags: _strs(json['tags']),
      spendKrw: _i(json, 'spendKrw'),
      workspace: jStr(json['workspace']),
      friends: [
        if (friends is List)
          for (final m in friends.whereType<Map<String, Object?>>()) Member.fromJson(m),
      ],
    );
  }
}

/// 공유 공간 멤버 (친구). 숫자는 그 사람의 좋아요 · 도감 점등 · 구매함
class Member {
  const Member({
    required this.name,
    required this.handle,
    required this.role,
    required this.self,
    required this.liked,
    required this.lit,
    required this.owned,
    this.verified = 0,
    this.status = '',
    this.group = 'friend',
    this.likedIds = const [],
    this.ownedIds = const [],
    this.guide = const {},
  });

  factory Member.fromJson(Map<String, Object?> m) {
    final guide = m['guide'];
    return Member(
      name: jStr(m['name']),
      handle: jStr(m['handle']),
      role: jStr(m['role']),
      self: _b(m, 'self'),
      liked: _i(m, 'liked'),
      lit: _i(m, 'lit'),
      owned: _i(m, 'owned'),
      verified: _i(m, 'verified'),
      status: jStr(m['status']),
      group: m['group'] is String ? m['group']! as String : 'friend',
      likedIds: _strs(m['likedIds']),
      ownedIds: _strs(m['ownedIds']),
      guide: {
        if (guide is Map<String, Object?>)
          for (final e in guide.entries)
            if (e.value is int) e.key: e.value! as int,
      },
    );
  }

  final String name;
  final String handle;
  final String role;
  final bool self;
  final int liked;
  final int lit;
  final int owned;

  /// 내 사진 인증(배지) 수
  final int verified;

  /// 친구 목록 한 줄 상태 ("[최근] … 인증")
  final String status;

  /// 'special' = 특별 관심, 'friend' = 친구
  final String group;
  final List<String> likedIds;
  final List<String> ownedIds;

  /// 작품 id → 이 친구가 모은 칸 수
  final Map<String, int> guide;
}

/// 알림 종류 — 탭 묶음: 상품(발매 · 예약 · 시세) · 예고 · 친구(활동 · 요청)
enum NoticeType { release, reserve, price, announce, friend, request }

/// 알림 한 줄. 누르면 [kitId] → 상품 상세, [annId] → 공고, [friend] → 친구 프로필
class AppNotice {
  const AppNotice({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.image,
    required this.at,
    required this.read,
    this.franchiseId = '',
    this.kitId = '',
    this.annId = '',
    this.friend = '',
  });

  final String id;
  final NoticeType type;
  final String title;
  final String body;
  final String image;
  final DateTime at;
  final bool read;

  /// 비어 있으면 채널과 상관없는 알림(친구)
  final String franchiseId;
  final String kitId;
  final String annId;

  /// 친구 아이디
  final String friend;

  static AppNotice? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final id = json['id'];
    final at = DateTime.tryParse(jStr(json['at']));
    final type = NoticeType.values.where((t) => t.name == json['type']).firstOrNull;
    if (id is! String || at == null || type == null) return null;
    return AppNotice(
      id: id,
      type: type,
      title: jStr(json['title']),
      body: jStr(json['body']),
      image: jStr(json['image']),
      at: at,
      read: _b(json, 'read'),
      franchiseId: jStr(json['franchiseId']),
      kitId: jStr(json['kitId']),
      annId: jStr(json['annId']),
      friend: jStr(json['friend']),
    );
  }
}
