// 채널 바 접기 — 내용을 한참(400 쯤, 한 번 세게 밀어 한 화면쯤) 내려 읽어야 채널 바만 위로 접히고, 조금이라도 올리면 다시 나온다.
// 아바타 줄은 늘 그대로. 손가락을 따라 조금씩 움직이면 어지럽다고 해서(2026-11-21 주인) 200ms 에 한 번에 접고 편다.
// 앱 셸 하나([HeaderCollapse])가 네 탭에서 올라오는 ScrollNotification 을 보고 정하고, 탭 머리([CollapsingHeader])는
// 그 값만 따른다 — 탭 화면이 스크롤을 따로 알리지 않아도 목록 · 당겨서 새로 고침 · 안쪽 탭 화면이 모두 같게 움직인다.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// 채널 바를 접었나 (true = 접힘). 앱 셸이 든다 — 탭을 바꾸거나 다른 탭으로 보낼 때 [show]
class HeaderCollapseController extends ValueNotifier<bool> {
  HeaderCollapseController() : super(false);

  bool get hidden => value;

  /// 이미 펴져 있어도 알린다 — 값이 같으면 ValueNotifier 가 조용해서, 앞 탭에서 내려 읽은 거리가 다음 탭으로 이어졌다
  void show() {
    if (value) {
      value = false;
    } else {
      notifyListeners();
    }
  }
}

/// 접고 펴는 시간 (2026-11-20 주인 시안: 200ms 쯤 한 번에)
const headerSnapDuration = Duration(milliseconds: 200);

/// 위로 올리지 않고 이만큼 내려 읽어야 접는다 — 천천히 읽는 동안은 그대로 (2026-11-21 주인: 12 는 너무 빨랐다)
const headerHideAfter = 400.0;

/// 채널 바를 접은 뒤 이만큼 더 내려 읽어야 탭 줄까지 접는다 (2026-11-21 주인: 한 겹씩 접히고 맨 윗줄만 남게)
const headerHideAfter2 = 320.0;

/// 이만큼 올리면 편다 (조금만 올려도)
const _showAfter = 6.0;

/// 앱 셸이 탭 묶음을 감싼다: 아래에서 올라오는 세로 스크롤을 보고 [controller] 를 정하고, 접힘 정도를 [CollapsingHeader] 에 내려 준다
class HeaderCollapse extends StatefulWidget {
  const HeaderCollapse({super.key, required this.controller, required this.child});

  final HeaderCollapseController controller;
  final Widget child;

  @override
  State<HeaderCollapse> createState() => _HeaderCollapseState();
}

class _HeaderCollapseState extends State<HeaderCollapse> with TickerProviderStateMixin {
  late final _anim = AnimationController(
    vsync: this,
    duration: headerSnapDuration,
    value: widget.controller.hidden ? 1 : 0,
  );

  // 접을 때 · 펼 때 모두 처음이 빠르고 끝이 느리게 (거꾸로 갈 때는 곡선도 거꾸로)
  late final _collapse = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);

  /// 두 번째 겹 — 탭 줄 (전체 · 종류 · 세대 …). 채널 바가 접힌 뒤에도 계속 내려 읽으면 이것도 접힌다
  late final _anim2 = AnimationController(vsync: this, duration: headerSnapDuration);
  late final _collapse2 = CurvedAnimation(parent: _anim2, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);

  /// 마지막으로 올린 뒤 내려 읽은 거리 (손으로 민 것 + 그 뒤 미끄러진 것)
  double _down = 0;

  /// 이번에 올린 거리
  double _up = 0;

  /// 지금 스크롤이 손에서 시작됐나 — 화면이 스스로 옮긴 것(jumpTo · animateTo)은 세지 않는다
  bool _user = false;

  /// 펼친 채널 바 높이 — [CollapsingHeader] 가 잴 때마다 알려 준다
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
    _collapse2.dispose();
    _anim.dispose();
    _anim2.dispose();
    super.dispose();
  }

  void _follow() {
    _down = 0;
    _up = 0;
    if (widget.controller.hidden) {
      _anim.forward();
    } else {
      _anim.reverse();
      _set2(false); // 탭을 바꾸거나 맨 위로 가면 두 겹 다 펴진다
    }
  }

  /// 두 번째 겹 접기 · 펴기
  void _set2(bool hidden) {
    if (hidden == (_anim2.status == AnimationStatus.forward || _anim2.value == 1)) return;
    hidden ? _anim2.forward() : _anim2.reverse();
  }

  void _set(bool hidden) {
    if (widget.controller.value != hidden) widget.controller.value = hidden; // STATE: 스크롤 거리 · 방향 → 채널 바 접기 · 펴기
  }

  /// 목록마다 마지막으로 본 보이는 높이 — 높이가 바뀐 알림은 채널 바를 접고 펴서(또는 자판이 올라와서) 생긴 것이라 무시한다
  final _viewport = Expando<double>();

  bool _onNotification(Notification n) {
    if (n is ScrollMetricsNotification) {
      // 내용이 바뀌어(채널 바꾸기 · 새 결과 · 필터) 맨 위에서 시작하거나 짧아 스크롤할 수 없으면 편다 — 접힌 채 못 꺼내지 않게.
      // 안쪽 작은 스크롤(가로 줄 · 글자 칸)은 depth 로 거른다
      final m = n.metrics;
      if (n.depth != 0 || m.axis != Axis.vertical) return false;
      final before = _viewport[n.context];
      _viewport[n.context] = m.viewportDimension;
      // 채널 바가 접히면 옆 목록(검색 탭 묶음 목록처럼 맨 위에 있는 것)도 높이가 바뀐다 — 그 알림으로 펴면 접고 펴기를 되풀이한다
      if (before != null && before != m.viewportDimension) return false;
      if (m.maxScrollExtent <= 0 || m.pixels <= m.minScrollExtent) _set(false);
      return false;
    }
    if (n is! ScrollNotification || n.metrics.axis != Axis.vertical) return false; // 가로로 넘기는 줄 · 안쪽 탭 화면은 무시
    final m = n.metrics;
    if (n is ScrollStartNotification) {
      _user = n.dragDetails != null; // 손으로 시작한 스크롤 (놓은 뒤 미끄러지는 것도 같은 스크롤)
      return false;
    }
    if (n is ScrollEndNotification) {
      _user = false;
      return false;
    }
    if (n is OverscrollNotification) {
      if (n.overscroll < 0) _set(false); // 맨 위에서 더 당김 = 당겨서 새로 고침
      return false;
    }
    if (n is! ScrollUpdateNotification) return false;
    if (m.pixels <= m.minScrollExtent) {
      _set2(false);
      _set(false); // 맨 위로 돌아왔다
      _down = 0;
      return false;
    }
    final d = n.scrollDelta ?? 0;
    if (!_user || d == 0) return false;
    // 끝 너머에서 올라온 것 = 채널 바가 접혀 목록이 길어지며 끝이 당겨진 것 (사람이 올린 게 아니다).
    // 이것으로 펴면 끝 가까이에서 접자마자 도로 펴져 흔들린다
    if (d < 0 && m.pixels - d > m.maxScrollExtent) return false;
    if (d < 0) {
      _up -= d;
      if (_up > _showAfter) {
        _down = 0;
        _set2(false); // 조금만 올려도 두 겹 다 돌아온다
        _set(false);
      }
      return false;
    }
    _up = 0;
    _down += d;
    // 채널 바를 접어 목록이 길어져도 아직 스크롤이 남을 때만 접는다 — 짧은 목록에서 접혔다 펴졌다 흔들리지 않게
    if (_down > headerHideAfter && m.maxScrollExtent > _extent) _set(true);
    // 채널 바가 접힌 뒤에도 더 내려 읽으면 탭 줄까지 — 맨 윗줄(프로필 · Lv · 검색 · 알림)만 남는다
    if (_down > headerHideAfter + headerHideAfter2 && widget.controller.hidden) _set2(true);
    return false;
  }

  @override
  Widget build(BuildContext context) => NotificationListener<Notification>(
    onNotification: _onNotification,
    child: _HeaderScope(collapse: _collapse, collapse2: _collapse2, onExtent: (h) => _extent = h, child: widget.child),
  );
}

class _HeaderScope extends InheritedWidget {
  const _HeaderScope({required this.collapse, required this.collapse2, required this.onExtent, required super.child});

  /// 0 = 펼침 · 1 = 접힘 (첫 겹 = 채널 바)
  final Animation<double> collapse;

  /// 두 번째 겹 = 탭 줄
  final Animation<double> collapse2;
  final ValueChanged<double> onExtent;

  @override
  bool updateShouldNotify(_HeaderScope old) => collapse != old.collapse || collapse2 != old.collapse2;
}

/// 접히는 채널 바 — [HeaderCollapse] 안이면 위로 밀려 접히고, 밖(셸 없이 띄운 화면 · 검색 덮개 · 테스트)이면 늘 펼침
class CollapsingHeader extends StatelessWidget {
  const CollapsingHeader({super.key, required this.child, this.step = 1});
  final Widget child;

  /// 1 = 채널 바 (먼저 접힘) · 2 = 탭 줄 (더 내려 읽으면 접힘)
  final int step;

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_HeaderScope>();
    if (scope == null) return child;
    final anim = step == 2 ? scope.collapse2 : scope.collapse;
    return AnimatedBuilder(
      animation: anim,
      child: step == 2 ? child : _ReportHeight(onHeight: scope.onExtent, child: child),
      builder: (context, child) {
        final t = anim.value;
        return ExcludeSemantics(
          excluding: t >= 1, // 접힌 채널 바의 버튼은 읽지 않는다 (높이 0 이라 눌리지도 않음)
          child: ClipRect(
            // 아래쪽을 붙여 두고 높이를 줄인다 = 위로 밀려 나가는 모양
            child: Align(alignment: Alignment.bottomCenter, heightFactor: 1 - t, child: child),
          ),
        );
      },
    );
  }
}

/// 펼친 높이 재기 (Align 이 줄여도 child 는 늘 제 높이로 잡힌다)
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
