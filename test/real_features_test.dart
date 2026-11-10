// 가짜였던 기능을 진짜로 (검색 기록 · 설명으로 찾기 · 바코드 · 수량 · 휴지통 · 제보 · 같은 IP · 발매 알림 · 도움말)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/api.dart';
import 'package:hobby_atlas/data/user_store.dart';
import 'package:hobby_atlas/detail_pane.dart';
import 'package:hobby_atlas/l10n/l10n.dart';
import 'package:hobby_atlas/logic/kit_rules.dart';
import 'package:hobby_atlas/logic/market.dart';
import 'package:hobby_atlas/marks.dart';
import 'package:hobby_atlas/models.dart';
import 'package:hobby_atlas/notifications/feed_rules.dart';
import 'package:hobby_atlas/notifications/notify_models.dart';
import 'package:hobby_atlas/notifications/notify_store.dart';
import 'package:hobby_atlas/report.dart';
import 'package:hobby_atlas/screens/b_search_screen.dart';
import 'package:hobby_atlas/screens/d_kit_detail_screen.dart';
import 'package:hobby_atlas/screens/e_camera_screen.dart';
import 'package:hobby_atlas/logic/collection_rules.dart';
import 'package:hobby_atlas/logic/announcement_match.dart';
import 'package:hobby_atlas/screens/k_settings_screen.dart' show HelpScreen;
import 'package:hobby_atlas/logic/sentence_search.dart';
import 'package:hobby_atlas/theme.dart';

import 'layout_test.dart' show fakeLoaders;

Kit kit(
  String id, {
  String name = '',
  String nameJa = '',
  String nameZh = '',
  String franchise = 'gundam',
  String series = '',
  String seriesKey = '',
  String line = '',
  String type = '',
  String date = '',
  int? price,
  String jan = '',
  String firstSeen = '',
}) => Kit(
  id: id,
  franchiseId: franchise,
  name: name.isEmpty ? id : name,
  nameJa: nameJa,
  nameZh: nameZh,
  series: series,
  line: line,
  type: type,
  scale: '',
  universe: '',
  date: date,
  priceJpy: price,
  image: '',
  gallery: const [],
  limited: false,
  pb: false,
  status: CollectStatus.none,
  wantedQty: 0,
  recent: false,
  month: false,
  market: null,
  keywords: const [],
  seriesKey: seriesKey,
  jan: jan,
  firstSeen: firstSeen,
);

Future<void> _pump(WidgetTester tester, Widget home, UserStore store) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildGpTheme(),
      builder: (context, child) => MarksHost(
        store: store,
        child: PaneHost(child: child!),
      ),
      home: home,
    ),
  );
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  group('UserStore: 최근 검색 · 자주 찾은', () {
    test('같은 말은 맨 앞으로 · 20개까지 · 횟수', () {
      final me = UserStore.memory();
      for (var i = 0; i < 25; i++) {
        me.addRecentSearch('q$i');
      }
      me.addRecentSearch('  q24 ');
      me.addRecentSearch('자쿠');
      me.addRecentSearch('자쿠');
      expect(me.recentSearches.length, UserStore.maxRecentSearches);
      expect(me.recentSearches.first, '자쿠');
      expect(me.recentSearches.where((q) => q == '자쿠').length, 1);
      expect(me.frequentSearches().map((e) => e.key), unorderedEquals(['자쿠', 'q24']));
      expect(me.frequentSearches().first.value, 2);
    });

    test('하나 지우기 · 되돌리기 · 전체 지우기 · 되돌리기 · 저장 모양', () {
      final me = UserStore.memory()
        ..addRecentSearch('a')
        ..addRecentSearch('b')
        ..addRecentSearch('c');
      final i = me.removeRecentSearch('b');
      expect(me.recentSearches, ['c', 'a']);
      me.insertRecentSearch(i, 'b');
      expect(me.recentSearches, ['c', 'b', 'a']);
      final before = me.clearRecentSearches();
      expect(me.recentSearches, isEmpty);
      expect(me.searchCounts, isEmpty);
      me.restoreRecentSearches(before);
      expect(me.recentSearches, ['c', 'b', 'a']);
      final again = UserStore.memory()..debugLoadJson(me.toJson());
      expect(again.recentSearches, ['c', 'b', 'a']);
      expect(again.searchCounts['a'], 1);
    });
  });

  group('UserStore: 휴지통 · 수량 · 최근 본', () {
    test('휴지통은 저장되고 30일 지나면 버린다 · 다시 넣은 상품은 휴지통에 안 보인다', () {
      final now = DateTime.utc(2026, 11, 2);
      final me = UserStore.memory()
        ..trashAdd(['old'], owned: true, now: now.subtract(const Duration(days: 31)))
        ..trashAdd(['new', 'back'], owned: false, now: now);
      me.setStatus('back', CollectStatus.wanted);
      expect(trashView(me), {'old': true, 'new': false});
      me.purgeTrash(now);
      expect(me.trash.keys, unorderedEquals(['new', 'back']));
      final again = UserStore.memory()..debugLoadJson(me.toJson());
      expect(again.trash['new']?.from, 'wanted');
      again.trashRemove(['new']);
      expect(again.trash.containsKey('new'), isFalse);
    });

    test('수량만 바꾸면 구매가 · 메모는 그대로 · 지출 합계 × 수량', () {
      final me = UserStore.memory()..setStatus('k1', CollectStatus.owned);
      me.setPurchasePrice('k1', 3000);
      me.debugLoadJson({
        ...me.toJson(),
        'collection': {
          'items': {
            'k1': {...me.entry('k1')!, 'note': '박스 있음'},
          },
        },
      });
      me.setQuantity('k1', 3);
      expect(me.quantityOf('k1'), 3);
      expect(me.entry('k1')!['purchase_price'], 3000);
      expect(me.entry('k1')!['note'], '박스 있음');
      expect(me.spendKrw, 9000);
      me.setQuantity('k1', 500);
      expect(me.quantityOf('k1'), 99);
      me.setPurchasePrice('k1', null);
      expect(me.entry('k1')!.containsKey('purchase_price'), isFalse);
      expect(me.entry('k1')!['note'], '박스 있음');
      expect(me.quantityOf('none'), 1);
    });

    test('최근 본 기록 지우기 · 되돌리기', () {
      final me = UserStore.memory()
        ..markViewed('a')
        ..markViewed('b');
      final before = me.clearRecentViewed();
      expect(me.recentViewed, isEmpty);
      me.restoreRecentViewed(before);
      expect(me.recentViewed, ['b', 'a']);
    });
  });

  group('설명으로 찾기', () {
    final kits = [
      kit('a', name: 'HG 샤아 전용 자쿠II', series: '초대', seriesKey: 'uc_first', line: 'HG', type: '프라모델', date: '2026-01'),
      kit('b', name: 'MG ザク ウォーリア', seriesKey: 'seed', line: 'MG', type: '프라모델', date: '2025-05'),
      kit('c', name: 'HG 건담 에어리얼', seriesKey: 'witch', line: 'HG', type: '프라모델', date: '2024-01'),
      kit('d', name: 'ピカチュウ ぬいぐるみ', franchise: 'pokemon', line: '봉제인형', type: '인형'),
      kit('e', name: '자쿠 아크릴 스탠드', type: '굿즈', date: '2027-01'),
      kit('f', name: '드랜 소드 3-60F', franchise: 'beyblade', line: 'BX', type: '배틀 토이'),
    ];

    test('한국어 · 일본어 · 영어 표기를 한 뜻으로 묶고 남은 낱말은 그대로', () {
      final q = parseSentence('샤아 전용 자쿠를 HG로 리바이브 찾아줘');
      expect(q.concepts.map((c) => c.label), containsAll(['샤아', '자쿠', 'HG']));
      expect(q.words, ['리바이브']);
      expect(parseSentence('白いザクのMG').concepts.map((c) => c.label), containsAll(['흰색', '자쿠', 'MG']));
      expect(parseSentence('blue wing gundam').concepts.map((c) => c.label), containsAll(['파랑', '날개', '건담']));
    });

    test('일치도 · 맞은 낱말 · 채널 힌트(피카츄 → 포켓몬만)', () {
      final hits = sentenceSearch('샤아 전용 자쿠 HG', kits);
      expect(hits.first.kit.id, 'a');
      expect(hits.first.score, 100);
      expect(hits.first.matched, containsAll(['샤아', '자쿠', 'HG']));
      // 일본어 이름만 있는 상품도 한국어로
      expect(sentenceSearch('자쿠 MG', kits).first.kit.id, 'b');
      expect(sentenceSearch('수성의 마녀 에어리얼', kits).first.kit.id, 'c');
      final pika = sentenceSearch('피카츄 인형', kits);
      expect(pika.map((h) => h.kit.id), ['d']);
      expect(sentenceSearch('드래곤 베이', kits).first.kit.id, 'f');
      // 같은 점수면 굿즈는 뒤로
      final zaku = sentenceSearch('자쿠 우주', kits); // 셋 다 50%, 굿즈(e)가 발매일은 가장 늦어도 맨 뒤
      expect(zaku.last.kit.id, 'e');
    });

    test('낱말이 하나면(이름 검색) · 아무것도 안 맞으면 빈 목록', () {
      expect(sentenceSearch('자쿠', kits), isEmpty);
      expect(sentenceSearch('없는 말 투성이', kits), isEmpty);
      expect(sentenceSearch('건담 포켓몬', kits), isEmpty); // 채널만 맞은 것은 빼기
    });
  });

  group('바코드', () {
    test('정리 · JAN 이 같은 상품', () {
      expect(normalizeBarcode(' 4573102720030 '), '4573102720030');
      expect(normalizeBarcode('012345678905'), '0012345678905');
      expect(normalizeBarcode('49123456'), '49123456');
      expect(normalizeBarcode('abc'), '');
      final kits = [kit('x', jan: '4573102720030'), kit('y')];
      expect(kitsWithBarcode(kits, '4573102720030').map((k) => k.id), ['x']);
      expect(kitsWithBarcode(kits, '4900000000000'), isEmpty);
    });

    testWidgets('모르는 바코드 → 없어요 패널 · 하나면 상세로', (tester) async {
      final found = kit('hg-1', name: 'HG 테스트 건담', jan: '4573102720030');
      final loaders = Loaders(
        kits: (_) async => [found],
        kitsByJan: (code) async => code == found.jan ? [found] : const [],
      );
      late ValueChanged<String> scan;
      await _pump(
        tester,
        BarcodeScanScreen(
          loaders: loaders,
          onGoSearch: () {},
          preview: (_, onCode) {
            scan = onCode;
            return const ColoredBox(color: Colors.black);
          },
        ),
        UserStore.memory(),
      );
      scan('4900000000000');
      await tester.pump();
      await tester.pump();
      expect(find.text('이 바코드의 상품이 아직 없어요'), findsOneWidget);
      await tester.tap(find.byTooltip('다시 찍기'));
      await tester.pump();
      expect(find.text('이 바코드의 상품이 아직 없어요'), findsNothing);
      scan('4573102720030');
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(find.byType(KitDetailScreen), findsOneWidget);
      expect(find.text('HG 테스트 건담'), findsWidgets);
    });
  });

  test('제보 주소: 공개 저장소 새 이슈 · kit_id · 무엇이 틀렸나', () {
    final k = kit('hg-9', name: 'HG 9', jan: '4573102720030');
    final u = dataIssueUri(kind: ReportKind.wrongInfo, kit: k, problem: '가격', detail: '¥2,970 이 맞아요');
    expect(u.toString(), startsWith('$dataIssueRepo?'));
    expect(u.queryParameters['title'], '[정보 오류] HG 9 — 가격');
    expect(u.queryParameters['body'], contains('kit_id: `hg-9`'));
    expect(u.queryParameters['body'], contains('¥2,970 이 맞아요'));
    final m = dataIssueUri(kind: ReportKind.missingKit, barcode: '4900000000000', problem: '상품이 없어요');
    expect(m.queryParameters['title'], '[없는 상품] 바코드 4900000000000 — 상품이 없어요');
    expect(reportChoices(ReportKind.guide), isNotEmpty);
  });

  test('중국어 화면에서도 국내 시세 검색 · 제보 제목은 한국어 이름 (없으면 일본어)', () {
    addTearDown(() => L10n.debugSet(AppLang.ko));
    L10n.debugSet(AppLang.zh);
    final k = kit(
      'goodsmile-fate-14196',
      name: '넨도로이드 프리텐더/오베론',
      nameJa: 'ねんどろいど プリテンダー/オベロン',
      nameZh: '粘土人 Pretender / 奥伯龙',
    );
    expect(k.name, '粘土人 Pretender / 奥伯龙');
    final q = marketSearchName(nameKo: k.nameKo, nameJa: k.nameJa);
    expect(q, '넨도로이드 프리텐더/오베론');
    expect(marketSearchUrl('번개장터', q), contains(Uri.encodeComponent('오베론')));
    expect(marketSearchName(nameKo: ' ', nameJa: 'ねんどろいど'), 'ねんどろいど');
    final u = dataIssueUri(kind: ReportKind.wrongInfo, kit: k, problem: '이름');
    expect(u.queryParameters['title'], '[정보 오류] 넨도로이드 프리텐더/오베론 — 이름');
    expect(u.queryParameters['body'], contains('- 중국어 이름: 粘土人 Pretender / 奥伯龙'));
  });

  test('같은 IP의 새 상품: 찾은 상품의 작품 · 새것부터 · 위에 보인 것 빼고 · 12개', () {
    final seed = [
      for (var i = 0; i < 15; i++)
        kit('s$i', seriesKey: 'seed', series: 'SEED', date: '2026-${(i % 12 + 1).toString().padLeft(2, '0')}'),
    ];
    final other = kit('w1', seriesKey: 'witch', series: '수성', date: '2027-01');
    final r = sameIpKits([seed[0]], [...seed, other], channelLabel: '건담');
    expect(r.label, 'SEED');
    expect(r.kits.length, 12);
    expect(r.kits.map((k) => k.id), isNot(contains('s0')));
    expect(r.kits.map((k) => k.id), isNot(contains('w1')));
    expect(r.kits.first.date, '2026-12');
    final none = sameIpKits(const [], [...seed, other], channelLabel: '건담');
    expect(none.label, '건담');
    expect(none.kits.first.id, 'w1');
  });

  test('새로 들어온 = 가장 늦은 날부터 7일', () {
    final kits = [
      kit('a', firstSeen: '2026-11-01'),
      kit('b', firstSeen: '2026-10-26'),
      kit('c', firstSeen: '2026-10-20'),
      kit('d'),
    ];
    expect(newThisWeek(kits).map((k) => k.id), ['a', 'b']);
  });

  group('좋아요한 상품 발매 알림', () {
    final now = DateTime.utc(2026, 11, 2, 3);
    NotifyConfig cfg(List<ReleaseDay> r, {bool on = true}) =>
        NotifyConfig(wanted: {for (final x in r) x.id}, releases: r, rules: {'release_soon': on});

    test('D-7(7–2일 전) · D-1 · 당일 · 지난 것 없음 · 이미 알린 것 빼기', () {
      final c = cfg(const [
        ReleaseDay(id: 'a', name: 'A', date: '2026-11-07'),
        ReleaseDay(id: 'b', name: 'B', date: '2026-11-03'),
        ReleaseDay(id: 'c', name: 'C', date: '2026-11-02'),
        ReleaseDay(id: 'd', name: 'D', date: '2026-11-20'),
        ReleaseDay(id: 'e', name: 'E', date: '2026-11-01'),
      ]);
      final rs = releaseRecords(c, const {}, now);
      expect(rs.map((r) => r.id), ['rel-a-2026-11-07-d7', 'rel-b-2026-11-03-d1', 'rel-c-2026-11-02-d0']);
      expect(rs.first.body, contains('D-5'));
      expect(rs[1].body, contains('내일 발매'));
      expect(rs.every((r) => r.wanted && r.channel == 'wanted'), isTrue);
      expect(releaseRecords(c, {'rel-a-2026-11-07-d7'}, now).length, 2);
      expect(releaseRecords(cfg(c.releases, on: false), const {}, now), isEmpty);
      // 좋아요를 뺀 상품은 알리지 않는다
      expect(releaseRecords(NotifyConfig(releases: c.releases), const {}, now), isEmpty);
      expect(NotifyState.isInboxId(rs.first.id), isTrue);
      // 휴대폰 알림 (좋아요 채널)
      expect(buildAlerts(rs).map((a) => a.channel).toSet(), {'wanted'});
    });

    test('확인 한 번(planCheck)에 들어가고 · 설정 파일에 남는다', () {
      final c = cfg(const [ReleaseDay(id: 'a', name: 'A', date: '2026-11-03', franchise: 'gundam')]);
      final plan = planCheck(config: c, state: NotifyState(), entries: const [], manifestSig: '', now: now);
      expect(plan.records.map((r) => r.id), ['rel-a-2026-11-03-d1']);
      final again = NotifyConfig.fromJson(c.toJson());
      expect(again.releases.single.date, '2026-11-03');
      expect(notifyInterestRules, contains('release_soon'));
      expect(notifyRuleLabels['release_soon'], isNotEmpty);
    });

    test('좋아요한 상품 중 하루까지 정해진 발매일만', () {
      final byId = {
        'a': kit('a', date: '2026-11-10'),
        'b': kit('b', date: '2026-12'),
        'c': kit('c', date: '2026-10-01'),
      };
      expect(releaseDaysFor(['a', 'b', 'c', 'zz'], byId, now).map((r) => r.id), ['a']);
    });
  });

  testWidgets('검색: 최근 검색어는 기기 기록 · × 로 지우기', (tester) async {
    final me = UserStore.memory()
      ..addRecentSearch('엑시아')
      ..addRecentSearch('엑시아')
      ..addRecentSearch('사자비');
    await _pump(
      tester,
      Scaffold(
        body: SearchScreen(
          myChannels: const ['gundam'],
          onMyChannelsChanged: (_) {},
          onCamera: () {},
          loaders: fakeLoaders,
        ),
      ),
      me,
    );
    await tester.tap(find.byType(TextField).first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('사자비'), findsOneWidget);
    expect(find.text('자주 찾은'), findsOneWidget);
    expect(find.text('×2'), findsOneWidget);
    expect(find.text('설명으로 찾기'), findsOneWidget);
    expect(find.textContaining('AI'), findsNothing);
    await tester.tap(find.descendant(of: find.widgetWithText(InputChip, '사자비'), matching: find.byIcon(Icons.close)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(me.recentSearches, ['엑시아']);
  });

  testWidgets('상세: 좋아요면 수량 − n + (기기 기록)', (tester) async {
    final k = kit('q1', name: '수량 테스트');
    final me = UserStore.memory()..setStatus('q1', CollectStatus.wanted);
    await _pump(
      tester,
      KitDetailScreen(
        kit: k,
        loaders: Loaders(kits: (_) async => [k]),
      ),
      me,
    );
    expect(find.text('갖고 싶은 수'), findsOneWidget);
    await tester.tap(find.byTooltip('하나 더'));
    await tester.pump();
    expect(me.quantityOf('q1'), 2);
    expect(find.text('2'), findsOneWidget);
    expect(find.textContaining('모은 시세 없음'), findsOneWidget);
  });

  testWidgets('도움말 화면', (tester) async {
    await _pump(tester, const HelpScreen(), UserStore.memory());
    expect(find.text('도감 칸'), findsOneWidget);
    expect(find.text('내 사진'), findsOneWidget);
  });
}
