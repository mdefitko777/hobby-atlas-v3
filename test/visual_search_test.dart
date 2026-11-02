// 생김새로 찾기 (E-18) — 표 파일 읽기 (Gunpula build_vectors.py 와 같은 모양) · 가장 비슷한 상품 · 모델 입력 자르기 · 화면 칸
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/data/user_store.dart';
import 'package:hobby_atlas/marks.dart';
import 'package:hobby_atlas/ml/visual_index.dart';
import 'package:hobby_atlas/ml/visual_search.dart';
import 'package:hobby_atlas/screens/e_visual_matches.dart';
import 'package:hobby_atlas/theme.dart';

import 'layout_test.dart' show fakeLoaders;

void main() {
  // Python(numpy) 이 쓴 작은 표: a = [1,0,0,0] · [0.6,0.8,0,0], b = [0,0,1,0], c = [0,0.6,0,0.8]
  final bytes = File('test/fixtures/imgsim-vectors.sample.bin').readAsBytesSync();

  test('표 파일: 머리 · 줄 · 모델 이름', () {
    final index = VisualIndex.parse(bytes);
    expect(index.dim, 4);
    expect(index.rows, 4);
    expect(index.ids, ['a', 'a', 'b', 'c']);
    expect(index.model, 'siglip2-b32-256-wi8');
    expect(index.updated, '2026-11-03T00:00:00Z');
  });

  test('가장 비슷한 상품: 상품마다 가장 높은 줄 · 점수 순 · only 로 좁히기', () {
    final index = VisualIndex.parse(bytes);
    final hits = index.nearest(l2normalize([0, 1, 0, 0.1]), k: 5);
    expect(hits.map((h) => h.kitId), ['a', 'c', 'b']); // a 의 둘째 줄(0.8) > c(0.6) > b(0)
    expect(hits.first.score, closeTo(0.8 / 1.005, 0.02));
    expect(index.nearest(l2normalize([0, 0, 1, 0]), k: 1).single.kitId, 'b');
    expect(index.nearest(l2normalize([0, 1, 0, 0]), only: {'b', 'c'}).first.kitId, 'c');
    expect(() => index.nearest(Float32List(3)), throwsArgumentError);
  });

  test('표가 아니거나 잘렸으면 FormatException', () {
    expect(() => VisualIndex.parse(Uint8List.fromList([1, 2, 3])), throwsFormatException);
    expect(() => VisualIndex.parse(bytes.sublist(0, bytes.length - 3)), throwsFormatException);
  });

  test('모델 입력: 짧은 변 256 맞춤 · 가운데 자르기 · 투명 = 흰색', () {
    expect(resizeForCrop(4000, 3000), (341, 256));
    expect(resizeForCrop(100, 200), (256, 512));
    // 260×256 그림: 왼쪽 2칸 · 오른쪽 2칸이 잘린다. 첫 칸(2,0)은 빨강, 나머지는 완전 투명(곱해진 알파 = 0,0,0,0)
    const w = 260, h = 256;
    final rgba = Uint8List(w * h * 4);
    rgba.setAll((0 * w + 2) * 4, [255, 0, 0, 255]);
    final x = cropToInput(rgba, w, h);
    expect(x.length, 256 * 256 * 3);
    expect(x.sublist(0, 3), [1.0, 0.0, 0.0]);
    expect(x.sublist(3, 6), [1.0, 1.0, 1.0]);
  });

  group('화면 칸', () {
    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildGpTheme(),
          home: MarksHost(
            store: UserStore.memory(),
            child: Scaffold(
              body: ListView(
                children: [VisualMatches(photo: Uint8List(0), kits: const [], loaders: fakeLoaders)],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    tearDown(() => VisualSearch.instance.debugSet(VisualState.unsupported));

    testWidgets('이 기기에서 못 하면 아무것도 없다', (tester) async {
      await pump(tester);
      expect(find.text('생김새가 비슷한 상품'), findsNothing);
    });

    testWidgets('아직 안 받음 → 받기 · 받는 중 → 진행 막대', (tester) async {
      VisualSearch.instance.debugSet(VisualState.absent);
      await pump(tester);
      expect(find.text('생김새가 비슷한 상품'), findsOneWidget);
      expect(find.byKey(const ValueKey('visual-install')), findsOneWidget);
      VisualSearch.instance
        ..progress = 0.42
        ..debugSet(VisualState.downloading);
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('모델 받는 중… 42%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
