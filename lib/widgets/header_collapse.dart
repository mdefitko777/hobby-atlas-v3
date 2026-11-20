// 탭 위 머리 접기 — 내용을 내려 읽으면 아바타 줄 · 채널 바가 위로 접히고, 살짝 올리면 다시 나온다
// (SliverAppBar floating + snap 처럼 200ms 에 한 번에). 검색창 줄은 머리 밖이라 그대로 남는다.
// 앱 셸 하나([HeaderCollapse])가 네 탭에서 올라오는 ScrollNotification 을 보고 정하고, 탭 머리([CollapsingHeader])는
// 그 값만 따른다 — 탭 화면이 스크롤을 따로 알리지 않아도 목록 · 당겨서 새로 고침 · 안쪽 탭 화면이 모두 같게 움직인다.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// 머리를 접었나 (true = 접힘). 앱 셸이 든다 — 탭을 바꾸거나 다른 탭으로 보낼 때 [show]
class HeaderCollapseController extends ValueNotifier<bool> {
  HeaderCollapseController() : super(false);

  bool get hidden => value;
  void show() => value = false;
}

/// 접고 펴는 시간 (2026-11-20 주인 시안: 200ms 쯤 한 번에)
const headerSnapDuration = Duration(milliseconds: 200);

/// 이만큼 손으로 내리면 접는다 — 탭하려다 조금 밀린 것으로는 접지 않게
const _hideAfter = 12.0;

/// 이만큼 손으로 올리면 편다 ("살짝 올리면")
const _showAfter = 6.0;

/// 앱 셸이 탭 묶음을 감싼다: 아래에서 올라오는 세로 스크롤을 보고 [controller] 를 정하고, 접힘 정도를 [CollapsingHeader] 에 내려 준다
class HeaderCollapse extends StatefulWidget {
  const HeaderCollapse({super.key, required this.controller, required this.child});

  final HeaderCollapseController controller;
  final Widget child;

  @override
  State<HeaderCollapse> createState() => _HeaderCollapseState();
}

class _HeaderCollapseState extends State<HeaderCollapse> with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(
    vsync: this,
    duration: headerSnapDuration,
    value: widget.controller.hidden ? 1 : 0,
  );

  // 접을 때 · 펼 때 모두 처음이 빠르고 끝이 느리게 (거꾸로 갈 때는 곡선도 거꾸로)
  late final _collapse = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);

  /// 같은 방향으로 손으로 민 거리 (방향이 바뀌면 0부터)
  double _drag = 0;

  /// 펼친 머리 높이 — [CollapsingHeader] 가 잴 때마다 알려 준다
  double _extent = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_follow);
  }

  @override
  void didUpdateWidget(HeaderCollapse old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_follow);
      widget.controller.addListener(_follow);
      _follow();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_follow);
    _collapse.dispose();
    _anim.dispose();
    super.dispose();
  }

  void _follow() {
    _drag = 0;
    widget.controller.hidden ? _anim.forward() : _anim.reverse();
  }

  void _set(bool hidden) {
    if (widget.controller.value != hidden) widget.controller.value = hidden; // STATE: 스크롤 방향 → 머리 접기 · 펴기
  }

  /// 목록마다 마지막으로 본 보이는 높이 — 높이가 바뀐 알림은 머리를 접고 펴서(또는 자판이 올라와서) 생긴 것이라 무시한다
  final _viewport = Expando<double>();

  bool _onNotification(Notification n) {
    if (n is ScrollMetricsNotification) {
      // 내용이 바뀌어(채널 바꾸기 · 새 결과 · 필터) 맨 위에서 시작하거나 짧아 스크롤할 수 없으면 편다 — 접힌 채 못 꺼내지 않게.
      // 안쪽 작은 스크롤(가로 줄 · 글자 칸)은 depth 로 거른다
      final m = n.metrics;
      if (n.depth != 0 || m.axis != Axis.vertical) return false;
      final before = _viewport[n.context];
      _viewport[n.context] = m.viewportDimension;
      // 머리가 접히면 옆 목록(검색 탭 묶음 목록처럼 맨 위에 있는 것)도 높이가 바뀐다 — 그 알림으로 펴면 접고 펴기를 되풀이한다
      if (before != null && before != m.viewportDimension) return false;
      if (m.maxScrollExtent <= 0 || m.pixels <= m.minScrollExtent) _set(false);
      return false;
    }
    if (n is! ScrollNotification || n.metrics.axis != Axis.vertical) return false; // 가로로 넘기는 줄 · 안쪽 탭 화면은 무시
    final m = n.metrics;
    if (n is OverscrollNotification) {
      if (n.overscroll < 0) _set(false); // 맨 위에서 더 당김 = 당겨서 새로 고침
      return false;
    }
    if (n is! ScrollUpdateNotification) return false;
    if (m.pixels <= m.minScrollExtent) {
      _set(false); // 맨 위로 돌아왔다
      return false;
    }
    // 손으로 민 것만 센다 — 머리가 접혀 목록이 길어지면서 위치가 고쳐지는 것(dragDetails 없음)으로 다시 펴지 않게
    if (n.dragDetails == null) return false;
    final d = n.scrollDelta ?? 0;
    if (d == 0) return false;
    if ((d > 0) != (_drag > 0)) _drag = 0;
    _drag += d;
    // 머리를 접어 목록이 길어져도 아직 스크롤이 남을 때만 접는다 — 짧은 목록에서 접혔다 펴졌다 흔들리지 않게
    if (_drag > _hideAfter && m.maxScrollExtent > _extent) {
      _set(true);
    } else if (_drag < -_showAfter) {
      _set(false);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => NotificationListener<Notification>(
    onNotification: _onNotification,
    child: _HeaderScope(collapse: _collapse, onExtent: (h) => _extent = h, child: widget.child),
  );
}

class _HeaderScope extends InheritedWidget {
  const _HeaderScope({required this.collapse, required this.onExtent, required super.child});

  /// 0 = 펼침 · 1 = 접힘
  final Animation<double> collapse;
  final ValueChanged<double> onExtent;

  @override
  bool updateShouldNotify(_HeaderScope old) => collapse != old.collapse;
}

/// 탭 위 머리 (아바타 줄 · 채널 바) — [HeaderCollapse] 안이면 위로 밀려 접히고, 밖(셸 없이 띄운 화면 · 테스트)이면 늘 펼침
class CollapsingHeader extends StatelessWidget {
  const CollapsingHeader({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_HeaderScope>();
    if (scope == null) return child;
    return AnimatedBuilder(
      animation: scope.collapse,
      child: _ReportHeight(onHeight: scope.onExtent, child: child),
      builder: (context, child) {
        final t = scope.collapse.value;
        return ExcludeSemantics(
          excluding: t >= 1, // 접힌 머리의 버튼은 읽지 않는다 (높이 0 이라 눌리지도 않음)
          child: ClipRect(
            // 아래쪽을 붙여 두고 높이를 줄인다 = 머리가 위로 밀려 나가는 모양
            child: Align(alignment: Alignment.bottomCenter, heightFactor: 1 - t, child: child),
          ),
        );
      },
    );
  }
}

/// 펼친 머리 높이 재기 (Align 이 줄여도 child 는 늘 제 높이로 잡힌다)
class _ReportHeight extends SingleChildRenderObjectWidget {
  const _ReportHeight({required this.onHeight, super.child});
  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderReportHeight(onHeight);

  @override
  void updateRenderObject(BuildContext context, _RenderReportHeight renderObject) => renderObject.onHeight = onHeight;
}

class _RenderReportHeight extends RenderProxyBox {
  _RenderReportHeight(this.onHeight);
  ValueChanged<double> onHeight;

  @override
  void performLayout() {
    super.performLayout();
    onHeight(size.height);
  }
}
