// 앱 업데이트: version.json 읽기 · 새 빌드면 ⬇ 아이콘 · 시트(바뀐 점) · 설정 버전 줄
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/theme.dart';
import 'package:hobby_atlas/update/app_update.dart';
import 'package:hobby_atlas/update/update_ui.dart';

final _json = jsonEncode({
  'build': 42,
  'version': '1.1.42',
  'sha': 'abc',
  'built_at': '2026-11-02T03:00:00Z',
  'major': true,
  'apk': 'hobby-atlas.apk',
  'sha256': 'ff',
  'size': 31457280,
  'notes': ['공식 예고 상세 = 원문을 앱 안에서 (WebView)', '앱 업데이트'],
});

void main() {
  final u = AppUpdate.instance;
  setUp(u.debugReset);

  test('version.json → UpdateInfo · [minor] 는 묻지 않음 · 빌드 없으면 버림', () {
    final i = UpdateInfo.fromJson(jsonDecode(_json))!;
    expect(i.build, 42);
    expect(i.versionLabel, '1.1.42');
    expect(UpdateInfo.fromJson({'build': 5})!.versionLabel, '빌드 5'); // 옛 version.json
    expect(i.major, isTrue);
    expect(i.sizeLabel, '30 MB');
    expect(i.notes, hasLength(2));
    expect(UpdateInfo.fromJson({'build': 43, 'major': false})!.major, isFalse);
    expect(UpdateInfo.fromJson({'sha': 'x'}), isNull);
  });

  test('내 빌드보다 새것만 · 못 받으면 그대로', () async {
    expect(appBuild, 0); // 테스트 = 개발 빌드
    expect(await u.check(fetch: (_) async => _json), isNotNull);
    expect(u.available!.build, 42);
    expect(await u.check(force: true, fetch: (_) async => null), isNotNull); // 오프라인 → 지난 결과
    expect(await u.check(force: true, fetch: (_) async => jsonEncode({'build': 0})), isNull);
  });

  testWidgets('새 빌드가 있으면 ⬇ → 시트에 바뀐 점 · 설정 줄에 "있음"', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildGpTheme(),
        home: Scaffold(
          appBar: AppBar(actions: const [UpdateButton()]),
          body: const VersionTile(),
        ),
      ),
    );
    expect(find.byTooltip('업데이트'), findsNothing);
    expect(find.text('Hobby Atlas · 개발 빌드'), findsOneWidget);

    await u.check(fetch: (_) async => _json);
    await tester.pump();
    expect(find.byTooltip('업데이트'), findsOneWidget);
    expect(find.text('Hobby Atlas · 개발 빌드 → 1.1.42 있음'), findsOneWidget);

    await tester.tap(find.byTooltip('업데이트'));
    await tester.pumpAndSettle();
    expect(find.text('새 버전이 있어요'), findsOneWidget);
    expect(find.text('· 공식 예고 상세 = 원문을 앱 안에서 (WebView)'), findsOneWidget);
    expect(find.text('나중에'), findsOneWidget);
    await tester.tap(find.text('나중에'));
    await tester.pumpAndSettle();
    expect(find.text('새 버전이 있어요'), findsNothing);
  });
}
