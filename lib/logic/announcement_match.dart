// 공식 예고 → 상품 잇기 — 제목의 「」 이름으로 상품 찾기 · 같은 IP 새 상품 · 예고 단계 (순수 Dart)
import '../models.dart';

/// 예고가 지나가는 단계 (db.json announcements.status 와 같은 글자)
const announcementStages = ['공식 발표', '상품화 확정', '예약 시작', '발매'];

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

final _nameNoise = RegExp(r'[\s\-_/・·.,:;!?！？()（）\[\]［］<>＜＞〈〉【】"“”＇’~〜]');

/// 이름 비교용: 전각 영숫자 → 반각, 소문자, 띄어쓰기 · 기호 빼기 (장음 ー 는 남긴다)
String foldName(String s) => String.fromCharCodes([
  for (final c in s.runes) c >= 0xFF01 && c <= 0xFF5E ? c - 0xFEE0 : c, // ＡＢＣ１２３ → ABC123
]).toLowerCase().replaceAll(_nameNoise, '');

/// J-7 같은 IP의 새 상품 — 제목으로 찾은 상품([matches])의 작품(series_key · 작품 이름) 상품 중 발매일 새것(예정 포함)부터.
/// 찾은 상품이 없으면 채널 전체([all]). 이미 위에 보인 상품은 뺀다. 발매일 없는 상품은 뒤로.
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
      label = matches.firstWhere((k) => k.seriesKey == key || k.series == key).series;
    }
  }
  final shown = {for (final k in matches) k.id};
  final pool = [
    for (final k in all)
      if (!shown.contains(k.id) && (key == null || k.seriesKey == key || (k.seriesKey.isEmpty && k.series == key))) k,
  ]..sort((a, b) => b.date.compareTo(a.date));
  return (label: label, kits: pool.take(max).toList());
}
