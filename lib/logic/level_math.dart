// 수집 레벨 계산 — 경험치 · 레벨 · 남은 양 (순수 Dart, 막대 · 시트는 lib/level.dart)
import '../models.dart';

/// 작품 도감 전체의 점등 칸 수
int litCount(Iterable<GuideWork> works) => works.fold(0, (s, w) => s + w.owned);

/// 수집 경험치 — 구매 10 · 도감 새 칸 5 · 사진 인증 3 · 좋아요 0 (lib/level.dart ? 에 같은 표)
int collectorXp({int owned = 0, int lit = 0, int verified = 0, int liked = 0}) => owned * 10 + lit * 5 + verified * 3;

/// 경험치 → 레벨 · 이번 레벨에서 모은 양 · 다음 레벨까지 필요한 양 (레벨 n 에서 n+1 까지 50 + 10·(n-1))
({int level, int into, int need}) levelOf(int xp) {
  var level = 1, rest = xp, need = 50;
  while (rest >= need) {
    rest -= need;
    level++;
    need = 50 + 10 * (level - 1);
  }
  return (level: level, into: rest, need: need);
}

/// 수집 레벨 (My Page · 도감 · 내 정보 · 친구 서랍 공통)
int guideLevel(int lit, int verified, {int owned = 0, int liked = 0}) =>
    levelOf(collectorXp(owned: owned, lit: lit, verified: verified, liked: liked)).level;
