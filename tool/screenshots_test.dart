// README · 발표자료 · 원칙 카드용 스크린샷을 만든다 (서버 · 브라우저 없이, db.json 가짜 Loaders).
// 쓰는 법 (Windows, 프로젝트 폴더에서):  flutter test tool/screenshots_test.dart
// 결과: docs/screenshots/*.png — 한글은 Windows 의 맑은 고딕(malgun.ttf), 아이콘은 Flutter 의 MaterialIcons 를 불러 그린다.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/api.dart';
import 'package:hobby_atlas/detail_pane.dart';
import 'package:hobby_atlas/marks.dart';
import 'package:hobby_atlas/models.dart';
import 'package:hobby_atlas/screens/c_channel_screen.dart';
import 'package:hobby_atlas/screens/d_kit_detail_screen.dart';
import 'package:hobby_atlas/screens/e_camera_screen.dart';
import 'package:hobby_atlas/screens/f_collection_screen.dart';
import 'package:hobby_atlas/screens/g_guide_view.dart';
import 'package:hobby_atlas/screens/i_profile_screen.dart';
import 'package:hobby_atlas/screens/k_settings_screen.dart';
import 'package:hobby_atlas/screens/l_friend_collection_screen.dart';
import 'package:hobby_atlas/screens/n_notifications_screen.dart';
import 'package:hobby_atlas/screens/s_app_shell.dart';
import 'package:hobby_atlas/theme.dart';
import 'package:hobby_atlas/widgets.dart';

import '../test/layout_test.dart' show db, fakeLoaders;

const _out = 'docs/screenshots';
final _shot = GlobalKey();

Future<void> _loadFonts() async {
  ByteData bytes(String path) => ByteData.view(Uint8List.fromList(File(path).readAsBytesSync()).buffer);
  const fonts = r'C:\Windows\Fonts';
  for (final family in ['Roboto', 'FlutterTest', '.SF UI Text', '.SF UI Display']) {
    final l = FontLoader(family)
      ..addFont(Future.value(bytes('$fonts\\malgun.ttf')))
      ..addFont(Future.value(bytes('$fonts\\malgunbd.ttf')));
    await l.load();
  }
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '';
  final icons = File('$flutterRoot/bin/cache/artifacts/material_fonts/materialicons-regular.otf');
  final l = FontLoader('MaterialIcons')..addFont(Future.value(bytes(icons.path)));
  await l.load();
}

Future<void> _settle(WidgetTester tester, {int frames = 6}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  // 사진(Image.asset)을 실제로 풀어 그리기
  await tester.runAsync(() async {
    for (final e in find.byType(Image).evaluate().toList()) {
      final img = e.widget as Image;
      try {
        await precacheImage(img.image, e);
      } catch (_) {}
    }
  });
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _save(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_shot));
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  });
  File('$_out/$name.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!);
}

// 테스트 엔진은 글꼴 이름이 없는 글자를 네모로 그린다 — 테마가 통째로 정한 글자(버튼 · 제목 줄)에만 이름을 붙여 준다(앱 테마는 그대로).
ThemeData _theme() {
  final th = buildGpTheme();
  return th.copyWith(
    appBarTheme: th.appBarTheme.copyWith(titleTextStyle: th.appBarTheme.titleTextStyle?.copyWith(fontFamily: 'Roboto')),
    filledButtonTheme: FilledButtonThemeData(
      style: th.filledButtonTheme.style?.copyWith(
        textStyle: const WidgetStatePropertyAll(TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.w700)),
      ),
    ),
  );
}

Future<void> _open(WidgetTester tester, Size size, Widget home) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _shot,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _theme(),
        builder: (context, child) => MarksHost(child: PaneHost(child: child!)),
        home: home,
      ),
    ),
  );
  await _settle(tester);
}

const phone = Size(390, 844);

void main() {
  setUpAll(_loadFonts);
  final kits = [for (final k in db['kits']! as List) Kit.fromJson(k)!];
  final profile = Profile.fromJson(db['profile'])!;
  final seed = [for (final w in db['guideWorks']! as List) GuideWork.fromJson(w)!].firstWhere((w) => w.id == 'w3000');

  testWidgets('02 홈', (t) async {
    await _open(t, phone, AppShell(loaders: fakeLoaders));
    await _save(t, '02_v2_a');
  });

  testWidgets('03 상품 상세', (t) async {
    await _open(t, phone, KitDetailScreen(kit: kits.firstWhere((k) => k.id == 'gu02'), loaders: fakeLoaders));
    await _save(t, '03_v2_b');
  });

  testWidgets('04 도감', (t) async {
    await _open(t, phone, WorkGuideScreen(work: seed, loaders: fakeLoaders));
    await _save(t, '04_v2_c');
  });

  testWidgets('05 넓은 화면 (반반)', (t) async {
    await _open(t, const Size(1280, 800), AppShell(loaders: fakeLoaders));
    t.widget<ProductTile>(find.byType(ProductTile).first).onTap();
    await _settle(t);
    await _save(t, '05_v2_wide');
  });

  testWidgets('검색 · 전체 상품', (t) async {
    await _open(t, phone, AppShell(loaders: fakeLoaders));
    await t.tap(find.byIcon(Icons.search).last);
    await _settle(t);
    await _save(t, '10_search_all');
  });

  testWidgets('캘린더', (t) async {
    await _open(t, phone, AppShell(loaders: fakeLoaders));
    await t.tap(find.byIcon(Icons.calendar_today_outlined).last);
    await _settle(t);
    await _save(t, '11_calendar');
  });

  testWidgets('컬렉션', (t) async {
    await _open(t, phone, AppShell(loaders: fakeLoaders));
    await t.tap(find.byIcon(Icons.auto_awesome_mosaic_outlined).last);
    await _settle(t);
    await _save(t, '12_collection');
  });

  testWidgets('친구 서랍', (t) async {
    await _open(t, phone, AppShell(loaders: fakeLoaders));
    await t.tap(find.byType(RingAvatar).first);
    await _settle(t);
    await _save(t, '13_friends_drawer');
  });

  testWidgets('내 정보', (t) async {
    await _open(t, phone, ProfileScreen(loaders: fakeLoaders, onJump: (_) {}));
    await _save(t, '14_profile');
  });

  testWidgets('친구 컬렉션', (t) async {
    await _open(
      t,
      phone,
      FriendCollectionScreen(friend: profile.friends.first, initial: CollectionJump.owned, loaders: fakeLoaders),
    );
    await _save(t, '15_friend_collection');
  });

  testWidgets('알림', (t) async {
    await _open(t, phone, NotificationsScreen(myChannels: const ['gundam', 'beyblade', 'pokemon'], loaders: fakeLoaders));
    await _save(t, '16_notifications');
  });

  // 화면 비율별 홈 (layout_test 와 같은 7가지 크기)
  for (final size in const [Size(320, 568), Size(390, 844), Size(844, 390), Size(690, 830), Size(830, 690), Size(768, 1024), Size(1280, 800)]) {
    testWidgets('비율 ${size.width.toInt()}x${size.height.toInt()}', (t) async {
      await _open(t, size, AppShell(loaders: fakeLoaders));
      if (size.width >= 700 && size.height >= 520) {
        t.widget<ProductTile>(find.byType(ProductTile).first).onTap();
        await _settle(t);
      }
      await _save(t, '30_size_${size.width.toInt()}x${size.height.toInt()}');
    });
  }

  testWidgets('채널 관리', (t) async {
    await _open(t, phone, ChannelManagerScreen(initial: const ['gundam', 'beyblade', 'pokemon'], onChanged: (_) {}));
    await _save(t, '24_channel_manager');
  });

  testWidgets('설정', (t) async {
    await _open(t, phone, const SettingsScreen());
    await _save(t, '17_settings');
  });

  testWidgets('카메라 결과', (t) async {
    await _open(t, phone, CameraResultScreen(scene: photoScene, loaders: fakeLoaders, onGoSearch: () {}));
    await _save(t, '18_camera_result');
  });

  testWidgets('가로 폰', (t) async {
    await _open(t, const Size(844, 390), AppShell(loaders: fakeLoaders));
    await _save(t, '19_landscape');
  });

  testWidgets('폴드 펼침', (t) async {
    await _open(t, const Size(830, 690), AppShell(loaders: fakeLoaders));
    t.widget<ProductTile>(find.byType(ProductTile).at(1)).onTap();
    await _settle(t);
    await _save(t, '20_fold');
  });

  // 3상태 (발표 부록 B1) — 홈의 GET 이 끝나지 않을 때 · 실패할 때 · 비었을 때
  Loaders homeWith(Future<List<Kit>> Function(List<String>) kits) => Loaders(
    kits: kits,
    collection: fakeLoaders.collection,
    kitsByIds: fakeLoaders.kitsByIds,
    worlds: fakeLoaders.worlds,
    guideWorks: fakeLoaders.guideWorks,
    guideUnits: fakeLoaders.guideUnits,
    bbxTops: fakeLoaders.bbxTops,
    announcements: (ids) async => [],
    profile: fakeLoaders.profile,
    notifications: fakeLoaders.notifications,
  );

  testWidgets('상태 · 로딩', (t) async {
    await _open(t, phone, AppShell(loaders: homeWith((_) => Completer<List<Kit>>().future)));
    await _save(t, '21_state_loading');
  });

  testWidgets('상태 · 오류', (t) async {
    await _open(t, phone, AppShell(loaders: homeWith((_) async => throw 'localhost:3000 서버에 연결할 수 없어요')));
    await _save(t, '22_state_error');
  });

  testWidgets('상태 · 빈 채널', (t) async {
    await _open(t, phone, AppShell(loaders: homeWith((_) async => [])));
    await _save(t, '23_state_empty');
  });
}
