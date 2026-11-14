// 내 수집 기록 — 기기에 저장, 옛 Gunpula 앱(app/collection-store.js)과 같은 모양.
//   items[kit_id] = {status: owned|wanted|deleted, updated_at, updated_by, quantity 1–99, note?, storage?, purchase_price?}
// 지운 것도 'deleted' 로 남겨 둔다 (나중에 동기화할 때 "지웠다"가 이기도록).
// 로그인하면 lib/sync/sync_service.dart 가 이 기록을 옛 앱과 같은 Supabase payload 에 합쳐 올린다:
//   · 공유되는 것 = 구매함 · 좋아요(내 버킷) — 바꾸면 sharedRevision +1, cloudDirty = true
//   · payload 에 넣지 않음 = 베이 부품 · 베이 연결 · 베이 조합 · 덱 · 도감 손으로 켜기 · 메자스타 · 프렌다 태그 · 최근 본 것 · 내 사진 목록 · 취향 태그
//     (내 사진 중 친구에게 보이기를 켠 것은 lib/sync/photo_share.dart 가 Storage 에, 태그는 v3 preferences.tags 에 따로 올린다)
//     최근 검색어 · 검색 횟수 · 컬렉션 휴지통도 payload 밖
//   · 조립 상태 · 예약 = local_state 'build_status' · 'preorders' (items 에 칸을 더하지 않는다 — user_store/kit_progress)
//   · 로그인하면 이 기기 기록 중 계정에 딸린 것(베이 · 도감 손으로 켜기 · 태그 · 채널 · 특별 관심 · 휴지통 · 조립 상태 · 예약 …)은
//     lib/sync/device_state_sync.dart 가 payload 와 따로 된 서버 행(gunpula_v3_device_state)에 맞춘다.
//     어느 local_state 키를 맞출지는 lib/sync/device_state.dart 의 deviceSections. 그 장부(항목별 시각 · 지움 표시)는 [deviceSync]
// 나눈 곳 (같은 라이브러리의 part): user_store/atlas_local · history · trash · profile_local · import · kit_progress
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../bbx/combo.dart' show Combo, Deck;
import '../channels.dart' show defaultMyChannels;
import '../json_util.dart';
import '../logic/build_status.dart';
import '../logic/lego_scope.dart';
import '../logic/preorder.dart';
import '../logic/spend.dart';
import '../models.dart';
import '../sync/collection_merge.dart' show collectionStatuses, normalizeCollectionEntry;
import 'blob_store.dart';
import 'photo_files.dart';
import 'social_local.dart';

part 'user_store/atlas_local.dart';
part 'user_store/history.dart';
part 'user_store/kit_progress.dart';
part 'user_store/profile_local.dart';
part 'user_store/trash.dart';

/// 옛 항목 하나 → 정리된 모양 (collection-store.js normalizeCollectionEntry 그대로 — lib/sync/collection_merge.dart).
/// 상태가 owned · wanted · deleted 가 아니면 null (버림)
Map<String, Object?>? normalizeEntry(Object? raw, String member) {
  final status = jMap(raw)['status'];
  if (status is! String || !collectionStatuses.contains(status)) return null;
  return normalizeCollectionEntry(raw, member: member);
}

class UserStore extends ChangeNotifier with _AtlasLocal, _History, _ProfileLocal, _Trash, _KitProgress {
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

  /// 기기 기록 동기화 장부 (lib/sync/device_state_sync.dart 만 읽고 쓴다):
  /// {account, revision, dirty, sections: {local_state 키: {항목: {t, v?, d?}}}} — 비어 있으면 저장 파일에 안 쓴다
  Map<String, Object?> deviceSync = {};

  /// 내 채널 (채널 바 · 알림 범위). 처음 설치하면 건담 · 베이블레이드 · 포켓몬
  final List<String> myChannels = [...defaultMyChannels];

  /// 레고 보기 범위 (검색 탭 › 레고) — 처음 값은 최근 정식 세트
  LegoScope legoScope = LegoScope.recent;

  /// 채널 맞춰 보기 (설정 › 앱): 홈 · 검색 · 캘린더 · 컬렉션이 같은 채널. 끄면 탭마다 따로 — 처음 값은 켜짐
  bool channelSync = true;

  /// 친구 쪽 기기 기록 (아바타 · 배경 · 사진 공개 범위 · 알 수도 있는 친구 닫음 · 서랍 본 시각) — lib/data/social_local.dart
  late final SocialLocal social = SocialLocal(_changed);

  /// 최근 검색어 · 검색 횟수 · 휴지통 한도 (user_store/history · trash)
  static const maxRecentSearches = 20;
  static const maxSearchCounts = 100;
  static const trashDays = 30;

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
    deviceSync = Map.of(jMap(j['device_sync']));
    final local = jMap(j['local_state']);
    bbxOwnedParts
      ..clear()
      ..addAll(jList(local['bbx_owned_parts']).whereType<String>());
    bbxManualMap
      ..clear()
      ..addAll({for (final e in jMap(local['bbx_manual_map']).entries) e.key: '${e.value}'});
    guideManualLit
      ..clear()
      ..addAll(_manualLitFrom(local['guide_manual_lit']));
    recentViewed
      ..clear()
      ..addAll(jList(local['recent_viewed']).whereType<String>());
    bbxCombos
      ..clear()
      ..addAll(jList(local['bbx_combos']).map(Combo.fromJson).nonNulls);
    bbxDecks
      ..clear()
      ..addAll(jList(local['bbx_decks']).map(Deck.fromJson).nonNulls.map(_deck3));
    tagOwned
      ..clear()
      ..addAll(jList(local['tag_owned']).whereType<String>());
    tagLiked
      ..clear()
      ..addAll(jList(local['tag_liked']).whereType<String>());
    // 키가 없으면(옛 파일) 처음 값. 빈 목록은 "채널 없음"으로 그대로 둔다.
    myChannels
      ..clear()
      ..addAll(local['my_channels'] is List ? jList(local['my_channels']).whereType<String>() : defaultMyChannels);
    specialFriends
      ..clear()
      ..addAll(jList(local['special_friends']).whereType<String>());
    legoScope = local['lego_scope'] == 'all' ? LegoScope.all : LegoScope.recent;
    channelSync = local['channel_sync'] != false;
    social.load(local);
    _photos
      ..clear()
      ..addAll(jList(local['photos']).map(MyPhoto.fromJson).nonNulls);
    profileTags
      ..clear()
      ..addAll(jList(local['profile_tags']).whereType<String>());
    recentSearches
      ..clear()
      ..addAll(jList(local['recent_searches']).whereType<String>().take(maxRecentSearches));
    searchCounts
      ..clear()
      ..addAll(_countsFrom(local['search_counts']));
    trash
      ..clear()
      ..addAll(_trashFrom(local['trash']));
    _purgeTrash(DateTime.now());
    _loadKitProgress(local);
  }

  Map<String, Object?> toJson() => {
    'schema': 1,
    'member': member,
    'collection': {'items': _items},
    'payload_extra': payloadExtra,
    'collection_extra': collectionExtra,
    'sync': {'dirty': cloudDirty, 'extras_dirty': extrasDirty, 'account': syncedAccount},
    if (deviceSync.isNotEmpty) 'device_sync': deviceSync,
    'local_state': {
      'bbx_owned_parts': bbxOwnedParts.toList(),
      'bbx_manual_map': bbxManualMap,
      'guide_manual_lit': guideManualLit.toList(),
      'recent_viewed': recentViewed,
      'bbx_combos': [for (final c in bbxCombos) c.toJson()],
      'bbx_decks': [for (final d in bbxDecks) d.toJson()],
      'tag_owned': tagOwned.toList(),
      'tag_liked': tagLiked.toList(),
      'my_channels': myChannels,
      'special_friends': specialFriends.toList(),
      // 처음 값(recent)도 늘 적는다 — 빠지면 동기화가 '지움'으로 보고 다른 기기의 '전부'가 되살아난다
      'lego_scope': legoScope.name,
      'channel_sync': channelSync,
      ...social.toJson(),
      'photos': [for (final p in _photos) p.toJson()],
      'profile_tags': profileTags,
      'recent_searches': recentSearches,
      'search_counts': searchCounts,
      'trash': _trashJson(),
      ..._kitProgressJson(),
    },
  };

  /// [shared] = 구매함 · 좋아요처럼 서버에 올라가야 하는 변경
  @override
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

  /// 내가 무언가 적어 둔 상품 — 좋아요 · 구매함 · 예약 · 조립 상태 · 휴지통 · 내 사진. 고르지 않은 채널은 받지 않아
  /// 카탈로그가 이 상품들만 따로 기기에 둔다 (lib/data/catalog.dart _kept)
  Set<String> get markedKitIds => {
    ...idsWith(const {CollectStatus.owned, CollectStatus.wanted}),
    ...activePreorders.keys,
    ...buildStatus.keys,
    ...trash.keys,
    for (final p in photos)
      if (p.kitId.isNotEmpty) p.kitId,
  };

  /// 구매가를 안 적은 상품의 값 (Catalog 가 정가 × 환율로 채운다)
  int? Function(String id)? listPrice;

  /// 수량 1–99 (기록이 없으면 1) — 좋아요 = 갖고 싶은 수, 구매함 = 가진 수
  int quantityOf(String kitId) => entryQuantity(_items[kitId]);

  /// 구매함 지출 합 (원) — 적어 둔 구매가, 없으면 정가 × 환율 (lib/logic/spend.dart)
  int get spendKrw => spendTotal(_items, listPrice);

  /// 이번 달 지출 — 산 날짜를 따로 적지 않아, 구매함 기록을 마지막으로 바꾼 달로 센다
  int spendInMonth(DateTime now) => spendInMonthOf(_items, now, listPrice);

  // ── 쓰기 ──
  @override
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
    // 준 값만 바꾼다 (null = 그대로, '' · 0 이하 = 지우기) — 옛 앱에서 온 보관 장소 · 메모를 지우지 않게
    void put(String k, Object? v) {
      if (v == null) return;
      (v == '' || (v is int && v <= 0)) ? next.remove(k) : next[k] = v;
    }

    put('purchase_price', purchasePrice);
    put('storage', storage);
    put('note', note);
    _items[kitId] = next;
    _changed(shared: true);
  }

  /// 수량만 바꾼다 (구매가 · 보관 장소 · 메모는 그대로 — setDetails 는 주지 않은 값을 지운다)
  void setQuantity(String kitId, int quantity) {
    final old = _items[kitId];
    final q = quantity.clamp(1, 99);
    if (old == null || entryQuantity(old) == q) return;
    _items[kitId] = {...old, 'quantity': q, 'updated_at': _now(), 'updated_by': member};
    _changed(shared: true);
  }

  /// 내 구매가(한 개 값)만 바꾼다. null = 지움 (보관 장소 · 메모는 그대로)
  void setPurchasePrice(String kitId, int? price) {
    final old = _items[kitId];
    if (old == null) return;
    final next = {...old, 'updated_at': _now(), 'updated_by': member};
    price == null ? next.remove('purchase_price') : next['purchase_price'] = price;
    _items[kitId] = next;
    _changed(shared: true);
  }

  /// 예약한 상품이 도착했다 — [toOwned] 면 구매함으로 옮기고 예약 총액을 내 구매가로 (예약은 지움으로 남긴다).
  /// 아니면 도착만 적는다 (좋아요 그대로). 되돌리기는 [undoArrival]
  ({Map<String, Object?>? entry, Preorder pre})? preorderArrived(String kitId, {required bool toOwned}) {
    final pre = preorderOf(kitId);
    if (pre == null) return null;
    final before = (entry: _items[kitId] == null ? null : {..._items[kitId]!}, pre: pre);
    final now = _now();
    preorders[kitId] = pre.copyWith(arrivedAt: now, deleted: toOwned, updatedAt: now);
    if (toOwned) {
      final old = _items[kitId];
      _items[kitId] = {
        ...?old,
        'status': 'owned',
        'updated_at': now,
        'updated_by': member,
        'quantity': old?['quantity'] ?? 1,
        'purchase_price': ?pre.price,
      };
    }
    _changed(shared: toOwned);
    return before;
  }

  /// [preorderArrived] 되돌리기 — 수집 기록 · 예약을 앞의 값으로 (시각은 새로)
  void undoArrival(String kitId, ({Map<String, Object?>? entry, Preorder pre}) before) {
    final now = _now();
    preorders[kitId] = before.pre.copyWith(updatedAt: now);
    final e = before.entry;
    final cur = _items[kitId];
    // 구매함으로 옮겼을 때만 수집 기록이 바뀌었다 (상태 · 구매가)
    final moved = jStr(e?['status']) != jStr(cur?['status']) || e?['purchase_price'] != cur?['purchase_price'];
    if (moved) {
      _items[kitId] = e == null
          ? {...?cur, 'status': 'deleted', 'updated_at': now, 'updated_by': member}
          : {...e, 'updated_at': now, 'updated_by': member};
    }
    _changed(shared: moved);
  }

  void setLegoScope(LegoScope v) {
    if (v == legoScope) return;
    legoScope = v;
    _changed();
  }

  void setChannelSync(bool on) {
    if (on == channelSync) return;
    channelSync = on;
    _changed();
  }

  void setMyChannels(List<String> ids) {
    if (listEquals(ids, myChannels)) return;
    myChannels
      ..clear()
      ..addAll(ids);
    _changed();
  }

  /// 테스트: 저장 파일(toJson 모양)을 다시 읽는다
  @visibleForTesting
  void debugLoadJson(Object? json) {
    _fromJson(json);
    revision++;
    notifyListeners();
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
    // 조립 상태 · 예약은 앞 계정의 구매함 · 좋아요에 붙은 기록이라 같이 비운다
    buildStatus.clear();
    preorders.clear();
    payloadExtra = {};
    collectionExtra = {};
    cloudDirty = false;
    extrasDirty = false;
    revision++; // sharedRevision 은 그대로 — "내가 바꾼 것"이 아니라 다시 올리지 않는다
    notifyListeners();
    _persistSoon();
  }

  // ── 기기 기록 동기화 (lib/sync/device_state_sync.dart 만 부른다) ──
  /// 지금 local_state 를 JSON 그대로 (복사본 — 고쳐도 기기 기록은 그대로)
  Map<String, Object?> localStateJson() => jMap(jsonDecode(jsonEncode(toJson()['local_state'])));

  /// 서버와 합친 local_state 키 몇 개를 바꿔 끼운다 — 저장 파일을 읽을 때와 같은 길(_fromJson)로 읽어 모양이 늘 같다.
  /// 내가 바꾼 것으로 세지 않는다 (구매함 · 좋아요 동기화는 그대로)
  void applyLocalState(Map<String, Object?> sections) {
    if (sections.isEmpty) return;
    final j = jMap(jsonDecode(jsonEncode(toJson())));
    j['local_state'] = {...jMap(j['local_state']), ...sections};
    _fromJson(j);
    revision++;
    notifyListeners();
    _persistSoon();
  }

  /// 장부 바꾸기 (화면은 다시 그리지 않는다)
  void setDeviceSync(Map<String, Object?> v) {
    deviceSync = v;
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
