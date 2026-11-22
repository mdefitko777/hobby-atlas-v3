// 앱 업데이트: version.json 읽기 · 새 빌드면 ⬇ 아이콘 · 시트(바뀐 점 · 이 버전 건너뛰기) · 설정 버전 줄
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/data/blob_store.dart';
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

/// 더 새 빌드의 version.json
String _newer(int build) =>
    jsonEncode({...jsonDecode(_json) as Map<String, Object?>, 'build': build, 'version': '1.1.$build'});

void main() {
  final u = AppUpdate.instance;
  setUp(() {
    u.debugReset();
    // 건너뛴 빌드 · 물어본 빌드는 기기 파일에 적힌다 — 테스트마다 빈 폴더로
    BlobStore.debugDirectory = Directory.systemTemp.createTempSync('ha_update');
  });

  test('version.json → UpdateInfo · [minor] 는 묻지 않음 · 빌드 없으면 버림', () {
    final i = UpdateInfo.fromJson(jsonDecode(_json))!;
    expect(i.build, 42);
    expect(i.versionLabel, '1.1.42');
    expect(UpdateInfo.fromJson({'build': 5})!.versionLabel, '버전 5'); // 옛 version.json
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

  testWidgets('새 빌드가 있으면 ⬇ → 시트에 바뀐 점 · 설정 줄에 "새 버전"', (tester) async {
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
    expect(find.text('Hobby Atlas · 개발 버전'), findsOneWidget);

    await u.check(fetch: (_) async => _json);
    await tester.pump();
    expect(find.byTooltip('업데이트'), findsOneWidget);
    // 작은 글씨는 이름 · 번호만, 새 버전 소식은 줄 오른쪽 끝 (2026-11-22)
    expect(find.text('Hobby Atlas · 개발 버전'), findsOneWidget);
    expect(find.text('새 버전 1.1.42 ›'), findsOneWidget);

    await tester.tap(find.byTooltip('업데이트'));
    await tester.pumpAndSettle();
    expect(find.text('새 버전이 있어요'), findsOneWidget);
    expect(find.text('· 공식 예고 상세 = 원문을 앱 안에서 (WebView)'), findsOneWidget);
    expect(find.text('나중에'), findsOneWidget);
    await tester.tap(find.text('나중에'));
    await tester.pumpAndSettle();
    expect(find.text('새 버전이 있어요'), findsNothing);
    expect(find.byTooltip('업데이트'), findsOneWidget, reason: '나중에 = 시트만 닫는다, ⬇ 는 남는다');
  });

  test('이 버전 건너뛰기 — ⬇ · 열 때 묻기는 쉬고, 손으로 확인하거나 더 새 빌드면 다시 나온다', () async {
    expect(await u.check(fetch: (_) async => _json), isNotNull);
    await u.skip(u.available!);
    expect(u.available, isNull, reason: '시트를 닫는 순간 ⬇ 가 사라진다');
    expect(await u.shouldAsk(UpdateInfo.fromJson(jsonDecode(_json))!), isFalse);

    u.debugReset(); // 앱을 다시 열었다 (건너뛴 번호는 기기에 남아 있다)
    expect(await u.check(fetch: (_) async => _json), isNull);
    expect(u.available, isNull);
    // 설정 › 앱 › 버전에서 손으로 확인 = force → 건너뛴 버전도 돌려준다 (안 그러면 영영 못 받는다)
    expect((await u.check(force: true, fetch: (_) async => _json))!.build, 42);
    // 받는 동안 ⬇(진행률) · 설정 줄의 「새 버전」을 따라갈 수 있게 available 도 다시 찬다
    expect(u.available?.build, 42);
    // 그래도 앱을 열 때 또 묻지는 않는다 (건너뛰기는 "조르지 마라")
    expect(await u.shouldAsk(u.available!), isFalse);

    u.debugReset();
    expect(await u.check(fetch: (_) async => _newer(43)), isNotNull, reason: '더 새 빌드는 다시 뜬다');
    expect(u.available!.versionLabel, '1.1.43');
  });

  testWidgets('시트의 「이 버전 건너뛰기」 → ⬇ 가 사라지고 어디서 받는지 알려 준다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildGpTheme(),
        home: Scaffold(
          appBar: AppBar(actions: const [UpdateButton()]),
          body: const SizedBox.shrink(),
        ),
      ),
    );
    await u.check(fetch: (_) async => _json);
    await tester.pump();
    await tester.tap(find.byTooltip('업데이트'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('update-skip')));
    await tester.pumpAndSettle();
    expect(find.text('새 버전이 있어요'), findsNothing);
    expect(find.byTooltip('업데이트'), findsNothing);
    // 시트 안 작은 글이 아니라 토스트로 (시트는 닫혔다)
    expect(find.descendant(of: find.byType(SnackBar), matching: find.text('설정 › 앱 › 버전에서 받을 수 있어요')), findsOneWidget);
  });

  testWidgets('작은 폰(320×568)에서도 두 시트가 넘치지 않는다 — 바뀐 점 8줄 + 단추 + 작은 글', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final notes = [for (var i = 0; i < 8; i++) '아주 긴 커밋 제목 $i — 공식 예고 상세 = 원문을 앱 안에서 (WebView) 그리고 더 긴 글'];
    final info = UpdateInfo.fromJson({...jsonDecode(_json) as Map<String, Object?>, 'notes': notes})!;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildGpTheme(),
        home: Builder(
          builder: (c) => Scaffold(
            body: Column(
              children: [
                ElevatedButton(onPressed: () => showUpdateSheet(c, info), child: const Text('apk')),
                ElevatedButton(
                  onPressed: () => showPatchSheet(c, versionLabel: '1.1.42 · 패치 3', notes: notes),
                  child: const Text('patch'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    for (final open in ['apk', 'patch']) {
      await tester.tap(find.text(open));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$open 시트가 넘쳤다 (길면 스크롤이어야 한다)');
      expect(find.byType(SingleChildScrollView), findsWidgets);
      await tester.tapAt(const Offset(160, 20)); // 바깥을 눌러 닫기
      await tester.pumpAndSettle();
    }
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
