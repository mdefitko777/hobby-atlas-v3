// Name clean-up for phstudy (via Gunpula bbx-database.json) part and series
// names. phstudy names carry the set code ("BX-14-03 "), a finish suffix
// ("Metallic Coat: Gold", "スペシャルVer.", "金屬塗層:燦金", "레드 버전") and
// sometimes stray Unity line breaks. Stripping them gives the mold's base name,
// which is what box names are made of and what recolours share.

/// The four name languages in bbx-database.json (`names.{zh,ko,en,ja}`).
const bbxLangs = ['ja', 'ko', 'zh', 'en'];

/// Fold full-width ASCII (U+FF01..U+FF5E) to ASCII, ideographic space to space,
/// both real and escaped ("\n" as two characters) line breaks to spaces, and
/// collapse runs of whitespace. Dart has no NFKC; this is the part of it the
/// phstudy names need ("F／Rage" -> "F/Rage", "ｘ" -> "x").
String foldWidth(String input) {
  final out = StringBuffer();
  for (final rune in input.replaceAll(r'\n', ' ').runes) {
    if (rune >= 0xFF01 && rune <= 0xFF5E) {
      out.writeCharCode(rune - 0xFEE0);
    } else if (rune == 0x3000 || rune == 0x0A || rune == 0x0D || rune == 0x09) {
      out.write(' ');
    } else {
      out.writeCharCode(rune);
    }
  }
  return out.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

final _setPrefix = RegExp(r'^[A-Z]{1,4}-\d+[A-Z]?(?:-\d+)?(?:\s*>)?\s*');

/// "BX-14-03 Sword Dran" -> "Sword Dran". Names without a set code are kept.
String stripSetPrefix(String name) => name.replaceFirst(_setPrefix, '');

const _colourWords =
    'Red|Blue|Black|White|Gold|Silver|Green|Orange|Yellow|Purple|Violet|Pink|'
    'Navy|Bronze|Cyan|Magenta|Clear|ClearBlack|Clear Black|Special|Holo sticker';

// Applied in order, repeatedly, until nothing changes. Each pattern removes a
// finish / edition marker from the end (or a promo marker from the start).
final _finish = <String, List<RegExp>>{
  'en': [
    RegExp(r'\s*(?:Double\s+)?Metallic Coat\s*:.*$', caseSensitive: false),
    RegExp(r'\s*DMM Kuji.*$', caseSensitive: false),
    RegExp(r'\s*Special Cross Bey$', caseSensitive: false),
    RegExp(r'\s*Version\s*\d+(?:\.\d+)?$', caseSensitive: false),
    RegExp('\\s+(?:$_colourWords)\\s+Ver\\.?\$', caseSensitive: false),
    RegExp(r'\s*\([^)]*type\)$', caseSensitive: false),
    RegExp(r'(?<=\d[A-Za-z]{1,3})\s+\S+\s+Type$', caseSensitive: false),
    RegExp(r'\s+Blade$'),
  ],
  'ja': [
    RegExp(r'^DMMくじ.*?賞\s*'),
    RegExp(r'^スペシャルクロスベイ\s*'),
    RegExp(r'\s*(?:ダブル)?メタルコート\s*:.*$'),
    RegExp(r'\s*バージョン\s*\d+(?:\.\d+)?$'),
    RegExp(r'\s+\S*Ver\.?$'),
    RegExp(r'\s+ブレード$'),
  ],
  'ko': [
    RegExp(r'^DMM\s*추첨\s*\S+\s*'),
    RegExp(r'\s*DMM\s*추첨.*$'),
    RegExp(r'\s*스페셜\s*크로스\s*베이$'),
    RegExp(r'\s*메탈\s*코(?:트|팅)\s*:.*$'),
    RegExp(r'\s*버전\s*\d+(?:\.\d+)?$'),
    RegExp(r'\s+(?:홀로 스티커|\S+)\s*버전$'),
    RegExp(r'\s*\([^)]*\)$'),
    RegExp(r'(?<=\d[A-Za-z]{1,3})\s+\S+형$'),
    RegExp(r'\s+블레이드$'),
  ],
  'zh': [
    RegExp(r'\s*DMM\s*抽獎.*$'),
    RegExp(r'\s*金屬塗層\s*:.*$'),
    RegExp(r'\s*版本\s*\d+(?:\.\d+)?$'),
    RegExp(r'\s+\S*版$'),
    RegExp(r'\s*特別合體陀螺$'),
    RegExp(r'\s*\([^)]*\)$'),
    RegExp(r'(?<=\d[A-Za-z]{1,3})\s+\S+型$'),
    RegExp(r'\s*鋼鐵戰刃$'),
  ],
};

// A box name glued onto a blade name ("Sword Dran 1-60V Metallic Coat: ...").
final _comboTail = RegExp(r'\s+[0-9M]-\d\d[A-Za-z]+$');

/// Base (mold) name of a part or series name in [lang]: width folded, set code
/// and finish removed. "BXH-25-01 Strike Dran Metallic Coat: Gold" ->
/// "Strike Dran".
String baseName(String raw, String lang) {
  var s = stripSetPrefix(foldWidth(raw));
  // An untranslated "en" name is cleaned with the Japanese rules.
  final rules = _finish[lang == 'en' && hasCjk(s) ? 'ja' : lang] ?? _finish['en']!;
  for (var guard = 0; guard < 6; guard++) {
    final before = s;
    for (final r in rules) {
      s = s.replaceFirst(r, '').trim();
    }
    if (s == before) break;
  }
  return s;
}

/// Base name with a trailing glued-on box name removed as well (part names
/// only; a series name *is* a box name).
String partBaseName(String raw, String lang) => baseName(raw, lang).replaceFirst(_comboTail, '').trim();

/// Comparison key: no whitespace or middle dots, upper case.
String nameKey(String s) => foldWidth(s).replaceAll(RegExp(r'[\s・･]'), '').toUpperCase();

const _smallKana = 'ァィゥェォッャュョヮぁぃぅぇぉっゃゅょゎ';
const _largeKana = 'アイウエオツヤユヨワあいうえおつやゆよわ';

/// [nameKey] that also ignores small / large kana ("ウイザード" = "ウィザード"),
/// for comparing printed names that contain typos.
String looseNameKey(String s) {
  final out = StringBuffer();
  for (final ch in nameKey(s).split('')) {
    final i = _smallKana.indexOf(ch);
    out.write(i < 0 ? ch : _largeKana[i]);
  }
  return out.toString();
}

/// True when [s] contains kana, kanji or hangul (an untranslated "en" name).
bool hasCjk(String s) => RegExp(r'[぀-ヿ㐀-鿿가-힯]').hasMatch(s);
