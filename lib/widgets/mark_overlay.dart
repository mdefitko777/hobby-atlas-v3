// 사진 위 표시 — 왼쪽 위 책갈피 리본 = 구매함 · 왼쪽 아래 ♡ = 좋아요 (태그 칸). 상품 카드(QuickMarks) · 도감 기체 칸은 ♡ 만
// (구매함은 길게 누르기, 리본은 구매함일 때 ✓ 표시만). 누르지 않는 칸은 StatusMarks
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../marks.dart';
import '../models.dart';
import '../theme.dart';
import 'icons.dart';

/// 사진 위 표시 (도감 칸 · 태그 칸): 왼쪽 위 책갈피 리본 = 구매함(+ → ✓) · 왼쪽 아래 ♡ = 좋아요
/// 보이는 크기는 작아도 누르는 자리는 44dp 이상 (P09 접근성).
/// [onOwn] 이 없으면 리본은 누르지 않고 구매함일 때만 ✓ (도감 기체 칸 — 그림 위에는 ♡ 만, 구매함은 칸 길게 누르기)
class MarkOverlay extends StatelessWidget {
  const MarkOverlay({
    super.key,
    required this.liked,
    required this.owned,
    required this.onLike,
    this.onOwn,
    this.size = 28,
  });

  final bool liked;
  final bool owned;
  final VoidCallback onLike;
  final VoidCallback? onOwn;
  final double size;

  @override
  Widget build(BuildContext context) {
    final inset = size * 0.22;
    final onOwn = this.onOwn;
    return Stack(
      children: [
        if (onOwn == null && owned)
          Positioned(
            left: inset + 2,
            top: 0,
            child: IgnorePointer(
              child: Semantics(
                label: tr('구매함'),
                child: _Ribbon(on: true, size: size),
              ),
            ),
          )
        else if (onOwn != null)
          Positioned(
            left: 0,
            top: 0,
            child: Semantics(
              button: true,
              selected: owned,
              label: tr('구매함'),
              child: GestureDetector(
                onTap: onOwn,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  // 누르는 자리 44 × 52
                  width: 44,
                  height: 52,
                  alignment: Alignment.topLeft,
                  padding: EdgeInsets.only(left: inset + 2),
                  child: _Ribbon(on: owned, size: size),
                ),
              ),
            ),
          ),
        _HeartButton(liked: liked, onLike: onLike, size: size),
      ],
    );
  }
}

/// 사진 왼쪽 아래 ♡ 누르는 칸 (누르는 자리 44 × 44) — [MarkOverlay] · [QuickMarks] 같은 자리 · 모양
class _HeartButton extends StatelessWidget {
  const _HeartButton({required this.liked, required this.onLike, required this.size});
  final bool liked;
  final VoidCallback onLike;
  final double size;

  @override
  Widget build(BuildContext context) {
    final inset = size * 0.22;
    return Positioned(
      left: 0,
      bottom: 0,
      child: Semantics(
        button: true,
        selected: liked,
        label: tr('좋아요'),
        child: GestureDetector(
          onTap: onLike,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.bottomLeft,
            padding: EdgeInsets.only(left: inset, bottom: inset),
            child: _Heart(on: liked, size: size),
          ),
        ),
      ),
    );
  }
}

/// 보기만 하는 표시 (누르지 않는 칸 · 도움말 견본) — 켜진 것만, [MarkOverlay] 와 같은 자리 · 모양 · 색:
/// 왼쪽 위 리본 ✓ = 구매함 · 왼쪽 아래 ♡ = 좋아요. 둘 다 아니면 아무것도 없다 (칸 그림은 늘 컬러)
class StatusMarks extends StatelessWidget {
  const StatusMarks({super.key, required this.liked, required this.owned, this.size = 22});
  final bool liked;
  final bool owned;
  final double size;

  @override
  Widget build(BuildContext context) {
    final inset = size * 0.22;
    return IgnorePointer(
      child: Stack(
        children: [
          if (owned)
            Positioned(
              left: inset + 2,
              top: 0,
              child: Semantics(
                label: tr('구매함'),
                child: _Ribbon(on: true, size: size),
              ),
            ),
          if (liked)
            Positioned(
              left: inset,
              bottom: inset,
              child: Semantics(
                label: tr('좋아요'),
                child: _Heart(on: true, size: size),
              ),
            ),
        ],
      ),
    );
  }
}

/// 책갈피 리본 (켜짐 = 민트 + ✓, 꺼짐 = 어두운 막 + +)
class _Ribbon extends StatelessWidget {
  const _Ribbon({required this.on, required this.size});
  final bool on;
  final double size;

  @override
  Widget build(BuildContext context) => ClipPath(
    clipper: const _RibbonClipper(),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: size + 2,
      height: size * 1.4,
      alignment: const Alignment(0, -0.3),
      color: on ? Gp.own : Gp.scrim,
      child: Icon(on ? Icons.check : Icons.add, size: size * 0.7, color: Colors.white),
    ),
  );
}

/// 동그라미 ♡ (켜짐 = 흰 바탕 파랑 ♥, 꺼짐 = 옅은 막 + 흰 ♡)
class _Heart extends StatelessWidget {
  const _Heart({required this.on, required this.size});
  final bool on;
  final double size;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: on ? Gp.panel : Gp.scrimLight),
    child: Icon(on ? Icons.favorite : Icons.favorite_border, size: size * 0.6, color: on ? Gp.accent : Colors.white),
  );
}

/// 상품 카드 사진 위 ♡ — 앱 전체 좋아요(Marks)를 보고 바꾼다 (토스트 + 되돌리기).
/// 구매함은 사진에 두지 않고 카드를 길게 누른다 ([ProductTile], 2026-11-20 주인: 사진 위에는 ♡ 만)
class QuickMarks extends StatelessWidget {
  const QuickMarks({super.key, required this.kit, this.size = 28});
  final Kit kit;
  final double size;

  @override
  Widget build(BuildContext context) {
    final liked = Marks.of(context).liked(kit);
    return Stack(
      children: [_HeartButton(liked: liked, onLike: () => Marks.read(context).toggleLike(context, kit), size: size)],
    );
  }
}

/// 목록 줄 오른쪽 ♡ · 리본 버튼 두 개 (사진 없는 줄: 기체 시트 · 사진으로 찾기 후보) — 켜짐 = 채운 색, 꺼짐 = 회색 테두리
class KitMarkButtons extends StatelessWidget {
  const KitMarkButtons({super.key, required this.kit, this.extra});
  final Kit kit;

  /// 리본 뒤에 하나 더 (사진 붙이기)
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final m = Marks.of(context);
    final liked = m.liked(kit);
    final owned = m.owned(kit);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: tr('좋아요'),
          visualDensity: VisualDensity.compact,
          onPressed: () => Marks.read(context).toggleLike(context, kit),
          icon: LikedIcon(filled: liked, size: Gp.iM, color: liked ? Gp.accent : Gp.muted),
        ),
        IconButton(
          tooltip: tr('구매함'),
          visualDensity: VisualDensity.compact,
          onPressed: () => Marks.read(context).toggleOwn(context, kit),
          icon: OwnedIcon(filled: owned, size: Gp.iM, color: owned ? Gp.own : Gp.muted),
        ),
        ?extra,
      ],
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
