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
          ReleaseState.upcoming =>
            k.date.isNotEmpty && k.date.compareTo(today.substring(0, k.date.length.clamp(0, 10))) > 0,
          ReleaseState.thisMonth => k.date.startsWith(today.substring(0, 7)),
          ReleaseState.released =>
            k.date.isNotEmpty && k.date.compareTo(today.substring(0, k.date.length.clamp(0, 10))) <= 0,
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
    if (mine != MineState.any)
      switch (mine) {
        MineState.liked => '좋아요',
        MineState.owned => '구매함',
        _ => '아직 없음',
      },
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
    backgroundColor: Gp.panel,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.62,
      child: FilterSheet(kits: kits, initial: initial),
    ),
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
                const Text(
                  '필터',
                  style: TextStyle(fontSize: Gp.t16, fontWeight: FontWeight.w700),
                ),
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
                _CheckGrid(
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
                  _CheckGrid(
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
                    countOf: (v) => _with(
                      (f) => f.lines
                        ..clear()
                        ..add(v),
                    ),
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
                    countOf: (v) => _with(
                      (f) => f.works
                        ..clear()
                        ..add(v),
                    ),
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
            child: GradientButton(
              label: hits == 0 ? '맞는 상품 없음' : '$hits개 보기', // P01 고르는 동안 개수
              onPressed: hits == 0 ? null : () => Navigator.pop(context, _draft),
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
  const SquareSegments({
    super.key,
    required this.values,
    required this.current,
    required this.child,
    required this.onPick,
  });
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
        borderRadius: BorderRadius.circular(Gp.rSmall),
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
                              borderRadius: BorderRadius.circular(Gp.rSmall),
                              border: Border.all(color: on ? Gp.accent : Gp.line),
                            ),
                            child: on ? const Icon(Icons.check, size: Gp.iS, color: Colors.white) : null,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              v,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: Gp.t14),
                            ),
                          ),
                          Text(
                            '$n',
                            style: const TextStyle(fontSize: Gp.t11, color: Gp.faint),
                          ),
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
            Text(
              title,
              style: const TextStyle(fontSize: Gp.t14, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Text(
              summary,
              style: TextStyle(fontSize: Gp.t12, color: summary == '전체' ? Gp.faint : Gp.accent),
            ),
            const SizedBox(width: 4),
            AnimatedRotation(
              turns: open ? 0.5 : 0,
              duration: const Duration(milliseconds: 150),
              child: const Icon(Icons.expand_more, size: Gp.iM, color: Gp.muted),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 검색창 줄 (홈 · 검색 · 캘린더 · 컬렉션 · My Page 공용) ─────────────────────────────
// 모든 탭이 같은 줄: [검색창][필터][보기 A][보기 B] — 검색창 높이 · 길이, 아이콘 크기 · 자리가 같다

/// 필터 아이콘 — 고른 조건이 있으면 브랜드 색 + 개수 배지. [onTap] 이 null 이면 옅게(그 목록엔 필터 없음)
class FilterButton extends StatelessWidget {
  const FilterButton({super.key, required this.count, required this.onTap});
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ToolIcon(
    icon: Icons.tune,
    tip: '필터',
    onTap: onTap,
    on: onTap != null,
    color: count > 0 ? Gp.accent : null,
    badge: count,
  );
}

/// 검색창 + 오른쪽 아이콘들 — 바깥 여백 · 간격을 한 곳에서
class ToolRow extends StatelessWidget {
  const ToolRow({super.key, required this.field, this.tools = const []});
  final Widget field;
  final List<Widget> tools;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
    child: Row(
      children: [
        Expanded(child: field),
        const SizedBox(width: 4),
        ...tools,
      ],
    ),
  );
}

/// 이 목록 안에서 찾기(카메라 없는 검색창) + 필터 + [tools] — 글자칸을 스스로 가진다
class FindBar extends StatefulWidget {
  const FindBar({
    super.key,
    required this.hint,
    required this.onQuery,
    this.filterCount = 0,
    this.onFilter,
    this.tools = const [],
    this.initial = '',
  });
  final String hint;
  final ValueChanged<String> onQuery;

  /// 처음 글자 (앞 화면에서 찾던 말을 이어서)
  final String initial;
  final int filterCount;
  final VoidCallback? onFilter;

  /// 필터 뒤 (보기 바꾸기 두 칸)
  final List<Widget> tools;

  @override
  State<FindBar> createState() => _FindBarState();
}

class _FindBarState extends State<FindBar> {
  late final _ctrl = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ToolRow(
    field: GpSearchBar(controller: _ctrl, hint: widget.hint, onChanged: (v) => widget.onQuery(v.trim())),
    tools: [
      FilterButton(count: widget.filterCount, onTap: widget.onFilter),
      ...widget.tools,
    ],
  );
}

// ── 도감 필터 (칸이 켜졌나) ────────────────────────────────────────────────────────

enum LitState { any, lit, unlit }

extension LitStateLabel on LitState {
  String get label => switch (this) {
    LitState.any => '전체',
    LitState.lit => '켜진 것',
    LitState.unlit => '아직',
  };

  /// [lit] = 그 칸(작품이면 하나라도) 켜졌나
  bool hit(bool lit) => switch (this) {
    LitState.any => true,
    LitState.lit => lit,
    LitState.unlit => !lit,
  };
}

/// 도감 필터 시트 — 상품 필터와 같은 네모 세그먼트 한 줄
Future<LitState?> showLitFilterSheet(BuildContext context, {required LitState initial}) =>
    showModalBottomSheet<LitState>(
      context: context,
      backgroundColor: Gp.panel,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '도감 필터',
                style: TextStyle(fontSize: Gp.t16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              SquareSegments<LitState>(
                values: LitState.values,
                current: initial,
                child: (v) => Text(v.label, style: const TextStyle(fontSize: Gp.t12)),
                onPick: (v) => Navigator.pop(sheet, v),
              ),
            ],
          ),
        ),
      ),
    );

// ── 도감 필터 (모든 도감 공통: 건담 작품 · 기체 칸 · 베이 · 세계관) ──────────────────────────
// 상품 필터와 같은 모양: 아래 시트(60%) · 네모 세그먼트 · 체크 2열(개수) · 펼치는 줄 · "n개 보기".
// 도감마다 칸 하나를 GuideFacet 으로 바꿔 넘기면, 시트는 그 재료에 있는 값만 보여 준다.

/// 칸 단계 (아직 · 좋아요 · 구매함 · 내 사진)
enum GuideTier { any, none, liked, owned, photo }

/// 정렬 (번호 = 데이터 순서)
enum GuideSort { number, name, kits, recent }

extension GuideSortLabel on GuideSort {
  String get label => switch (this) {
    GuideSort.number => '번호',
    GuideSort.name => '이름',
    GuideSort.kits => '상품 수',
    GuideSort.recent => '최근 구매',
  };
}

/// 도감 칸 하나를 필터가 보는 모양으로
class GuideFacet {
  const GuideFacet({
    required this.name,
    this.tiers = const {},
    this.grades = const {},
    this.types = const {},
    this.group = '',
    this.kits = 0,
    this.boughtAt = '',
  });

  final String name;

  /// 이 칸(작품이면 그 안 기체들)에 있는 단계 — 작품: 구매가 없으면 none, 좋아요가 있으면 liked, 구매가 있으면 owned
  final Set<GuideTier> tiers;

  /// 연결된 상품의 등급 · 라인 (HG · MG · ROBOT魂 · BX …)
  final Set<String> grades;

  /// 기체 종류 (MS · MA · 전함 …)
  final Set<String> types;

  /// 시대 · 작품 · 묶음 이름
  final String group;

  /// 칸을 켜는 상품 수
  final int kits;

  /// 마지막 구매 (updated_at)
  final String boughtAt;
}

/// 도감 필터 조건 (화면 안에서만, 저장하지 않음)
class GuideFilter {
  GuideTier tier = GuideTier.any;
  final Set<String> grades = {};
  final Set<String> types = {};
  final Set<String> groups = {};
  bool withKits = false;
  GuideSort sort = GuideSort.number;

  /// 필터 아이콘 배지 숫자 (정렬도 하나로 센다)
  int get count =>
      (tier == GuideTier.any ? 0 : 1) +
      (grades.isEmpty ? 0 : 1) +
      (types.isEmpty ? 0 : 1) +
      (groups.isEmpty ? 0 : 1) +
      (withKits ? 1 : 0) +
      (sort == GuideSort.number ? 0 : 1);

  bool get active => count > 0;

  bool matches(GuideFacet f) =>
      (tier == GuideTier.any || f.tiers.contains(tier)) &&
      (grades.isEmpty || f.grades.any(grades.contains)) &&
      (types.isEmpty || f.types.any(types.contains)) &&
      (groups.isEmpty || groups.contains(f.group)) &&
      (!withKits || f.kits > 0);

  /// 거르고 정렬 (같은 값끼리는 원래 순서)
  List<T> apply<T>(List<T> items, GuideFacet Function(T) facetOf) {
    final rows = [
      for (final (i, x) in items.indexed)
        if (facetOf(x) case final f when matches(f)) (i, x, f),
    ];
    int by((int, T, GuideFacet) a, (int, T, GuideFacet) b) => switch (sort) {
      GuideSort.number => 0,
      GuideSort.name => a.$3.name.compareTo(b.$3.name),
      GuideSort.kits => b.$3.kits.compareTo(a.$3.kits),
      GuideSort.recent => b.$3.boughtAt.compareTo(a.$3.boughtAt),
    };
    rows.sort((a, b) {
      final c = by(a, b);
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });
    return [for (final r in rows) r.$2];
  }

  /// [keepGroups] = false 면 시대 · 작품 조건은 빼고 (작품 도감 → 기체 칸으로 이어받을 때)
  GuideFilter copy({bool keepGroups = true}) => GuideFilter()
    ..tier = tier
    ..grades.addAll(grades)
    ..types.addAll(types)
    ..groups.addAll(keepGroups ? groups : const <String>{})
    ..withKits = withKits
    ..sort = sort;

  void clear() {
    tier = GuideTier.any;
    grades.clear();
    types.clear();
    groups.clear();
    withKits = false;
    sort = GuideSort.number;
  }
}

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
      _ExpandRow(
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
  }) => _CheckGrid(
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
                _CheckGrid(
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
