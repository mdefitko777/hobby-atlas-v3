// 화면: 조립 상태(컬렉션 F-2b · F-5c, 상세에는 없음) · 예약(상세 D-5g, 컬렉션 예약 탭 F-5d, 캘린더 H-9b · H-9c) ·
// 재판매(상세 D-5h, 캘린더) · 바코드 겹침 시트(E-6b) · 공유 카드(V)
// 데이터는 test/fixtures/sample-db.json (layout_test 의 가짜 Loaders) + 재판매만 가짜 묶음
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/api.dart';
import 'package:hobby_atlas/clock.dart';
import 'package:hobby_atlas/data/user_store.dart';
import 'package:hobby_atlas/detail_pane.dart';
import 'package:hobby_atlas/logic/build_status.dart';
import 'package:hobby_atlas/logic/preorder.dart';
import 'package:hobby_atlas/logic/restock.dart';
import 'package:hobby_atlas/marks.dart';
import 'package:hobby_atlas/models.dart';
import 'package:hobby_atlas/screens/d_kit_detail_screen.dart';
import 'package:hobby_atlas/screens/f_collection_screen.dart';
import 'package:hobby_atlas/screens/h_calendar_screen.dart';
import 'package:hobby_atlas/screens/i_profile_screen.dart';
import 'package:hobby_atlas/theme.dart';
import 'package:hobby_atlas/widgets.dart';

import 'layout_test.dart' show db, fakeLoaders;

final _restocks = RestockIndex.parse({
  'events': [
    {'kit_id': 'gu03', 'date': '2026-10-30', 'kind': 'pb_resale', 'source_url': 'https://p-bandai.jp/item/1/'},
    {'kit_id': 'gu03', 'date': '2024-01', 'kind': 'retail_resale', 'quiet': true},
    {'kit_id': 'gu01', 'date': '2026-10', 'kind': 'lottery'}, // 구매함 상품 → 캘린더에는 안 나온다 (좋아요만)
  ],
});

Loaders _loaders({RestockIndex? restocks}) => Loaders(
  kits: fakeLoaders.kits,
  collection: fakeLoaders.collection,
  kitsByIds: fakeLoaders.kitsByIds,
  worlds: fakeLoaders.worlds,
  guideWorks: fakeLoaders.guideWorks,
  guideUnits: fakeLoaders.guideUnits,
  bbxTops: fakeLoaders.bbxTops,
  announcements: fakeLoaders.announcements,
  profile: fakeLoaders.profile,
  notifications: fakeLoaders.notifications,
  guideChapters: (_) async => const [],
  restocks: () async => restocks ?? RestockIndex.empty,
  guideIndex: fakeLoaders.guideIndex, // 컬렉션 줄 부제의 건담 작품 이름
);

Kit _kit(String id) => Kit.fromJson((db['kits']! as List).firstWhere((k) => (k as Map)['id'] == id))!;

Future<void> _pump(WidgetTester tester, UserStore store, Widget home, {Size size = const Size(390, 844)}) async {
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
      home: home,
    ),
  );
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  fixedNow = DateTime(2026, 10, 25, 21);

  group('컬렉션', () {
    Widget screen() => Scaffold(
      body: CollectionScreen(
        myChannels: const ['gundam'],
        onMyChannelsChanged: (_) {},
        onGoSearch: () {},
        loaders: _loaders(),
      ),
    );

    testWidgets('구매함 탭: 조립 거르기 · 단계 버튼 없음 · 탭에 수 없음 · 합계는 목록 맨 끝', (tester) async {
      final store = UserStore.memory();
      await _pump(tester, store, screen());
      expect(find.byKey(const ValueKey('tab-preorder')), findsNothing); // 예약이 없으면 탭도 없다
      for (final t in ['tab-liked', 'tab-owned']) {
        expect(tester.widget<UnderlineTab>(find.byKey(ValueKey(t))).count, isNull);
      }
      await tester.tap(find.byKey(const ValueKey('tab-owned')));
      await _settle(tester);
      final owned = _kit('gu01');
      expect(find.byKey(const ValueKey('build-filter')), findsNothing);
      expect(find.byKey(ValueKey('build-${owned.id}')), findsNothing);
      final sum = find.byKey(const ValueKey('list-summary'));
      await tester.scrollUntilVisible(sum, 200, scrollable: find.byType(Scrollable).first);
      expect(
        tester.getTopLeft(sum).dy,
        greaterThan(tester.getTopLeft(find.text(owned.name, skipOffstage: false)).dy),
      ); // 줄들 다음
      expect(tester.takeException(), isNull);
    });

    testWidgets('예약 탭: 예약이 있으면 나타나고 결제 예정 금액을 보인다 · 좋아요 줄엔 예약 꼬리표', (tester) async {
      final store = UserStore.memory()
        ..putPreorder('gu03', const Preorder(shop: '프리미엄 반다이', price: 10000, deposit: 2000, arrival: '2026-11'));
      await _pump(tester, store, screen());
      expect(find.text('예약'), findsWidgets); // 좋아요 줄의 꼬리표 + 탭
      await tester.tap(find.byKey(const ValueKey('tab-preorder')));
      await _settle(tester);
      expect(find.text('결제 예정 8,000원'), findsOneWidget);
      expect(find.textContaining('2026.11 도착'), findsOneWidget);
      expect(find.text(_kit('gu04').name), findsNothing); // 예약 없는 좋아요는 빠진다
    });
  });

  group('상세', () {
    testWidgets('좋아요 상품: 예약 적기 → 도착 → 구매함으로 (예약 총액 = 내 구매가)', (tester) async {
      final store = UserStore.memory();
      final k = _kit('gu03');
      await _pump(tester, store, KitDetailScreen(kit: k, loaders: _loaders()));
      // 예약이 없으면 줄 대신 정가 아래 작은 버튼 「예약 적기」
      expect(find.byKey(const ValueKey('preorder-row')), findsNothing);
      final chip = find.byKey(const ValueKey('chip-preorder'));
      await tester.scrollUntilVisible(chip, 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(chip);
      await _settle(tester);
      await tester.enterText(find.byKey(const ValueKey('pre-shop')), '동네 샵');
      await tester.enterText(find.byKey(const ValueKey('pre-price')), '8800');
      await tester.enterText(find.byKey(const ValueKey('pre-arrival')), '2026.12');
      await tester.tap(find.text('저장'));
      await _settle(tester);
      final p = store.preorderOf(k.id)!;
      expect(p.shop, '동네 샵');
      expect(p.price, 8800);
      expect(p.arrival, '2026-12');
      expect(find.textContaining('동네 샵 · 8,800원 · 2026.12 도착 · 미결제'), findsOneWidget);
      // 상세 위 뒤로 · ? 버튼은 내용 위에 떠 있다 → 화면 가운데로 굴린 뒤 누른다
      await Scrollable.ensureVisible(tester.element(find.byKey(const ValueKey('preorder-arrived'))), alignment: 0.5);
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('preorder-arrived')));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('arrived-to-owned')));
      await _settle(tester);
      expect(store.statusOf(k.id), CollectStatus.owned);
      expect(store.entry(k.id)!['purchase_price'], 8800);
      expect(store.preorderOf(k.id), isNull);
    });

    testWidgets('구매함 상품: 예약 칸 없음 · 조립 상태 칸 없음 (적어 둔 기록은 그대로)', (tester) async {
      final k = _kit('gu01');
      final store = UserStore.memory()..setBuild(k.id, stage: BuildStage.building, painted: true);
      await _pump(tester, store, KitDetailScreen(kit: k, loaders: _loaders()));
      expect(find.byKey(const ValueKey('preorder-row')), findsNothing);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
      await _settle(tester);
      expect(find.byIcon(Icons.construction), findsNothing); // 조립 중 칸
      expect(find.byKey(ValueKey('paint-${k.id}')), findsNothing);
      expect(store.stageOf(k.id), BuildStage.building);
      expect(store.buildOf(k.id).painted, isTrue);
    });

    testWidgets('재판매: 꼬리표 + 소식 줄 (지난 것도 줄에는) · 파일이 없으면 숨김', (tester) async {
      final k = _kit('gu03');
      await _pump(
        tester,
        UserStore.memory(),
        KitDetailScreen(
          kit: k,
          loaders: _loaders(restocks: _restocks),
        ),
      );
      expect(find.widgetWithText(SoftTag, '재판매'), findsOneWidget);
      final list = find.byKey(const ValueKey('restock-list'));
      await tester.scrollUntilVisible(list, 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('2026.10.30'), findsOneWidget);
      expect(find.text('PB 재판매'), findsOneWidget);
      expect(find.text('2024.01'), findsOneWidget);

      await _pump(tester, UserStore.memory(), KitDetailScreen(key: UniqueKey(), kit: k, loaders: _loaders()));
      expect(find.widgetWithText(SoftTag, '재판매'), findsNothing);
      expect(find.byKey(const ValueKey('restock-list')), findsNothing);
    });
  });

  testWidgets('캘린더 내 일정: 예약 도착 · 이번 달 결제 예정 · 좋아요 상품 재판매', (tester) async {
    final store = UserStore.memory()
      ..putPreorder('gu03', const Preorder(shop: 'PB', price: 12000, deposit: 2000, arrival: '2026-10-28'))
      ..putPreorder('gu04', const Preorder(price: 5000, paid: true, arrival: '2026-10'));
    await _pump(
      tester,
      store,
      Scaffold(
        body: CalendarScreen(
          myChannels: const ['gundam'],
          onMyChannelsChanged: (_) {},
          loaders: _loaders(restocks: _restocks),
        ),
      ),
    );
    await tester.tap(find.text('내 일정'));
    await _settle(tester);
    // 예약 도착 · 재판매는 줄 둘째 줄의 상태 글 (알약 없이)
    final restock = find.textContaining(RegExp('^재판매 · '), skipOffstage: false);
    await tester.scrollUntilVisible(restock, 200, scrollable: find.byType(Scrollable).first);
    expect(restock, findsOneWidget); // gu03 (좋아요) 만, gu01(구매함) 추첨은 아님
    expect(find.textContaining(RegExp('^예약 · '), skipOffstage: false), findsNWidgets(2)); // 10.28 도착 · 날짜 미정(10월 중)
    // 이번 달 결제 예정은 목록 맨 끝
    final due = find.byKey(const ValueKey('month-due'));
    await tester.scrollUntilVisible(due, 200, scrollable: find.byType(Scrollable).first);
    expect(find.descendant(of: due, matching: find.text('10,000원')), findsOneWidget);
    expect(find.descendant(of: due, matching: find.text('1')), findsOneWidget); // 1건
  });

  testWidgets('바코드 겹침: 갖고 있는 상품이면 수량 시트 (조립 상태는 보이지 않음), 다시 찍기 = false', (tester) async {
    final store = UserStore.memory()
      ..setStatus('gu01', CollectStatus.owned)
      ..setQuantity('gu01', 2)
      ..setBuild('gu01', stage: BuildStage.building);
    bool? result;
    await _pump(
      tester,
      store,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await warnIfCollected(context, [_kit('gu06'), _kit('gu01')]),
            child: const Text('scan'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('scan'));
    await _settle(tester);
    expect(find.byKey(const ValueKey('scan-dup')), findsOneWidget);
    expect(find.text('이미 구매함에 있어요 ×2'), findsOneWidget);
    expect(find.text('조립 중'), findsNothing); // 기록은 있어도 화면에서 뺐다 (2026-11-20)
    await tester.tap(find.text('다시 찍기'));
    await _settle(tester);
    expect(result, isFalse);

    // 겹치는 것이 없으면 시트 없이 바로 true
    result = null;
    store.setStatus('gu01', CollectStatus.none);
    await tester.tap(find.text('scan'));
    await _settle(tester);
    expect(find.byKey(const ValueKey('scan-dup')), findsNothing);
    expect(result, isTrue);
  });

  testWidgets('작은 폰(320): 구매함 탭 · 예약 탭 · 내 정보 금액 줄이 넘치지 않는다', (tester) async {
    final store = UserStore.memory()..putPreorder('gu03', const Preorder(shop: '아주 긴 가게 이름 프리미엄 반다이', price: 123456));
    const small = Size(320, 568);
    await _pump(
      tester,
      store,
      Scaffold(
        body: CollectionScreen(
          myChannels: const ['gundam'],
          onMyChannelsChanged: (_) {},
          onGoSearch: () {},
          loaders: _loaders(),
        ),
      ),
      size: small,
    );
    for (final t in ['tab-owned', 'tab-preorder']) {
      await tester.tap(find.byKey(ValueKey(t)));
      await _settle(tester);
      expect(tester.takeException(), isNull);
    }
    await _pump(
      tester,
      store,
      ProfileScreen(loaders: _loaders(), onJump: (_) {}),
      size: small,
    );
    // 예약 금액 = 기다리는 예약의 결제 예정 합 (컬렉션 예약 목록 끝과 같은 셈)
    expect(
      find.descendant(of: find.byKey(const ValueKey('profile-preorder')), matching: find.text('123,456원')),
      findsOneWidget,
    );
    expect(find.byTooltip('미조립'), findsNothing); // 미조립 칸은 뺐다 (2026-11-20)
    expect(tester.takeException(), isNull);
  });

  group('공유 카드', () {
    testWidgets('컬렉션 카드: 숫자 · 워터마크 "HA · @아이디" · PNG 로 찍힘', (tester) async {
      final key = GlobalKey();
      await _pump(
        tester,
        UserStore.memory(),
        Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: key,
              child: const CollectionShareCard(
                avatar: SizedBox.square(dimension: 56),
                name: '냥이',
                handle: 'nyang',
                liked: 3,
                owned: 7,
                preorders: 1,
                thumbs: ['', '', ''],
              ),
            ),
          ),
        ),
      );
      expect(find.text('HA · @nyang'), findsOneWidget);
      expect(find.text('@nyang'), findsOneWidget);
      for (final n in ['3', '7', '1']) {
        expect(find.text(n), findsOneWidget);
      }
      final png = await tester.runAsync(() => captureCard(key, pixelRatio: 1));
      expect(png, isNotNull);
      expect(png!.sublist(1, 4), 'PNG'.codeUnits);
    });

    testWidgets('도감 카드: 켜진 칸 / 전체 · % · 아이디 없으면 HA · Hobby Atlas', (tester) async {
      await _pump(
        tester,
        UserStore.memory(),
        const Scaffold(
          body: Center(
            child: GuideShareCard(
              image: '',
              name: '기동전사 건담',
              handle: '',
              tiers: [CellTier.owned, CellTier.photo, CellTier.liked, CellTier.none],
            ),
          ),
        ),
      );
      expect(find.text('2 / 4'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('HA · Hobby Atlas'), findsOneWidget);
    });
  });
}
