// 프렌다 공식 페이지(pokemonfrienda.com) HTML → 픽 id 별 그림 주소. 순수 Dart, 정규식.
// 규칙은 Gunpula scripts/atlas/frienda/parse.mjs · build_pokemon_frienda.mjs 와 같다:
//   탄 페이지 /new/<탄>.html   #friendapick 의 <li class="grid__item"> — 첫 <p> 가 인쇄 번호 (1-1-001 · 3-2-036A · ★ → S)
//   /new/wonder/ · /new/special/  #specialfriendapick — 그림 이름이 id (3-2-W01.webp · p053.webp → P-053)
// 그림은 Gunpula 공개 데이터에 넣지 않는다 (사이트 약관이 다른 사이트의 그림 직링크를 삼가 달라고 함) —
// 앱이 이 기기에서 공식 페이지를 읽어 기기에만 둔다 (lib/data/frienda_images.dart).

/// 칸에 쓸 작은 그림 · 크게 볼 그림
typedef PickImage = ({String thumb, String full});

/// 페이지 하나의 그림 — {픽 id: 그림}. 모르는 모양의 칸은 건너뛴다
Map<String, PickImage> friendaPageImages(String html, Uri page) {
  final out = <String, PickImage>{};
  for (final (id, special) in const [('friendapick', false), ('specialfriendapick', true)]) {
    final sec = _section(html, id);
    if (sec == null) continue;
    for (final it in _gridItems(sec, page)) {
      final pickId = special ? _specialId(it.file) : _numberId(it.no);
      if (pickId == null || (it.thumb.isEmpty && it.full.isEmpty)) continue;
      out[pickId] = (thumb: it.thumb.isNotEmpty ? it.thumb : it.full, full: it.full.isNotEmpty ? it.full : it.thumb);
    }
  }
  return out;
}

/// 탄 칸: 인쇄 번호 → frienda:<번호> (전각 → 반각, ★ · ☆ → S, 띄어쓰기 없앰)
String? _numberId(String no) {
  final n = _halfWidth(no).replaceAll(RegExp('[★☆]'), 'S').replaceAll(RegExp(r'\s+'), '');
  return RegExp(r'^\d+-\d+-\d{3}[A-Z]?S?$').hasMatch(n) ? 'frienda:$n' : null;
}

/// 원더 · 스페셜 칸: 그림 이름 → id
String? _specialId(String file) {
  final w = RegExp(r'^(\d+-\d+-W\d+)\.webp$', caseSensitive: false).firstMatch(file);
  if (w != null) return 'frienda:${w.group(1)}';
  final p = RegExp(r'^p(\d+)(?:-[A-Za-z0-9]+)?\.webp$', caseSensitive: false).firstMatch(file);
  if (p != null) return 'frienda:P-${p.group(1)!.padLeft(3, '0')}';
  return null;
}

String _halfWidth(String s) =>
    String.fromCharCodes(s.runes.map((c) => c >= 0xFF01 && c <= 0xFF5E ? c - 0xFEE0 : (c == 0x3000 ? 0x20 : c)));

String? _section(String html, String id) =>
    RegExp('<section\\b[^>]*\\bid="$id"[^>]*>([\\s\\S]*?)</section>', caseSensitive: false).firstMatch(html)?.group(1);

String? _attr(String tag, String name) =>
    RegExp('\\b$name\\s*=\\s*"([^"]*)"', caseSensitive: false).firstMatch(tag)?.group(1);

const _entities = {'amp': '&', 'lt': '<', 'gt': '>', 'quot': '"', 'apos': "'", 'nbsp': ' '};

String _text(String s) => s
    .replaceAll(RegExp(r'<[^>]+>'), ' ')
    .replaceAllMapped(RegExp(r'&(#x[0-9a-f]+|#\d+|[a-z]+);', caseSensitive: false), (m) {
      final e = m.group(1)!;
      if (e.startsWith('#x') || e.startsWith('#X')) return String.fromCharCode(int.parse(e.substring(2), radix: 16));
      if (e.startsWith('#')) return String.fromCharCode(int.parse(e.substring(1)));
      return _entities[e.toLowerCase()] ?? m.group(0)!;
    })
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

typedef _Item = ({String no, String thumb, String full, String file});

List<_Item> _gridItems(String fragment, Uri page) {
  String abs(String? href) => href == null || href.isEmpty ? '' : page.resolve(href).toString();
  return [
    for (final m in RegExp(
      r'<li\s+class="grid__item[^"]*"\s*>([\s\S]*?)</li>',
      caseSensitive: false,
    ).allMatches(fragment))
      () {
        final body = m.group(1)!;
        final a = RegExp(r'<a\b[^>]*>', caseSensitive: false).firstMatch(body)?.group(0) ?? '';
        final img = RegExp(r'<img\b[^>]*>', caseSensitive: false).firstMatch(body)?.group(0) ?? '';
        final ps = RegExp(r'<p\b[^>]*>([\s\S]*?)</p>', caseSensitive: false).allMatches(body);
        final full = _attr(a, 'data-img');
        final thumb = _attr(img, 'src');
        return (
          no: ps.isEmpty ? '' : _text(ps.first.group(1)!),
          thumb: abs(thumb),
          full: abs(full),
          file: (full ?? thumb ?? '').split('/').last,
        );
      }(),
  ];
}
