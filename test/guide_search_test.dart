// 도감 탭(B, 검색 + 도감) — 처음 화면 = 도감 둘러보기 · 전체 상품 줄, 검색 = 작품 · 기체 줄 · 기체별 묶기,
// 상품 상세 "도감에서 보기" (D-16), 컬렉션 숫자의 도감 → 도감 탭
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/clock.dart';
import 'package:hobby_atlas/data/user_store.dart';
import 'package:hobby_atlas/detail_pane.dart';
import 'package:hobby_atlas/marks.dart';
import 'package:hobby_atlas/models.dart';
import 'package:hobby_atlas/screens/b_search_screen.dart';
import 'package:hobby_atlas/screens/d_kit_detail_screen.dart';
import 'package:hobby_atlas/screens/g_guide_view.dart';
import 'package:hobby_atlas/screens/guide/guide_search.dart';
import 'package:hobby_atlas/screens/guide/line_guide.dart';
import 'package:hobby_atlas/theme.dart';

import 'layout_test.dart' show db, fakeLoaders;

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildGpTheme(),
      builder: (context, child) => MarksHost(
        store: UserStore.memory(),
        child: PaneHost(child: child!),
      ),
      home: home,
    ),
  );
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Widget _screen({int browseTick = 0}) => Scaffold(
  body: SearchScreen(
    myChannels: const ['gundam'],
    onMyChannelsChanged: (_) {},
    onCamera: () {},
    browseTick: browseTick,
    loaders: fakeLoaders,
  ),
);

void main() {
  fixedNow = DateTime(2026, 10, 25, 21);

  test('작품 · 기체 찾기: 이름이 바로 맞는 기체 먼저 · 상품 없는 기체는 뺀다', () async {
    final index = await fakeLoaders.guideIndex();
    final hits = guideUnitHits(index, '스트라이크 건담');
    expect(hits.first.id, 'g3000u00100');
    expect(hits.every((u) => u.kitIds.isNotEmpty), isTrue);
    expect(index.unitOf('gu12')?.name, '스트라이크 건담');
    expect(guideUnitHits(index, ''), isEmpty);
  });

  testWidgets('처음 화면 = 도감 + "전체 상품 n개" → 펼치면 전체 상품, 돌아가기 = 도감', (tester) async {
    await _pump(tester, _screen());
    expect(find.byType(GuideView), findsOneWidget);
    expect(find.byKey(const ValueKey('all-products')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('all-products')));
    await _settle(tester);
    expect(find.byType(GuideView), findsNothing);
    expect(find.text('전체 상품'), findsOneWidget);
    await tester.tap(find.byTooltip('돌아가기'));
    await _settle(tester);
    expect(find.byType(GuideView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('검색: 맞는 기체 줄 → 도감 기체 시트 · 기체별로 묶기', (tester) async {
    await _pump(tester, _screen());
    await tester.enterText(find.byType(TextField), '스트라이크');
    await _settle(tester);
    expect(find.byKey(const ValueKey('guide-hits')), findsOneWidget);
    expect(find.byKey(const ValueKey('guide-hit-g3000u00100')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('group-toggle')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('grouped-results')), findsOneWidget);
    expect(find.byKey(const ValueKey('unit-head-g3000u00100')), findsOneWidget);

    // 기체 줄 → 그 작품 도감 + 그 기체 시트
    await tester.tap(find.byKey(const ValueKey('guide-hit-g3000u00100')));
    await _settle(tester);
    expect(find.byType(WorkGuideScreen), findsOneWidget);
    expect(find.text('스트라이크 건담'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('검색창 줄의 세대 · 종류 전환 → 종류별 도감', (tester) async {
    await _pump(tester, _screen());
    expect(find.byType(LineGuideView), findsNothing);
    await tester.tap(find.byTooltip('종류별 도감'));
    await _settle(tester);
    expect(find.byType(LineGuideView), findsOneWidget);
    expect(find.byType(GuideView), findsNothing);
    await tester.tap(find.byTooltip('세대별 도감'));
    await _settle(tester);
    expect(find.byType(GuideView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('마지막으로 고른 보기(종류 · 전체 상품)로 다시 열린다 (기기 저장)', (tester) async {
    final store = UserStore.memory();
    Future<void> open() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          theme: buildGpTheme(),
          builder: (context, child) => MarksHost(
            store: store,
            child: PaneHost(child: child!),
          ),
          home: _screen(),
        ),
      );
      await _settle(tester);
    }

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await open();
    expect(find.byType(GuideView), findsOneWidget); // 처음 = 세대
    await tester.tap(find.byTooltip('종류별 도감'));
    await _settle(tester);
    expect(store.guideView, 'type');
    await open();
    expect(find.byType(LineGuideView), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('all-products')));
    await _settle(tester);
    expect(store.guideView, 'all');
    expect(store.localStateJson()['guide_view'], 'all');
    await open();
    expect(find.text('전체 상품'), findsOneWidget);
    expect(UserStore.memory().localStateJson().containsKey('guide_view'), isFalse); // 처음 값은 적지 않는다
  });

  testWidgets('browseTick 이 바뀌면 검색어를 지우고 도감으로', (tester) async {
    await _pump(tester, _screen());
    await tester.enterText(find.byType(TextField), '스트라이크');
    await _settle(tester);
    expect(find.byType(GuideView), findsNothing);
    FocusManager.instance.primaryFocus?.unfocus();
    await _pump(tester, _screen(browseTick: 1));
    expect(find.byType(GuideView), findsOneWidget);
  });

  testWidgets('상품 상세: 건담 상품은 "도감에서 보기" → 그 기체 시트', (tester) async {
    final kit = (db['kits']! as List).map(Kit.fromJson).nonNulls.firstWhere((k) => k.id == 'gu12');
    await _pump(tester, KitDetailScreen(kit: kit, loaders: fakeLoaders));
    final link = find.byKey(const ValueKey('guide-link'));
    await tester.scrollUntilVisible(link, 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('도감에서 보기'), findsOneWidget);
    await tester.tap(link);
    await _settle(tester);
    expect(find.byType(WorkGuideScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
