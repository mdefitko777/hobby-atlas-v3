// 건담 도감 화면: 작품 카드 → 기체 칸 → 기체 시트(상품 전부 · ♡ · 구매함) · 도감 필터 · 화수별 보기
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/api.dart';
import 'package:hobby_atlas/data/user_store.dart';
import 'package:hobby_atlas/detail_pane.dart';
import 'package:hobby_atlas/widgets.dart';
import 'package:hobby_atlas/marks.dart';
import 'package:hobby_atlas/models.dart';
import 'package:hobby_atlas/screens/g_guide_view.dart';
import 'package:hobby_atlas/theme.dart';

import 'support/atlas_fixture.dart';

Future<void> _settle(WidgetTester t, [int n = 6]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _pumpGuide(WidgetTester t, {GuideFilterController? filter, String query = ''}) async {
  t.view.physicalSize = const Size(390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: buildGpTheme(),
      // 도감 계산(derive)이 보는 기록과 같은 한 벌
      builder: (context, child) => MarksHost(
        store: UserStore.instance,
        child: PaneHost(child: child!),
      ),
      home: Scaffold(
        body: GuideView(
          channel: 'gundam',
          myChannels: const ['gundam'],
          onPickChannel: (_) {},
          loaders: const Loaders(),
          filter: filter,
          query: query,
        ),
      ),
    ),
  );
  await _settle(t);
}

void main() {
  final me = UserStore.instance;
  setUp(loadAtlasFixture);
  tearDown(() {
    for (final id in fixtureKits.keys) {
      me.setStatus(id, CollectStatus.none);
    }
    for (final g in [...me.guideManualLit]) {
      me.setManualLit(g, false);
    }
  });

  testWidgets('작품 카드 → 기체 칸 → 기체 시트: 상품 전부 · ♡ · 구매함 → 칸이 켜진다', (t) async {
    await _pumpGuide(t);
    // G-3 시대 묶음 + 작품 카드
    expect(find.text('코즈믹 에라'), findsOneWidget);
    expect(find.text('기동전사 건담 SEED'), findsOneWidget);
    await t.tap(find.text('기동전사 건담 SEED'));
    await _settle(t);

    // G-4 기체 칸 — SEED 에는 GN- · V2 · 빌드 기체가 없다
    expect(find.text('수집 0 / 5'), findsOneWidget);
    expect(find.text('스트라이크 건담'), findsOneWidget);
    expect(find.text('건담 엑시아'), findsNothing);
    expect(find.text('V2 건담'), findsNothing);

    await t.tap(find.text('스트라이크 건담'));
    await _settle(t);
    // G-5 시트: 칸을 켜는 상품 4 + 관련(부품 · SD) 2
    expect(find.text('이 기체의 상품'), findsOneWidget);
    expect(find.text('HG 스트라이크 건담'), findsOneWidget);
    expect(find.text('ROBOT魂 스트라이크 건담'), findsOneWidget);
    expect(find.text('관련 상품'), findsOneWidget);
    expect(find.text('손으로 켜기'), findsOneWidget); // gget 기체

    // G-5a 첫 상품 ♡ → 좋아요, 리본 → 구매함
    await t.tap(find.byTooltip('좋아요').first);
    await _settle(t, 2);
    expect(me.statusOf('hg-strike'), CollectStatus.wanted);
    expect(find.text('좋아요'), findsWidgets);
    await t.tap(find.byTooltip('구매함').first);
    await _settle(t, 2);
    expect(me.statusOf('hg-strike'), CollectStatus.owned);

    // 시트를 닫으면 칸 · 수집 수가 바로 바뀌어 있다
    await t.tapAt(const Offset(195, 40));
    await _settle(t);
    expect(find.text('수집 1 / 5'), findsOneWidget);

    // 상품 시트에서 상품 상세로
    await t.tap(find.text('듀얼 건담'));
    await _settle(t);
    await t.tap(find.text('HG 스트라이크 & 듀얼 세트'));
    await _settle(t);
    expect(find.text('이 기체의 상품'), findsNothing); // 시트는 닫히고 상세가 열린다
    await t.pump(const Duration(seconds: 3)); // 토스트 · 저장 타이머
  });

  testWidgets('칸의 리본: 상품 없는 gget 기체는 손으로 켜기 (옛 기록과 같은 gget id)', (t) async {
    await _pumpGuide(t);
    await t.tap(find.text('기동전사 건담 SEED'));
    await _settle(t);
    // 프리덤 = 카탈로그 상품 없음 → 칸의 리본(구매함) = 손으로 켜기 (칸 순서: 스트라이크 · 듀얼 · 프리덤)
    t.widget<MarkOverlay>(find.byType(MarkOverlay).at(2)).onOwn();
    await _settle(t, 2);
    expect(me.guideManualLit, contains(1300004200));
    expect(find.text('수집 1 / 5'), findsOneWidget);
    await t.pump(const Duration(seconds: 3));
  });

  testWidgets('도감 필터: 작품 → 기체 칸으로 이어지고, 시트에서 상태 · 라인 · 정렬', (t) async {
    me.setStatus('ex-archangel', CollectStatus.owned);
    final ctrl = GuideFilterController();
    await _pumpGuide(t, filter: ctrl);
    // 작품 도감 필터 재료 = 지금 작품 카드
    expect(ctrl.pool.length, 6);
    unawaited(ctrl.openSheet(t.element(find.byType(GuideView)))); // 시트가 닫힐 때 끝난다
    await _settle(t, 3);
    expect(find.text('도감 필터'), findsOneWidget);
    await t.tap(find.byWidgetPredicate((w) => w is OwnedIcon).first); // 상태: 구매함
    await _settle(t, 2);
    expect(find.text('1개 보기'), findsOneWidget);
    await t.tap(find.text('1개 보기'));
    await _settle(t);
    expect(ctrl.filter.tier, GuideTier.owned);
    expect(find.text('기동전사 건담 SEED'), findsOneWidget);
    expect(find.text('기동전사 건담 00'), findsNothing);

    // 이어받은 조건 (구매함) — 기체 칸도 켜진 것만
    await t.tap(find.text('기동전사 건담 SEED'));
    await _settle(t);
    expect(find.text('아크엔젤'), findsOneWidget);
    expect(find.text('스트라이크 건담'), findsNothing);

    // 기체 칸 필터 시트: 초기화 → 등급 HG 만
    await t.tap(find.byTooltip('필터').last);
    await _settle(t, 3);
    await t.tap(find.text('초기화'));
    await t.tap(find.text('라인'));
    await _settle(t, 2);
    await t.tap(find.text('HG').last);
    await _settle(t, 2);
    expect(find.text('3개 보기'), findsOneWidget); // 스트라이크 · 듀얼 · 에일
    await t.tap(find.text('3개 보기'));
    await _settle(t);
    expect(find.text('스트라이크 건담'), findsOneWidget);
    expect(find.text('아크엔젤'), findsNothing);
    await t.pump(const Duration(seconds: 3));
  });

  testWidgets('화수별 보기: gundam-chapters 가 있으면 장마다 칸, 없으면 단추가 없다', (t) async {
    await _pumpGuide(t);
    await t.tap(find.text('기동전사 건담 SEED'));
    await _settle(t);
    expect(find.byTooltip('화수별'), findsOneWidget);
    await t.tap(find.byTooltip('화수별'));
    await _settle(t);
    expect(find.text('1–3화 · 그 이름은 건담'), findsOneWidget);
    expect(find.text('5화 · 페이즈 시프트 다운'), findsOneWidget);
    expect(find.textContaining('수집'), findsOneWidget); // 장 머리엔 숫자 없음 — 앱 바 하나만
  });

  testWidgets('화수 데이터가 아직 없으면(404) 화수별 단추가 없다', (t) async {
    loadAtlasFixture(chapters: false);
    await _pumpGuide(t);
    await t.tap(find.text('기동전사 건담 SEED'));
    await _settle(t);
    expect(find.text('스트라이크 건담'), findsOneWidget);
    expect(find.byTooltip('화수별'), findsNothing);
  });

  testWidgets('찾기: 기체 이름으로 작품을 찾고, 작품 안에서도 그 말로 거른다', (t) async {
    await _pumpGuide(t, query: '듀얼');
    expect(find.text('기동전사 건담 SEED'), findsOneWidget);
    expect(find.text('건담 빌드 파이터즈'), findsWidgets); // 공식 로고가 없어 그림 자리에도 이름
    expect(find.text('기동전사 건담'), findsNothing);
    await t.tap(find.text('기동전사 건담 SEED'));
    await _settle(t);
    expect(find.text('듀얼 건담'), findsOneWidget);
    expect(find.text('스트라이크 건담'), findsNothing);
  });
}
