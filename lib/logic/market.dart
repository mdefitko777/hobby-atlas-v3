// 시세 찾아보기 — 국내 플랫폼 검색 주소 (순수 Dart)

/// 시세를 찾아볼 국내 플랫폼 → 상품명으로 검색한 페이지를 브라우저로 연다
const marketPlatforms = ['네이버쇼핑', '번개장터', '중고나라'];

/// 국내 플랫폼에 칠 상품명 — 화면 언어와 상관없이 한국어 이름 (없으면 일본어 원문).
/// 중국어 화면의 [Kit.name] 은 중국어라 네이버 · 번개장터 · 중고나라에서 거의 안 찾힌다 (2026-11-11 점검)
String marketSearchName({required String nameKo, required String nameJa}) => nameKo.trim().isNotEmpty ? nameKo : nameJa;

String marketSearchUrl(String platform, String query) {
  final q = Uri.encodeComponent(query);
  return switch (platform) {
    '네이버쇼핑' => 'https://search.shopping.naver.com/search/all?query=$q',
    '번개장터' => 'https://m.bunjang.co.kr/search/products?q=$q',
    '중고나라' => 'https://web.joongna.com/search/$q',
    _ => 'https://www.google.com/search?q=$q',
  };
}
