// 새 소식 알림 계산 — Gunpula update-feed-lite.json 에서 잘라 낸 실제 모양 조각(test/fixtures)으로 확인한다.
//   거르기(내 채널 · 규칙 · 좋아요) · 처음 실행 · 같은 날짜 다시 · 규칙 끄기 · 오래 꺼져 있다 켜기 · PB 예약 기간 ·
//   알림함 합치기(앱 ↔ 백그라운드) · 파일까지 한 바퀴(runCatalogCheck)
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/background/catalog_check_worker.dart';
import 'package:hobby_atlas/data/blob_store.dart';
import 'package:hobby_atlas/notifications/feed_rules.dart';
import 'package:hobby_atlas/notifications/notify_models.dart';

final Map<String, Object?> feedJson =
    jsonDecode(File('test/fixtures/update-feed-lite.sample.json').readAsStringSync()) as Map<String, Object?>;
final String manifestText = File('test/fixtures/manifest.sample.json').readAsStringSync();

/// 기본 설정 (옛 앱 기본 규칙 + 처음 내 채널: 건담 · 베이블레이드 · 포켓몬)
NotifyConfig defaults({Set<String> wanted = const {}, List<PbWindow> pb = const []}) =>
    NotifyConfig(channels: const ['gundam', 'beyblade', 'pokemon'], wanted: wanted, pb: pb);

/// 피드에 날짜 하나를 더한다 — [from] 날짜의 상품 그대로, 날짜만 [date]
Map<String, Object?> withEntry(String date, {String from = '2026-10-23', List<String>? only}) {
  final copy = jsonDecode(jsonEncode(feedJson)) as Map<String, Object?>;
  final entries = copy['entries']! as List;
  final src = Map<String, Object?>.from(entries.firstWhere((e) => (e as Map)['date'] == from) as Map);
  src['date'] = date;
  src['generated_at'] = '${date}T00:10:00.000Z';
  if (only != null) {
    for (final k in ['added', 'changed']) {
      src[k] = (src[k]! as List).where((i) => only.contains((i as Map)['kit_id'])).toList();
    }
  }
  entries.insert(0, src);
  copy['updated_at'] = date;
  return copy;
}

final now = DateTime(2026, 10, 25, 9);

NotifyState firstRun(NotifyConfig c) => planCheck(
  config: c,
  state: NotifyState(),
  entries: parseFeed(feedJson),
  manifestSig: '2026-10-23|8853',
  now: now,
).applyTo(NotifyState());

void main() {
  group('피드 읽기', () {
    test('날짜 새것부터 · 상품 모양', () {
      final entries = parseFeed(feedJson);
      expect(entries.map((e) => e.date), ['2026-10-23', '2026-10-21', '2026-10-17', '2026-10-16', '2026-10-11']);
      final e = entries.first;
      expect(e.addedCount, 21); // 그날 전체 수 (lite 목록은 일부)
      expect(e.generatedAt, DateTime.utc(2026, 10, 22, 22, 9, 31, 413));
      final noir = e.items.firstWhere((i) => i.kitId == 'mg-mg-1-100-4543112863584000');
      expect(noir.changeType, 'changed');
      expect(noir.name, 'MG 1 / 100 건담아스트레이 느와르'); // ko 먼저
      expect(noir.priceJpy, 5940);
      expect(noir.isSeed00, isTrue);
      expect(noir.meaningful, isTrue); // 가격
      expect(e.items.firstWhere((i) => i.kitId == 'mgsd-mgsd-4573102743039000').isPb, isTrue);
      expect(e.items.firstWhere((i) => i.kitId == 'gsf-gallery-f13-4-a').meaningful, isFalse); // 분류만
    });

    test('BBX 의 BX-00 · CX-00 은 SEED / 00 이 아니다 (watch_tags 의 00 은 오탐)', () {
      final bbx = parseFeed(
        feedJson,
      ).firstWhere((e) => e.date == '2026-10-16').items.firstWhere((i) => i.kitId == 'beyblade-x-cx00-vv');
      expect(bbx.watchTags, ['00']);
      expect(bbx.isSeed00, isFalse);
      expect(bbx.isBbx, isTrue);
    });

    test('사진 · 이름만 바뀐 것은 알리지 않는다', () {
      final all = [for (final e in parseFeed(feedJson)) ...e.items];
      expect(all.firstWhere((i) => i.kitId == 'pokepla-01-4237').meaningful, isFalse); // image
      expect(all.firstWhere((i) => i.kitId == 'beyblade-x-ux00-ap-red').meaningful, isFalse); // name
      expect(all.firstWhere((i) => i.kitId == 'moncolle-mc-126').meaningful, isTrue); // name + image + source
    });

    test('PB 판정은 옛 앱과 같다 (is_premium_bandai 가 없어도 이름 · 주소로)', () {
      expect(
        itemIsPremiumBandai({
          'kit_id': 'x',
          'names': {'ja': 'プレミアムバンダイ限定 HG'},
        }),
        isTrue,
      );
      expect(
        itemIsPremiumBandai({
          'kit_id': 'x',
          'source_urls': ['https://p-bandai.jp/item/item-1000/'],
        }),
        isTrue,
      );
      expect(
        itemIsPremiumBandai({
          'kit_id': 'hg-1',
          'names': {'ja': 'HG ガンダム'},
        }),
        isFalse,
      );
    });

    test('깨진 파일 · 빈 값에도 죽지 않는다', () {
      expect(parseFeed(null), isEmpty);
      expect(
        parseFeed({
          'entries': [
            {'date': 'oops'},
            3,
            null,
          ],
        }),
        isEmpty,
      );
      expect(NotifyState.fromJson('nope').inbox, isEmpty);
      expect(NotifyConfig.fromJson(null).rule('premium_bandai'), isTrue);
    });
  });

  group('규칙 · 내 채널', () {
    final items = {
      for (final e in parseFeed(feedJson))
        for (final i in e.items) '${e.date}/${i.kitId}': i,
    };
    FeedItem item(String date, String id) => items['$date/$id']!;

    test('기본 규칙 = PB · SEED/00 · BBX (옛 앱 DEFAULT_NOTIFICATION_FILTERS)', () {
      final c = defaults();
      expect(ruleHits(item('2026-10-23', 'mg-mg-1-100-4543112863584000'), c), {'seed_00'});
      expect(ruleHits(item('2026-10-23', 'mgsd-mgsd-4573102743039000'), c), {'premium_bandai'});
      expect(ruleHits(item('2026-10-17', 'pbandai-wb-1000259133'), c), {'premium_bandai', 'seed_00'});
      expect(ruleHits(item('2026-10-16', 'beyblade-x-bx54'), c), {'bbx'});
      // 세계관 전체 규칙은 기본으로 꺼져 있다
      expect(ruleHits(item('2026-10-23', 'hg-hgbd-r-1-144-4573102605375000'), c), isEmpty);
      expect(ruleHits(item('2026-10-23', 'pokemon-kr-137504096'), c), isEmpty);
    });

    test('내 채널 밖(Fate · AC)은 규칙에 걸려도 알리지 않는다 — "내 채널 소식만" 을 끄면 알린다', () {
      final c = defaults()
        ..rules['fate'] = true
        ..rules['armored_core'] = true;
      final fate = item('2026-10-17', 'hobbysearch-fate-11485325');
      final ac = item('2026-10-16', 'acvi-4934054083251');
      expect(ruleHits(fate, c), isEmpty);
      expect(ruleHits(ac, c), isEmpty);
      c.onlyMine = false;
      expect(ruleHits(fate, c), {'fate'});
      expect(ruleHits(ac, c), {'armored_core'});
    });

    test('세계관 전체 규칙을 켜면 그 채널 새 상품 전부', () {
      final c = defaults()..rules['pokemon'] = true;
      expect(ruleHits(item('2026-10-23', 'pokemon-kr-137504096'), c), {'pokemon'});
    });

    test('좋아요한 상품은 채널 · 규칙과 상관없이 (가격 변경)', () {
      final fatePrice = item('2026-10-21', 'hobbysearch-fate-11336822'); // Fate, 내 채널 밖, 규칙 없음
      final c = defaults(wanted: {fatePrice.kitId});
      final e = parseFeed(feedJson).firstWhere((e) => e.date == '2026-10-21');
      final r = recordForItem(fatePrice, e, c)!;
      expect(r.wanted, isTrue);
      expect(r.channel, 'wanted');
      expect(r.body, startsWith('좋아요한 상품 · 가격 변경 ¥'));
      c.rules['wanted'] = false;
      expect(recordForItem(fatePrice, e, c), isNull);
    });
  });

  group('확인 계산 (planCheck)', () {
    test('처음 실행: 최근 7일만 읽음으로 채우고 휴대폰 알림은 없다', () {
      final c = defaults();
      final plan = planCheck(
        config: c,
        state: NotifyState(),
        entries: parseFeed(feedJson),
        manifestSig: '2026-10-23|8853',
        now: now,
      );
      // 10-23: 느와르(SEED) · 크샤트리아(PB) / 10-17: PB 3 / 10-16: BBX 3 / 10-11 은 7일 밖
      expect(plan.records.map((r) => r.id).toSet(), {
        'feed-2026-10-23-mg-mg-1-100-4543112863584000',
        'feed-2026-10-23-mgsd-mgsd-4573102743039000',
        'feed-2026-10-17-pbandai-wb-1000259133',
        'feed-2026-10-17-pbandai-wb-1000255094',
        'feed-2026-10-17-pbandai-wb-1000259642',
        'feed-2026-10-16-beyblade-x-cx00-vv',
        'feed-2026-10-16-beyblade-x-bx-00-143',
        'feed-2026-10-16-beyblade-x-bx54',
      });
      expect(plan.records.every((r) => r.seen), isTrue);
      expect(buildAlerts(plan.records), isEmpty);
      expect(plan.lastSeen, '2026-10-23');
      expect(plan.lastManifest, '2026-10-23|8853');
      final s = plan.applyTo(NotifyState());
      expect(s.inbox.first.id, startsWith('feed-2026-10-23-')); // 새것부터
      expect(s.isRead(s.inbox.first.id), isTrue);
    });

    test('새 피드 날짜 → 알림 하나 (SEED/00 제목) · 같은 날짜로 다시 돌면 또 울리지 않는다', () {
      final c = defaults();
      var state = firstRun(c);
      final next = parseFeed(withEntry('2026-10-24'));
      final plan = planCheck(config: c, state: state, entries: next, manifestSig: '2026-10-24|8860', now: now);
      expect(plan.records.map((r) => r.id), [
        'feed-2026-10-24-mg-mg-1-100-4543112863584000',
        'feed-2026-10-24-mgsd-mgsd-4573102743039000',
      ]);
      expect(plan.records.every((r) => !r.seen), isTrue);
      final alerts = buildAlerts(plan.records);
      expect(alerts, hasLength(1));
      expect(alerts.single.channel, 'catalog');
      expect(alerts.single.title, 'SEED / 00 업데이트');
      expect(alerts.single.body, startsWith('10.24 · 신규 0 · 변경 2 · 「MG 1 / 100 건담아스트레이 느와르」'));
      expect(alerts.single.payload, 'inbox'); // 둘 이상이면 알림 화면
      state = plan.applyTo(state);
      expect(state.lastSeen, '2026-10-24');

      final again = planCheck(config: c, state: state, entries: next, manifestSig: '2026-10-24|8860', now: now);
      expect(again.records, isEmpty);
      expect(buildAlerts(again.records), isEmpty);
    });

    test('같은 날짜에 상품이 늘면(하루 두 번 실행) 늘어난 것만', () {
      final c = defaults();
      var state = firstRun(c);
      final morning = parseFeed(withEntry('2026-10-24', only: ['mg-mg-1-100-4543112863584000']));
      state = planCheck(config: c, state: state, entries: morning, manifestSig: 'a', now: now).applyTo(state);
      final evening = parseFeed(withEntry('2026-10-24'));
      final plan = planCheck(config: c, state: state, entries: evening, manifestSig: 'b', now: now);
      expect(plan.records.map((r) => r.kitId), ['mgsd-mgsd-4573102743039000']);
      final alert = buildAlerts(plan.records).single;
      expect(alert.title, '관심 항목 업데이트'); // PB
      expect(alert.payload, 'kit:mgsd-mgsd-4573102743039000'); // 하나면 그 상품으로
    });

    test('이미 본 날짜는 규칙을 켜거나 좋아요를 눌러도 다시 울리지 않는다', () {
      final c = defaults();
      final state = firstRun(c);
      c.rules['pokemon'] = true;
      c.wanted = {'hg-hgbd-r-1-144-4573102605375000'};
      final plan = planCheck(config: c, state: state, entries: parseFeed(feedJson), manifestSig: 'y', now: now);
      expect(plan.records, isEmpty);
    });

    test('규칙을 끄면 알리지 않는다', () {
      final c = defaults();
      final state = firstRun(c);
      c.rules
        ..['seed_00'] = false
        ..['premium_bandai'] = false;
      final plan = planCheck(
        config: c,
        state: state,
        entries: parseFeed(withEntry('2026-10-24')),
        manifestSig: 'x',
        now: now,
      );
      expect(plan.records, isEmpty);
      expect(plan.lastSeen, '2026-10-24'); // 본 날짜는 앞으로
    });

    test('오래 꺼져 있다 켜지면 7일보다 오래된 날짜는 조용히 넣는다', () {
      final c = defaults();
      final state = NotifyState(lastSeen: '2026-10-10');
      final plan = planCheck(config: c, state: state, entries: parseFeed(feedJson), manifestSig: 'x', now: now);
      final old = plan.records.where((r) => r.date == '2026-10-11').toList();
      expect(old, hasLength(2));
      expect(old.every((r) => r.seen), isTrue);
      expect(plan.records.where((r) => r.date != '2026-10-11').every((r) => !r.seen), isTrue);
      expect(buildAlerts(plan.records).single.title, 'SEED / 00 업데이트');
    });

    test('피드를 못 받으면 날짜 · manifest 기록을 그대로 둔다', () {
      final state = NotifyState(lastSeen: '2026-10-23', lastManifest: '2026-10-23|8853');
      final plan = planCheck(
        config: defaults(),
        state: state,
        entries: const [],
        manifestSig: '',
        now: now,
        error: '인터넷에 연결하지 못했어요',
      );
      final next = plan.applyTo(state);
      expect(next.lastSeen, '2026-10-23');
      expect(next.lastManifest, '2026-10-23|8853');
      expect(next.lastError, '인터넷에 연결하지 못했어요');
    });

    test('좋아요한 상품: 3개까지 하나씩 (누르면 그 상품), 넘으면 요약', () {
      const ids = [
        'hg-hgbd-r-1-144-4573102605375000',
        'aniplex-fate-itemaimsoidf05',
        'pokemon-kr-137504096',
        'pokemon-center-4904810088165',
      ];
      final state = firstRun(defaults());
      var c = defaults(wanted: ids.take(2).toSet());
      var plan = planCheck(
        config: c,
        state: state,
        entries: parseFeed(withEntry('2026-10-24')),
        manifestSig: 'x',
        now: now,
      );
      var wanted = buildAlerts(plan.records).where((a) => a.channel == 'wanted').toList();
      expect(wanted.map((a) => a.payload), ['kit:hg-hgbd-r-1-144-4573102605375000', 'kit:aniplex-fate-itemaimsoidf05']);
      expect(wanted.first.id, stableId('wanted:hg-hgbd-r-1-144-4573102605375000'));

      c = defaults(wanted: ids.toSet());
      plan = planCheck(
        config: c,
        state: state,
        entries: parseFeed(withEntry('2026-10-24')),
        manifestSig: 'x',
        now: now,
      );
      wanted = buildAlerts(plan.records).where((a) => a.channel == 'wanted').toList();
      expect(wanted, hasLength(1));
      expect(wanted.single.title, '좋아요한 상품 4개가 바뀌었어요');
      expect(wanted.single.payload, 'inbox');
    });
  });

  group('PB 예약 기간 (Wayback · 바뀌었을 수 있음)', () {
    const kit = 'pbandai-wb-1000254018';
    NotifyConfig cfg(String opens, String closes, {bool wanted = true}) => defaults(
      wanted: wanted ? {kit} : const {},
      pb: [PbWindow(id: kit, name: 'HG 테스트', franchise: 'gundam', opens: opens, closes: closes)],
    );

    test('내일 시작 · 마감 D-2 · 오늘 마감', () {
      var rs = pbWindowRecords(cfg('2026-10-26', '2026-11-30'), {}, now);
      expect(rs.single.id, 'pb-open-$kit-2026-10-26');
      expect(rs.single.body, '내일 예약 시작 (10.26) · $pbStaleNote');
      rs = pbWindowRecords(cfg('', '2026-10-27'), {}, now);
      expect(rs.single.kind, 'pb_close');
      expect(rs.single.body, '예약 마감 D-2 (10.27) · $pbStaleNote');
      rs = pbWindowRecords(cfg('', '2026-10-25'), {}, now);
      expect(rs.single.body, startsWith('오늘 예약 마감'));
      final alert = buildAlerts(rs).single;
      expect(alert.channel, 'pb');
      expect(alert.title, 'PB 예약 마감 임박 · HG 테스트');
      expect(alert.payload, 'kit:$kit');
    });

    test('지난 기간 · 먼 마감 · 좋아요 아님 · 이미 알림 · 규칙 끔 → 없음', () {
      expect(pbWindowRecords(cfg('2026-07-08', '2026-10-12'), {}, now), isEmpty);
      expect(pbWindowRecords(cfg('', '2026-12-31'), {}, now), isEmpty);
      expect(pbWindowRecords(cfg('2026-10-26', '', wanted: false), {}, now), isEmpty);
      expect(pbWindowRecords(cfg('2026-10-26', ''), {'pb-open-$kit-2026-10-26'}, now), isEmpty);
      expect(pbWindowRecords(cfg('2026-10-26', '')..rules['pb_window'] = false, {}, now), isEmpty);
    });

    test('planCheck 는 피드가 그대로여도 PB 기간을 본다 (처음 실행이어도 알림)', () {
      final plan = planCheck(
        config: cfg('2026-10-25', ''),
        state: NotifyState(lastSeen: '2026-10-23', lastManifest: 'same'),
        entries: const [],
        manifestSig: 'same',
        now: now,
      );
      expect(plan.records.single.body, '오늘 예약 시작 · $pbStaleNote');
      expect(buildAlerts(plan.records), hasLength(1));
    });
  });

  group('알림함 합치기 (앱 화면 ↔ 백그라운드)', () {
    NoticeRecord rec(String id, DateTime at) =>
        NoticeRecord(id: id, kind: 'added', kitId: id, title: id, body: '', at: at);

    test('줄은 id 로 모으고, 읽음 · 지움은 나중에 바꾼 쪽이 이긴다 (되돌리기 포함)', () {
      final t = DateTime.utc(2026, 10, 24);
      final disk = NotifyState(
        lastSeen: '2026-10-24',
        lastCheckAt: '2026-10-24T01:00:00.000Z',
        lastManifest: 'bg',
        inbox: [rec('a', t), rec('b', t)],
        flags: {'a': const NoticeFlag(read: true, u: 100)},
      );
      final app = NotifyState(
        lastSeen: '2026-10-23',
        lastCheckAt: '2026-10-23T01:00:00.000Z',
        lastManifest: 'fg',
        inbox: [rec('a', t), rec('c', t.add(const Duration(hours: 1)))],
        flags: {
          'a': const NoticeFlag(read: false, u: 200), // 읽음 되돌리기 (더 나중)
          'c': const NoticeFlag(dismissed: true, u: 50),
        },
      );
      final m = NotifyState.merge(disk, app);
      expect(m.inbox.map((r) => r.id), ['c', 'a', 'b']);
      expect(m.isRead('a'), isFalse);
      expect(m.isDismissed('c'), isTrue);
      expect(m.lastSeen, '2026-10-24');
      expect(m.lastManifest, 'bg'); // 나중에 확인한 쪽
    });

    test('오래된 줄 · 넘치는 줄 · 주인 없는 표시는 버린다', () {
      final base = DateTime.utc(2026, 10, 25);
      final s = NotifyState(
        inbox: [
          rec('old', base.subtract(const Duration(days: NotifyState.keepDays + 1))),
          for (var i = 0; i < NotifyState.maxInbox + 5; i++) rec('n$i', base.subtract(Duration(minutes: i))),
        ],
        flags: {'old': const NoticeFlag(read: true, u: 1), 'n0': const NoticeFlag(read: true, u: 1)},
      )..prune(base);
      expect(s.inbox, hasLength(NotifyState.maxInbox));
      expect(s.inbox.first.id, 'n0');
      expect(s.flags.keys, ['n0']);
    });

    test('JSON 로 저장했다 읽어도 같다', () {
      final s = firstRun(defaults());
      s.flags['x'] = const NoticeFlag(read: true, dismissed: false, u: 7);
      final back = NotifyState.fromJson(jsonDecode(jsonEncode(s.toJson())));
      expect(back.inbox.map((r) => r.toJson()), s.inbox.map((r) => r.toJson()));
      expect(back.flags['x']!.read, isTrue);
      expect(back.lastSeen, s.lastSeen);
      final c = defaults(
        wanted: {'k'},
        pb: const [PbWindow(id: 'k', name: 'n', opens: '2026-10-26T10:00:00+09:00')],
      );
      final cb = NotifyConfig.fromJson(jsonDecode(jsonEncode(c.toJson())));
      expect(cb.wanted, {'k'});
      expect(cb.pb.single.opens, '2026-10-26');
      expect(cb.channels, ['gundam', 'beyblade', 'pokemon']);
    });

    test('알림 id 는 실행마다 같다 (FNV-1a)', () {
      expect(stableId('catalog'), stableId('catalog'));
      expect(stableId(''), 0x811c9dc5 & 0x7fffffff);
      expect(stableId('catalog'), isNot(stableId('wanted')));
      expect(stableId('catalog'), lessThanOrEqualTo(0x7fffffff));
    });
  });

  group('파일까지 한 바퀴 (runCatalogCheck)', () {
    late Directory dir;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('notify_test');
      BlobStore.debugDirectory = dir;
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('manifest 가 그대로면 피드를 다시 받지 않는다 · 새 날짜면 받아 알림함에', () async {
      await BlobStore.write(notifyConfigKey, jsonEncode(defaults().toJson()));
      final asked = <String>[];
      var feed = jsonEncode(feedJson);
      var manifest = manifestText;
      Future<String?> fetch(String path) async {
        asked.add(path);
        return path.endsWith('manifest.json') ? manifest : feed;
      }

      var r = await runCatalogCheck(now: now, fetch: fetch);
      expect(asked, ['data/split/manifest.json', 'data/update-feed-lite.json']);
      expect(r.liveCount, 0); // 처음: 읽음으로만
      expect(r.posted, 0); // Windows 테스트에서는 휴대폰 알림 없음
      var state = NotifyState.fromJson(jsonDecode((await BlobStore.read(notifyStateKey))!));
      expect(state.lastSeen, '2026-10-23');
      expect(state.inbox, hasLength(8));

      asked.clear();
      r = await runCatalogCheck(now: now, fetch: fetch);
      expect(asked, ['data/split/manifest.json']); // 176 B 만
      expect(r.liveCount, 0);

      // 앱 화면이 그 사이 읽음 표시를 썼다 → 백그라운드 확인이 지우지 않는다
      state.flags[state.inbox.first.id] = NoticeFlag(read: false, u: DateTime.now().millisecondsSinceEpoch);
      await BlobStore.write(notifyStateKey, jsonEncode(state.toJson()));

      asked.clear();
      feed = jsonEncode(withEntry('2026-10-24'));
      manifest = jsonEncode({'updated_at': '2026-10-24', 'total': 8860});
      r = await runCatalogCheck(now: now, fetch: fetch);
      expect(asked, ['data/split/manifest.json', 'data/update-feed-lite.json']);
      expect(r.liveCount, 2);
      state = NotifyState.fromJson(jsonDecode((await BlobStore.read(notifyStateKey))!));
      expect(state.inbox, hasLength(10));
      expect(state.lastNew, 2);
      expect(state.lastManifest, '2026-10-24|8860');
      expect(state.isRead('feed-2026-10-23-mg-mg-1-100-4543112863584000'), isFalse); // 앱이 되돌린 표시 그대로
    });

    test('인터넷이 없으면 오류만 적는다', () async {
      final r = await runCatalogCheck(now: now, fetch: (_) async => null);
      expect(r.error, isNotEmpty);
      final state = NotifyState.fromJson(jsonDecode((await BlobStore.read(notifyStateKey))!));
      expect(state.lastSeen, '');
      expect(state.lastError, r.error);
    });
  });
}
