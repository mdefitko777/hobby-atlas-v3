// 종류별 도감 규칙 — 채널 상품을 제품 라인 · 굿즈 종류로 묶고, 묶음 안에서 찾기 · 상태 · 정렬 · 발매 연도 (순수 Dart)
//   묶음 키: 굿즈 세부 종류 > 굿즈 라인 안의 가샤폰 · 카드 > 라인 > 유형 > 기타
//   순서: 건담 = 정해진 등급 순서(PG → MG → RG → HG → … → 완성품 → 굿즈), 그 밖 = 상품 많은 순. 기타는 늘 끝
import '../models.dart';

/// 작은 묶음을 모으는 이름 (굿즈 세부 종류 '기타' 와 같은 칸)
const lineOtherKey = '기타';

/// 이보다 작은 묶음은 [lineOtherKey] 로 모은다 (작은 묶음이 둘 이상일 때만)
const lineMinGroup = 3;

/// 묶음이 굿즈 쪽인지 가르는 유형
const _goodsTypes = {'굿즈', '카드'};

/// 굿즈 라인 안에서 따로 세우는 유형 (상품 이름으로 가른 것, lib/data/gunpula.dart typeLabel)
const _goodsLineSplit = {'가샤폰', '카드'};

/// 건담 등급 · 라인 순서 (Kit.line 표시 이름 그대로). 없는 라인은 굿즈 앞에 상품 많은 순
const gundamLineOrder = [
  // 프라모델: 큰 것부터
  'PG', 'PGU', 'MG', 'MGEX', 'RG', 'HG', 'EG',
  // SD
  'MGSD', 'SD', 'SDW', 'SDEX', 'SDCS', 'BB',
  // 1/100 · 옛 라인
  'RE100', 'FM', 'HIRM', 'MEGA', 'No Grade', 'AG', 'FG', 'HY2M',
  // 완성품
  'ROBOT魂', 'METAL BUILD', 'METAL ROBOT魂', 'S.H.Figuarts',
  // 식완 · 가샤폰
  'G FRAME FA', 'CONVERGE', 'MS 앙상블', '가샤폰 전사 f', 'MOBILITY JOINT', '건담 아티팩트', 'Superior Define',
  // 굿즈
  '가샤폰', '카드', '굿즈',
];

/// 키 → 보이는 이름 (라인 코드 그대로인 것만 다듬는다)
const _labels = {'RE100': 'RE/100', 'PGU': 'PG UNLEASHED'};

String lineGroupLabel(String key) => _labels[key] ?? key;

/// 상품 하나의 묶음 키 (작은 묶음 모으기 전)
String lineGroupKey(Kit k) {
  if (k.goodsKind.isNotEmpty) return k.goodsKind == lineOtherKey ? (k.line.isEmpty ? '굿즈' : k.line) : k.goodsKind;
  if (k.line == '굿즈' && _goodsLineSplit.contains(k.type)) return k.type;
  if (k.line.isNotEmpty) return k.line;
  return k.type.isNotEmpty ? k.type : lineOtherKey;
}

/// 발매일 새것부터 (발매일 없는 것은 끝), 같으면 이름
int newestFirst(Kit a, Kit b) {
  if (a.date.isEmpty != b.date.isEmpty) return a.date.isEmpty ? 1 : -1;
  final c = b.date.compareTo(a.date);
  return c != 0 ? c : a.name.compareTo(b.name);
}

/// 종류 묶음 하나 — 상품(새것부터) · 내 기록 숫자 · 표지
class LineGroup {
  const LineGroup({
    required this.key,
    required this.kits,
    required this.liked,
    required this.owned,
    required this.cover,
    required this.goods,
  });

  /// 묶음 키 = openLineGroup 에 넘기는 값
  final String key;

  /// 발매일 새것부터
  final List<Kit> kits;
  final int liked;
  final int owned;

  /// 사진이 있는 가장 새 상품의 그림 (참고 그림보다 제 사진 먼저)
  final String cover;

  /// 굿즈 쪽 묶음 (굿즈 · 카드 · 굿즈 세부 종류)
  final bool goods;

  String get label => lineGroupLabel(key);
  int get total => kits.length;

  /// 좋아요나 구매함이 하나라도 있다
  bool get mine => liked + owned > 0;
}

/// 채널 상품 → 종류 묶음 (순서대로). [status] = 내 기록 (없으면 상품에 적힌 값)
List<LineGroup> lineGroups(
  String channel,
  Iterable<Kit> kits, {
  CollectStatus Function(Kit)? status,
  int minGroup = lineMinGroup,
}) {
  final byKey = <String, List<Kit>>{};
  for (final k in kits) {
    (byKey[lineGroupKey(k)] ??= []).add(k);
  }
  // 작은 묶음이 둘 이상이면 기타로 (하나뿐이면 이름만 바뀌니 그대로)
  final small = [
    for (final e in byKey.entries)
      if (e.value.length < minGroup && e.key != lineOtherKey) e.key,
  ];
  if (small.length >= 2) {
    final other = byKey[lineOtherKey] ?? [];
    for (final key in small) {
      other.addAll(byKey.remove(key)!);
    }
    byKey[lineOtherKey] = other;
  }
  final st = status ?? (Kit k) => k.status;
  final groups = [
    for (final e in byKey.entries)
      () {
        final list = [...e.value]..sort(newestFirst);
        var liked = 0, owned = 0;
        for (final k in list) {
          switch (st(k)) {
            case CollectStatus.owned:
              owned++;
            case CollectStatus.wanted:
              liked++;
            case CollectStatus.none:
          }
        }
        final cover =
            list.where((k) => k.image.isNotEmpty && !k.imageRef).firstOrNull?.image ??
            list.where((k) => k.image.isNotEmpty).firstOrNull?.image ??
            '';
        return LineGroup(
          key: e.key,
          kits: list,
          liked: liked,
          owned: owned,
          cover: cover,
          goods: list.every((k) => k.goodsKind.isNotEmpty || _goodsTypes.contains(k.type)),
        );
      }(),
  ];
  groups.sort(_order(channel));
  return groups;
}

/// 묶음 순서: 기타는 끝. 건담 = [gundamLineOrder] (없는 라인은 굿즈 앞 · 굿즈 세부 종류는 굿즈 뒤), 그 밖 = 많은 순
int Function(LineGroup, LineGroup) _order(String channel) {
  int rank(LineGroup g) {
    if (g.key == lineOtherKey) return 1 << 20;
    if (channel != 'gundam') return 0;
    final i = gundamLineOrder.indexOf(g.key);
    if (i >= 0) return i * 2;
    return g.goods ? gundamLineOrder.length * 2 : gundamLineOrder.indexOf('가샤폰') * 2 - 1;
  }

  return (a, b) {
    final r = rank(a).compareTo(rank(b));
    if (r != 0) return r;
    final n = b.total.compareTo(a.total);
    return n != 0 ? n : a.key.compareTo(b.key);
  };
}

/// [key] 묶음 (없으면 null)
LineGroup? lineGroupOf(List<LineGroup> groups, String key) => groups.where((g) => g.key == key).firstOrNull;

/// 묶음 안 상태 거르기
enum LineStatus {
  all('전체'),
  mine('내 것'),
  liked('좋아요'),
  owned('구매함'),
  none('아직');

  const LineStatus(this.label);
  final String label;

  bool matches(CollectStatus s) => switch (this) {
    LineStatus.all => true,
    LineStatus.mine => s != CollectStatus.none,
    LineStatus.liked => s == CollectStatus.wanted,
    LineStatus.owned => s == CollectStatus.owned,
    LineStatus.none => s == CollectStatus.none,
  };
}

/// 묶음 안 정렬
enum LineSort {
  newest('발매일 최신'),
  oldest('발매일 오래된'),
  name('이름');

  const LineSort(this.label);
  final String label;

  /// 발매 연도로 나눠 보이는 정렬
  bool get byDate => this != LineSort.name;
}

/// 묶음 안 찾기 · 상태 · 정렬. [matches] = 글자 찾기 (lib/logic/kit_rules.dart kitMatches)
List<Kit> lineKits(
  List<Kit> kits, {
  required CollectStatus Function(Kit) status,
  required bool Function(Kit) matches,
  LineStatus filter = LineStatus.all,
  LineSort sort = LineSort.newest,
}) {
  final out = [
    for (final k in kits)
      if (filter.matches(status(k)) && matches(k)) k,
  ];
  switch (sort) {
    case LineSort.newest:
      out.sort(newestFirst);
    case LineSort.oldest:
      out.sort((a, b) {
        if (a.date.isEmpty != b.date.isEmpty) return a.date.isEmpty ? 1 : -1;
        final c = a.date.compareTo(b.date);
        return c != 0 ? c : a.name.compareTo(b.name);
      });
    case LineSort.name:
      out.sort((a, b) => a.name.compareTo(b.name));
  }
  return out;
}

/// 발매 연도 머리 이름 (발매일 없음 = 미정)
String releaseYear(Kit k) => k.date.length >= 4 ? '${k.date.substring(0, 4)}년' : '발매일 미정';

/// 정렬된 상품 → 연도 묶음 (순서 그대로, 붙어 있는 같은 연도끼리)
List<(String, List<Kit>)> byReleaseYear(List<Kit> sorted) {
  final out = <(String, List<Kit>)>[];
  for (final k in sorted) {
    final y = releaseYear(k);
    if (out.isNotEmpty && out.last.$1 == y) {
      out.last.$2.add(k);
    } else {
      out.add((y, [k]));
    }
  }
  return out;
}
