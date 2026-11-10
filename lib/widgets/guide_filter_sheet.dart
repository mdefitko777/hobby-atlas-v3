// 도감 필터 시트 (모든 도감 공통: 건담 작품 · 기체 칸 · 베이 · 세계관) — 상품 필터와 같은 틀(GpPickSheet) · 같은 조각.
//   순서: 상태(상품 필터와 같은 줄 + 내 사진) → 라인 → 도감에만: 시대 · 기체 종류 · 상품 있는 것만 · 정렬
// 거르는 규칙(GuideFilter.matches · apply)은 lib/logic/guide_filter.dart
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../logic/guide_filter.dart';
import '../logic/kit_filter.dart' show valueCounts;
import '../theme.dart';
import 'kit_filter_sheet.dart' show MineStateLabel;
import 'sheets.dart';

export '../logic/guide_filter.dart';

/// 컬렉션의 도감 보기 ↔ 그 안의 도감: 지금 조건 + 시트가 셀 재료(지금 보이는 도감의 칸들)
class GuideFilterController extends ChangeNotifier {
  GuideFilter filter = GuideFilter();

  /// 지금 도감의 칸 (도감 화면이 그릴 때 채운다 — 알리지 않음)
  List<GuideFacet> pool = const [];

  /// 시대 · 작품 줄 이름 (건담 = 시대, 그 밖 = 묶음)
  String groupLabel = '시대 · 작품';

  /// 내 사진 단계가 있는 도감인가
  bool photoTier = false;

  void set(GuideFilter f) {
    filter = f;
    notifyListeners();
  }

  /// 도감 필터 시트를 열고 고른 조건을 넣는다
  Future<void> openSheet(BuildContext context) async {
    final f = await showGuideFilterSheet(
      context,
      pool: pool,
      initial: filter,
      groupLabel: groupLabel,
      photoTier: photoTier,
    );
    if (f != null) set(f); // STATE: 도감 필터 → 칸 거르기 · 정렬
  }
}

/// 도감 필터 시트 — 고르면 새 조건, 닫으면 null
Future<GuideFilter?> showGuideFilterSheet(
  BuildContext context, {
  required List<GuideFacet> pool,
  required GuideFilter initial,
  String groupLabel = '시대 · 작품',
  bool photoTier = true,
}) => showGpSheet<GuideFilter>(
  context,
  heightFactor: gpSheetHeight,
  builder: (_) => GuideFilterSheet(pool: pool, initial: initial, groupLabel: groupLabel, photoTier: photoTier),
);

class GuideFilterSheet extends StatefulWidget {
  const GuideFilterSheet({
    super.key,
    required this.pool,
    required this.initial,
    this.groupLabel = '시대 · 작품',
    this.photoTier = true,
  });
  final List<GuideFacet> pool;
  final GuideFilter initial;
  final String groupLabel;

  /// 내 사진 단계가 있는 도감인가 (건담 기체 칸)
  final bool photoTier;

  @override
  State<GuideFilterSheet> createState() => _GuideFilterSheetState();
}

class _GuideFilterSheetState extends State<GuideFilterSheet> {
  late final GuideFilter _draft = widget.initial.copy();

  /// 펼친 줄 (라인 · 시대 · 기체 종류 · 정렬)
  String _open = '';

  int _hits(GuideFilter f) => widget.pool.where(f.matches).length;

  int _with(void Function(GuideFilter) change) {
    final f = _draft.copy();
    change(f);
    return _hits(f);
  }

  void _toggle(Set<String> set, String v) => setState(() => set.contains(v) ? set.remove(v) : set.add(v));

  /// 많은 순 값 목록 (칸 하나에 여러 값이면 각각 센다)
  List<String> _values(Iterable<Iterable<String>> all) =>
      valueCounts([for (final vs in all) ...vs]).map((e) => e.$1).toList();

  /// 고른 값들 한 줄 요약 (라인 · 시대 · 기체 종류 — 번역 표에 있으면 중국어)
  String _summary(Set<String> picked) => pickSummary({for (final v in picked) tr(v)});

  Widget _expand(String title, String summary, Widget body) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ExpandRow(
        title: title,
        summary: summary,
        open: _open == title,
        onTap: () => setState(() => _open = _open == title ? '' : title),
      ),
      if (_open == title) body,
    ],
  );

  Widget _checks(
    List<String> values,
    Set<String> selected,
    Set<String> Function(GuideFilter) field, {
    int columns = 2,
  }) => CheckGrid(
    columns: columns,
    values: values,
    selected: selected,
    countOf: (v) => _with(
      (f) => field(f)
        ..clear()
        ..add(v),
    ),
    onToggle: (v) => _toggle(selected, v),
  );

  @override
  Widget build(BuildContext context) {
    final pool = widget.pool;
    final hits = _hits(_draft);
    final grades = _values(pool.map((f) => f.grades));
    final types = _values(pool.map((f) => f.types));
    final groups = _values(pool.map((f) => [f.group]));
    final tiers = [
      for (final t in GuideTier.values)
        if (t != GuideTier.photo || widget.photoTier) t,
    ];
    return GpPickSheet(
      title: tr('도감 필터'),
      hits: hits,
      noHitLabel: tr('맞는 칸 없음'),
      onApply: () => Navigator.pop(context, _draft),
      onReset: () => setState(() {
        _draft.clear();
        _open = '';
      }),
      children: [
        // 상태: 상품 필터와 같은 줄 (전체 · ♡ · 리본 · 아직 없음) + 도감만 내 사진
        SquareSegments<GuideTier>(
          values: tiers,
          current: _draft.tier,
          child: (v) => switch (v.mine) {
            final m? => MineStateLabel(m),
            null => Tooltip(
              message: tr('내 사진'),
              child: const Icon(Icons.workspace_premium, size: Gp.iS, color: Gp.own),
            ),
          },
          onPick: (v) => setState(() => _draft.tier = v),
        ),
        const Divider(height: 20),
        // 상품 필터와 같은 줄: 라인
        if (grades.isNotEmpty)
          _expand(tr('라인'), _summary(_draft.grades), _checks(grades, _draft.grades, (f) => f.grades)),
        // 도감에만: 시대 · 기체 종류 · 상품 있는 것만 · 정렬
        if (groups.length > 1)
          _expand(
            tr(widget.groupLabel),
            _summary(_draft.groups),
            _checks(groups, _draft.groups, (f) => f.groups, columns: 1),
          ),
        if (types.length > 1)
          _expand(tr('기체 종류'), _summary(_draft.types), _checks(types, _draft.types, (f) => f.types)),
        CheckGrid(
          columns: 1,
          values: [tr('상품 있는 것만')],
          selected: {if (_draft.withKits) tr('상품 있는 것만')},
          countOf: (_) => _with((f) => f.withKits = true),
          onToggle: (_) => setState(() => _draft.withKits = !_draft.withKits),
        ),
        _expand(
          tr('정렬'),
          _draft.sort.label,
          SquareSegments<GuideSort>(
            values: GuideSort.values,
            current: _draft.sort,
            child: (v) => Text(v.label),
            onPick: (v) => setState(() => _draft.sort = v),
          ),
        ),
      ],
    );
  }
}
