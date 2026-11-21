// 필터 아이콘 줄 (좋아요 · 구매함 · 발매 예정 · 나라) 과 필터 시트에서 빈 칸 숨기기 (2026-11-19 실데이터 감사):
// 시트 위 네 줄을 검색창 아래로 · 뺀 칸(아직 없음 · 이번 달 · 발매됨 · 판매) · 0 개인 종류 · 값 하나뿐인 라인 · 작품 · 정가 없는 가격
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/api.dart';
import 'package:hobby_atlas/clock.dart';
import 'package:hobby_atlas/data/user_store.dart';
import 'package:hobby_atlas/detail_pane.dart';
import 'package:hobby_atlas/marks.dart';
import 'package:hobby_atlas/models.dart';
import 'package:hobby_atlas/screens/b_search_screen.dart';
import 'package:hobby_atlas/theme.dart';
import 'package:hobby_atlas/widgets.dart';

Kit _k(
  String id, {
  String channel = 'gundam',
  String line = 'HG',
  String type = '프라모델',
  String date = '2024-01-01',
  String region = '',
  int? jpy,
  int? krw,
  String work = '',
  String goodsKind = '',
}) => Kit(
  id: id,
  franchiseId: channel,
  name: '$line $id',
  nameJa: '',
  series: work,
  seriesKey: work,
  line: line,
  type: type,
  scale: '',
  universe: '',
  date: date,
  priceJpy: jpy,
  priceKrw: krw,
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
  region: region,
  goodsKind: goodsKind,
);

final _gundam = [
  _k('hg1', jpy: 2200, work: 'SEED'),
  _k('hg2', jpy: 2500, work: 'SEED', date: '2027-03-01'),
  _k('mg1', line: 'MG', jpy: 5000, work: 'SEED'),
  _k('rb1', line: 'ROBOT魂', type: '피규어', jpy: 8000, work: 'SEED'),
];

final _pokemon = [
  _k('kr1', channel: 'pokemon', line: '봉제인형', type: '인형', region: 'kr', krw: 20000),
  _k('jp1', channel: 'pokemon', line: '봉제인형', type: '인형', region: 'jp', jpy: 1650),
];

/// 작품이 둘인 목록 (작품 줄 · 라인 줄이 같이 보인다)
final _twoWorks = [..._gundam, _k('hg3', work: '00'), _k('mg2', line: 'MG', work: '00')];

Future<UserStore> _show(WidgetTester t, Widget body, {UserStore? store}) async {
  t.view.physicalSize = const Size(390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final s = store ?? UserStore.memory();
  await t.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      theme: buildGpTheme(),
      builder: (context, child) => MarksHost(
        store: s,
        child: PaneHost(child: child!),
      ),
      home: Scaffold(body: body),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 250));
  }
  return s;
}

Finder _key(String k) => find.byKey(ValueKey(k));

/// 종류 체크 칸에 보이는 값
List<String> _typeValues(WidgetTester t) => t.widget<CheckGrid>(_key('filter-types')).values;

void main() {
  fixedNow = DateTime(2026, 11, 19, 12);

  group('규칙', () {
    test('뺀 칸(아직 없음 · 이번 달 · 발매됨 · 판매)은 dropHidden 이 푼다 · 발매 예정 · 좋아요는 그대로', () {
      final f = KitFilter(mine: MineState.none, release: ReleaseState.thisMonth, sale: SaleState.pb);
      expect(f.dropHidden(), isTrue);
      expect((f.mine, f.release, f.sale), (MineState.any, ReleaseState.any, SaleState.any));
      expect(KitFilter(release: ReleaseState.released).dropHidden(), isTrue);
      final keep = KitFilter(mine: MineState.liked, release: ReleaseState.upcoming, region: SaleRegion.kr);
      expect(keep.dropHidden(), isFalse);
      expect((keep.mine, keep.release, keep.region), (MineState.liked, ReleaseState.upcoming, SaleRegion.kr));
    });

    test('시트 초기화: 아이콘 줄(좋아요 · 발매 예정 · 나라)도 시트 안이라 같이 푼다', () {
      final f = KitFilter(
        mine: MineState.liked,
        release: ReleaseState.upcoming,
        region: SaleRegion.kr,
        lines: {'HG'},
        price: PriceBand.values.last,
      )..clear();
      expect(f.count, 0);
    });

    test('굿즈를 풀면 숨는 굿즈 종류도 푼다 (보이지 않는 조건이 종류 칸을 굿즈 하나로 줄이지 않게)', () {
      final f = KitFilter(goodsKinds: {'의류'});
      expect(f.dropHidden(), isTrue);
      expect(f.goodsKinds, isEmpty);
      final goods = KitFilter(types: {goodsType}, goodsKinds: {'의류'});
      expect(goods.dropHidden(), isFalse);
      expect(goods.goodsKinds, {'의류'});
    });

    test('필터 버튼 숫자: 아이콘 줄 조건도 센다', () {
      final f = KitFilter(mine: MineState.owned, release: ReleaseState.upcoming, region: SaleRegion.jp, lines: {'HG'});
      expect(f.count, 4);
    });

    test('체크 칸 값: 다른 조건과 겹쳐 0 이 되는 값은 빼고, 이미 고른 값은 남긴다', () {
      final upcoming = KitFilter(release: ReleaseState.upcoming);
      expect(liveValues(_gundam, upcoming, (k) => k.type, (f) => f.types), ['프라모델']);
      expect(liveValues(_gundam, upcoming, (k) => k.line, (f) => f.lines), ['HG']);
      // 자기 줄의 고른 값은 거르지 않는다 (HG 를 골라도 MG · ROBOT魂 이 그대로)
      expect(
        liveValues(_gundam, KitFilter(lines: {'HG'}), (k) => k.line, (f) => f.lines),
        unorderedEquals(['HG', 'MG', 'ROBOT魂']),
      );
      // 고른 값은 맞는 상품이 없어도 풀 수 있게 남는다
      expect(
        liveValues(_gundam, KitFilter(release: ReleaseState.upcoming, types: {'피규어'}), (k) => k.type, (f) => f.types),
        ['프라모델', '피규어'],
      );
    });

    test('제외: 뺀 값은 고른 값을 보기 전에 떨어뜨린다 · 한 값은 고르기 · 빼기 중 한쪽만', () {
      final f = KitFilter(linesOut: {'MG'});
      expect(_gundam.where(f.matches).map((k) => k.id), ['hg1', 'hg2', 'rb1']);
      expect(f.count, 1);
      // 같은 줄에 고른 값 · 뺀 값이 겹치면 빼기가 이긴다 (화면에서는 겹치지 않지만 규칙을 정해 둔다)
      expect(KitFilter(lines: {'HG', 'MG'}, linesOut: {'MG'}).matches(_gundam[2]), isFalse);
      // 고르기 → 빼기 → 풀기
      final g = KitFilter();
      togglePick(g.lines, g.linesOut, 'HG');
      expect(g.lines, {'HG'});
      expect(g.linesOut, isEmpty);
      togglePick(g.linesOut, g.lines, 'HG');
      expect(g.lines, isEmpty);
      expect(g.linesOut, {'HG'});
      togglePick(g.linesOut, g.lines, 'HG');
      expect(g.count, 0);
    });

    test('제외도 복사 · 초기화 · 고른 조건 한 줄 · 굿즈를 풀 때 같이 풀린다', () {
      final f = KitFilter(worksOut: {'SEED'}, typesOut: {'피규어'}, linesOut: {'MG'}, goodsKindsOut: {'의류'});
      expect(f.labels, contains('MG 제외'));
      // 한 줄에서 뺀 값이 여럿이면 접은 줄 요약과 같은 한 덩이로 (줄마다 「… 제외」 를 따로 쓰지 않는다)
      expect(KitFilter(linesOut: {'MG', 'HG'}).labels, ['MG · HG 제외']);
      expect(KitFilter(linesOut: {'MG', 'HG', 'RG'}).labels, ['MG 외 2 제외']);
      final c = f.copy();
      expect(c.count, 4);
      c.linesOut.add('RG');
      expect(f.linesOut, {'MG'}); // 깊은 복사 (초안을 고쳐도 원래 조건은 그대로)
      expect(c.dropHidden(), isTrue); // 굿즈를 고르지 않았으면 굿즈 종류 제외도 푼다
      expect(c.goodsKindsOut, isEmpty);
      f.clear();
      expect(f.count, 0);
    });

    test('체크 칸 값: 뺀 값도 풀 수 있게 남는다', () {
      expect(
        liveValues(_gundam, KitFilter(linesOut: {'MG'}), (k) => k.line, (f) => f.lines, outField: (f) => f.linesOut),
        unorderedEquals(['HG', 'MG', 'ROBOT魂']),
      );
    });

    test('값 하나뿐인 줄 숨김 · 정가가 없는 목록', () {
      expect(showChoices(['SEED'], {}), isFalse);
      expect(showChoices(['HG'], {}, {'MG'}), isTrue); // 뺀 것이 있으면 풀 수 있게 둔다
      expect(showChoices(['SEED'], {'SEED'}), isTrue);
      expect(showChoices(['HG', 'MG'], {}), isTrue);
      expect(showChoices([], {}), isFalse);
      expect(hasAnyPrice(_gundam), isTrue);
      expect(hasAnyPrice([_k('lego', channel: 'lego', line: '세트', type: '세트')]), isFalse);
    });
  });

  group('필터 시트', () {
    testWidgets('위 네 줄 대신 아이콘 줄 · 판매 · 이번 달 · 아직 없음 칸은 없다', (t) async {
      await _show(t, FilterSheet(kits: _gundam, initial: KitFilter()));
      expect(_key('filter-toggles'), findsOneWidget);
      expect(_key('toggle-liked'), findsOneWidget);
      expect(_key('toggle-owned'), findsOneWidget);
      expect(_key('toggle-upcoming'), findsOneWidget);
      expect(_key('toggle-region'), findsNothing); // 한 나라뿐
      expect(find.byType(SquareSegments<MineState>), findsNothing);
      expect(find.byType(SquareSegments<ReleaseState>), findsNothing);
      expect(find.byType(SquareSegments<SaleState>), findsNothing);
      expect(find.byType(SquareSegments<SaleRegion>), findsNothing);
      expect(find.byType(MineStateLabel), findsNothing);
      // 남는 것: 종류 체크 → 라인 · 작품(값 하나라 숨김) · 기간 · 가격
      expect(_key('filter-types'), findsOneWidget);
      expect(_key('filter-lines'), findsOneWidget);
      expect(_key('filter-works'), findsNothing);
      expect(_key('filter-price'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('아이콘 줄을 켜면 0 개가 된 종류 칸 · 값 하나가 된 라인 줄은 숨는다', (t) async {
      await _show(t, FilterSheet(kits: _gundam, initial: KitFilter()));
      expect(_typeValues(t), unorderedEquals(['프라모델', '피규어']));
      await t.tap(_key('toggle-upcoming'));
      await t.pump();
      expect(_typeValues(t), ['프라모델']); // 발매 예정 피규어가 없다 — 회색 칸 대신 숨김
      expect(_key('filter-lines'), findsNothing); // HG 하나뿐
      // 다시 누르면 풀린다
      await t.tap(_key('toggle-upcoming'));
      await t.pump();
      expect(_typeValues(t), hasLength(2));
      expect(_key('filter-lines'), findsOneWidget);
    });

    testWidgets('정가가 하나도 없으면 가격 줄 숨김 · 나라가 섞이면 나라 아이콘', (t) async {
      final lego = [
        _k('l1', channel: 'lego', line: '세트', type: '세트'),
        _k('l2', channel: 'lego', line: '미니피규어', type: '피규어'),
      ];
      await _show(t, FilterSheet(kits: lego, initial: KitFilter()));
      expect(_key('filter-price'), findsNothing);

      await _show(t, FilterSheet(kits: _pokemon, initial: KitFilter()));
      expect(_key('toggle-region'), findsOneWidget);
      expect(_key('filter-price'), findsOneWidget);
    });

    testWidgets('시트 초기화는 맨 위 아이콘 줄(발매 예정)까지 끈다 — 줄이 시트 안에 있다', (t) async {
      KitFilter? picked;
      final initial = KitFilter(release: ReleaseState.upcoming, lines: {'MG'});
      await _show(
        t,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => picked = await showFilterSheet(context, kits: _gundam, initial: initial),
            child: const Text('open'),
          ),
        ),
      );
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      // 초기화 (시트 머리) → 보기
      await t.tap(find.descendant(of: find.byType(SectionHeader), matching: find.byType(TextButton)));
      await t.pump();
      await t.tap(find.descendant(of: find.byType(GpPickSheet), matching: find.byType(GradientButton)));
      await t.pumpAndSettle();
      expect((picked?.release, picked?.count), (ReleaseState.any, 0));
    });

    testWidgets('굿즈 → 의류 → 굿즈 풀기: 굿즈 종류도 풀려 종류 칸이 다 보인다', (t) async {
      final kits = [..._gundam, _k('g1', type: goodsType, line: '굿즈', goodsKind: '의류')];
      await _show(
        t,
        FilterSheet(
          kits: kits,
          initial: KitFilter(types: {goodsType}, goodsKinds: {'의류'}),
        ),
      );
      expect(_typeValues(t), hasLength(1)); // 굿즈 + 의류만 맞는다
      await t.tap(find.descendant(of: _key('filter-types'), matching: find.text(goodsType)));
      await t.pump();
      expect(_typeValues(t), unorderedEquals(['프라모델', '피규어', '굿즈']));
    });

    testWidgets('작품 줄이 라인 줄 위 · 작품 하나를 고르면 제목이 「필터 · SEED」', (t) async {
      await _show(
        t,
        FilterSheet(
          kits: _twoWorks,
          initial: KitFilter(works: {'SEED'}),
        ),
      );
      expect(t.getTopLeft(_key('filter-works')).dy, lessThan(t.getTopLeft(_key('filter-lines')).dy));
      expect(t.widget<GpPickSheet>(find.byType(GpPickSheet)).title, '필터 · SEED');

      await _show(
        t,
        FilterSheet(
          kits: _twoWorks,
          initial: KitFilter(works: {'SEED', '00'}),
        ),
      );
      expect(t.widget<GpPickSheet>(find.byType(GpPickSheet)).title, '필터'); // 둘 이상이면 그냥 필터
    });

    testWidgets('종류 칸의 × 는 그 종류를 빼고, 이름을 누르면 빼기가 풀려 고르기로 바뀐다', (t) async {
      await _show(t, FilterSheet(kits: _gundam, initial: KitFilter()));
      expect(find.text('4개 보기'), findsOneWidget);
      t.widget<CheckGrid>(_key('filter-types')).onExclude!('피규어');
      await t.pump();
      expect(t.widget<CheckGrid>(_key('filter-types')).excluded, {'피규어'});
      expect(find.text('3개 보기'), findsOneWidget); // ROBOT魂 피규어가 빠진다
      t.widget<CheckGrid>(_key('filter-types')).onToggle('피규어');
      await t.pump();
      final grid = t.widget<CheckGrid>(_key('filter-types'));
      expect(grid.excluded, isEmpty);
      expect(grid.selected, {'피규어'});
      expect(find.text('1개 보기'), findsOneWidget);
    });

    testWidgets('접은 라인 줄 요약에 뺀 값이 보인다 (MG · HG 제외)', (t) async {
      await _show(
        t,
        FilterSheet(
          kits: _gundam,
          initial: KitFilter(linesOut: {'MG', 'HG'}),
        ),
      );
      expect(t.widget<ExpandRow>(_key('filter-lines')).summary, 'MG · HG 제외');
    });

    testWidgets('뺀 칸이 걸린 조건으로 열면 풀린다 (보이지 않는 조건에 갇히지 않게)', (t) async {
      final hidden = KitFilter(sale: SaleState.base, release: ReleaseState.thisMonth, mine: MineState.none);
      await _show(t, FilterSheet(kits: _gundam, initial: hidden));
      expect(find.text('4개 보기'), findsOneWidget);
    });
  });

  group('검색 탭: ♡ · 구매함 · 발매 예정 · 나라는 필터 시트 맨 위 (2026-11-21 검색창 아래 줄을 시트로 되돌림)', () {
    Widget search(List<Kit> kits, List<String> channels) => SearchScreen(
      myChannels: channels,
      onMyChannelsChanged: (_) {},
      onCamera: () {},
      loaders: Loaders(
        kits: (ids) async => [
          for (final k in kits)
            if (ids.contains(k.franchiseId)) k,
        ],
      ),
    );

    /// 필터 시트를 열고 [then] 을 누른 뒤 "n개 보기"
    Future<void> pick(WidgetTester t, List<Finder> then) async {
      await t.tap(find.byType(FilterButton));
      await t.pumpAndSettle();
      expect(find.descendant(of: find.byType(GpPickSheet), matching: _key('filter-toggles')), findsOneWidget);
      for (final f in then) {
        await t.tap(f);
        await t.pump(const Duration(milliseconds: 300));
      }
      await t.tap(find.textContaining(RegExp(r'^\d+개 보기$')));
      await t.pumpAndSettle();
    }

    testWidgets('탭에는 검색창 · 아이콘 줄이 없고, 시트의 ♡ 를 고르면 목록이 거른다 · 필터 숫자에도 센다', (t) async {
      final store = UserStore.memory()..setStatus('hg1', CollectStatus.wanted);
      await _show(t, search(_gundam, const ['gundam']), store: store);
      expect(find.byType(GpSearchBar), findsNothing);
      expect(_key('filter-toggles'), findsNothing); // 시트 밖에는 없다
      expect(find.byType(ProductTile), findsNWidgets(4));
      await pick(t, [_key('toggle-liked')]);
      expect(find.byType(ProductTile), findsOneWidget);
      expect(t.widget<FilterButton>(find.byType(FilterButton)).count, 1);
      expect(t.takeException(), isNull);
    });

    testWidgets('포켓몬(한국 · 일본): 시트의 나라 아이콘 전체 → 한국 → 일본', (t) async {
      await _show(t, search(_pokemon, const ['pokemon']));
      expect(find.byType(ProductTile), findsNWidgets(2));
      await pick(t, [_key('toggle-region')]);
      expect(t.widget<ProductTile>(find.byType(ProductTile)).id, 'kr1');
      await pick(t, [_key('toggle-region')]);
      expect(t.widget<ProductTile>(find.byType(ProductTile)).id, 'jp1');
      expect(t.takeException(), isNull);
    });
  });
}
