// 상품 카드 · 목록 한 줄 — 홈 가로 줄 · 검색 결과 · 목록이 같이 쓴다
import 'package:flutter/material.dart';

import '../detail_pane.dart';
import '../l10n/l10n.dart';
import '../logic/kit_rules.dart' show kitPriceParts;
import '../models.dart';
import '../theme.dart';
import 'images.dart';
import 'tags.dart';

/// 상품 카드: 사진(왼쪽 위 + 리본 · 왼쪽 아래 ♡) · 이름 · 보조 한 줄
/// 홈 가로 줄 · 검색 결과가 같이 쓴다. [imageWidth]가 있으면 고정 너비(가로 줄), 없으면 칸 너비.
class ProductTile extends StatelessWidget {
  const ProductTile({
    super.key,
    required this.image,
    required this.title,
    required this.onTap,
    this.subtitle = '',
    this.note = '',
    this.marks,
    this.id,
    this.imageWidth,
    this.imageAspect = 1,
    this.titleLines = 1,
  });

  final String image;
  final String title;
  final String subtitle;

  /// 보조 줄 아래 작은 한 줄 (한국 · 일본 정가가 다 있는 상품의 둘째 정가) — 칸 높이를 그만큼 더 줘야 한다
  final String note;
  final VoidCallback onTap;

  /// 주면 사진 위에 겹친다 — 보통 [QuickMarks] (리본 + · ♡)
  final Widget? marks;

  /// 반반 화면에서 이 카드가 오른쪽 칸에 열려 있으면 사진에 파란 테두리
  final String? id;
  final double? imageWidth;

  /// 가로 / 세로 (1 = 정사각형, 공식 예고 배너는 16:9 쯤)
  final double imageAspect;
  final int titleLines;

  @override
  Widget build(BuildContext context) {
    final photo = AspectRatio(
      aspectRatio: imageAspect,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PhotoThumb(image),
          if (marks != null) Positioned.fill(child: marks!),
          if (id != null)
            Positioned.fill(
              child: IgnorePointer(
                child: Builder(
                  builder: (context) => isPaneSelected(context, id)
                      ? DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(Gp.radius),
                            border: Border.all(color: Gp.accent, width: 2.5),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
        ],
      ),
    );
    final card = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        photo,
        const SizedBox(height: 8),
        Text(
          title,
          maxLines: titleLines,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: Gp.t14, height: 1.3),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
          ),
        ],
        if (note.isNotEmpty)
          Text(
            note,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: Gp.t11, color: Gp.faint),
          ),
      ],
    );
    return GestureDetector(
      onTap: onTap,
      child: imageWidth == null ? card : SizedBox(width: imageWidth, child: card),
    );
  }
}

/// 목록 줄 오른쪽 정가 — 그 나라 돈 그대로(₩ · ¥). 한국 · 일본 정가가 다 있으면 둘째 정가는 아래 작은 줄로
/// (한 줄 "₩19,000 · ¥1,650" 은 360dp 폰에서 제목 칸을 밀어냈다)
class KitPriceLines extends StatelessWidget {
  const KitPriceLines(this.kit, {super.key, this.style = const TextStyle(fontSize: Gp.t12)});
  final Kit kit;

  /// 첫 정가 글자 모양 (둘째 정가는 작고 옅게)
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final parts = kitPriceParts(kit);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(parts.firstOrNull ?? tr('가격 미정'), style: style),
        for (final p in parts.skip(1))
          Text(
            p,
            style: const TextStyle(fontSize: Gp.t11, color: Gp.faint),
          ),
      ],
    );
  }
}

/// 목록 한 줄: (앞 위젯) 사진 · 제목(+앞 태그) · 보조 줄 · 오른쪽
class ThumbRow extends StatelessWidget {
  const ThumbRow({
    super.key,
    required this.image,
    required this.title,
    required this.onTap,
    this.subtitle = '',
    this.trailing,
    this.leading,
    this.tag = '',
    this.tagStrong = false,
    this.tagColor,
    this.size = 56,
    this.titleLines = 1,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
    this.id,
  });

  /// 반반 화면에서 이 줄이 오른쪽 칸에 열려 있으면 옅은 파랑 바탕
  final String? id;

  final String image;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  /// 사진 앞 (예: 편집 모드 체크)
  final Widget? leading;

  /// 제목 앞 작은 알약 (예: 발매 · 공식 발표)
  final String tag;

  /// 알약을 검정 테두리로 (확정된 것: 발매)
  final bool tagStrong;

  /// 뜻이 색으로 정해진 꼬리표 (예약 = Gp.reserve · 재판매 = Gp.resale) → SoftTag. 상세 · 캘린더 · 컬렉션이 같은 모양
  final Color? tagColor;
  final double size;
  final int titleLines;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    if (id == null) return _row(context);
    return Builder(
      builder: (context) => ColoredBox(
        color: isPaneSelected(context, id) ? Gp.accent.withValues(alpha: 0.08) : Colors.transparent,
        child: _row(context),
      ),
    );
  }

  Widget _row(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            if (leading != null) Padding(padding: const EdgeInsets.only(right: 8), child: leading),
            SizedBox.square(dimension: size, child: PhotoThumb(image)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (tag.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: tagColor == null ? TagPill(tag, strong: tagStrong) : SoftTag(tag, color: tagColor!),
                        ),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: titleLines,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: Gp.t14, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}

/// 분류 칸 (도감 · 검색의 종류 · 세대) — 공식 그림(라인 로고 · 작품 로고)과 이름만. 숫자 · 진행 막대는 넣지 않는다.
/// 칸 너비는 부모 격자가 정한다 ([categoryCols] — 폰에서 한 줄 4칸).
class CategoryTile extends StatelessWidget {
  const CategoryTile({super.key, required this.image, required this.name, required this.onTap, this.icon});
  final String image;
  final String name;
  final VoidCallback onTap;

  /// 공식 그림이 아직 없을 때 그림 자리 (예: MEZASTAR · Frienda) — 없으면 이름 글자 자리표시
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: name,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Gp.radius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1.25,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Gp.panel,
                borderRadius: BorderRadius.circular(Gp.radius),
                border: Border.all(color: Gp.line),
              ),
              child: image.isEmpty && icon != null
                  ? Icon(icon, size: Gp.iXL, color: Gp.accent)
                  : AppImage(image, fit: BoxFit.contain, placeholder: name),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: Gp.t12),
          ),
        ],
      ),
    ),
  );
}

/// 분류 칸 한 줄 수 — 칸이 80dp 아래로 줄지 않게 (폰 390dp = 4칸, 작은 폰 320dp = 3칸)
int categoryCols(double width) => (width / 88).floor().clamp(3, 8);

/// 분류 칸 격자 사이 (가로 · 세로)
const categoryGridGap = 10.0;

/// 분류 칸 한 칸 높이 비율 (그림 1.25 : 1 + 이름 한 줄)
const categoryTileAspect = 0.78;

/// 분류 칸 격자 — 목록 안에 넣는 [CategoryTile] 묶음 (폭에 맞춰 [categoryCols] 칸, 안에서 스크롤하지 않음)
class CategoryGrid extends StatelessWidget {
  const CategoryGrid({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.symmetric(horizontal: Gp.gutter),
  });
  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: LayoutBuilder(
      builder: (context, box) => GridView.count(
        crossAxisCount: categoryCols(box.maxWidth),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        mainAxisSpacing: categoryGridGap,
        crossAxisSpacing: categoryGridGap,
        childAspectRatio: categoryTileAspect,
        children: children,
      ),
    ),
  );
}
