// 보조 파일만 바뀐 갱신 — manifest 판(updated_at|total|content_hash)은 같아도 `files` 지문이 달라진 파일만 받는다.
// 2026-11-12: 공식 예고 2개가 Pages 에 올라왔는데 당겨서 새로 고침에도 안 왔다 (content_hash 가 예고를 덮지 않음).
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/data/blob_store.dart';
import 'package:hobby_atlas/data/catalog.dart';
import 'package:hobby_atlas/data/derive.dart' show deriveAnnouncements;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

Map<String, Object?> _ann(String id) => {
  'id': id,
  'franchise': 'gundam',
  'names': {'ko': id},
  'status': 'announced',
};

/// 가짜 Pages — 바꿔 가며 쓰는 manifest · 예고 · 받은 횟수
class _Pages {
  String updated = '2026-11-11';
  Map<String, String>? files = {'announcements.json': 'a1', 'grades.json': 'g1', 'kit-aliases.json': 'k1'};
  List<Map<String, Object?>> announcements = [_ann('ann-old')];
  bool failAnnouncements = false;

  /// 발행 직후 CDN 이 옛 예고를 주는 경우 — manifest 지문은 새 판, 받는 내용은 [staleBody]
  String? staleBody;
  final gets = <String, int>{};

  /// 이 가짜 Pages 가 [p] 에 내주는 내용 (없으면 null = 404)
  String? body(String p) {
    if (p == 'announcements.json' && !failAnnouncements) return jsonEncode({'announcements': announcements});
    // 표시값(g1 → g2 …)이 내용에 들어가 지문도 따라 바뀐다
    const marked = {'grades.json', 'kit-aliases.json', 'atlas/gundam-ms.json'};
    if (marked.contains(p)) return jsonEncode({'v': files?[p] ?? ''});
    return null;
  }

  /// manifest `files` = 올라와 있는 파일들의 진짜 지문 (Gunpula publish_site.mjs 와 같은 sha256 앞 16자리).
  /// [files] 는 어느 파일이 지문을 갖나와 그 판 표시(a1 · g2 …)를 정한다
  Map<String, String>? manifestFiles() => files == null
      ? null
      : {
          for (final k in files!.keys)
            k: sha256
                .convert(
                  utf8.encode(
                    k == 'announcements.json' ? jsonEncode({'announcements': announcements}) : (body(k) ?? ''),
                  ),
                )
                .toString()
                .substring(0, 16),
        };

  int got(String path) => gets[path] ?? 0;

  MockClient client() => MockClient((req) async {
    final p = req.url.path.replaceFirst('/Gunpula/data/', '');
    gets[p] = got(p) + 1;
    if (p == 'split/manifest.json') {
      return http.Response(
        jsonEncode({'updated_at': updated, 'total': 1, 'files': ?manifestFiles()}),
        200,
        headers: _json,
      );
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
    if (p == 'announcements.json' && staleBody != null) return http.Response(staleBody!, 200, headers: _json);
    final b = body(p);
    return b == null ? http.Response('', 404) : http.Response(b, 200, headers: _json);
  });
}

Future<_Pages> _start(String name, {bool withFiles = true}) async {
  BlobStore.debugDirectory = Directory.systemTemp.createTempSync(name);
  addTearDown(() => Catalog.debugClient = null);
  final pages = _Pages();
  if (!withFiles) pages.files = null;
  Catalog.debugClient = pages.client();
  final c = Catalog.instance..debugForget();
  await c.ensureLoaded();
  expect(pages.got('split/kits-gundam.json'), 1);
  return pages;
}

Future<List<String>> _shown() async => [
  for (final a in await deriveAnnouncements(['gundam'])) a.id,
];

void main() {
  test('예고만 바뀜 → 예고 파일만 받고 상품은 받지 않는다 · 앱을 다시 켜도 또 받지 않는다', () async {
    final pages = await _start('ha_aux_only');
    final c = Catalog.instance;
    expect(await _shown(), ['ann-old']);
    final v0 = c.version;

    pages
      ..announcements = [_ann('ann-old'), _ann('ann-new')]
      ..files = {...pages.files!, 'announcements.json': 'a2'};
    expect(await c.refresh(), isTrue);
    expect(pages.got('split/kits-gundam.json'), 1, reason: '상품은 그대로');
    expect(pages.got('announcements.json'), 2);
    expect(pages.got('grades.json'), 1, reason: '지문이 같은 파일은 받지 않는다');
    expect(c.version, v0 + 1);
    expect(c.lastChangeQuiet, isFalse);
    expect(await _shown(), containsAll(['ann-old', 'ann-new']));

    // 같은 manifest → 아무것도 받지 않는다. 앱을 다시 켜도 기기에 적어 둔 지문으로 같은 판
    expect(await c.refresh(), isFalse);
    c.debugForget();
    await c.ensureLoaded();
    await pumpEventQueue();
    expect(pages.got('announcements.json'), 2);
    expect(c.version, v0 + 1);
  });

  test('못 받은 보조 파일은 지문을 적지 않아 다음 확인에서 다시 받는다', () async {
    final pages = await _start('ha_aux_retry');
    final c = Catalog.instance;
    pages
      ..announcements = [_ann('ann-new')]
      ..files = {...pages.files!, 'announcements.json': 'a2'}
      ..failAnnouncements = true;
    expect(await c.refresh(), isFalse);
    expect(await _shown(), ['ann-old']);

    pages.failAnnouncements = false;
    expect(await c.refresh(), isTrue);
    expect(await _shown(), ['ann-new']);
    expect(pages.got('split/kits-gundam.json'), 1);
  });

  test('판이 바뀌면 예전처럼 전부 · 상품에 녹이는 파일만 바뀐 때는 상품을 다시 받지 않는다', () async {
    final pages = await _start('ha_aux_full');
    final c = Catalog.instance;
    pages.updated = '2026-11-12';
    expect(await c.refresh(), isTrue);
    expect(pages.got('split/kits-gundam.json'), 2);
    expect(pages.got('grades.json'), 2);
    expect(Catalog.auxHashes(c.manifest), pages.manifestFiles(), reason: '전부 받은 때도 지문을 적는다');

    // 상품에만 녹이는 grades → 아무것도 받지 않는다 (상품은 다음 판에서 같이 녹는다)
    final v = c.version;
    pages.files = {...pages.files!, 'grades.json': 'g2'};
    expect(await c.refresh(), isFalse);
    expect(pages.got('split/kits-gundam.json'), 2);
    expect(pages.got('grades.json'), 2);
    expect(c.version, v);

    // 도감 화면도 쓰는 MS 파일 → 그 파일만
    pages.files = {...pages.files!, 'atlas/gundam-ms.json': 'm2'};
    expect(await c.refresh(), isTrue);
    expect(pages.got('atlas/gundam-ms.json'), 3);
    expect(pages.got('split/kits-gundam.json'), 2);
    expect(await c.refresh(), isFalse);
  });

  test('files 가 없는 manifest (raw · 그전 Gunpula) → 예전처럼 판이 같으면 아무것도 받지 않는다', () async {
    final pages = await _start('ha_aux_no_files', withFiles: false);
    final c = Catalog.instance;
    final before = Map.of(pages.gets);
    expect(await c.refresh(), isFalse);
    expect(pages.got('split/kits-gundam.json'), 1);
    expect(pages.got('announcements.json'), before['announcements.json']);

    // 지문이 없던 캐시에 처음 지문이 오면 보조 파일만 한 번 (상품에만 녹이는 grades 는 적기만)
    pages.files = {'announcements.json': 'a1', 'grades.json': 'g1'};
    expect(await c.refresh(), isTrue);
    expect(pages.got('announcements.json'), before['announcements.json']! + 1);
    expect(pages.got('grades.json'), before['grades.json']);
    expect(pages.got('split/kits-gundam.json'), 1);
    final recorded = pages.manifestFiles();
    expect(Catalog.auxHashes(c.manifest), recorded);

    // Pages 가 안 돼 raw manifest(files 없음)를 받아도 적어 둔 지문은 그대로 — 다음 Pages 판과 비교한다
    pages.files = null;
    expect(await c.refresh(), isFalse);
    expect(Catalog.auxHashes(c.manifest), recorded);
  });

  test('발행 직후 CDN 이 옛 예고를 주면 지문을 적지 않고 다음 확인에서 다시 받는다', () async {
    final pages = await _start('ha_aux_stale');
    final c = Catalog.instance;
    final old = jsonEncode({'announcements': pages.announcements});
    pages
      ..announcements = [_ann('ann-old'), _ann('ann-new')]
      ..staleBody = old;
    expect(await c.refresh(), isTrue, reason: '받은 것은 쓴다');
    expect(await _shown(), ['ann-old'], reason: '아직 옛 내용');
    pages.staleBody = null;
    expect(await c.refresh(), isTrue, reason: '지문이 맞지 않아 다시 받는다');
    expect(await _shown(), containsAll(['ann-old', 'ann-new']));
    final n = pages.got('announcements.json');
    expect(await c.refresh(), isFalse);
    expect(pages.got('announcements.json'), n, reason: '맞는 내용을 받은 뒤에는 다시 받지 않는다');
  });
}
