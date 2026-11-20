// 상세 수량(D-6 · D-7) — 아래 버튼 ×n · 길게 누르면 수량 시트 · 2 개 이상일 때만 화면 줄 · 조립 상태 줄 없음
// 데이터는 test/fixtures/sample-db.json (layout_test 의 가짜 Loaders)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/api.dart';
import 'package:hobby_atlas/clock.dart';
import 'package:hobby_atlas/data/user_store.dart';
import 'package:hobby_atlas/detail_pane.dart';
import 'package:hobby_atlas/marks.dart';
import 'package:hobby_atlas/models.dart';
import 'package:hobby_atlas/screens/d_kit_detail_screen.dart';
import 'package:hobby_atlas/screens/t_photo_screen.dart' show KitPhotoStrip;
import 'package:hobby_atlas/theme.dart';

import 'layout_test.dart' show db, fakeLoaders;

Kit _kit(String id) => Kit.fromJson((db['kits']! as List).firstWhere((k) => (k as Map)['id'] == id))!;

const _own = ValueKey('detail-own');
const _like = ValueKey('detail-like');
const _sheet = ValueKey('qty-sheet');
const _row = ValueKey('qty-row');

Future<void> _pump(WidgetTester tester, UserStore store, Kit kit) async {
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
      home: KitDetailScreen(
        kit: kit,
        loaders: Loaders(kits: fakeLoaders.kits, kitsByIds: fakeLoaders.kitsByIds),
      ),
    ),
  );
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Finder _in(Key key, Finder f) => find.descendant(of: find.byKey(key), matching: f);

void main() {
  fixedNow = DateTime(2026, 10, 25, 21);

  testWidgets('구매함 1 개: 버튼에 ×1 · 수량 줄 없음 · 조립 상태 줄 없음 · 내 사진 줄은 있다', (tester) async {
    final store = UserStore.memory()..setStatus('gu01', CollectStatus.owned);
    await _pump(tester, store, _kit('gu01'));
    expect(_in(_own, find.textContaining('×1')), findsOneWidget);
    expect(_in(_like, find.textContaining('×')), findsNothing);
    expect(find.byKey(_row), findsNothing);
    expect(find.byIcon(Icons.construction), findsNothing); // 조립 중 칸
    expect(find.byKey(const ValueKey('paint-gu01')), findsNothing);
    expect(find.byType(KitPhotoStrip), findsOneWidget);
  });

  testWidgets('구매함 길게 누르기 → 수량 시트에서 + → 2 개면 화면에 수량 줄', (tester) async {
    final store = UserStore.memory()..setStatus('gu01', CollectStatus.owned);
    await _pump(tester, store, _kit('gu01'));
    await tester.longPress(find.byKey(_own));
    await _settle(tester);
    expect(find.byKey(_sheet), findsOneWidget);
    expect(store.statusOf('gu01'), CollectStatus.owned); // 길게 누르기는 켜고 끄지 않는다
    await tester.tap(_in(_sheet, find.byIcon(Icons.add)));
    await _settle(tester);
    expect(store.quantityOf('gu01'), 2);
    expect(tester.widget<Text>(_in(_sheet, find.byKey(const ValueKey('kit-qty')))).data, '2');
    Navigator.of(tester.element(find.byKey(_sheet))).pop();
    await _settle(tester);
    expect(_in(_own, find.textContaining('×2')), findsOneWidget);
    expect(find.byKey(_row), findsOneWidget);
    // 줄에서 − → 1 개가 되면 줄은 사라진다
    await tester.tap(_in(_row, find.byIcon(Icons.remove)));
    await _settle(tester);
    expect(store.quantityOf('gu01'), 1);
    expect(find.byKey(_row), findsNothing);
  });

  testWidgets('수량은 99 까지: 시트의 + 는 99 에서 멈춘다', (tester) async {
    final store = UserStore.memory()
      ..setStatus('gu01', CollectStatus.owned)
      ..setQuantity('gu01', 99);
    await _pump(tester, store, _kit('gu01'));
    await tester.longPress(find.byKey(_own));
    await _settle(tester);
    await tester.tap(_in(_sheet, find.byIcon(Icons.add)));
    await _settle(tester);
    expect(store.quantityOf('gu01'), 99);
  });

  testWidgets('좋아요도 같은 규칙: ×n · 길게 누르면 시트 · 꺼진 구매함은 길게 눌러도 아무것도 없다', (tester) async {
    final store = UserStore.memory()..setStatus('gu03', CollectStatus.wanted);
    await _pump(tester, store, _kit('gu03'));
    expect(_in(_like, find.textContaining('×1')), findsOneWidget);
    expect(_in(_own, find.textContaining('×')), findsNothing);
    await tester.longPress(find.byKey(_own));
    await _settle(tester);
    expect(find.byKey(_sheet), findsNothing);
    expect(store.statusOf('gu03'), CollectStatus.wanted);
    await tester.longPress(find.byKey(_like));
    await _settle(tester);
    await tester.tap(_in(_sheet, find.byIcon(Icons.add)));
    await _settle(tester);
    expect(store.quantityOf('gu03'), 2);
  });
}
