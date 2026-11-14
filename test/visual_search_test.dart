// 생김새로 찾기 (E-18) — 표 파일 읽기 (Gunpula build_vectors.py 와 같은 모양) · 가장 비슷한 상품 · 옛 id 풀기 ·
// 안내 파일 schema 1 / 2 · 새 모델 권하기 · 모델 입력 자르기 · 화면 칸 (채널 칩)
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/api.dart';
import 'package:hobby_atlas/data/user_store.dart';
import 'package:hobby_atlas/logic/photo_crop.dart';
import 'package:hobby_atlas/marks.dart';
import 'package:hobby_atlas/ml/visual_index.dart';
import 'package:hobby_atlas/ml/visual_manifest.dart';
import 'package:hobby_atlas/ml/visual_search.dart';
import 'package:hobby_atlas/models.dart';
import 'package:hobby_atlas/screens/e_visual_matches.dart';
import 'package:hobby_atlas/theme.dart';
import 'package:hobby_atlas/widgets.dart';

import 'layout_test.dart' show fakeLoaders;
import 'support/line_kits.dart';

/// 지금 올라가 있는 옛 안내 (schema 1)
Map<String, Object?> _v1({String modelSha = 'm1', String vecSha = 'v1'}) => {
  'schema': 1,
  'model': {'file': 'siglip2-b32-256-wi8.tflite', 'url': 'https://x/m32', 'bytes': 95728976, 'sha256': modelSha},
  'vectors': {
    'file': 'imgsim-vectors.bin',
    'url': 'https://x/v32',
    'bytes': 10692508,
    'sha256': vecSha,
    'model': 'siglip2-b32-256-wi8',
  },
};

Map<String, Object?> _entry(String id, {String sha = 'm', String vecSha = 'v'}) => {
  'id': id,
  'file': '$id.tflite',
  'url': 'https://x/$id',
  'bytes': 95000000,
  'sha256': sha,
  'vectors': {
    'file': id.contains('b16') ? 'imgsim-vectors-$id.bin' : 'imgsim-vectors.bin',
    'url': 'https://x/$id.bin',
    'bytes': 11000000,
    'sha256': vecSha,
    'model': id,
  },
};

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

  test('옛 id 풀기: 이름이 바뀐 상품의 옛 줄도 지금 id 로 · 같은 상품의 줄은 하나로 · only 도 지금 id', () {
    final index = VisualIndex.parse(bytes);
    // a 가 c 로 합쳐졌다: a 의 둘째 줄(0.8)이 c 의 점수가 된다
    final hits = index.nearest(l2normalize([0, 1, 0, 0]), k: null, alias: {'a': 'c'});
    expect(hits.map((h) => h.kitId), ['c', 'b']);
    expect(hits.first.score, closeTo(0.8, 0.02));
    expect(index.nearest(l2normalize([0, 1, 0, 0]), only: {'c'}, alias: {'a': 'c'}).single.kitId, 'c');
  });

  test('표 머리만 읽기: 메타 끝 · 모델 이름 (표 전체 없이)', () {
    final end = VisualIndex.metaEnd(bytes.sublist(0, 20));
    expect(VisualIndex.readMeta(bytes.sublist(0, end))['model'], 'siglip2-b32-256-wi8');
    expect(() => VisualIndex.metaEnd(Uint8List(20)), throwsFormatException);
  });

  group('안내 파일', () {
    test('옛 안내(schema 1) → 모델 하나, id = 표의 model', () {
      final m = VisualManifest.parse(_v1(), updateMessage: 'up');
      expect(m.preferred.id, 'siglip2-b32-256-wi8');
      expect(m.preferred.vectors.file, 'imgsim-vectors.bin');
      expect(m.preferred.bytes, 95728976 + 10692508);
    });

    test('새 안내(schema 2): default · 모델마다 표 이름 · 모르는 schema 는 앱 업데이트', () {
      final m = VisualManifest.parse({
        'schema': 2,
        'default': 'siglip2-b16-256-wi8',
        'models': [_entry('siglip2-b32-256-wi8'), _entry('siglip2-b16-256-wi8')],
      }, updateMessage: 'up');
      expect(m.preferred.id, 'siglip2-b16-256-wi8');
      expect(m.preferred.vectors.file, 'imgsim-vectors-siglip2-b16-256-wi8.bin');
      expect(m.byId('siglip2-b32-256-wi8')?.vectors.file, 'imgsim-vectors.bin');
      expect(() => VisualManifest.parse({'schema': 3}, updateMessage: 'up'), throwsFormatException);
      expect(() => VisualManifest.parse({'schema': 2, 'models': []}, updateMessage: 'up'), throwsFormatException);
    });

    test('파일 이름은 마지막 조각만 (폴더 밖으로 못 나간다)', () {
      expect(const VisualFile({'file': '../../x.bin'}).file, 'x.bin');
    });

    test('받아 둔 것: 새 모양 · 옛 판이 적은 모양(schema 1 통째) 둘 다', () {
      expect(installedModel({'schema': 2, 'installed': _entry('siglip2-b16-256-wi8')})?.id, 'siglip2-b16-256-wi8');
      expect(installedModel({..._v1(), 'checked': '2026-11-10T00:00:00'})?.id, 'siglip2-b32-256-wi8');
      expect(installedModel(const {}), isNull);
    });

    test('비교: 표만 새로 = 조용히 받기 · 모델 파일이 바뀜 / default 가 옮김 / 목록에서 빠짐 = 권하기', () {
      final mine = VisualModel.fromV1(_v1());
      VisualManifest v2(String def, List<Map<String, Object?>> models) =>
          VisualManifest.parse({'schema': 2, 'default': def, 'models': models}, updateMessage: 'up');
      // 그대로
      var up = visualUpgrade(mine, VisualManifest.parse(_v1(), updateMessage: 'up'));
      expect((up.vectors, up.model), (null, null));
      // 표만 새로
      up = visualUpgrade(mine, VisualManifest.parse(_v1(vecSha: 'v2'), updateMessage: 'up'));
      expect(up.vectors?.vectors.sha256, 'v2');
      expect(up.model, isNull);
      // default 가 B/16 으로: 권하고, 받아 둔 B/32 의 새 표는 그대로 받는다
      up = visualUpgrade(
        mine,
        v2('siglip2-b16-256-wi8', [
          _entry('siglip2-b32-256-wi8', sha: 'm1', vecSha: 'v3'),
          _entry('siglip2-b16-256-wi8'),
        ]),
      );
      expect(up.model?.id, 'siglip2-b16-256-wi8');
      expect(up.vectors?.vectors.sha256, 'v3');
      // 같은 모델 파일이 바뀜 → 권하기 (옛 표를 새 모델과 짝짓지 않는다)
      up = visualUpgrade(
        mine,
        VisualManifest.parse(
          _v1(modelSha: 'm2', vecSha: 'v2'),
          updateMessage: 'up',
        ),
      );
      expect(up.model?.id, 'siglip2-b32-256-wi8');
      expect(up.vectors, isNull);
      // 받아 둔 모델이 목록에서 빠짐
      up = visualUpgrade(mine, v2('siglip2-b16-256-wi8', [_entry('siglip2-b16-256-wi8')]));
      expect(up.model?.id, 'siglip2-b16-256-wi8');
    });
  });

  test('받기 실패 이유는 글만 (FormatException: · HttpException: 머리 없이)', () {
    expect(visualErrorText(const FormatException('앱을 업데이트해야 받을 수 있어요')), '앱을 업데이트해야 받을 수 있어요');
    expect(visualErrorText(const HttpException('내려받지 못했어요 (404)')), '내려받지 못했어요 (404)');
    expect(visualErrorText(StateError('모델을 아직 받지 않았어요')), '모델을 아직 받지 않았어요');
    expect(visualErrorText(UnsupportedError('못 해요')), '못 해요');
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

    tearDown(() {
      VisualSearch.instance
        ..debugSearch = null
        ..upgradeBytes = null
        ..debugSet(VisualState.unsupported);
    });

    final kits = <Kit>[
      lineKit('g1', channel: 'gundam'),
      lineKit('g2', channel: 'gundam'),
      lineKit('p1', channel: 'pokemon'),
      lineKit('b1', channel: 'beyblade'),
    ];

    /// 모델 대신: 건담이 위에 많고, 베이는 표에 옛 id(old-b1)로만 있다
    Future<void> pumpReady(WidgetTester tester, {String? channel}) async {
      Future<List<VisualHit>> fake(Uint8List photo, CropBox? crop, Map<String, String> alias) async => [
        for (final (id, s) in [('g1', 0.9), ('old-b1', 0.85), ('g2', 0.8), ('p1', 0.7)])
          (kitId: alias[id] ?? id, score: s),
      ];
      VisualSearch.instance
        ..debugSearch = fake
        ..debugSet(VisualState.ready);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildGpTheme(),
          home: MarksHost(
            store: UserStore.memory(),
            child: Scaffold(
              body: ListView(
                children: [
                  VisualMatches(
                    photo: Uint8List(0),
                    kits: kits,
                    channel: channel,
                    loaders: Loaders(kitAliases: () async => {'old-b1': 'b1'}),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Iterable<String> shown(WidgetTester tester) =>
        tester.widgetList<ProductTile>(find.byType(ProductTile)).map((t) => t.id ?? '');

    testWidgets('옛 id 로 1위인 상품도 보인다 · 칩 = 후보에 먼저 나온 채널 순서 · 전체가 기본', (tester) async {
      await pumpReady(tester);
      expect(shown(tester), ['g1', 'b1', 'g2', 'p1']);
      for (final c in ['all', 'gundam', 'beyblade', 'pokemon']) {
        expect(find.byKey(ValueKey('visual-channel-$c')), findsOneWidget, reason: c);
      }
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('visual-channel-gundam'))).dx,
        lessThan(tester.getTopLeft(find.byKey(const ValueKey('visual-channel-beyblade'))).dx),
      );
      await tester.tap(find.byKey(const ValueKey('visual-channel-gundam')));
      await tester.pump();
      expect(shown(tester), ['g1', 'g2']);
    });

    testWidgets('연 채널이 기본 칩 (후보에 그 채널이 있을 때) → 전체를 누르면 모두', (tester) async {
      await pumpReady(tester, channel: 'pokemon');
      expect(shown(tester), ['p1']);
      await tester.tap(find.byKey(const ValueKey('visual-channel-all')));
      await tester.pump();
      expect(shown(tester).length, 4);
    });

    testWidgets('연 채널의 후보가 없으면 전체로 (레고처럼 표에 없는 채널)', (tester) async {
      await pumpReady(tester, channel: 'lego');
      expect(shown(tester).length, 4);
    });

    testWidgets('새 모델이 있으면 받기 한 줄 (지금 후보는 그대로)', (tester) async {
      VisualSearch.instance.upgradeBytes = 96000000;
      await pumpReady(tester);
      expect(find.byKey(const ValueKey('visual-upgrade')), findsOneWidget);
      expect(find.textContaining('96 MB'), findsOneWidget);
      expect(shown(tester).length, 4);
    });

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
