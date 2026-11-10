// 베이 조합 만들기(화면 T)의 데이터: phstudy bbx-database.json → 규칙 엔진의 BbxCatalog
// + 상품(kit_id) → 세트(base_set_id) 표. "가진 부품" = 도감과 같은 규칙
// (UserStore.bbxOwnedParts 에 켠 부품 + 구매함에 넣은 상품 · 손으로 연결한 상품의 부품).
import 'dart:isolate';

import '../bbx/bbx.dart';
import '../json_util.dart';
import '../l10n/l10n.dart';
import '../models.dart' show CollectStatus;
import 'catalog.dart';
import 'user_store.dart';

class BbxBuilderData {
  BbxBuilderData(this.catalog, {this.kitSets = const {}});

  /// 상품 · 시리즈 json 을 가진 bbx-database.json 하나로
  factory BbxBuilderData.fromJson(Map<String, Object?> json) => BbxBuilderData(
    BbxCatalog.fromJson(json),
    kitSets: {
      for (final p in jList(json['products']))
        if (jStr(jMap(p)['product_id']).isNotEmpty)
          'beyblade-x-${jStr(jMap(p)['product_id']).toLowerCase()}': jStr(jMap(p)['base_set_id']),
    },
  );

  final BbxCatalog catalog;

  /// Gunpula kit_id → phstudy base_set_id (도감 derive.dart 와 같은 규칙)
  final Map<String, String> kitSets;

  /// 부품(part_id)별 가진 개수: 켠 부품은 1개, 상품을 가졌으면 그 상품의 시리즈마다 1개씩 — 둘 중 큰 값
  Map<String, int> ownedCounts(UserStore me) {
    final sets = {
      for (final e in kitSets.entries)
        if (me.statusOf(e.key) == CollectStatus.owned) e.value,
      ...me.bbxManualMap.values,
    };
    final fromKits = <String, int>{};
    if (sets.isNotEmpty) {
      for (final s in catalog.series) {
        if (!sets.contains(s.baseSetId)) continue;
        for (final id in s.partIds) {
          fromKits[id] = (fromKits[id] ?? 0) + 1;
        }
      }
    }
    return {...fromKits, for (final id in me.bbxOwnedParts) id: (fromKits[id] ?? 0) > 0 ? fromKits[id]! : 1};
  }

  BbxInventory inventory(UserStore me) => BbxInventory(catalog, parts: ownedCounts(me));
}

Future<BbxBuilderData>? _cache;
int _cacheVersion = -1;

/// 무거운 부품 표 정리는 Isolate.run 으로 (데이터가 새로 오면 다시, 실패하면 다음에 다시)
Future<BbxBuilderData> deriveBbxBuilder() async {
  final cat = Catalog.instance;
  if (_cache case final c? when _cacheVersion == cat.version) return c;
  _cacheVersion = cat.version;
  final f = _cache = _build(cat);
  try {
    return await f;
  } on Object {
    if (identical(_cache, f)) _cache = null;
    rethrow;
  }
}

Future<BbxBuilderData> _build(Catalog cat) async {
  await cat.ensureLoaded();
  final db = jMap(await cat.aux('bbx-database.json'));
  if (jMap(db['parts']).isEmpty) throw CatalogException(tr('베이 부품 데이터를 받지 못했어요.'));
  return Isolate.run(() => BbxBuilderData.fromJson(db));
}
