// 패치(코드 푸시): 번호 글자 · 받아 둔 패치 안내 · Shorebird 빌드가 아니면 아무것도 안 함 · 패치는 APK 알림을 띄우지 않음
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/l10n/l10n.dart';
import 'package:hobby_atlas/theme.dart';
import 'package:hobby_atlas/update/app_patch.dart';
import 'package:hobby_atlas/update/app_update.dart';
import 'package:hobby_atlas/update/update_ui.dart';
import 'package:hobby_atlas/widgets.dart';

import '../tool/release_plan.dart';

/// 가짜 Shorebird 엔진: [onServer] 번 패치가 서버에 있고, fetch 하면 기기에 받아 둔다
class _FakeSource implements PatchSource {
  _FakeSource({
    this.isAvailable = true,
    this.current,
    this.next,
    this.onServer,
    this.offline = false,
    this.arrivesAfterReads,
  });

  @override
  bool isAvailable;
  int? current;
  int? next;
  int? onServer;
  bool offline;

  /// 앱을 켤 때의 자동 받기가 받는 중: fetch 는 바로 돌아오고, 이만큼 더 읽은 뒤에야 받아 둔 패치가 보인다 (null = 바로)
  int? arrivesAfterReads;
  int reads = 0;
  int fetches = 0;

  @override
  Future<int?> currentPatch() async {
    reads++;
    return current;
  }

  @override
  Future<int?> nextPatch() async {
    final after = arrivesAfterReads;
    if (after != null && fetches > 0 && reads > after) next = onServer;
    return next;
  }

  @override
  Future<bool> fetch() async {
    fetches++;
    if (offline) throw StateError('offline');
    if (onServer != null && arrivesAfterReads == null) next = onServer;
    return onServer != null && onServer != current;
  }
}

void main() {
  final u = AppUpdate.instance;
  setUp(u.debugReset);

  test('번호 글자: 패치가 없으면 버전 그대로 · 있으면 「· 패치 n」 (중국어 화면은 补丁)', () {
    addTearDown(() => L10n.debugSet(AppLang.ko));
    expect(patchedLabel('1.1.60', null), '1.1.60');
    expect(patchedLabel('1.1.60', 3), '1.1.60 · 패치 3');
    L10n.debugSet(AppLang.zh);
    expect(patchedLabel('1.1.60', 3), '1.1.60 · 补丁 3');
  });

  test('Shorebird 빌드가 아니면 아무것도 하지 않는다 (테스트 · 디버그 · 웹 · 손으로 만든 빌드)', () async {
    // 엔진을 주지 않음 + 개발 빌드 → 엔진을 찾지도 않는다
    final none = AppPatch();
    expect(none.available, isFalse);
    await none.refresh();
    await none.check();
    expect(none.waiting, isFalse);
    expect(none.failed, isFalse);
    expect(none.versionLabel, '개발 빌드');

    // 엔진이 없는 빌드(isAvailable = false)는 읽지도 받지도 않는다
    final source = _FakeSource(isAvailable: false, current: 2, next: 3, onServer: 4);
    final off = AppPatch(source: source);
    await off.refresh();
    await off.check();
    expect(off.available, isFalse);
    expect(off.current, isNull);
    expect(off.waiting, isFalse);
    expect(source.reads + source.fetches, 0);
  });

  test('읽기: 돌고 있는 패치 · 받아 둔 패치가 다르면 기다리는 중', () async {
    final source = _FakeSource(current: 2, next: 2);
    final p = AppPatch(source: source);
    var changes = 0;
    p.addListener(() => changes++);
    await p.refresh();
    expect(p.versionLabel, '개발 빌드 · 패치 2');
    expect(p.waiting, isFalse);
    await p.refresh();
    expect(changes, 1, reason: '달라진 게 없으면 다시 그리지 않는다');

    source.next = 3; // 뒤에서 자동으로 받아 둠
    await p.refresh();
    expect(p.waiting, isTrue);
    expect(p.nextLabel, '개발 빌드 · 패치 3');
    expect(p.versionLabel, '개발 빌드 · 패치 2', reason: '다시 열기 전에는 지금 패치 그대로');

    source.next = null; // 패치를 되돌림 → 다시 열면 릴리스로
    await p.refresh();
    expect(p.waiting, isTrue);
  });

  test('지금 확인: 서버에 새 패치가 있으면 받아 둔다 · 못 받으면 failed, 앱은 그대로', () async {
    final source = _FakeSource(onServer: 1);
    final p = AppPatch(source: source);
    await p.check();
    expect(source.fetches, 1);
    expect(p.waiting, isTrue);
    expect(p.next, 1);
    expect(p.failed, isFalse);

    final offline = AppPatch(source: _FakeSource(current: 1, next: 1, offline: true));
    await offline.check();
    expect(offline.failed, isTrue);
    expect(offline.waiting, isFalse);
    expect(offline.current, 1);

    // 서버에도 새 패치가 없다 → 기다리지 않고 「최신」
    final latest = _FakeSource(current: 1, next: 1, onServer: 1);
    final same = AppPatch(source: latest, settle: Duration.zero);
    await same.check();
    expect(same.waiting, isFalse);
    expect(same.failed, isFalse);
    expect(latest.reads, 1);
  });

  test('지금 확인: 켤 때의 자동 받기가 아직 받는 중이면 잠깐 기다려 본다 — 받는 중인 것을 「최신」이라고 하지 않는다', () async {
    // 세 번째로 읽을 때 받아 둔 패치가 보인다
    final slow = _FakeSource(current: 1, next: 1, onServer: 2, arrivesAfterReads: 2);
    final p = AppPatch(source: slow, settle: Duration.zero);
    await p.check();
    expect(p.waiting, isTrue);
    expect(p.next, 2);
    expect(p.failed, isFalse);

    // 끝내 안 보이면 못 받은 것 (10번까지만 본다)
    final never = _FakeSource(current: 1, next: 1, onServer: 2, arrivesAfterReads: 1000);
    final q = AppPatch(source: never, settle: Duration.zero);
    await q.check();
    expect(q.waiting, isFalse);
    expect(q.failed, isTrue);
    expect(never.reads, 11);
  });

  test('version.json: 패치는 build 를 올리지 않는다 → ⬇ · 묻기가 뜨지 않고, patch 칸의 바뀐 점만 읽힌다', () async {
    addTearDown(() => L10n.debugSet(AppLang.ko));
    // 워크플로가 쓰는 그 함수로 만든다: APK 60 → 그 위에 패치 3
    final apk = releaseJson(
      build: 60,
      version: '1.1.60',
      sha: 'r60',
      builtAt: '2026-11-13T00:00:00Z',
      major: true,
      sha256: 'ff',
      size: 1,
      notes: ['지난 APK 의 바뀐 점'],
    );
    final patched = patchJson(
      apk,
      number: 3,
      sha: 'p3',
      builtAt: '2026-11-14T00:00:00Z',
      notes: ['찾기 화면 고침'],
      notesZh: ['修了搜索页'],
    );
    // 앱이 보는 APK 쪽 값은 패치 전과 같다 → build 60 을 쓰는 폰에는 새 APK 가 아니다 (available 은 build 로만 정한다)
    final before = UpdateInfo.fromJson(apk)!;
    final after = UpdateInfo.fromJson(patched)!;
    expect(after.build, before.build);
    expect(after.sha256, before.sha256);
    expect(after.major, before.major);
    expect(after.notes, before.notes, reason: 'APK 시트의 바뀐 점에 패치 글이 섞이지 않는다');

    await u.check(fetch: (_) async => jsonEncode(patched));
    expect(u.patch!.number, 3);
    expect(u.patchNotes(3, build: 60), ['찾기 화면 고침']);
    expect(u.patchNotes(2, build: 60), isEmpty, reason: '다른 번호의 바뀐 점은 보이지 않는다');
    expect(u.patchNotes(3), isEmpty, reason: '다른 APK(내 빌드 = 0) 위의 패치');
    L10n.debugSet(AppLang.zh);
    expect(u.patchNotes(3, build: 60), ['修了搜索页']);

    // patch 칸이 빈 version.json (옛 것 · 새 APK 직후)
    await u.check(force: true, fetch: (_) async => jsonEncode(apk));
    expect(u.patch, isNull);
    expect(PatchInfo.fromJson({'number': 0}), isNull);
    expect(PatchInfo.fromJson(null), isNull);
  });

  testWidgets('설정 버전 줄: 패치 번호 · 받아 둔 패치가 있으면 한 줄 · 확인을 누르면 받고 시트', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final source = _FakeSource(current: 2, next: 2);
    final p = AppPatch(source: source);
    u.patch = const PatchInfo(build: appBuild, number: 3, notes: ['찾기 화면 고침']);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildGpTheme(),
        home: Scaffold(body: VersionTile(patch: p)),
      ),
    );
    await tester.pump();
    final waiting = find.byKey(const Key('patch-waiting'));
    expect(find.text(patchedLabel('Hobby Atlas · $appVersionLabel', 2)), findsOneWidget);
    expect(waiting, findsNothing);

    // 서버에 패치 3 → "업데이트 확인"이 받아 두고 시트로 알린다 (새 APK 시트가 아니다)
    source.onServer = 3;
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    expect(source.fetches, 1);
    expect(find.byIcon(Icons.download_done), findsOneWidget);
    expect(find.byIcon(Icons.system_update_alt), findsNothing);
    expect(find.text(p.nextLabel), findsOneWidget);
    expect(find.text('· 찾기 화면 고침'), findsOneWidget);
    await tester.tap(find.byType(GradientButton));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.download_done), findsNothing);

    // 시트를 닫아도 줄은 남는다 · 번호는 다시 열기 전이라 그대로
    expect(waiting, findsOneWidget);
    expect(find.text(patchedLabel('Hobby Atlas · $appVersionLabel', 2)), findsOneWidget);
  });

  testWidgets('패치를 못 받는 빌드의 버전 줄은 전과 같다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildGpTheme(),
        home: Scaffold(
          body: VersionTile(patch: AppPatch(source: _FakeSource(isAvailable: false, current: 5))),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Hobby Atlas · $appVersionLabel'), findsOneWidget);
    expect(find.byKey(const Key('patch-waiting')), findsNothing);
    await tester.tap(find.byType(ListTile));
    await tester.pump();
    expect(find.byType(SnackBar), findsOneWidget); // 이 빌드는 앱 안 업데이트를 쓰지 않아요
    expect(find.byIcon(Icons.download_done), findsNothing);
  });
}
