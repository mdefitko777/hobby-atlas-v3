// 최근 본 · 최근 검색 · 검색 횟수 (기기에만) — UserStore 의 한 부분
part of '../user_store.dart';

/// 저장 파일의 search_counts → 검색어별 횟수 (숫자가 아닌 값은 버린다)
Map<String, int> _countsFrom(Object? raw) => {
  for (final e in jMap(raw).entries)
    if (e.value is num) e.key: (e.value! as num).toInt(),
};

mixin _History on ChangeNotifier {
  void _changed();

  final List<String> recentViewed = [];

  /// 최근 검색어 (새것부터, 같은 말은 한 번, [UserStore.maxRecentSearches] 개까지). 기기에만
  final List<String> recentSearches = [];

  /// 검색어 → 검색한 횟수 (검색 화면 "자주 찾은"). 기기에만, [UserStore.maxSearchCounts] 개까지
  final Map<String, int> searchCounts = {};

  /// 최근 본 기록 비우기 — 되돌리기용으로 지우기 전 목록을 돌려준다
  List<String> clearRecentViewed() {
    final before = [...recentViewed];
    if (before.isEmpty) return before;
    recentViewed.clear();
    _changed();
    return before;
  }

  void restoreRecentViewed(List<String> ids) {
    recentViewed
      ..clear()
      ..addAll(ids);
    _changed();
  }

  void markViewed(String kitId) {
    recentViewed
      ..remove(kitId)
      ..insert(0, kitId);
    if (recentViewed.length > 40) recentViewed.removeRange(40, recentViewed.length);
    _changed();
  }

  /// 검색어를 남긴다: 최근 검색 맨 앞(같은 말은 옮김) + 횟수 +1
  void addRecentSearch(String query) {
    final q = query.trim();
    if (q.isEmpty) return;
    recentSearches
      ..remove(q)
      ..insert(0, q);
    if (recentSearches.length > UserStore.maxRecentSearches) {
      recentSearches.removeRange(UserStore.maxRecentSearches, recentSearches.length);
    }
    searchCounts[q] = (searchCounts[q] ?? 0) + 1;
    if (searchCounts.length > UserStore.maxSearchCounts) {
      // 가장 적게 찾은 것부터 버린다 (방금 찾은 것은 빼고)
      final low = (searchCounts.entries.where((e) => e.key != q).toList()..sort((a, b) => a.value.compareTo(b.value)))
          .first
          .key;
      searchCounts.remove(low);
    }
    _changed();
  }

  /// 최근 검색에서 하나 지우기 — 되돌리기용으로 있던 자리를 돌려준다 (없었으면 -1)
  int removeRecentSearch(String query) {
    final i = recentSearches.indexOf(query);
    if (i < 0) return i;
    recentSearches.removeAt(i);
    _changed();
    return i;
  }

  /// 되돌리기: 지운 검색어를 [index] 자리에
  void insertRecentSearch(int index, String query) {
    if (recentSearches.contains(query)) return;
    recentSearches.insert(index.clamp(0, recentSearches.length), query);
    _changed();
  }

  /// 최근 검색 전체 지우기 (횟수 = "자주 찾은" 도 같이). 되돌리기용으로 지우기 전 값을 돌려준다
  ({List<String> recent, Map<String, int> counts}) clearRecentSearches() {
    final before = (recent: [...recentSearches], counts: {...searchCounts});
    recentSearches.clear();
    searchCounts.clear();
    _changed();
    return before;
  }

  void restoreRecentSearches(({List<String> recent, Map<String, int> counts}) before) {
    recentSearches
      ..clear()
      ..addAll(before.recent.take(UserStore.maxRecentSearches));
    searchCounts
      ..clear()
      ..addAll(before.counts);
    _changed();
  }

  /// 자주 찾은 검색어 — 두 번 이상 찾은 것, 많이 찾은 것부터
  List<MapEntry<String, int>> frequentSearches({int limit = 8}) =>
      (searchCounts.entries.where((e) => e.value >= 2).toList()..sort((a, b) => b.value.compareTo(a.value)))
          .take(limit)
          .toList();
}
