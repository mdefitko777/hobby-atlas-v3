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
}
