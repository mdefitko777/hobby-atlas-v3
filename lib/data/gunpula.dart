// Gunpula 데이터(GitHub Pages) → 앱 모델용 가벼운 Map.
// 여기 함수는 compute() 안(다른 isolate)에서도 돌아가야 해서 Flutter 위젯 · 전역 상태를 쓰지 않는다.
import 'dart:convert';
import '../json_util.dart';
import '../logic/url_lookup.dart' show isListingUrl;
import 'gundam_atlas.dart' show atlasBoxartFile, atlasChaptersFile, atlasKitMsFile, atlasMsFile;

/// Gunpula 저장소의 Pages 주소. 데이터는 data/, 이미지는 app/assets/
const gunpulaBase = 'https://mdefitko777.github.io/Gunpula/';

/// Pages 가 안 될 때만 (raw 는 kits.json 을 압축하지 않으니 split 만 받는다)
const gunpulaRawBase = 'https://raw.githubusercontent.com/mdefitko777/Gunpula/main/';

/// Gunpula · 공식 페이지(프렌다 그림)에 보내는 User-Agent — Hobby Atlas 데이터 작업들과 같은 봇 이름 (브라우저인 척하지 않는다 · 웹은 바꿀 수 없다)
const gunpulaUserAgent = 'HobbyAtlasDataBot/1.0 (+https://github.com/mdefitko777/Gunpula)';

/// 매일 갱신되는 순서대로 받는 파일들 (kits.json · search-index.json 은 받지 않는다).
/// 새 소식 피드는 여기서 받지 않는다 — 알림 확인(lib/background/catalog_check_worker.dart)이 manifest 가 바뀔 때 한 번만 받는다.
const franchiseIds = ['gundam', 'beyblade', 'pokemon', 'armored_core', 'fate'];

/// 예전에 받던 건담 도감 파일 (gget) — 기기 캐시에서 지운다
const retiredAuxFiles = ['gget-units.json', 'gget-kit-map.json', 'gget-series-sections.json'];

/// 매핑(compute)에만 쓰고 기기에 따로 두지 않는 보조 파일
const mapOnlyAuxFiles = {'grades.json', 'kit-first-seen.json', atlasBoxartFile};

const auxFiles = [
  'grades.json',
  'kit-first-seen.json',
  'announcements.json',
  'atlas-groups.json',
  // 건담 도감 (lib/data/gundam_atlas.dart): MS 마스터 · 상품↔MS 연결 · 박스 아트(매핑 때만)
  atlasMsFile,
  atlasKitMsFile,
  atlasBoxartFile,
  atlasChaptersFile, // 화수 · 장 묶음 + 기체 종류 (없으면 404 → 그 보기만 숨김)
  'bbx-database.json',
  // 합쳐진 · 빠진 kit_id (Gunpula 정리 때 생김) — 저장된 기록을 남은 상품으로 옮긴다
  'kit-aliases.json',
  // 엔 → 원 (구매가를 안 적은 상품은 정가 × 환율로 지출에 넣는다)
  'exchange-rates.json',
  // 포켓몬 메자스타 (한국 · 홍콩 · 대만 / 일본) · 프렌다 태그 도감 (lib/data/tag_atlas.dart)
  'atlas/mezastar-intl.json',
  'atlas/mezastar-jp.json',
  'atlas/pokemon-frienda.json',
  // 재판매(再販) 소식 — Gunpula 작업 중 (없으면 404 → 상세 · 캘린더의 재판매 칸만 숨김, lib/data/restocks.dart)
  'atlas/restocks.json',
];

/// `./assets/…` · `../app/assets/…` 처럼 Gunpula 웹앱 기준 상대 경로 → 전체 주소
String resolveAsset(Object? url) {
  if (url is! String || url.isEmpty) return '';
  if (url.startsWith('http')) return url;
  var u = url;
  if (u.startsWith('./')) u = u.substring(2);
  while (u.startsWith('../')) {
    u = u.substring(3);
  }
  return u.startsWith('app/') ? '$gunpulaBase$u' : '${gunpulaBase}app/$u';
}

/// 실제로 열어 보면 죽어 있는 이미지 주소 (Gunpula 실측: 403 · 503 · 가짜 도메인 · 만료된 서명)
bool deadImage(String url) =>
    url.contains('internal-pbn') ||
    url.contains('Expires=') ||
    url.contains('www.goodsmile.com') ||
    url.contains('bandai-hobby.net') ||
    url.contains('pokemon.hgodo.com');

/// 4개 언어 이름 중 [order] 순서로 처음 있는 것
String pickName(Object? names, [List<String> order = const ['ko', 'ja', 'en', 'zh']]) {
  final m = jMap(names);
  for (final l in order) {
    final s = jStr(m[l]).trim();
    if (s.isNotEmpty) return s;
  }
  return '';
}

// ── 제품 라인 · 상품 유형 (grades.json 에는 한국어 이름이 없다) ────────────────
const _lineLabels = {
  'GUNDAM_MERCH': '굿즈',
  'ROBOT_SPIRITS': 'ROBOT魂',
  'NG': 'No Grade',
  'METAL_BUILD': 'METAL BUILD',
  'METAL_ROBOT': 'METAL ROBOT魂',
  'MSE': 'MS 앙상블',
  'CONVERGE': 'CONVERGE',
  'GSF': '가샤폰 전사 f',
  'GFRAME': 'G FRAME FA',
  'SH_FIGUARTS': 'S.H.Figuarts',
  'MOBILITY': 'MOBILITY JOINT',
  'ARTIFACT': '건담 아티팩트',
  'SUPERIOR': 'Superior Define',
  'FATE_GOODS': '굿즈',
  'FATE_SCALE': '스케일',
  'NENDOROID': '넨도로이드',
  'FATE_ACTION': '액션 피규어',
  'FATE_PRIZE': '경품',
  'FATE_GASHAPON': '가샤폰',
  'ICHIBAN_KUJI': '제일복권',
  'POKE_PLUSH': '봉제인형',
  'POKE_GASHAPON': '가샤폰',
  'POKE_GOODS': '굿즈',
  'POKE_MONCOLLE': '몬콜레',
  'POKE_FIGURE': '피규어',
  'POKEPLA': '포켓프라',
  'POKE_PRIZE': '경품',
  'POKE_KUJI': '제일복권',
  'ACVI': 'V.I.',
  'AC30MM': '30MM',
  'AC_SMP': 'SMP',
  'AC_SHOKUGAN': '식완',
};

String lineLabel(String code, String subline, String kitId) {
  if (code == 'BEYBLADE_X') {
    // beyblade-x-bx36 → BX · UX · CX
    final m = RegExp(r'^beyblade-x-([a-z]+)\d').firstMatch(kitId);
    if (m != null) return m.group(1)!.toUpperCase();
    return subline.replaceFirst('BEYBLADE X ', '');
  }
  if (code == 'FATE_ACTION' && subline == 'figma') return 'figma';
  return _lineLabels[code] ?? code;
}

// 이름으로 가르는 상품 종류 — 굿즈 묶음(GUNDAM_MERCH · *_GOODS)에 카드 · 진짜 가샤폰이 섞여 있다
const _cardWords = ['カードダス', 'ウエハース', 'カードゲーム', 'カード', 'トレカ', 'TCG', '카드팩', '카드 게임'];
const _capsuleWords = ['ガシャポン', 'ガチャ', 'カプセル', '가샤폰', '캡슐'];
bool _hasAny(String name, List<String> words) => words.any(name.contains);

/// 굿즈 세부 종류 (Gunpula 레코드 goods_kind) → 한국어
const goodsKindLabels = {
  'ticket': '티켓 · 이벤트',
  'apparel': '의류',
  'household': '생활용품',
  'stationery': '문구',
  'acrylic': '아크릴',
  'accessory': '액세서리',
  'media_video': '블루레이 · DVD',
  'media_audio': '음반',
  'book': '책 · 화보',
  'pamphlet': '팸플릿',
  'food': '식품',
  'video_game': '게임',
  'board_game': '보드게임',
  'card_game': '카드 게임',
  'hobby_supply': '공구 · 재료',
  'other': '기타',
};

/// 상품 유형. [name] 은 일본어 이름 + 한국어 이름 (카드 · 가샤폰 낱말을 찾는다)
String typeLabel(String code, String category, [String name = '']) {
  // 가샤폰 = 캡슐 장난감만, 카드팩 · 웨하스 = 카드, 나머지 굿즈 (상품 이름이 묶음 코드보다 정확하다)
  if (_hasAny(name, _cardWords)) return '카드';
  if (code == 'GUNDAM_MERCH' || code.endsWith('_GOODS')) return _hasAny(name, _capsuleWords) ? '가샤폰' : '굿즈';
  switch (code) {
    case 'POKE_PLUSH':
      return '인형';
    case 'ICHIBAN_KUJI' || 'POKE_KUJI':
      return '제일복권';
    case 'FATE_PRIZE' || 'POKE_PRIZE':
      return '경품';
    case 'POKE_MONCOLLE' || 'POKE_FIGURE':
      return '피규어';
    case 'FATE_ACTION':
      return '액션';
  }
  return switch (category) {
    'core' || 'core_subline' || 'one_hundred' || 'sd' || 'historical' || 'special' || 'plastic_model' => '프라모델',
    'tamashii_figure' => '피규어',
    'shokugan' => '식완',
    'gashapon' => '가샤폰',
    'battle_toy' => '배틀 토이',
    _ => '굿즈',
  };
}

// ── 브랜드 (데이터에 제조사 칸이 없어 출처 사이트로 추정) ─────────────────────
const _brandBySource = {
  'bandai_spirits_products_jp': 'BANDAI SPIRITS',
  'bandai_hobby_pokemon_global': 'BANDAI SPIRITS',
  'bandai_hobby_pokemon_satellite': 'BANDAI SPIRITS',
  'tamashii_web_jp': 'TAMASHII NATIONS',
  'tamashii_web_fate_jp': 'TAMASHII NATIONS',
  'p_bandai_jp': '프리미엄 반다이',
  'p_bandai_wayback': '프리미엄 반다이',
  'banpresto_prize_jp': 'BANPRESTO',
  'banpresto_prize_fate_jp': 'BANPRESTO',
  'ichiban_kuji_jp': 'BANPRESTO',
  'ichiban_kuji_fate_jp': 'BANPRESTO',
  'kotobukiya_armored_core_jp': 'KOTOBUKIYA',
  'kotobukiya_fate_jp': 'KOTOBUKIYA',
  'good_smile_fate_en': 'Good Smile',
  'good_smile_fate_global': 'Good Smile',
  'good_smile_global': 'Good Smile',
  'takara_tomy_pokemon_jp': 'TAKARA TOMY',
  'takara_tomy_beyblade_x_jp': 'TAKARA TOMY',
  'pokemon_center_jp': '포켓몬센터',
  'pokemon_store_kr': '포켓몬센터',
  'aniplex_plus_fate_jp': 'Aniplex',
  'bandai_gashapon_products_jp': '반다이 가샤폰',
  'bandai_gashapon_gundam_jp': '반다이 가샤폰',
  'bandai_candy_gundam_jp': '반다이 캔디',
  'bandai_candy_jp': '반다이 캔디',
};

// ── JAN (바코드) — kit_id · 공식 주소 · 품번 · 사진 파일명에 숨어 있는 13자리 ─────
final _janRe = RegExp(r'(?<!\d)(4[59]\d{11})(?:000)?(?!\d)');

bool _eanOk(String s) {
  var t = 0;
  for (var i = 0; i < 12; i++) {
    t += (s.codeUnitAt(i) - 48) * (i.isOdd ? 3 : 1);
  }
  return (10 - t % 10) % 10 == s.codeUnitAt(12) - 48;
}

String findJan(Iterable<String> texts) {
  for (final s in texts) {
    for (final m in _janRe.allMatches(s)) {
      if (_eanOk(m.group(1)!)) return m.group(1)!;
    }
  }
  return '';
}

/// 박스 아트 한 개 (data/atlas/gundam-boxart.json)
/// kind '' = 상자 그림, 'dp' = 가샤폰 대지(세트 그림) → 대표 사진. 'maybe' = 확실하지 않음 → 사진 목록 끝에만.
typedef BoxArt = ({String url, String kind});

Map<String, BoxArt> parseBoxart(Object? json) => {
  for (final e in jMap(jMap(json)['boxart']).entries)
    if (resolveAsset(jMap(e.value)['url']) case final u when u.isNotEmpty && !deadImage(u))
      e.key: (url: u, kind: jStr(jMap(e.value)['kind'])),
};

/// 대표 사진 · 사진 목록 정하기 — 박스 아트가 있으면 그것이 먼저, 원래 대표 사진은 두 번째로 남긴다
({String cover, List<String> gallery}) pickCover({required String box, required List<String> gallery, BoxArt? art}) {
  final old = (box.isNotEmpty && !deadImage(box)) ? box : (gallery.isEmpty ? '' : gallery.first);
  final main = art != null && art.kind != 'maybe';
  final cover = main ? art.url : old;
  return (
    cover: cover,
    gallery: <String>{
      if (cover.isNotEmpty) cover,
      if (old.isNotEmpty) old,
      ...gallery,
      if (art != null && !main) art.url,
    }.take(10).toList(),
  );
}

/// compute() 작업: `split/kits-<franchise>.json` 한 개 → Kit.fromSlim 이 읽는 Map 목록
/// msg = {raw, grades, firstSeen, boxart?} (모두 JSON 글자 · boxart 는 건담만)
List<Map<String, Object?>> mapKitsJob(Map<String, String> msg) {
  final kits = jList(jMap(jsonDecode(msg['raw']!))['kits']);
  final boxart = msg['boxart'] == null ? const <String, BoxArt>{} : parseBoxart(jsonDecode(msg['boxart']!));
  final grades = {
    for (final g in jList(jMap(jsonDecode(msg['grades'] ?? '{}'))['grades']))
      if (jStr(jMap(g)['code']).isNotEmpty) jStr(jMap(g)['code']): jStr(jMap(g)['category']),
  };
  final firstSeen = jMap(jMap(jsonDecode(msg['firstSeen'] ?? '{}'))['dates']);
  final out = <Map<String, Object?>>[];
  for (final raw in kits) {
    final r = jMap(raw);
    final id = jStr(r['kit_id']);
    if (id.isEmpty) continue;
    final names = jMap(r['names']);
    final series = jMap(r['series']);
    final labels = jMap(series['labels']);
    final code = jStr(r['grade_code']);
    final subline = jStr(r['subline']);
    final sourceUrls = jList(r['source_urls']).whereType<String>().toList();
    final images = jMap(r['images']);
    final box = resolveAsset(images['box_art_url']);
    final gallery = <String>[
      for (final g in jList(r['gallery_image_urls']))
        if (resolveAsset(g) case final u when u.isNotEmpty && !deadImage(u)) u,
    ];
    final pick = pickCover(box: box, gallery: gallery, art: boxart[id]);
    final cover = pick.cover;
    final jan = findJan([id, ...sourceUrls, jStr(r['number']), jStr(images['box_art_url'])]);
    final pb = r['is_premium_bandai'] == true;
    final brands = <String>{
      for (final s in jList(r['source_refs'])) ?_brandBySource[jStr(jMap(s)['source_id'])],
      if (pb) '프리미엄 반다이',
    }.toList();
    final pbInfo = jMap(r['premium_bandai']);
    final name = pickName(names);
    final nameJa = pickName(names, const ['ja', 'en', 'ko']);
    final seriesLabel = pickName(labels);
    final line = lineLabel(code, subline, id);
    final goodsKind = jStr(r['goods_kind']);
    final type = goodsKind.isEmpty
        ? typeLabel(code, grades[code] ?? '', '${jStr(names['ja'])} ${jStr(names['ko'])}')
        : (goodsKind == 'card_game' ? '카드' : '굿즈');
    final keywords = <String>{
      jStr(names['en']),
      jStr(names['zh']),
      jStr(labels['ja']),
      jStr(labels['en']),
      jStr(labels['zh']),
      jStr(r['work_title']),
      code,
      subline,
      if (jan.isNotEmpty) jan,
      ...brands,
    }.where((s) => s.isNotEmpty).toList();
    out.add({
      'id': id,
      'franchiseId': jStr(r['franchise']),
      'name': name,
      'nameJa': nameJa == name ? '' : nameJa,
      'series': seriesLabel,
      'seriesKey': jStr(series['key']),
      'line': line,
      'type': type,
      'scale': jStr(r['scale']) == 'non-scale' ? '' : jStr(r['scale']),
      'universe': jStr(r['universe']),
      'date': jStr(r['release_date']),
      'priceJpy': r['price_jpy'] is num ? (r['price_jpy']! as num).toInt() : null,
      'priceKrw': r['price_krw'] is num ? (r['price_krw']! as num).toInt() : null,
      'image': cover,
      'gallery': pick.gallery,
      'limited': r['is_limited'] == true,
      'pb': pb,
      'pbOpens': jStr(pbInfo['order_opens_at']).split('T').first,
      'pbCloses': jStr(pbInfo['order_closes_at']).split('T').first,
      'officialUrl': sourceUrls.isEmpty ? '' : sourceUrls.first,
      // 공유로 받은 주소 찾기 (lib/logic/url_lookup.dart) — 목록 · 검색 페이지는 상품 하나를 가리키지 않아 뺀다
      'sourceUrls': [
        for (final u in sourceUrls)
          if (!isListingUrl(u)) u,
      ],
      // 굿즈 세부 종류 (티켓 · 의류 · 블루레이 …) — 데이터에 있으면 유형은 굿즈(카드 게임은 카드)
      'goodsKind': goodsKindLabels[jStr(r['goods_kind'])] ?? '',
      'jan': jan,
      'brands': brands,
      'firstSeen': jStr(firstSeen[id]),
      'keywords': keywords,
      'blob': [name, nameJa, seriesLabel, line, type, ...keywords].join(' ').toLowerCase(),
    });
  }
  return out;
}
