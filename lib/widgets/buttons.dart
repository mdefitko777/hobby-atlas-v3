// 버튼 — 떠 있는 원 · 켜고 끄기 · 주 버튼(그라데이션)
import 'package:flutter/material.dart';

import '../theme.dart';

/// 떠 있는 흰 원형 버튼 — 아바타 · 가운데 + 버튼
class RaisedCircleButton extends StatelessWidget {
  const RaisedCircleButton({
    super.key,
    required this.child,
    required this.onTap,
    required this.tooltip,
    this.size = 40,
  });

  final Widget child;
  final VoidCallback onTap;
  final String tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: Gp.raised(shape: BoxShape.circle),
            alignment: Alignment.center,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 켜고 끄는 버튼 (좋아요 · 구매함) — 켜지면 옅은 하늘색 바탕 + 브랜드 색 테두리·아이콘
class TogglePill extends StatelessWidget {
  const TogglePill({
    super.key,
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.active,
    required this.onTap,
    this.height = 44,
    this.color = Gp.accent,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool active;
  final VoidCallback onTap;
  final double height;

  /// 켜졌을 때 색 — 좋아요 · 알림 = 파랑, 구매함 · 인증 = 민트(Gp.own)
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: active ? color.withValues(alpha: 0.07) : Gp.panel,
            borderRadius: BorderRadius.circular(Gp.rSmall),
            border: Border.all(color: active ? color : Gp.line, width: active ? 1.3 : 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(active ? activeIcon : icon, size: Gp.iM, color: active ? color : Gp.ink),
              const SizedBox(width: 5),
              Flexible(
                // 좁은 화면에서는 말줄임
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: Gp.t14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 주 버튼 (화면에 하나) — 브랜드 그라데이션 파랑→민트 + 부드러운 그림자. 누를 수 없으면 회색
class GradientButton extends StatelessWidget {
  const GradientButton({super.key, required this.label, required this.onPressed, this.height = 46});
  final String label;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    final on = onPressed != null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Gp.radius),
        gradient: on ? Gp.accentGradient : null,
        color: on ? null : Gp.soft,
        boxShadow: on
            ? [BoxShadow(color: Gp.accent.withValues(alpha: 0.25), blurRadius: 14, offset: const Offset(0, 6))]
            : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(Gp.radius),
          onTap: onPressed,
          child: Center(
            child: Text(
              label,
              style: TextStyle(fontSize: Gp.t14, fontWeight: FontWeight.w700, color: on ? Colors.white : Gp.faint),
            ),
          ),
        ),
      ),
    );
  }
}
