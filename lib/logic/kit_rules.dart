// 상품 규칙 — 글자 찾기 · 바코드 · 작품 묶음 · 워터마크 글자 (순수 Dart)
import '../models.dart';

/// 검색어가 이름 · 일본어 이름 · 작품 · 라인 · 종류에 들어 있는지 (검색 탭 · 홈 전체 목록 공통)
bool kitMatches(Kit k, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  // 실제 데이터: 미리 만든 소문자 한 줄에서 (8,800개를 글자마다 다시 소문자로 바꾸지 않게)
  if (k.blob.isNotEmpty) return q.split(RegExp(r'\s+')).every(k.blob.contains);
  // keywords: 한글 줄임말(수성 · 철혈 …) · 다른 표기로도 찾히게
  return [k.name, k.nameJa, k.series, k.line, k.type, ...k.keywords].any((f) => f.toLowerCase().contains(q));
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
