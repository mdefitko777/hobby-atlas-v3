// 컬렉션 규칙 — 여러 상품 중 가장 높은 상태 · 휴지통에 보일 것 · 바코드 겹침 (순수 Dart)
import '../data/user_store.dart';
import '../models.dart';
import 'build_status.dart';
import 'preorder.dart';

/// 여러 상태 중 가장 높은 것 (구매함 > 좋아요 > 없음) — 도감 칸 · 작품 수집 수
CollectStatus bestStatus(Iterable<CollectStatus> all) {
  var best = CollectStatus.none;
  for (final s in all) {
    if (s == CollectStatus.owned) return s;
    if (s == CollectStatus.wanted) best = s;
  }
  return best;
}

/// 휴지통에 보여 줄 것: 지운 뒤 다시 좋아요 · 구매함에 넣지 않은 상품 → 구매함에서 지웠나
Map<String, bool> trashView(UserStore me) => {
  for (final e in me.trash.entries)
    if (me.statusOf(e.key) != CollectStatus.owned && me.statusOf(e.key) != CollectStatus.wanted)
      e.key: e.value.from == 'owned',
};

/// 바코드로 찾은 상품 중 이미 내 컬렉션에 있는 것 — 구매함 > 예약 > 좋아요 순으로 하나 (E-6b 겹침 경고)
typedef ScanDup = ({Kit kit, ScanDupKind kind, int quantity, BuildRecord build, Preorder? preorder});

enum ScanDupKind { owned, preorder, liked }

/// [kits] 에서 가장 "가진 쪽"인 상품 (없으면 null). [statusOf] = 앱 전체 상태(Marks.statusOf)
ScanDup? scanDuplicate(List<Kit> kits, UserStore me, CollectStatus Function(Kit) statusOf) {
  ScanDup? best;
  for (final k in kits) {
    final st = statusOf(k);
    final pre = me.preorderOf(k.id);
    final kind = switch (st) {
      CollectStatus.owned => ScanDupKind.owned,
      CollectStatus.wanted when pre != null && pre.active => ScanDupKind.preorder,
      CollectStatus.wanted => ScanDupKind.liked,
      CollectStatus.none => null,
    };
    if (kind == null) continue;
    if (best == null || kind.index < best.kind.index) {
      best = (
        kit: k,
        kind: kind,
        quantity: me.quantityOf(k.id),
        build: me.buildOf(k.id),
        preorder: kind == ScanDupKind.preorder ? pre : null,
      );
    }
  }
  return best;
}
