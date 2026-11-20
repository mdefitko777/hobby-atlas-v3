// G-7 포켓몬 세대 · Fate 작품 · AC 세대 — 왼쪽 묶음 목록(세대 묶음 · 포켓몬은 태그도) + 오른쪽 칸(그림 + 이름) → 그 묶음 상품.
// 검색 탭 종류 · 세대와 같은 틀 (lib/widgets/side_directory.dart)
import 'package:flutter/material.dart';

import '../../api.dart';
import '../../channels.dart';
import '../../detail_pane.dart';
import '../../l10n/l10n.dart';
import '../../marks.dart';
import '../../logic/category_browse.dart' show isAtlasCover, worldSections;
import '../../logic/short_names.dart' show shortWorldLabel;
import '../../models.dart';
import '../../theme.dart';
import '../../widgets.dart';
import '../o_see_all_screen.dart' show SectionListView;
import '../r_mezastar_screen.dart' show TagGameCards;
import 'guide_parts.dart';

/// G-7 포켓몬 세대 · Fate 작품 · AC 세대
class WorldGuide extends StatefulWidget {
  const WorldGuide({super.key, required this.channel, required this.loaders, required this.find});
  final String channel;
  final Loaders loaders;
  final GuideFind find;

  @override
  State<WorldGuide> createState() => _WorldGuideState();
}

class _WorldGuideState extends State<WorldGuide> {
  late Future<List<World>> _future = widget.loaders.worlds(widget.channel);

  /// 고른 묶음 이름 — 없거나 찾기로 사라졌으면 첫 묶음
  String _pick = '';

  @override
  void didUpdateWidget(WorldGuide old) {
    super.didUpdateWidget(old);
    if (old.channel != widget.channel) _future = widget.loaders.worlds(widget.channel);
  }

  @override
  Widget build(BuildContext context) {
    final label = tr(channelOf(widget.channel).label);
    return FutureBuilder<List<World>>(
      future: _future, // STATE: 채널의 세대 · 작품 → 칸
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const LoadingView();
        if (snap.hasError) {
          return ErrorView(
            message: '${snap.error}',
            onRetry: () => setState(() => _future = widget.loaders.worlds(widget.channel)),
          );
        }
        // G-9 찾기 + 도감 필터 (상태 · 상품 있는 것 · 정렬)
        final store = Marks.of(context).store;
        final worlds = widget.find.apply(
          snap.data!,
          (w) => '${w.label} ${w.subtitle}',
          (w) => GuideFacet(
            name: w.label,
            tiers: {
              if (w.owned > 0) GuideTier.owned else GuideTier.none,
              if (w.kitIds.any((id) => store.statusOf(id) == CollectStatus.wanted)) GuideTier.liked,
            },
            kits: w.kitIds.length,
          ),
        );
        if (worlds.isEmpty && widget.find.active) return guideNoHit;
        if (worlds.isEmpty) {
          return EmptyView(
            // G-8 P09
            icon: Icons.auto_awesome_mosaic_outlined,
            message: trf('{name} 도감은 아직 준비 중이에요', {'name': label}),
            detail: tr('상품이 들어오면 도감 칸이 생겨요'),
          );
        }
        final pokemon = widget.channel == 'pokemon';
        // 묶음 이름은 검색 탭 세대 목록과 한 벌 (포켓몬 본편 세대 · 여러 세대, AC 작품, 레고 테마 …)
        final groups = worldSections(widget.channel, worlds, (w) => w.id);
        final keys = [if (pokemon) _tagGroup, for (final (title, _) in groups) title];
        final cur = keys.contains(_pick) ? _pick : keys.first;
        return SideDirectory(
          directoryKey: guideDirKey,
          handleKey: guideDirHandleKey,
          initialOpen: guideDirOpen(context),
          onOpenChanged: (open) => setGuideDirOpen(context, open),
          rows: [
            for (final k in keys)
              SideDirItem(
                key: ValueKey('guide-group-$k'),
                label: tr(k),
                selected: k == cur,
                onTap: () => setState(() => _pick = k), // STATE: 묶음 → 오른쪽 칸
              ),
          ],
          pane: (context, pane) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              pane.head(tr(cur)),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final g = SideGrid.of(context, box.maxWidth, open: pane.open);
                    final group = [
                      for (final (title, ws) in groups)
                        if (title == cur) ...ws,
                    ];
                    return CustomScrollView(
                      key: ValueKey('worlds-$cur'),
                      slivers: [
                        if (cur == _tagGroup)
                          // G-7b → R 태그 도감 (분류 칸 · 같은 칸 수)
                          const SliverToBoxAdapter(
                            child: TagGameCards(padding: EdgeInsets.fromLTRB(SideGrid.pad, 4, SideGrid.pad, 0)),
                          )
                        else
                          g.sliver(group.length, (context, i) {
                            final w = group[i];
                            return CategoryTile(
                              // G-7 P06 그림 + 이름만 — 로고는 그 바탕색 위, 키 비주얼 · 상품 사진은 칸 가득
                              key: ValueKey('guide-world-${w.id}'),
                              image: w.image,
                              style: w.cover ?? (isAtlasCover(w.image) ? null : const CoverStyle(logo: false)),
                              color: Gp.channelColor(widget.channel),
                              icon: Icons.auto_awesome_mosaic_outlined,
                              name: shortWorldLabel(widget.channel, w.id, w.label), // "포켓몬스터" 머리 없이
                              onTap: () => openPage(context, _WorldKitsPage(world: w, loaders: widget.loaders)), // G-7a
                            );
                          }),
                        SliverToBoxAdapter(child: SizedBox(height: navClearance(context))),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 포켓몬 묶음 목록 맨 위 '태그' 줄 (MEZASTAR · Frienda 입구)
const _tagGroup = '태그';

/// G-2 사용법의 세계관 도감 묶음 — 묶음 목록 · 칸
List<HelpItem> worldGuideHelp() => [guideDirHelp, HelpItem(Icons.chevron_right, tr('칸을 누르면 그 상품 전부'))];

/// G-7a 세계관 묶음 → 그 묶음 상품 (전체 목록과 같은 찾기 · 필터 · 격자/목록)
class _WorldKitsPage extends StatefulWidget {
  const _WorldKitsPage({required this.world, required this.loaders});
  final World world;
  final Loaders loaders;

  @override
  State<_WorldKitsPage> createState() => _WorldKitsPageState();
}

class _WorldKitsPageState extends State<_WorldKitsPage> {
  late final Future<List<Kit>> _future = widget.loaders.kitsByIds(widget.world.kitIds); // STATE: 그 세대 · 작품의 상품

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: FutureBuilder<List<Kit>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingView();
          if (snap.hasError) return ErrorView(message: '${snap.error}', onRetry: () => Navigator.pop(context));
          return SectionListView(
            title: shortWorldLabel(widget.world.franchiseId, widget.world.id, widget.world.label),
            subtitle: widget.world.subtitle,
            kits: snap.data!,
            onBack: () => Navigator.pop(context),
            loaders: widget.loaders,
          );
        },
      ),
    ),
  );
}
