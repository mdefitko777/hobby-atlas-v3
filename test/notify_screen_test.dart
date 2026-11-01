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
import 'package:hobby_atlas/screens/k_settings_screen.dart';
import 'package:hobby_atlas/screens/n_notifications_screen.dart';
import 'package:hobby_atlas/screens/s_app_shell.dart';
import 'package:hobby_atlas/theme.dart';

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

  testWidgets('설정: 알림 규칙 칩 · 내 채널 소식만 스위치가 알림 설정에 남는다', (tester) async {
    final store = NotifyStore.memory();
    await pumpApp(tester, SettingsScreen(notify: store), size: const Size(390, 1800));
    expect(find.text('PB (프리미엄 반다이)'), findsOneWidget);
    expect(store.config.rule('gundam'), isFalse);
    await tester.tap(find.text('건담 전체'));
    await tester.pump();
    expect(store.config.rule('gundam'), isTrue);
    await tester.tap(find.text('SEED / 00'));
    await tester.pump();
    expect(store.config.rule('seed_00'), isFalse);
    await tester.tap(find.text('내 채널 소식만'));
    await tester.pump();
    expect(store.config.onlyMine, isFalse);
    expect(find.text('아직 확인하지 않았어요'), findsOneWidget);
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
}
