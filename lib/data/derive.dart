// 카탈로그 + 내 기록 → 화면 모델 (도감 · 세계관 · 베이블레이드 · 공식 예고 · 알림 · 내 정보).
// 숫자(모은 칸 · 진행도)는 db.json 처럼 미리 적힌 값이 아니라 매번 내 기록에서 센다.
import '../models.dart';
import '../notifications/feed_rules.dart' show annStageLabels;
import '../notifications/notify_models.dart';
import '../notifications/notify_store.dart';
import 'catalog.dart';
import 'gundam_atlas.dart';
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

// ── 건담 도감: Atlas (data/atlas/gundam-ms.json · gundam-kit-ms.json · gundam-chapters.json) ─────
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
          kitIds: ids,
        );
      }(),
  ];
}

// ── 공식 예고 (announcements.json: 일본어 제목만 있음) ─────────────────────────
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
          status: annStageLabels[jStr(m['status'])] ?? '공식 발표',
          date: jStr(m['announced_at']),
          source: jStr(m['source_name']),
          image: image,
          hero: image.isNotEmpty && heroes++ < 6,
          url: jStr(m['source_url']),
          video: jStr(m['video_id']),
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
AppNotice noticeOf(NoticeRecord r, Kit? kit) => r.isAnnStage
    ? AppNotice(
        id: r.id,
        type: NoticeType.announce,
        title: r.title,
        body: r.body,
        image: '',
        at: r.at.toLocal(),
        read: r.seen,
        franchiseId: r.franchise,
        annId: r.annId,
      )
    : AppNotice(
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
