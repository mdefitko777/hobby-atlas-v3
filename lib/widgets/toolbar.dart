// 도구 줄 — 네 탭은 검색창 없이 오른쪽에 아이콘만 [필터][보기 A][보기 B] (2026-11-21 주인: 찾기는 위 줄 🔍 하나),
// 검색 덮개 · 쌓아 연 화면(분류 상품 · 작품 도감)은 [검색창][아이콘들]. 아이콘 크기 · 오른쪽 끝 자리는 어디서나 같다.
// 아이콘 바로 왼쪽에는 작품을 바꿀 때 이어 쓴 조건 알림([CarryNote], 규칙은 lib/logic/filter_carryover.dart)
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../logic/filter_carryover.dart';
import '../theme.dart';
import 'sections.dart';
import 'sheets.dart';

/// 검색창 — 검색 덮개 · 쌓아 연 화면 · 친구 검색이 같은 것을 쓴다 (크기 · 글자 · 아이콘 통일, P04).
/// [onTap]을 주면 입력하지 않는 "입구": 누르면 검색 화면으로 간다.
/// 아니면 [controller]로 바로 입력하는 검색창.
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
    this.autofocus = false,
  });

  /// 열자마자 커서 (검색 덮개)
  final bool autofocus;

  /// 오른쪽 카메라 → 찍어서 찾기 (하단 카메라 버튼과 같은 동작). 없으면 카메라를 숨긴다(친구 검색)
  final VoidCallback? onCamera;

  /// 없으면 기본 안내 (이름 · 번호 · 생김새로 찾기)
  final String? hint;
  final VoidCallback? onTap;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  // getter — static final 이면 밤 모드를 켠 뒤에도 낮 색으로 얼어붙는다
  static TextStyle get _textStyle => TextStyle(fontSize: Gp.t14, color: Gp.ink);
  static TextStyle get _hintStyle => TextStyle(fontSize: Gp.t14, color: Gp.faint);

  @override
  Widget build(BuildContext context) {
    final c = controller;
    // 홈 입구도 같은 TextField로 그린다(읽기 전용) — 안내 문구의 위치·간격이 두 화면에서 똑같게
    final Widget field = TextField(
      controller: c,
      focusNode: focusNode,
      autofocus: autofocus,
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
              Icon(Icons.search, size: Gp.iM, color: Gp.muted),
              const SizedBox(width: 10),
              Expanded(child: field),
              if (c != null && onTap == null)
                ValueListenableBuilder(
                  valueListenable: c,
                  builder: (context, v, _) => v.text.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          // 40 칸 — 검색 덮개 줄(← · 아이콘 세 칸)과 함께 320dp 폰에 들어가게
                          visualDensity: VisualDensity.compact,
                          tooltip: tr('지우기'), // P03
                          icon: Icon(Icons.cancel, size: Gp.iM, color: Gp.faint),
                          onPressed: () {
                            c.clear();
                            onChanged?.call('');
                          },
                        ),
                ),
              if (onCamera != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: tr('찍어서 찾기'),
                  icon: Icon(Icons.photo_camera_outlined, size: Gp.iM, color: Gp.ink),
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

  /// 한 칸 너비 (탭마다 오른쪽 끝 자리가 같게)
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

/// 보기 바꾸기 아이콘 두 칸 (전체 ↔ 내 것) — 도구 줄 오른쪽 끝, 모든 탭 같은 자리
class ViewIconToggle extends StatelessWidget {
  const ViewIconToggle({
    super.key,
    required this.mine,
    required this.onChanged,
    required this.allIcon,
    required this.allTip,
    required this.mineTip,
    this.mineIcon = Icons.person_outline,
  });

  final bool mine;
  final ValueChanged<bool> onChanged;
  final IconData allIcon;
  final IconData mineIcon;
  final String allTip;
  final String mineTip;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      ToolIcon(icon: allIcon, tip: allTip, on: !mine, onTap: () => onChanged(false)),
      ToolIcon(icon: mineIcon, tip: mineTip, on: mine, onTap: () => onChanged(true)),
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

/// 도구 줄 — 오른쪽 아이콘들 (+ [field] 를 주면 왼쪽에 검색창). 바깥 여백 · 간격을 한 곳에서.
/// 네 탭은 [field] 없이: 상자 없는 아이콘만 오른쪽에 붙고 높이도 낮다
class ToolRow extends StatelessWidget {
  const ToolRow({super.key, this.field, this.tools = const [], this.leading});

  /// 검색창 (검색 덮개 · 쌓아 연 화면에만)
  final Widget? field;

  /// 왼쪽에 놓을 것 — 탭 줄(전체 · 종류 · 세대 …). 네 탭은 이것과 [tools] 가 한 줄에 같이 선다.
  /// 2026-11-21 탭에서 검색창을 뺀 뒤로 [field] 도 [leading] 도 없으면 아이콘 몇 개만 뜬 빈 띠가
  /// 남았다 — 주인이 "흰 박스" 라고 한 그 줄. 이제 그 경우에는 줄 자체를 그리지 않는다.
  final Widget? leading;

  final List<Widget> tools;

  @override
  Widget build(BuildContext context) {
    if (field == null && leading == null && tools.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: field == null ? const EdgeInsets.fromLTRB(16, 0, 8, 0) : const EdgeInsets.fromLTRB(16, 4, 8, 8),
      child: Row(
        children: [
          if (field case final f?) ...[Expanded(child: f), const SizedBox(width: 4)],
          // leading 은 남는 자리를 전부 받는다 — Flexible + Spacer 로 반씩 나누면 탭 줄이
          // 320dp 에서 17px 까지 눌려 "전체 · 종류 · 세대" 가 보이지 않았다
          if (leading case final l?) Expanded(child: l) else const Spacer(),
          ...tools,
        ],
      ),
    );
  }
}

/// 아이콘 바로 왼쪽 「이어 씀 2 ×」 — 작품을 바꿀 때 이어 쓴 조건 (줄을 새로 만들지 않고 탭 줄 안에).
/// 캡슐 · 칩 · 바탕 없이 브랜드 색 작은 글자 + × 뿐 (2026-11-22 주인: 캡슐 안 됨).
/// 글자를 누르면 「이어 쓴 필터」 시트, × 는 이어 쓴 조건을 한 번에 지운다. 이어 쓴 것이 없으면 아무것도 그리지 않는다
class CarryNote extends StatelessWidget {
  const CarryNote({super.key, required this.carry, required this.onChanged});

  /// 필터 시트가 돌려준 이어 쓴 결과 (null · 이어 쓴 것이 0 이면 줄이 오늘과 똑같다)
  final FilterCarry? carry;

  /// 지운 뒤의 조건 — 화면이 필터를 갈아 끼우고 다시 그린다
  final ValueChanged<FilterCarry> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = carry;
    if (c == null || c.count == 0) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          key: const ValueKey('carry-note'),
          onTap: () => showCarrySheet(context, c, onChanged),
          borderRadius: BorderRadius.circular(Gp.rSmall),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              trf('이어 씀 {n}', {'n': c.count}),
              style: TextStyle(fontSize: Gp.t12, fontWeight: FontWeight.w600, color: Gp.accent),
            ),
          ),
        ),
        Semantics(
          button: true,
          label: tr('지우기'),
          excludeSemantics: true,
          child: Tooltip(
            message: tr('지우기'),
            child: InkWell(
              key: const ValueKey('carry-clear'),
              onTap: () => onChanged(c.cleared()),
              borderRadius: BorderRadius.circular(Gp.rSmall),
              child: Padding(
                padding: EdgeInsets.fromLTRB(2, 8, 4, 8),
                child: Icon(Icons.close, size: Gp.iS, color: Gp.accent),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 「이어 쓴 필터」 시트 — 이어 쓴 조건마다 × (그 조건만 지운다), 못 이어 쓴 조건은 까닭과 함께 옅게 (× 없음).
/// 지울 때마다 [onChanged] 로 바로 알린다 — 시트를 밀어 닫아도 지운 것이 남는다
Future<void> showCarrySheet(BuildContext context, FilterCarry carry, ValueChanged<FilterCarry> onChanged) =>
    showGpSheet<void>(
      context,
      tall: true,
      builder: (_) => _CarrySheet(carry: carry, onChanged: onChanged),
    );

class _CarrySheet extends StatefulWidget {
  const _CarrySheet({required this.carry, required this.onChanged});
  final FilterCarry carry;
  final ValueChanged<FilterCarry> onChanged;

  @override
  State<_CarrySheet> createState() => _CarrySheetState();
}

class _CarrySheetState extends State<_CarrySheet> {
  late FilterCarry _carry = widget.carry;

  void _remove(CarriedFilter one) {
    final next = _carry.without(one);
    widget.onChanged(next);
    // 이어 쓴 줄이 다 없어지면 알림도 사라지니 시트도 닫는다
    if (next.count == 0) {
      Navigator.pop(context);
      return;
    }
    setState(() => _carry = next); // STATE: × → 남은 줄
  }

  void _clear() {
    widget.onChanged(_carry.cleared());
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(tr('이어 쓴 필터'), padding: const EdgeInsets.fromLTRB(20, 0, 20, 4)),
          for (final c in _carry.carried)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      c.label,
                      style: TextStyle(fontSize: Gp.t14, color: Gp.ink),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: tr('지우기'),
                    icon: Icon(Icons.close, size: Gp.iM, color: Gp.muted),
                    onPressed: () => _remove(c),
                  ),
                ],
              ),
            ),
          for (final d in _carry.dropped)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 7, 20, 7),
              child: Text(
                '${d.label} — ${d.reason}',
                style: TextStyle(fontSize: Gp.t12, color: Gp.faint),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('carry-clear-all'),
                    onPressed: _clear,
                    child: Text(tr('지우기')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(tr('닫기'))),
                ),
              ],
            ),
          ),
        ],
      ),
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
