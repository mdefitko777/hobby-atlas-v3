// D-18 받은 링크 · 알림의 옛 id (Gunpula 가 합친 상품) — 앱을 막 켠 때도 남은 상품으로 찾는다
// 옛 id 연결(kit-aliases.json)은 캐시를 다 읽은 뒤 따로 붙어서, 기다리지 않으면 「이 상품을 찾지 못했어요」가 떴다
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/api.dart';
import 'package:hobby_atlas/data/blob_store.dart';
import 'package:hobby_atlas/data/catalog.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('앱을 막 켜고 바로 옛 id 로 찾아도 남은 상품이 나온다', () async {
    BlobStore.debugDirectory = Directory.systemTemp.createTempSync('ha_alias_cold');
    Catalog.debugClient = MockClient((req) async {
      final p = req.url.path;
      if (p.endsWith('split/manifest.json')) return http.Response('{"updated_at":"2026-11-10","total":1}', 200);
      if (p.endsWith('data/kit-aliases.json')) {
        return http.Response(
          jsonEncode({
            'aliases': {'aniplex-fate-old': 'goodsmile-fate-new'},
          }),
          200,
        );
      }
      if (p.endsWith('split/kits-fate.json')) {
        return http.Response(
          jsonEncode({
            'kits': [
              {
                'kit_id': 'goodsmile-fate-new',
                'franchise': 'fate',
                'names': {'ko': '세이버'},
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
    addTearDown(() => Catalog.debugClient = null);
    final c = Catalog.instance;
    // 처음 받기 → 기기 캐시(상품 · kit-aliases.json)
    await c.ensureLoaded();
    expect(await fetchKitsByIds(['aniplex-fate-old']), hasLength(1));

    // 앱을 새로 켠 것처럼: 메모리(보조 파일 포함)를 비우고 캐시에서 다시 읽는다
    c.debugSet(slim: const [], aux: const {});
    c.debugForget();
    final kits = await fetchKitsByIds(['aniplex-fate-old', 'goodsmile-fate-new', 'no-such-kit']);
    expect(kits.map((k) => k.id), ['goodsmile-fate-new', 'goodsmile-fate-new']);
    await pumpEventQueue();
  });
}
