// 친구와 겹치는 상품 (알림 N-8 · 상품 상세 D-5e)
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/logic/friends.dart';
import 'package:hobby_atlas/sync/friends_service.dart';

FriendCollection _c(String h, Map<String, String> status) => FriendCollection(
  profile: PublicProfile(handle: h, name: h.toUpperCase()),
  items: {for (final e in status.entries) e.key: {'status': e.value, 'updated_at': '2026-11-01'}},
  updatedAt: '2026-11-01',
);

void main() {
  final friends = {
    'bbang': _c('bbang', {'a': 'owned', 'b': 'wanted'}),
    'amy': _c('amy', {'a': 'wanted', 'c': 'owned'}),
  };

  test('내 좋아요를 친구가 이미 가짐 — 친구 아이디순', () {
    final r = likedOwnedByFriends(friends, {'a', 'c', 'z'});
    expect([for (final o in r) '${o.handle}:${o.kitId}'], ['amy:c', 'bbang:a']);
    expect(r.last.name, 'BBANG');
  });

  test('이 상품을 가진 · 좋아요한 친구', () {
    final f = friendsWithKit(friends, 'a');
    expect(f.owned, ['bbang']);
    expect(f.liked, ['amy']);
    expect(friendsWithKit(friends, 'z').owned, isEmpty);
  });
}
