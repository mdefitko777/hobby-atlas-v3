// 고르지 않은 채널은 어떤 길로도 받지 않는다 — 가짜 Pages 가 고르지 않은 채널의 주소(상품 파일 · 검색 파일 · 그 채널 보조 파일)를
// 받으러 오면 적어 두고 시험을 떨어뜨린다. 옛 앱 캐시(7채널을 다 받아 둔 기기)에서 올라와도 내 채널은 그대로 · 닌텐도는 꺼져 있고,
// 더한 채널은 한 번만 받고, 받는 사이에 다시 뺀 채널은 남지 않는다.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/api.dart';
import 'package:hobby_atlas/channels.dart';
import 'package:hobby_atlas/data/blob_store.dart';
import 'package:hobby_atlas/data/catalog.dart';
import 'package:hobby_atlas/data/gunpula.dart';
import 'package:hobby_atlas/data/user_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

/// 받은 경로 (data/ 아래) → 그 경로가 딸린 채널 (모든 채널이 같이 쓰는 파일이면 null)
String? _channelOf(String p) {
  final m = RegExp(r'^(?:split/kits|search/search)-(\w+)\.json$').firstMatch(p);
  return m?.group(1) ?? auxChannel[p];
}

class _StrictPages {
  _StrictPages(this.allowed);

  /// 받아도 되는 채널 (시험 중에 바꾼다 — 채널을 더하는 것)
  Set<String> allowed;
  String updated = '2026-11-14';
  final gets = <String>[];
  final violations = <String>[];

  /// [holdPath] 를 돌려주기 전에 기다린다 (받는 사이에 채널을 빼는 시험)
  Future<void>? hold;
  String holdPath = '';

  int got(String p) => gets.where((g) => g == p).length;

  MockClient client() => MockClient((req) async {
    final p = req.url.path.replaceFirst(RegExp(r'^.*?/data/'), '');
    gets.add(p);
    final ch = _channelOf(p);
    if (ch != null && !allowed.contains(ch)) violations.add(p);
    if (p == holdPath && hold != null) await hold;
    if (p == 'split/manifest.json') {
      return http.Response(
        jsonEncode({
          'updated_at': updated,
          'total': 8,
          'franchises': {for (final f in franchiseIds) f: 1},
          // 모든 보조 파일에 지문 — 판이 같은 날 보조 파일만 바뀐 길(_refreshAux)도 거친다
          'files': {for (final f in auxFiles) f: updated == '2026-11-14' ? 'aaaaaaaaaaaaaaaa' : 'bbbbbbbbbbbbbbbb'},
        }),
        200,
        headers: _json,
      );
    }
    if (p.startsWith('split/kits-')) {
      final f = _channelOf(p)!;
      return http.Response(
        jsonEncode({
          'kits': [
            {
              'kit_id': '$f-1',
              'franchise': f,
              'names': {'ko': '$f-1'},
            },
          ],
        }),
        200,
        headers: _json,
      );
    }
    if (p.endsWith('.json')) return http.Response('{}', 200, headers: _json);
    return http.Response('', 404);
  });
}

/// 옛 앱(1.1.13)이 남긴 캐시: 앱이 알던 7채널을 다 받아 두었다 (닌텐도는 없다)
Future<void> _oldCache() async {
  const old = ['gundam', 'beyblade', 'pokemon', 'armored_core', 'fate', 'madoka', 'lego'];
  await BlobStore.write(
    'catalog_meta.json',
    jsonEncode({
      'manifest': {
        'updated_at': '2026-11-14',
        'total': 8,
        'franchises': {for (final f in franchiseIds) f: 1},
        'files': {for (final f in auxFiles) f: 'aaaaaaaaaaaaaaaa'},
      },
      'map_version': Catalog.mapVersion,
      'franchises': old,
      'fetched_at': '2026-11-14T00:00:00',
    }),
  );
  await BlobStore.write(
    'catalog_kits.json',
    jsonEncode([
      for (final f in old) {'id': '$f-1', 'franchiseId': f, 'nameKo': '$f-1'},
    ]),
  );
  for (final f in auxFiles) {
    await BlobStore.write(Catalog.auxKey(f), '{}');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _StrictPages pages;

  setUp(() async {
    BlobStore.debugDirectory = Directory.systemTemp.createTempSync('ha_strict');
    Catalog.instance.debugForget();
    UserStore.instance.setMyChannels(defaultMyChannels);
    await _oldCache();
    pages = _StrictPages(defaultMyChannels.toSet());
    Catalog.debugClient = pages.client();
  });
  tearDown(() {
    Catalog.debugClient = null;
    Catalog.instance.debugForget();
    UserStore.instance.setMyChannels(defaultMyChannels);
  });

  test('옛 캐시에서 올라와도: 내 채널 그대로 · 닌텐도 꺼짐 · 고르지 않은 채널은 어떤 길로도 받지 않는다', () async {
    final c = Catalog.instance;
    await c.ensureLoaded();
    await pumpEventQueue();
    expect(UserStore.instance.myChannels, defaultMyChannels);

    // 같은 판 → 고르지 않은 채널은 기기에서 지운다 (받지 않고)
    await c.refresh();
    expect(c.kits.map((k) => k.franchiseId).toSet(), defaultMyChannels.toSet());
    for (final e in auxChannel.entries) {
      final mine = defaultMyChannels.contains(e.value);
      expect(await BlobStore.read(Catalog.auxKey(e.key)) != null, mine, reason: e.key);
    }

    // 보조 파일만 바뀐 날 · 새 판 · 지금 새로 받기 · 못 찾은 상품 · 화면이 부르는 보조 파일 · 채널마다 목록
    pages.updated = '2026-11-15';
    await c.refresh();
    await c.refresh(force: true);
    await c.checkForNewData(maxAge: Duration.zero);
    expect(await fetchKitsByIds(['lego-1']), isEmpty, reason: '고르지 않은 채널 상품은 받지 않는다');
    await fetchCollection();
    for (final f in auxFiles) {
      await c.aux(f);
    }
    for (final f in franchiseIds) {
      await fetchKits([f]);
    }
    await fetchKits([...franchiseIds]);

    expect(pages.violations, isEmpty);
    expect(c.kits.map((k) => k.franchiseId).toSet(), defaultMyChannels.toSet());
  });

  test('채널을 더하면 한 번만 받고, 받는 사이에 다시 빼면 남지 않는다', () async {
    final c = Catalog.instance;
    await c.ensureLoaded();
    await c.refresh();
    await pumpEventQueue();

    pages.allowed = {...defaultMyChannels, 'nintendo'};
    UserStore.instance.setMyChannels([...defaultMyChannels, 'nintendo']);
    await Future.wait([
      fetchKits(['nintendo']),
      fetchKits([...defaultMyChannels, 'nintendo']),
      c.syncChannels(),
    ]);
    await pumpEventQueue();
    expect(pages.got('split/kits-nintendo.json'), 1, reason: '여러 탭이 같이 기다려도 한 번');
    expect(c.kits.map((k) => k.id), contains('nintendo-1'));

    // 레고를 더하는 중에 다시 뺀다
    final gate = Completer<void>();
    pages
      ..allowed = {...defaultMyChannels, 'nintendo', 'lego'}
      ..holdPath = 'split/kits-lego.json'
      ..hold = gate.future;
    UserStore.instance.setMyChannels([...defaultMyChannels, 'nintendo', 'lego']);
    for (var i = 0; i < 100 && pages.got('split/kits-lego.json') == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(pages.got('split/kits-lego.json'), 1, reason: '레고를 받기 시작했다');
    UserStore.instance.setMyChannels([...defaultMyChannels, 'nintendo']);
    gate.complete();
    // 아무도 다시 부르지 않아도 (다음 확인은 몇 시간 뒤) 받기가 끝나면 그 사이 바뀐 내 채널에 맞춘다
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(c.kits.map((k) => k.franchiseId), isNot(contains('lego')), reason: '뺀 채널이 목록에 남지 않는다');
    c.debugForget();
    await c.ensureLoaded();
    expect(c.kits.map((k) => k.franchiseId), isNot(contains('lego')), reason: '기기 캐시에도');
    expect(pages.violations, isEmpty);
  });
}
