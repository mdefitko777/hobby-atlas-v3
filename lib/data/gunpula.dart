// Gunpula 데이터(GitHub Pages) → 앱 모델용 가벼운 Map.
// 여기 함수는 compute() 안(다른 isolate)에서도 돌아가야 해서 Flutter 위젯 · 전역 상태를 쓰지 않는다.
import 'dart:convert';

/// Gunpula 저장소의 Pages 주소. 데이터는 data/, 이미지는 app/assets/
const gunpulaBase = 'https://mdefitko777.github.io/Gunpula/';

/// Pages 가 안 될 때만 (raw 는 kits.json 을 압축하지 않으니 split 만 받는다)
const gunpulaRawBase = 'https://raw.githubusercontent.com/mdefitko777/Gunpula/main/';

/// 매일 갱신되는 순서대로 받는 파일들 (kits.json · search-index.json 은 받지 않는다).
/// 새 소식 피드는 여기서 받지 않는다 — 알림 확인(lib/background/catalog_check_worker.dart)이 manifest 가 바뀔 때 한 번만 받는다.
const franchiseIds = ['gundam', 'beyblade', 'pokemon', 'armored_core', 'fate'];
const auxFiles = [
  'grades.json',
  'kit-first-seen.json',
  'announcements.json',
  'atlas-groups.json',
  'gget-units.json',
  'gget-kit-map.json',
  'gget-series-sections.json',
  'bbx-database.json',
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

String _str(Object? v) => v is String ? v : '';
Map<String, Object?> _map(Object? v) => v is Map<String, Object?> ? v : const {};
List<Object?> _list(Object? v) => v is List ? v : const [];

/// 4개 언어 이름 중 [order] 순서로 처음 있는 것
String pickName(Object? names, [List<String> order = const ['ko', 'ja', 'en', 'zh']]) {
  final m = _map(names);
  for (final l in order) {
    final s = _str(m[l]).trim();
    if (s.isNotEmpty) return s;
  }
  return '';
}

// ── 제품 라인 · 상품 유형 (grades.json 에는 한국어 이름이 없다) ────────────────
const _lineLabels = {
  'GUNDAM_MERCH': '가샤폰 굿즈',
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

String typeLabel(String code, String category) {
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

/// compute() 작업: `split/kits-<franchise>.json` 한 개 → Kit.fromSlim 이 읽는 Map 목록
/// msg = {raw, grades, firstSeen} (모두 JSON 글자)
List<Map<String, Object?>> mapKitsJob(Map<String, String> msg) {
  final kits = _list(_map(jsonDecode(msg['raw']!))['kits']);
  final grades = {
    for (final g in _list(_map(jsonDecode(msg['grades'] ?? '{}'))['grades']))
      if (_str(_map(g)['code']).isNotEmpty) _str(_map(g)['code']): _str(_map(g)['category']),
  };
  final firstSeen = _map(_map(jsonDecode(msg['firstSeen'] ?? '{}'))['dates']);
  final out = <Map<String, Object?>>[];
  for (final raw in kits) {
    final r = _map(raw);
    final id = _str(r['kit_id']);
    if (id.isEmpty) continue;
    final names = _map(r['names']);
    final series = _map(r['series']);
    final labels = _map(series['labels']);
    final code = _str(r['grade_code']);
    final subline = _str(r['subline']);
    final sourceUrls = _list(r['source_urls']).whereType<String>().toList();
    final images = _map(r['images']);
    final box = resolveAsset(images['box_art_url']);
    final gallery = <String>[
      for (final g in _list(r['gallery_image_urls']))
        if (resolveAsset(g) case final u when u.isNotEmpty && !deadImage(u)) u,
    ];
    final cover = (box.isNotEmpty && !deadImage(box)) ? box : (gallery.isEmpty ? '' : gallery.first);
    final jan = findJan([id, ...sourceUrls, _str(r['number']), _str(images['box_art_url'])]);
    final pb = r['is_premium_bandai'] == true;
    final brands = <String>{
      for (final s in _list(r['source_refs']))
        ?_brandBySource[_str(_map(s)['source_id'])],
      if (pb) '프리미엄 반다이',
    }.toList();
    final pbInfo = _map(r['premium_bandai']);
    final name = pickName(names);
    final nameJa = pickName(names, const ['ja', 'en', 'ko']);
    final seriesLabel = pickName(labels);
    final line = lineLabel(code, subline, id);
    final type = typeLabel(code, grades[code] ?? '');
    final keywords = <String>{
      _str(names['en']),
      _str(names['zh']),
      _str(labels['ja']),
      _str(labels['en']),
      _str(labels['zh']),
      _str(r['work_title']),
      code,
      subline,
      if (jan.isNotEmpty) jan,
      ...brands,
    }.where((s) => s.isNotEmpty).toList();
    out.add({
      'id': id,
      'franchiseId': _str(r['franchise']),
      'name': name,
      'nameJa': nameJa == name ? '' : nameJa,
      'series': seriesLabel,
      'seriesKey': _str(series['key']),
      'line': line,
      'type': type,
      'scale': _str(r['scale']) == 'non-scale' ? '' : _str(r['scale']),
      'universe': _str(r['universe']),
      'date': _str(r['release_date']),
      'priceJpy': r['price_jpy'] is num ? (r['price_jpy']! as num).toInt() : null,
      'priceKrw': r['price_krw'] is num ? (r['price_krw']! as num).toInt() : null,
      'image': cover,
      'gallery': [
        if (cover.isNotEmpty) cover,
        for (final g in gallery)
          if (g != cover) g,
      ].take(10).toList(),
      'limited': r['is_limited'] == true,
      'pb': pb,
      'pbOpens': _str(pbInfo['order_opens_at']).split('T').first,
      'pbCloses': _str(pbInfo['order_closes_at']).split('T').first,
      'officialUrl': sourceUrls.isEmpty ? '' : sourceUrls.first,
      'jan': jan,
      'brands': brands,
      'firstSeen': _str(firstSeen[id]),
      'keywords': keywords,
      'blob': [name, nameJa, seriesLabel, line, type, ...keywords].join(' ').toLowerCase(),
    });
  }
  return out;
}
