// 화면 S: 앱 셸 — 위: 아바타 줄 → 채널 바 / 아래: 바닥에 붙은 반투명 탭 바 (홈 · 검색 · (카메라) · 캘린더 · 컬렉션)
//
// ┌──────── 디자인 가이드 대응표: S 앱 셸 ───────────────────────────────────────────┐
// │ 번호 │ Flutter 위젯명                  │ 비즈니스 명칭(한글)                    │ 원칙(P번호)   │
// │ S-1  │ MyAvatar (색 고리 + 사진, 채널 바 위)  │ 친구 서랍 열기 → 서랍 머리에서 내 정보    │ P04 · P06     │
// │ S-2  │ BackdropFilter 바닥 탭 바       │ 반투명 하단 탭 바 (양옆 여백 없음)      │ P08           │
// │ S-3  │ 하단 탭 4개 (폰 · 반반 화면 왼쪽)      │ 홈 · 검색 · 캘린더 · 컬렉션              │ P06 · P04     │
// │ S-4  │ 가운데 카메라 버튼              │ 찍어서 찾기 (사진 · 바코드 · 앨범)     │ P07           │
// │ S-5  │ NavigationRail (가로 폰: 높이 <520)    │ 측면 탭 (아바타 / 탭 4개 / 🔔 ⚙)          │ 적응형 · P04  │
// │ S-6  │ IndexedStack                    │ 탭 상태 유지                           │ P03           │
// │ S-7  │ 내 채널 목록(UserStore 에 저장)    │ 네 화면이 같이 쓰는 내 IP 채널         │ P04           │
// │ S-9  │ 오른쪽 위 🔔 (안 읽은 수)          │ 알림 열기 · 휴대폰 알림 누르면 이동     │ P01           │
// │ S-10 │ 오른쪽 위 ⚙                     │ 설정 열기 (K)                          │ P04 · P06     │
// │ S-11 │ Drawer (아바타 · 홈 가장자리 밀기)     │ 친구 서랍 (M)                          │ P07           │
// │ S-13 │ AnimatedAlign(heightFactor) 아바타 줄 │ 아래로 스크롤하면 위 줄도 접힘          │ P08           │
// │ S-12 │ Row(왼쪽 폰 화면 | 오른쪽 Navigator)│ 반반 화면 (폴드 · 태블릿 · 넓은 창 ≥700dp) │ 적응형      │
// │ S-8  │ AnimatedSlide · AnimatedPositioned │ 아래로 스크롤하면 탭 바 숨김, 카메라만 오른쪽 아래 │ P08 · P07 │
// └────────────────────────────────────────────────────────────────────────────────┘
// 전환: S-3 옆으로(탭) · S-4 덮기(bottom sheet) · S-1 덮기(Drawer → M) · S-9 · S-10 쌓기(push, 넓은 화면은 오른쪽 칸).
// S-8: X · Threads처럼 내용을 내려 읽는 동안 탭 바를 숨겨 화면을 넓히고, 카메라 버튼만 남긴다.
// 현행 앱 문제: 위 5개 IP + 아래 5개 화면 + 도감 안 탭 → v2는 아래 탭 하나 + 화면 안 채널 바 하나.
import 'dart:ui' show DisplayFeatureType, ImageFilter;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

import '../api.dart';
import '../data/user_store.dart';
import '../detail_pane.dart';
import '../channels.dart';
import '../level.dart';
import '../marks.dart';
import '../notifications/local_notifier.dart';
import '../notifications/notify_store.dart';
import '../sync/account.dart';
import '../theme.dart';
import '../update/update_ui.dart';
import '../widgets.dart';
import 'a_home_screen.dart';
import 'b_search_screen.dart';
import 'd_kit_detail_screen.dart';
import 'e_camera_screen.dart';
import 'f_collection_screen.dart';
import 'h_calendar_screen.dart';
import 'i_profile_screen.dart';
import 'j_announcement_screen.dart';
import 'k_settings_screen.dart';
import 'm_friends_drawer.dart';
import 'n_notifications_screen.dart';
import 'u_social.dart' show MyAvatar;

/// 넓은 화면 기준 (Material 3 window size class: expanded ≥ 840dp)
/// 이만큼 넓으면(폴드 펼침 · 태블릿 · 넓은 창) 반반 화면: 왼쪽 = 폰 화면 그대로, 오른쪽 = 자세히 칸
const twoPaneBreakpoint = 700.0;

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.loaders = const Loaders(), this.notify});

  final Loaders loaders;

  /// 알림 한 벌 (테스트는 NotifyStore.memory())
  final NotifyStore? notify;

  @override
  State<AppShell> createState() => _AppShellState();
}

/// 하단 탭 (가운데 +는 탭이 아니라 동작)
const _tabs = <(IconData, IconData, String)>[
  (Icons.home_outlined, Icons.home, '홈'),
  (Icons.search, Icons.search, '검색'),
  (Icons.calendar_today_outlined, Icons.calendar_today, '캘린더'),
  (Icons.auto_awesome_mosaic_outlined, Icons.auto_awesome_mosaic, '컬렉션'), // 책갈피 리본은 구매함 표시라 겹치지 않게
];

class _AppShellState extends State<AppShell> {
  int _tab = 0;

  /// 하단 탭 바가 보이는지 (아래로 스크롤하면 숨김)
  bool _barShown = true;

  /// 홈 검색 알약 → 검색 탭 검색창에 커서
  int _searchFocusTick = 0;
  List<String> _myChannels = [...defaultMyChannels]; // S-7 P04 — 실제 값은 UserStore(기기 저장)에서

  final _scaffold = GlobalKey<ScaffoldState>();

  late final NotifyStore _notify = widget.notify ?? NotifyScope.read(context);
  UserStore? _me;

  /// 탭 묶음 (화면 모양이 바뀌어도 유지)
  final _bodyKey = GlobalKey();

  /// 내 정보 숫자 → 컬렉션 탭의 그 목록 (F-11)
  CollectionJump _jump = CollectionJump.liked;
  int _jumpTick = 0;

  void _setChannels(List<String> ids) {
    setState(() => _myChannels = [...ids]); // STATE: 내 채널 → 네 화면의 채널 바와 목록
    _me?.setMyChannels(ids); // 기기에 저장 (다음 실행 · 새 데이터를 받아 셸을 다시 만들 때도 그대로)
  }

  @override
  void initState() {
    super.initState();
    LocalNotifier.taps.addListener(_onNotificationTap);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onNotificationTap(); // 앱이 꺼져 있을 때 알림을 눌러 켰으면
      _askNotifyOnce();
      askUpdateOnce(context); // 큰 업데이트면 한 번 묻기 (나중에 → ⬇ 아이콘만)
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 내 채널은 내 기록(UserStore)에 저장된다 — 처음 읽기가 끝나면 · 다른 곳에서 바뀌면 따라간다
    final me = Marks.read(context).store;
    if (!identical(me, _me)) {
      _me?.removeListener(_onUserStore);
      _me = me..addListener(_onUserStore);
      _myChannels = [...me.myChannels];
    }
  }

  @override
  void dispose() {
    LocalNotifier.taps.removeListener(_onNotificationTap);
    _me?.removeListener(_onUserStore);
    super.dispose();
  }

  void _onUserStore() {
    final ids = _me!.myChannels;
    if (!listEquals(ids, _myChannels)) setState(() => _myChannels = [...ids]); // STATE: 저장된 내 채널 → 채널 바
  }

  /// 휴대폰 알림을 눌렀을 때: `kit:<id>` → 상품 상세, 그 밖에는 알림 화면
  Future<void> _onNotificationTap() async {
    final payload = LocalNotifier.taps.value;
    if (payload == null || !mounted) return;
    LocalNotifier.taps.value = null;
    // ann:<franchise>:<예고 id> → 공식 예고 (예고 단계 알림)
    if (payload.split(':') case ['ann', final ch, final id]) {
      try {
        final a = (await widget.loaders.announcements([ch])).where((a) => a.id == id).firstOrNull;
        if (!mounted) return;
        if (a != null) return openAnnouncement(context, a, loaders: widget.loaders);
      } on ApiException catch (e) {
        if (mounted) showToast(context, e.message);
      }
    }
    final kitId = payload.startsWith('kit:') ? payload.substring(4) : '';
    if (kitId.isNotEmpty) {
      _notify.markKitRead(kitId);
      try {
        final kits = await widget.loaders.kitsByIds([kitId]);
        if (!mounted) return;
        if (kits.isNotEmpty) {
          openKitDetail(context, kits.first, loaders: widget.loaders);
          return;
        }
      } on ApiException catch (e) {
        if (mounted) showToast(context, e.message);
      }
    }
    if (mounted) openNotifications(context, myChannels: _myChannels, loaders: widget.loaders, notify: _notify);
  }

  /// 처음 실행 때 한 번: 알림 권한(안드로이드 13+) → 허용하면 삼성 배터리 안내
  Future<void> _askNotifyOnce() async {
    final ok = await _notify.askPermissionOnce();
    if (ok && mounted && !_notify.config.hintShown) await showBatteryHint(context, _notify);
  }

  /// 검색 탭으로 + 검색창 커서 (홈 검색창 · 카메라 결과의 "이름으로 검색")
  void _goSearch() => setState(() {
    _tab = 1; // STATE: 검색으로 → 검색 탭 + 커서
    _searchFocusTick++;
    _barShown = true;
  });

  void _openAdd() {
    showModalBottomSheet<void>(
      // S-4 P07
      context: context,
      builder: (sheet) => AddSheet(
        onPick: (pick) {
          Navigator.pop(sheet);
          switch (pick) {
            case 'photo':
              openCamera(context, CameraMode.photo, loaders: widget.loaders, onGoSearch: _goSearch);
            case 'barcode':
              openCamera(context, CameraMode.barcode, loaders: widget.loaders, onGoSearch: _goSearch);
            default:
              openAlbum(context, loaders: widget.loaders, onGoSearch: _goSearch);
          }
        },
      ),
    );
  }

  /// 내 정보 숫자 · 홈 내 보드 → 컬렉션 탭 + 그 목록(좋아요 · 구매함 · 도감)
  void _jumpTo(CollectionJump j) => setState(() {
    _tab = 3; // STATE: 컬렉션 탭 + 그 목록
    _jump = j;
    _jumpTick++;
    _barShown = true;
  });

  void _openProfile() => openProfile(
    // S-1 → I 내 정보
    context,
    loaders: widget.loaders,
    myChannels: _myChannels,
    onJump: _jumpTo,
  );

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // 가로로 눕힌 폰(높이가 낮음) → 측면 탭: 위 아바타 줄과 아래 탭 바를 빼서 내용 높이를 확보
    final shortLandscape = size.width > size.height && size.height < 520;
    final wide = shortLandscape;
    // 폴드 펼침 · 태블릿 · 넓은 창 → 반반 화면 (QQ 처럼, S-12)
    final twoPane = !shortLandscape && size.width >= twoPaneBreakpoint;
    final account = AccountScope.of(context); // 이름 첫 글자 · 친구 요청 수
    // S-1 P04 아바타 → 친구 서랍(M). 서랍 머리의 아바타를 한 번 더 누르면 내 정보(I)
    final avatar = MyAvatar(
      // 아바타 사진(I-3)이 있으면 사진, 없으면 첫 글자
      fallback: 'A',
      size: 34,
      ringWidth: 2,
      tooltip: '친구 · 내 정보',
      onTap: () => _scaffold.currentState?.openDrawer(),
    );
    final bell = IconButton(
      // S-9 알림 (N)
      tooltip: '알림',
      onPressed: () =>
          openNotifications(context, myChannels: _myChannels, loaders: widget.loaders, notify: _notify), // N
      icon: ListenableBuilder(
        listenable: _notify,
        builder: (context, _) {
          // 안 읽은 알림 + 받은 친구 요청
          final unread = _notify.unreadCount(_myChannels) + account.incomingCount;
          return Badge(
            isLabelVisible: unread > 0,
            backgroundColor: Gp.accent, // 안 읽은 알림 수 = 브랜드 색
            label: Text(unread > 99 ? '99+' : '$unread'),
            child: const Icon(Icons.notifications_none, color: Gp.ink),
          );
        },
      ),
    );
    final gear = IconButton(
      // S-10 설정
      tooltip: '설정',
      onPressed: () => openSettings(context),
      icon: const Icon(Icons.settings_outlined, color: Gp.ink),
    );
    // S-13 아바타 줄은 늘 그대로 — 스크롤 중에 접으면 목록 높이가 바뀌어 손가락 아래 내용이 흔들린다.
    // 아래로 스크롤할 때는 아래 탭 바만 내용 위로 미끄러져 나간다 (_NarrowLayout)
    final topRow = Row(
      children: [
        avatar,
        const SizedBox(width: 6),
        LevelButton(loaders: widget.loaders),
        const Spacer(),
        const UpdateButton(), // 새 빌드가 있을 때만 ⬇
        bell,
        gear,
      ],
    );
    Widget page(int i) => i == 0
        ? HomeScreen(
            // A
            key: const ValueKey(0),
            leading: wide ? null : topRow,
            myChannels: _myChannels,
            onMyChannelsChanged: _setChannels,
            onCamera: _openAdd,
            onOpenSearch: _goSearch,
            onJump: _jumpTo,
            loaders: widget.loaders,
          )
        : i == 1
        ? SearchScreen(
            // B
            key: const ValueKey(1),
            leading: wide ? null : topRow,
            myChannels: _myChannels,
            onMyChannelsChanged: _setChannels,
            onCamera: _openAdd,
            focusTick: _searchFocusTick,
            loaders: widget.loaders,
          )
        : i == 2
        ? CalendarScreen(
            // H
            key: const ValueKey(2),
            leading: wide ? null : topRow,
            myChannels: _myChannels,
            onMyChannelsChanged: _setChannels,
            loaders: widget.loaders,
          )
        : CollectionScreen(
            // F
            key: const ValueKey(3),
            leading: wide ? null : topRow,
            myChannels: _myChannels,
            onMyChannelsChanged: _setChannels,
            onGoSearch: _goSearch,
            loaders: widget.loaders,
            jump: _jump,
            jumpTick: _jumpTick,
          );
    // 화면 모양이 바뀌어도(폴드 접기/펴기) 탭들의 상태가 그대로 옮겨 가게 GlobalKey
    final body = KeyedSubtree(
      key: _bodyKey,
      child: IndexedStack(
        // S-6 P03
        index: _tab,
        children: [
          for (var i = 0; i < _tabs.length; i++)
            // 뒤에 살아 있는 탭의 스크롤 알림은 막는다 — 위 줄이 접히면 그 탭들도 크기가 바뀌어
            // "스크롤할 게 없음" 알림을 보내 탭 바를 도로 꺼내 버린다
            NotificationListener<ScrollMetricsNotification>(onNotification: (_) => i != _tab, child: page(i)),
        ],
      ),
    );
    final narrow = _NarrowLayout(
      body: body,
      barShown: _barShown,
      bar: _BottomBar(
        index: _tab,
        onSelect: (i) => setState(() {
          _tab = i; // STATE: 탭 번호 → IndexedStack
          _barShown = true;
        }),
      ),
      camera: _CameraButton(onTap: _openAdd),
      onScroll: (shown) {
        if (shown != _barShown) setState(() => _barShown = shown); // STATE: 스크롤 방향 → 탭 바 숨김/표시
      },
    );
    return Scaffold(
      key: _scaffold,
      extendBody: true, // 탭 바 뒤로 내용이 비쳐 보이게
      // S-11 친구 서랍 (M): 아바타 · 홈에서 왼쪽 가장자리를 오른쪽으로 밀기
      drawer: FriendsDrawer(
        loaders: widget.loaders,
        onOpenProfile: _openProfile,
        onOpenFriend: (m) => openFriend(context, m, loaders: widget.loaders),
      ),
      drawerEdgeDragWidth: _tab == 0 ? 56 : 0,
      drawerScrimColor: Gp.shadow,
      body: SafeArea(
        bottom: false,
        child: wide
            ? Row(
                children: [
                  // S-5 높이가 모자라면 측면 탭이 위아래로 스크롤 (넘침 방지)
                  LayoutBuilder(
                    builder: (context, box) => SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: box.maxHeight),
                        child: IntrinsicHeight(
                          child: NavigationRail(
                            selectedIndex: _tab,
                            labelType: shortLandscape ? NavigationRailLabelType.none : NavigationRailLabelType.all,
                            onDestinationSelected: (i) => setState(() => _tab = i),
                            // 가로 폰: 탭이 먼저 보이게 — 아바타 / 탭 4개 / 🔔 ⚙ 한 줄 (카메라는 검색창 카메라로)
                            leading: shortLandscape
                                ? Padding(padding: const EdgeInsets.only(top: 4), child: avatar)
                                : Column(
                                    children: [
                                      const SizedBox(height: 8),
                                      avatar,
                                      const SizedBox(height: 8),
                                      bell,
                                      gear,
                                      const SizedBox(height: 10),
                                      _CameraButton(onTap: _openAdd),
                                      const SizedBox(height: 8),
                                    ],
                                  ),
                            trailing: shortLandscape
                                ? IconButtonTheme(
                                    data: const IconButtonThemeData(
                                      style: ButtonStyle(visualDensity: VisualDensity.compact),
                                    ),
                                    child: Row(mainAxisSize: MainAxisSize.min, children: [bell, gear]),
                                  )
                                : null,
                            destinations: [
                              for (final t in _tabs)
                                NavigationRailDestination(
                                  icon: Icon(t.$1),
                                  selectedIcon: Icon(t.$2),
                                  label: Text(t.$3),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: body),
                ],
              )
            : twoPane
            ? _TwoPane(left: narrow)
            : narrow,
      ),
    );
  }
}

/// S-12 반반 화면 — 폴드 접힘선(힌지)이 있으면 거기서, 없으면 왼쪽 45% (320–460)
class _TwoPane extends StatelessWidget {
  const _TwoPane({required this.left});
  final Widget left;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        // 세로로 긴 접힘선 · 힌지 (화면을 좌우로 나누는 것)
        final fold = mq.displayFeatures
            .where((f) => f.type != DisplayFeatureType.cutout && f.bounds.height > box.maxHeight / 2)
            .firstOrNull;
        final leftW = fold != null ? fold.bounds.left : (box.maxWidth * 0.45).clamp(320.0, 460.0);
        final gap = fold != null ? fold.bounds.width : 1.0;
        final rightW = box.maxWidth - leftW - gap;
        // 각 칸 안의 화면이 자기 칸 너비를 화면 너비로 알게 (폰 화면 · 상세 화면 배치가 그대로 동작)
        MediaQuery sized(double w, Widget child) => MediaQuery(
          data: mq.copyWith(size: Size(w, mq.size.height)),
          child: child,
        );
        return Row(
          children: [
            SizedBox(width: leftW, child: sized(leftW, left)),
            if (fold != null) SizedBox(width: gap) else const VerticalDivider(width: 1),
            SizedBox(width: rightW, child: sized(rightW, const DetailPaneView())),
          ],
        );
      },
    );
  }
}

/// S-4 카메라 버튼 — 홈 카드의 +(좋아요 담기)와 구분되게 카메라 모양
class _CameraButton extends StatelessWidget {
  const _CameraButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RaisedCircleButton(
      tooltip: '찍어서 찾기',
      size: _cameraSize,
      onTap: onTap,
      child: const Icon(Icons.photo_camera_outlined, color: Gp.ink, size: Gp.iL),
    );
  }
}

const _cameraSize = 52.0;
const _barHeight = 62.0;

/// 좁은 화면: 내용 + 바닥 탭 바 + 카메라 버튼(S-8 스크롤에 따라 위치 이동)
class _NarrowLayout extends StatelessWidget {
  const _NarrowLayout({
    required this.body,
    required this.bar,
    required this.camera,
    required this.barShown,
    required this.onScroll,
  });

  final Widget body;
  final Widget bar;
  final Widget camera;
  final bool barShown;
  final ValueChanged<bool> onScroll;

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    const curve = Curves.easeOutCubic;
    const duration = Duration(milliseconds: 260);
    return LayoutBuilder(
      builder: (context, box) => Stack(
        children: [
          Positioned.fill(
            child: NotificationListener<ScrollMetricsNotification>(
              // 내용이 짧아 스크롤할 수 없게 되면 탭 바를 다시 보인다
              onNotification: (n) {
                // depth 0 = 그 탭의 바깥 목록만 (검색창 글자칸 · 가로 줄 같은 안쪽 스크롤은 무시)
                if (n.depth == 0 && n.metrics.axis == Axis.vertical && n.metrics.maxScrollExtent <= 0) {
                  onScroll(true);
                }
                return false;
              },
              child: NotificationListener<UserScrollNotification>(
                onNotification: (n) {
                  // 세로 스크롤만 본다 (가로로 넘기는 줄은 무시)
                  if (n.metrics.axis == Axis.vertical) {
                    if (n.direction == ScrollDirection.reverse) onScroll(false);
                    if (n.direction == ScrollDirection.forward) onScroll(true);
                  }
                  return false;
                },
                child: body,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedSlide(
              // S-8
              offset: barShown ? Offset.zero : const Offset(0, 1.1),
              duration: duration,
              curve: curve,
              child: bar,
            ),
          ),
          AnimatedPositioned(
            // S-8 P07
            duration: duration,
            curve: curve,
            left: barShown ? (box.maxWidth - _cameraSize) / 2 : box.maxWidth - _cameraSize - 18,
            bottom: barShown ? safeBottom + (_barHeight - _cameraSize) / 2 : safeBottom + 22,
            child: camera,
          ),
        ],
      ),
    );
  }
}

/// S-2 바닥에 붙은 반투명 탭 바 (양옆 여백 없이 화면 끝까지)
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    Widget item(int i) {
      final t = _tabs[i];
      final on = i == index;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onSelect(i),
          child: Semantics(
            selected: on,
            button: true,
            label: t.$3,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(on ? t.$2 : t.$1, size: Gp.iL, color: on ? Gp.ink : Gp.navIdle),
                const SizedBox(height: 3),
                Text(
                  t.$3,
                  style: TextStyle(
                    fontSize: Gp.t11,
                    letterSpacing: 0.4,
                    fontWeight: on ? FontWeight.w700 : FontWeight.w400,
                    color: on ? Gp.ink : Gp.navIdle,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: Gp.glass,
            border: Border(top: BorderSide(color: Gp.line)),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: _barHeight,
              child: Row(
                children: [
                  item(0), // S-3 P06
                  item(1),
                  const Spacer(), // 가운데: 카메라 버튼 자리(S-4는 위에 겹쳐 놓는다)
                  item(2),
                  item(3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// S-4 찍어서 찾기 시트: 사진으로 찾기 · 바코드 · 앨범 → E 화면
class AddSheet extends StatelessWidget {
  const AddSheet({super.key, required this.onPick});

  /// 'photo' · 'barcode' · 'album'
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.center_focus_strong_outlined),
              title: const Text('사진으로 찾기'),
              subtitle: const Text('상자나 실물을 찍으면 후보를 보여 줘요'),
              onTap: () => onPick('photo'),
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_scanner),
              title: const Text('바코드 스캔'),
              subtitle: const Text('상자 뒷면 바코드로 정확히 찾기'),
              onTap: () => onPick('barcode'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('앨범에서 선택'),
              subtitle: const Text('저장해 둔 사진·캡처로 찾기'),
              onTap: () => onPick('album'),
            ),
          ],
        ),
      ),
    );
  }
}
