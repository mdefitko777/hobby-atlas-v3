// 레고 보기 범위 (설정 › 데이터 › 레고 범위) — 순수 Dart.
//   recent (처음 값): 2015년부터의 정식 세트 · 미니피규어 시리즈.
//     정식 세트 = 번호가 4~6자리 숫자 (잡지 부록 2D001164 · 7자리 굿즈 번호 빼고), 30xxx 폴리백 빼고,
//     굿즈 · 책 · 부품 · 프로모 · 스토어 · 교육용 같은 시리즈 빼고.
//     (부품 수로는 거르지 않는다: 듀플로는 부품이 적고, 막 나온 세트는 Rebrickable 부품 수가 0)
//   all: Rebrickable 카탈로그 전부 (약 2.8만 개)
enum LegoScope { recent, all }

/// 이 시리즈(Gunpula series key)들은 세트 모음이 아니다
const legoNonSetSeries = {
  'lego_gear',
  'lego_books',
  'lego_service_packs',
  'lego_bulk_bricks',
  'lego_promotional',
  'lego_lego_brand_store',
  'lego_legoland',
  'lego_legoland_parks',
  'lego_other',
  'lego_educational_and_dacta',
  'lego_first_lego_league',
  'lego_games',
  'lego_power_functions',
  'lego_value_packs',
  'lego_universal_building_set',
};

const legoRecentFromYear = 2015;

/// 매핑된 상품 한 줄(slim)이 "최근 정식 세트" 범위에 드는가
bool legoRecentSet(Map<String, Object?> slim) {
  final year = int.tryParse('${slim['date'] ?? ''}'.padRight(4).substring(0, 4)) ?? 0;
  if (year < legoRecentFromYear) return false;
  if (legoNonSetSeries.contains(slim['seriesKey'])) return false;
  final code = slim['gradeCode'];
  if (code == 'LEGO_MINIFIG') return true;
  if (code != 'LEGO_SET') return false;
  final number = '${slim['number'] ?? ''}';
  return RegExp(r'^\d{4,6}$').hasMatch(number) && !RegExp(r'^30\d{3}$').hasMatch(number);
}
