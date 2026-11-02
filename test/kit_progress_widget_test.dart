// 화면: 조립 상태(컬렉션 F-2b · F-5c, 상세 D-5f) · 예약(상세 D-5g, 컬렉션 예약 탭 F-5d, 캘린더 H-9b · H-9c) ·
// 재판매(상세 D-5h, 캘린더) · 바코드 겹침 시트(E-6b) · 공유 카드(V)
// 데이터는 mock_server/db.json (layout_test 의 가짜 Loaders) + 재판매만 가짜 묶음
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
import 'package:hobby_atlas/screens/a_my_page.dart';
import 'package:hobby_atlas/screens/d_kit_detail_screen.dart';
import 'package:hobby_atlas/screens/f_collection_screen.dart';
import 'package:hobby_atlas/screens/h_calendar_screen.dart';
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

    testWidgets('구매함 탭: 조립 상태 거르기 · 줄의 단계 아이콘 누르면 다음 단계', (tester) async {
      final store = UserStore.memory();
      await _pump(tester, store, screen());
      expect(find.byKey(const ValueKey('tab-preorder')), findsNothing); // 예약이 없으면 탭도 없다
      await tester.tap(find.byKey(const ValueKey('tab-owned')));
      await _settle(tester);
      final owned = _kit('gu01');
      expect(find.byKey(const ValueKey('build-filter')), findsOneWidget);
      final allUnbuilt = find.textContaining('미조립 ');
      expect(allUnbuilt, findsWidgets); // 합계 줄 · 세그먼트
      await tester.tap(find.byKey(ValueKey('build-${owned.id}')));
      await _settle(tester);
      expect(store.stageOf(owned.id), BuildStage.building);
      // 조립 중만 → 그 상품 하나
      await tester.tap(find.text('조립 중 1'));
      await _settle(tester);
      expect(find.text(owned.name), findsOneWidget);
      expect(find.text(_kit('gu02').name), findsNothing);
      // 길게 누르면 시트 → 붓(도색)
      await tester.longPress(find.byKey(ValueKey('build-${owned.id}')));
      await _settle(tester);
      await tester.tap(find.byKey(ValueKey('paint-${owned.id}')));
      await _settle(tester);
      expect(store.buildOf(owned.id).painted, isTrue);
    });

    testWidgets('예약 탭: 예약이 있으면 나타나고 낼 돈을 보인다 · 좋아요 줄엔 예약 꼬리표', (tester) async {
      final store = UserStore.memory()
        ..putPreorder('gu03', const Preorder(shop: '프리미엄 반다이', price: 10000, deposit: 2000, arrival: '2026-11'));
      await _pump(tester, store, screen());
      expect(find.text('예약'), findsWidgets); // 좋아요 줄의 꼬리표 + 탭
      await tester.tap(find.byKey(const ValueKey('tab-preorder')));
      await _settle(tester);
      expect(find.text('낼 돈 8,000원'), findsOneWidget);
      expect(find.textContaining('2026.11 도착'), findsOneWidget);
      expect(find.text(_kit('gu04').name), findsNothing); // 예약 없는 좋아요는 빠진다
    });
  });

  group('상세', () {
    testWidgets('좋아요 상품: 예약 적기 → 도착 → 구매함으로 (예약 총액 = 내 구매가)', (tester) async {
      final store = UserStore.memory();
      final k = _kit('gu03');
      await _pump(tester, store, KitDetailScreen(kit: k, loaders: _loaders()));
      final row = find.byKey(const ValueKey('preorder-row'));
      await tester.scrollUntilVisible(row, 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('안 적음'), findsOneWidget);
      await tester.tap(row);
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

    testWidgets('구매함 상품: 조립 상태 세 칸 · 예약 칸 없음', (tester) async {
      final store = UserStore.memory();
      final k = _kit('gu01');
      await _pump(tester, store, KitDetailScreen(kit: k, loaders: _loaders()));
      expect(find.byKey(const ValueKey('preorder-row')), findsNothing);
      final done = find.text('완성');
      await tester.scrollUntilVisible(done, 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(done);
      await _settle(tester);
      expect(store.stageOf(k.id), BuildStage.built);
    });

    testWidgets('조립하지 않는 상품(인형 · 피규어): 조립 상태 칸이 없다', (tester) async {
      final store = UserStore.memory();
      final json =
          Map<String, Object?>.of(
              (db['kits']! as List).firstWhere((k) => (k as Map)['id'] == 'gu01') as Map<String, Object?>,
            )
            ..['type'] = '인형'
            ..['line'] = '봉제인형';
      final k = Kit.fromJson(json)!;
      expect(needsAssembly(k), isFalse);
      await _pump(tester, store, KitDetailScreen(kit: k, loaders: _loaders()));
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
      await _settle(tester);
      expect(find.text('조립 중'), findsNothing);
      expect(find.byKey(ValueKey('paint-${k.id}')), findsNothing);
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

  testWidgets('캘린더 내 일정: 예약 도착 · 이번 달 낼 돈 · 좋아요 상품 재판매', (tester) async {
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
    await tester.tap(find.byTooltip('내 일정'));
    await _settle(tester);
    expect(find.byKey(const ValueKey('month-due')), findsOneWidget);
    expect(find.text('10,000원'), findsOneWidget);
    expect(find.text(' · 1건'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('재판매'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('재판매'), findsOneWidget); // gu03 (좋아요) 만, gu01(구매함) 추첨은 아님
    expect(find.text('예약'), findsNWidgets(2)); // 10.28 도착 · 날짜 미정(10월 중)
  });

  testWidgets('바코드 겹침: 갖고 있는 상품이면 수량 · 조립 상태 시트, 다시 찍기 = false', (tester) async {
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
    expect(find.text('이미 갖고 있어요 ×2'), findsOneWidget);
    expect(find.text('조립 중'), findsOneWidget);
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

  testWidgets('작은 폰(320): 구매함 탭 · 예약 탭 · My Page 숫자 줄이 넘치지 않는다', (tester) async {
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
      Scaffold(
        body: SingleChildScrollView(child: MyPageView(loaders: _loaders())),
      ),
      size: small,
    );
    expect(find.byKey(const ValueKey('mypage-share')), findsOneWidget);
    expect(find.byTooltip('미조립'), findsOneWidget);
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
                backlog: 4,
                thumbs: ['', '', ''],
              ),
            ),
          ),
        ),
      );
      expect(find.text('HA · @nyang'), findsOneWidget);
      expect(find.text('@nyang'), findsOneWidget);
      for (final n in ['3', '7', '1', '4']) {
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
