// 레고 보기 범위 — 최근 정식 세트 (2015~, 번호 4~6자리, 폴리백 · 굿즈 · 책 빼고)
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/logic/lego_scope.dart';

Map<String, Object?> lego(String number, String date, {String code = 'LEGO_SET', String series = 'lego_city'}) => {
  'franchiseId': 'lego',
  'number': number,
  'date': date,
  'gradeCode': code,
  'seriesKey': series,
};

void main() {
  test('정식 세트만', () {
    expect(legoRecentSet(lego('60347', '2022')), isTrue); // 시티 슈퍼마켓
    expect(legoRecentSet(lego('10446', '2025', series: 'lego_duplo')), isTrue); // 듀플로 (부품이 적어도)
    expect(legoRecentSet(lego('75192', '2017', series: 'lego_star_wars')), isTrue);
    expect(legoRecentSet(lego('6089', '2014')), isFalse); // 2015년 전
    expect(legoRecentSet(lego('30712', '2025')), isFalse); // 폴리백
    expect(legoRecentSet(lego('2D001164', '2024')), isFalse); // 잡지 부록
    expect(legoRecentSet(lego('5008073', '2024')), isFalse); // 7자리 굿즈 번호
    expect(legoRecentSet(lego('853990', '2020', code: 'LEGO_GEAR', series: 'lego_gear')), isFalse);
    expect(legoRecentSet(lego('40639', '2023', series: 'lego_promotional')), isFalse);
    expect(legoRecentSet(lego('71045-3', '2024', code: 'LEGO_MINIFIG', series: 'lego_collectible_minifigures')), isTrue);
  });
}
