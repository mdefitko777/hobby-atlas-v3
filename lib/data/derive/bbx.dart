// 베이블레이드 X 도감 — phstudy 상품 · 시리즈 · 부품 (bbx-database.json)
part of '../derive.dart';

const _partLabels = {
  'blade': '블레이드',
  'ratchet': '래칫',
  'bit': '비트',
  'assist_blade': '어시스트 블레이드',
  'lock_chip': '락 칩',
  'main_blade': '메인 블레이드',
  'metal_blade': '메탈 블레이드',
  'over_blade': '오버 블레이드',
};

String _bbxLine(String baseSetId) => RegExp(r'^[A-Za-z]+').firstMatch(baseSetId)?.group(0)?.toUpperCase() ?? '';

Future<List<BbxTop>> deriveBbxTops() async {
  await _cat.ensureLoaded();
  final db = jMap(await _cat.aux('bbx-database.json'));
  final parts = <String, Map<String, Object?>>{};
  for (final e in jMap(db['parts']).entries) {
    for (final p in jList(e.value)) {
      final m = jMap(p);
      if (jStr(m['part_id']).isNotEmpty) parts[jStr(m['part_id'])] = {...m, 'type': e.key};
    }
  }
  final seriesBySet = <String, List<Map<String, Object?>>>{};
  for (final s in jList(db['series'])) {
    final m = jMap(s);
    (seriesBySet[jStr(m['base_set_id'])] ??= []).add(m);
  }
  final out = <BbxTop>[];
  for (final p in jList(db['products'])) {
    final prod = jMap(p);
    final setId = jStr(prod['base_set_id']);
    final kitId = 'beyblade-x-${jStr(prod['product_id']).toLowerCase()}';
    final kitOwned = _kitStatus(kitId) == CollectStatus.owned || _me.bbxManualMap.values.contains(setId);
    final partList = <BbxPart>[];
    for (final s in seriesBySet[setId] ?? const <Map<String, Object?>>[]) {
      for (final type in _partLabels.keys) {
        final pid = jStr(s['${type}_id']);
        final part = parts[pid];
        if (part == null || partList.any((x) => x.id == pid)) continue;
        final stats = jMap(part['stats']);
        partList.add(
          BbxPart(
            id: pid,
            typeLabel: _partLabels[type]!,
            name: _shown(part['names']),
            image: jStr(part['image']).isNotEmpty ? jStr(part['image']) : jStr(part['image_remote']),
            have: kitOwned || _me.bbxOwnedParts.contains(pid),
            topId: setId,
            stats: {
              for (final e in stats.entries)
                if (e.value is num && (e.value! as num) > 0) e.key: (e.value! as num).toInt(),
            },
          ),
        );
      }
    }
    out.add(
      BbxTop(
        id: setId,
        line: _bbxLine(setId),
        name: _shown(prod['names']),
        image: resolveAsset(jStr(prod['image']).isNotEmpty ? prod['image'] : prod['image_remote']),
        owned: partList.where((x) => x.have).length,
        total: partList.length,
        parts: partList,
        kitIds: [if (_cat.byId.containsKey(kitId)) kitId],
      ),
    );
  }
  return out;
}
