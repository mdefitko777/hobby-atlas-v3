// 생김새로 찾기 전에 사진에서 물건만 고르는 틀 — 틀 끌기 · 모델 입력으로 바꾸는 계산 (순수 Dart).
// 집 · 가게에서 찍은 사진은 배경이 커서 생김새 비교가 배경을 닮은 상품으로 갔다. 손으로 상자를 맞추면
// 실사진 첫 후보가 포켓몬 +12 · 마도카 +15 점 (2026-11-14 imgsim 평가). 자동 상자는 득실이 섞여 쓰지 않는다.
library;

import 'dart:math' as math;

/// 사진 위 틀 — 사진 너비 · 높이에 대한 0–1 비율 (방향을 바로 세운 사진 기준)
typedef CropBox = ({double left, double top, double right, double bottom});

/// 사진 전체 (자르지 않음)
const CropBox fullCrop = (left: 0, top: 0, right: 1, bottom: 1);

/// 거의 전체면 자르지 않은 것으로 (손가락 오차로 1 % 남짓 줄어든 틀)
bool isFullCrop(CropBox b) => b.left <= 0.01 && b.top <= 0.01 && b.right >= 0.99 && b.bottom >= 0.99;

/// 끄는 곳: 틀 안 = 옮기기, 네 모서리 = 크기
enum CropGrip { move, topLeft, topRight, bottomLeft, bottomRight }

/// 누른 곳 ([x] · [y] 는 0–1 비율) → 끌 곳. 모서리에서 [reachX] · [reachY] 안이면 그 모서리, 틀 안이면 옮기기, 밖이면 null.
/// 손가락 칸은 화면 픽셀로 같아야 해서 가로 · 세로 비율을 따로 받는다
CropGrip? cropGripAt(CropBox b, double x, double y, {required double reachX, required double reachY}) {
  bool near(double px, double py) => (x - px).abs() <= reachX && (y - py).abs() <= reachY;
  if (near(b.left, b.top)) return CropGrip.topLeft;
  if (near(b.right, b.top)) return CropGrip.topRight;
  if (near(b.left, b.bottom)) return CropGrip.bottomLeft;
  if (near(b.right, b.bottom)) return CropGrip.bottomRight;
  if (x >= b.left && x <= b.right && y >= b.top && y <= b.bottom) return CropGrip.move;
  return null;
}

/// 틀을 [dx] · [dy](0–1 비율)만큼 끈다. 사진 밖으로 나가지 않고, 한 변이 [minW] · [minH] 보다 작아지지 않는다
CropBox dragCrop(CropBox b, CropGrip g, double dx, double dy, {double minW = 0.1, double minH = 0.1}) {
  switch (g) {
    case CropGrip.move:
      final mx = dx.clamp(-b.left, 1 - b.right);
      final my = dy.clamp(-b.top, 1 - b.bottom);
      return (left: b.left + mx, top: b.top + my, right: b.right + mx, bottom: b.bottom + my);
    case CropGrip.topLeft:
      return (
        left: (b.left + dx).clamp(0, b.right - minW),
        top: (b.top + dy).clamp(0, b.bottom - minH),
        right: b.right,
        bottom: b.bottom,
      );
    case CropGrip.topRight:
      return (
        left: b.left,
        top: (b.top + dy).clamp(0, b.bottom - minH),
        right: (b.right + dx).clamp(b.left + minW, 1),
        bottom: b.bottom,
      );
    case CropGrip.bottomLeft:
      return (
        left: (b.left + dx).clamp(0, b.right - minW),
        top: b.top,
        right: b.right,
        bottom: (b.bottom + dy).clamp(b.top + minH, 1),
      );
    case CropGrip.bottomRight:
      return (
        left: b.left,
        top: b.top,
        right: (b.right + dx).clamp(b.left + minW, 1),
        bottom: (b.bottom + dy).clamp(b.top + minH, 1),
      );
  }
}

/// 자른 사진을 모델 입력으로: 틀의 가운데 정사각형(짧은 변)을 [size]×[size] 로.
/// 상품 표(Gunpula build_vectors.py)의 "짧은 변 256 맞춤 → 가운데 자르기" 와 같은 부분이다.
/// [decodeW] × [decodeH] = 사진을 풀 크기 (정사각형 한 변이 [size] 에 가깝게 줄이되 늘리지는 않는다 — 큰 사진을 원래 크기로
/// 풀면 메모리가 크고, 늘려 풀면 더 크다), [src*] = 그 풀린 그림에서 가져올 정사각형 (픽셀)
({int decodeW, int decodeH, double srcLeft, double srcTop, double srcSide}) cropPlan(
  int width,
  int height,
  CropBox b, {
  int size = 256,
}) {
  final side = math.min((b.right - b.left) * width, (b.bottom - b.top) * height);
  final s = side <= 0 ? 1.0 : math.min(1.0, size / side);
  final dw = math.max(1, (width * s).round());
  final dh = math.max(1, (height * s).round());
  final sq = math.min((b.right - b.left) * dw, (b.bottom - b.top) * dh);
  final cx = (b.left + b.right) / 2 * dw, cy = (b.top + b.bottom) / 2 * dh;
  return (decodeW: dw, decodeH: dh, srcLeft: cx - sq / 2, srcTop: cy - sq / 2, srcSide: sq);
}
