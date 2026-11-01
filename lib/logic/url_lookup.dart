// 공유로 받은 주소 → 상품 (프리미엄 반다이 · 반다이 하비 · 혼웹 · 코토부키야 · 굿스마일 · 가샤폰 · 아마존 …).
//   1) 주소를 같은 모양으로 고친다: https · www · 언어 칸(/en/ · /ja/) · 끝 / · 추적 값(utm_ …)을 떼고, 상품을 가리키는 값(prd_id · jan_code …)만 남긴다
//   2) 상품의 출처 주소(Kit.officialUrl + Kit.sourceUrls)와 같으면 그 상품
//   3) 없으면 주소 안의 JAN 13자리(검사 숫자가 맞는 것) → 바코드가 같은 상품
//   4) 없으면 프리미엄 반다이 item-<번호> → 그 번호가 든 상품 id · 출처 주소
// Flutter 를 쓰지 않는다 (단위 테스트 · compute 안 매핑 함수도 isListingUrl 을 부른다).
import '../models.dart';
import 'kit_rules.dart' show kitsWithBarcode;

/// 글 안의 주소 (http · https)
final _urlRe = RegExp(r'https?://[^\s<>"「」『』（）()]+', caseSensitive: false);

List<String> urlsIn(String text) => [
  for (final m in _urlRe.allMatches(text)) m.group(0)!.replaceFirst(RegExp(r'[.,;:!?。、]+$'), ''),
];

/// 상품을 가리키는 값 (이것만 남긴다)
const _idParams = {'prd_id', 'jan_code', 'jan', 'productno', 'product_no', 'item_id', 'goods_id', 'item_code', 'id', 'pid'};

/// 언어 · 지역 칸 (/en/ · /ja/ · /en-others/ …) — 같은 상품의 다른 언어 페이지
final _localeSeg = RegExp(r'^(en|ja|jp|ko|kr|zh|tw|hk|cn|zh-hant|zh-hans|zh-tw|en-others|en-us|en-gb|ja-jp|ko-kr|global)$');

/// 목록 · 검색 페이지 (상품 하나가 아님) — 매핑 때 출처 주소에서 뺀다
bool isListingUrl(String url) {
  final u = url.toLowerCase();
  return u.contains('result.php') ||
      u.contains('search.aspx') ||
      u.contains('item_brand') ||
      u.contains('?category=') ||
      u.contains('?free=') ||
      u.contains('?keyword=') ||
      u.endsWith('/lineup/') ||
      u.endsWith('/products/') ||
      RegExp(r'/title/[^/]+/?$').hasMatch(u);
}

/// 비교용 주소 열쇠: 호스트(www 뗌) + 경로(언어 칸 · 끝 / 뗌, 소문자) + 상품 값 (정렬). 주소가 아니면 ''
String urlKey(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return '';
  final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^(www|m|sp)\.'), '');
  final segs = [
    for (final s in uri.pathSegments)
      if (s.isNotEmpty && !_localeSeg.hasMatch(s.toLowerCase())) s.toLowerCase(),
  ];
  // 굿스마일 옛 주소: /product/8394/Scathach+…html → 번호까지만
  final keep = <String>[];
  for (final s in segs) {
    keep.add(s);
    if (keep.length >= 2 && keep[keep.length - 2] == 'product' && RegExp(r'^\d+$').hasMatch(s)) break;
  }
  final params = <String>[
    for (final e in uri.queryParameters.entries)
      if (_idParams.contains(e.key.toLowerCase())) '${e.key.toLowerCase()}=${e.value.toLowerCase()}',
  ]..sort();
  return [host, keep.join('/'), if (params.isNotEmpty) params.join('&')].join('|');
}

/// 주소 안의 JAN (검사 숫자가 맞는 13 · 8자리). 반다이 스피리츠 prd_id(16자리)는 앞 13자리
List<String> jansInUrl(String url) {
  final out = <String>[];
  for (final m in RegExp(r'(?<!\d)(\d{13,16})(?!\d)').allMatches(url)) {
    final d = m.group(1)!.substring(0, 13);
    if (validEan(d) && !out.contains(d)) out.add(d);
  }
  return out;
}

/// EAN-13 · EAN-8 검사 숫자 (오른쪽에서 두 번째부터 ×3, ×1 번갈아)
bool validEan(String d) {
  if ((d.length != 13 && d.length != 8) || !RegExp(r'^\d+$').hasMatch(d)) return false;
  var sum = 0;
  for (var i = 0; i < d.length - 1; i++) {
    final w = (d.length - 1 - i).isOdd ? 3 : 1;
    sum += (d.codeUnitAt(i) - 48) * w;
  }
  return (10 - sum % 10) % 10 == d.codeUnitAt(d.length - 1) - 48;
}

/// 프리미엄 반다이 상품 번호 (item-1000255590)
String pbandaiItem(String url) => RegExp(r'p-bandai\.(?:jp|com)/.*?item-(\d{6,})').firstMatch(url)?.group(1) ?? '';

/// 주소로 찾은 것: 상품 + 어떻게 찾았나 ('주소' · 'JAN …' · '상품 번호 …')
class UrlHit {
  const UrlHit(this.kit, this.how);
  final Kit kit;
  final String how;
}

/// 상품 출처 주소 → 상품 (한 번 만들어 두고 여러 번 찾는다)
class UrlIndex {
  UrlIndex(Iterable<Kit> kits) : _kits = kits.toList(growable: false) {
    for (final k in _kits) {
      for (final u in {if (k.officialUrl.isNotEmpty) k.officialUrl, ...k.sourceUrls}) {
        final key = urlKey(u);
        if (key.isNotEmpty) (_byKey[key] ??= []).add(k);
      }
    }
  }

  final List<Kit> _kits;
  final Map<String, List<Kit>> _byKey = {};

  List<UrlHit> find(String url) {
    final key = urlKey(url);
    if (key.isEmpty) return const [];
    if (_byKey[key] case final ks?) return [for (final k in ks) UrlHit(k, '주소')];
    for (final jan in jansInUrl(url)) {
      final ks = kitsWithBarcode(_kits, jan);
      if (ks.isNotEmpty) return [for (final k in ks) UrlHit(k, 'JAN $jan')];
    }
    final item = pbandaiItem(url);
    if (item.isNotEmpty) {
      final needle = 'item-$item';
      final ks = [
        for (final k in _kits)
          if (k.id.endsWith('-$item') || k.officialUrl.contains(needle) || k.sourceUrls.any((u) => u.contains(needle))) k,
      ];
      if (ks.isNotEmpty) return [for (final k in ks) UrlHit(k, '상품 번호 $item')];
    }
    return const [];
  }

  /// 글 안의 주소를 차례로 (처음 찾은 주소의 상품들, 같은 상품은 한 번)
  List<UrlHit> findInText(String text) {
    for (final u in urlsIn(text)) {
      final hits = find(u);
      if (hits.isNotEmpty) {
        final seen = <String>{};
        return [
          for (final h in hits)
            if (seen.add(h.kit.id)) h,
        ];
      }
    }
    return const [];
  }
}
