// 인터넷 그림을 칸 크기만큼만 풀기 · 작은 그림 주소(Rebrickable · Gunpula data/thumbs.json) — 순수 Dart.
// 점검(2026-11-14): 52 dp 알림 칸(3배 화면 156 px)에 560–2400 px 원본을 그대로 풀어 메모리 캐시(100 MB)가 30장쯤에서 차고,
// 화면을 오갈 때마다 다시 읽고 다시 풀었다. 칸 크기로 풀면 「최근 추가」 60칸이 143 MB → 약 35 MB.
import 'dart:convert';
import 'dart:math' as math;

/// 그림을 칸에 맞추는 방법 (BoxFit 중 크기에 영향을 주는 것만)
enum DecodeFit { cover, contain, width, height, fill }

/// 칸 한 변(물리 px)을 이 값의 배수로 올린다 — 칸 크기가 조금씩 달라도 같은 크기로 풀어 메모리 캐시를 같이 쓰게
const decodeStep = 64;

/// 칸 한 변(물리 px) → 풀 크기 기준. 끝없는 변(세로로 늘어나는 칸)은 그대로
double decodeBucket(double px) =>
    px.isFinite ? math.max(decodeStep, (px / decodeStep).ceil() * decodeStep).toDouble() : px;

/// 원본 [iw]×[ih] 를 칸 [boxW]×[boxH](물리 px)에 [fit] 으로 그릴 때 풀 크기. null = 원본 그대로
/// (칸보다 작은 그림 — 키우지 않는다 · 칸 크기를 모름)
({int width, int height})? decodeSize(int iw, int ih, double boxW, double boxH, DecodeFit fit) {
  if (iw <= 0 || ih <= 0) return null;
  final sx = boxW.isFinite && boxW > 0 ? boxW / iw : double.infinity;
  final sy = boxH.isFinite && boxH > 0 ? boxH / ih : double.infinity;
  if (sx.isInfinite && sy.isInfinite) return null;
  if (fit == DecodeFit.fill) {
    // 늘려 채우기: 가로 · 세로 따로 (모르는 변은 원본)
    final w = sx.isFinite ? math.min(iw, boxW.ceil()) : iw;
    final h = sy.isFinite ? math.min(ih, boxH.ceil()) : ih;
    return w == iw && h == ih ? null : (width: w, height: h);
  }
  // 모르는 변(무한)은 빼고 본다 — cover 는 아는 변을 채우면 되고, contain 은 min 이 알아서 아는 변을 고른다
  final scale = switch (fit) {
    DecodeFit.cover => sx.isFinite && sy.isFinite ? math.max(sx, sy) : math.min(sx, sy),
    DecodeFit.contain => math.min(sx, sy),
    DecodeFit.width => sx.isFinite ? sx : sy,
    DecodeFit.height => sy.isFinite ? sy : sx,
    DecodeFit.fill => 1.0,
  };
  if (scale >= 1) return null;
  return (width: math.max(1, (iw * scale).ceil()), height: math.max(1, (ih * scale).ceil()));
}

/// 작은 그림 주소 — 없으면 [url] 그대로. [px] = 칸의 긴 변(물리 px), [thumbs] = Gunpula 작은 그림 목록
/// 레고 표지는 전부 Rebrickable 원본(점검 2026-11-14: 31209-1 은 2048×2160 · 4.25 MB · 1.5초)인데,
/// 같은 그림의 줄인 판(thumbs/…/250x250p · 500x500p)을 그 서버가 같이 준다 (250 = 104 KB, 500 = 355 KB).
/// 작은 판이 없으면 그림 쪽(images.dart)이 원본으로 다시 받는다.
String imageThumbUrl(String url, double px, [ThumbIndex? thumbs]) {
  if (!px.isFinite || px <= 0) return url;
  const rebrickable = 'https://cdn.rebrickable.com/media/sets/';
  if (url.startsWith(rebrickable)) {
    final size = px <= 250 ? '250x250p' : (px <= 500 ? '500x500p' : '');
    if (size.isEmpty) return url;
    return 'https://cdn.rebrickable.com/media/thumbs/sets/${url.substring(rebrickable.length)}/$size.jpg';
  }
  final t = thumbs ?? ThumbIndex.current;
  return t.fits(px) ? t.of(url) ?? url : url;
}

/// Gunpula 가 발행하는 작은 그림 목록 (data/thumbs.json `gunpula-thumbs-v1` — 원본 주소 → 사진 저장소의 WebP,
/// 긴 변 [maxSide] px). 파일이 없거나(옛 데이터 · 404) 모양이 다르면 [none] = 원본 그대로
class ThumbIndex {
  const ThumbIndex({this.thumbs = const {}, this.rules = const [], this.maxSide = 400});
  final Map<String, String> thumbs;
  final List<({String prefix, String thumbPrefix, String thumbSuffix})> rules;
  final int maxSide;

  static const none = ThumbIndex();

  /// 지금 쓰는 목록 — 카탈로그가 보조 파일을 읽으면 바꾼다 (lib/data/catalog.dart)
  static ThumbIndex current = none;

  bool get isEmpty => thumbs.isEmpty && rules.isEmpty;

  /// 칸이 작은 그림으로 충분한가. 잘라 채우기 칸은 그림의 짧은 변이 칸을 채워야 하는데, 상품 사진은 4:3 쯤이라
  /// 짧은 변 ≈ 긴 변 × 0.8 — 그보다 큰 칸에 쓰면 늘려 그려 흐려진다 (그럴 땐 원본을 칸 크기로 푼다)
  bool fits(double px) => !isEmpty && px <= maxSide * 0.8;

  /// [url] 의 작은 그림 (없으면 null). 주소는 발행된 그대로 비교한다
  String? of(String url) {
    if (thumbs[url] case final t?) return t;
    for (final r in rules) {
      if (url.startsWith(r.prefix)) return '${r.thumbPrefix}${url.substring(r.prefix.length)}${r.thumbSuffix}';
    }
    return null;
  }
}

/// data/thumbs.json 글 → [ThumbIndex] (compute 안에서도 돈다). 모양이 다르면 [ThumbIndex.none]
ThumbIndex parseThumbIndex(String text) {
  final Object? v;
  try {
    v = jsonDecode(text);
  } on FormatException {
    return ThumbIndex.none;
  }
  if (v is! Map || v['schema'] != 'gunpula-thumbs-v1') return ThumbIndex.none;
  final thumbs = v['thumbs'];
  final rules = v['rules'];
  final max = v['max_side'];
  return ThumbIndex(
    thumbs: {
      if (thumbs is Map)
        for (final e in thumbs.entries)
          if (e.key is String && e.value is String && '${e.value}'.startsWith('https://'))
            e.key as String: e.value as String,
    },
    rules: [
      if (rules is List)
        for (final r in rules)
          if (r is Map &&
              r['prefix'] is String &&
              (r['prefix'] as String).isNotEmpty &&
              '${r['thumb_prefix']}'.startsWith('https://'))
            (
              prefix: r['prefix'] as String,
              thumbPrefix: r['thumb_prefix'] as String,
              thumbSuffix: r['thumb_suffix'] is String ? r['thumb_suffix'] as String : '',
            ),
    ],
    maxSide: max is num && max > 0 ? max.toInt() : 400,
  );
}
