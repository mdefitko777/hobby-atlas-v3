// 검색 탭 종류 · 세대 보기 (lib/screens/b_category_browse.dart) + 분류 상품 화면 (b_category_products.dart):
// 칸 = 그림 + 이름만 · 묶음 머리 · 공식 그림 · 칸 → 상품 화면 · 세부 시리즈 줄 · 필터 시트 · 검색 탭 필터 · '전체' 채널 · 화면 크기
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/api.dart';
import 'package:hobby_atlas/channels.dart';
import 'package:hobby_atlas/clock.dart';
import 'package:hobby_atlas/data/user_store.dart';
import 'package:hobby_atlas/detail_pane.dart';
import 'package:hobby_atlas/marks.dart';
import 'package:hobby_atlas/models.dart';
import 'package:hobby_atlas/screens/b_category_browse.dart';
import 'package:hobby_atlas/screens/b_category_products.dart';
import 'package:hobby_atlas/screens/c_channel_screen.dart' show allChannelId;
import 'package:hobby_atlas/theme.dart';
import 'package:hobby_atlas/widgets.dart';

import 'layout_test.dart' show fakeLoaders;
import 'support/line_kits.dart';

final _kits = [
  for (var i = 0; i < 3; i++) lineKit('uc$i', subline: 'HGUC', date: '2024-0${i + 1}-01'),
  for (var i = 0; i < 2; i++) lineKit('ce$i', subline: 'HGCE', date: '2023-0${i + 1}-01'),
  lineKit('hgpb', pb: true, date: '2022-01-01'),
  for (var i = 0; i < 3; i++) lineKit('m$i', line: 'MG', date: '2021-0${i + 1}-01'),
  lineKit('rb', line: 'ROBOT魂', type: '피규어'),
  for (var i = 0; i < 3; i++) lineKit('p$i', channel: 'pokemon', line: '봉제인형', type: '인형'),
  for (var i = 0; i < 2; i++) lineKit('bx$i', channel: 'beyblade', line: 'BX', type: '배틀 토이', subline: '스타터'),
];

GuideUnit _unit(String id, String work, List<String> kitIds) =>
    GuideUnit(id: id, workId: work, name: '기체 $id', nameEn: '', image: '', status: CollectStatus.none, kitIds: kitIds);

final _units = {
  'w10': [
    _unit('u1', 'w10', ['uc0', 'uc1']),
  ],
  'w3000': [
    _unit('u2', 'w3000', ['ce0', 'ce1']),
    _unit('u3', 'w3000', ['m0', 'nope']),
  ],
};

GuideWork _work(String id, String section, String name) =>
    GuideWork(id: id, section: section, name: name, image: 'assets/test/$id.png', total: 0, owned: 0);

World _world(String id, String label, List<String> kitIds) => World(
  id: id,
  franchiseId: id.split('-').first,
  label: label,
  subtitle: '',
  image: '',
  total: 0,
  owned: 0,
  kitIds: kitIds,
);

Loaders _loaders([List<Kit>? kits]) => Loaders(
  kits: (ids) async => [
    for (final k in kits ?? _kits)
      if (ids.contains(k.franchiseId)) k,
  ],
  guideWorks: () async => [
    _work('w10', '우주세기', '기동전사 건담'),
    _work('w3000', '코즈믹 에라', '건담 SEED'),
    _work('w99', '우주세기', '상품 없는 작품'),
  ],
  guideUnits: (id) async => _units[id] ?? const [],
  guideIndex: () async => GuideIndex(
    units: {
      for (final us in _units.values)
        for (final u in us) u.id: u,
    },
    unitsByKit: {
      for (final us in _units.values)
        for (final u in us)
          for (final k in u.kitIds) k: [u.id],
    },
  ),
  worlds: (c) async => [
    for (final w in [
      _world('pokemon-gen1', '1세대', ['p0', 'p1']),
      _world('pokemon-gen2', '2세대', const []),
      _world('pokemon-pokemon_common', '포켓몬 공통 굿즈', ['p2']),
      _world('beyblade-bx', 'BX 라인', const []),
      _world('beyblade-cx', 'CX 라인', const []),
    ])
      if (w.franchiseId == c) w,
  ],
);

Future<void> _frames(WidgetTester t, [int n = 6]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 250));
  }
}

Future<UserStore> _show(WidgetTester t, Widget body, {Size size = const Size(390, 844), UserStore? store}) async {
  t.view.physicalSize = size;
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
  await _frames(t);
  return s;
}

Finder _cat(String channel, String key) => find.byKey(ValueKey('cat-$channel-$key'));

void main() {
  fixedNow = DateTime(2026, 10, 25, 21);

  testWidgets('종류: 묶음 머리 아래 칸 · 칸은 공식 그림 + 이름만 (숫자 · 진행 막대 없음)', (t) async {
    await _show(t, TypeBrowse(channel: 'gundam', loaders: _loaders()));
    expect(find.text('프라모델'), findsOneWidget);
    expect(find.text('완성품 피규어'), findsOneWidget);
    expect(_cat('gundam', 'MG'), findsOneWidget);
    expect(_cat('gundam', 'HG'), findsOneWidget);
    expect(_cat('gundam', 'ROBOT魂'), findsOneWidget);
    expect(_cat('pokemon', '봉제인형'), findsNothing); // 다른 채널은 안 보인다
    expect(find.text('SD'), findsNothing); // 빈 묶음 숨김
    // MG → HG (정한 순서), 완성품 묶음은 아래
    expect(t.getTopLeft(_cat('gundam', 'MG')).dx, lessThan(t.getTopLeft(_cat('gundam', 'HG')).dx));
    expect(t.getTopLeft(_cat('gundam', 'ROBOT魂')).dy, greaterThan(t.getTopLeft(_cat('gundam', 'HG')).dy));
    // 칸 하나 = 그림 하나 + 이름 한 줄
    for (final tile in t.widgetList<CategoryTile>(find.byType(CategoryTile))) {
      final texts = t
          .widgetList<Text>(find.descendant(of: find.byWidget(tile), matching: find.byType(Text)))
          .map((w) => w.data)
          .toList();
      expect(texts, [tile.name]);
    }
    expect(find.descendant(of: find.byType(CategoryTile), matching: find.byType(AppImage)), findsNWidgets(3));
    // 숫자 · 개수 · 진행 없음
    final all = t.widgetList<Text>(find.byType(Text)).map((w) => w.data ?? '').toList();
    expect(all.where((s) => RegExp(r'\d').hasMatch(s)), isEmpty);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(t.takeException(), isNull);

    // B-22 ?
    await t.tap(find.byTooltip(HelpButton.tip));
    await t.pumpAndSettle();
    expect(find.textContaining('공식 라인'), findsOneWidget);
  });

  testWidgets('종류 칸 그림: lineCovers 공식 로고가 먼저, 없으면 최근 상품', (t) async {
    lineCovers['gundam'] = {'MG': 'assets/test/mg-logo.png'};
    addTearDown(lineCovers.clear);
    await _show(t, TypeBrowse(channel: 'gundam', loaders: _loaders()));
    expect(t.widget<CategoryTile>(_cat('gundam', 'MG')).image, 'assets/test/mg-logo.png');
    expect(t.widget<CategoryTile>(_cat('gundam', 'HG')).image, 'assets/gp/kits/gu01.jpg');
  });

  testWidgets('칸 → 상품 화면: 검색 결과와 같은 격자 · 세부 시리즈 줄로 거르기', (t) async {
    await _show(t, TypeBrowse(channel: 'gundam', loaders: _loaders()));
    await t.tap(_cat('gundam', 'HG'));
    await _frames(t);
    expect(find.byType(CategoryProductsScreen), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'HG'), findsOneWidget);
    expect(find.byType(GpSearchBar), findsOneWidget);
    expect(find.byType(ProductTile), findsNWidgets(6));
    for (final c in ['', 'HGUC', 'HGCE', 'PB 한정']) {
      expect(find.byKey(ValueKey('sub-$c')), findsOneWidget);
    }
    await t.tap(find.byKey(const ValueKey('sub-HGUC')));
    await _frames(t, 2);
    expect(find.byType(ProductTile), findsNWidgets(3));
    await t.tap(find.byKey(const ValueKey('sub-PB 한정')));
    await _frames(t, 2);
    expect(find.byType(ProductTile), findsOneWidget);
    // 찾기
    await t.tap(find.byKey(const ValueKey('sub-')));
    await t.enterText(find.byType(TextField), 'uc1');
    await _frames(t, 2);
    expect(find.byType(ProductTile), findsOneWidget);
    expect(t.takeException(), isNull);

    // MG 는 세부 시리즈가 없어 줄도 없다
    await _show(t, TypeBrowse(channel: 'gundam', loaders: _loaders()));
    await t.tap(_cat('gundam', 'MG'));
    await _frames(t);
    expect(find.byKey(const ValueKey('sub-')), findsNothing);
    expect(find.byType(ProductTile), findsNWidgets(3));
  });

  testWidgets('상품 화면 필터 시트: 상태 = 좋아요 → 좋아요한 상품만', (t) async {
    final store = UserStore.memory()..setStatus('uc0', CollectStatus.wanted);
    await _show(
      t,
      TypeBrowse(channel: 'gundam', loaders: _loaders()),
      store: store,
    );
    await t.tap(_cat('gundam', 'HG'));
    await _frames(t);
    await t.tap(find.byTooltip('필터'));
    await t.pumpAndSettle();
    await t.tap(find.descendant(of: find.byType(GpPickSheet), matching: find.byType(LikedIcon)));
    await t.pumpAndSettle();
    await t.tap(find.text('1개 보기'));
    await t.pumpAndSettle();
    expect(find.byType(ProductTile), findsOneWidget);
    expect(t.widget<FilterButton>(find.byType(FilterButton)).count, 1);
    expect(t.takeException(), isNull);
  });

  testWidgets('검색 탭 필터: 조건이 있으면 맞는 상품이 있는 칸만 · 상품 화면이 그 필터로 시작 (복사)', (t) async {
    final store = UserStore.memory()..setStatus('m1', CollectStatus.wanted);
    final filter = KitFilter(mine: MineState.liked);
    await _show(
      t,
      TypeBrowse(channel: 'gundam', loaders: _loaders(), filter: filter),
      store: store,
    );
    expect(_cat('gundam', 'MG'), findsOneWidget);
    expect(_cat('gundam', 'HG'), findsNothing);
    expect(_cat('gundam', 'ROBOT魂'), findsNothing);
    expect(find.text('완성품 피규어'), findsNothing); // 빈 묶음도 숨김
    await t.tap(_cat('gundam', 'MG'));
    await _frames(t);
    expect(find.byType(ProductTile), findsOneWidget);
    expect(t.widget<FilterButton>(find.byType(FilterButton)).count, 1);
    // 상품 화면에서 필터를 지워도 검색 탭 필터는 그대로
    await t.tap(find.byIcon(Icons.close).last);
    await _frames(t, 2);
    expect(find.byType(ProductTile), findsNWidgets(3));
    expect(filter.mine, MineState.liked);

    // 맞는 칸이 없으면 안내 · 조건이 없으면 전부
    await _show(
      t,
      TypeBrowse(
        channel: 'gundam',
        loaders: _loaders(),
        filter: KitFilter(mine: MineState.owned),
      ),
    );
    expect(find.text('이 조건의 상품이 없어요'), findsOneWidget);
    await _show(t, TypeBrowse(channel: 'gundam', loaders: _loaders(), filter: KitFilter()));
    expect(find.byType(CategoryTile), findsNWidgets(3));
  });

  testWidgets("'전체': 내 채널마다 덩어리 · 채널 머리 → 그 채널 · 내 채널 없음 안내", (t) async {
    final picked = <String>[];
    await _show(
      t,
      TypeBrowse(
        channel: allChannelId,
        loaders: _loaders(),
        myChannels: const ['gundam', 'pokemon'],
        onPickChannel: picked.add,
      ),
    );
    expect(find.text('건담'), findsOneWidget);
    expect(find.text('포켓몬'), findsOneWidget);
    expect(_cat('gundam', 'HG'), findsOneWidget);
    expect(_cat('pokemon', '봉제인형'), findsOneWidget);
    expect(_cat('beyblade', '스타터'), findsNothing); // 내 채널이 아님
    await t.tap(find.text('포켓몬'));
    expect(picked, ['pokemon']);
    await t.tap(_cat('pokemon', '봉제인형'));
    await _frames(t);
    expect(find.byType(ProductTile), findsNWidgets(3));

    await _show(t, TypeBrowse(channel: allChannelId, loaders: _loaders()));
    expect(find.text('내 채널이 비어 있어요'), findsOneWidget);
  });

  testWidgets('세대 · 건담: 시대 묶음 아래 작품 로고 · 상품 없는 작품 숨김 · 작품 → 기체 상품 · 기체별로 묶기', (t) async {
    await _show(t, EraBrowse(channel: 'gundam', loaders: _loaders()));
    expect(find.text('우주세기'), findsOneWidget);
    expect(find.text('코즈믹 에라'), findsOneWidget);
    expect(_cat('gundam', 'w10'), findsOneWidget);
    expect(_cat('gundam', 'w99'), findsNothing);
    expect(t.widget<CategoryTile>(_cat('gundam', 'w3000')).image, 'assets/test/w3000.png');
    await t.tap(_cat('gundam', 'w3000'));
    await _frames(t);
    expect(find.widgetWithText(AppBar, '건담 SEED'), findsOneWidget);
    expect(find.byType(ProductTile), findsNWidgets(3)); // ce0 · ce1 · m0 (없는 상품은 뺀다)
    expect(find.byKey(const ValueKey('sub-HGCE')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('group-toggle')));
    await _frames(t);
    expect(find.byKey(const ValueKey('grouped-results')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('세대 · 포켓몬 세대 묶음 / 베이 라인 (라인 로고)', (t) async {
    await _show(t, EraBrowse(channel: 'pokemon', loaders: _loaders()));
    expect(find.text('본편 세대'), findsOneWidget);
    expect(find.text('공통 굿즈'), findsOneWidget);
    expect(_cat('pokemon', 'pokemon-gen1'), findsOneWidget);
    expect(_cat('pokemon', 'pokemon-gen2'), findsNothing);
    await t.tap(_cat('pokemon', 'pokemon-gen1'));
    await _frames(t);
    expect(find.byType(ProductTile), findsNWidgets(2));
    expect(find.byKey(const ValueKey('group-toggle')), findsNothing); // 건담 작품만

    lineCovers['beyblade'] = {'BX': 'assets/test/bx.png'};
    addTearDown(lineCovers.clear);
    await _show(t, EraBrowse(channel: 'beyblade', loaders: _loaders()));
    expect(t.widget<CategoryTile>(_cat('beyblade', 'beyblade-bx')).image, 'assets/test/bx.png');
    expect(_cat('beyblade', 'beyblade-cx'), findsNothing);
    await t.tap(_cat('beyblade', 'beyblade-bx'));
    await _frames(t);
    expect(find.byType(ProductTile), findsNWidgets(2));
  });

  testWidgets('큰 칸 (HG 1400): 상품 화면이 보이는 것만 그리고 끝까지 스크롤된다', (t) async {
    final big = [
      for (var i = 0; i < 1400; i++)
        lineKit('b$i', subline: i.isEven ? 'HGUC' : 'HGCE', date: '${2000 + i % 25}-0${i % 9 + 1}-01'),
    ];
    await _show(t, CategoryProductsScreen(title: 'HG', kits: big, loaders: _loaders(big)));
    expect(find.byType(ProductTile).evaluate().length, lessThan(60));
    for (var i = 0; i < 6; i++) {
      await t.fling(find.byType(CustomScrollView), const Offset(0, -4000), 6000);
      await _frames(t, 2);
    }
    expect(t.takeException(), isNull);
  });

  group('폰 크기', () {
    for (final size in const [Size(320, 568), Size(390, 844)]) {
      final name = '${size.width.toInt()}×${size.height.toInt()}';
      testWidgets('$name 종류 · 세대 · 상품 화면 (세부 시리즈 줄 + 기체별로 묶기)', (t) async {
        await _show(
          t,
          TypeBrowse(channel: 'gundam', loaders: _loaders()),
          size: size,
        );
        expect(t.takeException(), isNull);
        await t.tap(_cat('gundam', 'HG'));
        await _frames(t);
        expect(t.takeException(), isNull);
        await t.tap(find.byTooltip('목록으로 보기'));
        await _frames(t, 2);
        expect(find.byType(ThumbRow), findsWidgets);
        expect(t.takeException(), isNull);

        await _show(
          t,
          EraBrowse(channel: 'gundam', loaders: _loaders()),
          size: size,
        );
        await t.tap(_cat('gundam', 'w3000'));
        await _frames(t);
        await t.tap(find.byKey(const ValueKey('group-toggle')));
        await _frames(t);
        expect(find.byKey(const ValueKey('grouped-results')), findsOneWidget);
        expect(t.takeException(), isNull);

        await _show(
          t,
          TypeBrowse(channel: allChannelId, loaders: _loaders(), myChannels: const ['gundam', 'pokemon', 'beyblade']),
          size: size,
        );
        expect(t.takeException(), isNull);
      });

      testWidgets('$name db.json', (t) async {
        await _show(
          t,
          TypeBrowse(channel: 'gundam', loaders: fakeLoaders),
          size: size,
        );
        expect(_cat('gundam', 'HG'), findsOneWidget);
        await t.tap(_cat('gundam', 'HG'));
        await _frames(t);
        expect(find.byType(ProductTile), findsWidgets);
        expect(t.takeException(), isNull);
        await _show(
          t,
          TypeBrowse(
            channel: allChannelId,
            loaders: fakeLoaders,
            myChannels: const ['gundam', 'beyblade', 'pokemon', 'armored_core', 'fate'],
          ),
          size: size,
        );
        expect(t.takeException(), isNull);
        await _show(
          t,
          EraBrowse(channel: 'gundam', loaders: fakeLoaders),
          size: size,
        );
        expect(_cat('gundam', 'w3000'), findsOneWidget);
        await t.tap(_cat('gundam', 'w3000'));
        await _frames(t);
        expect(find.byType(ProductTile), findsWidgets);
        expect(t.takeException(), isNull);
      });
    }
  });
}
