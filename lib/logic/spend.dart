// 지출 계산 — 구매함 기록(collection-store 모양)의 구매가 × 수량 (순수 Dart)
import '../json_util.dart';

/// 기록 한 줄의 수량 1–99 (기록이 없거나 값이 없으면 1)
int entryQuantity(Map<String, Object?>? e) => switch (e?['quantity']) {
  final num q => q.toInt().clamp(1, 99),
  _ => 1,
};

/// 구매가(한 개 값) × 수량 — 적어 둔 구매가, 없으면 [listPrice] (정가 × 환율), 그것도 없으면 0
int paidFor(String id, Map<String, Object?> e, int? Function(String id)? listPrice) =>
    switch (e['purchase_price']) {
      final num p => p.toInt(),
      _ => listPrice?.call(id) ?? 0,
    } *
    entryQuantity(e);

/// 구매함 지출 합 (원)
int spendTotal(Map<String, Map<String, Object?>> items, int? Function(String id)? listPrice) =>
    items.entries.fold(0, (s, e) => e.value['status'] == 'owned' ? s + paidFor(e.key, e.value, listPrice) : s);

/// [now] 가 든 달의 지출 — 산 날짜를 따로 적지 않아, 구매함 기록을 마지막으로 바꾼 달(기기 시간)로 센다
int spendInMonthOf(Map<String, Map<String, Object?>> items, DateTime now, int? Function(String id)? listPrice) {
  final prefix = '${now.year}-${now.month.toString().padLeft(2, '0')}';
  return items.entries.fold(0, (s, e) {
    final at = DateTime.tryParse(jStr(e.value['updated_at']))?.toLocal().toIso8601String() ?? '';
    return e.value['status'] == 'owned' && at.startsWith(prefix) ? s + paidFor(e.key, e.value, listPrice) : s;
  });
}
