// ? 도움말 — 아이콘만 있는 화면에서 아이콘 뜻을 한 줄씩 (P10).
// 자리는 모든 화면이 같다: 머리 줄(아바타 줄 · AppBar · 서랍 머리)의 오른쪽 끝. 크기는 ToolIcon 한 칸.
import 'package:flutter/material.dart';

import '../theme.dart';
import 'buttons.dart';
import 'sections.dart';
import 'sheets.dart';
import 'toolbar.dart';

/// 도움말 시트 한 줄 — 아이콘(또는 색 점 · 작은 그림) + 짧은 글 한 줄. [HelpItem.group] 은 작은 회색 묶음 이름
@immutable
class HelpItem {
  const HelpItem(IconData this.icon, this.text, {this.color}) : leading = null, dot = false, group = false;

  /// 달력 점처럼 색 하나
  const HelpItem.dot(Color this.color, this.text) : icon = null, leading = null, dot = true, group = false;

  /// 아이콘이 아닌 것 (Lv 칩 · 도감 칸 · 글자 버튼)
  const HelpItem.widget(Widget this.leading, this.text) : icon = null, color = null, dot = false, group = false;

  /// 묶음 이름 (위 줄 · 이 탭 …)
  const HelpItem.group(this.text) : icon = null, color = null, leading = null, dot = false, group = true;

  final IconData? icon;
  final Color? color;
  final Widget? leading;
  final bool dot;
  final bool group;
  final String text;
}

/// ? 버튼 — 누르면 [title] + [items] 시트. [raised] = 사진 위에 떠 있는 흰 원(상품 상세)
class HelpButton extends StatelessWidget {
  const HelpButton({super.key, required this.title, required this.items, this.raised = false}) : builder = null;

  /// 줄 목록이 아닌 내용 (레벨 · 도감 시트) — 버튼 모양만 같이 쓴다
  const HelpButton.sheet({super.key, required this.title, required WidgetBuilder this.builder, this.raised = false})
    : items = const [];

  final String title;
  final List<HelpItem> items;
  final WidgetBuilder? builder;
  final bool raised;

  static const tip = '도움말';

  void _open(BuildContext context) => showGpSheet<void>(
    context,
    tall: builder == null,
    builder: builder ?? (_) => HelpSheet(title: title, items: items),
  );

  @override
  Widget build(BuildContext context) {
    if (raised) {
      return RaisedCircleButton(
        tooltip: tip,
        onTap: () => _open(context),
        child: const Icon(Icons.help_outline, size: Gp.iM, color: Gp.ink),
      );
    }
    return SizedBox(
      width: ToolIcon.width,
      height: 48,
      child: IconButton(
        tooltip: tip,
        padding: EdgeInsets.zero,
        onPressed: () => _open(context),
        icon: const Icon(Icons.help_outline, size: Gp.iM, color: Gp.muted),
      ),
    );
  }
}

/// 도움말 시트 내용 (길면 스크롤)
class HelpSheet extends StatelessWidget {
  const HelpSheet({super.key, required this.title, required this.items});
  final String title;
  final List<HelpItem> items;

  @override
  Widget build(BuildContext context) {
    Widget lead(HelpItem i) => switch (i) {
      HelpItem(dot: true) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(shape: BoxShape.circle, color: i.color),
      ),
      HelpItem(:final IconData icon) => Icon(icon, size: Gp.iL, color: i.color ?? Gp.ink),
      _ => i.leading ?? const SizedBox.shrink(),
    };
    Widget row(HelpItem i) => i.group
        ? Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 2),
            child: Text(
              i.text,
              style: const TextStyle(fontSize: Gp.t12, color: Gp.muted, fontWeight: FontWeight.w600),
            ),
          )
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(width: 40, height: 32, child: Center(child: lead(i))),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(i.text, style: const TextStyle(fontSize: Gp.t14)),
                ),
              ],
            ),
          );
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(title, padding: const EdgeInsets.only(bottom: 6)), // 다른 시트와 같은 머리
              for (final i in items) row(i),
            ],
          ),
        ),
      ),
    );
  }
}
