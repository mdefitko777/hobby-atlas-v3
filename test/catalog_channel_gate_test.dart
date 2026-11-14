// 고른 채널만 받는다 (2026-11-14): 고르지 않은 채널은 상품 파일도 그 채널 보조 파일(건담 도감 · 베이 부품 · 태그 도감)도
// 받지 않고, 채널을 더하면 그 채널 것만 처음 받고, 빼면 인터넷 없이 지운다. 새 채널(닌텐도)은 처음엔 꺼져 있다.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/api.dart';
import 'package:hobby_atlas/channels.dart';
import 'package:hobby_atlas/data/blob_store.dart';
import 'package:hobby_atlas/data/catalog.dart';
import 'package:hobby_atlas/data/gundam_atlas.dart' show atlasBoxartFile, atlasKitMsFile, atlasMsFile;
import 'package:hobby_atlas/data/gunpula.dart';
import 'package:hobby_atlas/data/user_store.dart';
import 'package:hobby_atlas/widgets.dart' show LoadingView;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

final _emptyHash = sha256.convert(utf8.encode('{}')).toString().substring(0, 16);

Map<String, Object?> _kit(String id, String franchise, [Map<String, Object?> more = const {}]) => {
  'kit_id': id,
  'franchise': franchise,
  'names': {'ko': id},
  ...more,
};

/// 가짜 Pages — 받은 경로를 센다
class _Pages {
  _Pages({this.franchises = const ['gundam', 'beyblade', 'pokemon', 'lego', 'nintendo']});

  List<String> franchises;
  String updated = '2026-11-14';
  Map<String, String> franchiseHashes = {};
  final missing = <String>{};
  final gets = <String>[];

  int got(String path) => gets.where((p) => p == path).length;

  /// 채널 하나에 딸린 것(상품 파일 · 그 채널 보조 파일)을 받았나
  bool touched(String channel) => gets.any((p) => p == 'split/kits-$channel.json' || auxChannel[p] == channel);

  MockClient client() => MockClient((req) async {
    final p = req.url.path.replaceFirst(RegExp(r'^.*?/data/'), ''); // Pages · raw 둘 다
    gets.add(p);
    if (missing.contains(p)) return http.Response('', 404);
    if (p == 'split/manifest.json') {
      return http.Response(
        jsonEncode({
          'updated_at': updated,
          'total': 3,
          'franchises': {for (final f in franchises) f: 1},
          if (franchiseHashes.isNotEmpty) 'franchise_hashes': franchiseHashes,
          // 상품 매핑에 녹이는 보조 파일 지문 (내용은 모두 '{}')
          'files': {
            for (final f in ['grades.json', atlasBoxartFile, atlasKitMsFile, atlasMsFile]) f: _emptyHash,
          },
        }),
        200,
        headers: _json,
      );
    }
    final kits = switch (p) {
      'split/kits-gundam.json' => [_kit('hg-001', 'gundam')],
      'split/kits-beyblade.json' => [_kit('beyblade-x-bx01', 'beyblade')],
      'split/kits-nintendo.json' => [
        _kit('nintendo-kr-14917', 'nintendo', {
          'grade_code': 'NIN_GAME',
          'subline': 'Nintendo Switch 2',
          'price_krw': 74800,
          'source_refs': [
            {'source_id': 'nintendo_store_kr'},
          ],
        }),
      ],
      _ when p.startsWith('split/kits-') => const <Object>[],
      _ => null,
    };
    if (kits != null) return http.Response(jsonEncode({'kits': kits}), 200, headers: _json);
    if (p == 'bbx-database.json') return http.Response('{"parts":{"blade":[]}}', 200, headers: _json);
    if (p.endsWith('.json')) return http.Response('{}', 200, headers: _json);
    return http.Response('', 404);
  });
}

Future<_Pages> _start(String name, List<String> channels, {_Pages? pages}) async {
  BlobStore.debugDirectory = Directory.systemTemp.createTempSync(name);
  addTearDown(() => Catalog.debugClient = null);
  UserStore.instance.setMyChannels(channels);
  final p = pages ?? _Pages();
  Catalog.debugClient = p.client();
  final c = Catalog.instance..debugForget();
  await c.ensureLoaded();
  await pumpEventQueue();
  return p;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    Catalog.instance.debugForget(); // manifest 를 비워 두어야 채널을 되돌려도 받으러 가지 않는다
    UserStore.instance.setMyChannels(defaultMyChannels);
  });

  test('닌텐도는 처음 내 채널에 없다 (고르기 전엔 받지 않는다)', () {
    expect(defaultMyChannels, isNot(contains('nintendo')));
    expect(allChannels.map((c) => c.id), contains('nintendo'));
    expect(franchiseIds, contains('nintendo'));
  });

  test('처음 받기: 고른 채널의 상품 · 보조 파일만', () async {
    final pages = await _start('ha_gate_first', ['gundam']);
    final c = Catalog.instance;
    expect(pages.got('split/kits-gundam.json'), 1);
    for (final f in ['beyblade', 'pokemon', 'lego', 'nintendo']) {
      expect(pages.touched(f), isFalse, reason: '$f 는 고르지 않았다');
    }
    expect(pages.got('announcements.json'), 1, reason: '모든 채널이 같이 쓰는 작은 파일은 받는다');
    expect(c.kits.map((k) => k.id), ['hg-001']);
    expect(c.wantedChannels, ['gundam']);

    // 고르지 않은 채널의 보조 파일은 화면이 불러도 받지 않는다
    expect(await c.aux('bbx-database.json'), isNull);
    expect(pages.touched('beyblade'), isFalse);
  });

  test('채널을 더하면 그 채널만 처음 받고, 빼면 인터넷 없이 지운다', () async {
    final pages = await _start('ha_gate_add', ['gundam']);
    final c = Catalog.instance;
    final before = pages.gets.length;

    UserStore.instance.setMyChannels(['gundam', 'nintendo']);
    final kits = await fetchKits(['nintendo']); // 화면은 받을 때까지 기다린다
    expect(kits.map((k) => k.id), ['nintendo-kr-14917']);
    expect(pages.gets.skip(before), ['split/kits-nintendo.json'], reason: '등급 · first-seen 은 기기에 둔 것');
    expect(c.kits.map((k) => k.id).toSet(), {'hg-001', 'nintendo-kr-14917'});

    // 베이를 더하면 베이 부품도 같이
    UserStore.instance.setMyChannels(['gundam', 'nintendo', 'beyblade']);
    await c.syncChannels();
    expect(pages.got('bbx-database.json'), 1);
    expect(await c.aux('bbx-database.json'), isNotNull);

    // 빼기 — 받지 않고 목록 · 기기 파일만 지운다
    final n = pages.gets.length;
    UserStore.instance.setMyChannels(['nintendo']);
    await c.syncChannels();
    expect(pages.gets.length, n);
    expect(c.kits.map((k) => k.id), ['nintendo-kr-14917']);
    expect(await BlobStore.read(Catalog.auxKey(atlasMsFile)), isNull);
    expect(await BlobStore.read(Catalog.auxKey('bbx-database.json')), isNull);

    // 다시 켜도 그 목록 그대로 (기기 캐시의 채널 목록)
    c.debugForget();
    await c.ensureLoaded();
    await pumpEventQueue();
    expect(c.kits.map((k) => k.id), ['nintendo-kr-14917']);
  });

  test('Gunpula 에 아직 없는 채널(닌텐도 발행 전): 받지 않고 빈 목록 · 채널은 회색', () async {
    final pages = await _start('ha_gate_absent', [
      'gundam',
      'nintendo',
    ], pages: _Pages(franchises: const ['gundam', 'beyblade', 'pokemon']));
    expect(pages.got('split/kits-nintendo.json'), 0);
    expect(await fetchKits(['nintendo']), isEmpty);
    expect(channelOf('nintendo').hasData, isFalse);
    expect(channelOf('gundam').hasData, isTrue);
  });

  test('채널을 하나도 안 고르면 상품 없이 받기가 끝난다 (실패가 아니다)', () async {
    final pages = await _start('ha_gate_none', const []);
    final c = Catalog.instance;
    expect(pages.gets.where((p) => p.startsWith('split/kits-')), isEmpty);
    expect(c.kits, isEmpty);
    expect(c.phase, CatalogPhase.ready);
    await c.ensureLoaded(); // 다시 불러도 오류 없음
  });

  test('더한 채널을 못 받으면 그 채널을 보는 화면만 오류 — 다시 시도하면 받는다', () async {
    final pages = await _start('ha_gate_fail', ['gundam']);
    pages.missing.add('split/kits-nintendo.json');
    UserStore.instance.setMyChannels(['gundam', 'nintendo']);
    await expectLater(fetchKits(['nintendo']), throwsA(isA<ApiException>()));
    expect((await fetchKits(['gundam', 'nintendo'])).map((k) => k.id), ['hg-001'], reason: '전체는 있는 것만');

    pages.missing.clear();
    expect((await fetchKits(['nintendo'])).map((k) => k.id), ['nintendo-kr-14917']);
  });

  test('새 판이어도 지문(franchise_hashes)이 같은 채널 파일은 다시 받지 않는다', () async {
    final pages = _Pages()..franchiseHashes = {'gundam': 'g1', 'beyblade': 'b1'};
    await _start('ha_gate_hash', ['gundam', 'beyblade'], pages: pages);
    final c = Catalog.instance;
    expect(pages.got('split/kits-gundam.json'), 1);

    pages
      ..updated = '2026-11-15'
      ..franchiseHashes = {'gundam': 'g1', 'beyblade': 'b2'};
    expect(await c.refresh(), isTrue);
    expect(pages.got('split/kits-gundam.json'), 1, reason: '건담 파일은 그대로');
    expect(pages.got('split/kits-beyblade.json'), 2);
    expect(c.kits.map((k) => k.id).toSet(), {'hg-001', 'beyblade-x-bx01'});
  });

  testWidgets('채널을 받는 동안 불러오는 중 자리에 그 채널 이름 · 받은 MB', (tester) async {
    final c = Catalog.instance
      ..channelStep = '닌텐도 상품 받는 중'
      ..channelBytes = 3 * 1024 * 1024;
    addTearDown(() {
      c
        ..channelStep = ''
        ..channelBytes = 0;
    });
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SizedBox(height: 120, child: LoadingView())),
      ),
    );
    expect(find.text('닌텐도 상품 받는 중 · 3.0 MB'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: '상세의 120 높이 칸에도 들어간다');
  });
}
