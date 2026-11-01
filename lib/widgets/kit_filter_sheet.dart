// 상품 필터 시트 — 검색 결과 · 전체 목록 · 홈 · 캘린더 · 컬렉션이 같이 쓰는 한 벌.
// 아래에서 올라오는 시트(화면의 60%). 캡슐 대신 네모 세그먼트 · 체크 2열 · 펼치는 줄.
//   위 3줄(내 상태 · 발매 · 판매)은 하나만 고르는 세그먼트, 종류는 개수 붙은 체크, 라인 · 작품 · 가격은 한 줄 눌러 펼침.
// 거르는 규칙(KitFilter.matches)은 lib/logic/kit_filter.dart
import 'package:flutter/material.dart';

import '../logic/kit_filter.dart';
import '../logic/kit_rules.dart';
import '../models.dart';
import '../theme.dart';
import 'icons.dart';
import 'sheets.dart';

export '../logic/kit_filter.dart';

/// 필터 시트 열기 — 고르면 새 조건, 닫으면 null
Future<KitFilter?> showFilterSheet(BuildContext context, {required List<Kit> kits, required KitFilter initial}) =>
    showGpSheet<KitFilter>(
      context,
      heightFactor: gpSheetHeight,
      builder: (_) => FilterSheet(kits: kits, initial: initial),
    );

class FilterSheet extends StatefulWidget {
  const FilterSheet({super.key, required this.kits, required this.initial});
  final List<Kit> kits;
  final KitFilter initial;

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late final KitFilter _draft = widget.initial.copy();

  /// 펼친 줄 (라인 · 작품 · 가격)
  String _open = '';

  int _hits(KitFilter f) => widget.kits.where(f.matches).length;

  int _with(void Function(KitFilter) change) {
    final f = _draft.copy();
    change(f);
    return _hits(f);
  }

  void _toggle(Set<String> set, String v) => setState(() => set.contains(v) ? set.remove(v) : set.add(v));

  @override
  Widget build(BuildContext context) {
    final kits = widget.kits;
    final hits = _hits(_draft);
    return GpPickSheet(
      title: '필터',
      hits: hits,
      noHitLabel: '맞는 상품 없음',
      onApply: () => Navigator.pop(context, _draft),
      onReset: () => setState(() {
        _draft.clear();
        _open = '';
      }),
      children: [
        SquareSegments<MineState>(
          values: MineState.values,
          current: _draft.mine,
          child: (v) => switch (v) {
            MineState.any => const Text('전체'),
            MineState.liked => const LikedIcon(),
            MineState.owned => const OwnedIcon(size: Gp.iS),
            MineState.none => const Text('아직 없음'),
          },
          onPick: (v) => setState(() => _draft.mine = v),
        ),
        const SizedBox(height: 8),
        SquareSegments<ReleaseState>(
          values: ReleaseState.values,
          current: _draft.release,
          child: (v) => Text(v.label),
          onPick: (v) => setState(() => _draft.release = v),
        ),
        const SizedBox(height: 8),
        SquareSegments<SaleState>(
          values: SaleState.values,
          current: _draft.sale,
          child: (v) => Text(v.label),
          onPick: (v) => setState(() => _draft.sale = v),
        ),
        const SizedBox(height: 12),
        CheckGrid(
          values: valueCounts(kits.map((k) => k.type)).map((e) => e.$1).toList(),
          selected: _draft.types,
          countOf: (v) => _with(
            (f) => f.types
              ..clear()
              ..add(v),
          ),
          onToggle: (v) => _toggle(_draft.types, v),
        ),
        // 굿즈를 고르면 세부 종류 (티켓 · 의류 · 블루레이 …)
        if (_draft.types.contains('굿즈') && kits.any((k) => k.goodsKind.isNotEmpty)) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(2, 10, 0, 2),
            child: Text(
              '굿즈 종류',
              style: TextStyle(fontSize: Gp.t12, color: Gp.muted),
            ),
          ),
          CheckGrid(
            values: valueCounts(kits.map((k) => k.goodsKind)).map((e) => e.$1).toList(),
            selected: _draft.goodsKinds,
            countOf: (v) => _with(
              (f) => f.goodsKinds
                ..clear()
                ..add(v),
            ),
            onToggle: (v) => _toggle(_draft.goodsKinds, v),
          ),
        ],
        const Divider(height: 20),
        ExpandRow(
          title: '라인',
          summary: pickSummary(_draft.lines),
          open: _open == '라인',
          onTap: () => setState(() => _open = _open == '라인' ? '' : '라인'),
        ),
        if (_open == '라인')
          CheckGrid(
            values: valueCounts(kits.map((k) => k.line)).map((e) => e.$1).toList(),
            selected: _draft.lines,
            countOf: (v) => _with(
              (f) => f.lines
                ..clear()
                ..add(v),
            ),
            onToggle: (v) => _toggle(_draft.lines, v),
          ),
        ExpandRow(
          title: '작품',
          summary: pickSummary(_draft.works),
          open: _open == '작품',
          onTap: () => setState(() => _open = _open == '작품' ? '' : '작품'),
        ),
        if (_open == '작품')
          CheckGrid(
            columns: 1,
            values: valueCounts(kits.map(kitWork)).map((e) => e.$1).toList(),
            selected: _draft.works,
            countOf: (v) => _with(
              (f) => f.works
                ..clear()
                ..add(v),
            ),
            onToggle: (v) => _toggle(_draft.works, v),
          ),
        ExpandRow(
          title: '가격',
          summary: _draft.price.label,
          open: _open == '가격',
          onTap: () => setState(() => _open = _open == '가격' ? '' : '가격'),
        ),
        if (_open == '가격')
          SquareSegments<PriceBand>(
            values: PriceBand.values,
            current: _draft.price,
            child: (v) => Text(v == PriceBand.mid ? '3천–1만' : v.label.replaceAll(',000', '천')),
            onPick: (v) => setState(() => _draft.price = v),
          ),
      ],
    );
  }
}
