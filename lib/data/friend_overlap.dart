// 친구와 겹치는 상품 — 겹쳐 사지 않기 · 선물 고르기 (알림 화면 · 상품 상세가 같이 쓴다)
// 친구 컬렉션은 계정의 FriendsService.collections (get_friend_collection, 받아 둔 것만). 순수 함수라 테스트하기 쉽다.
import '../sync/friends_service.dart' show FriendCollection;

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
