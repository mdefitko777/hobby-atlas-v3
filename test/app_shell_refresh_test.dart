// S 앱 셸 — 뒤에서 새 데이터를 받아도 셸은 그대로 (지금 탭 · 검색어), 탭 화면만 다시 불러온다.
// 예전에는 main.dart 가 AppShell(key: ValueKey(Catalog.version)) 이라 데이터가 바뀔 때마다 셸이 통째로 새로 만들어져
// 검색 · 컬렉션을 보다가 홈으로 튕기고 검색어 · 서랍이 사라졌다.
// + 휴대폰 알림 「새 상품」을 눌렀는데 그 상품을 찾는 데 오래 걸리면(새 데이터 받는 중) 알려 주고, 찾으면 상세로.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/api.dart';
import 'package:hobby_atlas/clock.dart';
import 'package:hobby_atlas/data/catalog.dart';
import 'package:hobby_atlas/data/user_store.dart';
import 'package:hobby_atlas/detail_pane.dart';
import 'package:hobby_atlas/marks.dart';
import 'package:hobby_atlas/notifications/local_notifier.dart';
import 'package:hobby_atlas/notifications/notify_store.dart';
import 'package:hobby_atlas/screens/b_search_screen.dart';
import 'package:hobby_atlas/screens/d_kit_detail_screen.dart';
import 'package:hobby_atlas/screens/s_app_shell.dart';
import 'package:hobby_atlas/theme.dart';

import 'layout_test.dart' show fakeLoaders;

/// fakeLoaders 와 같고, kits 를 부른 횟수를 센다 · kitsByIds 를 늦출 수 있다
Loaders _loaders({required void Function() onKits, Duration byIdsDelay = Duration.zero}) {
  final f = fakeLoaders;
  return Loaders(
    kits: (ids) {
      onKits();
      return f.kits(ids);
    },
    collection: f.collection,
    kitsByIds: (ids) async {
      await Future<void>.delayed(byIdsDelay);
      return f.kitsByIds(ids);
    },
    worlds: f.worlds,
    guideWorks: f.guideWorks,
    guideUnits: f.guideUnits,
    bbxTops: f.bbxTops,
    bbxBuilder: f.bbxBuilder,
    announcements: f.announcements,
    profile: f.profile,
    notifications: f.notifications,
    friendGuide: f.friendGuide,
    guideChapters: f.guideChapters,
    kitsByJan: f.kitsByJan,
    restocks: f.restocks,
    guideIndex: f.guideIndex,
  );
}

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

/// 끝없는 애니메이션(색 고리 · 배너)이 있어 pumpAndSettle 대신 나눠 그린다
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

/// 바닥 탭 바의 탭 (글자)
Future<void> _tapTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await _settle(tester);
}

void main() {
  fixedNow = DateTime(2026, 10, 25, 21);

  testWidgets('뒤에서 새 데이터를 받아도 검색 탭 · 검색어는 그대로, 다른 탭은 다시 불러온다', (tester) async {
    var kitLoads = 0;
    await _pump(
      tester,
      AppShell(
        loaders: _loaders(onKits: () => kitLoads++),
        notify: NotifyStore.memory(),
      ),
    );
    await _tapTab(tester, '검색');
    expect(find.byType(SearchScreen), findsOneWidget);
    await tester.enterText(find.byType(TextField), '프리덤');
    await _settle(tester);
    final before = kitLoads;

    Catalog.instance.debugBumpVersion(quiet: true); // 켤 때 뒤에서 받은 새 데이터
    await _settle(tester);
    expect(find.byType(SearchScreen), findsOneWidget, reason: '홈으로 튕기지 않는다');
    expect(find.text('프리덤'), findsOneWidget, reason: '보고 있는 탭의 검색어는 그대로');
    expect(kitLoads, greaterThan(before), reason: '보이지 않는 탭(홈 · 캘린더 · 컬렉션)은 새 데이터로');

    // 검색 탭을 떠났다 돌아오면 그때 새 데이터로 (옛 목록에 남지 않는다)
    await _tapTab(tester, '홈');
    await _tapTab(tester, '검색');
    expect(find.text('프리덤'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('사람이 고른 새로 받기(당겨서 새로 고침 · 지금 새로 받기)는 보고 있는 탭도 바로 — 탭은 그대로', (tester) async {
    var kitLoads = 0;
    await _pump(
      tester,
      AppShell(
        loaders: _loaders(onKits: () => kitLoads++),
        notify: NotifyStore.memory(),
      ),
    );
    await _tapTab(tester, '검색');
    await tester.enterText(find.byType(TextField), '프리덤');
    await _settle(tester);

    Catalog.instance.debugBumpVersion(quiet: false);
    await _settle(tester);
    expect(find.byType(SearchScreen), findsOneWidget);
    expect(find.text('프리덤'), findsNothing, reason: '보고 있는 탭도 새 데이터로');
    expect(tester.takeException(), isNull);
  });

  testWidgets('「새 상품」 알림: 찾는 데 오래 걸리면 「새 데이터를 받는 중」 → 찾으면 상세', (tester) async {
    await _pump(
      tester,
      AppShell(
        loaders: _loaders(onKits: () {}, byIdsDelay: const Duration(seconds: 3)),
        notify: NotifyStore.memory(),
      ),
    );
    LocalNotifier.taps.value = 'kit:gu02';
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('새 데이터를 받는 중이에요 · 잠시만요'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await _settle(tester);
    expect(find.byType(KitDetailScreen), findsOneWidget);
    expect(find.textContaining('스트라이크 프리덤'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('바로 찾으면 알리지 않고 상세', (tester) async {
    await _pump(
      tester,
      AppShell(
        loaders: _loaders(onKits: () {}),
        notify: NotifyStore.memory(),
      ),
    );
    LocalNotifier.taps.value = 'kit:gu01';
    await _settle(tester);
    expect(find.text('새 데이터를 받는 중이에요 · 잠시만요'), findsNothing);
    expect(find.byType(KitDetailScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
