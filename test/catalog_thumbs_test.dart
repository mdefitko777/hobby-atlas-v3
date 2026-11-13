// 작은 그림 목록(data/thumbs.json) — 보조 파일로 받아 ThumbIndex.current 에 넣는다. 아직 발행 전이면(404) 원본 그대로
// (Gunpula img-contract v1, 2026-11-14)
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/data/blob_store.dart';
import 'package:hobby_atlas/data/catalog.dart';
import 'package:hobby_atlas/logic/image_size.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};
const _orig = 'https://bandai-a.akamaihd.net/bc/img/model/b/1000256190_1.jpg';
const _thumb = 'https://mdefitko777.github.io/gunpula-img-3/thumbs/web/bandai-a.akamaihd.net/3f2a9c0d41b7e8a6.webp';

/// 가짜 Pages — [thumbs] 가 null 이면 thumbs.json 은 404
MockClient _pages({String? thumbs}) => MockClient((req) async {
  final p = req.url.path.replaceFirst('/Gunpula/data/', '');
  if (p == 'split/manifest.json') {
    return http.Response(jsonEncode({'updated_at': '2026-11-14', 'total': 1}), 200, headers: _json);
  }
  if (p == 'split/kits-gundam.json') {
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
      headers: _json,
    );
  }
  if (p.startsWith('split/kits-')) return http.Response('{"kits":[]}', 200);
  // Pages 에만 있다 (raw 에는 없다)
  if (p == 'thumbs.json' && thumbs != null && req.url.host == 'mdefitko777.github.io') {
    return http.Response(thumbs, 200, headers: _json);
  }
  return http.Response('', 404);
});

Future<void> _load(String name, MockClient client) async {
  BlobStore.debugDirectory = Directory.systemTemp.createTempSync(name);
  Catalog.debugClient = client;
  addTearDown(() => Catalog.debugClient = null);
  final c = Catalog.instance..debugForget();
  await c.ensureLoaded();
  // 목록은 다른 isolate 에서 푼다 — 끝날 때까지
  for (var i = 0; i < 100 && ThumbIndex.current.isEmpty; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  setUp(() => ThumbIndex.current = ThumbIndex.none);
  tearDown(() => ThumbIndex.current = ThumbIndex.none);

  test('발행된 목록을 받아 작은 칸 주소를 바꾼다', () async {
    final file = jsonEncode({
      'schema': 'gunpula-thumbs-v1',
      'max_side': 400,
      'rules': <Object>[],
      'thumbs': {_orig: _thumb},
    });
    await _load('ha_thumbs_on', _pages(thumbs: file));
    expect(ThumbIndex.current.of(_orig), _thumb);
    expect(imageThumbUrl(_orig, 192), _thumb);
  });

  test('아직 없는 목록(404 · 옛 데이터) → 원본 그대로', () async {
    await _load('ha_thumbs_off', _pages());
    expect(ThumbIndex.current.isEmpty, isTrue);
    expect(imageThumbUrl(_orig, 192), _orig);
  });
}
