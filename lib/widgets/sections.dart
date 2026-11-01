// 섹션 · 탭 · 진행 — 색 막대 제목 · 흰 띠 · 밑줄 탭 · 넘김 점 · 진행 막대
import 'package:flutter/material.dart';

import '../theme.dart';

/// 섹션 제목: 브랜드 색 세로 막대 + 제목 (+ 기간 같은 보조 글 · 오른쪽 버튼 · › 전체 보기)
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.subtitle = '',
    this.trailing,
    this.onMore,
    this.padding = const EdgeInsets.fromLTRB(16, 20, 12, 12),
  });

  final String title;

  /// 브랜드 색 작은 글자 (예: 최근 추가 기간)
  final String subtitle;
  final Widget? trailing;

  /// 주면 오른쪽에 › 가 붙고 줄 전체를 누를 수 있다
  final VoidCallback? onMore;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 20,
            margin: const EdgeInsets.only(top: 1, right: 10),
            decoration: BoxDecoration(
              color: Gp.accent, // 브랜드 포인트 색
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: Gp.t16, fontWeight: FontWeight.w600),
                ),
                if (subtitle.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      subtitle,
                      style: const TextStyle(fontSize: Gp.t12, color: Gp.accent, fontWeight: FontWeight.w500),
                    ),
                  ),
              ],
            ),
          ),
          ?trailing,
          if (onMore != null) const Icon(Icons.chevron_right, color: Gp.muted),
        ],
      ),
    );
    return onMore == null ? row : InkWell(onTap: onMore, child: row);
  }
}

/// 글자 + 브랜드 색 밑줄 탭 (채널 바 · 좋아요/구매함 · 사진/바코드)
class UnderlineTab extends StatelessWidget {
  const UnderlineTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
    this.fontSize = 15,
    this.padding = const EdgeInsets.symmetric(horizontal: 8),
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// 있으면 글자 뒤에 개수 (선택되면 브랜드 색)
  final int? count;
  final double fontSize;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: label),
                    if (count != null)
                      TextSpan(
                        text: ' $count',
                        style: TextStyle(color: selected ? Gp.accent : Gp.faint),
                      ),
                  ],
                ),
                style: TextStyle(
                  fontSize: fontSize,
                  letterSpacing: 0.2,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected ? Gp.ink : Gp.faint,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 2,
                width: selected ? 14 : 0,
                color: Gp.accent, // 브랜드 포인트 색
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 넘김 위치 점 — 지금 쪽은 브랜드 색 긴 막대
class PageDots extends StatelessWidget {
  const PageDots({super.key, required this.count, required this.index, this.center = true});
  final int count;
  final int index;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: center ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            width: i == index ? 16 : 5,
            height: 4,
            decoration: BoxDecoration(color: i == index ? Gp.accent : Gp.line, borderRadius: BorderRadius.circular(2)),
          ),
      ],
    );
  }
}

/// 브랜드 색 진행 막대 (도감 수집 · 일치도)
class AccentBar extends StatelessWidget {
  const AccentBar({super.key, required this.value, this.height = 4, this.color = Gp.accent});
  final double value;
  final double height;

  /// 비교용 두 번째 막대는 Gp.faint
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1),
        minHeight: height,
        backgroundColor: Gp.soft,
        color: color,
      ),
    );
  }
}

/// 흰 띠 섹션 — 위에 회백색 틈 10을 두어 섹션마다 층이 보이게 (홈 · 상세)
class SectionPanel extends StatelessWidget {
  const SectionPanel({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(16, 18, 16, 18)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      // Material: 안의 ListTile · InkWell 누름 물결이 흰 바탕 위에 보이게
      child: Material(
        color: Gp.panel,
        child: SizedBox(
          width: double.infinity,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
