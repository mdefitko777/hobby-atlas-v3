// 상품 필터 규칙 — 내 상태 · 발매 · 판매 · 가격 · 종류 · 라인 · 작품 (화면 없이 테스트할 수 있는 순수 Dart)
import '../clock.dart';
import '../models.dart';

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
