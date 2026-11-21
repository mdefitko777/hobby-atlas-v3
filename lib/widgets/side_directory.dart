// 왼쪽 묶음 목록 + 오른쪽 칸 격자 한 벌 — 검색 탭 종류 · 세대(B-20 · B-21)와 도감(G)이 같은 틀을 쓴다.
//   목록 너비 108dp · 밀기 + ≡ 손잡이로 펴고 접기(240ms easeOutCubic) · 펴면 한 줄 3칸, 접으면 4칸(폰) · 칸은 정사각 그림 + 이름.
//   펴 둔 상태는 쓰는 화면이 기기에 따로 기억한다 (검색 browse_dir_open · 도감 guide_dir_open).
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme.dart';
import 'feedback.dart' show navClearance;
import 'tiles.dart' show KeepWordsText, categoryGridGap, categoryNameExtent, keepWords;

/// 왼쪽 묶음 목록 너비 — 묶음 이름이 두 줄 안에 든다 (한 줄 한글 7자 안팎)
const sideDirWidth = 108.0;

/// 칸 하나의 가장 작은 너비 — 넓은 화면은 이만큼씩 칸을 늘린다. 폰은 이것보다 좁아도 펴면 3칸, 접으면 4칸
/// (2026-11-20 주인: 칸이 너무 크다 · 한 줄 3 / 2 칸 → 4 / 3 칸, 360dp 폰에서 칸 너비 약 70dp)
const sideCellMinWidth = 80.0;

/// 오른쪽 칸 격자 재기 — 열 수 · 칸 너비 · 칸 높이(정사각 그림 + 이름 두 줄). 분류 칸 · 도감 칸이 같은 크기
class SideGrid {
  const SideGrid._(this.cols, this.cellW, this.nameExtent);

  /// [width] = 오른쪽 칸 자리 너비, [open] = 묶음 목록이 펴짐 (폰에서 3칸, 접히면 4칸)
  factory SideGrid.of(BuildContext context, double width, {required bool open}) {
    final inner = width - pad * 2;
    final cols = (inner / sideCellMinWidth).floor().clamp(open ? 3 : 4, 8);
    final cellW = (inner - categoryGridGap * (cols - 1)) / cols;
    return SideGrid._(cols, cellW, categoryNameExtent(context, cellW));
  }

  /// 격자 옆 여백
  static const pad = 12.0;
  final int cols;
  final double cellW;

  /// 그림 아래 이름 두 줄 + 틈 높이 ([categoryNameExtent] — 칸 너비에 따라 이름 크기가 다르다)
  final double nameExtent;

  /// 칸 그림 자리 높이 — 정사각 (반다이 남코 Collectibles 칸처럼, 2026-11-20 주인. 전에는 1.25 : 1)
  double get imageHeight => cellW;

  SliverGridDelegate get delegate => SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: cols,
    mainAxisSpacing: categoryGridGap + 4,
    crossAxisSpacing: categoryGridGap,
    mainAxisExtent: imageHeight + nameExtent,
  );

  /// 칸 격자 한 덩이 (그릴 때만 칸을 만든다)
  Widget sliver(int count, IndexedWidgetBuilder cell) => SliverPadding(
    padding: const EdgeInsets.fromLTRB(pad, 4, pad, 0),
    sliver: SliverGrid(
      gridDelegate: delegate,
      delegate: SliverChildBuilderDelegate(cell, childCount: count),
    ),
  );
}

/// 오른쪽 칸 자리에 넘기는 것 — 묶음 목록이 펴졌는지 · 손잡이가 든 머리 줄
class SidePane {
  const SidePane._(this.open, this._toggle, this._handleKey);

  /// 펴짐 (반 넘게) — 칸 수를 정한다
  final bool open;
  final VoidCallback _toggle;
  final Key _handleKey;

  /// 머리 줄: ≡ 손잡이 · 제목 · [actions] (? · 공유 …)
  Widget head(String title, {List<Widget> actions = const []}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Row(
      children: [
        IconButton(
          key: _handleKey,
          tooltip: open ? tr('묶음 접기') : tr('묶음 펴기'),
          visualDensity: VisualDensity.compact,
          onPressed: _toggle,
          icon: Icon(open ? Icons.menu_open : Icons.menu, size: Gp.iM, color: Gp.muted),
        ),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: Gp.t14, fontWeight: FontWeight.w700),
          ),
        ),
        ...actions,
      ],
    ),
  );
}

/// 왼쪽 묶음 목록([rows] = [SideDirHead] · [SideDirItem]) + 오른쪽 칸 자리([pane]). 오른쪽으로 밀면 펴고 왼쪽으로 밀면 접는다
class SideDirectory extends StatefulWidget {
  const SideDirectory({
    super.key,
    required this.rows,
    required this.pane,
    required this.initialOpen,
    required this.onOpenChanged,
    this.directoryKey = const ValueKey('browse-dir'),
    this.handleKey = const ValueKey('dir-handle'),
  });

  final List<Widget> rows;
  final Widget Function(BuildContext context, SidePane pane) pane;

  /// 처음 펴짐 — 기기에 기억한 값
  final bool initialOpen;

  /// 손잡이 · 밀기로 바뀌었을 때 (기기에 기억)
  final ValueChanged<bool> onOpenChanged;

  /// 화면 테스트가 찾는 열쇠 (검색 · 도감이 따로)
  final Key directoryKey;
  final Key handleKey;

  @override
  State<SideDirectory> createState() => _SideDirectoryState();
}

class _SideDirectoryState extends State<SideDirectory> with SingleTickerProviderStateMixin {
  /// 묶음 목록이 펴진 정도 (0 = 접힘, 1 = 펴짐)
  late final AnimationController _dir = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    value: widget.initialOpen ? 1 : 0,
  );

  @override
  void dispose() {
    _dir.dispose();
    super.dispose();
  }

  void _set(bool open) {
    _dir.animateTo(open ? 1 : 0, curve: Curves.easeOutCubic);
    widget.onOpenChanged(open); // STATE: 묶음 목록 펴짐 (기기 저장)
  }

  /// 밀기를 놓을 때: 빠르게 밀었으면 그 방향, 아니면 반 넘게 펴졌는지로
  void _dragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    _set(v.abs() > 300 ? v > 0 : _dir.value >= 0.5);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    // 칸 격자는 세로로만 움직여 가로 밀기와 겹치지 않는다
    behavior: HitTestBehavior.translucent,
    onHorizontalDragUpdate: (d) => _dir.value += (d.primaryDelta ?? 0) / sideDirWidth,
    onHorizontalDragEnd: _dragEnd,
    child: AnimatedBuilder(
      animation: _dir,
      builder: (context, _) {
        final open = _dir.value >= 0.5;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_dir.value > 0)
              SizedBox(
                width: sideDirWidth * _dir.value,
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.centerRight,
                    minWidth: sideDirWidth,
                    maxWidth: sideDirWidth,
                    child: DecoratedBox(
                      key: widget.directoryKey,
                      decoration: BoxDecoration(
                        border: Border(right: BorderSide(color: Gp.line)),
                      ),
                      // 한 번에 다 만든다 (작품 60개 안팎) — 고른 줄이 아래에 있어도 처음에 보이게 [SideDirItem]
                      child: SingleChildScrollView(
                        padding: EdgeInsets.only(top: 4, bottom: navClearance(context)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: widget.rows),
                      ),
                    ),
                  ),
                ),
              ),
            // 목록이 사라져도 칸 자리 상태(받은 칸 · 스크롤)는 그대로
            Expanded(
              key: const ValueKey('side-pane'),
              child: widget.pane(context, SidePane._(open, () => _set(!open), widget.handleKey)),
            ),
          ],
        );
      },
    ),
  );
}

/// 묶음 목록 한 줄 — 고르면 파란 글자 + 왼쪽 선. 처음 그릴 때 고른 줄이면 목록을 그 줄까지 내린다
class SideDirItem extends StatefulWidget {
  const SideDirItem({super.key, required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<SideDirItem> createState() => _SideDirItemState();
}

class _SideDirItemState extends State<SideDirItem> {
  @override
  void initState() {
    super.initState();
    if (!widget.selected) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 목록 하나만 움직인다 (Scrollable.ensureVisible 은 바깥 스크롤까지 움직인다)
      final ro = mounted ? context.findRenderObject() : null;
      if (ro != null && ro.attached) Scrollable.maybeOf(context)?.position.ensureVisible(ro, alignment: 0.3);
    });
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: selected ? Gp.accent : Colors.transparent, width: 3)),
          ),
          // 낱말 안에서 줄이 바뀌지 않게 ('베이블레이 / 드 X')
          child: KeepWordsText(
            widget.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: Gp.t14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              color: selected ? Gp.accent : Gp.ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// 묶음 목록 안 머리 (검색 '전체'의 채널 · 도감의 시대) — [onTap] 이 있으면 이름 뒤 ›
class SideDirHead extends StatelessWidget {
  const SideDirHead({super.key, required this.label, this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 4, 4),
      // › 는 이름 바로 뒤에 붙인다 — 오른쪽 끝에 따로 두면 그만큼 이름 칸이 좁아져 '베이블레이드' 도 한 줄에 못 들었다
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: keepWords(label)),
            // 아이콘(WidgetSpan)은 혼자 다음 줄로 떨어져서 글자 › 를 붙지 않는 빈칸(U+00A0)으로 잇는다
            if (onTap != null) const TextSpan(text: ' ›'),
          ],
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: Gp.t12, fontWeight: FontWeight.w800, color: Gp.muted),
      ),
    ),
  );
}
