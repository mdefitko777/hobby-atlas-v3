// 설명으로 찾기 (검색 B-5 · B-6, 사진 찾기 E) — AI 가 아니라 낱말 맞추기.
//   1) 문장을 고친다: 소문자 · 전각 → 반각
//   2) 아래 낱말 표(색 · 작품 · 라인 · 종류 · 채널 · 기체/캐릭터 별명)에서 한국어 · 일본어 · 영어 · 중국어 표기를 찾아 뜻 하나로 묶는다
//      (화면 언어와 상관없이 — 두 사람이 어느 말로 쳐도 같은 뜻)
//   3) 표에 없는 나머지 낱말은 조사를 떼고 그대로 상품 글자(이름 4개 언어 · 작품 · 라인 · 종류 · 키워드)에서 찾는다
//   4) 상품마다 맞은 낱말의 무게 / 전체 무게 = 일치도 %, 맞은 낱말 = 이유
// Flutter 위젯을 쓰지 않는다 (단위 테스트).
import '../l10n/l10n.dart';
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
/// 중국어 한 글자(红 · 金 · 粉 · 龙 …)는 [Concept.terms](문장 쪽)에만 — 상품 쪽 [Concept.needles] 에는 두 글자 이상만
/// (상품 글자에 중국어 이름이 들어 있어 奥伯龙 · 金属 · 闪粉 · 黑胶 가 드래곤 · 금색 · 분홍 · 검정으로 잡혔다, 2026-11-11 점검).
/// 문장 쪽 한 글자 한자도 띄어 쓴 낱말(또는 한 글자 한자 · 군말만으로 된 덩어리)일 때만 뜻으로 본다 — [_singleHanRun]
const sentenceConcepts = <Concept>[
  // ── 색 ──
  Concept(
    '흰색',
    ['하얀', '흰색', '흰', '화이트', 'white', '白', 'ホワイト', '白色'],
    needles: ['white', 'ホワイト', '白', '화이트', '흰'],
    weight: _color,
  ),
  Concept(
    '검정',
    ['검은', '검정', '까만', '블랙', 'black', '黒', 'ブラック', '黑色', '黑'],
    needles: ['black', 'ブラック', '黒', '블랙', '黑色'],
    weight: _color,
  ),
  Concept(
    '빨강',
    ['빨간', '빨강', '붉은', '레드', 'red', '赤', 'レッド', '红色', '红'],
    needles: ['red', 'レッド', '赤', '레드', '빨간', '红色'],
    weight: _color,
  ),
  Concept(
    '파랑',
    ['파란', '파랑', '푸른', '블루', 'blue', '青', 'ブルー', '蓝色', '蓝'],
    needles: ['blue', 'ブルー', '青', '블루', '파란', '蓝色'],
    weight: _color,
  ),
  Concept(
    '초록',
    ['초록', '녹색', '그린', 'green', '緑', 'グリーン', '绿色', '绿'],
    needles: ['green', 'グリーン', '緑', '그린', '绿色'],
    weight: _color,
  ),
  Concept(
    '노랑',
    ['노란', '노랑', '옐로', 'yellow', '黄', 'イエロー', '黄色'],
    needles: ['yellow', 'イエロー', '黄', '옐로'],
    weight: _color,
  ),
  Concept(
    '금색',
    ['금색', '골드', '황금', 'gold', '金', 'ゴールド', '金色', '黄金'],
    // 金 한 글자는 일본어 · 중국어 이름의 金属(메탈) · 金型 에도 있어 뺀다
    needles: ['gold', 'ゴールド', '金色', '黄金', '金メッキ', '镀金', '골드', '금색'],
    weight: _color,
  ),
  Concept(
    '은색',
    ['은색', '실버', 'silver', '銀', 'シルバー', '银色', '银'],
    needles: ['silver', 'シルバー', '銀', '실버', '银色'],
    weight: _color,
  ),
  Concept(
    '분홍',
    ['분홍', '핑크', 'pink', 'ピンク', '粉红色', '粉红', '粉色', '粉'],
    needles: ['pink', 'ピンク', '핑크', '粉色', '粉红'],
    weight: _color,
  ),
  Concept('보라', ['보라', '퍼플', 'purple', '紫', 'パープル', '紫色'], needles: ['purple', 'パープル', '紫', '퍼플'], weight: _color),
  Concept('투명', ['투명', '클리어', 'clear', 'クリア', '透明色', '透明'], needles: ['clear', 'クリア', '클리어', '透明'], weight: _color),
  Concept(
    '메탈',
    ['메탈릭', '메탈', '도금', '코팅', 'metallic', 'メタリック', 'メッキ', 'コーティング', '金属色', '金属', '电镀', '涂层'],
    needles: ['metal', 'メタリック', 'メッキ', 'コーティング', '메탈', '코팅', '金属', '电镀'],
    weight: _color,
  ),
  // ── 생김새 · 별명 (이름에 들어가는 말) ──
  Concept(
    '날개',
    ['날개', 'wing', 'ウイング', 'ウィング', '翼', '翅膀', '羽翼'],
    needles: ['wing', 'ウイング', 'ウィング', '翼', '윙', '날개', '翅膀'],
  ),
  Concept(
    '드래곤',
    ['드래곤', '드라군', '용 모양', 'dragon', 'ドラゴン', 'ドラン', '竜', '龍', '龙'],
    needles: ['dragon', 'ドラゴン', 'ドラン', 'ドラグーン', '竜', '龍', '드래곤', '드랜', '드라군', 'dran', '飞龙'],
  ),
  Concept('자쿠', ['자쿠', 'zaku', 'ザク', '扎古'], needles: ['zaku', 'ザク', '자쿠', '扎古'], hint: 'gundam'),
  Concept(
    '건담 Mk-II',
    ['마크투', '마크2', 'mk-ii', 'mk2', '马克二'],
    needles: ['mk-ii', 'mk-2', 'mk-ⅱ', 'マークii', 'マークⅱ', '마크 ii', '마크2'],
    hint: 'gundam',
  ),
  Concept('프리덤', ['프리덤', 'freedom', 'フリーダム', '自由高达', '自由'], needles: ['freedom', 'フリーダム', '프리덤', '自由'], hint: 'gundam'),
  Concept('스트라이크', ['스트라이크', 'strike', 'ストライク', '强袭'], needles: ['strike', 'ストライク', '스트라이크', '强袭']),
  Concept(
    '저스티스',
    ['저스티스', 'justice', 'ジャスティス', '正义高达', '正义'],
    needles: ['justice', 'ジャスティス', '저스티스', '正义'],
    hint: 'gundam',
  ),
  Concept('에어리얼', ['에어리얼', 'aerial', 'エアリアル', '风灵'], needles: ['aerial', 'エアリアル', '에어리얼', '风灵'], hint: 'gundam'),
  Concept(
    '바르바토스',
    ['바르바토스', '발바토스', 'barbatos', 'バルバトス', '巴巴托斯'],
    needles: ['barbatos', 'バルバトス', '바르바토스', '巴巴托斯'],
    hint: 'gundam',
  ),
  Concept('엑시아', ['엑시아', 'exia', 'エクシア', '能天使'], needles: ['exia', 'エクシア', '엑시아', '能天使'], hint: 'gundam'),
  Concept('사자비', ['사자비', 'sazabi', 'サザビー', '沙扎比'], needles: ['sazabi', 'サザビー', '사자비', '沙扎比'], hint: 'gundam'),
  Concept(
    'ν건담',
    ['뉴건담', 'ν건담', 'νガンダム', 'nu gundam', 'hi-ν', '하이뉴', 'ν高达', '牛高达'],
    needles: ['ν', 'hi-ν', '뉴 건담', '뉴건담', '牛高达'],
    hint: 'gundam',
  ),
  Concept('샤아', ['샤아', '샤아 전용', 'char', 'シャア', '夏亚专用', '夏亚'], needles: ['シャア', 'char', '샤아', '夏亚'], hint: 'gundam'),
  Concept('피카츄', ['피카츄', 'pikachu', 'ピカチュウ', '皮卡丘'], needles: ['pikachu', 'ピカチュウ', '피카츄', '皮卡丘'], hint: 'pokemon'),
  Concept('이브이', ['이브이', 'eevee', 'イーブイ', '伊布'], needles: ['eevee', 'イーブイ', '이브이', '伊布'], hint: 'pokemon'),
  Concept(
    '잠자는',
    ['자고 있는', '자는', '잠자는', '잠든', 'sleep', 'おやすみ', 'すやすや', '寝', '睡觉', '睡着', '睡姿', '睡'],
    needles: ['sleep', 'おやすみ', 'すやすや', '寝', '잠', '자는', '睡姿', '睡着', '熟睡', '睡觉'],
  ),
  Concept('세이버', ['세이버', 'saber', 'セイバー'], needles: ['saber', 'セイバー', '세이버']),
  Concept('블레이드', ['블레이드', 'blade', 'ブレード', '战刃'], needles: ['blade', 'ブレード', '블레이드']),
  // ── 작품 (건담 series_key) ──
  Concept('SEED', ['seed', '시드', 'シード', '种命'], field: ConceptField.series, needles: ['seed']),
  Concept('00', ['더블오', '00', 'oo', 'ダブルオー', '双零'], field: ConceptField.series, needles: ['double_o']),
  Concept('초대', ['퍼스트', '초대', '0079', 'ファースト', '初代'], field: ConceptField.series, needles: ['uc_first']),
  Concept('Z', ['제타', 'zeta', 'zガンダム', 'z건담', 'z高达'], field: ConceptField.series, needles: ['zeta']),
  Concept('ZZ', ['더블제타', 'zz'], field: ConceptField.series, needles: ['zz']),
  Concept('UC', ['유니콘', 'unicorn', 'ユニコーン', '独角兽'], field: ConceptField.series, needles: ['unicorn']),
  Concept('역샤', ['역습의 샤아', '역샤', 'cca', '逆襲のシャア', '逆袭的夏亚', '逆袭'], field: ConceptField.series, needles: ['cca']),
  Concept('W', ['건담 w', '건담w', 'gundam w', 'ガンダムw', '高达w'], field: ConceptField.series, needles: ['w']),
  Concept('빌드', ['빌드', 'build', 'ビルド', '创战者'], field: ConceptField.series, needles: ['build']),
  Concept('철혈', ['철혈', '오펀스', 'iron-blooded', '鉄血', '铁血'], field: ConceptField.series, needles: ['ibo']),
  Concept(
    '수성',
    ['수성의 마녀', '수성', '水星', 'witch from mercury', 'mercury', '水星的魔女'],
    field: ConceptField.series,
    needles: ['witch'],
  ),
  Concept(
    '하사웨이',
    ['섬광의 하사웨이', '하사웨이', '섬하사', 'hathaway', 'ハサウェイ', '闪光的哈萨维', '哈萨维'],
    field: ConceptField.series,
    needles: ['hathaway'],
  ),
  Concept('GQuuuuuuX', ['지쿠악스', 'gquuuuuux', 'gqux', 'ジークアクス'], field: ConceptField.series, needles: ['gqux']),
  Concept('AGE', ['에이지', 'gundam age', '건담 age', '高达age'], field: ConceptField.series, needles: ['age']),
  Concept('G', ['g건담', '건담 g', 'gガンダム', 'g高达'], field: ConceptField.series, needles: ['g']),
  Concept('크로스본', ['크로스본', 'crossbone', 'クロスボーン', '海盗高达', '骷髅'], field: ConceptField.series, needles: ['crossbone']),
  Concept('Origin', ['오리진', 'origin', 'オリジン', '起源'], field: ConceptField.series, needles: ['origin']),
  Concept('썬더볼트', ['썬더볼트', 'thunderbolt', 'サンダーボルト', '雷霆宙域'], field: ConceptField.series, needles: ['thunderbolt']),
  Concept('턴에이', ['턴에이', '∀', 'turn a'], field: ConceptField.series, needles: ['turn_a']),
  Concept('F91', ['f91'], field: ConceptField.series, needles: ['f91']),
  Concept('0083', ['0083'], field: ConceptField.series, needles: ['0083']),
  Concept('0080', ['0080'], field: ConceptField.series, needles: ['0080']),
  Concept('08소대', ['08소대', '08ms', '08小队'], field: ConceptField.series, needles: ['08ms']),
  // ── 제품 라인 (Kit.line, 앞부분이 같으면 — MG 는 MGEX · MGSD 도) ──
  Concept('HG', ['hg', '하이그레이드', 'high grade', 'ハイグレード'], field: ConceptField.line, needles: ['hg']),
  Concept('RG', ['rg', '리얼그레이드', 'real grade', 'リアルグレード'], field: ConceptField.line, needles: ['rg']),
  Concept('MG', ['mg', '마스터그레이드', 'master grade', 'マスターグレード'], field: ConceptField.line, needles: ['mg']),
  Concept('PG', ['pg', '퍼펙트그레이드', 'perfect grade', 'パーフェクトグレード'], field: ConceptField.line, needles: ['pg']),
  Concept('SD', ['sd', 'sdcs', 'bb전사', 'bb战士'], field: ConceptField.line, needles: ['sd']),
  Concept('EG', ['eg', '엔트리그레이드', 'entry grade'], field: ConceptField.line, needles: ['eg']),
  Concept('METAL BUILD', ['메탈빌드', '메탈 빌드', 'metal build'], field: ConceptField.line, needles: ['metal build']),
  Concept('ROBOT魂', ['로봇혼', '로봇 혼', 'robot魂', 'robot spirits', '机器人魂'], field: ConceptField.line, needles: ['robot魂']),
  Concept('30MM', ['30mm'], field: ConceptField.line, needles: ['30mm']),
  Concept('넨도로이드', ['넨도로이드', '넨도', 'nendoroid', 'ねんどろいど', '粘土人'], field: ConceptField.line, needles: ['넨도로이드']),
  Concept('figma', ['figma', '피그마'], field: ConceptField.line, needles: ['figma']),
  Concept('포켓프라', ['포켓프라', 'pokepla', 'ポケプラ', '宝可梦拼装'], field: ConceptField.line, needles: ['포켓프라']),
  Concept('BX', ['bx'], field: ConceptField.line, needles: ['bx']),
  Concept('UX', ['ux'], field: ConceptField.line, needles: ['ux']),
  Concept('CX', ['cx'], field: ConceptField.line, needles: ['cx']),
  // ── 상품 유형 (Kit.type) ──
  Concept(
    '프라모델',
    ['프라모델', '프라', '건프라', '조립', 'plastic model', 'プラモデル', 'プラモ', 'ガンプラ', '拼装模型', '拼装', '模型'],
    field: ConceptField.type,
    needles: ['프라모델'],
    weight: 1.5,
  ),
  Concept(
    '피규어',
    ['피규어', '피겨', 'figure', 'フィギュア', '手办', '可动'],
    field: ConceptField.type,
    needles: ['피규어', '액션'],
    weight: 1.5,
  ),
  Concept(
    '인형',
    ['인형', '봉제', '봉제인형', 'plush', 'ぬいぐるみ', '毛绒玩偶', '毛绒', '玩偶', '布偶', '公仔'],
    field: ConceptField.type,
    needles: ['인형'],
    weight: 1.5,
  ),
  Concept(
    '가샤폰',
    ['가샤폰', '가챠', '캡슐토이', 'gashapon', 'ガシャポン', 'ガチャ', '扭蛋', '转蛋'],
    field: ConceptField.type,
    needles: ['가샤폰'],
    weight: 1.5,
  ),
  Concept('카드', ['카드', 'card', 'カード', '卡片', '卡牌'], field: ConceptField.type, needles: ['카드'], weight: 1.5),
  Concept('굿즈', ['굿즈', 'goods', 'グッズ', '周边'], field: ConceptField.type, needles: ['굿즈'], weight: 1.5),
  // ── 채널 (넓은 말이라 가볍게) ──
  Concept(
    '건담',
    ['건담', 'gundam', 'ガンダム', '高达', '敢达', '钢弹'],
    field: ConceptField.franchise,
    needles: ['gundam'],
    weight: 0.5,
  ),
  Concept(
    '포켓몬',
    ['포켓몬', 'pokemon', 'pokémon', 'ポケモン', '宝可梦', '神奇宝贝'],
    field: ConceptField.franchise,
    needles: ['pokemon'],
    weight: 0.5,
  ),
  Concept(
    '베이블레이드',
    ['베이블레이드', '베이', 'beyblade', 'ベイブレード', '战斗陀螺', '陀螺'],
    field: ConceptField.franchise,
    needles: ['beyblade'],
    weight: 0.5,
  ),
  Concept('Fate', ['페이트', 'fate'], field: ConceptField.franchise, needles: ['fate'], weight: 0.5),
  Concept('레고', ['레고', 'lego', 'レゴ', '乐高'], field: ConceptField.franchise, needles: ['lego'], weight: 0.5),
  Concept(
    '마도카 마기카',
    ['마도카', '마마마', 'madoka', 'まどか', 'まどマギ', '魔法少女小圆', '小圆'],
    field: ConceptField.franchise,
    needles: ['madoka'],
    weight: 0.5,
  ),
  Concept(
    '아머드 코어',
    ['아머드 코어', '아머드코어', 'armored core', 'アーマード・コア', '装甲核心'],
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

/// 중국어 군말 — 띄어 쓰지 않으니 낱말로 못 버리고 글자째 지운다 (표의 표기를 먼저 찾은 뒤라 "水星的魔女" 의 的 는 안 건드린다).
/// 긴 것부터 (帮我找 → 帮我 → 找)
const _zhFillers = [
  '帮我找找',
  '帮我找',
  '给我找',
  '找一下',
  '我想要',
  '帮我',
  '找找',
  '想要',
  '我要',
  '一个',
  '一只',
  '一款',
  '一台',
  '那种',
  '这种',
  '这个',
  '那个',
  '有点',
  '样子',
  '感觉',
  '类似',
  '一样',
  '像是',
  '拿着',
  '穿着',
  '带着',
  '长着',
  '还有',
  '以及',
  '或者',
  '的',
  '有',
  '和',
  '跟',
  '与',
  '或',
  '找',
  '请',
  '吧',
  '呢',
  '啊',
  '很',
  '款',
];

/// 전각 영숫자 → 반각, 소문자
String normalizeSentence(String s) =>
    String.fromCharCodes([for (final c in s.runes) c >= 0xFF01 && c <= 0xFF5E ? c - 0xFEE0 : c]).toLowerCase();

final _asciiWord = RegExp(r'^[a-z0-9\-]+$');

/// 한자 (CJK 통합 한자 + 확장 A)
final _hanRun = RegExp(r'[\u3400-\u9fff]+');
bool _isSingleHan(String t) => t.length == 1 && _hanRun.hasMatch(t);

/// 문장 쪽 한 글자 한자 표기 → 뜻 (红 · 金 · 龙 · 赤 …)
final _singleHanTerms = <String, Concept>{
  for (final c in sentenceConcepts)
    for (final t in c.terms)
      if (_isSingleHan(t)) t: c,
};
final _singleHanFillers = {
  for (final f in _zhFillers)
    if (f.length == 1) f,
};

/// 한자 덩어리 하나가 한 글자 표기 · 한 글자 군말만으로 되어 있으면 그 뜻들, 아니면 null.
/// 红 · 红的 · 黑金 · 找龙 → 뜻 / 奥伯龙 · 闪粉 · 粉丝 → null (낱말 그대로 상품 글자에서 찾는다)
List<Concept>? _singleHanRun(String run) {
  final cs = run.split('');
  if (!cs.any(_singleHanTerms.containsKey)) return null;
  if (!cs.every((ch) => _singleHanTerms.containsKey(ch) || _singleHanFillers.contains(ch))) return null;
  return [for (final ch in cs) ?_singleHanTerms[ch]];
}

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
      for (final t in c.terms)
        if (!_isSingleHan(t)) (c, t),
  ]..sort((a, b) => b.$2.length.compareTo(a.$2.length));
  for (final (c, t) in terms) {
    final re = _asciiWord.hasMatch(t)
        ? RegExp('(?<![a-z0-9])${RegExp.escape(t)}(?![a-z0-9])')
        : RegExp(RegExp.escape(t));
    if (!re.hasMatch(text)) continue;
    text = text.replaceAll(re, ' ');
    if (!found.contains(c)) found.add(c);
  }
  // 두 글자 이상 군말도 먼저 지운다 — 안 그러면 "帮我找红的" · "一个红的" 덩어리에 帮 · 我 · 一 · 个 가 남아 红 을 못 본다
  for (final f in _zhFillers) {
    if (f.length > 1) text = text.replaceAll(f, ' ');
  }
  // 긴 표기 · 긴 군말을 다 지운 뒤 남은 한자 덩어리 (红高达 → 高达 를 지우면 红 만 남는다)
  text = text.replaceAllMapped(_hanRun, (m) {
    final cs = _singleHanRun(m[0]!);
    if (cs == null) return m[0]!;
    for (final c in cs) {
      if (!found.contains(c)) found.add(c);
    }
    return ' ';
  });
  for (final f in _zhFillers) {
    text = text.replaceAll(f, ' ');
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

  /// 화면에 보이는 이유 — 표의 뜻 이름은 화면 언어로, 친 낱말은 그대로
  String get reason => [for (final m in matched) _labels.contains(m) ? tr(m) : m].join(' · ');
}

final _labels = {for (final c in sentenceConcepts) c.label};

/// 상품 글자 (소문자 한 줄) — 실제 데이터는 미리 만든 blob, 테스트용 가짜 상품은 칸을 이어 붙인다.
/// 화면 언어에 따라 바뀌지 않게 [Kit.nameKo] (중국어 이름은 [_zhName] 으로 따로)
String _hay(Kit k) =>
    k.blob.isNotEmpty ? k.blob : [k.nameKo, k.nameJa, k.series, k.line, k.type, ...k.keywords].join(' ').toLowerCase();

/// 중국어 이름 — blob 에 없어서 따로 본다 (중국어로 친 이름 · 별명이 중국어 이름만 있는 상품에도 맞게)
String _zhName(Kit k) => k.nameZh.toLowerCase();

bool _hits(Concept c, Kit k, String hay, String zh) => switch (c.field) {
  ConceptField.name => c.look.any((n) {
    final l = n.toLowerCase();
    return hay.contains(l) || zh.contains(l);
  }),
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
    final zh = _zhName(k);
    var got = 0.0;
    var strong = false;
    final matched = <String>[];
    for (final c in q.concepts) {
      if (_hits(c, k, hay, zh)) {
        got += c.weight;
        matched.add(c.label);
        if (c.field != ConceptField.franchise) strong = true;
      }
    }
    for (final w in q.words) {
      if (hay.contains(w) || zh.contains(w)) {
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
