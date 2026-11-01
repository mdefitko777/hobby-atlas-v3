// 공유 카드 그림 — 내 컬렉션 요약 · 도감 작품 진행. RepaintBoundary 로 감싸 PNG 로 찍는다 (lib/screens/v_share_sheet.dart).
// 모든 카드 아래에 워터마크 "HA · @아이디". 글자보다 아이콘 (♡ · 리본 · 예약 · 미조립)
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;

import '../theme.dart';
import '../logic/build_status.dart' show BuildStage;
import 'icons.dart';
import 'kit_progress.dart' show buildStageIcon;
import 'images.dart';
import 'sections.dart';
import 'tier_cell.dart' show CellTier;

/// 공유 카드 너비 (논리 px) — 찍을 때 ×3 → 1080px
const shareCardWidth = 360.0;

/// 워터마크 글자: "HA · @아이디" (아이디가 없으면 "HA · Hobby Atlas")
String shareWatermark(String handle) => handle.isEmpty ? 'HA · Hobby Atlas' : 'HA · @$handle';

/// [key] 의 RepaintBoundary → PNG 바이트 (못 찍으면 null)
Future<Uint8List?> captureCard(GlobalKey key, {double pixelRatio = 3}) async {
  final box = key.currentContext?.findRenderObject();
  if (box is! RenderRepaintBoundary) return null;
  final img = await box.toImage(pixelRatio: pixelRatio);
  try {
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  } finally {
    img.dispose();
  }
}

/// 카드 틀 — 흰 면 · 큰 모서리 · 아래 워터마크
class ShareCardFrame extends StatelessWidget {
  const ShareCardFrame({super.key, required this.handle, required this.child});
  final String handle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: shareCardWidth,
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
    decoration: BoxDecoration(
      color: Gp.panel,
      borderRadius: BorderRadius.circular(Gp.rLarge),
      border: Border.all(color: Gp.line),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        child,
        const SizedBox(height: 14),
        Row(
          children: [
            Container(
              width: 14,
              height: 4,
              decoration: BoxDecoration(gradient: Gp.accentGradient, borderRadius: BorderRadius.circular(99)),
            ),
            const Spacer(),
            Text(
              shareWatermark(handle),
              key: const ValueKey('share-watermark'),
              style: const TextStyle(fontSize: Gp.t11, color: Gp.faint, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ],
    ),
  );
}

/// (a) 내 컬렉션 요약: 아바타 · 이름 · @아이디 · Lv / ♡ · 리본 · 예약 · 미조립 / 최근 산 것 박스 아트
class CollectionShareCard extends StatelessWidget {
  const CollectionShareCard({
    super.key,
    required this.avatar,
    required this.name,
    required this.handle,
    required this.liked,
    required this.owned,
    required this.preorders,
    required this.backlog,
    required this.thumbs,
    this.level,
  });

  final Widget avatar;
  final String name;
  final String handle;

  /// Lv 알약 (lib/level.dart LevelChip)
  final Widget? level;
  final int liked, owned, preorders, backlog;

  /// 박스 아트 (최근 산 것부터, 앞의 8개)
  final List<String> thumbs;

  static const maxThumbs = 8;

  @override
  Widget build(BuildContext context) {
    Widget stat(Widget icon, int n, String tip) => Expanded(
      child: Semantics(
        label: '$tip $n',
        child: Column(
          children: [
            SizedBox(height: 20, child: Center(child: icon)),
            const SizedBox(height: 3),
            Text(
              '$n',
              style: const TextStyle(fontSize: Gp.t16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
    final shown = thumbs.take(maxThumbs).toList();
    return ShareCardFrame(
      handle: handle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              avatar,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: Gp.t19, fontWeight: FontWeight.w800),
                    ),
                    if (handle.isNotEmpty)
                      Text(
                        '@$handle',
                        style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
                      ),
                  ],
                ),
              ),
              ?level,
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: Gp.bg, borderRadius: BorderRadius.circular(Gp.radius)),
            child: Row(
              children: [
                stat(const LikedIcon(size: Gp.iM), liked, '좋아요'),
                stat(const OwnedIcon(size: Gp.iM), owned, '구매함'),
                stat(const Icon(preorderIcon, size: Gp.iM, color: Gp.reserve), preorders, '예약'),
                stat(Icon(buildStageIcon(BuildStage.unbuilt), size: Gp.iM, color: Gp.muted), backlog, '미조립'),
              ],
            ),
          ),
          if (shown.isNotEmpty) ...[
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              children: [
                for (final img in shown)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(Gp.rSmall),
                    child: ColoredBox(
                      color: Gp.soft,
                      child: AppImage(img, fit: BoxFit.cover),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// (b) 도감 작품 진행: 작품 그림 · 이름 · 켜진 칸 / 전체 · 칸 격자 (단계 색)
class GuideShareCard extends StatelessWidget {
  const GuideShareCard({super.key, required this.image, required this.name, required this.handle, required this.tiers});

  final String image;
  final String name;
  final String handle;

  /// 기체 칸마다 단계 (도감 순서 그대로)
  final List<CellTier> tiers;

  int get lit => tiers.where((t) => t.index >= CellTier.owned.index).length;

  static Color cellColor(CellTier t) => switch (t) {
    CellTier.none => Gp.soft,
    CellTier.liked => Gp.accent.withValues(alpha: 0.35),
    CellTier.owned => Gp.own,
    CellTier.photo => Gp.accent2,
  };

  @override
  Widget build(BuildContext context) {
    final total = tiers.length;
    final pct = total == 0 ? 0 : (lit * 100 / total).round();
    // 칸이 많으면 작게 (한 장에 다 들어가게)
    final cell = total > 300 ? 7.0 : (total > 120 ? 10.0 : 14.0);
    return ShareCardFrame(
      handle: handle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(Gp.rSmall),
                child: SizedBox.square(
                  dimension: 48,
                  child: AppImage(image, fit: BoxFit.contain, placeholder: name),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: Gp.t16, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '$lit / $total',
                      key: const ValueKey('share-lit'),
                      style: const TextStyle(fontSize: Gp.t12, color: Gp.own, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Text(
                '$pct%',
                style: const TextStyle(fontSize: Gp.t24, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AccentBar(value: total == 0 ? 0 : lit / total, color: Gp.own),
          const SizedBox(height: 12),
          Wrap(
            spacing: 3,
            runSpacing: 3,
            children: [for (final t in tiers) Container(width: cell, height: cell, color: cellColor(t))],
          ),
        ],
      ),
    );
  }
}
