// 고르지 않은 채널의 내 상품 (2026-11-14): 채널을 고른 것만 받게 되자 옛 7채널 캐시에서 올라오거나 채널을 빼면 좋아요 ·
// 구매함 · 예약 · 알림이 기댄 상품이 사라졌다. 그 상품만 기기에 따로 두어(catalog_kept.json) byId · 컬렉션 · 알림에는 있고
// 둘러보는 목록에는 없다. 가짜 Pages 는 고르지 않은 채널의 주소를 받으러 오면 적어 둔다.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/api.dart';
import 'package:hobby_atlas/channels.dart';
import 'package:hobby_atlas/data/blob_store.dart';
import 'package:hobby_atlas/data/catalog.dart';
import 'package:hobby_atlas/data/gunpula.dart';
import 'package:hobby_atlas/data/tag_atlas.dart' show mezastarJpFile;
import 'package:hobby_atlas/data/user_store.dart';
import 'package:hobby_atlas/logic/preorder.dart';
import 'package:hobby_atlas/models.dart';
import 'package:hobby_atlas/notifications/notify_store.dart' show preorderDuesFor, releaseDaysFor;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

/// 받은 경로 (data/ 아래) → 그 경로가 딸린 채널 (모든 채널이 같이 쓰는 파일이면 null)
String? _channelOf(String p) {
  final m = RegExp(r'^(?:split/kits|search/search)-(\w+)\.json$').firstMatch(p);
  return m?.group(1) ?? auxChannel[p];
}

class _Pages {
  _Pages(this.allowed);

  /// 받아도 되는 채널 (내 채널)
  Set<String> allowed;

  /// 채널 → 상품 (없으면 `<채널>-1` 하나)
  final data = <String, List<Map<String, Object?>>>{};
  final gets = <String>[];
  final violations = <String>[];

  MockClient client() => MockClient((req) async {
    final p = req.url.path.replaceFirst(RegExp(r'^.*?/data/'), '');
    gets.add(p);
    final ch = _channelOf(p);
    if (ch != null && !allowed.contains(ch)) violations.add(p);
    if (p == 'split/manifest.json') {
      return http.Response(
        jsonEncode({
          'updated_at': '2026-11-14',
          'total': 9,
          'franchises': {for (final f in franchiseIds) f: 1},
        }),
        200,
        headers: _json,
      );
    }
    if (p.startsWith('split/kits-')) {
      final kits =
          data[ch] ??
          [
            {
              'kit_id': '$ch-1',
              'franchise': ch,
              'names': {'ko': '$ch-1'},
            },
          ];
      return http.Response(jsonEncode({'kits': kits}), 200, headers: _json);
    }
    if (p.endsWith('.json')) return http.Response('{}', 200, headers: _json);
    return http.Response('', 404);
  });
}

/// 1.1.13 이 남긴 캐시: 매핑 18 · 앱이 알던 7채널을 다 받아 두었다 (닌텐도는 없다)
Future<void> _oldCache() async {
  const old = ['gundam', 'beyblade', 'pokemon', 'armored_core', 'fate', 'madoka', 'lego'];
  await BlobStore.write(
    'catalog_meta.json',
    jsonEncode({
      'manifest': {
        'updated_at': '2026-11-13',
        'total': 7,
        'franchises': {for (final f in old) f: 1},
      },
      'map_version': 18,
      'franchises': old,
      'fetched_at': '2026-11-13T00:00:00',
    }),
  );
  await BlobStore.write(
    'catalog_kits.json',
    jsonEncode([
      for (final f in old)
        {'id': '$f-1', 'franchiseId': f, 'name': '$f-1 old', 'date': '2099-12-20', 'region': 'jp', 'priceJpy': 1650},
    ]),
  );
}

Set<String> _franchises(Iterable<Kit> kits) => {for (final k in kits) k.franchiseId};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Pages pages;
  final c = Catalog.instance;
  final me = UserStore.instance;

  setUpAll(() => me.load());

  setUp(() {
    BlobStore.debugDirectory = Directory.systemTemp.createTempSync('ha_kept');
    c.debugForget();
    me.debugLoadJson(const <String, Object?>{}); // 기록 없음 · 내 채널 = 처음 값
    pages = _Pages(defaultMyChannels.toSet());
    Catalog.debugClient = pages.client();
  });
  tearDown(() {
    Catalog.debugClient = null;
    c.debugForget();
    me.debugLoadJson(const <String, Object?>{});
  });

  test('옛 7채널 캐시에서 올라와도 레고 좋아요 · 아머드 코어 구매함 · 마도카 예약이 남는다 (레고 · 닌텐도는 받지 않는다)', () async {
    await _oldCache();
    me
      ..setStatus('lego-1', CollectStatus.wanted)
      ..setStatus('armored_core-1', CollectStatus.owned)
      ..setStatus('gundam-1', CollectStatus.wanted)
      ..putPreorder('madoka-1', const Preorder(shop: 'shop', arrival: '2099-12'));

    await c.ensureLoaded(); // 매핑이 바뀐 캐시 → 내 채널만 새로 받는다
    await pumpEventQueue();

    expect(pages.violations, isEmpty);
    expect(pages.gets, isNot(contains('split/kits-lego.json')));
    expect(pages.gets, isNot(contains('split/kits-nintendo.json')));
    expect(_franchises(c.kits), defaultMyChannels.toSet(), reason: '둘러보는 목록은 내 채널만');

    final collection = [for (final k in await fetchCollection()) k.id];
    expect(collection, containsAll(['lego-1', 'armored_core-1', 'gundam-1']));
    expect(c.byId['madoka-1']?.name, 'madoka-1 old', reason: '예약만 적은 상품도');
    expect(c.byId.containsKey('fate-1'), isFalse, reason: '적어 둔 것이 없는 상품은 두지 않는다');
    expect(
      [
        for (final k in await fetchKitsByIds(['lego-1', 'armored_core-1'])) k.id,
      ],
      ['lego-1', 'armored_core-1'],
    );
    expect(await fetchKits(['lego']), isEmpty, reason: '고르지 않은 채널의 둘러보는 목록에는 없다');
    // 알림이 기대는 것: 좋아요한 상품의 발매일 · 예약 도착
    expect(
      [
        for (final r in releaseDaysFor(['lego-1'], c.byId, DateTime(2026, 11, 14))) r.id,
      ],
      ['lego-1'],
    );
    expect(preorderDuesFor(me.activePreorders, c.byId).single.name, 'madoka-1 old');

    // 앱을 다시 켜도 (기기 파일에서)
    c.debugForget();
    await c.ensureLoaded();
    await pumpEventQueue();
    expect(c.byId['lego-1']?.name, 'lego-1 old');
    expect(c.byId['armored_core-1'], isNotNull);
    expect(_franchises(c.kits), defaultMyChannels.toSet());
    expect(pages.violations, isEmpty);
  });

  test('채널을 빼도 그 채널의 내 상품은 남고, 다시 고르면 새 데이터로 바뀐다', () async {
    pages.allowed = {...defaultMyChannels, 'lego'};
    me.setMyChannels([...defaultMyChannels, 'lego']);
    await c.ensureLoaded();
    await pumpEventQueue();
    expect(c.byId['lego-1'], isNotNull);
    me.setStatus('lego-1', CollectStatus.owned);

    pages.allowed = defaultMyChannels.toSet();
    me.setMyChannels(defaultMyChannels);
    await c.syncChannels();
    await pumpEventQueue();
    expect(_franchises(c.kits), isNot(contains('lego')));
    expect([for (final k in await fetchCollection()) k.id], contains('lego-1'));

    c.debugForget();
    await c.ensureLoaded();
    await pumpEventQueue();
    expect(c.byId['lego-1']?.name, 'lego-1', reason: '다시 켜도');
    expect(pages.violations, isEmpty);

    // 다시 고르면 받은 데이터가 이긴다 · 따로 둔 것에서는 빠진다
    pages
      ..allowed = {...defaultMyChannels, 'lego'}
      ..data['lego'] = [
        {
          'kit_id': 'lego-1',
          'franchise': 'lego',
          'names': {'ko': 'lego-1 new'},
        },
      ];
    me.setMyChannels([...defaultMyChannels, 'lego']);
    await fetchKits(['lego']);
    await pumpEventQueue();
    expect(c.byId['lego-1']?.name, 'lego-1 new');
    expect(await BlobStore.read('catalog_kept.json'), isNot(contains('lego-1')));
  });

  test('친구 컬렉션에서 좋아요한 상품: 그 채널을 빼도 남고, 이 기기에 없는 친구 상품은 받지 않는다', () async {
    await c.ensureLoaded();
    await pumpEventQueue();
    // 친구 컬렉션 화면이 부르는 길 (loaders.kitsByIds) — 레고는 이 기기에 없다
    final friendLiked = ['pokemon-1', 'lego-9'];
    final shown = await fetchKitsByIds(friendLiked);
    expect([for (final k in shown) k.id], ['pokemon-1']);
    me.setStatus(shown.single.id, CollectStatus.wanted); // 친구 컬렉션의 ♡

    me.setMyChannels(['gundam', 'beyblade']);
    await c.syncChannels();
    await pumpEventQueue();
    expect(_franchises(c.kits), {'gundam', 'beyblade'});
    expect([for (final k in await fetchCollection()) k.id], ['pokemon-1']);
    expect([for (final k in await fetchKitsByIds(friendLiked)) k.id], ['pokemon-1'], reason: '친구 화면의 「나도 있음」');
    expect(pages.violations, isEmpty);
  });

  test('메자스타 태그를 적어 둔 사람은 포켓몬을 빼도 태그 도감 파일이 기기에 남는다 (다시 받지는 않는다)', () async {
    await c.ensureLoaded();
    await pumpEventQueue();
    final key = Catalog.auxKey(mezastarJpFile);
    expect(await BlobStore.read(key), isNotNull);
    me.setTagStatus('mezastar-1', CollectStatus.owned);

    pages.allowed = {'gundam', 'beyblade'};
    me.setMyChannels(['gundam', 'beyblade']);
    await c.syncChannels();
    await pumpEventQueue();
    expect(await BlobStore.read(key), isNotNull, reason: '컬렉션 전체의 내 태그가 이 파일로 이름 · 그림을 찾는다');
    expect(await c.aux(mezastarJpFile), isNotNull);
    expect(pages.violations, isEmpty);

    // 태그가 없으면 지운다
    pages.allowed = defaultMyChannels.toSet();
    me
      ..setTagStatus('mezastar-1', CollectStatus.none)
      ..setMyChannels(defaultMyChannels);
    await c.syncChannels();
    me.setMyChannels(['gundam', 'beyblade']);
    await c.syncChannels();
    await pumpEventQueue();
    expect(await BlobStore.read(key), isNull);
    expect(pages.violations, isEmpty);
  });

  test('다른 기기에서 적은, 이 기기 어디에도 없는 상품: 기록은 지우지 않고 수에는 센다', () async {
    await c.ensureLoaded();
    await pumpEventQueue();
    me.setStatus('zoids-77', CollectStatus.owned);
    expect(await fetchCollection(), isEmpty);
    expect(me.ownedCount, 1);
    expect(me.statusOf('zoids-77'), CollectStatus.owned);
    expect(pages.violations, isEmpty);
  });
}
