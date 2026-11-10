// 화면 V: 처음 데이터 받기 — 처음 설치해 기기에 상품 데이터가 없을 때만 (main.dart 의 FirstRunGate).
// 두 번째부터는 기기 캐시로 바로 열고 뒤에서 새 데이터를 받는다 (lib/data/catalog.dart).
//
// ┌──────── 디자인 가이드 대응표: V 처음 데이터 받기 ──────────────────────────────────┐
// │ 번호 │ Flutter 위젯명                  │ 비즈니스 명칭(한글)                      │ 원칙(P번호)   │
// │ W-1  │ Image.asset(app_icon)           │ 앱 아이콘                                │ P04           │
// │ W-2  │ Text + AccentBar                │ 데이터 받는 중 · 받은 파일 n/m · MB       │ P01           │
// │ W-3  │ ErrorView                       │ 받지 못함 · 다시 시도                     │ P09 · P10     │
// └──────────────────────────────────────────────────────────────────────────────────┘
// 전환: 다 받으면 앱 셸로 바뀐다 (쌓지 않음 — 뒤로 가기로 돌아오지 않는다)
import 'package:flutter/material.dart';

import '../data/catalog.dart';
import '../l10n/l10n.dart';
import '../theme.dart';
import '../widgets.dart';

/// 처음 받는 동안은 [FirstRunScreen], 아니면 [builder] (앱 셸)
class FirstRunGate extends StatelessWidget {
  const FirstRunGate({super.key, required this.catalog, required this.builder});
  final Catalog catalog;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: catalog,
    builder: (context, _) => catalog.firstDownload ? FirstRunScreen(catalog: catalog) : builder(context),
  );
}

class FirstRunScreen extends StatelessWidget {
  const FirstRunScreen({super.key, required this.catalog});
  final Catalog catalog;

  /// 앱 아이콘 크기 (상세 빈 칸 그림과 같은 72)
  static const iconSize = 72.0;

  @override
  Widget build(BuildContext context) {
    final c = catalog;
    final failed = c.phase == CatalogPhase.error;
    final mb = (c.bytesReceived / (1024 * 1024)).toStringAsFixed(1);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: Gp.gutter * 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // W-1
                ClipRRect(
                  borderRadius: BorderRadius.circular(Gp.rLarge),
                  child: Image.asset('assets/app_icon.png', width: iconSize, height: iconSize),
                ),
                const SizedBox(height: 20),
                if (failed)
                  // W-3
                  ErrorView(title: tr('데이터를 받지 못했어요'), message: c.error, onRetry: c.retry)
                else ...[
                  // V-2
                  Text(
                    tr('데이터 받는 중'),
                    style: const TextStyle(fontSize: Gp.t16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: 220,
                    child: AccentBar(value: c.filesTotal == 0 ? 0 : c.filesDone / c.filesTotal, height: 6),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${c.filesDone} / ${c.filesTotal} · $mb MB',
                    style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
                  ),
                  if (c.progress.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      c.progress,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: Gp.t12, color: Gp.faint),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
