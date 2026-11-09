// 그림 한 곳 — 인터넷(캐시) · 앱 안 그림 · 내 사진(`local:파일`) 경로를 여기서만 가른다
import 'dart:async' show scheduleMicrotask;
import 'dart:typed_data';
import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../data/photo_files.dart';
import '../theme.dart';

/// 상품·로고 이미지. 경로가 비었거나 못 읽으면 회색 칸 + 글자.
/// [grayscale] = 흑백 (베이 조합 만들기의 안 가진 부품만 — 도감 칸은 늘 컬러)
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
            errorWidget: (_, _, _) {
              BrokenImages.mark(path);
              return _Placeholder(placeholder);
            },
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

/// 열리지 않은 인터넷 사진 — 공식 사이트에서 지워졌거나, 번호만 짐작해 만든 주소(반다이 상품 사진 _1 … _10)라 없는 것.
/// 상세 사진 넘기기 · 크게 보기에서 그 장을 뺀다. 앱을 켜 둔 동안만 기억 (다음에 켜면 다시 한 번 시도)
abstract final class BrokenImages {
  static final _urls = <String>{};

  /// 새로 열리지 않은 사진이 생길 때마다 +1
  static final changes = ValueNotifier<int>(0);

  static bool has(String url) => _urls.contains(url);

  static void mark(String url) {
    if (!_urls.add(url)) return;
    // 그리는 도중(errorWidget)에 불리므로, 지금 그리기가 끝난 뒤 알린다
    scheduleMicrotask(() => changes.value++);
  }

  /// 열리는 사진만 — 다 안 열리면 첫 장은 남겨 이름 자리표시가 보이게
  static List<String> keep(List<String> images) {
    final ok = [
      for (final u in images)
        if (!_urls.contains(u)) u,
    ];
    return ok.isEmpty && images.isNotEmpty ? [images.first] : ok;
  }

  @visibleForTesting
  static void reset() => _urls.clear();
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

/// 공식 그림 크게 보기 — 검은 바탕 전체 화면, 두 손가락으로 확대, 여러 장이면 옆으로 넘기기 (태그 앞 · 뒤, 상품 사진)
Future<void> openImageViewer(BuildContext context, List<String> images, {int index = 0, String label = ''}) {
  final list = [
    for (final s in images)
      if (s.isNotEmpty) s,
  ];
  if (list.isEmpty) return Future.value();
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => ImageViewerScreen(images: list, index: index.clamp(0, list.length - 1), label: label),
    ),
  );
}

class ImageViewerScreen extends StatefulWidget {
  const ImageViewerScreen({super.key, required this.images, this.index = 0, this.label = ''});
  final List<String> images;
  final int index;
  final String label;

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  late int _page = widget.index;
  late final _pages = PageController(initialPage: widget.index);

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    // 열리지 않은 사진은 빠진다
    valueListenable: BrokenImages.changes,
    builder: (context, _, _) {
      final images = BrokenImages.keep(widget.images);
      final many = images.length > 1;
      final page = _page.clamp(0, images.isEmpty ? 0 : images.length - 1);
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: many ? Text('${page + 1} / ${images.length}', style: const TextStyle(fontSize: Gp.t14)) : null,
        ),
        body: PageView.builder(
          key: const ValueKey('image-viewer'),
          controller: _pages,
          allowImplicitScrolling: true, // 옆 장을 미리 불러 열리지 않는 사진을 넘기기 전에 뺀다
          itemCount: images.length,
          onPageChanged: (i) => setState(() => _page = i), // STATE: 몇 번째 그림
          itemBuilder: (_, i) => InteractiveViewer(
            maxScale: 5,
            child: Center(
              child: AppImage(images[i], fit: BoxFit.contain, placeholder: widget.label),
            ),
          ),
        ),
      );
    },
  );
}
