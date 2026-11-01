// 내 수집 기록 — 기기에 저장, 옛 Gunpula 앱(app/collection-store.js)과 같은 모양.
//   items[kit_id] = {status: owned|wanted|deleted, updated_at, updated_by, quantity 1–99, note?, storage?, purchase_price?}
// 지운 것도 'deleted' 로 남겨 둔다 (나중에 동기화할 때 "지웠다"가 이기도록).
// 로그인하면 lib/sync/sync_service.dart 가 이 기록을 옛 앱과 같은 Supabase payload 에 합쳐 올린다:
//   · 공유되는 것 = 구매함 · 좋아요(내 버킷) — 바꾸면 sharedRevision +1, cloudDirty = true
//   · 이 기기에만 = 베이 부품 · 베이 연결 · 도감 손으로 켜기 · 최근 본 것 · 내 사진 목록 · 취향 태그 (payload 에 넣지 않음)
//     (내 사진 중 친구에게 보이기를 켠 것은 lib/sync/photo_share.dart 가 Storage 에, 태그는 v3 preferences.tags 에 따로 올린다)
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../channels.dart' show defaultMyChannels;
import '../models.dart';
import '../sync/collection_merge.dart' show collectionStatuses, normalizeCollectionEntry;
import 'blob_store.dart';
import 'photo_files.dart';
import '../json_util.dart';

class UserStore extends ChangeNotifier {
  UserStore._() : persist = true;

  /// 테스트용: 파일에 쓰지 않는다
  UserStore.memory() : persist = false;

  static final instance = UserStore._();

  final bool persist;

  static const _key = 'user.json';

  /// updated_by 에 들어가는 내 이름 (옛 앱의 멤버 이름을 가져오면 그것)
  String member = 'member';

  final Map<String, Map<String, Object?>> _items = {};

  /// 옛 payload 에서 그대로 보관만 하는 값 (overrides · series_label_overrides …, appearance 는 빼고)
  Map<String, Object?> payloadExtra = {};

  /// payload.collection 의 기본 4키 말고 나머지 (custom_items …) — 그대로 보관만
  Map<String, Object?> collectionExtra = {};

  /// 아직 서버에 올리지 않은 내 기록 변경이 있음 (오프라인 · 실패 → 다음 동기화 때 다시)
  bool cloudDirty = false;

  /// 백업 파일에서 가져온 overrides 등이 아직 안 올라감 → 다음 저장 때만 서버 값과 합친다
  bool extrasDirty = false;

  /// 공유되는 기록(구매함 · 좋아요)을 내가 바꿀 때마다 +1 (서버에서 받은 것은 세지 않음)
  int sharedRevision = 0;

  /// 이 기기의 구매함 · 좋아요가 어느 계정 것인지 (Supabase user id, 아직 로그인한 적 없으면 '').
  /// 다른 계정으로 로그인하면 앞 계정의 기록을 새 계정에 올리지 않도록 동기화가 본다.
  String syncedAccount = '';

  // 옛 앱에서 기기에만 있던 값 (백업 · 클라우드에 없음)
  final Set<String> bbxOwnedParts = {};
  final Map<String, String> bbxManualMap = {};
  final Set<int> guideManualLit = {};
  final List<String> recentViewed = [];

  /// 내 채널 (채널 바 · 알림 범위). 처음 설치하면 건담 · 베이블레이드 · 포켓몬
  final List<String> myChannels = [...defaultMyChannels];

  /// 특별 관심 친구 (@아이디) — My Page ★ 에 이 사람들 소식만. 기기에만
  final Set<String> specialFriends = {};

  /// 내 사진 (사진 벽 · 도감 칸 · 상품 상세). 지운 것도 서버에서 내릴 때까지 [MyPhoto.deleted] 로 남는다
  final List<MyPhoto> _photos = [];

  /// 내 취향 태그 (내 정보 머리) — 로그인하면 v3 preferences.tags 에도
  final List<String> profileTags = [];

  /// 바뀔 때마다 +1 (Marks 가 다시 그릴지 판단)
  int revision = 0;
  Future<void>? _loading;
  Timer? _saveTimer;

  /// 파일에서 읽기 — 여러 번 불러도 한 번만 읽고, 읽는 중이면 끝날 때까지 기다린다 (동기화가 먼저 덮어쓰지 않게)
  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    if (!persist) return;
    final text = await BlobStore.read(_key);
    if (text == null) return;
    try {
      _fromJson(jsonDecode(text));
      revision++;
      notifyListeners();
    } on FormatException {
      // 깨진 파일 — 덮어쓰지 않게 다른 이름으로 남겨 둔다
      await BlobStore.write('user.broken.json', text);
    }
  }

  void _fromJson(Object? json) {
    final j = jMap(json);
    member = jStr(j['member']).isEmpty ? 'member' : jStr(j['member']);
    _items
      ..clear()
      ..addAll({for (final e in jMap(jMap(j['collection'])['items']).entries) e.key: ?normalizeEntry(e.value, member)});
    payloadExtra = Map.of(jMap(j['payload_extra']))..remove('appearance');
    collectionExtra = Map.of(jMap(j['collection_extra']));
    // 예전 파일: custom_items 를 payload_extra 에 두었다 → collection 쪽으로
    if (payloadExtra.remove('custom_items') case final Object c) collectionExtra.putIfAbsent('custom_items', () => c);
    final sync = jMap(j['sync']);
    cloudDirty = sync['dirty'] == true;
    extrasDirty = sync['extras_dirty'] == true;
    syncedAccount = jStr(sync['account']);
    final local = jMap(j['local_state']);
    bbxOwnedParts
      ..clear()
      ..addAll(jList(local['bbx_owned_parts']).whereType<String>());
    bbxManualMap
      ..clear()
      ..addAll({for (final e in jMap(local['bbx_manual_map']).entries) e.key: '${e.value}'});
    guideManualLit
      ..clear()
      ..addAll(jList(local['guide_manual_lit']).map((v) => v is num ? v.toInt() : int.tryParse('$v')).nonNulls);
    recentViewed
      ..clear()
      ..addAll(jList(local['recent_viewed']).whereType<String>());
    // 키가 없으면(옛 파일) 처음 값. 빈 목록은 "채널 없음"으로 그대로 둔다.
    myChannels
      ..clear()
      ..addAll(local['my_channels'] is List ? jList(local['my_channels']).whereType<String>() : defaultMyChannels);
    specialFriends
      ..clear()
      ..addAll(jList(local['special_friends']).whereType<String>());
    _photos
      ..clear()
      ..addAll(jList(local['photos']).map(MyPhoto.fromJson).nonNulls);
    profileTags
      ..clear()
      ..addAll(jList(local['profile_tags']).whereType<String>());
  }

  Map<String, Object?> toJson() => {
    'schema': 1,
    'member': member,
    'collection': {'items': _items},
    'payload_extra': payloadExtra,
    'collection_extra': collectionExtra,
    'sync': {'dirty': cloudDirty, 'extras_dirty': extrasDirty, 'account': syncedAccount},
    'local_state': {
      'bbx_owned_parts': bbxOwnedParts.toList(),
      'bbx_manual_map': bbxManualMap,
      'guide_manual_lit': guideManualLit.toList(),
      'recent_viewed': recentViewed,
      'my_channels': myChannels,
      'special_friends': specialFriends.toList(),
      'photos': [for (final p in _photos) p.toJson()],
      'profile_tags': profileTags,
    },
  };

  /// [shared] = 구매함 · 좋아요처럼 서버에 올라가야 하는 변경
  void _changed({bool shared = false}) {
    revision++;
    if (shared) {
      sharedRevision++;
      cloudDirty = true;
    }
    notifyListeners();
    _persistSoon();
  }

  void _persistSoon() {
    if (!persist) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), () => BlobStore.write(_key, jsonEncode(toJson())));
  }

  // ── 읽기 ──
  Map<String, Object?>? entry(String kitId) => _items[kitId];

  /// 내 버킷 전체 (읽기 전용) — 동기화가 서버 payload 와 합칠 때
  Map<String, Map<String, Object?>> get items => Map.unmodifiable(_items);

  /// 기록이 없으면 null (가짜 데이터 테스트에서는 상품의 status 를 그대로 쓴다)
  CollectStatus? statusOf(String kitId) => switch (_items[kitId]?['status']) {
    'owned' => CollectStatus.owned,
    'wanted' => CollectStatus.wanted,
    'deleted' => CollectStatus.none,
    _ => null,
  };

  /// 좋아요 · 구매함 id — 최근에 바꾼 것부터
  List<String> idsWith(Set<CollectStatus> statuses) {
    final e = [
      for (final x in _items.entries)
        if (statuses.contains(statusOf(x.key))) x,
    ]..sort((a, b) => jStr(b.value['updated_at']).compareTo(jStr(a.value['updated_at'])));
    return [for (final x in e) x.key];
  }

  int get ownedCount => idsWith(const {CollectStatus.owned}).length;
  int get wantedCount => idsWith(const {CollectStatus.wanted}).length;

  /// 구매가를 안 적은 상품의 값 (Catalog 가 정가 × 환율로 채운다)
  int? Function(String id)? listPrice;

  int _paid(String id, Map<String, Object?> e) => switch (e['purchase_price']) {
    final num p => p.toInt(),
    _ => listPrice?.call(id) ?? 0,
  };

  /// 구매함 지출 합 (원) — 적어 둔 구매가, 없으면 정가 × 환율
  int get spendKrw => _items.entries.fold(0, (s, e) => e.value['status'] == 'owned' ? s + _paid(e.key, e.value) : s);

  /// 이번 달 지출 — 산 날짜를 따로 적지 않아, 구매함 기록을 마지막으로 바꾼 달로 센다
  int spendInMonth(DateTime now) {
    final prefix = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    return _items.entries.fold(0, (s, e) {
      final at = DateTime.tryParse(jStr(e.value['updated_at']))?.toLocal().toIso8601String() ?? '';
      return e.value['status'] == 'owned' && at.startsWith(prefix) ? s + _paid(e.key, e.value) : s;
    });
  }

  // ── 쓰기 ──
  String _now() => DateTime.now().toUtc().toIso8601String();

  /// 한 상품에 상태는 하나: 좋아요(wanted) · 구매함(owned) · 없음(deleted 로 남김)
  void setStatus(String kitId, CollectStatus s) {
    final old = _items[kitId];
    if (s == CollectStatus.none && old == null) return;
    _items[kitId] = {
      ...?old,
      'status': switch (s) {
        CollectStatus.owned => 'owned',
        CollectStatus.wanted => 'wanted',
        CollectStatus.none => 'deleted',
      },
      'updated_at': _now(),
      'updated_by': member,
      'quantity': old?['quantity'] ?? 1,
    };
    _changed(shared: true);
  }

  /// Gunpula 가 합친 상품: 옛 id 의 기록을 남은 id 로 옮기고, 옛 id 는 '지움'으로 남긴다 (동기화 때 되살아나지 않게)
  void applyAliases(Map<String, String> aliases) {
    var moved = false;
    for (final e in aliases.entries) {
      final old = _items[e.key];
      if (old == null || old['status'] == 'deleted' || e.key == e.value) continue;
      final cur = _items[e.value];
      if (cur == null || jStr(cur['updated_at']).compareTo(jStr(old['updated_at'])) < 0) _items[e.value] = {...old};
      _items[e.key] = {...old, 'status': 'deleted', 'updated_at': _now(), 'updated_by': member};
      moved = true;
    }
    if (moved) _changed(shared: true);
  }

  /// 수량 · 산 값 · 보관 장소 · 메모 (null 이면 지움)
  void setDetails(String kitId, {int? quantity, int? purchasePrice, String? storage, String? note}) {
    final old = _items[kitId];
    if (old == null) return;
    final next = {...old, 'updated_at': _now(), 'updated_by': member};
    if (quantity != null) next['quantity'] = quantity.clamp(1, 99);
    void put(String k, Object? v) => (v == null || v == '') ? next.remove(k) : next[k] = v;
    put('purchase_price', purchasePrice);
    put('storage', storage);
    put('note', note);
    _items[kitId] = next;
    _changed(shared: true);
  }

  void markViewed(String kitId) {
    recentViewed
      ..remove(kitId)
      ..insert(0, kitId);
    if (recentViewed.length > 40) recentViewed.removeRange(40, recentViewed.length);
    _changed();
  }

  void setSpecialFriend(String handle, bool on) {
    if (on ? specialFriends.add(handle) : specialFriends.remove(handle)) _changed();
  }

  // ── 내 사진 · 태그 ──
  /// 보이는 내 사진 — 새것부터
  List<MyPhoto> get photos => [
    for (final p in _photos)
      if (!p.deleted) p,
  ];

  /// 지운 것까지 (서버에서 내릴 것 찾기 — 사진 공유만 본다)
  List<MyPhoto> get allPhotos => List.unmodifiable(_photos);

  MyPhoto? photo(String id) => _photos.where((p) => p.id == id).firstOrNull;

  void addPhoto(MyPhoto p) {
    _photos.insert(0, p);
    _changed();
  }

  /// 같은 id 를 바꿔 끼운다 (친구에게 보이기 · 워터마크 · 상품 잇기 · 올림 표시)
  void updatePhoto(MyPhoto p) {
    final i = _photos.indexWhere((x) => x.id == p.id);
    if (i < 0) return;
    _photos[i] = p;
    _changed();
  }

  /// 지우기 — 서버에 올라가 있으면 내릴 때까지 '지움'으로 남긴다
  void removePhoto(String id) {
    final p = photo(id);
    if (p == null) return;
    if (p.uploadedTo.isEmpty) {
      _photos.remove(p);
      _changed();
    } else {
      updatePhoto(p.copyWith(deleted: true));
    }
  }

  /// 서버에서 내렸다 → 목록에서 뺀다
  void purgePhoto(String id) {
    final before = _photos.length;
    _photos.removeWhere((p) => p.id == id);
    if (_photos.length != before) _changed();
  }

  void setProfileTags(List<String> tags) {
    if (listEquals(tags, profileTags)) return;
    profileTags
      ..clear()
      ..addAll(tags);
    _changed();
  }

  void setMyChannels(List<String> ids) {
    if (listEquals(ids, myChannels)) return;
    myChannels
      ..clear()
      ..addAll(ids);
    _changed();
  }

  void setBbxPart(String partId, bool have) {
    if (have ? bbxOwnedParts.add(partId) : bbxOwnedParts.remove(partId)) _changed();
  }

  void setManualLit(int unitId, bool lit) {
    if (lit ? guideManualLit.add(unitId) : guideManualLit.remove(unitId)) _changed();
  }

  // ── 옛 Gunpula 에서 가져오기 ──
  /// [knownKit] = 지금 카탈로그에 있는 kit_id 인지 (없는 것은 "찾을 수 없음"으로 센다)
  ImportPreview previewImport(String text, bool Function(String kitId) knownKit) => ImportPreview.parse(text, knownKit);

  /// 같은 상품은 updated_at 이 더 새것이 이긴다 (옛 앱 mergeCollectionState 와 같음)
  void applyImport(ImportPreview p) {
    if (p.member.isNotEmpty) member = p.member;
    for (final e in p.items.entries) {
      final mine = _items[e.key];
      if (mine == null || jStr(e.value['updated_at']).compareTo(jStr(mine['updated_at'])) > 0) {
        _items[e.key] = e.value;
      }
    }
    if (p.payloadExtra.isNotEmpty || p.collectionExtra.isNotEmpty) {
      payloadExtra = {...payloadExtra, ...p.payloadExtra}..remove('appearance');
      collectionExtra = {...collectionExtra, ...p.collectionExtra};
      extrasDirty = true;
    }
    bbxOwnedParts.addAll(p.bbxOwnedParts);
    bbxManualMap.addAll(p.bbxManualMap);
    guideManualLit.addAll(p.guideManualLit);
    for (final id in p.recentViewed.reversed) {
      if (!recentViewed.contains(id)) recentViewed.insert(0, id);
    }
    if (p.myChannels case final ch? when ch.isNotEmpty) {
      myChannels
        ..clear()
        ..addAll(ch);
    }
    _changed(shared: p.items.isNotEmpty || extrasDirty);
  }

  // ── 동기화 (lib/sync/sync_service.dart 만 부른다) ──
  /// 서버와 합친 결과를 받아 들인다. 내가 바꾼 것으로 세지 않는다 (다시 올리지 않게).
  void applyCloud({
    required String member,
    required Map<String, Map<String, Object?>> selfItems,
    required Map<String, Object?> payloadExtra,
    required Map<String, Object?> collectionExtra,
  }) {
    this.member = member.trim().isEmpty ? this.member : member.trim();
    _items
      ..clear()
      ..addAll({for (final e in selfItems.entries) e.key: ?normalizeEntry(e.value, this.member)});
    this.payloadExtra = Map.of(payloadExtra)
      ..remove('collection')
      ..remove('appearance'); // 집 사진(data URL) 같은 큰 값은 기기에 두지 않는다 — 저장 때마다 서버 것을 그대로 쓴다
    this.collectionExtra = Map.of(collectionExtra);
    revision++;
    notifyListeners();
    _persistSoon();
  }

  /// 처음 로그인한 계정 — 로그인 전에 기기에서 모은 기록은 이 계정 것으로 본다
  void bindAccount(String accountId) {
    if (syncedAccount == accountId) return;
    syncedAccount = accountId;
    _persistSoon();
  }

  /// 다른 계정으로 로그인했다 → 앞 계정의 구매함 · 좋아요(와 아직 못 올린 변경)는 새 계정에 섞지 않는다.
  /// 앞 계정 것은 서버의 그 계정에 그대로 있다. 베이 부품 · 도감 손으로 켜기 · 최근 본 것(기기에만)은 둔다.
  void resetForAccount(String accountId) {
    syncedAccount = accountId;
    member = 'member';
    _items.clear();
    payloadExtra = {};
    collectionExtra = {};
    cloudDirty = false;
    extrasDirty = false;
    revision++; // sharedRevision 은 그대로 — "내가 바꾼 것"이 아니라 다시 올리지 않는다
    notifyListeners();
    _persistSoon();
  }

  /// [atSharedRevision] 까지의 변경이 서버에 올라갔다. 그 뒤에 또 바꿨으면 dirty 는 그대로.
  void markSynced(int atSharedRevision) {
    if (sharedRevision != atSharedRevision) return;
    if (!cloudDirty && !extrasDirty) return;
    cloudDirty = false;
    extrasDirty = false;
    _persistSoon();
  }
}

/// 옛 항목 하나 → 정리된 모양 (collection-store.js normalizeCollectionEntry 그대로 — lib/sync/collection_merge.dart).
/// 상태가 owned · wanted · deleted 가 아니면 null (버림)
Map<String, Object?>? normalizeEntry(Object? raw, String member) {
  final status = jMap(raw)['status'];
  if (status is! String || !collectionStatuses.contains(status)) return null;
  return normalizeCollectionEntry(raw, member: member);
}

/// 가져오기 전에 보여 줄 숫자 + 실제로 넣을 값.
/// 받는 모양 3가지:
///  1) 옛 앱 설정 › 데이터 › 수집 백업 내보내기: {collection, overrides, series_label_overrides, appearance, github_token?}
///  2) chrome://inspect 에서 뽑은 localStorage: `{local_storage: {'gunpula-…-v1': '<JSON 글자>'}}`
///  3) 1) + local_state {bbx_owned_parts, bbx_manual_map, guide_manual_lit, recent_viewed}
/// github_token · 로그인 세션 · 동기화 비밀값은 읽지 않는다.
class ImportPreview {
  ImportPreview._();

  String member = '';
  final Map<String, Map<String, Object?>> items = {};
  final Map<String, Object?> payloadExtra = {};

  /// collection.custom_items 등 (비공개 위시 — 보관만)
  final Map<String, Object?> collectionExtra = {};
  final Set<String> bbxOwnedParts = {};
  final Map<String, String> bbxManualMap = {};
  final Set<int> guideManualLit = {};
  final List<String> recentViewed = [];

  /// Hobby Atlas 자신의 백업에만 있다 (옛 Gunpula 에는 채널이 없음)
  List<String>? myChannels;
  int owned = 0, wanted = 0, deleted = 0, unknown = 0;

  /// 다른 멤버(공유 공간) 버킷 — 가져오지 않고 숫자만 알려 준다
  final Map<String, int> otherMembers = {};

  bool get isEmpty =>
      items.isEmpty && bbxOwnedParts.isEmpty && bbxManualMap.isEmpty && guideManualLit.isEmpty && recentViewed.isEmpty;

  static ImportPreview parse(String text, bool Function(String kitId) knownKit) {
    final p = ImportPreview._();
    final Object? root;
    try {
      root = jsonDecode(text.trim());
    } on FormatException {
      throw const FormatException('JSON 이 아니에요. 옛 앱에서 내보낸 파일 그대로인지 확인해 주세요.');
    }
    var j = jMap(root);
    final ls = jMap(j['local_storage']);
    if (ls.isNotEmpty) {
      Object? sub(String k) {
        final v = ls[k];
        if (v is! String) return v;
        try {
          return jsonDecode(v);
        } on FormatException {
          return null;
        }
      }

      j = {
        'collection': sub('gunpula-catalog-collection-v1'),
        'overrides': sub('gunpula-catalog-overrides-v1'),
        'series_label_overrides': sub('gunpula-catalog-series-labels-v1'),
        'local_state': {
          'bbx_owned_parts': sub('gunpula-bbx-owned-parts-v1'),
          'bbx_manual_map': sub('gunpula-bbx-manual-map-v1'),
          'guide_manual_lit': sub('gunpula-guide-manual-lit-v1'),
          'recent_viewed': sub('gunpula-catalog-recent-viewed-v1'),
        },
      };
    }

    final col = jMap(j['collection']);
    final memberItems = jMap(col['member_items']);
    var own = jMap(col['items']);
    // 내 버킷 이름 = items 와 같은 내용을 가진 member_items 키
    for (final e in memberItems.entries) {
      final m = jMap(e.value);
      if (own.isNotEmpty && m.length == own.length && m.keys.every(own.containsKey)) {
        p.member = e.key;
      } else if (m.isNotEmpty) {
        p.otherMembers[e.key] = m.length;
      }
    }
    if (own.isEmpty && memberItems.length == 1) {
      p.member = memberItems.keys.first;
      own = jMap(memberItems.values.first);
      p.otherMembers.clear();
    }
    // 아주 옛날 모양: owned[] · wanted[] 만 있는 것
    final legacyNow = DateTime.now().toUtc().toIso8601String();
    if (own.isEmpty) {
      own = {
        for (final id in jList(col['wanted']).whereType<String>()) id: {'status': 'wanted', 'updated_at': legacyNow},
        for (final id in jList(col['owned']).whereType<String>()) id: {'status': 'owned', 'updated_at': legacyNow},
      };
    }
    for (final e in own.entries) {
      final n = normalizeEntry(e.value, p.member.isEmpty ? 'member' : p.member);
      if (n == null) continue;
      p.items[e.key] = n;
      switch (n['status']) {
        case 'owned':
          p.owned++;
        case 'wanted':
          p.wanted++;
        default:
          p.deleted++;
      }
      if (n['status'] != 'deleted' && !e.key.startsWith('private-') && !knownKit(e.key)) p.unknown++;
    }
    for (final k in const ['overrides', 'series_label_overrides']) {
      if (jMap(j[k]).isNotEmpty) p.payloadExtra[k] = j[k];
    }
    // Hobby Atlas 자신의 백업 (설정 › 백업 파일로 내보내기)
    p.payloadExtra.addAll(jMap(j['payload_extra']));
    p.collectionExtra.addAll(jMap(j['collection_extra']));
    if (p.payloadExtra.remove('custom_items') case final Object c) {
      p.collectionExtra.putIfAbsent('custom_items', () => c);
    }
    p.payloadExtra.remove('appearance');
    if (jMap(col['custom_items']).isNotEmpty) p.collectionExtra['custom_items'] = col['custom_items'];

    final local = jMap(j['local_state']);
    p.bbxOwnedParts.addAll(jList(local['bbx_owned_parts']).whereType<String>());
    p.bbxManualMap.addAll({for (final e in jMap(local['bbx_manual_map']).entries) e.key: '${e.value}'});
    p.guideManualLit.addAll(
      jList(local['guide_manual_lit']).map((v) => v is num ? v.toInt() : int.tryParse('$v')).nonNulls,
    );
    p.recentViewed.addAll(jList(local['recent_viewed']).whereType<String>());
    if (local['my_channels'] is List) p.myChannels = jList(local['my_channels']).whereType<String>().toList();
    return p;
  }
}
