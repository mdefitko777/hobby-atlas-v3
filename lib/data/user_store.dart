// 내 수집 기록 — 기기에 저장, 옛 Gunpula 앱(app/collection-store.js)과 같은 모양.
//   items[kit_id] = {status: owned|wanted|deleted, updated_at, updated_by, quantity 1–99, note?, storage?, purchase_price?}
// 지운 것도 'deleted' 로 남겨 둔다 (나중에 동기화할 때 "지웠다"가 이기도록).
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models.dart';
import 'blob_store.dart';

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

  /// 옛 payload 에서 그대로 보관만 하는 값 (overrides · series_label_overrides · custom_items)
  Map<String, Object?> payloadExtra = {};

  // 옛 앱에서 기기에만 있던 값 (백업 · 클라우드에 없음)
  final Set<String> bbxOwnedParts = {};
  final Map<String, String> bbxManualMap = {};
  final Set<int> guideManualLit = {};
  final List<String> recentViewed = [];

  /// 바뀔 때마다 +1 (Marks 가 다시 그릴지 판단)
  int revision = 0;
  bool _loaded = false;
  Timer? _saveTimer;

  Future<void> load() async {
    if (_loaded || !persist) return;
    _loaded = true;
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
    final j = _map(json);
    member = _str(j['member']).isEmpty ? 'member' : _str(j['member']);
    _items
      ..clear()
      ..addAll({
        for (final e in _map(_map(j['collection'])['items']).entries)
          e.key: ?normalizeEntry(e.value, member),
      });
    payloadExtra = Map.of(_map(j['payload_extra']));
    final local = _map(j['local_state']);
    bbxOwnedParts
      ..clear()
      ..addAll(_list(local['bbx_owned_parts']).whereType<String>());
    bbxManualMap
      ..clear()
      ..addAll({for (final e in _map(local['bbx_manual_map']).entries) e.key: '${e.value}'});
    guideManualLit
      ..clear()
      ..addAll(_list(local['guide_manual_lit']).map((v) => v is num ? v.toInt() : int.tryParse('$v')).nonNulls);
    recentViewed
      ..clear()
      ..addAll(_list(local['recent_viewed']).whereType<String>());
  }

  Map<String, Object?> toJson() => {
    'schema': 1,
    'member': member,
    'collection': {'items': _items},
    'payload_extra': payloadExtra,
    'local_state': {
      'bbx_owned_parts': bbxOwnedParts.toList(),
      'bbx_manual_map': bbxManualMap,
      'guide_manual_lit': guideManualLit.toList(),
      'recent_viewed': recentViewed,
    },
  };

  void _changed() {
    revision++;
    notifyListeners();
    if (!persist) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), () => BlobStore.write(_key, jsonEncode(toJson())));
  }

  // ── 읽기 ──
  Map<String, Object?>? entry(String kitId) => _items[kitId];

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
    ]..sort((a, b) => _str(b.value['updated_at']).compareTo(_str(a.value['updated_at'])));
    return [for (final x in e) x.key];
  }

  int get ownedCount => idsWith(const {CollectStatus.owned}).length;
  int get wantedCount => idsWith(const {CollectStatus.wanted}).length;

  /// 구매함에 적어 둔 산 값의 합 (원)
  int get spendKrw => _items.values.fold(0, (s, e) {
    final p = e['purchase_price'];
    return e['status'] == 'owned' && p is num ? s + p.toInt() : s;
  });

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
    _changed();
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
    _changed();
  }

  void markViewed(String kitId) {
    recentViewed
      ..remove(kitId)
      ..insert(0, kitId);
    if (recentViewed.length > 40) recentViewed.removeRange(40, recentViewed.length);
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
      if (mine == null || _str(e.value['updated_at']).compareTo(_str(mine['updated_at'])) > 0) {
        _items[e.key] = e.value;
      }
    }
    payloadExtra = {...payloadExtra, ...p.payloadExtra};
    bbxOwnedParts.addAll(p.bbxOwnedParts);
    bbxManualMap.addAll(p.bbxManualMap);
    guideManualLit.addAll(p.guideManualLit);
    for (final id in p.recentViewed.reversed) {
      if (!recentViewed.contains(id)) recentViewed.insert(0, id);
    }
    _changed();
  }
}

/// 옛 항목 하나 → 정리된 모양 (collection-store.js normalizeCollectionEntry)
Map<String, Object?>? normalizeEntry(Object? raw, String member) {
  final e = _map(raw);
  final status = _str(e['status']);
  if (!const {'owned', 'wanted', 'deleted'}.contains(status)) return null;
  final q = e['quantity'] ?? e['wanted_quantity'];
  final qty = (q is num ? q.toInt() : int.tryParse('$q') ?? 1).clamp(1, 99);
  final out = <String, Object?>{
    'status': status,
    'updated_at': _str(e['updated_at']).isEmpty ? DateTime.now().toUtc().toIso8601String() : _str(e['updated_at']),
    'updated_by': _str(e['updated_by']).isEmpty ? member : _str(e['updated_by']),
    'quantity': qty,
  };
  if (_str(e['note']).isNotEmpty) out['note'] = _str(e['note']);
  if (_str(e['storage']).isNotEmpty) out['storage'] = _str(e['storage']);
  final price = num.tryParse('${e['purchase_price'] ?? ''}'.replaceAll(RegExp(r'[^\d.]'), ''));
  if (price != null) out['purchase_price'] = price.round();
  return out;
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
  final Set<String> bbxOwnedParts = {};
  final Map<String, String> bbxManualMap = {};
  final Set<int> guideManualLit = {};
  final List<String> recentViewed = [];
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
    var j = _map(root);
    final ls = _map(j['local_storage']);
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

    final col = _map(j['collection']);
    final memberItems = _map(col['member_items']);
    var own = _map(col['items']);
    // 내 버킷 이름 = items 와 같은 내용을 가진 member_items 키
    for (final e in memberItems.entries) {
      final m = _map(e.value);
      if (own.isNotEmpty && m.length == own.length && m.keys.every(own.containsKey)) {
        p.member = e.key;
      } else if (m.isNotEmpty) {
        p.otherMembers[e.key] = m.length;
      }
    }
    if (own.isEmpty && memberItems.length == 1) {
      p.member = memberItems.keys.first;
      own = _map(memberItems.values.first);
      p.otherMembers.clear();
    }
    // 아주 옛날 모양: owned[] · wanted[] 만 있는 것
    final legacyNow = DateTime.now().toUtc().toIso8601String();
    if (own.isEmpty) {
      own = {
        for (final id in _list(col['wanted']).whereType<String>()) id: {'status': 'wanted', 'updated_at': legacyNow},
        for (final id in _list(col['owned']).whereType<String>()) id: {'status': 'owned', 'updated_at': legacyNow},
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
      if (_map(j[k]).isNotEmpty) p.payloadExtra[k] = j[k];
    }
    // Hobby Atlas 자신의 백업 (설정 › 백업 파일로 내보내기)
    p.payloadExtra.addAll(_map(j['payload_extra']));
    if (_map(col['custom_items']).isNotEmpty) p.payloadExtra['custom_items'] = col['custom_items'];

    final local = _map(j['local_state']);
    p.bbxOwnedParts.addAll(_list(local['bbx_owned_parts']).whereType<String>());
    p.bbxManualMap.addAll({for (final e in _map(local['bbx_manual_map']).entries) e.key: '${e.value}'});
    p.guideManualLit.addAll(_list(local['guide_manual_lit']).map((v) => v is num ? v.toInt() : int.tryParse('$v')).nonNulls);
    p.recentViewed.addAll(_list(local['recent_viewed']).whereType<String>());
    return p;
  }
}

String _str(Object? v) => v is String ? v : '';
Map<String, Object?> _map(Object? v) => v is Map<String, Object?> ? v : const {};
List<Object?> _list(Object? v) => v is List ? v : const [];
