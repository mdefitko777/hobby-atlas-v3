// 가짜 Gunpula Supabase — 진짜 서버에는 절대 닿지 않는다.
// v2 공유 공간(get_state · save_state) · v3 내 행(get_me · save_state 40001) · 친구 함수를
// docs/supabase-setup-v2.sql · v3.sql 과 같은 규칙으로 메모리에서 흉내 낸다. JSON 으로 한 번 오가게 해서
// 앱과 서버가 같은 Map 을 나눠 쓰는 일이 없게 한다.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hobby_atlas/sync/rpc.dart';

Object? roundTrip(Object? v) => v == null ? null : jsonDecode(jsonEncode(v));

class FakeAuth extends ChangeNotifier implements AuthService {
  FakeAuth({bool signedIn = false, this.email = 'me@example.com', this.code = '123456'}) : _signedIn = signedIn;

  bool _signedIn;
  @override
  String email;

  /// 맞는 코드
  final String code;
  final List<String> sentTo = [];

  @override
  bool get available => true;
  @override
  bool get ready => true;
  @override
  bool get signedIn => _signedIn;

  set signedIn(bool v) {
    _signedIn = v;
    notifyListeners();
  }

  @override
  Future<void> sendCode(String email) async => sentTo.add(email);

  @override
  Future<void> verifyCode(String email, String code) async {
    if (code.trim() != this.code) throw const AuthFailure('코드가 틀렸거나 시간이 지났어요. 새 코드를 받아 주세요');
    this.email = email;
    signedIn = true;
  }

  @override
  Future<void> signOut() async => signedIn = false;
}

class FakeServer implements RpcClient {
  FakeServer({
    Map<String, Object?>? v2Payload,
    this.selfName = '빵빵한빵디',
    List<Map<String, Object?>>? members,
    Map<String, Object?>? v3Payload,
    this.handle,
    this.displayName = '',
  }) : members = members ?? [],
       v2Payload = roundTrip(v2Payload) as Map<String, Object?>?,
       // v3 의 기본 행 (supabase-setup-v3.sql 의 default)
       v3Payload =
           roundTrip(
                 v3Payload ??
                     {
                       'schema_version': 1,
                       'collection': {'owned': [], 'wanted': [], 'items': {}, 'member_items': {}},
                       'overrides': {},
                       'series_label_overrides': {},
                     },
               )!
               as Map<String, Object?>;

  /// null = 공유 공간 없음 (get_state 가 null)
  Map<String, Object?>? v2Payload;
  int v2Revision = 3;
  String selfName;
  final List<Map<String, Object?>> members;
  bool canEdit = true;

  Map<String, Object?> v3Payload;
  int v3Revision = 7;
  String? handle;
  String displayName;

  /// 다른 기기가 v3 에 먼저 저장한 것처럼: v3 save_state 직전에 하나씩 꺼내 적용 (리비전 +1 → 40001)
  final List<void Function(Map<String, Object?> payload)> otherDeviceV3Writes = [];

  /// 이 이름들의 v3 함수는 "없음"(SQL 안 돌림)
  final Set<String> missing = {};
  bool offline = false;

  /// 세션이 죽어 anon 으로 부른 것처럼 (auth.uid() 가 null → 42501)
  bool authExpired = false;

  final List<({String fn, Map<String, Object?> params})> calls = [];

  // 친구
  final Map<String, ({String name, Map<String, Object?> collection})> users = {};
  final Set<String> friends = {};
  final Set<String> incoming = {};
  final Set<String> outgoing = {};

  int count(String fn) => calls.where((c) => c.fn == fn).length;
  List<Map<String, Object?>> paramsOf(String fn) => [
    for (final c in calls)
      if (c.fn == fn) c.params,
  ];

  Map<String, Object?> _profile(String h) => {'handle': h, 'name': users[h]?.name ?? h, 'avatar': ''};

  Map<String, Object?> _me() => {
    'handle': handle,
    'display_name': displayName,
    'avatar': '',
    'preferences': {},
    'payload': v3Payload,
    'revision': v3Revision,
    'updated_at': '2026-11-01T00:00:00Z',
    'friends': [for (final h in friends) _profile(h)],
    'incoming_requests': [for (final h in incoming) _profile(h)],
    'outgoing_requests': [for (final h in outgoing) _profile(h)],
  };

  Map<String, Object?>? _state() => v2Payload == null
      ? null
      : {
          'workspace_id': 'ws-1',
          'workspace_name': '우리집 컬렉션',
          'invite_code': 'ABC123',
          'payload': v2Payload,
          'revision': v2Revision,
          'updated_by': selfName,
          'updated_at': '2026-11-01T00:00:00Z',
          'can_edit': canEdit,
          'role': 'owner',
          'members': [
            {'name': selfName, 'email': 'me@example.com', 'role': 'owner', 'is_self': true},
            ...members,
          ],
        };

  @override
  Future<Object?> call(String fn, [Map<String, Object?> params = const {}]) async {
    final p = roundTrip(params)! as Map<String, Object?>;
    calls.add((fn: fn, params: p));
    await Future<void>.delayed(Duration.zero);
    if (offline) throw const OfflineException('인터넷에 연결되지 않았어요');
    if (authExpired) throw const RpcException('42501', 'gunpula not signed in');
    if (missing.contains(fn)) throw RpcException('PGRST202', 'Could not find the function public.$fn');
    switch (fn) {
      case 'gunpula_v2_get_state':
        return roundTrip(_state());
      case 'gunpula_v2_save_state':
        if (v2Payload == null) throw const RpcException('42501', 'gunpula no workspace');
        if (!canEdit) throw const RpcException('42501', 'gunpula read-only workspace access');
        v2Payload = p['p_payload']! as Map<String, Object?>;
        v2Revision++;
        return roundTrip(_state());
      case 'gunpula_v3_get_me':
        return roundTrip(_me());
      case 'gunpula_v3_save_state':
        if (otherDeviceV3Writes.isNotEmpty) {
          otherDeviceV3Writes.removeAt(0)(v3Payload);
          v3Revision++;
        }
        if (p['p_base_revision'] != v3Revision) {
          throw RpcException('40001', 'gunpula revision conflict (server $v3Revision, sent ${p['p_base_revision']})');
        }
        v3Payload = p['p_payload']! as Map<String, Object?>;
        v3Revision++;
        return roundTrip(_me());
      case 'gunpula_v3_claim_handle':
        final h = '${p['p_handle']}';
        if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(h)) {
          throw const RpcException('22023', 'gunpula handle must be 3-20 chars of a-z 0-9 _');
        }
        if (users.containsKey(h)) throw const RpcException('23505', 'gunpula handle taken');
        handle = h;
        return roundTrip(_me());
      case 'gunpula_v3_update_profile':
        displayName = '${p['p_display_name'] ?? displayName}';
        return roundTrip(_me());
      case 'gunpula_v3_search_user':
        final h = '${p['p_handle']}';
        if (h == handle) return {..._profile(h), 'name': displayName.isEmpty ? h : displayName, 'relation': 'self'};
        if (!users.containsKey(h)) return null;
        final rel = friends.contains(h)
            ? 'friends'
            : outgoing.contains(h)
            ? 'outgoing'
            : incoming.contains(h)
            ? 'incoming'
            : 'none';
        return {..._profile(h), 'relation': rel};
      case 'gunpula_v3_request_friend':
        final h = '${p['p_handle']}';
        if (!users.containsKey(h)) throw const RpcException('22023', 'gunpula user not found');
        if (friends.contains(h)) throw const RpcException('23505', 'gunpula already friends');
        if (incoming.remove(h)) {
          friends.add(h);
        } else {
          outgoing.add(h);
        }
        return roundTrip(_me());
      case 'gunpula_v3_respond_friend':
        final h = '${p['p_handle']}';
        if (incoming.remove(h) && p['p_accept'] == true) friends.add(h);
        return roundTrip(_me());
      case 'gunpula_v3_remove_friend':
        final h = '${p['p_handle']}';
        friends.remove(h);
        outgoing.remove(h);
        incoming.remove(h);
        return roundTrip(_me());
      case 'gunpula_v3_get_friend_collection':
        final h = '${p['p_handle']}';
        final u = users[h];
        if (u == null) throw const RpcException('22023', 'gunpula user not found');
        if (!friends.contains(h)) throw const RpcException('42501', 'gunpula not friends');
        return roundTrip({..._profile(h), 'collection': u.collection, 'updated_at': '2026-10-31T09:00:00Z'});
    }
    throw RpcException('PGRST202', 'Could not find the function public.$fn');
  }
}
