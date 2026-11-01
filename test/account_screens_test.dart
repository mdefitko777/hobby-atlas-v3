// 계정 화면 — 로그인 · 설정 · 친구 서랍 · 친구 요청(알림) · 아이디로 추가 · 내 정보.
// 가짜 서버 + 가짜 로그인만 쓴다 (진짜 Supabase · 진짜 계정 없음).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/api.dart';
import 'package:hobby_atlas/data/user_store.dart';
import 'package:hobby_atlas/detail_pane.dart';
import 'package:hobby_atlas/marks.dart';
import 'package:hobby_atlas/models.dart';
import 'package:hobby_atlas/screens/i_profile_screen.dart';
import 'package:hobby_atlas/screens/k_settings_screen.dart';
import 'package:hobby_atlas/screens/m_friends_drawer.dart';
import 'package:hobby_atlas/screens/n_notifications_screen.dart';
import 'package:hobby_atlas/screens/p_sign_in_screen.dart';
import 'package:hobby_atlas/sync/account.dart';
import 'package:hobby_atlas/theme.dart';

import 'support/fake_backend.dart';

const _profile = Profile(
  name: '나',
  handle: '',
  avatarText: '나',
  tags: [],
  spendKrw: 0,
  workspace: '',
  inviteCode: '',
  members: [],
  showcase: [],
  friends: [],
  suggested: [],
);

final _loaders = Loaders(
  kits: (_) async => const [],
  collection: () async => const [],
  kitsByIds: (_) async => const [],
  worlds: (_) async => const [],
  guideWorks: () async => const [],
  guideUnits: (_) async => const [],
  bbxTops: () async => const [],
  announcements: (_) async => const [],
  profile: () async => _profile,
  notifications: () async => const [],
  friendGuide: (_) async => const {'1': 2},
);

void main() {
  late FakeServer server;
  late FakeAuth auth;
  late Account account;

  setUp(() {
    server = FakeServer(v2Payload: null, handle: 'bbang', displayName: '빵빵한빵디');
    server.users['dongsaeng'] = (
      name: '동생',
      collection: {
        'items': {
          'a': {'status': 'wanted', 'updated_at': '2026-02-01T00:00:00Z'},
          'b': {'status': 'owned', 'updated_at': '2026-02-02T00:00:00Z'},
        },
      },
    );
    server.users['friend_b'] = (name: '친구B', collection: const {});
    server.friends.add('dongsaeng');
    server.incoming.add('friend_b');
    auth = FakeAuth(signedIn: true);
    // start() 를 부르지 않는다: 15초 타이머 없이 화면만 본다
    account = Account(auth: auth, rpc: server, store: UserStore.memory());
  });

  tearDown(() => account.dispose());

  Future<void> show(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildGpTheme(),
        builder: (context, child) => AccountScope(
          account: account,
          child: MarksHost(
            store: account.store,
            child: PaneHost(child: child!),
          ),
        ),
        home: home,
      ),
    );
    await settle(tester);
  }

  Future<void> loadMe(WidgetTester tester) async {
    account.friends.refresh().ignore();
    await settle(tester);
  }

  testWidgets('로그인: 메일 → 코드 받기 → 코드 → 로그인', (tester) async {
    auth.signedIn = false;
    await show(tester, const SignInScreen());
    await tester.enterText(find.byType(TextField), 'brother@example.com');
    await tester.tap(find.text('코드 받기'));
    await settle(tester);
    expect(auth.sentTo, ['brother@example.com']);
    await tester.enterText(find.byType(TextField).last, '000000');
    await tester.tap(find.widgetWithText(FilledButton, '로그인'));
    await settle(tester);
    expect(find.textContaining('코드가 틀렸'), findsOneWidget);
    expect(auth.signedIn, isFalse);
    await tester.enterText(find.byType(TextField).last, '123456');
    await tester.tap(find.widgetWithText(FilledButton, '로그인'));
    await settle(tester);
    expect(auth.signedIn, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('설정: 로그인 전엔 로그인 줄, 로그인하면 메일 · 동기화 · 로그아웃', (tester) async {
    auth.signedIn = false;
    await show(tester, const SettingsScreen());
    expect(find.text('계정 · 동기화'), findsOneWidget);
    expect(find.text('로그인'), findsOneWidget);
    auth.signedIn = true;
    await settle(tester);
    expect(find.text('me@example.com'), findsOneWidget);
    expect(find.text('지금 동기화'), findsOneWidget);
    await tester.tap(find.text('로그아웃'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, '로그아웃'));
    await settle(tester);
    expect(auth.signedIn, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('친구 서랍: 계정 친구 · 받은 요청 수 · 친구 숫자', (tester) async {
    await show(
      tester,
      Scaffold(
        drawer: FriendsDrawer(loaders: _loaders, onOpenProfile: () {}, onOpenFriend: (_) {}),
        body: Builder(
          builder: (c) => TextButton(onPressed: () => Scaffold.of(c).openDrawer(), child: const Text('열기')),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await settle(tester);
    expect(find.text('빵빵한빵디'), findsOneWidget);
    expect(find.text('@bbang'), findsOneWidget);
    expect(find.text('친구 요청 1건'), findsOneWidget);
    expect(find.text('동생'), findsOneWidget);
    expect(find.text('@dongsaeng · 좋아요 1 · 구매함 1'), findsOneWidget); // get_friend_collection 숫자
    expect(server.count('gunpula_v3_get_friend_collection'), 1);
    // 받은 요청 시트 → 수락
    await tester.tap(find.text('친구 요청 1건'));
    await settle(tester);
    expect(find.text('친구B'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '수락'));
    await settle(tester);
    expect(server.friends, containsAll(['dongsaeng', 'friend_b']));
    expect(account.incomingCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('알림: 받은 친구 요청이 맨 위 · 수락하면 친구', (tester) async {
    await loadMe(tester);
    await show(tester, NotificationsScreen(myChannels: const ['gundam'], loaders: _loaders));
    expect(find.text('친구 요청'), findsWidgets);
    expect(find.text('친구B님의 친구 요청'), findsOneWidget);
    await tester.tap(find.text('친구B님의 친구 요청'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, '수락'));
    await settle(tester);
    expect(server.friends, contains('friend_b'));
    expect(find.text('친구B님의 친구 요청'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('아이디로 친구 추가: 찾기 → 친구 요청', (tester) async {
    server.users['new_one'] = (name: '새친구', collection: const {});
    await loadMe(tester);
    await show(tester, ProfileScreen(loaders: _loaders, onJump: (_) {}));
    expect(find.text('@bbang'), findsWidgets);
    await tester.tap(find.text('아이디로 친구 추가'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, '친구 아이디'), 'New_One');
    await tester.tap(find.text('찾기'));
    await settle(tester);
    expect(find.text('새친구'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '친구 요청'));
    await settle(tester);
    expect(server.outgoing, contains('new_one'));
    expect(find.text('요청 취소'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('내 정보: 아이디가 없으면 정하라고 하고, 정하면 보인다', (tester) async {
    server.handle = null;
    await loadMe(tester);
    await show(tester, ProfileScreen(loaders: _loaders, onJump: (_) {}));
    expect(find.text('아이디 없음'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '아이디 정하기'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'bbang_2');
    await tester.tap(find.widgetWithText(FilledButton, '정하기'));
    await settle(tester);
    expect(server.handle, 'bbang_2');
    expect(find.text('@bbang_2'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('친구 보기: 계정에서 숫자를 받고, 친구 끊기', (tester) async {
    await loadMe(tester);
    const friend = Member(name: '동생', handle: 'dongsaeng', role: '친구', self: false, liked: 0, lit: 0, owned: 0);
    await show(tester, ProfileScreen(friend: friend, loaders: _loaders));
    expect(find.text('Lv.1'), findsOneWidget); // lit 2 → 1 + 4 ~/ 5
    expect(find.text('1'), findsWidgets); // 좋아요 1 · 구매함 1
    await tester.tap(find.text('친구 끊기'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, '친구 끊기'));
    await settle(tester);
    expect(server.friends, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('로그아웃 상태: 내 정보 · 서랍은 로그인 안내', (tester) async {
    auth.signedIn = false;
    await show(tester, ProfileScreen(loaders: _loaders, onJump: (_) {}));
    expect(find.text('로그인 전'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '로그인'), findsOneWidget);
    expect(server.calls, isEmpty);
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
