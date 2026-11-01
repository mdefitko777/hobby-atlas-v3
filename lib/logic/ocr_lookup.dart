// 글자로 찾기 (사진 글자 읽기 E-11 · 공유로 받은 글 E-15) — AI 가 아니라 글자 맞추기.
//   1) 읽은 글자를 고친다: 전각 → 반각 · 줄표 · 로마 숫자(Ⅱ → II) · 가타카나 장음(一 → ー)
//   2) 버릴 줄(경고 · 저작권 · 문의처 · 재질)은 통째로, 가격 · 날짜 · 회사 이름 · 가게 버튼 글자는 줄에서 지운다
//   3) 남은 글자에서 낱말 조각(OcrToken)을 뽑는다:
//        JAN(검사 숫자가 맞는 13 · 8자리) · 등급(HG · RG · MG · PG · RE/100 · SD · EG · ROBOT魂 · METAL BUILD …) ·
//        축척(1/144 …) · 형식번호(RX-78-2 · MSN-04 · ZGMF-X10A …) · 베이 번호(BX-01 · 3-60F) · 나머지 낱말
//   4) 상품마다: JAN 이 같으면 100%. 아니면 상품 이름 조각이 읽은 글자에 얼마나 들어 있나(글자 둘씩 겹침) ×
//      이름 길이(짧은 이름이 우연히 다 맞는 것을 낮춤). 등급 · 축척 · 형식번호 · 베이 번호가 서로 다르면 깎는다.
//      건담은 도감 데이터(형식번호 ↔ 상품)로 이름에 형식번호가 없는 상품도 찾는다.
//   5) 일치도 = 그 점수(0–99, JAN · 주소만 100), 이유 = 맞은 조각 그대로
// Flutter 를 쓰지 않는다 (단위 테스트). 상품 쪽 글자는 OcrIndex 가 한 번만 만든다 (약 1만 개).
import '../json_util.dart';
import '../models.dart';
import 'kit_rules.dart' show kitsWithBarcode;
import 'sentence_search.dart' show ConceptField, sentenceConcepts;
import 'url_lookup.dart' show validEan;

enum OcrKind { jan, grade, scale, model, bbx, word }

/// 읽은 글자에서 뽑은 조각 하나 (화면의 칩 하나)
class OcrToken {
  const OcrToken(this.kind, this.label, this.key, {this.group = ''});
  final OcrKind kind;

  /// 보이는 글자 (칩)
  final String label;

  /// 맞추기용 (접은 글자: 소문자 · 띄어쓰기 · 기호 없음)
  final String key;

  /// 등급 묶음 (HGUC → HG) · 축척 (1/144). 그 밖에는 ''
  final String group;

  @override
  bool operator ==(Object other) => other is OcrToken && other.kind == kind && other.key == key;

  @override
  int get hashCode => Object.hash(kind, key);

  @override
  String toString() => '${kind.name}:$label';
}

// ── 글자 고치기 ────────────────────────────────────────────────────────────────

const _roman = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X', 'XI', 'XII'];
final _dashBetween = RegExp(r'(?<=[A-Za-z0-9])\s?[ー‐‑‒–—―−一]\s?(?=[A-Za-z0-9])');
final _kanaDash = RegExp(r'(?<=[ァ-ヺ])[一\-−–—]');

/// 전각 영숫자 → 반각 · 전각 빈칸 → 빈칸 · Ⅱ → II · 영숫자 사이 줄표 → '-' · 가타카나 뒤 一 → ー
String normalizeOcr(String s) {
  final b = StringBuffer();
  for (final c in s.runes) {
    if (c >= 0xFF01 && c <= 0xFF5E) {
      b.writeCharCode(c - 0xFEE0);
    } else if (c == 0x3000) {
      b.write(' ');
    } else if (c >= 0x2160 && c <= 0x216B) {
      b.write(_roman[c - 0x2160]);
    } else if (c >= 0x2170 && c <= 0x217B) {
      b.write(_roman[c - 0x2170].toLowerCase());
    } else {
      b.writeCharCode(c);
    }
  }
  return b.toString().replaceAll(_dashBetween, '-').replaceAll(_kanaDash, 'ー');
}

final _foldDrop = RegExp(r'''[\s・･·.,，、。\-‐‑‒–—―−ー_/\\|()\[\]{}【】「」『』〈〉《》<>"'“”‘’!?~〜:;+*#&]''');

/// 맞추기용 접은 글자: 고친 뒤 소문자 · 띄어쓰기 · 기호 · 장음 없음 ("RX-78-2" → "rx782", "サザビー" → "サザビ")
String foldKey(String s) => _fold(normalizeOcr(s));

/// 이미 고친 글자 접기
String _fold(String s) => s.toLowerCase().replaceAll(_foldDrop, '');

// ── 조각 뽑기 ──────────────────────────────────────────────────────────────────

/// 통째로 버릴 줄 (상자 옆면 · 화면 아래쪽)
final _noiseLine = RegExp(
  r'©|\(c\)|copyright|all rights reserved|made in|対象年齢|才以上|歳以上|세\s*이상|警告|注意|ご注意|使用上|warning|caution|choking|'
  r'窒息|誤飲|小さな部品|お問い合わせ|お客様相談|相談センター|材質|素材|原産国|日本製|中国製|ベトナム製|원산지|제조자|제조국|수입원|판매원|품질표시|사용연령|'
  r'株式会社|有限会社|\btel\b|\bfax\b|\bpvc\b|\babs\b',
  caseSensitive: false,
);

/// 줄에서 지울 것 (가격 · 날짜 · 회사 · 가게 버튼)
final _strip = <RegExp>[
  RegExp(r'https?://\S+|www\.\S+', caseSensitive: false),
  RegExp(r'[(（]\s*(?:税込|税抜|税別)[^)）]*[)）]|税込|税抜|税別|送料無料|送料'),
  RegExp(r'[¥￥$₩]\s*[\d,]+(?:\.\d+)?|[\d,]+\s*(?:円|원|엔|yen|jpy|krw)', caseSensitive: false),
  RegExp(r'\d{4}\s*[年/.\-]\s*\d{1,2}(?:\s*[月/.\-]\s*\d{1,2}\s*日?)?|\d{1,2}\s*月(?:\s*\d{1,2}\s*日)?|\d{1,2}\s*월(?:\s*\d{1,2}\s*일)?'),
  RegExp(r'\d{1,2}:\d{2}|\d+\s*%'),
  RegExp(
    r'bandai\s*spirits|bandai\s*namco|バンダイ\s*スピリッツ|バンダイナムコ|プレミアムバンダイ|premium\s*bandai|프리미엄\s*반다이|'
    r'takara\s*tomy|タカラトミー|good\s*smile\s*company|グッドスマイルカンパニー|kotobukiya|コトブキヤ|aniplex|'
    r'sotsu|sunrise|創通|サンライズ|amazon\.co\.jp|amazon|반다이남코|반다이|バンダイ|bandai',
    caseSensitive: false,
  ),
  RegExp(
    r'カートに入れる|予約受付中|予約受付|受付中|在庫あり|在庫なし|在庫|売り切れ|品切れ|お気に入り|ポイント|発売日|発売|発送|'
    r'商品詳細|商品説明|商品情報|レビュー|購入|新品|中古|未開封|美品|価格|'
    r'장바구니|바로구매|구매하기|구매|찜하기|채팅하기|채팅|배송비|무료배송|배송|무료|택배|직거래|네고|미개봉|새상품|중고|급처|팝니다|'
    r'판매합니다|판매|팔아요|일괄|풀박|정품|리뷰|상품정보|상세정보|'
    r'add to cart|buy now|in stock|out of stock|pre-?order|free shipping|sold out',
    caseSensitive: false,
  ),
];

/// 등급 · 라인 (긴 표기부터). (무늬, 묶음)
const _gradeDefs = <(String, String)>[
  (r'PG\s*UNLEASHED', 'PG'),
  (r'PERFECT\s*GRADE', 'PG'),
  (r'MASTER\s*GRADE', 'MG'),
  (r'REAL\s*GRADE', 'RG'),
  (r'HIGH\s*GRADE', 'HG'),
  (r'ENTRY\s*GRADE', 'EG'),
  (r'FULL\s*MECHANICS', 'FM'),
  (r'METAL\s*ROBOT\s*魂', 'METAL ROBOT魂'),
  (r'METAL\s*BUILD', 'METAL BUILD'),
  (r'ROBOT\s*魂|ROBOT\s*SPIRITS|로봇\s*혼', 'ROBOT魂'),
  (r'S\.?\s*H\.?\s*Figuarts|フィギュアーツ', 'S.H.Figuarts'),
  (r'RE\s*/\s*100', 'RE/100'),
  (r'MGEX', 'MGEX'),
  (r'MGSD', 'MGSD'),
  (r'HG(?:UC|CE|BF|BD|BM|AC|IBO|GTO|FC|AW|AGE|BC|GC|PG)?', 'HG'),
  (r'SD(?:CS|EX|W)?|BB戦士', 'SD'),
  (r'MG', 'MG'),
  (r'RG', 'RG'),
  (r'PG', 'PG'),
  (r'EG', 'EG'),
  (r'FM', 'FM'),
  (r'FG', 'FG'),
  (r'30\s*MM', '30MM'),
  (r'30\s*MS', '30MS'),
  (r'figma', 'figma'),
  (r'ねんどろいど|Nendoroid|넨도로이드', '넨도로이드'),
  (r'ポケプラ|Pokepla|포켓프라', '포켓프라'),
  (r'一番くじ|제일복권', '제일복권'),
];

final _gradeRe = RegExp(
  '(?<![A-Za-z0-9])(?:${[for (final (p, _) in _gradeDefs) '($p)'].join('|')})(?![A-Za-z])',
  caseSensitive: false,
);

/// 등급 무늬에 맞은 글자 → 묶음
String _gradeGroup(Match m) {
  for (var i = 0; i < _gradeDefs.length; i++) {
    if (m.group(i + 1) != null) return _gradeDefs[i].$2;
  }
  return '';
}

/// 상품 라인(Kit.line) → 등급 묶음
const _lineGroup = {
  'NG': 'NG',
  'HG': 'HG',
  'MG': 'MG',
  'RG': 'RG',
  'PG': 'PG',
  'PGU': 'PG',
  'EG': 'EG',
  'RE100': 'RE/100',
  'FM': 'FM',
  'FG': 'FG',
  'SD': 'SD',
  'SDW': 'SD',
  'SDEX': 'SD',
  'SDCS': 'SD',
  'MGSD': 'MGSD',
  'MGEX': 'MGEX',
  'ROBOT魂': 'ROBOT魂',
  'METAL ROBOT魂': 'METAL ROBOT魂',
  'METAL BUILD': 'METAL BUILD',
  'S.H.Figuarts': 'S.H.Figuarts',
  '30MM': '30MM',
  'figma': 'figma',
  '넨도로이드': '넨도로이드',
  '포켓프라': '포켓프라',
  '제일복권': '제일복권',
};

final _scaleRe = RegExp(r'(?<![\d/.])1\s*/\s*(\d{1,4})(?![\d/])');
final _bbxRe = RegExp(r'(?<![A-Za-z0-9])(BX|UX|CX)\s*-?\s*(\d{1,3})(?!\d)', caseSensitive: false);
final _comboRe = RegExp(r'(?<![A-Za-z0-9\-])(\d{1,2})-(\d{2})([A-Za-z]{1,3})(?![A-Za-z0-9])');

/// 형식번호: 영문 머리 - 숫자 (- 이어지는 것). 하이픈이 하나는 있어야 한다
final _modelRe = RegExp(
  r'(?<![A-Za-z0-9\-])([A-Z]{1,5}\d{0,3}[A-Z]?)-([A-Z]{0,4}\d{1,4}(?:[A-Za-z]{1,4}\d{0,3})?)((?:-[A-Z0-9][A-Za-z0-9]{0,3})*)(?![A-Za-z0-9])',
);
const _notModel = {'BX', 'UX', 'CX', 'VER', 'NO', 'TEL', 'FAX', 'ISBN', 'JAN', 'EAN', 'VOL', 'PART', 'TYPE', 'SET'};

/// 모델 번호로 볼 만한가 (머리 영문 2자 이상 또는 접어서 4자 이상)
bool _isModel(Match m) {
  final head = m.group(1)!;
  if (_notModel.contains(head.replaceAll(RegExp(r'\d'), ''))) return false;
  final letters = head.replaceAll(RegExp(r'[^A-Z]'), '').length;
  final folded = foldKey(m.group(0)!);
  return letters >= 2 ? folded.length >= 3 : folded.length >= 4;
}

final _digitsRe = RegExp(r'(?<!\d)\d(?:[\d ]{6,18})\d(?!\d)');
final _wordSplit = RegExp(r'''[\s,、。·|｜:：;；!！?？"“”'‘’「」『』【】\[\]()（）<>《》〈〉/]+''');
final _onlyDigits = RegExp(r'^[\d.]+$');
final _letter = RegExp('[a-z]');
final _asciiOnly = RegExp(r'^[a-z0-9]+$');

/// 낱말로 두지 않는 말 (접은 글자)
const _stopWords = {
  'the', 'and', 'for', 'with', 'new', 'ver', 'version', 'edition', 'japan', 'china', 'vietnam', 'plastic', 'model', 'kit',
  'figure', 'scale', 'nonscale', 'item', 'product', 'products', 'official', 'shop', 'store', 'online', 'limited', 'only',
  'ガンプラ', 'プラモデル', 'プラモ', 'フィギュア', '限定', '商品', '組立', '組み立て', '接着剤不要', '色分け済み', 'スケール', 'ノンスケール',
  '건프라', '프라모델', '피규어', '상품', '한정', '조립', '판매중', '팝니다',
};

/// 읽은 글(사진 글자 · 공유로 받은 글) → 조각 (읽은 차례, 같은 것은 한 번)
List<OcrToken> extractOcrTokens(String raw, {int maxWords = 30}) {
  final out = <OcrToken>[];
  final seen = <String>{};
  var words = 0;
  void add(OcrKind kind, String label, {String group = ''}) {
    final key = foldKey(label);
    if (key.isEmpty || !seen.add('${kind.name}:$key')) return;
    out.add(OcrToken(kind, label, key, group: group));
  }

  for (var line in normalizeOcr(raw).split(RegExp(r'[\r\n]+'))) {
    line = line.trim();
    if (line.isEmpty || _noiseLine.hasMatch(line)) continue;
    for (final re in _strip) {
      line = line.replaceAll(re, ' ');
    }
    // JAN (사이에 빈칸이 있어도: "4 573102 683540")
    // 13자리만 (8자리는 우연히 검사 숫자가 맞는 숫자가 많아 다른 상품을 100% 로 잘못 고른다)
    line = line.replaceAllMapped(_digitsRe, (m) {
      final raw = m.group(0)!;
      for (final d in [raw.replaceAll(' ', ''), for (final x in RegExp(r'\d{12,13}').allMatches(raw)) x.group(0)!]) {
        final code = d.length == 12 ? '0$d' : d;
        if (code.length == 13 && validEan(code)) {
          add(OcrKind.jan, code);
          return ' ';
        }
      }
      return raw;
    });
    line = line.replaceAllMapped(_gradeRe, (m) {
      add(OcrKind.grade, m.group(0)!.toUpperCase().replaceAll(RegExp(r'\s+'), ' '), group: _gradeGroup(m));
      return ' ';
    });
    line = line.replaceAllMapped(_scaleRe, (m) {
      final n = int.parse(m.group(1)!);
      if (n < 2) return m.group(0)!;
      add(OcrKind.scale, '1/$n', group: '1/$n');
      return ' ';
    });
    line = line.replaceAllMapped(_bbxRe, (m) {
      add(OcrKind.bbx, '${m.group(1)!.toUpperCase()}-${m.group(2)!.padLeft(2, '0')}');
      return ' ';
    });
    line = line.replaceAllMapped(_comboRe, (m) {
      add(OcrKind.bbx, '${m.group(1)}-${m.group(2)}${m.group(3)!.toUpperCase()}');
      return ' ';
    });
    line = line.replaceAllMapped(_modelRe, (m) {
      if (!_isModel(m)) return m.group(0)!;
      add(OcrKind.model, m.group(0)!);
      return ' ';
    });
    for (final w in line.split(_wordSplit)) {
      if (words >= maxWords) break;
      final key = foldKey(w);
      if (key.length < 2 || _onlyDigits.hasMatch(key) || _stopWords.contains(key)) continue;
      // 영문만인 짧은 말(ii · ew · ex)은 버린다
      if (_asciiOnly.hasMatch(key) && key.length < 3) continue;
      final before = out.length;
      add(OcrKind.word, w.trim());
      if (out.length > before) words++;
    }
  }
  return out;
}

// ── 건담 형식번호 ↔ 상품 (도감 데이터) ─────────────────────────────────────────

/// gundam-ms.json · gundam-kit-ms.json → 접은 형식번호("rx782") → 상품 id. 부품 · SD 캐릭터 연결은 뺀다
Map<String, List<String>> atlasModelIndex(Object? ms, Object? kitMs) {
  final root = jMap(ms);
  final redirects = {for (final e in jMap(root['ms_redirects']).entries) e.key: jStr(e.value)};
  final msModels = <String, Set<String>>{};
  for (final raw in jList(root['ms'])) {
    final m = jMap(raw);
    final id = jStr(m['id']);
    if (id.isEmpty) continue;
    final models = <String>{
      for (final s in jList(m['model_numbers']).whereType<String>()) foldKey(s),
      // MS id 앞의 형식번호 ("RX-78-2 Gundam")
      for (final x in _modelRe.allMatches(normalizeOcr(id)))
        if (x.start == 0 && _isModel(x)) foldKey(x.group(0)!),
    }..removeWhere((s) => s.length < 3);
    if (models.isNotEmpty) msModels[id] = models;
  }
  final out = <String, List<String>>{};
  for (final e in jMap(jMap(kitMs)['links']).entries) {
    for (final l in jList(e.value)) {
      final link = jMap(l);
      final role = jStr(link['role']);
      if (role == 'accessory_for' || role == 'sd_character') continue;
      var msId = jStr(link['ms']);
      msId = redirects[msId]?.isNotEmpty == true ? redirects[msId]! : msId;
      for (final model in msModels[msId] ?? const <String>{}) {
        final list = out[model] ??= [];
        if (!list.contains(e.key)) list.add(e.key);
      }
    }
  }
  return out;
}

// ── 상품 쪽 글자 (한 번만) ──────────────────────────────────────────────────────

enum _PartKind { grade, scale, other }

class _Part {
  _Part(this.label, this.key, this.kind)
    : grams = _grams(key),
      anchor =
          kind == _PartKind.other &&
          !_onlyDigits.hasMatch(key) &&
          (_asciiOnly.hasMatch(key) ? key.length >= 3 && key.contains(_letter) : key.length >= 2);

  final String label;
  final String key;
  final _PartKind kind;
  final List<int> grams;

  /// 이 조각이 맞아야 후보가 된다 (등급 · 축척 · 숫자만인 조각은 혼자서 후보를 만들지 않는다)
  final bool anchor;

  int get weight => key.length.clamp(1, 12);
}

List<int> _grams(String s) {
  final c = s.codeUnits;
  if (c.length < 2) return const [];
  return {for (var i = 0; i + 1 < c.length; i++) (c[i] << 16) | c[i + 1]}.toList(growable: false);
}

/// 상품이 아니라 파는 방법을 적은 괄호 (재판 · 추첨 · 발송 · 한정) — 사진에 없으니 셈에서 뺀다.
/// [クリアカラー] 같은 다른 판 표시는 남긴다 (사진에 없으면 그만큼 낮게)
final _notice = RegExp(
  r'【[^】]*(?:再販|再生産|抽選|予約|発送|販売|受注|限定|추첨|재판|발송|판매|한정)[^】]*】|'
  r'\[[^\]]*(?:Reissue|再販|재판|Limited)[^\]]*\]|[(（]\s*(?:再販売?|再生産|Reissue[^)）]*|재판[^)）]*)\s*[)）]',
);
final _edgePunct = RegExp(r'^[\s()\[\]（）【】「」『』〈〉<>.,·・:;~〜/-]+|[\s()\[\]（）【】「」『』〈〉<>.,·・:;~〜/-]+$');

/// 상품 이름 → 조각 ("1 / 144" 는 한 조각, 글자 종류가 바뀌는 곳에서도 자른다)
final _space = RegExp(r'\s+');

List<_Part> _nameParts(String normalized) {
  var n = normalized.replaceAll(_notice, ' ');
  n = n.replaceAllMapped(_scaleRe, (m) => ' 1/${m.group(1)} ');
  final parts = <_Part>[];
  final seen = <String>{};
  for (final seg in [for (final w in n.split(_space)) ..._scriptSplit(w)]) {
    final key = _fold(seg);
    if (key.isEmpty || !seen.add(key)) continue;
    final label = seg.replaceAll(_edgePunct, '');
    final kind = seg.startsWith('1/') && _scaleRe.hasMatch(seg)
        ? _PartKind.scale
        : (label.length <= 14 && _gradeRe.firstMatch(label)?.group(0)?.length == label.length
              ? _PartKind.grade
              : _PartKind.other);
    parts.add(_Part(label.isEmpty ? seg : label, key, kind));
  }
  return parts;
}

/// 글자 종류가 바뀌는 곳에서 자른다: 가타카나 | 한자 · 히라가나 | 한글 | 영숫자 ("シャア専用ザク" → シャア · 専用 · ザク)
List<String> _scriptSplit(String w) {
  int cls(int c) {
    if ((c >= 0x30A0 && c <= 0x30FF) || c == 0x30FC) return 1;
    if ((c >= 0x3040 && c <= 0x309F) || (c >= 0x4E00 && c <= 0x9FFF) || (c >= 0x3400 && c <= 0x4DBF) || c == 0x3005) return 2;
    if ((c >= 0xAC00 && c <= 0xD7AF) || (c >= 0x1100 && c <= 0x11FF) || (c >= 0x3130 && c <= 0x318F)) return 3;
    if ((c >= 0x30 && c <= 0x39) || (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A) || c == 0x2D || c == 0x2F) return 4;
    return 0; // 기호 · 그 밖: 앞 조각에 붙인다
  }

  final out = <String>[];
  final b = StringBuffer();
  var prev = 0;
  for (final c in w.runes) {
    final k = cls(c);
    if (k != 0 && prev != 0 && k != prev && b.isNotEmpty) {
      out.add(b.toString());
      b.clear();
    }
    b.writeCharCode(c);
    if (k != 0) prev = k;
  }
  if (b.isNotEmpty) out.add(b.toString());
  return out;
}

class _Entry {
  _Entry(this.i, this.id, this.variants, this.grades, this.scales, this.models, this.atlasModels, this.bbx);

  /// 상품 목록 안 순번 (다른 isolate 에서 만들 때 Kit 을 넘기지 않는다)
  final int i;
  final String id;
  final List<List<_Part>> variants;
  final Set<String> grades;
  final Set<String> scales;

  /// 이름에 있는 형식번호 (접은 글자)
  final Set<String> models;

  /// 도감 데이터로만 아는 형식번호 (이름에는 없음)
  final Set<String> atlasModels;

  /// 베이 번호 (bx52)
  final Set<String> bbx;

  /// 이 상품 이름들의 글자 둘씩 (읽은 조각이 이 상품으로 설명되나) — 후보가 됐을 때만 만든다
  late final Set<int> grams = {
    for (final v in variants) ..._grams(v.map((p) => p.key).join()),
  };
}

/// 한국어 · 영어로 쓴 기체 이름 → 일본어 표기도 (설명으로 찾기의 낱말 표, 이름 쪽만): "에어리얼" → エアリアル · aerial
List<String> _aliases(String key) {
  if (key.length < 2) return const [];
  for (final c in sentenceConcepts) {
    if (c.field != ConceptField.name) continue;
    if (c.terms.any((t) => foldKey(t) == key)) {
      return {for (final n in c.look) foldKey(n)}.where((n) => n.length >= 2 && n != key).toList();
    }
  }
  return const [];
}

/// 후보 하나: 상품 · 일치도(0–100) · 맞은 조각
class OcrCandidate {
  const OcrCandidate(this.kit, this.score, this.matched, {this.exact = false});
  final Kit kit;
  final int score;
  final List<String> matched;

  /// JAN · 주소가 같은 것 (100%)
  final bool exact;

  String get reason => matched.join(' · ');
}

/// 찾기 표의 상품 쪽 — [buildOcrIndexData] 를 compute() 로 다른 isolate 에서 만들어 넘길 수 있다
class OcrIndexData {
  const OcrIndexData._(this._entries);
  final List<_Entry> _entries;
}

/// compute() 에 넘길 상품 줄: [id, 이름, 일본어 이름, 라인, 축척]
List<List<String>> ocrRows(List<Kit> kits) => [
  for (final k in kits) [k.id, k.name, k.nameJa, k.line, k.scale],
];

/// compute() 작업: 상품 줄 + 형식번호 표(접은 형식번호 → 상품 id) → 찾기 표의 상품 쪽 (약 1만 개에 0.5초쯤)
OcrIndexData buildOcrIndexData(({List<List<String>> rows, Map<String, List<String>> models}) msg) {
  final byKit = <String, Set<String>>{};
  for (final e in msg.models.entries) {
    for (final id in e.value) {
      (byKit[id] ??= {}).add(e.key);
    }
  }
  final out = <_Entry>[];
  for (var i = 0; i < msg.rows.length; i++) {
    final [id, name, nameJa, line, scale] = msg.rows[i];
    final names = [
      for (final n in [name, if (nameJa.isNotEmpty && nameJa != name) nameJa]) normalizeOcr(n),
    ];
    final variants = [for (final n in names) _nameParts(n)];
    final grades = <String>{?_lineGroup[line]};
    final scales = <String>{if (scale.startsWith('1/')) scale};
    final inName = <String>{};
    final bbx = <String>{};
    for (final t in names) {
      for (final m in _gradeRe.allMatches(t)) {
        grades.add(_gradeGroup(m));
      }
      for (final m in _scaleRe.allMatches(t)) {
        scales.add('1/${m.group(1)}');
      }
      for (final m in _modelRe.allMatches(t)) {
        if (_isModel(m)) inName.add(_fold(m.group(0)!));
      }
      for (final m in _bbxRe.allMatches(t)) {
        bbx.add('${m.group(1)!.toLowerCase()}${m.group(2)!.padLeft(2, '0')}');
      }
    }
    final atlas = {...?byKit[id]}..removeAll(inName);
    out.add(_Entry(i, id, variants, grades, scales, inName, atlas, bbx));
  }
  return OcrIndexData._(out);
}

/// 상품 쪽 글자를 한 번 만들어 두는 찾기 표
class OcrIndex {
  /// 바로 만들기 (테스트 · 작은 목록). 앱은 [OcrIndex.withData] + compute()
  factory OcrIndex(List<Kit> kits, {Map<String, List<String>> models = const {}}) =>
      OcrIndex.withData(kits, buildOcrIndexData((rows: ocrRows(kits), models: models)), models: models);

  OcrIndex.withData(this._kits, OcrIndexData data, {Map<String, List<String>> models = const {}})
    : _models = models,
      _entries = data._entries {
    _last = this;
  }

  final List<Kit> _kits;
  final Map<String, List<String>> _models;
  final List<_Entry> _entries;

  static OcrIndex? _last;

  /// 같은 상품 목록(같은 객체들) · 같은 형식번호 표로 지난번에 만든 표 (없으면 null)
  static OcrIndex? reuse(List<Kit> kits, {Map<String, List<String>> models = const {}}) {
    final l = _last;
    if (l != null &&
        identical(l._models, models) &&
        l._kits.length == kits.length &&
        (kits.isEmpty || (identical(l._kits.first, kits.first) && identical(l._kits.last, kits.last)))) {
      return l;
    }
    return null;
  }

  /// 지난번 표를 다시 쓰거나 바로 만든다
  static OcrIndex of(List<Kit> kits, {Map<String, List<String>> models = const {}}) =>
      reuse(kits, models: models) ?? OcrIndex(kits, models: models);

  /// 조각 → 후보 (일치도 높은 것부터). [minScore] 보다 낮은 것은 뺀다.
  /// 일치도 = (상품 이름 조각 중 읽은 글자에 있는 몫) × (읽은 조각 중 이 상품으로 설명되는 양 ÷ 가장 많이 설명한 후보의 양)
  ///          × 다르면 깎기 (등급 0.6 · 축척 0.75 · 베이 번호 0.4 · 형식번호 0.7)
  List<OcrCandidate> lookUp(List<OcrToken> tokens, {int limit = 8, int minScore = 20}) {
    final out = <OcrCandidate>[];
    final exactIds = <String>{};
    for (final t in tokens) {
      if (t.kind != OcrKind.jan) continue;
      for (final k in kitsWithBarcode(_kits, t.key)) {
        if (exactIds.add(k.id)) out.add(OcrCandidate(k, 100, ['JAN ${t.key}'], exact: true));
      }
    }
    final rest = [
      for (final t in tokens)
        if (t.kind != OcrKind.jan) t,
    ];
    if (rest.isEmpty) return out.take(limit).toList();

    final alias = {
      for (final t in rest)
        if (t.kind == OcrKind.word) t: _aliases(t.key),
    };
    // 읽은 차례대로 이어 붙인 글자 (줄이 나뉜 이름도) + 다른 표기
    final qGrams = {
      ..._grams(rest.map((t) => t.key).join()),
      for (final a in alias.values)
        for (final k in a) ..._grams(k),
    };
    final qChars = {for (final t in rest) ...t.key.codeUnits};
    final qKeys = {for (final t in rest) t.key};
    final oGrades = {for (final t in rest) if (t.kind == OcrKind.grade) t.group};
    final oScales = {for (final t in rest) if (t.kind == OcrKind.scale) t.group};
    final oModels = [for (final t in rest) if (t.kind == OcrKind.model) t];
    final oBbx = {
      for (final t in rest)
        if (t.kind == OcrKind.bbx && RegExp(r'^[a-z]').hasMatch(t.key)) t.key,
    };

    double recall(_Part p) {
      if (p.grams.isEmpty) {
        // 한 글자: 한자 · 기호(改 · ν)는 읽은 글자에 있으면, 영문 한 글자(X · V)는 그 글자만 따로 읽었을 때만
        final c = p.key.codeUnitAt(0);
        return (c < 128 ? qKeys.contains(p.key) : qChars.contains(c)) ? 1 : 0;
      }
      var n = 0;
      for (final g in p.grams) {
        if (qGrams.contains(g)) n++;
      }
      return n / p.grams.length;
    }

    // 읽은 조각 하나가 이 상품으로 설명되나
    bool covered(_Entry e, String key) {
      final g = _grams(key);
      if (g.isEmpty) return false;
      final hit = g.where(e.grams.contains).length;
      return key.length < 4 ? hit == g.length : hit / g.length >= 0.8;
    }

    bool explains(_Entry e, OcrToken t, Set<String> kitModels) => switch (t.kind) {
      OcrKind.grade => e.grades.contains(t.group),
      OcrKind.scale => e.scales.contains(t.group),
      OcrKind.model => kitModels.any((k) => _modelMatch(t.key, k) > 0),
      OcrKind.jan => false,
      OcrKind.bbx || OcrKind.word => covered(e, t.key) || (alias[t] ?? const []).any((a) => covered(e, a)),
    };

    final raw = <(_Entry, double, double, List<String>)>[];
    var maxQ = 0.0;
    for (final e in _entries) {
      if (exactIds.contains(e.id)) continue;
      var best = 0.0;
      var bestMatched = const <String>[];
      // 도감으로만 아는 형식번호가 읽은 형식번호와 맞나
      var atlasHit = '';
      var atlasQ = 0.0;
      for (final m in oModels) {
        for (final a in e.atlasModels) {
          final q = _modelMatch(m.key, a);
          if (q > atlasQ) {
            atlasQ = q;
            atlasHit = m.label;
          }
        }
      }
      for (final parts in e.variants) {
        var total = 0.0, got = 0.0;
        var anchored = false;
        final matched = <String>[];
        for (final p in parts) {
          // 사진에 축척 · 등급 글자가 아예 없으면 그 조각은 셈에 넣지 않는다 (모르는 것 ≠ 틀린 것)
          if (p.kind == _PartKind.scale && oScales.isEmpty) continue;
          if (p.kind == _PartKind.grade && oGrades.isEmpty) continue;
          final w = p.weight;
          total += w;
          final r = recall(p);
          final credit = r == 1 ? w.toDouble() : (p.key.length >= 4 && r >= 0.7 ? w * r : 0.0);
          if (credit > 0) {
            got += credit;
            if (!matched.contains(p.label)) matched.add(p.label);
          }
          if (p.anchor && (r == 1 || (p.key.length >= 4 && r >= 0.8))) anchored = true;
        }
        if (atlasQ > 0) {
          total += atlasHit.length;
          got += atlasHit.length * atlasQ;
          matched.add(atlasHit);
          anchored = true;
        }
        if (!anchored || total == 0) continue;
        final s = (got / total) * (got / 6).clamp(0.0, 1.0);
        if (s > best) {
          best = s;
          bestMatched = matched;
        }
      }
      if (best == 0) continue;
      final kitModels = {...e.models, ...e.atlasModels};
      var q = 0.0;
      for (final t in rest) {
        if (explains(e, t, kitModels)) q += t.key.length.clamp(1, 12);
      }
      if (q > maxQ) maxQ = q;
      // 서로 다르면 깎기: 등급 · 축척 · 베이 번호 · 형식번호
      if (oGrades.isNotEmpty && e.grades.isNotEmpty && !e.grades.any(oGrades.contains)) best *= 0.6;
      if (oScales.isNotEmpty && e.scales.isNotEmpty && !e.scales.any(oScales.contains)) best *= 0.75;
      if (oBbx.isNotEmpty && e.bbx.isNotEmpty && !e.bbx.any(oBbx.contains)) best *= 0.4;
      if (oModels.isNotEmpty &&
          kitModels.isNotEmpty &&
          !oModels.any((m) => kitModels.any((k) => _modelMatch(m.key, k) > 0))) {
        best *= 0.7;
      }
      raw.add((e, best, q, bestMatched));
    }
    // 읽은 조각을 가장 많이 설명한 후보 = 1 (사진의 다른 글자 · 작품 이름처럼 아무 상품도 설명 못 하는 것은 모두에게 같다)
    final scored = <OcrCandidate>[];
    for (final (e, s, q, matched) in raw) {
      final score = (s * (maxQ == 0 ? 1 : q / maxQ) * 100).round().clamp(0, 99);
      if (score < minScore) continue;
      scored.add(OcrCandidate(_kits[e.i], score, matched.take(5).toList()));
    }
    scored.sort((a, b) {
      final s = b.score.compareTo(a.score);
      if (s != 0) return s;
      final g = (a.kit.type == '굿즈' ? 1 : 0).compareTo(b.kit.type == '굿즈' ? 1 : 0);
      return g != 0 ? g : b.kit.date.compareTo(a.kit.date);
    });
    return [...out, ...scored].take(limit).toList();
  }
}

/// 형식번호 맞춤: 같으면 1, 한쪽이 다른 쪽 + 영문 꼬리(XVX-016 ↔ XVX-016RN)면 0.6, 아니면 0
double _modelMatch(String a, String b) {
  if (a == b) return 1;
  final (s, l) = a.length < b.length ? (a, b) : (b, a);
  if (s.length >= 4 && l.startsWith(s) && RegExp(r'^[a-z]+$').hasMatch(l.substring(s.length))) return 0.6;
  return 0;
}
