// 도감(G) 공용 조각 — 찾기 + 도감 필터 · 작품 카드 · 진행 막대 · 칸 한 개
import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../widgets.dart';

/// G-9 찾기 글자 + 도감 필터
class GuideFind {
  GuideFind(this.query, [GuideFilterController? ctrl]) : ctrl = ctrl ?? GuideFilterController();
  final String query;
  final GuideFilterController ctrl;

  GuideFilter get filter => ctrl.filter;
  bool get active => query.isNotEmpty || filter.active;
  bool hitName(String text) => query.isEmpty || text.toLowerCase().contains(query.toLowerCase());

  /// 찾기 + 필터 + 정렬. [pool] 은 필터 시트가 셀 재료로 남긴다 (찾기 글자로 거른 뒤)
  List<T> apply<T>(
    List<T> items,
    String Function(T) text,
    GuideFacet Function(T) facet, {
    String groupLabel = '묶음',
    bool photo = false,
  }) {
    final found = [
      for (final x in items)
        if (hitName(text(x))) x,
    ];
    ctrl
      ..pool = [for (final x in found) facet(x)]
      ..groupLabel = groupLabel
      ..photoTier = photo;
    return filter.apply(found, facet);
  }
}

/// 찾기 · 필터에 맞는 것이 없을 때
const guideNoHit = EmptyView(icon: Icons.search_off, message: '이 조건의 칸이 없어요');

/// 진행 막대 + "n/전체"
class GuideProgress extends StatelessWidget {
  const GuideProgress({super.key, required this.owned, required this.total});
  final int owned;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AccentBar(value: total == 0 ? 0 : owned / total, color: Gp.own),
        ),
        const SizedBox(width: 8),
        Text(
          '$owned/$total',
          style: const TextStyle(fontSize: Gp.t11, color: Gp.muted),
        ),
      ],
    );
  }
}

/// 작품 · 세대 카드 (이미지 + 이름 + 진행)
class GuideWorkCard extends StatelessWidget {
  const GuideWorkCard({
    super.key,
    required this.image,
    required this.name,
    required this.owned,
    required this.total,
    required this.onTap,
    this.subtitle = '',
    this.fit = BoxFit.contain,
  });

  final String image;
  final String name;
  final String subtitle;
  final int owned;
  final int total;
  final VoidCallback onTap;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Gp.panel,
          borderRadius: BorderRadius.circular(Gp.radius),
          border: Border.all(color: Gp.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(fit == BoxFit.contain ? 10 : 0),
                child: AppImage(image, fit: fit, placeholder: name),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: Gp.t12, fontWeight: FontWeight.w600),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: Gp.t11, color: Gp.faint),
                    ),
                  const SizedBox(height: 6),
                  GuideProgress(owned: owned, total: total), // P01
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

int guideCols(double w, double min) => (w / min).floor().clamp(2, 6);

/// 도감 칸 한 개 (기체 · 베이) — TierCell + 오른쪽 위 꼬리표 · 인증 배지 · 리본 · ♡
class GuideCell extends StatelessWidget {
  const GuideCell({
    super.key,
    required this.image,
    required this.name,
    required this.tier,
    required this.onTap,
    this.photo,
    this.badge = '',
    this.liked = false,
    this.onLike,
    this.onOwn,
  });

  final String image;
  final String name;
  final CellTier tier;
  final VoidCallback onTap;

  /// 내가 올린 사진 (있으면 칸 그림 대신 보여 준다)
  final String? photo;
  final String badge;
  final bool liked;

  /// 주면 칸 위에 ♡ + 리본
  final VoidCallback? onLike;
  final VoidCallback? onOwn;

  @override
  Widget build(BuildContext context) => TierCell(
    image: image,
    tier: tier,
    photo: photo,
    onTap: onTap,
    overlays: [
      if (badge.isNotEmpty) Positioned(right: 5, top: 5, child: TagPill(badge, filled: true)),
      if (tier == CellTier.photo)
        const Positioned(right: 4, bottom: 4, child: VerifiedBadge()) // 3점 = 배지
      else if (onLike != null && onOwn != null)
        Positioned.fill(
          child: MarkOverlay(
            size: 22,
            liked: liked,
            owned: tier.index >= CellTier.owned.index,
            onLike: onLike!,
            onOwn: onOwn!,
          ),
        ),
    ],
    caption: SizedBox(
      height: 30,
      child: Text(
        name,
        maxLines: 2,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: Gp.t12, color: tier == CellTier.none ? Gp.muted : Gp.ink, height: 1.25),
      ),
    ),
  );
}
