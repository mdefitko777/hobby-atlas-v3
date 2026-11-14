// 화면 E-19 찾을 부분 고르기 — 생김새로 찾기(E-18) 전에 사진에서 물건만 틀로 고른다. 글자 읽기는 사진 전체 그대로.
// 배경이 큰 집 · 가게 사진, 스크린숏에서 생김새 비교가 배경을 닮은 상품으로 갔다 (2026-11-14 평가: 상자를 맞추면
// 첫 후보가 포켓몬 +12 · 마도카 +15 점, 스크린숏은 잃은 점수 대부분을 되찾음). 자동 상자는 득실이 섞여 손으로만.
// 틀 위젯(PhotoCropView)은 E-8 사진 칸에서도 보기만으로 쓴다 (고른 틀이 보이게).
import 'dart:typed_data';

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../logic/photo_crop.dart';
import '../theme.dart';
import '../widgets.dart';

/// 찾을 부분 고르기 열기 → 고른 틀 (취소면 null)
Future<CropBox?> pickPhotoCrop(BuildContext context, Uint8List photo, CropBox current) =>
    Navigator.of(context).push<CropBox>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PhotoCropScreen(photo: photo, initial: current),
      ),
    );

/// E-19 찾을 부분 고르기
class PhotoCropScreen extends StatefulWidget {
  const PhotoCropScreen({super.key, required this.photo, this.initial = fullCrop});
  final Uint8List photo;
  final CropBox initial;

  @override
  State<PhotoCropScreen> createState() => _PhotoCropScreenState();
}

class _PhotoCropScreenState extends State<PhotoCropScreen> {
  late CropBox _box = widget.initial;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(tr('찾을 부분 고르기')),
      actions: [
        TextButton(
          key: const ValueKey('crop-reset'),
          onPressed: isFullCrop(_box) ? null : () => setState(() => _box = fullCrop), // STATE: 전체로
          child: Text(tr('전체')),
        ),
        TextButton(
          key: const ValueKey('crop-done'),
          onPressed: () => Navigator.pop(context, _box),
          child: Text(tr('확인')),
        ),
        const SizedBox(width: 6),
      ],
    ),
    body: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gp.gutter, 4, Gp.gutter, 12),
            child: Text(
              tr('물건만 들어가게 모서리를 끌어 주세요'),
              style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Gp.gutter, 0, Gp.gutter, Gp.gutter),
              child: PhotoCropView(
                photo: widget.photo,
                box: _box,
                onChanged: (b) => setState(() => _box = b), // STATE: 틀 끌기
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// 사진 + 틀. [onChanged] 가 있으면 모서리 · 안쪽을 끌 수 있다 (없으면 보기만)
class PhotoCropView extends StatefulWidget {
  const PhotoCropView({super.key, required this.photo, required this.box, this.onChanged});
  final Uint8List photo;
  final CropBox box;
  final ValueChanged<CropBox>? onChanged;

  @override
  State<PhotoCropView> createState() => _PhotoCropViewState();
}

class _PhotoCropViewState extends State<PhotoCropView> {
  /// 방향을 바로 세운 사진 크기 (화면에 그릴 칸을 맞추려면 필요)
  Size? _size;
  ImageStream? _stream;
  late final _listener = ImageStreamListener((info, _) {
    final s = Size(info.image.width.toDouble(), info.image.height.toDouble());
    info.dispose();
    if (mounted) setState(() => _size = s); // STATE: 사진 크기 → 틀 칸
  }, onError: (_, _) {});
  CropGrip? _grip;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(PhotoCropView old) {
    super.didUpdateWidget(old);
    if (!identical(old.photo, widget.photo)) _resolve();
  }

  /// Image.memory 와 같은 MemoryImage 라 이미 푼 그림을 같이 쓴다
  void _resolve() {
    _stream?.removeListener(_listener);
    _stream = MemoryImage(widget.photo).resolve(ImageConfiguration.empty)..addListener(_listener);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = _size;
    if (size == null) return BytesImage(widget.photo, fit: BoxFit.contain);
    return LayoutBuilder(
      builder: (context, c) {
        final fit = applyBoxFit(BoxFit.contain, size, c.biggest).destination;
        final w = fit.width, h = fit.height;
        final edit = widget.onChanged;
        return Center(
          child: SizedBox(
            width: w,
            height: h,
            child: Stack(
              fit: StackFit.expand,
              children: [
                BytesImage(widget.photo, fit: BoxFit.fill),
                CustomPaint(painter: _CropPainter(widget.box, grips: edit != null)),
                if (edit != null)
                  GestureDetector(
                    key: const ValueKey('crop-area'),
                    behavior: HitTestBehavior.opaque,
                    // 누른 곳으로 모서리를 고른다 (기본값은 손가락이 조금 움직인 뒤의 곳이라 모서리를 놓친다)
                    dragStartBehavior: DragStartBehavior.down,
                    onPanStart: (d) => _grip = cropGripAt(
                      widget.box,
                      d.localPosition.dx / w,
                      d.localPosition.dy / h,
                      reachX: 28 / w,
                      reachY: 28 / h,
                    ),
                    onPanUpdate: (d) {
                      final g = _grip;
                      if (g == null) return;
                      edit(dragCrop(widget.box, g, d.delta.dx / w, d.delta.dy / h, minW: 48 / w, minH: 48 / h));
                    },
                    onPanEnd: (_) => _grip = null,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 틀 밖은 어둡게, 틀은 파란 선, 고를 때는 네 모서리에 손잡이
class _CropPainter extends CustomPainter {
  _CropPainter(this.box, {required this.grips});
  final CropBox box;
  final bool grips;

  @override
  void paint(Canvas canvas, Size size) {
    if (!grips && isFullCrop(box)) return;
    final r = Rect.fromLTRB(
      box.left * size.width,
      box.top * size.height,
      box.right * size.width,
      box.bottom * size.height,
    );
    canvas.drawPath(
      Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), Path()..addRect(r)),
      Paint()..color = grips ? Gp.scrim : Gp.scrimLight,
    );
    canvas.drawRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Gp.accent,
    );
    if (!grips) return;
    final fill = Paint()..color = Gp.panel;
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Gp.accent;
    for (final p in [r.topLeft, r.topRight, r.bottomLeft, r.bottomRight]) {
      canvas
        ..drawCircle(p, 9, fill)
        ..drawCircle(p, 9, edge);
    }
  }

  @override
  bool shouldRepaint(_CropPainter old) => old.box != box || old.grips != grips;
}
