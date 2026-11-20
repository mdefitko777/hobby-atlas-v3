// 상품 카드 (lib/widgets/tiles.dart ProductTile) — 이름 두 줄 · 낱말 안에서 안 끊음 · 사진 위 ♡ 만 · 길게 = 구매함
// 글자 대신 타입 · 아이콘 · 상태로 본다 (중국어 화면에서도 같게)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/data/user_store.dart';
import 'package:hobby_atlas/marks.dart';
import 'package:hobby_atlas/models.dart';
import 'package:hobby_atlas/theme.dart';
import 'package:hobby_atlas/widgets.dart';

import 'layout_test.dart' show db;

Kit _plainKit() => (db['kits']! as List).map(Kit.fromJson).nonNulls.firstWhere((k) => k.status == CollectStatus.none);

Future<void> _show(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    theme: buildGpTheme(),
    builder: (context, c) => MarksHost(store: UserStore.memory(), child: c!),
    home: Scaffold(
      body: Align(alignment: Alignment.topLeft, child: child),
    ),
  ),
);

void main() {
  group('keepWords', () {
    test('낱말 안 글자 사이에만 이음표 — 띄어쓰기는 그대로', () {
      final joiner = String.fromCharCode(0x2060);
      expect(keepWords('건담 에어리얼'), '${['건', '담'].join(joiner)} ${['에', '어', '리', '얼'].join(joiner)}');
      expect(keepWords('HG').replaceAll(joiner, ''), 'HG');
      expect(keepWords(''), '');
    });

    test('붙임표 뒤에서는 끊을 수 있게 — 붙임표 앞에만 이음표', () {
      final joiner = String.fromCharCode(0x2060);
      final shown = keepWords('Hi-Resolution');
      expect(shown.replaceAll(joiner, ''), 'Hi-Resolution');
      expect(shown, contains('$joiner-R'), reason: "'-' 바로 뒤에 이음표가 없어야 거기서 줄이 바뀐다");
      expect(shown, isNot(contains('-$joiner')));
    });
  });

  testWidgets('분류 칸 이름 — 칸보다 긴 낱말은 글자를 줄여 낱말 안에서 안 끊는다', (tester) async {
    late TextStyle fit, short;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            fit = fitCategoryName(context, 'Hi-Resolution Model', 60);
            short = fitCategoryName(context, 'HG', 60);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(short.fontSize, categoryNameStyle(60).fontSize);
    expect(fit.fontSize!, lessThan(categoryNameStyle(60).fontSize!));
    expect(fit.fontSize!, greaterThanOrEqualTo(Gp.t11));
  });

  testWidgets('이름은 두 줄까지 · find.text 는 원래 이름 그대로', (tester) async {
    const name = '하이 그레이드 건담 에어리얼 개수형 퍼멧 스코어 식스 풀 패키지';
    await _show(tester, ProductTile(image: '', title: name, imageWidth: 110, onTap: () {}));
    expect(find.text(name), findsOneWidget);
    final shown = tester.widget<Text>(
      find.descendant(of: find.byType(KeepWordsText), matching: find.byType(Text)).last,
    );
    expect(shown.maxLines, 2);
    expect(shown.data, keepWords(name));
    expect(tester.takeException(), isNull);
  });

  testWidgets('옛 높이(사진 + 한 줄) 가로 줄에서는 들어가는 한 줄만 — 넘치지 않음', (tester) async {
    await _show(
      tester,
      SizedBox(
        height: 148 + 32,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [ProductTile(image: '', title: '아주 긴 상품 이름 ' * 6, imageWidth: 148, onTap: () {})],
        ),
      ),
    );
    final shown = tester.widget<Text>(
      find.descendant(of: find.byType(KeepWordsText), matching: find.byType(Text)).last,
    );
    expect(shown.maxLines, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('productTileHeight 줄에는 두 줄이 들어간다', (tester) async {
    late double h;
    await _show(
      tester,
      Builder(
        builder: (context) {
          h = productTileHeight(context, 110);
          return SizedBox(
            height: h,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [ProductTile(image: '', title: '긴 상품 이름 ' * 8, imageWidth: 110, onTap: () {})],
            ),
          );
        },
      ),
    );
    final shown = tester.widget<Text>(
      find.descendant(of: find.byType(KeepWordsText), matching: find.byType(Text)).last,
    );
    expect(shown.maxLines, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('사진 위에는 ♡ 만 — 길게 누르면 구매함 넣기 · 다시 길게 누르면 빼기 · 되돌리기', (tester) async {
    final kit = _plainKit();
    await _show(
      tester,
      Column(
        children: [
          ProductTile(
            image: '',
            title: kit.name,
            imageWidth: 120,
            marks: QuickMarks(kit: kit),
            onTap: () {},
          ),
          Builder(
            builder: (c) => Icon(
              Marks.of(c).owned(kit) ? Icons.check_box : Icons.check_box_outline_blank,
              key: const ValueKey('owned-state'),
            ),
          ),
        ],
      ),
    );
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.byIcon(Icons.add), findsNothing); // 리본 + 없음
    bool owned() => tester.widget<Icon>(find.byKey(const ValueKey('owned-state'))).icon == Icons.check_box;

    await tester.longPress(find.byType(ProductTile));
    await tester.pump();
    expect(owned(), isTrue);
    expect(find.byType(SnackBarAction), findsOneWidget); // 되돌리기

    await tester.longPress(find.byType(ProductTile));
    await tester.pump();
    expect(owned(), isFalse);
    // 앞 토스트가 내려가고 새 토스트(빼기의 되돌리기)가 올라올 때까지
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.byType(SnackBarAction));
    await tester.pump();
    expect(owned(), isTrue, reason: '되돌리기 = 빼기 전으로');
  });

  testWidgets('kit 을 주면 marks 없이도 길게 = 구매함 (My Page 최근 산 것)', (tester) async {
    final kit = _plainKit();
    late BuildContext ctx;
    await _show(
      tester,
      Builder(
        builder: (c) {
          ctx = c;
          return ProductTile(image: '', title: kit.name, imageWidth: 86, kit: kit, onTap: () {});
        },
      ),
    );
    await tester.longPress(find.byType(ProductTile));
    await tester.pump();
    expect(Marks.read(ctx).owned(kit), isTrue);
  });

  testWidgets('공식 예고 카드처럼 상품이 없으면 길게 눌러도 아무것도 안 함', (tester) async {
    await _show(tester, ProductTile(image: '', title: '예고', imageWidth: 120, onTap: () {}));
    await tester.longPress(find.byType(ProductTile));
    await tester.pump();
    expect(find.byType(SnackBar), findsNothing);
  });
}
