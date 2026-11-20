// 건담 도감 화면: 왼쪽 묶음 목록(시대 · 작품) → 오른쪽 기체 칸 → 기체 시트(상품 전부 · ♡ · 구매함) · 도감 필터 · 화수별 보기
// · 묶음 목록 펴기 · 접기(검색 탭과 따로 기억) · 작품 도감 화면(같은 틀, 그 작품을 고른 채로). 레벨 막대 · 수집 n / m 없음
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/api.dart';
import 'package:hobby_atlas/data/user_store.dart';
import 'package:hobby_atlas/detail_pane.dart';
import 'package:hobby_atlas/level.dart' show LevelBar;
import 'package:hobby_atlas/widgets.dart';
import 'package:hobby_atlas/marks.dart';
import 'package:hobby_atlas/models.dart';
import 'package:hobby_atlas/screens/g_guide_view.dart';
import 'package:hobby_atlas/screens/guide/guide_parts.dart';
import 'package:hobby_atlas/theme.dart';

import 'support/atlas_fixture.dart';

Future<void> _settle(WidgetTester t, [int n = 6]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _pumpBody(WidgetTester t, Widget body) async {
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
      home: body,
    ),
  );
  await _settle(t);
}

Future<void> _pumpGuide(WidgetTester t, {GuideFilterController? filter, String query = ''}) => _pumpBody(
  t,
  Scaffold(
    body: GuideView(
      channel: 'gundam',
      myChannels: const ['gundam'],
      onPickChannel: (_) {},
      loaders: const Loaders(),
      filter: filter,
      query: query,
    ),
  ),
);

/// 왼쪽 묶음 목록 안의 줄 (오른쪽 머리 줄에도 같은 작품 이름이 있다)
Finder _dir(String label) => find.descendant(of: find.byKey(guideDirKey), matching: find.text(label));

/// 오른쪽 기체 칸의 단계
CellTier _tier(WidgetTester t, String name) =>
    t.widget<GuideCell>(find.ancestor(of: find.text(name), matching: find.byType(GuideCell))).tier;

/// 첫 줄 기체 칸 수
int _firstRow(WidgetTester t) {
  final ys = [for (final e in find.byType(GuideCell).evaluate()) t.getTopLeft(find.byWidget(e.widget)).dy];
  final top = ys.reduce((a, b) => a < b ? a : b);
  return ys.where((y) => (y - top).abs() < 1).length;
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

  testWidgets('묶음 목록의 작품 → 오른쪽 기체 칸 → 기체 시트: 상품 전부 · ♡ · 구매함 → 칸이 켜진다', (t) async {
    await _pumpGuide(t);
    // G-3 시대 머리 + 작품 줄 (검색 탭 종류 · 세대와 같은 틀) — 레벨 막대 · 수집 n / m 없음
    expect(find.byKey(guideDirKey), findsOneWidget);
    expect(find.byKey(const ValueKey('guide-era-코즈믹 에라')), findsOneWidget); // 시대 머리
    expect(_dir('SEED'), findsOneWidget);
    expect(find.byType(LevelBar), findsNothing);
    expect(find.textContaining('수집'), findsNothing);
    await t.tap(_dir('SEED'));
    await _settle(t);

    // G-4 기체 칸 — SEED 에는 GN- · V2 · 빌드 기체가 없다
    expect(find.text('스트라이크 건담'), findsOneWidget);
    expect(find.text('건담 엑시아'), findsNothing);
    expect(find.text('V2 건담'), findsNothing);
    expect(find.textContaining('수집'), findsNothing);

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
    await t.tap(find.byTooltip('구매함').first);
    await _settle(t, 2);
    expect(me.statusOf('hg-strike'), CollectStatus.owned);

    // 시트를 닫으면 칸이 바로 켜져 있다 (민트 테두리 + 리본), 고른 작품은 그대로
    await t.tapAt(const Offset(195, 40));
    await _settle(t);
    expect(_tier(t, '스트라이크 건담'), CellTier.owned);
    expect(_tier(t, '듀얼 건담'), CellTier.none);

    // 상품 시트에서 상품 상세로
    await t.tap(find.text('듀얼 건담'));
    await _settle(t);
    await t.tap(find.text('HG 스트라이크 & 듀얼 세트'));
    await _settle(t);
    expect(find.text('이 기체의 상품'), findsNothing); // 시트는 닫히고 상세가 열린다
    await t.pump(const Duration(seconds: 3)); // 토스트 · 저장 타이머
  });

  testWidgets('칸의 리본 +(구매함): 상품 없는 gget 기체는 손으로 켜기 · 다시 누르면 끄기', (t) async {
    await _pumpGuide(t);
    await t.tap(_dir('SEED'));
    await _settle(t);
    final cells = find.byType(GuideCell);
    expect(find.descendant(of: cells, matching: find.byIcon(Icons.add)), findsWidgets);
    expect(find.descendant(of: cells, matching: find.byIcon(Icons.favorite_border)), findsWidgets);
    // 프리덤 = 카탈로그 상품 없음 → 리본 + = 손으로 켜기 (칸 순서: 스트라이크 · 듀얼 · 프리덤)
    await t.tap(find.descendant(of: cells.at(2), matching: find.byIcon(Icons.add)));
    await _settle(t, 2);
    expect(me.guideManualLit, contains(1300004200));
    expect(t.widget<GuideCell>(cells.at(2)).tier, CellTier.owned);
    // 구매함이면 리본 ✓ · 토스트에 되돌리기
    expect(find.descendant(of: cells.at(2), matching: find.byIcon(Icons.check)), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
    // 다시 누르면 끄기
    await t.tap(find.descendant(of: cells.at(2), matching: find.byIcon(Icons.check)));
    await _settle(t, 2);
    expect(me.guideManualLit, isNot(contains(1300004200)));
    expect(t.widget<GuideCell>(cells.at(2)).tier, isNot(CellTier.owned));
    await t.pump(const Duration(seconds: 3));
  });

  testWidgets('도감 필터: 묶음 목록(작품)과 기체 칸이 같은 조건', (t) async {
    me.setStatus('ex-archangel', CollectStatus.owned);
    final ctrl = GuideFilterController();
    await _pumpGuide(t, filter: ctrl);
    // 도감 필터 재료 = 지금 작품들
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
    expect(_dir('SEED'), findsOneWidget);
    expect(_dir('00'), findsNothing);

    // 남은 작품이 하나라 바로 그 작품 — 기체 칸도 켜진 것만
    expect(find.text('아크엔젤'), findsOneWidget);
    expect(find.text('스트라이크 건담'), findsNothing);
    await t.pump(const Duration(seconds: 3));
  });

  testWidgets('화수별 보기: gundam-chapters 가 있으면 머리 줄 단추 → 장마다 칸, 다시 누르면 모아 보기', (t) async {
    await _pumpGuide(t);
    await t.tap(_dir('SEED'));
    await _settle(t);
    expect(find.byIcon(Icons.format_list_numbered), findsOneWidget);
    await t.tap(find.byIcon(Icons.format_list_numbered));
    await _settle(t);
    expect(find.text('1–3화 · 그 이름은 건담'), findsOneWidget);
    expect(find.text('5화 · 페이즈 시프트 다운'), findsOneWidget);
    expect(find.textContaining('수집'), findsNothing); // 장 머리 · 머리 줄 모두 숫자 없음
    await t.tap(find.byIcon(Icons.grid_view_outlined));
    await _settle(t);
    expect(find.text('1–3화 · 그 이름은 건담'), findsNothing);
  });

  testWidgets('화수 데이터가 아직 없으면(404) 화수별 단추가 없다', (t) async {
    loadAtlasFixture(chapters: false);
    await _pumpGuide(t);
    await t.tap(_dir('SEED'));
    await _settle(t);
    expect(find.text('스트라이크 건담'), findsOneWidget);
    expect(find.byIcon(Icons.format_list_numbered), findsNothing);
  });

  testWidgets('찾기: 기체 이름으로 작품을 찾고, 작품 안에서도 그 말로 거른다', (t) async {
    await _pumpGuide(t, query: '듀얼');
    expect(_dir('SEED'), findsOneWidget);
    expect(_dir('건담 빌드 파이터즈'), findsOneWidget);
    expect(_dir('기동전사 건담'), findsNothing);
    await t.tap(_dir('SEED'));
    await _settle(t);
    expect(find.text('듀얼 건담'), findsOneWidget);
    expect(find.text('스트라이크 건담'), findsNothing);
  });

  testWidgets('묶음 목록 펴기 · 접기: 펴면 한 줄 3칸 · 접으면 4칸, 검색 탭(browse_dir_open)과 따로 기억', (t) async {
    await _pumpGuide(t);
    await t.tap(_dir('SEED'));
    await _settle(t);
    expect(_firstRow(t), 3);
    final browseBefore = me.browseDirOpen;

    // ≡ 손잡이 → 접힘 (240ms 애니메이션)
    await t.tap(find.byKey(guideDirHandleKey));
    await t.pumpAndSettle();
    expect(find.byKey(guideDirKey), findsNothing);
    expect(_firstRow(t), 4);
    expect(me.browseDirOpen, browseBefore);
    expect(guideDirOpen(t.element(find.byType(GuideView))), isFalse);
    expect(me.guideDirOpen, isFalse);
    expect(me.toJson()['local_state'], containsPair('guide_dir_open', false)); // 기기에 기억

    // 다시 열어도 접힌 채로, 오른쪽으로 밀면 펴짐
    await _pumpGuide(t);
    expect(find.byKey(guideDirKey), findsNothing);
    await t.drag(find.byType(CustomScrollView), const Offset(160, 0));
    await t.pumpAndSettle();
    expect(find.byKey(guideDirKey), findsOneWidget);
    expect(guideDirOpen(t.element(find.byType(GuideView))), isTrue);
    expect(me.toJson()['local_state'], isNot(contains('guide_dir_open'))); // 처음 값은 적지 않는다 (골든 그대로)
    await t.pump(const Duration(seconds: 1)); // 기기 저장 타이머
  });

  testWidgets('작품 도감 화면: 같은 묶음 목록 + 기체 칸, 그 작품을 고른 채로 · 위 줄 찾기', (t) async {
    const seed = GuideWork(id: 'seed', section: '코즈믹 에라', name: '기동전사 건담 SEED', image: '', total: 5, owned: 0);
    await _pumpBody(t, const WorkGuideScreen(work: seed, loaders: Loaders()));
    expect(find.byKey(guideDirKey), findsOneWidget);
    expect(find.text('스트라이크 건담'), findsOneWidget); // 첫 작품이 아니라 SEED
    expect(find.byKey(const ValueKey('guide-share')), findsOneWidget);
    expect(find.textContaining('수집'), findsNothing);
    expect(find.byType(LevelBar), findsNothing);

    await t.enterText(find.byType(TextField), '듀얼');
    await _settle(t);
    expect(find.text('듀얼 건담'), findsOneWidget);
    expect(find.text('스트라이크 건담'), findsNothing);
  });
}
