// 카탈로그 + 내 기록 → 화면 모델 (도감 · 세계관 · 베이블레이드 · 공식 예고 · 알림 · 내 정보).
// 숫자(모은 칸 · 진행도)는 db.json 처럼 미리 적힌 값이 아니라 매번 내 기록에서 센다.
import '../models.dart';
import '../notifications/notify_models.dart';
import '../notifications/notify_store.dart';
import 'catalog.dart';
import 'gunpula.dart';
import 'user_store.dart';
import '../sync/account.dart';
import '../json_util.dart';
import '../sync/friends_service.dart' show PublicProfile;

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
  final u = jMap(await _cat.aux('gget-units.json'));
  final km = jMap(await _cat.aux('gget-kit-map.json'));
  final sec = jMap(await _cat.aux('gget-series-sections.json'));
  final atlas = jMap(await _cat.aux('atlas-groups.json'));
  final workImage = <int, String>{};
  final workSection = <int, String>{};
  for (final g in jList(jMap(atlas['franchises'])['gundam_timeline'])) {
    final label = pickName(jMap(g)['labels']);
    for (final w in jList(jMap(g)['works'])) {
      final id = jInt(jMap(w)['work_id']);
      workSection.putIfAbsent(id, () => label);
      if (jStr(jMap(w)['image']).isNotEmpty) workImage[id] = jStr(jMap(w)['image']);
    }
  }
  for (final w in jList(sec['works'])) {
    final id = jInt(jMap(w)['work_id']);
    if (jStr(jMap(w)['image']).isNotEmpty) workImage[id] = jStr(jMap(w)['image']);
  }
  return _Gget(
    [for (final w in jList(u['works'])) jMap(w)],
    [for (final x in jList(u['units'])) jMap(x)],
    {for (final e in jMap(km['unit_kits']).entries) e.key: jList(e.value).whereType<String>().toList()},
    workImage,
    workSection,
  );
}

bool _inWork(Map<String, Object?> unit, int workId) {
  final ids = jList(unit['work_ids']);
  return ids.isEmpty ? jInt(unit['work_id']) == workId : ids.any((w) => jInt(w) == workId);
}

CollectStatus _unitStatus(_Gget g, Map<String, Object?> unit) {
  final id = jInt(unit['unit_id']);
  final s = _best(g.unitKits['$id'] ?? const []);
  if (s != CollectStatus.none) return s;
  return _me.guideManualLit.contains(id) ? CollectStatus.owned : CollectStatus.none;
}

Future<List<GuideWork>> deriveGuideWorks() async {
  await _cat.ensureLoaded();
  final g = await _gget();
  final out = <GuideWork>[];
  for (final w in g.works) {
    final id = jInt(w['work_id']);
    final units = [
      for (final u in g.units)
        if (_inWork(u, id)) u,
    ];
    if (units.isEmpty) continue;
    out.add(
      GuideWork(
        id: '$id',
        section: g.workSection[id] ?? '기타 작품',
        name: jStr(w['name']),
        image: g.workImage[id] ?? jStr(units.first['image_url']),
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
          id: '${jInt(u['unit_id'])}',
          workId: workId,
          name: jStr(u['name']),
          nameEn: jStr(u['name']),
          image: jStr(u['image_url']),
          status: _unitStatus(g, u),
          kitIds: [
            for (final k in g.unitKits['${jInt(u['unit_id'])}'] ?? const <String>[])
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
      if ((g.unitKits['${jInt(u['unit_id'])}'] ?? const <String>[]).any(owned.contains)) jInt(u['unit_id']),
  };
  if (litUnits.isEmpty) return const {};
  final out = <String, int>{};
  for (final w in g.works) {
    final id = jInt(w['work_id']);
    final n = g.units.where((u) => litUnits.contains(jInt(u['unit_id'])) && _inWork(u, id)).length;
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
            name: pickName(part['names']),
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
        name: pickName(prod['names']),
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
  final atlas = jMap(jMap(await _cat.aux('atlas-groups.json'))['franchises']);
  if (channelId == 'gundam') {
    final g = await _gget();
    return [
      for (final grp in jList(atlas['gundam_timeline']))
        () {
          final m = jMap(grp);
          final workIds = {for (final w in jList(m['works'])) jInt(jMap(w)['work_id'])};
          final units = [
            for (final u in g.units)
              if (workIds.any((w) => _inWork(u, w))) u,
          ];
          return World(
            id: 'gundam-${jStr(m['id'])}',
            franchiseId: 'gundam',
            label: pickName(m['labels']),
            subtitle: pickName(m['subtitle']),
            image: jStr(m['image']),
            total: units.length,
            owned: units.where((u) => _unitStatus(g, u) == CollectStatus.owned).length,
          );
        }(),
    ];
  }
  return [
    for (final grp in jList(atlas[channelId]))
      () {
        final m = jMap(grp);
        final ids = jList(m['kit_ids']).whereType<String>().toList();
        return World(
          id: '$channelId-${jStr(m['id'])}',
          franchiseId: channelId,
          label: pickName(m['labels']),
          subtitle: pickName(m['subtitle']),
          image: jStr(m['image']),
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
    for (final a in jList(jMap(await _cat.aux('announcements.json'))['announcements']))
      if (jMap(a) case final m when set.contains(jStr(m['franchise'])) && jStr(m['id']).isNotEmpty) m,
  ]..sort((a, b) => jStr(b['announced_at']).compareTo(jStr(a['announced_at'])));
  var heroes = 0;
  return [
    for (final m in list)
      () {
        final image = resolveAsset(m['thumbnail_url']);
        return Announcement(
          id: jStr(m['id']),
          franchiseId: jStr(m['franchise']),
          title: pickName(m['names']),
          status: _stageLabels[jStr(m['status'])] ?? '공식 발표',
          date: jStr(m['announced_at']),
          source: jStr(m['source_name']),
          image: image,
          hero: image.isNotEmpty && heroes++ < 6,
          url: jStr(m['source_url']),
        );
      }(),
  ];
}

// ── 알림: 알림함 (lib/notifications) ──────────────────────────────────────────
/// 알림 화면: 알림함(lib/notifications — 앱을 열 때 · 12시간마다 Gunpula 새 소식 파일을 걸러 넣은 줄), 새것부터.
/// 사진은 카탈로그에서 (아직 받는 중이면 빈 사진). 좋아요 · PB 예약 줄은 franchiseId 를 비워 채널과 상관없이 보이게.
Future<List<AppNotice>> deriveNotifications() async {
  final store = NotifyStore.instance;
  await store.load();
  return [for (final r in store.state.inbox) noticeOf(r, _cat.byId[r.kitId])];
}

/// 알림함 한 줄 → 화면 모델
AppNotice noticeOf(NoticeRecord r, Kit? kit) => AppNotice(
  id: r.id,
  type: r.isPbWindow || (r.pb && r.kind == 'added')
      ? NoticeType.reserve
      : (r.reasons.contains('price') ? NoticeType.price : NoticeType.release),
  title: kit?.name ?? r.title,
  body: r.body,
  image: kit?.image ?? '',
  at: r.at.toLocal(),
  read: r.seen,
  franchiseId: r.wanted ? '' : r.franchise,
  kitId: r.kitId,
);

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
