// 한국 가게가 더 붙은 포켓몬 데이터 (Gunpula nintendo-kr 2026-11-14 모양): 반다이남코코리아(bnkrmall_kr) · 아카데미과학(academy_kr)
// 가격이 일본 상품에 붙으면 두 나라 출처 상품(both)이 되고, 따로 된 한국 상품도 생긴다. 짝짓기 · 카드 수 · 가격 · 기록을 본다
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/api.dart';
import 'package:hobby_atlas/data/catalog.dart';
import 'package:hobby_atlas/data/gunpula.dart';
import 'package:hobby_atlas/data/user_store.dart';
import 'package:hobby_atlas/json_util.dart';
import 'package:hobby_atlas/logic/kit_filter.dart';
import 'package:hobby_atlas/logic/kit_rules.dart';
import 'package:hobby_atlas/models.dart';

Map<String, Object?> _ref(String source, String url) => {'source_id': source, 'url': url, 'confidence': 'high'};

Map<String, Object?> _rec(
  String id,
  List<Map<String, Object?>> refs, {
  String? jan,
  int? jpy,
  int? krw,
  String grade = 'POKE_GOODS',
  String ko = '',
}) => {
  'kit_id': id,
  'franchise': 'pokemon',
  'grade_code': grade,
  'names': {'ko': ko.isEmpty ? id : ko, 'ja': id},
  'jan': ?jan,
  'price_jpy': jpy,
  'price_krw': krw,
  'source_urls': [for (final r in refs) r['url']],
  'source_refs': refs,
};

final _records = [
  // 일본 포켓몬센터 ↔ 한국 포켓몬스토어 (같은 바코드) — 원래 짝
  _rec('pokemon-center-4521329340401', [
    _ref('pokemon_center_jp', 'https://www.pokemoncenter-online.com/4521329340401.html'),
  ], jpy: 1650),
  _rec(
    'pokemon-store-kr-1001',
    [_ref('pokemon_store_kr', 'https://pokemonstore.co.kr/1001')],
    jan: '4521329340401',
    krw: 19000,
  ),
  // 일본 포켓프라에 BNKR 가격이 붙었다 → 두 나라 출처 · 두 정가 (짝 없음)
  _rec(
    'pokepla-01-7148',
    [
      _ref('bandai_spirits_pokepla_jp', 'https://www.bandaispirits.co.jp/detail.php?prd_id=4573102742957000'),
      _ref('bnkrmall_kr', 'https://www.bnkrmall.co.kr/goods/detail.do?gno=1'),
    ],
    jan: '4573102742957',
    jpy: 858,
    krw: 9400,
    grade: 'POKEPLA',
  ),
  // 두 나라 출처 상품과 같은 바코드의 한국 포켓몬스토어 상품 → 한 카드 (한국 쪽)
  _rec(
    'pokepla-02',
    [
      _ref('bandai_spirits_pokepla_jp', 'https://www.bandaispirits.co.jp/detail.php?prd_id=4573102742971000'),
      _ref('bnkrmall_kr', 'https://www.bnkrmall.co.kr/goods/detail.do?gno=2'),
    ],
    jan: '4573102742971',
    jpy: 990,
    krw: 11000,
    grade: 'POKEPLA',
  ),
  _rec(
    'pokemon-store-kr-2002',
    [_ref('pokemon_store_kr', 'https://pokemonstore.co.kr/2002')],
    jan: '4573102742971',
    krw: 12000,
  ),
  // BNKR · 아카데미에만 있는 상품 (한국)
  _rec(
    'bnkr-3003',
    [_ref('bnkrmall_kr', 'https://www.bnkrmall.co.kr/goods/detail.do?gno=3003')],
    jan: '4573102742988',
    krw: 15000,
    grade: 'POKE_FIGURE',
  ),
  _rec(
    'academy-2178',
    [_ref('academy_kr', 'https://academy.co.kr/product/detail.html?product_no=2178')],
    krw: 14000,
    grade: 'POKE_MONCOLLE',
  ),
  // 바코드 없는 몬콜레에 아카데미 가격 → 두 나라 출처, 원 정가만
  _rec(
    'moncolle-x',
    [
      _ref('takara_tomy_pokemon_jp', 'https://www.takaratomy.co.jp/products/pokemon/moncolle_ex/lineup/mega_raichu_x/'),
      _ref('academy_kr', 'https://academy.co.kr/product/detail.html?product_no=2178'),
    ],
    krw: 14000,
    grade: 'POKE_MONCOLLE',
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final slim = mapKitsJob({
    'raw': jsonEncode({'kits': _records}),
  });
  final kits = {for (final m in slim) jStr(m['id']): Kit.fromSlim(m, recentSince: '', monthPrefix: '2026-11')};
  Kit k(String id) => kits[id]!;

  test('파는 나라: _kr 출처만이면 한국, 일본 출처와 같이 있으면 둘 다', () {
    expect(k('pokemon-center-4521329340401').region, 'jp');
    expect(k('pokemon-store-kr-1001').region, 'kr');
    expect(k('pokepla-01-7148').region, 'both');
    expect(k('bnkr-3003').region, 'kr');
    expect(k('academy-2178').region, 'kr');
    expect(k('moncolle-x').region, 'both');
    expect(saleRegion(['bnkrmall_kr', 'academy_kr']), 'kr');
    expect(k('bnkr-3003').brands, ['반다이남코코리아']);
    expect(k('academy-2178').brands, ['아카데미과학']);
  });

  test('두 나라 출처 상품은 다시 짝짓지 않는다 — 제 두 정가 그대로', () {
    final both = k('pokepla-01-7148');
    expect(both.twinId, isEmpty);
    expect((both.priceKrw, both.priceJpy), (9400, 858));
    expect(kitPrice(both), '₩9,400 · ¥858');
    expect(kitPrice(k('moncolle-x')), '₩14,000');
    expect(k('pokemon-store-kr-1001').twinId, 'pokemon-center-4521329340401', reason: '원래 짝은 그대로');
    expect(kitPrice(k('pokemon-store-kr-1001')), '₩19,000 · ¥1,650');
  });

  test('가게 ↗: 두 나라 출처 상품은 한국 줄 = .kr 주소, 일본 줄 = 일본 가게 (첫 출처가 일본 페이지라)', () {
    final both = k('pokepla-01-7148');
    expect(shopUrl(both, kr: true), 'https://www.bnkrmall.co.kr/goods/detail.do?gno=1');
    expect(shopUrl(both, kr: false), startsWith('https://www.bandaispirits.co.jp/'));
    expect(shopUrl(k('moncolle-x'), kr: true), startsWith('https://academy.co.kr/'));
    expect(shopUrl(k('moncolle-x'), kr: false), startsWith('https://www.takaratomy.co.jp/'));
    // 한 나라 상품은 공식 주소 그대로
    expect(shopUrl(k('bnkr-3003'), kr: true), k('bnkr-3003').officialUrl);
    expect(shopUrl(k('pokemon-center-4521329340401'), kr: false), k('pokemon-center-4521329340401').officialUrl);
  });

  test('같은 바코드의 한국 상품이 따로 있으면 한 카드 (한국 쪽), 두 상품의 정가는 덮지 않는다', () {
    final kr = k('pokemon-store-kr-2002');
    final both = k('pokepla-02');
    expect((kr.twinId, both.twinId), ('pokepla-02', 'pokemon-store-kr-2002'));
    expect((isJpTwin(kr), isJpTwin(both)), (false, true));
    expect((kr.priceKrw, kr.priceJpy), (12000, 990), reason: '한국 카드에 없던 엔 정가만 채운다');
    expect((both.priceKrw, both.priceJpy), (11000, 990));
    expect(SaleRegion.jp.shownIn(kr, kits).id, 'pokepla-02');
    expect(SaleRegion.kr.shownIn(kr, kits).id, 'pokemon-store-kr-2002');
    expect(mergeTwins([both, kr]).map((x) => x.id), ['pokemon-store-kr-2002']);
  });

  group('카탈로그', () {
    setUp(() {
      UserStore.instance.debugLoadJson(const <String, Object?>{});
      Catalog.instance.debugSet(slim: [for (final m in slim) Map.of(m)], aux: const {});
    });
    tearDown(() {
      Catalog.instance.debugForget();
      UserStore.instance.debugLoadJson(const <String, Object?>{});
    });

    test('카드는 빠짐도 겹침도 없다: 숨는 쪽은 byId 에만', () {
      final c = Catalog.instance;
      expect(c.kits.map((x) => x.id).toSet(), {
        'pokemon-store-kr-1001',
        'pokepla-01-7148',
        'pokemon-store-kr-2002',
        'bnkr-3003',
        'academy-2178',
        'moncolle-x',
      });
      expect(c.byId.keys.toSet(), kits.keys.toSet());
      expect(hasBothRegions(c.kits), isTrue);
      expect(hasBothCurrencies(c.kits), isTrue);
    });

    test('숨은 두 나라 상품에 적은 좋아요도 한 카드로 보인다', () async {
      UserStore.instance.setStatus('pokepla-02', CollectStatus.wanted);
      expect([for (final x in await fetchCollection()) x.id], ['pokepla-02']);
      UserStore.instance.setStatus('pokemon-store-kr-2002', CollectStatus.wanted);
      expect([for (final x in await fetchCollection()) x.id], ['pokemon-store-kr-2002'], reason: '둘 다 적혀도 한 줄');
    });
  });
}
