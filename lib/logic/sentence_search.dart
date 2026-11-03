// 설명으로 찾기 (검색 B-5 · B-6, 사진 찾기 E) — AI 가 아니라 낱말 맞추기.
//   1) 문장을 고친다: 소문자 · 전각 → 반각
//   2) 아래 낱말 표(색 · 작품 · 라인 · 종류 · 채널 · 기체/캐릭터 별명)에서 한국어 · 일본어 · 영어 표기를 찾아 뜻 하나로 묶는다
//   3) 표에 없는 나머지 낱말은 조사를 떼고 그대로 상품 글자(이름 4개 언어 · 작품 · 라인 · 종류 · 키워드)에서 찾는다
//   4) 상품마다 맞은 낱말의 무게 / 전체 무게 = 일치도 %, 맞은 낱말 = 이유
// Flutter 위젯을 쓰지 않는다 (단위 테스트).
import '../models.dart';

/// 낱말 표의 한 뜻
enum ConceptField { name, series, line, type, franchise }

class Concept {
  const Concept(
    this.label,
    this.terms, {
    this.field = ConceptField.name,
    this.needles = const [],
    this.weight = 2,
    this.hint = '',
  });

  /// 이유에 보일 이름
  final String label;

  /// 문장에서 찾는 표기 (소문자)
  final List<String> terms;
  final ConceptField field;

  /// 상품에서 찾는 글자 (비면 [terms]). series = series_key, franchise = 채널 id
  final List<String> needles;
  final double weight;

  /// 이 말이 나오면 그 채널 상품만 (자쿠 → 건담, 피카츄 → 포켓몬). 비면 채널을 가리지 않는다
  final String hint;

  List<String> get look => needles.isEmpty ? terms : needles;
}

const _color = 1.0;

/// 낱말 표 — 짧게 유지한다. 이름 쪽은 한국어 이름이 없는(일본어만 있는) 상품도 찾히게 표기를 모은다.
const sentenceConcepts = <Concept>[
  // ── 색 ──
  Concept(
    '흰색',
    ['하얀', '흰색', '흰', '화이트', 'white', '白', 'ホワイト'],
    needles: ['white', 'ホワイト', '白', '화이트', '흰'],
    weight: _color,
  ),
  Concept('검정', ['검은', '검정', '까만', '블랙', 'black', '黒', 'ブラック'], needles: ['black', 'ブラック', '黒', '블랙'], weight: _color),
  Concept('빨강', ['빨간', '빨강', '붉은', '레드', 'red', '赤', 'レッド'], needles: ['red', 'レッド', '赤', '레드', '빨간'], weight: _color),
  Concept(
    '파랑',
    ['파란', '파랑', '푸른', '블루', 'blue', '青', 'ブルー'],
    needles: ['blue', 'ブルー', '青', '블루', '파란'],
    weight: _color,
  ),
  Concept('초록', ['초록', '녹색', '그린', 'green', '緑', 'グリーン'], needles: ['green', 'グリーン', '緑', '그린'], weight: _color),
  Concept('노랑', ['노란', '노랑', '옐로', 'yellow', '黄', 'イエロー'], needles: ['yellow', 'イエロー', '黄', '옐로'], weight: _color),
  Concept('금색', ['금색', '골드', '황금', 'gold', '金', 'ゴールド'], needles: ['gold', 'ゴールド', '金', '골드'], weight: _color),
  Concept('은색', ['은색', '실버', 'silver', '銀', 'シルバー'], needles: ['silver', 'シルバー', '銀', '실버'], weight: _color),
  Concept('분홍', ['분홍', '핑크', 'pink', 'ピンク'], needles: ['pink', 'ピンク', '핑크'], weight: _color),
  Concept('보라', ['보라', '퍼플', 'purple', '紫', 'パープル'], needles: ['purple', 'パープル', '紫', '퍼플'], weight: _color),
  Concept('투명', ['투명', '클리어', 'clear', 'クリア'], needles: ['clear', 'クリア', '클리어'], weight: _color),
  Concept(
    '메탈',
    ['메탈릭', '메탈', '도금', '코팅', 'metallic', 'メタリック', 'メッキ', 'コーティング'],
    needles: ['metal', 'メタリック', 'メッキ', 'コーティング', '메탈', '코팅'],
    weight: _color,
  ),
  // ── 생김새 · 별명 (이름에 들어가는 말) ──
  Concept('날개', ['날개', 'wing', 'ウイング', 'ウィング', '翼'], needles: ['wing', 'ウイング', 'ウィング', '翼', '윙', '날개']),
  Concept(
    '드래곤',
    ['드래곤', '드라군', '용 모양', 'dragon', 'ドラゴン', 'ドラン', '竜', '龍'],
    needles: ['dragon', 'ドラゴン', 'ドラン', 'ドラグーン', '竜', '龍', '드래곤', '드랜', '드라군', 'dran'],
  ),
  Concept('자쿠', ['자쿠', 'zaku', 'ザク'], needles: ['zaku', 'ザク', '자쿠'], hint: 'gundam'),
  Concept(
    '건담 Mk-II',
    ['마크투', '마크2', 'mk-ii', 'mk2'],
    needles: ['mk-ii', 'mk-2', 'mk-ⅱ', 'マークii', 'マークⅱ', '마크 ii', '마크2'],
    hint: 'gundam',
  ),
  Concept('프리덤', ['프리덤', 'freedom', 'フリーダム'], needles: ['freedom', 'フリーダム', '프리덤'], hint: 'gundam'),
  Concept('스트라이크', ['스트라이크', 'strike', 'ストライク'], needles: ['strike', 'ストライク', '스트라이크']),
  Concept('저스티스', ['저스티스', 'justice', 'ジャスティス'], needles: ['justice', 'ジャスティス', '저스티스'], hint: 'gundam'),
  Concept('에어리얼', ['에어리얼', 'aerial', 'エアリアル'], needles: ['aerial', 'エアリアル', '에어리얼'], hint: 'gundam'),
  Concept('바르바토스', ['바르바토스', '발바토스', 'barbatos', 'バルバトス'], needles: ['barbatos', 'バルバトス', '바르바토스'], hint: 'gundam'),
  Concept('엑시아', ['엑시아', 'exia', 'エクシア'], needles: ['exia', 'エクシア', '엑시아'], hint: 'gundam'),
  Concept('사자비', ['사자비', 'sazabi', 'サザビー'], needles: ['sazabi', 'サザビー', '사자비'], hint: 'gundam'),
  Concept(
    'ν건담',
    ['뉴건담', 'ν건담', 'νガンダム', 'nu gundam', 'hi-ν', '하이뉴'],
    needles: ['ν', 'hi-ν', '뉴 건담', '뉴건담'],
    hint: 'gundam',
  ),
  Concept('샤아', ['샤아', '샤아 전용', 'char', 'シャア'], needles: ['シャア', 'char', '샤아'], hint: 'gundam'),
  Concept('피카츄', ['피카츄', 'pikachu', 'ピカチュウ'], needles: ['pikachu', 'ピカチュウ', '피카츄'], hint: 'pokemon'),
  Concept('이브이', ['이브이', 'eevee', 'イーブイ'], needles: ['eevee', 'イーブイ', '이브이'], hint: 'pokemon'),
  Concept(
    '잠자는',
    ['자고 있는', '자는', '잠자는', '잠든', 'sleep', 'おやすみ', 'すやすや', '寝'],
    needles: ['sleep', 'おやすみ', 'すやすや', '寝', '잠', '자는'],
  ),
  Concept('세이버', ['세이버', 'saber', 'セイバー'], needles: ['saber', 'セイバー', '세이버']),
  Concept('블레이드', ['블레이드', 'blade', 'ブレード'], needles: ['blade', 'ブレード', '블레이드']),
  // ── 작품 (건담 series_key) ──
  Concept('SEED', ['seed', '시드', 'シード'], field: ConceptField.series, needles: ['seed']),
  Concept('00', ['더블오', '00', 'oo', 'ダブルオー'], field: ConceptField.series, needles: ['double_o']),
  Concept('초대', ['퍼스트', '초대', '0079', 'ファースト'], field: ConceptField.series, needles: ['uc_first']),
  Concept('Z', ['제타', 'zeta', 'zガンダム', 'z건담'], field: ConceptField.series, needles: ['zeta']),
  Concept('ZZ', ['더블제타', 'zz'], field: ConceptField.series, needles: ['zz']),
  Concept('UC', ['유니콘', 'unicorn', 'ユニコーン'], field: ConceptField.series, needles: ['unicorn']),
  Concept('역샤', ['역습의 샤아', '역샤', 'cca', '逆襲のシャア'], field: ConceptField.series, needles: ['cca']),
  Concept('W', ['건담 w', '건담w', 'gundam w', 'ガンダムw'], field: ConceptField.series, needles: ['w']),
  Concept('빌드', ['빌드', 'build', 'ビルド'], field: ConceptField.series, needles: ['build']),
  Concept('철혈', ['철혈', '오펀스', 'iron-blooded', '鉄血'], field: ConceptField.series, needles: ['ibo']),
  Concept(
    '수성',
    ['수성의 마녀', '수성', '水星', 'witch from mercury', 'mercury'],
    field: ConceptField.series,
    needles: ['witch'],
  ),
  Concept('하사웨이', ['섬광의 하사웨이', '하사웨이', '섬하사', 'hathaway', 'ハサウェイ'], field: ConceptField.series, needles: ['hathaway']),
  Concept('GQuuuuuuX', ['지쿠악스', 'gquuuuuux', 'gqux', 'ジークアクス'], field: ConceptField.series, needles: ['gqux']),
  Concept('AGE', ['에이지', 'gundam age', '건담 age'], field: ConceptField.series, needles: ['age']),
  Concept('G', ['g건담', '건담 g', 'gガンダム'], field: ConceptField.series, needles: ['g']),
  Concept('크로스본', ['크로스본', 'crossbone', 'クロスボーン'], field: ConceptField.series, needles: ['crossbone']),
  Concept('Origin', ['오리진', 'origin', 'オリジン'], field: ConceptField.series, needles: ['origin']),
  Concept('썬더볼트', ['썬더볼트', 'thunderbolt', 'サンダーボルト'], field: ConceptField.series, needles: ['thunderbolt']),
  Concept('턴에이', ['턴에이', '∀', 'turn a'], field: ConceptField.series, needles: ['turn_a']),
  Concept('F91', ['f91'], field: ConceptField.series, needles: ['f91']),
  Concept('0083', ['0083'], field: ConceptField.series, needles: ['0083']),
  Concept('0080', ['0080'], field: ConceptField.series, needles: ['0080']),
  Concept('08소대', ['08소대', '08ms'], field: ConceptField.series, needles: ['08ms']),
  // ── 제품 라인 (Kit.line, 앞부분이 같으면 — MG 는 MGEX · MGSD 도) ──
  Concept('HG', ['hg', '하이그레이드', 'high grade', 'ハイグレード'], field: ConceptField.line, needles: ['hg']),
  Concept('RG', ['rg', '리얼그레이드', 'real grade', 'リアルグレード'], field: ConceptField.line, needles: ['rg']),
  Concept('MG', ['mg', '마스터그레이드', 'master grade', 'マスターグレード'], field: ConceptField.line, needles: ['mg']),
  Concept('PG', ['pg', '퍼펙트그레이드', 'perfect grade', 'パーフェクトグレード'], field: ConceptField.line, needles: ['pg']),
  Concept('SD', ['sd', 'sdcs', 'bb전사'], field: ConceptField.line, needles: ['sd']),
  Concept('EG', ['eg', '엔트리그레이드', 'entry grade'], field: ConceptField.line, needles: ['eg']),
  Concept('METAL BUILD', ['메탈빌드', '메탈 빌드', 'metal build'], field: ConceptField.line, needles: ['metal build']),
  Concept('ROBOT魂', ['로봇혼', '로봇 혼', 'robot魂', 'robot spirits'], field: ConceptField.line, needles: ['robot魂']),
  Concept('30MM', ['30mm'], field: ConceptField.line, needles: ['30mm']),
  Concept('넨도로이드', ['넨도로이드', '넨도', 'nendoroid', 'ねんどろいど'], field: ConceptField.line, needles: ['넨도로이드']),
  Concept('figma', ['figma', '피그마'], field: ConceptField.line, needles: ['figma']),
  Concept('포켓프라', ['포켓프라', 'pokepla', 'ポケプラ'], field: ConceptField.line, needles: ['포켓프라']),
  Concept('BX', ['bx'], field: ConceptField.line, needles: ['bx']),
  Concept('UX', ['ux'], field: ConceptField.line, needles: ['ux']),
  Concept('CX', ['cx'], field: ConceptField.line, needles: ['cx']),
  // ── 상품 유형 (Kit.type) ──
  Concept(
    '프라모델',
    ['프라모델', '프라', '건프라', '조립', 'plastic model', 'プラモデル', 'プラモ', 'ガンプラ'],
    field: ConceptField.type,
    needles: ['프라모델'],
    weight: 1.5,
  ),
  Concept('피규어', ['피규어', '피겨', 'figure', 'フィギュア'], field: ConceptField.type, needles: ['피규어', '액션'], weight: 1.5),
  Concept('인형', ['인형', '봉제', '봉제인형', 'plush', 'ぬいぐるみ'], field: ConceptField.type, needles: ['인형'], weight: 1.5),
  Concept(
    '가샤폰',
    ['가샤폰', '가챠', '캡슐토이', 'gashapon', 'ガシャポン', 'ガチャ'],
    field: ConceptField.type,
    needles: ['가샤폰'],
    weight: 1.5,
  ),
  Concept('카드', ['카드', 'card', 'カード'], field: ConceptField.type, needles: ['카드'], weight: 1.5),
  Concept('굿즈', ['굿즈', 'goods', 'グッズ'], field: ConceptField.type, needles: ['굿즈'], weight: 1.5),
  // ── 채널 (넓은 말이라 가볍게) ──
  Concept('건담', ['건담', 'gundam', 'ガンダム'], field: ConceptField.franchise, needles: ['gundam'], weight: 0.5),
  Concept(
    '포켓몬',
    ['포켓몬', 'pokemon', 'pokémon', 'ポケモン'],
    field: ConceptField.franchise,
    needles: ['pokemon'],
    weight: 0.5,
  ),
  Concept(
    '베이블레이드',
    ['베이블레이드', '베이', 'beyblade', 'ベイブレード'],
    field: ConceptField.franchise,
    needles: ['beyblade'],
    weight: 0.5,
  ),
  Concept('Fate', ['페이트', 'fate'], field: ConceptField.franchise, needles: ['fate'], weight: 0.5),
  Concept(
    '마도카 마기카',
    ['마도카', '마마마', 'madoka', 'まどか', 'まどマギ'],
    field: ConceptField.franchise,
    needles: ['madoka'],
    weight: 0.5,
  ),
  Concept(
    '아머드 코어',
    ['아머드 코어', '아머드코어', 'armored core', 'アーマード・コア'],
    field: ConceptField.franchise,
    needles: ['armored_core'],
    weight: 0.5,
  ),
];

/// 뜻이 없는 말 (문장에서 버림)
const _stopWords = {
  '달린',
  '달려',
  '있는',
  '있고',
  '같은',
  '같이',
  '비슷한',
  '느낌',
  '모양',
  '모양의',
  '생긴',
  '들고',
  '입은',
  '하는',
  '나오는',
  '것',
  '거',
  '그',
  '이거',
  '저거',
  '좀',
  '찾아줘',
  '찾아',
  '주세요',
  '줘',
  '아주',
  '엄청',
  '조금',
  '그리고',
  '또는',
  '랑',
  '하고',
  'the',
  'a',
  'an',
  'with',
  'of',
  'and',
  'in',
};

/// 낱말 끝 조사 (떼고 남는 게 2글자 이상일 때만)
const _particles = ['으로', '에서', '이랑', '하고', '처럼', '이', '가', '은', '는', '을', '를', '의', '에', '로', '와', '과', '랑', '도', '만'];

/// 전각 영숫자 → 반각, 소문자
String normalizeSentence(String s) =>
    String.fromCharCodes([for (final c in s.runes) c >= 0xFF01 && c <= 0xFF5E ? c - 0xFEE0 : c]).toLowerCase();

final _asciiWord = RegExp(r'^[a-z0-9\-]+$');
final _split = RegExp(r'[\s,./!?·・、。()（）\[\]「」『』"“”]+');

/// 문장에서 찾은 것: 표의 뜻 + 나머지 낱말
class SentenceQuery {
  const SentenceQuery(this.concepts, this.words);
  final List<Concept> concepts;
  final List<String> words;

  int get size => concepts.length + words.length;
  double get totalWeight => concepts.fold<double>(0, (s, c) => s + c.weight) + words.length * _wordWeight;
}

const _wordWeight = 2.0;

SentenceQuery parseSentence(String sentence) {
  var text = ' ${normalizeSentence(sentence)} ';
  final found = <Concept>[];
  // 긴 표기부터 (예: "역습의 샤아" 를 "샤아" 보다 먼저)
  final terms = [
    for (final c in sentenceConcepts)
      for (final t in c.terms) (c, t),
  ]..sort((a, b) => b.$2.length.compareTo(a.$2.length));
  for (final (c, t) in terms) {
    final re = _asciiWord.hasMatch(t)
        ? RegExp('(?<![a-z0-9])${RegExp.escape(t)}(?![a-z0-9])')
        : RegExp(RegExp.escape(t));
    if (!re.hasMatch(text)) continue;
    text = text.replaceAll(re, ' ');
    if (!found.contains(c)) found.add(c);
  }
  final words = <String>[];
  for (var w in text.split(_split)) {
    if (w.isEmpty || _stopWords.contains(w)) continue;
    for (final p in _particles) {
      if (w.endsWith(p) && w.length - p.length >= 2) {
        w = w.substring(0, w.length - p.length);
        break;
      }
    }
    if (w.length < 2 || _stopWords.contains(w) || words.contains(w)) continue;
    words.add(w);
  }
  return SentenceQuery(found, words);
}

/// 후보 하나: 상품 · 일치도(0–100) · 맞은 낱말
class SentenceHit {
  const SentenceHit(this.kit, this.score, this.matched);
  final Kit kit;
  final int score;
  final List<String> matched;

  String get reason => matched.join(' · ');
}

/// 상품 글자 (소문자 한 줄) — 실제 데이터는 미리 만든 blob, 테스트용 가짜 상품은 칸을 이어 붙인다
String _hay(Kit k) =>
    k.blob.isNotEmpty ? k.blob : [k.name, k.nameJa, k.series, k.line, k.type, ...k.keywords].join(' ').toLowerCase();

bool _hits(Concept c, Kit k, String hay) => switch (c.field) {
  ConceptField.name => c.look.any((n) => hay.contains(n.toLowerCase())),
  ConceptField.series =>
    c.look.contains(k.seriesKey) || (k.seriesKey.isEmpty && c.terms.any((t) => k.series.toLowerCase().contains(t))),
  ConceptField.line => c.look.any((n) => k.line.toLowerCase().startsWith(n)),
  ConceptField.type => c.look.any((n) => k.type.contains(n)),
  ConceptField.franchise => c.look.contains(k.franchiseId),
};

/// 문장 → 후보 (일치도 높은 것부터, 같으면 발매일 새것부터). 맞은 것이 채널뿐인 상품은 뺀다.
/// [minWords] 보다 낱말이 적으면(그냥 이름 검색) 빈 목록.
List<SentenceHit> sentenceSearch(String sentence, Iterable<Kit> kits, {int limit = 5, int minWords = 2}) {
  final q = parseSentence(sentence);
  if (q.size < minWords) return const [];
  final total = q.totalWeight;
  final only = {
    for (final c in q.concepts)
      if (c.hint.isNotEmpty) c.hint,
  };
  final hits = <SentenceHit>[];
  for (final k in kits) {
    if (only.isNotEmpty && !only.contains(k.franchiseId)) continue;
    final hay = _hay(k);
    var got = 0.0;
    var strong = false;
    final matched = <String>[];
    for (final c in q.concepts) {
      if (_hits(c, k, hay)) {
        got += c.weight;
        matched.add(c.label);
        if (c.field != ConceptField.franchise) strong = true;
      }
    }
    for (final w in q.words) {
      if (hay.contains(w)) {
        got += _wordWeight;
        matched.add(w);
        strong = true;
      }
    }
    if (!strong) continue;
    hits.add(SentenceHit(k, (got / total * 100).round().clamp(1, 100), matched));
  }
  hits.sort((a, b) {
    final s = b.score.compareTo(a.score);
    if (s != 0) return s;
    // 같은 점수면 굿즈(이펙트 · 아크릴 …)보다 본품, 그다음 발매일 새것
    final g = (a.kit.type == '굿즈' ? 1 : 0).compareTo(b.kit.type == '굿즈' ? 1 : 0);
    return g != 0 ? g : b.kit.date.compareTo(a.kit.date);
  });
  return hits.take(limit).toList();
}
