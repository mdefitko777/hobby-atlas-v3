// 도감(G) 공용 조각 — 찾기 + 도감 필터 · 묶음 목록 펴 둠 · 칸 한 개(♡ · 길게 = 구매함) (작품 · 세대 · 채널 고르기는 공용 CategoryTile)
// 틀(왼쪽 묶음 목록 + 오른쪽 칸 격자)은 검색 탭 종류 · 세대와 같은 lib/widgets/side_directory.dart
import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../marks.dart';
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
    String? groupLabel,
    bool photo = false,
  }) {
    final found = [
      for (final x in items)
        if (hitName(text(x))) x,
    ];
    ctrl
      ..pool = [for (final x in found) facet(x)]
      ..groupLabel = groupLabel ?? tr('묶음')
      ..photoTier = photo;
    return filter.apply(found, facet);
  }
}

/// 찾기 · 필터에 맞는 것이 없을 때
Widget get guideNoHit => EmptyView(icon: Icons.search_off, message: tr('이 조건의 칸이 없어요'));

/// 도감 묶음 목록을 펴 둠 — 검색 탭(browse_dir_open)과 따로 기기에 기억한다 (local_state guide_dir_open, 2026-11-20 주인)
bool guideDirOpen(BuildContext context) => Marks.maybeRead(context)?.store.guideDirOpen ?? true;

void setGuideDirOpen(BuildContext context, bool open) => Marks.maybeRead(context)?.store.setGuideDirOpen(open);

/// 도감 묶음 목록 열쇠 (화면 테스트 — 검색 탭 browse-dir · dir-handle 과 따로)
const guideDirKey = ValueKey('guide-dir');
const guideDirHandleKey = ValueKey('guide-dir-handle');

/// 묶음 목록 읽는 법 한 줄 (검색 탭 종류 · 세대 ? 와 같은 말)
HelpItem get guideDirHelp => HelpItem(Icons.menu_open, tr('왼쪽 묶음을 누르면 그 묶음의 칸만 · 밀어서 펴고 접기'));

/// 도감 칸 한 개 (기체 · 베이) — TierCell(늘 컬러) + 인증 배지 · 리본 · ♡. 숫자 꼬리표는 두지 않는다 (2026-11-20 주인).
/// 그림 위에는 ♡ 만 — 구매함은 상품 카드(ProductTile)처럼 칸을 길게 눌러 넣고 뺀다 (진동 + 토스트 · 되돌리기, 2026-11-20 주인:
/// 왼쪽 위 리본 + 를 뺐다). 구매함이면 민트 테두리 + 리본 ✓ 는 그대로.
/// 도감 격자에서는 분류 칸(CategoryTile)과 같은 크기: 정사각 그림([square] false 면 [SideGrid] 칸 높이) + 이름 두 줄([captionHeight])
class GuideCell extends StatelessWidget {
  const GuideCell({
    super.key,
    required this.image,
    required this.name,
    required this.tier,
    required this.onTap,
    this.photo,
    this.liked = false,
    this.onLike,
    this.onOwn,
    this.square = true,
    this.captionHeight = 30,
  });

  final String image;
  final String name;
  final CellTier tier;
  final VoidCallback onTap;

  /// 내가 올린 사진 (있으면 칸 그림 대신 보여 준다)
  final String? photo;
  final bool liked;

  /// 주면 칸 위에 누르는 ♡ (MarkOverlay), 없으면 켜진 표시만 (StatusMarks)
  final VoidCallback? onLike;

  /// 길게 누르기 = 구매함 넣기 · 빼기 (토스트 · 되돌리기는 부르는 쪽 — Marks.toggleOwn · 손으로 켜기)
  final VoidCallback? onOwn;

  /// true = 정사각 그림 (혼자 쓰는 칸), false = 격자 칸 높이를 다 쓴다 ([SideGrid] 가 정사각으로 맞춘다)
  final bool square;

  /// 이름 두 줄 자리 — 칸마다 같아야 그림 높이가 같다 ([SideGrid.nameExtent] − 틈)
  final double captionHeight;

  @override
  Widget build(BuildContext context) => TierCell(
    image: image,
    tier: tier,
    photo: photo,
    onTap: onTap,
    onLongPress: onOwn == null
        ? null
        : () {
            Feedback.forLongPress(context);
            onOwn!();
          },
    square: square,
    gap: 4,
    overlays: [
      if (tier == CellTier.photo)
        const Positioned(right: 4, bottom: 4, child: VerifiedBadge()) // 3점 = 배지
      else if (onLike != null)
        Positioned.fill(
          child: MarkOverlay(size: 22, liked: liked, owned: tier.index >= CellTier.owned.index, onLike: onLike!),
        )
      else
        tierMarks(tier, liked: liked),
    ],
    caption: SizedBox(
      height: captionHeight,
      child: Text(
        name,
        maxLines: 2,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: Gp.t12, color: Gp.ink),
      ),
    ),
  );
}
