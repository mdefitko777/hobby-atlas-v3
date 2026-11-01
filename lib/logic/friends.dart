// 친구 규칙 (순수 Dart) — 친구 컬렉션은 계정의 FriendsService.collections (get_friend_collection, 받아 둔 것만)
//   · 친구와 겹치는 상품: 겹쳐 사지 않기 · 선물 고르기 (알림 화면 · 상품 상세)
//   · 친구 → 화면 모델 (서랍 · 내 정보) · 친구의 가장 최근 일 · 새 사진 수 (서랍 · 상태 줄)
import '../models.dart';
import '../sync/friends_service.dart' show FriendCollection, PublicProfile;
import '../sync/photo_share.dart' show FriendPhoto, FriendWall;

/// 내가 좋아요한 상품을 이미 가진 친구 — (친구 아이디, kit_id), 친구 이름순 · 친구 안에서는 최근 산 것부터
List<({String handle, String name, String kitId})> likedOwnedByFriends(
  Map<String, FriendCollection> friends,
  Set<String> myLiked,
) {
  final handles = friends.keys.toList()..sort();
  return [
    for (final h in handles)
      for (final id in friends[h]!.ownedIds)
        if (myLiked.contains(id)) (handle: h, name: friends[h]!.profile.name, kitId: id),
  ];
}

/// 이 상품을 가진 친구 · 좋아요한 친구 (아이디)
({List<String> owned, List<String> liked}) friendsWithKit(Map<String, FriendCollection> friends, String kitId) {
  final owned = <String>[];
  final liked = <String>[];
  for (final e in friends.entries) {
    final st = e.value.items[kitId]?['status'];
    if (st == 'owned') owned.add(e.key);
    if (st == 'wanted') liked.add(e.key);
  }
  return (owned: owned..sort(), liked: liked..sort());
}

/// 계정 친구 → 화면 모델 (숫자는 받아 둔 컬렉션에서)
Member friendMemberOf(PublicProfile f, FriendCollection? c) => Member(
  name: f.name,
  handle: f.handle,
  role: '친구',
  self: false,
  liked: c?.likedIds.length ?? 0,
  lit: 0,
  owned: c?.ownedIds.length ?? 0,
  likedIds: c?.likedIds ?? const [],
  ownedIds: c?.ownedIds ?? const [],
);

/// 친구의 가장 최근 일 — 구매함 · 좋아요에 담은 것 또는 보이기로 둔 사진
class FriendEvent {
  const FriendEvent(this.kind, this.kitId, this.at);

  /// 'owned' · 'wanted' · 'photo'
  final String kind;
  final String kitId;
  final DateTime at;
}

FriendEvent? latestFriendEvent(FriendCollection? c, FriendWall? w) {
  FriendEvent? best;
  void consider(FriendEvent e) {
    if (best == null || e.at.isAfter(best!.at)) best = e;
  }

  for (final e in c?.items.entries ?? const <MapEntry<String, Map<String, Object?>>>[]) {
    final st = '${e.value['status'] ?? ''}';
    final at = DateTime.tryParse('${e.value['updated_at'] ?? ''}');
    if (at != null && (st == 'owned' || st == 'wanted')) consider(FriendEvent(st, e.key, at));
  }
  for (final p in w?.photos ?? const <FriendPhoto>[]) {
    final at = DateTime.tryParse(p.createdAt);
    if (at != null) consider(FriendEvent('photo', p.kitId, at));
  }
  return best;
}

/// [sinceIso] 뒤에 올라온 친구 사진 수 (처음 여는 것이면 0)
int newPhotoCount(FriendWall? w, String sinceIso) {
  final since = DateTime.tryParse(sinceIso);
  if (since == null || w == null) return 0;
  return w.photos.where((p) => DateTime.tryParse(p.createdAt)?.isAfter(since) ?? false).length;
}
