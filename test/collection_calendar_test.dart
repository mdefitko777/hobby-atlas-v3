// 컬렉션 줄 부제(같은 말 한 번 · 건담은 도감 공식 작품 이름) · 목록 맨 끝 합계(₩ · ¥ 따로) ·
// 캘린더 한 주 ↔ 한 달 손잡이 · 점 두 가지 뜻 (2026-11-20 화면 정리)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/api.dart';
import 'package:hobby_atlas/clock.dart';
import 'package:hobby_atlas/data/user_store.dart';
import 'package:hobby_atlas/detail_pane.dart';
import 'package:hobby_atlas/logic/kit_meta.dart';
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
}) => Kit.fromSlim(
  {
    'id': id,
    'franchiseId': ch,
    'name': 'name-$id',
    'line': line,
    'series': series,
    'date': date,
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
    Future<void> pumpCalendar(WidgetTester tester, UserStore store, List<Kit> kits, List<Announcement> anns) => _pump(
      tester,
      store,
      CalendarScreen(
        myChannels: const ['gundam'],
        onMyChannelsChanged: (_) {},
        loaders: Loaders(kits: (_) async => kits, announcements: (_) async => anns),
      ),
    );

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

    testWidgets('점 뜻은 둘: 내 좋아요 상품 = 파랑, 그 밖(다른 발매 · 예고) = 회색 · 상태는 알약 없이 둘째 줄', (tester) async {
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
      expect(find.byKey(const ValueKey('event-dot-other'), skipOffstage: false), findsNWidgets(2));
      final annRow = find.byKey(const ValueKey('event-ann'), skipOffstage: false);
      expect(find.descendant(of: annRow, matching: find.byKey(const ValueKey('event-dot-other'))), findsOneWidget);
      // 달력 칸 점: 27일 파랑, 28 · 29일 회색
      Iterable<Color> dotsOn(String day) => tester
          .widgetList<Container>(
            find.descendant(
              of: find.ancestor(of: find.text(day), matching: find.byType(GestureDetector)).first,
              matching: find.byType(Container),
            ),
          )
          .map((c) => (c.decoration as BoxDecoration?)?.color)
          .whereType<Color>()
          .where((c) => c == Gp.accent || c == Gp.muted);
      expect(dotsOn('27'), [Gp.accent]);
      expect(dotsOn('28'), [Gp.muted]);
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
