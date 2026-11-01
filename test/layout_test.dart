// 화면 크기별 배치 테스트 — 작은 폰 · 보통 폰 · 가로 폰 · 태블릿 · 넓은 창에서
// 주요 화면을 그려 보고, 넘침(RenderFlex overflowed) 같은 그리기 오류가 없는지 확인한다.
// 데이터는 mock_server/db.json 을 직접 읽는 가짜 Loaders (서버 없이 돌아감).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/api.dart';
import 'package:hobby_atlas/clock.dart';
import 'package:hobby_atlas/data/user_store.dart';
import 'package:hobby_atlas/detail_pane.dart';
import 'package:hobby_atlas/marks.dart';
import 'package:hobby_atlas/widgets.dart';
import 'package:hobby_atlas/models.dart';
import 'package:hobby_atlas/notifications/notify_store.dart';
import 'package:hobby_atlas/screens/d_kit_detail_screen.dart';
import 'package:hobby_atlas/screens/f_collection_screen.dart';
import 'package:hobby_atlas/screens/g_guide_view.dart';
import 'package:hobby_atlas/screens/i_profile_screen.dart';
import 'package:hobby_atlas/screens/k_settings_screen.dart';
import 'package:hobby_atlas/screens/l_friend_collection_screen.dart';
import 'package:hobby_atlas/screens/n_notifications_screen.dart';
import 'package:hobby_atlas/screens/s_app_shell.dart';
import 'package:hobby_atlas/theme.dart';

final Map<String, Object?> db = jsonDecode(File('mock_server/db.json').readAsStringSync()) as Map<String, Object?>;

List<T> _list<T extends Object>(String key, T? Function(Object?) parse) =>
    (db[key]! as List).map(parse).nonNulls.toList();

int _byDateDesc(Kit a, Kit b) => b.date.compareTo(a.date);

/// db.json 을 그대로 쓰는 가짜 Loaders
final fakeLoaders = Loaders(
  kits: (ids) async =>
      _list<Kit>('kits', Kit.fromJson).where((k) => ids.contains(k.franchiseId)).toList()..sort(_byDateDesc),
  collection: () async =>
      _list<Kit>('kits', Kit.fromJson).where((k) => k.status != CollectStatus.none).toList()..sort(_byDateDesc),
  kitsByIds: (ids) async => _list<Kit>('kits', Kit.fromJson).where((k) => ids.contains(k.id)).toList(),
  worlds: (c) async => _list<World>('worlds', World.fromJson).where((w) => w.franchiseId == c).toList(),
  guideWorks: () async => _list<GuideWork>('guideWorks', GuideWork.fromJson),
  guideUnits: (id) async =>
      (db['guideUnits']! as List).where((u) => (u as Map)['workId'] == id).map(GuideUnit.fromJson).nonNulls.toList(),
  bbxTops: () async => _list<BbxTop>('bbxTops', BbxTop.fromJson),
  announcements: (ids) async =>
      _list<Announcement>('announcements', Announcement.fromJson).where((a) => ids.contains(a.franchiseId)).toList()
        ..sort((a, b) => b.date.compareTo(a.date)),
  profile: () async => Profile.fromJson(db['profile'])!,
  notifications: () async =>
      _list<AppNotice>('notifications', AppNotice.fromJson)..sort((a, b) => b.at.compareTo(a.at)),
);

/// 작은 폰 · 보통 폰 · 가로 폰 · 태블릿 세로 · 넓은 창
const sizes = <String, Size>{
  '작은 폰 320×568': Size(320, 568),
  '보통 폰 390×844': Size(390, 844),
  '가로 폰 844×390': Size(844, 390),
  '폴드 펼침 세로 690×830': Size(690, 830),
  '폴드 펼침 가로 830×690': Size(830, 690),
  '태블릿 768×1024': Size(768, 1024),
  '넓은 창 1280×800': Size(1280, 800),
};

Future<void> _show(WidgetTester tester, Size size, Widget home) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // 실제 앱(main.dart)처럼 맨 위에 좋아요 · 구매함 한 벌
  await tester.pumpWidget(
    MaterialApp(
      theme: buildGpTheme(),
      builder: (context, child) => MarksHost(store: UserStore.memory(), child: PaneHost(child: child!)),
      home: home,
    ),
  );
  // 끝없는 애니메이션(색 고리 · 배너 자동 넘김)이 있어 pumpAndSettle 대신 몇 번 나눠 그린다
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  fixedNow = DateTime(2026, 10, 25, 21); // 가짜 데이터(db.json)의 오늘
  final kit = _list<Kit>('kits', Kit.fromJson).firstWhere((k) => k.id == 'gu02');
  final friend = Profile.fromJson(db['profile'])!.friends.first;
  final seed = _list<GuideWork>('guideWorks', GuideWork.fromJson).firstWhere((w) => w.id == 'w3000');

  final screens = <String, Widget Function()>{
    '앱 셸 · 홈': () => AppShell(loaders: fakeLoaders),
    '상품 상세': () => KitDetailScreen(kit: kit, loaders: fakeLoaders),
    '내 정보': () => ProfileScreen(loaders: fakeLoaders, onJump: (_) {}),
    '친구 컬렉션': () => FriendCollectionScreen(friend: friend, initial: CollectionJump.guide, loaders: fakeLoaders),
    '알림': () => NotificationsScreen(
      myChannels: const ['gundam', 'beyblade', 'pokemon'],
      loaders: fakeLoaders,
      notify: NotifyStore.memory(),
    ),
    '설정 (알림 규칙)': () => SettingsScreen(notify: NotifyStore.memory()),
    '작품 도감': () => WorkGuideScreen(work: seed, loaders: fakeLoaders),
  };

  for (final s in sizes.entries) {
    group(s.key, () {
      for (final e in screens.entries) {
        testWidgets(e.key, (tester) async {
          await _show(tester, s.value, e.value());
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets('앱 셸 · 탭 4개 돌기', (tester) async {
        await _show(tester, s.value, AppShell(loaders: fakeLoaders));
        for (final icon in [Icons.search, Icons.calendar_today_outlined, Icons.auto_awesome_mosaic_outlined]) {
          await tester.tap(find.byIcon(icon).last);
          for (var i = 0; i < 5; i++) {
            await tester.pump(const Duration(milliseconds: 300));
          }
          expect(tester.takeException(), isNull);
        }
      });
    });
  }

  // 반반 화면: 왼쪽에서 상품을 누르면 오른쪽 칸에 상세 (왼쪽 앱은 그대로)
  for (final size in const [Size(830, 690), Size(1280, 800)]) {
    testWidgets('반반 화면 ${size.width.toInt()}×${size.height.toInt()} · 상품 → 오른쪽 칸', (tester) async {
      await _show(tester, size, AppShell(loaders: fakeLoaders));
      expect(find.byType(DetailPaneView), findsOneWidget);
      expect(find.text('상품 · 공고 · 친구를 고르면 여기에 보여요'), findsOneWidget);
      // 홈 위쪽(내 보드 · 아이콘 칸 · 배너) 아래에 있는 상품 줄까지 내린다
      final vertical = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down);
      for (var i = 0; i < 6 && find.byType(ProductTile).evaluate().isEmpty; i++) {
        await tester.drag(vertical.first, const Offset(0, -300));
        await tester.pump(const Duration(milliseconds: 300));
      }
      tester.widget<ProductTile>(find.byType(ProductTile).first).onTap(); // 탭 바에 가려질 수 있어 직접 호출
      await tester.drag(vertical.first, const Offset(0, 3000)); // 다시 맨 위 (검색창이 보이게)
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(find.byType(KitDetailScreen), findsOneWidget);
      expect(find.descendant(of: find.byType(DetailPaneView), matching: find.byType(KitDetailScreen)), findsOneWidget);
      expect(find.byType(GpSearchBar), findsWidgets); // 왼쪽 홈은 그대로
      expect(paneSelectedId(tester.element(find.byType(DetailPaneView))), isNotNull); // 왼쪽에서 그 카드가 칠해짐
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('폰(390×844)에서는 칸 없이 쌓기', (tester) async {
    await _show(tester, const Size(390, 844), AppShell(loaders: fakeLoaders));
    expect(find.byType(DetailPaneView), findsNothing);
  });

  // 좋아요 · 구매함 한 벌: 상품 사진에서 ♡ 를 누르면 다른 화면(여기선 글자)도 같이 바뀐다
  testWidgets('좋아요 한 벌 — 한 곳에서 누르면 다른 곳도 바뀜', (tester) async {
    final none = _list<Kit>('kits', Kit.fromJson).firstWhere((k) => k.status == CollectStatus.none);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildGpTheme(),
        builder: (context, child) => MarksHost(store: UserStore.memory(), child: child!),
        home: Scaffold(
          body: Column(
            children: [
              SizedBox.square(dimension: 150, child: QuickMarks(kit: none)),
              Builder(builder: (c) => Text(Marks.of(c).liked(none) ? '좋아요 켜짐' : '좋아요 꺼짐')),
              Builder(builder: (c) => Text(Marks.of(c).owned(none) ? '구매함 켜짐' : '구매함 꺼짐')),
            ],
          ),
        ),
      ),
    );
    expect(find.text('좋아요 꺼짐'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pump();
    expect(find.text('좋아요 켜짐'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add)); // 리본 +
    await tester.pump();
    expect(find.text('구매함 켜짐'), findsOneWidget);
  });
}
