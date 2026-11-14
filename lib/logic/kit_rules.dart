// 상품 규칙 — 글자 찾기 · 바코드 · 작품 묶음 · 워터마크 글자 (순수 Dart)
import '../clock.dart';
import '../format.dart';
import '../l10n/l10n.dart';
import '../models.dart';

/// 검색어가 이름 · 일본어 이름 · 작품 · 라인 · 종류에 들어 있는지 (검색 탭 · 홈 전체 목록 공통)
bool kitMatches(Kit k, String query) {
  // 전각으로 친 검색어(ＨＧ · ０088)도 반각으로 — blob 은 미리 반각 (lib/data/gunpula.dart)
  final q = halfWidth(query).trim().toLowerCase();
  if (q.isEmpty) return true;
  // 실제 데이터: 미리 만든 소문자 한 줄에서 (8,800개를 글자마다 다시 소문자로 바꾸지 않게)
  if (k.blob.isNotEmpty) return q.split(RegExp(r'\s+')).every(k.blob.contains);
  // keywords: 한글 줄임말(수성 · 철혈 …) · 다른 표기로도 찾히게
  return [k.name, k.nameJa, k.series, k.line, k.type, ...k.keywords].any((f) => halfWidth(f).toLowerCase().contains(q));
}

// ── 한국 · 일본 정가 (같은 바코드 짝) ─────────────────────────────────────────

/// 둘러보는 목록에서 빠지는 쪽 — 한국 짝이 있는 일본 상품 (lib/data/gunpula.dart pairTwins)
bool isJpTwin(Kit k) => k.twinId.isNotEmpty && k.region == 'jp';

/// 한국에서 파는 상품 (한국 출처 · 둘 다 · 짝이 있는 것)
bool soldInKorea(Kit k) => k.region == 'kr' || k.region == 'both' || k.twinId.isNotEmpty;

/// 일본에서 파는 상품
bool soldInJapan(Kit k) => k.region == 'jp' || k.region == 'both' || k.twinId.isNotEmpty;

/// 정가 조각 — 그 상품 나라의 돈이 앞 (일본 상품은 ¥ 먼저, 나머지는 ₩ 먼저). 정가가 없으면 빈 목록
List<String> kitPriceParts(Kit k) {
  final krw = k.priceKrw == null ? null : wonSign(k.priceKrw);
  final jpy = k.priceJpy == null ? null : yen(k.priceJpy);
  return k.region == 'jp' ? [?jpy, ?krw] : [?krw, ?jpy];
}

/// 정가 한 줄: "₩19,000 · ¥1,650" · "¥1,540" · '가격 미정' (목록 · 상세 · 컬렉션 공통, 환산값 없음)
String kitPrice(Kit k) => prices(krw: k.priceKrw, jpy: k.priceJpy, jpyFirst: k.region == 'jp');

/// 한 목록에 짝이 둘 다 들었으면 일본 쪽을 뺀다 (도감 묶음 · 받은 id 목록은 둘 다 가질 수 있다)
List<Kit> mergeTwins(List<Kit> kits) {
  final ids = {for (final k in kits) k.id};
  return [
    for (final k in kits)
      if (!(isJpTwin(k) && ids.contains(k.twinId))) k,
  ];
}

/// 정가 합계 — 상품마다 제 나라 돈 하나로만 센다 (한국 정가가 있으면 원, 없으면 엔). 서로 환산하지 않는다
({int krw, int jpy}) priceTotals(Iterable<Kit> kits, int Function(Kit) qty) {
  var krw = 0;
  var jpy = 0;
  for (final k in kits) {
    if (k.priceKrw case final w?) {
      krw += w * qty(k);
    } else if (k.priceJpy case final p?) {
      jpy += p * qty(k);
    }
  }
  return (krw: krw, jpy: jpy);
}

/// 바코드 읽은 값 → 숫자 13자리 비교용 (UPC-A 12자리는 앞에 0, EAN-8 은 그대로). 숫자가 아니면 빈 글자
String normalizeBarcode(String raw) {
  final d = raw.replaceAll(RegExp(r'\D'), '');
  if (d.length == 12) return '0$d';
  return d.length == 8 || d.length == 13 ? d : '';
}

/// 이 바코드의 상품 (Kit.jan, 없으면 이름 · 키워드 한 줄에 그 숫자가 있는 것)
List<Kit> kitsWithBarcode(Iterable<Kit> kits, String raw) {
  final code = normalizeBarcode(raw);
  if (code.isEmpty) return const [];
  final exact = [
    for (final k in kits)
      if (k.jan == code) k,
  ];
  if (exact.isNotEmpty) return exact;
  return [
    for (final k in kits)
      if (k.blob.contains(code) || k.keywords.contains(code)) k,
  ];
}

/// 작품 묶음 이름 (홈 전체 목록 거르기). 베이블레이드는 작품이 하나라 series(한정 · UX…) 대신 이름 하나로
String kitWork(Kit k) => k.franchiseId == 'beyblade' ? 'BEYBLADE X' : k.series;

/// [kitWork] 를 화면에 보일 때 (중국어 화면이면 작품 중국어 이름) — 묶기 · 비교는 [kitWork] 그대로
String kitWorkLabel(Kit k) => k.franchiseId == 'beyblade' ? 'BEYBLADE X' : k.seriesLabel;

/// 워터마크 글자: 앱 이름 줄임(GP) + 올린 사람 아이디
String watermarkText(String handle) => 'HA · @$handle';

/// "새로 들어온" = 가장 늦게 들어온 날부터 7일 안 (새것부터, [limit] 개)
List<Kit> newThisWeek(List<Kit> kits, {int limit = 8}) {
  final seen = [
    for (final k in kits)
      if (k.firstSeen.length >= 10) k,
  ]..sort((a, b) => b.firstSeen.compareTo(a.firstSeen));
  if (seen.isEmpty) return const [];
  final top = DateTime.tryParse(seen.first.firstSeen.substring(0, 10));
  if (top == null) return seen.take(limit).toList();
  final since = top.subtract(const Duration(days: 6)).toIso8601String().substring(0, 10);
  return seen.where((k) => k.firstSeen.compareTo(since) >= 0).take(limit).toList();
}

/// 상품의 다가오는 날짜 (PB 예약 마감 > 발매일) — 없으면 null. My Page · 캘린더 공통
({String sortKey, String label, bool urgent})? upcomingOf(Kit k, {bool wanted = true}) {
  final now = appNow();
  final today = dayKey(now);
  if (wanted && k.pbCloses.length >= 10 && k.pbCloses.compareTo(today) >= 0) {
    final d = DateTime.parse(k.pbCloses).difference(DateTime(now.year, now.month, now.day)).inDays;
    return (sortKey: k.pbCloses, label: d == 0 ? tr('PB 오늘') : 'PB D-$d', urgent: true);
  }
  if (k.date.length == 10 && k.date.compareTo(today) >= 0) {
    return (sortKey: k.date, label: dateDot(k.date.substring(5)), urgent: false);
  }
  if (k.date.length == 7 && k.date.compareTo(today.substring(0, 7)) >= 0) {
    return (sortKey: '${k.date}-99', label: trf('{m}월', {'m': int.parse(k.date.substring(5))}), urgent: false);
  }
  return null;
}
