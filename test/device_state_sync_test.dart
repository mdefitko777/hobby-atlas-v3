// 기기 기록 동기화 (lib/sync/device_state.dart · device_state_sync.dart) — 가짜 서버만 쓴다. 진짜 Supabase 에는 닿지 않는다.
// 두 기기 = UserStore.memory 두 개 + DeviceStateSync 두 개가 같은 FakeServer 를 본다.
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/bbx/combo.dart';
import 'package:hobby_atlas/bbx/parts.dart';
import 'package:hobby_atlas/data/user_store.dart';
import 'package:hobby_atlas/models.dart';
import 'package:hobby_atlas/sync/device_state.dart';
import 'package:hobby_atlas/sync/device_state_sync.dart';

import 'support/fake_backend.dart';

/// 시계를 손으로 돌리는 기기 하나
class Device {
  Device(this.server, {String email = 'me@example.com', bool switched = false})
    : auth = FakeAuth(signedIn: true, email: email) {
    sync = DeviceStateSync(
      auth: auth,
      rpc: () => server,
      store: store,
      clock: () => now,
      accountSwitched: () => switched,
    );
  }

  final FakeServer server;
  final FakeAuth auth;
  final store = UserStore.memory();
  late final DeviceStateSync sync;
  DateTime now = DateTime.utc(2026, 11, 1, 9);

  Future<void> run() => sync.syncNow();
  void tick([Duration d = const Duration(minutes: 1)]) => now = now.add(d);
}

Combo combo(String id, {String? nick}) => Combo(
  id: id,
  arch: Arch.standard,
  parts: const {Slot.blade: 'b1', Slot.ratchet: 'r1', Slot.bit: 'f1'},
  nickname: nick,
  createdAt: DateTime.utc(2026, 10, 1),
);

Map<String, Object?> sections(FakeServer s) => (s.deviceData['sections'] ?? const {}) as Map<String, Object?>;

void main() {
  group('규칙 (device_state.dart)', () {
    const set = DeviceSection.set('x');

    test('항목마다 늦은 쪽 · 같으면 서버 · 지움 표시가 이김', () {
      final local = {
        'a': {'t': 5},
        'b': {'t': 9, 'd': 1},
        'c': {'t': 3, 'v': 'L'},
      };
      final remote = {
        'a': {'t': 7, 'd': 1},
        'b': {'t': 4},
        'c': {'t': 3, 'v': 'R'},
        'd': {'t': 1},
      };
      final m = mergeSection(local, remote, 10);
      expect(m['a'], {'t': 7, 'd': 1}); // 다른 기기가 나중에 지움
      expect(m['b'], {'t': 9, 'd': 1}); // 내가 나중에 지움
      expect(m['c'], {'t': 3, 'v': 'R'}); // 같은 시각 → 서버
      expect(m.containsKey('d'), isTrue);
      expect(rebuildSection(set, m, ['a', 'b']), ['c', 'd']);
    });

    test('오래된 지움 표시는 버린다', () {
      final now = DateTime.utc(2026, 11, 1).millisecondsSinceEpoch;
      final old = now - (tombstoneDays + 1) * Duration.millisecondsPerDay;
      expect(mergeSection({'a': {'t': old, 'd': 1}}, null, now), isEmpty);
    });

    test('적기: 처음은 시각 0, 그 뒤 바뀐 것 = 지금, 없어진 것 = 지움', () {
      final first = stampSection(set, null, ['a', 'b'], 100);
      expect(first, {
        'a': {'t': 0},
        'b': {'t': 0},
      });
      expect(identical(stampSection(set, first, ['b', 'a'], 200), first), isTrue); // 순서만 다름 = 그대로
      final next = stampSection(set, first, ['b', 'c'], 300);
      expect(next['a'], {'t': 300, 'd': 1});
      expect(next['b'], {'t': 0});
      expect(next['c'], {'t': 300});
    });

    test('통째로 하나: 처음 기본값이면 "없음" → 다른 기기 값을 받는다', () {
      const ch = DeviceSection.value('my_channels', empty: ['gundam', 'beyblade', 'pokemon']);
      final mine = stampSection(ch, null, ['gundam', 'beyblade', 'pokemon'], 100);
      expect(mine, isEmpty);
      expect(stampSection(ch, mine, ['gundam', 'beyblade', 'pokemon'], 200), isEmpty); // 그대로면 계속 없음
      final merged = mergeSection(mine, {
        '_': {
          't': 0,
          'v': ['pokemon'],
        },
      }, 300);
      expect(rebuildSection(ch, merged, ['gundam', 'beyblade', 'pokemon']), ['pokemon']);
    });

    test('최근 검색: 두 기기 것을 새것부터 섞는다', () {
      const r = DeviceSection.recent('recent_searches', cap: 3);
      final a = stampSection(r, {}, ['건담', '자쿠'], 200);
      final b = stampSection(r, {}, ['베이', '자쿠'], 100);
      expect(rebuildSection(r, mergeSection(a, b, 300), const []), ['건담', '자쿠', '베이']);
    });

    test('조합 목록: id 로 합치고 기기 순서는 그대로, 새 것은 앞에', () {
      const c = DeviceSection.records('bbx_combos', newFirst: true);
      final cur = [
        {'id': 'c1', 'n': 1},
        {'id': 'c2', 'n': 2},
      ];
      final led = stampSection(c, {}, cur, 100);
      final merged = mergeSection(led, {
        'c2': {
          't': 200,
          'v': {'id': 'c2', 'n': 22},
        },
        'c3': {
          't': 150,
          'v': {'id': 'c3', 'n': 3},
        },
      }, 300);
      expect(rebuildSection(c, merged, cur), [
        {'id': 'c3', 'n': 3},
        {'id': 'c1', 'n': 1},
        {'id': 'c2', 'n': 22},
      ]);
    });

    test('새 키 등록 (batch-b 의 build_status 같은 것)', () {
      registerDeviceSection(const DeviceSection.map('test_only_status'));
      registerDeviceSection(const DeviceSection.map('test_only_status'));
      expect(deviceSections.where((s) => s.key == 'test_only_status'), hasLength(1));
    });
  });

  group('서비스', () {
    late FakeServer server;
    setUp(() => server = FakeServer());

    test('기기 A 기록 → 서버 → 새로 설치한 기기 B 가 받는다 (payload 에는 안 들어감)', () async {
      final a = Device(server);
      a.store
        ..setBbxPart('p1', true)
        ..setBbxPart('p2', true)
        ..setManualLit(42, true)
        ..setTagOwned('mz-intl:1-1-001@KR', true)
        ..setSpecialFriend('@bro', true)
        ..setMyChannels(['pokemon'])
        ..saveBbxCombo(combo('c1', nick: '드랜'))
        ..addRecentSearch('자쿠');
      a.store.bbxManualMap['kit-a'] = 'BX-01';
      await a.run();
      expect(a.sync.phase, DeviceSyncPhase.synced);
      expect(server.deviceRevision, 1);
      expect(sections(server).keys, containsAll(['bbx_owned_parts', 'bbx_combos', 'guide_manual_lit', 'my_channels']));
      // 옛 앱과 같이 쓰는 payload 는 건드리지 않는다
      expect(server.count('gunpula_v3_save_state'), 0);
      expect('${server.v3Payload}', isNot(contains('bbx')));

      final b = Device(server);
      await b.run();
      expect(b.store.bbxOwnedParts, {'p1', 'p2'});
      expect(b.store.bbxManualMap, {'kit-a': 'BX-01'});
      expect(b.store.guideManualLit, {42});
      expect(b.store.tagOwned, {'mz-intl:1-1-001@KR'});
      expect(b.store.specialFriends, {'@bro'});
      expect(b.store.myChannels, ['pokemon']);
      expect(b.store.bbxCombo('c1')?.nickname, '드랜');
      expect(b.store.recentSearches, ['자쿠']);
      expect(server.deviceRevision, 1, reason: 'B 는 받기만 — 같은 내용을 다시 올리지 않는다');
    });

    test('두 기기가 따로 바꿔도 잃지 않는다 (지우기 · 더하기 · 같은 항목은 늦은 쪽)', () async {
      final a = Device(server);
      final b = Device(server);
      a.store
        ..setBbxPart('p1', true)
        ..setBbxPart('p2', true);
      await a.run();
      await b.run();

      b.tick();
      b.store
        ..setBbxPart('p1', false)
        ..setBbxPart('p3', true);
      b.store.bbxManualMap['k'] = 'B';
      await b.run();

      a.tick(const Duration(minutes: 2)); // A 가 더 늦게 (B 것을 아직 안 받음)
      a.store.setBbxPart('p4', true);
      a.store.bbxManualMap['k'] = 'A';
      await a.run();
      expect(a.store.bbxOwnedParts, {'p2', 'p3', 'p4'});
      expect(a.store.bbxManualMap['k'], 'A');

      await b.run();
      expect(b.store.bbxOwnedParts, {'p2', 'p3', 'p4'});
      expect(b.store.bbxManualMap['k'], 'A');
    });

    test('40001: 다른 기기가 먼저 썼으면 다시 받아 합친 뒤 재시도', () async {
      final a = Device(server);
      a.store.setBbxPart('p1', true);
      await a.run();
      a.tick();
      a.store.setBbxPart('a2', true);
      server.otherDeviceStateWrites.add((data) {
        final sec = (data['sections']! as Map)['bbx_owned_parts']! as Map;
        sec['other'] = {'t': DateTime.utc(2026, 11, 1, 9, 0, 30).millisecondsSinceEpoch};
      });
      await a.run();
      expect(a.sync.conflicts, 1);
      expect(a.sync.phase, DeviceSyncPhase.synced);
      expect(a.store.bbxOwnedParts, {'p1', 'a2', 'other'});
      expect((sections(server)['bbx_owned_parts']! as Map).keys, containsAll(['p1', 'a2', 'other']));
    });

    test('처음 맞춤: 두 기기에 이미 있던 기록(시각 없음)은 합집합', () async {
      final a = Device(server);
      final b = Device(server);
      a.store.setBbxPart('old-a', true);
      b.store.setBbxPart('old-b', true);
      a.store.setManualLit(1, true);
      await a.run();
      await b.run();
      await a.run();
      expect(a.store.bbxOwnedParts, {'old-a', 'old-b'});
      expect(b.store.bbxOwnedParts, {'old-a', 'old-b'});
      expect(b.store.guideManualLit, {1});
      // 처음 기본 채널인 기기는 다른 기기가 고른 채널을 받는다
      a.store.setMyChannels(['gundam']);
      a.tick();
      await a.run();
      final c = Device(server);
      await c.run();
      expect(c.store.myChannels, ['gundam']);
    });

    test('서버에 함수가 없으면 아무것도 안 한다', () async {
      server.missing.addAll({'gunpula_v3_get_device_state', 'gunpula_v3_save_device_state'});
      final a = Device(server);
      a.store.setBbxPart('p1', true);
      await a.run();
      expect(a.sync.phase, DeviceSyncPhase.missing);
      expect(a.store.bbxOwnedParts, {'p1'});
      expect(a.store.deviceSync, isEmpty);
    });

    test('오프라인 → 기기에 dirty 로 남고, 연결되면 올린다', () async {
      final a = Device(server);
      server.offline = true;
      a.store.setBbxPart('p1', true);
      await a.run();
      expect(a.sync.phase, DeviceSyncPhase.offline);
      server.offline = false;
      await a.run();
      expect(a.sync.phase, DeviceSyncPhase.synced);
      expect(a.sync.dirty, isFalse);
      expect((sections(server)['bbx_owned_parts']! as Map).keys, ['p1']);
      a.sync.dispose();
    });

    test('모르는 키(새 버전 앱이 올린 것)는 서버에 그대로 남긴다', () async {
      server.deviceData = {
        'schema': 1,
        'future_top': 7,
        'sections': {
          'pre_orders_future': {
            'x': {'t': 1, 'v': 1},
          },
        },
      };
      final a = Device(server);
      a.store.setBbxPart('p1', true);
      await a.run();
      expect(server.deviceData['future_top'], 7);
      expect(sections(server)['pre_orders_future'], {
        'x': {'t': 1, 'v': 1},
      });
    });

    test('다른 계정으로 로그인 → 앞 계정 기록을 섞지 않고 새 계정 것으로', () async {
      final a = Device(server);
      a.store.setBbxPart('mine', true);
      await a.run();
      expect(a.store.deviceSync['account'], 'uid:me@example.com');

      final other = FakeServer()
        ..deviceData = {
          'schema': 1,
          'sections': {
            'bbx_owned_parts': {
              'bro': {'t': 5},
            },
          },
        }
        ..deviceRevision = 4;
      final b = Device(other, email: 'bro@example.com');
      b.store.debugLoadJson(a.store.toJson()); // 같은 기기 (저장 파일 그대로)
      await b.run();
      expect(b.store.bbxOwnedParts, {'bro'});
      expect((sections(other)['bbx_owned_parts'] ?? const {}) as Map, isNot(contains('mine')));
      expect(b.store.deviceSync['account'], 'uid:bro@example.com');
    });

    test('바꾸고 조금 뒤에 스스로 올린다 (바뀐 게 없으면 서버를 부르지 않는다)', () async {
      final auth = FakeAuth(signedIn: true);
      final store = UserStore.memory();
      final s = DeviceStateSync(auth: auth, rpc: () => server, store: store, debounce: Duration.zero)..start();
      await s.idle;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final saves = server.count('gunpula_v3_save_device_state');
      store.setTagOwned('frienda:1', true);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await s.idle;
      expect(server.count('gunpula_v3_save_device_state'), saves + 1);
      final gets = server.count('gunpula_v3_get_device_state');
      store.markViewed('kit-a'); // 맞추지 않는 키 (최근 본 것)
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await s.idle;
      expect(server.count('gunpula_v3_get_device_state'), gets);
      s.dispose();
    });
  });

  test('UserStore: 장부는 저장 파일에 남고, 바꿔 끼워도 구매함 · 좋아요는 그대로', () {
    final s = UserStore.memory()..setStatus('kit-a', CollectStatus.owned);
    s.setDeviceSync({
      'account': 'u1',
      'revision': 3,
      'sections': {
        'tag_owned': {
          'x': {'t': 1},
        },
      },
    });
    s.applyLocalState({
      'tag_owned': ['x'],
      'bbx_owned_parts': ['p'],
    });
    expect(s.tagOwned, {'x'});
    expect(s.bbxOwnedParts, {'p'});
    expect(s.statusOf('kit-a'), CollectStatus.owned);
    final again = UserStore.memory()..debugLoadJson(s.toJson());
    expect(again.deviceSync['revision'], 3);
    expect(UserStore.memory().toJson().containsKey('device_sync'), isFalse);
  });
}
