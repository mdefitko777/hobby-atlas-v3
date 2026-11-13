// 화면 J: 공식 예고 상세 — 원문(반다이 · 혼 웹 · 유튜브)을 앱 안에서 그대로 읽는다
//
// ┌──────── 디자인 가이드 대응표: J 공식 예고 상세 ────────────────────────────────────┐
// │ 번호 │ Flutter 위젯명                     │ 비즈니스 명칭(한글)                    │ 원칙(P번호)   │
// │ J-1  │ 위 띠: 뒤로 · 제목 한 줄 · AnnTag · 날짜 │ 예고 요약 (한 줄, 라이브 · 예약이면 때) │ P01 · P03     │
// │ J-2  │ WebViewWidget (+ 읽는 중 가는 줄)     │ 공식 원문 (글 · 사진 · 영상)            │ P02 · P10     │
// │ J-2b │ 요약 화면 (BlurFitImage · 단계 줄)     │ 원문을 열 수 없을 때 · 웹 미리보기 (+ 예약 시작 · 마감 한 줄) │ P09 │
// │ J-3  │ 아래 띠: TogglePill(알림 받기)        │ 다음 단계가 되면 휴대폰 알림 (진짜)      │ P03 · P07     │
// │ J-4  │ 아래 띠: 이 예고 · 상품 n → 시트       │ 4단계 진행 줄(비공식이면 안내 한 줄 · 예약 시작 · 마감 한 줄) + 이어진 상품 · 제목 「」 으로 찾은 상품 │ P01 · P06 │
// │ J-5  │ 아래 띠: 브라우저로 (↗)               │ Chrome 등에서 열기                      │ P10           │
// │ J-5b │ 아래 띠: 번역 (文A)                   │ 원문 글을 한국어로 · 다시 누르면 원문    │ P02 · P03     │
// │ J-6  │ PageView (위 띠 · 아래 띠에서)        │ 좌우로 밀어 이전 · 다음 예고            │ P03           │
// │ J-7  │ 시트 안 가로 ProductTile (최대 12)    │ 같은 IP의 새 상품 (작품 · 없으면 채널)   │ P06 · P08     │
// │ J-8  │ ExpandRow + AnimatedSize (J-2b · J-4) │ 상품 소개: 사진 · 가격 · 예약 기간 · 발송 · 설명 · 사양 · 구성품 · 공식 상품 페이지 (글은 일본어 그대로, 공식만) │ P02 · P08 │
// └──────────────────────────────────────────────────────────────────────────────────┘
// 전환: 홈 배너 · 홈 공식 예고 줄 · 캘린더 예고 줄 · 예고 목록 · 알림에서 쌓기(push, 오른쪽에서).
import 'dart:async';

import 'package:flutter/foundation.dart' show Factory;
import 'package:flutter/gestures.dart' show EagerGestureRecognizer, OneSequenceGestureRecognizer;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart' show AndroidWebViewController;

import '../api.dart';
import '../clock.dart';
import '../data/announcement_details.dart' show AnnDetail;
import '../data/page_translate.dart';
import '../logic/page_text.dart';
import '../detail_pane.dart';
import '../channels.dart';
import '../l10n/l10n.dart';
import '../logic/announcement_match.dart';
import '../logic/preorder_open.dart';
import '../models.dart';
import '../notifications/live_reminders.dart' show liveLead;
import '../notifications/notify_store.dart';
import '../notifications/preorder_reminders.dart' show preorderRule;
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

  /// J-5b 번역해서 보는 중 (원문 안에서 다른 페이지로 가도 이어서 번역)
  bool _translateOn = false;

  /// 번역 중 · 모델 받는 중이면 진행 글 (빈 글자 = 쉬는 중)
  String _translateBusy = '';

  /// J-5b 번역 차례 — 새로 번역을 시작하면 +1. 옛 차례(다른 페이지로 감 · 화면을 닫음)는 멈추고 화면을 건드리지 않는다
  int _trRun = 0;

  /// J-5b 켜는 중 (모델 확인 · 묻기 · 받기) — 빨리 두 번 눌러도 한 번만
  bool _toggling = false;

  /// 원문 안에서 주소만 바뀜(SPA — 유튜브 등) → 새 글이 그려질 때쯤 다시 번역
  Timer? _urlTr;

  /// 이 예고 채널의 상품 (못 받으면 빈 목록)
  late final Future<List<Kit>> _all = widget.loaders
      .kits([widget.item.franchiseId])
      .then((kits) => kits, onError: (Object _) => const <Kit>[]);

  /// 이 예고의 상품: 데이터가 이어 둔 상품이 먼저, 그다음 제목 「」 으로 찾은 상품
  late final Future<List<Kit>> _related = _all.then((kits) => annKits(widget.item, kits));

  /// J-8 상품 소개 + 이어진 상품 (사진 · 가격이 비었을 때 빌린다). 비공식 소식은 늘 없음 — 공식 상품 페이지가 아니다
  late final Future<_Intro> _intro = widget.item.unofficial
      ? Future.value((detail: null, kit: null))
      : Future.wait<Object?>([
          widget.loaders.annDetails().then<Object?>((m) => m[widget.item.id], onError: (Object _) => null),
          _all,
        ]).then(
          (r) => (
            detail: r[0] as AnnDetail?,
            kit: (r[1]! as List<Kit>).where((k) => k.id == widget.item.linkedKitId).firstOrNull,
          ),
        );

  /// J-7 같은 IP의 새 상품 (제목으로 찾은 상품의 작품, 없으면 채널 전체)
  late final Future<({String label, List<Kit> kits})> _sameIp = Future.wait([
    _all,
    _related,
  ]).then((r) => sameIpKits(r[1], r[0], channelLabel: tr(channelOf(widget.item.franchiseId).label)));

  @override
  void initState() {
    super.initState();
    final u = _uri;
    if (u != null && articleViewSupported) _web = _makeWeb(u);
  }

  @override
  void dispose() {
    _urlTr?.cancel();
    super.dispose();
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
        onPageStarted: (_) {
          // 다른 페이지로 넘어가기 시작 — 앞 페이지 번역은 끝낸다 (새 페이지는 onPageFinished 가 다시 번역)
          _trRun++;
          _urlTr?.cancel();
          if (mounted && _translateBusy.isNotEmpty) setState(() => _translateBusy = ''); // STATE: 번역 멈춤 → 버튼
        },
        onPageFinished: (_) {
          _urlTr?.cancel(); // 페이지를 다시 읽었으면 여기서 한 번만
          _syncBack();
          if (_translateOn) _translatePage();
        },
        onUrlChange: (_) {
          _syncBack();
          // 페이지를 다시 읽지 않고 주소만 바꾸는 곳은 onPageFinished 가 안 온다 → 조금 기다렸다 새 글을 번역
          _urlTr?.cancel();
          if (!_translateOn) return;
          _urlTr = Timer(const Duration(milliseconds: 800), () {
            // 아직 읽는 중이면 onPageFinished 가 번역한다
            if (mounted && _translateOn && _progress >= 1) _translatePage();
          });
        },
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

  /// J-5b 번역 켜고 끄기 — 처음이면 모델(약 60 MB)을 받을지 먼저 묻는다
  Future<void> _toggleTranslate() async {
    final web = _web;
    if (web == null || _translateBusy.isNotEmpty || _toggling) return;
    if (_translateOn) {
      _urlTr?.cancel();
      setState(() => _translateOn = false); // STATE: 번역 끔 → 원문
      await web.runJavaScript(restoreTextsJs);
      return;
    }
    _toggling = true; // 첫 await 전에 — 모델 확인 중에 또 눌러도 대화상자 · 번역이 두 번 뜨지 않게
    try {
      final translator = PageTranslator.instance;
      if (!await translator.ready()) {
        if (!mounted) return;
        final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(tr('번역 모델 받기')),
            // 번역은 화면 언어로 (lib/data/page_translate.dart) — 중국어 화면이면 일본어 · 중국어 모델
            content: Text(tr('일본어 · 한국어 번역 모델(약 60 MB)을 한 번 받아요. 그다음부터는 인터넷 없이도 이 기기 안에서 번역해요. Wi-Fi 에서 받는 것을 권해요.')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('나중에'))),
              TextButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('받기'))),
            ],
          ),
        );
        if (ok != true || !mounted) return;
        setState(() => _translateBusy = tr('모델 받는 중')); // STATE: 모델 받는 중 → 버튼 옆 글
        final done = await translator.download(); // 멈춘 받기는 5분 뒤 false
        if (!mounted) return;
        setState(() => _translateBusy = '');
        if (!done) {
          showToast(context, tr('번역 모델을 받지 못했어요 · 인터넷을 확인해 주세요'));
          return;
        }
      }
      if (!mounted) return; // 모델 확인 중에 화면을 넘겼다
      setState(() => _translateOn = true); // STATE: 번역 켬
    } finally {
      _toggling = false;
    }
    await _translatePage();
  }

  /// 지금 보이는 원문의 일본어 글을 모아 번역해서 바꿔 끼운다. 새로 부르면 하던 번역은 멈춘다 ([_trRun])
  Future<void> _translatePage() async {
    final web = _web;
    if (web == null || !mounted) return;
    _urlTr?.cancel();
    final run = ++_trRun;
    // 더 새 번역이 시작됐거나 · 껐거나 · 화면을 닫았다
    bool stale() => !mounted || run != _trRun || !_translateOn;
    // 글을 모으는 동안에도 버튼 대신 도는 표시 (그 사이 눌러 끄면 번역만 남아 돌았다)
    setState(() => _translateBusy = tr('번역 준비 중')); // STATE: 번역 시작
    try {
      // 원문이 멈춰 답하지 않으면 도는 표시가 남지 않게 15초까지만 (TimeoutException → 아래 알림)
      final raw = await web.runJavaScriptReturningResult(collectTextsJs).timeout(const Duration(seconds: 15));
      final texts = textsToTranslate(decodeTextList(raw));
      if (!mounted || stale()) return;
      if (texts.isEmpty) {
        showToast(context, tr('번역할 일본어 글이 없어요 (그림 안 글자는 못 바꿔요)'));
        return;
      }
      final map = await PageTranslator.instance.translate(
        texts,
        shouldStop: stale,
        onProgress: (done, total) {
          if (stale()) return;
          setState(() => _translateBusy = trf('번역 중 {done}/{total}', {'done': done, 'total': total})); // STATE: 번역 진행
        },
      );
      if (stale()) return;
      await web.runJavaScript(applyTranslationsJs(map));
    } on Exception {
      if (mounted && !stale()) showToast(context, tr('이 페이지는 번역하지 못했어요 · ↗ 브라우저에서 번역해 보세요'));
    } finally {
      // 이 차례가 마지막일 때만 — 옛 차례가 새 차례의 도는 표시를 지우지 않게
      if (mounted && run == _trRun) setState(() => _translateBusy = '');
    }
  }

  /// J-5 브라우저로
  Future<void> _openOutside() async {
    final u = _uri;
    if (u == null) {
      showToast(context, tr('원문 주소가 없는 예고예요'));
      return;
    }
    final ok = await launchUrl(u, mode: LaunchMode.externalApplication);
    if (!ok && mounted) showToast(context, tr('브라우저를 열지 못했어요'));
  }

  /// J-3 알림 받기 — 다음 단계(상품화 확정 · 예약 시작 · 발매)가 되면 휴대폰 알림
  void _toggleFollow(NotifyStore store) {
    final a = widget.item;
    if (a.status == announcementStages.last) {
      showToast(context, tr('이미 발매된 예고예요'));
      return;
    }
    final before = store.isFollowing(a.id);
    void set(bool on) => store.setFollow(a.id, on, stage: a.status, title: a.title, franchise: a.franchiseId);
    set(!before); // STATE: 알림 받기 → 버튼 채움 (notify_config.json)
    // 예약이 열리는 시각을 알고 30분 전 알림을 걸 수 있으면 그것을 말한다 (preorder_reminders.dart)
    final at = a.preorderAt;
    final remind =
        at != null &&
        store.config.enabled &&
        store.config.rule(preorderRule) &&
        at.subtract(liveLead).isAfter(appNow());
    showToast(
      context,
      before
          ? tr('이 예고 알림을 껐어요')
          : remind
          ? tr('예약 시작 30분쯤 전에 알려 드릴게요')
          : store.config.enabled
          ? tr('다음 단계가 되면 알려 드릴게요')
          : tr('다음 단계가 되면 알림함에 · 휴대폰 알림은 설정에서'),
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
                : _Summary(item: a, failed: _failed && _uri != null, intro: _intro), // J-2b P09
          ),
          _BottomBar(
            // J-3 · J-4 · J-5
            item: a,
            related: _related,
            onFollow: _toggleFollow,
            onAbout: () => _showAbout(context),
            onOutside: _openOutside,
            // J-5b 원문을 앱 안에서 보고 있을 때만
            onTranslate: web == null ? null : _toggleTranslate,
            translateOn: _translateOn,
            translateBusy: _translateBusy,
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
            padding: const EdgeInsets.symmetric(horizontal: Gp.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.title,
                  style: const TextStyle(fontSize: Gp.t16, fontWeight: FontWeight.w600, height: 1.4),
                ),
                const SizedBox(height: 6),
                Text(
                  joinDot([tr(channelOf(a.franchiseId).label), dateDot(annShownDay(a)), a.source]),
                  style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
                ),
                _PreorderLine(item: a),
                if (a.unofficial) const _UnofficialNote(),
                const SizedBox(height: 20),
                _StageLine(current: stage, unofficial: a.unofficial),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _IntroSlot(item: a, intro: _intro, sheet: true), // J-8
          FutureBuilder<List<Kit>>(
            future: _related,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const SizedBox(height: 120, child: LoadingView());
              }
              final kits = snap.data ?? const <Kit>[];
              if (kits.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    tr('이어진 상품 아직 없음 · 상품화되면 여기에'), // P09
                    style: const TextStyle(color: Gp.muted, fontSize: Gp.t12),
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(tr('이 예고의 상품'), subtitle: trf('{n}개', {'n': kits.length})), // P06
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
                  SectionHeader(tr('같은 IP의 새 상품'), subtitle: ip.label), // P06
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
      padding: const EdgeInsets.symmetric(horizontal: Gp.gutter),
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
            tooltip: tr('뒤로'),
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
                    AnnTag(item),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        joinDot([dateDot(annShownDay(item)), item.source]),
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
    this.onTranslate,
    this.translateOn = false,
    this.translateBusy = '',
  });
  final Announcement item;
  final Future<List<Kit>> related;
  final void Function(NotifyStore store) onFollow;
  final VoidCallback onAbout;
  final VoidCallback onOutside;
  final VoidCallback? onTranslate;
  final bool translateOn;
  final String translateBusy;

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
                  label: on ? tr('알림 받는 중') : tr('알림 받기'),
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
                      label: Text(n > 0 ? trf('이 예고 · 상품 {n}', {'n': n}) : tr('이 예고')),
                    );
                  },
                ),
              ),
              if (onTranslate != null)
                translateBusy.isNotEmpty
                    ? Tooltip(
                        message: translateBusy,
                        triggerMode: TooltipTriggerMode.tap,
                        child: const SizedBox(
                          width: 48,
                          height: 48,
                          child: Center(
                            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                        ),
                      )
                    : IconButton(
                        key: const ValueKey('translate'),
                        tooltip: translateOn ? tr('원문으로') : tr('한국어로 번역'),
                        onPressed: onTranslate,
                        icon: Icon(Icons.translate, size: Gp.iM, color: translateOn ? Gp.accent : Gp.muted),
                      ),
              IconButton(
                tooltip: tr('브라우저로 열기'),
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
  const _Summary({required this.item, required this.failed, required this.intro});
  final Announcement item;
  final bool failed;
  final Future<_Intro> intro;

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
                Text(
                  tr('앱 안에서 열 수 없는 페이지 · 아래 ↗ 로 브라우저에서'),
                  style: const TextStyle(fontSize: Gp.t12, color: Gp.danger),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                item.title,
                style: const TextStyle(fontSize: Gp.t19, fontWeight: FontWeight.w600, height: 1.35),
              ),
              const SizedBox(height: 6),
              Text(
                joinDot([tr(channelOf(item.franchiseId).label), dateDot(annShownDay(item)), item.source]),
                style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
              ),
              _PreorderLine(item: item),
              if (item.unofficial) const _UnofficialNote(),
              const SizedBox(height: 20),
              _StageLine(current: stage, unofficial: item.unofficial),
            ],
          ),
        ),
        _IntroSlot(item: item, intro: intro, sheet: false), // J-8
        const SizedBox(height: 24),
      ],
    );
  }
}

/// 비공식 소식 안내 한 줄 (요약 · 이 예고 시트) — 위 띠 꼬리표만으로는 왜 조심해서 봐야 하는지 알 수 없다
class _UnofficialNote extends StatelessWidget {
  const _UnofficialNote();

  @override
  Widget build(BuildContext context) => Padding(
    key: const ValueKey('unofficial-note'),
    padding: const EdgeInsets.only(top: 8),
    child: Text(
      tr('비공식 소식 · 공식 발표와 다를 수 있어요'),
      style: const TextStyle(fontSize: Gp.t12, color: unofficialColor),
    ),
  );
}

/// J-4 단계 진행 줄 — 지난 단계 · 지금(브랜드 색) · 남은 단계(회색)
class _StageLine extends StatelessWidget {
  const _StageLine({required this.current, this.unofficial = false});
  final int current;

  /// 비공식 소식: 첫 단계 이름이 「공식 발표」가 아니라 「비공식」 (꼬리표와 같은 말)
  final bool unofficial;

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
                  tr(i == 0 && unofficial ? unofficialLabel : label), // 단계 이름은 비교 값 — 보이는 곳에서만 번역
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

/// 예약 시작 · 마감 한 줄 (요약 · 이 예고 시트) — 「예약 시작 11.13 18:00 · 마감 11.20 23:59」, 예약 때를 모르면 없음
class _PreorderLine extends StatelessWidget {
  const _PreorderLine({required this.item});
  final Announcement item;

  @override
  Widget build(BuildContext context) {
    final now = appNow();
    final stage = annPreorderStage(item, now);
    if (stage == null) return const SizedBox.shrink();
    return Padding(
      key: const ValueKey('preorder-line'),
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        preorderLine(item, now),
        style: TextStyle(fontSize: Gp.t12, fontWeight: FontWeight.w600, color: preorderColor(stage)),
      ),
    );
  }
}

/// J-8 상품 소개 + 이 예고에 이어진 상품
typedef _Intro = ({AnnDetail? detail, Kit? kit});

/// J-8 자리 — 읽는 동안 · 상품 소개가 없으면 아무것도 (버튼도 빈 칸 글도 없다)
class _IntroSlot extends StatelessWidget {
  const _IntroSlot({required this.item, required this.intro, required this.sheet});
  final Announcement item;
  final Future<_Intro> intro;
  final bool sheet;

  @override
  Widget build(BuildContext context) => FutureBuilder<_Intro>(
    future: intro,
    builder: (context, snap) => switch (snap.data) {
      (detail: final d?, kit: final kit) when !item.unofficial => _ProductIntro(
        item: item,
        detail: d,
        kit: kit,
        sheet: sheet,
      ),
      _ => const SizedBox.shrink(),
    },
  );
}

/// J-8 상품 소개 — 버튼 하나(처음엔 접힘)를 누르면 그 자리에서 펼친다:
/// 사진 → 가격 · 예약 기간 · 발송 → 설명 → 사양 → 구성품 → 공식 상품 페이지.
/// 글은 공식 페이지의 일본어 그대로 (번역하지 않는다 — 길게 눌러 고를 수 있게 SelectionArea). 칸 이름만 화면 언어
class _ProductIntro extends StatefulWidget {
  const _ProductIntro({required this.item, required this.detail, required this.kit, required this.sheet});
  final Announcement item;
  final AnnDetail detail;

  /// 이 예고에 이어진 상품 — 상품 소개에 사진 · 가격이 없을 때 빌린다
  final Kit? kit;

  /// 이 예고 시트 안 (요약 화면은 위에 큰 사진이 이미 있어 예고 사진으로 채우지 않는다)
  final bool sheet;

  @override
  State<_ProductIntro> createState() => _ProductIntroState();
}

class _ProductIntroState extends State<_ProductIntro> {
  bool _open = false;

  Future<void> _openPage() async {
    final u = Uri.tryParse(widget.detail.pageUrl.isNotEmpty ? widget.detail.pageUrl : widget.item.url);
    final ok = u != null && u.hasScheme && await launchUrl(u, mode: LaunchMode.externalApplication);
    if (!ok && mounted) showToast(context, tr('브라우저를 열지 못했어요'));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gp.gutter),
          child: ExpandRow(
            key: const ValueKey('ann-detail-toggle'),
            title: tr('상품 소개'),
            summary: '',
            open: _open,
            onTap: () => setState(() => _open = !_open), // STATE: 상품 소개 펼침 · 접음
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: _open ? _body() : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  Widget _body() {
    final d = widget.detail;
    final a = widget.item;
    final kit = widget.kit;
    final images = d.gallery.isNotEmpty
        ? d.gallery
        : kit != null && kit.gallery.isNotEmpty
        ? kit.gallery
        : [if (kit != null && kit.image.isNotEmpty) kit.image else if (widget.sheet && a.image.isNotEmpty) a.image];
    final price = d.priceJpy ?? kit?.priceJpy;
    final period = preorderPeriod(a);
    final rows = [
      (tr('가격'), price != null ? yen(price) : d.priceText),
      // 시각은 예고 쪽에만 있다 (상품 페이지는 날짜만) — 있으면 그것, 없으면 페이지 글 그대로
      (tr('예약 기간'), period.isNotEmpty ? period : d.saleText),
      (
        tr(d.releaseKind == 'ship' ? '발송 예정' : '발매 예정'),
        d.releaseMonth.isNotEmpty ? dateDot(d.releaseMonth) : d.releaseText,
      ),
    ].where((r) => r.$2.isNotEmpty);
    const text = TextStyle(fontSize: Gp.t14, height: 1.6);
    return Column(
      key: const ValueKey('ann-detail-body'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (images.isNotEmpty)
          ImagePager(images: images, label: a.title, padding: const EdgeInsets.fromLTRB(16, 4, 16, 32)),
        SelectionArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gp.gutter, 8, Gp.gutter, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (label, value) in rows) _InfoRow(label: label, value: value),
                if (d.lead.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(d.lead, style: text.copyWith(fontWeight: FontWeight.w600)),
                ],
                for (final p in d.description) ...[const SizedBox(height: 10), Text(p, style: text)],
                if (d.spec.isNotEmpty) ...[
                  _IntroHeader(tr('사양')),
                  for (final (label, value) in d.spec) _InfoRow(label: label, value: value),
                ],
                if (d.contents.isNotEmpty) ...[
                  _IntroHeader(tr('구성품')),
                  for (final c in d.contents) Text('・$c', style: text),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Gp.gutter - 8, 8, Gp.gutter, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('ann-detail-page'),
              onPressed: _openPage,
              icon: const Icon(Icons.open_in_new, size: Gp.iS),
              label: Text(tr('공식 상품 페이지')),
            ),
          ),
        ),
      ],
    );
  }
}

/// 상품 소개 안 칸 제목 (사양 · 구성품)
class _IntroHeader extends StatelessWidget {
  const _IntroHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 6),
    child: Text(
      text,
      style: const TextStyle(fontSize: Gp.t14, fontWeight: FontWeight.w600),
    ),
  );
}

/// 이름 · 값 한 줄 — D-8 공식 정보 시트 아래 줄과 같은 모양 (이름 회색 · 값 본문)
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(fontSize: Gp.t12, color: Gp.muted, height: 1.7),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(value, style: const TextStyle(fontSize: Gp.t14, height: 1.5)),
        ),
      ],
    ),
  );
}
