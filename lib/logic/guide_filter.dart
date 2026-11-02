// 도감 필터 규칙 — 상태 · 라인 · 시대 · 기체 종류 · 상품 있는 것 · 정렬 (순수 Dart)

import 'kit_filter.dart' show MineState;

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

// ── 도감 필터 (모든 도감 공통: 건담 작품 · 기체 칸 · 베이 · 세계관) ──────────────────────────
// 상품 필터와 같은 모양: 아래 시트(60%) · 네모 세그먼트 · 체크 2열(개수) · 펼치는 줄 · "n개 보기".
// 도감마다 칸 하나를 GuideFacet 으로 바꿔 넘기면, 시트는 그 재료에 있는 값만 보여 준다.

/// 칸 상태 — 상품 필터 상태(MineState)와 같은 순서 · 같은 말 (전체 · 좋아요 · 구매함 · 아직 없음) + 내 사진
enum GuideTier { any, liked, owned, none, photo }

extension GuideTierMine on GuideTier {
  /// 상품 필터의 같은 상태 (내 사진은 도감에만 → null)
  MineState? get mine => switch (this) {
    GuideTier.any => MineState.any,
    GuideTier.liked => MineState.liked,
    GuideTier.owned => MineState.owned,
    GuideTier.none => MineState.none,
    GuideTier.photo => null,
  };
}

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
