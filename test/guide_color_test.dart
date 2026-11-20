// 도감 한 벌: 칸은 늘 컬러(흑백 · 흐림 없음) · 상태는 ♡ · 리본 표시로만 · 분류 칸 = 그림 + 이름(숫자 없음) · 도감 필터 = 상품 필터와 같은 상태 줄
// · 도감에 레벨 막대 · 수집 n / m 없음
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/api.dart';
import 'package:hobby_atlas/channels.dart';
import 'package:hobby_atlas/data/tag_atlas.dart';
import 'package:hobby_atlas/data/user_store.dart';
import 'package:hobby_atlas/detail_pane.dart';
import 'package:hobby_atlas/level.dart';
import 'package:hobby_atlas/marks.dart';
import 'package:hobby_atlas/models.dart';
import 'package:hobby_atlas/screens/c_channel_screen.dart' show allChannelId;
import 'package:hobby_atlas/screens/g_guide_view.dart';
import 'package:hobby_atlas/screens/guide/guide_parts.dart';
import 'package:hobby_atlas/screens/guide/work_guide_screen.dart' show workGuideHelp;
import 'package:hobby_atlas/screens/r_mezastar_screen.dart';
import 'package:hobby_atlas/theme.dart';
import 'package:hobby_atlas/widgets.dart';

import 'support/atlas_fixture.dart';

Future<void> _settle(WidgetTester t, [int n = 6]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _pump(WidgetTester t, Widget body, {double width = 390, UserStore? store}) async {
  t.view.physicalSize = Size(width, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: buildGpTheme(),
      builder: (context, child) => MarksHost(
        store: store ?? UserStore.instance,
        child: PaneHost(child: child!),
      ),
      home: Scaffold(body: body),
    ),
  );
  await _settle(t);
}

/// 흑백 · 흐림이 없다 (AppImage 의 흑백 = Opacity + ColorFiltered)
void _expectFullColour(WidgetTester t, Finder scope) {
  expect(find.descendant(of: scope, matching: find.byType(ColorFiltered)), findsNothing);
  for (final o in t.widgetList<Opacity>(find.descendant(of: scope, matching: find.byType(Opacity)))) {
    expect(o.opacity, 1);
  }
}

Finder _icon(Finder scope, IconData icon) => find.descendant(of: scope, matching: find.byIcon(icon));

GuideView _gundam({GuideFilterController? filter}) => GuideView(
  channel: 'gundam',
  myChannels: const ['gundam'],
  onPickChannel: (_) {},
  loaders: const Loaders(),
  filter: filter,
);

TagCard _tag(String id) => TagCard(
  id: id,
  tagId: id,
  game: TagGame.mezastar,
  region: 'KR',
  number: '1-1-001',
  name: '뮤츠',
  setIds: const ['s1'],
  image: 'assets/test/tag.png',
);

void main() {
  final me = UserStore.instance;
  setUp(loadAtlasFixture);
  tearDown(() {
    for (final id in fixtureKits.keys) {
      me.setStatus(id, CollectStatus.none);
    }
  });

  group('칸은 늘 컬러 · 상태는 표시로만', () {
    testWidgets('GuideCell: 아직 = 그림 그대로 · ♡ = 좋아요 · 리본 = 구매함 (보기만 하는 칸)', (t) async {
      Widget cell(CellTier tier, {bool liked = false}) => SizedBox(
        width: 100,
        height: 140,
        child: GuideCell(
          key: ValueKey('$tier'),
          image: 'assets/test/u.png',
          name: '칸',
          tier: tier,
          liked: liked,
          onTap: () {},
        ),
      );
      await _pump(
        t,
        Wrap(
          children: [cell(CellTier.none), cell(CellTier.liked), cell(CellTier.owned), cell(CellTier.none, liked: true)],
        ),
      );
      Finder at(CellTier tier) => find.byKey(ValueKey('$tier')).first;
      for (final tier in [CellTier.none, CellTier.liked, CellTier.owned]) {
        _expectFullColour(t, at(tier));
        // 이름도 흐리지 않는다
        expect(t.widget<Text>(find.descendant(of: at(tier), matching: find.text('칸'))).style?.color, Gp.ink);
      }
      expect(_icon(at(CellTier.none), Icons.favorite), findsNothing);
      expect(_icon(at(CellTier.none), Icons.check), findsNothing);
      expect(_icon(at(CellTier.liked), Icons.favorite), findsOneWidget);
      expect(_icon(at(CellTier.liked), Icons.check), findsNothing);
      expect(_icon(at(CellTier.owned), Icons.check), findsOneWidget); // 리본 ✓ (상품 사진과 같은 모양)
      expect(_icon(at(CellTier.owned), Icons.favorite), findsNothing);
      expect(_icon(find.byKey(const ValueKey('CellTier.none')).last, Icons.favorite), findsOneWidget); // liked 따로
      expect(t.takeException(), isNull);
    });

    testWidgets('누르는 칸은 상품 카드처럼 그림 위 리본 + · ♡ (구매함이면 ✓), 길게 누르기 없음', (t) async {
      var owns = 0;
      Widget cell(CellTier tier) => SizedBox(
        width: 100,
        height: 140,
        child: GuideCell(
          image: 'assets/test/u.png',
          name: '칸',
          tier: tier,
          liked: true,
          onTap: () {},
          onLike: () {},
          onOwn: () => owns++,
        ),
      );
      await _pump(t, cell(CellTier.owned));
      final o = t.widget<MarkOverlay>(find.byType(MarkOverlay));
      expect([o.liked, o.owned, o.onOwn], [isTrue, isTrue, isNotNull]);
      expect(find.byType(StatusMarks), findsNothing);
      expect(_icon(find.byType(GuideCell), Icons.check), findsOneWidget);
      expect(_icon(find.byType(GuideCell), Icons.add), findsNothing);
      _expectFullColour(t, find.byType(GuideCell));
      await t.tap(_icon(find.byType(GuideCell), Icons.check));
      expect(owns, 1);
      await t.longPress(find.byType(GuideCell));
      expect(owns, 1, reason: '길게 누르기는 구매함을 바꾸지 않는다');
      // 아직 칸: 리본 + · ♡
      await _pump(t, cell(CellTier.none));
      expect(_icon(find.byType(GuideCell), Icons.add), findsOneWidget);
      expect(_icon(find.byType(GuideCell), Icons.check), findsNothing);
      expect(_icon(find.byType(GuideCell), Icons.favorite), findsOneWidget);
      await t.tap(_icon(find.byType(GuideCell), Icons.add));
      expect(owns, 2);
    });

    testWidgets('작품 도감 기체 칸: 아무것도 없는 칸도 흑백이 아니다', (t) async {
      me.setStatus('hg-strike', CollectStatus.wanted);
      await _pump(t, _gundam());
      await t.tap(find.descendant(of: find.byKey(guideDirKey), matching: find.text('SEED')));
      await _settle(t);
      expect(find.byType(GuideCell), findsWidgets);
      _expectFullColour(t, find.byType(Scaffold).last);
      // 스트라이크 = 좋아요 → 칸의 ♡ 켜짐
      final strike = find.ancestor(of: find.text('스트라이크 건담'), matching: find.byType(GuideCell));
      expect(t.widget<MarkOverlay>(find.descendant(of: strike, matching: find.byType(MarkOverlay))).liked, isTrue);
      await t.pump(const Duration(seconds: 3));
    });

    testWidgets('태그 칸: 아직 · 좋아요 · 구매함 모두 컬러 · 이름 진하게 · 표시로 구별', (t) async {
      Widget cell(CollectStatus s) => SizedBox(
        width: 100,
        height: 160,
        child: TagCell(key: ValueKey(s), card: _tag('mz:$s'), status: s, onTap: () {}),
      );
      await _pump(t, Wrap(children: [for (final s in CollectStatus.values) cell(s)]));
      for (final s in CollectStatus.values) {
        final c = find.byKey(ValueKey(s));
        _expectFullColour(t, c);
        expect(t.widget<Text>(find.descendant(of: c, matching: find.text('뮤츠'))).style?.color, Gp.ink);
      }
      expect(_icon(find.byKey(const ValueKey(CollectStatus.none)), Icons.check), findsNothing);
      expect(_icon(find.byKey(const ValueKey(CollectStatus.wanted)), Icons.favorite), findsOneWidget);
      expect(_icon(find.byKey(const ValueKey(CollectStatus.owned)), Icons.check), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    test('도움말 글: 흑백 · 불 꺼짐 · 컬러 단계 말이 없다', () {
      final items = [...tierHelpItems(), ...workGuideHelp(), ...tagHelp()].map((i) => i.text).toList();
      final texts = items.join(' ');
      for (final w in ['흑백', '불 꺼', '점등', '컬러 =']) {
        expect(texts, isNot(contains(w)));
      }
      expect(items, containsAll(['♡ = 좋아요 · 0', '리본 = 구매함 · +10']));
    });
  });

  group('분류 칸 = 그림 + 이름만', () {
    void expectNameOnly(WidgetTester t) {
      final tiles = find.byType(CategoryTile);
      expect(tiles, findsWidgets);
      for (final e in tiles.evaluate()) {
        final tile = e.widget as CategoryTile;
        final texts = t.widgetList<Text>(find.descendant(of: find.byWidget(tile), matching: find.byType(Text)));
        for (final x in texts) {
          expect(x.data, keepWords(tile.name)); // 이름뿐 (낱말 안에서 안 끊는 글자) — 수집 n/m · % 없음
        }
        expect(find.descendant(of: find.byWidget(tile), matching: find.byType(AccentBar)), findsNothing);
      }
    }

    for (final width in [320.0, 390.0]) {
      testWidgets('건담 도감: 묶음 목록 · 기체 칸에 숫자 · 진행 막대 · 레벨 없음, 펴면 한 줄 3칸 (폭 $width)', (t) async {
        me.setStatus('ex-archangel', CollectStatus.owned);
        await _pump(t, _gundam(), width: width);
        expect(find.byKey(const ValueKey('guide-era-코즈믹 에라')), findsOneWidget);
        expect(find.textContaining('수집'), findsNothing);
        expect(find.byType(AccentBar), findsNothing);
        expect(find.byType(LevelBar), findsNothing);
        // 칸 크기 = 검색 탭 종류 · 세대 칸 (SideGrid) — 폰 390 · 작은 폰 320 모두 묶음 목록을 펴면 3칸 (기체가 넉넉한 SEED 로)
        await t.tap(find.descendant(of: find.byKey(guideDirKey), matching: find.text('SEED')));
        await _settle(t);
        final ys = [for (final e in find.byType(GuideCell).evaluate()) t.getTopLeft(find.byWidget(e.widget)).dy];
        final top = ys.reduce((a, b) => a < b ? a : b);
        expect(ys.where((y) => (y - top).abs() < 1).length, 3);
        expect(t.takeException(), isNull);
        await t.pump(const Duration(seconds: 3));
      });

      testWidgets('채널 고르기 · 태그 입구도 분류 칸 (폭 $width)', (t) async {
        await _pump(
          t,
          ListView(
            children: [
              SizedBox(
                height: 400,
                child: GuideView(
                  channel: allChannelId,
                  myChannels: const ['gundam', 'beyblade', 'pokemon', 'fate'],
                  onPickChannel: (_) {},
                  loaders: const Loaders(),
                ),
              ),
              const TagGameCards(),
            ],
          ),
          width: width,
        );
        expect(find.byType(CategoryTile), findsNWidgets(6));
        expect(find.text(channelOf('beyblade').label), findsWidgets);
        expect(find.text('MEZASTAR'), findsOneWidget);
        expect(find.text('Frienda'), findsOneWidget);
        expectNameOnly(t);
        expect(t.takeException(), isNull);
      });
    }
  });

  group('도감 필터 = 상품 필터와 같은 틀', () {
    const pool = [
      GuideFacet(name: '가', tiers: {GuideTier.owned}, grades: {'HG'}, types: {'MS'}, group: 'UC', kits: 2),
      GuideFacet(name: '나', tiers: {GuideTier.none}, grades: {'MG'}, types: {'전함'}, group: 'CE'),
      GuideFacet(name: '다', tiers: {GuideTier.liked}, grades: {'HG'}, types: {'MS'}, group: 'CE', kits: 1),
    ];

    Future<void> open(WidgetTester t, Future<Object?> Function(BuildContext) show, {double width = 390}) async {
      await _pump(
        t,
        Builder(
          builder: (context) => TextButton(onPressed: () => unawaited(show(context)), child: const Text('열기')),
        ),
        width: width,
      );
      await t.tap(find.text('열기'));
      await _settle(t, 3);
    }

    for (final width in [320.0, 390.0]) {
      testWidgets('상태 줄 = 전체 · ♡ · 리본 · 아직 없음 (+ 내 사진) → 라인 → 시대 · 기체 종류 · 상품 있는 것만 · 정렬 (폭 $width)', (t) async {
        await open(
          t,
          (c) => showGuideFilterSheet(c, pool: pool, initial: GuideFilter(), groupLabel: '시대'),
          width: width,
        );
        expect(find.byType(GpPickSheet), findsOneWidget);
        expect(t.widgetList<MineStateLabel>(find.byType(MineStateLabel)).map((l) => l.state), MineState.values);
        expect(find.text('아직 없음'), findsOneWidget);
        expect(find.byTooltip('좋아요'), findsOneWidget);
        expect(find.byTooltip('구매함'), findsOneWidget);
        expect(find.byTooltip('내 사진'), findsOneWidget);
        expect(find.text('단계'), findsNothing);
        expect(find.text('등급 · 라인'), findsNothing);
        double y(String s) => t.getTopLeft(find.text(s)).dy;
        final order = ['라인', '시대', '기체 종류', '상품 있는 것만', '정렬'];
        for (var i = 1; i < order.length; i++) {
          expect(y(order[i - 1]), lessThan(y(order[i])), reason: '${order[i - 1]} → ${order[i]}');
        }
        expect(y('아직 없음'), lessThan(y('라인'))); // 상태가 맨 위
        expect(find.text('3개 보기'), findsOneWidget);
        await t.tap(find.text('아직 없음'));
        await _settle(t, 2);
        expect(find.text('1개 보기'), findsOneWidget);
        await t.tap(find.text('초기화'));
        await _settle(t, 2);
        expect(find.text('3개 보기'), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('상품 상태와 같은 순서 · 상품 필터 시트는 같은 ♡ · 리본을 아이콘 줄로', (t) async {
      expect([for (final g in GuideTier.values) ?g.mine], MineState.values, reason: '도감 상태 = 상품 상태 + 내 사진');
      // 상품 필터는 아직 없음 칸을 뺐다 (2026-11-19) — ♡ · 리본은 아이콘 줄
      await open(t, (c) => showFilterSheet(c, kits: const [], initial: KitFilter()));
      expect(find.byType(MineStateLabel), findsNothing);
      expect(
        find.descendant(of: find.byKey(const ValueKey('toggle-liked')), matching: find.byType(LikedIcon)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byKey(const ValueKey('toggle-owned')), matching: find.byType(OwnedIcon)),
        findsOneWidget,
      );
    });
  });
}
