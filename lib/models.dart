// db.json 레코드 → Dart 객체. 모양이 맞지 않는 레코드는 null로 버린다(화면이 죽지 않게).
// db.json 최상위 키: kits · worlds · guideWorks · guideUnits · bbxTops · bbxParts · announcements · profile
enum CollectStatus { owned, wanted, none }

CollectStatus parseCollectStatus(Object? v) => switch (v) {
  'owned' => CollectStatus.owned,
  'wanted' => CollectStatus.wanted,
  _ => CollectStatus.none,
};

String _s(Map<String, Object?> j, String k) => j[k] is String ? j[k]! as String : '';
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
    required this.name,
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
  });

  final String id;
  final String franchiseId;
  final String name;
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

  /// lib/data/gunpula.dart mapKitsJob 의 결과 → Kit.
  /// [recentSince] 이후에 처음 들어온 상품 = 최근 추가, [monthPrefix]('yyyy-mm')에 발매 = 이번 달
  static Kit fromSlim(Map<String, Object?> j, {required String recentSince, required String monthPrefix}) {
    final firstSeen = _s(j, 'firstSeen');
    final date = _s(j, 'date');
    return Kit(
      id: _s(j, 'id'),
      franchiseId: _s(j, 'franchiseId'),
      name: _s(j, 'name'),
      nameJa: _s(j, 'nameJa'),
      series: _s(j, 'series'),
      line: _s(j, 'line'),
      type: _s(j, 'type'),
      scale: _s(j, 'scale'),
      universe: _s(j, 'universe'),
      date: date,
      priceJpy: _iOrNull(j, 'priceJpy'),
      image: _s(j, 'image'),
      gallery: _strs(j['gallery']),
      limited: _b(j, 'limited'),
      pb: _b(j, 'pb'),
      status: CollectStatus.none, // 내 기록은 UserStore 에서 (lib/marks.dart)
      wantedQty: 0,
      recent: firstSeen.isNotEmpty && recentSince.isNotEmpty && firstSeen.compareTo(recentSince) >= 0,
      month: date.startsWith(monthPrefix),
      market: null,
      keywords: _strs(j['keywords']),
      seriesKey: _s(j, 'seriesKey'),
      priceKrw: _iOrNull(j, 'priceKrw'),
      pbOpens: _s(j, 'pbOpens'),
      pbCloses: _s(j, 'pbCloses'),
      officialUrl: _s(j, 'officialUrl'),
      jan: _s(j, 'jan'),
      brands: _strs(j['brands']),
      firstSeen: firstSeen,
      blob: _s(j, 'blob'),
    );
  }

  static Kit? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final id = json['id'];
    if (id is! String) return null;
    return Kit(
      id: id,
      franchiseId: _s(json, 'franchiseId'),
      name: _s(json, 'name'),
      nameJa: _s(json, 'nameJa'),
      series: _s(json, 'series'),
      line: _s(json, 'line'),
      type: _s(json, 'type'),
      scale: _s(json, 'scale'),
      universe: _s(json, 'universe'),
      date: _s(json, 'date'),
      priceJpy: _iOrNull(json, 'priceJpy'),
      image: _s(json, 'image'),
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
  });

  final String id;
  final String franchiseId;
  final String label;
  final String subtitle;
  final String image;
  final int total;
  final int owned;

  static World? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final id = json['id'];
    if (id is! String) return null;
    return World(
      id: id,
      franchiseId: _s(json, 'franchiseId'),
      label: _s(json, 'label'),
      subtitle: _s(json, 'subtitle'),
      image: _s(json, 'image'),
      total: _i(json, 'total'),
      owned: _i(json, 'owned'),
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
  });

  final String id;
  final String section;
  final String name;
  final String image;
  final int total;
  final int owned;

  static GuideWork? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final id = json['id'];
    if (id is! String) return null;
    return GuideWork(
      id: id,
      section: _s(json, 'section'),
      name: _s(json, 'name'),
      image: _s(json, 'image'),
      total: _i(json, 'total'),
      owned: _i(json, 'owned'),
    );
  }
}

/// 도감의 기체 칸 — 구매함이면 컬러로 "점등"
class GuideUnit {
  const GuideUnit({
    required this.id,
    required this.workId,
    required this.name,
    required this.nameEn,
    required this.image,
    required this.status,
    required this.kitIds,
  });

  final String id;
  final String workId;
  final String name;
  final String nameEn;
  final String image;
  final CollectStatus status;
  final List<String> kitIds;

  static GuideUnit? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final id = json['id'];
    if (id is! String) return null;
    return GuideUnit(
      id: id,
      workId: _s(json, 'workId'),
      name: _s(json, 'name'),
      nameEn: _s(json, 'nameEn'),
      image: _s(json, 'image'),
      status: parseCollectStatus(json['status']),
      kitIds: _strs(json['kitIds']),
    );
  }
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
      typeLabel: _s(json, 'typeLabel'),
      name: _s(json, 'name'),
      image: _s(json, 'image'),
      have: _b(json, 'have'),
      topId: _s(json, 'topId'),
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
      line: _s(json, 'line'),
      name: _s(json, 'name'),
      image: _s(json, 'image'),
      owned: _i(json, 'owned'),
      total: _i(json, 'total'),
      parts: parts is List ? parts.map(BbxPart.fromJson).nonNulls.toList() : const [],
      kitIds: _strs(json['kitIds']),
    );
  }
}

/// 공식 예고 (반다이 방송·공지)
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
  });

  /// 공식 원문 (뉴스 · 유튜브)
  final String url;

  final String id;
  final String franchiseId;
  final String title;
  final String status;
  final String date;
  final String source;
  final String image;

  /// 가로로 넓은 고화질 배너 — 홈 맨 위 큰 사진에 쓴다
  final bool hero;

  static Announcement? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final id = json['id'];
    if (id is! String) return null;
    return Announcement(
      id: id,
      franchiseId: _s(json, 'franchiseId'),
      title: _s(json, 'title'),
      status: _s(json, 'status'),
      date: _s(json, 'date'),
      source: _s(json, 'source'),
      image: _s(json, 'image'),
      hero: _b(json, 'hero'),
    );
  }
}

/// 내 정보 (가짜 계정 — 실제 로그인 없음)
class Profile {
  const Profile({
    required this.name,
    required this.handle,
    required this.avatarText,
    required this.tags,
    required this.spendKrw,
    required this.workspace,
    required this.inviteCode,
    required this.members,
    required this.showcase,
    required this.friends,
    required this.suggested,
  });

  final String name;
  final String handle;
  final String avatarText;
  final List<String> tags;
  final int spendKrw;
  final String workspace;
  final String inviteCode;
  final List<Member> members;

  /// 사진 벽 (나 + 친구). [ShowcasePhoto.owner] = 올린 사람 아이디
  final List<ShowcasePhoto> showcase;

  /// 친구 목록 (친구 서랍 · 친구 프로필)
  final List<Member> friends;

  /// 내 게시물 (= 내 사진 인증 수)
  List<ShowcasePhoto> get myPosts => [
    for (final s in showcase)
      if (s.owner == handle) s,
  ];

  /// 공유 공간 멤버 → 친구 목록의 자세한 정보(좋아요 · 구매함 id 등)
  Member friendOf(Member m) => friends.where((f) => f.handle == m.handle).firstOrNull ?? m;

  /// 알 수도 있는 친구 (이름, 아이디, 함께 아는 친구 수)
  final List<({String name, String handle, int mutual})> suggested;

  static Profile? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final members = json['members'];
    final showcase = json['showcase'];
    final friends = json['friends'];
    final suggested = json['suggested'];
    return Profile(
      name: _s(json, 'name'),
      handle: _s(json, 'handle'),
      avatarText: _s(json, 'avatarText'),
      tags: _strs(json['tags']),
      spendKrw: _i(json, 'spendKrw'),
      workspace: _s(json, 'workspace'),
      inviteCode: _s(json, 'inviteCode'),
      members: [
        if (members is List)
          for (final m in members.whereType<Map<String, Object?>>()) Member.fromJson(m),
      ],
      friends: [
        if (friends is List)
          for (final m in friends.whereType<Map<String, Object?>>()) Member.fromJson(m),
      ],
      suggested: [
        if (suggested is List)
          for (final m in suggested.whereType<Map<String, Object?>>())
            (name: _s(m, 'name'), handle: _s(m, 'handle'), mutual: _i(m, 'mutual')),
      ],
      showcase: [
        if (showcase is List)
          for (final m in showcase.whereType<Map<String, Object?>>())
            ShowcasePhoto(
              id: _s(m, 'id'),
              owner: _s(m, 'owner'),
              image: _s(m, 'image'),
              unit: _s(m, 'unit'),
              work: _s(m, 'work'),
              watermark: _b(m, 'watermark'),
            ),
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
      name: _s(m, 'name'),
      handle: _s(m, 'handle'),
      role: _s(m, 'role'),
      self: _b(m, 'self'),
      liked: _i(m, 'liked'),
      lit: _i(m, 'lit'),
      owned: _i(m, 'owned'),
      verified: _i(m, 'verified'),
      status: _s(m, 'status'),
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

/// 사진 벽 한 장 — 도감에서 인증한 기체와 이어져 있다
class ShowcasePhoto {
  const ShowcasePhoto({
    required this.id,
    required this.owner,
    required this.image,
    required this.unit,
    required this.work,
    required this.watermark,
  });

  final String id;
  final String owner;
  final String image;
  final String unit;
  final String work;

  /// 다른 사람이 저장할 때 오른쪽 아래 "HA · @아이디" 를 넣을지
  final bool watermark;
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
    final at = DateTime.tryParse(_s(json, 'at'));
    final type = NoticeType.values.where((t) => t.name == json['type']).firstOrNull;
    if (id is! String || at == null || type == null) return null;
    return AppNotice(
      id: id,
      type: type,
      title: _s(json, 'title'),
      body: _s(json, 'body'),
      image: _s(json, 'image'),
      at: at,
      read: _b(json, 'read'),
      franchiseId: _s(json, 'franchiseId'),
      kitId: _s(json, 'kitId'),
      annId: _s(json, 'annId'),
      friend: _s(json, 'friend'),
    );
  }
}

/// 검색어가 이름 · 일본어 이름 · 작품 · 라인 · 종류에 들어 있는지 (검색 탭 · 홈 전체 목록 공통)
bool kitMatches(Kit k, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  // 실제 데이터: 미리 만든 소문자 한 줄에서 (8,800개를 글자마다 다시 소문자로 바꾸지 않게)
  if (k.blob.isNotEmpty) return q.split(RegExp(r'\s+')).every(k.blob.contains);
  // keywords: 한글 줄임말(수성 · 철혈 …) · 다른 표기로도 찾히게
  return [k.name, k.nameJa, k.series, k.line, k.type, ...k.keywords].any((f) => f.toLowerCase().contains(q));
}

/// 작품 묶음 이름 (홈 전체 목록 거르기). 베이블레이드는 작품이 하나라 series(한정 · UX…) 대신 이름 하나로
String kitWork(Kit k) => k.franchiseId == 'beyblade' ? 'BEYBLADE X' : k.series;

/// 작품 도감 전체의 점등 칸 수
int litCount(Iterable<GuideWork> works) => works.fold(0, (s, w) => s + w.owned);

/// 수집 경험치 — 구매 10 · 도감 새 칸 5 · 사진 인증 3 · 좋아요 0 (lib/level.dart ? 에 같은 표)
int collectorXp({int owned = 0, int lit = 0, int verified = 0, int liked = 0}) => owned * 10 + lit * 5 + verified * 3;

/// 경험치 → 레벨 · 이번 레벨에서 모은 양 · 다음 레벨까지 필요한 양 (레벨 n 에서 n+1 까지 50 + 10·(n-1))
({int level, int into, int need}) levelOf(int xp) {
  var level = 1, rest = xp, need = 50;
  while (rest >= need) {
    rest -= need;
    level++;
    need = 50 + 10 * (level - 1);
  }
  return (level: level, into: rest, need: need);
}

/// 수집 레벨 (My Page · 도감 · 내 정보 · 친구 서랍 공통)
int guideLevel(int lit, int verified, {int owned = 0, int liked = 0}) =>
    levelOf(collectorXp(owned: owned, lit: lit, verified: verified, liked: liked)).level;

/// 워터마크 글자: 앱 이름 줄임(GP) + 올린 사람 아이디
String watermarkText(String handle) => 'HA · @$handle';
