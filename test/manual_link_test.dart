// 공식 조립 설명서 (D-17 → X): Gunpula 가 이름으로 이은 manual_id 가 있는 상품만 「조립 설명서」 줄
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/data/gunpula.dart';
import 'package:hobby_atlas/data/user_store.dart';
import 'package:hobby_atlas/detail_pane.dart';
import 'package:hobby_atlas/marks.dart';
import 'package:hobby_atlas/models.dart';
import 'package:hobby_atlas/screens/d_kit_detail_screen.dart';
import 'package:hobby_atlas/screens/x_manual_screen.dart';
import 'package:hobby_atlas/theme.dart';

import 'layout_test.dart' show fakeLoaders;

List<Kit> _kits({int? manualId}) {
  final doc =
      jsonDecode(File('test/fixtures/kits-gundam-boxart.sample.json').readAsStringSync()) as Map<String, Object?>;
  final first = (doc['kits']! as List).first as Map<String, Object?>;
  if (manualId != null) first['manual_id'] = manualId;
  return [
    for (final j in mapKitsJob({'raw': jsonEncode(doc)})) Kit.fromSlim(j, recentSince: '', monthPrefix: '2026-11'),
  ];
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
  test('manual_id → Kit.manualId, 없으면 0', () {
    expect(_kits(manualId: 2234).first.manualId, 2234);
    expect(_kits().first.manualId, 0);
    expect(manualViewerUri(2234).toString(), 'https://manual.bandai-hobby.net/viewer.php?file=/pdf/2234.pdf');
  });

  testWidgets('설명서가 있는 상품만 「조립 설명서」 줄 → 누르면 X 화면', (tester) async {
    await _pump(tester, KitDetailScreen(kit: _kits().first, loaders: fakeLoaders));
    expect(find.byKey(const ValueKey('manual-link')), findsNothing);

    final kit = _kits(manualId: 2234).first;
    await _pump(tester, KitDetailScreen(kit: kit, loaders: fakeLoaders));
    final link = find.byKey(const ValueKey('manual-link'));
    await tester.scrollUntilVisible(link, 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('조립 설명서'), findsOneWidget);
    await tester.ensureVisible(link);
    await tester.pump();
    await tester.tap(link, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(ManualScreen), findsOneWidget);
    // 테스트에는 WebView 가 없다 → 브라우저로 열 수 있다고 알린다 (X-3)
    expect(find.text('이 기기에서는 앱 안에서 볼 수 없어요'), findsOneWidget);
    expect(find.text(kit.name), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
