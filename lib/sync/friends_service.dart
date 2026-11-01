// 친구 — Gunpula v3 (docs/supabase-setup-v3.sql). 내 아이디(@handle)로 찾고, 요청 → 수락하면 서로의 컬렉션을 읽기만 한다.
// 모든 함수는 get_me 결과(내 프로필 + 친구 + 받은/보낸 요청)를 돌려주므로 그걸 그대로 [me] 로 쓴다.
// 친구 컬렉션에는 collection 만 온다 (집 사진 · overrides 는 서버가 빼고 준다).
library;

import 'package:flutter/foundation.dart';

import 'rpc.dart';

class PublicProfile {
  const PublicProfile({required this.handle, required this.name, this.avatar = ''});

  final String handle;
  final String name;

  /// 옛 앱이 넣은 사진(data URL)일 수 있다 — 지금은 첫 글자만 보여 준다
  final String avatar;

  static PublicProfile? parse(Object? raw) {
    final m = _map(raw);
    final handle = _str(m['handle']);
    if (handle.isEmpty && _str(m['name']).isEmpty) return null;
    return PublicProfile(
      handle: handle,
      name: _str(m['name']).isEmpty ? handle : _str(m['name']),
      avatar: _str(m['avatar']),
    );
  }
}

/// gunpula_v3_get_me
class MeState {
  const MeState({
    required this.handle,
    required this.displayName,
    required this.avatar,
    required this.preferences,
    required this.revision,
    required this.payload,
    required this.friends,
    required this.incoming,
    required this.outgoing,
  });

  /// 아직 안 정했으면 ''
  final String handle;
  final String displayName;
  final String avatar;
  final Map<String, Object?> preferences;

  /// v3 내 행의 리비전 (save_state 의 p_base_revision)
  final int revision;
  final Map<String, Object?> payload;
  final List<PublicProfile> friends;
  final List<PublicProfile> incoming;
  final List<PublicProfile> outgoing;

  static MeState? parse(Object? raw) {
    if (raw is! Map) return null;
    final m = _map(raw);
    List<PublicProfile> people(String k) => [for (final x in _list(m[k])) ?PublicProfile.parse(x)];
    final rev = m['revision'];
    return MeState(
      handle: _str(m['handle']),
      displayName: _str(m['display_name']),
      avatar: _str(m['avatar']),
      preferences: _map(m['preferences']),
      revision: rev is num ? rev.toInt() : int.tryParse('$rev') ?? 0,
      payload: _map(m['payload']),
      friends: people('friends'),
      incoming: people('incoming_requests'),
      outgoing: people('outgoing_requests'),
    );
  }
}

/// search_user 결과. relation: self · friends · outgoing · incoming · none
class FriendSearch {
  const FriendSearch(this.profile, this.relation);
  final PublicProfile profile;
  final String relation;
}

/// get_friend_collection — 친구의 좋아요 · 구매함 (읽기 전용)
class FriendCollection {
  FriendCollection({required this.profile, required this.items, required this.updatedAt});

  final PublicProfile profile;

  /// kit_id → 기록 (status · updated_at …)
  final Map<String, Map<String, Object?>> items;
  final String updatedAt;

  List<String> _ids(String status) {
    final e = [
      for (final x in items.entries)
        if (x.value['status'] == status) x,
    ]..sort((a, b) => _str(b.value['updated_at']).compareTo(_str(a.value['updated_at'])));
    return [for (final x in e) x.key];
  }

  late final List<String> likedIds = _ids('wanted');
  late final List<String> ownedIds = _ids('owned');

  /// 옛 앱 openFriendProfile 과 같은 규칙: member_items[이름] → 없으면 items
  static FriendCollection parse(Object? raw, String fallbackHandle) {
    final m = _map(raw);
    final profile = PublicProfile.parse(m) ?? PublicProfile(handle: fallbackHandle, name: fallbackHandle);
    final col = _map(m['collection']);
    final byName = _map(col['member_items'])[profile.name];
    final src = byName is Map ? _map(byName) : _map(col['items']);
    return FriendCollection(
      profile: PublicProfile(
        handle: profile.handle.isEmpty ? fallbackHandle : profile.handle,
        name: profile.name,
        avatar: profile.avatar,
      ),
      items: {
        for (final e in src.entries)
          if (e.value is Map) e.key: _map(e.value),
      },
      updatedAt: _str(m['updated_at']),
    );
  }
}

class FriendsService extends ChangeNotifier {
  FriendsService(this._rpc);

  final RpcClient Function() _rpc;

  MeState? me;

  /// 서버에 v3 함수가 없음 (Gunpula 의 supabase-setup-v3.sql 을 안 돌림)
  bool unavailable = false;

  /// 친구 컬렉션 (handle → 마지막으로 받은 것)
  final Map<String, FriendCollection> collections = {};

  List<PublicProfile> get friends => me?.friends ?? const [];
  List<PublicProfile> get incoming => me?.incoming ?? const [];
  List<PublicProfile> get outgoing => me?.outgoing ?? const [];

  /// get_me · 친구 함수의 결과를 받아 들인다 (동기화도 부른다)
  void applyMe(Object? raw) {
    final m = MeState.parse(raw);
    if (m == null) return;
    me = m;
    unavailable = false;
    final keep = {for (final f in m.friends) f.handle};
    collections.removeWhere((h, _) => !keep.contains(h));
    notifyListeners();
  }

  void clear() {
    me = null;
    collections.clear();
    unavailable = false;
    notifyListeners();
  }

  Future<MeState?> _act(String fn, [Map<String, Object?> params = const {}]) async {
    try {
      applyMe(await _rpc()(fn, params));
      return me;
    } on RpcException catch (e) {
      if (e.isMissingFunction) {
        unavailable = true;
        notifyListeners();
      }
      throw FriendsFailure(friendlyError(e));
    } on OfflineException catch (e) {
      throw FriendsFailure(e.message);
    }
  }

  Future<MeState?> refresh() => _act('gunpula_v3_get_me');

  /// 아이디 정하기 · 바꾸기 (영문 소문자 · 숫자 · _ 3–20자)
  Future<void> claimHandle(String handle) {
    final h = normalizeHandle(handle);
    if (!validHandle(h)) return Future.error(const FriendsFailure('아이디는 영문 소문자 · 숫자 · _ 로 3–20자예요'));
    return _act('gunpula_v3_claim_handle', {'p_handle': h});
  }

  /// 친구에게 보이는 이름
  Future<void> setDisplayName(String name) {
    final n = name.trim();
    if (n.isEmpty) return Future.error(const FriendsFailure('이름을 적어 주세요'));
    return _act('gunpula_v3_update_profile', {'p_display_name': n.length > 40 ? n.substring(0, 40) : n});
  }

  /// 아이디로 찾기 (정확히 같은 아이디만) — 없으면 null
  Future<FriendSearch?> search(String handle) async {
    final h = normalizeHandle(handle);
    if (!validHandle(h)) throw const FriendsFailure('아이디는 영문 소문자 · 숫자 · _ 로 3–20자예요');
    try {
      final r = await _rpc()('gunpula_v3_search_user', {'p_handle': h});
      final p = PublicProfile.parse(r);
      if (p == null) return null;
      return FriendSearch(p, _str(_map(r)['relation']));
    } on RpcException catch (e) {
      throw FriendsFailure(friendlyError(e));
    } on OfflineException catch (e) {
      throw FriendsFailure(e.message);
    }
  }

  Future<void> request(String handle) => _act('gunpula_v3_request_friend', {'p_handle': normalizeHandle(handle)});

  Future<void> respond(String handle, {required bool accept}) =>
      _act('gunpula_v3_respond_friend', {'p_handle': normalizeHandle(handle), 'p_accept': accept});

  /// 친구 끊기 · 보낸 요청 취소 (어느 쪽에서든)
  Future<void> remove(String handle) async {
    await _act('gunpula_v3_remove_friend', {'p_handle': normalizeHandle(handle)});
    collections.remove(normalizeHandle(handle));
  }

  /// 친구의 컬렉션 — [force] 가 아니면 받아 둔 것
  Future<FriendCollection> collection(String handle, {bool force = false}) async {
    final h = normalizeHandle(handle);
    final cached = collections[h];
    if (cached != null && !force) return cached;
    try {
      final c = FriendCollection.parse(await _rpc()('gunpula_v3_get_friend_collection', {'p_handle': h}), h);
      collections[h] = c;
      notifyListeners();
      return c;
    } on RpcException catch (e) {
      throw FriendsFailure(friendlyError(e));
    } on OfflineException catch (e) {
      throw FriendsFailure(e.message);
    }
  }

  /// 친구 서랍 숫자용 — 실패한 친구는 건너뛴다
  Future<void> loadAllCollections({bool force = false}) async {
    for (final f in friends) {
      if (f.handle.isEmpty) continue;
      try {
        await collection(f.handle, force: force);
      } on FriendsFailure {
        // 한 명 실패해도 나머지는 보여 준다
      }
    }
  }
}

class FriendsFailure implements Exception {
  const FriendsFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

String normalizeHandle(String h) {
  final t = h.trim().toLowerCase();
  return t.startsWith('@') ? t.substring(1) : t;
}

bool validHandle(String h) => RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(h);

/// v3 SQL 의 오류 문장 → 한국어
String friendlyError(RpcException e) {
  final m = e.message.toLowerCase();
  if (e.isMissingFunction) return '서버에 친구 기능(Gunpula v3 SQL)이 아직 없어요';
  if (m.contains('handle taken')) return '이미 누가 쓰는 아이디예요';
  if (m.contains('handle must be')) return '아이디는 영문 소문자 · 숫자 · _ 로 3–20자예요';
  if (m.contains('user not found')) return '그 아이디를 찾지 못했어요';
  if (m.contains('cannot add yourself')) return '나 자신은 친구로 추가할 수 없어요';
  if (m.contains('already friends')) return '이미 친구예요';
  if (m.contains('not friends')) return '친구가 아니라서 볼 수 없어요';
  if (m.contains('not signed in') || e.isAuth) return '로그인이 필요해요';
  return e.message;
}

String _str(Object? v) => v is String ? v : '';
Map<String, Object?> _map(Object? v) =>
    v is Map<String, Object?> ? v : (v is Map ? {for (final e in v.entries) '${e.key}': e.value} : const {});
List<Object?> _list(Object? v) => v is List ? v : const [];
