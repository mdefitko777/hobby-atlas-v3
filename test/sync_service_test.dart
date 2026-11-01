// 동기화 약속(설계 §1.5) 확인 — 가짜 서버(test/support/fake_backend.dart)만 쓴다. 진짜 Supabase 에는 닿지 않는다.
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/data/user_store.dart';
import 'package:hobby_atlas/models.dart';
import 'package:hobby_atlas/sync/account.dart';
import 'package:hobby_atlas/sync/rpc.dart';
import 'package:hobby_atlas/sync/sync_service.dart';

import 'support/fake_backend.dart';

const me = '빵빵한빵디';

Map<String, Object?> entry(String status, String at, {String by = me}) => {
  'status': status,
  'updated_at': at,
  'updated_by': by,
  'quantity': 1,
};

/// 옛 앱이 올려 둔 v2 payload (모르는 키 · 다른 멤버 · overrides · 집 사진 · 비공개 위시까지)
Map<String, Object?> oldAppPayload() => {
  'schema_version': 1,
  'collection': {
    'owned': ['kit-a'],
    'wanted': ['kit-b'],
    'items': {
      'kit-a': entry('owned', '2026-10-01T00:00:00.000Z'),
      'kit-b': entry('wanted', '2026-10-02T00:00:00.000Z'),
      'kit-gone': entry('deleted', '2026-10-03T00:00:00.000Z'),
    },
    'member_items': {
      me: {
        'kit-a': entry('owned', '2026-10-01T00:00:00.000Z'),
        'kit-b': entry('wanted', '2026-10-02T00:00:00.000Z'),
        'kit-gone': entry('deleted', '2026-10-03T00:00:00.000Z'),
      },
      '동생': {
        'kit-z': {'status': 'owned', 'purchase_price': '12,000', 'updated_at': '2026-09-01T00:00:00Z'},
      },
    },
    'custom_items': {
      'private-1': {
        'name': '비공개 위시',
        'image_data_url': 'data:image/jpeg;base64,AAAA',
        'updated_at': '2026-09-09T00:00:00Z',
      },
    },
  },
  'overrides': {
    'kit-9': {'name_ko': '고친 이름', 'updated_at': '2026-08-01T00:00:00Z'},
  },
  'series_label_overrides': {'seed': 'SEED 시리즈'},
  'appearance': {
    'theme': 'classic',
    'app_icon': '',
    'home_covers': {'gundam': 'data:image/png;base64,BBBB'},
  },
  'unknown_future_key': [1, 2, 3],
};

void main() {
  late FakeServer server;
  late FakeAuth auth;
  late UserStore store;
  late Account account;

  Account make({bool signedIn = true}) {
    auth = FakeAuth(signedIn: signedIn);
    store = UserStore.memory();
    account = Account(
      auth: auth,
      rpc: server,
      store: store,
      debounce: const Duration(milliseconds: 20),
      pollEvery: const Duration(hours: 1), // 테스트에서는 직접 부른다
    );
    addTearDown(account.dispose);
    return account;
  }

  /// 바꾼 뒤 0.7초(여기선 20ms) 기다렸다 올리는 것까지
  Future<void> settle() async {
    await Future<void>.delayed(const Duration(milliseconds: 60));
    await account.sync.idle;
  }

  Map<String, Object?> v2Collection() => server.v2Payload!['collection']! as Map<String, Object?>;
  Map<String, dynamic> v2Mine() => (v2Collection()['member_items']! as Map)[me] as Map<String, dynamic>;

  group('로그인하면 옛 앱 컬렉션이 온다', () {
    setUp(() => server = FakeServer(v2Payload: oldAppPayload()));

    test('로그인 직후 받기 — 구매함 · 좋아요 수가 옛 앱과 같다', () async {
      make().start();
      await account.sync.idle;
      expect(store.ownedCount, 1);
      expect(store.wantedCount, 1);
      expect(store.statusOf('kit-gone'), CollectStatus.none); // 지운 기록도 남아 있음
      expect(store.member, me);
      expect(account.sync.phase, SyncPhase.synced);
      expect(account.sync.workspace?.name, '우리집 컬렉션');
      // 바뀐 게 없으니 v2 에는 저장하지 않고, v3 복사본만 맞춘다
      expect(server.count('gunpula_v2_save_state'), 0);
      expect(server.count('gunpula_v3_save_state'), 1);
      expect(server.v3Payload, server.v2Payload);
    });

    test('Hobby Atlas 에만 있는 값(베이 부품 · 도감 손으로 켜기)은 payload 에 안 들어간다', () async {
      make().start();
      await account.sync.idle;
      store
        ..setBbxPart('BX-01-blade', true)
        ..setManualLit(987654321, true)
        ..setStatus('kit-c', CollectStatus.owned);
      await settle();
      final text = server.v2Payload.toString();
      expect(text, isNot(contains('BX-01-blade')));
      expect(text, isNot(contains('987654321')));
      expect(v2Mine().keys, contains('kit-c'));
    });
  });

  group('저장: get → 합침 → save, 서버 것은 그대로', () {
    setUp(() => server = FakeServer(v2Payload: oldAppPayload()));

    test('좋아요 하나 → 0.7초 뒤 v2 저장 + v3 복사, 나머지 키는 한 글자도 안 바뀜', () async {
      make().start();
      await account.sync.idle;
      final before = roundTrip(server.v2Payload)! as Map<String, Object?>;
      store.setStatus('kit-new', CollectStatus.wanted);
      expect(store.cloudDirty, isTrue);
      await settle();

      expect(server.count('gunpula_v2_save_state'), 1);
      final p = server.paramsOf('gunpula_v2_save_state').single;
      expect(p['p_base_revision'], 3);
      expect(p['p_reason'], 'hobby-atlas');
      final after = server.v2Payload!;
      for (final k in ['overrides', 'series_label_overrides', 'appearance', 'unknown_future_key', 'schema_version']) {
        expect(after[k], before[k], reason: k);
      }
      final col = after['collection']! as Map;
      final beforeCol = before['collection']! as Map;
      expect(col['custom_items'], beforeCol['custom_items']);
      expect((col['member_items'] as Map)['동생'], (beforeCol['member_items'] as Map)['동생']); // 정리도 안 함
      expect(v2Mine()['kit-new']?['status'], 'wanted');
      expect(v2Mine()['kit-new']?['updated_by'], me);
      expect((col['items'] as Map).keys, contains('kit-new'));
      expect(col['wanted'], containsAll(['kit-b', 'kit-new']));
      // 옛 앱이 아는 필드만
      expect((v2Mine()['kit-new'] as Map).keys.toSet(), {'status', 'updated_at', 'updated_by', 'quantity'});
      expect(store.cloudDirty, isFalse);
      // v3 복사본 = v2
      expect(server.v3Payload, server.v2Payload);
      expect(server.paramsOf('gunpula_v3_save_state').last['p_base_revision'], 8);
    });

    test('옛 앱이 그사이 바꾼 것도 살린다 (상품별로 늦은 쪽)', () async {
      make().start();
      await account.sync.idle;
      // 옛 앱(다른 기기)에서 kit-a 를 지우고 kit-d 를 좋아요
      final mine = v2Mine();
      mine['kit-a'] = entry('deleted', '2026-10-30T00:00:00.000Z');
      mine['kit-d'] = entry('wanted', '2026-10-30T00:00:01.000Z');
      server.v2Revision++;
      // 이 기기에서 kit-b 를 구매함으로
      store.setStatus('kit-b', CollectStatus.owned);
      await settle();
      expect(v2Mine()['kit-a']?['status'], 'deleted');
      expect(v2Mine()['kit-d']?['status'], 'wanted');
      expect(v2Mine()['kit-b']?['status'], 'owned');
      expect(store.statusOf('kit-a'), CollectStatus.none);
      expect(store.statusOf('kit-d'), CollectStatus.wanted);
    });

    test('지운 것(tombstone)이 더 늦으면 지움이 이긴다 · 더 이른 지움은 진다', () async {
      make().start();
      await account.sync.idle;
      store.setStatus('kit-a', CollectStatus.none); // 지금 지움 → 서버 owned(10-01)보다 늦음
      await settle();
      expect(v2Mine()['kit-a']?['status'], 'deleted');
      // 다른 기기가 나중에 다시 owned
      v2Mine()['kit-a'] = entry('owned', '2099-01-01T00:00:00.000Z');
      await account.sync.syncNow();
      expect(store.statusOf('kit-a'), CollectStatus.owned);
    });

    test('바뀐 게 없으면 15초마다 받아도 저장하지 않는다', () async {
      make().start();
      await account.sync.idle;
      await account.sync.syncNow(reason: 'poll');
      await account.sync.syncNow(reason: 'poll');
      expect(server.count('gunpula_v2_get_state'), 3);
      expect(server.count('gunpula_v2_save_state'), 0);
      expect(server.count('gunpula_v3_save_state'), 1); // 처음 한 번 복사본만
      // 15초 받기는 v2 만 — v3 get_me(친구 요청)는 4번에 1번 (payload 가 무거워서)
      expect(server.count('gunpula_v3_get_me'), 1);
      await account.sync.syncNow(reason: 'poll');
      await account.sync.syncNow(reason: 'poll');
      expect(server.count('gunpula_v3_get_me'), 2);
      // 앱으로 돌아오면 바로
      await account.sync.syncNow(reason: 'resume');
      expect(server.count('gunpula_v3_get_me'), 3);
    });

    test("별칭 버킷 'member' 는 나에게 합치고 '냐아' 는 버린다 (옛 앱 규칙)", () async {
      final p = oldAppPayload();
      final members = (p['collection']! as Map)['member_items'] as Map;
      members['member'] = {'kit-m': entry('wanted', '2026-10-05T00:00:00.000Z', by: 'member')};
      members['냐아'] = {'kit-n': entry('owned', '2026-10-05T00:00:00.000Z', by: '냐아')};
      server = FakeServer(v2Payload: p);
      make().start();
      await account.sync.idle;
      final saved = v2Collection()['member_items']! as Map;
      expect(saved.keys.toSet(), {me, '동생'});
      expect(v2Mine().keys, contains('kit-m'));
      expect(store.statusOf('kit-m'), CollectStatus.wanted);
    });

    test("옛 앱이 이름을 안 정해 'member' 에 쓰고 있으면 Hobby Atlas 도 'member' 에 쓴다", () async {
      final p = oldAppPayload();
      final col = p['collection']! as Map<String, Object?>;
      final members = col['member_items']! as Map<String, Object?>;
      members['member'] = members.remove(me);
      server = FakeServer(v2Payload: p, selfName: 'mdefitko');
      make().start();
      await account.sync.idle;
      expect(store.member, 'member');
      expect(store.ownedCount, 1);
      store.setStatus('kit-x', CollectStatus.owned);
      await settle();
      final saved = v2Collection()['member_items']! as Map;
      expect(saved.keys.toSet(), {'member', '동생'});
      expect((saved['member'] as Map).keys, contains('kit-x'));
    });

    test('공유 공간에서 동생이 마지막에 저장했어도 동생 버킷은 건드리지 않는다', () async {
      final p = oldAppPayload();
      final col = p['collection']! as Map<String, Object?>;
      final members = col['member_items']! as Map<String, Object?>;
      members.remove(me); // 내 버킷이 아직 없음
      col['items'] = members['동생']; // 마지막 저장 = 동생
      server = FakeServer(
        v2Payload: p,
        members: [
          {'name': '동생', 'email': 'bro@example.com', 'role': 'editor', 'is_self': false},
        ],
      );
      make().start();
      await account.sync.idle;
      expect(store.member, me);
      expect(store.ownedCount, 0);
      final before = roundTrip((v2Collection()['member_items']! as Map)['동생']);
      store.setStatus('kit-mine', CollectStatus.owned);
      await settle();
      final saved = v2Collection()['member_items']! as Map;
      expect(saved['동생'], before);
      expect((saved[me] as Map).keys, ['kit-mine']);
    });

    test('로그인 전에 기기에서 바꾼 것도 로그인하면 올라간다', () async {
      make(signedIn: false).start();
      store.setStatus('kit-offline', CollectStatus.owned);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(server.calls, isEmpty); // 로그아웃 상태에서는 서버를 부르지 않는다
      auth.signedIn = true;
      await account.sync.idle;
      expect(v2Mine()['kit-offline']?['status'], 'owned');
      expect(store.ownedCount, 2);
    });
  });

  group('v3 복사본: 40001 이면 get_me → 합침 → 다시 (최대 3번)', () {
    setUp(() => server = FakeServer(v2Payload: oldAppPayload()));

    test('다른 기기가 v3 에 먼저 써서 두 번 부딪혀도 둘 다 살아남는다', () async {
      make().start();
      await account.sync.idle;
      final saves = server.count('gunpula_v3_save_state');
      // 다른 기기(옛 앱)의 v3 복사본 저장 2번 — 그쪽에만 있는 기록
      for (final kit in ['kit-other-1', 'kit-other-2']) {
        server.otherDeviceV3Writes.add((payload) {
          final col = payload['collection']! as Map<String, Object?>;
          ((col['member_items']! as Map)[me] as Map)[kit] = entry('owned', '2026-10-31T00:00:00.000Z');
        });
      }
      store.setStatus('kit-mine', CollectStatus.wanted);
      await settle();
      expect(server.count('gunpula_v3_save_state') - saves, 3); // 첫 시도 + 재시도 2번
      expect(account.sync.v3Conflicts, 2);
      final v3Mine = ((server.v3Payload['collection']! as Map)['member_items'] as Map)[me] as Map;
      expect(v3Mine.keys, containsAll(['kit-mine', 'kit-other-1', 'kit-other-2']));
      expect(account.sync.phase, SyncPhase.synced);
    });

    test('계속 부딪히면 3번 다시 해 보고 멈춘다 (v2 저장은 이미 끝남)', () async {
      make().start();
      await account.sync.idle;
      final saves = server.count('gunpula_v3_save_state');
      for (var i = 0; i < 10; i++) {
        server.otherDeviceV3Writes.add((_) {});
      }
      store.setStatus('kit-mine', CollectStatus.wanted);
      await settle();
      expect(server.count('gunpula_v3_save_state') - saves, 4); // 1 + 재시도 3
      expect(v2Mine()['kit-mine']?['status'], 'wanted');
      expect(store.cloudDirty, isFalse);
      expect(account.sync.phase, SyncPhase.synced); // v2 가 원본이라 실패로 보지 않음 (다음 번에 다시 맞춤)
    });
  });

  group('공유 공간이 없는 계정 (동생 · 친구) → v3 내 행이 원본', () {
    test('v3 에 저장, 40001 이면 합쳐서 다시', () async {
      server = FakeServer(handle: 'dongsaeng', displayName: '동생');
      make().start();
      await account.sync.idle;
      expect(account.sync.workspace, isNull);
      store.setStatus('kit-1', CollectStatus.owned);
      server.otherDeviceV3Writes.add((payload) {
        final col = payload['collection']! as Map<String, Object?>;
        (col['member_items']! as Map<String, Object?>)['동생'] = {'kit-2': entry('wanted', '2026-10-31T00:00:00.000Z')};
      });
      await settle();
      final col = server.v3Payload['collection']! as Map;
      final bucket = (col['member_items'] as Map)['동생'] as Map;
      expect(bucket.keys.toSet(), {'kit-1', 'kit-2'});
      expect((col['items'] as Map).keys.toSet(), {'kit-1', 'kit-2'});
      expect(store.statusOf('kit-2'), CollectStatus.wanted); // 다른 기기 것이 이 기기로
      expect(server.count('gunpula_v2_save_state'), 0);
    });
  });

  group('오프라인', () {
    test('바꾼 것은 기기에 남고, 연결되면 다시 올린다', () async {
      server = FakeServer(v2Payload: oldAppPayload());
      make().start();
      await account.sync.idle;
      server.offline = true;
      store.setStatus('kit-offline', CollectStatus.owned);
      await settle();
      expect(account.sync.phase, SyncPhase.offline);
      expect(store.cloudDirty, isTrue);
      expect(account.sync.statusLine, contains('오프라인'));
      server.offline = false;
      await account.sync.syncNow(reason: 'poll');
      expect(v2Mine()['kit-offline']?['status'], 'owned');
      expect(store.cloudDirty, isFalse);
      expect(account.sync.phase, SyncPhase.synced);
    });

    test('로그인이 풀리면(42501) 오류로 알리고, 바꾼 것은 남긴다', () async {
      server = FakeServer(v2Payload: oldAppPayload());
      make().start();
      await account.sync.idle;
      server.authExpired = true;
      store.setStatus('kit-x', CollectStatus.owned);
      await settle();
      expect(account.sync.phase, SyncPhase.error);
      expect(account.sync.statusLine, contains('다시 로그인'));
      expect(store.cloudDirty, isTrue);
    });

    test('v2 SQL 이 없는 프로젝트면 v3 만으로 계속', () async {
      server = FakeServer(v2Payload: oldAppPayload());
      server.missing.add('gunpula_v2_get_state');
      make().start();
      await account.sync.idle;
      expect(account.sync.phase, SyncPhase.synced);
      expect(account.sync.workspace, isNull);
    });
  });

  group('앱 앞/뒤 · 15초 받기', () {
    test('앞에 있는 동안 주기적으로 받고, 뒤로 가면 멈춘다', () async {
      server = FakeServer(v2Payload: oldAppPayload());
      auth = FakeAuth(signedIn: true);
      store = UserStore.memory();
      account = Account(auth: auth, rpc: server, store: store, pollEvery: const Duration(milliseconds: 40));
      addTearDown(account.dispose);
      account.start();
      await Future<void>.delayed(const Duration(milliseconds: 230));
      final polled = server.count('gunpula_v2_get_state');
      expect(polled, greaterThanOrEqualTo(3));
      account.sync.didChangeAppLifecycleState(AppLifecycleState.paused);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(server.count('gunpula_v2_get_state'), lessThanOrEqualTo(polled + 1));
      account.sync.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await account.sync.idle;
      expect(server.count('gunpula_v2_get_state'), greaterThan(polled));
    });

    test('바꾼 직후 뒤로 가면 0.7초를 기다리지 않고 바로 올린다', () async {
      server = FakeServer(v2Payload: oldAppPayload());
      auth = FakeAuth(signedIn: true);
      store = UserStore.memory();
      account = Account(
        auth: auth,
        rpc: server,
        store: store,
        debounce: const Duration(seconds: 30),
        pollEvery: const Duration(hours: 1),
      );
      addTearDown(account.dispose);
      account.start();
      await account.sync.idle;
      store.setStatus('kit-last', CollectStatus.owned);
      account.sync.didChangeAppLifecycleState(AppLifecycleState.paused);
      await account.sync.idle;
      expect(v2Mine()['kit-last']?['status'], 'owned');
    });
  });

  group('로그아웃', () {
    test('기기의 기록은 남고 친구 · 공유 공간 정보는 지운다', () async {
      server = FakeServer(v2Payload: oldAppPayload(), handle: 'bbang');
      server.users['dongsaeng'] = (name: '동생', collection: const {});
      server.friends.add('dongsaeng');
      make().start();
      await account.sync.idle;
      expect(account.friends.friends.single.handle, 'dongsaeng');
      await account.signOut();
      expect(account.signedIn, isFalse);
      expect(account.friends.friends, isEmpty);
      expect(account.sync.workspace, isNull);
      expect(store.ownedCount, 1);
      final before = server.calls.length;
      await account.sync.syncNow();
      expect(server.calls.length, before);
    });
  });

  test('설정이 없으면 늘 로그아웃 (NoAuth · NoBackendRpc)', () async {
    final a = Account.offline();
    addTearDown(a.dispose);
    expect(a.available, isFalse);
    expect(a.signedIn, isFalse);
    await expectLater(a.sendCode('x@y.z'), throwsA(isA<AuthFailure>()));
  });
}
