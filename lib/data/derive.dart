// 카탈로그 + 내 기록 → 화면 모델 (도감 · 세계관 · 베이블레이드 · 공식 예고 · 알림 · 내 정보).
// 숫자(모은 칸 · 진행도)는 db.json 처럼 미리 적힌 값이 아니라 매번 내 기록에서 센다.
import '../models.dart';
import 'catalog.dart';
import 'gunpula.dart';
import 'user_store.dart';
import '../sync/account.dart';
import '../sync/friends_service.dart' show PublicProfile;

String _str(Object? v) => v is String ? v : '';
Map<String, Object?> _map(Object? v) => v is Map<String, Object?> ? v : const {};
List<Object?> _list(Object? v) => v is List ? v : const [];
int _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

Catalog get _cat => Catalog.instance;
UserStore get _me => UserStore.instance;

CollectStatus _kitStatus(String id) => _me.statusOf(id) ?? CollectStatus.none;

/// 여러 상품 중 가장 높은 상태 (구매함 > 좋아요 > 없음)
CollectStatus _best(Iterable<String> kitIds) {
  var best = CollectStatus.none;
  for (final id in kitIds) {
    final s = _kitStatus(id);
    if (s == CollectStatus.owned) return s;
    if (s == CollectStatus.wanted) best = s;
  }
  return best;
}

// ── 건담 도감: gget (SD 건담 G제네레이션 ETERNAL) 작품 · 기체 ──────────────────
class _Gget {
  _Gget(this.works, this.units, this.unitKits, this.workImage, this.workSection);
  final List<Map<String, Object?>> works;
  final List<Map<String, Object?>> units;
  final Map<String, List<String>> unitKits;
  final Map<int, String> workImage;

  /// 작품 id → 시대 묶음 이름 (우주세기 UC · SEED 우주 …), 순서 = atlas-groups 순서
  final Map<int, String> workSection;
}

Future<_Gget> _gget() async {
  final u = _map(await _cat.aux('gget-units.json'));
  final km = _map(await _cat.aux('gget-kit-map.json'));
  final sec = _map(await _cat.aux('gget-series-sections.json'));
  final atlas = _map(await _cat.aux('atlas-groups.json'));
  final workImage = <int, String>{};
  final workSection = <int, String>{};
  for (final g in _list(_map(atlas['franchises'])['gundam_timeline'])) {
    final label = pickName(_map(g)['labels']);
    for (final w in _list(_map(g)['works'])) {
      final id = _int(_map(w)['work_id']);
      workSection.putIfAbsent(id, () => label);
      if (_str(_map(w)['image']).isNotEmpty) workImage[id] = _str(_map(w)['image']);
    }
  }
  for (final w in _list(sec['works'])) {
    final id = _int(_map(w)['work_id']);
    if (_str(_map(w)['image']).isNotEmpty) workImage[id] = _str(_map(w)['image']);
  }
  return _Gget(
    [for (final w in _list(u['works'])) _map(w)],
    [for (final x in _list(u['units'])) _map(x)],
    {for (final e in _map(km['unit_kits']).entries) e.key: _list(e.value).whereType<String>().toList()},
    workImage,
    workSection,
  );
}

bool _inWork(Map<String, Object?> unit, int workId) {
  final ids = _list(unit['work_ids']);
  return ids.isEmpty ? _int(unit['work_id']) == workId : ids.any((w) => _int(w) == workId);
}

CollectStatus _unitStatus(_Gget g, Map<String, Object?> unit) {
  final id = _int(unit['unit_id']);
  final s = _best(g.unitKits['$id'] ?? const []);
  if (s != CollectStatus.none) return s;
  return _me.guideManualLit.contains(id) ? CollectStatus.owned : CollectStatus.none;
}

Future<List<GuideWork>> deriveGuideWorks() async {
  await _cat.ensureLoaded();
  final g = await _gget();
  final out = <GuideWork>[];
  for (final w in g.works) {
    final id = _int(w['work_id']);
    final units = [for (final u in g.units) if (_inWork(u, id)) u];
    if (units.isEmpty) continue;
    out.add(
      GuideWork(
        id: '$id',
        section: g.workSection[id] ?? '기타 작품',
        name: _str(w['name']),
        image: g.workImage[id] ?? _str(units.first['image_url']),
        total: units.length,
        owned: units.where((u) => _unitStatus(g, u) == CollectStatus.owned).length,
      ),
    );
  }
  // 시대 묶음 순서대로 (atlas-groups 순서), 묶음 안에서는 원래 순서
  final order = <String>[];
  for (final s in g.workSection.values) {
    if (!order.contains(s)) order.add(s);
  }
  int rank(GuideWork w) => order.contains(w.section) ? order.indexOf(w.section) : order.length;
  final indexed = [for (var i = 0; i < out.length; i++) (i, out[i])]
    ..sort((a, b) {
      final c = rank(a.$2).compareTo(rank(b.$2));
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });
  return [for (final e in indexed) e.$2];
}

Future<List<GuideUnit>> deriveGuideUnits(String workId) async {
  await _cat.ensureLoaded();
  final g = await _gget();
  final wid = int.tryParse(workId) ?? -1;
  return [
    for (final u in g.units)
      if (_inWork(u, wid))
        GuideUnit(
          id: '${_int(u['unit_id'])}',
          workId: workId,
          name: _str(u['name']),
          nameEn: _str(u['name']),
          image: _str(u['image_url']),
          status: _unitStatus(g, u),
          kitIds: [
            for (final k in g.unitKits['${_int(u['unit_id'])}'] ?? const <String>[])
              if (_cat.byId.containsKey(k)) k,
          ],
        ),
  ];
}

/// 친구 도감 비교: 친구가 산 상품 → 작품 id 별 모은 기체 수 (친구의 "손으로 켜기"는 기기에만 있어 안 셈)
Future<Map<String, int>> deriveFriendGuide(List<String> ownedKitIds) async {
  if (ownedKitIds.isEmpty) return const {};
  await _cat.ensureLoaded();
  final g = await _gget();
  final owned = ownedKitIds.toSet();
  final litUnits = <int>{
    for (final u in g.units)
      if ((g.unitKits['${_int(u['unit_id'])}'] ?? const <String>[]).any(owned.contains)) _int(u['unit_id']),
  };
  if (litUnits.isEmpty) return const {};
  final out = <String, int>{};
  for (final w in g.works) {
    final id = _int(w['work_id']);
    final n = g.units.where((u) => litUnits.contains(_int(u['unit_id'])) && _inWork(u, id)).length;
    if (n > 0) out['$id'] = n;
  }
  return out;
}

// ── 베이블레이드 X: phstudy 상품 · 시리즈 · 부품 ──────────────────────────────
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
  final db = _map(await _cat.aux('bbx-database.json'));
  final parts = <String, Map<String, Object?>>{};
  for (final e in _map(db['parts']).entries) {
    for (final p in _list(e.value)) {
      final m = _map(p);
      if (_str(m['part_id']).isNotEmpty) parts[_str(m['part_id'])] = {...m, 'type': e.key};
    }
  }
  final seriesBySet = <String, List<Map<String, Object?>>>{};
  for (final s in _list(db['series'])) {
    final m = _map(s);
    (seriesBySet[_str(m['base_set_id'])] ??= []).add(m);
  }
  final out = <BbxTop>[];
  for (final p in _list(db['products'])) {
    final prod = _map(p);
    final setId = _str(prod['base_set_id']);
    final kitId = 'beyblade-x-${_str(prod['product_id']).toLowerCase()}';
    final kitOwned = _kitStatus(kitId) == CollectStatus.owned || _me.bbxManualMap.values.contains(setId);
    final partList = <BbxPart>[];
    for (final s in seriesBySet[setId] ?? const <Map<String, Object?>>[]) {
      for (final type in _partLabels.keys) {
        final pid = _str(s['${type}_id']);
        final part = parts[pid];
        if (part == null || partList.any((x) => x.id == pid)) continue;
        final stats = _map(part['stats']);
        partList.add(
          BbxPart(
            id: pid,
            typeLabel: _partLabels[type]!,
            name: pickName(part['names']),
            image: _str(part['image']).isNotEmpty ? _str(part['image']) : _str(part['image_remote']),
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
        name: pickName(prod['names']),
        image: resolveAsset(_str(prod['image']).isNotEmpty ? prod['image'] : prod['image_remote']),
        owned: partList.where((x) => x.have).length,
        total: partList.length,
        parts: partList,
        kitIds: [if (_cat.byId.containsKey(kitId)) kitId],
      ),
    );
  }
  return out;
}

// ── 도감 첫 화면 · 홈 진행도: 세계관 묶음 ─────────────────────────────────────
Future<List<World>> deriveWorlds(String channelId) async {
  await _cat.ensureLoaded();
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
          label: '${e.key} 라인',
          subtitle: '${e.value.length}개 상품',
          image: e.value.first.image,
          total: e.value.length,
          owned: e.value.where((t) => t.owned > 0).length,
        ),
    ];
  }
  final atlas = _map(_map(await _cat.aux('atlas-groups.json'))['franchises']);
  if (channelId == 'gundam') {
    final g = await _gget();
    return [
      for (final grp in _list(atlas['gundam_timeline']))
        () {
          final m = _map(grp);
          final workIds = {for (final w in _list(m['works'])) _int(_map(w)['work_id'])};
          final units = [
            for (final u in g.units)
              if (workIds.any((w) => _inWork(u, w))) u,
          ];
          return World(
            id: 'gundam-${_str(m['id'])}',
            franchiseId: 'gundam',
            label: pickName(m['labels']),
            subtitle: pickName(m['subtitle']),
            image: _str(m['image']),
            total: units.length,
            owned: units.where((u) => _unitStatus(g, u) == CollectStatus.owned).length,
          );
        }(),
    ];
  }
  return [
    for (final grp in _list(atlas[channelId]))
      () {
        final m = _map(grp);
        final ids = _list(m['kit_ids']).whereType<String>().toList();
        return World(
          id: '$channelId-${_str(m['id'])}',
          franchiseId: channelId,
          label: pickName(m['labels']),
          subtitle: pickName(m['subtitle']),
          image: _str(m['image']),
          total: ids.length,
          owned: ids.where((id) => _kitStatus(id) == CollectStatus.owned).length,
        );
      }(),
  ];
}

// ── 공식 예고 (announcements.json: 일본어 제목만 있음) ─────────────────────────
const _stageLabels = {'announced': '공식 발표', 'product_confirmed': '상품화 확정', 'preorder_open': '예약 시작', 'released': '발매'};

Future<List<Announcement>> deriveAnnouncements(List<String> channelIds) async {
  await _cat.ensureLoaded();
  final set = channelIds.toSet();
  final list = [
    for (final a in _list(_map(await _cat.aux('announcements.json'))['announcements']))
      if (_map(a) case final m when set.contains(_str(m['franchise'])) && _str(m['id']).isNotEmpty) m,
  ]..sort((a, b) => _str(b['announced_at']).compareTo(_str(a['announced_at'])));
  var heroes = 0;
  return [
    for (final m in list)
      () {
        final image = resolveAsset(m['thumbnail_url']);
        return Announcement(
          id: _str(m['id']),
          franchiseId: _str(m['franchise']),
          title: pickName(m['names']),
          status: _stageLabels[_str(m['status'])] ?? '공식 발표',
          date: _str(m['announced_at']),
          source: _str(m['source_name']),
          image: image,
          hero: image.isNotEmpty && heroes++ < 6,
          url: _str(m['source_url']),
        );
      }(),
  ];
}

// ── 알림: update-feed-lite 의 새로 수록된 상품 ─────────────────────────────────
Future<List<AppNotice>> deriveNotifications() async {
  await _cat.ensureLoaded();
  final out = <AppNotice>[];
  for (final e in _list(_map(await _cat.aux('update-feed-lite.json'))['entries'])) {
    final entry = _map(e);
    final at = DateTime.tryParse(_str(entry['date']));
    if (at == null) continue;
    for (final it in _list(entry['added'])) {
      final m = _map(it);
      final id = _str(m['kit_id']);
      final kit = _cat.byId[id];
      if (kit == null) continue;
      out.add(
        AppNotice(
          id: 'feed-${entry['date']}-$id',
          type: kit.pb ? NoticeType.reserve : NoticeType.release,
          title: kit.name,
          body: [if (kit.pb) '프리미엄 반다이', '새로 수록', kit.series].where((s) => s.isNotEmpty).join(' · '),
          image: kit.image,
          at: at,
          read: at.isBefore(DateTime.now().subtract(const Duration(days: 3))),
          franchiseId: kit.franchiseId,
          kitId: id,
        ),
      );
      if (out.length >= 150) return out;
    }
  }
  return out;
}

// ── 내 정보 (이름 · 아이디 · 친구는 계정에서, 숫자는 기기 기록에서) ──────────────
Future<Profile> deriveProfile() async {
  final a = Account.instance;
  final name = a.signedIn ? a.displayName : (_me.member == 'member' ? '나' : _me.member);
  return Profile(
    name: name,
    handle: a.handle,
    avatarText: name.characters.isEmpty ? '나' : name.characters.first,
    tags: const [],
    spendKrw: _me.spendKrw,
    workspace: a.sync.workspace?.name ?? '',
    inviteCode: '',
    members: const [],
    showcase: const [],
    friends: [
      for (final f in a.signedIn ? a.friends.friends : const <PublicProfile>[])
        Member(
          name: f.name,
          handle: f.handle,
          role: '친구',
          self: false,
          liked: a.friends.collections[f.handle]?.likedIds.length ?? 0,
          lit: 0,
          owned: a.friends.collections[f.handle]?.ownedIds.length ?? 0,
          likedIds: a.friends.collections[f.handle]?.likedIds ?? const [],
          ownedIds: a.friends.collections[f.handle]?.ownedIds ?? const [],
        ),
    ],
    suggested: const [],
  );
}

extension on String {
  // flutter 의 characters 패키지 없이 첫 글자 (한글 · 영문은 code unit 하나)
  List<String> get characters => runes.map(String.fromCharCode).toList();
}
