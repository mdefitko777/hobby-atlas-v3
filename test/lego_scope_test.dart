// 레고 보기 범위 — 최근 정식 세트 (2015~, 번호 4~6자리, 폴리백 · 굿즈 · 책 빼고)
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/data/catalog.dart';
import 'package:hobby_atlas/data/user_store.dart';
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
    expect(
      legoRecentSet(lego('71045-3', '2024', code: 'LEGO_MINIFIG', series: 'lego_collectible_minifigures')),
      isTrue,
    );
  });

  test('범위 밖 레고도 id 로는 찾는다 (좋아요 · 구매함) — 둘러보는 목록에서만 빠진다', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    Map<String, Object?> slim(String id, String number, String date, {String code = 'LEGO_SET'}) => {
      ...lego(number, date, code: code),
      'id': id,
      'name': id,
      'line': '세트',
      'type': '레고',
    };
    UserStore.instance.setLegoScope(LegoScope.recent);
    Catalog.instance.debugSet(
      slim: [
        slim('lego-75192-1', '75192', '2017'),
        slim('lego-6089-1', '6089', '2014'),
        {'id': 'hg-1', 'franchiseId': 'gundam', 'name': 'HG', 'date': '2024'},
      ],
      aux: const {},
    );
    final c = Catalog.instance;
    expect(c.kits.map((k) => k.id), unorderedEquals(['lego-75192-1', 'hg-1']));
    expect(c.byId['lego-6089-1'], isNotNull); // 2014 세트를 구매함에 넣어 두었어도 보인다
    expect(c.hiddenByScope('lego-6089-1'), isTrue);
    expect(c.hiddenByScope('lego-75192-1'), isFalse);
    UserStore.instance.setLegoScope(LegoScope.all); // Catalog 가 듣고 목록만 다시 거른다
    expect(c.kits.map((k) => k.id), contains('lego-6089-1'));
    expect(c.hiddenByScope('lego-6089-1'), isFalse);
    UserStore.instance.setLegoScope(LegoScope.recent);
    expect(c.kits.map((k) => k.id), isNot(contains('lego-6089-1')));
  });

  test('처음 값(최근 정식 세트)도 기기 상태에 적는다 — 빠지면 다른 기기의 "전부"가 되살아난다', () {
    UserStore.instance.setLegoScope(LegoScope.recent);
    final local = UserStore.instance.toJson()['local_state'] as Map;
    expect(local['lego_scope'], 'recent');
  });
}
