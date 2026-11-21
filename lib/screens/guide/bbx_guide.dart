// G-6 베이블레이드 X 도감 — 왼쪽 묶음 목록(베이 · 블레이더별) + 오른쪽 베이 칸 · 부품 시트 · 🔧 조합 만들기(T).
// 검색 탭 종류 · 세대와 같은 틀 (lib/widgets/side_directory.dart)
import 'package:flutter/material.dart';

import '../../api.dart';
import '../../l10n/l10n.dart';
import '../../logic/category_browse.dart' show isBeyLineWorld;
import '../../level.dart' show tierHelpItems;
import '../../marks.dart';
import '../../models.dart';
import '../../theme.dart';
import '../../widgets.dart';
import '../t_bbx_builder_screen.dart';
import 'guide_parts.dart';

/// G-6 베이블레이드 X 도감
class BbxGuide extends StatefulWidget {
  const BbxGuide({super.key, required this.loaders, required this.find});
  final Loaders loaders;
  final GuideFind find;

  @override
  State<BbxGuide> createState() => _BbxGuideState();
}

/// 묶음 목록의 '베이' 줄 (블레이더 id 와 겹치지 않는 열쇠)
const _allTops = '';

class _BbxGuideState extends State<BbxGuide> {
  late Future<(List<BbxTop>, List<World>)> _future = _load();

  /// 고른 줄 — '' = 베이 전부, 그 밖 = 블레이더 묶음 id
  String _pick = _allTops;

  /// 베이 목록 + 블레이더 묶음 (그 캐릭터 블레이드가 든 상품) — 베이 세대 묶음 중 라인(BX · UX · CX)이 아닌 것
  Future<(List<BbxTop>, List<World>)> _load() async {
    final tops = await widget.loaders.bbxTops(); // STATE: 베이 목록
    final bladers = await widget.loaders
        .worlds('beyblade')
        .then(
          (ws) => [
            for (final w in ws)
              if (!isBeyLineWorld(w.id) && w.kitIds.isNotEmpty) w,
          ],
        )
        .catchError((Object _) => <World>[]); // 블레이더를 못 받아도 베이 칸은 보인다
    return (tops, bladers);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(List<BbxTop>, List<World>)>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const LoadingView();
        if (snap.hasError) {
          return ErrorView(message: '${snap.error}', onRetry: () => setState(() => _future = _load()));
        }
        final (all, bladers) = snap.data!;
        if (all.isEmpty) return EmptyView(message: tr('베이 도감이 아직 없어요'));
        final m = Marks.of(context);
        bool done(BbxTop t) => t.total > 0 && t.owned >= t.total; // 부품 다 모음 = 구매함
        bool liked(BbxTop t) => t.kitIds.any((id) => m.store.statusOf(id) == CollectStatus.wanted);
        // G-9 찾기 + 도감 필터 (상태 = 부품 다 모음 · 상품 좋아요, 라인 = BX · UX · CX)
        final tops = widget.find.apply(
          all,
          (t) => t.name,
          (t) => GuideFacet(
            name: t.name,
            tiers: {done(t) ? GuideTier.owned : GuideTier.none, if (liked(t)) GuideTier.liked},
            grades: {if (t.line.isNotEmpty) t.line},
            kits: t.kitIds.length,
            boughtAt: [
              for (final id in t.kitIds) '${m.store.entry(id)?['updated_at'] ?? ''}',
            ].fold('', (a, b) => b.compareTo(a) > 0 ? b : a),
          ),
        );
        if (tops.isEmpty) return guideNoHit;
        List<BbxTop> topsOf(World w) => [
          for (final t in tops)
            if (t.kitIds.any(w.kitIds.contains)) t,
        ];
        // 찾기 · 필터에 맞는 베이가 있는 블레이더만
        final shown = [
          for (final w in bladers)
            if (topsOf(w).isNotEmpty) w,
        ];
        final cur = shown.where((w) => w.id == _pick).firstOrNull;
        return SideDirectory(
          directoryKey: guideDirKey,
          handleKey: guideDirHandleKey,
          initialOpen: guideDirOpen(context),
          onOpenChanged: (open) => setGuideDirOpen(context, open),
          rows: [
            SideDirItem(
              key: const ValueKey('guide-bey-all'),
              label: tr('베이'),
              selected: cur == null,
              onTap: () => setState(() => _pick = _allTops), // STATE: 베이 전부
            ),
            if (shown.isNotEmpty) SideDirHead(label: tr('블레이더')),
            for (final w in shown)
              SideDirItem(
                key: ValueKey('guide-blader-${w.id}'),
                label: w.label,
                selected: w.id == cur?.id,
                onTap: () => setState(() => _pick = w.id), // STATE: 블레이더 → 그 캐릭터 베이
              ),
          ],
          pane: (context, pane) => _cells(pane, cur, cur == null ? tops : topsOf(cur), done, liked),
        );
      },
    );
  }

  /// 고른 줄의 베이 칸 — 머리(손잡이 · 이름 · 🔧 · ?) + 격자. 다 모으면 리본 + 민트 테두리 · 좋아요 ♡
  Widget _cells(
    SidePane pane,
    World? blader,
    List<BbxTop> tops,
    bool Function(BbxTop) done,
    bool Function(BbxTop) liked,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      pane.head(
        blader?.label ?? tr('베이'),
        actions: [
          ToolIcon(
            // G-6a → T 조합 만들기
            icon: Icons.build_outlined,
            tip: tr('조합 만들기'),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => BbxBuilderScreen(loaders: widget.loaders))),
          ),
        ],
      ),
      Expanded(
        child: LayoutBuilder(
          builder: (context, box) {
            final g = SideGrid.of(context, box.maxWidth, open: pane.open);
            return CustomScrollView(
              key: ValueKey('tops-${blader?.id ?? _allTops}'),
              slivers: [
                g.sliver(tops.length, (context, i) {
                  final t = tops[i];
                  return GuideCell(
                    // G-6 P01 늘 컬러 · 리본 · ♡ (부품 수는 시트에)
                    key: ValueKey('top-${t.id}'),
                    image: t.image,
                    name: t.name,
                    tier: done(t) ? CellTier.owned : (liked(t) ? CellTier.liked : CellTier.none),
                    liked: liked(t),
                    onTap: () => showGpSheet<void>(context, builder: (_) => _TopSheet(top: t)),
                    square: false,
                    captionHeight: g.nameExtent - 4,
                  );
                }),
                SliverToBoxAdapter(child: SizedBox(height: navClearance(context))),
              ],
            );
          },
        ),
      ),
    ],
  );
}

/// G-2 사용법의 베이 도감 묶음 — 칸 표시 + 묶음 목록 · 조합 만들기
List<HelpItem> bbxGuideHelp() => [
  ...tierHelpItems(),
  HelpItem.group(tr('아이콘')),
  guideDirHelp,
  HelpItem(Icons.build_outlined, tr('조합 만들기')),
];

class _TopSheet extends StatelessWidget {
  const _TopSheet({required this.top});
  final BbxTop top;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              top.name,
              style: const TextStyle(fontSize: Gp.t16, fontWeight: FontWeight.w600),
            ),
            Text(
              trf('보유 부품 {owned} / {total}', {'owned': top.owned, 'total': top.total}),
              style: TextStyle(fontSize: Gp.t12, color: Gp.own, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            for (final p in top.parts)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox.square(
                      dimension: 52,
                      child: AppImage(p.image, fit: BoxFit.contain), // 늘 컬러 — 보유한 것은 오른쪽 '보유'
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr(p.typeLabel),
                            style: TextStyle(fontSize: Gp.t12, color: Gp.muted),
                          ),
                          Text(p.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    Text(
                      p.have ? tr('보유') : tr('미보유'),
                      style: TextStyle(fontWeight: FontWeight.w600, color: p.have ? Gp.own : Gp.faint),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
