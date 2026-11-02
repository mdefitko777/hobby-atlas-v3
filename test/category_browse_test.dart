// 검색 탭 종류 · 세대 규칙 (lib/logic/category_browse.dart) — 칸 키 · 묶음 · 순서 · 빈 칸 숨김 · 작은 칸 모으기 ·
// 세부 시리즈 · 세대 묶음 + 매핑의 세부 시리즈 (lib/data/gunpula.dart cleanSubline)
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/data/gunpula.dart' show cleanSubline;
import 'package:hobby_atlas/logic/category_browse.dart';
import 'package:hobby_atlas/models.dart';

import 'support/line_kits.dart';

List<Kit> _many(
  String prefix,
  int n, {
  String channel = 'gundam',
  String line = 'HG',
  String type = '프라모델',
  String goodsKind = '',
  String subline = '',
}) => [
  for (var i = 0; i < n; i++)
    lineKit(
      '$prefix$i',
      channel: channel,
      line: line,
      type: type,
      goodsKind: goodsKind,
      subline: subline,
      date: '2024-0${i % 9 + 1}-01',
    ),
];

/// 묶음 → ['묶음: 칸 · 칸']
List<String> _shape(List<TypeSection> s) => [
  for (final x in s) '${x.title}: ${x.entries.map((e) => e.key).join(' · ')}',
];

void main() {
  group('칸 키', () {
    test('라인 · 굿즈 세부 종류 · 굿즈 라인의 가샤폰 · 카드 · 빈 라인', () {
      expect(lineGroupKey(lineKit('a', line: 'MG')), 'MG');
      expect(lineGroupKey(lineKit('b', line: '굿즈', type: '굿즈', goodsKind: '의류')), '의류');
      expect(lineGroupKey(lineKit('c', line: '굿즈', type: '가샤폰')), '가샤폰');
      expect(lineGroupKey(lineKit('d', line: '굿즈', type: '카드')), '카드');
      expect(lineGroupKey(lineKit('f', line: '굿즈', type: '굿즈', goodsKind: '기타')), '굿즈');
      expect(lineGroupKey(lineKit('g', line: '', type: '피규어')), '피규어');
      expect(lineGroupKey(lineKit('h', line: '', type: '')), lineOtherKey);
      expect(lineGroupLabel('RE100'), 'RE/100');
      expect(lineGroupLabel('PGU'), 'PG UNLEASHED');
    });

    test('베이블레이드 X = 상품 형태 (라인 BX · UX · CX 는 세대 쪽)', () {
      final k = lineKit('bx01', channel: 'beyblade', line: 'BX', type: '배틀 토이', subline: '스타터');
      expect(typeKeyOf('beyblade', k), '스타터');
      expect(typeKeyOf('beyblade', lineKit('x', channel: 'beyblade', line: 'BX')), 'BX'); // 형태를 모르면 라인
      expect(typeKeyOf('gundam', lineKit('hg', subline: 'HGUC')), 'HG'); // 건담 세부 시리즈는 칸을 가르지 않는다
    });
  });

  group('종류 묶음', () {
    test('건담: 프라모델 → 옛 등급 → SD → 완성품 → 식완 · 가샤폰 → 굿즈 → 영상 · 책 · 이벤트, 빈 칸 · 빈 묶음 없음', () {
      final s = typeSections('gundam', [
        ..._many('hg', 4),
        ..._many('mg', 3, line: 'MG'),
        lineKit('pg', line: 'PG'), // 공식 라인은 하나여도 제 칸
        lineKit('re', line: 'RE100'),
        lineKit('ng', line: 'No Grade'),
        lineKit('bmc', line: 'BMC'),
        ..._many('sd', 2, line: 'SD'),
        lineKit('ganso', line: '元祖 SD', type: '피규어'),
        ..._many('rb', 3, line: 'ROBOT魂', type: '피규어'),
        lineKit('sdx', line: 'SDX', type: '피규어'),
        ..._many('cv', 2, line: 'CONVERGE', type: '식완'),
        ..._many('gp', 3, line: '굿즈', type: '가샤폰'),
        ..._many('gd', 4, line: '굿즈', type: '굿즈'),
        ..._many('ap', 3, line: '굿즈', type: '굿즈', goodsKind: '의류'),
        ..._many('bd', 3, line: '굿즈', type: '굿즈', goodsKind: '블루레이 · DVD'),
      ]);
      expect(_shape(s), [
        '프라모델: PG · MG · HG · RE100',
        '옛 등급 · 특수: No Grade · BMC',
        'SD: SD · 元祖 SD',
        '완성품 피규어: ROBOT魂 · SDX',
        '식완 · 가샤폰: CONVERGE · 가샤폰',
        '굿즈: 굿즈 · 의류',
        '영상 · 책 · 이벤트: 블루레이 · DVD',
      ]);
      expect(s.first.entries.last.label, 'RE/100');
    });

    test('모르는 라인 = 상품 유형으로 묶음, 유형도 모르면 끝의 기타 묶음', () {
      final s = typeSections('gundam', [
        ..._many('hg', 3),
        ..._many('nw', 3, line: 'NEWGRADE'),
        ..._many('fx', 3, line: 'NEWFIG', type: '피규어'),
        ..._many('zz', 3, line: 'ODD', type: '배틀 토이'),
      ]);
      expect(_shape(s), ['프라모델: HG · NEWGRADE', '완성품 피규어: NEWFIG', '기타: ODD']);
    });

    test('작은 굿즈 칸이 둘 이상이면 그 묶음 끝 기타로 · 공식 라인과 하나뿐인 작은 칸은 그대로', () {
      final s = typeSections('fate', [
        ..._many('sc', 3, channel: 'fate', line: '스케일', type: '피규어'),
        lineKit('fg', channel: 'fate', line: 'figma', type: '액션'),
        ..._many('gd', 5, channel: 'fate', line: '굿즈', type: '굿즈'),
        lineKit('ac', channel: 'fate', line: '굿즈', type: '굿즈', goodsKind: '아크릴'),
        lineKit('fd', channel: 'fate', line: '굿즈', type: '굿즈', goodsKind: '식품'),
        ..._many('tk', 4, channel: 'fate', line: '굿즈', type: '굿즈', goodsKind: '티켓 · 이벤트'),
        lineKit('bk', channel: 'fate', line: '굿즈', type: '굿즈', goodsKind: '책 · 화보'),
      ]);
      expect(_shape(s), ['피규어: 스케일 · figma', '굿즈: 굿즈 · 굿즈/기타', '영상 · 책 · 이벤트: 티켓 · 이벤트 · 책 · 화보']);
      final other = s[1].entries.last;
      expect(other.label, lineOtherKey);
      expect([for (final k in other.kits) k.id]..sort(), ['ac', 'fd']);
      expect(typeSections('fate', _many('sc', 3, channel: 'fate', line: '스케일'), minGroup: 1).single.entries.length, 1);
    });

    test('포켓몬 · AC · 베이 묶음', () {
      expect(
        _shape(
          typeSections('pokemon', [
            ..._many('pl', 5, channel: 'pokemon', line: '봉제인형', type: '인형'),
            ..._many('mc', 3, channel: 'pokemon', line: '몬콜레', type: '피규어'),
            ..._many('gp', 3, channel: 'pokemon', line: '가샤폰', type: '가샤폰'),
            ..._many('gg', 3, channel: 'pokemon', line: '굿즈', type: '가샤폰'), // 굿즈 라인의 가샤폰 = 같은 칸
            lineKit('kj', channel: 'pokemon', line: '제일복권', type: '제일복권'),
          ]),
        ),
        ['인형 · 피규어: 봉제인형 · 몬콜레', '가샤폰 · 경품 · 복권: 가샤폰 · 제일복권'],
      );
      expect(
        _shape(
          typeSections('armored_core', [
            ..._many('vi', 3, channel: 'armored_core', line: 'V.I.'),
            lineKit('mm', channel: 'armored_core', line: '30MM'),
            lineKit('sk', channel: 'armored_core', line: '식완', type: '식완'),
          ]),
        ),
        ['프라모델: V.I. · 30MM', '식완 · 가샤폰: 식완'],
      );
      expect(
        _shape(
          typeSections('beyblade', [
            ..._many('st', 2, channel: 'beyblade', line: 'BX', type: '배틀 토이', subline: '스타터'),
            ..._many('rb', 2, channel: 'beyblade', line: 'UX', type: '배틀 토이', subline: '랜덤 부스터'),
            ..._many('bo', 2, channel: 'beyblade', line: 'CX', type: '배틀 토이', subline: '부스터'),
            lineKit('to', channel: 'beyblade', line: 'BX', type: '배틀 토이', subline: '런처 · 도구'),
          ]),
        ),
        ['베이: 스타터 · 부스터 · 랜덤 부스터', '세트 · 도구: 런처 · 도구'],
      );
    });

    test('모르는 채널 = 한 묶음 · 많은 순', () {
      final s = typeSections('zoids', [..._many('a', 2, line: 'A'), ..._many('b', 4, line: 'B')]);
      expect(_shape(s), ['종류: B · A']);
      expect(typeSections('gundam', const []), isEmpty);
    });

    test('칸 상품 = 새것부터 · 대표 그림 = 사진 있는 가장 새 상품', () {
      final e = typeSections('gundam', [
        lineKit('old', date: '2020-01-01', image: 'old.jpg'),
        lineKit('new', date: '2025-05-01', image: ''),
        lineKit('ref', date: '2025-04-01', image: 'ref.jpg', imageRef: true),
        lineKit('mid', date: '2023-01-01', image: 'mid.jpg'),
        lineKit('nodate', date: '', image: 'nodate.jpg'),
      ]).single.entries.single;
      expect([for (final k in e.kits) k.id], ['new', 'ref', 'mid', 'old', 'nodate']);
      expect(e.cover, 'mid.jpg');
    });
  });

  group('세부 시리즈', () {
    test('상품 2개 이상인 것만 · 많은 순 · PB 한정', () {
      final kits = [
        ..._many('uc', 3, subline: 'HGUC'),
        ..._many('ce', 2, subline: 'HGCE'),
        lineKit('bf', subline: 'HGBF'),
        lineKit('pb', pb: true),
      ];
      expect(sublineChoices(kits), ['HGUC', 'HGCE', pbChoice]);
      expect(kitsOfChoice(kits, '').length, 7);
      expect([for (final k in kitsOfChoice(kits, 'HGCE')) k.id], ['ce0', 'ce1']);
      expect([for (final k in kitsOfChoice(kits, pbChoice)) k.id], ['pb']);
    });

    test('고를 것이 없으면 빈 줄 (세부 시리즈 없음 · 하나뿐인 시리즈가 전부)', () {
      expect(sublineChoices(_many('mg', 3, line: 'MG')), isEmpty);
      expect(sublineChoices(_many('st', 3, subline: '스타터')), isEmpty);
      expect(sublineChoices([..._many('st', 3, subline: '스타터'), lineKit('x')]), ['스타터']);
    });

    test('매핑: HG 이름 머리 · ROBOT魂 ver. A.N.I.M.E. · 베이 상품 형태', () {
      expect(cleanSubline('HG', 'HG', 'HG', name: 'ＨＧＵＣ 1/144 ガンダム'), 'HGUC');
      expect(cleanSubline('ROBOT魂 ver. A.N.I.M.E.', 'ROBOT_SPIRITS', 'ROBOT魂'), 'ver. A.N.I.M.E.');
      expect(cleanSubline('BEYBLADE X Starter', 'BEYBLADE_X', 'BX'), '스타터');
      expect(cleanSubline('BEYBLADE X Random Booster', 'BEYBLADE_X', 'UX'), '랜덤 부스터');
      expect(cleanSubline('BEYBLADE X Tool', 'BEYBLADE_X', 'BX'), '런처 · 도구');
      expect(cleanSubline('BEYBLADE X ???', 'BEYBLADE_X', 'BX'), '');
      expect(cleanSubline('MG', 'MG', 'MG'), '');
    });
  });

  group('세대 묶음', () {
    GuideWork work(String id, String section) =>
        GuideWork(id: id, section: section, name: id, image: '', total: 0, owned: 0);

    test('건담 작품 = 시대 묶음 (처음 나온 순서, 작품 순서 그대로)', () {
      final s = workSections([work('w10', 'UC'), work('w3000', 'SEED'), work('w810', 'UC')]);
      expect([for (final (t, ws) in s) '$t: ${ws.map((w) => w.id).join(' · ')}'], ['UC: w10 · w810', 'SEED: w3000']);
    });

    test('포켓몬 세대 · Fate 작품 · AC · 베이', () {
      expect(worldSectionOf('pokemon', 'pokemon-gen1'), '본편 세대');
      expect(worldSectionOf('pokemon', 'pokemon-pokemon_common'), '공통 굿즈');
      expect(worldSectionOf('armored_core', 'armored_core-ac6'), '시리즈');
      expect(worldSectionOf('beyblade', 'beyblade-bx'), '라인');
      final fate = worldSections('fate', [
        'fate-fgo_fes',
        'fate-tsukihime',
        'fate-fgo_308',
        'fate-fgo_101',
        'fate-fgo_203',
        'fate-stay_night',
        'fate-zero',
      ], (id) => id);
      expect(
        [for (final (t, ids) in fate) '$t: ${ids.join(' · ')}'],
        [
          'Fate 시리즈: fate-stay_night · fate-zero',
          'FGO 1부 · 1.5부: fate-fgo_101 · fate-fgo_203',
          'FGO 2부 · 주장: fate-fgo_308',
          'FGO 이벤트 · 굿즈: fate-fgo_fes',
          'TYPE-MOON · 기타: fate-tsukihime',
        ],
      );
    });

    test('베이 라인 묶음 = 라인이 같은 상품', () {
      expect(beyInWorld(lineKit('a', channel: 'beyblade', line: 'UX'), 'beyblade-ux'), isTrue);
      expect(beyInWorld(lineKit('b', channel: 'beyblade', line: 'BX'), 'beyblade-ux'), isFalse);
    });
  });
}
