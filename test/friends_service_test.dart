// 친구(Gunpula v3) — 가짜 서버로 아이디 · 요청 · 수락 · 끊기 · 친구 컬렉션 읽기.
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/sync/friends_service.dart';

import 'support/fake_backend.dart';

void main() {
  late FakeServer server;
  late FriendsService friends;

  setUp(() {
    server = FakeServer(handle: null, displayName: '나');
    server.users['gomdol'] = (
      name: '곰돌',
      collection: {
        'items': {
          'x': {'status': 'owned', 'updated_at': '2026-01-01T00:00:00Z'},
        },
        'member_items': {
          '곰돌': {
            'a': {'status': 'wanted', 'updated_at': '2026-02-01T00:00:00Z'},
            'b': {'status': 'wanted', 'updated_at': '2026-03-01T00:00:00Z'},
            'c': {'status': 'owned', 'updated_at': '2026-01-15T00:00:00Z'},
            'd': {'status': 'deleted', 'updated_at': '2026-04-01T00:00:00Z'},
          },
        },
      },
    );
    server.users['friend_b'] = (
      name: 'friend_b',
      collection: {
        'items': {
          'y': {'status': 'owned', 'updated_at': '2026-01-01T00:00:00Z'},
        },
      },
    );
    friends = FriendsService(() => server);
  });

  test('아이디: 틀린 모양은 서버에 묻지 않고 막는다 · 맞으면 소문자로 정한다', () async {
    await expectLater(friends.claimHandle('ab'), throwsA(isA<FriendsFailure>()));
    await expectLater(friends.claimHandle('한글아이디'), throwsA(isA<FriendsFailure>()));
    expect(server.count('gunpula_v3_claim_handle'), 0);
    await friends.claimHandle('@Bbang_01');
    expect(server.paramsOf('gunpula_v3_claim_handle').single['p_handle'], 'bbang_01');
    expect(friends.me?.handle, 'bbang_01');
  });

  test('이미 쓰는 아이디', () async {
    await expectLater(
      friends.claimHandle('gomdol'),
      throwsA(isA<FriendsFailure>().having((e) => e.message, 'message', '이미 누가 쓰는 아이디예요')),
    );
  });

  test('찾기 → 요청 → (상대가 수락) → 친구 → 컬렉션 → 끊기', () async {
    expect(await friends.search('nobody_here'), isNull);
    final found = await friends.search('@GomDol');
    expect(found?.profile.name, '곰돌');
    expect(found?.relation, 'none');

    await friends.request('gomdol');
    expect(friends.outgoing.single.handle, 'gomdol');
    expect((await friends.search('gomdol'))?.relation, 'outgoing');

    await expectLater(
      friends.collection('gomdol'),
      throwsA(isA<FriendsFailure>().having((e) => e.message, 'message', '친구가 아니라서 볼 수 없어요')),
    );

    // 곰돌이 수락
    server.outgoing.remove('gomdol');
    server.friends.add('gomdol');
    await friends.refresh();
    expect(friends.friends.single.name, '곰돌');

    final c = await friends.collection('gomdol');
    // member_items[이름] 이 items 보다 먼저 (옛 앱 openFriendProfile 과 같음), 최근 것부터, 지운 것은 뺌
    expect(c.likedIds, ['b', 'a']);
    expect(c.ownedIds, ['c']);
    expect(friends.collections.keys, ['gomdol']);

    await friends.remove('gomdol');
    expect(friends.friends, isEmpty);
    expect(friends.collections, isEmpty);
  });

  test('이름 버킷이 없으면 items 를 읽는다', () async {
    server.friends.add('friend_b');
    final c = await friends.collection('friend_b');
    expect(c.ownedIds, ['y']);
  });

  test('받은 요청: 수락 · 거절', () async {
    server.incoming.addAll(['gomdol', 'friend_b']);
    await friends.refresh();
    expect(friends.incoming.length, 2);
    await friends.respond('gomdol', accept: true);
    await friends.respond('friend_b', accept: false);
    expect(friends.friends.map((f) => f.handle), ['gomdol']);
    expect(friends.incoming, isEmpty);
    expect(server.paramsOf('gunpula_v3_respond_friend').first, {'p_handle': 'gomdol', 'p_accept': true});
  });

  test('상대가 먼저 요청했으면 내 요청이 곧 수락', () async {
    server.incoming.add('gomdol');
    await friends.request('gomdol');
    expect(friends.friends.single.handle, 'gomdol');
  });

  test('서버에 v3 함수가 없으면 unavailable', () async {
    server.missing.add('gunpula_v3_get_me');
    await expectLater(friends.refresh(), throwsA(isA<FriendsFailure>()));
    expect(friends.unavailable, isTrue);
  });

  test('오프라인이면 그 문장 그대로', () async {
    server.offline = true;
    await expectLater(
      friends.refresh(),
      throwsA(isA<FriendsFailure>().having((e) => e.message, 'message', contains('인터넷'))),
    );
  });
}
