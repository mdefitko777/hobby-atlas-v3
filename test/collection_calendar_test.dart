// 컬렉션 줄 부제(같은 말 한 번 · 건담은 도감 공식 작품 이름) · 목록 맨 끝 합계(₩ · ¥ 따로) ·
// 캘린더 한 주 ↔ 한 달 손잡이 · 한 주 줄은 늘 위에 · 뜻마다 다른 점 색 + 발매(꽉 참) · 예고(속 빔) 모양 (2026-11-22 주인)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/api.dart';
import 'package:hobby_atlas/clock.dart';
import 'package:hobby_atlas/data/user_store.dart';
import 'package:hobby_atlas/detail_pane.dart';
import 'package:hobby_atlas/logic/kit_meta.dart';
import 'package:hobby_atlas/logic/preorder.dart';
import 'package:hobby_atlas/logic/restock.dart';
import 'package:hobby_atlas/marks.dart';
import 'package:hobby_atlas/models.dart';
import 'package:hobby_atlas/screens/f_collection_screen.dart';
import 'package:hobby_atlas/screens/h_calendar_screen.dart';
import 'package:hobby_atlas/theme.dart';

Kit _kit(
  String id, {
  String ch = 'gundam',
  String line = 'HG',
  String series = '',
  int? krw,
  int? jpy,
  String date = '',
  String pbCloses = '',
}) => Kit.fromSlim(
  {
    'id': id,
    'franchiseId': ch,
    'name': 'name-$id',
    'line': line,
    'series': series,
    'date': date,
    'pbCloses': pbCloses,
    'priceKrw': ?krw,
    'priceJpy': ?jpy,
  },
  recentSince: '',
  monthPrefix: '',
);

GuideUnit _unit(String id, String work, List<String> kits) =>
    GuideUnit(id: id, workId: work, name: id, nameEn: id, image: '', status: CollectStatus.none, kitIds: kits);

GuideWork _work(String id, String name) => GuideWork(id: id, section: '', name: name, image: '', total: 0, owned: 0);

Future<void> _pump(WidgetTester tester, UserStore store, Widget home) async {
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
      home: Scaffold(body: home),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  fixedNow = DateTime(2026, 10, 25, 21);

  group('kitMetaLine · kitWorkName', () {
    test('채널 · 라인 · 작품에서 같은 말은 한 번 (포켓몬 · 봉제인형 · 포켓몬 ✗)', () {
      final k = _kit('p1', ch: 'pokemon', line: '봉제인형', series: '포켓몬');
      expect(kitMetaLine(k), '포켓몬 · 봉제인형');
      expect(kitMetaLine(k, channel: false), '봉제인형');
      // 띄어쓰기 · 대소문자만 다른 것도 같은 말
      expect(kitMetaLine(_kit('l1', ch: 'lego', line: '굿즈', series: '굿즈'), channel: false), '굿즈');
    });

    test('건담 작품은 도감의 공식 이름(반복 머리 없이), 대표 기체를 모르면 series 이름', () {
      final index = GuideIndex(
        works: [_work('cca', '기동전사 건담 역습의 샤아')],
        units: {
          'nu': _unit('nu', 'cca', ['g1']),
        },
        unitsByKit: {
          'g1': ['nu'],
        },
      );
      expect(kitWorkName(_kit('g1', series: '역샤아'), index), '역습의 샤아');
      expect(kitWorkName(_kit('g2', series: '역샤아'), index), '역샤아');
      expect(kitWorkName(_kit('p1', ch: 'pokemon', series: '포켓몬'), index), '포켓몬');
      expect(kitMetaLine(_kit('g1', series: '역샤아'), work: kitWorkName(_kit('g1'), index)), '건담 · HG · 역습의 샤아');
    });
  });

  testWidgets('컬렉션 좋아요: 탭에 수 없음 · 맨 끝 합계에 상품 수 · 정가 합계 ₩ 와 ¥ 따로 (환산 없음)', (tester) async {
    final kits = [_kit('a', krw: 19000), _kit('b', jpy: 1650), _kit('c', krw: 1000)];
    final store = UserStore.memory();
    for (final k in kits) {
      store.setStatus(k.id, CollectStatus.wanted);
    }
    await _pump(
      tester,
      store,
      CollectionScreen(
        myChannels: const ['gundam'],
        onMyChannelsChanged: (_) {},
        onGoSearch: () {},
        loaders: Loaders(kits: (_) async => kits, guideIndex: () async => GuideIndex.empty),
      ),
    );
    final sum = find.byKey(const ValueKey('list-summary'));
    await tester.scrollUntilVisible(sum, 200, scrollable: find.byType(Scrollable).first);
    expect(find.descendant(of: sum, matching: find.text('3')), findsOneWidget);
    expect(find.descendant(of: sum, matching: find.text('₩20,000')), findsOneWidget);
    expect(find.descendant(of: sum, matching: find.text('¥1,650')), findsOneWidget);
    expect(find.textContaining('≈'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  group('캘린더', () {
    Future<void> pumpCalendar(
      WidgetTester tester,
      UserStore store,
      List<Kit> kits,
      List<Announcement> anns, {
      RestockIndex restocks = RestockIndex.empty,
    }) => _pump(
      tester,
      store,
      CalendarScreen(
        myChannels: const ['gundam'],
        onMyChannelsChanged: (_) {},
        loaders: Loaders(kits: (_) async => kits, announcements: (_) async => anns, restocks: () async => restocks),
      ),
    );

    /// 뜻마다 다른 점 색 (lib/screens/h_calendar_screen.dart `_Mark`) — 밤 모드 때문에 getter 라 const 가 아니다
    Set<Color> markColors() => {Gp.accent, Gp.danger, Gp.reserve, Gp.resale, Gp.own, Gp.muted};

    /// 달력 격자 [day] 칸 아래 점들 — (색, 속 빔). 꽉 찬 점은 칠한 색, 속 빈 동그라미는 테두리 색으로 읽는다
    /// (고른 날 옅은 동그라미 · 오늘 테두리는 `_Mark` 색이 아니라 걸러진다)
    Iterable<(Color, bool)> dotsOn(WidgetTester tester, String day) => tester
        .widgetList<Container>(
          find.descendant(
            of: find.ancestor(of: find.text(day), matching: find.byType(GestureDetector)).first,
            matching: find.byType(Container),
          ),
        )
        .map((c) => c.decoration as BoxDecoration?)
        .map((d) => (d?.color ?? (d?.border as Border?)?.top.color, d?.color == null))
        .where((e) => markColors().contains(e.$1))
        .map((e) => (e.$1!, e.$2));

    // 점 색이 낮 값으로 얼어붙으면(`static final` 함정) 밤에 안 보인다 — 두 벌을 각각 읽어 견준다
    test('점 색 여섯은 낮 · 밤 두 벌에서 서로 다르고, 밤 바탕에서 보인다 (얼어붙음 없음)', () {
      addTearDown(() => GpMode.debugSet(false));
      // 모양 줄(속 빈 동그라미 = 예고)은 색이 회색과 같은 한 벌이라 색 세는 데서 뺀다
      List<Color> dotColors() => [
        for (final h in calendarHelp)
          if (h.dot && !h.hollow) h.color!,
      ];
      double ratio(Color a, Color b) {
        final (x, y) = (a.computeLuminance(), b.computeLuminance());
        return ((x > y ? x : y) + 0.05) / ((x < y ? x : y) + 0.05);
      }

      GpMode.debugSet(false);
      final day = dotColors();
      GpMode.debugSet(true);
      final night = dotColors();
      expect(day, hasLength(6));
      expect(day.toSet(), hasLength(6), reason: '낮에 두 뜻이 같은 색이면 구분이 없어진다');
      expect(night.toSet(), hasLength(6), reason: '밤에 두 뜻이 같은 색이면 구분이 없어진다');
      for (final (i, c) in night.indexed) {
        expect(c, isNot(day[i]), reason: '$i 번째 점이 낮 색으로 얼어붙었다');
        // 글자가 아닌 그림 요소 기준 3:1 (WCAG AA)
        expect(ratio(c, Gp.bg), greaterThanOrEqualTo(3.0), reason: '$i 번째 점이 밤 바탕에서 안 보인다');
      }
      // 모양 줄은 새 색을 들이지 않는다 — 속 빈 동그라미도 그 밖(회색) 한 벌 (2026-11-22 주인: 색은 그대로)
      expect(
        [
          for (final h in calendarHelp)
            if (h.dot && h.hollow) h.color,
        ],
        [Gp.muted],
      );
    });

    testWidgets('처음은 오늘이 든 한 주 · ‹ › 는 주 · 손잡이를 밀어 내리면 한 달, 올리면 다시 한 주', (tester) async {
      final store = UserStore.memory();
      await pumpCalendar(tester, store, const [], const []);
      expect(find.text('25'), findsOneWidget);
      expect(find.text('18'), findsNothing);
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('18'), findsOneWidget); // 앞 주 18–24
      expect(find.text('25'), findsNothing);

      final handle = find.byKey(const ValueKey('month-handle'));
      await tester.drag(handle, const Offset(0, 300));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('1'), findsOneWidget);
      expect(find.text('31'), findsOneWidget);
      expect(store.toJson()['local_state'], containsPair('calendar_month_open', true)); // 펴 둔 것을 기기에 기억
      await tester.drag(handle, const Offset(0, -300));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('1'), findsNothing);
      expect(find.text('18'), findsOneWidget); // 접으면 보던 주
      expect(store.toJson()['local_state'], isNot(contains('calendar_month_open'))); // 처음 값(한 주)은 적지 않는다
      expect(tester.takeException(), isNull);
    });

    testWidgets('한 달로 펴 둔 기기는 다시 열어도 한 달', (tester) async {
      final store = UserStore.memory()..setCalendarMonthOpen(true);
      await pumpCalendar(tester, store, const [], const []);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('31'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('점: 내 좋아요 = 파랑 · 그 밖 = 회색, 예고는 같은 회색 속 빈 동그라미 · 상태는 알약 없이 둘째 줄', (tester) async {
      final liked = _kit('liked', date: '2026-10-27');
      final other = _kit('other', date: '2026-10-28');
      final store = UserStore.memory()..setStatus(liked.id, CollectStatus.wanted);
      const ann = Announcement(
        id: 'ann',
        franchiseId: 'gundam',
        title: 'ann',
        status: '공식 발표',
        date: '2026-10-29',
        source: '',
        image: '',
        hero: false,
      );
      await pumpCalendar(tester, store, [liked, other], [ann]);
      expect(find.byKey(const ValueKey('event-dot-mine'), skipOffstage: false), findsOneWidget);
      // 발매 줄은 꽉 찬 점, 예고 줄은 같은 회색 속 빈 동그라미 (2026-11-22 주인: 색이 아니라 모양으로)
      expect(find.byKey(const ValueKey('event-dot-other'), skipOffstage: false), findsOneWidget);
      final annRow = find.byKey(const ValueKey('event-ann'), skipOffstage: false);
      expect(
        find.descendant(of: annRow, matching: find.byKey(const ValueKey('event-dot-other-hollow'))),
        findsOneWidget,
      );
      // 달력 칸 점: 27일 파랑(꽉 참), 28일 회색(꽉 참 — 내 것 아닌 발매), 29일 회색 속 빔(예고)
      expect(dotsOn(tester, '27'), [(Gp.accent, false)]);
      expect(dotsOn(tester, '28'), [(Gp.muted, false)]);
      expect(dotsOn(tester, '29'), [(Gp.muted, true)]);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('calendar-card')),
          matching: find.byKey(const ValueKey('day-dot-other-hollow')),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    // 2026-11-22 주인: 격자 점도 종류 탭을 따라간다. 그때까지 거르기는 아래 목록에만 걸려 있어서,
    // 「예고」를 열면 목록은 예고뿐인데 격자에는 발매 점이 그대로 남아 있었다 (H-3b `_inKind`).
    testWidgets('격자 점이 전체 · 발매 · 예고 탭을 따라간다', (tester) async {
      final liked = _kit('liked', date: '2026-10-27');
      final store = UserStore.memory()..setStatus(liked.id, CollectStatus.wanted);
      const ann = Announcement(
        id: 'ann',
        franchiseId: 'gundam',
        title: 'ann',
        status: '공식 발표',
        date: '2026-10-29',
        source: '',
        image: '',
        hero: false,
      );
      await pumpCalendar(tester, store, [liked], [ann]);

      Future<void> openKind(int i) async {
        // 종류 탭만 집는다 — 줄의 "발매" · "예고" 상태 글자와 겹치지 않게
        final tab = find.byKey(ValueKey('kind-$i'));
        expect(tab, findsOneWidget, reason: '종류 탭 $i 이 한 벌만 있어야 한다 (두 겹으로 그려지면 둘)');
        await tester.tap(tab);
        await tester.pump(const Duration(milliseconds: 400));
      }

      expect(dotsOn(tester, '27'), [(Gp.accent, false)]);
      expect(dotsOn(tester, '29'), [(Gp.muted, true)]);

      await openKind(2);
      expect(dotsOn(tester, '27'), isEmpty, reason: '「예고」를 열었는데 격자에 발매 점이 남았다');
      expect(dotsOn(tester, '29'), [(Gp.muted, true)]);

      await openKind(1);
      expect(dotsOn(tester, '27'), [(Gp.accent, false)]);
      expect(dotsOn(tester, '29'), isEmpty, reason: '「발매」를 열었는데 격자에 예고 점이 남았다');

      await openKind(0);
      expect(dotsOn(tester, '27'), [(Gp.accent, false)]);
      expect(dotsOn(tester, '29'), [(Gp.muted, true)]);
      expect(tester.takeException(), isNull);
    });

    // 모양 축이 생겨 같은 회색이 꽉 참 · 속 빔으로 갈린다 — 셋까지인 자리를 같은 색 둘로 낭비하지 않는다
    testWidgets('한 날에 겹치면 뜻마다 한 점씩 먼저 (내 발매 · 그 밖의 발매 · 예고 = 세 점)', (tester) async {
      final liked = _kit('liked', date: '2026-10-26');
      final other = _kit('other', date: '2026-10-26');
      final store = UserStore.memory()..setStatus(liked.id, CollectStatus.wanted);
      const ann = Announcement(
        id: 'ann',
        franchiseId: 'gundam',
        title: 'ann',
        status: '공식 발표',
        date: '2026-10-26',
        source: '',
        image: '',
        hero: false,
      );
      await pumpCalendar(tester, store, [liked, other], [ann]);
      expect(dotsOn(tester, '26'), [(Gp.accent, false), (Gp.muted, false), (Gp.muted, true)]);
      expect(tester.takeException(), isNull);
    });

    // 셋까지 자르는 자리를 같은 색이 두 번 쓰지 않는다 — 네 뜻이 한 날에 겹치면 앞의 세 뜻(_Mark 순서)만
    testWidgets('한 날에 네 뜻이 겹치면 앞의 세 뜻만 (내 발매 · PB 마감 · 예약 도착, 재판매는 밀린다)', (tester) async {
      final k = _kit('all', date: '2026-10-28', pbCloses: '2026-10-28');
      final store = UserStore.memory()
        ..setStatus(k.id, CollectStatus.wanted)
        ..putPreorder(k.id, const Preorder(shop: '샵', arrival: '2026-10-28'));
      await pumpCalendar(
        tester,
        store,
        [k],
        const [],
        restocks: RestockIndex({
          'all': [RestockEvent(kitId: 'all', date: '2026-10-28')],
        }),
      );
      await tester.tap(find.byKey(const ValueKey('calendar-scope-1'))); // 내 일정
      await tester.pumpAndSettle();
      expect(dotsOn(tester, '28'), [(Gp.accent, false), (Gp.danger, false), (Gp.reserve, false)]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('내 일정 점 색은 뜻마다 다르다: 예약 도착 · 재판매 · 구매한 날 · PB 마감 (2026-11-22 주인)', (tester) async {
      final pre = _kit('pre');
      final res = _kit('res');
      final pb = _kit('pb', pbCloses: '2026-10-30');
      final own = _kit('own');
      // 구매한 날 = 기록을 적은 때라 UserStore 의 지금 시각이 아니라 저장 파일로 심는다 (10월 안이어야 보인다)
      final store = UserStore.memory()
        ..debugLoadJson({
          'collection': {
            'items': {
              for (final id in ['pre', 'res', 'pb'])
                id: {'status': 'wanted', 'updated_at': '2026-10-20T00:00:00Z', 'quantity': 1},
              'own': {'status': 'owned', 'updated_at': '2026-10-26T12:00:00Z', 'quantity': 1},
            },
          },
        })
        ..putPreorder(pre.id, const Preorder(shop: '샵', arrival: '2026-10-28', price: 50000));
      await pumpCalendar(
        tester,
        store,
        [pre, res, pb, own],
        const [],
        restocks: RestockIndex({
          'res': [RestockEvent(kitId: 'res', date: '2026-10-29')],
        }),
      );
      await tester.tap(find.byKey(const ValueKey('calendar-scope-1'))); // 내 일정
      await tester.pumpAndSettle();
      // 목록 줄 앞 점 (한 주 목록은 아래로 길어 skipOffstage: false)
      for (final key in ['event-dot-preorder', 'event-dot-resale', 'event-dot-bought', 'event-dot-pb']) {
        expect(find.byKey(ValueKey(key), skipOffstage: false), findsOneWidget, reason: key);
      }
      // 달력 격자에도 네 뜻이 다 있다 (구매한 날은 적은 시각이 기기 시간대에 따라 26 · 27 로 갈려 날을 못 박지 않는다)
      final card = find.byKey(const ValueKey('calendar-card'));
      for (final key in ['day-dot-preorder', 'day-dot-resale', 'day-dot-bought', 'day-dot-pb']) {
        expect(
          find.descendant(of: card, matching: find.byKey(ValueKey(key))),
          findsOneWidget,
          reason: key,
        );
      }
      // 격자 점 색도 목록과 같다 — 28 예약(보라) · 29 재판매(주황) · 30 PB 마감(빨강), 내 일정은 다 꽉 찬 점
      expect(dotsOn(tester, '28'), [(Gp.reserve, false)]);
      expect(dotsOn(tester, '29'), [(Gp.resale, false)]);
      expect(dotsOn(tester, '30'), [(Gp.danger, false)]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('한 주 줄은 늘 위에: 목록을 밀어도 달력이 남는다 (전체 일정 · 내 일정 · 다시 접은 뒤 · 넓은 화면)', (tester) async {
      final kits = [
        for (var d = 1; d <= 31; d++)
          _kit('d${d.toString().padLeft(2, '0')}', date: '2026-10-${d.toString().padLeft(2, '0')}'),
      ];
      final store = UserStore.memory();
      for (final k in kits) {
        store.setStatus(k.id, CollectStatus.wanted); // 내 일정에도 줄이 있게
      }
      await pumpCalendar(tester, store, kits, const []);
      final card = find.byKey(const ValueKey('calendar-card'));
      final list = find.byKey(const ValueKey('calendar-week-list'));
      // 달력이 목록 밖(고정)에 있다 = 목록을 밀어도 화면 안에 그대로
      Future<void> expectPinned(String path) async {
        await tester.drag(list, const Offset(0, -1500));
        await tester.pumpAndSettle();
        expect(card, findsOneWidget, reason: path);
        expect(tester.getRect(card).top, greaterThanOrEqualTo(0.0), reason: path);
        expect(tester.getRect(card).bottom, lessThanOrEqualTo(844.0), reason: path);
        expect(
          find.descendant(of: card, matching: find.text('25')),
          findsOneWidget,
          reason: path,
        );
      }

      await expectPinned('전체 일정');
      await tester.tap(find.byKey(const ValueKey('calendar-scope-1')));
      await tester.pumpAndSettle();
      await expectPinned('내 일정');
      // 한 달로 펴고 다시 한 주로 접은 뒤에도
      await tester.tap(find.byKey(const ValueKey('month-handle')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('month-handle')));
      await tester.pumpAndSettle();
      await expectPinned('다시 접은 뒤');
      // 넓은 화면(≥720dp): 달력은 왼쪽 칸에 고정, 오른쪽 목록만 밀린다
      tester.view.physicalSize = const Size(900, 844);
      await tester.pumpAndSettle();
      expect(list, findsNothing, reason: '넓은 화면 갈래로 안 갔다 — 아래 밀기가 좁은 화면을 또 보고 있다');
      await tester.dragFrom(const Offset(700, 600), const Offset(0, -1500));
      await tester.pumpAndSettle();
      expect(card, findsOneWidget);
      expect(tester.getRect(card).top, greaterThanOrEqualTo(0.0));
      expect(find.descendant(of: card, matching: find.text('25')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('한 주: 목록이 1일이 아니라 오늘부터 · 그 주의 날을 누르면 목록이 그날로 (거르지 않음) · 한 달은 그대로 1일부터', (tester) async {
      final kits = [
        for (var d = 1; d <= 31; d++)
          _kit('d${d.toString().padLeft(2, '0')}', date: '2026-10-${d.toString().padLeft(2, '0')}'),
      ];
      final store = UserStore.memory();
      await pumpCalendar(tester, store, kits, const []);
      final list = find.byKey(const ValueKey('calendar-week-list'));
      expect(list, findsOneWidget);
      final top = tester.getTopLeft(list).dy;
      double y(String id) => tester.getTopLeft(find.text('name-$id', skipOffstage: false)).dy;
      // 오늘(10.25)의 줄이 목록 맨 위 (날짜 머리 한 줄 아래), 앞날은 위로 밀려 있다
      expect(y('d25') - top, inInclusiveRange(0, 80));
      expect(find.text('name-d01'), findsNothing);
      // 그 주의 27일 → 목록이 27일로, 다른 날도 그대로 있다 (한 주에서는 그날만 보기가 아님)
      await tester.tap(find.text('27'));
      await tester.pumpAndSettle();
      expect(y('d27') - top, inInclusiveRange(0, 80));
      expect(find.text('name-d26', skipOffstage: false), findsOneWidget);
      // 위로 밀면 앞날도 보인다
      await tester.drag(list, const Offset(0, 3000));
      await tester.pumpAndSettle();
      expect(find.text('name-d01'), findsOneWidget);
      // 다음 주(11월 첫 주)로 넘기면 그 주 첫날부터
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // 한 달로 펴 둔 기기는 전처럼 한 목록(달력과 함께 밀림) · 1일부터
      await tester.pumpWidget(const SizedBox());
      await pumpCalendar(tester, UserStore.memory()..setCalendarMonthOpen(true), kits, const []);
      expect(list, findsNothing);
      expect(find.text('name-d01'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
