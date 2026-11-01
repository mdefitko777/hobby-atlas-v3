// 사진 위 표시 — 왼쪽 위 책갈피 리본 = 구매함 · 왼쪽 아래 ♡ = 좋아요 (모든 상품 사진 · 도감 칸)
import 'package:flutter/material.dart';

import '../marks.dart';
import '../models.dart';
import '../theme.dart';

/// 사진 위 표시 (모든 상품 사진 · 도감 칸 공통): 왼쪽 위 책갈피 리본 = 구매함(+ → ✓) · 왼쪽 아래 ♡ = 좋아요
/// 보이는 크기는 작아도 누르는 자리는 44dp 이상 (P09 접근성)
class MarkOverlay extends StatelessWidget {
  const MarkOverlay({
    super.key,
    required this.liked,
    required this.owned,
    required this.onLike,
    required this.onOwn,
    this.size = 28,
  });

  final bool liked;
  final bool owned;
  final VoidCallback onLike;
  final VoidCallback onOwn;
  final double size;

  @override
  Widget build(BuildContext context) {
    final inset = size * 0.22;
    return Stack(
      children: [
        Positioned(
          left: 0,
          top: 0,
          child: Semantics(
            button: true,
            selected: owned,
            label: '구매함',
            child: GestureDetector(
              onTap: onOwn,
              behavior: HitTestBehavior.opaque,
              child: Container(
                // 누르는 자리 44 × 52
                width: 44,
                height: 52,
                alignment: Alignment.topLeft,
                padding: EdgeInsets.only(left: inset + 2),
                child: ClipPath(
                  clipper: const _RibbonClipper(),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: size + 2,
                    height: size * 1.4,
                    alignment: const Alignment(0, -0.3),
                    color: owned ? Gp.own : Gp.scrim,
                    child: Icon(owned ? Icons.check : Icons.add, size: size * 0.7, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          bottom: 0,
          child: Semantics(
            button: true,
            selected: liked,
            label: '좋아요',
            child: GestureDetector(
              onTap: onLike,
              behavior: HitTestBehavior.opaque,
              child: Container(
                // 누르는 자리 44 × 44
                width: 44,
                height: 44,
                alignment: Alignment.bottomLeft,
                padding: EdgeInsets.only(left: inset, bottom: inset),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: size,
                  height: size,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: liked ? Gp.panel : Gp.scrimLight),
                  child: Icon(
                    liked ? Icons.favorite : Icons.favorite_border,
                    size: size * 0.6,
                    color: liked ? Gp.accent : Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 상품 카드용 MarkOverlay — 앱 전체 좋아요 · 구매함(Marks)을 보고 바꾼다 (토스트 + 되돌리기)
class QuickMarks extends StatelessWidget {
  const QuickMarks({super.key, required this.kit, this.size = 28});
  final Kit kit;
  final double size;

  @override
  Widget build(BuildContext context) {
    final m = Marks.of(context);
    return MarkOverlay(
      liked: m.liked(kit),
      owned: m.owned(kit),
      onLike: () => Marks.read(context).toggleLike(context, kit),
      onOwn: () => Marks.read(context).toggleOwn(context, kit),
      size: size,
    );
  }
}

/// 책갈피 리본 모양 (아래 가운데가 파인 사각형)
class _RibbonClipper extends CustomClipper<Path> {
  const _RibbonClipper();

  @override
  Path getClip(Size s) => Path()
    ..moveTo(0, 0)
    ..lineTo(s.width, 0)
    ..lineTo(s.width, s.height)
    ..lineTo(s.width / 2, s.height - 8)
    ..lineTo(0, s.height)
    ..close();

  @override
  bool shouldReclip(_RibbonClipper old) => false;
}
