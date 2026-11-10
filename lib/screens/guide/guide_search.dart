// 도감 탭(B) 검색 조각 — 검색어에 맞는 작품 · 기체 줄(B-12), 결과를 기체별로 묶기(B-13),
// 기체 → 그 작품 도감의 기체 시트로 바로 가는 길(상품 상세 "도감에서 보기" D-15 도 같이 쓴다).
// 표는 GuideIndex (lib/data/derive/guide.dart deriveGuideIndex) — 건담만 기체가 있다.
import 'package:flutter/material.dart';

import '../../api.dart';
import '../../data/catalog.dart';
import '../../detail_pane.dart';
import '../../l10n/l10n.dart';
import '../../marks.dart';
import '../../models.dart';
import '../../theme.dart';
import '../../widgets.dart';
import '../d_kit_detail_screen.dart';
import 'work_guide_screen.dart';

/// 이 기체가 처음 나온 작품의 도감을 열고 그 기체 시트까지 (작품을 모르면 아무것도 안 함)
void openUnitInGuide(BuildContext context, GuideIndex index, String unitId, {required Loaders loaders}) {
  final u = index.units[unitId];
  final w = u == null ? null : index.work(u.workId);
  if (w == null) return;
  openPage(context, WorkGuideScreen(work: w, loaders: loaders, focusUnit: unitId));
}

/// 기체에 연결된 상품 중 내가 가진 수 (지금 Marks 기준)
int _ownedOf(Marks m, GuideUnit u) => u.kitIds.where((id) {
  final k = Catalog.instance.byId[id];
  return k != null && m.owned(k);
}).length;

/// 찾기 글자가 작품 · 기체 이름에 맞는지 (기체는 모든 언어 이름 · 형식번호 = keywords)
List<GuideWork> guideWorkHits(GuideIndex index, String query, {int max = 3}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];
  return index.works.where((w) => w.name.toLowerCase().contains(q)).take(max).toList();
}

List<GuideUnit> guideUnitHits(GuideIndex index, String query, {int max = 6}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];
  final hits = [
    for (final u in index.units.values)
      if (u.kitIds.isNotEmpty && (u.name.toLowerCase().contains(q) || u.keywords.contains(q))) u,
  ];
  // 이름이 바로 맞는 것 → 상품이 많은 것 먼저
  int rank(GuideUnit u) => u.name.toLowerCase() == q ? 0 : (u.name.toLowerCase().startsWith(q) ? 1 : 2);
  hits.sort((a, b) {
    final r = rank(a).compareTo(rank(b));
    return r != 0 ? r : b.kitIds.length.compareTo(a.kitIds.length);
  });
  return hits.take(max).toList();
}

/// B-12 검색 결과 위: 맞는 작품 · 기체 (누르면 도감 — 기체는 그 시트까지)
class GuideHits extends StatelessWidget {
  const GuideHits({super.key, required this.index, required this.query, required this.loaders});
  final GuideIndex index;
  final String query;
  final Loaders loaders;

  @override
  Widget build(BuildContext context) {
    final works = guideWorkHits(index, query);
    final units = guideUnitHits(index, query);
    if (works.isEmpty && units.isEmpty) return const SizedBox.shrink();
    final m = Marks.of(context);
    return Container(
      key: const ValueKey('guide-hits'),
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 6),
      decoration: BoxDecoration(
        color: Gp.panel,
        borderRadius: BorderRadius.circular(Gp.rLarge),
        border: Border.all(color: Gp.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome_mosaic_outlined, size: Gp.iM, color: Gp.accent),
                const SizedBox(width: 6),
                Text(tr('도감'), style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          for (final w in works)
            ThumbRow(
              image: w.image,
              title: w.name,
              subtitle: joinDot([
                tr('작품'),
                tr(w.section),
                trf('수집 {owned} / {total}', {'owned': w.owned, 'total': w.total}),
              ]),
              size: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              onTap: () => openPage(context, WorkGuideScreen(work: w, loaders: loaders)),
            ),
          for (final u in units)
            ThumbRow(
              key: ValueKey('guide-hit-${u.id}'),
              image: u.image,
              title: u.name,
              subtitle: joinDot([
                u.nameEn,
                index.work(u.workId)?.name ?? '',
                trf('상품 {n}', {'n': u.kitIds.length}),
                if (_ownedOf(m, u) case final n when n > 0) trf('가짐 {n}', {'n': n}),
              ]),
              size: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              onTap: () => openUnitInGuide(context, index, u.id, loaders: loaders),
            ),
        ],
      ),
    );
  }
}

/// B-13 결과를 기체별로: 기체 머리(그림 · 이름 · 상품 n · 가짐 m · 도감 ›) 아래 상품 줄. 기체 없는 상품은 끝 "기타"
class GroupedResults extends StatelessWidget {
  const GroupedResults({super.key, required this.kits, required this.index, required this.loaders, this.header});
  final List<Kit> kits;
  final GuideIndex index;
  final Loaders loaders;

  /// 목록과 함께 스크롤되는 머리 (태그 · 도감 줄 · 설명 후보)
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<Kit>>{};
    final rest = <Kit>[];
    for (final k in kits) {
      final u = index.unitOf(k.id);
      u == null ? rest.add(k) : (groups[u.id] ??= []).add(k);
    }
    final m = Marks.of(context);
    // 줄 = 머리 · 상품 섞어서 한 줄씩 (큰 결과도 builder 로)
    final rows = <Object>[
      for (final e in groups.entries) ...[index.units[e.key]!, ...e.value],
      if (rest.isNotEmpty) ...['기타', ...rest],
    ];
    return ListView.builder(
      key: const ValueKey('grouped-results'),
      padding: EdgeInsets.only(bottom: navClearance(context)),
      itemCount: rows.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) return header ?? const SizedBox.shrink();
        final row = rows[i - 1];
        return switch (row) {
          final GuideUnit u => _UnitHead(
            unit: u,
            count: groups[u.id]!.length,
            owned: groups[u.id]!.where(m.owned).length,
            onTap: () => openUnitInGuide(context, index, u.id, loaders: loaders),
          ),
          final Kit k => ThumbRow(
            image: k.image,
            title: k.name,
            subtitle: joinDot([tr(k.line), k.date]),
            size: 48,
            padding: const EdgeInsets.fromLTRB(28, 4, 8, 4),
            trailing: KitMarkButtons(kit: k),
            onTap: () => openKitDetail(context, k, loaders: loaders, list: kits),
          ),
          _ => SectionHeader(tr('기타'), padding: const EdgeInsets.fromLTRB(16, 18, 16, 6)),
        };
      },
    );
  }
}

class _UnitHead extends StatelessWidget {
  const _UnitHead({required this.unit, required this.count, required this.owned, required this.onTap});
  final GuideUnit unit;
  final int count;
  final int owned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    key: ValueKey('unit-head-${unit.id}'),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
      child: Row(
        children: [
          CircleThumb(image: unit.image, label: unit.name, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unit.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: Gp.t14, fontWeight: FontWeight.w700),
                ),
                Text(
                  joinDot([
                    unit.nameEn,
                    trf('상품 {n}', {'n': count}),
                    if (owned > 0) trf('가짐 {n}', {'n': owned}),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
                ),
              ],
            ),
          ),
          Text(
            tr('도감'),
            style: const TextStyle(fontSize: Gp.t12, color: Gp.accent),
          ),
          const Icon(Icons.chevron_right, size: Gp.iM, color: Gp.accent),
        ],
      ),
    ),
  );
}
