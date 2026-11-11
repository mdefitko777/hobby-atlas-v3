// 앱 업데이트: version.json 읽기 · 새 빌드면 ⬇ 아이콘 · 시트(바뀐 점) · 설정 버전 줄
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/l10n/l10n.dart';
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

  test('못 받으면 checkFailed — 「최신 버전」과 구별 · 한 시간 간격을 쓰지 않아 다음 확인은 바로 다시', () async {
    var fetches = 0;
    expect(
      await u.check(
        fetch: (_) async {
          fetches++;
          return null; // 켤 때 오프라인
        },
      ),
      isNull,
    );
    expect(u.checkFailed, isTrue);
    // 인터넷이 돌아온 뒤 (force 아님) — 한 시간을 기다리지 않고 다시 받는다
    expect(
      await u.check(
        fetch: (_) async {
          fetches++;
          return _json;
        },
      ),
      isNotNull,
    );
    expect(fetches, 2);
    expect(u.checkFailed, isFalse);
    // 받은 뒤로는 한 시간에 한 번
    await u.check(
      fetch: (_) async {
        fetches++;
        return _json;
      },
    );
    expect(fetches, 2);
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

  test('바뀐 점: 중국어 화면은 notes_zh 만 (없으면 빈 목록 = 칸 숨김) · 한국어 화면은 notes', () {
    addTearDown(() => L10n.debugSet(AppLang.ko));
    final withZh = UpdateInfo.fromJson({
      ...jsonDecode(_json) as Map<String, Object?>,
      'notes_zh': ['通知跟随语言'],
    })!;
    final old = UpdateInfo.fromJson(jsonDecode(_json))!; // notes_zh 가 없는 version.json
    L10n.debugSet(AppLang.ko);
    expect(withZh.shownNotes, withZh.notes);
    expect(old.shownNotes, hasLength(2));
    L10n.debugSet(AppLang.zh);
    expect(withZh.shownNotes, ['通知跟随语言']);
    expect(old.shownNotes, isEmpty, reason: '한국어 커밋 제목은 중국어 화면에 보이지 않는다');
  });
}
