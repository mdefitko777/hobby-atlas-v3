// 수집 기록 합치기 — 옛 Gunpula `app/collection-store.js` 를 그대로 옮긴 것 + 옛 앱 `mergeCloudPayload`.
// 두 앱이 같은 Supabase payload 를 번갈아 쓰므로, 규칙이 한 글자라도 다르면 서로 덮어쓴다.
//   · 상품 하나 = 기록 하나, updated_at 이 더 늦은 쪽이 이긴다 (같으면 local).
//   · 지운 것도 status 'deleted' 로 남긴다 (지웠다는 사실이 다른 기기에서도 이기게).
//   · 멤버 버킷: 'member' · 'ttungyimungyi' · 'ttungyimu' 는 로그인한 나에게 합치고, '냐아' 는 버린다.
//     (내가 아직 'member' 일 때 = 로그인 전에는 합치지 않는다 — main.js collectionStoreOptions 와 같음)
// 일부러 다르게 한 곳 (데이터를 덜 잃는 쪽):
//   · newerByTimestamp: 한쪽이 없으면 다른 쪽을 고른다 (JS 는 양쪽 시각이 0 이면 없는 쪽을 골라 기록이 사라질 수 있음).
//   · collection 안의 다른 키(custom_items 등)를 버리지 않는다 (JS normalizeCollection 은 4개 키만 남김).
library;

import 'dart:convert';
import '../json_util.dart';

/// 기록 상태 3가지
const collectionStatuses = ['owned', 'wanted', 'deleted'];

/// 버리는 멤버 버킷 (main.js DROPPED_COLLECTION_MEMBERS)
const droppedCollectionMembers = {'냐아'};

/// 로그인한 나에게 합치는 버킷 (main.js MERGED_COLLECTION_ALIASES)
const mergedCollectionAliases = ['member', 'ttungyimungyi', 'ttungyimu'];

/// collection 의 기본 키 — 나머지(custom_items 등)는 그대로 둔다
const _collectionCoreKeys = {'owned', 'wanted', 'items', 'member_items'};

class CollectionOptions {
  const CollectionOptions({
    this.statuses = collectionStatuses,
    this.self = 'member',
    this.droppedMembers = const {},
    this.memberMerges = const {},
  });

  /// 로그인한 내 이름 기준 (main.js collectionStoreOptions)
  factory CollectionOptions.forSelf(String self) {
    final me = safeMemberName(self);
    return CollectionOptions(
      self: me,
      droppedMembers: droppedCollectionMembers,
      memberMerges: me == 'member' ? const {} : {for (final a in mergedCollectionAliases) a: me},
    );
  }

  final List<String> statuses;
  final String self;
  final Set<String> droppedMembers;
  final Map<String, String> memberMerges;
}

// ── 작은 도우미 (collection-store.js 와 같은 이름) ─────────────────────────────

String safeMemberName(Object? value) {
  final s = _jsString(value).trim();
  return s.isEmpty ? 'member' : s;
}

/// Math.trunc(Number(v)), 1 미만 · 숫자 아님 → 1, 최대 99
int clampCollectionQuantity(Object? value) {
  final n = _jsNumber(value);
  if (n == null || !n.isFinite || n < 1) return 1;
  final q = n.truncate();
  return q > 99 ? 99 : (q < 1 ? 1 : q);
}

/// 처음으로 읽히는 날짜의 밀리초 (없으면 0)
int timestampMs(Iterable<Object?> values) {
  for (final v in values) {
    if (v is String && v.isNotEmpty) {
      final t = DateTime.tryParse(v);
      if (t != null) return t.millisecondsSinceEpoch;
    }
  }
  return 0;
}

/// 더 늦게 바뀐 쪽 (같으면 left). 한쪽이 없으면 다른 쪽.
T? newerByTimestamp<T extends Object>(T? left, T? right, [List<String> fields = const ['updated_at']]) {
  if (left == null) return right;
  if (right == null) return left;
  int at(Object v) => v is Map ? timestampMs(fields.map((f) => v[f])) : 0;
  return at(left) >= at(right) ? left : right;
}

/// String(v ?? "").replace(/[^\d.]/g, "") → Number → 유한하면 그 값
num? _numericValue(Object? value) {
  final cleaned = _jsString(value ?? '').replaceAll(RegExp(r'[^\d.]'), '');
  if (cleaned.isEmpty) return null;
  final n = double.tryParse(cleaned);
  return n != null && n.isFinite ? n : null;
}

Map<String, Object?> normalizeCollectionEntry(
  Object? raw, {
  List<String> statuses = collectionStatuses,
  String? now,
  String member = 'member',
}) {
  final entry = jMap(raw);
  final status = entry['status'];
  final out = <String, Object?>{
    'status': status is String && statuses.contains(status) ? status : 'wanted',
    'updated_at': _truthy(entry['updated_at']) ? entry['updated_at'] : (now ?? _nowIso()),
    'updated_by': _truthy(entry['updated_by']) ? entry['updated_by'] : safeMemberName(member),
    'quantity': clampCollectionQuantity(entry['quantity'] ?? entry['wanted_quantity'] ?? 1),
  };
  if (_truthy(entry['note'])) out['note'] = _jsString(entry['note']);
  if (_truthy(entry['storage'])) out['storage'] = _jsString(entry['storage']);
  final price = _numericValue(entry['purchase_price']);
  if (price != null) out['purchase_price'] = price.round();
  return out;
}

/// {owned[], wanted[], items{}, member_items{멤버: {kit_id: 기록}}} (+ 그 밖의 키는 그대로)
Map<String, Object?> normalizeCollection(Object? raw, [CollectionOptions options = const CollectionOptions()]) {
  final collection = jMap(raw);
  final statuses = options.statuses;
  final self = safeMemberName(options.self);
  final now = _nowIso();
  final legacyItems = <String, Object?>{...jMap(collection['items'])};
  final memberItems = <String, Object?>{
    for (final e in jMap(collection['member_items']).entries) e.key: e.value is Map ? _deepCopy(e.value) : e.value,
  };

  for (final id in jList(collection['owned'])) {
    if (id is String) legacyItems[id] ??= {'status': 'owned', 'updated_at': now, 'updated_by': 'local'};
  }
  for (final id in jList(collection['wanted'])) {
    if (id is String) legacyItems[id] ??= {'status': 'wanted', 'quantity': 1, 'updated_at': now, 'updated_by': 'local'};
  }

  if (memberItems.isEmpty) {
    for (final e in legacyItems.entries) {
      if (!_truthy(jMap(e.value)['status'])) continue;
      ((memberItems[self] ??= <String, Object?>{}) as Map)[e.key] = e.value;
    }
  }

  final normalized = <String, Map<String, Object?>>{};
  for (final e in memberItems.entries) {
    var key = safeMemberName(e.key);
    final memberMap = e.value;
    if (memberMap is! Map || options.droppedMembers.contains(key)) continue;
    final target = options.memberMerges[key];
    if (target != null && target.isNotEmpty && key != self) key = safeMemberName(target);
    for (final it in memberMap.entries) {
      final entry = jMap(it.value);
      final status = entry['status'];
      if (status is! String || !statuses.contains(status)) continue;
      final ne = normalizeCollectionEntry(entry, statuses: statuses, now: now, member: key);
      final bucket = normalized[key] ??= <String, Object?>{};
      final existing = bucket['${it.key}'];
      bucket['${it.key}'] = existing == null ? ne : newerByTimestamp(jMap(existing), ne)!;
    }
  }

  final owned = <String>[];
  final wanted = <String>[];
  final items = <String, Object?>{};
  for (final e in (normalized[self] ?? const <String, Object?>{}).entries) {
    items[e.key] = e.value;
    final status = jMap(e.value)['status'];
    if (status == 'owned') owned.add(e.key);
    if (status == 'wanted') wanted.add(e.key);
  }
  return {
    for (final e in collection.entries)
      if (!_collectionCoreKeys.contains(e.key)) e.key: e.value,
    'owned': owned.toSet().toList(),
    'wanted': wanted.toSet().toList(),
    'items': items,
    'member_items': normalized,
  };
}

/// 멤버별 · 상품별로 더 늦은 기록을 고른다 (collection-store.js mergeCollectionState)
Map<String, Object?> mergeCollectionState(
  Object? localCollection,
  Object? remoteCollection, [
  CollectionOptions options = const CollectionOptions(),
]) {
  final local = normalizeCollection(localCollection, options);
  final remote = normalizeCollection(remoteCollection, options);
  final lm = jMap(local['member_items']);
  final rm = jMap(remote['member_items']);
  final merged = <String, Map<String, Object?>>{};
  for (final member in {...lm.keys, ...rm.keys}) {
    final l = jMap(lm[member]);
    final r = jMap(rm[member]);
    for (final kitId in {...l.keys, ...r.keys}) {
      final next = newerByTimestamp(l[kitId], r[kitId]);
      if (next == null) continue;
      (merged[member] ??= {})[kitId] = next;
    }
  }
  return normalizeCollection({
    ..._collectionExtras(remote),
    ..._collectionExtras(local),
    'member_items': merged,
  }, options);
}

/// 키별로 더 늦은 값 (updated_at · hidden_at · reviewed_at) — overrides 용
Map<String, Object?> mergeTimestampedMap(Object? localMap, Object? remoteMap) {
  final l = jMap(localMap);
  final r = jMap(remoteMap);
  final merged = <String, Object?>{};
  for (final key in {...l.keys, ...r.keys}) {
    final next = newerByTimestamp(l[key], r[key], const ['updated_at', 'hidden_at', 'reviewed_at']);
    if (next == null) continue;
    if (next is Map && next.isEmpty) continue;
    if (next is String && next.isEmpty) continue;
    merged[key] = next;
  }
  return merged;
}

/// 옛 앱 mergeCloudPayload: remote 를 바탕으로 collection · overrides · series_label_overrides 만 합친다.
/// (v3 저장이 40001 로 부딪혔을 때 다시 합치는 데 쓴다)
Map<String, Object?> mergeCloudPayload(
  Map<String, Object?> localPayload,
  Map<String, Object?> remotePayload, [
  CollectionOptions options = const CollectionOptions(),
]) {
  final merged = mergeCollectionState(localPayload['collection'], remotePayload['collection'], options);
  merged.addAll(
    _mergeExtras(
      _collectionExtras(jMap(localPayload['collection'])),
      _collectionExtras(jMap(remotePayload['collection'])),
    ),
  );
  return {
    ...remotePayload,
    'collection': merged,
    'overrides': mergeTimestampedMap(localPayload['overrides'], remotePayload['overrides']),
    'series_label_overrides': {
      ...jMap(remotePayload['series_label_overrides']),
      ...jMap(localPayload['series_label_overrides']),
    },
  };
}

// ── Hobby Atlas 저장용 ──────────────────────────────────────────────────────────

/// payload 안에서 "내 버킷" 이름.
///  1) 서버가 알려 준 내 이름([preferred]) 버킷이 있으면 그것
///  2) 없으면 'member' 버킷 (옛 앱에서 이름을 안 정하면 거기에 쓴다 — 그때는 별칭 합치기도 안 함)
///  3) 없으면 collection.items 와 같은 상품을 가진 버킷 — 단 [notMine](공유 공간의 다른 멤버 이름)은 빼고.
///     공유 공간의 items 는 "마지막에 저장한 사람"의 버킷이라 같이 쓰는 사람 것일 수도 있다.
///  4) 그것도 없으면 [preferred] (비었으면 'member')
String resolveSelfBucket(Map<String, Object?> payload, String preferred, {Set<String> notMine = const {}}) {
  final col = jMap(payload['collection']);
  final members = jMap(col['member_items']);
  final want = preferred.trim();
  if (want.isNotEmpty && members[want] is Map) return want;
  if (members['member'] is Map) return 'member';
  final items = jMap(col['items']);
  if (items.isNotEmpty) {
    for (final e in members.entries) {
      final name = safeMemberName(e.key);
      if (notMine.contains(name) || droppedCollectionMembers.contains(name)) continue;
      final m = jMap(e.value);
      if (m.length == items.length && m.keys.every(items.containsKey)) return name;
    }
  }
  return safeMemberName(want);
}

/// 내 기록(이 기기)을 서버 payload 에 합친 새 payload.
///  · 내 버킷: 상품별로 더 늦은 기록 (+ 'member' 등 별칭 버킷을 합침, '냐아' 버림)
///  · 다른 멤버 버킷 · overrides · series_label_overrides · appearance · 모르는 키: 서버 것 그대로
///  · [extrasDirty] (백업 파일에서 가져온 overrides 등이 아직 안 올라감) 일 때만 옛 앱처럼 그 값들도 합친다
Map<String, Object?> buildSyncPayload({
  required Map<String, Object?> remote,
  required String self,
  required Map<String, Map<String, Object?>> localSelf,
  Map<String, Object?> localExtras = const {},
  Map<String, Object?> localCollectionExtras = const {},
  bool extrasDirty = false,
}) {
  final options = CollectionOptions.forSelf(self);
  final me = options.self;
  final remoteCol = jMap(remote['collection']);
  final remoteMembers = jMap(remoteCol['member_items']);
  final merged = mergeCollectionState(
    {
      'member_items': {me: localSelf},
    },
    remoteCol,
    options,
  );
  // 다른 멤버 버킷은 읽은 글자 그대로 (정리하지 않음)
  final members = jMap(merged['member_items']);
  final keptMembers = <String, Object?>{
    for (final e in members.entries)
      e.key: e.key != me && remoteMembers[e.key] is Map ? _deepCopy(remoteMembers[e.key]) : e.value,
  };
  final remoteExtras = _collectionExtras(remoteCol);
  final collection = <String, Object?>{
    ...(extrasDirty ? _mergeExtras(localCollectionExtras, remoteExtras) : _deepCopyMap(remoteExtras)),
    'owned': merged['owned'],
    'wanted': merged['wanted'],
    'items': merged['items'],
    'member_items': keptMembers,
  };
  final out = <String, Object?>{
    'schema_version': 1,
    for (final e in remote.entries) e.key: _deepCopy(e.value),
    'collection': collection,
  };
  if (extrasDirty) {
    for (final e in localExtras.entries) {
      if (e.key == 'collection' || e.key == 'appearance') continue;
      if (!out.containsKey(e.key)) out[e.key] = _deepCopy(e.value);
    }
    out['overrides'] = mergeTimestampedMap(localExtras['overrides'], remote['overrides']);
    out['series_label_overrides'] = {
      ...jMap(remote['series_label_overrides']),
      ...jMap(localExtras['series_label_overrides']),
    };
  }
  return out;
}

/// 두 payload 가 같은 내용인지 (키 순서 · owned/wanted 순서 무시)
bool samePayload(Object? a, Object? b) => _canonical(a) == _canonical(b);

/// payload 에서 내 버킷만 (정리된 기록)
Map<String, Map<String, Object?>> selfItemsOf(Map<String, Object?> payload, String self) {
  final members = jMap(jMap(payload['collection'])['member_items']);
  return {
    for (final e in jMap(members[safeMemberName(self)]).entries)
      if (e.value is Map) e.key: Map<String, Object?>.of(jMap(e.value)),
  };
}

/// collection 의 기본 4키 말고 나머지 (custom_items 등)
Map<String, Object?> collectionExtrasOf(Map<String, Object?> payload) => _collectionExtras(jMap(payload['collection']));

Map<String, Object?> _collectionExtras(Map<String, Object?> collection) => {
  for (final e in collection.entries)
    if (!_collectionCoreKeys.contains(e.key)) e.key: e.value,
};

/// collection 추가 키 합치기: custom_items 는 키별로 더 늦은 것, 그 밖은 remote 우선
Map<String, Object?> _mergeExtras(Map<String, Object?> local, Map<String, Object?> remote) {
  final out = <String, Object?>{};
  for (final key in {...local.keys, ...remote.keys}) {
    final l = local[key];
    final r = remote[key];
    if (key == 'custom_items' && l is Map && r is Map) {
      out[key] = mergeTimestampedMap(l, r);
    } else {
      out[key] = _deepCopy(r ?? l);
    }
  }
  return out;
}

String _canonical(Object? v, [String key = '']) {
  if (v is Map) {
    final keys = v.keys.map((k) => '$k').toList()..sort();
    return '{${keys.map((k) => '${jsonEncode(k)}:${_canonical(v[k], k)}').join(',')}}';
  }
  if (v is List) {
    final parts = [for (final x in v) _canonical(x)];
    if (key == 'owned' || key == 'wanted') parts.sort();
    return '[${parts.join(',')}]';
  }
  if (v is double && v == v.truncateToDouble() && v.isFinite) return jsonEncode(v.toInt());
  return jsonEncode(v);
}

// ── JS 흉내 ─────────────────────────────────────────────────────────────────

String _nowIso() => DateTime.now().toUtc().toIso8601String();

/// JS 의 참/거짓 (null · '' · 0 · false → 거짓)
bool _truthy(Object? v) => !(v == null || v == false || v == '' || (v is num && (v == 0 || v.isNaN)));

/// String(v)
String _jsString(Object? v) {
  if (v == null) return '';
  if (v is double && v == v.truncateToDouble() && v.isFinite) return '${v.toInt()}';
  return '$v';
}

/// Number(v)
double? _jsNumber(Object? v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  if (v is bool) return v ? 1 : 0;
  if (v is String) {
    final t = v.trim();
    if (t.isEmpty) return 0;
    return double.tryParse(t);
  }
  return null;
}

Object? _deepCopy(Object? v) {
  if (v is Map) return {for (final e in v.entries) '${e.key}': _deepCopy(e.value)};
  if (v is List) return [for (final x in v) _deepCopy(x)];
  return v;
}

Map<String, Object?> _deepCopyMap(Map<String, Object?> m) => {for (final e in m.entries) e.key: _deepCopy(e.value)};
