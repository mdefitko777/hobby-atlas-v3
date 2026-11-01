// 그림 한 곳 — 인터넷(캐시) · 앱 안 그림 · 내 사진(`local:파일`) 경로를 여기서만 가른다
import 'dart:typed_data';
import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../data/photo_files.dart';
import '../theme.dart';

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
    if (path.startsWith(localPhotoPrefix)) return LocalPhotoImage(path.substring(localPhotoPrefix.length), fit: fit);
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

/// AppImage 경로 앞에 붙이면 내 사진 파일 (도감 칸 등 그림 경로 하나만 받는 곳)
const localPhotoPrefix = 'local:';

/// 내 사진 (기기 파일 — lib/data/photo_files.dart, 되찾은 사진은 처음 볼 때 서버에서 받는다). 못 읽으면 회색 칸, [fallback] 을 주면 파일이 없거나 깨졌을 때 그것
/// (아바타 · 배경 · 친구 아바타는 첫 글자)
class LocalPhotoImage extends StatefulWidget {
  const LocalPhotoImage(this.file, {super.key, this.fit = BoxFit.cover, this.fallback});
  final String file;
  final BoxFit fit;
  final Widget? fallback;

  @override
  State<LocalPhotoImage> createState() => _LocalPhotoImageState();
}

class _LocalPhotoImageState extends State<LocalPhotoImage> {
  late Future<ImageProvider?> _img = PhotoFiles.instance.providerOrFetch(widget.file);

  @override
  void didUpdateWidget(LocalPhotoImage old) {
    super.didUpdateWidget(old);
    if (old.file != widget.file) _img = PhotoFiles.instance.providerOrFetch(widget.file);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ImageProvider?>(
    future: _img,
    builder: (context, snap) => switch (snap.data) {
      final img? => Image(
        image: img,
        fit: widget.fit,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => widget.fallback ?? const _Placeholder(''),
      ),
      _ when widget.fallback != null && snap.connectionState == ConnectionState.done => widget.fallback!,
      _ => const ColoredBox(color: Gp.soft),
    },
  );
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

/// 메모리에 있는 사진 (찍은 · 공유로 받은 · 서버에서 받은 바이트). 못 풀면 회색 칸
class BytesImage extends StatelessWidget {
  const BytesImage(this.bytes, {super.key, this.fit = BoxFit.cover});
  final Uint8List bytes;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => Image.memory(
    bytes,
    fit: fit,
    gaplessPlayback: true,
    errorBuilder: (_, _, _) => const ColoredBox(color: Gp.soft),
  );
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

/// 둥근 모서리 상품 사진 (회백색 바탕)
class PhotoThumb extends StatelessWidget {
  const PhotoThumb(this.image, {super.key, this.radius = Gp.radius});
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
