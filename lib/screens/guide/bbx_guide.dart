// G-6 베이블레이드 X 도감 — 베이 칸 + n/3 · 부품 시트 · 🔧 조합 만들기(T)
import 'package:flutter/material.dart';

import '../../api.dart';
import '../../level.dart';
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

class _BbxGuideState extends State<BbxGuide> {
  late Future<List<BbxTop>> _future = widget.loaders.bbxTops(); // STATE: GET /bbxTops

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<BbxTop>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const LoadingView();
        if (snap.hasError) {
          return ErrorView(message: '${snap.error}', onRetry: () => setState(() => _future = widget.loaders.bbxTops()));
        }
        if (snap.data!.isEmpty) return const EmptyView(message: '베이 도감이 아직 없어요');
        final m = Marks.of(context);
        // G-9 찾기 + 도감 필터 (단계 = 부품 다 모음 · 상품 좋아요, 라인 = BX · UX · CX)
        final tops = widget.find.apply(
          snap.data!,
          (t) => t.name,
          (t) => GuideFacet(
            name: t.name,
            tiers: {
              if (t.total > 0 && t.owned >= t.total) GuideTier.owned else GuideTier.none,
              if (t.kitIds.any((id) => m.store.statusOf(id) == CollectStatus.wanted)) GuideTier.liked,
            },
            grades: {if (t.line.isNotEmpty) t.line},
            kits: t.kitIds.length,
            boughtAt: [
              for (final id in t.kitIds) '${m.store.entry(id)?['updated_at'] ?? ''}',
            ].fold('', (a, b) => b.compareTo(a) > 0 ? b : a),
          ),
        );
        if (tops.isEmpty) return guideNoHit;
        final done = tops.where((t) => t.total > 0 && t.owned >= t.total).length;
        return LayoutBuilder(
          builder: (context, box) => ListView(
            padding: EdgeInsets.only(bottom: navClearance(context)),
            children: [
              SectionHeader(
                '베이',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ToolIcon(
                      // G-6a → T 조합 만들기
                      icon: Icons.build_outlined,
                      tip: '조합 만들기',
                      onTap: () => Navigator.of(
                        context,
                      ).push(MaterialPageRoute<void>(builder: (_) => BbxBuilderScreen(loaders: widget.loaders))),
                    ),
                    const LevelHelpButton(),
                  ],
                ),
                subtitle: '완성 $done / ${tops.length}',
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.count(
                  crossAxisCount: guideCols(box.maxWidth, 110),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.7,
                  children: [
                    for (final t in tops)
                      GuideCell(
                        // G-6 P01
                        image: t.image,
                        name: t.name,
                        tier: t.total > 0 && t.owned >= t.total ? CellTier.owned : CellTier.none,
                        badge: '${t.owned}/${t.total}',
                        onTap: () => showModalBottomSheet<void>(
                          context: context,
                          builder: (_) => _TopSheet(top: t),
                        ),
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
              '부품 ${top.owned} / ${top.total} 보유',
              style: const TextStyle(fontSize: Gp.t12, color: Gp.own, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            for (final p in top.parts)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox.square(
                      dimension: 52,
                      child: AppImage(p.image, fit: BoxFit.contain, grayscale: !p.have),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.typeLabel,
                            style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
                          ),
                          Text(p.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    Text(
                      p.have ? '보유' : '미보유',
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
