// 탭 위 머리 접기 (lib/widgets/header_collapse.dart) — 내리면 접고 · 살짝 올리면 펴고 · 짧은 목록 · 가로 줄 · 맨 위 당기기
// 글자 없이 Key · 타입 · 높이로 본다
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/widgets.dart';

const _headerKey = ValueKey('header');
const _listKey = ValueKey('list');
const _rowKey = ValueKey('row');

Future<HeaderCollapseController> _show(WidgetTester tester, {int items = 60, bool refresh = false}) async {
  final controller = HeaderCollapseController();
  addTearDown(controller.dispose);
  Widget list = ListView(
    key: _listKey,
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
              const CollapsingHeader(child: SizedBox(key: _headerKey, height: 110)),
              const SizedBox(height: 56), // 검색창 줄 — 머리 밖이라 남는다
              Expanded(child: list),
            ],
          ),
        ),
      ),
    ),
  );
  return controller;
}

double _headerHeight(WidgetTester tester) => tester.getSize(find.byType(CollapsingHeader)).height;

void main() {
  testWidgets('아래로 내리면 접히고 살짝 올리면 다시 펴진다 (200ms 에 한 번에)', (tester) async {
    final c = await _show(tester);
    expect(_headerHeight(tester), 110);

    await tester.drag(find.byKey(_listKey), const Offset(0, -300));
    await tester.pump();
    expect(c.hidden, isTrue);
    await tester.pump(headerSnapDuration);
    expect(_headerHeight(tester), 0);

    await tester.drag(find.byKey(_listKey), const Offset(0, 30));
    await tester.pump();
    expect(c.hidden, isFalse);
    await tester.pump(headerSnapDuration);
    expect(_headerHeight(tester), 110);
  });

  testWidgets('머리를 접어도 스크롤이 남지 않는 짧은 목록은 접지 않는다', (tester) async {
    // 내용 80 + 8 × 48 = 464, 보이는 높이 600 − 110 − 56 = 434 → 30 만 스크롤된다 (머리 110 보다 짧다)
    final c = await _show(tester, items: 8);
    await tester.drag(find.byKey(_listKey), const Offset(0, -200));
    await tester.pump(headerSnapDuration);
    expect(c.hidden, isFalse);
    expect(_headerHeight(tester), 110);
  });

  testWidgets('가로 줄을 밀어도 머리는 그대로', (tester) async {
    final c = await _show(tester);
    await tester.drag(find.byKey(_rowKey), const Offset(-300, 0));
    await tester.pump(headerSnapDuration);
    expect(c.hidden, isFalse);
  });

  testWidgets('당겨서 새로 고침이 있는 목록도 같게 — 맨 위로 돌아오면 편다', (tester) async {
    final c = await _show(tester, refresh: true);
    await tester.drag(find.byKey(_listKey), const Offset(0, -300));
    await tester.pump(headerSnapDuration);
    expect(c.hidden, isTrue);

    // 맨 위까지 한 번에 올리기
    await tester.drag(find.byKey(_listKey), const Offset(0, 600));
    await tester.pump(headerSnapDuration);
    expect(c.hidden, isFalse);
    await tester.pumpAndSettle();
  });

  testWidgets('셸이 show() 하면 편다 (탭 바꾸기)', (tester) async {
    final c = await _show(tester);
    await tester.drag(find.byKey(_listKey), const Offset(0, -300));
    await tester.pump(); // 애니메이션은 다음 프레임부터
    await tester.pump(headerSnapDuration);
    expect(_headerHeight(tester), 0);
    c.show();
    await tester.pump();
    await tester.pump(headerSnapDuration);
    expect(_headerHeight(tester), 110);
  });

  testWidgets('HeaderCollapse 밖이면 늘 펼침', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CollapsingHeader(child: SizedBox(key: _headerKey, height: 110)),
      ),
    );
    expect(find.byKey(_headerKey), findsOneWidget);
  });
}
