// 생김새로 찾기 후보 고르기 — 채널 칩 순서 · 칩으로 좁힌 12개 (순수 Dart).
// 표의 54 % 가 건담이고 모델이 "상품 모양(키링 · 아크릴 · 인형)"부터 맞춰서, 포켓몬 · 마도카 사진의 12칸 중 20–40 % 가
// 다른 채널 상품이었다. 한 채널로 좁히면 실사진 포켓몬 5위 안 +8 · Fate 12위 안 +23 · 마도카 1위 +30 점 (2026-11-14 평가).
// 위 12개로 투표해 채널을 저절로 고르면 마도카 피규어가 Fate 로 가서 더 나빠졌다 → 칩은 사람이 고르고, 순서만 후보에서.
library;

/// 칩에 보일 채널 순서: 후보 앞쪽 [head]개에 먼저 나온 채널부터, 그다음 나머지 후보의 채널 (같은 채널은 한 번)
List<String> visualChannels(Iterable<String> rankedChannels, {int head = 60}) {
  final out = <String>[];
  for (final c in rankedChannels.take(head)) {
    if (c.isNotEmpty && !out.contains(c)) out.add(c);
  }
  final seen = out.toSet();
  for (final c in rankedChannels.skip(head)) {
    if (c.isNotEmpty && seen.add(c)) out.add(c);
  }
  return out;
}

/// 비슷한 순서의 후보에서 [channel](null = 전체) 상품만 [k]개
List<T> visualTop<T>(Iterable<T> ranked, String? channel, String Function(T) channelOf, {int k = 12}) =>
    (channel == null ? ranked : ranked.where((x) => channelOf(x) == channel)).take(k).toList();
