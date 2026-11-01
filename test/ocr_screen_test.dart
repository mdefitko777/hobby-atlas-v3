// 사진 · 공유로 찾기 화면 (E-8 · E-11 ~ E-16) — 기기 글자 읽기(ML Kit)는 가짜로 바꿔 끼운다
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/api.dart';
import 'package:hobby_atlas/data/user_store.dart';
import 'package:hobby_atlas/detail_pane.dart';
import 'package:hobby_atlas/marks.dart';
import 'package:hobby_atlas/models.dart';
import 'package:hobby_atlas/ocr/ocr_catalog.dart';
import 'package:hobby_atlas/ocr/text_reader.dart';
import 'package:hobby_atlas/screens/d_kit_detail_screen.dart';
import 'package:hobby_atlas/screens/e_photo_find_screen.dart';
import 'package:hobby_atlas/screens/s_app_shell.dart';
import 'package:hobby_atlas/share/share_intake.dart';
import 'package:hobby_atlas/theme.dart';

import 'layout_test.dart' show fakeLoaders;
import 'ocr_lookup_test.dart' show aerialBox, catalog;

/// 1×1 PNG (Image.memory 가 풀 수 있는 진짜 그림)
final _png = Uint8List.fromList(
  base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='),
);

final _loaders = Loaders(kits: (_) async => catalog, kitsByIds: (ids) async => [for (final k in catalog) if (ids.contains(k.id)) k]);

Future<void> _pump(WidgetTester tester, Widget home, UserStore store) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildGpTheme(),
      builder: (context, child) => MarksHost(store: store, child: PaneHost(child: child!)),
      home: home,
    ),
  );
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  setUp(() => ocrModelSource = () async => const {});
  tearDown(() => textReader = (_) async => '');

  testWidgets('사진 → 글자 조각 칩 · 후보 (일치도 · 맞은 조각) · ♡ · 칩 끄기', (tester) async {
    textReader = (_) async => aerialBox;
    final store = UserStore.memory();
    await _pump(tester, PhotoFindScreen(photo: _png, loaders: _loaders, onGoSearch: () {}), store);
    expect(find.text('사진으로 찾기'), findsOneWidget);
    expect(find.textContaining('아직 없어요'), findsNothing); // 옛 "사진 인식 없음" 안내는 없다
    // E-12 읽은 조각
    expect(find.text('XVX-016'), findsOneWidget);
    expect(find.text('1/144'), findsOneWidget);
    expect(find.text('BANDAI SPIRITS'), findsNothing);
    // E-13 후보: 첫 줄 = HG 에어리얼, 일치도 알약 + 맞은 조각
    expect(find.text('후보'), findsOneWidget);
    final first = find.text('HG 1 / 144 건담エアリアル');
    expect(first, findsOneWidget);
    expect(find.textContaining('HG · 1/144'), findsWidgets);
    expect(find.textContaining(RegExp(r'^\d+%$')), findsWidgets);
    // ♡ 바로 표시
    final row = find.ancestor(of: first, matching: find.byType(InkWell)).first;
    await tester.tap(find.descendant(of: row, matching: find.byTooltip('좋아요')));
    await _settle(tester);
    expect(store.statusOf('hg-hg-1-144-4573102630308000'), CollectStatus.wanted);
    // 칩을 누르면 꺼진다 (가운데 줄) → 다시 누르면 켜진다
    await tester.tap(find.text('1/144'));
    await tester.pump();
    TextStyle? style() => tester.widget<Text>(find.text('1/144')).style;
    expect(style()?.decoration, TextDecoration.lineThrough);
    await tester.tap(find.text('1/144'));
    await tester.pump();
    expect(style()?.decoration, isNull);
    // 후보를 누르면 상세
    await tester.tap(first);
    await _settle(tester);
    expect(find.byType(KitDetailScreen), findsOneWidget);
  });

  testWidgets('글자가 없으면 "글자를 찾지 못했어요 · 이름으로 찾기" → 이름으로 찾기', (tester) async {
    textReader = (_) async => '';
    await _pump(tester, PhotoFindScreen(photo: _png, loaders: _loaders, onGoSearch: () {}), UserStore.memory());
    expect(find.text('글자를 찾지 못했어요 · 이름으로 찾기'), findsOneWidget);
    expect(find.text('후보'), findsNothing);
    await tester.enterText(find.byType(TextField), '사자비');
    await _settle(tester);
    expect(find.text('RG 1 / 144 사자비'), findsOneWidget);
  });

  testWidgets('읽기에 실패하면 (웹 · 모델 없음) 솔직하게 → 이름으로 찾기', (tester) async {
    textReader = (_) async => throw UnsupportedError('no');
    await _pump(tester, PhotoFindScreen(photo: _png, loaders: _loaders, onGoSearch: () {}), UserStore.memory());
    expect(find.text('글자를 읽지 못했어요 · 이름으로 찾기'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('맞는 상품이 없으면 낱말 맞추기로 (E-16) 또는 "못 찾았어요"', (tester) async {
    textReader = (_) async => '今日の天気\nWEATHER REPORT';
    await _pump(tester, PhotoFindScreen(photo: _png, loaders: _loaders, onGoSearch: () {}), UserStore.memory());
    expect(find.text('후보'), findsNothing);
    expect(find.text('맞는 상품을 못 찾았어요 · 이름으로 찾기'), findsOneWidget);
  });

  testWidgets('공유로 받은 주소 → 그 상품 100% (주소), 글 칸', (tester) async {
    await _pump(
      tester,
      PhotoFindScreen(
        sharedText: 'ガンダムエアリアル｜プレミアムバンダイ https://p-bandai.jp/item/item-1000188677/',
        loaders: _loaders,
        onGoSearch: () {},
      ),
      UserStore.memory(),
    );
    expect(find.text('공유로 찾기'), findsOneWidget);
    expect(find.byIcon(Icons.link), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('주소'), findsOneWidget);
    expect(find.text('HG 1 / 144 건담エアリアル'), findsOneWidget);
    expect(find.byTooltip('사진 붙이기'), findsNothing); // 사진이 없으면 붙이기 없음
  });

  testWidgets('앱 셸: 공유로 받은 것이 있으면 바로 공유로 찾기를 연다 (공유로 켜진 경우)', (tester) async {
    ShareIntake.instance.incoming.value = const SharedText('RG サザビー');
    await _pump(tester, AppShell(loaders: fakeLoaders), UserStore.memory());
    expect(find.byType(PhotoFindScreen), findsOneWidget);
    expect(find.text('공유로 찾기'), findsOneWidget);
    expect(ShareIntake.instance.incoming.value, isNull);
  });

  testWidgets('앱 셸: 켜져 있는 동안 받은 사진 → 사진으로 찾기 (붙이기 없음)', (tester) async {
    textReader = (_) async => aerialBox;
    readSharedFile = (_) async => _png;
    addTearDown(() => readSharedFile = (_) async => throw UnsupportedError(''));
    await _pump(tester, AppShell(loaders: fakeLoaders), UserStore.memory());
    expect(find.byType(PhotoFindScreen), findsNothing);
    ShareIntake.instance.incoming.value = const SharedImage('/cache/shot.png');
    await _settle(tester);
    final screen = tester.widget<PhotoFindScreen>(find.byType(PhotoFindScreen));
    expect(screen.photo, isNotNull);
    expect(screen.attachable, isFalse);
  });
}
