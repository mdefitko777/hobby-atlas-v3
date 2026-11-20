// ? 도움말 (lib/widgets/help.dart) — 버튼 하나 · 시트 줄 · 쌓아 연 화면의 자리 · 서랍 › 사용법 한 쪽
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
import 'package:hobby_atlas/screens/g_guide_view.dart' show guideHelpSections;
import 'package:hobby_atlas/screens/s_app_shell.dart';
import 'package:hobby_atlas/screens/u_social.dart' show MyAvatar;
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

  testWidgets('위 줄 ? 는 없고 서랍 › 사용법 한 쪽에 위 줄 · 네 탭 · 도감 · 친구 · 내 정보 (캘린더 = 점 색까지)', (tester) async {
    await _show(tester, AppShell(loaders: fakeLoaders));
    expect(find.byTooltip('도움말'), findsNothing); // 2026-11-21 주인: 위 줄 · 탭 안의 ? 를 서랍으로
    await tester.tap(find.byType(MyAvatar).first);
    await _frames(tester, 3);
    await tester.tap(find.byKey(const ValueKey('drawer-help')));
    await _frames(tester);
    expect(find.byType(HelpPage), findsOneWidget);
    expect(find.text('수집 레벨'), findsOneWidget); // 위 줄
    expect(find.text('격자 · 목록 (전체 보기 안)'), findsOneWidget); // 홈 묶음
    final list = find.descendant(of: find.byType(HelpPage), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.text('그 밖의 일정'), 300, scrollable: list);
    expect(find.text('좋아요 · 예약한 상품'), findsOneWidget); // 점 색은 둘뿐 (파랑 · 회색)
    await tester.scrollUntilVisible(find.text('아이디로 친구 추가'), 300, scrollable: list);
    expect(tester.takeException(), isNull);
  });

  testWidgets('사용법: 검색에 기체별 묶기 · 컬렉션에 휴지통 · 편집 · 도감 묶음에 칸 (늘 컬러)', (tester) async {
    expect(searchHelp().map((i) => i.text), contains('검색 결과를 기체별로 묶기'));
    final c = collectionHelp().map((i) => i.text);
    expect(c, containsAll(['휴지통 (30일 동안 복원)', '편집 (골라서 지우기)']));
    final guide = [for (final (_, items) in guideHelpSections()) ...items.map((i) => i.text)];
    expect(guide, contains('리본 = 구매함 · +10'));
    expect(guide.join(), isNot(contains('흑백'))); // 도감 칸은 늘 컬러
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
