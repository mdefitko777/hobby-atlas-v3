// 중국어 화면 — 묶음 "detail" (상품 상세 · 설정 도움말 · 설명서 · 업데이트): 고른 언어를 따라 글이 바뀐다
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/data/gunpula.dart';
import 'package:hobby_atlas/data/user_store.dart';
import 'package:hobby_atlas/detail_pane.dart';
import 'package:hobby_atlas/l10n/l10n.dart';
import 'package:hobby_atlas/marks.dart';
import 'package:hobby_atlas/models.dart';
import 'package:hobby_atlas/screens/d_kit_detail_screen.dart';
import 'package:hobby_atlas/screens/k_settings_screen.dart';
import 'package:hobby_atlas/screens/x_manual_screen.dart';
import 'package:hobby_atlas/theme.dart';
import 'package:hobby_atlas/update/app_update.dart';

import 'layout_test.dart' show fakeLoaders;

Kit _kit() {
  final doc =
      jsonDecode(File('test/fixtures/kits-gundam-boxart.sample.json').readAsStringSync()) as Map<String, Object?>;
  final first = (doc['kits']! as List).first as Map<String, Object?>;
  first['manual_id'] = 2234;
  return Kit.fromSlim(mapKitsJob({'raw': jsonEncode(doc)}).first, recentSince: '', monthPrefix: '2026-11');
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
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUp(() => L10n.debugSet(AppLang.zh));
  tearDown(() => L10n.debugSet(AppLang.ko));

  testWidgets('상품 상세: 중국어 화면이면 정가 · 시세 · 아래 띠가 중국어', (tester) async {
    await _pump(tester, KitDetailScreen(kit: _kit(), loaders: fakeLoaders));
    expect(find.text('日本定价'), findsOneWidget);
    expect(find.text('韩国行情'), findsOneWidget);
    expect(find.text('复制'), findsOneWidget);
    expect(find.text('喜欢'), findsOneWidget);
    expect(find.text('已购'), findsOneWidget);
    expect(find.text('일본 정가'), findsNothing);
    final link = find.byKey(const ValueKey('manual-link'));
    await tester.scrollUntilVisible(link, 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('组装说明书'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 1)); // 본 기록 저장 타이머(0.4초)를 마저 보낸다
  });

  test('상품 상세 도움말은 열 때의 언어로', () {
    expect(detailHelp.first.text, '喜欢（想要的）');
    L10n.debugSet(AppLang.ko);
    expect(detailHelp.first.text, '좋아요 (갖고 싶은 것)');
  });

  testWidgets('설명서 · 설정 도움말: 중국어', (tester) async {
    await _pump(tester, const ManualScreen(id: 2234, kitName: 'RG'));
    expect(find.text('组装说明书'), findsOneWidget);
    expect(find.text('这台设备不能在 App 里看'), findsOneWidget);
    expect(find.text('用浏览器'), findsOneWidget);

    await _pump(tester, const HelpScreen());
    expect(find.text('帮助'), findsOneWidget);
    expect(find.text('图鉴格子'), findsOneWidget);
    expect(find.text('每 12 小时检查一次'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('업데이트: 빌드 이름도 화면 언어로', () {
    expect(UpdateInfo.fromJson({'build': 5})!.versionLabel, '构建 5');
  });
}
