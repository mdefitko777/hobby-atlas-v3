// 재판매(再販) · 예약 도착 — restocks.json 묶기(test/fixtures/restocks.sample.json, Gunpula 와 같은 모양) ·
// 알림 규칙 '재판매'(피드 changed[] 의 change_reasons 'restock' + restock 객체) · '예약 도착'
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/data/gunpula.dart' show auxFiles;
import 'package:hobby_atlas/logic/restock.dart';
import 'package:hobby_atlas/notifications/feed_rules.dart';
import 'package:hobby_atlas/notifications/notify_models.dart';

final Object? restocksJson = jsonDecode(File('test/fixtures/restocks.sample.json').readAsStringSync());

/// 피드 하루치 — changed[] 에 재판매 한 줄 (+ 다른 이유가 섞인 줄)
Map<String, Object?> feedWith(List<Map<String, Object?>> changed, {String date = '2026-11-02'}) => {
  'schema': 1,
  'entries': [
    {
      'date': date,
      'generated_at': '${date}T04:00:00.000Z',
      'total_after': 100,
      'restock_count': changed.length,
      'added': <Object?>[],
      'changed': changed,
    },
  ],
};

Map<String, Object?> restockItem(
  String id, {
  List<String> reasons = const ['restock'],
  Map<String, Object?>? restock,
}) => {
  'kit_id': id,
  'change_type': 'changed',
  'franchise': 'gundam',
  'names': {'ko': '상품 $id'},
  'release_date': '2020-05',
  'change_reasons': reasons,
  'restock':
      restock ??
      {'date': '2027-01', 'kind': 'pb_resale', 'url': 'https://p-bandai.jp/item/item-1/', 'announced_at': '2026-10-30'},
};

void main() {
  group('restocks.json 묶기', () {
    final idx = RestockIndex.parse(restocksJson);

    test('kit_id 별 · 새것부터 · 같은 소식 한 번 · 깨진 줄 버림', () {
      expect(idx.byKit.keys, unorderedEquals(['hg-001', 'mg-002', 'rg-003']));
      expect(idx.of('hg-001').map((e) => e.date), ['2026-12', '2025-06-14']);
      expect(idx.of('hg-001').first.label, 'PB 재판매');
      expect(idx.of('hg-001').first.title, contains('再販'));
      expect(idx.of('hg-001').last.quiet, isTrue);
      expect(idx.of('mg-002').single.sourceUrl, ''); // http 가 아닌 주소는 버린다
      expect(idx.of('mg-002').single.dateEstimated, isTrue);
      expect(idx.of('mg-002').single.day, 20);
      expect(idx.of('rg-003').single.label, '추첨');
      expect(idx.of('nope'), isEmpty);
    });

    test('달력: 그 달 · 고른 상품만 · quiet 빼고', () {
      expect(idx.inMonth(['hg-001', 'mg-002'], DateTime(2026, 12)).map((e) => e.kitId), ['hg-001']);
      expect(idx.inMonth(['hg-001'], DateTime(2025, 6)), isEmpty); // quiet
      expect(idx.inMonth(['rg-003'], DateTime(2026, 12)), isEmpty);
    });

    test('파일이 없거나 모양이 다르면 빈 묶음', () {
      expect(RestockIndex.parse(null).isEmpty, isTrue);
      expect(RestockIndex.parse('x').isEmpty, isTrue);
      expect(
        RestockIndex.parse([
          {'kit_id': 'a', 'date': '2026-12'},
        ]).of('a'),
        hasLength(1),
      );
    });

    test('보조 파일 목록에 들어 있다', () => expect(auxFiles, contains(restocksFile)));
  });

  group('재판매 알림 규칙', () {
    final now = DateTime(2026, 11, 2, 12);
    CheckPlan plan(NotifyConfig c, Map<String, Object?> feed, {NotifyState? state}) => planCheck(
      config: c,
      state: state ?? NotifyState(lastSeen: '2026-11-01'),
      entries: parseFeed(feed),
      manifestSig: 'x',
      now: now,
    );

    test('피드 restock 객체 읽기 (release_date 는 원래 발매일)', () {
      final it = parseFeed(feedWith([restockItem('a')])).single.items.single;
      expect(it.isRestock, isTrue);
      expect(it.restockDate, '2027-01');
      expect(it.restockKind, 'pb_resale');
      expect(it.releaseDate, '2020-05');
      expect(itemBody(it), '재판매 2027.01 · PB');
    });

    test('좋아요한 상품 → 재판매 줄 + 휴대폰 알림 "재판매 · 「이름」 YYYY.MM" · kit:<id>', () {
      final c = NotifyConfig(channels: const ['pokemon'], wanted: {'a'}); // 채널 밖이어도
      final p = plan(c, feedWith([restockItem('a')]));
      final r = p.records.single;
      expect(r.kind, 'restock');
      expect(r.channel, 'restock');
      expect(r.date, '2027-01');
      expect(r.body, '재판매 · 2027.01 · 좋아요한 상품 · PB 재판매');
      final a = buildAlerts(p.records).single;
      expect(a.title, '재판매 · 「상품 a」 2027.01');
      expect(a.payload, 'kit:a');
      expect(a.channel, 'restock');
    });

    test('구매함 상품도 · 다른 이유와 섞여도 재판매로', () {
      final c = NotifyConfig(owned: {'b'});
      final p = plan(
        c,
        feedWith([
          restockItem('b', reasons: ['limited', 'source', 'restock']),
        ]),
      );
      expect(p.records.single.kind, 'restock');
      expect(p.records.single.body, contains('구매함 상품'));
    });

    test('관심 없는 상품 · 규칙 끔 · quiet 는 재판매로 알리지 않는다', () {
      expect(plan(NotifyConfig(channels: const []), feedWith([restockItem('z')])).records, isEmpty);
      final off = NotifyConfig(owned: {'b'}, rules: {'restock': false});
      expect(plan(off, feedWith([restockItem('b')])).records, isEmpty);
      final quiet = restockItem('b', restock: {'date': '2025-01', 'kind': 'pb_resale', 'quiet': true});
      expect(plan(NotifyConfig(owned: {'b'}), feedWith([quiet])).records, isEmpty);
    });

    test('재판매 규칙을 꺼도 좋아요 규칙으로는 한 줄 (변경 이유 글자에 재판매)', () {
      final c = NotifyConfig(wanted: {'a'}, rules: {'restock': false});
      final r = plan(c, feedWith([restockItem('a')])).records.single;
      expect(r.kind, 'changed');
      expect(r.body, contains('재판매 2027.01 · PB'));
    });

    test('재판매 넷 이상이면 요약 하나', () {
      final c = NotifyConfig(wanted: {'a', 'b', 'c', 'd'});
      final p = plan(
        c,
        feedWith([
          for (final id in ['a', 'b', 'c', 'd']) restockItem(id),
        ]),
      );
      final alerts = buildAlerts(p.records);
      expect(alerts.single.title, '재판매 소식 4개');
      expect(alerts.single.payload, 'inbox');
    });

    test('규칙 기본값 켜짐 · 설정 칩 목록에 있음', () {
      expect(notifyRuleDefaults['restock'], isTrue);
      expect(notifyRuleDefaults['preorder_arrival'], isTrue);
      expect(notifyInterestRules, containsAll(['restock', 'preorder_arrival']));
      expect(notifyRuleLabels['restock'], '재판매');
    });
  });

  group('예약 도착 알림', () {
    NotifyConfig cfg(List<PreorderDue> p, {bool on = true}) =>
        NotifyConfig(preorders: p, rules: {'preorder_arrival': on});

    test('도착 달에 한 번 · 하루까지 정했으면 그날 한 번 더 · 이미 알린 것은 빼고', () {
      final dues = [
        const PreorderDue(id: 'a', name: 'A', arrival: '2026-11', due: 7000, shop: 'PB'),
        const PreorderDue(id: 'b', name: 'B', arrival: '2026-11-02'),
        const PreorderDue(id: 'c', name: 'C', arrival: '2026-12'),
      ];
      final day = DateTime(2026, 11, 2, 9);
      final recs = preorderRecords(cfg(dues), {}, day);
      expect(recs.map((r) => r.id), ['pre-a-2026-11-month', 'pre-b-2026-11-02-month', 'pre-b-2026-11-02-d0']);
      expect(recs.first.body, '예약 · 이번 달 도착 예정 · PB · 낼 돈 7,000원');
      expect(recs.last.body, '예약 · 오늘 도착 예정 · 결제 완료');
      expect(recs.first.channel, 'preorder');
      expect(NotifyState.isInboxId(recs.first.id), isTrue);
      expect(preorderRecords(cfg(dues), {for (final r in recs) r.id}, day), isEmpty);
      expect(preorderRecords(cfg(dues, on: false), {}, day), isEmpty);
      final alert = buildAlerts(recs).first;
      expect(alert.title, '예약 도착 · 「A」');
      expect(alert.payload, 'kit:a');
    });

    test('설정 파일 왕복 (owned · preorders)', () {
      final c = NotifyConfig(
        owned: {'x'},
        preorders: [const PreorderDue(id: 'a', name: 'A', arrival: '2026-11', due: 5)],
      );
      final back = NotifyConfig.fromJson(jsonDecode(jsonEncode(c.toJson())));
      expect(back.owned, {'x'});
      expect(back.preorders.single.toJson(), c.preorders.single.toJson());
      expect(PreorderDue.fromJson({'id': 'a', 'arrival': 'soon'}), isNull);
    });
  });
}
