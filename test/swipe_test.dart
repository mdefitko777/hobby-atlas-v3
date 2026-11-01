// 좌우 밀기: 캘린더 달 넘기기 · 상세에서 이전 · 다음 상품
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/clock.dart';
import 'package:hobby_atlas/data/user_store.dart';
import 'package:hobby_atlas/detail_pane.dart';
import 'package:hobby_atlas/marks.dart';
import 'package:hobby_atlas/models.dart';
import 'package:hobby_atlas/screens/d_kit_detail_screen.dart';
import 'package:hobby_atlas/screens/h_calendar_screen.dart';
import 'package:hobby_atlas/theme.dart';

import 'layout_test.dart' show db, fakeLoaders;

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildGpTheme(),
      builder: (context, child) => MarksHost(store: UserStore.memory(), child: PaneHost(child: child!)),
      home: home,
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  fixedNow = DateTime(2026, 10, 25, 21);

  testWidgets('캘린더: 달력 위에서 왼쪽으로 밀면 다음 달', (tester) async {
    await _pump(
      tester,
      Scaffold(body: CalendarScreen(myChannels: const ['gundam'], onMyChannelsChanged: (_) {}, loaders: fakeLoaders)),
    );
    expect(find.text('2026년 10월'), findsOneWidget);
    await tester.fling(find.text('15'), const Offset(-300, 0), 1200);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('2026년 11월'), findsOneWidget);
    await tester.fling(find.text('15'), const Offset(300, 0), 1200);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('2026년 10월'), findsOneWidget);
  });

  testWidgets('상세: 목록과 함께 열면 좌우로 다음 상품', (tester) async {
    final kits = [for (final j in (db['kits']! as List).take(3)) Kit.fromJson(j)!];
    await _pump(tester, KitPager(kits: kits, index: 0, loaders: fakeLoaders));
    expect(find.text(kits[0].name), findsWidgets);
    await tester.fling(find.byType(PageView).first, const Offset(-350, 0), 1500);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.text(kits[1].name), findsWidgets);
  });
}
