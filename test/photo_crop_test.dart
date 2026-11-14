// 생김새로 찾기 전 찾을 부분 고르기 (E-19) · 채널 칩 (E-18) — 틀 끌기 · 모델 입력 계산 · 칩 순서 · 칩으로 좁히기
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/api.dart';
import 'package:hobby_atlas/data/user_store.dart';
import 'package:hobby_atlas/logic/photo_crop.dart';
import 'package:hobby_atlas/logic/visual_pick.dart';
import 'package:hobby_atlas/marks.dart';
import 'package:hobby_atlas/ml/visual_engine_io.dart' show prepareVisualInput;
import 'package:hobby_atlas/ml/visual_search.dart';
import 'package:hobby_atlas/ocr/text_reader.dart';
import 'package:hobby_atlas/screens/e_photo_crop_screen.dart';
import 'package:hobby_atlas/screens/e_photo_find_screen.dart';
import 'package:hobby_atlas/theme.dart';

import 'support/line_kits.dart';

/// [w]×[h] 한 가지 색 PNG (Image.memory 가 풀 수 있는 진짜 그림)
Future<Uint8List> _solidPng(WidgetTester tester, int w, int h) async => (await tester.runAsync(() async {
  final rec = ui.PictureRecorder();
  ui.Canvas(rec).drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), Paint()..color = const Color(0xFF00FF00));
  final img = await rec.endRecording().toImage(w, h);
  return (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
}))!;

void main() {
  const box = (left: 0.2, top: 0.2, right: 0.6, bottom: 0.8);

  test('누른 곳 → 모서리 · 옮기기 · 밖', () {
    expect(cropGripAt(box, 0.21, 0.19, reachX: 0.05, reachY: 0.05), CropGrip.topLeft);
    expect(cropGripAt(box, 0.6, 0.8, reachX: 0.05, reachY: 0.05), CropGrip.bottomRight);
    expect(cropGripAt(box, 0.4, 0.5, reachX: 0.05, reachY: 0.05), CropGrip.move);
    expect(cropGripAt(box, 0.9, 0.5, reachX: 0.05, reachY: 0.05), isNull);
  });

  test('끌기: 사진 밖으로 안 나가고 · 최소 크기 · 옮기면 크기 그대로', () {
    final moved = dragCrop(box, CropGrip.move, 0.6, -0.5);
    expect([moved.left, moved.top, moved.right, moved.bottom], [closeTo(0.6, 1e-9), 0.0, 1.0, closeTo(0.6, 1e-9)]);
    final shrunk = dragCrop(box, CropGrip.topLeft, 0.5, 0.0, minW: 0.1);
    expect(shrunk.left, closeTo(0.5, 1e-9));
    expect(shrunk.right, 0.6);
    final grown = dragCrop(box, CropGrip.bottomRight, 0.9, 0.9);
    expect((grown.right, grown.bottom), (1.0, 1.0));
    expect(isFullCrop(fullCrop), isTrue);
    expect(isFullCrop(box), isFalse);
  });

  test('모델 입력 계산: 틀의 가운데 정사각형 · 짧은 변 256 으로 줄여 풀기 · 늘리지 않음', () {
    // 4000×3000 사진의 가운데 절반 (2000×1500 → 짧은 변 1500 → 256/1500 로 줄여 풀기)
    final p = cropPlan(4000, 3000, (left: 0.25, top: 0.25, right: 0.75, bottom: 0.75));
    expect((p.decodeW, p.decodeH), (683, 512));
    expect(p.srcSide, closeTo(256, 1));
    expect(p.srcLeft + p.srcSide / 2, closeTo(683 / 2, 1)); // 가로 가운데
    // 작은 틀: 원래 크기로 풀고 (늘리지 않음) 정사각형만 크게 그린다
    final small = cropPlan(800, 600, (left: 0.0, top: 0.0, right: 0.2, bottom: 0.5));
    expect((small.decodeW, small.decodeH), (800, 600));
    expect(small.srcSide, closeTo(160, 1e-6));
    expect(small.srcTop, closeTo(150 - 80, 1e-6));
  });

  testWidgets('자른 사진 → 모델 입력: 틀 안 색만 (왼쪽 빨강 · 오른쪽 파랑 사진의 오른쪽 틀 = 파랑)', (tester) async {
    final png = await tester.runAsync(() async {
      final rec = ui.PictureRecorder();
      ui.Canvas(rec)
        ..drawRect(const Rect.fromLTWH(0, 0, 300, 300), Paint()..color = const Color(0xFFFF0000))
        ..drawRect(const Rect.fromLTWH(300, 0, 300, 300), Paint()..color = const Color(0xFF0000FF));
      final img = await rec.endRecording().toImage(600, 300);
      return (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
    });
    final whole = (await tester.runAsync(() => prepareVisualInput(png!, null)))!;
    final right = (await tester.runAsync(
      () => prepareVisualInput(png!, (left: 0.55, top: 0.0, right: 1.0, bottom: 1.0)),
    ))!;
    expect(whole.length, 256 * 256 * 3);
    expect(right.length, 256 * 256 * 3);
    // 전체: 가운데 정사각형 = 왼쪽 반 빨강 · 오른쪽 반 파랑
    expect(whole.sublist(0, 3), [1.0, 0.0, 0.0]);
    // 오른쪽 틀: 모든 칸이 파랑 (가장자리 섞임 없이)
    for (final i in [0, 128 * 256 + 128, 256 * 256 - 1]) {
      expect(right.sublist(i * 3, i * 3 + 3), [0.0, 0.0, 1.0], reason: 'px $i');
    }
  });

  test('채널 칩 순서: 앞쪽 후보에 먼저 나온 채널부터, 뒤의 채널은 그다음 · 빈 값은 빼기', () {
    final ranked = ['fate', 'madoka', 'fate', '', 'gundam', 'pokemon'];
    expect(visualChannels(ranked, head: 3), ['fate', 'madoka', 'gundam', 'pokemon']);
    expect(visualChannels(const []), isEmpty);
  });

  test('칩으로 좁히기: 그 채널만 비슷한 순서대로 12개 · 전체는 그대로', () {
    final ranked = [for (var i = 0; i < 30; i++) (id: 'k$i', ch: i.isEven ? 'pokemon' : 'gundam')];
    final poke = visualTop(ranked, 'pokemon', (x) => x.ch);
    expect(poke.length, 12);
    expect(poke.first.id, 'k0');
    expect(poke[1].id, 'k2');
    expect(visualTop(ranked, null, (x) => x.ch, k: 3).map((x) => x.id), ['k0', 'k1', 'k2']);
  });

  testWidgets('찾을 부분 고르기 (360dp 폰, 세로 사진): 전체 → 확인이면 그 틀, 모서리를 끌면 틀이 줄어든다', (tester) async {
    final png = await _solidPng(tester, 300, 600);
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    CropBox? got;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildGpTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async => got = await pickPhotoCrop(context, png, fullCrop),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(PhotoCropScreen), findsOneWidget);
    // 사진 크기를 푼 뒤에야 틀을 끌 수 있다
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
    final area = find.byKey(const ValueKey('crop-area'));
    expect(area, findsOneWidget);
    final r = tester.getRect(area);
    // 사진이 화면 높이를 거의 다 쓰고 (머리 줄 · 안내 한 줄 빼고) 손가락으로 모서리를 잡을 만큼 크다
    expect(r.height, greaterThan(400));
    expect(r.width, greaterThan(200));
    await tester.dragFrom(r.topLeft + const Offset(2, 2), Offset(r.width / 2, r.height / 4));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('crop-done')));
    await tester.pumpAndSettle();
    expect(got, isNotNull);
    expect(got!.left, greaterThan(0.3));
    expect(got!.top, greaterThan(0.1));
    expect((got!.right, got!.bottom), (1.0, 1.0));
  });

  testWidgets('사진으로 찾기: ✂ → 틀 고르기 → 생김새만 그 틀로 다시 비교 (모델이 있을 때만 ✂)', (tester) async {
    final png = await _solidPng(tester, 400, 300);
    final crops = <CropBox?>[];
    Future<List<VisualHit>> fake(Uint8List photo, CropBox? crop, Map<String, String> alias) async {
      crops.add(crop);
      return [(kitId: 'p1', score: 0.9)];
    }

    textReader = (_) async => '';
    VisualSearch.instance
      ..debugSearch = fake
      ..debugSet(VisualState.ready);
    addTearDown(() {
      textReader = (_) async => '';
      VisualSearch.instance
        ..debugSearch = null
        ..debugSet(VisualState.unsupported);
    });
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildGpTheme(),
        builder: (context, child) => MarksHost(store: UserStore.memory(), child: child!),
        home: PhotoFindScreen(
          photo: png,
          channel: 'pokemon',
          loaders: Loaders(
            kits: (_) async => [lineKit('p1', channel: 'pokemon')],
            kitAliases: () async => const {},
          ),
          onGoSearch: () {},
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(crops, [fullCrop]);
    await tester.tap(find.byKey(const ValueKey('visual-crop')));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
    final r = tester.getRect(find.byKey(const ValueKey('crop-area')));
    await tester.dragFrom(r.bottomRight - const Offset(2, 2), Offset(-r.width / 2, -r.height / 2));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('crop-done')));
    await tester.pumpAndSettle();
    expect(crops.length, 2);
    expect(isFullCrop(crops.last!), isFalse);
    expect(crops.last!.right, lessThan(0.6));
  });
}
