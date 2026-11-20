// 채널 바 접기 (lib/widgets/header_collapse.dart) — 천천히 조금 읽는 동안은 그대로, 한참(400 넘게 · 한 번 세게 밀기) 내려야 접고,
// 조금이라도 올리면 편다. 짧은 목록 · 가로 줄 · 화면이 스스로 옮긴 스크롤 · 맨 위 당기기. 글자 없이 Key · 타입 · 높이로 본다
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/widgets.dart';

const _headerKey = ValueKey('header');
const _listKey = ValueKey('list');
const _rowKey = ValueKey('row');

Future<(HeaderCollapseController, ScrollController)> _show(
  WidgetTester tester, {
  int items = 60,
  bool refresh = false,
}) async {
  final controller = HeaderCollapseController();
  final scroll = ScrollController();
  addTearDown(controller.dispose);
  addTearDown(scroll.dispose);
  Widget list = ListView(
    key: _listKey,
    controller: scroll,
    children: [
      SizedBox(
        key: _rowKey,
        height: 80,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [for (var i = 0; i < 20; i++) const SizedBox(width: 90)],
        ),
      ),
      for (var i = 0; i < items; i++) const SizedBox(height: 48),
    ],
  );
  if (refresh) list = RefreshIndicator(onRefresh: () async {}, child: list);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: HeaderCollapse(
          controller: controller,
          child: Column(
            children: [
              const SizedBox(height: 56), // 아바타 줄 — 머리 밖이라 늘 그대로
              const CollapsingHeader(child: SizedBox(key: _headerKey, height: 60)), // 채널 바
              Expanded(child: list),
            ],
          ),
        ),
      ),
    ),
  );
  return (controller, scroll);
}

double _barHeight(WidgetTester tester) => tester.getSize(find.byType(CollapsingHeader)).height;

Future<void> _snap(WidgetTester tester) async {
  await tester.pump(); // 애니메이션은 다음 프레임부터
  await tester.pump(headerSnapDuration);
}

void main() {
  testWidgets('천천히 조금씩(합쳐 400 아래) 내려 읽는 동안은 그대로', (tester) async {
    final (c, _) = await _show(tester);
    for (var i = 0; i < 3; i++) {
      await tester.drag(find.byKey(_listKey), const Offset(0, -100));
      await _snap(tester);
    }
    expect(c.hidden, isFalse);
    expect(_barHeight(tester), 60);
  });

  testWidgets('한 번에 400 넘게 내리면 200ms 에 한 번에 접히고, 조금 올리면 다시 펴진다', (tester) async {
    final (c, _) = await _show(tester);
    await tester.drag(find.byKey(_listKey), const Offset(0, -500));
    await tester.pump();
    expect(c.hidden, isTrue);
    await tester.pump(headerSnapDuration ~/ 2);
    expect(_barHeight(tester), inExclusiveRange(0, 60)); // 손가락이 아니라 시간을 따라 접힌다
    await tester.pump(headerSnapDuration);
    expect(_barHeight(tester), 0);

    await tester.drag(find.byKey(_listKey), const Offset(0, 30));
    await tester.pump();
    expect(c.hidden, isFalse);
    await tester.pump(headerSnapDuration);
    expect(_barHeight(tester), 60);
  });

  testWidgets('세게 한 번 밀기(손을 뗀 뒤 미끄러진 거리까지) = 한참 내려 읽기', (tester) async {
    final (c, _) = await _show(tester);
    await tester.fling(find.byKey(_listKey), const Offset(0, -200), 2500);
    await tester.pumpAndSettle();
    expect(c.hidden, isTrue);
  });

  testWidgets('올리지 않고 이어서 내린 거리는 합친다 · 중간에 올리면 처음부터', (tester) async {
    final (c, _) = await _show(tester);
    await tester.drag(find.byKey(_listKey), const Offset(0, -250));
    await tester.drag(find.byKey(_listKey), const Offset(0, 40)); // 올림 → 처음부터
    await tester.drag(find.byKey(_listKey), const Offset(0, -250));
    await _snap(tester);
    expect(c.hidden, isFalse);
    await tester.drag(find.byKey(_listKey), const Offset(0, -250)); // 이어서 250 + 250
    await _snap(tester);
    expect(c.hidden, isTrue);
  });

  testWidgets('채널 바를 접어도 스크롤이 남지 않는 짧은 목록은 접지 않는다', (tester) async {
    // 내용 80 + 8 × 48 = 464, 보이는 높이 600 − 56 − 60 = 484 → 스크롤이 없다
    final (c, _) = await _show(tester, items: 8);
    await tester.drag(find.byKey(_listKey), const Offset(0, -600));
    await _snap(tester);
    expect(c.hidden, isFalse);
    expect(_barHeight(tester), 60);
  });

  testWidgets('가로 줄을 밀어도 · 화면이 스스로 옮겨도(jumpTo) 그대로', (tester) async {
    final (c, scroll) = await _show(tester);
    await tester.drag(find.byKey(_rowKey), const Offset(-600, 0));
    await _snap(tester);
    expect(c.hidden, isFalse);
    scroll.jumpTo(1200);
    await _snap(tester);
    expect(c.hidden, isFalse);
  });

  testWidgets('당겨서 새로 고침이 있는 목록도 같게 — 맨 위로 돌아오면 편다', (tester) async {
    final (c, _) = await _show(tester, refresh: true);
    await tester.drag(find.byKey(_listKey), const Offset(0, -500));
    await _snap(tester);
    expect(c.hidden, isTrue);

    // 맨 위까지 한 번에 올리기
    await tester.drag(find.byKey(_listKey), const Offset(0, 900));
    await _snap(tester);
    expect(c.hidden, isFalse);
    await tester.pumpAndSettle();
  });

  testWidgets('셸이 show() 하면 편다 (탭 바꾸기)', (tester) async {
    final (c, _) = await _show(tester);
    await tester.drag(find.byKey(_listKey), const Offset(0, -500));
    await _snap(tester);
    expect(_barHeight(tester), 0);
    c.show();
    await _snap(tester);
    expect(_barHeight(tester), 60);
  });

  testWidgets('펴져 있을 때 show() 해도 앞에서 내려 읽은 거리는 버린다 (탭 바꾸기)', (tester) async {
    final (c, _) = await _show(tester);
    await tester.drag(find.byKey(_listKey), const Offset(0, -300));
    await _snap(tester);
    expect(c.hidden, isFalse);
    c.show(); // 다른 탭으로 — 300 은 이어지지 않는다
    await tester.drag(find.byKey(_listKey), const Offset(0, -150));
    await _snap(tester);
    expect(c.hidden, isFalse);
  });

  // 내용 80 + n × 48, 보이는 높이 484 → 끝 460(n 18) · 508(n 19). 접으면 보이는 높이가 60 늘어 위치가 새 끝으로 당겨진다.
  // 고치기 전에는 이 둘에서 접히다(또는 다 접힌 뒤) 도로 펴졌다
  for (final (items, drag) in [(18, -420.0), (19, -150.0)]) {
    testWidgets('끝 가까이에서 접혀 목록 끝이 당겨져도 다시 펴지지 않는다 ($items)', (tester) async {
      final (c, scroll) = await _show(tester, items: items);
      await tester.fling(find.byKey(_listKey), Offset(0, drag), 1500);
      final heights = <double>[];
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        heights.add(_barHeight(tester));
      }
      await tester.pumpAndSettle();
      expect(c.hidden, isTrue);
      expect(_barHeight(tester), 0);
      expect(scroll.position.pixels, scroll.position.maxScrollExtent);
      for (var i = 1; i < heights.length; i++) {
        expect(heights[i], lessThanOrEqualTo(heights[i - 1]), reason: '$heights'); // 접히다 도로 커지는 프레임 없음
      }
    });
  }

  testWidgets('HeaderCollapse 밖이면 늘 펼침 (검색 덮개 · 셸 없이 띄운 화면)', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CollapsingHeader(child: SizedBox(key: _headerKey, height: 60)),
      ),
    );
    expect(find.byKey(_headerKey), findsOneWidget);
  });
}
