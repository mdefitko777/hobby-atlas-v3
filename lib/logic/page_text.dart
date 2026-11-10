// 앱 안 웹 페이지(공식 예고 원문)의 일본어 글을 한국어로 바꿔 끼우기 — 페이지 쪽 스크립트와 고를 글
// 번역 자체는 lib/data/page_translate.dart (기기 안 ML Kit). 그림 안 글자는 바꾸지 못한다.
import 'dart:convert';

/// 가나 · 한자가 있는 글 (일본어로 볼 것)
final _japanese = RegExp(r'[぀-ヿ㐀-鿿ｦ-ﾟ]');

/// 번역할 글 — 일본어가 있는 것만, 앞뒤 빈칸을 빼고, 같은 글은 한 번, 많아도 [max] 개 (긴 목록 페이지)
List<String> textsToTranslate(Iterable<String> raw, {int max = 800}) {
  final out = <String>[];
  final seen = <String>{};
  for (final s in raw) {
    final t = s.trim();
    if (t.isEmpty || !_japanese.hasMatch(t) || !seen.add(t)) continue;
    out.add(t);
    if (out.length >= max) break;
  }
  return out;
}

/// runJavaScriptReturningResult 결과 → 글 목록. 안드로이드는 JS 문자열을 한 번 더 JSON 으로 감싸 돌려준다
List<String> decodeTextList(Object? result) {
  Object? v = result;
  for (var i = 0; i < 2 && v is String; i++) {
    try {
      v = jsonDecode(v);
    } on FormatException {
      return const [];
    }
  }
  return v is List
      ? [
          for (final e in v)
            if (e is String) e,
        ]
      : const [];
}

/// 페이지의 글 조각(스크립트 · 스타일 밖, 일본어가 있는 것)을 모아 두고 그 글을 JSON 으로 돌려준다.
/// window.__haTr = { nodes, orig: 원문, cur: 우리가 마지막에 둔 글 }. 원문 안에서 넘긴 페이지(SPA)는 같은 window 라
/// 먼저 페이지가 지운 조각(isConnected 아님)은 버리고, 페이지가 글을 바꾼 조각(cur 과 다름)은 그 글을 새 원문으로 한다
const collectTextsJs = r'''
(function () {
  var re = /[぀-ヿ㐀-鿿ｦ-ﾟ]/;
  var skip = { SCRIPT: 1, STYLE: 1, NOSCRIPT: 1, TEXTAREA: 1 };
  if (!window.__haTr) window.__haTr = { nodes: [], orig: [], cur: [] };
  var t = window.__haTr, keepN = [], keepO = [], keepC = [];
  for (var j = 0; j < t.nodes.length; j++) {
    var x = t.nodes[j];
    // 떼어 낸 조각은 원문으로 돌려놓고 버린다 (뒤로 가기로 다시 붙으면 다시 모아진다)
    if (!x.isConnected) { if (x.nodeValue === t.cur[j]) x.nodeValue = t.orig[j]; continue; }
    var v = x.nodeValue;
    keepN.push(x);
    keepO.push(v === t.cur[j] ? t.orig[j] : v);
    keepC.push(v);
  }
  t.nodes = keepN; t.orig = keepO; t.cur = keepC;
  var known = new Set(t.nodes);
  var w = document.createTreeWalker(document.body || document.documentElement, NodeFilter.SHOW_TEXT, {
    acceptNode: function (n) {
      var p = n.parentElement;
      if (!p || skip[p.tagName]) return NodeFilter.FILTER_REJECT;
      return re.test(n.nodeValue) ? NodeFilter.FILTER_ACCEPT : NodeFilter.FILTER_REJECT;
    }
  });
  var n;
  while ((n = w.nextNode())) {
    if (known.has(n)) continue;
    t.nodes.push(n);
    t.orig.push(n.nodeValue);
    t.cur.push(n.nodeValue);
  }
  return JSON.stringify(t.orig.map(function (s) { return s.trim(); }));
})();
''';

/// 모아 둔 글 조각을 [translated] (원문 → 번역) 으로 바꾼다. 모은 뒤 페이지가 바꾼 조각은 건드리지 않는다.
/// 번역은 함수로 넣는다 — 글로 넣으면 String.replace 가 번역 안의 `$&` · `$$` · `$'` 같은 것을 바꿔 버린다
/// (이 Dart 글은 r'' 이 아니라 안에 달러 기호를 쓰지 않는다)
String applyTranslationsJs(Map<String, String> translated) =>
    '''
(function (m) {
  var t = window.__haTr; if (!t) return 0;
  var done = 0;
  for (var i = 0; i < t.nodes.length; i++) {
    var o = t.orig[i], k = o.trim();
    if (t.nodes[i].nodeValue !== t.cur[i] || !Object.prototype.hasOwnProperty.call(m, k)) continue;
    t.nodes[i].nodeValue = t.cur[i] = o.replace(k, function () { return m[k]; });
    done++;
  }
  return done;
})(${jsonEncode(translated)});
''';

/// 원문으로 되돌리기 (모은 뒤 페이지가 바꾼 조각은 그대로)
const restoreTextsJs = r'''
(function () {
  var t = window.__haTr; if (!t) return 0;
  var done = 0;
  for (var i = 0; i < t.nodes.length; i++) {
    if (t.nodes[i].nodeValue !== t.cur[i]) continue;
    t.nodes[i].nodeValue = t.cur[i] = t.orig[i];
    done++;
  }
  return done;
})();
''';
