// 상품 필터 규칙 — 내 상태 · 발매 · 판매 · 나라 · 가격 · 종류 · 라인 · 작품 (화면 없이 테스트할 수 있는 순수 Dart)
import '../clock.dart';
import '../format.dart';
import '../l10n/l10n.dart';
import '../models.dart';
import 'kit_rules.dart';

enum MineState { any, liked, owned, none }

enum ReleaseState { any, upcoming, thisMonth, released }

enum SaleState { any, regular, limited, pb, base }

/// 가격대를 고르는 돈 — 한국 정가(원) · 일본 정가(엔). 서로 환산하지 않는다
enum PriceCurrency { krw, jpy }

extension PriceCurrencyLabel on PriceCurrency {
  String get label => switch (this) {
    PriceCurrency.krw => tr('원'),
    PriceCurrency.jpy => tr('엔'),
  };

  /// 이 돈의 진짜 정가 (없으면 null) — 짝 상품은 둘 다 있다
  int? of(Kit k) => this == PriceCurrency.krw ? k.priceKrw : k.priceJpy;

  PriceCurrency get other => this == PriceCurrency.krw ? PriceCurrency.jpy : PriceCurrency.krw;
}

/// 가격대 — 원은 엔의 10배 칸 (2026-11-14 실측: 원 중간값 2만 · 엔 대부분 ¥3,000 이하)
enum PriceBand { any, low, mid, high }

extension PriceBandLabel on PriceBand {
  /// 고른 조건 한 줄에 보일 이름
  String labelIn(PriceCurrency? c) => switch ((this, c)) {
    (PriceBand.any, _) => tr('전체'),
    (PriceBand.low, PriceCurrency.krw) => tr('3만원 이하'),
    (PriceBand.mid, PriceCurrency.krw) => tr('3만–10만원'),
    (PriceBand.high, PriceCurrency.krw) => tr('10만원 이상'),
    (PriceBand.low, _) => tr('¥3,000 이하'),
    (PriceBand.mid, _) => '¥3,000 – ¥10,000',
    (PriceBand.high, _) => tr('¥10,000 이상'),
  };

  /// 필터 시트 칸 (좁아서 짧게 — 360dp 네 칸 하나가 약 80dp, 중국어 "3万–10万韩元" 은 잘렸다. 돈은 위 원 · 엔 칸에)
  String shortIn(PriceCurrency c) => switch ((this, c)) {
    (PriceBand.any, _) => tr('전체'),
    (PriceBand.low, PriceCurrency.krw) => tr('₩3만 이하'),
    (PriceBand.mid, PriceCurrency.krw) => tr('3만–10만'),
    (PriceBand.high, PriceCurrency.krw) => tr('₩10만 이상'),
    (PriceBand.low, _) => tr('¥3천 이하'),
    (PriceBand.mid, _) => tr('3천–1만'),
    (PriceBand.high, _) => tr('¥10천 이상'),
  };

  bool _inBand(int? p, PriceCurrency c) {
    if (p == null) return false;
    final unit = c == PriceCurrency.krw ? 10 : 1;
    return switch (this) {
      PriceBand.any => true,
      PriceBand.low => p <= 3000 * unit,
      PriceBand.mid => p > 3000 * unit && p <= 10000 * unit,
      PriceBand.high => p > 10000 * unit,
    };
  }

  /// [c] 돈의 진짜 정가가 이 칸에 드나. [c] 가 없으면 원 · 엔 어느 쪽이든 제 칸에 들면
  bool hit(Kit k, PriceCurrency? c) {
    if (this == PriceBand.any) return true;
    if (c != null) return _inBand(c.of(k), c);
    return _inBand(k.priceKrw, PriceCurrency.krw) || _inBand(k.priceJpy, PriceCurrency.jpy);
  }
}

/// 가격대 · 가격순의 돈 — 고른 돈이 이 목록에 있으면 그것, 아니면 원(한국 정가가 하나라도 있으면), 그다음 엔
PriceCurrency currencyFor(Iterable<Kit> pool, PriceCurrency? picked) {
  if (picked != null && pool.any((k) => picked.of(k) != null)) return picked;
  return pool.any((k) => k.priceKrw != null) ? PriceCurrency.krw : PriceCurrency.jpy;
}

/// 원 · 엔이 둘 다 있는 목록인가 (필터 시트의 원 · 엔 칸)
bool hasBothCurrencies(Iterable<Kit> pool) =>
    pool.any((k) => k.priceKrw != null) && pool.any((k) => k.priceJpy != null);

/// 가격순 — 고른 돈 [c] 의 정가가 있는 상품을 그 값으로 먼저, 다음은 다른 돈만 있는 상품을 그 값으로,
/// 정가가 없는 상품은 끝. 낮은순 · 높은순([high])은 묶음 안에서만 (원과 엔을 환산해 섞지 않는다)
int comparePrice(Kit a, Kit b, PriceCurrency c, {bool high = false}) {
  int group(Kit k) => c.of(k) != null ? 0 : (c.other.of(k) != null ? 1 : 2);
  final ga = group(a);
  final gb = group(b);
  if (ga != gb) return ga.compareTo(gb);
  if (ga == 2) return 0;
  final cur = ga == 0 ? c : c.other;
  final d = cur.of(a)!.compareTo(cur.of(b)!);
  return high ? -d : d;
}

/// 파는 나라 — 한국 · 일본 (짝 상품은 둘 다)
enum SaleRegion { any, kr, jp }

extension SaleRegionLabel on SaleRegion {
  String get label => switch (this) {
    SaleRegion.any => tr('전체'),
    SaleRegion.kr => tr('한국'),
    SaleRegion.jp => tr('일본'),
  };

  bool hit(Kit k) => switch (this) {
    SaleRegion.any => true,
    SaleRegion.kr => soldInKorea(k),
    SaleRegion.jp => soldInJapan(k),
  };

  /// 한 나라만 볼 때 보일 상품 — 짝이 있으면 그 나라 쪽 ([byId] = 카탈로그 전체, 짝을 못 찾으면 그대로)
  Kit shownIn(Kit k, Map<String, Kit> byId) {
    if (this == SaleRegion.any || k.twinId.isEmpty) return k;
    if (k.region == (this == SaleRegion.jp ? 'jp' : 'kr')) return k;
    return byId[k.twinId] ?? k;
  }
}

/// 나라가 둘 이상 섞인 목록인가 (필터 시트의 한국 · 일본 칸 — 지금은 포켓몬 · 전체 채널)
bool hasBothRegions(Iterable<Kit> pool) => pool.any(soldInKorea) && pool.any(soldInJapan);

extension ReleaseStateLabel on ReleaseState {
  String get label => switch (this) {
    ReleaseState.any => tr('전체'),
    ReleaseState.upcoming => tr('발매 예정'),
    ReleaseState.thisMonth => tr('이번 달'),
    ReleaseState.released => tr('발매됨'),
  };
}

extension SaleStateLabel on SaleState {
  String get label => switch (this) {
    SaleState.any => tr('전체'),
    SaleState.regular => tr('일반'),
    SaleState.limited => tr('한정'),
    SaleState.pb => 'PB',
    SaleState.base => tr('베이스'),
  };
}

/// 건담베이스 · 이벤트 한정 (이름에 적혀 있는 것)
bool isBaseOrEvent(Kit k) {
  final n = '${k.nameJa} ${k.name}';
  return n.contains('ガンダムベース') || n.contains('GUNDAM BASE') || n.contains('イベント') || n.contains('EXPO');
}

String _today() => dayKey(appNow());

/// 기간 빠른 고르기 (필터 시트 「기간」)
enum PeriodPreset { any, thisYear, lastYear, lastYearSpan }

extension PeriodPresetLabel on PeriodPreset {
  String get label => switch (this) {
    PeriodPreset.any => tr('전체'),
    PeriodPreset.thisYear => tr('올해'),
    PeriodPreset.lastYear => tr('작년'),
    PeriodPreset.lastYearSpan => tr('최근 1년'),
  };

  /// (시작, 끝) — 'YYYY-MM', 빈 글자 = 끝이 열림. [today] = 'YYYY-MM-DD'
  (String, String) range(String today) {
    final y = int.parse(today.substring(0, 4));
    final m = int.parse(today.substring(5, 7));
    String ym(int year, int month) => '$year-${month.toString().padLeft(2, '0')}';
    return switch (this) {
      PeriodPreset.any => ('', ''),
      PeriodPreset.thisYear => (ym(y, 1), ym(y, 12)),
      PeriodPreset.lastYear => (ym(y - 1, 1), ym(y - 1, 12)),
      PeriodPreset.lastYearSpan => (m == 12 ? ym(y, 1) : ym(y - 1, m + 1), ym(y, m)),
    };
  }
}

/// 지금 기간 [from]–[to] 가 어느 빠른 고르기인가 (없으면 null). 12월엔 올해 = 최근 1년이라 앞의 것(올해)
PeriodPreset? periodPresetOf(String from, String to, String today) {
  for (final p in PeriodPreset.values) {
    final r = p.range(today);
    if (r.$1 == from && r.$2 == to) return p;
  }
  return null;
}

/// 달 고르기에서 갈 수 있는 가장 이른 해 = [dates](발매일 'YYYY…') 중 가장 이른 해, 없으면 [fallback]
/// (레고는 1949년 세트부터 있다)
int earliestYear(Iterable<String> dates, {int fallback = 1980}) {
  int? first;
  for (final d in dates) {
    if (d.length < 4) continue;
    final y = int.tryParse(d.substring(0, 4));
    if (y != null && y >= 1900 && (first == null || y < first)) first = y;
  }
  return first ?? fallback;
}

/// 'YYYY-MM' → 'YYYY.MM' (빈 글자는 그대로)
String monthDot(String ym) => ym.replaceAll('-', '.');

/// 기간 한 줄: 2023.01–2024.06 · 2023.01 부터 · 2024.06 까지 · 빈 글자
String periodLabel(String from, String to) => switch ((from.isEmpty, to.isEmpty)) {
  (true, true) => '',
  (false, true) => trf('{from} 부터', {'from': monthDot(from)}),
  (true, false) => trf('{to} 까지', {'to': monthDot(to)}),
  _ => from == to ? monthDot(from) : '${monthDot(from)}–${monthDot(to)}',
};

/// 발매일이 기간 [from]–[to] ('YYYY-MM', 빈 글자 = 열림) 안인가. 발매일이 없으면 밖, 해만 있으면 해로 비교
bool inPeriod(String date, String from, String to) {
  if (from.isEmpty && to.isEmpty) return true;
  if (date.length < 4) return false;
  if (date.length < 7) {
    final y = date.substring(0, 4);
    return (from.isEmpty || y.compareTo(from.substring(0, 4)) >= 0) &&
        (to.isEmpty || y.compareTo(to.substring(0, 4)) <= 0);
  }
  final ym = date.substring(0, 7);
  return (from.isEmpty || ym.compareTo(from) >= 0) && (to.isEmpty || ym.compareTo(to) <= 0);
}

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
    this.currency,
    this.region = SaleRegion.any,
    this.from = '',
    this.to = '',
    Map<String, String>? workNames,
  }) : workNames = workNames ?? {},
       works = works ?? {},
       types = types ?? {},
       lines = lines ?? {},
       goodsKinds = goodsKinds ?? {};

  final Set<String> works;
  final Set<String> types;
  final Set<String> lines;

  /// 굿즈 세부 종류 (굿즈를 고르면 보인다)
  final Set<String> goodsKinds;

  /// 작품 묶음 이름 → 화면에 보일 이름 (중국어 화면의 작품 이름 — 필터 시트가 채운다, 거르기에는 안 쓴다)
  final Map<String, String> workNames;
  MineState mine;
  ReleaseState release;
  SaleState sale;
  PriceBand price;

  /// 가격대 · 가격순의 돈 (null = 목록에 맞춰 — [currencyFor])
  PriceCurrency? currency;

  /// 파는 나라
  SaleRegion region;

  /// 가격대 · 가격순의 돈 — 고른 것, 없으면 고른 나라의 돈 (null = 목록에 맞춰, [currencyFor])
  PriceCurrency? get preferredCurrency =>
      currency ??
      switch (region) {
        SaleRegion.kr => PriceCurrency.krw,
        SaleRegion.jp => PriceCurrency.jpy,
        SaleRegion.any => null,
      };

  /// 발매 기간 'YYYY-MM' (빈 글자 = 열림)
  String from;
  String to;

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
    currency: currency,
    region: region,
    from: from,
    to: to,
    workNames: {...workNames},
  )..statusOf = statusOf;

  /// 모든 조건 비우기 (필터 시트 초기화)
  void clear() {
    works.clear();
    types.clear();
    lines.clear();
    goodsKinds.clear();
    mine = MineState.any;
    release = ReleaseState.any;
    sale = SaleState.any;
    price = PriceBand.any;
    currency = null;
    region = SaleRegion.any;
    from = '';
    to = '';
  }

  int get count =>
      works.length +
      types.length +
      lines.length +
      goodsKinds.length +
      (mine == MineState.any ? 0 : 1) +
      (release == ReleaseState.any ? 0 : 1) +
      (sale == SaleState.any ? 0 : 1) +
      (price == PriceBand.any ? 0 : 1) +
      (region == SaleRegion.any ? 0 : 1) +
      (from.isEmpty && to.isEmpty ? 0 : 1);

  bool matches(Kit k) {
    if (works.isNotEmpty && !works.contains(kitWork(k))) return false;
    if (types.isNotEmpty && !types.contains(k.type)) return false;
    if (lines.isNotEmpty && !lines.contains(k.line)) return false;
    if (goodsKinds.isNotEmpty && !goodsKinds.contains(k.goodsKind)) return false;
    if (!price.hit(k, currency)) return false;
    if (!region.hit(k)) return false;
    if (!inPeriod(k.date, from, to)) return false;
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
        MineState.liked => tr('좋아요'),
        MineState.owned => tr('구매함'),
        _ => tr('아직 없음'),
      },
    if (release != ReleaseState.any) release.label,
    if (from.isNotEmpty || to.isNotEmpty) periodLabel(from, to),
    if (sale != SaleState.any) sale.label,
    if (region != SaleRegion.any) region.label,
    for (final w in works) workNames[w] ?? w,
    ...types.map(tr),
    ...lines.map(tr),
    ...goodsKinds.map(tr),
    if (price != PriceBand.any) price.labelIn(currency),
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
