// 넓은 화면(폴드 펼침 · 태블릿 · 넓은 창)의 반반 화면 — QQ 처럼 왼쪽은 앱 그대로, 오른쪽은 자세히 칸.
// 상세 · 공고 · 친구 · 내 정보 · 알림 · 설정 · 작품 도감은 openPage 로 연다:
//   폰(칸 없음)  → 지금처럼 쌓기(push, 오른쪽에서)
//   왼쪽에서 열기 → 오른쪽 칸의 내용을 바꿈 (메신저에서 대화방을 고르듯)
//   오른쪽 안에서 열기 → 오른쪽 칸 안에서 쌓기 (‹ 로 돌아감)
// 상태관리 패키지 없이: 칸 Navigator 의 GlobalKey 하나 + "칸 안쪽" 표시 InheritedWidget
// + 지금 열린 것(id)은 맨 위 PaneHost 의 setState 로 (좋아요 · 구매함 MarksHost 와 같은 방식).
import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import 'l10n/l10n.dart';
import 'theme.dart';

/// 오른쪽 자세히 칸의 Navigator — 앱에 칸은 하나뿐. 넓은 화면에서만 붙어 있다(아니면 currentState == null)
final detailPaneKey = GlobalKey<NavigatorState>();

/// 오른쪽 칸에 지금 열린 것의 id (상품 id · 공고 id · 친구 아이디) — 왼쪽 목록이 같은 줄을 칠한다.
/// MaterialApp.builder 에 둔다. 칸이 없거나(폰) 비면 null.
class PaneHost extends StatefulWidget {
  const PaneHost({super.key, required this.child});
  final Widget child;

  @override
  State<PaneHost> createState() => _PaneHostState();
}

class _PaneHostState extends State<PaneHost> {
  String? _id;

  void _select(String? id) {
    if (id != _id) setState(() => _id = id); // STATE: 오른쪽 칸에 연 것 → 왼쪽 카드 테두리 · 줄 바탕
  }

  @override
  Widget build(BuildContext context) => _PaneScope(id: _id, host: this, child: widget.child);
}

class _PaneScope extends InheritedWidget {
  const _PaneScope({required this.id, required this.host, required super.child});
  final String? id;
  final _PaneHostState host;

  @override
  bool updateShouldNotify(_PaneScope old) => id != old.id;
}

/// 지금 오른쪽 칸에 열린 것의 id (테스트 · 확인용)
String? paneSelectedId(BuildContext context) => context.getInheritedWidgetOfExactType<_PaneScope>()?.id;

/// 이 id 가 지금 오른쪽 칸에 열려 있나 — 그리는 중에 부르면, 바뀔 때 다시 그려진다
bool isPaneSelected(BuildContext context, String? id) {
  final scope = context.dependOnInheritedWidgetOfExactType<_PaneScope>();
  return id != null && scope != null && detailPaneKey.currentState != null && scope.id == id;
}

void _selectPane(BuildContext context, String? id) =>
    context.getInheritedWidgetOfExactType<_PaneScope>()?.host._select(id);

/// 오른쪽 칸 안쪽 표시 — 여기서 연 화면은 칸 안에서 쌓는다
class _InsidePane extends InheritedWidget {
  const _InsidePane({required super.child});

  @override
  bool updateShouldNotify(_InsidePane old) => false;
}

/// 화면 열기: 넓으면 오른쪽 칸, 아니면 쌓기
void openPage(BuildContext context, Widget page, {String? id}) {
  final nav = detailPaneKey.currentState;
  final inside = context.getInheritedWidgetOfExactType<_InsidePane>() != null;
  // 앱 셸(맨 아래 화면: 왼쪽 · 서랍 · 🔔 ⚙)에서 연 것만 칸으로. 위에 덮인 전체 화면(카메라 결과 등)에서는 그 위에 쌓기
  final fromShell = ModalRoute.of(context)?.isFirst ?? false;
  if (nav == null || (!inside && !fromShell)) {
    Navigator.of(context, rootNavigator: true).push(CupertinoPageRoute<void>(builder: (_) => page));
    return;
  }
  if (inside) {
    nav.push(CupertinoPageRoute<void>(builder: (_) => page)); // 칸 안에서 더 들어가기
  } else {
    // 왼쪽에서 고름 → 칸 내용을 바꿈 (빈 칸 안내 위에 하나만) + 왼쪽에서 그 줄을 칠함
    _selectPane(context, id);
    nav.pushAndRemoveUntil(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => page,
        transitionDuration: const Duration(milliseconds: 180),
        transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
      ),
      (r) => r.isFirst,
    );
  }
}

/// 오른쪽 칸 본체: 칸 전용 Navigator + 아무것도 안 골랐을 때 안내
class DetailPaneView extends StatefulWidget {
  const DetailPaneView({super.key});

  @override
  State<DetailPaneView> createState() => _DetailPaneViewState();
}

class _DetailPaneViewState extends State<DetailPaneView> {
  // 칸이 빈 안내로 돌아가면(‹) 왼쪽 칠하기를 지운다
  late final _watcher = _EmptyWatcher(() => _selectPane(context, null));

  @override
  Widget build(BuildContext context) {
    return _InsidePane(
      // 안드로이드 뒤로 가기: 오른쪽 칸에 쌓인 게 있으면 그것부터 닫는다
      child: NavigatorPopHandler<void>(
        onPopWithResult: (_) => detailPaneKey.currentState?.maybePop(),
        child: ClipRect(
          child: Navigator(
            key: detailPaneKey,
            observers: [_watcher],
            onGenerateRoute: (_) => PageRouteBuilder<void>(pageBuilder: (_, _, _) => const _EmptyPane()),
          ),
        ),
      ),
    );
  }
}

/// 칸이 빈 안내로 돌아가면 왼쪽 칠하기를 지운다
class _EmptyWatcher extends NavigatorObserver {
  _EmptyWatcher(this.onEmpty);
  final VoidCallback onEmpty;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute?.isFirst ?? false) onEmpty();
  }
}

/// 빈 칸: 옅은 로고 + 한 줄 안내 (QQ 의 펭귄 자리)
class _EmptyPane extends StatelessWidget {
  const _EmptyPane();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Gp.bg,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.view_in_ar_outlined, size: 72, color: Gp.ghost),
            const SizedBox(height: 10),
            const Text(
              'Hobby Atlas',
              style: TextStyle(fontSize: Gp.t24, fontWeight: FontWeight.w800, letterSpacing: 1.5, color: Gp.ghost),
            ),
            const SizedBox(height: 8),
            Text(
              tr('상품 · 공고 · 친구를 고르면 여기에 보여요'),
              style: const TextStyle(fontSize: Gp.t12, color: Gp.faint),
            ),
          ],
        ),
      ),
    );
  }
}
