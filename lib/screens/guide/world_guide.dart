// G-7 포켓몬 세대 · Fate 작품 · AC 세대 — 묶음 카드 → 그 묶음 상품
import 'package:flutter/material.dart';

import '../../api.dart';
import '../../channels.dart';
import '../../detail_pane.dart';
import '../../models.dart';
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
    final label = channelOf(widget.channel).label;
    return FutureBuilder<List<World>>(
      future: _future, // STATE: GET /worlds?franchiseId= → 카드
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const LoadingView();
        if (snap.hasError) {
          return ErrorView(
            message: '${snap.error}',
            onRetry: () => setState(() => _future = widget.loaders.worlds(widget.channel)),
          );
        }
        // G-9 찾기 + 도감 필터 (단계 · 상품 있는 것 · 정렬)
        final worlds = widget.find.apply(
          snap.data!,
          (w) => '${w.label} ${w.subtitle}',
          (w) => GuideFacet(
            name: w.label,
            tiers: {if (w.owned > 0) GuideTier.owned else GuideTier.none},
            kits: w.kitIds.length,
          ),
        );
        if (worlds.isEmpty && widget.find.active) return guideNoHit;
        if (worlds.isEmpty) {
          return EmptyView(
            // G-8 P09
            icon: Icons.auto_awesome_mosaic_outlined,
            message: '$label 도감은 아직 준비 중이에요',
            detail: '상품이 수록되면 도감 칸이 생겨요',
          );
        }
        final pokemon = widget.channel == 'pokemon';
        return LayoutBuilder(
          builder: (context, box) => ListView(
            padding: EdgeInsets.only(bottom: navClearance(context)),
            children: [
              if (pokemon) const TagGameCards(), // G-7b → R 태그 도감
              SectionHeader(
                pokemon ? '세대' : (widget.channel == 'fate' ? '작품' : '게임 세대'),
                subtitle:
                    '수집 ${worlds.fold(0, (s, w) => s + w.owned)}'
                    ' / ${worlds.fold(0, (s, w) => s + w.total)}',
                padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.count(
                  crossAxisCount: guideCols(box.maxWidth, 120),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.78,
                  children: [
                    for (final w in worlds)
                      GuideWorkCard(
                        // G-7 P01
                        image: w.image,
                        name: w.label,
                        subtitle: w.subtitle,
                        owned: w.owned,
                        total: w.total,
                        fit: pokemon ? BoxFit.contain : BoxFit.cover,
                        onTap: () => openPage(context, _WorldKitsPage(world: w, loaders: widget.loaders)), // G-7a
                      ),
                  ],
                ),
              ),
            ],
          ),
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
  late final Future<List<Kit>> _future = widget.loaders.kitsByIds(widget.world.kitIds); // STATE: GET /kits?id=

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: FutureBuilder<List<Kit>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingView();
          if (snap.hasError) return ErrorView(message: '${snap.error}', onRetry: () => Navigator.pop(context));
          return SectionListView(
            title: widget.world.label,
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
