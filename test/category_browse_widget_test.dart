// 검색 탭 종류 · 세대 보기 (lib/screens/b_category_browse.dart) + 분류 상품 화면 (b_category_products.dart):
// 왼쪽 묶음 목록(펴기 · 접기 · 기억) · 칸 = 정사각 그림(로고는 바탕색 위 · 없으면 가장 새 상품 사진 · 그것도 없으면 채널 색 + 종류 아이콘)
// + 굵은 이름 · 칸 → 상품 화면 · 세부 시리즈 줄 · 필터 시트 · 검색 탭 필터 · '전체' 채널 · 화면 크기
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

World _world(String id, String label, List<String> kitIds, {String image = ''}) => World(
  id: id,
  franchiseId: id.split('-').first,
  label: label,
  subtitle: '',
  image: image,
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
      _world('pokemon-pokemon_common', '여러 세대 포켓몬 굿즈', ['p2']),
      _world('beyblade-bx', 'BX 라인', const []),
      _world('beyblade-cx', 'CX 라인', const []),
      // atlas 공식 표지 하나 · 「가장 새 상품 사진」 하나 (Gunpula atlas-groups 마도카 묶음 그대로)
      _world('madoka-movie', '극장판', ['md0'], image: 'assets/atlas/covers/madoka-movie.png'),
      _world('madoka-madoka', '마도카', ['md1'], image: 'assets/catalog/madoka/aniplex-01.jpg'),
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

/// 왼쪽 묶음 목록의 묶음 한 줄
Finder _dir(String channel, String title) => find.byKey(ValueKey('dir-$channel-$title'));

final _dirList = find.byKey(const ValueKey('browse-dir'));
final _handle = find.byKey(const ValueKey('dir-handle'));

/// 칸 안 그림 (AppImage = 공식 로고) 경로들
List<String> _logos(WidgetTester t) => t
    .widgetList<AppImage>(find.descendant(of: find.byType(CategoryTile), matching: find.byType(AppImage)))
    .map((i) => i.path)
    .toList();

/// 사진이 없는 상품 (칸이 채널 색 + 종류 아이콘이 되게)
Kit _noPhoto(Kit k) => lineKit(
  k.id,
  channel: k.franchiseId,
  line: k.line,
  type: k.type,
  subline: k.subline,
  date: k.date,
  pb: k.pb,
  image: '',
);

/// 칸 그림 자리를 채운 바탕색 (그림 자리 안 맨 바깥 ColoredBox)
Color? _bg(WidgetTester t, Finder tile) => t
    .widgetList<ColoredBox>(
      find.descendant(
        of: find.descendant(of: tile, matching: find.byType(ClipRRect)),
        matching: find.byType(ColoredBox),
      ),
    )
    .first
    .color;

/// 첫 줄 칸 수 (맨 위 칸과 같은 높이의 칸)
int _firstRow(WidgetTester t) {
  final ys = [for (final e in find.byType(CategoryTile).evaluate()) t.getTopLeft(find.byWidget(e.widget)).dy];
  final top = ys.reduce((a, b) => a < b ? a : b);
  return ys.where((y) => (y - top).abs() < 1).length;
}

void main() {
  fixedNow = DateTime(2026, 10, 25, 21);

  testWidgets('종류: 왼쪽 묶음 목록 · 고른 묶음의 칸만 · 칸은 그림 + 이름 (숫자 · 진행 막대 없음)', (t) async {
    await _show(t, TypeBrowse(channel: 'gundam', loaders: _loaders()));
    expect(_dirList, findsOneWidget);
    expect(_dir('gundam', '프라모델'), findsOneWidget);
    expect(_dir('gundam', '완성품'), findsOneWidget);
    expect(_dir('gundam', 'SD건담'), findsNothing); // 빈 묶음 숨김
    // 처음 = 첫 묶음 (프라모델) 칸만
    expect(_cat('gundam', 'MG'), findsOneWidget);
    expect(_cat('gundam', 'HG'), findsOneWidget);
    expect(_cat('gundam', 'ROBOT魂'), findsNothing);
    expect(_cat('pokemon', '봉제인형'), findsNothing); // 다른 채널은 안 보인다
    // MG → HG (정한 순서)
    expect(t.getTopLeft(_cat('gundam', 'MG')).dx, lessThan(t.getTopLeft(_cat('gundam', 'HG')).dx));
    // 묶음 누르면 그 묶음 칸만
    await t.tap(_dir('gundam', '완성품'));
    await _frames(t, 2);
    expect(_cat('gundam', 'ROBOT魂'), findsOneWidget);
    expect(_cat('gundam', 'HG'), findsNothing);
    // 칸 하나 = 그림 자리 하나 + 이름 (두 줄까지, 낱말 안에서 안 끊음 · 굵게)
    for (final tile in t.widgetList<CategoryTile>(find.byType(CategoryTile))) {
      final texts = t
          .widgetList<Text>(find.descendant(of: find.byWidget(tile), matching: find.byType(Text)))
          .map((w) => w.data)
          .toList();
      expect(texts, [keepWords(tile.name)]);
      expect(tile.nameLines, 2);
      final name = t.widget<KeepWordsText>(
        find.descendant(of: find.byWidget(tile), matching: find.byType(KeepWordsText)),
      );
      expect(name.style?.fontWeight, FontWeight.w700);
      expect(name.textAlign, TextAlign.center);
    }
    // 로고가 없으면 가장 새 상품 사진 (아이콘은 사진도 없을 때)
    final robot = t.widget<CategoryTile>(_cat('gundam', 'ROBOT魂'));
    expect(robot.image, '');
    expect(robot.photo, 'assets/gp/kits/gu01.jpg');
    expect(robot.icon, Icons.accessibility_new_outlined);
    expect(robot.color, Gp.channelColor('gundam'));
    // 숫자 · 개수 · 진행 없음
    final all = t.widgetList<Text>(find.byType(Text)).map((w) => w.data ?? '').toList();
    expect(all.where((s) => RegExp(r'\d').hasMatch(s)), isEmpty);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(t.takeException(), isNull);

    // B-22 칸 머리 ? 는 서랍 › 사용법으로 (그 줄들은 categoryBrowseHelp)
    expect(find.byType(HelpButton), findsNothing);
    expect(categoryBrowseHelp(era: false).any((i) => i.text.contains('공식 라인')), isTrue);
  });

  testWidgets('칸 그림: 공식 로고(lineCovers, 바탕색 lineCoverStyles) → 가장 새 상품 사진 → 종류 아이콘 (line_icons → 칸 키 → 상품 유형)', (
    t,
  ) async {
    lineCovers['gundam'] = {'MG': 'assets/test/mg-logo.png'};
    lineCoverStyles['gundam'] = {'MG': const CoverStyle(bg: 0xFFFFE101)};
    lineIcons['gundam'] = {'ROBOT魂': 'prize', 'HG': 'nope'};
    addTearDown(lineCovers.clear);
    addTearDown(lineCoverStyles.clear);
    addTearDown(lineIcons.clear);
    final kits = [
      ..._kits.where((k) => k.line != 'HG'),
      for (final k in _kits.where((k) => k.line == 'HG')) _noPhoto(k),
    ];
    await _show(t, TypeBrowse(channel: 'gundam', loaders: _loaders(kits)));
    final mg = t.widget<CategoryTile>(_cat('gundam', 'MG'));
    expect(mg.image, 'assets/test/mg-logo.png');
    expect(mg.style?.bg, 0xFFFFE101);
    // 로고 칸: 그 브랜드 바탕색이 칸 가득 · 로고는 칸의 80% 안 (흰 안쪽 칸 · 테두리 없음)
    expect(_bg(t, _cat('gundam', 'MG')), const Color(0xFFFFE101));
    expect(_logos(t), contains('assets/test/mg-logo.png'));
    // 사진도 없는 칸: 채널 색 위 종류 아이콘 — 모르는 종류 이름(nope)은 버리고 상품 유형(프라모델)으로
    expect(t.widget<CategoryTile>(_cat('gundam', 'HG')).image, '');
    expect(t.widget<CategoryTile>(_cat('gundam', 'HG')).photo, '');
    expect(find.descendant(of: _cat('gundam', 'HG'), matching: find.byIcon(Icons.extension_outlined)), findsOneWidget);
    expect(_bg(t, _cat('gundam', 'HG')), Gp.channelColor('gundam'));
    await t.tap(_dir('gundam', '완성품'));
    await _frames(t, 2);
    // Gunpula 가 정한 아이콘 종류가 먼저 (피규어 → 경품) — 사진이 있어도 열리지 않을 때를 위해 아이콘은 정해 둔다
    expect(t.widget<CategoryTile>(_cat('gundam', 'ROBOT魂')).icon, Icons.emoji_events_outlined);
    expect(t.widget<CategoryTile>(_cat('gundam', 'ROBOT魂')).photo, 'assets/gp/kits/gu01.jpg');

    await _show(t, TypeBrowse(channel: 'pokemon', loaders: _loaders()));
    expect(t.widget<CategoryTile>(_cat('pokemon', '봉제인형')).icon, Icons.cruelty_free_outlined);
    expect(_logos(t), ['assets/gp/kits/gu01.jpg']); // 로고가 없어 상품 사진
  });

  testWidgets('묶음 목록 펴기 · 접기: 손잡이 · 밀기, 펴면 한 줄 3칸 · 접으면 4칸 (360dp 폰), 기기에 기억', (t) async {
    final kits = [
      for (final l in ['PG', 'MG', 'RG', 'HG', 'EG', 'RE100']) lineKit('k$l', line: l),
    ];
    const phone = Size(360, 780);
    final store = await _show(
      t,
      TypeBrowse(channel: 'gundam', loaders: _loaders(kits)),
      size: phone,
    );
    expect(store.browseDirOpen, isTrue);
    expect(_dirList, findsOneWidget);
    expect(_firstRow(t), 3);

    // 손잡이 → 접힘 (오른쪽 칸이 화면 가득 4칸)
    await t.tap(_handle);
    await t.pumpAndSettle();
    expect(_dirList, findsNothing);
    expect(_firstRow(t), 4);
    expect(store.browseDirOpen, isFalse);
    expect(store.toJson()['local_state'], containsPair('browse_dir_open', false));

    // 오른쪽으로 밀면 다시 펴짐
    await t.drag(find.byType(CustomScrollView), const Offset(160, 0));
    await t.pumpAndSettle();
    expect(_dirList, findsOneWidget);
    expect(_firstRow(t), 3);
    expect(store.browseDirOpen, isTrue);
    expect(store.toJson()['local_state'], isNot(contains('browse_dir_open'))); // 처음 값은 적지 않는다

    // 왼쪽으로 밀면 접힘
    await t.drag(find.byType(CustomScrollView), const Offset(-160, 0));
    await t.pumpAndSettle();
    expect(_dirList, findsNothing);
    expect(store.browseDirOpen, isFalse);

    // 다시 열어도 접힌 채로 (세대도 같은 기억)
    await _show(
      t,
      EraBrowse(channel: 'gundam', loaders: _loaders()),
      store: store,
      size: phone,
    );
    expect(_dirList, findsNothing);
    expect(find.descendant(of: _handle, matching: find.byIcon(Icons.menu)), findsOneWidget); // 접힌 손잡이
    expect(t.takeException(), isNull);
  });

  testWidgets('넓은 화면은 칸 최소 너비(80dp)만큼 칸이 늘고, 칸 이름 · 아이콘이 칸 안에 든다', (t) async {
    final kits = [
      for (final l in ['PG', 'MG', 'RG', 'HG', 'EG', 'RE100', 'FM', 'MEGA', '옵션 파츠']) lineKit('k$l', line: l),
    ];
    final store = await _show(
      t,
      TypeBrowse(channel: 'gundam', loaders: _loaders(kits)),
      size: const Size(800, 900),
    );
    // 800 - 묶음 목록 108 - 여백 24 = 668 → 8칸 (최대)
    expect(_firstRow(t), 8);
    await t.tap(_handle);
    await t.pumpAndSettle();
    expect(store.browseDirOpen, isFalse);
    expect(_firstRow(t), 8);

    // 360dp 펴짐(칸 약 70dp): 그림 자리는 정사각, 아이콘은 그림 자리보다 작고, 이름은 칸 너비 안 (t12)
    await _show(
      t,
      TypeBrowse(channel: 'gundam', loaders: _loaders([for (final k in kits) _noPhoto(k)])),
      size: const Size(360, 780),
    );
    expect(_dirList, findsOneWidget);
    for (final e in find.byType(CategoryTile).evaluate()) {
      final tile = find.byWidget(e.widget);
      final w = t.getSize(tile).width;
      expect(w, inInclusiveRange(60, 80));
      final art = find.descendant(of: tile, matching: find.byType(AspectRatio));
      expect(t.getSize(art).height, closeTo(w, 0.5));
      final icon = find.descendant(of: tile, matching: find.byType(Icon));
      expect(t.getSize(icon).height, lessThan(w));
      expect(t.getSize(find.descendant(of: tile, matching: find.byType(Text))).width, lessThanOrEqualTo(w));
      // t12 — 칸보다 긴 낱말이 있으면 그 낱말이 한 줄에 들도록 10 까지 줄인다 (fitCategoryName)
      final size = t.widget<KeepWordsText>(find.descendant(of: tile, matching: find.byType(KeepWordsText))).style!;
      expect(size.fontSize!, inInclusiveRange(10, Gp.t12));
    }
    // 접으면(4칸, 칸 약 76dp) 이름이 조금 크게 (t14)
    await t.tap(_handle);
    await t.pumpAndSettle();
    final sizes = <double>[];
    for (final e in find.byType(KeepWordsText).evaluate()) {
      if (find.ancestor(of: find.byWidget(e.widget), matching: find.byType(CategoryTile)).evaluate().isEmpty) continue;
      sizes.add((e.widget as KeepWordsText).style!.fontSize!);
    }
    expect(sizes, everyElement(inInclusiveRange(10, Gp.t14)));
    expect(sizes, contains(Gp.t14), reason: '짧은 이름(HG)은 줄이지 않는다');
    expect(t.takeException(), isNull);
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

  testWidgets('상품 화면 필터 시트: 아이콘 줄 ♡ → 좋아요한 상품만', (t) async {
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
    await t.tap(find.descendant(of: find.byType(GpPickSheet), matching: find.byKey(const ValueKey('toggle-liked'))));
    await t.pumpAndSettle();
    await t.tap(find.text('1개 보기'));
    await t.pumpAndSettle();
    expect(find.byType(ProductTile), findsOneWidget);
    expect(t.widget<FilterButton>(find.byType(FilterButton)).count, 1);
    expect(t.takeException(), isNull);
  });

  testWidgets('검색 탭 필터: 조건이 있으면 맞는 상품이 있는 칸 · 묶음만 · 상품 화면이 그 필터로 시작 (복사)', (t) async {
    final store = UserStore.memory()..setStatus('m1', CollectStatus.wanted);
    final filter = KitFilter(mine: MineState.liked);
    await _show(
      t,
      TypeBrowse(channel: 'gundam', loaders: _loaders(), filter: filter),
      store: store,
    );
    expect(_cat('gundam', 'MG'), findsOneWidget);
    expect(_cat('gundam', 'HG'), findsNothing);
    expect(_dir('gundam', '완성품'), findsNothing); // 빈 묶음도 숨김
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
    expect(find.byType(CategoryTile), findsNWidgets(2)); // 프라모델 묶음 MG · HG
  });

  testWidgets("'전체': 묶음 목록에 채널마다 머리 + 그 묶음 · 채널 머리 → 그 채널 · 내 채널 없음 안내", (t) async {
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
    final pokemonHead = find.byKey(const ValueKey('dir-ch-pokemon'));
    expect(find.byKey(const ValueKey('dir-ch-gundam')), findsOneWidget);
    expect(pokemonHead, findsOneWidget);
    expect(find.byKey(const ValueKey('dir-ch-beyblade')), findsNothing); // 내 채널이 아님
    expect(_cat('gundam', 'HG'), findsOneWidget);
    expect(t.getTopLeft(_dir('gundam', '프라모델')).dy, lessThan(t.getTopLeft(pokemonHead).dy));
    await t.tap(pokemonHead);
    expect(picked, ['pokemon']);
    await t.tap(_dir('pokemon', '피규어 · 봉제인형'));
    await _frames(t, 2);
    expect(_cat('gundam', 'HG'), findsNothing);
    await t.tap(_cat('pokemon', '봉제인형'));
    await _frames(t);
    expect(find.byType(ProductTile), findsNWidgets(3));

    await _show(t, TypeBrowse(channel: allChannelId, loaders: _loaders()));
    expect(find.text('내 채널이 비어 있어요'), findsOneWidget);
  });

  testWidgets('세대 · 건담: 시대 묶음 → 작품 로고 · 상품 없는 작품 숨김 · 작품 → 기체 상품 · 기체별로 묶기', (t) async {
    await _show(t, EraBrowse(channel: 'gundam', loaders: _loaders()));
    expect(_dir('gundam', '우주세기'), findsOneWidget);
    expect(_dir('gundam', '코즈믹 에라'), findsOneWidget);
    expect(_cat('gundam', 'w10'), findsOneWidget);
    expect(_cat('gundam', 'w99'), findsNothing);
    await t.tap(_dir('gundam', '코즈믹 에라'));
    await _frames(t, 2);
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

  testWidgets('세대 · 포켓몬 세대 묶음 / 베이 라인 (라인 로고, 없으면 아이콘 — 베이 사진은 안 쓴다)', (t) async {
    await _show(t, EraBrowse(channel: 'pokemon', loaders: _loaders()));
    expect(_dir('pokemon', '본편 세대'), findsOneWidget);
    expect(_dir('pokemon', '여러 세대'), findsOneWidget);
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
    lineCovers.clear();
    await _show(t, EraBrowse(channel: 'beyblade', loaders: _loaders()));
    expect(t.widget<CategoryTile>(_cat('beyblade', 'beyblade-bx')).image, '');
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

  testWidgets('세대 칸: atlas 공식 표지는 그림 자리, 묶음 그림이 상품 사진이면 그 묶음의 가장 새 상품 사진', (t) async {
    final kits = [
      for (final id in ['md0', 'md1']) lineKit(id, channel: 'madoka', line: '피규어', type: '피규어'),
    ];
    await _show(t, EraBrowse(channel: 'madoka', loaders: _loaders(kits)));
    expect(t.widget<CategoryTile>(_cat('madoka', 'madoka-movie')).image, 'assets/atlas/covers/madoka-movie.png');
    expect(t.widget<CategoryTile>(_cat('madoka', 'madoka-madoka')).image, '');
    expect(t.widget<CategoryTile>(_cat('madoka', 'madoka-madoka')).photo, 'assets/gp/kits/gu01.jpg');
    expect(t.widget<CategoryTile>(_cat('madoka', 'madoka-madoka')).icon, Icons.accessibility_new_outlined);
  });

  testWidgets('로고가 열리지 않으면 회색 칸이 아니라 종류 아이콘', (t) async {
    lineCovers['gundam'] = {'MG': 'assets/test/no-such-logo.png'};
    addTearDown(lineCovers.clear);
    await _show(t, TypeBrowse(channel: 'gundam', loaders: _loaders()));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await _frames(t, 2);
    expect(t.widget<CategoryTile>(_cat('gundam', 'MG')).image, 'assets/test/no-such-logo.png');
    expect(find.descendant(of: _cat('gundam', 'MG'), matching: find.byIcon(Icons.extension_outlined)), findsOneWidget);
    expect(find.descendant(of: _cat('gundam', 'MG'), matching: find.text('MG')), findsOneWidget); // 이름 한 번만
  });

  testWidgets('기기 글자 크기 1.15 · 1.3 에서도 칸 이름 두 줄이 넘치지 않는다', (t) async {
    final kits = [
      for (final l in ['GUNDAM FIX FIGURATION METAL COMPOSITE', 'Hi-Resolution Model', 'METAL ROBOT魂 Ka signature'])
        lineKit(l, line: l, type: '피규어'),
    ];
    for (final scale in const [1.15, 1.3]) {
      for (final width in const [360.0, 411.0]) {
        final store = await _show(
          t,
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
              child: TypeBrowse(channel: 'gundam', loaders: _loaders(kits)),
            ),
          ),
          size: Size(width, 800),
        );
        expect(t.takeException(), isNull, reason: '$scale · $width 폄');
        await t.tap(_handle);
        await t.pumpAndSettle();
        expect(store.browseDirOpen, isFalse);
        expect(t.takeException(), isNull, reason: '$scale · $width 접음');
      }
    }
  });

  testWidgets('320 · 360 · 390 · 768dp: 두 줄 이름이 펴고 접은 칸 안에 든다 (정사각 그림 아래)', (t) async {
    final kits = [
      for (final l in [
        '넨도로이드 · 이치방쿠지 피규어',
        'GUNDAM FIX FIGURATION METAL COMPOSITE',
        'ROBOT魂',
        'METAL ROBOT魂',
        '프라모델 옵션 파츠',
      ])
        lineKit(l, line: l, type: '피규어'),
    ];
    for (final width in const [320.0, 360.0, 390.0, 768.0]) {
      final store = await _show(
        t,
        TypeBrowse(channel: 'gundam', loaders: _loaders(kits)),
        size: Size(width, 800),
      );
      await t.tap(_dir('gundam', '완성품'));
      await _frames(t, 2);
      for (final open in [true, false]) {
        final at = '$width · ${open ? '폄' : '접음'}';
        expect(store.browseDirOpen, open, reason: at);
        expect(t.takeException(), isNull, reason: at);
        var twoLines = false;
        for (final e in find.byType(CategoryTile).evaluate()) {
          final tile = find.byWidget(e.widget);
          final box = t.getRect(tile);
          final text = find.descendant(of: tile, matching: find.byType(KeepWordsText));
          final name = t.getRect(text);
          expect(name.bottom, lessThanOrEqualTo(box.bottom + 0.5), reason: at);
          expect(name.width, lessThanOrEqualTo(box.width + 0.5), reason: at);
          // 글자 크기는 칸 · 긴 낱말에 따라 줄어든다 (fitCategoryName) — 그 크기의 한 줄 높이로 견준다
          final size = t.widget<KeepWordsText>(text).style!.fontSize!;
          if (name.height > size * 1.6) twoLines = true;
        }
        expect(twoLines, isTrue, reason: '$at 두 줄 이름이 있어야 시험이 된다');
        if (open) {
          await t.tap(_handle);
          await t.pumpAndSettle();
        }
      }
    }
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
        await t.tap(_dir('gundam', '코즈믹 에라'));
        await _frames(t, 2);
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
        // 접은 채로도 넘치지 않는다
        await t.tap(_handle);
        await t.pumpAndSettle();
        expect(_dirList, findsNothing);
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
        await t.tap(_dir('gundam', 'SEED'));
        await _frames(t, 2);
        expect(_cat('gundam', 'w3000'), findsOneWidget);
        await t.tap(_cat('gundam', 'w3000'));
        await _frames(t);
        expect(find.byType(ProductTile), findsWidgets);
        expect(t.takeException(), isNull);
      });
    }
  });

  group('분류 칸 그림 (CategoryTile)', () {
    Future<void> tile(WidgetTester t, CategoryTile c) =>
        _show(t, Center(child: SizedBox(width: 80, height: 130, child: c)));

    testWidgets('로고 칸: 바탕색이 칸 가득 · 로고는 80% 안 contain · 테두리 없이 옅은 그림자', (t) async {
      await tile(
        t,
        CategoryTile(
          key: const ValueKey('logo'),
          image: 'assets/test/bx.png',
          style: const CoverStyle(bg: 0xFF70BBE9),
          photo: 'assets/gp/kits/gu01.jpg',
          name: 'BX',
          onTap: () {},
        ),
      );
      final c = find.byKey(const ValueKey('logo'));
      expect(_bg(t, c), const Color(0xFF70BBE9));
      final box = t.widget<FractionallySizedBox>(find.descendant(of: c, matching: find.byType(FractionallySizedBox)));
      expect([box.widthFactor, box.heightFactor], [0.8, 0.8]);
      expect(t.widget<AppImage>(find.descendant(of: c, matching: find.byType(AppImage))).fit, BoxFit.contain);
      final deco = t
          .widgetList<DecoratedBox>(find.descendant(of: c, matching: find.byType(DecoratedBox)))
          .map((d) => d.decoration as BoxDecoration)
          .firstWhere((d) => d.boxShadow != null);
      expect(deco.border, isNull);
      expect(deco.boxShadow, Gp.tileShadow);
      // 바탕색이 없는 로고(G제네 작품 로고)는 흰 바탕 — 회색 칸이 아니다
      await tile(
        t,
        CategoryTile(key: const ValueKey('plain-logo'), image: 'assets/test/w10.png', name: '건담', onTap: () {}),
      );
      expect(_bg(t, find.byKey(const ValueKey('plain-logo'))), Gp.panel);
    });

    testWidgets('로고가 없으면 가장 새 상품 사진이 칸 가득 (cover)', (t) async {
      await tile(
        t,
        CategoryTile(
          key: const ValueKey('photo'),
          image: '',
          photo: 'assets/gp/kits/gu01.jpg',
          color: Gp.channelColor('gundam'),
          icon: Icons.extension_outlined,
          name: 'HG',
          onTap: () {},
        ),
      );
      final c = find.byKey(const ValueKey('photo'));
      final img = t.widget<AppImage>(find.descendant(of: c, matching: find.byType(AppImage)));
      expect(img.path, 'assets/gp/kits/gu01.jpg');
      expect(img.fit, BoxFit.cover);
      expect(find.descendant(of: c, matching: find.byType(FractionallySizedBox)), findsNothing);
      // 받는 동안 · 못 열면 회색 대신 채널 색 (위에 아이콘)
      expect(_bg(t, c), Gp.channelColor('gundam'));
      // 키 비주얼(로고가 아닌 공식 그림)도 칸 가득
      await tile(
        t,
        CategoryTile(
          key: const ValueKey('visual'),
          image: 'assets/atlas/covers/pokemon-gen1.webp',
          style: const CoverStyle(logo: false, bg: 0xFF958A75),
          name: '1세대',
          onTap: () {},
        ),
      );
      final v = find.byKey(const ValueKey('visual'));
      expect(t.widget<AppImage>(find.descendant(of: v, matching: find.byType(AppImage)).first).fit, BoxFit.cover);
      expect(find.descendant(of: v, matching: find.byType(FractionallySizedBox)), findsNothing);
    });

    testWidgets('로고도 사진도 없으면 채널 색(회색 아님) 위 흰 아이콘 · 밝은 바탕색이면 검정 아이콘', (t) async {
      await tile(
        t,
        CategoryTile(
          key: const ValueKey('plain'),
          image: '',
          color: Gp.channelColor('pokemon'),
          icon: Icons.cruelty_free_outlined,
          name: '봉제인형',
          onTap: () {},
        ),
      );
      final c = find.byKey(const ValueKey('plain'));
      expect(_bg(t, c), Gp.channelColor('pokemon'));
      expect(find.descendant(of: c, matching: find.byType(AppImage)), findsNothing);
      expect(
        t.widget<Icon>(find.descendant(of: c, matching: find.byIcon(Icons.cruelty_free_outlined))).color,
        Colors.white,
      );
      for (final ch in ['gundam', 'beyblade', 'pokemon', 'lego', 'nintendo', 'effects', 'zoids']) {
        final col = Gp.channelColor(ch);
        expect(col.r == col.g && col.g == col.b, isFalse, reason: '$ch 색이 회색');
      }
      // atlas 바탕색 + fg dark → 검정 아이콘
      await tile(
        t,
        CategoryTile(
          key: const ValueKey('light'),
          image: '',
          style: CoverStyle.parse(bg: '#fcf3cf', fg: 'dark'),
          icon: Icons.category_outlined,
          name: '굿즈',
          onTap: () {},
        ),
      );
      final l = find.byKey(const ValueKey('light'));
      expect(_bg(t, l), const Color(0xFFFCF3CF));
      expect(t.widget<Icon>(find.descendant(of: l, matching: find.byIcon(Icons.category_outlined))).color, Gp.ink);
    });
  });
}
