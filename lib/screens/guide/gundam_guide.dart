// G-3 건담 도감 — 왼쪽 묶음 목록(시대 머리 아래 작품) + 오른쪽 고른 작품의 기체 칸(G-4, work_guide_screen WorkUnits).
// 검색 탭 종류 · 세대와 같은 틀 (lib/widgets/side_directory.dart) — 컬렉션의 도감 탭과 작품 도감 화면이 이 한 벌을 쓴다.
import 'package:flutter/material.dart';

import '../../api.dart';
import '../../l10n/l10n.dart';
import '../../logic/data_labels.dart';
import '../../logic/short_names.dart' show shortWorkName;
import '../../marks.dart';
import '../../models.dart';
import '../../widgets.dart';
import 'guide_parts.dart';
import 'work_guide_screen.dart';

/// G-3 건담 도감 (시대 · 작품 목록 → 그 작품의 기체 칸)
class GundamGuide extends StatefulWidget {
  const GundamGuide({super.key, required this.loaders, required this.find, this.initialWork, this.focusUnit});
  final Loaders loaders;
  final GuideFind find;

  /// 처음 고를 작품 (작품 도감 화면) — 받은 작품 목록에 없으면 맨 앞에 넣는다
  final GuideWork? initialWork;

  /// 열자마자 이 기체의 시트 (도감 탭 검색의 기체 줄 · 상품 상세 "도감에서 보기")
  final String? focusUnit;

  @override
  State<GundamGuide> createState() => _GundamGuideState();
}

class _GundamGuideState extends State<GundamGuide> {
  late Future<List<GuideWork>> _future = widget.loaders.guideWorks(); // STATE: 건담 작품 목록

  /// 마지막으로 센 내 기록 버전 — 좋아요 · 구매함 · 손으로 켜기가 바뀌면 필터 재료(상태)를 다시 센다
  int _seen = -1;

  /// 고른 작품 id — 없거나 찾기 · 필터로 사라졌으면 첫 작품
  late String _pick = widget.initialWork?.id ?? '';

  /// [GundamGuide.focusUnit] 시트는 처음 한 번만 (다른 작품을 골랐다 돌아와도 다시 열지 않는다)
  bool _focusDone = false;

  /// 작품 이름이 아니라 기체 이름으로 찾은 것이면 작품 안에서도 그 말로 거른다
  String _carry(GuideWork w) {
    final q = widget.find.query.toLowerCase();
    return q.isNotEmpty && !w.name.toLowerCase().contains(q) ? widget.find.query : '';
  }

  @override
  Widget build(BuildContext context) {
    final v = Marks.of(context).version;
    if (v != _seen) {
      // STATE: 내 기록이 바뀜 → 다시 센다 (세는 동안 앞 목록을 그대로 보여 준다)
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
        var all = snap.data!;
        if (widget.initialWork case final w? when !all.any((x) => x.id == w.id)) all = [w, ...all];
        if (all.isEmpty) return EmptyView(message: tr('도감 작품이 아직 없어요'));
        // G-9 작품 이름 · 기체 이름 · 형식번호로 찾기 + 도감 필터(상태 · 라인 · 시대 · 기체 종류 · 정렬)
        final works = widget.find.apply(all, (w) => '${w.name} ${w.keywords}', _workFacet, groupLabel: tr('시대'));
        if (works.isEmpty) return guideNoHit;
        final sections = <String, List<GuideWork>>{};
        for (final w in works) {
          (sections[w.section] ??= []).add(w);
        }
        final cur = works.firstWhere((w) => w.id == _pick, orElse: () => works.first);
        return SideDirectory(
          directoryKey: guideDirKey,
          handleKey: guideDirHandleKey,
          initialOpen: guideDirOpen(context),
          onOpenChanged: (open) => setGuideDirOpen(context, open),
          rows: [
            for (final e in sections.entries) ...[
              // 시대 이름은 데이터 그대로 — '기타 작품'만 번역 표에
              SideDirHead(key: ValueKey('guide-era-${e.key}'), label: tr(e.key)),
              for (final w in e.value)
                SideDirItem(
                  // G-3 P06 작품 이름 ("기동전사 건담" 머리 없이 — 검색 탭 세대와 같은 이름)
                  key: ValueKey('guide-work-${w.id}'),
                  label: dataLabel(shortWorkName(w.name)),
                  selected: w.id == cur.id,
                  onTap: () => setState(() {
                    _pick = w.id; // STATE: 작품 → 오른쪽 기체 칸
                    _focusDone = true;
                  }),
                ),
            ],
          ],
          pane: (context, pane) => WorkUnits(
            // 작품을 바꾸면 칸 · 화수별 보기 · 스크롤을 새로
            key: ValueKey('work-${cur.id}'),
            work: cur,
            loaders: widget.loaders,
            pane: pane,
            query: _carry(cur),
            filter: widget.find.filter.copy(keepGroups: false), // 라인 · 단계 · 정렬을 기체 칸에도 (시대 빼고)
            focusUnit: _focusDone || cur.id != widget.initialWork?.id ? null : widget.focusUnit,
          ),
        );
      },
    );
  }
}

/// 작품 → 도감 필터 재료 (구매가 없으면 '아직', 좋아요 · 구매가 있으면 그 단계)
GuideFacet _workFacet(GuideWork w) => GuideFacet(
  name: w.name,
  tiers: {if (w.owned == 0) GuideTier.none, if (w.liked > 0) GuideTier.liked, if (w.owned > 0) GuideTier.owned},
  grades: w.grades.toSet(),
  types: w.types.toSet(),
  group: w.section,
  kits: w.kits,
  boughtAt: w.boughtAt,
);
