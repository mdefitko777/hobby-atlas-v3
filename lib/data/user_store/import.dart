// 옛 Gunpula · Hobby Atlas 백업 파일 읽기 (가져오기 전에 보여 줄 숫자 + 넣을 값)
part of '../user_store.dart';

/// 옛 항목 하나 → 정리된 모양 (collection-store.js normalizeCollectionEntry 그대로 — lib/sync/collection_merge.dart).
/// 상태가 owned · wanted · deleted 가 아니면 null (버림)
Map<String, Object?>? normalizeEntry(Object? raw, String member) {
  final status = jMap(raw)['status'];
  if (status is! String || !collectionStatuses.contains(status)) return null;
  return normalizeCollectionEntry(raw, member: member);
}

/// 가져오기 전에 보여 줄 숫자 + 실제로 넣을 값.
/// 받는 모양 3가지:
///  1) 옛 앱 설정 › 데이터 › 수집 백업 내보내기: {collection, overrides, series_label_overrides, appearance, github_token?}
///  2) chrome://inspect 에서 뽑은 localStorage: `{local_storage: {'gunpula-…-v1': '<JSON 글자>'}}`
///  3) 1) + local_state {bbx_owned_parts, bbx_manual_map, guide_manual_lit, recent_viewed, bbx_combos?, bbx_decks?}
/// github_token · 로그인 세션 · 동기화 비밀값은 읽지 않는다.
class ImportPreview {
  ImportPreview._();

  String member = '';
  final Map<String, Map<String, Object?>> items = {};
  final Map<String, Object?> payloadExtra = {};

  /// collection.custom_items 등 (비공개 위시 — 보관만)
  final Map<String, Object?> collectionExtra = {};
  final Set<String> bbxOwnedParts = {};
  final Map<String, String> bbxManualMap = {};
  final Set<int> guideManualLit = {};
  final List<String> recentViewed = [];

  /// Hobby Atlas 자신의 백업에만 있다 (베이 조합 · 덱)
  final List<Combo> bbxCombos = [];
  final List<Deck> bbxDecks = [];

  /// 메자스타 · 프렌다 구매함 · 좋아요 태그 (Hobby Atlas 백업에만)
  final Set<String> tagOwned = {};
  final Set<String> tagLiked = {};

  /// 최근 검색어 · 검색 횟수 · 컬렉션 휴지통 (Hobby Atlas 백업에만)
  final List<String> recentSearches = [];
  final Map<String, int> searchCounts = {};
  final Map<String, ({String from, String at})> trash = {};

  /// Hobby Atlas 자신의 백업에만 있다 (옛 Gunpula 에는 채널이 없음)
  List<String>? myChannels;
  int owned = 0, wanted = 0, deleted = 0, unknown = 0;

  /// 다른 멤버(공유 공간) 버킷 — 가져오지 않고 숫자만 알려 준다
  final Map<String, int> otherMembers = {};

  bool get isEmpty =>
      items.isEmpty &&
      bbxOwnedParts.isEmpty &&
      bbxManualMap.isEmpty &&
      guideManualLit.isEmpty &&
      recentViewed.isEmpty &&
      bbxCombos.isEmpty &&
      bbxDecks.isEmpty &&
      tagOwned.isEmpty &&
      tagLiked.isEmpty &&
      recentSearches.isEmpty &&
      trash.isEmpty;

  static ImportPreview parse(String text, bool Function(String kitId) knownKit) {
    final p = ImportPreview._();
    final Object? root;
    try {
      root = jsonDecode(text.trim());
    } on FormatException {
      throw const FormatException('JSON 이 아니에요. 옛 앱에서 내보낸 파일 그대로인지 확인해 주세요.');
    }
    var j = jMap(root);
    final ls = jMap(j['local_storage']);
    if (ls.isNotEmpty) {
      Object? sub(String k) {
        final v = ls[k];
        if (v is! String) return v;
        try {
          return jsonDecode(v);
        } on FormatException {
          return null;
        }
      }

      j = {
        'collection': sub('gunpula-catalog-collection-v1'),
        'overrides': sub('gunpula-catalog-overrides-v1'),
        'series_label_overrides': sub('gunpula-catalog-series-labels-v1'),
        'local_state': {
          'bbx_owned_parts': sub('gunpula-bbx-owned-parts-v1'),
          'bbx_manual_map': sub('gunpula-bbx-manual-map-v1'),
          'guide_manual_lit': sub('gunpula-guide-manual-lit-v1'),
          'recent_viewed': sub('gunpula-catalog-recent-viewed-v1'),
        },
      };
    }

    final col = jMap(j['collection']);
    final memberItems = jMap(col['member_items']);
    var own = jMap(col['items']);
    // 내 버킷 이름 = items 와 같은 내용을 가진 member_items 키
    for (final e in memberItems.entries) {
      final m = jMap(e.value);
      if (own.isNotEmpty && m.length == own.length && m.keys.every(own.containsKey)) {
        p.member = e.key;
      } else if (m.isNotEmpty) {
        p.otherMembers[e.key] = m.length;
      }
    }
    if (own.isEmpty && memberItems.length == 1) {
      p.member = memberItems.keys.first;
      own = jMap(memberItems.values.first);
      p.otherMembers.clear();
    }
    // 아주 옛날 모양: owned[] · wanted[] 만 있는 것
    final legacyNow = DateTime.now().toUtc().toIso8601String();
    if (own.isEmpty) {
      own = {
        for (final id in jList(col['wanted']).whereType<String>()) id: {'status': 'wanted', 'updated_at': legacyNow},
        for (final id in jList(col['owned']).whereType<String>()) id: {'status': 'owned', 'updated_at': legacyNow},
      };
    }
    for (final e in own.entries) {
      final n = normalizeEntry(e.value, p.member.isEmpty ? 'member' : p.member);
      if (n == null) continue;
      p.items[e.key] = n;
      switch (n['status']) {
        case 'owned':
          p.owned++;
        case 'wanted':
          p.wanted++;
        default:
          p.deleted++;
      }
      if (n['status'] != 'deleted' && !e.key.startsWith('private-') && !knownKit(e.key)) p.unknown++;
    }
    for (final k in const ['overrides', 'series_label_overrides']) {
      if (jMap(j[k]).isNotEmpty) p.payloadExtra[k] = j[k];
    }
    // Hobby Atlas 자신의 백업 (설정 › 백업 파일로 내보내기)
    p.payloadExtra.addAll(jMap(j['payload_extra']));
    p.collectionExtra.addAll(jMap(j['collection_extra']));
    if (p.payloadExtra.remove('custom_items') case final Object c) {
      p.collectionExtra.putIfAbsent('custom_items', () => c);
    }
    p.payloadExtra.remove('appearance');
    if (jMap(col['custom_items']).isNotEmpty) p.collectionExtra['custom_items'] = col['custom_items'];

    final local = jMap(j['local_state']);
    p.bbxOwnedParts.addAll(jList(local['bbx_owned_parts']).whereType<String>());
    p.bbxManualMap.addAll({for (final e in jMap(local['bbx_manual_map']).entries) e.key: '${e.value}'});
    p.guideManualLit.addAll(_manualLitFrom(local['guide_manual_lit']));
    p.recentViewed.addAll(jList(local['recent_viewed']).whereType<String>());
    p.bbxCombos.addAll(jList(local['bbx_combos']).map(Combo.fromJson).nonNulls);
    p.bbxDecks.addAll(jList(local['bbx_decks']).map(Deck.fromJson).nonNulls);
    p.tagOwned.addAll(jList(local['tag_owned']).whereType<String>());
    p.tagLiked.addAll(jList(local['tag_liked']).whereType<String>());
    p.recentSearches.addAll(jList(local['recent_searches']).whereType<String>());
    p.searchCounts.addAll(_countsFrom(local['search_counts']));
    p.trash.addAll(_trashFrom(local['trash']));
    if (local['my_channels'] is List) p.myChannels = jList(local['my_channels']).whereType<String>().toList();
    return p;
  }
}
