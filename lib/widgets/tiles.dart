// 상품 카드 · 목록 한 줄 — 홈 가로 줄 · 검색 결과 · 목록이 같이 쓴다. 상품 카드는 사진 + 이름(두 줄, 낱말 안에서 안 끊음)
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../detail_pane.dart';
import '../l10n/l10n.dart';
import '../logic/kit_rules.dart' show kitPriceParts;
import '../models.dart';
import '../theme.dart';
import 'images.dart';
import 'mark_overlay.dart';
import 'tags.dart';

/// 상품 카드: 사진(왼쪽 위 구매함 리본 + · 왼쪽 아래 ♡) · 이름 두 줄 · 보조 한 줄.
/// 홈 가로 줄 · 검색 결과가 같이 쓴다. [imageWidth]가 있으면 고정 너비(가로 줄), 없으면 칸 너비.
/// 구매함은 리본 + 를 누른다 — 길게 누르기로 옮겼다가 주인이 되돌림 (2026-11-20 「长按那个改回原来的加号」)
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
    this.titleLines = 2,
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

  /// 이름 줄 수 — 칸 높이가 모자라면(옛 높이의 가로 줄) 들어가는 만큼만
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
    final lineH = _titleLineHeight(context);
    Widget card(int lines, {required bool bounded}) {
      final name = KeepWordsText(
        title,
        maxLines: lines,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: Gp.t14, height: _titleHeight),
      );
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          photo,
          const SizedBox(height: _titleGap),
          // 높이가 정해진 칸에서는 어림이 조금 틀려도 넘치지 않게 (글자는 칸 끝에서 잘린다)
          if (bounded) Flexible(child: name) else name,
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: Gp.t12, color: Gp.muted),
            ),
          ],
          if (note.isNotEmpty)
            Text(
              note,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: Gp.t11, color: Gp.faint),
            ),
        ],
      );
    }

    final body = LayoutBuilder(
      builder: (context, box) {
        if (!box.hasBoundedHeight) return card(titleLines, bounded: false);
        // 다른 화면의 옛 높이 가로 줄(사진 + 한 줄)에 두 줄을 넣으면 둘째 줄이 반쯤 잘려 보인다 → 들어가는 줄만
        final scale = MediaQuery.textScalerOf(context);
        var rest = box.maxHeight - box.maxWidth / imageAspect - _titleGap;
        if (subtitle.isNotEmpty) rest -= 3 + scale.scale(Gp.t12) * 1.4;
        if (note.isNotEmpty) rest -= scale.scale(Gp.t11) * 1.4;
        return card((rest / lineH).floor().clamp(1, titleLines), bounded: true);
      },
    );
    return GestureDetector(
      onTap: onTap,
      child: imageWidth == null ? body : SizedBox(width: imageWidth, child: body),
    );
  }
}

/// 상품 카드 이름 글자 줄 높이 배수 · 사진과 이름 사이
const _titleHeight = 1.3;
const _titleGap = 8.0;

double _titleLineHeight(BuildContext context) => MediaQuery.textScalerOf(context).scale(Gp.t14) * _titleHeight;

/// 가로 줄에 놓는 상품 카드 높이 — 사진 + 이름 [titleLines] 줄 (글자 크기 설정을 따른다)
double productTileHeight(BuildContext context, double imageWidth, {double imageAspect = 1, int titleLines = 2}) =>
    imageWidth / imageAspect + _titleGap + titleLines * _titleLineHeight(context) + 2;

/// 한국어 낱말 안에서 줄이 바뀌지 않게 (Flutter 는 한글을 글자마다 끊는다 — '베이블레이 / 드 X').
/// 글자 사이에 단어 이음표(U+2060)를 넣어 띄어쓰기 · 붙임표(-) 뒤에서만 끊는다 ('Hi- / Resolution Model').
/// 한 낱말이 칸보다 길면 그때만 글자에서 — 분류 칸은 [fitCategoryName] 이 글자를 줄여 그것도 막는다
String keepWords(String s) =>
    s.split(' ').map((w) => w.split('-').map((p) => p.characters.join(_wordJoiner)).join('$_wordJoiner-')).join(' ');

/// 단어 이음표 U+2060 (보이지 않음)
final _wordJoiner = String.fromCharCode(0x2060);

/// 낱말 안에서 줄을 바꾸지 않는 글자 ([keepWords]). [data] 는 이음표 없는 원래 글 그대로 둔다 —
/// 읽어 주기 · 테스트의 find.text 가 상품 이름 그대로 맞게
class KeepWordsText extends Text {
  const KeepWordsText(super.data, {super.key, super.style, super.maxLines, super.overflow, super.textAlign});

  @override
  Widget build(BuildContext context) => Text(
    keepWords(data!),
    style: style,
    maxLines: maxLines,
    overflow: overflow,
    textAlign: textAlign,
    semanticsLabel: data,
  );
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
            style: TextStyle(fontSize: Gp.t11, color: Gp.faint),
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
    this.titleLead,
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

  /// 제목 첫 줄 앞 작은 표시 (예: 캘린더 점 — 상태는 알약 대신 부제 글자로). 여러 줄 제목이면 첫 줄에 맞춘다
  final Widget? titleLead;
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
                    crossAxisAlignment: titleLead == null ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                    children: [
                      // t14 첫 줄(약 20dp) 가운데 — 점(6dp) 기준
                      if (titleLead != null)
                        Padding(padding: const EdgeInsets.only(top: 7, right: 6), child: titleLead),
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
                      style: TextStyle(fontSize: Gp.t12, color: Gp.muted),
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

/// 분류 칸 (도감 · 검색의 종류 · 세대) — 정사각 그림 + 아래 굵은 이름(두 줄, 낱말 안에서 안 끊음). 숫자 · 진행 막대는 넣지 않는다.
/// 반다이 남코 Collectibles 의 브랜드 칸처럼 그림이 칸을 꽉 채운다 — 흰 안쪽 칸 · 테두리 없이 옅은 그림자만 (2026-11-20 주인):
///   공식 로고 = 그 브랜드 바탕색(atlas `bg`, 없으면 흰색) 위에 칸의 80% 안으로
///   키 비주얼 · 묶음 그림([style] logo false) = 칸 가득
///   로고가 없으면 가장 새 상품 사진([photo])을 칸 가득 — 2026-11-19 "사진 대신 종류 아이콘" 결정을 주인이 되돌렸다
///   사진도 없으면 바탕색(없으면 [color] = 채널 색) 위 흰(밝은 바탕이면 검정) 종류 아이콘 — 회색 칸은 없다
/// 칸 너비는 부모 격자가 정한다 — 폰에서 묶음 목록을 접으면 한 줄 4칸 · 펴면 3칸 ([SideGrid]).
class CategoryTile extends StatelessWidget {
  const CategoryTile({
    super.key,
    required this.image,
    required this.name,
    required this.onTap,
    this.style,
    this.photo = '',
    this.color,
    this.icon,
    this.nameLines = 2,
  });

  /// 공식 그림 (라인 로고 · 작품 로고 · atlas 표지) — '' = 없음
  final String image;
  final String name;
  final VoidCallback onTap;

  /// [image] 의 모양 · 바탕색 (atlas kind · bg · fg). 없으면 로고로 보고 흰 바탕
  final CoverStyle? style;

  /// 로고가 없을 때 칸을 채우는 사진 (그 칸의 가장 새 상품)
  final String photo;

  /// 로고도 사진도 없을 때 바탕 (보통 채널 색 [Gp.channelColor]) — [style] 에 바탕색이 있으면 그것
  final Color? color;

  /// 그림이 없거나 열리지 않을 때 가운데 아이콘 (종류 아이콘 · MEZASTAR · Frienda)
  final IconData? icon;

  /// 이름 줄 수
  final int nameLines;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: name,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Gp.radius),
      child: LayoutBuilder(
        builder: (context, box) {
          final side = box.maxWidth;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(Gp.radius), boxShadow: Gp.tileShadow),
                  child: ClipRRect(borderRadius: BorderRadius.circular(Gp.radius), child: _art(side)),
                ),
              ),
              const SizedBox(height: categoryNameGap),
              // 높이가 정해진 칸에서 어림이 조금 틀려도 넘치지 않게 (글자는 칸 끝에서 잘린다)
              Flexible(
                child: KeepWordsText(
                  name,
                  maxLines: nameLines,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: fitCategoryName(context, name, side),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );

  Color? get _styleBg => switch (style?.bg) {
    final int c => Color(c),
    _ => null,
  };

  /// 바탕 위 아이콘 색 — atlas 바탕이면 그 fg, 아니면 밝기로 (밝은 바탕 = 검정 · 짙은 바탕 = 흰색)
  Color _iconOn(Color bg) {
    if (style case CoverStyle(bg: final int c, :final lightFg) when c == bg.toARGB32()) {
      return lightFg ? Colors.white : Gp.ink;
    }
    return bg.computeLuminance() > 0.45 ? Gp.ink : Colors.white;
  }

  Widget _art(double side) {
    final iconSize = (side * 0.42).clamp(Gp.iL, Gp.iXL).toDouble();
    Widget glyph(Color bg) => Icon(icon ?? Icons.category_outlined, size: iconSize, color: _iconOn(bg));
    final base = _styleBg ?? color ?? Gp.tilePalette.first;
    final plain = ColoredBox(
      color: base,
      child: Center(child: glyph(base)),
    );
    // 사진 · 그림은 받는 동안에도 회색 대신 바탕색 (fallback 이 있으면 AppImage 는 빈 칸으로 기다린다)
    Widget fill(String path, Widget fallback, {bool next = false}) => Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: base),
        AppImage(path, nextOnError: next, fallback: fallback),
      ],
    );
    final photoOrPlain = photo.isEmpty ? plain : fill(photo, plain, next: true);
    if (image.isEmpty) return photoOrPlain;
    if (!(style?.logo ?? true)) return fill(image, photoOrPlain);
    final logoBg = _styleBg ?? Gp.panel;
    return ColoredBox(
      color: logoBg,
      child: Center(
        child: FractionallySizedBox(
          widthFactor: 0.8,
          heightFactor: 0.8,
          // 로고가 404 · 오프라인으로 안 열려도 회색 칸 대신 같은 바탕 위 아이콘
          child: AppImage(
            image,
            fit: BoxFit.contain,
            fallback: Center(child: glyph(logoBg)),
          ),
        ),
      ),
    );
  }
}

/// 분류 칸 그림과 이름 사이
const categoryNameGap = 4.0;

/// 분류 칸 이름 — 굵게. 칸이 74dp 이상(360dp 폰에서 접어 4칸 · 큰 폰)이면 t14, 그보다 좁으면(펴서 3칸 약 69dp) t12:
/// 69dp 칸에 t14 굵은 한글은 한 줄 네 자라 '넨도로이드' · '이치방쿠지' 가 낱말 안에서 끊겼다
TextStyle categoryNameStyle(double cellW) =>
    TextStyle(fontSize: cellW >= 74 ? Gp.t14 : Gp.t12, fontWeight: FontWeight.w700, height: 1.25);

/// [categoryNameStyle] 인데, 가장 긴 낱말 하나가 칸보다 넓으면 그 낱말이 한 줄에 들 때까지 글자를 줄인다 (10 까지 — t11 로는 'Hi-Resolution' 이 80dp 칸에 1px 모자랐다).
/// 'Hi-Resolution Model' 이 'Hi-Resolutio / n Model' · 'Hi- / Resolution …' 으로 끊기던 것 → 'Hi-Resolution / Model'
const _nameFloor = 10.0;

TextStyle fitCategoryName(BuildContext context, String name, double cellW) {
  final style = categoryNameStyle(cellW);
  // 붙임표 낱말도 통째로 ('Hi-Resolution') — 'Hi-' 혼자 한 줄이 되지 않게. 그래도 넘치면 붙임표 뒤에서 끊긴다
  final words = name.split(' ').where((w) => w.isNotEmpty);
  var widest = 0.0;
  for (final w in words) {
    final p = TextPainter(
      // 그려지는 글과 똑같이 (이음표 포함 — 웹은 이음표가 폭을 조금 먹는다)
      text: TextSpan(text: keepWords(w), style: DefaultTextStyle.of(context).style.merge(style)),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    widest = math.max(widest, p.width);
    p.dispose();
  }
  final room = cellW - 2; // 반올림 · 글꼴 차이 여유
  if (widest <= room) return style;
  final size = math.max(_nameFloor, (style.fontSize! * room / widest * 10).floorToDouble() / 10);
  return style.copyWith(fontSize: size);
}

/// 분류 칸 이름 두 줄 + 틈 높이 — 기기 글자 크기(큰 글씨 1.15 · 1.3)를 따른다.
/// 고정 42 였을 때 1.15 에서 둘째 줄이 4px 넘쳐 잘렸다 (2026-11-19 리뷰). 기본 크기에서는 전과 같은 42
double categoryNameExtent(BuildContext context, double cellW) {
  final p = TextPainter(
    text: TextSpan(text: '가\n가', style: DefaultTextStyle.of(context).style.merge(categoryNameStyle(cellW))),
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  final h = p.height;
  p.dispose();
  return math.max(42, categoryNameGap + h + 2);
}

/// 분류 칸 한 줄 수 — 칸 최소 80dp (폰 360 · 390dp = 4칸, 작은 폰 320dp = 3칸). 88 이던 때는 360dp 폰이 3칸이었다
int categoryCols(double width) => (width / 80).floor().clamp(3, 8);

/// 분류 칸 격자 사이 (가로 · 세로)
const categoryGridGap = 10.0;

/// 분류 칸 격자 — 목록 안에 넣는 [CategoryTile] 묶음 (폭에 맞춰 [categoryCols] 칸, 안에서 스크롤하지 않음).
/// 칸 높이 = 정사각 그림 + 이름 두 줄 ([categoryNameExtent] — 묶음 목록 격자 SideGrid 와 같은 크기)
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
      builder: (context, box) {
        final cols = categoryCols(box.maxWidth);
        final cellW = (box.maxWidth - categoryGridGap * (cols - 1)) / cols;
        return GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: categoryGridGap,
            crossAxisSpacing: categoryGridGap,
            mainAxisExtent: cellW + categoryNameExtent(context, cellW),
          ),
          children: children,
        );
      },
    ),
  );
}
