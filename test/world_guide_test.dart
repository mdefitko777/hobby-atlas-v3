// G-7 세계관 도감 묶음 이름 = 검색 탭 세대 목록과 한 벌 (worldSections) — 화면이 따로 이름을 정하지 않는다.
// 묶음은 왼쪽 묶음 목록 줄(SideDirItem), 고른 묶음의 칸만 오른쪽에
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/api.dart';
import 'package:hobby_atlas/data/user_store.dart';
import 'package:hobby_atlas/detail_pane.dart';
import 'package:hobby_atlas/logic/category_browse.dart' show worldSectionOf;
import 'package:hobby_atlas/marks.dart';
import 'package:hobby_atlas/models.dart';
import 'package:hobby_atlas/screens/guide/guide_parts.dart';
import 'package:hobby_atlas/screens/guide/world_guide.dart';
import 'package:hobby_atlas/screens/r_mezastar_screen.dart' show TagGameCards;
import 'package:hobby_atlas/theme.dart';
import 'package:hobby_atlas/widgets.dart';

World _world(String channel, String id) =>
    World(id: '$channel-$id', franchiseId: channel, label: id, subtitle: '', image: '', total: 1, owned: 0);

Future<List<String>> _sectionTitles(WidgetTester t, String channel, List<World> worlds) async {
  t.view.physicalSize = const Size(390, 1600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: buildGpTheme(),
      builder: (context, child) => MarksHost(
        store: UserStore.instance,
        child: PaneHost(child: child!),
      ),
      home: Scaffold(
        body: WorldGuide(
          channel: channel,
          loaders: Loaders(worlds: (_) async => worlds),
          find: GuideFind(''),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  return [for (final h in t.widgetList<SideDirItem>(find.byType(SideDirItem))) h.label];
}

void main() {
  testWidgets('아머드 코어 = 「작품」 한 묶음', (t) async {
    final titles = await _sectionTitles(t, 'armored_core', [
      _world('armored_core', 'ac6'),
      _world('armored_core', 'ac5'),
    ]);
    expect(titles, ['작품']);
  });

  testWidgets('포켓몬 = 태그 · 본편 세대 · 여러 세대 (검색 탭 세대 목록과 같은 이름)', (t) async {
    final worlds = [_world('pokemon', 'gen1'), _world('pokemon', 'gen9'), _world('pokemon', 'pokemon_general')];
    final titles = await _sectionTitles(t, 'pokemon', worlds);
    expect(titles, [
      '태그',
      worldSectionOf('pokemon', 'pokemon-gen1'),
      worldSectionOf('pokemon', 'pokemon-pokemon_general'),
    ]);
    expect(titles.sublist(1), ['본편 세대', '여러 세대']);
    // 처음 고른 묶음 = 태그 → MEZASTAR · Frienda 입구만
    expect(find.byType(TagGameCards), findsOneWidget);
    expect(find.byKey(const ValueKey('guide-world-pokemon-gen1')), findsNothing);

    // 본편 세대 → 그 묶음 칸만 (그림 + 이름)
    await t.tap(find.byKey(const ValueKey('guide-group-본편 세대')));
    await t.pumpAndSettle();
    expect(find.byType(TagGameCards), findsNothing);
    expect(find.byKey(const ValueKey('guide-world-pokemon-gen1')), findsOneWidget);
    expect(find.byKey(const ValueKey('guide-world-pokemon-pokemon_general')), findsNothing);
  });
}
