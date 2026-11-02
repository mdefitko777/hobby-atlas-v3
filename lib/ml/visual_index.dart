// 생김새로 찾기 (E-18) — 상품 공식 그림의 "생김새 벡터" 표 · 가장 비슷한 상품 고르기. 순수 Dart (테스트 가능).
// 표는 Gunpula 가 매주 만든다 (scripts/imgsim/build_vectors.py → release imgsim / imgsim-vectors.bin).
// 파일: b'HAIS' · 판 1 · u32 차원 · u32 줄 수 · u32 JSON 길이 · JSON {model, updated, ids, src} · f32 배율[줄] · i8 벡터[줄 × 차원]
// 한 상품에 줄이 둘일 수 있다 (대표 사진 + 상자 그림) — 상품 점수는 그중 큰 것.
library;

import 'dart:convert';
import 'dart:math' show sqrt;
import 'dart:typed_data';

/// 비슷한 상품 하나 (score = 코사인 유사도, 대략 0.0–1.0)
typedef VisualHit = ({String kitId, double score});

class VisualIndex {
  VisualIndex._(this.dim, this.model, this.updated, this.ids, this._scale, this._vec);

  /// 사진 하나의 벡터 길이 (SigLIP2 B/32 = 768)
  final int dim;
  final String model;
  final String updated;

  /// 줄마다 상품 id (같은 상품이 두 줄일 수 있다)
  final List<String> ids;
  final Float32List _scale;
  final Int8List _vec;

  int get rows => ids.length;

  /// 파일 바이트 → 표. 모양이 틀리면 FormatException
  factory VisualIndex.parse(Uint8List bytes) {
    if (bytes.length < 20 || ascii.decode(bytes.sublist(0, 4), allowInvalid: true) != 'HAIS' || bytes[4] != 1) {
      throw const FormatException('생김새 표 파일이 아니에요');
    }
    final head = ByteData.sublistView(bytes, 8, 20);
    final dim = head.getUint32(0, Endian.little);
    final n = head.getUint32(4, Endian.little);
    final jl = head.getUint32(8, Endian.little);
    final scaleAt = 20 + jl;
    final vecAt = scaleAt + 4 * n;
    if (dim == 0 || jl % 4 != 0 || bytes.length < vecAt + n * dim) throw const FormatException('생김새 표가 잘렸어요');
    final meta = jsonDecode(utf8.decode(bytes.sublist(20, scaleAt))) as Map<String, Object?>;
    final ids = (meta['ids']! as List).cast<String>();
    if (ids.length != n) throw const FormatException('생김새 표 줄 수가 맞지 않아요');
    // 배율은 4바이트 경계 (20 + jl, jl 은 4의 배수) — 복사해서 정렬 걱정 없이
    final scale = Float32List(n);
    final sd = ByteData.sublistView(bytes, scaleAt, vecAt);
    for (var i = 0; i < n; i++) {
      scale[i] = sd.getFloat32(i * 4, Endian.little);
    }
    return VisualIndex._(
      dim,
      '${meta['model'] ?? ''}',
      '${meta['updated'] ?? ''}',
      ids,
      scale,
      Int8List.sublistView(bytes, vecAt, vecAt + n * dim),
    );
  }

  /// [query](L2 정규화된 벡터)와 가장 비슷한 상품 [k]개 — 상품마다 가장 높은 줄 하나만
  List<VisualHit> nearest(Float32List query, {int k = 12, Set<String>? only}) {
    if (query.length != dim) throw ArgumentError('벡터 길이 ${query.length} ≠ $dim');
    final best = <String, double>{};
    final d = dim;
    for (var r = 0; r < rows; r++) {
      final id = ids[r];
      if (only != null && !only.contains(id)) continue;
      final o = r * d;
      var s0 = 0.0, s1 = 0.0, s2 = 0.0, s3 = 0.0;
      var j = 0;
      for (; j + 3 < d; j += 4) {
        s0 += query[j] * _vec[o + j];
        s1 += query[j + 1] * _vec[o + j + 1];
        s2 += query[j + 2] * _vec[o + j + 2];
        s3 += query[j + 3] * _vec[o + j + 3];
      }
      for (; j < d; j++) {
        s0 += query[j] * _vec[o + j];
      }
      final s = (s0 + s1 + s2 + s3) * _scale[r];
      final prev = best[id];
      if (prev == null || s > prev) best[id] = s;
    }
    final out = [for (final e in best.entries) (kitId: e.key, score: e.value)]
      ..sort((a, b) => b.score.compareTo(a.score));
    return out.take(k).toList();
  }
}

/// 벡터를 길이 1로 (모델이 이미 정규화하지만 int8 가중치 오차 · 안전)
Float32List l2normalize(List<double> v) {
  var s = 0.0;
  for (final x in v) {
    s += x * x;
  }
  final n = s <= 0 ? 1.0 : 1 / sqrt(s);
  return Float32List.fromList([for (final x in v) x * n]);
}

/// 모델 입력: 짧은 변을 [size]로 줄인 RGBA(곱해진 알파) 그림 → 가운데 [size]×[size] 를 흰 바탕에 얹은 0–1 RGB (NHWC)
/// (Gunpula build_vectors.py 의 prep 와 같은 순서: 알파 → 흰 바탕, 짧은 변 맞춤, 가운데 자르기, ÷255)
Float32List cropToInput(Uint8List rgba, int width, int height, {int size = 256}) {
  if (width < size || height < size) throw ArgumentError('그림이 $size 보다 작아요 ($width×$height)');
  final left = (width - size) ~/ 2;
  final top = (height - size) ~/ 2;
  final out = Float32List(size * size * 3);
  var o = 0;
  for (var y = 0; y < size; y++) {
    var p = ((top + y) * width + left) * 4;
    for (var x = 0; x < size; x++, p += 4) {
      final a = rgba[p + 3];
      // 곱해진 알파 위에 흰 바탕: c + (255 − a)
      out[o++] = (rgba[p] + 255 - a) / 255;
      out[o++] = (rgba[p + 1] + 255 - a) / 255;
      out[o++] = (rgba[p + 2] + 255 - a) / 255;
    }
  }
  return out;
}

/// 짧은 변이 [size] 가 되게 줄일 크기 (작은 사진은 늘린다)
(int, int) resizeForCrop(int width, int height, {int size = 256}) {
  final s = size / (width < height ? width : height);
  int r(double v) => v.round() < size ? size : v.round();
  return (r(width * s), r(height * s));
}
