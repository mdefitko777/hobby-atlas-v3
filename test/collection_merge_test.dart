// lib/sync/collection_merge.dart — 옛 Gunpula scripts/test_collection_store.mjs 의 시험 값을 그대로 옮기고,
// Hobby Atlas 가 서버 payload 를 망가뜨리지 않는지(모르는 키 · 다른 멤버 · overrides 보존)를 더 본다.
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/sync/collection_merge.dart';

void main() {
  // test_collection_store.mjs 와 같은 options
  const options = CollectionOptions(self: 'me', droppedMembers: {'drop-me'}, memberMerges: {'member': 'me'});

  group('collection-store.js 시험 값', () {
    test('safeMemberName · clampCollectionQuantity', () {
      expect(safeMemberName('  '), 'member');
      expect(safeMemberName(null), 'member');
      expect(clampCollectionQuantity('0'), 1);
      expect(clampCollectionQuantity('120'), 99);
      expect(clampCollectionQuantity('abc'), 1);
      expect(clampCollectionQuantity(3.9), 3);
    });

    test('normalizeCollection: 버림 · 합침 · 옛 owned[]/wanted[] 는 member_items 가 있으면 무시', () {
      final normalized = normalizeCollection({
        'owned': ['kit-a'],
        'wanted': ['kit-b'],
        'member_items': {
          'drop-me': {
            'kit-x': {'status': 'owned'},
          },
          'member': {
            'kit-c': {'status': 'wanted', 'quantity': 2, 'updated_at': '2026-01-01T00:00:00Z'},
          },
        },
      }, options);
      expect(normalized['owned'], isEmpty);
      expect(normalized['wanted'], ['kit-c']);
      final members = normalized['member_items']! as Map;
      expect(members['drop-me'], isNull);
      expect((members['me'] as Map)['kit-c']['quantity'], 2);
    });

    test('mergeCollectionState: 더 늦은 기록이 이긴다', () {
      final merged = mergeCollectionState(
        {
          'member_items': {
            'me': {
              'kit-a': {'status': 'wanted', 'updated_at': '2026-01-01T00:00:00Z'},
            },
          },
        },
        {
          'member_items': {
            'me': {
              'kit-a': {'status': 'owned', 'updated_at': '2026-02-01T00:00:00Z'},
            },
          },
        },
        options,
      );
      expect(((merged['member_items']! as Map)['me'] as Map)['kit-a']['status'], 'owned');
    });

    test('mergeTimestampedMap: 키별로 더 늦은 값', () {
      expect(
        mergeTimestampedMap(
          {
            'a': {'value': 1, 'updated_at': '2026-01-01T00:00:00Z'},
          },
          {
            'a': {'value': 2, 'updated_at': '2025-01-01T00:00:00Z'},
          },
        ),
        {
          'a': {'value': 1, 'updated_at': '2026-01-01T00:00:00Z'},
        },
      );
    });
  });

  group('기록 한 줄 정리 (normalizeCollectionEntry)', () {
    test('값 정리: 수량 · 산 값 · 메모', () {
      final e = normalizeCollectionEntry({
        'status': 'owned',
        'updated_at': '2026-03-01T00:00:00Z',
        'quantity': '250',
        'purchase_price': '₩12,500.4',
        'note': '박스 찌그러짐',
        'storage': '',
      }, member: 'me');
      expect(e, {
        'status': 'owned',
        'updated_at': '2026-03-01T00:00:00Z',
        'updated_by': 'me',
        'quantity': 99,
        'note': '박스 찌그러짐',
        'purchase_price': 12500,
      });
    });

    test('모르는 상태는 wanted, wanted_quantity 도 읽는다', () {
      final e = normalizeCollectionEntry({'status': 'x', 'wanted_quantity': 4, 'updated_at': 't'});
      expect(e['status'], 'wanted');
      expect(e['quantity'], 4);
    });
  });

  group('지움(tombstone) · 같은 시각', () {
    test('지운 기록이 더 늦으면 지움이 이긴다', () {
      final merged = mergeCollectionState(
        {
          'member_items': {
            'me': {
              'k': {'status': 'deleted', 'updated_at': '2026-05-02T00:00:00Z'},
            },
          },
        },
        {
          'member_items': {
            'me': {
              'k': {'status': 'owned', 'updated_at': '2026-05-01T00:00:00Z'},
            },
          },
        },
        options,
      );
      expect(((merged['member_items']! as Map)['me'] as Map)['k']['status'], 'deleted');
      expect(merged['owned'], isEmpty);
    });

    test('같은 시각이면 local', () {
      final merged = mergeCollectionState(
        {
          'member_items': {
            'me': {
              'k': {'status': 'wanted', 'updated_at': '2026-05-01T00:00:00Z'},
            },
          },
        },
        {
          'member_items': {
            'me': {
              'k': {'status': 'owned', 'updated_at': '2026-05-01T00:00:00Z'},
            },
          },
        },
        options,
      );
      expect(merged['wanted'], ['k']);
    });

    test('한쪽에만 있으면 그대로 (시각이 없어도 사라지지 않음)', () {
      expect(newerByTimestamp<Object>(null, {'status': 'owned'}), {'status': 'owned'});
      expect(newerByTimestamp<Object>({'status': 'owned'}, null), {'status': 'owned'});
    });
  });

  group('로그인한 나 기준 (main.js collectionStoreOptions)', () {
    test('member · ttungyimu 는 나에게 합치고 냐아는 버린다', () {
      final o = CollectionOptions.forSelf('빵빵한빵디');
      final n = normalizeCollection({
        'member_items': {
          'member': {
            'a': {'status': 'owned', 'updated_at': '2026-01-01T00:00:00Z'},
          },
          'ttungyimu': {
            'b': {'status': 'wanted', 'updated_at': '2026-01-02T00:00:00Z'},
          },
          '냐아': {
            'c': {'status': 'owned', 'updated_at': '2026-01-03T00:00:00Z'},
          },
          '빵빵한빵디': {
            'a': {'status': 'wanted', 'updated_at': '2025-12-01T00:00:00Z'},
          },
          '곰돌': {
            'd': {'status': 'owned', 'updated_at': '2026-01-04T00:00:00Z'},
          },
        },
      }, o);
      final m = n['member_items']! as Map;
      expect(m.keys.toSet(), {'빵빵한빵디', '곰돌'});
      expect((m['빵빵한빵디'] as Map)['a']['status'], 'owned'); // member 쪽이 더 늦음
      expect(n['items'], contains('b'));
    });

    test("아직 'member' 이면 합치지 않는다 (로그인 전)", () {
      final o = CollectionOptions.forSelf('member');
      expect(o.memberMerges, isEmpty);
      expect(o.droppedMembers, contains('냐아'));
    });
  });

  group('내 버킷 이름 고르기', () {
    test('서버가 알려 준 이름의 버킷이 있으면 그것', () {
      final p = {
        'collection': {
          'items': {'x': {}},
          'member_items': {
            'member': {'x': {}},
            '빵빵한빵디': {'y': {}},
          },
        },
      };
      expect(resolveSelfBucket(p, '빵빵한빵디'), '빵빵한빵디');
    });

    test('없으면 items 와 같은 버킷 (옛 앱이 이름을 안 정해 member 에 쓰는 경우)', () {
      final p = {
        'collection': {
          'items': {
            'x': {'status': 'owned'},
          },
          'member_items': {
            'member': {
              'x': {'status': 'owned'},
            },
            '곰돌': {
              'z': {'status': 'owned'},
            },
          },
        },
      };
      expect(resolveSelfBucket(p, 'mdefitko'), 'member');
    });

    test('공유 공간에서 곰돌이 마지막에 저장해 items 가 곰돌 것이어도 곰돌 버킷을 내 것으로 잡지 않는다', () {
      final p = {
        'collection': {
          'items': {
            'z': {'status': 'owned'},
          },
          'member_items': {
            '곰돌': {
              'z': {'status': 'owned'},
            },
            'old_name': {
              'x': {'status': 'owned'},
            },
          },
        },
      };
      expect(resolveSelfBucket(p, 'mdefitko', notMine: {'곰돌'}), 'mdefitko');
      expect(resolveSelfBucket(p, 'mdefitko'), '곰돌'); // 다른 멤버 이름을 모르면 items 를 따른다 (v3 만 쓰는 계정)
    });

    test('빈 payload 면 서버 이름', () {
      expect(resolveSelfBucket(const {}, 'mdefitko'), 'mdefitko');
      expect(resolveSelfBucket(const {}, ''), 'member');
    });
  });

  group('buildSyncPayload — 서버 것을 망가뜨리지 않기', () {
    final remote = <String, Object?>{
      'schema_version': 1,
      'collection': {
        'owned': ['a'],
        'wanted': [],
        'items': {
          'a': {'status': 'owned', 'updated_at': '2026-01-01T00:00:00Z', 'updated_by': '빵빵한빵디', 'quantity': 1},
        },
        'member_items': {
          '빵빵한빵디': {
            'a': {'status': 'owned', 'updated_at': '2026-01-01T00:00:00Z', 'updated_by': '빵빵한빵디', 'quantity': 1},
          },
          // 다른 멤버: 정리 안 된 글자 그대로 남아야 한다 (가격 문자열 · 수량 없음)
          '곰돌': {
            'z': {'status': 'owned', 'purchase_price': '12,000', 'updated_at': '2026-01-05T00:00:00Z'},
          },
          'member': {
            'm': {'status': 'wanted', 'updated_at': '2026-01-03T00:00:00Z'},
          },
          '냐아': {
            'n': {'status': 'owned', 'updated_at': '2026-01-03T00:00:00Z'},
          },
        },
        'custom_items': {
          'private-1': {
            'name': '비공개 위시',
            'image_data_url': 'data:image/jpeg;base64,AAAA',
            'updated_at': '2026-01-01T00:00:00Z',
          },
        },
      },
      'overrides': {
        'kit-9': {'name_ko': '고친 이름', 'updated_at': '2026-01-01T00:00:00Z'},
      },
      'series_label_overrides': {'seed': 'SEED 시리즈'},
      'appearance': {
        'theme': 'classic',
        'app_icon': '',
        'home_covers': {'gundam': 'data:image/png;base64,BBBB'},
      },
      'future_key': {'from': 'newer old-app'},
    };

    test('내 버킷만 바뀌고 나머지는 글자 그대로', () {
      final out = buildSyncPayload(
        remote: remote,
        self: '빵빵한빵디',
        localSelf: {
          'b': {'status': 'wanted', 'updated_at': '2026-02-01T00:00:00Z', 'updated_by': '빵빵한빵디', 'quantity': 1},
        },
      );
      for (final k in ['overrides', 'series_label_overrides', 'appearance', 'future_key', 'schema_version']) {
        expect(out[k], remote[k], reason: k);
      }
      final col = out['collection']! as Map;
      expect(col['custom_items'], (remote['collection']! as Map)['custom_items']);
      final members = col['member_items'] as Map;
      expect(members['곰돌'], ((remote['collection']! as Map)['member_items'] as Map)['곰돌']);
      expect(members.containsKey('member'), isFalse); // 나에게 합침
      expect(members.containsKey('냐아'), isFalse); // 버림
      expect((members['빵빵한빵디'] as Map).keys.toSet(), {'a', 'b', 'm'});
      expect((col['wanted'] as List).toSet(), {'b', 'm'});
      expect(col['owned'], ['a']);
    });

    test('같은 내용이면 samePayload (저장하지 않음)', () {
      final once = buildSyncPayload(remote: remote, self: '빵빵한빵디', localSelf: const {});
      final twice = buildSyncPayload(remote: once, self: '빵빵한빵디', localSelf: const {});
      expect(samePayload(once, twice), isTrue);
      expect(samePayload(once, remote), isFalse); // member · 냐아 정리가 한 번은 들어감
    });

    test('백업 파일에서 가져온 overrides 는 extrasDirty 일 때만 합친다', () {
      const local = {
        'overrides': {
          'kit-1': {'name_ko': '가져온 것', 'updated_at': '2026-03-01T00:00:00Z'},
        },
        'series_label_overrides': {'00': '더블오'},
      };
      final clean = buildSyncPayload(remote: remote, self: '빵빵한빵디', localSelf: const {}, localExtras: local);
      expect(clean['overrides'], remote['overrides']);
      final dirty = buildSyncPayload(
        remote: remote,
        self: '빵빵한빵디',
        localSelf: const {},
        localExtras: local,
        extrasDirty: true,
      );
      expect((dirty['overrides']! as Map).keys.toSet(), {'kit-9', 'kit-1'});
      expect(dirty['series_label_overrides'], {'seed': 'SEED 시리즈', '00': '더블오'});
      expect(dirty['appearance'], remote['appearance']);
    });

    test('mergeCloudPayload (40001 재시도용): remote 를 바탕으로 collection 만 합침', () {
      final local = buildSyncPayload(
        remote: remote,
        self: '빵빵한빵디',
        localSelf: {
          'b': {'status': 'wanted', 'updated_at': '2026-02-01T00:00:00Z'},
        },
      );
      final other = buildSyncPayload(
        remote: remote,
        self: '빵빵한빵디',
        localSelf: {
          'c': {'status': 'owned', 'updated_at': '2026-02-02T00:00:00Z'},
        },
      );
      final merged = mergeCloudPayload(local, other, CollectionOptions.forSelf('빵빵한빵디'));
      final mine = ((merged['collection']! as Map)['member_items'] as Map)['빵빵한빵디'] as Map;
      expect(mine.keys.toSet(), containsAll(['a', 'b', 'c']));
      expect((merged['collection']! as Map)['custom_items'], isNotEmpty);
      expect(merged['appearance'], remote['appearance']);
    });
  });
}
