// 채널 맞춰 보기 (2026-11-14): 홈에서 건담을 고르면 검색 · 캘린더 · 컬렉션도 건담 (설정에서 끄면 탭마다 따로).
// 고른 채널은 앱 셸이 들고 있어 새 데이터로 탭 화면을 다시 만들어도 전체로 돌아가지 않는다.
// 글자 대신 화면 타입 · ChannelBar.selected · Key 로 찾는다 (중국어 화면에서도 같게)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/clock.dart';
import 'package:hobby_atlas/data/catalog.dart';
import 'package:hobby_atlas/data/user_store.dart';
import 'package:hobby_atlas/detail_pane.dart';
import 'package:hobby_atlas/marks.dart';
import 'package:hobby_atlas/notifications/notify_store.dart';
import 'package:hobby_atlas/screens/a_home_screen.dart';
import 'package:hobby_atlas/screens/b_search_screen.dart';
import 'package:hobby_atlas/screens/c_channel_screen.dart';
import 'package:hobby_atlas/screens/f_collection_screen.dart';
import 'package:hobby_atlas/screens/h_calendar_screen.dart';
import 'package:hobby_atlas/screens/k_settings_screen.dart';
import 'package:hobby_atlas/screens/s_app_shell.dart';
import 'package:hobby_atlas/theme.dart';

import 'layout_test.dart' show fakeLoaders;

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<UserStore> _pumpShell(WidgetTester tester, {bool sync = true}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final store = UserStore.memory()..setChannelSync(sync);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildGpTheme(),
      builder: (context, child) => MarksHost(
        store: store,
        child: PaneHost(child: child!),
      ),
      home: AppShell(loaders: fakeLoaders, notify: NotifyStore.memory()),
    ),
  );
  await _settle(tester);
  return store;
}

/// 탭 화면 [screen] 안 채널 바 (IndexedStack 뒤쪽 탭도)
ChannelBar _bar(WidgetTester tester, Type screen) => tester.widget<ChannelBar>(
  find.descendant(of: find.byType(screen, skipOffstage: false), matching: find.byType(ChannelBar, skipOffstage: false)),
);

Map<Type, String> _selected(WidgetTester tester) => {
  for (final t in [HomeScreen, SearchScreen, CalendarScreen, CollectionScreen]) t: _bar(tester, t).selected,
};

void main() {
  fixedNow = DateTime(2026, 10, 25, 21);

  testWidgets('맞춰 보기(기본): 한 탭에서 고른 채널을 네 탭이 같이', (tester) async {
    await _pumpShell(tester);
    _bar(tester, HomeScreen).onSelect('gundam');
    await _settle(tester);
    expect(_selected(tester).values.toSet(), {'gundam'});

    _bar(tester, CalendarScreen).onSelect('beyblade');
    await _settle(tester);
    expect(_selected(tester).values.toSet(), {'beyblade'});

    // 새 데이터로 탭 화면을 다시 만들어도 고른 채널 그대로 (예전에는 전체로 돌아갔다)
    Catalog.instance.debugBumpVersion(quiet: false);
    await _settle(tester);
    expect(_selected(tester).values.toSet(), {'beyblade'});
    expect(tester.takeException(), isNull);
  });

  testWidgets('맞춰 보기를 끄면 탭마다 따로 — 다시 켜면 지금 탭의 채널로 맞춘다', (tester) async {
    final store = await _pumpShell(tester, sync: false);
    _bar(tester, HomeScreen).onSelect('gundam');
    await _settle(tester);
    expect(_selected(tester), {
      HomeScreen: 'gundam',
      SearchScreen: allChannelId,
      CalendarScreen: allChannelId,
      CollectionScreen: allChannelId,
    });
    _bar(tester, SearchScreen).onSelect('pokemon');
    await _settle(tester);
    expect(_bar(tester, HomeScreen).selected, 'gundam');
    expect(_bar(tester, SearchScreen).selected, 'pokemon');

    Catalog.instance.debugBumpVersion(quiet: false);
    await _settle(tester);
    expect(_bar(tester, HomeScreen).selected, 'gundam', reason: '끈 때도 새 데이터로 전체로 돌아가지 않는다');

    store.setChannelSync(true); // 지금 탭(홈)의 채널로
    await _settle(tester);
    expect(_selected(tester).values.toSet(), {'gundam'});
    expect(tester.takeException(), isNull);
  });

  testWidgets('내 채널에서 뺀 채널을 보고 있었으면 전체로', (tester) async {
    final store = await _pumpShell(tester);
    _bar(tester, HomeScreen).onSelect('pokemon');
    await _settle(tester);
    store.setMyChannels(const ['gundam', 'beyblade']);
    await _settle(tester);
    expect(_selected(tester).values.toSet(), {allChannelId});
    // 다시 넣어도 저절로 그 채널로 돌아가지 않는다
    store.setMyChannels(const ['gundam', 'beyblade', 'pokemon']);
    await _settle(tester);
    expect(_selected(tester).values.toSet(), {allChannelId});
  });

  testWidgets('내 정보 숫자로 컬렉션에 가면 전체 — 맞춰 보기면 네 탭, 끄면 컬렉션만', (tester) async {
    final store = await _pumpShell(tester);
    HomeScreen home() => tester.widget<HomeScreen>(find.byType(HomeScreen, skipOffstage: false));
    _bar(tester, HomeScreen).onSelect('gundam');
    await _settle(tester);
    home().onJump!(CollectionJump.owned);
    await _settle(tester);
    expect(_selected(tester).values.toSet(), {allChannelId});

    store.setChannelSync(false);
    await _settle(tester);
    _bar(tester, HomeScreen).onSelect('gundam');
    _bar(tester, CollectionScreen).onSelect('pokemon');
    await _settle(tester);
    home().onJump!(CollectionJump.liked);
    await _settle(tester);
    expect(_bar(tester, CollectionScreen).selected, allChannelId);
    expect(_bar(tester, HomeScreen).selected, 'gundam', reason: '끈 때는 홈은 그대로');
    expect(tester.takeException(), isNull);
  });

  testWidgets('설정 › 채널 맞춰 보기 스위치 (기본 켜짐, 저장된다)', (tester) async {
    final me = UserStore.memory();
    tester.view.physicalSize = const Size(360, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildGpTheme(),
        builder: (context, child) => MarksHost(store: me, child: child!),
        home: SettingsScreen(notify: NotifyStore.memory()),
      ),
    );
    await _settle(tester);
    final tile = find.byKey(const Key('settings-channel-sync'));
    expect(tester.widget<SwitchListTile>(tile).value, isTrue);
    await tester.tap(tile);
    await tester.pump();
    expect(me.channelSync, isFalse);
    expect((me.toJson()['local_state'] as Map)['channel_sync'], isFalse);
    expect(tester.widget<SwitchListTile>(tile).value, isFalse);
    expect(tester.takeException(), isNull);
  });
}
