// 도감 첫 화면 · 홈 진행도 — 세계관 묶음 (atlas-groups.json · 건담 시대 · 베이 라인)
part of '../derive.dart';

Future<List<World>> deriveWorlds(String channelId) async {
  await _cat.ensureLoaded();
  final atlas = jMap(jMap(await _cat.aux('atlas-groups.json'))['franchises']);
  if (channelId == 'beyblade') {
    final tops = await deriveBbxTops();
    final lines = <String, List<BbxTop>>{};
    for (final t in tops) {
      (lines[t.line] ??= []).add(t);
    }
    return [
      for (final e in lines.entries)
        World(
          id: 'beyblade-${e.key.toLowerCase()}',
          franchiseId: 'beyblade',
          label: trf('{line} 라인', {'line': e.key}),
          subtitle: '', // 상품 개수는 쓰지 않는다 (2026-11-14 — 분류마다 몇 개인지 보지 않기)
          image: e.value.first.image,
          total: e.value.length,
          owned: e.value.where((t) => t.owned > 0).length,
        ),
      // 블레이더 묶음 (그 캐릭터가 쓰는 블레이드가 든 상품 — Gunpula atlas franchises.beyblade)
      ..._atlasWorlds('beyblade', atlas),
    ];
  }
  if (channelId == 'gundam') {
    // 시대 하나 = 묶음 하나 (기체가 여러 작품에 나와도 한 번만 센다)
    final a = await _atlas();
    return [
      for (final t in a.timelines)
        if (a.works.where((w) => w.timeline == t.id).toList() case final works when works.isNotEmpty)
          () {
            final ids = {for (final w in works) ...w.unitIds};
            return World(
              id: 'gundam-${t.id.toLowerCase()}',
              franchiseId: 'gundam',
              label: t.name,
              subtitle: t.nameEn,
              image: a.timelineImage(t.id), // 그 시대 첫 작품의 공식 로고
              total: ids.length,
              owned: ids.where((id) => _unitStatus(a.units[id]!) == CollectStatus.owned).length,
            );
          }(),
    ];
  }
  return _atlasWorlds(channelId, atlas);
}

List<World> _atlasWorlds(String channelId, Map<String, Object?> atlas) {
  return [
    for (final grp in jList(atlas[channelId]))
      if (_worldIds(channelId, grp) case final ids when channelId != 'lego' || ids.isNotEmpty)
        () {
          final m = jMap(grp);
          return World(
            id: '$channelId-${jStr(m['id'])}',
            franchiseId: channelId,
            label: _shown(m['labels']),
            subtitle: _shown(m['subtitle']),
            image: resolveAsset(m['image']), // ./assets/atlas/covers/… → Pages 주소 (공식 표지)
            total: ids.length,
            owned: ids.where((id) => _kitStatus(id) == CollectStatus.owned).length,
            kitIds: ids,
          );
        }(),
  ];
}

/// atlas 묶음 하나의 이름 (atlas-groups.json `franchises.<채널>[].labels`) — [zh] 면 중국어 먼저.
/// 알림 조건은 묶음 id 를 두고 이름은 보일 때 이것으로 (고를 때 언어로 적어 두면 언어를 바꿔도 그대로였다).
/// 파일을 아직 풀지 않았거나 그 묶음이 없으면 null
String? atlasGroupLabel(String channelId, String groupId, {required bool zh}) {
  final atlas = jMap(jMap(_cat.auxLoaded('atlas-groups.json'))['franchises']);
  for (final grp in jList(atlas[channelId])) {
    final m = jMap(grp);
    if (jStr(m['id']) != groupId) continue;
    final name = atlasName(m['labels'], zh: zh);
    return name.isEmpty ? null : name;
  }
  return null;
}

/// 묶음의 상품 id — 레고는 레고 범위(검색 탭 › 레고)에서 보이는 것만
List<String> _worldIds(String channelId, Object? grp) {
  final ids = jList(jMap(grp)['kit_ids']).whereType<String>();
  return channelId == 'lego'
      ? [
          for (final id in ids)
            if (_cat.byId.containsKey(id)) id,
        ]
      : ids.toList();
}
