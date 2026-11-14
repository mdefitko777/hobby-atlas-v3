// 한국 · 일본 정가와 같은 바코드 짝 — 진짜 가격만(₩ · ¥, 환산 없음) · 짝은 한 카드 · 나라 필터 · 원/엔 가격대 · 가격순
// 데이터 규칙: lib/data/gunpula.dart saleRegion · pairTwins, 화면 규칙: lib/logic/kit_rules.dart · kit_filter.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/api.dart';
import 'package:hobby_atlas/clock.dart';
import 'package:hobby_atlas/data/catalog.dart';
import 'package:hobby_atlas/data/gunpula.dart';
import 'package:hobby_atlas/data/user_store.dart';
import 'package:hobby_atlas/detail_pane.dart';
import 'package:hobby_atlas/l10n/l10n.dart';
import 'package:hobby_atlas/logic/kit_rules.dart';
import 'package:hobby_atlas/marks.dart';
import 'package:hobby_atlas/models.dart';
import 'package:hobby_atlas/screens/d_kit_detail_screen.dart';
import 'package:hobby_atlas/screens/o_see_all_screen.dart';
import 'package:hobby_atlas/theme.dart';
import 'package:hobby_atlas/widgets.dart';

// 실제 데이터 모양 (2026-11-14 kits-pokemon.json): 한국 = pokemon_store_kr · price_krw 만, 일본 = price_jpy 만
Map<String, Object?> _raw(
  String id, {
  required String source,
  int? krw,
  int? jpy,
  String? jan,
  List<String> cachedFrom = const [],
  List<String> urls = const [],
  String ko = '',
  String ja = '',
}) => {
  'kit_id': id,
  'franchise': 'pokemon',
  'grade_code': 'POKE_PLUSH',
  'names': {'ko': ko.isEmpty ? id : ko, 'ja': ja.isEmpty ? (ko.isEmpty ? id : ko) : ja},
  'images': {'cached_from': cachedFrom},
  'price_krw': krw,
  'price_jpy': jpy,
  'jan': ?jan,
  'source_urls': urls,
  'source_refs': [
    {'source_id': source},
  ],
};

List<Map<String, Object?>> _mapped() => mapKitsJob({
  'raw': jsonEncode({
    'kits': [
      // 사진 원래 파일 이름이 바코드인 한국 상품 ↔ 일본 포켓몬센터
      _raw(
        'pokemon-kr-1',
        source: 'pokemon_store_kr',
        krw: 20000,
        ko: '늪짱이',
        cachedFrom: ['https://shopby-images.cdn-nhncommerce.com/20250822/164518.8/4521329340401.jpg'],
      ),
      _raw('pokemon-center-4521329340401', source: 'pokemon_center_jp', jpy: 1540, ko: '늪짱이', ja: 'ヌマクロー'),
      // 같은 바코드의 다른 일본 상품 — 포켓몬센터 쪽이 먼저 짝이 된다
      _raw(
        'pokemon-gacha-1',
        source: 'bandai_gashapon_products_jp',
        jpy: 500,
        urls: ['https://example.jp/item/4521329340401'],
      ),
      // jan 칸으로
      _raw('pokemon-kr-2', source: 'pokemon_store_kr', krw: 17000, jan: '4521329280738'),
      _raw('pokemon-center-4521329280738', source: 'pokemon_center_jp', jpy: 1650),
      // 짝 없음
      _raw('pokemon-kr-3', source: 'pokemon_store_kr', krw: 38000),
      _raw('pokemon-center-4521329316130', source: 'pokemon_center_jp', jpy: 1650),
    ],
  }),
});

Kit _k(String id, {String region = '', String twin = '', int? krw, int? jpy, String channel = 'pokemon'}) => Kit(
  id: id,
  franchiseId: channel,
  name: 'N $id',
  nameJa: '',
  series: '',
  line: '봉제인형',
  type: '인형',
  scale: '',
  universe: '',
  date: '2026-11-01',
  priceJpy: jpy,
  image: 'assets/gp/kits/gu01.jpg',
  gallery: const [],
  limited: false,
  pb: false,
  status: CollectStatus.none,
  wantedQty: 0,
  recent: false,
  month: false,
  market: null,
  keywords: const [],
  priceKrw: krw,
  region: region,
  twinId: twin,
  officialUrl: 'https://shop.example/$id',
  blob: 'n $id',
);

// 짝 한 쌍 (짝끼리 가격을 채운 뒤의 모양) + 한국만 · 일본만 · 가격 없음 · 건담(엔만)
final _kr = _k('kr', region: 'kr', twin: 'jp', krw: 19000, jpy: 1650);
final _jp = _k('jp', region: 'jp', twin: 'kr', krw: 19000, jpy: 1650);
final _krOnly = _k('kr-only', region: 'kr', krw: 20000);
final _krBig = _k('kr-big', region: 'kr', krw: 150000);
final _jpOnly = _k('jp-only', region: 'jp', jpy: 900);
final _jpMid = _k('jp-mid', region: 'jp', jpy: 4000);
final _none = _k('none', region: 'jp');
final _gundam = _k('hg', region: 'jp', jpy: 2200, channel: 'gundam');

void main() {
  fixedNow = DateTime(2026, 11, 14, 12);

  group('데이터: 나라 · 짝', () {
    test('출처 사이트 → 파는 나라', () {
      expect(saleRegion(['pokemon_store_kr']), 'kr');
      expect(saleRegion(['bnkr_kr']), 'kr'); // 앞으로 들어올 한국 가게도 _kr 로
      expect(saleRegion(['pokemon_center_jp', 'bandai_hobby_pokemon_global']), 'jp');
      expect(saleRegion(['pokemon_store_kr', 'pokemon_center_jp']), 'both');
      expect(saleRegion(['rebrickable_lego']), '');
      expect(saleRegion(['manual_seed']), '');
      expect(saleRegion(const []), '');
    });

    test('같은 바코드 → 짝 · 서로 없는 나라 가격(진짜 값) · 일본어로도 한국 카드가 찾힌다', () {
      final m = {for (final j in _mapped()) j['id']: j};
      final kr1 = m['pokemon-kr-1']!;
      final jp1 = m['pokemon-center-4521329340401']!;
      expect(kr1['region'], 'kr');
      expect(jp1['region'], 'jp');
      expect(kr1['jan'], '4521329340401'); // 사진 원래 주소에서
      expect(kr1['twin'], 'pokemon-center-4521329340401'); // 같은 바코드 가샤폰보다 포켓몬센터
      expect(jp1['twin'], 'pokemon-kr-1');
      expect(m['pokemon-gacha-1']!['twin'], isNull);
      expect((kr1['priceKrw'], kr1['priceJpy']), (20000, 1540));
      expect((jp1['priceKrw'], jp1['priceJpy']), (20000, 1540));
      expect(kr1['nameJa'], 'ヌマクロー');
      expect(Kit.fromSlim(kr1, recentSince: '', monthPrefix: '2026-11').blob, contains('ヌマクロー'));
      // jan 칸
      expect(m['pokemon-kr-2']!['twin'], 'pokemon-center-4521329280738');
      expect(m['pokemon-center-4521329280738']!['priceKrw'], 17000);
      // 짝 없음
      expect(m['pokemon-kr-3']!['twin'], isNull);
      expect(m['pokemon-center-4521329316130']!['twin'], isNull);
      expect(m['pokemon-kr-3']!['priceJpy'], isNull); // 환산해서 채우지 않는다
    });

    test('카탈로그: 둘러보는 목록에는 한국 쪽 하나, byId 에는 둘 다 · 지출용 정가는 한국 정가 그대로', () {
      TestWidgetsFlutterBinding.ensureInitialized();
      Catalog.instance.debugSet(slim: _mapped(), aux: const {});
      final c = Catalog.instance;
      final shown = c.kits.map((k) => k.id).toSet();
      expect(shown, containsAll(['pokemon-kr-1', 'pokemon-kr-2', 'pokemon-kr-3', 'pokemon-gacha-1']));
      expect(shown, isNot(contains('pokemon-center-4521329340401')));
      expect(shown, isNot(contains('pokemon-center-4521329280738')));
      expect(shown, contains('pokemon-center-4521329316130')); // 짝 없는 일본 상품은 그대로
      expect(c.byId['pokemon-center-4521329340401']?.twinId, 'pokemon-kr-1');
      expect(c.listPriceKrw('pokemon-kr-3'), 38000);
      expect(c.listPriceKrw('pokemon-center-4521329340401'), 20000); // 짝의 한국 정가
      expect(c.listPriceKrw('pokemon-center-4521329316130'), (1650 * c.jpyToKrw).round()); // 지출 합계에만
      // 나라 필터: 한국 = 한국 상품 + 짝, 일본 = 일본 상품 + 짝 → 한 나라만 보면 그 나라 쪽 상품으로
      final kr = c.kits.where((k) => SaleRegion.kr.hit(k)).map((k) => k.id);
      expect(kr, unorderedEquals(['pokemon-kr-1', 'pokemon-kr-2', 'pokemon-kr-3']));
      final jp = [
        for (final k in c.kits)
          if (SaleRegion.jp.hit(k)) SaleRegion.jp.shownIn(k, c.byId).id,
      ];
      expect(
        jp,
        unorderedEquals([
          'pokemon-center-4521329340401',
          'pokemon-center-4521329280738',
          'pokemon-gacha-1',
          'pokemon-center-4521329316130',
        ]),
      );
    });
  });

  group('정가 글자 (환산 없음)', () {
    test('짝 = 둘 다 (제 나라 돈이 앞) · 하나면 그것 · 없으면 가격 미정', () {
      expect(kitPrice(_kr), '₩19,000 · ¥1,650');
      expect(kitPrice(_jp), '¥1,650 · ₩19,000');
      expect(kitPrice(_krOnly), '₩20,000');
      expect(kitPrice(_jpOnly), '¥900');
      expect(kitPrice(_none), '가격 미정');
      expect(kitPriceParts(_kr), ['₩19,000', '¥1,650']);
      for (final k in [_kr, _jp, _krOnly, _jpOnly]) {
        expect(kitPrice(k), isNot(contains('≈')));
        expect(kitPrice(k), isNot(contains('원')));
      }
    });

    test('좋아요 합계: 상품마다 제 나라 돈 하나로 (원 · 엔 따로)', () {
      final t = priceTotals([_kr, _krOnly, _jpOnly, _none], (k) => k == _krOnly ? 2 : 1);
      expect(t, (krw: 19000 + 40000, jpy: 900));
    });

    test('짝이 둘 다 든 목록은 한국 쪽만', () {
      expect(mergeTwins([_jp, _kr, _jpOnly]).map((k) => k.id), ['kr', 'jp-only']);
      expect(mergeTwins([_jp, _jpOnly]).map((k) => k.id), ['jp', 'jp-only']); // 한국 쪽이 없으면 그대로
    });
  });

  group('필터 · 정렬', () {
    final pool = [_kr, _krOnly, _krBig, _jpOnly, _jpMid, _none];

    test('가격대: 고른 돈의 진짜 정가로 — 짝은 원 · 엔 어느 쪽으로도', () {
      expect(PriceBand.low.hit(_krOnly, PriceCurrency.krw), isTrue); // ₩20,000 ≤ 3만
      expect(PriceBand.low.hit(_krOnly, PriceCurrency.jpy), isFalse); // 엔 정가가 없다 (환산하지 않음)
      expect(PriceBand.high.hit(_krBig, PriceCurrency.krw), isTrue);
      expect(PriceBand.mid.hit(_jpMid, PriceCurrency.jpy), isTrue);
      expect(PriceBand.low.hit(_kr, PriceCurrency.krw), isTrue);
      expect(PriceBand.low.hit(_kr, PriceCurrency.jpy), isTrue);
      expect(PriceBand.low.hit(_jpOnly, null), isTrue); // 돈을 안 정했으면 제 나라 칸으로
      expect(PriceBand.any.hit(_none, PriceCurrency.krw), isTrue);
      final f = KitFilter(price: PriceBand.low, currency: PriceCurrency.krw);
      expect(pool.where(f.matches).map((k) => k.id), ['kr', 'kr-only']);
      expect(f.labels, ['3만원 이하']);
      f.currency = PriceCurrency.jpy;
      expect(pool.where(f.matches).map((k) => k.id), ['kr', 'jp-only']);
      expect(f.labels, ['¥3,000 이하']);
    });

    test('시트 칸 가격대는 짧게 — 360dp 네 칸에 중국어도 다 들어가게 (돈 이름은 위 칸에)', () {
      L10n.debugSet(AppLang.zh);
      addTearDown(() => L10n.debugSet(AppLang.ko));
      final krw = [for (final b in PriceBand.values) b.shortIn(PriceCurrency.krw)];
      expect(krw, ['全部', '₩3万以下', '3万–10万', '₩10万以上']);
      expect(krw.every((s) => s.runes.length <= 6), isTrue);
      expect(PriceBand.mid.labelIn(PriceCurrency.krw), '3万–10万韩元'); // 고른 조건 줄은 돈까지
    });

    test('가격의 돈: 고른 것이 목록에 없으면 원, 원이 없는 목록(건담)은 엔', () {
      expect(currencyFor(pool, null), PriceCurrency.krw);
      expect(currencyFor(pool, PriceCurrency.jpy), PriceCurrency.jpy);
      expect(currencyFor([_gundam], PriceCurrency.krw), PriceCurrency.jpy);
      expect(hasBothCurrencies(pool), isTrue);
      expect(hasBothCurrencies([_gundam, _jpOnly]), isFalse);
      expect(KitFilter(region: SaleRegion.jp).preferredCurrency, PriceCurrency.jpy);
    });

    test('가격순: 원 정가로 먼저, 엔만 있는 상품은 그 뒤에 엔으로, 정가 없음은 끝 (섞어 환산하지 않음)', () {
      List<String> sorted(PriceCurrency c, {bool high = false}) =>
          ([...pool]..sort((a, b) => comparePrice(a, b, c, high: high))).map((k) => k.id).toList();
      expect(sorted(PriceCurrency.krw), ['kr', 'kr-only', 'kr-big', 'jp-only', 'jp-mid', 'none']);
      expect(sorted(PriceCurrency.krw, high: true), ['kr-big', 'kr-only', 'kr', 'jp-mid', 'jp-only', 'none']);
      expect(sorted(PriceCurrency.jpy), ['jp-only', 'kr', 'jp-mid', 'kr-only', 'kr-big', 'none']);
    });

    test('나라: 한국 · 일본 (짝은 둘 다) · 세기 · 초기화 · 복사', () {
      final f = KitFilter(region: SaleRegion.kr);
      expect(pool.where(f.matches).map((k) => k.id), ['kr', 'kr-only', 'kr-big']);
      f.region = SaleRegion.jp;
      expect(pool.where(f.matches).map((k) => k.id), ['kr', 'jp-only', 'jp-mid', 'none']);
      expect(f.count, 1);
      expect(f.labels, ['일본']);
      expect(f.copy().region, SaleRegion.jp);
      f.clear();
      expect((f.region, f.currency, f.count), (SaleRegion.any, null, 0));
      expect(hasBothRegions(pool), isTrue);
      expect(hasBothRegions([_gundam, _jpOnly]), isFalse);
      expect(SaleRegion.jp.shownIn(_kr, {'jp': _jp}).id, 'jp');
      expect(SaleRegion.kr.shownIn(_jp, {'kr': _kr}).id, 'kr');
      expect(SaleRegion.any.shownIn(_jp, {'kr': _kr}).id, 'jp');
    });
  });

  group('좋아요 · 구매함: 짝의 어느 id 에 적힌 기록이든 한 카드에', () {
    Future<Marks Function()> pumpMarks(WidgetTester t, UserStore store) async {
      late BuildContext ctx;
      await t.pumpWidget(
        MarksHost(
          store: store,
          child: Builder(
            builder: (c) {
              ctx = c;
              Marks.of(c);
              return const SizedBox();
            },
          ),
        ),
      );
      return () => Marks.read(ctx);
    }

    testWidgets('일본 쪽 좋아요 → 한국 카드에 ♡ · 끄면 일본 쪽 기록을 지운다', (t) async {
      final store = UserStore.memory()..setStatus('jp', CollectStatus.wanted);
      final m = await pumpMarks(t, store);
      expect(m().liked(_kr), isTrue);
      expect(m().holderId(_kr), 'jp');
      m().set(_kr, liked: false);
      await t.pump();
      expect(store.statusOf('jp'), CollectStatus.none);
      expect(store.statusOf('kr'), isNull); // 중복 기록을 만들지 않는다
      expect(m().liked(_kr), isFalse);
      // 아무 쪽에도 기록이 없으면 누른 카드 id 에
      m().set(_kr, owned: true);
      await t.pump();
      expect(store.statusOf('kr'), CollectStatus.owned);
      expect(m().owned(_jp), isTrue);
    });

    testWidgets('둘 다 기록이 있으면 센 쪽(구매함) · 바꾸면 둘 다', (t) async {
      final store = UserStore.memory()
        ..setStatus('kr', CollectStatus.wanted)
        ..setStatus('jp', CollectStatus.owned);
      final m = await pumpMarks(t, store);
      expect(m().owned(_kr), isTrue);
      m().set(_kr, owned: false);
      await t.pump();
      expect((store.statusOf('kr'), store.statusOf('jp')), (CollectStatus.none, CollectStatus.none));
    });
  });

  group('화면', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      Catalog.instance.debugSet(
        slim: [
          for (final k in [_kr, _jp, _krOnly, _jpOnly, _gundam])
            {
              'id': k.id,
              'franchiseId': k.franchiseId,
              'name': k.name,
              'date': k.date,
              'priceKrw': k.priceKrw,
              'priceJpy': k.priceJpy,
              'region': k.region,
              'twin': k.twinId,
              'officialUrl': k.officialUrl,
            },
        ],
        aux: const {},
      );
    });

    Future<void> show(WidgetTester t, Widget home, {UserStore? store, double width = 360}) async {
      t.view.physicalSize = Size(width, 780);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          key: UniqueKey(),
          theme: buildGpTheme(),
          builder: (context, child) => MarksHost(
            store: store ?? UserStore.memory(),
            child: PaneHost(child: child!),
          ),
          home: Scaffold(body: home),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await t.pump(const Duration(milliseconds: 250));
      }
    }

    for (final lang in AppLang.values) {
      testWidgets('360dp 격자: 짝은 한 카드 · 두 정가가 넘치지 않는다 · 일본 쪽 ♡ 가 한국 카드에 (${lang.name})', (t) async {
        L10n.debugSet(lang);
        addTearDown(() => L10n.debugSet(AppLang.ko));
        final store = UserStore.memory()..setStatus('jp', CollectStatus.wanted);
        await show(
          t,
          SectionListView(title: '포켓몬', kits: [_kr, _jp, _krOnly, _jpOnly, _gundam]),
          store: store,
        );
        final ids = t.widgetList<ProductTile>(find.byType(ProductTile)).map((p) => p.id).toList();
        expect(ids, ['kr', 'kr-only', 'jp-only', 'hg']);
        final tile = t.widget<ProductTile>(find.byType(ProductTile).first);
        expect(tile.subtitle, startsWith('₩19,000'));
        expect(tile.note, '¥1,650');
        expect(find.byIcon(Icons.favorite), findsOneWidget);
        expect(find.textContaining('≈'), findsNothing);
        expect(t.takeException(), isNull);
        // 목록 줄도 두 정가 (둘째는 아래 작은 줄)
        await t.tap(find.byIcon(Icons.view_list_outlined));
        await t.pump(const Duration(milliseconds: 300));
        final price = find.byType(KitPriceLines).first;
        expect(find.descendant(of: price, matching: find.text('₩19,000')), findsOneWidget);
        expect(find.descendant(of: price, matching: find.text('¥1,650')), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('일본만 보면 짝은 일본 쪽 상품 (¥ 먼저)', (t) async {
      final tools = ListTools()..filter = KitFilter(region: SaleRegion.jp);
      await show(t, SectionListView(title: '포켓몬', kits: [_kr, _krOnly, _jpOnly], tools: tools));
      final tiles = t.widgetList<ProductTile>(find.byType(ProductTile)).toList();
      expect(tiles.map((p) => p.id), ['jp', 'jp-only']);
      expect(tiles.first.subtitle, startsWith('¥1,650'));
      expect(tiles.first.note, '₩19,000');
    });

    testWidgets('필터 시트: 두 나라 · 두 돈이 섞인 목록에만 나라 · 돈 칸 · 체크 칸에 개수 없음', (t) async {
      await show(t, FilterSheet(kits: [_kr, _krOnly, _jpOnly], initial: KitFilter()));
      expect(find.byKey(const ValueKey('filter-region')), findsOneWidget);
      await t.tap(find.text(tr('가격')));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('filter-currency')), findsOneWidget);
      // 종류 체크 칸 — 이름만 (숫자 없음)
      final checks = t.widgetList<Text>(find.descendant(of: find.byType(CheckGrid), matching: find.byType(Text)));
      expect(checks.map((w) => w.data ?? '').where((s) => RegExp(r'^\d+$').hasMatch(s)), isEmpty);

      await show(t, FilterSheet(kits: [_gundam], initial: KitFilter()));
      expect(find.byKey(const ValueKey('filter-region')), findsNothing);
      await t.tap(find.text(tr('가격')));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('filter-currency')), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('상세: 짝은 한국 정가 크게 + 일본 정가 작게, 줄마다 ↗ (360dp, 환산값 없음)', (t) async {
      await show(
        t,
        KitDetailScreen(
          kit: _kr,
          loaders: Loaders(kits: (_) async => [_kr, _krOnly], kitsByIds: (_) async => const []),
        ),
      );
      expect(find.text('₩19,000'), findsOneWidget);
      expect(find.text('${tr('일본')} ¥1,650'), findsOneWidget);
      expect(find.byKey(const ValueKey('price-link-kr')), findsOneWidget);
      expect(find.byKey(const ValueKey('price-link-jp')), findsOneWidget);
      expect(find.textContaining('≈'), findsNothing);
      expect(t.takeException(), isNull);

      // 한 나라 정가만: ↗ 없이 그 정가만
      await show(
        t,
        KitDetailScreen(
          kit: _krOnly,
          loaders: Loaders(kits: (_) async => [_krOnly], kitsByIds: (_) async => const []),
        ),
      );
      expect(find.text('₩20,000'), findsOneWidget);
      expect(find.byKey(const ValueKey('price-link-kr')), findsNothing);
      expect(t.takeException(), isNull);
    });
  });
}
