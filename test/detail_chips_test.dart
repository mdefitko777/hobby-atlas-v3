// 상세 정가 아래 작은 버튼 줄(D-5a) — 적은 것이 없으면 칩 한 줄, 적으면 그 줄 (시세 D-5b · 구매가 D-5c · 예약 D-5g)
// 데이터는 test/fixtures/sample-db.json (layout_test 의 가짜 Loaders)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/api.dart';
import 'package:hobby_atlas/clock.dart';
import 'package:hobby_atlas/data/user_store.dart';
import 'package:hobby_atlas/detail_pane.dart';
import 'package:hobby_atlas/l10n/l10n.dart';
import 'package:hobby_atlas/logic/preorder.dart';
import 'package:hobby_atlas/marks.dart';
import 'package:hobby_atlas/models.dart';
import 'package:hobby_atlas/screens/d_kit_detail_screen.dart';
import 'package:hobby_atlas/theme.dart';
import 'package:hobby_atlas/widgets.dart';

import 'layout_test.dart' show db, fakeLoaders;

Kit _kit(String id) => Kit.fromJson((db['kits']! as List).firstWhere((k) => (k as Map)['id'] == id))!;

const _chips = ValueKey('detail-chips');
const _market = ValueKey('chip-market');
const _preorder = ValueKey('chip-preorder');
const _paid = ValueKey('chip-paid');

Future<void> _pump(WidgetTester tester, UserStore store, Kit kit, {Size size = const Size(390, 844)}) async {
  tester.view.physicalSize = size;
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
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Finder _in(ValueKey<String> key, Finder f) => find.descendant(of: find.byKey(key), matching: f);

void main() {
  fixedNow = DateTime(2026, 10, 25, 21);

  testWidgets('좋아요 · 예약 없음: 시세 · 예약 칩이 한 줄, 빈 예약 줄은 없다', (tester) async {
    final store = UserStore.memory();
    await _pump(tester, store, _kit('gu03'));
    expect(find.byKey(_chips), findsOneWidget);
    expect(find.byKey(_market), findsOneWidget);
    expect(find.byKey(_preorder), findsOneWidget);
    expect(find.byKey(_paid), findsNothing);
    expect(find.byKey(const ValueKey('preorder-row')), findsNothing);
    expect(tester.getTopLeft(find.byKey(_market)).dy, tester.getTopLeft(find.byKey(_preorder)).dy);
    // 칩을 누르면 전과 같은 예약 시트
    await tester.tap(find.byKey(_preorder));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pre-shop')), findsOneWidget);
  });

  testWidgets('예약을 적었으면 예약 줄 · 칩은 시세만', (tester) async {
    final store = UserStore.memory()..putPreorder('gu03', const Preorder(shop: '동네 샵', price: 8800));
    await _pump(tester, store, _kit('gu03'));
    expect(find.byKey(const ValueKey('preorder-row')), findsOneWidget);
    expect(find.byKey(_preorder), findsNothing);
    expect(find.byKey(_market), findsOneWidget);
  });

  testWidgets('구매함 · 구매가 없음: 구매가 칩 → 입력 시트, 구매가 줄은 없다', (tester) async {
    final store = UserStore.memory()..setStatus('gu06', CollectStatus.owned);
    await _pump(tester, store, _kit('gu06'));
    expect(find.byKey(_paid), findsOneWidget);
    expect(find.byKey(_preorder), findsNothing, reason: '구매함은 예약 칸이 없다');
    expect(find.byKey(const ValueKey('paid-row')), findsNothing);
    await tester.tap(find.byKey(_paid));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('구매함 · 구매가 있음: 구매가 줄 · 칩 없음', (tester) async {
    final store = UserStore.memory();
    await _pump(tester, store, _kit('gu01')); // 구매함 · 41,000원
    expect(find.byKey(const ValueKey('paid-row')), findsOneWidget);
    expect(find.byKey(_paid), findsNothing);
  });

  testWidgets('시세는 그래프 아이콘 — ↗ 는 공식 링크에만', (tester) async {
    await _pump(tester, UserStore.memory(), _kit('gu03'));
    expect(_in(_market, find.byIcon(marketIcon)), findsOneWidget);
    expect(marketIcon, isNot(Icons.north_east));
    expect(_in(_chips, find.byIcon(Icons.north_east)), findsNothing);
    expect(find.byIcon(Icons.north_east), findsWidgets); // 아래 고정 바 「공식」
    expect(detailHelp.where((h) => h.icon == marketIcon), hasLength(1));
  });

  for (final lang in AppLang.values) {
    testWidgets('360 dp 에서 넘치지 않는다 · 칩은 한 줄 (${lang.name})', (tester) async {
      L10n.debugSet(lang);
      addTearDown(() => L10n.debugSet(AppLang.ko));
      const narrow = Size(360, 780);
      await _pump(tester, UserStore.memory(), _kit('gu03'), size: narrow);
      expect(tester.takeException(), isNull);
      expect(tester.getTopLeft(find.byKey(_market)).dy, tester.getTopLeft(find.byKey(_preorder)).dy);
      await _pump(tester, UserStore.memory()..setStatus('gu06', CollectStatus.owned), _kit('gu06'), size: narrow);
      expect(tester.takeException(), isNull);
      expect(tester.getTopLeft(find.byKey(_market)).dy, tester.getTopLeft(find.byKey(_paid)).dy);
    });
  }
}
