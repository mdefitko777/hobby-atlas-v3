// 검색 탭 종류 · 세대 둘러보기 규칙 (순수 Dart) — 상품 카탈로그처럼 "분류 칸 = 공식 그림 + 이름"
//   종류: 채널 상품 → 칸 키(라인 · 굿즈 세부 종류 · 베이 상품 형태) → 채널마다 정한 묶음(프라모델 · SD · 완성품 …)
//   세대: 건담 = 작품을 시대 묶음으로, 그 밖 = atlas 묶음(세대 · 작품)을 채널마다 정한 묶음으로
//   세부 시리즈: 상품 화면 위 줄 (HGUC · HGCE … · PB 한정)
import '../models.dart';

/// 작은 칸을 모으는 이름 (같은 묶음 안 끝)
const lineOtherKey = '기타';

/// 굿즈 종류 칸이 이보다 작으면 [lineOtherKey] 로 모은다 (작은 칸이 둘 이상일 때만)
const lineMinGroup = 3;

/// 세부 시리즈 줄의 PB 칸
const pbChoice = 'PB 한정';

/// 굿즈 라인 안에서 따로 세우는 유형 (상품 이름으로 가른 것, lib/data/gunpula.dart typeLabel)
const _goodsLineSplit = {'가샤폰', '카드'};

/// 키 → 보이는 이름 (라인 코드 그대로인 것만 다듬는다)
const _labels = {'RE100': 'RE/100', 'PGU': 'PG UNLEASHED'};

String lineGroupLabel(String key) => _labels[key] ?? key;

/// 상품 하나의 종류 칸 키: 굿즈 세부 종류 > 굿즈 라인 안의 가샤폰 · 카드 > 라인 > 유형 > 기타
String lineGroupKey(Kit k) {
  if (k.goodsKind.isNotEmpty) return k.goodsKind == lineOtherKey ? (k.line.isEmpty ? '굿즈' : k.line) : k.goodsKind;
  if (k.line == '굿즈' && _goodsLineSplit.contains(k.type)) return k.type;
  if (k.line.isNotEmpty) return k.line;
  return k.type.isNotEmpty ? k.type : lineOtherKey;
}

/// 채널별 칸 키 — 베이블레이드 X 는 라인(BX · UX · CX = 세대 쪽)이 아니라 상품 형태(스타터 · 부스터 …)
String typeKeyOf(String channel, Kit k) => channel == 'beyblade' && k.subline.isNotEmpty ? k.subline : lineGroupKey(k);

/// 발매일 새것부터 (발매일 없는 것은 끝), 같으면 이름
int newestFirst(Kit a, Kit b) {
  if (a.date.isEmpty != b.date.isEmpty) return a.date.isEmpty ? 1 : -1;
  final c = b.date.compareTo(a.date);
  return c != 0 ? c : a.name.compareTo(b.name);
}

/// 사진이 있는 가장 새 상품의 그림 (참고 그림보다 제 사진 먼저) — [sorted] 는 새것부터
String newestCover(List<Kit> sorted) =>
    sorted.where((k) => k.image.isNotEmpty && !k.imageRef).firstOrNull?.image ??
    sorted.where((k) => k.image.isNotEmpty).firstOrNull?.image ??
    '';

// ── 종류 묶음 ─────────────────────────────────────────────────────────────

/// 묶음 정의: 이름 · 칸 순서 · 목록에 없는 칸을 받을 상품 유형 · 작은 칸 모으기
class _Sec {
  const _Sec(this.title, this.keys, {this.types = const {}, this.merge = false});
  final String title;
  final List<String> keys;
  final Set<String> types;

  /// true = 굿즈 종류처럼 작은 칸을 기타로 모은다 (공식 라인은 작아도 그대로)
  final bool merge;
}

const _goods = _Sec(
  '굿즈',
  ['굿즈', '카드', '카드 게임', '의류', '생활용품', '아크릴', '문구', '액세서리', '식품', '공구 · 재료'],
  types: {'굿즈', '카드'},
  merge: true,
);
const _media = _Sec('영상 · 책 · 이벤트', ['티켓 · 이벤트', '블루레이 · DVD', '음반', '책 · 화보', '팸플릿', '게임', '보드게임'], merge: true);

/// 채널마다 종류 묶음 (위에서 아래 순서). 없는 채널 = 한 묶음 '종류'
const _typeSectionDefs = <String, List<_Sec>>{
  'gundam': [
    _Sec(
      '프라모델',
      ['PG', 'PGU', 'MG', 'MGEX', 'RG', 'HG', 'EG', 'RE100', 'FM', 'Hi-Resolution Model', 'MEGA', '옵션 파츠'],
      types: {'프라모델'},
    ),
    _Sec('옛 등급 · 특수', ['No Grade', 'AG', 'FG', 'BMC', 'EX', 'HY2M', 'UCHG', 'HAROPLA']),
    _Sec('SD', ['MGSD', 'SD', 'SDW', 'SDEX', 'SDCS', 'BB', '元祖 SD']),
    _Sec(
      '완성품 피규어',
      [
        'ROBOT魂',
        'METAL BUILD',
        'METAL ROBOT魂',
        'S.H.Figuarts',
        'Figuarts mini',
        'GUNDAM FIX FIGURATION',
        'GUNDAM UNIVERSE',
        'METAL STRUCTURE',
        '超合金',
        'NXEDGE STYLE',
        'SDX',
        '魂 기타',
      ],
      types: {'피규어'},
    ),
    _Sec(
      '식완 · 가샤폰',
      ['G FRAME FA', 'CONVERGE', 'MS 앙상블', '가샤폰 전사 f', 'MOBILITY JOINT', '건담 아티팩트', 'Superior Define', '가샤폰'],
      types: {'식완', '가샤폰'},
    ),
    _goods,
    _media,
  ],
  'pokemon': [
    _Sec('인형 · 피규어', ['봉제인형', '몬콜레', '피규어', '포켓프라'], types: {'인형', '피규어', '프라모델'}),
    _Sec('가샤폰 · 경품 · 복권', ['가샤폰', '경품', '제일복권'], types: {'가샤폰', '식완', '경품', '제일복권'}),
    _goods,
    _media,
  ],
  'fate': [
    _Sec('피규어 · 인형', ['스케일', '넨도로이드', 'figma', '액션 피규어', '미니 · 트레이딩', '인형'], types: {'피규어', '액션', '인형'}),
    _Sec('경품 · 가샤폰 · 복권', ['경품', '가샤폰', '제일복권'], types: {'경품', '가샤폰', '식완', '제일복권'}),
    _goods,
    _media,
  ],
  'armored_core': [
    _Sec('프라모델', ['V.I.', '30MM', 'SMP'], types: {'프라모델'}),
    _Sec('식완 · 가샤폰', ['식완'], types: {'식완', '가샤폰'}),
    _goods,
    _media,
  ],
  'beyblade': [
    _Sec('베이', ['스타터', '부스터', '랜덤 부스터'], types: {'배틀 토이'}),
    _Sec('세트 · 도구', ['세트', '런처 · 도구'], types: {'툴'}),
    _goods,
    _media,
  ],
};

/// 종류 칸 하나 — 상품(새것부터) · 대표 그림 (공식 로고는 화면이 lineCovers 에서 먼저 찾는다)
class TypeEntry {
  const TypeEntry({required this.key, required this.label, required this.kits, required this.cover});

  /// 채널 안에서 하나뿐인 키 (lineCovers 의 키 = 라인 이름, 모은 칸 = '묶음/기타')
  final String key;
  final String label;
  final List<Kit> kits;
  final String cover;
}

/// 종류 묶음 하나 (빈 묶음은 만들지 않는다)
class TypeSection {
  const TypeSection(this.title, this.entries);
  final String title;
  final List<TypeEntry> entries;
}

/// 채널 상품 → 종류 묶음 (정해진 순서, 빈 칸 · 빈 묶음 없음)
List<TypeSection> typeSections(String channel, Iterable<Kit> kits, {int minGroup = lineMinGroup}) {
  final defs = _typeSectionDefs[channel] ?? const [_Sec('종류', [])];
  final byKey = <String, List<Kit>>{};
  for (final k in kits) {
    (byKey[typeKeyOf(channel, k)] ??= []).add(k);
  }
  // 칸 → 묶음: 정해진 키 → 상품 유형(가장 많은 유형) → 기타 묶음
  final listed = {
    for (final (i, d) in defs.indexed)
      for (final key in d.keys) key: i,
  };
  final other = defs.length; // 맨 끝 '기타' 묶음
  final bySec = <int, List<String>>{};
  for (final e in byKey.entries) {
    var i = listed[e.key];
    if (i == null) {
      final type = _mostCommon(e.value.map((k) => k.type));
      final hit = defs.indexWhere((d) => d.types.contains(type));
      i = hit >= 0 ? hit : (_typeSectionDefs.containsKey(channel) ? other : 0);
    }
    (bySec[i] ??= []).add(e.key);
  }
  final out = <TypeSection>[];
  for (var i = 0; i <= defs.length; i++) {
    final keys = bySec[i];
    if (keys == null) continue;
    final def = i < defs.length ? defs[i] : const _Sec(lineOtherKey, []);
    // 작은 칸 모으기: 굿즈 종류 · 목록에 없는 칸만 (공식 라인은 작아도 제 칸)
    final small = [
      for (final key in keys)
        if (byKey[key]!.length < minGroup && (def.merge || !listed.containsKey(key))) key,
    ];
    final merged = <Kit>[];
    if (small.length >= 2) {
      for (final key in small) {
        keys.remove(key);
        merged.addAll(byKey[key]!);
      }
    }
    int rank(String key) {
      final r = def.keys.indexOf(key);
      return r >= 0 ? r : def.keys.length;
    }

    keys.sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      if (r != 0) return r;
      final n = byKey[b]!.length.compareTo(byKey[a]!.length);
      return n != 0 ? n : a.compareTo(b);
    });
    TypeEntry entry(String key, String label, List<Kit> list) {
      final sorted = [...list]..sort(newestFirst);
      return TypeEntry(key: key, label: label, kits: sorted, cover: newestCover(sorted));
    }

    out.add(
      TypeSection(def.title, [
        for (final key in keys) entry(key, lineGroupLabel(key), byKey[key]!),
        if (merged.isNotEmpty) entry('${def.title}/$lineOtherKey', lineOtherKey, merged),
      ]),
    );
  }
  return out;
}

String _mostCommon(Iterable<String> values) {
  final n = <String, int>{};
  for (final v in values) {
    n[v] = (n[v] ?? 0) + 1;
  }
  return n.entries.fold<MapEntry<String, int>?>(null, (b, e) => b == null || e.value > b.value ? e : b)?.key ?? '';
}

// ── 세부 시리즈 ──────────────────────────────────────────────────────────

/// 상품 화면 위 줄: 상품 2개 이상인 세부 시리즈(많은 순) + PB 상품이 있으면 [pbChoice]. 고를 것이 없으면 빈 목록
List<String> sublineChoices(List<Kit> kits) {
  final n = <String, int>{};
  for (final k in kits) {
    if (k.subline.isNotEmpty) n[k.subline] = (n[k.subline] ?? 0) + 1;
  }
  final subs = [
    for (final e in n.entries)
      if (e.value >= 2) e.key,
  ]..sort((a, b) => n[b]!.compareTo(n[a]!) != 0 ? n[b]!.compareTo(n[a]!) : a.compareTo(b));
  // 세부 시리즈가 하나뿐이고 모든 상품이 그것이면 고를 의미가 없다
  if (subs.length == 1 && n[subs.first] == kits.length) subs.clear();
  return [...subs, if (kits.any((k) => k.pb)) pbChoice];
}

/// [choice] 칸의 상품 ('' = 전체)
List<Kit> kitsOfChoice(List<Kit> kits, String choice) => switch (choice) {
  '' => kits,
  pbChoice => [
    for (final k in kits)
      if (k.pb) k,
  ],
  _ => [
    for (final k in kits)
      if (k.subline == choice) k,
  ],
};

// ── 세대 묶음 ─────────────────────────────────────────────────────────────

/// 건담 작품 → 시대 묶음 (작품 순서 그대로, 시대는 처음 나온 순서)
List<(String, List<GuideWork>)> workSections(Iterable<GuideWork> works) {
  final out = <(String, List<GuideWork>)>[];
  for (final w in works) {
    final i = out.indexWhere((s) => s.$1 == w.section);
    i >= 0 ? out[i].$2.add(w) : out.add((w.section, [w]));
  }
  return out;
}

/// Fate atlas 묶음 id(채널 머리 뺀 것) → 묶음 순서 · 이름
const _fateSections = ['Fate 시리즈', 'FGO 1부 · 1.5부', 'FGO 2부 · 주장', 'FGO 이벤트 · 굿즈', 'TYPE-MOON · 기타'];
const _typeMoon = {'tsukihime', 'kara_no_kyoukai', 'mahoyo', 'type_moon', 'fate_general'};

String _fateSection(String id) {
  final m = RegExp(r'^fgo_(\d)\d\d$').firstMatch(id);
  if (m != null) return int.parse(m.group(1)!) <= 2 ? _fateSections[1] : _fateSections[2];
  if (id.startsWith('fgo_')) return _fateSections[3];
  return _typeMoon.contains(id) ? _fateSections[4] : _fateSections[0];
}

/// 채널의 세대 묶음 이름 (World.id = '<채널>-<묶음 id>')
String worldSectionOf(String channel, String worldId) {
  final id = worldId.startsWith('$channel-') ? worldId.substring(channel.length + 1) : worldId;
  return switch (channel) {
    'pokemon' => RegExp(r'^gen\d+$').hasMatch(id) ? '본편 세대' : '공통 굿즈',
    'fate' => _fateSection(id),
    'armored_core' => '시리즈',
    'beyblade' => '라인',
    _ => '세대',
  };
}

/// 세대 묶음들 → 묶음 순서대로 (Fate 는 정한 순서, 그 밖은 처음 나온 순서 · 묶음 안은 받은 순서)
List<(String, List<T>)> worldSections<T>(String channel, Iterable<T> items, String Function(T) idOf) {
  final out = <(String, List<T>)>[];
  for (final w in items) {
    final s = worldSectionOf(channel, idOf(w));
    final i = out.indexWhere((x) => x.$1 == s);
    i >= 0 ? out[i].$2.add(w) : out.add((s, [w]));
  }
  if (channel == 'fate') out.sort((a, b) => _fateSections.indexOf(a.$1).compareTo(_fateSections.indexOf(b.$1)));
  return out;
}

/// 베이 세대 묶음(World id 'beyblade-bx')의 상품 = 라인이 같은 상품 (World.kitIds 가 비어 있을 때)
bool beyInWorld(Kit k, String worldId) => worldId == 'beyblade-${k.line.toLowerCase()}';
