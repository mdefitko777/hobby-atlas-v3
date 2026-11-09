// 새 소식 알림 계산 — Gunpula 실제 파일에서 잘라 낸 조각(test/fixtures)으로 확인한다.
//   update-feed-lite.sample.json        : 2026-10-23 기준 lite 피드 (날짜마다 20개까지)
//   notify-feed.sample.json · update-feed-lite-1101.sample.json · manifest-1101.sample.json :
//       2026-11-01(새 상품 312개) 의 새 소식 파일(atlas, 건담 · 포켓몬 · AC 는 전부, Fate 는 일부) 과 같은 날의 lite 피드
//   거르기(내 채널 · 규칙 · 좋아요) · 처음 실행 · 같은 날짜 다시 · 규칙 끄기 · 오래 꺼져 있다 켜기 · PB 예약 기간 ·
//   알림함 합치기(앱 ↔ 백그라운드) · 바쁜 날 lite 가 잘라 낸 상품 · 피드 고르기(atlas → lite) · 파일까지 한 바퀴(runCatalogCheck)
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/background/catalog_check_worker.dart';
import 'package:hobby_atlas/data/blob_store.dart';
import 'package:hobby_atlas/models.dart';
import 'package:hobby_atlas/notifications/feed_rules.dart';
import 'package:hobby_atlas/notifications/notify_models.dart';
import 'package:hobby_atlas/notifications/notify_store.dart' show pbWindowsFor;

final Map<String, Object?> feedJson =
    jsonDecode(File('test/fixtures/update-feed-lite.sample.json').readAsStringSync()) as Map<String, Object?>;
final String manifestText = File('test/fixtures/manifest.sample.json').readAsStringSync();
final String atlasText = File('test/fixtures/notify-feed.sample.json').readAsStringSync();
final String lite1101Text = File('test/fixtures/update-feed-lite-1101.sample.json').readAsStringSync();
final String manifest1101Text = File('test/fixtures/manifest-1101.sample.json').readAsStringSync();

/// 새 소식 파일에서 [date] 이전(포함) 날짜만 남긴 것 = Gunpula Atlas 작업이 아직 그날 것을 안 올린 상태
String atlasUpTo(String date) {
  final j = jsonDecode(atlasText) as Map<String, Object?>;
  j['entries'] = (j['entries']! as List).where((e) => ((e as Map)['date'] as String).compareTo(date) <= 0).toList();
  return jsonEncode(j);
}

/// 기본 설정 (옛 앱 기본 규칙 + 처음 내 채널: 건담 · 베이블레이드 · 포켓몬)
NotifyConfig defaults({Set<String> wanted = const {}, List<PbWindow> pb = const []}) =>
    NotifyConfig(channels: const ['gundam', 'beyblade', 'pokemon'], wanted: wanted, pb: pb);

/// 피드에 날짜 하나를 더한다 — [from] 날짜의 상품 그대로, 날짜만 [date]
Map<String, Object?> withEntry(String date, {String from = '2026-10-23', List<String>? only, int? total}) {
  final copy = jsonDecode(jsonEncode(feedJson)) as Map<String, Object?>;
  final entries = copy['entries']! as List;
  final src = Map<String, Object?>.from(entries.firstWhere((e) => (e as Map)['date'] == from) as Map);
  src['date'] = date;
  src['generated_at'] = '${date}T00:10:00.000Z';
  if (total != null) src['total_after'] = total;
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

    test('발매일이 처음 생긴 것(release_found)은 알리지 않고, 바뀐 발매일(release)은 알린다', () {
      FeedItem it(String id, String reason) => FeedItem.fromJson({
        'kit_id': id,
        'franchise': 'fate',
        'change_reasons': [reason],
      }, 'changed')!;
      expect(it('a', 'release_found').meaningful, isFalse);
      expect(it('b', 'release').meaningful, isTrue);
    });

    test('세계관 전체 규칙을 켜면 그 채널 새 상품 전부', () {
      final c = defaults()..rules['pokemon'] = true;
      expect(ruleHits(item('2026-10-23', 'pokemon-kr-137504096'), c), {'pokemon'});
    });

    test('내가 만든 조건 — 채널 · 작품(캐릭터) · 종류, 내 채널 밖이어도', () {
      FeedItem it(Map<String, Object?> j) => FeedItem.fromJson(j, 'added')!;
      final hg = it({'kit_id': 'a', 'franchise': 'gundam', 'series_key': 'seed', 'grade_code': 'HG'});
      final mg = it({'kit_id': 'b', 'franchise': 'gundam', 'series_key': 'seed', 'grade_code': 'MG'});
      final homura = it({
        'kit_id': 'c',
        'franchise': 'madoka',
        'grade_code': 'NENDOROID',
        'groups': ['homura'],
      });
      final c = defaults(); // 내 채널 = 건담 · 베이 · 포켓몬 (마도카 아님)
      c.rules['seed_00'] = false;
      c.conditions
        ..add(const NotifyCondition(franchise: 'gundam', scope: 'series:seed', scopeLabel: 'SEED', line: 'HG'))
        ..add(const NotifyCondition(franchise: 'madoka', scope: 'group:homura', scopeLabel: '호무라'));
      expect(ruleHits(hg, c), {'cond:gundam|series:seed|HG'});
      expect(ruleHits(mg, c), isEmpty); // 종류가 다르다
      expect(ruleHits(homura, c), {'cond:madoka|group:homura|'}); // 내 채널 밖이어도
      expect(
        ruleHits(
          it({
            'kit_id': 'd',
            'franchise': 'madoka',
            'groups': ['mami'],
          }),
          c,
        ),
        isEmpty,
      );
      // 저장 · 읽기 한 바퀴
      final back = NotifyConfig.fromJson(c.toJson());
      expect(back.conditions.map((x) => x.id), ['gundam|series:seed|HG', 'madoka|group:homura|']);
      expect(back.conditions.last.scopeLabel, '호무라');
    });

    test('조건의 종류 = 앱 상품의 종류 (일본어 이름 · subline 으로 고친 등급)', () {
      FeedItem it(Map<String, Object?> j) => FeedItem.fromJson(j, 'added')!;
      final c = defaults();
      c.conditions
        ..add(const NotifyCondition(franchise: 'fate', scope: '', scopeLabel: '', line: '미니 · 트레이딩'))
        ..add(const NotifyCondition(franchise: 'madoka', scope: '', scopeLabel: '', line: 'figma'));
      // FATE_SCALE 이지만 이름이 트레이딩 피규어 → 앱에선 미니 · 트레이딩
      final mini = it({
        'kit_id': 'f1',
        'franchise': 'fate',
        'grade_code': 'FATE_SCALE',
        'name_ja': 'Fate トレーディングフィギュア',
      });
      final scale = it({'kit_id': 'f2', 'franchise': 'fate', 'grade_code': 'FATE_SCALE', 'name_ja': 'セイバー 1/7'});
      expect(ruleHits(mini, c), {'cond:fate||미니 · 트레이딩'});
      expect(ruleHits(scale, c), isEmpty);
      // figma 는 subline 으로만 — 같은 액션 피규어라도 BUZZmod. 는 아니다
      final figma = it({
        'kit_id': 'm1',
        'franchise': 'madoka',
        'grade_code': 'MADOKA_ACTION',
        'subline': 'figma',
        'name_ja': 'figma 暁美ほむら',
      });
      final buzz = it({
        'kit_id': 'm2',
        'franchise': 'madoka',
        'grade_code': 'MADOKA_ACTION',
        'subline': 'BUZZmod.',
        'name_ja': 'BUZZmod. 鹿目まどか',
      });
      expect(ruleHits(figma, c), {'cond:madoka||figma'});
      expect(ruleHits(buzz, c), isEmpty);
      // subline · 이름이 없는 옛 피드는 전처럼 액션 피규어 전체
      expect(ruleHits(it({'kit_id': 'm3', 'franchise': 'madoka', 'grade_code': 'MADOKA_ACTION'}), c), {
        'cond:madoka||figma',
      });
    });

    test('레고 범위 "최근 정식 세트" — 범위 밖 레고는 규칙 · 조건으로 알리지 않는다', () {
      FeedItem it(Map<String, Object?> j) => FeedItem.fromJson(j, 'added')!;
      final c = defaults()..channels = ['lego'];
      c.rules['lego'] = true;
      final set = it({
        'kit_id': 'lego-75192-1',
        'franchise': 'lego',
        'grade_code': 'LEGO_SET',
        'series_key': 'lego_star_wars',
        'release_date': '2017-10',
      });
      final gear = it({
        'kit_id': 'lego-853990-1',
        'franchise': 'lego',
        'grade_code': 'LEGO_GEAR',
        'series_key': 'lego_gear',
        'release_date': '2020',
      });
      final old = it({
        'kit_id': 'lego-6089-1',
        'franchise': 'lego',
        'grade_code': 'LEGO_SET',
        'series_key': 'lego_city',
        'release_date': '2014',
      });
      expect(ruleHits(set, c), contains('lego'));
      expect(ruleHits(gear, c), isEmpty);
      expect(ruleHits(old, c), isEmpty);
      c.legoAll = true; // 설정 › 레고 범위 › 전부
      expect(ruleHits(gear, c), contains('lego'));
      expect(NotifyConfig.fromJson(c.toJson()).legoAll, isTrue);
    });

    test('새 상품이 5개를 넘으면 요약 하나 — 요약마다 id 가 달라 앞 요약을 덮지 않는다', () {
      final at = DateTime.utc(2026, 11, 3);
      List<NoticeRecord> batch(String p, int n) => [
        for (var i = 0; i < n; i++)
          NoticeRecord(id: '$p$i', kind: 'added', kitId: '$p$i', title: '$p$i', body: '', at: at, date: '2026-11-03'),
      ];
      final a = buildAlerts(batch('a', 6));
      final b = buildAlerts(batch('b', 7));
      expect(a, hasLength(1));
      expect(a.single.payload, 'inbox');
      expect(a.single.id, isNot(b.single.id));
      expect(buildAlerts(batch('c', 5)), hasLength(5));
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

    test('새 피드 날짜 → 상품마다 알림 하나 · 같은 날짜로 다시 돌면 또 울리지 않는다', () {
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
      expect(alerts, hasLength(2)); // 5개까지는 하나씩
      expect(alerts.every((a) => a.channel == 'catalog'), isTrue);
      expect(alerts.first.title, 'MG 1 / 100 건담아스트레이 느와르');
      expect(alerts.first.payload, 'kit:mg-mg-1-100-4543112863584000');
      expect(alerts.map((a) => a.id).toSet(), hasLength(2)); // 서로 덮어쓰지 않는다
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
      expect(alert.title, 'MGSD 크샤트리아');
      expect(alert.payload, 'kit:mgsd-mgsd-4573102743039000');
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

    test('pbWindowsFor: 좋아요한 상품 중 기간이 남은 것만 백그라운드 설정에 (마감일 없으면 시작 사흘 안쪽)', () {
      Kit k(String id, {String opens = '', String closes = ''}) => Kit(
        id: id,
        franchiseId: 'gundam',
        name: 'HG $id',
        nameJa: '',
        series: '',
        line: 'HG',
        type: '',
        scale: '',
        universe: '',
        date: '',
        priceJpy: null,
        image: '',
        gallery: const [],
        limited: true,
        pb: true,
        status: CollectStatus.wanted,
        wantedQty: 1,
        recent: false,
        month: false,
        market: null,
        keywords: const [],
        pbOpens: opens,
        pbCloses: closes,
      );
      final byId = {
        for (final kit in [
          k('open-soon', opens: '2026-10-26', closes: '2026-11-30'),
          k('closed', opens: '2026-07-08', closes: '2026-10-12'),
          k('no-close-recent', opens: '2026-10-23'),
          k('no-close-old', opens: '2026-10-01'),
          k('no-window'),
        ])
          kit.id: kit,
      };
      final ws = pbWindowsFor([...byId.keys, 'not-in-catalog'], byId, now);
      expect(ws.map((w) => w.id), ['open-soon', 'no-close-recent']);
      expect(ws.first.opens, '2026-10-26');
      expect(ws.first.closes, '2026-11-30');
      expect(ws.first.franchise, 'gundam');
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
          rec('feed-old', base.subtract(const Duration(days: NotifyState.keepDays + 1))),
          for (var i = 0; i < NotifyState.maxInbox + 5; i++) rec('feed-n$i', base.subtract(Duration(minutes: i))),
        ],
        flags: {
          'feed-old': const NoticeFlag(read: true, u: 1),
          'feed-n0': const NoticeFlag(read: true, u: 1),
          'pb-open-gone-2026-10-01': const NoticeFlag(dismissed: true, u: 1),
        },
      )..prune(base);
      expect(s.inbox, hasLength(NotifyState.maxInbox));
      expect(s.inbox.first.id, 'feed-n0');
      expect(s.flags.keys, ['feed-n0']);
    });

    test('알림함 밖 줄(친구 요청 req- 등)의 표시는 확인할 때 지우지 않는다 — 바꾼 지 120일이 지나면만', () {
      final base = DateTime.utc(2026, 10, 25);
      final recent = base.subtract(const Duration(days: 1)).millisecondsSinceEpoch;
      final old = base.subtract(const Duration(days: NotifyState.keepDays + 1)).millisecondsSinceEpoch;
      final s = NotifyState(
        inbox: [rec('feed-a', base)],
        flags: {
          'req-alice': NoticeFlag(dismissed: true, read: true, u: recent), // 수락한 친구 요청
          'friend-demo-1': NoticeFlag(read: true, u: recent),
          'req-old': NoticeFlag(dismissed: true, u: old),
          'feed-orphan': NoticeFlag(read: true, u: recent),
        },
      );
      // 백그라운드 확인이 한 바퀴 돌아도 (merge → prune)
      final next = NotifyState.merge(NotifyState(), s)..prune(base);
      expect(next.flags.keys.toSet(), {'req-alice', 'friend-demo-1'});
      expect(next.isDismissed('req-alice'), isTrue);
      expect(NotifyState.isInboxId('feed-2026-10-23-x'), isTrue);
      expect(NotifyState.isInboxId('pb-close-x-2026-11-03'), isTrue);
      expect(NotifyState.isInboxId('req-alice'), isFalse);
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
      // 새 소식 파일이 아직 없으면(이 테스트의 fetch 는 그 파일에도 lite 를 준다 → schema 가 달라 버림) lite 로
      expect(asked, ['data/split/manifest.json', notifyFeedPath, liteFeedPath]);
      expect(r.source, 'lite');
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
      feed = jsonEncode(withEntry('2026-10-24', total: 8860));
      manifest = jsonEncode({'updated_at': '2026-10-24', 'total': 8860});
      r = await runCatalogCheck(now: now, fetch: fetch);
      expect(asked, ['data/split/manifest.json', notifyFeedPath, liteFeedPath]);
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

    // 2026-11-01 갱신 직후: Pages 에 manifest · lite 는 새것, 새 소식 파일은 몇 분 늦게 올라온다
    test('새 소식 파일이 늦으면 lite 로 먼저 알리고, 올라온 뒤 다시 받아 잘린 상품을 알린다', () async {
      final c = defaults(wanted: {'pokemon-kr-137529060'});
      await BlobStore.write(notifyConfigKey, jsonEncode(c.toJson()));
      // 10.23 까지 본 상태
      final s0 = planCheck(
        config: c,
        state: NotifyState(),
        entries: parseFeed(jsonDecode(lite1101Text)).where((e) => e.date == '2026-10-23').toList(),
        manifestSig: '2026-10-23|8853',
        now: DateTime.utc(2026, 10, 24),
      ).applyTo(NotifyState());
      await BlobStore.write(notifyStateKey, jsonEncode(s0.toJson()));

      final asked = <String>[];
      var atlas = atlasUpTo('2026-10-23');
      Future<String?> fetch(String path) async {
        asked.add(path);
        return switch (path) {
          'data/split/manifest.json' => manifest1101Text,
          notifyFeedPath => atlas,
          _ => lite1101Text,
        };
      }

      final t0 = DateTime.utc(2026, 11, 1, 5); // lite 를 만든 지 25분
      var r = await runCatalogCheck(now: t0, fetch: fetch);
      expect(asked, ['data/split/manifest.json', notifyFeedPath, liteFeedPath]);
      expect(r.source, 'atlas+lite');
      var state = NotifyState.fromJson(jsonDecode((await BlobStore.read(notifyStateKey))!));
      expect(state.lastSeen, '2026-11-01');
      expect(state.lastManifest, '2026-10-23|8853'); // 다 본 것으로 적지 않는다 → 다음에 다시
      expect(state.pending, startsWith('2026-11-01|9165|'));
      final firstIds = {for (final x in state.inbox) x.id};
      expect(firstIds, isNot(contains('feed-2026-11-01-pokemon-kr-137529060'))); // lite 에는 없다

      // 25분 뒤: 새 소식 파일이 올라왔다
      asked.clear();
      atlas = atlasText;
      r = await runCatalogCheck(now: t0.add(const Duration(minutes: 25)), fetch: fetch);
      expect(asked, ['data/split/manifest.json', notifyFeedPath]); // lite 는 다시 받지 않는다
      expect(r.source, 'atlas');
      state = NotifyState.fromJson(jsonDecode((await BlobStore.read(notifyStateKey))!));
      expect(state.lastManifest, '2026-11-01|9165');
      expect(state.pending, '');
      expect(state.lastSource, 'atlas');
      final late = state.inbox.where((x) => !firstIds.contains(x.id)).toList();
      expect(late.map((x) => x.id), contains('feed-2026-11-01-pokemon-kr-137529060')); // 좋아요한 상품 (lite 가 잘라 냄)
      expect(late.map((x) => x.id), contains('feed-2026-11-01-hg-hg-1-144-4573102691859000')); // PB (lite 가 잘라 냄)
      expect(late.where((x) => x.seen), isEmpty); // 늦게라도 휴대폰 알림
      expect(r.liveCount, late.length);

      // 그다음은 manifest 만
      asked.clear();
      r = await runCatalogCheck(now: t0.add(const Duration(hours: 1)), fetch: fetch);
      expect(asked, ['data/split/manifest.json']);
      expect(r.liveCount, 0);
    });

    test('같은 판의 피드가 끝내 안 오면(사진만 다시 받은 날) 6시간 뒤 그만 기다린다', () async {
      await BlobStore.write(notifyConfigKey, jsonEncode(defaults().toJson()));
      final s0 = NotifyState(
        lastSeen: '2026-10-23',
        lastManifest: '2026-10-23|8853',
        lastCheckAt: '2026-10-24T00:00:00.000Z',
      );
      await BlobStore.write(notifyStateKey, jsonEncode(s0.toJson()));
      final asked = <String>[];
      Future<String?> fetch(String path) async {
        asked.add(path);
        return switch (path) {
          'data/split/manifest.json' => jsonEncode({'updated_at': '2026-10-25', 'total': 8853}),
          notifyFeedPath => null, // 404
          _ => jsonEncode(feedJson), // 10.23 판 그대로
        };
      }

      final t0 = DateTime.utc(2026, 10, 25, 1);
      await runCatalogCheck(now: t0, fetch: fetch);
      var state = NotifyState.fromJson(jsonDecode((await BlobStore.read(notifyStateKey))!));
      expect(state.lastManifest, '2026-10-23|8853');
      expect(state.pending, '2026-10-25|8853|${t0.toIso8601String()}');

      await runCatalogCheck(now: t0.add(const Duration(hours: 3)), fetch: fetch);
      state = NotifyState.fromJson(jsonDecode((await BlobStore.read(notifyStateKey))!));
      expect(state.lastManifest, '2026-10-23|8853');
      expect(state.pending, startsWith('2026-10-25|8853|${t0.toIso8601String()}')); // 처음 본 시각 그대로

      asked.clear();
      await runCatalogCheck(now: t0.add(const Duration(hours: 7)), fetch: fetch);
      state = NotifyState.fromJson(jsonDecode((await BlobStore.read(notifyStateKey))!));
      expect(state.lastManifest, '2026-10-25|8853');
      expect(state.pending, '');
      asked.clear();
      await runCatalogCheck(now: t0.add(const Duration(hours: 8)), fetch: fetch);
      expect(asked, ['data/split/manifest.json']);
    });
  });

  group('바쁜 날: lite 피드가 잘라 낸 상품 (2026-11-01 새 상품 312개)', () {
    final lite = parseFeed(jsonDecode(lite1101Text));
    final atlas = parseFeed(jsonDecode(atlasText));
    final manifest = jsonDecode(manifest1101Text);

    test('두 파일 모두 같은 모양으로 읽고, manifest 와 같은 판인지 안다', () {
      expect(atlas.map((e) => e.date), ['2026-11-01', '2026-10-23']);
      expect(atlas.first.totalAfter, 9165);
      expect(atlas.first.addedCount, 312);
      expect(lite.first.items.where((i) => i.changeType == 'added'), hasLength(20)); // lite 는 20개까지
      expect(feedMatches(atlas, manifest), isTrue);
      expect(feedMatches(lite, manifest), isTrue);
      expect(feedMatches(parseFeed(jsonDecode(atlasUpTo('2026-10-23'))), manifest), isFalse); // CDN 이 옛 판
      expect(feedMatches(parseFeed(feedJson), manifest), isFalse);
      expect(feedMatches(atlas, {'updated_at': '2026-11-01', 'total': 9166}), isFalse); // 같은 날 두 번째 갱신
      expect(feedMatches(const [], manifest), isFalse);
      final mandala = atlas.first.items.firstWhere((i) => i.kitId == 'hg-hg-1-144-4573102691859000');
      expect(mandala.isPb, isTrue); // 새 소식 파일은 is_premium_bandai 를 미리 계산해 둔다
      expect(mandala.reasons, ['source']);
      expect(mandala.name, 'HG 1 / 144 マンダラ건담');
    });

    test('좋아요한 상품 · PB 는 lite 로는 놓치고 새 소식 파일로는 잡힌다', () {
      final c = defaults(wanted: {'pokemon-kr-137529060', 'hg-hg-1-144-4580886844531000'});
      final s0 = planCheck(
        config: c,
        state: NotifyState(),
        entries: lite.where((e) => e.date == '2026-10-23').toList(),
        manifestSig: '2026-10-23|8853',
        now: DateTime.utc(2026, 10, 24),
      ).applyTo(NotifyState());
      List<NoticeRecord> live(List<FeedEntry> entries) => planCheck(
        config: c,
        state: s0,
        entries: entries,
        manifestSig: '2026-11-01|9165',
        now: DateTime.utc(2026, 11, 1, 6),
      ).records.where((r) => !r.seen && r.date == '2026-11-01').toList();
      final fromLite = live(lite);
      final fromAtlas = live(atlas);
      expect(fromLite.where((r) => r.wanted), isEmpty);
      expect(fromLite.where((r) => r.pb).map((r) => r.kitId), [
        'hg-hg-1-144-specii-4573102688590000',
      ]); // lite 에 남은 PB 하나뿐
      expect(fromAtlas.where((r) => r.wanted).map((r) => r.kitId).toSet(), {
        'pokemon-kr-137529060',
        'hg-hg-1-144-4580886844531000',
      });
      expect(fromAtlas.where((r) => r.pb).map((r) => r.kitId).toSet(), {
        'hg-hg-1-144-specii-4573102688590000',
        'hg-hg-1-144-4573102691859000', // HG 만다라 건담 (lite 가 잘라 냄)
      });
      expect(fromAtlas.map((r) => r.id).toSet().containsAll(fromLite.map((r) => r.id)), isTrue); // lite 에 있던 것도 그대로
      final alerts = buildAlerts(fromAtlas);
      expect(alerts.where((a) => a.channel == 'wanted'), hasLength(2)); // 하나씩
    });

    test('loadFeed: 새 소식 파일 → (없거나 옛 판이면) lite', () async {
      Future<FeedLoad> load({String? atlasBody, String? liteBody, DateTime? at, List<String>? asked}) => loadFeed(
        (p) async {
          asked?.add(p);
          return p == notifyFeedPath ? atlasBody : liteBody;
        },
        manifest as Map<String, Object?>,
        at ?? DateTime.utc(2026, 11, 1, 5),
      );
      final asked = <String>[];
      var f = await load(atlasBody: atlasText, liteBody: lite1101Text, asked: asked);
      expect((f.source, f.settled), ('atlas', true));
      expect(asked, [notifyFeedPath]); // lite 는 받지 않는다
      f = await load(atlasBody: null, liteBody: lite1101Text);
      expect((f.source, f.settled), ('lite', true)); // 아직 Gunpula 에 없는 파일 → lite 로 다 본 것
      f = await load(atlasBody: atlasUpTo('2026-10-23'), liteBody: lite1101Text);
      expect((f.source, f.settled), ('atlas+lite', false)); // 늦는 중 → 다시 받아 본다
      expect(f.entries.map((e) => e.date), ['2026-11-01', '2026-10-23']);
      expect(f.entries.last.items.length, greaterThan(lite.last.items.length)); // 10.23 은 새 소식 파일 것까지
      f = await load(atlasBody: atlasUpTo('2026-10-23'), liteBody: lite1101Text, at: DateTime.utc(2026, 11, 1, 8));
      expect((f.source, f.settled), ('atlas+lite', true)); // lite 를 만든 지 2시간 넘음 → 그만 기다린다
      f = await load(atlasBody: atlasUpTo('2026-10-23'), liteBody: jsonEncode(feedJson));
      expect((f.source, f.settled), ('atlas+lite', false)); // 둘 다 옛 판 (CDN)
      f = await load(atlasBody: '{"schema":2}', liteBody: null);
      expect((f.source, f.settled), ('', false));
      expect(f.entries, isEmpty);
    });
  });

  group('파일 잠금 (앱 화면 · 백그라운드가 같은 파일을 동시에)', () {
    late Directory dir;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('notify_lock');
      BlobStore.debugDirectory = dir;
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('읽고 · 합치고 · 쓰는 동안 끼어들지 못한다 · 임시 파일이 남지 않는다', () async {
      await BlobStore.write('counter', '0');
      Future<void> bump() => BlobStore.locked('counter', () async {
        final v = int.parse((await BlobStore.read('counter'))!);
        await Future<void>.delayed(const Duration(milliseconds: 3));
        await BlobStore.write('counter', '${v + 1}');
      });
      await Future.wait([for (var i = 0; i < 12; i++) bump()]);
      expect(await BlobStore.read('counter'), '12');
      expect(dir.listSync().map((f) => f.uri.pathSegments.last), ['counter']);
    });

    test('쓰다 죽은 잠금(30초 넘음)은 지우고 진행한다', () async {
      final stale = File('${dir.path}/x.lock')..writeAsStringSync('');
      stale.setLastModifiedSync(DateTime.now().subtract(const Duration(minutes: 5)));
      final sw = Stopwatch()..start();
      expect(await BlobStore.locked('x', () async => 7), 7);
      expect(sw.elapsed, lessThan(const Duration(seconds: 2)));
      expect(stale.existsSync(), isFalse);
    });
  });
}
