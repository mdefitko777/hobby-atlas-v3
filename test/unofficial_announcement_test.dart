// 비공식 소식(일본 취미 매체 · 팬 사이트가 전한 예고, announcements.json 의 unofficial: true) —
// 읽기 · 꼬리표 글과 색 · 줄 제목 · 예고 목록 탭 · 홈 · 캘린더 · 예고 상세 · 알림 제목 (한국어 · 중국어).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/api.dart';
import 'package:hobby_atlas/clock.dart';
import 'package:hobby_atlas/data/derive.dart';
import 'package:hobby_atlas/data/user_store.dart';
import 'package:hobby_atlas/detail_pane.dart';
import 'package:hobby_atlas/l10n/l10n.dart';
import 'package:hobby_atlas/l10n/zh_text.dart';
import 'package:hobby_atlas/logic/announcement_match.dart';
import 'package:hobby_atlas/logic/live_stream.dart';
import 'package:hobby_atlas/marks.dart';
import 'package:hobby_atlas/models.dart';
import 'package:hobby_atlas/notifications/feed_rules.dart';
import 'package:hobby_atlas/notifications/notify_models.dart';
import 'package:hobby_atlas/notifications/notify_store.dart';
import 'package:hobby_atlas/screens/a_home_screen.dart';
import 'package:hobby_atlas/screens/h_calendar_screen.dart';
import 'package:hobby_atlas/screens/j_announcement_screen.dart';
import 'package:hobby_atlas/screens/o_see_all_screen.dart';
import 'package:hobby_atlas/theme.dart';
import 'package:hobby_atlas/widgets.dart';

import 'layout_test.dart' show fakeLoaders;

final _hangul = RegExp(r'[가-힣]');

Announcement _ann(
  String id, {
  String status = '공식 발표',
  bool unofficial = false,
  bool hero = false,
  String date = '2026-10-20',
  DateTime? at,
  String state = '',
  String? title,
}) => Announcement(
  id: id,
  franchiseId: 'gundam',
  title: title ?? id,
  status: status,
  date: date,
  source: unofficial ? '電撃ホビーウェブ' : 'BANDAI HOBBY SITE',
  image: '',
  hero: hero,
  liveAt: at,
  liveState: state,
  unofficial: unofficial,
);

/// Gunpula data/announcements.json 한 줄 모양 (2026-11-13) + 비공식 표시
Map<String, Object?> _row(String id, {String status = 'announced', Object? unofficial}) => {
  'id': id,
  'franchise': 'gundam',
  'names': {'ja': 'HG 新商品', 'zh': null, 'ko': null},
  'status': status,
  'announced_at': '2026-11-13',
  'source_type': 'news',
  'source_name': '電撃ホビーウェブ',
  'source_url': 'https://hobby.dengeki.com/news/1/',
  'thumbnail_url': null,
  'video_id': null,
  'unofficial': ?unofficial,
};

Future<void> _pump(WidgetTester tester, Widget home, {NotifyStore? notify, Size size = const Size(390, 844)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildGpTheme(),
      builder: (context, child) => NotifyScope(
        store: notify ?? NotifyStore.memory(),
        child: MarksHost(
          store: UserStore.memory(),
          child: PaneHost(child: child!),
        ),
      ),
      home: home,
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  tearDown(() {
    fixedNow = null;
    L10n.debugSet(AppLang.ko);
  });

  group('읽기', () {
    test('unofficial: true 만 비공식 · 없거나 false 면 공식, 출처는 사이트 이름', () {
      final a = announcementOf(_row('fan-1', unofficial: true));
      expect(a.unofficial, isTrue);
      expect(a.source, '電撃ホビーウェブ');
      expect(a.status, '공식 발표', reason: '단계 값은 그대로 — 보일 때만 「비공식」으로');
      expect(announcementOf(_row('news-1')).unofficial, isFalse);
      expect(announcementOf(_row('news-2', unofficial: false)).unofficial, isFalse);
      expect(announcementOf(_row('news-3', unofficial: 'true')).unofficial, isFalse, reason: '글자는 표시로 보지 않는다');
    });

    test('홈 배너로 올려도 표시가 남는다 · 화면 모델 JSON', () {
      expect(_ann('fan-1', unofficial: true).asHero().unofficial, isTrue);
      expect(_ann('news-1').asHero().unofficial, isFalse);
      final json = {'id': 'x', 'franchiseId': 'gundam', 'title': 't', 'status': '공식 발표'};
      expect(Announcement.fromJson({...json, 'unofficial': true})!.unofficial, isTrue);
      expect(Announcement.fromJson(json)!.unofficial, isFalse);
    });
  });

  group('꼬리표 글 · 줄 제목 · 탭', () {
    test('공식은 단계 그대로, 비공식은 「공식 발표」 자리에 「비공식」 · 뒤 단계는 단계를 남긴다', () {
      expect(annStageText('공식 발표'), '공식 발표');
      expect(annStageText('예약 시작'), '예약 시작');
      expect(annStageText('공식 발표', unofficial: true), '비공식');
      expect(annStageText('상품화 확정', unofficial: true), '비공식 · 상품화 확정');
      expect(annStageText('발매', unofficial: true), '비공식 · 발매');
    });

    test('모든 단계의 비공식 글이 중국어 번역 표에 있다', () {
      for (final s in announcementStages) {
        final ko = annStageText(s, unofficial: true);
        expect(zhText[ko], isNotNull, reason: ko);
        expect(zhText[ko], startsWith('非官方'));
      }
      expect(zhText['비공식 · 예약 시작'], '非官方 · 开始预订');
    });

    test('줄 제목: 공식뿐이면 「공식 예고」, 비공식이 섞였으면 「예고」', () {
      expect(annSectionTitle([_ann('a'), _ann('b')]), '공식 예고');
      expect(annSectionTitle([_ann('a'), _ann('f', unofficial: true)]), '예고');
      expect(annSectionTitle(const []), '공식 예고');
    });

    test('탭: 전체 · 공식 단계(나온 순서) · 비공식은 있을 때만 맨 끝 — 단계 탭에 비공식을 세지 않는다', () {
      final all = [
        _ann('f1', unofficial: true),
        _ann('a', status: '예약 시작'),
        _ann('b'),
        _ann('f2', status: '예약 시작', unofficial: true),
        _ann('c', status: '예약 시작'),
      ];
      expect(announcementTabs(all), [
        (tab: '', count: 5),
        (tab: '예약 시작', count: 2),
        (tab: '공식 발표', count: 1),
        (tab: unofficialLabel, count: 2),
      ]);
      expect(all.where((a) => inAnnTab(a, unofficialLabel)).map((a) => a.id), ['f1', 'f2']);
      expect(all.where((a) => inAnnTab(a, '예약 시작')).map((a) => a.id), ['a', 'c']);
      // 비공식이 없으면 탭도 없다
      expect(announcementTabs([_ann('a'), _ann('b')]).map((t) => t.tab), ['', '공식 발표']);
    });
  });

  group('알림 받는 예고 — 비공식도 같은 규칙, 제목만 「비공식」', () {
    final now = DateTime.utc(2026, 11, 13, 9);
    NotifyConfig config(Map<String, String> stages) => NotifyConfig(
      followed: {
        for (final e in stages.entries) e.key: FollowedAnn(stage: e.value, title: 'HG 新商品', franchise: 'gundam'),
      },
    );
    Map<String, Object?> file(List<Map<String, Object?>> rows) => {'announcements': rows};

    test('둘째 줄 · 휴대폰 알림 제목이 「비공식」으로 시작 (한국어 · 중국어), 공식은 그대로', () {
      final rs = annStageRecords(
        config({'fan-1': 'announced', 'fan-2': 'product_confirmed', 'news-1': 'announced'}),
        file([
          _row('fan-1', status: 'preorder_open', unofficial: true),
          _row('fan-2', status: 'preorder_open', unofficial: true),
          _row('news-1', status: 'preorder_open'),
        ]),
        {},
        now,
      );
      final byId = {for (final r in rs) r.annId: r};
      expect(byId.keys, ['fan-1', 'fan-2', 'news-1']);
      expect(byId['fan-1']!.unofficial, isTrue);
      expect(byId['fan-1']!.reasons.first, 'preorder_open', reason: '단계는 첫 칸 그대로 (notify_store 가 읽는다)');
      expect(byId['fan-1']!.body, '비공식 → 예약 시작');
      expect(byId['fan-2']!.body, '비공식 · 상품화 확정 → 예약 시작');
      expect(byId['news-1']!.unofficial, isFalse);
      expect(byId['news-1']!.body, '공식 발표 → 예약 시작');

      final titles = {for (final a in buildAlerts(rs)) a.payload: a.title};
      expect(titles['ann:gundam:fan-1'], '비공식 · 예약 시작 · HG 新商品');
      expect(titles['ann:gundam:news-1'], '예약 시작 · HG 新商品');
      // 저장했다 다시 읽어도 비공식
      expect(NoticeRecord.fromJson(byId['fan-1']!.toJson())!.unofficial, isTrue);

      L10n.debugSet(AppLang.zh);
      expect(byId['fan-2']!.body, '非官方 · 确定商品化 → 开始预订');
      expect(buildAlerts([byId['fan-1']!]).single.title, '非官方 · 开始预订 · HG 新商品');
    });

    test('여럿을 묶은 알림: 공식뿐 · 비공식뿐 · 섞임', () {
      List<NoticeRecord> records(Set<String> unofficial) => annStageRecords(
        config({
          for (final id in ['a', 'b', 'c', 'd']) id: 'announced',
        }),
        file([
          for (final id in ['a', 'b', 'c', 'd'])
            _row(id, status: 'released', unofficial: unofficial.contains(id) ? true : null),
        ]),
        {},
        now,
      );
      expect(buildAlerts(records({})).single.title, '알림 받는 공식 예고 4개가 다음 단계로');
      expect(buildAlerts(records({'a', 'b', 'c', 'd'})).single.title, '알림 받는 비공식 예고 4개가 다음 단계로');
      expect(buildAlerts(records({'a'})).single.title, '알림 받는 예고 4개가 다음 단계로');
      L10n.debugSet(AppLang.zh);
      for (final set in [
        <String>{},
        {'a'},
        {'a', 'b', 'c', 'd'},
      ]) {
        expect(buildAlerts(records(set)).single.title, isNot(matches(_hangul)));
      }
    });
  });

  group('화면', () {
    const tag = ValueKey('unofficial-tag-fan-1');
    final anns = [
      _ann('fan-1', unofficial: true, hero: true),
      _ann('fan-2', status: '예약 시작', unofficial: true),
      _ann('news-1'),
      _ann('news-2', status: '예약 시작'),
    ];

    testWidgets('꼬리표: 호박색 「비공식」 · 뒤 단계는 「비공식 · 예약 시작」 · 사진 위는 「비공식」만 (한국어 · 중국어)', (tester) async {
      for (final lang in AppLang.values) {
        L10n.debugSet(lang);
        await _pump(
          tester,
          Scaffold(
            key: ValueKey(lang),
            body: Column(
              children: [
                AnnTag(anns[0]),
                AnnTag(anns[1]),
                AnnTag(anns[1], onPhoto: true),
                AnnTag(anns[2], key: const ValueKey('official')),
              ],
            ),
          ),
        );
        final soft = tester.widgetList<SoftTag>(find.byType(SoftTag)).toList();
        expect(soft.map((t) => t.text), [
          lang == AppLang.zh ? '非官方' : '비공식',
          lang == AppLang.zh ? '非官方 · 开始预订' : '비공식 · 예약 시작',
          lang == AppLang.zh ? '官方公告' : '공식 발표',
        ]);
        expect(soft.map((t) => t.color), [unofficialColor, unofficialColor, stageColor('공식 발표')]);
        expect(unofficialColor, isNot(stageColor('공식 발표')), reason: '공식 발표(회색)와 다른 색');
        final pill = tester.widget<TagPill>(find.byType(TagPill));
        expect(pill.text, lang == AppLang.zh ? '非官方' : '비공식');
        expect(pill.filled, isTrue);
      }
    });

    testWidgets('비공식이 전한 라이브: 때 앞에 「비공식」', (tester) async {
      fixedNow = DateTime(2026, 10, 25, 21);
      final live = _ann('fan-live', unofficial: true, at: DateTime(2026, 10, 26, 21), state: 'upcoming');
      await _pump(tester, Scaffold(body: AnnTag(live)));
      expect(tester.widget<SoftTag>(find.byType(SoftTag)).text, '비공식 · 라이브 · 내일 21:00');
    });

    testWidgets('예고 목록: 「비공식 n」 탭은 있을 때만 · 누르면 비공식만 · 단계 탭은 공식만', (tester) async {
      const unofficialTab = ValueKey('ann-tab-$unofficialLabel');
      await _pump(
        tester,
        Scaffold(
          body: SectionListView(title: '예고', announcements: anns, loaders: const Loaders()),
        ),
      );
      List<String> shown() => [
        for (final t in tester.widgetList<AnnTag>(find.byType(AnnTag, skipOffstage: false))) t.item.id,
      ];
      expect(tester.widget<UnderlineTab>(find.byKey(unofficialTab)).count, 2);
      expect(tester.widget<UnderlineTab>(find.byKey(const ValueKey('ann-tab-'))).count, 4);
      expect(tester.widget<UnderlineTab>(find.byKey(const ValueKey('ann-tab-예약 시작'))).count, 1);
      expect(shown(), ['fan-1', 'fan-2', 'news-1', 'news-2']);
      expect(tester.widget<SoftTag>(find.byKey(tag)).color, unofficialColor);

      await tester.tap(find.byKey(unofficialTab));
      await tester.pump();
      expect(shown(), ['fan-1', 'fan-2']);
      await tester.tap(find.byKey(const ValueKey('ann-tab-예약 시작')));
      await tester.pump();
      expect(shown(), ['news-2']);
      expect(tester.takeException(), isNull);

      // 공식뿐인 목록에는 탭이 없다
      await _pump(
        tester,
        Scaffold(
          key: const ValueKey('official-only'),
          body: SectionListView(title: '공식 예고', announcements: [anns[2], anns[3]], loaders: const Loaders()),
        ),
      );
      expect(find.byKey(unofficialTab), findsNothing);
      expect(find.byType(UnderlineTab), findsNWidgets(3)); // 전체 · 공식 발표 · 예약 시작
    });

    testWidgets('홈: 배너 꼬리표 · 예고 줄 사진 위 「비공식」 (한국어 · 중국어)', (tester) async {
      fixedNow = DateTime(2026, 10, 25, 21);
      final loaders = Loaders(kits: fakeLoaders.kits, announcements: (_) async => anns);
      for (final lang in AppLang.values) {
        L10n.debugSet(lang);
        await _pump(
          tester,
          Scaffold(
            key: ValueKey(lang),
            body: HomeScreen(
              myChannels: const ['gundam'],
              onMyChannelsChanged: (_) {},
              onOpenSearch: () {},
              onCamera: () {},
              loaders: loaders,
            ),
          ),
        );
        // 배너 (fan-1 만 hero)
        final banner = tester.widget<SoftTag>(find.byKey(tag).first);
        expect(banner.text, lang == AppLang.zh ? '非官方' : '비공식');
        expect(banner.color, unofficialColor);
        // 예고 줄: 비공식 둘만 사진 위 알약 (공식 예고는 사진 + 이름만)
        await tester.scrollUntilVisible(find.byType(TagPill).first, 300, scrollable: find.byType(Scrollable).first);
        final pills = tester.widgetList<TagPill>(find.byType(TagPill)).toList();
        expect(pills.map((p) => p.text).toSet(), {lang == AppLang.zh ? '非官方' : '비공식'});
        expect(pills.every((p) => p.filled), isTrue);
        // 줄 제목: 비공식이 섞였으니 「공식 예고」가 아니라 「예고」
        expect(find.text(tr('예고')), findsOneWidget);
        expect(find.text(tr('공식 예고')), findsNothing);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('캘린더: 비공식 줄은 호박색 꼬리표 · 공식 줄은 그대로', (tester) async {
      fixedNow = DateTime(2026, 10, 25, 21);
      final loaders = Loaders(kits: (_) async => const [], announcements: (_) async => anns);
      for (final lang in AppLang.values) {
        L10n.debugSet(lang);
        await _pump(
          tester,
          Scaffold(
            key: ValueKey(lang),
            body: CalendarScreen(myChannels: const ['gundam'], onMyChannelsChanged: (_) {}, loaders: loaders),
          ),
        );
        final rows = {for (final r in tester.widgetList<ThumbRow>(find.byType(ThumbRow, skipOffstage: false))) r.id: r};
        expect(rows['fan-1']!.tag, lang == AppLang.zh ? '非官方' : '비공식');
        expect(rows['fan-1']!.tagColor, unofficialColor);
        expect(rows['fan-2']!.tag, lang == AppLang.zh ? '非官方 · 开始预订' : '비공식 · 예약 시작');
        expect(rows['news-1']!.tag, lang == AppLang.zh ? '官方公告' : '공식 발표');
        expect(rows['news-1']!.tagColor, isNull);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('예고 상세: 위 띠 꼬리표 · 안내 한 줄 · 단계 줄 첫 칸이 「비공식」 — 공식 예고에는 없다', (tester) async {
      const note = ValueKey('unofficial-note');
      for (final lang in AppLang.values) {
        L10n.debugSet(lang);
        await _pump(tester, AnnouncementScreen(key: ValueKey(lang), item: anns[0], loaders: const Loaders()));
        expect(articleViewSupported, isFalse); // 위젯 테스트에는 웹 보기가 없다 → 요약 화면
        expect(tester.widget<SoftTag>(find.byKey(tag)).color, unofficialColor);
        expect(find.byKey(note), findsOneWidget);
        final word = lang == AppLang.zh ? '非官方' : '비공식';
        expect(find.text(word), findsNWidgets(2)); // 위 띠 꼬리표 + 단계 줄 첫 칸
        expect(find.text(lang == AppLang.zh ? '官方公告' : '공식 발표'), findsNothing);
        if (lang == AppLang.zh) {
          final text = tester.widget<Text>(find.descendant(of: find.byKey(note), matching: find.byType(Text)));
          expect(text.data, isNot(matches(_hangul)));
        }
        expect(tester.takeException(), isNull);
      }
      L10n.debugSet(AppLang.ko);
      await _pump(tester, AnnouncementScreen(key: const ValueKey('official'), item: anns[2], loaders: const Loaders()));
      expect(find.byKey(note), findsNothing);
      expect(find.text('공식 발표'), findsNWidgets(2));
    });

    testWidgets('공식뿐인 홈은 그대로: 줄 제목 「공식 예고」 · 사진 위 알약 없음 · 호박색 꼬리표 없음', (tester) async {
      fixedNow = DateTime(2026, 10, 25, 21);
      final official = [_ann('news-1', hero: true), _ann('news-2', status: '예약 시작')];
      for (final lang in AppLang.values) {
        L10n.debugSet(lang);
        await _pump(
          tester,
          Scaffold(
            key: ValueKey(lang),
            body: HomeScreen(
              myChannels: const ['gundam'],
              onMyChannelsChanged: (_) {},
              onOpenSearch: () {},
              onCamera: () {},
              loaders: Loaders(kits: fakeLoaders.kits, announcements: (_) async => official),
            ),
          ),
        );
        final banner = tester.widget<SoftTag>(
          find.descendant(of: find.byType(AnnTag).first, matching: find.byType(SoftTag)),
        );
        expect(banner.color, stageColor('공식 발표'));
        await tester.scrollUntilVisible(find.text(tr('공식 예고')), 300, scrollable: find.byType(Scrollable).first);
        expect(find.text(tr('예고')), findsNothing);
        expect(find.byType(TagPill, skipOffstage: false), findsNothing);
        expect(
          tester
              .widgetList<SoftTag>(find.byType(SoftTag, skipOffstage: false))
              .where((t) => t.color == unofficialColor),
          isEmpty,
        );
        expect(tester.takeException(), isNull);
      }
    });

    // 가장 긴 꼬리표(「비공식 · 상품화 확정」 · 비공식이 전한 라이브 「비공식 · 라이브 · 10.28 21:00」) + 긴 제목 · 출처가
    // 360dp 폰의 한 줄(꼬리표 · 날짜 · 출처)에서 넘치지 않는다 — 넘치면 RenderFlex 오류가 takeException 에 잡힌다
    group('좁은 화면 360dp', () {
      const narrow = Size(360, 640);
      const longTitle = 'BX-55 ランダムブースターVol.12「ホルスシャッター3-85MO」 2026年12月26日発売';
      const longTag = ValueKey('unofficial-tag-fan-long');
      const liveTag = ValueKey('live-tag-fan-live');
      final long = [
        _ann('fan-long', status: '상품화 확정', unofficial: true, hero: true, date: '2026-10-30', title: longTitle),
        _ann(
          'fan-live',
          unofficial: true,
          hero: true,
          at: DateTime(2026, 10, 28, 21),
          state: 'upcoming',
          title: longTitle,
        ),
        _ann('news-1', hero: true, title: longTitle),
      ];

      /// 꼬리표가 화면 안에 통째로 있다
      void expectInside(WidgetTester tester, Finder tag) {
        final r = tester.getRect(tag);
        expect(r.left, greaterThanOrEqualTo(0), reason: '$tag');
        expect(r.right, lessThanOrEqualTo(narrow.width), reason: '$tag');
      }

      testWidgets('예고 목록 카드 · 예고 상세 위 띠 (한국어 · 중국어)', (tester) async {
        fixedNow = DateTime(2026, 10, 25, 21);
        for (final lang in AppLang.values) {
          L10n.debugSet(lang);
          await _pump(
            tester,
            Scaffold(
              key: ValueKey(lang),
              body: SectionListView(title: '예고', announcements: long, loaders: const Loaders()),
            ),
            size: narrow,
          );
          expect(tester.takeException(), isNull);
          expectInside(tester, find.byKey(longTag));
          expectInside(tester, find.byKey(liveTag));
          expect(tester.widget<SoftTag>(find.byKey(longTag)).text, lang == AppLang.zh ? '非官方 · 确定商品化' : '비공식 · 상품화 확정');

          for (final a in long.take(2)) {
            await _pump(
              tester,
              AnnouncementScreen(key: ValueKey('$lang-${a.id}'), item: a, loaders: const Loaders()),
              size: narrow,
            );
            expect(tester.takeException(), isNull, reason: '$lang ${a.id}');
            expectInside(tester, find.byKey(a.isStream ? liveTag : longTag));
          }
        }
      });

      testWidgets('홈 배너 · 예고 줄 (한국어 · 중국어)', (tester) async {
        fixedNow = DateTime(2026, 10, 25, 21);
        final loaders = Loaders(kits: fakeLoaders.kits, announcements: (_) async => long);
        for (final lang in AppLang.values) {
          L10n.debugSet(lang);
          await _pump(
            tester,
            Scaffold(
              key: ValueKey(lang),
              body: HomeScreen(
                myChannels: const ['gundam'],
                onMyChannelsChanged: (_) {},
                onOpenSearch: () {},
                onCamera: () {},
                loaders: loaders,
              ),
            ),
            size: narrow,
          );
          expect(tester.takeException(), isNull);
          expectInside(tester, find.byKey(longTag).first); // 배너 첫 장
          await tester.scrollUntilVisible(find.byType(TagPill).first, 300, scrollable: find.byType(Scrollable).first);
          expect(tester.takeException(), isNull);
        }
      });

      testWidgets('캘린더 줄 — 비공식이 전한 라이브는 「21:00 비공식 · 라이브」 (색은 라이브 단계)', (tester) async {
        fixedNow = DateTime(2026, 10, 25, 21);
        final loaders = Loaders(kits: (_) async => const [], announcements: (_) async => long);
        for (final lang in AppLang.values) {
          L10n.debugSet(lang);
          await _pump(
            tester,
            Scaffold(
              key: ValueKey(lang),
              body: CalendarScreen(myChannels: const ['gundam'], onMyChannelsChanged: (_) {}, loaders: loaders),
            ),
            size: narrow,
          );
          expect(tester.takeException(), isNull);
          final rows = {
            for (final r in tester.widgetList<ThumbRow>(find.byType(ThumbRow, skipOffstage: false))) r.id: r,
          };
          expect(rows['fan-long']!.tag, lang == AppLang.zh ? '非官方 · 确定商品化' : '비공식 · 상품화 확정');
          expect(rows['fan-live']!.tag, lang == AppLang.zh ? '21:00 非官方 · 直播' : '21:00 비공식 · 라이브');
          expect(rows['fan-live']!.tagColor, liveColor(LiveStage.upcoming));
        }
      });
    });
  });
}
