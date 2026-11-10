// 상품 필터 시트 — 검색 결과 · 전체 목록 · 홈 · 캘린더 · 컬렉션이 같이 쓰는 한 벌.
// 아래에서 올라오는 시트(화면의 60%). 캡슐 대신 네모 세그먼트 · 체크 2열 · 펼치는 줄. 도감 필터도 같은 틀 · 같은 상태 줄.
//   위 3줄(내 상태 · 발매 · 판매)은 하나만 고르는 세그먼트, 종류는 개수 붙은 체크, 라인 · 작품 · 기간 · 가격은 한 줄 눌러 펼침.
// 거르는 규칙(KitFilter.matches)은 lib/logic/kit_filter.dart
import 'package:flutter/material.dart';

import '../clock.dart';
import '../format.dart';
import '../logic/kit_filter.dart';
import '../logic/kit_rules.dart';
import '../marks.dart';
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

/// 필터 시트를 열어 고른 조건을 돌려준다 (닫으면 null). 내 상태(좋아요 · 구매함)는 앱 전체 Marks 로 센다
Future<KitFilter?> pickKitFilter(BuildContext context, {required List<Kit> pool, required KitFilter current}) {
  current.statusOf = Marks.read(context).statusOf;
  return showFilterSheet(context, kits: pool, initial: current);
}

/// 목록 안 찾기 글자 + 상품 필터 한 벌 (컬렉션 · 캘린더 · My Page). 값만 들고, 다시 그리기는 화면의 setState
class KitFind {
  String query = '';
  KitFilter filter = KitFilter();

  /// 찾기나 필터가 걸려 있다
  bool get active => query.isNotEmpty || filter.count > 0;

  void clear() {
    query = '';
    filter = KitFilter();
  }

  /// 찾기 글자에 맞나
  bool hitText(Kit k) => kitMatches(k, query);

  /// 찾기 + 필터에 맞나. 먼저 [watch] 로 내 상태를 이어 둔다
  bool hit(Kit k) => kitMatches(k, query) && filter.matches(k);

  /// build 안에서: 필터의 내 상태 = 지금 Marks (좋아요 · 구매함이 바뀌면 다시 그린다)
  void watch(BuildContext context) => filter.statusOf = Marks.of(context).statusOf;

  /// 찾기 글자에 맞는 [kits] 로 필터 시트를 연다. 골랐으면 true (화면이 setState)
  Future<bool> openFilter(BuildContext context, Iterable<Kit> kits) async {
    final f = await pickKitFilter(
      context,
      pool: [
        for (final k in kits)
          if (hitText(k)) k,
      ],
      current: filter,
    );
    if (f == null) return false;
    filter = f;
    return true;
  }
}

/// 상태 줄 한 칸 (전체 · ♡ · 리본 · 아직 없음) — 상품 · 도감 · 태그 필터가 같은 말 · 같은 아이콘
class MineStateLabel extends StatelessWidget {
  const MineStateLabel(this.state, {super.key});
  final MineState state;

  @override
  Widget build(BuildContext context) => switch (state) {
    MineState.any => const Text('전체'),
    MineState.liked => const Tooltip(message: '좋아요', child: LikedIcon()),
    MineState.owned => const Tooltip(message: '구매함', child: OwnedIcon()),
    MineState.none => const Text('아직 없음'),
  };
}

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
          child: MineStateLabel.new,
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
          title: '기간',
          summary: periodLabel(_draft.from, _draft.to).isEmpty ? '전체' : periodLabel(_draft.from, _draft.to),
          open: _open == '기간',
          onTap: () => setState(() => _open = _open == '기간' ? '' : '기간'),
        ),
        if (_open == '기간')
          _PeriodPicker(
            from: _draft.from,
            to: _draft.to,
            onChanged: (from, to) => setState(() {
              _draft.from = from; // STATE: 기간 → 맞는 상품 수 · 「n개 보기」
              _draft.to = to;
            }),
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

/// 필터 「기간」 — 빠른 고르기(전체 · 올해 · 작년 · 최근 1년) + 시작 · 끝 달 (발매일 기준, 달 단위)
class _PeriodPicker extends StatelessWidget {
  const _PeriodPicker({required this.from, required this.to, required this.onChanged});
  final String from;
  final String to;
  final void Function(String from, String to) onChanged;

  @override
  Widget build(BuildContext context) {
    final today = dayKey(appNow());
    PeriodPreset? preset;
    for (final p in PeriodPreset.values) {
      final r = p.range(today);
      if (r.$1 == from && r.$2 == to) preset = p;
    }
    Future<void> pick({required bool start}) async {
      final now = start ? from : to;
      final v = await pickMonth(
        context,
        title: start ? '시작 달' : '끝 달',
        initial: now.isEmpty ? today.substring(0, 7) : now,
      );
      if (v == null) return;
      var f = start ? v : from;
      var t = start ? to : v;
      // 시작이 끝보다 늦으면 둘을 같은 달로
      if (f.isNotEmpty && t.isNotEmpty && f.compareTo(t) > 0) {
        if (start) {
          t = f;
        } else {
          f = t;
        }
      }
      onChanged(f, t);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          SquareSegments<PeriodPreset?>(
            values: PeriodPreset.values,
            current: preset,
            child: (v) => Text(v!.label),
            onPick: (v) {
              final r = v!.range(today);
              onChanged(r.$1, r.$2);
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _MonthButton(
                  key: const ValueKey('period-from'),
                  label: '시작',
                  value: from,
                  onTap: () => pick(start: true),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('–', style: TextStyle(color: Gp.muted)),
              ),
              Expanded(
                child: _MonthButton(
                  key: const ValueKey('period-to'),
                  label: '끝',
                  value: to,
                  onTap: () => pick(start: false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthButton extends StatelessWidget {
  const _MonthButton({super.key, required this.label, required this.value, required this.onTap});
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(40),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(Gp.rSmall))),
    ),
    child: Text(
      value.isEmpty ? '$label  ·  열어 둠' : '$label  ${monthDot(value)}',
      style: TextStyle(fontSize: Gp.t12, color: value.isEmpty ? Gp.muted : Gp.ink),
    ),
  );
}

/// 달 고르기 시트 — 위에 ‹ 해 ›, 아래 1–12월, 「정하지 않기」= 빈 글자. 그냥 닫으면 null
Future<String?> pickMonth(BuildContext context, {required String title, required String initial}) =>
    showGpSheet<String>(
      context,
      builder: (_) => _MonthSheet(title: title, initial: initial),
    );

class _MonthSheet extends StatefulWidget {
  const _MonthSheet({required this.title, required this.initial});
  final String title;
  final String initial;

  @override
  State<_MonthSheet> createState() => _MonthSheetState();
}

class _MonthSheetState extends State<_MonthSheet> {
  late int _year = int.parse(widget.initial.substring(0, 4));
  late final int _month = int.parse(widget.initial.substring(5, 7));
  late final int _initialYear = _year;

  @override
  Widget build(BuildContext context) {
    final thisYear = appNow().year;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gp.gutter, 16, Gp.gutter, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.title,
            style: const TextStyle(fontSize: Gp.t16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: '작년',
                onPressed: _year > 1980 ? () => setState(() => _year--) : null, // STATE: 해 → 달 칸
                icon: const Icon(Icons.chevron_left, size: Gp.iL),
              ),
              SizedBox(
                width: 96,
                child: Text(
                  '$_year',
                  key: const ValueKey('month-sheet-year'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: Gp.t19, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: '다음 해',
                onPressed: _year < thisYear + 3 ? () => setState(() => _year++) : null,
                icon: const Icon(Icons.chevron_right, size: Gp.iL),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.2,
            children: [
              for (var m = 1; m <= 12; m++)
                OutlinedButton(
                  key: ValueKey('month-$m'),
                  onPressed: () => Navigator.pop(context, '$_year-${m.toString().padLeft(2, '0')}'),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: _year == _initialYear && m == _month ? Gp.accent.withValues(alpha: 0.12) : null,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(Gp.rSmall))),
                  ),
                  child: Text('$m월', style: const TextStyle(fontSize: Gp.t14)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: () => Navigator.pop(context, ''), child: const Text('정하지 않기 (열어 두기)')),
        ],
      ),
    );
  }
}
