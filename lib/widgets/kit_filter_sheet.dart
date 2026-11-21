// 상품 필터 시트 — 검색 결과 · 전체 목록 · 홈 · 캘린더 · 컬렉션이 같이 쓰는 한 벌.
// 아래에서 올라오는 시트(화면의 60%). 캡슐 대신 아이콘 줄 · 체크 2열 · 펼치는 줄. 도감 필터도 같은 틀 · 같은 상태 줄.
//   맨 위 아이콘 줄(좋아요 · 구매함 · 발매 예정, 나라가 섞인 목록이면 + 나라)은 [KitFilterToggles] — 검색 탭도 이제 시트 안
//   (2026-11-21 탭에서 검색창을 빼며 되돌림).
//   체크 칸은 이름을 누르면 고르고 오른쪽 × 를 누르면 뺀다 (「MG · HG 제외」 — 접은 줄 요약에도 보인다).
//   맞는 상품이 없는 칸 · 값이 하나뿐인 줄 · 정가가 없는 목록의 가격 줄은 숨긴다 (회색 칸을 두지 않기).
//   가격은 원 · 엔이 섞인 목록이면 돈을 먼저 고른다 (환산하지 않음).
// 거르는 규칙(KitFilter.matches)은 lib/logic/kit_filter.dart
import 'package:flutter/material.dart';

import '../clock.dart';
import '../format.dart';
import '../l10n/l10n.dart';
import '../logic/data_labels.dart';
import '../logic/filter_carryover.dart';
import '../logic/kit_filter.dart';
import '../logic/kit_rules.dart';
import '../marks.dart';
import '../models.dart';
import '../theme.dart';
import 'icons.dart';
import 'sheets.dart';

export '../logic/filter_carryover.dart';
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

/// 필터 시트를 열고, 작품이 바뀌었으면 남은 조건을 이어 쓴다 (닫으면 null).
/// 돌려준 [FilterCarry] 를 화면이 들고 있다가 탭 줄 「이어 씀 n」([CarryNote])으로 보인다
Future<FilterCarry?> pickKitFilterCarry(
  BuildContext context, {
  required List<Kit> pool,
  required KitFilter current,
}) async {
  final before = current.copy();
  final picked = await pickKitFilter(context, pool: pool, current: current);
  if (picked == null) return null;
  return carryFilter(pool, before, picked);
}

/// 목록 안 상품 필터 한 벌 (컬렉션 · 캘린더). 값만 들고, 다시 그리기는 화면의 setState.
/// 찾기 글자는 없다 — 탭 안 찾기 칸을 빼고 위 줄 🔍 검색 덮개 하나로 (2026-11-21)
class KitFind {
  KitFilter _filter = KitFilter();

  KitFilter get filter => _filter;

  /// 조건을 밖에서 갈아 끼우면(「필터 초기화」) 이어 쓴 알림도 같이 사라진다 —
  /// 남겨 두면 그 × 가 방금 지운 조건을 되살린다 ([apply] 는 알림과 짝이라 그대로 둔다)
  set filter(KitFilter f) {
    _filter = f;
    carry = null;
  }

  /// 작품을 바꿀 때 이어 쓴 조건 (탭 줄 「이어 씀 n」 — 아직 바꾼 적이 없으면 null)
  FilterCarry? carry;

  /// 필터가 걸려 있다
  bool get active => filter.count > 0;

  /// 필터에 맞나. 먼저 [watch] 로 내 상태를 이어 둔다
  bool hit(Kit k) => filter.matches(k);

  /// build 안에서: 필터의 내 상태 = 지금 Marks (좋아요 · 구매함이 바뀌면 다시 그린다)
  void watch(BuildContext context) => filter.statusOf = Marks.of(context).statusOf;

  /// [kits] 로 필터 시트를 연다. 골랐으면 true (화면이 setState)
  Future<bool> openFilter(BuildContext context, Iterable<Kit> kits) async {
    final c = await pickKitFilterCarry(context, pool: kits.toList(), current: filter);
    if (c == null) return false;
    apply(c);
    return true;
  }

  /// 이어 쓴 결과로 갈아 끼우기 (필터 시트 · 「이어 씀」 줄에서 지울 때)
  void apply(FilterCarry c) {
    _filter = c.filter;
    carry = c;
  }
}

/// 상태 줄 한 칸 (전체 · ♡ · 리본 · 아직 없음) — 도감 · 태그 필터가 같은 말 · 같은 아이콘
class MineStateLabel extends StatelessWidget {
  const MineStateLabel(this.state, {super.key});
  final MineState state;

  @override
  Widget build(BuildContext context) => switch (state) {
    MineState.any => Text(tr('전체')),
    MineState.liked => Tooltip(message: tr('좋아요'), child: const LikedIcon()),
    MineState.owned => Tooltip(message: tr('구매함'), child: const OwnedIcon()),
    MineState.none => Text(tr('아직 없음')),
  };
}

/// 상품 필터 아이콘 줄 — ♡ 좋아요 · 리본 구매함 · 발매 예정 · 나라(전체 → 한국 → 일본, 두 나라가 섞인 목록에만).
/// 캡슐 · 칩 없이 아이콘만: 고르면 채운 아이콘 + 색, 다시 누르면 풀린다. 검색 탭은 검색창 아래, 다른 화면은 필터 시트 맨 위.
/// 누를 때마다 새 조건(복사)을 [onChanged] 로
class KitFilterToggles extends StatelessWidget {
  const KitFilterToggles({super.key, required this.filter, required this.regions, required this.onChanged});
  final KitFilter filter;

  /// 한국 · 일본 상품이 섞인 목록 ([hasBothRegions]) — 아니면 나라 칸을 숨긴다
  final bool regions;
  final ValueChanged<KitFilter> onChanged;

  void _set(void Function(KitFilter) change) {
    final f = filter.copy()..dropHidden();
    change(f);
    onChanged(f);
  }

  @override
  Widget build(BuildContext context) {
    final liked = filter.mine == MineState.liked;
    final owned = filter.mine == MineState.owned;
    final upcoming = filter.release == ReleaseState.upcoming;
    final region = filter.region;
    return Row(
      key: const ValueKey('filter-toggles'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _Toggle(
          key: const ValueKey('toggle-liked'),
          tip: tr('좋아요'),
          on: liked,
          icon: LikedIcon(filled: liked, size: Gp.iM, color: liked ? Gp.accent : Gp.muted),
          onTap: () => _set((f) => f.mine = liked ? MineState.any : MineState.liked),
        ),
        _Toggle(
          key: const ValueKey('toggle-owned'),
          tip: tr('구매함'),
          on: owned,
          icon: OwnedIcon(filled: owned, size: Gp.iM, color: owned ? Gp.own : Gp.muted),
          onTap: () => _set((f) => f.mine = owned ? MineState.any : MineState.owned),
        ),
        _Toggle(
          key: const ValueKey('toggle-upcoming'),
          tip: tr('발매 예정'),
          on: upcoming,
          icon: Icon(
            upcoming ? Icons.watch_later : Icons.watch_later_outlined,
            size: Gp.iM,
            color: upcoming ? Gp.accent : Gp.muted,
          ),
          onTap: () => _set((f) => f.release = upcoming ? ReleaseState.any : ReleaseState.upcoming),
        ),
        // 나라 — 두 나라 상품이 섞인 목록에서만 (포켓몬 · 전체 채널). 이미 골라 두었으면 풀 수 있게 남긴다
        if (regions || region != SaleRegion.any)
          _Toggle(
            key: const ValueKey('toggle-region'),
            tip: region == SaleRegion.any ? '${tr('한국')} · ${tr('일본')}' : region.label,
            on: region != SaleRegion.any,
            icon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.public, size: Gp.iM, color: region == SaleRegion.any ? Gp.muted : Gp.accent),
                if (region != SaleRegion.any) ...[
                  const SizedBox(width: 3),
                  Text(
                    region.label,
                    style: const TextStyle(fontSize: Gp.t12, fontWeight: FontWeight.w700, color: Gp.accent),
                  ),
                ],
              ],
            ),
            onTap: () => _set(
              (f) => f.region = switch (region) {
                SaleRegion.any => SaleRegion.kr,
                SaleRegion.kr => SaleRegion.jp,
                SaleRegion.jp => SaleRegion.any,
              },
            ),
          ),
      ],
    );
  }
}

/// 아이콘 줄 한 칸 — 누르는 자리 40, 그림은 아이콘만 (읽어 주기는 이름 + 고름)
class _Toggle extends StatelessWidget {
  const _Toggle({super.key, required this.tip, required this.on, required this.icon, required this.onTap});
  final String tip;
  final bool on;
  final Widget icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    toggled: on,
    label: tip,
    excludeSemantics: true,
    child: Tooltip(
      message: tip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Gp.radius),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 40, minHeight: 36),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(widthFactor: 1, child: icon),
          ),
        ),
      ),
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
  // 화면에서 뺀 칸(아직 없음 · 이번 달 · 판매)이 걸려 있던 조건은 열 때 푼다
  late KitFilter _draft = widget.initial.copy()..dropHidden();

  /// 펼친 줄 (작품 · 라인 · 기간 · 가격)
  String _open = '';

  /// 기간 달 고르기의 가장 이른 해 — 이 목록에서 가장 오래된 발매일 (레고 전부면 1949)
  late final int _minYear = earliestYear(widget.kits.map((k) => k.date));

  /// 작품 묶음 → 화면 이름 (중국어 화면이면 작품 중국어 이름)
  late final Map<String, String> _workNames = {
    ...widget.initial.workNames,
    for (final k in widget.kits) kitWork(k): kitWorkLabel(k),
  };

  /// 고른 값 · 뺀 값 한 줄 요약 — 라인 · 종류는 번역 표로, 작품은 [_workNames] 로.
  /// 뺀 값의 모양은 고른 조건 한 줄과 같은 [outSummary]
  String _summary(Set<String> picked, Set<String> out, {bool works = false}) {
    final name = works ? _workName : dataLabel;
    if (out.isEmpty) return pickSummary(picked, label: name);
    return joinDot([if (picked.isNotEmpty) pickSummary(picked, label: name), outSummary(out, label: name)]);
  }

  String _workName(String work) => _workNames[work] ?? work;

  int _hits(KitFilter f) => widget.kits.where(f.matches).length;

  int _with(void Function(KitFilter) change) {
    final f = _draft.copy();
    change(f);
    return _hits(f);
  }

  /// 이 값 하나만 골랐을 때의 수 — 같은 줄에서 뺀 값은 풀고 센다 (뺀 칸도 수가 있으면 보인다)
  int _only(String v, Set<String> Function(KitFilter) pick, Set<String> Function(KitFilter) out) => _with((f) {
    out(f).clear();
    pick(f)
      ..clear()
      ..add(v);
  });

  /// 체크 칸 하나 켜고 끄기 — 고르기와 빼기는 한 값에 한쪽만 ([togglePick])
  void _toggle(Set<String> set, Set<String> other, String v) => setState(() => togglePick(set, other, v));

  /// 체크 칸에 보일 값 — 맞는 상품이 없는 값은 숨긴다 ([liveValues])
  List<String> _live(
    String Function(Kit) valueOf,
    Set<String> Function(KitFilter) field,
    Set<String> Function(KitFilter) outField,
  ) => liveValues(widget.kits, _draft, valueOf, field, outField: outField);

  /// 한국 · 일본 상품이 섞인 목록 (나라 칸을 보인다)
  late final bool _regions = hasBothRegions(widget.kits);

  /// 원 · 엔 정가가 섞인 목록 (가격의 돈 칸을 보인다)
  late final bool _currencies = hasBothCurrencies(widget.kits);

  /// 정가가 있는 상품이 하나라도 있다 (없으면 가격 줄을 숨긴다)
  late final bool _prices = hasAnyPrice(widget.kits);

  @override
  Widget build(BuildContext context) {
    final kits = widget.kits;
    final hits = _hits(_draft);
    final currency = currencyFor(kits, _draft.preferredCurrency);
    final lines = _live((k) => k.line, (f) => f.lines, (f) => f.linesOut);
    final works = _live(kitWork, (f) => f.works, (f) => f.worksOut);
    return GpPickSheet(
      // 작품 하나만 고른 채로 열면 어느 작품을 보는지 제목에 ("필터 · SEED")
      title: _draft.works.length == 1 ? joinDot([tr('필터'), _workName(_draft.works.first)]) : tr('필터'),
      hits: hits,
      noHitLabel: tr('맞는 상품 없음'),
      onApply: () => Navigator.pop(context, _draft..workNames.addAll(_workNames)),
      onReset: () => setState(() {
        _draft.clear();
        _open = '';
      }),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: KitFilterToggles(
            filter: _draft,
            regions: _regions,
            onChanged: (f) => setState(() => _draft = f), // STATE: 아이콘 줄 → 맞는 상품 수 · 보일 칸
          ),
        ),
        const SizedBox(height: 8),
        CheckGrid(
          key: const ValueKey('filter-types'),
          values: _live((k) => k.type, (f) => f.types, (f) => f.typesOut),
          selected: _draft.types,
          excluded: _draft.typesOut,
          label: dataLabel,
          countOf: (v) => _only(v, (f) => f.types, (f) => f.typesOut),
          onToggle: (v) {
            _toggle(_draft.types, _draft.typesOut, v);
            _draft.dropHidden(); // 굿즈를 풀면 숨는 굿즈 종류도 푼다
          },
          onExclude: (v) {
            _toggle(_draft.typesOut, _draft.types, v);
            _draft.dropHidden(); // 굿즈를 빼면 굿즈 종류 줄이 숨으니 같이 푼다
          },
        ),
        // 굿즈를 고르면 세부 종류 (티켓 · 의류 · 블루레이 …)
        if (_draft.types.contains(goodsType) && kits.any((k) => k.goodsKind.isNotEmpty)) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 10, 0, 2),
            child: Text(
              tr('굿즈 종류'),
              style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
            ),
          ),
          CheckGrid(
            values: _live((k) => k.goodsKind, (f) => f.goodsKinds, (f) => f.goodsKindsOut),
            selected: _draft.goodsKinds,
            excluded: _draft.goodsKindsOut,
            label: dataLabel,
            countOf: (v) => _only(v, (f) => f.goodsKinds, (f) => f.goodsKindsOut),
            onToggle: (v) => _toggle(_draft.goodsKinds, _draft.goodsKindsOut, v),
            onExclude: (v) => _toggle(_draft.goodsKindsOut, _draft.goodsKinds, v),
          ),
        ],
        const Divider(height: 20),
        // 작품이 라인보다 먼저 — 무엇을 보려는지(작품)를 고르고 나서 라인을 좁힌다 (2026-11-22).
        // 값이 하나뿐인 줄은 고를 것이 없어 숨긴다 (포켓몬 · 베이 · AC 작품, 레고 라인 — 2026-11-19 감사)
        // 이펙트뿐이면 이 줄은 이펙트 갈래 (이펙트 종류)
        if (showChoices(works, _draft.works, _draft.worksOut)) ...[
          ExpandRow(
            key: const ValueKey('filter-works'),
            title: tr(kitWorkTitle(kits)),
            summary: _summary(_draft.works, _draft.worksOut, works: true),
            open: _open == '작품',
            onTap: () => setState(() => _open = _open == '작품' ? '' : '작품'),
          ),
          if (_open == '작품')
            CheckGrid(
              columns: 1,
              values: works,
              label: _workName, // 작품 이름은 번역 표가 아니라 상품의 중국어 작품 이름
              selected: _draft.works,
              excluded: _draft.worksOut,
              countOf: (v) => _only(v, (f) => f.works, (f) => f.worksOut),
              onToggle: (v) => _toggle(_draft.works, _draft.worksOut, v),
              onExclude: (v) => _toggle(_draft.worksOut, _draft.works, v),
            ),
        ],
        if (showChoices(lines, _draft.lines, _draft.linesOut)) ...[
          ExpandRow(
            key: const ValueKey('filter-lines'),
            title: tr('라인'),
            summary: _summary(_draft.lines, _draft.linesOut),
            open: _open == '라인',
            onTap: () => setState(() => _open = _open == '라인' ? '' : '라인'),
          ),
          if (_open == '라인')
            CheckGrid(
              values: lines,
              selected: _draft.lines,
              excluded: _draft.linesOut,
              label: dataLabel,
              countOf: (v) => _only(v, (f) => f.lines, (f) => f.linesOut),
              onToggle: (v) => _toggle(_draft.lines, _draft.linesOut, v),
              onExclude: (v) => _toggle(_draft.linesOut, _draft.lines, v),
            ),
        ],
        ExpandRow(
          title: tr('기간'),
          summary: periodLabel(_draft.from, _draft.to).isEmpty ? tr('전체') : periodLabel(_draft.from, _draft.to),
          open: _open == '기간',
          onTap: () => setState(() => _open = _open == '기간' ? '' : '기간'),
        ),
        if (_open == '기간')
          _PeriodPicker(
            from: _draft.from,
            to: _draft.to,
            minYear: _minYear,
            onChanged: (from, to) => setState(() {
              _draft.from = from; // STATE: 기간 → 맞는 상품 수 · 「n개 보기」
              _draft.to = to;
            }),
          ),
        // 정가가 하나도 없는 목록(레고 등)은 가격대를 골라도 비어서 숨긴다
        if (_prices || _draft.price != PriceBand.any) ...[
          ExpandRow(
            key: const ValueKey('filter-price'),
            title: tr('가격'),
            summary: _draft.price.labelIn(currency),
            open: _open == '가격',
            onTap: () => setState(() => _open = _open == '가격' ? '' : '가격'),
          ),
          if (_open == '가격') ...[
            if (_currencies) ...[
              SquareSegments<PriceCurrency>(
                key: const ValueKey('filter-currency'),
                values: PriceCurrency.values,
                current: currency,
                child: (v) => Text(v.label),
                onPick: (v) => setState(() => _draft.currency = v), // STATE: 돈 → 가격대 칸 · 맞는 상품 수
              ),
              const SizedBox(height: 8),
            ],
            SquareSegments<PriceBand>(
              values: PriceBand.values,
              current: _draft.price,
              child: (v) => Text(v.shortIn(currency)),
              // 가격대를 고르면 지금 보이는 돈으로 정해 둔다 (목록 · 정렬이 같은 돈을 쓴다)
              onPick: (v) => setState(() {
                _draft.price = v;
                if (v != PriceBand.any) _draft.currency = currency;
              }),
            ),
          ],
        ],
      ],
    );
  }
}

/// 필터 「기간」 — 빠른 고르기(전체 · 올해 · 작년 · 최근 1년) + 시작 · 끝 달 (발매일 기준, 달 단위)
class _PeriodPicker extends StatelessWidget {
  const _PeriodPicker({required this.from, required this.to, required this.minYear, required this.onChanged});
  final String from;
  final String to;

  /// 달 고르기의 ‹ 가 멈추는 해
  final int minYear;
  final void Function(String from, String to) onChanged;

  @override
  Widget build(BuildContext context) {
    final today = dayKey(appNow());
    // 12월엔 올해 = 최근 1년 — 앞의 것(올해)에 불을 켠다
    final preset = periodPresetOf(from, to, today);
    Future<void> pick({required bool start}) async {
      final now = start ? from : to;
      final v = await pickMonth(
        context,
        title: start ? tr('시작 월') : tr('종료 월'),
        initial: now.isEmpty ? today.substring(0, 7) : now,
        minYear: minYear,
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
                  label: tr('시작'),
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
                  label: tr('끝'),
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
      value.isEmpty ? trf('{label} · 정하지 않음', {'label': label}) : joinDot([label, monthDot(value)]),
      style: TextStyle(fontSize: Gp.t12, color: value.isEmpty ? Gp.muted : Gp.ink),
    ),
  );
}

/// 달 고르기 시트 — 위에 ‹ 해 ›, 아래 1–12월, 「정하지 않음」= 빈 글자. 그냥 닫으면 null.
/// ‹ 는 [minYear] 에서 멈춘다 (처음 해 [initial] 가 더 이르면 그 해)
Future<String?> pickMonth(BuildContext context, {required String title, required String initial, int minYear = 1980}) =>
    showGpSheet<String>(
      context,
      builder: (_) => _MonthSheet(title: title, initial: initial, minYear: minYear),
    );

class _MonthSheet extends StatefulWidget {
  const _MonthSheet({required this.title, required this.initial, required this.minYear});
  final String title;
  final String initial;
  final int minYear;

  @override
  State<_MonthSheet> createState() => _MonthSheetState();
}

class _MonthSheetState extends State<_MonthSheet> {
  late int _year = int.parse(widget.initial.substring(0, 4));
  late final int _month = int.parse(widget.initial.substring(5, 7));
  late final int _initialYear = _year;
  late final int _minYear = widget.minYear < _initialYear ? widget.minYear : _initialYear;

  @override
  Widget build(BuildContext context) {
    final thisYear = appNow().year;
    // 가로 화면 · 아주 작은 화면에선 시트(화면 높이의 9/16)보다 길다 → 넘치지 않고 밀어 본다
    return SingleChildScrollView(
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
                tooltip: tr('이전 해'), // 기간 빠른 고르기의 「작년」(지난해)과 뜻이 달라 따로
                onPressed: _year > _minYear ? () => setState(() => _year--) : null, // STATE: 해 → 달 칸
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
                tooltip: tr('다음 해'),
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
                  child: Text(trf('{m}월', {'m': m}), style: const TextStyle(fontSize: Gp.t14)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: () => Navigator.pop(context, ''), child: Text(tr('정하지 않음'))),
        ],
      ),
    );
  }
}
