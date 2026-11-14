// G-7 포켓몬 세대 · Fate 작품 · AC 세대 — 묶음 칸(그림 + 이름) → 그 묶음 상품
import 'package:flutter/material.dart';

import '../../api.dart';
import '../../channels.dart';
import '../../detail_pane.dart';
import '../../l10n/l10n.dart';
import '../../marks.dart';
import '../../logic/category_browse.dart' show worldSections;
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
            detail: tr('상품이 수록되면 도감 칸이 생겨요'),
          );
        }
        final pokemon = widget.channel == 'pokemon';
        return ListView(
          padding: EdgeInsets.only(bottom: navClearance(context)),
          children: [
            if (pokemon) ...[
              SectionHeader(tr('태그'), padding: const EdgeInsets.fromLTRB(16, 10, 12, 10)),
              const TagGameCards(padding: EdgeInsets.symmetric(horizontal: Gp.gutter)), // G-7b → R 태그 도감
            ],
            // 베이는 라인(BX · UX · CX) · 블레이더 두 묶음, 그 밖은 한 묶음
            for (final (title, group)
                in widget.channel == 'beyblade'
                    ? worldSections('beyblade', worlds, (w) => w.id)
                    : [
                        (
                          switch (widget.channel) {
                            'pokemon' => '세대',
                            'fate' => '작품',
                            'madoka' => '캐릭터',
                            'lego' => '시리즈',
                            _ => '게임 세대',
                          },
                          worlds,
                        ),
                      ]) ...[
              SectionHeader(tr(title), padding: const EdgeInsets.fromLTRB(16, 14, 12, 10)),
              CategoryGrid(
                children: [
                  for (final w in group)
                    CategoryTile(
                      // G-7 P06 그림 + 이름만
                      image: w.image,
                      name: shortWorldLabel(widget.channel, w.id, w.label), // "포켓몬스터" 머리 없이
                      onTap: () => openPage(context, _WorldKitsPage(world: w, loaders: widget.loaders)), // G-7a
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

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
