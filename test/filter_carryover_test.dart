// 작품을 바꿀 때 남은 조건 이어 쓰기 (lib/logic/filter_carryover.dart) — 있는 값만 남고, 없는 값은 까닭과 함께 떨어진다.
// 맨 끝은 그 결과를 보이는 탭 줄 알림 (lib/widgets/toolbar.dart CarryNote)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/screens/o_see_all_screen.dart' show ListTools;
import 'package:hobby_atlas/theme.dart';
// 규칙(logic/filter_carryover.dart) · 알림 줄(widgets/toolbar.dart) 둘 다 이 묶음이 내보낸다
import 'package:hobby_atlas/widgets.dart';

import 'support/line_kits.dart';

void main() {
  // SEED = HG · MG 프라모델 + 굿즈(티켓), 00 = MG 프라모델 하나뿐 (2019년 · ₩12만)
  final pool = [
    lineKit('s1', series: 'SEED', line: 'HG', date: '2024-03-01', priceKrw: 20000),
    lineKit('s2', series: 'SEED', line: 'MG', date: '2024-05-01', priceKrw: 60000),
    lineKit('s3', series: 'SEED', line: '', type: '굿즈', goodsKind: '티켓', date: '2024-06-01'),
    lineKit('d1', series: '00', line: 'MG', date: '2019-07-01', priceKrw: 120000),
  ];

  KitFilter seed({
    Set<String>? lines,
    Set<String>? linesOut,
    Set<String>? types,
    Set<String>? goodsKinds,
    PriceBand price = PriceBand.any,
    String from = '',
    String to = '',
  }) => KitFilter(
    works: {'SEED'},
    lines: lines,
    linesOut: linesOut,
    types: types,
    goodsKinds: goodsKinds,
    price: price,
    currency: price == PriceBand.any ? null : PriceCurrency.krw,
    from: from,
    to: to,
  );

  /// 필터 시트에서 작품만 다시 고른 것
  KitFilter toWork(KitFilter before, String work) {
    final f = before.copy();
    f.works
      ..clear()
      ..add(work);
    return f;
  }

  test('새 작품에 있는 조건은 이어 쓴다 (라인 · 기간)', () {
    final before = seed(lines: {'MG'}, from: '2019-01', to: '2026-12');
    final c = carryFilter(pool, before, toWork(before, '00'));
    expect(c.count, 2);
    expect([for (final x in c.carried) x.label], ['라인 MG', '기간 2019.01–2026.12']);
    expect(c.dropped, isEmpty);
    expect(c.filter.lines, {'MG'});
    expect((c.filter.from, c.filter.to), ('2019-01', '2026-12'));
  });

  test('새 작품에 없는 조건은 까닭과 함께 떨어진다 (종류 · 굿즈 종류 · 라인 · 기간 · 가격)', () {
    final before = seed(
      lines: {'HG'},
      types: {'굿즈'},
      goodsKinds: {'티켓'},
      price: PriceBand.low, // 3만원 이하 — 00 은 ₩12만 하나뿐
      from: '2024-01',
      to: '2024-12',
    );
    final c = carryFilter(pool, before, toWork(before, '00'));
    expect(c.count, 0, reason: '이어 쓸 것이 하나도 없다');
    expect([for (final x in c.dropped) x.label], ['종류 굿즈', '굿즈 종류 티켓', '라인 HG', '기간 2024.01–2024.12', '가격 3만원 이하']);
    expect(c.dropped.first.reason, '00 에 없어요');
    // 떨어뜨린 값은 새 조건에서 빠진다 — 아무것도 안 맞는 필터에 갇히지 않게
    expect(c.filter.types, isEmpty);
    expect(c.filter.goodsKinds, isEmpty);
    expect(c.filter.lines, isEmpty);
    expect((c.filter.price, c.filter.from, c.filter.to), (PriceBand.any, '', ''));
    expect(pool.where(c.filter.matches).length, 1, reason: '00 상품은 그대로 보인다');
  });

  test('「제외」 짝도 같은 규칙 · 같은 말투 (「라인 HG 제외」)', () {
    final out = seed(linesOut: {'HG'});
    final c = carryFilter(pool, out, toWork(out, '00'));
    expect([for (final x in c.dropped) x.label], ['라인 HG 제외']);
    expect(c.carried, isEmpty);
    expect(c.filter.linesOut, isEmpty);
  });

  test('이어 쓸 것이 없으면 빈 결과 (조건이 작품뿐 · 작품이 그대로 · 작품을 풀기)', () {
    final only = seed();
    final c = carryFilter(pool, only, toWork(only, '00'));
    expect(c.count, 0);
    expect(c.dropped, isEmpty);
    expect(c.isEmpty, isTrue);

    // 작품이 그대로면 아무 일도 없었던 것 (고른 조건도 건드리지 않는다)
    final same = seed(lines: {'MG'});
    final kept = carryFilter(pool, same, same.copy());
    expect(kept.isEmpty, isTrue);
    expect(kept.filter.lines, {'MG'});

    // 작품을 풀면 보는 범위가 넓어진다 — 떨어뜨리지 않고 다 이어 쓴다
    final wide = carryFilter(pool, same, same.copy()..works.clear());
    expect(wide.count, 1);
    expect(wide.dropped, isEmpty);
    expect(wide.filter.lines, {'MG'});
  });

  test('이어 쓴 조건은 하나씩 · 한 번에 지울 수 있다', () {
    final before = seed(lines: {'MG'}, from: '2019-01', to: '2026-12');
    final c = carryFilter(pool, before, toWork(before, '00'));

    final one = c.without(c.carried.first);
    expect(one.count, 1);
    expect(one.filter.lines, isEmpty);
    expect(one.filter.from, '2019-01', reason: '지운 것 하나만 빠진다');

    final all = c.cleared();
    expect(all.count, 0);
    expect(all.isEmpty, isTrue);
    expect(all.filter.lines, isEmpty);
    expect((all.filter.from, all.filter.to), ('', ''));
    expect(all.filter.works, {'00'}, reason: '고른 작품은 남는다');
  });

  test('「필터 초기화」로 조건을 갈아 끼우면 알림도 사라진다 (× 가 지운 조건을 되살리지 않게)', () {
    final before = seed(lines: {'MG'});
    final c = carryFilter(pool, before, toWork(before, '00'));
    expect(c.count, 1);

    final find = KitFind()..apply(c);
    expect(find.carry?.count, 1);
    find.filter = KitFilter(); // 빈 결과 화면의 「필터 초기화」
    expect(find.carry, isNull, reason: '알림이 남으면 × 가 라인 MG 를 되살린다');
    expect(find.filter.count, 0);

    final tools = ListTools()..setCarry(c);
    expect(tools.carry?.count, 1);
    tools.setFilter(KitFilter());
    expect(tools.carry, isNull);
    expect(tools.filter.count, 0);
  });

  group('탭 줄 알림 (CarryNote)', () {
    /// 라인 MG 는 이어 쓰고, 종류 굿즈는 00 에 없어 떨어뜨린 상태
    FilterCarry made() {
      final before = seed(lines: {'MG'}, types: {'굿즈'});
      return carryFilter(pool, before, toWork(before, '00'));
    }

    /// 탭 줄 하나 — 아이콘 왼쪽에 알림. 지운 결과는 [got] 에 담긴다
    Future<void> pump(WidgetTester tester, FilterCarry? carry, void Function(FilterCarry) got) => tester.pumpWidget(
      MaterialApp(
        theme: buildGpTheme(),
        home: Scaffold(
          body: ToolRow(
            leading: const SizedBox(),
            tools: [
              CarryNote(carry: carry, onChanged: got),
              FilterButton(count: 2, onTap: () {}),
            ],
          ),
        ),
      ),
    );

    testWidgets('이어 쓴 것이 없으면 아무것도 그리지 않는다', (tester) async {
      await pump(tester, null, (_) {});
      expect(find.byKey(const ValueKey('carry-note')), findsNothing);
      await pump(tester, FilterCarry(KitFilter()), (_) {});
      expect(find.byKey(const ValueKey('carry-note')), findsNothing);
    });

    testWidgets('× 는 이어 쓴 조건을 한 번에 지운다', (tester) async {
      FilterCarry? got;
      await pump(tester, made(), (c) => got = c);
      expect(find.byKey(const ValueKey('carry-note')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('carry-clear')));
      await tester.pump();
      expect(got, isNotNull);
      expect(got!.count, 0);
      expect(got!.filter.lines, isEmpty);
    });

    testWidgets('글자를 누르면 「이어 쓴 필터」 시트 — 못 이어 쓴 줄은 까닭과 함께', (tester) async {
      FilterCarry? got;
      await pump(tester, made(), (c) => got = c);
      await tester.tap(find.byKey(const ValueKey('carry-note')));
      await tester.pumpAndSettle();
      expect(find.text('라인 MG'), findsOneWidget);
      expect(find.textContaining('종류 굿즈'), findsOneWidget);
      expect(find.textContaining('00 에 없어요'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('carry-clear-all')));
      await tester.pumpAndSettle();
      expect(got, isNotNull);
      expect(got!.filter.lines, isEmpty);
    });
  });
}
