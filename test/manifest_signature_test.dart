// split/manifest.json 의 판 — updated_at · total 에 Gunpula 의 content_hash 까지 (같은 날 파일만 바뀐 갱신도 받는다)
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/data/blob_store.dart';
import 'package:hobby_atlas/data/catalog.dart';
import 'package:hobby_atlas/data/gunpula.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('판 표시: content_hash 가 없으면 예전 모양 그대로, 있으면 붙인다', () {
    expect(manifestSignature({'updated_at': '2026-11-10', 'total': 39334}), '2026-11-10|39334');
    expect(
      manifestSignature({'updated_at': '2026-11-10', 'total': 39334, 'content_hash': 'ab12'}),
      '2026-11-10|39334|ab12',
    );
    expect(manifestSignature({'updated_at': '2026-11-10', 'total': 39334, 'content_hash': ''}), '2026-11-10|39334');
    // 양쪽 다 없으면 같은 판 · 한쪽에만 있으면 다른 판
    expect(
      manifestSignature({'updated_at': 'd', 'total': 1}) == manifestSignature({'updated_at': 'd', 'total': 1}),
      isTrue,
    );
    expect(
      manifestSignature({'updated_at': 'd', 'total': 1}) ==
          manifestSignature({'updated_at': 'd', 'total': 1, 'content_hash': 'x'}),
      isFalse,
    );
    expect(manifestSignature(null), manifestSignature(const <String, Object?>{}));
  });

  test('updated_at · total 이 같아도 content_hash 가 바뀌면 상품을 다시 받는다', () async {
    BlobStore.debugDirectory = Directory.systemTemp.createTempSync('ha_manifest_hash');
    var hash = 'aaaa';
    var kitFetches = 0;
    Catalog.debugClient = MockClient((req) async {
      final p = req.url.path;
      if (p.endsWith('split/manifest.json')) {
        return http.Response(jsonEncode({'updated_at': '2026-11-10', 'total': 1, 'content_hash': hash}), 200);
      }
      if (p.endsWith('split/kits-gundam.json')) {
        kitFetches++;
        return http.Response(
          jsonEncode({
            'kits': [
              {
                'kit_id': 'hg-001',
                'franchise': 'gundam',
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
    addTearDown(() => Catalog.debugClient = null);
    final c = Catalog.instance;
    await c.ensureLoaded();
    expect(kitFetches, 1);

    expect(await c.refresh(), isFalse, reason: '같은 판');
    expect(kitFetches, 1);

    hash = 'bbbb'; // Gunpula 가 같은 날 split 파일만 다시 씀 (예: 조립 설명서 번호)
    expect(await c.refresh(), isTrue);
    expect(kitFetches, 2);
    expect(c.manifest['content_hash'], 'bbbb');
  });
}
