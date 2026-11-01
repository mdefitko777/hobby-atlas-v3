// 뜻이 정해진 아이콘 — ♡ 좋아요 · 책갈피 구매함 · 인증 배지 · 채널 관리
import 'package:flutter/material.dart';

import '../theme.dart';

/// 예약 · 도착 · 재판매 · 도색 — 같은 뜻은 어디서나 이 아이콘 (상세 · 컬렉션 · 캘린더 · 공유 카드 · 도움말).
/// 조립 단계(미조립 · 조립 중 · 완성)는 kit_progress.dart buildStageIcon
const preorderIcon = Icons.event_available_outlined;
const arrivedIcon = Icons.move_to_inbox_outlined;
const restockIcon = Icons.autorenew;
const paintIcon = Icons.brush;

/// 채널 관리 아이콘: 짧은 선(왼쪽 위) · 긴 선(가운데) · 짧은 선(오른쪽 아래)
class ChannelGlyph extends StatelessWidget {
  const ChannelGlyph({super.key, this.size = 22, this.color = Gp.ink});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _ChannelGlyphPainter(color));
}

class _ChannelGlyphPainter extends CustomPainter {
  const _ChannelGlyphPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..strokeWidth = s.width * 0.085
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(Offset(s.width * 0.12, s.height * 0.26), Offset(s.width * 0.52, s.height * 0.26), p)
      ..drawLine(Offset(s.width * 0.12, s.height * 0.5), Offset(s.width * 0.88, s.height * 0.5), p)
      ..drawLine(Offset(s.width * 0.48, s.height * 0.74), Offset(s.width * 0.88, s.height * 0.74), p);
  }

  @override
  bool shouldRepaint(_ChannelGlyphPainter old) => old.color != color;
}

/// 좋아요 표시 (♡, 파랑) — 글자 대신. 상세 · 필터 · My Page · 친구 소식 공통
class LikedIcon extends StatelessWidget {
  const LikedIcon({super.key, this.filled = true, this.size = Gp.iS, this.color = Gp.accent});
  final bool filled;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Icon(filled ? Icons.favorite : Icons.favorite_border, size: size, color: color);
}

/// 구매함 표시 (책갈피, 민트) — 상품 카드의 리본과 같은 뜻
class OwnedIcon extends StatelessWidget {
  const OwnedIcon({super.key, this.filled = true, this.size = Gp.iS, this.color = Gp.own});
  final bool filled;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Icon(filled ? Icons.bookmark : Icons.bookmark_border, size: size, color: color);
}

/// 3점(내 사진 인증) 배지 — 도감 칸 · 게시물 · 숫자에 같이 쓴다
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.size = 22});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Gp.own, // 인증 = 가진 것 (민트)
        border: Border.all(color: Gp.panel, width: 1.5),
      ),
      child: Icon(Icons.workspace_premium, size: size * 0.66, color: Colors.white),
    );
  }
}
