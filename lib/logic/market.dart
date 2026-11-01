// 시세 찾아보기 — 국내 플랫폼 검색 주소 (순수 Dart)


/// 시세를 찾아볼 국내 플랫폼 → 상품명으로 검색한 페이지를 브라우저로 연다
const marketPlatforms = ['네이버쇼핑', '번개장터', '중고나라'];

String marketSearchUrl(String platform, String query) {
  final q = Uri.encodeComponent(query);
  return switch (platform) {
    '네이버쇼핑' => 'https://search.shopping.naver.com/search/all?query=$q',
    '번개장터' => 'https://m.bunjang.co.kr/search/products?q=$q',
    '중고나라' => 'https://web.joongna.com/search/$q',
    _ => 'https://www.google.com/search?q=$q',
  };
}
