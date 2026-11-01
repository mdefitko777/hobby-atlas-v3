// 화면 T: 사진 벽 · 사진 보기 — 내 정보(I) · 친구 보기 · 상품 상세(D) · 도감 칸(G)이 같이 쓴다.
// 내 사진은 기기에 (lib/data/photo_files.dart · UserStore local_state.photos), 친구에게 보이기를 켠 것만
// Supabase Storage 로 (lib/sync/photo_share.dart). 서버 SQL 이 아직 없으면 ⚠ 하나 · 사진은 기기에만.
//
// ┌──────── 디자인 가이드 대응표: T 사진 벽 · 사진 보기 ─────────────────────────────────┐
// │ 번호 │ Flutter 위젯명                     │ 비즈니스 명칭(한글)                    │ 원칙(P번호)   │
// │ T-1  │ PhotoWall (3열 격자)                │ 사진 벽: 내 사진 먼저 → 구매함 상품 사진   │ P02 · P06     │
// │ T-2  │ + 칸 → 바텀 시트(카메라 · 갤러리)     │ 내 사진 넣기                            │ P07           │
// │ T-3  │ PhotoViewScreen                    │ 사진 한 장 보기 (워터마크 미리보기)        │ P02 · P10     │
// │ T-4  │ SwitchListTile(👥)                  │ 친구에게 보이기 (사진마다)                │ P05 · P01     │
// │ T-5  │ SwitchListTile(워터마크) · ⤓ 저장     │ 저장할 때 "HA · @아이디"                 │ P05 · P10     │
// │ T-6  │ 🔗 → 바텀 시트(구매함 격자)           │ 사진에 상품 잇기 · 끊기                   │ P07           │
// │ T-7  │ ⚠ 아이콘 + 툴팁                     │ 서버에 사진 공유가 아직 없음 → 기기에만     │ P09 · P01     │
// │ T-8  │ KitPhotoStrip (상품 상세)            │ 이 상품의 내 사진 + 넣기                  │ P07           │
// └──────────────────────────────────────────────────────────────────────────────────┘
// 전환: 사진 칸 → 쌓기(push). 넣기 · 상품 잇기 → 덮기(바텀 시트). 지우기 → 확인 대화상자.
library;

import '../logic/kit_rules.dart';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/catalog.dart';
import '../data/photo_files.dart';
import '../detail_pane.dart';
import '../marks.dart';
import '../models.dart';
import '../sync/account.dart';
import '../sync/photo_share.dart';
import '../theme.dart';
import '../widgets.dart';
import 'd_kit_detail_screen.dart';

/// 사진 고르기 (카메라 · 갤러리) — 테스트는 바꿔 끼운다
typedef PhotoPicker = Future<Uint8List?> Function(ImageSource source);

PhotoPicker photoPicker = _pickWithImagePicker;

Future<Uint8List?> _pickWithImagePicker(ImageSource source) async {
  // 긴 변 1600px · JPEG 85 로 줄여서 (올릴 때 5 MB 한도 · 기기 용량)
  final x = await ImagePicker().pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 85);
  return x?.readAsBytes();
}

/// 워터마크 글자 (아이디가 없으면 앱 이름만)
String markFor(String handle) => handle.isEmpty ? 'HA' : watermarkText(handle);

/// 사진 고르는 곳 (T-2 · I-3 아바타 · 배경). [remove] = 지우기 칸도 (I-3, 이미 사진이 있을 때)
enum PhotoChoice { camera, gallery, remove }

Future<PhotoChoice?> askPhotoSource(BuildContext context, {bool remove = false}) => showGpSheet<PhotoChoice>(
  context,
  builder: (sheet) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Row(
        children: [
          for (final (c, icon, label) in [
            (PhotoChoice.camera, Icons.photo_camera_outlined, '카메라'),
            (PhotoChoice.gallery, Icons.photo_library_outlined, '갤러리'),
            if (remove) (PhotoChoice.remove, Icons.delete_outline, '지우기'),
          ]) ...[
            if (c != PhotoChoice.camera) const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(Gp.radius),
                onTap: () => Navigator.pop(sheet, c),
                child: Ink(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: Gp.raised(),
                  child: Column(
                    children: [
                      Icon(icon, size: Gp.iL, color: c == PhotoChoice.remove ? Gp.danger : Gp.ink),
                      const SizedBox(height: 6),
                      Text(label, style: const TextStyle(fontSize: Gp.t12)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  ),
);

/// T-2 내 사진 넣기: 카메라 · 갤러리 → 기기에 저장 → 목록 맨 앞. 고르지 않으면 null
Future<MyPhoto?> addMyPhoto(BuildContext context, {String kitId = '', String unitId = ''}) async {
  final choice = await askPhotoSource(context);
  final source = switch (choice) {
    PhotoChoice.camera => ImageSource.camera,
    PhotoChoice.gallery => ImageSource.gallery,
    _ => null,
  };
  if (source == null || !context.mounted) return null;
  final Uint8List? bytes;
  try {
    bytes = await photoPicker(source);
  } on Object catch (e) {
    if (context.mounted) showToast(context, '사진을 가져오지 못했어요 ($e)');
    return null;
  }
  if (bytes == null || bytes.isEmpty || !context.mounted) return null;
  final store = Marks.read(context).store;
  final photos = AccountScope.read(context).photos;
  final p = MyPhoto.create(kitId: kitId, unitId: unitId);
  await PhotoFiles.instance.write(p.file, bytes);
  store.addPhoto(p);
  photos.syncSoon();
  return p;
}

/// 내 사진 지우기 — 파일 · 목록에서 (서버에 올라가 있으면 다음 동기화 때 내린다)
Future<void> deleteMyPhoto(BuildContext context, MyPhoto p) async {
  final store = Marks.read(context).store;
  final share = AccountScope.read(context).photos;
  store.removePhoto(p.id);
  share.syncSoon();
  await PhotoFiles.instance.delete(p.file);
}

/// T-1 사진 벽 — 흰 띠 + 머리 아이콘(글자 제목 없음) + 3열 격자
class PhotoWall extends StatelessWidget {
  const PhotoWall({super.key, required this.tiles, this.warn = '', this.onAdd, this.extra});
  final List<Widget> tiles;

  /// 머리 오른쪽, + 앞에 (I-9 공개 범위 아이콘)
  final Widget? extra;

  /// T-7 비어 있지 않으면 ⚠ + 이 글을 툴팁으로
  final String warn;

  /// 주면 머리 오른쪽에 + (내 사진 넣기)
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return SectionPanel(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.photo_library_outlined, size: Gp.iM, color: Gp.ink),
              if (warn.isNotEmpty) ...[
                const SizedBox(width: 6),
                Tooltip(
                  key: const ValueKey('photo-warn'),
                  message: warn,
                  triggerMode: TooltipTriggerMode.tap,
                  child: const Icon(Icons.warning_amber_rounded, size: Gp.iS, color: Gp.star),
                ),
              ],
              const Spacer(),
              ?extra,
              if (onAdd != null)
                IconButton(
                  tooltip: '사진 넣기',
                  visualDensity: VisualDensity.compact,
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_a_photo_outlined, size: Gp.iM, color: Gp.ink),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (tiles.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Icon(Icons.photo_outlined, size: Gp.iL, color: Gp.line),
            )
          else
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              children: tiles,
            ),
        ],
      ),
    );
  }
}

/// 격자 한 칸 틀 (둥근 모서리 · 회백색 바탕 · 누름)
class _Tile extends StatelessWidget {
  const _Tile({super.key, required this.child, required this.onTap, this.badge});
  final Widget child;
  final VoidCallback onTap;
  final Widget? badge;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(Gp.rSmall),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: Gp.soft, child: child),
          if (badge != null) Positioned(left: 4, bottom: 4, child: badge!),
        ],
      ),
    ),
  );
}

/// 작은 흰 동그라미 위 아이콘 (사진 위 표시)
Widget _dot(Widget icon) => Container(
  padding: const EdgeInsets.all(3),
  decoration: const BoxDecoration(color: Gp.glass, shape: BoxShape.circle),
  child: icon,
);

/// 내 사진 칸 — 친구에게 안 보이면 눈 꺼짐 표시
class MyPhotoTile extends StatelessWidget {
  const MyPhotoTile(this.photo, {super.key});
  final MyPhoto photo;

  @override
  Widget build(BuildContext context) => _Tile(
    key: ValueKey('my-photo-${photo.id}'),
    onTap: () => openPage(context, PhotoViewScreen(mine: photo.id)),
    badge: photo.shared ? null : _dot(const Icon(Icons.visibility_off_outlined, size: Gp.iXS, color: Gp.muted)),
    child: LocalPhotoImage(photo.file),
  );
}

/// 구매함 상품 사진 칸 (사진이 없어도 벽이 비지 않게) — 리본 표시 · 누르면 상품 상세
class KitPhotoTile extends StatelessWidget {
  const KitPhotoTile(this.kit, {super.key});
  final Kit kit;

  @override
  Widget build(BuildContext context) => _Tile(
    key: ValueKey('kit-photo-${kit.id}'),
    onTap: () => openKitDetail(context, kit),
    badge: _dot(const OwnedIcon(size: Gp.iXS)),
    child: Padding(
      padding: const EdgeInsets.all(4),
      child: AppImage(kit.image, fit: BoxFit.contain, placeholder: kit.line),
    ),
  );
}

/// 친구 사진 칸 (Storage 에서 받기)
class FriendPhotoTile extends StatefulWidget {
  const FriendPhotoTile(this.photo, {super.key});
  final FriendPhoto photo;

  @override
  State<FriendPhotoTile> createState() => _FriendPhotoTileState();
}

class _FriendPhotoTileState extends State<FriendPhotoTile> {
  late final Future<Uint8List> _bytes = AccountScope.read(context).photos.friendImage(widget.photo);

  @override
  Widget build(BuildContext context) => _Tile(
    key: ValueKey('friend-photo-${widget.photo.id}'),
    onTap: () => openPage(context, PhotoViewScreen(friend: widget.photo)),
    child: _FriendImage(_bytes),
  );
}

class _FriendImage extends StatelessWidget {
  const _FriendImage(this.bytes, {this.fit = BoxFit.cover});
  final Future<Uint8List> bytes;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: bytes,
    builder: (context, snap) => switch (snap) {
      AsyncSnapshot(hasData: true, :final data?) => BytesImage(data, fit: fit),
      AsyncSnapshot(hasError: true) => const Center(child: Icon(Icons.broken_image_outlined, color: Gp.faint)),
      _ => const ColoredBox(color: Gp.soft),
    },
  );
}

/// T-3 사진 한 장 보기 — [mine] = 내 사진 id (스위치 · 지우기 · 상품 잇기), [friend] = 친구 사진 (저장만)
class PhotoViewScreen extends StatefulWidget {
  const PhotoViewScreen({super.key, this.mine, this.friend}) : assert((mine == null) != (friend == null));
  final String? mine;
  final FriendPhoto? friend;

  @override
  State<PhotoViewScreen> createState() => _PhotoViewScreenState();
}

class _PhotoViewScreenState extends State<PhotoViewScreen> {
  Future<Uint8List>? _friendBytes;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.friend case final f?) _friendBytes ??= AccountScope.read(context).photos.friendImage(f);
  }

  MyPhoto? get _photo => widget.mine == null ? null : Marks.of(context).store.photo(widget.mine!);

  void _update(MyPhoto p, {bool reupload = false}) {
    // 서버에 있는 것을 고쳤으면 다시 올린다 (같은 id 로 덮어쓰기)
    Marks.read(context).store.updatePhoto(reupload ? p.copyWith(uploadedTo: '') : p);
    AccountScope.read(context).photos.syncSoon();
  }

  /// T-5 저장 — 워터마크가 켜져 있으면 오른쪽 아래에 글자를 그려 넣은 PNG
  Future<void> _save(String mark, bool watermark) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final src = widget.friend != null ? await _friendBytes! : await PhotoFiles.instance.readOrFetch(_photo!.file);
      if (src == null) throw StateError('사진 파일이 없어요');
      final out = watermark ? await composeWatermark(src, mark) : src;
      final id = widget.mine ?? widget.friend!.id;
      final uri = await FilePicker.saveFile(
        fileName: 'hobby-atlas-$id.${watermark ? 'png' : 'jpg'}',
        bytes: out,
        mimeType: watermark ? 'image/png' : 'image/jpeg',
      );
      if (mounted && uri != null) showToast(context, '저장했어요');
    } on Object catch (e) {
      if (mounted) showToast(context, '저장하지 못했어요: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(MyPhoto p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('사진을 지울까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('취소')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Gp.danger),
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('지우기'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final nav = Navigator.of(context);
    await deleteMyPhoto(context, p);
    nav.maybePop();
  }

  /// T-6 상품 잇기 — 구매함에서 고르기
  Future<void> _link(MyPhoto p) async {
    final store = Marks.read(context).store;
    final cat = Catalog.instance;
    final owned = [
      for (final id in store.idsWith(const {CollectStatus.owned})) ?cat.byId[id],
    ];
    if (owned.isEmpty) {
      showToast(context, '구매함이 비어 있어요');
      return;
    }
    final kit = await showGpSheet<Kit>(
      context,
      tall: true,
      builder: (sheet) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheet).height * 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Icon(Icons.link, size: Gp.iM),
                    SizedBox(width: 6),
                    OwnedIcon(size: Gp.iS),
                  ],
                ),
              ),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 4,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  children: [
                    for (final k in owned)
                      Tooltip(
                        message: k.name,
                        child: GestureDetector(
                          onTap: () => Navigator.pop(sheet, k),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(Gp.rSmall),
                            child: ColoredBox(
                              color: Gp.soft,
                              child: AppImage(k.image, fit: BoxFit.contain, placeholder: k.line),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (kit != null && mounted) _update(p.copyWith(kitId: kit.id), reupload: p.shared);
  }

  @override
  Widget build(BuildContext context) {
    final account = AccountScope.of(context);
    final p = _photo;
    final f = widget.friend;
    if (p == null && f == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyView(message: '지운 사진이에요'),
      );
    }
    final mark = markFor(f?.owner ?? account.handle);
    final watermark = p?.watermark ?? f!.watermark;
    final kitId = p?.kitId ?? f!.kitId;
    final kit = kitId.isEmpty ? null : Catalog.instance.byId[kitId];
    final Widget image = p != null
        ? LocalPhotoImage(p.file, fit: BoxFit.contain)
        : _FriendImage(_friendBytes!, fit: BoxFit.contain);
    return Scaffold(
      appBar: AppBar(
        title: f == null ? null : Text('@${f.owner}', style: const TextStyle(fontSize: Gp.t16)),
        actions: [
          IconButton(
            tooltip: '저장',
            onPressed: _saving ? null : () => _save(mark, watermark),
            icon: _saving ? const MiniSpinner(size: 18) : const Icon(Icons.download_outlined, size: Gp.iL),
          ),
          if (p != null)
            IconButton(
              tooltip: '지우기',
              onPressed: () => _delete(p),
              icon: const Icon(Icons.delete_outline, size: Gp.iL),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ColoredBox(
              color: Gp.panel,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  InteractiveViewer(maxScale: 4, child: image),
                  if (watermark) Positioned(right: 10, bottom: 10, child: _Watermark(mark)), // 저장하면 이렇게
                ],
              ),
            ),
          ),
          if (p != null) ...[
            SwitchListTile(
              // T-4 P05
              key: const ValueKey('photo-shared'),
              secondary: Icon(
                p.shared ? Icons.group_outlined : Icons.visibility_off_outlined,
                size: Gp.iM,
                color: p.shared ? Gp.accent : Gp.muted,
              ),
              title: Row(
                children: [
                  const Text('친구에게 보이기', style: TextStyle(fontSize: Gp.t14)),
                  if (p.shared && account.photos.warn) ...[
                    const SizedBox(width: 6),
                    Tooltip(
                      message: _warnText(account.photos),
                      triggerMode: TooltipTriggerMode.tap,
                      child: const Icon(Icons.warning_amber_rounded, size: Gp.iS, color: Gp.star),
                    ),
                  ],
                ],
              ),
              value: p.shared,
              activeThumbColor: Gp.accent,
              onChanged: (v) => _update(p.copyWith(shared: v)), // STATE: 친구에게 보이기 → 올림 · 내림
            ),
            SwitchListTile(
              // T-5 P05
              key: const ValueKey('photo-watermark'),
              secondary: const Icon(Icons.branding_watermark_outlined, size: Gp.iM, color: Gp.muted),
              title: Text(mark, style: const TextStyle(fontSize: Gp.t14)),
              value: p.watermark,
              activeThumbColor: Gp.accent,
              onChanged: (v) => _update(p.copyWith(watermark: v), reupload: p.shared),
            ),
          ],
          // T-6 이어 붙인 상품
          if (kit != null)
            ThumbRow(
              image: kit.image,
              title: kit.name,
              size: 44,
              leading: const Padding(
                padding: EdgeInsets.only(right: 4),
                child: OwnedIcon(size: Gp.iS),
              ),
              trailing: p == null
                  ? null
                  : IconButton(
                      tooltip: '상품 끊기',
                      onPressed: () => _update(p.copyWith(kitId: ''), reupload: p.shared),
                      icon: const Icon(Icons.link_off, size: Gp.iM, color: Gp.muted),
                    ),
              onTap: () => openKitDetail(context, kit),
            )
          else if (p != null)
            ListTile(
              leading: const Icon(Icons.link, size: Gp.iM, color: Gp.muted),
              title: const Text('상품 잇기', style: TextStyle(fontSize: Gp.t14)),
              onTap: () => _link(p),
            ),
        ],
      ),
    );
  }
}

String _warnText(PhotoShareService s) =>
    s.missing ? '서버에 사진 공유가 아직 없어요 · 사진은 이 기기에만 있어요' : '올리지 못했어요 · 다음에 다시 올려요 (${s.message})';

/// T-7 ⚠ 툴팁 글 — 서버에 없음 · 실패일 때만 (아니면 '')
String photoWarn(PhotoShareService s) => s.warn ? _warnText(s) : '';

/// 사진 위 워터마크 미리보기 — 작은 반투명 띠
class _Watermark extends StatelessWidget {
  const _Watermark(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: const Color(0x47000000), borderRadius: BorderRadius.circular(Gp.rSmall)),
    child: Text(
      text,
      style: const TextStyle(color: Colors.white, fontSize: Gp.t11, fontWeight: FontWeight.w600, letterSpacing: 0.3),
    ),
  );
}

/// 사진 오른쪽 아래에 [mark] 를 그려 넣은 PNG (미리보기 띠와 같은 모양, 사진 크기에 맞춰 키운다)
Future<Uint8List> composeWatermark(Uint8List src, String mark) async {
  final codec = await ui.instantiateImageCodec(src);
  final img = (await codec.getNextFrame()).image;
  final w = img.width.toDouble(), h = img.height.toDouble();
  final fs = ((w < h ? w : h) * 0.035).clamp(12.0, 64.0);
  final para =
      (ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: fs, fontWeight: FontWeight.w600))
            ..pushStyle(ui.TextStyle(color: Colors.white, letterSpacing: fs * 0.03))
            ..addText(mark))
          .build()
        ..layout(ui.ParagraphConstraints(width: w));
  final padX = fs * 0.7, padY = fs * 0.3, margin = fs * 0.9;
  final box = RRect.fromLTRBR(
    w - margin - para.maxIntrinsicWidth - padX * 2,
    h - margin - para.height - padY * 2,
    w - margin,
    h - margin,
    Radius.circular(fs * 0.5),
  );
  final rec = ui.PictureRecorder();
  Canvas(rec)
    ..drawImage(img, Offset.zero, Paint())
    ..drawRRect(box, Paint()..color = const Color(0x47000000))
    ..drawParagraph(para, Offset(box.left + padX, box.top + padY));
  final out = await rec.endRecording().toImage(img.width, img.height);
  final data = await out.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  out.dispose();
  return data!.buffer.asUint8List();
}

/// T-8 상품 상세: 이 상품의 내 사진 + 넣기 (구매함일 때)
class KitPhotoStrip extends StatelessWidget {
  const KitPhotoStrip({super.key, required this.kitId});
  final String kitId;

  @override
  Widget build(BuildContext context) {
    final mine = [
      for (final p in Marks.of(context).store.photos)
        if (p.kitId == kitId) p,
    ];
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Tooltip(
            message: '내 사진 넣기',
            child: InkWell(
              borderRadius: BorderRadius.circular(Gp.rSmall),
              onTap: () => addMyPhoto(context, kitId: kitId),
              child: Ink(
                width: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Gp.rSmall),
                  border: Border.all(color: Gp.line),
                ),
                child: const Icon(Icons.add_a_photo_outlined, size: Gp.iM, color: Gp.muted),
              ),
            ),
          ),
          for (final p in mine) ...[const SizedBox(width: 6), SizedBox(width: 48, child: MyPhotoTile(p))],
        ],
      ),
    );
  }
}
