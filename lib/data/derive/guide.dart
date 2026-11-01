// 건담 도감 — 작품 · 기체 칸 · 화수 · 친구 도감 비교 (Atlas: gundam-ms · gundam-kit-ms · gundam-chapters)
part of '../derive.dart';

// 시대 → 작품 → 기체(MS) → 연결된 상품. 칸은 그 기체의 상품을 사면(좋아요면 컬러) 켜진다.
// 옛 "손으로 켜기" 기록은 gget unit_id 그대로 두고, 그 id 를 가진 기체를 켠다.
GundamAtlas? _atlasCache;
List<Object?> _atlasKey = const [];

Future<GundamAtlas> _atlas() async {
  final ms = await _cat.aux(atlasMsFile);
  final km = await _cat.aux(atlasKitMsFile);
  final groups = await _cat.aux('atlas-groups.json');
  final chapters = await _cat.aux(atlasChaptersFile); // 아직 없으면 null → 화수별 보기 · 종류 필터만 빠진다
  final key = [ms, km, groups, chapters, _cat.byId];
  if (_atlasCache case final a? when _sameAll(_atlasKey, key)) return a;
  if (ms == null) throw const CatalogException('건담 도감 데이터를 받지 못했어요.');
  // gget 시리즈 번호 → 공식 작품 로고 (atlas-groups 의 건담 시대 묶음)
  final logos = <int, String>{};
  for (final g in jList(jMap(jMap(groups)['franchises'])['gundam_timeline'])) {
    for (final w in jList(jMap(g)['works'])) {
      final img = jStr(jMap(w)['image']);
      if (img.isNotEmpty) logos.putIfAbsent(jInt(jMap(w)['work_id']), () => img);
    }
  }
  var a = GundamAtlas.parse(ms, km, knownKit: _cat.byId.containsKey, workLogos: logos);
  if (chapters != null) a = a.withChapters(parseChapters(chapters)).withUnitTypes(parseUnitTypes(chapters));
  _atlasKey = key;
  return _atlasCache = a;
}

bool _sameAll(List<Object?> a, List<Object?> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!identical(a[i], b[i])) return false;
  }
  return true;
}

/// 기체 그림: gget 썸네일 → 없으면 연결된 상품의 대표 사진(박스 아트)
String _unitImage(AtlasUnit u) {
  if (u.icon.isNotEmpty) return u.icon;
  for (final id in [...u.litKitIds, ...u.kitIds]) {
    final img = _cat.byId[id]?.image ?? '';
    if (img.isNotEmpty) return img;
  }
  return '';
}

bool _manualLit(AtlasUnit u) => u.ggetIds.any(_me.guideManualLit.contains);

CollectStatus _unitStatus(AtlasUnit u) {
  final s = _best(u.litKitIds);
  if (s == CollectStatus.owned) return s;
  return _manualLit(u) ? CollectStatus.owned : s;
}

/// 구매함에 넣은 때 (내 기록 updated_at)
String _boughtAt(Iterable<String> kitIds) {
  var last = '';
  for (final id in kitIds) {
    if (_kitStatus(id) != CollectStatus.owned) continue;
    final at = jStr(_me.entry(id)?['updated_at']);
    if (at.compareTo(last) > 0) last = at;
  }
  return last;
}

Future<List<GuideWork>> deriveGuideWorks() async {
  await _cat.ensureLoaded();
  final a = await _atlas();
  return [
    for (final w in a.works)
      () {
        final units = [for (final id in w.unitIds) a.units[id]!];
        final status = [for (final u in units) _unitStatus(u)];
        final kits = {for (final u in units) ...u.litKitIds};
        return GuideWork(
          id: w.id,
          section: a.timeline(w.timeline)?.name ?? '기타 작품',
          name: w.name,
          image: w.image, // 공식 작품 로고만 (없으면 이름 칸)
          imageSource: w.imageSource,
          total: units.length,
          owned: status.where((s) => s == CollectStatus.owned).length,
          liked: status.where((s) => s == CollectStatus.wanted).length,
          keywords: [for (final u in units) u.blob].join(' '),
          grades: {
            for (final k in kits)
              if (_cat.byId[k]?.line case final l? when l.isNotEmpty) l,
          }.toList(),
          types: {for (final u in units) u.type}.toList(),
          kits: kits.length,
          boughtAt: _boughtAt(kits),
        );
      }(),
  ];
}

Future<List<GuideUnit>> deriveGuideUnits(String workId) async {
  await _cat.ensureLoaded();
  final a = await _atlas();
  final w = a.work(workId);
  if (w == null) return const [];
  return [
    for (final id in w.unitIds)
      if (a.units[id] case final u?)
        GuideUnit(
          id: u.id,
          workId: workId,
          name: u.name,
          nameEn: u.sub,
          image: _unitImage(u),
          status: _unitStatus(u),
          kitIds: u.kitIds,
          kitRoles: {for (final k in u.kits) k.kitId: k.role},
          ggetIds: u.ggetIds,
          type: u.type,
          keywords: u.blob,
        ),
  ];
}

/// 작품 안 화수 · 장 (gundam-chapters.json 이 없으면 빈 목록 → 화수별 보기를 숨긴다)
Future<List<GuideChapter>> deriveGuideChapters(String workId) async {
  await _cat.ensureLoaded();
  final w = (await _atlas()).work(workId);
  return [
    for (final c in w?.chapters ?? const <AtlasChapter>[])
      GuideChapter(name: c.name, episodes: c.episodes, unitIds: c.unitIds),
  ];
}

/// 친구 도감 비교: 친구가 산 상품 → 작품 id 별 모은 기체 수 (친구의 "손으로 켜기"는 기기에만 있어 안 셈)
Future<Map<String, int>> deriveFriendGuide(List<String> ownedKitIds) async {
  if (ownedKitIds.isEmpty) return const {};
  await _cat.ensureLoaded();
  final a = await _atlas();
  final lit = <String>{for (final k in ownedKitIds) ...?a.unitsByKit[k]};
  if (lit.isEmpty) return const {};
  return {
    for (final w in a.works)
      if (w.unitIds.where(lit.contains).length case final n when n > 0) w.id: n,
  };
}
