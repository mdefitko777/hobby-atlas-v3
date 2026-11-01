// 작은 꼬리표 — 테두리 알약 · 연한 색 꼬리표 · 날짜 · 공식 예고 단계 색
import 'package:flutter/material.dart';

import '../theme.dart';

/// 테두리 알약 글자 (한정 · PB · 예고 · 3/3). [strong] = 검정 테두리 · 굵게
class TagPill extends StatelessWidget {
  const TagPill(this.text, {super.key, this.strong = false, this.filled = false});
  final String text;
  final bool strong;

  /// 사진 위에 올릴 때 흰 반투명 바탕
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: filled ? Gp.glass : null,
        borderRadius: BorderRadius.circular(Gp.rSmall),
        border: Border.all(color: strong ? Gp.ink : Gp.line),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: Gp.t11,
          fontWeight: strong ? FontWeight.w600 : FontWeight.w500,
          color: strong ? Gp.ink : Gp.muted,
        ),
      ),
    );
  }
}

/// 날짜 꼬리표 하나 (빨강 = PB 예약 마감, 파랑 = 발매)
class DateTag extends StatelessWidget {
  const DateTag(this.text, {super.key, this.urgent = false});
  final String text;
  final bool urgent;

  @override
  Widget build(BuildContext context) => SoftTag(text, color: urgent ? Gp.danger : Gp.accent);
}

/// 연한 색 꼬리표 하나 (네모 · 색 글자 + 같은 색 10% 바탕) — 날짜 · 예고 단계 · 상태 공통
class SoftTag extends StatelessWidget {
  const SoftTag(this.text, {super.key, this.color = Gp.accent});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(Gp.rSmall)),
    child: Text(
      text,
      style: TextStyle(fontSize: Gp.t11, fontWeight: FontWeight.w700, color: color),
    ),
  );
}

/// 공식 예고 단계 색: 공식 발표 회색 · 상품화 확정 파랑 · 예약 시작 민트(지금 살 수 있음) · 발매 검정
Color stageColor(String status) => switch (status) {
  '상품화 확정' => Gp.accent,
  '예약 시작' => Gp.own,
  '발매' => Gp.ink,
  _ => Gp.muted,
};
