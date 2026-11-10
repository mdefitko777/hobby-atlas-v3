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

/// 페이지의 글 조각(스크립트 · 스타일 밖, 일본어가 있는 것)을 모아 두고 그 글을 JSON 으로 돌려준다
const collectTextsJs = r'''
(function () {
  var re = /[぀-ヿ㐀-鿿ｦ-ﾟ]/;
  var skip = { SCRIPT: 1, STYLE: 1, NOSCRIPT: 1, TEXTAREA: 1 };
  var w = document.createTreeWalker(document.body || document.documentElement, NodeFilter.SHOW_TEXT, {
    acceptNode: function (n) {
      var p = n.parentElement;
      if (!p || skip[p.tagName]) return NodeFilter.FILTER_REJECT;
      return re.test(n.nodeValue) ? NodeFilter.FILTER_ACCEPT : NodeFilter.FILTER_REJECT;
    }
  });
  var nodes = [], n;
  while ((n = w.nextNode())) nodes.push(n);
  if (!window.__haTr) window.__haTr = { nodes: [], orig: [] };
  for (var i = 0; i < nodes.length; i++) {
    if (window.__haTr.nodes.indexOf(nodes[i]) < 0) {
      window.__haTr.nodes.push(nodes[i]);
      window.__haTr.orig.push(nodes[i].nodeValue);
    }
  }
  return JSON.stringify(window.__haTr.orig.map(function (s) { return s.trim(); }));
})();
''';

/// 모아 둔 글 조각을 [translated] (원문 → 번역) 으로 바꾼다
String applyTranslationsJs(Map<String, String> translated) =>
    '''
(function (m) {
  var t = window.__haTr; if (!t) return 0;
  var done = 0;
  for (var i = 0; i < t.nodes.length; i++) {
    var o = t.orig[i], k = o.trim();
    if (Object.prototype.hasOwnProperty.call(m, k)) { t.nodes[i].nodeValue = o.replace(k, m[k]); done++; }
  }
  return done;
})(${jsonEncode(translated)});
''';

/// 원문으로 되돌리기
const restoreTextsJs = r'''
(function () {
  var t = window.__haTr; if (!t) return 0;
  for (var i = 0; i < t.nodes.length; i++) t.nodes[i].nodeValue = t.orig[i];
  return t.nodes.length;
})();
''';
