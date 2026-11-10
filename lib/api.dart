// 화면이 부르는 데이터 함수 — v3: Gunpula 실제 데이터(lib/data/catalog.dart) + 내 기록(lib/data/user_store.dart).
// 화면 코드는 이 파일의 fetch…() 함수만 부른다. 테스트는 Loaders 에 가짜 함수를 넣는다.
import 'data/bbx_builder_data.dart';
import 'data/catalog.dart';
import 'data/derive.dart';
import 'data/restocks.dart';
import 'data/user_store.dart';
import 'logic/kit_rules.dart';
import 'logic/restock.dart';
import 'models.dart';

/// 화면에 그대로 보여 줄 수 있는 오류 문장
class ApiException implements Exception {
  const ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

Future<T> _guard<T>(Future<T> Function() f) async {
  try {
    return await f();
  } on CatalogException catch (e) {
    throw ApiException(e.message);
  }
}

/// 홈 · 검색 · 캘린더: 내 채널의 상품 (발매일 새것부터). 채널이 없으면 빈 목록.
Future<List<Kit>> fetchKits(List<String> channelIds) => _guard(() async {
  if (channelIds.isEmpty) return const <Kit>[];
  await Catalog.instance.ensureLoaded();
  final set = channelIds.toSet();
  return [
    for (final k in Catalog.instance.kits)
      if (set.contains(k.franchiseId)) k,
  ];
});

/// 좋아요 · 구매함 상품 (모든 채널, 최근에 바꾼 것부터)
Future<List<Kit>> fetchCollection() => _guard(() async {
  await Catalog.instance.ensureLoaded();
  final ids = UserStore.instance.idsWith(const {CollectStatus.owned, CollectStatus.wanted});
  return [for (final id in ids) ?Catalog.instance.byId[id]];
});

/// 찍어서 찾기 (바코드): JAN · EAN 이 같은 상품 (Gunpula 에 바코드가 있는 상품은 약 40%)
Future<List<Kit>> fetchKitsByJan(String code) => _guard(() async {
  await Catalog.instance.ensureLoaded();
  return kitsWithBarcode(Catalog.instance.kits, code);
});

/// 도감 대화상자의 대응 모델 · 받은 상품 링크 · 알림
Future<List<Kit>> fetchKitsByIds(List<String> ids) => _guard(() async {
  if (ids.isEmpty) return const <Kit>[];
  final cat = Catalog.instance;
  await cat.ensureLoaded();
  // 앱을 막 켠 때는 옛 id(Gunpula 가 합친 상품)가 아직 안 붙었을 수 있다 — 못 찾은 id 가 있을 때만 기다린다
  // (기기 파일이 없어 인터넷으로 받는 중이면 오래 걸릴 수 있어 5초까지만)
  if (ids.any((id) => cat.byId[id] == null)) {
    await cat.aliasesReady.timeout(const Duration(seconds: 5), onTimeout: () {});
  }
  return [for (final id in ids) ?cat.byId[id]];
});

/// 도감(포켓몬 세대 · Fate 작품 · AC 세대 · BBX 라인 · 건담 시대) · 홈 진행도
Future<List<World>> fetchWorlds(String channelId) => _guard(() => deriveWorlds(channelId));

/// 도감 > 건담: 작품 목록
Future<List<GuideWork>> fetchGuideWorks() => _guard(deriveGuideWorks);

/// 도감 > 건담 > 작품: 기체 칸
Future<List<GuideUnit>> fetchGuideUnits(String workId) => _guard(() => deriveGuideUnits(workId));

/// 도감 탭 검색 · 상세 "도감에서 보기": 작품 · 기체 · 상품 → 기체
Future<GuideIndex> fetchGuideIndex() => _guard(deriveGuideIndex);

/// 도감 > 베이블레이드 X
Future<List<BbxTop>> fetchBbxTops() => _guard(deriveBbxTops);

/// 도감 > 베이블레이드 X > 조합 만들기: 부품 · 규칙
Future<BbxBuilderData> fetchBbxBuilder() => _guard(deriveBbxBuilder);

/// 캘린더 · 홈: 공식 예고
Future<List<Announcement>> fetchAnnouncements(List<String> channelIds) =>
    _guard(() => channelIds.isEmpty ? Future.value(const <Announcement>[]) : deriveAnnouncements(channelIds));

/// 알림: 최근 것부터
Future<List<AppNotice>> fetchNotifications() => _guard(deriveNotifications);

/// 내 정보
Future<Profile> fetchProfile() => _guard(deriveProfile);

/// 친구 도감 비교: 친구가 산 상품 → 작품 id 별 모은 기체 수
Future<Map<String, int>> fetchFriendGuide(List<String> ownedKitIds) => _guard(() => deriveFriendGuide(ownedKitIds));

/// 건담 작품 도감: 화수 · 장 묶음 (data/atlas/gundam-chapters.json — 없으면 빈 목록)
Future<List<GuideChapter>> fetchGuideChapters(String workId) => _guard(() => deriveGuideChapters(workId));

/// 상세 · 캘린더: 재판매 소식 (data/atlas/restocks.json — 없으면 빈 묶음, 오류를 내지 않는다)
Future<RestockIndex> fetchRestocks() => loadRestocks();

/// 화면 사이에 그대로 넘겨 주는 데이터 함수 묶음 (의존성 주입).
/// 앱은 기본값(실제 데이터)을, 테스트는 가짜 함수를 넣는다.
class Loaders {
  const Loaders({
    this.kits = fetchKits,
    this.collection = fetchCollection,
    this.kitsByIds = fetchKitsByIds,
    this.worlds = fetchWorlds,
    this.guideWorks = fetchGuideWorks,
    this.guideUnits = fetchGuideUnits,
    this.bbxTops = fetchBbxTops,
    this.bbxBuilder = fetchBbxBuilder,
    this.announcements = fetchAnnouncements,
    this.profile = fetchProfile,
    this.notifications = fetchNotifications,
    this.friendGuide = fetchFriendGuide,
    this.guideChapters = fetchGuideChapters,
    this.kitsByJan = fetchKitsByJan,
    this.restocks = fetchRestocks,
    this.guideIndex = fetchGuideIndex,
  });

  final Future<List<Kit>> Function(List<String> channelIds) kits;
  final Future<List<Kit>> Function() collection;
  final Future<List<Kit>> Function(List<String> ids) kitsByIds;
  final Future<List<World>> Function(String channelId) worlds;
  final Future<List<GuideWork>> Function() guideWorks;
  final Future<List<GuideUnit>> Function(String workId) guideUnits;
  final Future<List<BbxTop>> Function() bbxTops;
  final Future<BbxBuilderData> Function() bbxBuilder;
  final Future<List<Announcement>> Function(List<String> channelIds) announcements;
  final Future<Profile> Function() profile;
  final Future<List<AppNotice>> Function() notifications;
  final Future<Map<String, int>> Function(List<String> ownedKitIds) friendGuide;

  /// 건담 작품 안 화수 · 장 (없으면 빈 목록)
  final Future<List<GuideChapter>> Function(String workId) guideChapters;

  /// 바코드(JAN · EAN · UPC) → 그 상품들
  final Future<List<Kit>> Function(String code) kitsByJan;

  /// 재판매 소식 (kit_id 별) — 없으면 빈 묶음
  final Future<RestockIndex> Function() restocks;

  /// 건담 도감 찾아보기 표 (작품 · 기체 · 상품 → 기체)
  final Future<GuideIndex> Function() guideIndex;
}
