// 아래 시트 조각 — 하나 고르기 · 네모 세그먼트 · 체크 칸 · 펼치는 줄
import 'package:flutter/material.dart';

import '../theme.dart';
import 'sections.dart';

/// 하나 고르기 바텀 시트 — 제목 + 줄마다 이름, 고른 줄은 브랜드 색 글자 + ✓ (정렬 · 언어 공통)
Future<T?> showPickSheet<T>(
  BuildContext context, {
  required String title,
  required List<T> values,
  required T current,
  required String Function(T) label,
}) {
  return showModalBottomSheet<T>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(title, padding: const EdgeInsets.fromLTRB(20, 0, 20, 6)),
          for (final v in values)
            InkWell(
              onTap: () => Navigator.pop(sheet, v),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label(v),
                        style: TextStyle(
                          fontSize: Gp.t14,
                          color: v == current ? Gp.accent : Gp.ink,
                          fontWeight: v == current ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (v == current) const Icon(Icons.check, size: Gp.iM, color: Gp.accent),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// 네모 세그먼트 (캡슐 대신) — 한 줄에 하나만 고름. 필터 · 홈 · 캘린더가 같이 쓴다
class SquareSegments<T> extends StatelessWidget {
  const SquareSegments({
    super.key,
    required this.values,
    required this.current,
    required this.child,
    required this.onPick,
  });
  final List<T> values;
  final T current;
  final Widget Function(T) child;
  final ValueChanged<T> onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        border: Border.all(color: Gp.line),
        borderRadius: BorderRadius.circular(Gp.rSmall),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          for (final (i, v) in values.indexed) ...[
            if (i > 0) const VerticalDivider(width: 1, color: Gp.line),
            Expanded(
              child: Material(
                color: v == current ? Gp.accent.withValues(alpha: 0.12) : Gp.panel,
                child: InkWell(
                  onTap: () => onPick(v),
                  child: Center(
                    child: DefaultTextStyle.merge(
                      style: TextStyle(
                        fontSize: Gp.t12,
                        fontWeight: v == current ? FontWeight.w700 : FontWeight.w400,
                        color: v == current ? Gp.accent : Gp.muted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      child: child(v),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 체크 칸 2열 (이름 · 개수 · 네모 체크)
class CheckGrid extends StatelessWidget {
  const CheckGrid({
    super.key,
    required this.values,
    required this.selected,
    required this.countOf,
    required this.onToggle,
    this.columns = 2,
  });
  final List<String> values;
  final Set<String> selected;
  final int Function(String) countOf;
  final ValueChanged<String> onToggle;
  final int columns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => Wrap(
        children: [
          for (final v in values)
            SizedBox(
              width: box.maxWidth / columns,
              child: () {
                final on = selected.contains(v);
                final n = countOf(v);
                return Opacity(
                  opacity: n == 0 && !on ? 0.4 : 1,
                  child: InkWell(
                    onTap: () => onToggle(v),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: on ? Gp.accent : Gp.panel,
                              borderRadius: BorderRadius.circular(Gp.rSmall),
                              border: Border.all(color: on ? Gp.accent : Gp.line),
                            ),
                            child: on ? const Icon(Icons.check, size: Gp.iS, color: Colors.white) : null,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              v,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: Gp.t14),
                            ),
                          ),
                          Text(
                            '$n',
                            style: const TextStyle(fontSize: Gp.t11, color: Gp.faint),
                          ),
                          const SizedBox(width: 10),
                        ],
                      ),
                    ),
                  ),
                );
              }(),
            ),
        ],
      ),
    );
  }
}

/// 한 줄 눌러 펼치기 (라인 · 작품 · 가격)
class ExpandRow extends StatelessWidget {
  const ExpandRow({super.key, required this.title, required this.summary, required this.open, required this.onTap});
  final String title;
  final String summary;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: Gp.t14, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Text(
              summary,
              style: TextStyle(fontSize: Gp.t12, color: summary == '전체' ? Gp.faint : Gp.accent),
            ),
            const SizedBox(width: 4),
            AnimatedRotation(
              turns: open ? 0.5 : 0,
              duration: const Duration(milliseconds: 150),
              child: const Icon(Icons.expand_more, size: Gp.iM, color: Gp.muted),
            ),
          ],
        ),
      ),
    );
  }
}
