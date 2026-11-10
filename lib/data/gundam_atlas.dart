// 건담 도감 데이터 (Gunpula data/atlas/) — MS 마스터 · 상품↔MS 연결을 "시대 → 작품 → 기체 → 상품" 으로 묶는다.
//   gundam-ms.json       : 시대(timelines) · 작품(works) · MS(ms: 이름 · 형식번호 · 시대 · 나온 작품 · gget_ids · icon)
//   gundam-kit-ms.json   : links {kit_id: [{ms, role, method, confidence}]} · kit_works {kit_id: [작품 id]}
//   gundam-chapters.json : (있을 때만) 작품별 화수 · 장(arcs · episodes) · 기체 종류(unit_types)
// 순수 Dart (Flutter · 전역 상태 없음) — 테스트가 작은 fixture 로 바로 부른다.
//
// 기체 id = MS id (Gundam Wiki 문서 제목, 예: "RX-78-2 Gundam").
// 옛 기록(도감 손으로 켜기)은 gget unit_id 정수 → 그 id 를 gget_ids 에 가진 MS 로 옮겨 읽는다 ([GundamAtlas.unitByGget]).
// 작품 배정은 MS 마스터의 작품 목록(작품별 등장 기체)에서 오고, 시대 가드([eraAllowed])가 다른 세계관 기체를 걸러 낸다
// (예: GN- 은 서력(00) · LM3xx 는 우주세기(V건담) — SEED 작품에 들어가지 않는다).
import '../json_util.dart';
import '../l10n/l10n.dart';
import 'gunpula.dart' show pickName;

/// 앱이 받는 Atlas 파일 (data/ 아래 경로 = Catalog.aux 이름)
const atlasMsFile = 'atlas/gundam-ms.json';
const atlasKitMsFile = 'atlas/gundam-kit-ms.json';

/// 화수 · 장 묶음 + 기체 종류 — 아직 안 올라왔으면(404) 그 보기만 숨긴다
const atlasChaptersFile = 'atlas/gundam-chapters.json';

/// 상품 대표 사진(박스 아트) — 매핑(mapKitsJob) 때만 쓰고 기기에 따로 두지 않는다
const atlasBoxartFile = 'atlas/gundam-boxart.json';

/// 작품 카드 그림 = 공식 작품 타이틀 로고 (SD건담 G제네레이션 ETERNAL 이 쓰는 작품 로고, soshage/kusoge 미러).
/// atlas-groups 에 적힌 주소가 먼저, 없으면 작품의 gget 시리즈 번호로 만든다. 로고가 없는 작품은 그림 없이 이름만.
const ggetSeriesLogoTemplate = 'https://img.kusoge.xyz/ggenet/series/logo_l_series_{id}.webp';
const ggetSeriesLogoSource = 'SD Gundam G Generation ETERNAL series logos via soshage.com (img.kusoge.xyz) — hotlinked';

/// gget unit_id → 시리즈 번호 (1|3040|00300 → 3040)
int ggetSeriesOf(int unitId) => (unitId ~/ 100000) % 10000;

String ggetSeriesLogo(int seriesId) => ggetSeriesLogoTemplate.replaceAll('{id}', seriesId.toString().padLeft(4, '0'));

/// 칸을 켜지 않는 연결 (부품 · 이펙트 / SD 오리지널 캐릭터) — 기체 시트에는 보인다
const unlitRoles = {'accessory_for', 'sd_character'};

/// 시트 순서: 그 기체 자체 → 세트 → 완성품 → 부품 → SD
const _roleRank = {'main': 0, 'set_member': 1, 'figure': 2, 'accessory_for': 3, 'sd_character': 4};

/// 기체 시트의 상품 줄 꼬리표 (main 은 없음)
const roleLabels = {'set_member': '세트', 'figure': '완성품', 'accessory_for': '부품', 'sd_character': 'SD'};

// ── 시대 가드 ─────────────────────────────────────────────────────────────────────

/// 한 세계관 안의 시대 (빌드 · SD · 기타(게임) 작품은 여러 세계관 기체가 함께 나오므로 가드하지 않는다)
const canonEras = {'UC', 'GQ', 'FC', 'AC', 'AW', 'CC', 'CE', 'AD', 'AG', 'RC', 'PD', 'AS'};

/// 형식번호 머리 → 시대 (마스터에 시대가 없거나 틀렸을 때 잡는 두 번째 줄)
final eraPrefixRules = <(RegExp, String)>[
  (RegExp(r'^GN'), 'AD'), // 00 (GN-001 · GNX-603T …)
  (RegExp(r'^LM[34]\d'), 'UC'), // V건담 (LM312V04 · LM314V21)
  (RegExp(r'^(ZGMF|GAT|ORB|MBF|YMF)-'), 'CE'), // SEED
  (RegExp(r'^(XXXG|OZ)-'), 'AC'), // W
  (RegExp(r'^ASW-G'), 'PD'), // 철혈의 오펀스
  (RegExp(r'^(XVX|MD)-'), 'AS'), // 수성의 마녀
  (RegExp(r'^GF13-'), 'FC'), // G건담
  (RegExp(r'^AGE-'), 'AG'), // AGE
];

/// 형식번호(또는 MS id) 로 정한 시대 ('' = 모름)
String eraByModel(Iterable<String> modelsOrIds) {
  for (final m in modelsOrIds) {
    for (final (re, era) in eraPrefixRules) {
      if (re.hasMatch(m.trim())) return era;
    }
  }
  return '';
}

bool _sameEra(String a, String b) => a == b || ({a, b}.containsAll(const {'UC', 'GQ'}));

/// [unitEra] (마스터의 시대) · [modelEra] (형식번호) 기체가 [workEra] 작품에 들어가도 되나.
/// 한 세계관 작품에는 그 시대 기체만 — 빌드 · SD · 기타 작품은 누구나.
bool eraAllowed({required String workEra, required String unitEra, required String modelEra}) {
  if (!canonEras.contains(workEra)) return true;
  if (unitEra.isNotEmpty && !_sameEra(unitEra, workEra)) return false;
  if (modelEra.isNotEmpty && !_sameEra(modelEra, workEra)) return false;
  return true;
}

// ── 기체 종류 (gundam-chapters.json unit_types: 적힌 것만 MS 가 아님) ────────────────
const unitTypeLabels = {'Ship': '전함', 'Fighter': '전투기', 'Vehicle': '차량'};

/// Gundam Wiki 종류 → 도감 필터 이름 (없음 = MS · MA)
String unitTypeLabel(String wikiType) =>
    wikiType.isEmpty || wikiType == 'Suit' ? 'MS · MA' : (unitTypeLabels[wikiType] ?? '기타');

class AtlasKit {
  const AtlasKit(this.kitId, this.role);
  final String kitId;
  final String role;

  bool get lights => !unlitRoles.contains(role);
}

/// 도감 칸 하나 = MS 하나
class AtlasUnit {
  const AtlasUnit({
    required this.id,
    required this.name,
    required this.sub,
    required this.icon,
    required this.ggetIds,
    required this.kits,
    required this.works,
    required this.debutWork,
    required this.era,
    required this.blob,
    this.type = 'MS · MA',
  });

  final String id;

  /// 한국어 → 일본어 → 영어 순서로 처음 있는 이름
  final String name;

  /// 둘째 줄: 형식번호 · 영어 이름 (예: "RX-78-2 · Gundam")
  final String sub;

  /// gget 썸네일 전체 주소 (없으면 '' → 화면이 상품 사진을 쓴다)
  final String icon;

  /// 옛 gget unit_id (도감 손으로 켜기 기록의 키)
  final List<int> ggetIds;

  /// 연결된 상품 (역할 순)
  final List<AtlasKit> kits;

  /// 이 기체가 들어간 작품 id (시대 가드를 지난 것만)
  final List<String> works;
  final String debutWork;

  /// 시대 (마스터 → 없으면 형식번호)
  final String era;

  /// 찾기용 (모든 언어 이름 · 형식번호 · id, 소문자)
  final String blob;

  /// 도감 필터 종류 (MS · MA / 전함 / 전투기 / 차량 / 기타)
  final String type;

  List<String> get kitIds => [for (final k in kits) k.kitId];

  /// 구매하면 칸이 켜지는 상품 (부품 · SD 캐릭터 제외)
  List<String> get litKitIds => [
    for (final k in kits)
      if (k.lights) k.kitId,
  ];

  int get _ggetKey => ggetIds.isEmpty ? 1 << 40 : ggetIds.reduce((a, b) => a < b ? a : b);

  AtlasUnit _typed(String t) => AtlasUnit(
    id: id,
    name: name,
    sub: sub,
    icon: icon,
    ggetIds: ggetIds,
    kits: kits,
    works: works,
    debutWork: debutWork,
    era: era,
    blob: blob,
    type: t,
  );
}

/// [AtlasChapter.episodes] ("1–3화" · "12화", 기기에 그대로 둔 한국어) → 화면 글 (고른 언어)
String episodesLabel(String episodes) {
  final range = RegExp(r'^(\d+)–(\d+)화$').firstMatch(episodes);
  if (range != null) return trf('{from}–{to}화', {'from': range[1], 'to': range[2]});
  final one = RegExp(r'^(\d+)화$').firstMatch(episodes);
  if (one != null) return trf('{n}화', {'n': one[1]});
  return episodes;
}

/// 작품 안 묶음 — 화수 범위(장 · arc) 또는 한 화(episode)
class AtlasChapter {
  const AtlasChapter(this.name, this.unitIds, {this.episodes = ''});

  /// 장 · 화 제목 (한국어 → 일본어 → 영어)
  final String name;

  /// "1–3화" · "12화" (없으면 '')
  final String episodes;
  final List<String> unitIds;
}

class AtlasWork {
  const AtlasWork({
    required this.id,
    required this.name,
    required this.nameEn,
    required this.timeline,
    required this.order,
    required this.ggetSeriesIds,
    required this.unitIds,
    this.image = '',
    this.imageSource = '',
    this.chapters = const [],
  });

  final String id;
  final String name;
  final String nameEn;

  /// 시대 id (UC · CE · BUILD …)
  final String timeline;
  final int order;

  /// 이 작품에 해당하는 gget 시리즈 (작품 로고 그림을 찾는다)
  final List<int> ggetSeriesIds;

  /// 이 작품의 기체 (나온 작품이 여기인 것 먼저, 그다음 gget 순서)
  final List<String> unitIds;

  /// 공식 작품 로고 ('' = 없음 → 카드에 이름만)
  final String image;

  /// [image] 의 출처 (데이터 기록용)
  final String imageSource;

  /// 화수 · 장 묶음 (gundam-chapters.json 이 있을 때만)
  final List<AtlasChapter> chapters;

  AtlasWork _with(List<AtlasChapter> c) => AtlasWork(
    id: id,
    name: name,
    nameEn: nameEn,
    timeline: timeline,
    order: order,
    ggetSeriesIds: ggetSeriesIds,
    unitIds: unitIds,
    image: image,
    imageSource: imageSource,
    chapters: c,
  );
}

class AtlasTimeline {
  const AtlasTimeline(this.id, this.name, this.nameEn);
  final String id;
  final String name;
  final String nameEn;
}

class GundamAtlas {
  GundamAtlas._(this.timelines, this.works, this.units, this.unitByGget, this.unitsByKit);

  /// 데이터가 없을 때 (작품 0개)
  static final empty = GundamAtlas._(const [], const [], const {}, const {}, const {});

  /// 시대 (gundam-ms.json 순서)
  final List<AtlasTimeline> timelines;

  /// 기체가 하나라도 있는 작품 — 시대 순서, 그 안에서 order 순서
  final List<AtlasWork> works;
  final Map<String, AtlasUnit> units;

  /// 옛 gget unit_id → 기체 id (도감 손으로 켜기 옛 기록)
  final Map<int, String> unitByGget;

  /// 상품 → 이 상품으로 켜지는 기체 (친구 도감 비교)
  final Map<String, List<String>> unitsByKit;

  AtlasWork? work(String id) {
    for (final w in works) {
      if (w.id == id) return w;
    }
    return null;
  }

  AtlasTimeline? timeline(String id) {
    for (final t in timelines) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// 시대 카드 그림 = 그 시대 첫 작품(로고가 있는 것)의 공식 로고
  String timelineImage(String id) {
    for (final w in works) {
      if (w.timeline == id && w.image.isNotEmpty) return w.image;
    }
    return '';
  }

  /// 옛 gget id 들 → 켜진 기체 id
  Set<String> unitsForGget(Iterable<int> ggetIds) => {for (final g in ggetIds) ?unitByGget[g]};

  /// [ms] = gundam-ms.json, [kitMs] = gundam-kit-ms.json (jsonDecode 결과).
  /// [knownKit] 을 주면 카탈로그에 없는 상품 연결은 버린다. [workLogos] = gget 시리즈 번호 → 로고 (atlas-groups).
  /// 칸 = gget 그림이 있거나 칸을 켜는 상품(부품 · SD 제외)이 하나라도 연결된 MS (여객기 · 배처럼 둘 다 없는 것은 뺀다).
  factory GundamAtlas.parse(
    Object? ms,
    Object? kitMs, {
    bool Function(String kitId)? knownKit,
    Map<int, String> workLogos = const {},
  }) {
    final root = jMap(ms);
    final km = jMap(kitMs);
    final redirects = {
      for (final e in jMap(root['ms_redirects']).entries)
        if (jStr(e.value).isNotEmpty) e.key: jStr(e.value),
    };
    String resolve(String id) => redirects[id] ?? id;
    final iconTemplate = jStr(root['icon_template']);

    final timelines = [
      for (final t in jList(root['timelines']))
        if (jStr(jMap(t)['id']) case final id when id.isNotEmpty)
          AtlasTimeline(id, pickName(jMap(t)['names']), pickName(jMap(t)['names'], const ['en', 'ja', 'ko'])),
    ];
    final tlRank = {for (var i = 0; i < timelines.length; i++) timelines[i].id: i};

    // 작품 (아직 기체 없이)
    final rawWorks = <String, Map<String, Object?>>{};
    for (final w in jList(root['works'])) {
      final m = jMap(w);
      if (jStr(m['id']).isNotEmpty) rawWorks[jStr(m['id'])] = m;
    }
    String workEra(String w) => jStr(rawWorks[w]?['timeline']);
    final seriesWorks = {
      for (final e in rawWorks.entries)
        e.key: {jInt(e.value['gget_series_id']), for (final g in jList(e.value['gget_series_ids'])) jInt(g)}..remove(0),
    };

    // MS → 상품 (역할 순)
    final kitsByMs = <String, List<AtlasKit>>{};
    for (final e in jMap(km['links']).entries) {
      if (knownKit != null && !knownKit(e.key)) continue;
      for (final l in jList(e.value)) {
        final link = jMap(l);
        final msId = resolve(jStr(link['ms']));
        if (msId.isEmpty) continue;
        final list = kitsByMs[msId] ??= [];
        if (list.any((k) => k.kitId == e.key)) continue;
        list.add(AtlasKit(e.key, jStr(link['role']).isEmpty ? 'main' : jStr(link['role'])));
      }
    }
    for (final list in kitsByMs.values) {
      // 역할 순, 같은 역할 안에서는 kit_id 순 (실행마다 같은 순서)
      list.sort((a, b) {
        final c = (_roleRank[a.role] ?? 9).compareTo(_roleRank[b.role] ?? 9);
        return c != 0 ? c : a.kitId.compareTo(b.kitId);
      });
    }
    final kitWorks = {
      for (final e in jMap(km['kit_works']).entries) e.key: jList(e.value).whereType<String>().toList(),
    };

    final units = <String, AtlasUnit>{};
    for (final raw in jList(root['ms'])) {
      final m = jMap(raw);
      final id = jStr(m['id']);
      if (id.isEmpty || units.containsKey(id)) continue;
      final icon = jStr(m['icon']);
      final kits = kitsByMs[id] ?? const <AtlasKit>[];
      // 켤 수 없는 칸(그림도 없고 · 칸을 켜는 상품도 없음)은 만들지 않는다
      if (icon.isEmpty && !kits.any((k) => k.lights)) continue;
      final models = jList(m['model_numbers']).whereType<String>().where((s) => s.isNotEmpty).toList();
      final unitEra = jStr(m['timeline']);
      final modelEra = eraByModel([...models, id]);
      bool fits(String w) =>
          rawWorks.containsKey(w) && eraAllowed(workEra: workEra(w), unitEra: unitEra, modelEra: modelEra);
      // 나온 작품 (시대 가드) — 없으면 연결된 상품의 작품
      var works = [
        for (final w in jList(m['works']).whereType<String>())
          if (fits(w)) w,
      ];
      if (works.isEmpty) {
        works = <String>{
          for (final k in kits)
            for (final w in kitWorks[k.kitId] ?? const <String>[])
              if (fits(w)) w,
        }.toList();
      }
      final ggetIds = [for (final g in jList(m['gget_ids'])) jInt(g)]..removeWhere((g) => g == 0);
      if (works.isEmpty) {
        // 그래도 없으면 gget 시리즈 번호 (unit_id 1|3040|00300 → 3040) 가 든 작품
        final series = {for (final g in ggetIds) ggetSeriesOf(g)};
        works = [
          for (final e in seriesWorks.entries)
            if (series.any(e.value.contains) && fits(e.key)) e.key,
        ];
      }
      if (works.isEmpty) continue;
      final names = jMap(m['names']);
      final name = pickName(names, const ['ko', 'ja', 'en', 'zh']);
      final en = jStr(names['en']).trim();
      units[id] = AtlasUnit(
        id: id,
        name: name.isEmpty ? id : name,
        sub: [...models.take(1), if (en.isNotEmpty && en != name) en].join(' · '),
        icon: icon.isEmpty || iconTemplate.isEmpty ? '' : iconTemplate.replaceAll('{icon}', icon),
        ggetIds: ggetIds,
        kits: kits,
        works: works,
        debutWork: jStr(m['debut_work']),
        era: unitEra.isNotEmpty ? unitEra : modelEra,
        blob: <String>{
          id,
          ...models,
          for (final v in names.values) jStr(v),
        }.where((s) => s.isNotEmpty).join(' ').toLowerCase(),
      );
    }

    // 작품 → 기체 (그 작품에서 처음 나온 것 먼저, 그다음 gget 순서, 마지막 id)
    final byWork = <String, List<AtlasUnit>>{};
    for (final u in units.values) {
      for (final w in u.works) {
        (byWork[w] ??= []).add(u);
      }
    }
    final works = <AtlasWork>[];
    for (final e in rawWorks.entries) {
      final list = byWork[e.key];
      if (list == null || list.isEmpty) continue;
      list.sort((a, b) {
        final da = a.debutWork == e.key ? 0 : 1;
        final db = b.debutWork == e.key ? 0 : 1;
        if (da != db) return da.compareTo(db);
        final g = a._ggetKey.compareTo(b._ggetKey);
        return g != 0 ? g : a.id.compareTo(b.id);
      });
      final m = e.value;
      final series = <int>{
        if (jInt(m['gget_series_id']) != 0) jInt(m['gget_series_id']),
        for (final g in jList(m['gget_series_ids'])) jInt(g),
      }.where((g) => g != 0).toList();
      // 공식 로고: atlas-groups 에 적힌 것 → 대표 gget 시리즈 번호로 만든 주소
      var image = '';
      for (final g in series) {
        if (workLogos[g] case final img? when img.isNotEmpty) {
          image = img;
          break;
        }
      }
      if (image.isEmpty && series.isNotEmpty) image = ggetSeriesLogo(series.first);
      works.add(
        AtlasWork(
          id: e.key,
          name: pickName(m['names']).isEmpty ? e.key : pickName(m['names']),
          nameEn: jStr(jMap(m['names'])['en']),
          timeline: jStr(m['timeline']),
          order: jInt(m['order']),
          ggetSeriesIds: series,
          unitIds: [for (final u in list) u.id],
          image: image,
          imageSource: image.isEmpty ? '' : ggetSeriesLogoSource,
        ),
      );
    }
    works.sort((a, b) {
      final c = (tlRank[a.timeline] ?? tlRank.length).compareTo(tlRank[b.timeline] ?? tlRank.length);
      return c != 0 ? c : a.order.compareTo(b.order);
    });

    final unitByGget = <int, String>{};
    final unitsByKit = <String, List<String>>{};
    for (final u in units.values) {
      for (final g in u.ggetIds) {
        unitByGget.putIfAbsent(g, () => u.id);
      }
      for (final k in u.litKitIds) {
        (unitsByKit[k] ??= []).add(u.id);
      }
    }
    return GundamAtlas._(timelines, works, units, unitByGget, unitsByKit);
  }

  /// 작품 id → 묶음 (화 · 장). 모르는 기체 id 는 버리고, 비게 되는 묶음도 버린다.
  GundamAtlas withChapters(Map<String, List<AtlasChapter>> chapters) => GundamAtlas._(
    timelines,
    [
      for (final w in works)
        if (chapters[w.id] case final list?)
          w._with([
            for (final c in list)
              if (c.unitIds.where(w.unitIds.contains).toList() case final ids when ids.isNotEmpty)
                AtlasChapter(c.name, ids, episodes: c.episodes),
          ])
        else
          w,
    ],
    units,
    unitByGget,
    unitsByKit,
  );

  /// 기체 종류를 얹는다 (MS id → Gundam Wiki 종류). 적히지 않은 기체는 MS · MA
  GundamAtlas withUnitTypes(Map<String, String> wikiTypes) => wikiTypes.isEmpty
      ? this
      : GundamAtlas._(
          timelines,
          works,
          {
            for (final e in units.entries)
              e.key: wikiTypes[e.key] == null ? e.value : e.value._typed(unitTypeLabel(wikiTypes[e.key]!)),
          },
          unitByGget,
          unitsByKit,
        );
}

// ── gundam-chapters.json ───────────────────────────────────────────────────────────

/// 작품 id → 묶음. 장(arcs, 화수 범위)이 있으면 장, 없으면 기체가 적힌 화(episodes)
Map<String, List<AtlasChapter>> parseChapters(Object? json) {
  final out = <String, List<AtlasChapter>>{};
  for (final e in jMap(jMap(json)['works']).entries) {
    final w = jMap(e.value);
    final arcs = [for (final a in jList(w['arcs'])) jMap(a)]
      ..sort((a, b) => jInt(a['order']).compareTo(jInt(b['order'])));
    List<String> ids(Object? list) => <String>{
      for (final x in jList(list))
        if (jStr(jMap(x)['ms']) case final id when id.isNotEmpty) id,
    }.toList();
    final list = <AtlasChapter>[
      if (arcs.isNotEmpty)
        for (final a in arcs)
          AtlasChapter(
            pickName(a['title']),
            ids(a['ms']),
            episodes: switch ((jInt(a['episode_from']), jInt(a['episode_to']))) {
              (0, _) => '',
              (final f, final t) when t <= f => '$f화',
              (final f, final t) => '$f–$t화',
            },
          )
      else
        for (final ep in jList(w['episodes']))
          if (ids(jMap(ep)['ms']) case final ms when ms.isNotEmpty)
            AtlasChapter(
              pickName({'ja': jMap(ep)['title_ja'], 'en': jMap(ep)['title_en']}, const ['ja', 'en']),
              ms,
              episodes: jInt(jMap(ep)['no']) == 0 ? '' : '${jInt(jMap(ep)['no'])}화',
            ),
    ];
    if (list.isNotEmpty) out[e.key] = list;
  }
  return out;
}

/// MS id → Gundam Wiki 종류 (Ship · Vehicle · Fighter …). gundam-chapters.json 의 unit_types · extra_ms
Map<String, String> parseUnitTypes(Object? json) {
  final j = jMap(json);
  return {
    for (final e in jMap(j['extra_ms']).entries)
      if (jStr(jMap(e.value)['type']).isNotEmpty) e.key: jStr(jMap(e.value)['type']),
    for (final e in jMap(j['unit_types']).entries)
      if (jStr(e.value).isNotEmpty) e.key: jStr(e.value),
  };
}
