// 공식 예고 → 상품 잇기 — 이어 둔 상품 · 제목의 「」 이름으로 상품 찾기 · 같은 IP 새 상품 · 예고 단계 ·
// 비공식 소식 가르기(꼬리표 글 · 줄 제목 · 예고 목록 탭 · 홈 배너) · 이어받은 예고 id (순수 Dart)
import '../json_util.dart';
import '../models.dart';

/// 예고가 지나가는 단계 (공식 예고 데이터의 status 와 같은 글자)
const announcementStages = ['공식 발표', '상품화 확정', '예약 시작', '발매'];

/// 공식이 아닌 곳(취미 매체 · 팬 사이트)의 소식을 가르는 말 — 꼬리표 · 예고 목록 탭 · 알림 제목 (보일 때 tr)
const unofficialLabel = '비공식';

/// 꼬리표 · 캘린더 알약 · 알림함 줄에 쓰는 단계 글 (번역 표의 한국어 말 — 보일 때 tr).
/// 비공식 소식은 「공식 발표」 자리에 「비공식」만 (공식이 아닌데 공식 발표라고 읽히면 안 된다),
/// 뒤 단계는 「비공식 · 예약 시작」처럼 단계를 남긴다
String annStageText(String status, {bool unofficial = false}) =>
    !unofficial ? status : (status == announcementStages.first ? unofficialLabel : '$unofficialLabel · $status');

/// 예고 줄 · 전체 목록의 제목 (번역 표의 한국어 말): 공식뿐이면 「공식 예고」 그대로, 비공식이 섞였으면 「예고」
String annSectionTitle(Iterable<Announcement> list) => list.any((a) => a.unofficial) ? '예고' : '공식 예고';

/// 예고 목록 탭에 드는가 — [tab]: '' 전체 · 단계 글(공식 예고만) · [unofficialLabel].
/// 비공식 소식은 단계 탭에 세지 않는다 (「공식 발표 3」에 공식이 아닌 것이 섞이지 않게)
bool inAnnTab(Announcement a, String tab) => tab.isEmpty || (a.unofficial ? tab == unofficialLabel : a.status == tab);

/// 예고 목록 탭 (O-5): 전체 · 공식 예고의 단계(나온 순서대로 한 번씩) · 비공식(있을 때만, 맨 끝)
List<({String tab, int count})> announcementTabs(List<Announcement> all) => [
  for (final tab in {
    '',
    for (final a in all)
      if (!a.unofficial) a.status,
    if (all.any((a) => a.unofficial)) unofficialLabel,
  })
    (tab: tab, count: all.where((a) => inAnnTab(a, tab)).length),
];

/// 홈 배너(A-3)에 올릴 예고 id — 사진 있는 공식 예고가 먼저 [max] 개, 모자랄 때만 사진 있는 비공식 소식으로 채운다
/// (각각 줄 순서대로). 배너는 첫눈에 보는 자리라 공식이 넉넉하면 비공식을 올리지 않는다
Set<String> annHeroIds(List<Announcement> list, {int max = 6}) {
  final shown = list.where((a) => a.image.isNotEmpty);
  return {
    for (final a in [...shown.where((a) => !a.unofficial), ...shown.where((a) => a.unofficial)].take(max)) a.id,
  };
}

/// 홈 배너(A-3)에 넘기는 순서 — 공식 먼저, 채운 비공식은 뒤 (각각 줄 순서). 줄 순서 그대로면
/// 새 비공식 소식이 첫 장에 와서 「공식 먼저」가 깨진다
List<Announcement> annHeroes(List<Announcement> list) => [
  for (final a in list)
    if (a.hero && !a.unofficial) a,
  for (final a in list)
    if (a.hero && a.unofficial) a,
];

/// announcements.json 의 `replaced` (옛 id → 새 id): 공식 쪽이 이어받아 Gunpula 가 옛 줄을 뺀 것
/// (魂ウェブ 「商品化決定」 소식 → 예약 글). 사슬 a → b → c 는 끝 id 로, 고리 · 모양이 다른 값은 버린다.
/// 지도가 없는 옛 파일이면 빈 지도
Map<String, String> annReplacedOf(Object? announcements) {
  final m = jMap(jMap(announcements)['replaced']);
  String? last(String id) {
    final seen = {id};
    var cur = id;
    for (var next = m[cur]; next is String && next.isNotEmpty; next = m[cur]) {
      if (!seen.add(next)) return null; // 고리 — 어느 쪽이 남은 것인지 알 수 없다
      cur = next;
    }
    return cur;
  }

  return {
    for (final k in m.keys)
      if (last(k) case final to? when to != k) k: to,
  };
}

/// 예고 id 로 묶은 기록(알림 받는 예고 …)의 옛 id 를 [replaced] 의 새 id 로 옮긴 새 지도 — 옮길 것이 없으면 null
/// (부르는 쪽이 그때만 저장한다). 새 id 도 이미 있으면 그쪽을 둔다 (새 예고에서 직접 고른 것이 더 새것)
Map<String, T>? moveAnnIds<T>(Map<String, T> byId, Map<String, String> replaced) {
  if (!byId.keys.any(replaced.containsKey)) return null;
  final out = {
    for (final e in byId.entries)
      if (!replaced.containsKey(e.key)) e.key: e.value,
  };
  for (final e in byId.entries) {
    if (replaced[e.key] case final to?) out.putIfAbsent(to, () => e.value);
  }
  return out;
}

/// 제목의 「」 안 이름으로 상품 찾기 — 『』(작품 이름)는 쓰지 않는다. 띄어쓰기 · 전각 · 기호는 무시.
/// 「ブラックナイトスコードカルラ」 → 'METAL ROBOT魂 ＜SIDE MS＞ ブラックナイトスコード カルラ'
List<Kit> matchAnnouncementKits(String title, List<Kit> kits) {
  final names = {
    for (final m in RegExp('「([^」]+)」').allMatches(title))
      if (foldName(m.group(1)!) case final n when n.length >= 3) n,
  };
  if (names.isEmpty) return const [];
  return [
    for (final k in kits)
      if ([foldName(k.nameJa), foldName(k.name)] case final own when names.any((n) => own.any((o) => o.contains(n)))) k,
  ]..sort((a, b) => b.date.compareTo(a.date));
}

/// 이 예고의 상품 — 데이터가 이어 둔 상품(linked_kit_id: 공식 페이지 주소 · 魂ウェブ 번호 · JAN 이 같은 상품)이 먼저,
/// 그다음 제목 「」 으로 찾은 상품 (같은 상품은 한 번). 이어 둔 상품이 [kits] 에 없으면 제목으로만
List<Kit> annKits(Announcement a, List<Kit> kits) {
  final linked = a.linkedKitId.isEmpty ? null : kits.where((k) => k.id == a.linkedKitId).firstOrNull;
  return [
    ?linked,
    for (final k in matchAnnouncementKits(a.title, kits))
      if (k.id != linked?.id) k,
  ];
}

final _nameNoise = RegExp(r'[\s\-_/・·.,:;!?！？()（）\[\]［］<>＜＞〈〉【】"“”＇’~〜]');

/// 이름 비교용: 전각 영숫자 → 반각, 소문자, 띄어쓰기 · 기호 빼기 (장음 ー 는 남긴다)
String foldName(String s) => String.fromCharCodes([
  for (final c in s.runes) c >= 0xFF01 && c <= 0xFF5E ? c - 0xFEE0 : c, // ＡＢＣ１２３ → ABC123
]).toLowerCase().replaceAll(_nameNoise, '');

/// J-7 같은 IP의 새 상품 — 제목으로 찾은 상품([matches])의 작품(series_key · 작품 이름) 상품 중 발매일 새것(예정 포함)부터.
/// 찾은 상품이 없으면 채널 전체([all]). 이미 위에 보인 상품은 뺀다. 발매일 없는 상품은 뒤로.
/// label = 화면 글 (작품의 seriesLabel, 없으면 [channelLabel] — 부르는 쪽이 화면 언어로 넘긴다)
({String label, List<Kit> kits}) sameIpKits(
  List<Kit> matches,
  List<Kit> all, {
  String channelLabel = '',
  int max = 12,
}) {
  String? key;
  var label = channelLabel;
  if (matches.isNotEmpty) {
    final count = <String, int>{};
    for (final k in matches) {
      final s = k.seriesKey.isNotEmpty ? k.seriesKey : k.series;
      if (s.isNotEmpty) count[s] = (count[s] ?? 0) + 1;
    }
    if (count.isNotEmpty) {
      key = (count.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
      label = matches.firstWhere((k) => k.seriesKey == key || k.series == key).seriesLabel; // 화면 글 — 고르기는 series 그대로
    }
  }
  final shown = {for (final k in matches) k.id};
  final pool = [
    for (final k in all)
      if (!shown.contains(k.id) && (key == null || k.seriesKey == key || (k.seriesKey.isEmpty && k.series == key))) k,
  ]..sort((a, b) => b.date.compareTo(a.date));
  return (label: label, kits: pool.take(max).toList());
}
