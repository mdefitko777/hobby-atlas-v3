// 종류별 도감 규칙 (lib/logic/line_guide.dart) — 묶음 키 · 순서 · 굿즈 세부 종류 · 기타 모으기 · 내 기록 숫자 · 표지 · 찾기 · 정렬
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/logic/kit_rules.dart';
import 'package:hobby_atlas/logic/line_guide.dart';
import 'package:hobby_atlas/models.dart';

import 'support/line_kits.dart';

List<Kit> _many(
  String prefix,
  int n, {
  String channel = 'gundam',
  String line = 'HG',
  String type = '프라모델',
  String goodsKind = '',
}) => [
  for (var i = 0; i < n; i++)
    lineKit('$prefix$i', channel: channel, line: line, type: type, goodsKind: goodsKind, date: '2024-0${i % 9 + 1}-01'),
];

List<String> _keys(List<LineGroup> gs) => [for (final g in gs) g.key];

void main() {
  group('묶음 키', () {
    test('라인 · 굿즈 세부 종류 · 굿즈 라인의 가샤폰 · 카드 · 빈 라인', () {
      expect(lineGroupKey(lineKit('a', line: 'MG')), 'MG');
      expect(lineGroupKey(lineKit('b', line: '굿즈', type: '굿즈', goodsKind: '의류')), '의류');
      expect(lineGroupKey(lineKit('c', line: '굿즈', type: '가샤폰')), '가샤폰');
      expect(lineGroupKey(lineKit('d', line: '굿즈', type: '카드')), '카드');
      expect(lineGroupKey(lineKit('e', line: '굿즈', type: '굿즈')), '굿즈');
      // 굿즈 세부 종류 '기타' = 그 라인의 굿즈 칸
      expect(lineGroupKey(lineKit('f', line: '굿즈', type: '굿즈', goodsKind: '기타')), '굿즈');
      expect(lineGroupKey(lineKit('g', line: '', type: '피규어')), '피규어');
      expect(lineGroupKey(lineKit('h', line: '', type: '')), lineOtherKey);
    });

    test('보이는 이름: RE100 → RE/100', () {
      expect(lineGroupLabel('RE100'), 'RE/100');
      expect(lineGroupLabel('HG'), 'HG');
    });
  });

  group('순서', () {
    test('건담: 정해진 등급 순서 → 모르는 라인(굿즈 앞) → 굿즈 → 굿즈 세부 종류 → 기타', () {
      final groups = lineGroups('gundam', [
        ..._many('hg', 9),
        ..._many('mg', 3, line: 'MG'),
        ..._many('pg', 3, line: 'PG'),
        ..._many('rb', 4, line: 'ROBOT魂', type: '피규어'),
        ..._many('gd', 3, line: '굿즈', type: '굿즈'),
        ..._many('xx', 5, line: 'NEWLINE'),
        ..._many('ap', 3, line: '굿즈', type: '굿즈', goodsKind: '의류'),
        ..._many('re', 3, line: 'RE100'),
        lineKit('eg', line: 'EG'),
        lineKit('sd', line: 'SD'),
      ]);
      expect(_keys(groups), ['PG', 'MG', 'HG', 'RE100', 'ROBOT魂', 'NEWLINE', '굿즈', '의류', lineOtherKey]);
      expect(groups.firstWhere((g) => g.key == 'ROBOT魂').goods, isFalse);
      expect(groups.firstWhere((g) => g.key == '의류').goods, isTrue);
    });

    test('건담 밖: 상품 많은 순, 같으면 이름 순 · 기타는 끝', () {
      final groups = lineGroups('pokemon', [
        ..._many('pl', 5, channel: 'pokemon', line: '봉제인형', type: '인형'),
        ..._many('mc', 3, channel: 'pokemon', line: '몬콜레', type: '피규어'),
        ..._many('fg', 4, channel: 'pokemon', line: '피규어', type: '피규어'),
        ..._many('gp', 3, channel: 'pokemon', line: '가샤폰', type: '가샤폰'),
        lineKit('k1', channel: 'pokemon', line: '제일복권'),
        lineKit('k2', channel: 'pokemon', line: '경품'),
      ]);
      expect(_keys(groups), ['봉제인형', '피규어', '가샤폰', '몬콜레', lineOtherKey]);
    });
  });

  group('기타 모으기', () {
    test('작은 묶음이 둘 이상이면 기타로', () {
      final groups = lineGroups('gundam', [
        ..._many('hg', 3),
        lineKit('eg', line: 'EG'),
        lineKit('mgex1', line: 'MGEX'),
        lineKit('mgex2', line: 'MGEX'),
      ]);
      expect(_keys(groups), ['HG', lineOtherKey]);
      expect(groups.last.total, 3);
      expect(lineGroupOf(groups, 'EG'), isNull);
    });

    test('작은 묶음이 하나뿐이면 그대로 · 굿즈 세부 종류 기타와 합쳐진다', () {
      expect(_keys(lineGroups('gundam', [..._many('hg', 3), lineKit('eg', line: 'EG')])), ['HG', 'EG']);
      final withOther = lineGroups('fate', [
        ..._many('sc', 3, channel: 'fate', line: '스케일'),
        lineKit('o1', channel: 'fate', line: '', type: ''),
        lineKit('n1', channel: 'fate', line: '넨도로이드'),
        lineKit('a1', channel: 'fate', line: '액션 피규어'),
      ]);
      expect(_keys(withOther), ['스케일', lineOtherKey]);
      expect(withOther.last.total, 3);
    });

    test('minGroup 으로 문턱을 바꾼다', () {
      final kits = [..._many('hg', 4), ..._many('mg', 2, line: 'MG'), ..._many('rg', 2, line: 'RG')];
      expect(_keys(lineGroups('gundam', kits)), ['HG', lineOtherKey]);
      expect(_keys(lineGroups('gundam', kits, minGroup: 2)), ['MG', 'RG', 'HG']);
    });
  });

  test('묶음 숫자: 전체 · 좋아요 · 구매함 (내 기록 함수) · 표지 = 사진 있는 가장 새 상품', () {
    final kits = [
      lineKit('old', date: '2020-01-01', image: 'old.jpg'),
      lineKit('new', date: '2025-05-01', image: ''),
      lineKit('ref', date: '2025-04-01', image: 'ref.jpg', imageRef: true),
      lineKit('mid', date: '2023-01-01', image: 'mid.jpg'),
      lineKit('nodate', date: '', image: 'nodate.jpg'),
    ];
    final status = {'old': CollectStatus.owned, 'mid': CollectStatus.wanted, 'nodate': CollectStatus.owned};
    final g = lineGroups('gundam', kits, status: (k) => status[k.id] ?? CollectStatus.none).single;
    expect(g.total, 5);
    expect(g.owned, 2);
    expect(g.liked, 1);
    expect(g.mine, isTrue);
    expect([for (final k in g.kits) k.id], ['new', 'ref', 'mid', 'old', 'nodate']); // 발매일 없는 것은 끝
    expect(g.cover, 'mid.jpg'); // 사진 없는 것 · 참고 그림은 건너뛴다
    // 내 기록 함수를 안 주면 상품에 적힌 값
    final plain = lineGroups('gundam', [lineKit('a', status: CollectStatus.wanted)]).single;
    expect((plain.liked, plain.owned, plain.mine), (1, 0, true));
    expect(lineGroups('gundam', [lineKit('b')]).single.mine, isFalse);
  });

  group('묶음 안', () {
    final kits = [
      lineKit('a', name: 'HG 자쿠', date: '2023-02-01'),
      lineKit('b', name: 'HG 건담', date: '2024-05-01'),
      lineKit('c', name: 'HG 구프', date: '2024-01-01'),
      lineKit('d', name: 'HG 돔', date: ''),
    ];
    final status = {'a': CollectStatus.owned, 'b': CollectStatus.wanted};
    CollectStatus st(Kit k) => status[k.id] ?? CollectStatus.none;
    List<String> ids(List<Kit> ks) => [for (final k in ks) k.id];

    test('상태 거르기', () {
      List<String> by(LineStatus f) => ids(lineKits(kits, status: st, matches: (_) => true, filter: f));
      expect(by(LineStatus.all), ['b', 'c', 'a', 'd']);
      expect(by(LineStatus.mine), ['b', 'a']);
      expect(by(LineStatus.liked), ['b']);
      expect(by(LineStatus.owned), ['a']);
      expect(by(LineStatus.none), ['c', 'd']);
    });

    test('정렬: 최신 · 오래된(발매일 없는 것은 끝) · 이름', () {
      List<String> by(LineSort s) => ids(lineKits(kits, status: st, matches: (_) => true, sort: s));
      expect(by(LineSort.newest), ['b', 'c', 'a', 'd']);
      expect(by(LineSort.oldest), ['a', 'c', 'b', 'd']);
      expect(by(LineSort.name), ['b', 'c', 'd', 'a']); // 건담 · 구프 · 돔 · 자쿠 (가나다)
      expect(LineSort.name.byDate, isFalse);
    });

    test('찾기 (kitMatches)', () {
      expect(ids(lineKits(kits, status: st, matches: (k) => kitMatches(k, '자쿠'))), ['a']);
    });

    test('발매 연도 머리', () {
      final years = byReleaseYear(lineKits(kits, status: st, matches: (_) => true));
      expect([for (final (y, l) in years) '$y ${l.length}'], ['2024년 2', '2023년 1', '발매일 미정 1']);
    });
  });
}
