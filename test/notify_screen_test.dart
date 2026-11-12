// 알림 화면 · 🔔 숫자 — 알림함(NotifyStore)과 같은 값인지, 읽음 · 지움 · 되돌리기가 알림함에 남는지
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/api.dart';
import 'package:hobby_atlas/clock.dart';
import 'package:hobby_atlas/data/derive.dart' show noticeOf;
import 'package:hobby_atlas/data/user_store.dart';
import 'package:hobby_atlas/detail_pane.dart';
import 'package:hobby_atlas/marks.dart';
import 'package:hobby_atlas/notifications/notify_models.dart';
import 'package:hobby_atlas/notifications/notify_store.dart';
import 'package:hobby_atlas/screens/k_notify_settings.dart';
import 'package:hobby_atlas/screens/k_settings_screen.dart';
import 'package:hobby_atlas/screens/notify_condition_sheet.dart' show conditionLabel;
import 'package:hobby_atlas/screens/n_notifications_screen.dart';
import 'package:hobby_atlas/screens/s_app_shell.dart';
import 'package:hobby_atlas/theme.dart';
import 'package:hobby_atlas/widgets.dart' show GradientButton;

import 'layout_test.dart' show fakeLoaders;

final at = DateTime(2026, 10, 25, 7);

/// 실제 확인이 만드는 모양 그대로 (`feed-<날짜>-<kit_id>`)
final records = [
  NoticeRecord(
    id: 'feed-2026-10-25-mg-noir',
    kind: 'changed',
    kitId: 'mg-noir',
    title: 'MG 건담 아스트레이 느와르',
    body: '가격 변경 ¥5,940 · SEED',
    at: at,
    franchise: 'gundam',
    reasons: const ['price'],
    watched: true,
  ),
  NoticeRecord(
    id: 'feed-2026-10-25-pb-kshatriya',
    kind: 'added',
    kitId: 'pb-kshatriya',
    title: 'MGSD 크샤트리아',
    body: '새로 수록 · 프리미엄 반다이',
    at: at,
    franchise: 'gundam',
    pb: true,
  ),
  NoticeRecord(
    id: 'feed-2026-10-25-fate-poster',
    kind: 'changed',
    kitId: 'fate-poster',
    title: 'A3 포스터',
    body: '좋아요한 상품 · 한정 표시',
    at: at,
    franchise: 'fate', // 내 채널 밖이지만 좋아요 → 보인다
    wanted: true,
  ),
  NoticeRecord(
    id: 'feed-2026-10-20-ac-mirage',
    kind: 'added',
    kitId: 'ac-mirage',
    title: '미라지 C02',
    body: '새로 수록',
    at: at.subtract(const Duration(days: 5)),
    franchise: 'armored_core', // 내 채널 밖 → 안 보인다
  ),
  NoticeRecord(
    id: 'feed-2026-10-18-bbx-bx54',
    kind: 'added',
    kitId: 'bbx-bx54',
    title: 'BX-54',
    body: '새로 수록',
    at: at.subtract(const Duration(days: 7)),
    franchise: 'beyblade',
    seen: true, // 처음 실행 때 채운 지난 소식
  ),
];

Loaders loadersFor(NotifyStore store) => Loaders(
  notifications: () async => [for (final r in store.state.inbox) noticeOf(r, null)],
  kitsByIds: (_) async => const [],
);

Future<void> pumpApp(WidgetTester tester, Widget home, {Size size = const Size(390, 844)}) async {
  tester.view.physicalSize = size;
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
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  fixedNow = DateTime(2026, 10, 25, 21);
  const mine = ['gundam', 'beyblade', 'pokemon'];

  test('🔔 숫자 = 내 채널 + 좋아요, 안 읽은 것, 지우지 않은 것', () {
    final store = NotifyStore.memory(records: records);
    expect(store.unreadCount(mine), 3); // 느와르 · 크샤트리아 · (Fate 좋아요). AC 는 채널 밖, BX-54 는 읽음
    store.setDismissed('feed-2026-10-25-pb-kshatriya', true);
    expect(store.unreadCount(mine), 2);
    store.config.onlyMine = false;
    expect(store.unreadCount(mine), 3); // AC 도
  });

  test('? 도움말: 가격 알림은 일본 정가 변경 (앱에서 「시세」는 국내 시세만)', () {
    // 알림 둘째 줄과 같은 말 (lib/notifications/feed_rules.dart 'price' → "가격 변경 ¥…")
    final texts = [for (final h in notificationsHelp) h.text];
    expect(texts, contains('가격 변경 (일본 정가)'));
    expect(texts, everyElement(isNot(contains('시세'))));
    // 🛍 예약 묶음 = PB 예약 기간 · 재판매 · 예약 도착 (lib/data/derive/notifications.dart)
    expect(texts, contains('PB 예약 · 재판매 · 예약 도착'));
  });

  testWidgets('알림 화면: 모두 읽음 → 🔔 0, 되돌리기 → 다시 3', (tester) async {
    final store = NotifyStore.memory(records: records);
    await pumpApp(tester, NotificationsScreen(myChannels: mine, loaders: loadersFor(store), notify: store));
    expect(find.text('MG 건담 아스트레이 느와르'), findsOneWidget);
    expect(find.text('A3 포스터'), findsOneWidget); // 좋아요는 채널 밖이어도
    expect(find.text('미라지 C02'), findsNothing); // 채널 밖
    await tester.tap(find.text('모두 읽음'));
    await tester.pump();
    expect(store.unreadCount(mine), 0);
    expect(store.isRead('feed-2026-10-25-mg-noir'), isTrue);
    await tester.pump(const Duration(milliseconds: 500)); // 토스트가 올라올 때까지
    await tester.tap(find.text('되돌리기'));
    await tester.pump();
    expect(store.unreadCount(mine), 3);
  });

  testWidgets('알림 화면: 밀어서 지우기 → 알림함에 남고 목록에서 빠짐 · 누르면 읽음', (tester) async {
    final store = NotifyStore.memory(records: records);
    await pumpApp(tester, NotificationsScreen(myChannels: mine, loaders: loadersFor(store), notify: store));
    await tester.drag(find.text('MGSD 크샤트리아'), const Offset(-500, 0));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('MGSD 크샤트리아'), findsNothing);
    expect(store.isDismissed('feed-2026-10-25-pb-kshatriya'), isTrue);
    expect(store.state.inbox, hasLength(records.length)); // 줄은 남는다 (다음 확인 때 다시 들어오지 않게)

    await tester.tap(find.text('MG 건담 아스트레이 느와르'));
    await tester.pump();
    expect(store.isRead('feed-2026-10-25-mg-noir'), isTrue);
    await tester.pump(const Duration(milliseconds: 500)); // 상품 찾기(비동기) → 토스트
    expect(find.text('이 상품은 지금 카탈로그에 없어요'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('알림 페이지 자리: 규칙 키는 하나도 빠지지 않고 내 상품 · 채널 전체 · 채널 규칙 중 한 곳에', () {
    final placed = [...notifyMineRules, ...notifyWorldRules, for (final l in notifyChannelRules.values) ...l];
    expect(placed.toSet(), notifyRuleDefaults.keys.toSet());
    expect(placed, hasLength(notifyRuleDefaults.length), reason: '두 곳에 있으면 한쪽만 바뀌어 보인다');
  });

  test('요약: 설정 줄 "켜짐 · 규칙 n개" · 채널 줄 "전부 · SEED/00 · PB … · 끔"', () {
    final c = NotifyConfig();
    expect(notifySummary(c), '켜짐 · 규칙 9개'); // 처음 켜져 있는 규칙 9개 (라이브 시작 전 포함)
    expect(notifySummary(c, permitted: false), '꺼짐');
    expect(channelNotifySummary(c, 'gundam', mine: true), 'SEED/00 · PB · PB 예약');
    expect(channelNotifySummary(c, 'beyblade', mine: true), 'BBX');
    expect(channelNotifySummary(c, 'fate', mine: true), '끔');
    c.rules['gundam'] = true;
    expect(channelNotifySummary(c, 'gundam', mine: true), '전부');
    // 내 채널 소식만 + 내 채널 밖: 규칙은 걸리지 않는다 (PB 예약 기간 · 내가 만든 조건만)
    expect(channelNotifySummary(c, 'gundam', mine: false), 'PB 예약');
    c.conditions.add(const NotifyCondition(franchise: 'fate', scope: 'group:saber', scopeLabel: '세이버'));
    expect(channelNotifySummary(c, 'fate', mine: false), '조건 1개');
    expect(notifySummary(c), '켜짐 · 규칙 11개');
    c.enabled = false;
    expect(notifySummary(c), '꺼짐');
  });

  Finder inRow(Key row, String text) => find.descendant(of: find.byKey(row), matching: find.text(text));

  testWidgets('설정: 알림은 한 줄 (요약 · ›) → 알림 페이지', (tester) async {
    final store = NotifyStore.memory();
    await pumpApp(tester, SettingsScreen(notify: store), size: const Size(390, 1400));
    const row = Key('settings-notify');
    expect(inRow(row, notifySummary(store.config)), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNothing, reason: '규칙 스위치 · 칩은 알림 페이지에');
    store.setRule('wanted', false);
    await tester.pump();
    expect(inRow(row, notifySummary(store.config)), findsOneWidget);
    await tester.tap(find.byKey(row));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.byType(NotifySettingsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('알림 페이지: 내 상품 스위치 · 내 채널 소식만 · 확인 줄이 NotifyConfig 에 남는다', (tester) async {
    final store = NotifyStore.memory();
    await pumpApp(tester, NotifySettingsScreen(notify: store), size: const Size(390, 2000));
    for (final k in notifyMineRules) {
      expect(store.config.rule(k), isTrue);
      await tester.tap(find.byKey(Key('rule-$k')));
      await tester.pump();
      expect(store.config.rule(k), isFalse, reason: k);
    }
    await tester.tap(find.byKey(const Key('notify-only-mine')));
    await tester.pump();
    expect(store.config.onlyMine, isFalse);
    expect(find.text(store.shortStatus), findsOneWidget); // 마지막 확인
    expect(tester.takeException(), isNull);
  });

  testWidgets('알림 페이지: 채널 줄 요약 → 채널 시트 (전체 · 채널 규칙 · 그 채널 조건 · 조건 추가)', (tester) async {
    final seed = const NotifyCondition(franchise: 'gundam', scope: 'series:seed', scopeLabel: 'SEED');
    final fate = const NotifyCondition(franchise: 'fate', scope: 'group:saber', scopeLabel: '세이버');
    // 데이터가 없는 채널에 남은 조건 (예전에 고른 것) — 지울 줄이 있어야 한다
    final rider = const NotifyCondition(franchise: 'kamen_rider');
    final store = NotifyStore.memory(config: NotifyConfig(conditions: [seed, fate, rider]));
    await pumpApp(tester, NotifySettingsScreen(notify: store), size: const Size(390, 2400));
    const gundam = Key('notify-channel-gundam');
    expect(inRow(gundam, channelNotifySummary(store.config, 'gundam', mine: true)), findsOneWidget);
    expect(find.byKey(const Key('notify-channel-lego')), findsOneWidget, reason: '내 채널 밖도 (더 많은 채널)');
    expect(find.byKey(const Key('notify-channel-kamen_rider')), findsOneWidget, reason: '조건이 남은 채널');
    expect(find.byKey(const Key('notify-channel-zoids')), findsNothing, reason: '데이터도 조건도 없는 채널');

    Future<void> settle() async {
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    await tester.tap(find.byKey(gundam));
    await settle();
    for (final k in ['gundam', 'seed_00', 'premium_bandai', 'pb_window']) {
      expect(find.byKey(Key('rule-$k')), findsOneWidget, reason: k);
    }
    expect(find.byKey(const Key('rule-bbx')), findsNothing);
    expect(find.text(conditionLabel(seed)), findsOneWidget);
    expect(find.text(conditionLabel(fate)), findsNothing, reason: '다른 채널 조건은 그 채널 시트에');

    await tester.tap(find.byKey(const Key('rule-gundam')));
    await tester.pump();
    expect(store.config.rule('gundam'), isTrue);
    expect(inRow(gundam, channelNotifySummary(store.config, 'gundam', mine: true)), findsOneWidget);

    // 조건 추가 = 조건 시트 그대로, 채널은 정해져 있다
    await tester.tap(find.byKey(const Key('notify-add-condition')));
    await settle();
    await tester.tap(find.byType(GradientButton));
    await settle();
    expect(store.config.conditions.map((x) => x.id), contains('gundam||'));

    await tester.tap(find.byIcon(Icons.close).first); // SEED 조건 지우기
    await tester.pump();
    expect(store.config.conditions.map((x) => x.id), isNot(contains(seed.id)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('앱 셸 🔔 에 안 읽은 수', (tester) async {
    final store = NotifyStore.memory(records: records);
    await pumpApp(tester, AppShell(loaders: fakeLoaders, notify: store));
    Finder bellCount(String n) => find.descendant(of: find.byType(Badge), matching: find.text(n));
    expect(bellCount('3'), findsWidgets);
    store.setRead(['feed-2026-10-25-mg-noir'], true);
    await tester.pump();
    expect(bellCount('2'), findsWidgets);
    store.setRead([for (final r in records) r.id], true);
    await tester.pump();
    expect(bellCount('2'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('NotifyScope: 화면은 위쪽 한 벌을 쓰고, 닫힐 때(dispose) 위쪽을 다시 찾지 않는다', (tester) async {
    final store = NotifyStore.memory(records: records);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      NotifyScope(
        store: store,
        child: MaterialApp(
          theme: buildGpTheme(),
          builder: (context, child) => MarksHost(
            store: UserStore.memory(),
            child: PaneHost(child: child!),
          ),
          home: NotificationsScreen(myChannels: mine, loaders: loadersFor(store)), // notify 를 넘기지 않는다
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.tap(find.text('모두 읽음'));
    await tester.pump();
    expect(store.unreadCount(mine), 0); // 위쪽 한 벌에 적혔다
    await tester.pump(const Duration(seconds: 5)); // 토스트가 닫힐 때까지
    await tester.pumpWidget(const SizedBox()); // 화면이 닫힌다 → dispose
    expect(tester.takeException(), isNull);
  });
}
