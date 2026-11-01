// 브랜드 색 고리 · 고리 아바타
import 'package:flutter/material.dart';

import '../theme.dart';
import 'buttons.dart';

/// 색 고리 아바타 — 앱 셸 왼쪽 위(누르면 친구 서랍) · 서랍 머리 · 내 정보 머리
class RingAvatar extends StatelessWidget {
  const RingAvatar({
    super.key,
    required this.text,
    this.size = 56,
    this.ringWidth = 2.5,
    this.onTap,
    this.tooltip = '',
    this.photo,
  });
  final String text;
  final double size;
  final double ringWidth;

  /// 주면 떠 있는 흰 버튼 얼굴 (앱 셸)
  final VoidCallback? onTap;
  final String tooltip;

  /// 아바타 사진 (없으면 [text] 첫 글자)
  final Widget? photo;

  @override
  Widget build(BuildContext context) {
    final Widget label = photo == null
        ? Text(
            text,
            style: TextStyle(fontSize: size * 0.4, fontWeight: FontWeight.w700, color: Gp.ink),
          )
        : ClipOval(
            child: SizedBox.square(dimension: size, child: photo),
          );
    final face = onTap == null
        ? Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Gp.panel),
            child: label,
          )
        : Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Gp.bg),
            child: RaisedCircleButton(tooltip: tooltip, size: size, onTap: onTap!, child: label),
          );
    return AccentRing(width: ringWidth, child: face);
  }
}

/// 브랜드 색 고리 (하늘색 → 민트). 아바타 · 도감 "내 사진" 칸이 같이 쓴다.
/// [spin] = 천천히 돌아가는 고리 (내 사진으로 점등한 칸)
class AccentRing extends StatefulWidget {
  const AccentRing({super.key, required this.child, this.width = 2.5, this.radius, this.spin = false});

  final Widget child;
  final double width;

  /// null = 동그라미, 값이 있으면 둥근 사각형
  final double? radius;
  final bool spin;

  @override
  State<AccentRing> createState() => _AccentRingState();
}

class _AccentRingState extends State<AccentRing> with SingleTickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(vsync: this, duration: const Duration(seconds: 4));

  @override
  void initState() {
    super.initState();
    if (widget.spin) _turn.repeat();
  }

  @override
  void didUpdateWidget(AccentRing old) {
    super.didUpdateWidget(old);
    if (widget.spin && !_turn.isAnimating) _turn.repeat();
    if (!widget.spin) _turn.stop();
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final circle = widget.radius == null;
    return AnimatedBuilder(
      animation: _turn,
      builder: (context, child) => Container(
        padding: EdgeInsets.all(widget.width),
        decoration: BoxDecoration(
          shape: circle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: circle ? null : BorderRadius.circular(widget.radius!),
          gradient: SweepGradient(
            colors: const [Gp.accent, Gp.accent2, Gp.accent],
            transform: GradientRotation(_turn.value * 6.2832),
          ),
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}
