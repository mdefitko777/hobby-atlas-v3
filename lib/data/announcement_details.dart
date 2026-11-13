// 예고의 상품 소개 — Catalog 보조 파일 announcement-details.json (Gunpula, 예고 id 별 공식 상품 페이지 글 · 사진).
// 모양 (schema 1): {schema, updated_at, extractor_version, details: {예고 id: {page_url, lead, description[], spec[{label, value}],
//   contents[], price_jpy, price_text, sale_period_text, release_kind(ship · release), release_month, release_text, gallery[], …}}}
// 글은 일본어 그대로 (번역하지 않는다). announcements.json 에 넣지 않은 까닭: 크고(예고 줄마다 2–4 KB) 상세를 열 때만 쓴다.
// 없거나(404 — Gunpula 가 아직 안 만듦) 깨졌으면 빈 묶음 → 「상품 소개」 버튼이 숨는다. 같은 카탈로그 판 안에서는 한 번만 푼다.
import 'package:flutter/foundation.dart';

import '../json_util.dart';
import 'catalog.dart';
import 'gunpula.dart' show deadImage, resolveAsset;

/// 보조 파일 이름 (lib/data/gunpula.dart auxFiles)
const annDetailsFile = 'announcement-details.json';

/// 예고 하나의 상품 소개 (공식 상품 페이지에서 읽은 그대로)
class AnnDetail {
  const AnnDetail({
    this.pageUrl = '',
    this.lead = '',
    this.description = const [],
    this.spec = const [],
    this.contents = const [],
    this.priceJpy,
    this.priceText = '',
    this.saleText = '',
    this.releaseKind = '',
    this.releaseMonth = '',
    this.releaseText = '',
    this.gallery = const [],
  });

  /// 공식 상품 페이지 (없으면 예고 원문 주소를 연다)
  final String pageUrl;
  final String lead;

  /// 문단 (문단 안 줄바꿈은 그대로)
  final List<String> description;

  /// (이름, 값) — 이름도 일본어 그대로 (商品サイズ · 商品素材 …). セット内容 은 여기 없고 [contents]
  final List<(String, String)> spec;

  /// 구성품 (セット内容) 한 줄씩
  final List<String> contents;
  final int? priceJpy;
  final String priceText;

  /// 예약 기간 원문 ('2026年11月13日～') — 시각은 예고의 preorder_at 쪽에만 있다
  final String saleText;

  /// ship = 발송 달 (혼 웹 상점 発送月) · release = 발매 · 빈 글자 = 모름
  final String releaseKind;

  /// 'YYYY-MM'
  final String releaseMonth;
  final String releaseText;

  /// 공식 사진 (인터넷 주소, 12장까지)
  final List<String> gallery;

  /// 한 줄 → 모델. 보일 것(설명 · 사양 · 구성품 · 가격 · 사진)이 하나도 없으면 null —
  /// 읽기에 실패한 줄(error 만 있음)은 버튼이 없다. 내용이 있고 error 도 있으면(다시 읽기 실패) 옛 내용을 그대로 보인다
  static AnnDetail? fromJson(Object? json) {
    if (json is! Map) return null;
    final j = jMap(json);
    List<String> strs(Object? v) => [
      for (final s in jList(v))
        if (jStr(s).trim() case final t when t.isNotEmpty) t,
    ];
    final price = j['price_jpy'];
    final d = AnnDetail(
      pageUrl: jStr(j['page_url']),
      lead: jStr(j['lead']).trim(),
      description: strs(j['description']),
      spec: [
        for (final s in jList(j['spec']))
          if ((jStr(jMap(s)['label']).trim(), jStr(jMap(s)['value']).trim()) case (final l, final v) when v.isNotEmpty)
            (l, v),
      ],
      contents: strs(j['contents']),
      priceJpy: price is num && price > 0 ? price.toInt() : null,
      priceText: jStr(j['price_text']).trim(),
      saleText: jStr(j['sale_period_text']).trim(),
      releaseKind: jStr(j['release_kind']),
      releaseMonth: RegExp(r'^\d{4}-\d{2}$').hasMatch(jStr(j['release_month'])) ? jStr(j['release_month']) : '',
      releaseText: jStr(j['release_text']).trim(),
      gallery: [
        // 서명이 붙은 주소(THE GUNDAM BASE CloudFront)는 몇 분 뒤 열리지 않는다 — 혹시 들어와도 뺀다
        for (final u in strs(j['gallery']).map(resolveAsset))
          if (u.isNotEmpty && !deadImage(u)) u,
      ],
    );
    final showable =
        d.lead.isNotEmpty ||
        d.description.isNotEmpty ||
        d.spec.isNotEmpty ||
        d.contents.isNotEmpty ||
        d.priceJpy != null ||
        d.gallery.isNotEmpty;
    return showable ? d : null;
  }

  /// 파일 전체 → 예고 id 별 (보일 것이 없는 줄은 뺀다)
  static Map<String, AnnDetail> parseFile(Object? file) => {
    for (final e in jMap(jMap(file)['details']).entries) e.key: ?fromJson(e.value),
  };
}

Future<Map<String, AnnDetail>>? _cached;
int _cachedVersion = -1;

/// 예고 id → 상품 소개 (lib/data/restocks.dart 와 같은 길: 카탈로그 판마다 한 번)
Future<Map<String, AnnDetail>> loadAnnDetails() {
  final c = Catalog.instance;
  if (c.kits.isEmpty) return Future.value(const {}); // 카탈로그 전(테스트 · 첫 실행) — 기억하지 않는다
  if (_cached == null || _cachedVersion != c.version) {
    _cachedVersion = c.version;
    _cached = _load(c);
  }
  return _cached!;
}

Future<Map<String, AnnDetail>> _load(Catalog c) async {
  try {
    return AnnDetail.parseFile(await c.aux(annDetailsFile));
  } on Object catch (e) {
    debugPrint('[ann-details] $e');
    return const {};
  }
}
