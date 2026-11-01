// 컬렉션 규칙 — 여러 상품 중 가장 높은 상태 · 휴지통에 보일 것 (순수 Dart)
import '../data/user_store.dart';
import '../models.dart';

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
