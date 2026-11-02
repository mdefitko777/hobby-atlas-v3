// ? 도움말 (lib/widgets/help.dart) — 버튼 하나 · 시트 줄 · 화면마다 같은 자리에 있는지
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/clock.dart';
import 'package:hobby_atlas/data/user_store.dart';
import 'package:hobby_atlas/detail_pane.dart';
import 'package:hobby_atlas/marks.dart';
import 'package:hobby_atlas/models.dart';
import 'package:hobby_atlas/screens/d_kit_detail_screen.dart';
import 'package:hobby_atlas/screens/b_search_screen.dart' show searchHelp;
import 'package:hobby_atlas/screens/f_collection_screen.dart';
import 'package:hobby_atlas/screens/s_app_shell.dart';
import 'package:hobby_atlas/theme.dart';
import 'package:hobby_atlas/widgets.dart';

import 'layout_test.dart' show db, fakeLoaders;

Future<void> _frames(WidgetTester tester, [int n = 6]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _show(WidgetTester tester, Widget home) async {
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
  await _frames(tester);
}

void main() {
  fixedNow = DateTime(2026, 10, 25, 21);

  testWidgets('HelpButton — 누르면 제목 + 아이콘 · 점 · 묶음 줄', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildGpTheme(),
        home: const Scaffold(
          body: Center(
            child: HelpButton(
              title: '시험',
              items: [
                HelpItem(Icons.tune, '필터'),
                HelpItem.group('묶음'),
                HelpItem.dot(Gp.accent, '발매'),
                HelpItem.widget(Text('편집'), '골라서 지우기'),
              ],
            ),
          ),
        ),
      ),
    );
    final btn = tester.getSize(find.byType(HelpButton));
    expect(btn, const Size(ToolIcon.width, 48)); // ToolIcon 한 칸
    expect(find.byTooltip('도움말'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.help_outline));
    await tester.pumpAndSettle();
    for (final t in ['시험', '필터', '묶음', '발매', '편집', '골라서 지우기']) {
      expect(find.text(t), findsOneWidget);
    }
    expect(find.byIcon(Icons.tune), findsOneWidget);
  });

  testWidgets('긴 도움말도 넘치지 않는다 (작은 폰)', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildGpTheme(),
        home: Scaffold(
          body: Center(
            child: HelpButton(title: '긴 것', items: [for (var i = 0; i < 30; i++) HelpItem(Icons.tune, '줄 $i')]),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(HelpButton));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('줄 0'), findsOneWidget);
  });

  testWidgets('앱 셸 위 줄 ? — 탭마다 그 탭 아이콘 뜻 (캘린더 = 점 색까지)', (tester) async {
    await _show(tester, AppShell(loaders: fakeLoaders));
    await tester.tap(find.byTooltip('도움말'));
    await _frames(tester, 3);
    expect(find.text('설정'), findsWidgets); // 위 줄
    expect(find.text('전체 소식'), findsWidgets); // 홈 묶음
    Navigator.of(tester.element(find.text('수집 레벨'))).pop();
    await _frames(tester, 3);

    await tester.tap(find.byIcon(Icons.calendar_today_outlined).last);
    await _frames(tester);
    await tester.tap(find.byTooltip('도움말'));
    await _frames(tester, 3);
    expect(find.text('산 날 (내 일정)'), findsOneWidget);
    expect(find.text('PB 예약 마감 (내 일정)'), findsOneWidget);
    expect(find.byTooltip('점 색'), findsNothing); // 달력 위 ? 는 합쳤다
    expect(tester.takeException(), isNull);
  });

  testWidgets('검색 ? 에 기체별 묶기 · 컬렉션 ? 에 휴지통 · 편집 · 도감 칸', (tester) async {
    expect(searchHelp().map((i) => i.text), contains('검색 결과를 기체별로 묶기'));
    expect(collectionHelp().map((i) => i.text), containsAll(['휴지통 (30일 동안 되살리기)', '편집 (골라서 지우기)', '구매함 · +10']));
  });

  testWidgets('상품 상세 — 오른쪽 위 ? (뒤로 맞은편)', (tester) async {
    final kit = (db['kits']! as List).map(Kit.fromJson).nonNulls.firstWhere((k) => k.id == 'gu02');
    await _show(tester, KitDetailScreen(kit: kit, loaders: fakeLoaders));
    final help = tester.getCenter(find.byTooltip('도움말'));
    final back = tester.getCenter(find.byTooltip('뒤로'));
    expect(help.dy, closeTo(back.dy, 1));
    expect(help.dx, greaterThan(300));
    await tester.tap(find.byTooltip('도움말'));
    await _frames(tester, 3);
    expect(find.text('정보 오류 제보'), findsOneWidget);
  });
}
