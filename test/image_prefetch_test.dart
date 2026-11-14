// 새 소식 사진 미리 받기 (lib/background/image_prefetch.dart) — 하루 한도 · 밤 12시 · 와이파이만 · 새것만 · 작은 그림만
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/background/catalog_check_worker.dart';
import 'package:hobby_atlas/background/image_prefetch.dart';
import 'package:hobby_atlas/data/blob_store.dart';
import 'package:hobby_atlas/data/catalog.dart';
import 'package:hobby_atlas/logic/image_size.dart';
import 'package:hobby_atlas/notifications/feed_rules.dart';
import 'package:hobby_atlas/notifications/notify_models.dart';
import 'package:workmanager/workmanager.dart';

const _shard = 'https://mdefitko777.github.io/gunpula-img-1/';
const _thumbs = ThumbIndex(thumbs: {'${_shard}a.jpg': '${_shard}t/a.webp', '${_shard}b.jpg': '${_shard}t/b.webp'});

NoticeRecord _rec(String id, String kind, String kitId, {bool seen = false}) =>
    NoticeRecord(id: id, kind: kind, kitId: kitId, title: kitId, body: '', at: DateTime.utc(2026, 11, 14), seen: seen);

FeedEntry _entry(String date, List<(String, String, String)> items) => FeedEntry(
  date: date,
  items: [for (final (id, type, ch) in items) FeedItem(kitId: id, changeType: type, franchise: ch, name: id)],
);

/// 기기 카탈로그 파일 모양 그대로 (Catalog 가 jsonEncode 로 쓴다)
String _slim(Map<String, String> images) => jsonEncode([
  for (final e in images.entries)
    {
      'id': e.key,
      'franchiseId': 'gundam',
      'name': e.key,
      'image': e.value,
      'gallery': ['${_shard}big-${e.key}.jpg'],
    },
]);

void main() {
  group('하루 한도', () {
    test('받은 바이트를 세고, 기기 시계 밤 12시에 0 부터', () {
      final s = PrefetchState();
      final night = DateTime(2026, 11, 14, 23, 50);
      s.spend(14 * 1024 * 1024, night);
      expect(s.usedOn(night), 14 * 1024 * 1024);
      expect(s.leftOn(night), 1024 * 1024);
      s.spend(2 * 1024 * 1024, night.add(const Duration(minutes: 5)));
      expect(s.leftOn(night), 0, reason: '넘으면 0 (음수 아님)');
      final morning = DateTime(2026, 11, 15, 0, 10);
      expect(s.usedOn(morning), 0);
      expect(s.leftOn(morning), prefetchDailyCap);
      s.spend(100, morning);
      expect((s.day, s.bytes), ('2026-11-15', 100));
    });

    test('파일로 갔다 와도 같다', () {
      final s = PrefetchState(day: '2026-11-14', bytes: 5)..enqueue(['a', 'b'], DateTime.utc(2026, 11, 14));
      final back = PrefetchState.fromJson(jsonDecode(jsonEncode(s.toJson())));
      expect((back.day, back.bytes), ('2026-11-14', 5));
      expect([for (final q in back.queue) q.kitId], ['a', 'b']);
    });
  });

  group('새것만', () {
    final config = NotifyConfig(channels: const ['gundam']);
    test('읽지 않은 새 알림 + 지난번 본 날짜부터 처음 보는 내 채널 새 상품', () {
      final before = NotifyState(
        lastSeen: '2026-11-13',
        seenFeed: const {'feed-2026-11-13-old'},
        inbox: [_rec('feed-2026-11-13-had', 'added', 'had')],
      );
      final ids = newPrefetchKits(
        fresh: [
          _rec('rel-w-d1', 'release', 'w'),
          _rec('feed-x', 'added', 'quiet', seen: true), // 조용히 넣은 지난 소식
          _rec('ann-1-stage', 'ann_stage', ''),
          _rec('stream-1', 'live', ''),
        ],
        entries: [
          _entry('2026-11-14', [('n1', 'added', 'gundam'), ('p1', 'added', 'pokemon'), ('c1', 'changed', 'gundam')]),
          _entry('2026-11-13', [('old', 'added', 'gundam'), ('had', 'added', 'gundam'), ('n2', 'added', 'gundam')]),
          _entry('2026-11-12', [('older', 'added', 'gundam')]),
        ],
        before: before,
        config: config,
      );
      expect(ids, ['w', 'n1', 'n2']);
    });

    test('처음 실행(지난 소식을 조용히 채우는 날)은 피드에서 고르지 않는다', () {
      final ids = newPrefetchKits(
        fresh: const [],
        entries: [
          _entry('2026-11-14', [('n1', 'added', 'gundam')]),
        ],
        before: NotifyState(),
        config: config,
      );
      expect(ids, isEmpty);
    });

    test('한 번에 많아야 $prefetchPerRun 개', () {
      final ids = newPrefetchKits(
        fresh: [for (var i = 0; i < 60; i++) _rec('r$i', 'added', 'k$i')],
        entries: const [],
        before: NotifyState(),
        config: config,
      );
      expect(ids.length, prefetchPerRun);
    });
  });

  group('작은 그림만', () {
    test('작은 판이 있으면 그것, 원본뿐이면 받지 않는다', () {
      expect(prefetchUrl('a', '${_shard}a.jpg', _thumbs), '${_shard}t/a.webp');
      expect(prefetchUrl('c', '${_shard}c.jpg', _thumbs), isNull);
      expect(prefetchUrl('c', '${_shard}c.jpg', ThumbIndex.none), isNull);
      expect(prefetchUrl('x', null, _thumbs), isNull);
    });

    test('레고는 Rebrickable 250 px — 카탈로그에 아직 없으면 kit id 로', () {
      const small = 'https://cdn.rebrickable.com/media/thumbs/sets/31209-1.jpg/250x250p.jpg';
      expect(prefetchUrl('lego-31209-1', null, ThumbIndex.none), small);
      expect(prefetchUrl('lego-31209-1', 'https://cdn.rebrickable.com/media/sets/31209-1.jpg', ThumbIndex.none), small);
    });

    test('카탈로그 글에서 그 상품의 표지만 읽는다', () {
      final text = _slim({'a': '${_shard}a.jpg', 'q': 'https://x.test/q\\"1.jpg', 'none': ''});
      final got = slimImages(text, ['a', 'q', 'none', 'missing']);
      expect(got, {'a': '${_shard}a.jpg', 'q': 'https://x.test/q\\"1.jpg'});
    });
  });

  group('뒤 받기', () {
    late Directory dir;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('prefetch_test');
      BlobStore.debugDirectory = dir;
    });
    tearDown(() => dir.deleteSync(recursive: true));

    Future<PrefetchState> state() async =>
        PrefetchState.fromJson(jsonDecode((await BlobStore.read(imagePrefetchKey))!));

    Future<String?> Function(String) files(Map<String, String> images, {String sig = '2026-11-14|10'}) =>
        (key) async => switch (key) {
          _ when key == Catalog.cacheKitsKey => _slim(images),
          _ when key == Catalog.cacheMetaKey => jsonEncode({
            'manifest': {'updated_at': sig.split('|').first, 'total': int.parse(sig.split('|').last)},
          }),
          _ when key == Catalog.auxKey('thumbs.json') => jsonEncode({
            'schema': 'gunpula-thumbs-v1',
            'thumbs': _thumbs.thumbs,
          }),
          _ => null,
        };

    test('작은 그림만 받고, 하루 한도에서 멈추고, 다음 날 이어서', () async {
      final night = DateTime(2026, 11, 14, 23, 0);
      await BlobStore.write(
        imagePrefetchKey,
        jsonEncode(
          (PrefetchState(
            day: '2026-11-14',
            bytes: prefetchDailyCap - 1500,
          )..enqueue(['a', 'b', 'c', 'lego-1-1'], night)).toJson(),
        ),
      );
      final read = files({'a': '${_shard}a.jpg', 'b': '${_shard}b.jpg', 'c': '${_shard}c.jpg'});
      final asked = <String>[];
      Future<int?> fetch(String url) async {
        asked.add(url);
        return 1000;
      }

      var r = await runImagePrefetch(now: night, fetch: fetch, readText: read);
      expect(asked, ['${_shard}t/a.webp', '${_shard}t/b.webp'], reason: '1500 바이트 남음 → 두 장째에서 한도');
      expect(r.bytes, 2000);
      var s = await state();
      expect(s.usedOn(night), prefetchDailyCap + 500);
      expect([for (final q in s.queue) q.kitId], ['c', 'lego-1-1']);

      // 같은 날은 더 받지 않는다
      asked.clear();
      r = await runImagePrefetch(now: night.add(const Duration(minutes: 30)), fetch: fetch, readText: read);
      expect(asked, isEmpty);

      // 밤 12시가 지나면 이어서 — c 는 원본뿐이라 받지 않고 줄에서 뺀다
      final morning = DateTime(2026, 11, 15, 6);
      r = await runImagePrefetch(now: morning, fetch: fetch, readText: read);
      expect(asked, ['https://cdn.rebrickable.com/media/thumbs/sets/1-1.jpg/250x250p.jpg']);
      s = await state();
      expect(s.queue, isEmpty);
      expect((s.day, s.bytes), ('2026-11-15', 1000));
      for (final u in asked) {
        expect(u, isNot(contains('big-')), reason: '갤러리 사진은 받지 않는다');
        expect(u, isNot(endsWith('/c.jpg')));
      }
    });

    test('주소를 모르는 새 상품은 줄에 두고, 카탈로그가 새로 받혀야 다시 건다', () async {
      final t = DateTime(2026, 11, 14, 9);
      final calls = <bool>[];
      Future<void> schedule({required bool wifiOnly, bool replace = false}) async => calls.add(wifiOnly);

      expect(await queueImagePrefetch(['new'], wifiOnly: false, now: t, catalogSig: 'v1', schedule: schedule), isTrue);
      await runImagePrefetch(
        now: t,
        fetch: (_) async => 1,
        readText: files(const {}, sig: '2026-11-14|10'),
      );
      var s = await state();
      expect([for (final q in s.queue) q.kitId], ['new']);
      expect(s.scanned, '2026-11-14|10');

      // 새것 없음 · 카탈로그 그대로 → 걸지 않는다
      expect(
        await queueImagePrefetch(const [], wifiOnly: false, now: t, catalogSig: '2026-11-14|10', schedule: schedule),
        isFalse,
      );
      // 카탈로그가 새로 받혔다 → 다시
      expect(
        await queueImagePrefetch(const [], wifiOnly: false, now: t, catalogSig: '2026-11-15|12', schedule: schedule),
        isTrue,
      );
      // 이틀이 지나면 뺀다
      await runImagePrefetch(now: t.add(const Duration(days: 3)), fetch: (_) async => 1, readText: files(const {}));
      s = await state();
      expect(s.queue, isEmpty);
      expect(calls, [false, false]);
    });

    test('잠깐의 실패는 줄에 남기고 바이트는 세지 않는다', () async {
      final t = DateTime(2026, 11, 14, 9);
      await queueImagePrefetch(
        ['a'],
        wifiOnly: false,
        now: t,
        catalogSig: '',
        schedule: ({required wifiOnly, replace = false}) async {},
      );
      final r = await runImagePrefetch(now: t, fetch: (_) async => null, readText: files({'a': '${_shard}a.jpg'}));
      expect(r.bytes, 0);
      final s = await state();
      expect([for (final q in s.queue) q.kitId], ['a']);
      expect(s.usedOn(t), 0);
      // 새것이 없어도 다음 확인이 다시 건다 (끝까지 못 본 것)
      var again = false;
      await queueImagePrefetch(
        const [],
        wifiOnly: false,
        now: t,
        catalogSig: '2026-11-14|10',
        schedule: ({required wifiOnly, replace = false}) async => again = true,
      );
      expect(again, isTrue);
    });

    test('망이 끊겼으면 몇 번 실패하고 그만', () async {
      final t = DateTime(2026, 11, 14, 9);
      await BlobStore.write(
        imagePrefetchKey,
        jsonEncode((PrefetchState()..enqueue(['a', 'b', 'lego-1-1', 'lego-2-1'], t)).toJson()),
      );
      final asked = <String>[];
      await runImagePrefetch(
        now: t,
        fetch: (u) async {
          asked.add(u);
          return null;
        },
        readText: files({'a': '${_shard}a.jpg', 'b': '${_shard}b.jpg'}),
      );
      expect(asked, hasLength(prefetchMisses));
      expect((await state()).queue, hasLength(4));
    });

    test('이미 기기에 있는 그림(0 바이트)은 장 수 · 바이트에 넣지 않고 줄에서 뺀다', () async {
      final t = DateTime(2026, 11, 14, 9);
      await BlobStore.write(imagePrefetchKey, jsonEncode((PrefetchState()..enqueue(['a'], t)).toJson()));
      final r = await runImagePrefetch(now: t, fetch: (_) async => 0, readText: files({'a': '${_shard}a.jpg'}));
      expect((r.fetched, r.bytes), (0, 0));
      expect((await state()).queue, isEmpty);
    });
  });

  group('와이파이만', () {
    test('와이파이만이면 요금이 붙지 않는 망에서만 · 늘 배터리 부족이 아닐 때', () {
      final wifi = prefetchConstraints(wifiOnly: true);
      expect(wifi.networkType, NetworkType.unmetered);
      expect(wifi.requiresBatteryNotLow, isTrue);
      final mobile = prefetchConstraints(wifiOnly: false);
      expect(mobile.networkType, NetworkType.connected);
      expect(mobile.requiresBatteryNotLow, isTrue);
    });

    test('설정은 알림 설정 파일에 같이 (기본 = 모바일 데이터도)', () {
      expect(NotifyConfig().prefetchWifiOnly, isFalse);
      expect(NotifyConfig().toJson().containsKey('prefetch_wifi_only'), isFalse);
      final c = NotifyConfig.fromJson(jsonDecode(jsonEncode(NotifyConfig(prefetchWifiOnly: true).toJson())));
      expect(c.prefetchWifiOnly, isTrue);
    });

    group('확인 한 번', () {
      late Directory dir;
      setUp(() {
        dir = Directory.systemTemp.createTempSync('prefetch_check');
        BlobStore.debugDirectory = dir;
      });
      tearDown(() => dir.deleteSync(recursive: true));

      test('새 상품이 오면 줄에 세우고 와이파이만 조건으로 일을 건다 — 확인 안에서는 그림을 받지 않는다', () async {
        await BlobStore.write(
          notifyConfigKey,
          jsonEncode(NotifyConfig(channels: const ['gundam'], prefetchWifiOnly: true).toJson()),
        );
        await BlobStore.write(
          notifyStateKey,
          jsonEncode(NotifyState(lastSeen: '2026-11-13', lastManifest: '2026-11-13|9').toJson()),
        );
        final asked = <String>[];
        Future<String?> fetch(String path) async {
          asked.add(path);
          return switch (path) {
            'data/split/manifest.json' => jsonEncode({'updated_at': '2026-11-14', 'total': 10}),
            notifyFeedPath => jsonEncode({
              'schema': 1,
              'entries': [
                {
                  'date': '2026-11-14',
                  'total_after': 10,
                  'generated_at': '2026-11-14T01:00:00Z',
                  'added': [
                    {
                      'kit_id': 'gu-new',
                      'franchise': 'gundam',
                      'names': {'ko': '새 상품'},
                      'change_reasons': ['new'],
                    },
                  ],
                },
              ],
            }),
            _ => null,
          };
        }

        final calls = <bool>[];
        await runCatalogCheck(
          now: DateTime.utc(2026, 11, 14, 3),
          fetch: fetch,
          applyLive: (_) async => const {},
          schedulePrefetch: ({required wifiOnly, replace = false}) async => calls.add(wifiOnly),
        );
        expect(calls, [true]);
        final s = PrefetchState.fromJson(jsonDecode((await BlobStore.read(imagePrefetchKey))!));
        expect([for (final q in s.queue) q.kitId], ['gu-new']);
        expect(asked.where((p) => !p.startsWith('data/')), isEmpty, reason: '그림은 뒤 받기 일에서만');
      });
    });
  });
}
