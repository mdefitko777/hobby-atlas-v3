// 도감 필터 시트 (모든 도감 공통: 건담 작품 · 기체 칸 · 베이 · 세계관) — 상품 필터와 같은 모양.
// 거르는 규칙(GuideFilter.matches · apply)은 lib/logic/guide_filter.dart
import 'package:flutter/material.dart';

import '../logic/guide_filter.dart';
import '../logic/kit_filter.dart' show valueCounts;
import '../theme.dart';
import 'buttons.dart';
import 'icons.dart';
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
}) => showModalBottomSheet<GuideFilter>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Gp.panel,
  builder: (_) => FractionallySizedBox(
    heightFactor: 0.62,
    child: GuideFilterSheet(pool: pool, initial: initial, groupLabel: groupLabel, photoTier: photoTier),
  ),
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

  /// 펼친 줄 (등급 · 종류 · 시대 · 정렬)
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
    return SafeArea(
      top: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 4),
            child: Row(
              children: [
                const Text(
                  '도감 필터',
                  style: TextStyle(fontSize: Gp.t16, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() {
                    _draft.clear();
                    _open = '';
                  }),
                  child: const Text('초기화', style: TextStyle(color: Gp.muted)),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              children: [
                // 칸 단계: 전체 · 아직 · ♡ · 구매함 · 내 사진
                SquareSegments<GuideTier>(
                  values: tiers,
                  current: _draft.tier,
                  child: (v) => switch (v) {
                    GuideTier.any => const Text('전체'),
                    GuideTier.none => const Text('아직'),
                    GuideTier.liked => const LikedIcon(),
                    GuideTier.owned => const OwnedIcon(),
                    GuideTier.photo => const Icon(Icons.workspace_premium, size: Gp.iS, color: Gp.own),
                  },
                  onPick: (v) => setState(() => _draft.tier = v),
                ),
                const SizedBox(height: 8),
                CheckGrid(
                  columns: 1,
                  values: const ['상품 있는 것만'],
                  selected: {if (_draft.withKits) '상품 있는 것만'},
                  countOf: (_) => _with((f) => f.withKits = true),
                  onToggle: (_) => setState(() => _draft.withKits = !_draft.withKits),
                ),
                const Divider(height: 20),
                if (grades.isNotEmpty)
                  _expand('등급 · 라인', _summary(_draft.grades), _checks(grades, _draft.grades, (f) => f.grades)),
                if (types.length > 1)
                  _expand('종류', _summary(_draft.types), _checks(types, _draft.types, (f) => f.types)),
                if (groups.length > 1)
                  _expand(
                    widget.groupLabel,
                    _summary(_draft.groups),
                    _checks(groups, _draft.groups, (f) => f.groups, columns: 1),
                  ),
                _expand(
                  '정렬',
                  _draft.sort.label,
                  SquareSegments<GuideSort>(
                    values: GuideSort.values,
                    current: _draft.sort,
                    child: (v) => Text(v.label),
                    onPick: (v) => setState(() => _draft.sort = v),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: GradientButton(
              label: hits == 0 ? '맞는 칸 없음' : '$hits개 보기', // P01 고르는 동안 개수
              onPressed: hits == 0 ? null : () => Navigator.pop(context, _draft),
            ),
          ),
        ],
      ),
    );
  }

  String _summary(Set<String> s) => s.isEmpty ? '전체' : (s.length == 1 ? s.first : '${s.first} 외 ${s.length - 1}');
}
