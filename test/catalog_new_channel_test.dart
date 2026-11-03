// 새 채널이 생긴 앱 — 옛 앱이 같은 manifest 를 받아 두었어도 새 채널을 받는다 (마도카, 2026-11-04)
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/data/blob_store.dart';
import 'package:hobby_atlas/data/catalog.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('캐시의 채널 목록이 지금과 다르면 같은 manifest 여도 새로 받는다', () async {
    final dir = BlobStore.debugDirectory = Directory.systemTemp.createTempSync('ha_new_channel');
    var kitFetches = 0;
    Catalog.debugClient = MockClient((req) async {
      final p = req.url.path;
      if (p.endsWith('split/manifest.json')) return http.Response('{"updated_at":"2026-11-03","total":1}', 200);
      if (p.endsWith('split/kits-gundam.json')) {
        kitFetches++;
        return http.Response(
          jsonEncode({
            'kits': [
              {'kit_id': 'hg-001', 'franchise': 'gundam', 'names': {'ko': '건담'}},
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (p.contains('split/kits-')) return http.Response('{"kits":[]}', 200);
      return http.Response('', 404);
    });
    final c = Catalog.instance;
    await c.ensureLoaded();
    expect(kitFetches, 1);

    // 같은 앱으로 다시 켜면 캐시를 쓰고, manifest 가 같아 다시 받지 않는다
    c.debugForget();
    await c.ensureLoaded();
    await pumpEventQueue();
    expect(kitFetches, 1);
    expect(c.kits.map((k) => k.id), ['hg-001']);

    // 옛 앱이 적은 캐시 (채널 목록 없음) → 새로 받는다
    final meta = File('${dir.path}/catalog_meta.json');
    final m = jsonDecode(meta.readAsStringSync()) as Map<String, Object?>..remove('franchises');
    meta.writeAsStringSync(jsonEncode(m));
    c.debugForget();
    await c.ensureLoaded();
    expect(kitFetches, 2);
    expect(c.kits.map((k) => k.id), ['hg-001']);
  });
}
