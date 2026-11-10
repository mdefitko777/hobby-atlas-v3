// 화면 X: 공식 조립 설명서 — BANDAI HOBBY 説明書(manual.bandai-hobby.net)의 보기 화면을 앱 안에서 그대로
//
// ┌──────── 디자인 가이드 대응표: X 조립 설명서 ───────────────────────────────────────┐
// │ 번호 │ Flutter 위젯명                     │ 비즈니스 명칭(한글)                    │ 원칙(P번호)   │
// │ X-1  │ 위 띠: 뒤로 · "조립 설명서" · 상품명   │ 어떤 상품의 설명서인지 (한 줄)           │ P01 · P03     │
// │ X-2  │ WebViewWidget (+ 읽는 중 가는 줄)     │ 공식 설명서 (넘기기 · 두 손가락 확대)    │ P02 · P10     │
// │ X-3  │ ErrorView + 브라우저로                │ 앱 안에서 못 열 때                      │ P09           │
// │ X-4  │ 아래 띠: 브라우저로 (↗)               │ Chrome 등에서 열기 · 내려받기           │ P10           │
// └──────────────────────────────────────────────────────────────────────────────────┘
// 전환: 상품 상세 D-17 「조립 설명서」에서 쌓기(push). 설명서는 반다이 사이트에 있는 그대로 — 앱은 주소만 안다.
import 'package:flutter/foundation.dart' show Factory;
import 'package:flutter/gestures.dart' show EagerGestureRecognizer, OneSequenceGestureRecognizer;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../detail_pane.dart';
import '../theme.dart';
import '../widgets.dart';
import 'j_announcement_screen.dart' show articleViewSupported;

const _manualBase = 'https://manual.bandai-hobby.net';

/// 설명서 보기 주소 (PDF.js 보기 화면 — 넘기기 · 확대가 된다)
Uri manualViewerUri(int id) => Uri.parse('$_manualBase/viewer.php?file=/pdf/$id.pdf');

/// 설명서 소개 페이지 (브라우저로 열 때 — 내려받기 · 의견 보내기가 있는 곳)
Uri manualPageUri(int id) => Uri.parse('$_manualBase/menus/detail/$id');

void openManual(BuildContext context, {required int id, required String kitName}) => openPage(
  context,
  ManualScreen(id: id, kitName: kitName),
  id: 'manual-$id',
);

class ManualScreen extends StatefulWidget {
  const ManualScreen({super.key, required this.id, required this.kitName});
  final int id;
  final String kitName;

  @override
  State<ManualScreen> createState() => _ManualScreenState();
}

class _ManualScreenState extends State<ManualScreen> {
  WebViewController? _web;

  /// 읽는 중 (0–1, 1 이면 줄을 숨긴다)
  double _progress = 0;

  /// 앱 안에서 못 열었다 → X-3
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if (articleViewSupported) {
      _web = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted) // PDF.js 보기 화면은 스크립트로 그린다
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (p) {
              if (mounted) setState(() => _progress = p / 100); // STATE: 읽는 중 → 가는 줄
            },
            onWebResourceError: (e) {
              if ((e.isForMainFrame ?? false) && mounted) setState(() => _failed = true); // STATE: 실패 → X-3
            },
          ),
        )
        ..loadRequest(manualViewerUri(widget.id));
    }
  }

  /// X-3 다시 시도
  void _retry() {
    setState(() {
      _failed = false; // STATE: 다시 시도 → 설명서
      _progress = 0;
    });
    _web?.loadRequest(manualViewerUri(widget.id));
  }

  /// X-4 브라우저로
  Future<void> _openOutside() async {
    final ok = await launchUrl(manualPageUri(widget.id), mode: LaunchMode.externalApplication);
    if (!ok && mounted) showToast(context, '브라우저를 열지 못했어요');
  }

  @override
  Widget build(BuildContext context) {
    final web = _failed ? null : _web;
    return Scaffold(
      backgroundColor: Gp.panel,
      body: Column(
        children: [
          // X-1
          SafeArea(
            bottom: false,
            child: SizedBox(
              height: 56,
              child: Row(
                children: [
                  IconButton(
                    tooltip: '뒤로',
                    icon: const Icon(Icons.arrow_back_ios_new, size: Gp.iM),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '조립 설명서',
                          style: TextStyle(fontSize: Gp.t16, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          widget.kitName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Gp.gutter),
                ],
              ),
            ),
          ),
          if (web != null)
            SizedBox(height: 2, child: _progress < 1 ? LinearProgressIndicator(value: _progress, minHeight: 2) : null)
          else
            const Divider(height: 1),
          Expanded(
            child: web != null
                ? WebViewWidget(
                    // X-2 손가락은 전부 설명서가 받는다 (넘기기 · 확대가 끊기지 않게)
                    controller: web,
                    gestureRecognizers: {Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new)},
                  )
                : ErrorView(
                    // X-3 P09
                    title: _web == null ? '이 기기에서는 앱 안에서 볼 수 없어요' : '설명서를 열지 못했어요',
                    message: '아래 「브라우저로」로 열 수 있어요',
                    onRetry: _web == null ? _openOutside : _retry,
                  ),
          ),
          // X-4
          DecoratedBox(
            decoration: const BoxDecoration(
              color: Gp.panel,
              border: Border(top: BorderSide(color: Gp.line)),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 52,
                child: Row(
                  children: [
                    const SizedBox(width: Gp.gutter),
                    const Expanded(
                      child: Text(
                        'BANDAI HOBBY 공식 설명서',
                        style: TextStyle(fontSize: Gp.t12, color: Gp.muted),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _openOutside,
                      icon: const Icon(Icons.north_east, size: Gp.iS),
                      label: const Text('브라우저로'),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
