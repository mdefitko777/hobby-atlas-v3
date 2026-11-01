// G-3 건담 작품 도감 — 시대 묶음 → 작품 카드 → 작품 도감(G-4)
import 'package:flutter/material.dart';

import '../../api.dart';
import '../../detail_pane.dart';
import '../../level.dart';
import '../../marks.dart';
import '../../models.dart';
import '../../widgets.dart';
import 'guide_parts.dart';
import 'work_guide_screen.dart';

/// G-3 건담 작품 도감 (시대 묶음 → 작품 카드)
class GundamGuide extends StatefulWidget {
  const GundamGuide({super.key, required this.loaders, required this.find});
  final Loaders loaders;
  final GuideFind find;

  @override
  State<GundamGuide> createState() => _GundamGuideState();
}

class _GundamGuideState extends State<GundamGuide> {
  late Future<List<GuideWork>> _future = widget.loaders.guideWorks(); // STATE: GET /guideWorks

  /// 마지막으로 센 내 기록 버전 — 좋아요 · 구매함 · 손으로 켜기가 바뀌면 수집 숫자를 다시 센다
  int _seen = -1;

  void _open(GuideWork w) {
    final q = widget.find.query.toLowerCase();
    // 작품 이름이 아니라 기체 이름으로 찾은 것이면 작품 안에서도 그 말로 거른다
    final carry = q.isNotEmpty && !w.name.toLowerCase().contains(q);
    openPage(
      context,
      WorkGuideScreen(
        work: w,
        loaders: widget.loaders,
        initialQuery: carry ? widget.find.query : '',
        initialFilter: widget.find.filter.copy(keepGroups: false), // 등급 · 단계 · 정렬을 이어받는다
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = Marks.of(context).version;
    if (v != _seen) {
      // STATE: 내 기록이 바뀜 → 다시 센다 (세는 동안 앞 숫자를 그대로 보여 준다)
      if (_seen != -1) _future = widget.loaders.guideWorks();
      _seen = v;
    }
    return FutureBuilder<List<GuideWork>>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData && !snap.hasError) return const LoadingView(); // G-8
        if (snap.hasError) {
          return ErrorView(
            message: '${snap.error}',
            onRetry: () => setState(() => _future = widget.loaders.guideWorks()),
          );
        }
        if (snap.data!.isEmpty) return const EmptyView(message: '도감 작품이 아직 없어요');
        // G-9 작품 이름 · 기체 이름 · 형식번호로 찾기 + 도감 필터(단계 · 등급 · 종류 · 시대 · 정렬)
        final works = widget.find.apply(snap.data!, (w) => '${w.name} ${w.keywords}', _workFacet, groupLabel: '시대');
        if (works.isEmpty) return guideNoHit;
        final sections = <String, List<GuideWork>>{};
        for (final w in works) {
          (sections[w.section] ??= []).add(w);
        }
        return LayoutBuilder(
          builder: (context, box) => ListView(
            padding: EdgeInsets.only(bottom: navClearance(context)),
            children: [
              for (final e in sections.entries) ...[
                SectionHeader(
                  e.key,
                  trailing: e.key == sections.keys.first ? const LevelHelpButton() : null, // G-2
                  subtitle:
                      '수집 ${e.value.fold(0, (s, w) => s + w.owned)}'
                      ' / ${e.value.fold(0, (s, w) => s + w.total)}',
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.count(
                    crossAxisCount: guideCols(box.maxWidth, 120),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.82,
                    children: [
                      for (final w in e.value)
                        GuideWorkCard(
                          // G-3 P06
                          image: w.image,
                          name: w.name,
                          owned: w.owned,
                          total: w.total,
                          onTap: () => _open(w),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// 작품 카드 → 도감 필터 재료 (구매가 없으면 '아직', 좋아요 · 구매가 있으면 그 단계)
GuideFacet _workFacet(GuideWork w) => GuideFacet(
  name: w.name,
  tiers: {if (w.owned == 0) GuideTier.none, if (w.liked > 0) GuideTier.liked, if (w.owned > 0) GuideTier.owned},
  grades: w.grades.toSet(),
  types: w.types.toSet(),
  group: w.section,
  kits: w.kits,
  boughtAt: w.boughtAt,
);
