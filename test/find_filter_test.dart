// 찾기 · 필터 줄(FindBar)과 홈 채널 좌우 밀기
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/api.dart';
import 'package:hobby_atlas/clock.dart';
import 'package:hobby_atlas/data/user_store.dart';
import 'package:hobby_atlas/detail_pane.dart';
import 'package:hobby_atlas/filter_sheet.dart';
import 'package:hobby_atlas/marks.dart';
import 'package:hobby_atlas/screens/a_home_screen.dart';
import 'package:hobby_atlas/screens/h_calendar_screen.dart';
import 'package:hobby_atlas/theme.dart';

import 'layout_test.dart' show fakeLoaders;

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
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  fixedNow = DateTime(2026, 10, 25, 21);

  testWidgets('홈: 내용을 왼쪽으로 밀면 다음 채널, 오른쪽으로 밀면 앞 채널', (tester) async {
    final asked = <String>[];
    final loaders = Loaders(
      kits: (ids) {
        asked.add(ids.join(','));
        return fakeLoaders.kits(ids);
      },
      announcements: fakeLoaders.announcements,
    );
    await _pump(
      tester,
      Scaffold(
        body: HomeScreen(
          myChannels: const ['gundam', 'beyblade'],
          onMyChannelsChanged: (_) {},
          onOpenSearch: () {},
          onCamera: () {},
          loaders: loaders,
        ),
      ),
    );
    expect(asked.last, 'gundam,beyblade'); // 전체
    // 섹션 제목 줄(가로 줄이 아닌 곳)에서 민다
    Future<void> swipe(double dx) async {
      await tester.flingFrom(tester.getCenter(find.text('최근 추가').first), Offset(dx, 0), 1200);
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    await swipe(-300);
    expect(asked.last, 'gundam');
    await swipe(-300);
    expect(asked.last, 'beyblade');
    await swipe(300);
    expect(asked.last, 'gundam');
  });

  testWidgets('캘린더: 찾기 줄에 쓰면 그 글자가 든 일정만 · 필터 버튼이 있다', (tester) async {
    await _pump(
      tester,
      Scaffold(
        body: CalendarScreen(
          myChannels: const ['gundam', 'pokemon'],
          onMyChannelsChanged: (_) {},
          loaders: fakeLoaders,
        ),
      ),
    );
    expect(find.byType(FilterButton), findsOneWidget);
    expect(find.textContaining('카르라 전용 이펙트'), findsOneWidget);
    await tester.enterText(find.descendant(of: find.byType(FindBar), matching: find.byType(TextField)), '포켓프라');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('카르라 전용 이펙트'), findsNothing);
    expect(find.textContaining('포켓프라 Quick'), findsOneWidget);
  });

  test('도감 필터: 켜진 것 · 아직', () {
    expect(LitState.lit.hit(true), isTrue);
    expect(LitState.lit.hit(false), isFalse);
    expect(LitState.unlit.hit(false), isTrue);
    expect(LitState.any.hit(false), isTrue);
  });
}
