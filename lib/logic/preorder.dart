// 예약 (좋아요와 구매함 사이) — 가게 · 낸 돈 · 결제 상태 · 도착 예정. 순수 Dart.
// 기기 local_state 'preorders' 에 kit_id 별로 둔다 (lib/data/user_store/kit_progress.dart).
// 공유 상태 모양(owned · wanted · deleted)은 그대로: 예약한 상품은 좋아요(wanted) 이고, 도착하면 구매함(owned)으로 옮긴다.
import '../format.dart' show monthKey;
import '../json_util.dart';

/// 예약 한 건 — [updatedAt] 이 늦은 쪽이 이긴다. 지우면 [deleted] 로 남긴다 (기기 사이 동기화 때 되살아나지 않게)
class Preorder {
  const Preorder({
    this.shop = '',
    this.price,
    this.deposit,
    this.paid = false,
    this.arrival = '',
    this.arrivedAt = '',
    this.deleted = false,
    this.updatedAt = '',
  });

  /// 예약한 가게 (프리미엄 반다이 · 동네 샵 …)
  final String shop;

  /// 한 개 총액 (원) — 도착해 구매함으로 옮기면 내 구매가가 된다
  final int? price;

  /// 이미 낸 예약금 (원)
  final int? deposit;

  /// 결제 완료 (false = 미결제 · 잔금 남음)
  final bool paid;

  /// 도착 예정 'YYYY-MM' 또는 'YYYY-MM-DD' (모르면 빈 글자)
  final String arrival;

  /// 도착했다고 누른 때 (UTC ISO, 아직이면 빈 글자)
  final String arrivedAt;
  final bool deleted;
  final String updatedAt;

  /// 지금 기다리는 예약 (지우지 않았고 · 아직 안 옴)
  bool get active => !deleted && arrivedAt.isEmpty;

  /// 아직 낼 돈 — 결제 완료면 0, 아니면 총액 − 예약금
  int get due {
    if (paid) return 0;
    final d = (price ?? 0) - (deposit ?? 0);
    return d < 0 ? 0 : d;
  }

  /// 'YYYY-MM' (도착 예정이 없으면 빈 글자)
  String get arrivalMonth => arrival.length >= 7 ? arrival.substring(0, 7) : '';

  /// 도착 예정일이 하루까지 정해졌나
  bool get exactDay => arrival.length == 10;

  Preorder copyWith({
    String? shop,
    int? Function()? price,
    int? Function()? deposit,
    bool? paid,
    String? arrival,
    String? arrivedAt,
    bool? deleted,
    String? updatedAt,
  }) => Preorder(
    shop: shop ?? this.shop,
    price: price == null ? this.price : price(),
    deposit: deposit == null ? this.deposit : deposit(),
    paid: paid ?? this.paid,
    arrival: arrival ?? this.arrival,
    arrivedAt: arrivedAt ?? this.arrivedAt,
    deleted: deleted ?? this.deleted,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, Object?> toJson() => {
    if (shop.isNotEmpty) 'shop': shop,
    'price': ?price,
    'deposit': ?deposit,
    'paid': paid,
    if (arrival.isNotEmpty) 'arrival': arrival,
    if (arrivedAt.isNotEmpty) 'arrived_at': arrivedAt,
    if (deleted) 'deleted': true,
    'updated_at': updatedAt,
  };

  static Preorder? fromJson(Object? raw) {
    final m = jMap(raw);
    if (m.isEmpty) return null;
    int? n(Object? v) => v is num && v > 0 ? v.toInt() : null;
    return Preorder(
      shop: jStr(m['shop']),
      price: n(m['price']),
      deposit: n(m['deposit']),
      paid: m['paid'] == true,
      arrival: normalizeArrival(jStr(m['arrival'])),
      arrivedAt: jStr(m['arrived_at']),
      deleted: m['deleted'] == true,
      updatedAt: jStr(m['updated_at']),
    );
  }
}

/// 저장 모양 → kit_id 별 예약 (모양이 틀린 줄은 버린다)
Map<String, Preorder> preordersFrom(Object? raw) => {
  for (final e in jMap(raw).entries) e.key: ?Preorder.fromJson(e.value),
};

/// 사람이 적은 도착 예정 → 'YYYY-MM' · 'YYYY-MM-DD' (점 · 빗금 · 한 자리 달도 받는다). 못 읽으면 빈 글자
String normalizeArrival(String input) {
  final m = RegExp(r'^\s*(\d{4})\s*[-./년]\s*(\d{1,2})\s*(?:[-./월]\s*(\d{1,2})?\s*일?)?\s*$').firstMatch(input);
  if (m == null) return '';
  final mo = int.parse(m.group(2)!);
  if (mo < 1 || mo > 12) return '';
  final ym = '${m.group(1)}-${mo.toString().padLeft(2, '0')}';
  final d = int.tryParse(m.group(3) ?? '');
  if (d == null) return ym;
  if (d < 1 || d > 31) return '';
  return '$ym-${d.toString().padLeft(2, '0')}';
}

/// [month] 에 도착 예정인 기다리는 예약
Iterable<MapEntry<String, Preorder>> arrivingIn(Map<String, Preorder> all, DateTime month) {
  final ym = monthKey(month);
  return all.entries.where((e) => e.value.active && e.value.arrivalMonth == ym);
}

/// "이번 달 낼 돈" — [month] 에 도착 예정인 미결제 예약의 남은 돈 합 (원) · 건수
({int total, int count}) monthDue(Map<String, Preorder> all, DateTime month) {
  var total = 0;
  var count = 0;
  for (final e in arrivingIn(all, month)) {
    if (e.value.due <= 0) continue;
    total += e.value.due;
    count++;
  }
  return (total: total, count: count);
}

/// 'YYYY-MM' → 'YYYY.MM', 'YYYY-MM-DD' → 'YYYY.MM.DD'
String arrivalLabel(String arrival) => arrival.replaceAll('-', '.');
