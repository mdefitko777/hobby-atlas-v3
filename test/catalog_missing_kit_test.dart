// 「새 상품」 휴대폰 알림을 눌렀을 때 — 뒤 작업(runCatalogCheck)은 새 manifest 를 보고 알림을 보내지만,
// 이 기기 상품 목록은 아직 옛것이다. 예전에는 fetchKitsByIds 가 캐시만 보고 빈 목록을 돌려줘
// 알림 화면 → 「이 상품은 지금 카탈로그에 없어요」가 떴다. 이제 못 찾으면 새 데이터를 받은 뒤 다시 찾는다.
// + 앱으로 돌아올 때의 확인(checkForNewData)은 간격 안이면 manifest 도 받지 않는다.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/api.dart';
import 'package:hobby_atlas/data/blob_store.dart';
import 'package:hobby_atlas/data/catalog.dart';
import 'package:hobby_atlas/data/gunpula.dart' show manifestSignature;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, Object?> _kit(String id, String name) => {
  'kit_id': id,
  'franchise': 'fate',
  'names': {'ko': name},
};

void main() {
  test('목록에 없는 상품 → 새 데이터를 받아 찾는다 · 다시 눌러도 1분 안엔 manifest 를 또 받지 않는다', () async {
    BlobStore.debugDirectory = Directory.systemTemp.createTempSync('ha_missing_kit');
    var updated = '2026-11-10';
    var kits = [_kit('fate-old', '세이버')];
    var manifestGets = 0;
    var kitGets = 0;
    Catalog.debugClient = MockClient((req) async {
      final p = req.url.path;
      if (p.endsWith('split/manifest.json')) {
        manifestGets++;
        return http.Response('{"updated_at":"$updated","total":${kits.length}}', 200);
      }
      if (p.endsWith('split/kits-fate.json')) {
        kitGets++;
        return http.Response(
          jsonEncode({'kits': kits}),
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
    expect(kitGets, 1);
    final v0 = c.version;

    // Gunpula 에 새 상품이 들어왔다 (뒤 작업이 이것을 보고 「새 상품 · 아처」 알림을 보냈다)
    updated = '2026-11-11';
    kits = [_kit('fate-old', '세이버'), _kit('fate-new', '아처')];
    // 방금(1분 안) 확인했고 뒤 작업 소식도 모르면 — 다시 받지 않는다 (못 찾은 id 마다 manifest 를 받지 않게)
    expect(await fetchKitsByIds(['fate-new']), isEmpty);
    expect(kitGets, 1);
    // 뒤 작업이 본 새 manifest (notify_state.json last_manifest → NotifyStore._adopt) — 이 목록보다 새것
    expect(c.noteManifestSeen(manifestSignature({'updated_at': updated, 'total': 2})), isTrue);
    // 여러 개를 늘어놓는 목록(도감 칸 · 친구 컬렉션)은 기다리지 않고 있는 것만 바로
    expect((await fetchKitsByIds(['fate-old', 'fate-new'])).map((k) => k.id), ['fate-old']);
    expect(kitGets, 1);
    final found = await fetchKitsByIds(['fate-new']);
    expect(found.map((k) => k.id), ['fate-new']);
    expect(kitGets, 2);
    expect(c.version, v0 + 1);
    expect(c.lastChangeQuiet, isTrue, reason: '뒤에서 받은 것 — 앱 셸은 보고 있는 탭을 바로 다시 만들지 않는다');
    expect(c.noteManifestSeen(manifestSignature({'updated_at': updated, 'total': 2})), isFalse, reason: '이제 같은 판');

    // 정말 없는 id 를 여러 번 — 1분 안에는 manifest 를 다시 받지 않는다
    final gets = manifestGets;
    expect(await fetchKitsByIds(['no-such-kit']), isEmpty);
    expect(await fetchKitsByIds(['no-such-kit']), isEmpty);
    expect(manifestGets, gets);

    // 있는 상품은 인터넷을 보지 않는다
    expect(await fetchKitsByIds(['fate-old']), hasLength(1));
    expect(manifestGets, gets);

    // 돌아올 때 확인: 간격 안이면 받지 않고, 간격이 0이면 manifest 만 (같으면 상품은 받지 않는다)
    expect(await c.checkForNewData(maxAge: const Duration(minutes: 20)), isFalse);
    expect(manifestGets, gets);
    expect(await c.checkForNewData(maxAge: Duration.zero), isFalse);
    expect(manifestGets, gets + 1);
    expect(kitGets, 2);
  });

  test('받는 중에 찾으면 그 받기가 끝날 때까지 기다린다 (켜자마자 알림을 누른 때)', () async {
    BlobStore.debugDirectory = Directory.systemTemp.createTempSync('ha_missing_kit_inflight');
    var kits = [_kit('fate-old', '세이버')];
    var updated = '2026-11-10';
    var manifestGets = 0;
    Catalog.debugClient = MockClient((req) async {
      final p = req.url.path;
      if (p.endsWith('split/manifest.json')) {
        manifestGets++;
        return http.Response('{"updated_at":"$updated","total":${kits.length}}', 200);
      }
      if (p.endsWith('split/kits-fate.json')) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return http.Response(
          jsonEncode({'kits': kits}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (p.contains('split/kits-')) return http.Response('{"kits":[]}', 200);
      return http.Response('', 404);
    });
    addTearDown(() => Catalog.debugClient = null);
    final c = Catalog.instance..debugForget(); // 앞 테스트의 메모리를 비우고 이 폴더에 처음 받기
    await c.ensureLoaded();
    expect(c.byId.keys, ['fate-old']);

    // 앱을 새로 켠 것처럼: 캐시로 먼저 보이고 뒤에서 새 데이터를 받는 중
    updated = '2026-11-11';
    kits = [_kit('fate-old', '세이버'), _kit('fate-new', '아처')];
    c.debugForget();
    final gets = manifestGets;
    final found = await fetchKitsByIds(['fate-new']);
    expect(found.map((k) => k.id), ['fate-new']);
    expect(manifestGets, gets + 1, reason: '켤 때의 받기 하나로 — 따로 또 받지 않는다');
  });

  test('뒤에서 받는 중에 당겨서 새로 고침 · 지금 새로 받기 — 그 받기를 기다려 결과를 알려 주고 사람이 고른 것으로 친다', () async {
    BlobStore.debugDirectory = Directory.systemTemp.createTempSync('ha_refresh_during_quiet');
    var kits = [_kit('fate-old', '세이버')];
    var updated = '2026-11-10';
    var manifestGets = 0;
    var kitGets = 0;
    Catalog.debugClient = MockClient((req) async {
      final p = req.url.path;
      if (p.endsWith('split/manifest.json')) {
        manifestGets++;
        return http.Response('{"updated_at":"$updated","total":${kits.length}}', 200);
      }
      if (p.endsWith('split/kits-fate.json')) {
        kitGets++;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return http.Response(
          jsonEncode({'kits': kits}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (p.contains('split/kits-')) return http.Response('{"kits":[]}', 200);
      return http.Response('', 404);
    });
    addTearDown(() => Catalog.debugClient = null);
    final c = Catalog.instance..debugForget();
    await c.ensureLoaded();

    // 켜자마자 뒤에서 새 데이터를 받는 중에 홈을 당겼다 — 예전에는 바로 false(「새것 없음」)였고, 받은 뒤에도
    // 뒤에서 받은 것이라 보고 있던 홈은 옛 데이터로 남았다
    updated = '2026-11-11';
    kits = [_kit('fate-old', '세이버'), _kit('fate-new', '아처')];
    c.debugForget();
    final gets = manifestGets;
    final v0 = c.version;
    final ensure = c.ensureLoaded(); // 캐시 → 뒤에서 refresh(quiet)
    await ensure;
    expect(await c.refresh(), isTrue);
    expect(c.version, v0 + 1);
    expect(c.lastChangeQuiet, isFalse);
    expect(manifestGets, gets + 1, reason: '같은 받기 하나');

    // 지금 새로 받기(force) 를 눌렀는데 뒤의 확인이 같은 manifest 였다 → 그래도 다시 받는다
    final k0 = kitGets;
    final quiet = c.checkForNewData(maxAge: Duration.zero);
    expect(await c.refresh(force: true), isTrue);
    expect(await quiet, isFalse);
    expect(kitGets, k0 + 1);
    expect(c.lastChangeQuiet, isFalse);
  });
}
