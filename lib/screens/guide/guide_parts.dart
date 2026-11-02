// 도감(G) 공용 조각 — 찾기 + 도감 필터 · 칸 한 개 (작품 · 세대 · 채널 고르기는 공용 CategoryTile · CategoryGrid)
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

/// 칸 격자 열 수 — 칸이 [min] 아래로 줄지 않게 (2–6열)
int guideCols(double w, double min) => (w / min).floor().clamp(2, 6);

/// 도감 칸 한 개 (기체 · 베이) — TierCell(늘 컬러) + 오른쪽 위 꼬리표 · 인증 배지 · 리본 · ♡
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

  /// 주면 칸 위에 누르는 ♡ + 리본 (MarkOverlay), 없으면 켜진 표시만 (StatusMarks)
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
        )
      else
        tierMarks(tier, liked: liked),
    ],
    caption: SizedBox(
      height: 30,
      child: Text(
        name,
        maxLines: 2,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: Gp.t12, color: Gp.ink, height: 1.25),
      ),
    ),
  );
}
