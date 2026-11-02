// 기기 저장 파일(user.json) · 백업 가져오기의 모양을 글자 그대로 고정한다.
// UserStore 를 나눠도(lib/data/user_store*.dart) 읽고 → 쓰고 → 가져온 결과가 바뀌면 안 된다.
// 기대값은 test/fixtures/user_store.*.golden.json — 모양을 일부러 바꿀 때만
//   flutter test test/user_store_golden_test.dart --dart-define=UPDATE_GOLDEN=true
// 로 다시 만든다.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/data/user_store.dart';

const _update = bool.fromEnvironment('UPDATE_GOLDEN');

/// 모든 키를 채운 저장 파일 (모르는 값 · 옛 모양 · 버릴 값도 섞었다)
final Map<String, Object?> _input = {
  'schema': 1,
  'member': '냥이',
  'collection': {
    'items': {
      'hg-001': {
        'status': 'owned',
        'quantity': 2,
        'updated_at': '2026-10-01T00:00:00.000Z',
        'updated_by': '냥이',
        'purchase_price': 2500,
        'storage': '선반',
        'note': '메모',
      },
      'hg-002': {'status': 'wanted', 'updated_at': '2026-10-02T00:00:00.000Z'},
      'hg-003': {'status': 'deleted', 'updated_at': '2026-10-03T00:00:00.000Z', 'updated_by': 'x'},
      'bad-1': {'status': 'weird'},
    },
  },
  'payload_extra': {
    'overrides': {
      'hg-001': {'name': '이름'},
    },
    'appearance': {'bg': 'data:…'},
    'custom_items': {
      'private-1': {'name': '비공개'},
    },
    'unknown_key': [1, 2, 3],
  },
  'collection_extra': {'member_note': 'keep'},
  'sync': {'dirty': true, 'extras_dirty': true, 'account': 'user-123'},
  'local_state': {
    'bbx_owned_parts': ['p1', 'p2'],
    'bbx_manual_map': {'kit-a': 'BX-01', 'kit-b': 7},
    'guide_manual_lit': [11, '12', 'x'],
    'recent_viewed': ['hg-001', 'hg-002'],
    'bbx_combos': [
      {
        'id': 'c1',
        'arch': 'standard',
        'parts': {'blade': 'b1', 'ratchet': 'r1', 'bit': 'f1'},
        'nickname': '내 드랜',
        'favorite': true,
        'rating': 4,
        'tags': ['공격'],
        'notes': '메모',
        'source': 'custom',
        'created_at': '2026-09-01T00:00:00.000Z',
        'updated_at': '2026-09-02T00:00:00.000Z',
      },
      {'id': 'bad'},
    ],
    'bbx_decks': [
      {
        'id': 'd1',
        'name': '덱',
        'rules_profile': 'wbo',
        'combo_ids': ['c1'],
      },
    ],
    'tag_owned': ['mz-intl:1-1-001@KR', 'frienda:1-1-001'],
    'tag_liked': ['mz-intl:1-1-002@KR'],
    'my_channels': ['gundam', 'pokemon'],
    'special_friends': ['@bro'],
    'profile_images': {
      'avatar': {'file': 'a1.jpg', 'at': '2026-10-01T00:00:00.000Z', 'uploaded_to': 'user-123'},
      'cover': {'file': '../bad.jpg', 'at': 'x'},
    },
    'photo_privacy': {
      'public': false,
      'hidden_from': ['@aunt'],
      'dirty': true,
    },
    'dismissed_suggestions': ['@x'],
    'friends_seen_at': '2026-10-20T00:00:00.000Z',
    'friend_avatars': {'@bro': 'f1.jpg', '@bad': 'a/b.jpg'},
    'photos': [
      {
        'id': 'p1',
        'file': 'p1.jpg',
        'created_at': '2026-10-05T00:00:00.000Z',
        'kit_id': 'hg-001',
        'unit_id': '42',
        'shared': false,
        'watermark': false,
        'uploaded_to': 'user-123',
        'deleted': true,
      },
      {'id': 'p2', 'file': 'p2.jpg', 'created_at': '2026-10-06T00:00:00.000Z'},
      {'id': 'p3', 'file': 'x/p3.jpg'},
    ],
    'profile_tags': ['HG', '포켓몬'],
    'recent_searches': ['엑시아', '드랜'],
    'search_counts': {'엑시아': 3, '드랜': 1, 'bad': 'x'},
    'trash': {
      'hg-004': {'from': 'owned', 'at': '2099-01-01T00:00:00.000Z'},
      'hg-005': {'from': 'wanted', 'at': '2099-01-02T00:00:00.000Z'},
      'hg-006': {'from': 'other', 'at': '2099-01-02T00:00:00.000Z'},
      'hg-007': {'from': 'owned', 'at': '2000-01-01T00:00:00.000Z'},
    },
  },
};

String _pretty(Object? j) => const JsonEncoder.withIndent('  ').convert(j);

void _golden(String name, Object? actual) {
  final f = File('test/fixtures/user_store.$name.golden.json');
  final text = '${_pretty(actual)}\n';
  if (_update) f.writeAsStringSync(text);
  // git 이 줄 끝을 CRLF 로 바꿔 꺼내도 같게 본다
  expect(text, f.readAsStringSync().replaceAll('\r\n', '\n'), reason: '$name 모양이 바뀌었다');
}

void main() {
  test('user.json 읽기 → 쓰기 모양이 글자 그대로 같다', () {
    final s = UserStore.memory()..debugLoadJson(_input);
    _golden('load', s.toJson());
    // 한 번 더 돌려도 같다 (쓴 것을 다시 읽으면 그대로)
    final again = UserStore.memory()..debugLoadJson(jsonDecode(jsonEncode(s.toJson())));
    expect(_pretty(again.toJson()), _pretty(s.toJson()));
  });

  test('백업 파일 가져오기 결과 모양이 같다', () {
    final src = UserStore.memory()..debugLoadJson(_input);
    final p = ImportPreview.parse(jsonEncode(src.toJson()), (id) => id != 'hg-003');
    expect(
      [p.member, p.owned, p.wanted, p.deleted, p.unknown, p.otherMembers, p.myChannels, p.isEmpty],
      [
        '',
        1,
        1,
        1,
        0,
        <String, int>{},
        ['gundam', 'pokemon'],
        false,
      ],
    );
    final dst = UserStore.memory()..applyImport(p);
    final j = dst.toJson();
    // 가져오기는 기기 계정 · 친구 쪽 · 사진을 옮기지 않는다 (member 도: 내 백업에는 member_items 가 없다)
    _golden('import', j);
  });

  test('백업 파일 = 저장 파일 + 내보낸 때 · 앱 이름, 가져오면 저장 파일로 가져온 것과 같다', () {
    final s = UserStore.memory()..debugLoadJson(_input);
    final b = s.backupFile(DateTime.utc(2026, 11, 2, 9));
    expect(b.fileName, startsWith('hobby-atlas-backup-2026-11-0'));
    final j = jsonDecode(b.text) as Map<String, Object?>;
    expect(j['exported_at'], '2026-11-02T09:00:00.000Z');
    expect(j['app'], 'hobby-atlas-v3');
    expect(
      _pretty(
        {...j}
          ..remove('exported_at')
          ..remove('app'),
      ),
      _pretty(s.toJson()),
    );
    final viaBackup = UserStore.memory()..applyImport(ImportPreview.parse(b.text, (id) => id != 'hg-003'));
    final viaFile = UserStore.memory()
      ..applyImport(ImportPreview.parse(jsonEncode(s.toJson()), (id) => id != 'hg-003'));
    expect(_pretty(viaBackup.toJson()), _pretty(viaFile.toJson()));
  });
}
