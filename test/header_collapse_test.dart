// 채널 바 접기 (lib/widgets/header_collapse.dart) — 한두 줄 읽는 동안은 그대로, 살짝 한 번(120 넘게) 밀면 채널 바가,
// 거기서 또 살짝 밀면 탭 줄까지 한 겹씩 접히고, 조금이라도 올리면 두 겹 다 펴진다 (2026-11-22 주인).
// 짧은 목록 · 가로 줄 · 화면이 스스로 옮긴 스크롤 · 맨 위 당기기 · 캘린더 한 주 보기처럼 안쪽에 따로 밀리는 목록.
// 글자 없이 Key · 타입 · 높이로 본다
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/widgets.dart';

const _headerKey = ValueKey('header');
const _barKey = ValueKey('bar'); // 첫 겹 — 채널 바
const _tabsKey = ValueKey('tabs'); // 둘째 겹 — 탭 줄
const _listKey = ValueKey('list');
const _rowKey = ValueKey('row');

Future<(HeaderCollapseController, ScrollController)> _show(
  WidgetTester tester, {
  int items = 60,
  bool refresh = false,
  bool twoSteps = false,
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
              const CollapsingHeader(
                key: _barKey,
                child: SizedBox(key: _headerKey, height: 60),
              ), // 채널 바
              if (twoSteps) const CollapsingHeader(key: _tabsKey, step: 2, child: SizedBox(height: 40)), // 탭 줄
              Expanded(child: list),
            ],
          ),
        ),
      ),
    ),
  );
  return (controller, scroll);
}

double _barHeight(WidgetTester tester) => tester.getSize(find.byKey(_barKey)).height;

double _tabsHeight(WidgetTester tester) => tester.getSize(find.byKey(_tabsKey)).height;

Future<void> _snap(WidgetTester tester) async {
  await tester.pump(); // 애니메이션은 다음 프레임부터
  await tester.pump(headerSnapDuration);
}

void main() {
  testWidgets('한두 줄씩(합쳐 120 아래) 천천히 내려 읽는 동안은 그대로', (tester) async {
    final (c, _) = await _show(tester);
    for (var i = 0; i < 3; i++) {
      await tester.drag(find.byKey(_listKey), const Offset(0, -35));
      await _snap(tester);
    }
    expect(c.hidden, isFalse);
    expect(_barHeight(tester), 60);
  });

  testWidgets('살짝 한 번(120 넘게) 밀면 200ms 에 한 번에 접히고, 조금 올리면 다시 펴진다', (tester) async {
    final (c, _) = await _show(tester);
    await tester.drag(find.byKey(_listKey), const Offset(0, -160));
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

  testWidgets('살짝 한 번 밀면 한 겹, 또 살짝 밀면 또 한 겹 (2026-11-22 주인)', (tester) async {
    await _show(tester, twoSteps: true);
    await tester.drag(find.byKey(_listKey), const Offset(0, -160));
    await _snap(tester);
    expect(_barHeight(tester), 0);
    expect(_tabsHeight(tester), 40); // 아직 탭 줄은 남는다

    await tester.drag(find.byKey(_listKey), const Offset(0, -160));
    await _snap(tester);
    expect(_tabsHeight(tester), 0);
  });

  testWidgets('두 겹이 다 접혀도 조금 올리면 한 번에 둘 다 펴진다', (tester) async {
    await _show(tester, twoSteps: true);
    for (var i = 0; i < 2; i++) {
      await tester.drag(find.byKey(_listKey), const Offset(0, -160));
      await _snap(tester);
    }
    expect((_barHeight(tester), _tabsHeight(tester)), (0.0, 0.0));

    await tester.drag(find.byKey(_listKey), const Offset(0, 30));
    await _snap(tester);
    expect((_barHeight(tester), _tabsHeight(tester)), (60.0, 40.0));
  });

  testWidgets('세게 한 번 밀기(손을 뗀 뒤 미끄러진 거리까지)도 접는다', (tester) async {
    final (c, _) = await _show(tester);
    await tester.fling(find.byKey(_listKey), const Offset(0, -200), 2500);
    await tester.pumpAndSettle();
    expect(c.hidden, isTrue);
  });

  testWidgets('올리지 않고 이어서 내린 거리는 합친다 · 중간에 올리면 처음부터', (tester) async {
    final (c, _) = await _show(tester);
    await tester.drag(find.byKey(_listKey), const Offset(0, -90));
    await tester.drag(find.byKey(_listKey), const Offset(0, 40)); // 올림 → 처음부터
    await tester.drag(find.byKey(_listKey), const Offset(0, -90));
    await _snap(tester);
    expect(c.hidden, isFalse);
    await tester.drag(find.byKey(_listKey), const Offset(0, -90)); // 이어서 90 + 90 (손가락 미끌림 18 을 뺀 72 + 72)
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
    await tester.drag(find.byKey(_listKey), const Offset(0, -80));
    await _snap(tester);
    expect(c.hidden, isFalse);
    c.show(); // 다른 탭으로 — 80 은 이어지지 않는다
    await tester.drag(find.byKey(_listKey), const Offset(0, -80));
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

  // H-4 캘린더 한 주 보기: 달력은 위에 남고 목록만 안쪽에서 제 ScrollController 로 따로 밀린다.
  // 그 목록을 밀어도 알림이 HeaderCollapse 까지 올라와 두 겹이 접히는지 — 옆에 있는 달력 쪽 SingleChildScrollView 의
  // 알림이 끼어들어 도로 펴 버리지 않는지 함께 본다 (lib/screens/h_calendar_screen.dart 는 읽기만 했다)
  testWidgets('캘린더 한 주 보기처럼 안쪽 목록이 따로 밀려도 두 겹이 접힌다 (H-4)', (tester) async {
    final controller = HeaderCollapseController();
    final listCtrl = ScrollController();
    addTearDown(controller.dispose);
    addTearDown(listCtrl.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HeaderCollapse(
            controller: controller,
            child: Column(
              children: [
                const SizedBox(height: 56),
                const CollapsingHeader(key: _barKey, child: SizedBox(height: 60)),
                const CollapsingHeader(key: _tabsKey, step: 2, child: SizedBox(height: 40)),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) => Column(
                      children: [
                        ConstrainedBox(
                          // 달력 + 종류 탭 — 남은 높이의 3/4 까지
                          constraints: BoxConstraints(maxHeight: box.maxHeight * 0.75),
                          child: const SingleChildScrollView(child: SizedBox(height: 400)),
                        ),
                        Expanded(
                          child: ListView(
                            key: _listKey,
                            controller: listCtrl,
                            children: [for (var i = 0; i < 60; i++) const SizedBox(height: 48)],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.drag(find.byKey(_listKey), const Offset(0, -160));
    await _snap(tester);
    expect(_barHeight(tester), 0);
    expect(_tabsHeight(tester), 40);

    await tester.drag(find.byKey(_listKey), const Offset(0, -160));
    await _snap(tester);
    expect(_tabsHeight(tester), 0);
  });

  testWidgets('HeaderCollapse 밖이면 늘 펼침 (검색 덮개 · 셸 없이 띄운 화면)', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CollapsingHeader(child: SizedBox(key: _headerKey, height: 60)),
      ),
    );
    expect(find.byKey(_headerKey), findsOneWidget);
  });
}
