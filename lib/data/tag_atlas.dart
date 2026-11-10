// 포켓몬 메자스타 태그 · 프렌다 픽 도감 데이터 (Gunpula data/atlas/*.json → 화면용 가벼운 모양).
//   · mezastar-intl.json  : 한국(KR) · 홍콩 영어판(EN) · 대만(TC) — 태그 하나에 지역별 인쇄(printings)
//   · mezastar-jp.json    : 일본판(JA, 2020–2024 끝남)
//   · pokemon-frienda.json: 일본 프렌다 픽 (공식 사이트가 이미지 직접 링크를 막아 그림이 없다 → 도감 번호 그림)
// 칸 하나 = 그 지역에서 나온 인쇄 하나. 좋아요 · 구매함 표시는 인쇄 id(메자스타 `…@KR`) · 픽 id(프렌다) 그대로 쓴다.
import 'catalog.dart';
import '../json_util.dart';
import '../l10n/l10n.dart';

enum TagGame { mezastar, frienda }

extension TagGameInfo on TagGame {
  String get label => switch (this) {
    TagGame.mezastar => 'MEZASTAR',
    TagGame.frienda => 'Frienda',
  };

  /// 부제 (고른 언어)
  String get subtitle => switch (this) {
    TagGame.mezastar => tr('메자스타 · 태그스타 태그'),
    TagGame.frienda => tr('프렌다 픽'),
  };

  List<TagRegion> get regions => switch (this) {
    TagGame.mezastar => mezastarRegions,
    TagGame.frienda => const [friendaRegion],
  };
}

/// 지역 하나 = 받을 파일 + 그 파일 안 인쇄 지역 코드
class TagRegion {
  const TagRegion(this.id, this.label, this.file, this.code);

  /// 화면 표시 (KR · JP · HK · TW)
  final String id;
  final String label;
  final String file;

  /// 데이터 안 지역 코드 (KR · JA · EN · TC)
  final String code;
}

const mezastarIntlFile = 'atlas/mezastar-intl.json';
const mezastarJpFile = 'atlas/mezastar-jp.json';
const friendaFile = 'atlas/pokemon-frienda.json';

const mezastarRegions = [
  TagRegion('KR', '한국', mezastarIntlFile, 'KR'),
  TagRegion('JP', '일본', mezastarJpFile, 'JA'),
  TagRegion('HK', '홍콩', mezastarIntlFile, 'EN'),
  TagRegion('TW', '대만', mezastarIntlFile, 'TC'),
];
const friendaRegion = TagRegion('JP', '일본', friendaFile, 'JP');

/// 탄 · 시리즈 하나
class TagSet {
  const TagSet({
    required this.id,
    required String name,
    this.nameZh = '',
    this.local = '',
    this.date = '',
    this.ordinal = 0,
    this.extra = false,
  }) : nameKo = name;
  final String id;

  /// 한국어 이름 (스타더스트 1탄 · 고저스스타 5탄 · 베스트태그 2탄 …)
  final String nameKo;

  /// 중국어 화면 이름 (데이터의 중국어 이름 · 'N탄' → 第N弹 · 영어 이름). 비면 [nameKo] 를 번역 표로
  final String nameZh;

  /// 화면에 보이는 이름 — 고른 언어를 따른다
  String get name => !L10n.isZh ? nameKo : (nameZh.isNotEmpty ? nameZh : tr(nameKo));

  /// 그 지역 이름 (星塵第1彈 · ゴージャススター5弾 …)
  final String local;
  final String date;
  final int ordinal;

  /// 프로모 · 원더 · 레거시처럼 번호 탄이 아닌 묶음
  final bool extra;
}

/// 도감 칸 하나 (지역 인쇄 · 픽 하나)
class TagCard {
  const TagCard({
    required this.id,
    required this.tagId,
    required this.game,
    required this.region,
    required this.number,
    required String name,
    required this.setIds,
    this.nameZh = '',
    this.local = '',
    this.searchText = '',
    this.rarity = '',
    this.grade,
    this.types = const [],
    this.image = '',
    this.large = const [],
    this.url = '',
    this.dex = 0,
    String variant = '',
  }) : nameKo = name,
       variantKo = variant;

  /// 좋아요 · 구매함 키 — 데이터의 인쇄 id / 픽 id 그대로
  final String id;

  /// 같은 태그의 다른 지역 인쇄를 묶는 id
  final String tagId;
  final TagGame game;
  final String region;

  /// 1-1-001 · 4-5-001 · P (B-001)
  final String number;

  /// 한국어 이름 (없으면 일본어 · 영어)
  final String nameKo;

  /// 중국어 이름 (데이터 zh → zh_hant, 포켓몬 공식 이름). 없으면 ''
  final String nameZh;

  /// 화면에 보이는 이름 — 중국어 화면이면 [nameZh] 가 있을 때 그것
  String get name => L10n.isZh && nameZh.isNotEmpty ? nameZh : nameKo;

  /// 그 지역 이름 (뮤츠 · 超夢 · Mewtwo · ミュウツー)
  final String local;
  final List<String> setIds;

  /// 소문자 · 띄어쓰기 없는 찾기 글자 (모든 언어 이름 · 번호)
  final String searchText;

  /// 등급 묶음 키 (superstar · star · normal · promo · super_treasure · treasure …)
  final String rarity;

  /// 별 수 (★2–6, 모르면 null)
  final int? grade;
  final List<String> types;
  final String image;

  /// 크게 볼 공식 그림 (앞 · 뒤). 없으면 [image] 를 크게 (lib/widgets/images.dart openImageViewer)
  final List<String> large;

  /// 공식 페이지 (메자스타 KR · 국제판 태그 팝업, 프렌다 픽 목록) — 앱 밖 브라우저로 연다
  final String url;
  final int dex;

  /// 같은 번호의 다른 판 (체험판 · 캠페인) — 데이터 그대로 (찾기 글자에 들어간다)
  final String variantKo;

  /// 화면에 보이는 [variantKo] (앱이 붙인 '이전 탄' 같은 말은 번역)
  String get variant => tr(variantKo);

  /// 등급 이름 (고른 언어)
  String get rarityLabel => tr(rarityLabels[rarity] ?? rarity);

  /// 칸 위 짧은 표시: ★6 · 프로모
  String get badge => grade != null ? '★$grade' : rarityLabel;

  /// 그림만 바꾼 카드 (프렌다: 기기에서 받은 공식 그림 — lib/data/frienda_images.dart)
  TagCard withImages({required String image, required List<String> large}) => TagCard(
    id: id,
    tagId: tagId,
    game: game,
    region: region,
    number: number,
    name: nameKo,
    nameZh: nameZh,
    setIds: setIds,
    local: local,
    searchText: searchText,
    rarity: rarity,
    grade: grade,
    types: types,
    image: image,
    large: large,
    url: url,
    dex: dex,
    variant: variantKo,
  );

  bool matches(String query) {
    final q = normalizeQuery(query);
    return q.isEmpty || searchText.contains(q);
  }
}

/// 지역 하나의 도감
class TagBook {
  const TagBook({required this.game, required this.region, required this.sets, required this.cards, this.defaultSet});
  final TagGame game;
  final TagRegion region;
  final List<TagSet> sets;
  final List<TagCard> cards;

  /// 처음 보여 줄 탄 (가장 새 번호 탄)
  final String? defaultSet;

  String get title => game == TagGame.mezastar ? '${game.label} ${region.id}' : game.label;

  /// [setId] 가 null 이면 전부
  List<TagCard> inSet(String? setId) => setId == null
      ? cards
      : [
          for (final c in cards)
            if (c.setIds.contains(setId)) c,
        ];

  TagSet? set(String id) => sets.where((s) => s.id == id).firstOrNull;
}

// ── 한국어 이름표 ────────────────────────────────────────────────────────────────

const rarityLabels = {
  'superstar': '슈퍼스타',
  'star': '스타',
  'normal': '노멀',
  'regular': '레귤러',
  'legacy': '레거시',
  'promo': '프로모',
  'special': '스페셜',
  'ultra_beast': '울트라비스트',
  'super_treasure': '슈퍼 트레저',
  'treasure': '트레저',
  'wonder': '원더',
  'shiny': '이로치',
  'parallel': '패럴렐',
};

/// 등급 순서 (필터 시트 · 정렬)
const rarityOrder = [
  'superstar',
  'super_treasure',
  'star',
  'treasure',
  'normal',
  'regular',
  'ultra_beast',
  'legacy',
  'wonder',
  'special',
  'promo',
];

const typeLabels = {
  'Normal': '노말',
  'Fire': '불꽃',
  'Water': '물',
  'Electric': '전기',
  'Grass': '풀',
  'Ice': '얼음',
  'Fighting': '격투',
  'Poison': '독',
  'Ground': '땅',
  'Flying': '비행',
  'Psychic': '에스퍼',
  'Bug': '벌레',
  'Rock': '바위',
  'Ghost': '고스트',
  'Dragon': '드래곤',
  'Dark': '악',
  'Steel': '강철',
  'Fairy': '페어리',
};

const _seriesLabels = {
  'stardust': '스타더스트',
  'galaxy': '갤럭시',
  'base': '',
  'supertag': '슈퍼태그',
  'doublechain': '더블체인',
  'gorgeousstar': '고저스스타',
};

/// 찾기 글자: 소문자 · 띄어쓰기 · 가운뎃점 없앰
String normalizeQuery(String s) => s.toLowerCase().replaceAll(RegExp(r'[\s·・]+'), '');

/// 그림이 없는 칸 (프렌다 · 위키에만 있는 판) — 도감 번호의 공식 아트워크 (PokeAPI sprites)
String dexArtwork(int dex) => dex <= 0
    ? ''
    : 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/$dex.png';

/// 중국어 이름: 간체 먼저, 없으면 번체 (대만판 공식 이름)
String _zhName(Map<String, Object?> names) {
  for (final l in const ['zh', 'zh_hans', 'zh_hant']) {
    final s = jStr(names[l]).trim();
    if (s.isNotEmpty) return s;
  }
  return '';
}

/// 탄 이름의 중국어판 — 데이터 중국어 → '3탄' 같은 번호만인 것 → 영어 이름 ('' = 한국어 이름을 번역 표로)
String _setZh(Map<String, Object?> names, String ko, {bool promo = false}) {
  final zh = _zhName(names);
  if (zh.isNotEmpty) return zh;
  if (promo) return '';
  final no = RegExp(r'^(\d+)탄$').firstMatch(ko);
  if (no != null) return '第${no.group(1)}弹';
  return jStr(names['en']).trim();
}

String _koName(Map<String, Object?> names) {
  for (final l in const ['ko', 'ja', 'en', 'zh_hant']) {
    final s = jStr(names[l]).trim();
    if (s.isNotEmpty) return s;
  }
  return '';
}

int? _grade(Object? v) => v is num ? v.toInt() : null;

String _setNo(String id) => RegExp(r'(\d+)$').firstMatch(id)?.group(1) ?? '';

String _search(Iterable<Object?> parts) => normalizeQuery(parts.whereType<String>().join(' '));

// ── 메자스타 (intl · jp 같은 모양) ────────────────────────────────────────────────

/// mezastar-intl.json / mezastar-jp.json → [region] 의 도감
TagBook parseMezastar(Object? json, TagRegion region) {
  final root = jMap(json);
  final cards = <TagCard>[];
  for (final raw in jList(root['tags'])) {
    final t = jMap(raw);
    final names = jMap(t['names']);
    final tagSets = jList(t['sets']).whereType<String>().toList();
    final serial = jStr(t['serial']);
    final tagId = jStr(t['id']);
    final suffix = tagId.substring(tagId.indexOf(':') + 1);
    // 공식 번호가 없는 프로모(P-<포켓몬>-<캠페인>)는 'P' 만 — 캠페인은 variant 로
    final number = jStr(t['code']).isNotEmpty
        ? jStr(t['code'])
        : serial.length > 1
        ? serial
        : (suffix.startsWith('P-') && !RegExp(r'^P-\d+$').hasMatch(suffix) ? 'P' : suffix);
    final campaign = jStr(t['promo_campaign']);
    for (final pRaw in jList(t['printings'])) {
      final p = jMap(pRaw);
      if (jStr(p['region']) != region.code) continue;
      final id = jStr(p['id']);
      if (id.isEmpty) continue;
      final pSets = jList(p['sets']).whereType<String>().toList();
      final variant = jStr(p['variant']).isNotEmpty ? jStr(p['variant']) : campaign;
      final image = [p['img_thumb'], p['img_front']].map(jStr).firstWhere((s) => s.isNotEmpty, orElse: () => '');
      final large = [p['img_front'], p['img_back']].map(jStr).where((s) => s.isNotEmpty).toList();
      cards.add(
        TagCard(
          id: id,
          tagId: tagId,
          game: TagGame.mezastar,
          region: region.id,
          number: number,
          name: _koName(names),
          nameZh: _zhName(names),
          local: jStr(p['name']),
          setIds: pSets.isNotEmpty ? pSets : tagSets,
          searchText: _search([...names.values, p['name'], number, serial, tagId, variant]),
          rarity: jStr(t['grade_group']),
          grade: _grade(t['grade']),
          types: jList(t['types']).whereType<String>().toList(),
          image: image.isNotEmpty ? image : dexArtwork(jInt(t['dex'])),
          large: large,
          url: jStr(p['url']),
          dex: jInt(t['dex']),
          variant: variant,
        ),
      );
    }
  }
  final sets = <TagSet>[];
  for (final raw in jList(root['sets'])) {
    final s = jMap(raw);
    final id = jStr(s['id']);
    if (!cards.any((c) => c.setIds.contains(id))) continue; // 이 지역에 안 나온 탄
    final names = jMap(s['names']);
    final releases = [for (final r in jList(s['releases'])) jMap(r)];
    final mine =
        releases.where((r) => jStr(r['region']) == region.code).firstOrNull ?? releases.firstOrNull ?? const {};
    final series = jStr(s['series']);
    final promo = series == 'promo';
    final ko = jStr(names['ko']).replaceFirst('스타태그 ', '');
    final name = ko.isNotEmpty
        ? ko
        : promo
        ? '프로모 태그'
        : '${_seriesLabels[series] ?? series} ${_setNo(id)}탄'.trim();
    sets.add(
      TagSet(
        id: id,
        name: name,
        nameZh: _setZh(names, name, promo: promo),
        local: jStr(mine['local_name']).isNotEmpty ? jStr(mine['local_name']) : jStr(names['ja']),
        date: jStr(mine['date']),
        ordinal: jInt(s['ordinal']),
        extra: promo,
      ),
    );
  }
  sets.sort((a, b) => a.ordinal.compareTo(b.ordinal));
  final main = sets.where((s) => !s.extra).toList();
  // 서포트 포켓몬 티켓 (한국 — 공식 사이트 htp13 에 지금 있는 것 · 예전 것). 태그처럼 좋아요 · 구매함 (id mz-support:KR:…).
  // 기술 이름은 그 지역 이름 줄에, 타입은 공식 아이콘으로. 공식 그림이 없는 예전 티켓은 그 포켓몬의 공식 아트워크
  for (final (statuses, setId, setName) in const [
    ({'current'}, 'mz-support:current', '서포트 포켓몬 티켓'),
    ({'past', 'retired'}, 'mz-support:retired', '서포트 포켓몬 티켓 · 이전'),
  ]) {
    final tickets = [
      for (final raw in jList(root['support_tickets']))
        if (jStr(jMap(raw)['region']) == region.code && statuses.contains(jStr(jMap(raw)['status']))) jMap(raw),
    ];
    if (tickets.isEmpty) continue;
    sets.add(TagSet(id: setId, name: setName, extra: true, ordinal: 1000 + sets.length));
    for (final t in tickets) {
      final id = jStr(t['id']);
      final name = jStr(t['name']);
      final move = jStr(t['move']);
      final official = jStr(t['image']);
      final image = official.isNotEmpty ? official : dexArtwork(jInt(t['dex']));
      cards.add(
        TagCard(
          id: id,
          tagId: id,
          game: TagGame.mezastar,
          region: region.id,
          number: '',
          name: name,
          local: move,
          setIds: [setId],
          searchText: _search([name, move, '서포트', '티켓']),
          rarity: '',
          grade: null,
          types: [if (jStr(t['type']).isNotEmpty) jStr(t['type'])],
          image: image,
          large: [image],
          url: jStr(t['url']),
          dex: jInt(t['dex']),
          variant: statuses.contains('current') ? '' : (official.isEmpty ? '이전 탄 · 그림은 공식 아트워크' : '이전 탄'),
        ),
      );
    }
  }
  return TagBook(
    game: TagGame.mezastar,
    region: region,
    sets: sets,
    cards: cards,
    defaultSet: main.isEmpty ? sets.firstOrNull?.id : main.last.id,
  );
}

// ── 프렌다 ───────────────────────────────────────────────────────────────────────

TagBook parseFrienda(Object? json) {
  final root = jMap(json);
  final cards = <TagCard>[];
  for (final raw in jList(root['picks'])) {
    final p = jMap(raw);
    final id = jStr(p['id']);
    if (id.isEmpty) continue;
    final names = jMap(p['names']);
    final no = jStr(p['no']);
    final number = no.length > 1 ? no : id.substring(id.indexOf(':') + 1);
    final kind = jStr(p['kind']);
    final rarity = jStr(p['rarity']).isNotEmpty ? jStr(p['rarity']) : kind;
    // 데이터엔 그림이 없다 — 공식 사이트 약관이 그림 직링크를 삼가 달라고 해서 Gunpula 가 넣지 않는다
    // (https://pokemonfrienda.com/policy/). 앱이 이 기기에서 공식 페이지를 읽어 입힌다 (lib/data/frienda_images.dart), 그 전엔 포켓몬 공식 아트워크
    final image = [
      p['thumb'],
      p['img_thumb'],
      p['img'],
      p['img_front'],
    ].map(jStr).firstWhere((s) => s.isNotEmpty, orElse: () => '');
    final variant = [p['variant'], p['art']].map(jText).where((s) => s.isNotEmpty).join(' · ');
    cards.add(
      TagCard(
        id: id,
        tagId: id,
        game: TagGame.frienda,
        region: friendaRegion.id,
        number: number,
        name: _koName(names),
        nameZh: _zhName(names),
        local: jStr(names['ja']),
        setIds: [jStr(p['set'])],
        searchText: _search([...names.values, number, no, id, variant]),
        rarity: rarity,
        grade: _grade(p['grade']),
        types: jList(p['types']).whereType<String>().toList(),
        image: image.isNotEmpty ? image : dexArtwork(jInt(p['dex'])),
        large: [p['img']].map(jStr).where((s) => s.isNotEmpty).toList(),
        url: jStr(p['url']),
        dex: jInt(p['dex']),
        variant: variant,
      ),
    );
  }
  final sets = <TagSet>[];
  for (final raw in jList(root['sets'])) {
    final s = jMap(raw);
    final id = jStr(s['id']);
    final names = jMap(s['names']);
    final kind = jStr(s['kind']);
    final ko = jStr(names['ko']).replaceAll(RegExp(r'\s*\(.*\)$'), '');
    sets.add(
      TagSet(
        id: id,
        name: ko.isNotEmpty ? ko : _koName(names),
        nameZh: _setZh(names, ko.isNotEmpty ? ko : _koName(names)),
        local: jStr(names['ja']),
        date: jStr(s['release_date']),
        ordinal: jInt(s['ordinal']) == 0 ? 1000 + sets.length : jInt(s['ordinal']),
        extra: kind.isNotEmpty && kind != 'main',
      ),
    );
  }
  sets.sort((a, b) => a.ordinal.compareTo(b.ordinal));
  final latest = jStr(jMap(root['latest'])['set']);
  final main = sets.where((s) => !s.extra).toList();
  return TagBook(
    game: TagGame.frienda,
    region: friendaRegion,
    sets: sets,
    cards: cards,
    defaultSet: sets.any((s) => s.id == latest) ? latest : (main.isEmpty ? sets.firstOrNull?.id : main.last.id),
  );
}

// ── 불러오기 ──────────────────────────────────────────────────────────────────────

/// 보조 파일 읽기 (기본: Catalog.aux — 기기 캐시, 없으면 Pages 에서 바로)
typedef AtlasSource = Future<Object?> Function(String file);

class TagAtlas {
  TagAtlas._();

  /// 테스트에서 바꿔 끼운다 (fixtures)
  static AtlasSource source = Catalog.instance.aux;

  static final Map<String, (Object?, TagBook)> _cache = {};

  /// 그 게임 · 지역 도감. 파일이 없으면 오류
  static Future<TagBook> book(TagGame game, TagRegion region) async {
    final raw = await source(region.file);
    if (raw == null) throw CatalogException(tr('태그 데이터를 받지 못했어요.'));
    final key = '${game.name}/${region.id}';
    final hit = _cache[key];
    if (hit != null && identical(hit.$1, raw)) return hit.$2;
    final b = game == TagGame.frienda ? parseFrienda(raw) : parseMezastar(raw, region);
    _cache[key] = (raw, b);
    return b;
  }

  /// 메자스타 4지역 + 프렌다 (검색 탭). 못 읽은 것은 건너뛴다
  static Future<List<TagBook>> all() async {
    final out = <TagBook>[];
    for (final g in TagGame.values) {
      for (final r in g.regions) {
        try {
          out.add(await book(g, r));
        } on Object {
          // 그 파일만 건너뛴다
        }
      }
    }
    return out;
  }
}

// ── 검색 탭 ───────────────────────────────────────────────────────────────────────

const _gameWords = {
  TagGame.mezastar: ['메자스타', '태그스타', '스타태그', 'mezastar', 'tagstar', 'メザスタ', '寶可夢mezastar'],
  TagGame.frienda: ['프렌다', 'frienda', 'フレンダ', '프렌다픽'],
};

/// 검색어 속 게임 이름 → (그 게임, 이름을 뺀 나머지 검색어). 게임 이름이 없으면 null
(TagGame, String)? gameInQuery(String query) {
  final q = normalizeQuery(query);
  if (q.isEmpty) return null;
  for (final e in _gameWords.entries) {
    for (final w in e.value) {
      if (q.contains(w)) return (e.key, normalizeQuery(q.replaceFirst(w, '')));
      if (q.length >= 3 && w.startsWith(q)) return (e.key, ''); // 쓰는 중 (메자스 · fried)
    }
  }
  return null;
}

/// 모든 도감에서 [query] 에 맞는 칸 (같은 태그의 지역 인쇄는 지역 순서대로 모두)
List<TagCard> searchTags(List<TagBook> books, String query, {int limit = 60}) {
  final inGame = gameInQuery(query);
  final q = inGame?.$2 ?? normalizeQuery(query);
  if (q.isEmpty) return const [];
  final out = <TagCard>[];
  for (final b in books) {
    if (inGame != null && b.game != inGame.$1) continue;
    for (final c in b.cards) {
      if (c.searchText.contains(q)) {
        out.add(c);
        if (out.length >= limit) return out;
      }
    }
  }
  return out;
}
