// 상품 필터 — 검색 결과 · 전체 목록 · (나중에) 홈 블록이 같이 쓰는 한 벌.
// 아래에서 올라오는 시트(화면의 60%). 캡슐 대신 네모 세그먼트 · 체크 2열 · 펼치는 줄.
//   위 3줄(내 상태 · 발매 · 판매)은 하나만 고르는 세그먼트, 종류는 개수 붙은 체크, 라인 · 작품 · 가격은 한 줄 눌러 펼침.
import 'package:flutter/material.dart';

import 'clock.dart';
import 'models.dart';
import 'theme.dart';
import 'widgets.dart';

enum MineState { any, liked, owned, none }

enum ReleaseState { any, upcoming, thisMonth, released }

enum SaleState { any, regular, limited, pb, base }

enum PriceBand { any, under3k, mid, over10k }

extension PriceBandLabel on PriceBand {
  String get label => switch (this) {
    PriceBand.any => '전체',
    PriceBand.under3k => '¥3,000 이하',
    PriceBand.mid => '¥3,000 – ¥10,000',
    PriceBand.over10k => '¥10,000 이상',
  };

  bool hit(int? p) => switch (this) {
    PriceBand.any => true,
    PriceBand.under3k => p != null && p <= 3000,
    PriceBand.mid => p != null && p > 3000 && p <= 10000,
    PriceBand.over10k => p != null && p > 10000,
  };
}

extension ReleaseStateLabel on ReleaseState {
  String get label => switch (this) {
    ReleaseState.any => '전체',
    ReleaseState.upcoming => '발매 예정',
    ReleaseState.thisMonth => '이번 달',
    ReleaseState.released => '발매됨',
  };
}

extension SaleStateLabel on SaleState {
  String get label => switch (this) {
    SaleState.any => '전체',
    SaleState.regular => '일반',
    SaleState.limited => '한정',
    SaleState.pb => 'PB',
    SaleState.base => '베이스',
  };
}

/// 건담베이스 · 이벤트 한정 (이름에 적혀 있는 것)
bool isBaseOrEvent(Kit k) {
  final n = '${k.nameJa} ${k.name}';
  return n.contains('ガンダムベース') || n.contains('GUNDAM BASE') || n.contains('イベント') || n.contains('EXPO');
}

String _today() => appNow().toIso8601String().substring(0, 10);

/// 필터 조건 (이 목록 안에서만, 저장하지 않음)
class KitFilter {
  KitFilter({
    Set<String>? works,
    Set<String>? types,
    Set<String>? lines,
    Set<String>? goodsKinds,
    this.mine = MineState.any,
    this.release = ReleaseState.any,
    this.sale = SaleState.any,
    this.price = PriceBand.any,
  }) : works = works ?? {},
       types = types ?? {},
       lines = lines ?? {},
       goodsKinds = goodsKinds ?? {};

  final Set<String> works;
  final Set<String> types;
  final Set<String> lines;

  /// 굿즈 세부 종류 (굿즈를 고르면 보인다)
  final Set<String> goodsKinds;
  MineState mine;
  ReleaseState release;
  SaleState sale;
  PriceBand price;

  /// 내 상태(좋아요 · 구매함)를 읽는 곳 — 화면이 Marks 로 채운다
  CollectStatus Function(Kit)? statusOf;

  KitFilter copy() => KitFilter(
    works: {...works},
    types: {...types},
    lines: {...lines},
    goodsKinds: {...goodsKinds},
    mine: mine,
    release: release,
    sale: sale,
    price: price,
  )..statusOf = statusOf;

  int get count =>
      works.length +
      types.length +
      lines.length +
      goodsKinds.length +
      (mine == MineState.any ? 0 : 1) +
      (release == ReleaseState.any ? 0 : 1) +
      (sale == SaleState.any ? 0 : 1) +
      (price == PriceBand.any ? 0 : 1);

  bool matches(Kit k) {
    if (works.isNotEmpty && !works.contains(kitWork(k))) return false;
    if (types.isNotEmpty && !types.contains(k.type)) return false;
    if (lines.isNotEmpty && !lines.contains(k.line)) return false;
    if (goodsKinds.isNotEmpty && !goodsKinds.contains(k.goodsKind)) return false;
    if (!price.hit(k.priceJpy)) return false;
    final st = statusOf?.call(k) ?? k.status;
    final today = _today();
    return switch (mine) {
          MineState.any => true,
          MineState.liked => st == CollectStatus.wanted,
          MineState.owned => st == CollectStatus.owned,
          MineState.none => st == CollectStatus.none,
        } &&
        switch (release) {
          ReleaseState.any => true,
          ReleaseState.upcoming => k.date.isNotEmpty && k.date.compareTo(today.substring(0, k.date.length.clamp(0, 10))) > 0,
          ReleaseState.thisMonth => k.date.startsWith(today.substring(0, 7)),
          ReleaseState.released => k.date.isNotEmpty && k.date.compareTo(today.substring(0, k.date.length.clamp(0, 10))) <= 0,
        } &&
        switch (sale) {
          SaleState.any => true,
          SaleState.regular => !k.limited && !k.pb,
          SaleState.limited => k.limited || k.pb,
          SaleState.pb => k.pb,
          SaleState.base => isBaseOrEvent(k),
        };
  }

  /// 고른 조건 한 줄 ("SEED · HG · PB")
  List<String> get labels => [
    if (mine != MineState.any) switch (mine) { MineState.liked => '좋아요', MineState.owned => '구매함', _ => '아직 없음' },
    if (release != ReleaseState.any) release.label,
    if (sale != SaleState.any) sale.label,
    ...works,
    ...types,
    ...lines,
    ...goodsKinds,
    if (price != PriceBand.any) price.label,
  ];
}

/// 값별 개수, 많은 순
List<(String, int)> valueCounts(Iterable<String> values) {
  final m = <String, int>{};
  for (final v in values) {
    if (v.isNotEmpty) m[v] = (m[v] ?? 0) + 1;
  }
  return [for (final e in m.entries) (e.key, e.value)]..sort((a, b) => b.$2.compareTo(a.$2));
}

/// 필터 시트 열기 — 고르면 새 조건, 닫으면 null
Future<KitFilter?> showFilterSheet(BuildContext context, {required List<Kit> kits, required KitFilter initial}) {
  return showModalBottomSheet<KitFilter>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Gp.panel,
    builder: (_) => FractionallySizedBox(heightFactor: 0.62, child: FilterSheet(kits: kits, initial: initial)),
  );
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
    return SafeArea(
      top: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 4),
            child: Row(
              children: [
                const Text('필터', style: TextStyle(fontSize: Gp.t16, fontWeight: FontWeight.w700)),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() {
                    _draft
                      ..goodsKinds.clear()
                      ..works.clear()
                      ..types.clear()
                      ..lines.clear()
                      ..mine = MineState.any
                      ..release = ReleaseState.any
                      ..sale = SaleState.any
                      ..price = PriceBand.any;
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
                SquareSegments<MineState>(
                  values: MineState.values,
                  current: _draft.mine,
                  child: (v) => switch (v) {
                    MineState.any => const Text('전체'),
                    MineState.liked => const Icon(Icons.favorite, size: 16, color: Gp.accent),
                    MineState.owned => const RibbonIcon(size: 15),
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
                _CheckGrid(
                  values: valueCounts(kits.map((k) => k.type)).map((e) => e.$1).toList(),
                  selected: _draft.types,
                  countOf: (v) => _with((f) => f.types
                    ..clear()
                    ..add(v)),
                  onToggle: (v) => _toggle(_draft.types, v),
                ),
                // 굿즈를 고르면 세부 종류 (티켓 · 의류 · 블루레이 …)
                if (_draft.types.contains('굿즈') && kits.any((k) => k.goodsKind.isNotEmpty)) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(2, 10, 0, 2),
                    child: Text('굿즈 종류', style: TextStyle(fontSize: Gp.t12, color: Gp.muted)),
                  ),
                  _CheckGrid(
                    values: valueCounts(kits.map((k) => k.goodsKind)).map((e) => e.$1).toList(),
                    selected: _draft.goodsKinds,
                    countOf: (v) => _with((f) => f.goodsKinds
                      ..clear()
                      ..add(v)),
                    onToggle: (v) => _toggle(_draft.goodsKinds, v),
                  ),
                ],
                const Divider(height: 20),
                _ExpandRow(
                  title: '라인',
                  summary: _summary(_draft.lines),
                  open: _open == '라인',
                  onTap: () => setState(() => _open = _open == '라인' ? '' : '라인'),
                ),
                if (_open == '라인')
                  _CheckGrid(
                    values: valueCounts(kits.map((k) => k.line)).map((e) => e.$1).toList(),
                    selected: _draft.lines,
                    countOf: (v) => _with((f) => f.lines
                      ..clear()
                      ..add(v)),
                    onToggle: (v) => _toggle(_draft.lines, v),
                  ),
                _ExpandRow(
                  title: '작품',
                  summary: _summary(_draft.works),
                  open: _open == '작품',
                  onTap: () => setState(() => _open = _open == '작품' ? '' : '작품'),
                ),
                if (_open == '작품')
                  _CheckGrid(
                    columns: 1,
                    values: valueCounts(kits.map(kitWork)).map((e) => e.$1).toList(),
                    selected: _draft.works,
                    countOf: (v) => _with((f) => f.works
                      ..clear()
                      ..add(v)),
                    onToggle: (v) => _toggle(_draft.works, v),
                  ),
                _ExpandRow(
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
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: FilledButton(
              onPressed: hits == 0 ? null : () => Navigator.pop(context, _draft),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(hits == 0 ? '맞는 상품 없음' : '$hits개 보기'), // P01 고르는 동안 개수
            ),
          ),
        ],
      ),
    );
  }

  String _summary(Set<String> s) => s.isEmpty ? '전체' : (s.length == 1 ? s.first : '${s.first} 외 ${s.length - 1}');
}

/// 네모 세그먼트 (캡슐 대신) — 한 줄에 하나만 고름. 필터 · 홈 · 캘린더가 같이 쓴다
class SquareSegments<T> extends StatelessWidget {
  const SquareSegments({super.key, required this.values, required this.current, required this.child, required this.onPick});
  final List<T> values;
  final T current;
  final Widget Function(T) child;
  final ValueChanged<T> onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        border: Border.all(color: Gp.line),
        borderRadius: BorderRadius.circular(7),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          for (final (i, v) in values.indexed) ...[
            if (i > 0) const VerticalDivider(width: 1, color: Gp.line),
            Expanded(
              child: Material(
                color: v == current ? Gp.accent.withValues(alpha: 0.12) : Gp.panel,
                child: InkWell(
                  onTap: () => onPick(v),
                  child: Center(
                    child: DefaultTextStyle.merge(
                      style: TextStyle(
                        fontSize: Gp.t12,
                        fontWeight: v == current ? FontWeight.w700 : FontWeight.w400,
                        color: v == current ? Gp.accent : Gp.muted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      child: child(v),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 체크 칸 2열 (이름 · 개수 · 네모 체크)
class _CheckGrid extends StatelessWidget {
  const _CheckGrid({
    required this.values,
    required this.selected,
    required this.countOf,
    required this.onToggle,
    this.columns = 2,
  });
  final List<String> values;
  final Set<String> selected;
  final int Function(String) countOf;
  final ValueChanged<String> onToggle;
  final int columns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => Wrap(
        children: [
          for (final v in values)
            SizedBox(
              width: box.maxWidth / columns,
              child: () {
                final on = selected.contains(v);
                final n = countOf(v);
                return Opacity(
                  opacity: n == 0 && !on ? 0.4 : 1,
                  child: InkWell(
                    onTap: () => onToggle(v),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: on ? Gp.accent : Gp.panel,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: on ? Gp.accent : Gp.line),
                            ),
                            child: on ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(v, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: Gp.t14)),
                          ),
                          Text('$n', style: const TextStyle(fontSize: Gp.t11, color: Gp.faint)),
                          const SizedBox(width: 10),
                        ],
                      ),
                    ),
                  ),
                );
              }(),
            ),
        ],
      ),
    );
  }
}

/// 한 줄 눌러 펼치기 (라인 · 작품 · 가격)
class _ExpandRow extends StatelessWidget {
  const _ExpandRow({required this.title, required this.summary, required this.open, required this.onTap});
  final String title;
  final String summary;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Text(title, style: const TextStyle(fontSize: Gp.t14, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(summary, style: TextStyle(fontSize: Gp.t12, color: summary == '전체' ? Gp.faint : Gp.accent)),
            const SizedBox(width: 4),
            AnimatedRotation(
              turns: open ? 0.5 : 0,
              duration: const Duration(milliseconds: 150),
              child: const Icon(Icons.expand_more, size: 20, color: Gp.muted),
            ),
          ],
        ),
      ),
    );
  }
}
