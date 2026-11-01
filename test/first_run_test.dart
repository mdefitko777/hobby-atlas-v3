// 처음 데이터 받기 (V) — 가짜 인터넷(MockClient)과 임시 폴더만 쓴다. GitHub Pages 에는 닿지 않는다.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/data/blob_store.dart';
import 'package:hobby_atlas/data/catalog.dart';
import 'package:hobby_atlas/screens/w_first_run_screen.dart';
import 'package:hobby_atlas/theme.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// manifest · 건담 상품 하나만 있는 가짜 Pages (보조 파일은 404). [down] = 인터넷 끊김
MockClient fakePages({bool Function()? down}) => MockClient((req) async {
  if (down?.call() ?? false) throw const SocketException('offline');
  final p = req.url.path;
  if (p.endsWith('split/manifest.json')) return http.Response('{"updated_at":"2026-11-01","total":1}', 200);
  if (p.endsWith('split/kits-gundam.json')) {
    return http.Response(
      jsonEncode({
        'kits': [
          {
            'kit_id': 'hg-001',
            'names': {'ko': '건담'},
          },
        ],
      }),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }
  if (p.contains('split/kits-')) return http.Response('{"kits":[]}', 200);
  return http.Response('', 404);
});

void main() {
  test('캐시가 없으면 첫 다운로드: 파일 수 · 바이트를 세고, 끊기면 다시 시도', () async {
    BlobStore.debugDirectory = Directory.systemTemp.createTempSync('ha_first_run');
    final c = Catalog.instance;
    var offline = true;
    Catalog.debugClient = fakePages(down: () => offline);
    final seen = <int>[];
    void listen() => seen.add(c.filesDone);
    c.addListener(listen);

    await expectLater(c.ensureLoaded(), throwsA(isA<CatalogException>()));
    expect(c.firstDownload, isTrue, reason: '실패해도 받는 화면 (다시 시도)');
    expect(c.phase, CatalogPhase.error);

    offline = false;
    await c.retry();
    expect(c.kits.map((k) => k.id), ['hg-001']);
    expect(c.firstDownload, isFalse);
    expect(seen.reduce((a, b) => a > b ? a : b), c.filesTotal);
    expect(c.bytesReceived, greaterThan(0));
    c.removeListener(listen);
  });

  testWidgets('받는 동안은 아이콘 · 진행, 실패면 다시 시도, 다 받으면 앱 셸', (tester) async {
    final c = Catalog.instance;
    c.debugFirstRun(on: true, files: 4, bytes: 3 * 1024 * 1024, step: '건담 상품 받는 중');
    await tester.pumpWidget(
      MaterialApp(
        theme: buildGpTheme(),
        home: FirstRunGate(catalog: c, builder: (_) => const Text('셸')),
      ),
    );
    expect(find.text('데이터 받는 중'), findsOneWidget);
    expect(find.text('4 / ${c.filesTotal} · 3.0 MB'), findsOneWidget);
    expect(find.text('건담 상품 받는 중'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);

    c.debugFirstRun(on: true, error: '인터넷에 연결하지 못했어요.');
    await tester.pump();
    expect(find.text('다시 시도'), findsOneWidget);
    expect(find.text('인터넷에 연결하지 못했어요.'), findsOneWidget);

    c.debugFirstRun(on: false);
    await tester.pump();
    expect(find.text('셸'), findsOneWidget);
  });
}
