// 필터 「기간」 — 발매일을 달 단위로 (빠른 고르기 · 시작 · 끝 달)
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/clock.dart';
import 'package:hobby_atlas/models.dart';
import 'package:hobby_atlas/theme.dart';
import 'package:hobby_atlas/widgets.dart';

import 'layout_test.dart' show db;

void main() {
  test('기간 안인가: 달 · 날짜 · 해만 있는 발매일, 열린 끝, 발매일 없음', () {
    expect(inPeriod('2024-05-10', '2024-01', '2024-12'), isTrue);
    expect(inPeriod('2024-05', '2024-06', ''), isFalse);
    expect(inPeriod('2025-01', '2024-06', ''), isTrue, reason: '끝이 열림');
    expect(inPeriod('2023-12-31', '', '2023-12'), isTrue, reason: '시작이 열림');
    expect(inPeriod('2024', '2024-03', '2024-09'), isTrue, reason: '해만 있으면 해로');
    expect(inPeriod('', '2024-01', '2024-12'), isFalse, reason: '기간을 정하면 발매일 없는 상품은 빠진다');
    expect(inPeriod('', '', ''), isTrue);
  });

  test('빠른 고르기 · 한 줄 글', () {
    const today = '2026-11-10';
    expect(PeriodPreset.thisYear.range(today), ('2026-01', '2026-12'));
    expect(PeriodPreset.lastYear.range(today), ('2025-01', '2025-12'));
    expect(PeriodPreset.lastYearSpan.range(today), ('2025-12', '2026-11'));
    expect(PeriodPreset.lastYearSpan.range('2026-12-01'), ('2026-01', '2026-12'));
    expect(PeriodPreset.any.range(today), ('', ''));
    expect(periodLabel('2023-01', '2024-06'), '2023.01–2024.06');
    expect(periodLabel('2023-01', ''), '2023.01 부터');
    expect(periodLabel('', '2024-06'), '2024.06 까지');
    expect(periodLabel('2024-06', '2024-06'), '2024.06');
  });

  test('12월엔 올해 = 최근 1년 — 앞의 것(올해)으로 본다', () {
    expect(periodPresetOf('2026-01', '2026-12', '2026-12-05'), PeriodPreset.thisYear);
    expect(periodPresetOf('2025-12', '2026-11', '2026-11-10'), PeriodPreset.lastYearSpan);
    expect(periodPresetOf('', '', '2026-11-10'), PeriodPreset.any);
    expect(periodPresetOf('2024-03', '2024-05', '2026-11-10'), isNull);
  });

  test('달 고르기의 가장 이른 해 = 목록에서 가장 오래된 발매일 (없으면 1980)', () {
    expect(earliestYear(['2024-05-10', '1949', '', '1975-03', 'TBA']), 1949);
    expect(earliestYear(['2024-05-10', '2021']), 2021);
    expect(earliestYear(const []), 1980);
    expect(earliestYear(['', '0000']), 1980, reason: '이상한 해는 건너뛴다');
  });

  test('KitFilter: 기간이 개수 · 글 · 복사 · 초기화에 들어간다', () {
    final f = KitFilter(from: '2024-01', to: '2024-12');
    expect(f.count, 1);
    expect(f.labels, ['2024.01–2024.12']);
    final c = f.copy();
    expect((c.from, c.to), ('2024-01', '2024-12'));
    f.clear();
    expect((f.from, f.to, f.count), ('', '', 0));
  });

  testWidgets('필터 시트: 기간 → 올해 → 시작 달을 작년 1월로', (t) async {
    fixedNow = DateTime(2026, 10, 25, 21);
    addTearDown(() => fixedNow = null);
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final kits = (db['kits']! as List).map(Kit.fromJson).nonNulls.toList();
    int hits(String from, String to) => kits.where((k) => inPeriod(k.date, from, to)).length;
    await t.pumpWidget(
      MaterialApp(
        theme: buildGpTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => unawaited(showFilterSheet(context, kits: kits, initial: KitFilter())),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('열기'));
    await t.pumpAndSettle();
    final row = find.text('기간');
    await t.scrollUntilVisible(row, 200, scrollable: find.byType(Scrollable).last);
    await t.tap(row);
    await t.pumpAndSettle();
    await t.tap(find.text('올해'));
    await t.pumpAndSettle();
    expect(find.text('${hits('2026-01', '2026-12')}개 보기'), findsOneWidget);

    await t.ensureVisible(find.byKey(const ValueKey('period-from')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('period-from')));
    await t.pumpAndSettle();
    expect(find.text('시작 달'), findsOneWidget);
    await t.tap(find.byTooltip('작년'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('month-sheet-year')), findsOneWidget);
    expect(find.text('2025'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('month-1')));
    await t.pumpAndSettle();
    expect(find.text('시작  2025.01'), findsOneWidget);
    expect(find.text('${hits('2025-01', '2026-12')}개 보기'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('12월에 올해를 누르면 올해에 불이 켜진다 (최근 1년이 아니라)', (t) async {
    fixedNow = DateTime(2026, 12, 5, 12);
    addTearDown(() => fixedNow = null);
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final kits = (db['kits']! as List).map(Kit.fromJson).nonNulls.toList();
    await _openPeriod(t, kits);
    await t.tap(find.text('올해'));
    await t.pumpAndSettle();
    FontWeight? weight(String label) => DefaultTextStyle.of(t.element(find.text(label))).style.fontWeight;
    expect(weight('올해'), FontWeight.w700);
    expect(weight('최근 1년'), FontWeight.w400);
    expect(t.takeException(), isNull);
  });

  testWidgets('달 고르기: 목록의 가장 오래된 해(1949)까지 가고 거기서 멈춘다 · 가로 화면에서도 넘치지 않는다', (t) async {
    fixedNow = DateTime(2026, 10, 25, 21);
    addTearDown(() => fixedNow = null);
    t.view.physicalSize = const Size(844, 390); // 휴대폰 가로
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final kits = [
      ...(db['kits']! as List).map(Kit.fromJson).nonNulls,
      Kit.fromJson({'id': 'lego-old-1', 'franchiseId': 'lego', 'name': '오래된 레고', 'type': '레고', 'date': '1949'})!,
    ];
    await _openPeriod(t, kits);
    await t.ensureVisible(find.byKey(const ValueKey('period-from')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('period-from')));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull, reason: '시트보다 긴 내용은 밀어 본다');
    final back = find.byTooltip('작년');
    bool canGoBack() =>
        t.widget<IconButton>(find.ancestor(of: back, matching: find.byType(IconButton))).onPressed != null;
    for (var i = 0; i < 2026 - 1949; i++) {
      await t.tap(back);
      await t.pump();
    }
    expect(find.text('1949'), findsOneWidget);
    expect(canGoBack(), isFalse);
    // 맨 아래 「정하지 않기」도 밀어서 누를 수 있다
    final open = find.text('정하지 않기 (열어 두기)');
    final sheet = find.ancestor(of: find.byKey(const ValueKey('month-sheet-year')), matching: find.byType(Scrollable));
    await t.scrollUntilVisible(open, 100, scrollable: sheet.first);
    await t.tap(open);
    await t.pumpAndSettle();
    expect(find.text('시작 달'), findsNothing);
    expect(t.takeException(), isNull);
  });
}

/// 필터 시트를 열고 「기간」 줄을 펼친다
Future<void> _openPeriod(WidgetTester t, List<Kit> kits) async {
  await t.pumpWidget(
    MaterialApp(
      theme: buildGpTheme(),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => unawaited(showFilterSheet(context, kits: kits, initial: KitFilter())),
            child: const Text('열기'),
          ),
        ),
      ),
    ),
  );
  await t.tap(find.text('열기'));
  await t.pumpAndSettle();
  final row = find.text('기간');
  await t.scrollUntilVisible(row, 200, scrollable: find.byType(Scrollable).last);
  await t.tap(row);
  await t.pumpAndSettle();
}
