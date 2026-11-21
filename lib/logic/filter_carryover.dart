// 작품을 바꿀 때 남은 조건 이어 쓰기 — 새로 고른 작품의 상품에 있는 값만 남기고, 없는 값은 떨어뜨린다.
// 2026-11-22 주인: 작품을 바꾸면 라인 · 종류 · 가격이 조용히 사라졌다 — 이어 쓸 수 있는 것은 이어 쓰고,
// 못 이어 쓴 것은 까닭까지 보여야 한다. 화면은 탭 줄의 「이어 씀 n ×」 와 「이어 쓴 필터」 시트
// (lib/widgets/toolbar.dart CarryNote). 거르는 규칙은 kit_filter.dart — 여기는 위젯 없는 순수 Dart
import '../l10n/l10n.dart';
import '../models.dart';
import 'data_labels.dart';
import 'kit_filter.dart';
import 'kit_rules.dart';

/// 이어 쓴 조건 한 줄 — 보일 이름(「라인 MG」)과 이것만 지우는 법
class CarriedFilter {
  const CarriedFilter(this.label, this.remove);

  final String label;

  /// 이 조건만 지우기 (「이어 쓴 필터」 시트의 ×)
  final void Function(KitFilter) remove;
}

/// 못 이어 쓴 조건 한 줄 — 보일 이름(「라인 HG 제외」)과 까닭(「00 에 없어요」)
class DroppedFilter {
  const DroppedFilter(this.label, this.reason);

  final String label;
  final String reason;
}

/// 작품을 바꾼 뒤의 조건 + 무슨 일이 있었나
class FilterCarry {
  const FilterCarry(this.filter, {this.carried = const [], this.dropped = const []});

  /// 이어 쓴 것만 남은 새 조건 (화면이 이것으로 갈아 끼운다)
  final KitFilter filter;

  final List<CarriedFilter> carried;
  final List<DroppedFilter> dropped;

  /// 이어 쓴 조건 수 — 탭 줄 「이어 씀 n」 (0 이면 화면에 아무것도 그리지 않는다)
  int get count => carried.length;

  /// 보일 것이 없다
  bool get isEmpty => carried.isEmpty && dropped.isEmpty;

  /// 조건 하나만 지운 뒤 (떨어뜨린 것은 그대로 — 까닭은 아직 보여 준다)
  FilterCarry without(CarriedFilter one) {
    final f = filter.copy();
    one.remove(f);
    return FilterCarry(
      f,
      carried: [
        for (final c in carried)
          if (c != one) c,
      ],
      dropped: dropped,
    );
  }

  /// 이어 쓴 조건 모두 지운 뒤 (탭 줄 × · 시트 「지우기」) — 알림도 사라진다
  FilterCarry cleared() {
    final f = filter.copy();
    for (final c in carried) {
      c.remove(f);
    }
    return FilterCarry(f);
  }
}

/// 작품만 새로 고른 조건 [after] 에서 작품을 뺀 다른 조건(종류 · 굿즈 종류 · 라인 · 그 「제외」 짝 · 기간 · 가격)을
/// 새 작품의 상품에 있는 것만 남긴다. [before] 와 작품이 같으면 이어 쓸 것도 떨어뜨릴 것도 없어 그대로 돌려준다.
/// 작품을 아예 풀었으면(전체) 보는 범위가 넓어지므로 떨어뜨리지 않고 다 이어 쓴다
FilterCarry carryFilter(Iterable<Kit> pool, KitFilter before, KitFilter after) {
  if (_same(before.works, after.works)) return FilterCarry(after);
  final f = after.copy();
  final wide = f.works.isEmpty;
  final scope = wide
      ? const <Kit>[]
      : [
          for (final k in pool)
            if (f.works.contains(kitWork(k))) k,
        ];
  bool has(bool Function(Kit) hit) => wide || scope.any(hit);
  String reason() => trf('{work} 에 없어요', {'work': _worksLabel(f)});
  final carried = <CarriedFilter>[];
  final dropped = <DroppedFilter>[];

  /// 값 묶음 한 줄씩 — 「라인 MG」 · 「라인 HG 제외」 ([out] = 「제외」 짝)
  void values(String name, Set<String> Function(KitFilter) of, String Function(Kit) valueOf, {bool out = false}) {
    for (final v in [...of(f)]) {
      final label = '$name ${out ? outSummary({v}) : dataLabel(v)}';
      if (has((k) => valueOf(k) == v)) {
        carried.add(CarriedFilter(label, (g) => of(g).remove(v)));
      } else {
        of(f).remove(v);
        dropped.add(DroppedFilter(label, reason()));
      }
    }
  }

  values(tr('종류'), (g) => g.types, (k) => k.type);
  values(tr('종류'), (g) => g.typesOut, (k) => k.type, out: true);
  values(tr('굿즈 종류'), (g) => g.goodsKinds, (k) => k.goodsKind);
  values(tr('굿즈 종류'), (g) => g.goodsKindsOut, (k) => k.goodsKind, out: true);
  values(tr('라인'), (g) => g.lines, (k) => k.line);
  values(tr('라인'), (g) => g.linesOut, (k) => k.line, out: true);

  if (f.from.isNotEmpty || f.to.isNotEmpty) {
    final label = '${tr('기간')} ${periodLabel(f.from, f.to)}';
    final from = f.from;
    final to = f.to;
    if (has((k) => inPeriod(k.date, from, to))) {
      carried.add(
        CarriedFilter(label, (g) {
          g.from = '';
          g.to = '';
        }),
      );
    } else {
      f.from = '';
      f.to = '';
      dropped.add(DroppedFilter(label, reason()));
    }
  }
  if (f.price != PriceBand.any) {
    final band = f.price;
    // 보일 돈은 새 작품의 상품에 맞춰 (필터 시트의 가격 줄과 같은 규칙), 맞나 보는 것은 거를 때와 같은 f.currency
    final label = '${tr('가격')} ${band.labelIn(currencyFor(wide ? pool : scope, f.preferredCurrency))}';
    if (has((k) => band.hit(k, f.currency))) {
      carried.add(CarriedFilter(label, (g) => g.price = PriceBand.any));
    } else {
      f.price = PriceBand.any;
      dropped.add(DroppedFilter(label, reason()));
    }
  }
  return FilterCarry(f, carried: carried, dropped: dropped);
}

/// 떨어뜨린 까닭에 쓸 작품 이름 — 하나면 그 이름, 여럿이면 「첫 것 외 n」 (필터 시트 요약과 같은 모양)
String _worksLabel(KitFilter f) {
  final names = [for (final w in f.works) f.workNames[w] ?? w];
  if (names.isEmpty) return '';
  return names.length == 1 ? names.first : trf('{first} 외 {n}', {'first': names.first, 'n': names.length - 1});
}

bool _same(Set<String> a, Set<String> b) => a.length == b.length && a.every(b.contains);
