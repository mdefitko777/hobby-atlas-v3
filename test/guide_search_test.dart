// 검색 탭(B) — 처음 = 전체 상품, 탭 줄 전체 · 종류 · 세대, 검색 = 작품 · 기체 줄 · 기체별 묶기 /
// 컬렉션 탭 줄의 "도감"(F-8), 상품 상세 "도감에서 보기" (D-16)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/clock.dart';
import 'package:hobby_atlas/data/user_store.dart';
import 'package:hobby_atlas/detail_pane.dart';
import 'package:hobby_atlas/marks.dart';
import 'package:hobby_atlas/models.dart';
import 'package:hobby_atlas/screens/b_search_screen.dart';
import 'package:hobby_atlas/screens/d_kit_detail_screen.dart';
import 'package:hobby_atlas/screens/f_collection_screen.dart';
import 'package:hobby_atlas/screens/g_guide_view.dart';
import 'package:hobby_atlas/screens/guide/guide_search.dart';
import 'package:hobby_atlas/theme.dart';
import 'package:hobby_atlas/widgets.dart';

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

Widget _screen() => Scaffold(
  body: SearchScreen(
    myChannels: const ['gundam'],
    onMyChannelsChanged: (_) {},
    onCamera: () {},
    loaders: fakeLoaders,
  ),
);

Widget _collection({CollectionJump jump = CollectionJump.liked, int tick = 0}) => Scaffold(
  body: CollectionScreen(
    myChannels: const ['gundam'],
    onMyChannelsChanged: (_) {},
    onGoSearch: () {},
    loaders: fakeLoaders,
    jump: jump,
    jumpTick: tick,
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

  testWidgets('검색 탭 처음 = 전체 상품 · 탭 줄 전체 · 종류 · 세대 · 검색창 줄은 늘 [필터][격자][목록]', (tester) async {
    await _pump(tester, _screen());
    expect(find.text('전체 상품'), findsOneWidget);
    final row = find.byType(ToolRow).first;
    expect(find.descendant(of: row, matching: find.byType(ToolIcon)), findsNWidgets(3));
    await tester.tap(find.byKey(const ValueKey('view-1')));
    await _settle(tester);
    expect(find.text('전체 상품'), findsNothing);
    expect(find.descendant(of: row, matching: find.byType(ToolIcon)), findsNWidgets(3));
    await tester.tap(find.byKey(const ValueKey('view-0')));
    await _settle(tester);
    expect(find.text('전체 상품'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('컬렉션 탭 줄 끝 "도감" → 도감(내 진행) · 편집 자리에 공유 카드', (tester) async {
    await _pump(tester, _collection());
    expect(find.byType(GuideView), findsNothing);
    await tester.tap(find.byKey(const ValueKey('tab-guide')));
    await _settle(tester);
    expect(find.byType(GuideView), findsOneWidget);
    expect(find.byTooltip('공유 카드'), findsOneWidget);
    expect(find.byTooltip('편집'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('tab-liked')));
    await _settle(tester);
    expect(find.byType(GuideView), findsNothing);
    expect(find.byTooltip('편집'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('컬렉션: 내 정보 Lv(CollectionJump.guide) → 도감 탭으로 열린다', (tester) async {
    await _pump(tester, _collection(jump: CollectionJump.guide));
    expect(find.byType(GuideView), findsNothing);
    await _pump(tester, _collection(jump: CollectionJump.guide, tick: 1));
    expect(find.byType(GuideView), findsOneWidget);
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
