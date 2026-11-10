// 검색창 줄 (홈 · 검색 · 캘린더 · 컬렉션 · My Page 공용) — [검색창][필터][보기 A][보기 B]
// 모든 탭이 같은 줄: 검색창 높이 · 길이, 아이콘 크기 · 자리가 같다
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme.dart';

/// 검색창 — 홈과 검색 화면이 같은 것을 쓴다 (크기 · 글자 · 아이콘 통일, P04).
/// [onTap]을 주면 입력하지 않는 "입구"(홈): 누르면 검색 화면으로 간다.
/// 아니면 [controller]로 바로 입력하는 검색창(검색 화면).
class GpSearchBar extends StatelessWidget {
  const GpSearchBar({
    super.key,
    this.onCamera,
    this.hint,
    this.onTap,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
  });

  /// 오른쪽 카메라 → 찍어서 찾기 (하단 카메라 버튼과 같은 동작). 없으면 카메라를 숨긴다(친구 검색)
  final VoidCallback? onCamera;

  /// 없으면 기본 안내 (이름 · 번호 · 생김새로 찾기)
  final String? hint;
  final VoidCallback? onTap;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  static const _textStyle = TextStyle(fontSize: Gp.t14, color: Gp.ink);
  static const _hintStyle = TextStyle(fontSize: Gp.t14, color: Gp.faint);

  @override
  Widget build(BuildContext context) {
    final c = controller;
    // 홈 입구도 같은 TextField로 그린다(읽기 전용) — 안내 문구의 위치·간격이 두 화면에서 똑같게
    final Widget field = TextField(
      controller: c,
      focusNode: focusNode,
      readOnly: onTap != null,
      showCursor: onTap == null,
      enableInteractiveSelection: onTap == null,
      onTap: onTap,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
      style: _textStyle,
      decoration: InputDecoration(
        hintText: hint ?? tr('이름 · 번호 · 생김새로 찾기'),
        hintStyle: _hintStyle,
        filled: false,
        isDense: true,
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
    );
    return Semantics(
      button: onTap != null,
      label: onTap != null ? tr('검색 열기') : null,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 48,
          padding: const EdgeInsets.only(left: 16, right: 4),
          decoration: Gp.raised(radius: Gp.radius),
          child: Row(
            children: [
              const Icon(Icons.search, size: Gp.iM, color: Gp.muted),
              const SizedBox(width: 10),
              Expanded(child: field),
              if (c != null && onTap == null)
                ValueListenableBuilder(
                  valueListenable: c,
                  builder: (context, v, _) => v.text.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          tooltip: tr('지우기'), // P03
                          icon: const Icon(Icons.cancel, size: Gp.iM, color: Gp.faint),
                          onPressed: () {
                            c.clear();
                            onChanged?.call('');
                          },
                        ),
                ),
              if (onCamera != null)
                IconButton(
                  tooltip: tr('찍어서 찾기'),
                  icon: const Icon(Icons.photo_camera_outlined, size: Gp.iM, color: Gp.ink),
                  onPressed: onCamera,
                )
              else
                const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// 검색창 옆 아이콘 한 칸 — 모든 탭이 같은 크기 · 테두리 없음 (컬렉션의 목록 · 도감 아이콘과 같은 모양).
/// 고른 것 = 진한 색, 아닌 것 = 옅은 색. [badge] > 0 이면 숫자 배지
class ToolIcon extends StatelessWidget {
  const ToolIcon({
    super.key,
    required this.icon,
    required this.tip,
    required this.onTap,
    this.on = true,
    this.color,
    this.badge = 0,
  });
  final IconData icon;
  final String tip;
  final VoidCallback? onTap;
  final bool on;
  final Color? color;
  final int badge;

  /// 한 칸 너비 (검색창 길이가 탭마다 같도록 늘 3칸)
  static const width = 40.0;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: 48,
    child: IconButton(
      tooltip: tip,
      onPressed: onTap,
      padding: EdgeInsets.zero,
      icon: Badge(
        isLabelVisible: badge > 0,
        backgroundColor: Gp.accent,
        label: Text('$badge'),
        child: Icon(icon, size: Gp.iL, color: color ?? (on ? Gp.ink : Gp.faint)),
      ),
    ),
  );
}

/// 보기 바꾸기 아이콘 두 칸 (전체 ↔ 내 것 · 목록 ↔ 도감 · 격자 ↔ 목록) — 검색창 옆 오른쪽 끝, 모든 탭 같은 자리
class ViewIconToggle extends StatelessWidget {
  const ViewIconToggle({
    super.key,
    required this.mine,
    required this.onChanged,
    this.allIcon = Icons.newspaper_outlined,
    this.mineIcon = Icons.person_outline,
    this.allTip,
    this.mineTip,
  });

  final bool mine;
  final ValueChanged<bool> onChanged;
  final IconData allIcon;
  final IconData mineIcon;

  /// 없으면 '전체 소식' · 'My Page'
  final String? allTip;
  final String? mineTip;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      ToolIcon(icon: allIcon, tip: allTip ?? tr('전체 소식'), on: !mine, onTap: () => onChanged(false)),
      ToolIcon(icon: mineIcon, tip: mineTip ?? 'My Page', on: mine, onTap: () => onChanged(true)),
    ],
  );
}

/// 필터 아이콘 — 고른 조건이 있으면 브랜드 색 + 개수 배지. [onTap] 이 null 이면 옅게(그 목록엔 필터 없음)
class FilterButton extends StatelessWidget {
  const FilterButton({super.key, required this.count, required this.onTap});
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ToolIcon(
    icon: Icons.tune,
    tip: tr('필터'),
    onTap: onTap,
    on: onTap != null,
    color: count > 0 ? Gp.accent : null,
    badge: count,
  );
}

/// 검색창 + 오른쪽 아이콘들 — 바깥 여백 · 간격을 한 곳에서
class ToolRow extends StatelessWidget {
  const ToolRow({super.key, required this.field, this.tools = const []});
  final Widget field;
  final List<Widget> tools;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
    child: Row(
      children: [
        Expanded(child: field),
        const SizedBox(width: 4),
        ...tools,
      ],
    ),
  );
}

/// 이 목록 안에서 찾기(카메라 없는 검색창) + 필터 + [tools] — 글자칸을 스스로 가진다
class FindBar extends StatefulWidget {
  const FindBar({
    super.key,
    required this.hint,
    required this.onQuery,
    this.filterCount = 0,
    this.onFilter,
    this.tools = const [],
    this.initial = '',
  });
  final String hint;
  final ValueChanged<String> onQuery;

  /// 처음 글자 (앞 화면에서 찾던 말을 이어서)
  final String initial;
  final int filterCount;
  final VoidCallback? onFilter;

  /// 필터 뒤 (보기 바꾸기 두 칸)
  final List<Widget> tools;

  @override
  State<FindBar> createState() => _FindBarState();
}

class _FindBarState extends State<FindBar> {
  late final _ctrl = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ToolRow(
    field: GpSearchBar(controller: _ctrl, hint: widget.hint, onChanged: (v) => widget.onQuery(v.trim())),
    tools: [
      FilterButton(count: widget.filterCount, onTap: widget.onFilter),
      ...widget.tools,
    ],
  );
}
