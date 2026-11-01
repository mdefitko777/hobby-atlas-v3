// 화면 J: 공식 예고 상세 — 원문(반다이 · 혼 웹 · 유튜브)을 앱 안에서 그대로 읽는다
//
// ┌──────── 디자인 가이드 대응표: J 공식 예고 상세 ────────────────────────────────────┐
// │ 번호 │ Flutter 위젯명                     │ 비즈니스 명칭(한글)                    │ 원칙(P번호)   │
// │ J-1  │ 위 띠: 뒤로 · 제목 한 줄 · SoftTag · 날짜 │ 예고 요약 (한 줄)                     │ P01 · P03     │
// │ J-2  │ WebViewWidget (+ 읽는 중 가는 줄)     │ 공식 원문 (글 · 사진 · 영상)            │ P02 · P10     │
// │ J-2b │ 요약 화면 (BlurFitImage · 단계 줄)     │ 원문을 열 수 없을 때 · 웹 미리보기       │ P09           │
// │ J-3  │ 아래 띠: TogglePill(알림 받기)        │ 다음 단계가 되면 휴대폰 알림 (진짜)      │ P03 · P07     │
// │ J-4  │ 아래 띠: 이 예고 · 상품 n → 시트       │ 4단계 진행 줄 + 제목 「」 으로 찾은 상품  │ P01 · P06     │
// │ J-5  │ 아래 띠: 브라우저로 (↗)               │ Chrome 등에서 열기 (번역할 때)          │ P10           │
// │ J-6  │ PageView (위 띠 · 아래 띠에서)        │ 좌우로 밀어 이전 · 다음 예고            │ P03           │
// │ J-7  │ 시트 안 가로 ProductTile (최대 12)    │ 같은 IP의 새 상품 (작품 · 없으면 채널)   │ P06 · P08     │
// └──────────────────────────────────────────────────────────────────────────────────┘
// 전환: 홈 배너 · 홈 공식 예고 줄 · 캘린더 예고 줄 · 예고 목록 · 알림에서 쌓기(push, 오른쪽에서).
import 'package:flutter/foundation.dart' show Factory;
import 'package:flutter/gestures.dart' show EagerGestureRecognizer, OneSequenceGestureRecognizer;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart' show AndroidWebViewController;

import '../api.dart';
import '../detail_pane.dart';
import '../channels.dart';
import '../logic/announcement_match.dart';
import '../models.dart';
import '../notifications/notify_store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'd_kit_detail_screen.dart';

/// [list] 를 주면 그 목록 안에서 좌우로 밀어 이전 · 다음 예고 (홈 배너 · 예고 목록 …)
void openAnnouncement(
  BuildContext context,
  Announcement a, {
  Loaders loaders = const Loaders(),
  List<Announcement> list = const [],
}) {
  final i = list.indexWhere((x) => x.id == a.id);
  openPage(
    context,
    i < 0 || list.length < 2
        ? AnnouncementScreen(item: a, loaders: loaders)
        : AnnouncementPager(items: list, index: i, loaders: loaders),
    id: a.id,
  );
}

/// J-6 예고 넘기기 — 원문은 위아래로, 예고는 좌우로
class AnnouncementPager extends StatefulWidget {
  const AnnouncementPager({super.key, required this.items, required this.index, this.loaders = const Loaders()});
  final List<Announcement> items;
  final int index;
  final Loaders loaders;

  @override
  State<AnnouncementPager> createState() => _AnnouncementPagerState();
}

class _AnnouncementPagerState extends State<AnnouncementPager> {
  late final _controller = PageController(initialPage: widget.index);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PageView.builder(
    controller: _controller,
    itemCount: widget.items.length,
    itemBuilder: (context, i) =>
        AnnouncementScreen(key: ValueKey(widget.items[i].id), item: widget.items[i], loaders: widget.loaders),
  );
}

/// 앱 안 웹 보기를 쓸 수 있나 — 안드로이드 · iOS 앱만 (웹 미리보기 · 위젯 테스트는 요약 화면)
bool get articleViewSupported => WebViewPlatform.instance != null;

class AnnouncementScreen extends StatefulWidget {
  const AnnouncementScreen({super.key, required this.item, this.loaders = const Loaders()});
  final Announcement item;
  final Loaders loaders;

  @override
  State<AnnouncementScreen> createState() => _AnnouncementScreenState();
}

class _AnnouncementScreenState extends State<AnnouncementScreen> {
  late final Uri? _uri = _webUri(widget.item.url);
  WebViewController? _web;

  /// 원문 읽는 중 (0–1, 1 이면 줄을 숨긴다)
  double _progress = 0;

  /// 원문을 앱 안에서 못 열었다 → 요약 화면 + 브라우저로
  bool _failed = false;

  /// 원문 안에서 다른 페이지로 갔다 → 뒤로 = 원문 안에서 뒤로
  bool _webBack = false;

  /// 이 예고 채널의 상품 (못 받으면 빈 목록)
  late final Future<List<Kit>> _all = widget.loaders
      .kits([widget.item.franchiseId])
      .then((kits) => kits, onError: (Object _) => const <Kit>[]);

  /// 제목 「」 으로 찾은 상품
  late final Future<List<Kit>> _related = _all.then((kits) => matchAnnouncementKits(widget.item.title, kits));

  /// J-7 같은 IP의 새 상품 (제목으로 찾은 상품의 작품, 없으면 채널 전체)
  late final Future<({String label, List<Kit> kits})> _sameIp = Future.wait([
    _all,
    _related,
  ]).then((r) => sameIpKits(r[1], r[0], channelLabel: channelOf(widget.item.franchiseId).label));

  @override
  void initState() {
    super.initState();
    final u = _uri;
    if (u != null && articleViewSupported) _web = _makeWeb(u);
  }

  static Uri? _webUri(String url) {
    final u = Uri.tryParse(url);
    return u != null && (u.scheme == 'https' || u.scheme == 'http') ? u : null;
  }

  WebViewController _makeWeb(Uri uri) {
    final c = _baseWeb(uri);
    // 휴대폰용 페이지가 없는 곳(코토부키야 상점 · 프리미엄 반다이 …): 페이지 전체 폭으로 줄여 보이고 두 손가락으로 키운다
    c.enableZoom(true);
    if (c.platform case final AndroidWebViewController android) android.setUseWideViewPort(true);
    return c;
  }

  WebViewController _baseWeb(Uri uri) => WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted) // 공식 페이지 · 유튜브는 스크립트가 있어야 글 · 영상이 보인다
    ..setNavigationDelegate(
      NavigationDelegate(
        onProgress: (p) {
          if (mounted) setState(() => _progress = p / 100); // STATE: 읽는 중 → 가는 줄
        },
        onPageFinished: (_) => _syncBack(),
        onUrlChange: (_) => _syncBack(),
        onWebResourceError: (e) {
          // 원문 자체를 못 열었을 때만 (사진 · 광고 하나가 안 되는 것은 무시)
          if ((e.isForMainFrame ?? false) && mounted) setState(() => _failed = true); // STATE: 실패 → 요약 + 브라우저로
        },
        onNavigationRequest: (r) {
          // 앱 열기 링크(intent: · market: · line: …)는 휴대폰에 맡긴다
          final u = Uri.tryParse(r.url);
          if (u == null || u.scheme == 'http' || u.scheme == 'https' || u.scheme == 'about') {
            return NavigationDecision.navigate;
          }
          launchUrl(u, mode: LaunchMode.externalApplication);
          return NavigationDecision.prevent;
        },
      ),
    )
    ..loadRequest(uri);

  Future<void> _syncBack() async {
    final back = await _web?.canGoBack() ?? false;
    if (mounted && back != _webBack) setState(() => _webBack = back); // STATE: 원문 안 뒤로 가능
  }

  /// J-5 브라우저로 (Chrome 의 번역을 쓰고 싶을 때)
  Future<void> _openOutside() async {
    final u = _uri;
    if (u == null) {
      showToast(context, '원문 주소가 없는 예고예요');
      return;
    }
    final ok = await launchUrl(u, mode: LaunchMode.externalApplication);
    if (!ok && mounted) showToast(context, '브라우저를 열지 못했어요');
  }

  /// J-3 알림 받기 — 다음 단계(상품화 확정 · 예약 시작 · 발매)가 되면 휴대폰 알림
  void _toggleFollow(NotifyStore store) {
    final a = widget.item;
    if (a.status == announcementStages.last) {
      showToast(context, '이미 발매된 예고예요');
      return;
    }
    final before = store.isFollowing(a.id);
    void set(bool on) => store.setFollow(a.id, on, stage: a.status, title: a.title, franchise: a.franchiseId);
    set(!before); // STATE: 알림 받기 → 버튼 채움 (notify_config.json)
    showToast(
      context,
      before
          ? '이 예고 알림을 껐어요'
          : store.config.enabled
          ? '다음 단계가 되면 알려 드릴게요'
          : '다음 단계가 되면 알림함에 넣어 둘게요 · 휴대폰 알림은 설정에서 켜요',
      onUndo: () => set(before),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.item;
    final web = _failed ? null : _web;
    final page = Scaffold(
      backgroundColor: Gp.panel,
      body: Column(
        children: [
          _TopBar(item: a, onBack: () => Navigator.of(context).maybePop()), // J-1
          if (web != null)
            SizedBox(height: 2, child: _progress < 1 ? LinearProgressIndicator(value: _progress, minHeight: 2) : null)
          else
            const Divider(height: 1),
          Expanded(
            child: web != null
                ? WebViewWidget(
                    // J-2 P02 원문 위의 손가락은 전부 원문이 받는다 (위아래 스크롤 · 확대가 끊기지 않게).
                    // 예고 넘기기(J-6)는 위 띠 · 아래 띠에서 좌우로
                    controller: web,
                    gestureRecognizers: {Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new)},
                  )
                : _Summary(item: a, failed: _failed && _uri != null), // J-2b P09
          ),
          _BottomBar(
            // J-3 · J-4 · J-5
            item: a,
            related: _related,
            onFollow: _toggleFollow,
            onAbout: () => _showAbout(context),
            onOutside: _openOutside,
          ),
        ],
      ),
    );
    // 원문 안에서 링크를 따라갔으면 휴대폰 뒤로 = 원문 안에서 뒤로
    return PopScope(
      canPop: !_webBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _web?.goBack().then((_) => _syncBack());
      },
      child: page,
    );
  }

  /// J-4 이 예고 — 단계 줄 + 제목으로 찾은 상품 (시트)
  void _showAbout(BuildContext context) {
    final a = widget.item;
    final stage = announcementStages.indexOf(a.status).clamp(0, announcementStages.length - 1);
    showGpSheet<void>(
      context,
      heightFactor: gpSheetHeight,
      builder: (sheet) => ListView(
        padding: const EdgeInsets.fromLTRB(0, 20, 0, 24),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.title,
                  style: const TextStyle(fontSize: Gp.t16, fontWeight: FontWeight.w600, height: 1.4),
                ),
                const SizedBox(height: 6),
                Text(
                  joinDot([channelOf(a.franchiseId).label, dateDot(a.date), a.source]),
                  style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
                ),
                const SizedBox(height: 20),
                _StageLine(current: stage),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<Kit>>(
            future: _related,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const SizedBox(height: 120, child: LoadingView());
              }
              final kits = snap.data ?? const <Kit>[];
              if (kits.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    '제목에서 상품을 찾지 못했어요 · 상품화되면 여기에 보여요', // P09
                    style: TextStyle(color: Gp.muted, fontSize: Gp.t12),
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader('이 예고의 상품', subtitle: '${kits.length}개'), // P06
                  _tiles(sheet, kits),
                ],
              );
            },
          ),
          FutureBuilder<({String label, List<Kit> kits})>(
            future: _sameIp, // J-7
            builder: (context, snap) {
              final ip = snap.data;
              if (ip == null || ip.kits.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader('같은 IP의 새 상품', subtitle: ip.label), // P06
                  _tiles(sheet, ip.kits),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// 가로 상품 줄 (누르면 시트를 닫고 상세)
  Widget _tiles(BuildContext sheet, List<Kit> kits) => SizedBox(
    height: 148 + 32,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: kits.length,
      separatorBuilder: (_, _) => const SizedBox(width: 12),
      itemBuilder: (context, i) => ProductTile(
        image: kits[i].image,
        title: kits[i].name,
        imageWidth: 148,
        onTap: () {
          Navigator.pop(sheet);
          openKitDetail(this.context, kits[i], loaders: widget.loaders, list: kits);
        },
        marks: QuickMarks(kit: kits[i]),
      ),
    ),
  );
}

/// J-1 위 띠 — 뒤로 · 제목 한 줄 · 단계 · 날짜 출처
class _TopBar extends StatelessWidget {
  const _TopBar({required this.item, required this.onBack});
  final Announcement item;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: SizedBox(
      height: 56,
      child: Row(
        children: [
          IconButton(
            tooltip: '뒤로',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new, size: Gp.iM, color: Gp.ink),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: Gp.t14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    SoftTag(item.status, color: stageColor(item.status)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        joinDot([dateDot(item.date), item.source]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: Gp.t11, color: Gp.muted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    ),
  );
}

/// J-3 · J-4 · J-5 아래 띠
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.item,
    required this.related,
    required this.onFollow,
    required this.onAbout,
    required this.onOutside,
  });
  final Announcement item;
  final Future<List<Kit>> related;
  final void Function(NotifyStore store) onFollow;
  final VoidCallback onAbout;
  final VoidCallback onOutside;

  @override
  Widget build(BuildContext context) {
    final store = NotifyScope.of(context);
    final on = store.isFollowing(item.id);
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Gp.panel,
        border: Border(top: BorderSide(color: Gp.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(
            children: [
              Expanded(
                child: TogglePill(
                  label: on ? '알림 받는 중' : '알림 받기',
                  icon: Icons.notifications_none,
                  activeIcon: Icons.notifications_active,
                  active: on,
                  onTap: () => onFollow(store),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FutureBuilder<List<Kit>>(
                  future: related,
                  builder: (context, snap) {
                    final n = snap.data?.length ?? 0;
                    return OutlinedButton.icon(
                      onPressed: onAbout,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(Gp.radius))),
                      ),
                      icon: const Icon(Icons.info_outline, size: Gp.iS),
                      label: Text(n > 0 ? '이 예고 · 상품 $n' : '이 예고'),
                    );
                  },
                ),
              ),
              IconButton(
                tooltip: '브라우저로 열기',
                onPressed: onOutside,
                icon: const Icon(Icons.open_in_new, size: Gp.iM, color: Gp.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// J-2b 요약 — 원문을 앱 안에서 열 수 없을 때 (웹 미리보기 · 열기 실패 · 주소 없음)
class _Summary extends StatelessWidget {
  const _Summary({required this.item, required this.failed});
  final Announcement item;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final stage = announcementStages.indexOf(item.status).clamp(0, announcementStages.length - 1);
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        if (item.image.isNotEmpty) AspectRatio(aspectRatio: 16 / 9, child: BlurFitImage(item.image)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (failed) ...[
                const Text(
                  '이 페이지는 앱 안에서 열 수 없어요 · 아래 ↗ 로 브라우저에서 볼 수 있어요',
                  style: TextStyle(fontSize: Gp.t12, color: Gp.danger),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                item.title,
                style: const TextStyle(fontSize: Gp.t19, fontWeight: FontWeight.w600, height: 1.35),
              ),
              const SizedBox(height: 6),
              Text(
                joinDot([channelOf(item.franchiseId).label, dateDot(item.date), item.source]),
                style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
              ),
              const SizedBox(height: 20),
              _StageLine(current: stage),
            ],
          ),
        ),
      ],
    );
  }
}

/// J-4 단계 진행 줄 — 지난 단계 · 지금(브랜드 색) · 남은 단계(회색)
class _StageLine extends StatelessWidget {
  const _StageLine({required this.current});
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, label) in announcementStages.indexed) ...[
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 2,
                        color: i == 0 ? Colors.transparent : (i <= current ? Gp.accent : Gp.line),
                      ),
                    ),
                    Container(
                      width: i == current ? 14 : 10,
                      height: i == current ? 14 : 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i <= current ? Gp.accent : Gp.panel,
                        border: Border.all(color: i <= current ? Gp.accent : Gp.line, width: 2),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 2,
                        color: i == announcementStages.length - 1
                            ? Colors.transparent
                            : (i < current ? Gp.accent : Gp.line),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: Gp.t11,
                    fontWeight: i == current ? FontWeight.w700 : FontWeight.w400,
                    color: i == current ? Gp.accent : (i < current ? Gp.ink : Gp.faint),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
