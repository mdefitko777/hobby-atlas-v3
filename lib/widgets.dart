// 공용 화면 조각 — GET을 쓰는 화면은 모두 이 세 상태를 그린다 (AGENTS.md MUST).
//   LoadingView  불러오는 중          P01 시스템 상태의 가시성
//   ErrorView    오류 안내·다시 시도   P09 오류 인식·진단·복구
//   EmptyView    빈 목록 안내(+ 할 일) P01 · P09
// 그리고 여러 화면이 같은 모양으로 쓰는 조각 (P04 일관성):
//   GpSearchBar 검색창 · SectionHeader 색 막대 제목 · ProductTile 상품 카드 · PhotoThumb 둥근 사진 · MarkOverlay/QuickMarks (리본 = 구매함 · ♡ = 좋아요)
//   UnderlineTab 밑줄 탭 · PageDots 넘김 점 · ThumbRow 사진 줄 · TagPill 알약 글자 · TogglePill 켜고 끄는 버튼
//   AccentBar 진행 막대 · SectionPanel 흰 띠 섹션 · AccentRing 브랜드 색 고리(돌아가는 것 포함) · joinDot
//   AppImage · CircleThumb · RaisedCircleButton · ChannelGlyph · showSoon · showToast · navClearance · 가격 표기
import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'detail_pane.dart';
import 'marks.dart';
import 'models.dart';
import 'theme.dart';

export 'format.dart';

/// 로딩 상태
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label = '불러오는 중…'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MiniSpinner(),
            const SizedBox(height: 12),
            Text(label, style: const TextStyle(color: Gp.muted)),
          ],
        ),
      ),
    );
  }
}

/// 오류 상태: 무엇이 잘못됐는지 + 다시 시도 버튼
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, this.title = '정보를 불러오지 못했어요', this.message = '', required this.onRetry});

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 40, color: Gp.ink),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: Gp.t16, fontWeight: FontWeight.w700),
            ),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Gp.muted),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: Gp.iM),
              label: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 빈 상태: 왜 비었는지 + (있으면) 다음에 할 일 버튼
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    this.message = '표시할 항목이 없어요',
    this.detail = '',
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String message;
  final String detail;
  final IconData icon;

  /// 예: 필터 초기화 · 채널 추가 버튼
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: Gp.faint),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (detail.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Gp.muted),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 14), action!],
          ],
        ),
      ),
    );
  }
}

/// 상품·로고 이미지. 경로가 비었거나 못 읽으면 회색 칸 + 글자.
/// [grayscale] = 도감에서 아직 모으지 않은 칸 (불 꺼짐)
class AppImage extends StatelessWidget {
  const AppImage(this.path, {super.key, this.fit = BoxFit.cover, this.placeholder = '', this.grayscale = false});

  final String path;
  final BoxFit fit;
  final String placeholder;
  final bool grayscale;

  @override
  Widget build(BuildContext context) {
    Widget fallback(BuildContext _, Object _, StackTrace? _) => _Placeholder(placeholder);
    if (path.isEmpty) return _Placeholder(placeholder);
    // 인터넷 사진은 기기에 남겨 두고(비행기 모드에서도 본 것은 보인다), 실패하면 이름 글자 자리표시
    final Widget img = path.startsWith('http')
        ? CachedNetworkImage(
            imageUrl: path,
            fit: fit,
            fadeInDuration: const Duration(milliseconds: 150),
            placeholder: (_, _) => const ColoredBox(color: Gp.soft),
            errorWidget: (_, _, _) => _Placeholder(placeholder),
          )
        : Image.asset(path, fit: fit, errorBuilder: fallback);
    if (!grayscale) return img;
    return Opacity(
      opacity: 0.55,
      child: ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: img,
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Gp.soft,
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Gp.faint, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// 원 안에 사진(또는 첫 글자) — 채널 아이콘 · 아바타
class CircleThumb extends StatelessWidget {
  const CircleThumb({super.key, required this.image, required this.label, this.size = 40});

  final String image;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Gp.soft,
        border: Border.all(color: Gp.line),
      ),
      child: image.isEmpty
          ? Center(
              child: Text(
                label.characters.first,
                style: TextStyle(fontSize: size * 0.4, fontWeight: FontWeight.w800),
              ),
            )
          : AppImage(image),
    );
  }
}

/// 떠 있는 흰 원형 버튼 — 아바타 · 가운데 + 버튼
class RaisedCircleButton extends StatelessWidget {
  const RaisedCircleButton({
    super.key,
    required this.child,
    required this.onTap,
    required this.tooltip,
    this.size = 40,
  });

  final Widget child;
  final VoidCallback onTap;
  final String tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: Gp.raised(shape: BoxShape.circle),
            alignment: Alignment.center,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 채널 관리 아이콘: 짧은 선(왼쪽 위) · 긴 선(가운데) · 짧은 선(오른쪽 아래)
class ChannelGlyph extends StatelessWidget {
  const ChannelGlyph({super.key, this.size = 22, this.color = Gp.ink});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _ChannelGlyphPainter(color));
}

class _ChannelGlyphPainter extends CustomPainter {
  const _ChannelGlyphPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..strokeWidth = s.width * 0.085
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(Offset(s.width * 0.12, s.height * 0.26), Offset(s.width * 0.52, s.height * 0.26), p)
      ..drawLine(Offset(s.width * 0.12, s.height * 0.5), Offset(s.width * 0.88, s.height * 0.5), p)
      ..drawLine(Offset(s.width * 0.48, s.height * 0.74), Offset(s.width * 0.88, s.height * 0.74), p);
  }

  @override
  bool shouldRepaint(_ChannelGlyphPainter old) => old.color != color;
}

/// 검색창 — 홈과 검색 화면이 같은 것을 쓴다 (크기 · 글자 · 아이콘 통일, P04).
/// [onTap]을 주면 입력하지 않는 "입구"(홈): 누르면 검색 화면으로 간다.
/// 아니면 [controller]로 바로 입력하는 검색창(검색 화면).
class GpSearchBar extends StatelessWidget {
  const GpSearchBar({
    super.key,
    this.onCamera,
    this.hint = defaultHint,
    this.onTap,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
  });

  /// 오른쪽 카메라 → 찍어서 찾기 (하단 카메라 버튼과 같은 동작). 없으면 카메라를 숨긴다(친구 검색)
  final VoidCallback? onCamera;
  final String hint;
  final VoidCallback? onTap;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  static const defaultHint = '이름 · 번호 · 생김새로 찾기';
  static const _textStyle = TextStyle(fontSize: Gp.t14, color: Gp.ink);
  static const _hintStyle = TextStyle(fontSize: Gp.t14, color: Gp.faint);

  @override
  Widget build(BuildContext context) {
    final c = controller;
    // 홈 입구도 같은 TextField로 그린다(읽기 전용) — 안내 문구의 위치·간격이 두 화면에서 똑같게
    final Widget field = TextField(
      controller: c,
      focusNode: focusNode,
      readOnly: onTap != null,
      showCursor: onTap == null,
      enableInteractiveSelection: onTap == null,
      onTap: onTap,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
      style: _textStyle,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: _hintStyle,
        filled: false,
        isDense: true,
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
    );
    return Semantics(
      button: onTap != null,
      label: onTap != null ? '검색 열기' : null,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 48,
          padding: const EdgeInsets.only(left: 16, right: 4),
          decoration: Gp.raised(radius: Gp.radius),
          child: Row(
            children: [
              const Icon(Icons.search, size: Gp.iM, color: Gp.muted),
              const SizedBox(width: 10),
              Expanded(child: field),
              if (c != null && onTap == null)
                ValueListenableBuilder(
                  valueListenable: c,
                  builder: (context, v, _) => v.text.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          tooltip: '지우기', // P03
                          icon: const Icon(Icons.cancel, size: Gp.iM, color: Gp.faint),
                          onPressed: () {
                            c.clear();
                            onChanged?.call('');
                          },
                        ),
                ),
              if (onCamera != null)
                IconButton(
                  tooltip: '찍어서 찾기',
                  icon: const Icon(Icons.photo_camera_outlined, size: Gp.iM, color: Gp.ink),
                  onPressed: onCamera,
                )
              else
                const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// 아직 만들지 않은 화면으로 가는 자리 — 같은 안내 문구로 통일
void showSoon(BuildContext context, [String what = '상품 상세']) => showToast(context, '$what 화면은 다음 단계에서 만들어요');

/// 짧은 알림(토스트) — 흰 바탕 · 검정 글자, 2.5초 뒤 사라진다. [onUndo]가 있으면 "되돌리기" (P03)
void showToast(BuildContext context, String message, {VoidCallback? onUndo}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 2500),
        persist: false, // 되돌리기가 있어도 몇 초 뒤 저절로 사라지게
        action: onUndo == null ? null : SnackBarAction(label: '되돌리기', onPressed: onUndo),
      ),
    );
}

/// 목록 맨 아래 여백 — 하단 탭 바 · 카메라 버튼에 가려지지 않게
double navClearance(BuildContext context) => MediaQuery.paddingOf(context).bottom + 100;

/// 섹션 제목: 브랜드 색 세로 막대 + 제목 (+ 기간 같은 보조 글 · 오른쪽 버튼 · › 전체 보기)
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.subtitle = '',
    this.trailing,
    this.onMore,
    this.padding = const EdgeInsets.fromLTRB(16, 20, 12, 12),
  });

  final String title;

  /// 브랜드 색 작은 글자 (예: 최근 추가 기간)
  final String subtitle;
  final Widget? trailing;

  /// 주면 오른쪽에 › 가 붙고 줄 전체를 누를 수 있다
  final VoidCallback? onMore;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 20,
            margin: const EdgeInsets.only(top: 1, right: 10),
            decoration: BoxDecoration(
              color: Gp.accent, // 브랜드 포인트 색
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: Gp.t16, fontWeight: FontWeight.w600),
                ),
                if (subtitle.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      subtitle,
                      style: const TextStyle(fontSize: Gp.t12, color: Gp.accent, fontWeight: FontWeight.w500),
                    ),
                  ),
              ],
            ),
          ),
          ?trailing,
          if (onMore != null) const Icon(Icons.chevron_right, color: Gp.muted),
        ],
      ),
    );
    return onMore == null ? row : InkWell(onTap: onMore, child: row);
  }
}

/// 둥근 모서리 상품 사진 (회백색 바탕)
class PhotoThumb extends StatelessWidget {
  const PhotoThumb(this.image, {super.key, this.radius = 14});
  final String image;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: ColoredBox(color: Gp.soft, child: AppImage(image)),
    );
  }
}

/// 상품 카드: 사진(왼쪽 위 + 리본 · 왼쪽 아래 ♡) · 이름 · 보조 한 줄
/// 홈 가로 줄 · 검색 결과가 같이 쓴다. [imageWidth]가 있으면 고정 너비(가로 줄), 없으면 칸 너비.
class ProductTile extends StatelessWidget {
  const ProductTile({
    super.key,
    required this.image,
    required this.title,
    required this.onTap,
    this.subtitle = '',
    this.marks,
    this.id,
    this.imageWidth,
    this.imageAspect = 1,
    this.titleLines = 1,
  });

  final String image;
  final String title;
  final String subtitle;
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
      ],
    );
    return GestureDetector(
      onTap: onTap,
      child: imageWidth == null ? card : SizedBox(width: imageWidth, child: card),
    );
  }
}

/// 사진 위 표시 (모든 상품 사진 · 도감 칸 공통): 왼쪽 위 책갈피 리본 = 구매함(+ → ✓) · 왼쪽 아래 ♡ = 좋아요
/// 보이는 크기는 작아도 누르는 자리는 44dp 이상 (P09 접근성)
class MarkOverlay extends StatelessWidget {
  const MarkOverlay({
    super.key,
    required this.liked,
    required this.owned,
    required this.onLike,
    required this.onOwn,
    this.size = 28,
  });

  final bool liked;
  final bool owned;
  final VoidCallback onLike;
  final VoidCallback onOwn;
  final double size;

  @override
  Widget build(BuildContext context) {
    final inset = size * 0.22;
    return Stack(
      children: [
        Positioned(
          left: 0,
          top: 0,
          child: Semantics(
            button: true,
            selected: owned,
            label: '구매함',
            child: GestureDetector(
              onTap: onOwn,
              behavior: HitTestBehavior.opaque,
              child: Container(
                // 누르는 자리 44 × 52
                width: 44,
                height: 52,
                alignment: Alignment.topLeft,
                padding: EdgeInsets.only(left: inset + 2),
                child: ClipPath(
                  clipper: const _RibbonClipper(),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: size + 2,
                    height: size * 1.4,
                    alignment: const Alignment(0, -0.3),
                    color: owned ? Gp.own : Gp.scrim,
                    child: Icon(owned ? Icons.check : Icons.add, size: size * 0.7, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          bottom: 0,
          child: Semantics(
            button: true,
            selected: liked,
            label: '좋아요',
            child: GestureDetector(
              onTap: onLike,
              behavior: HitTestBehavior.opaque,
              child: Container(
                // 누르는 자리 44 × 44
                width: 44,
                height: 44,
                alignment: Alignment.bottomLeft,
                padding: EdgeInsets.only(left: inset, bottom: inset),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: size,
                  height: size,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: liked ? Gp.panel : Gp.scrimLight),
                  child: Icon(
                    liked ? Icons.favorite : Icons.favorite_border,
                    size: size * 0.6,
                    color: liked ? Gp.accent : Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 상품 카드용 MarkOverlay — 앱 전체 좋아요 · 구매함(Marks)을 보고 바꾼다 (토스트 + 되돌리기)
class QuickMarks extends StatelessWidget {
  const QuickMarks({super.key, required this.kit, this.size = 28});
  final Kit kit;
  final double size;

  @override
  Widget build(BuildContext context) {
    final m = Marks.of(context);
    return MarkOverlay(
      liked: m.liked(kit),
      owned: m.owned(kit),
      onLike: () => Marks.read(context).toggleLike(context, kit),
      onOwn: () => Marks.read(context).toggleOwn(context, kit),
      size: size,
    );
  }
}

/// 좋아요 표시 (♡, 파랑) — 글자 대신. 상세 · 필터 · My Page · 친구 소식 공통
class LikedIcon extends StatelessWidget {
  const LikedIcon({super.key, this.filled = true, this.size = Gp.iS, this.color = Gp.accent});
  final bool filled;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Icon(filled ? Icons.favorite : Icons.favorite_border, size: size, color: color);
}

/// 구매함 표시 (책갈피, 민트) — 상품 카드의 리본과 같은 뜻
class OwnedIcon extends StatelessWidget {
  const OwnedIcon({super.key, this.filled = true, this.size = Gp.iS, this.color = Gp.own});
  final bool filled;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Icon(filled ? Icons.bookmark : Icons.bookmark_border, size: size, color: color);
}

/// 책갈피 리본 모양 (아래 가운데가 파인 사각형)
class _RibbonClipper extends CustomClipper<Path> {
  const _RibbonClipper();

  @override
  Path getClip(Size s) => Path()
    ..moveTo(0, 0)
    ..lineTo(s.width, 0)
    ..lineTo(s.width, s.height)
    ..lineTo(s.width / 2, s.height - 8)
    ..lineTo(0, s.height)
    ..close();

  @override
  bool shouldReclip(_RibbonClipper old) => false;
}

/// 3점(내 사진 인증) 배지 — 도감 칸 · 게시물 · 숫자에 같이 쓴다
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.size = 22});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Gp.own, // 인증 = 가진 것 (민트)
        border: Border.all(color: Gp.panel, width: 1.5),
      ),
      child: Icon(Icons.workspace_premium, size: size * 0.66, color: Colors.white),
    );
  }
}

/// 하나 고르기 바텀 시트 — 제목 + 줄마다 이름, 고른 줄은 브랜드 색 글자 + ✓ (정렬 · 언어 공통)
Future<T?> showPickSheet<T>(
  BuildContext context, {
  required String title,
  required List<T> values,
  required T current,
  required String Function(T) label,
}) {
  return showModalBottomSheet<T>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(title, padding: const EdgeInsets.fromLTRB(20, 0, 20, 6)),
          for (final v in values)
            InkWell(
              onTap: () => Navigator.pop(sheet, v),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label(v),
                        style: TextStyle(
                          fontSize: Gp.t14,
                          color: v == current ? Gp.accent : Gp.ink,
                          fontWeight: v == current ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (v == current) const Icon(Icons.check, size: Gp.iM, color: Gp.accent),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// 작은 돌아가는 원 — 불러오기 · 확인 중 (LoadingView · 시트 · 대화 상자 공통)
class MiniSpinner extends StatelessWidget {
  const MiniSpinner({super.key, this.size = 22, this.color = Gp.ink});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CircularProgressIndicator(strokeWidth: size * 0.11, color: color),
  );
}

/// 색 고리 아바타 — 앱 셸 왼쪽 위(누르면 친구 서랍) · 서랍 머리 · 내 정보 머리
class RingAvatar extends StatelessWidget {
  const RingAvatar({
    super.key,
    required this.text,
    this.size = 56,
    this.ringWidth = 2.5,
    this.onTap,
    this.tooltip = '',
  });
  final String text;
  final double size;
  final double ringWidth;

  /// 주면 떠 있는 흰 버튼 얼굴 (앱 셸)
  final VoidCallback? onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text,
      style: TextStyle(fontSize: size * 0.4, fontWeight: FontWeight.w700, color: Gp.ink),
    );
    final face = onTap == null
        ? Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Gp.panel),
            child: label,
          )
        : Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Gp.bg),
            child: RaisedCircleButton(tooltip: tooltip, size: size, onTap: onTap!, child: label),
          );
    return AccentRing(width: ringWidth, child: face);
  }
}

/// 글자 + 브랜드 색 밑줄 탭 (채널 바 · 좋아요/구매함 · 사진/바코드)
class UnderlineTab extends StatelessWidget {
  const UnderlineTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
    this.fontSize = 15,
    this.padding = const EdgeInsets.symmetric(horizontal: 8),
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// 있으면 글자 뒤에 개수 (선택되면 브랜드 색)
  final int? count;
  final double fontSize;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: label),
                    if (count != null)
                      TextSpan(
                        text: ' $count',
                        style: TextStyle(color: selected ? Gp.accent : Gp.faint),
                      ),
                  ],
                ),
                style: TextStyle(
                  fontSize: fontSize,
                  letterSpacing: 0.2,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected ? Gp.ink : Gp.faint,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 2,
                width: selected ? 14 : 0,
                color: Gp.accent, // 브랜드 포인트 색
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 넘김 위치 점 — 지금 쪽은 브랜드 색 긴 막대
class PageDots extends StatelessWidget {
  const PageDots({super.key, required this.count, required this.index, this.center = true});
  final int count;
  final int index;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: center ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            width: i == index ? 16 : 5,
            height: 4,
            decoration: BoxDecoration(color: i == index ? Gp.accent : Gp.line, borderRadius: BorderRadius.circular(2)),
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
            SizedBox.square(
              dimension: size,
              child: PhotoThumb(image, radius: size > 60 ? 12 : 10),
            ),
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
                          child: TagPill(tag, strong: tagStrong),
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

/// 테두리 알약 글자 (한정 · PB · 예고 · 3/3). [strong] = 검정 테두리 · 굵게
class TagPill extends StatelessWidget {
  const TagPill(this.text, {super.key, this.strong = false, this.filled = false});
  final String text;
  final bool strong;

  /// 사진 위에 올릴 때 흰 반투명 바탕
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: filled ? Gp.glass : null,
        borderRadius: BorderRadius.circular(Gp.rSmall),
        border: Border.all(color: strong ? Gp.ink : Gp.line),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: Gp.t11,
          fontWeight: strong ? FontWeight.w600 : FontWeight.w500,
          color: strong ? Gp.ink : Gp.muted,
        ),
      ),
    );
  }
}

/// 켜고 끄는 버튼 (좋아요 · 구매함) — 켜지면 옅은 하늘색 바탕 + 브랜드 색 테두리·아이콘
class TogglePill extends StatelessWidget {
  const TogglePill({
    super.key,
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.active,
    required this.onTap,
    this.height = 44,
    this.color = Gp.accent,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool active;
  final VoidCallback onTap;
  final double height;

  /// 켜졌을 때 색 — 좋아요 · 알림 = 파랑, 구매함 · 인증 = 민트(Gp.own)
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: active ? color.withValues(alpha: 0.07) : Gp.panel,
            borderRadius: BorderRadius.circular(Gp.rSmall),
            border: Border.all(color: active ? color : Gp.line, width: active ? 1.3 : 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(active ? activeIcon : icon, size: Gp.iM, color: active ? color : Gp.ink),
              const SizedBox(width: 5),
              Flexible(
                // 좁은 화면에서는 말줄임
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: Gp.t14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 브랜드 색 진행 막대 (도감 수집 · 일치도)
class AccentBar extends StatelessWidget {
  const AccentBar({super.key, required this.value, this.height = 4, this.color = Gp.accent});
  final double value;
  final double height;

  /// 비교용 두 번째 막대는 Gp.faint
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1),
        minHeight: height,
        backgroundColor: Gp.soft,
        color: color,
      ),
    );
  }
}

/// 흰 띠 섹션 — 위에 회백색 틈 10을 두어 섹션마다 층이 보이게 (홈 · 상세)
class SectionPanel extends StatelessWidget {
  const SectionPanel({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(16, 18, 16, 18)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      // Material: 안의 ListTile · InkWell 누름 물결이 흰 바탕 위에 보이게
      child: Material(
        color: Gp.panel,
        child: SizedBox(
          width: double.infinity,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// 브랜드 색 고리 (하늘색 → 민트). 아바타 · 도감 "내 사진" 칸이 같이 쓴다.
/// [spin] = 천천히 돌아가는 고리 (내 사진으로 점등한 칸)
class AccentRing extends StatefulWidget {
  const AccentRing({super.key, required this.child, this.width = 2.5, this.radius, this.spin = false});

  final Widget child;
  final double width;

  /// null = 동그라미, 값이 있으면 둥근 사각형
  final double? radius;
  final bool spin;

  @override
  State<AccentRing> createState() => _AccentRingState();
}

class _AccentRingState extends State<AccentRing> with SingleTickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(vsync: this, duration: const Duration(seconds: 4));

  @override
  void initState() {
    super.initState();
    if (widget.spin) _turn.repeat();
  }

  @override
  void didUpdateWidget(AccentRing old) {
    super.didUpdateWidget(old);
    if (widget.spin && !_turn.isAnimating) _turn.repeat();
    if (!widget.spin) _turn.stop();
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final circle = widget.radius == null;
    return AnimatedBuilder(
      animation: _turn,
      builder: (context, child) => Container(
        padding: EdgeInsets.all(widget.width),
        decoration: BoxDecoration(
          shape: circle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: circle ? null : BorderRadius.circular(widget.radius!),
          gradient: SweepGradient(
            colors: const [Gp.accent, Gp.accent2, Gp.accent],
            transform: GradientRotation(_turn.value * 6.2832),
          ),
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// 보기 바꾸기 아이콘 두 개 (전체 ↔ 내 것) — 홈 검색창 옆 · 캘린더. 글자 없이 아이콘, 고른 쪽만 연한 파랑 칸
class ViewIconToggle extends StatelessWidget {
  const ViewIconToggle({
    super.key,
    required this.mine,
    required this.onChanged,
    this.allIcon = Icons.newspaper_outlined,
    this.allTip = '전체 소식',
    this.mineTip = 'My Page',
  });

  final bool mine;
  final ValueChanged<bool> onChanged;
  final IconData allIcon;
  final String allTip;
  final String mineTip;

  @override
  Widget build(BuildContext context) {
    Widget button(bool v, IconData icon, String tip) => Tooltip(
      message: tip,
      child: Material(
        color: v == mine ? Gp.accent.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(Gp.radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(Gp.radius),
          onTap: () => onChanged(v),
          child: SizedBox.square(
            dimension: 38,
            child: Icon(icon, size: Gp.iM, color: v == mine ? Gp.accent : Gp.faint),
          ),
        ),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [button(false, allIcon, allTip), const SizedBox(width: 2), button(true, Icons.person_outline, mineTip)],
    );
  }
}

/// 칸보다 작은 사진 — 남는 곳을 흰색 대신 같은 사진을 크게 · 흐리게 · 어둡게 깔고, 위에 사진 전체를 얹는다
/// (공식 예고 배너. 포켓몬 예고 이미지처럼 가장자리가 번져 보이게)
class BlurFitImage extends StatelessWidget {
  const BlurFitImage(this.path, {super.key, this.blur = 18, this.dim = 0.35});
  final String path;
  final double blur;

  /// 뒤 사진 어둡게 (0 = 그대로, 1 = 검정)
  final double dim;

  @override
  Widget build(BuildContext context) {
    if (path.isEmpty) return const AppImage('');
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRect(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur, tileMode: TileMode.clamp),
            child: Transform.scale(scale: 1.15, child: AppImage(path)), // cover
          ),
        ),
        ColoredBox(color: Colors.black.withValues(alpha: dim)),
        AppImage(path, fit: BoxFit.contain),
      ],
    );
  }
}

/// 날짜 꼬리표 하나 (빨강 = PB 예약 마감, 파랑 = 발매)
class DateTag extends StatelessWidget {
  const DateTag(this.text, {super.key, this.urgent = false});
  final String text;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final c = urgent ? Gp.danger : Gp.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(Gp.rSmall)),
      child: Text(
        text,
        style: TextStyle(fontSize: Gp.t11, fontWeight: FontWeight.w700, color: c),
      ),
    );
  }
}
