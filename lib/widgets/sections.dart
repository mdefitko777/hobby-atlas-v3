// 섹션 · 탭 · 진행 — 색 막대 제목 · 흰 띠 · 밑줄 탭 · 넘김 점 · 진행 막대 · 목록 맨 끝 합계
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
    this.underline = true,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// 있으면 글자 뒤에 개수 (선택되면 브랜드 색)
  final int? count;
  final double fontSize;
  final EdgeInsets padding;

  /// 밑줄을 그을까 — 한 화면에 밑줄은 맨 윗줄 한 군데만 (2026-11-21 주인: 둘 다 밑줄이면
  /// "전체" 로 시작하는 두 줄이 똑같아 보였다).
  /// 셸 탭(홈 · 검색 · 캘린더 · 컬렉션)은 위에 채널 바가 보이므로 그 아래 탭 줄은 false + 작게.
  /// 쌓아 연 화면(상세 · 알림 · 친구 컬렉션 · 베이 조합 …)은 채널 바가 가려져 제 탭 줄이 맨 윗줄이라 true 그대로.
  final bool underline;

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
              if (underline) ...[
                const SizedBox(height: 4),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 2,
                  width: selected ? 14 : 0,
                  color: Gp.accent, // 브랜드 포인트 색
                ),
              ],
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

/// 흰 띠 섹션 — 위에 회백색 틈 10을 두어 섹션마다 층이 보이게 (홈 · 상세). 흰 바탕이라 틈 위에 머리카락 줄
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
        shape: const Border(top: Gp.bandLine),
        child: SizedBox(
          width: double.infinity,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// AppBar 두 줄 제목 — 이름(t16) + 아래 민트 "수집 n / m" (작품 도감 · 태그 도감). [count] 가 비면 한 줄
class BarTitle extends StatelessWidget {
  const BarTitle(this.title, {super.key, this.count = ''});
  final String title;
  final String count;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: Gp.t16, fontWeight: FontWeight.w600),
      ),
      if (count.isNotEmpty)
        Text(
          count,
          style: const TextStyle(fontSize: Gp.t12, color: Gp.own, fontWeight: FontWeight.w500),
        ),
    ],
  );
}

/// 목록 맨 끝의 조용한 합계 — 큰 숫자 + 작은 이름 짝들 (컬렉션 F-4 · 캘린더 H-9c). 판 · 테두리 없이 가는 줄 아래.
/// 탭 · 목록 머리에는 수를 쓰지 않고 여기에만 (2026-11-20 주인)
class ListSummary extends StatelessWidget {
  const ListSummary(this.items, {super.key});

  /// (숫자 글자, 이름) — 값이 없는 짝은 부르는 쪽이 뺀다
  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 18, 16, 0),
    padding: const EdgeInsets.only(top: 14),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: Gp.line)),
    ),
    child: Wrap(
      spacing: 28,
      runSpacing: 12,
      children: [
        for (final (value, label) in items)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: const TextStyle(fontSize: Gp.t19, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
              ),
            ],
          ),
      ],
    ),
  );
}
