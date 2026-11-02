// 찾기 · 필터 줄(FindBar)과 홈 채널 좌우 밀기
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/api.dart';
import 'package:hobby_atlas/clock.dart';
import 'package:hobby_atlas/data/user_store.dart';
import 'package:hobby_atlas/detail_pane.dart';
import 'package:hobby_atlas/widgets.dart';
import 'package:hobby_atlas/marks.dart';
import 'package:hobby_atlas/models.dart';
import 'package:hobby_atlas/screens/a_home_screen.dart';
import 'package:hobby_atlas/screens/b_search_screen.dart';
import 'package:hobby_atlas/screens/f_collection_screen.dart';
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

  test('구매가를 안 적은 구매함 상품은 정가 × 환율로 지출에 들어간다', () {
    final me = UserStore.memory()..listPrice = (id) => id == 'a' ? 8500 : null;
    me.setStatus('a', CollectStatus.owned); // 안 적음 → 정가 8,500원
    me.setStatus('b', CollectStatus.owned);
    me.setDetails('b', purchasePrice: 12000); // 적음 → 그 값
    me.setStatus('c', CollectStatus.owned); // 정가도 없음 → 0
    expect(me.spendKrw, 20500);
  });

  testWidgets('검색창 줄: 홈 · 도감 · 캘린더 · 컬렉션 모두 [검색창][필터][보기 두 칸] — 검색창 폭이 같다', (tester) async {
    final widths = <double>[];
    Future<void> measure(Widget screen) async {
      await _pump(tester, Scaffold(body: screen));
      final row = find.byType(ToolRow).first;
      expect(find.descendant(of: row, matching: find.byType(ToolIcon)), findsNWidgets(3));
      widths.add(tester.getSize(find.descendant(of: row, matching: find.byType(GpSearchBar))).width);
    }

    await measure(
      HomeScreen(
        myChannels: const ['gundam'],
        onMyChannelsChanged: (_) {},
        onOpenSearch: () {},
        onCamera: () {},
        loaders: fakeLoaders,
      ),
    );
    await measure(CalendarScreen(myChannels: const ['gundam'], onMyChannelsChanged: (_) {}, loaders: fakeLoaders));
    await measure(
      CollectionScreen(
        myChannels: const ['gundam'],
        onMyChannelsChanged: (_) {},
        onGoSearch: () {},
        loaders: fakeLoaders,
      ),
    );
    await measure(
      SearchScreen(myChannels: const ['gundam'], onMyChannelsChanged: (_) {}, onCamera: () {}, loaders: fakeLoaders),
    );
    expect(widths.toSet(), hasLength(1));
  });

  test('setDetails 는 준 값만 바꾼다 (옛 앱의 보관 장소 · 메모를 지우지 않음)', () {
    final me = UserStore.memory();
    me.setStatus('a', CollectStatus.owned);
    me.setDetails('a', storage: '책장', note: '선물');
    me.setDetails('a', purchasePrice: 12000);
    expect(me.entry('a')?['storage'], '책장');
    expect(me.entry('a')?['note'], '선물');
    expect(me.entry('a')?['purchase_price'], 12000);
    me.setDetails('a', note: '');
    expect(me.entry('a')?.containsKey('note'), isFalse);
  });
}
