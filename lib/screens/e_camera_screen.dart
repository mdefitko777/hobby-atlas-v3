// 화면 E: 찍어서 찾기 — 바코드(기기 안에서 읽기) · 사진(이름 · 설명으로 찾고 내 상품에 붙이기)
//
// ┌──────── 디자인 가이드 대응표: E 찍어서 찾기 ───────────────────────────────────────┐
// │ 번호 │ Flutter 위젯명                     │ 비즈니스 명칭(한글)                    │ 원칙(P번호)   │
// │ E-1  │ MobileScanner + 맞춤 틀 + 바깥 어둡게 │ 바코드 카메라 (기기 안 ML Kit)          │ P02 · P10     │
// │ E-2  │ 사진 | 바코드 전환                   │ 찍는 방식 고르기                        │ P07 · P06     │
// │ E-3  │ ⌨ 번호 입력                         │ 카메라가 안 될 때 바코드 숫자 직접 넣기   │ P09 · P07     │
// │ E-4  │ 틀 안 "찾는 중…"                     │ 읽은 바코드로 상품 찾는 중               │ P01           │
// │ E-5  │ image_picker (카메라 · 갤러리)        │ 사진 찍기 · 앨범에서 고르기              │ P07           │
// │ E-6  │ 바코드 결과: 상세 / 여러 개면 목록    │ 바코드 = JAN 이 같은 상품               │ P01 · P10     │
// │ E-7  │ 모르는 바코드 패널 (제보 · 다시 · 검색) │ 이 바코드의 상품이 아직 없어요          │ P09 · P03     │
// │ E-8  │ 사진 + "이름으로 찾기" + 결과 줄       │ 사진 인식 없음 → 이름 · 설명으로 찾기     │ P09 · P10     │
// │ E-9  │ 줄 오른쪽 📎 / 리본+                  │ 구매함 상품에 사진 붙이기 (내 사진 · 사진 벽) │ P07 · P03 │
// │ E-10 │ LoadingView / ErrorView / EmptyView  │ 불러오기 3상태                          │ P01 · P09     │
// └──────────────────────────────────────────────────────────────────────────────────┘
// 전환: 앱 셸 카메라 버튼 → 추가 시트 → 바코드: E 카메라(아래에서 올라옴) → 찾으면 D 상세로 바꿔 쌓기.
//       사진 · 앨범: 휴대폰 카메라 / 사진 고르기 → E-8 사진으로 찾기(쌓기) → D 상세(쌓기).
// 사진으로 상품을 알아보는 AI 는 없다 (서버 · 유료 API 가 필요) — 가짜 후보를 만들지 않고 이름 · 설명 검색으로 이어 준다.
import '../logic/kit_rules.dart';
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:image_picker/image_picker.dart' show ImageSource;
import 'package:mobile_scanner/mobile_scanner.dart';

import '../api.dart';
import '../channels.dart';
import '../data/photo_files.dart';
import '../marks.dart';
import '../models.dart';
import '../report.dart';
import '../logic/sentence_search.dart';
import '../sync/account.dart';
import '../theme.dart';
import '../widgets.dart';
import 'b_search_screen.dart' show SentenceCandidates;
import 'd_kit_detail_screen.dart';
import 't_photo_screen.dart' show photoPicker;

enum CameraMode { photo, barcode }

/// 찍어서 찾기 열기 — 바코드: 카메라 화면(아래에서 올라옴), 사진: 휴대폰 카메라로 찍은 뒤 E-8
void openCamera(BuildContext context, CameraMode mode, {required Loaders loaders, required VoidCallback onGoSearch}) {
  if (mode == CameraMode.photo) {
    unawaited(_pickPhoto(context, ImageSource.camera, loaders: loaders, onGoSearch: onGoSearch));
    return;
  }
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => BarcodeScanScreen(loaders: loaders, onGoSearch: onGoSearch),
    ),
  );
}

/// E-5 앨범에서 고르기 → E-8
void openAlbum(BuildContext context, {required Loaders loaders, required VoidCallback onGoSearch}) =>
    unawaited(_pickPhoto(context, ImageSource.gallery, loaders: loaders, onGoSearch: onGoSearch));

Future<void> _pickPhoto(
  BuildContext context,
  ImageSource source, {
  required Loaders loaders,
  required VoidCallback onGoSearch,
}) async {
  final nav = Navigator.of(context, rootNavigator: true);
  final Uint8List? bytes;
  try {
    bytes = await photoPicker(source); // 사진 벽(T)과 같은 고르기 (줄여서 JPEG)
  } on Object catch (e) {
    if (context.mounted) showToast(context, '사진을 가져오지 못했어요 ($e)');
    return;
  }
  if (bytes == null || bytes.isEmpty) return;
  nav.push(
    MaterialPageRoute<void>(
      builder: (_) => PhotoFindScreen(photo: bytes!, loaders: loaders, onGoSearch: onGoSearch),
    ),
  );
}

/// 바코드 카메라 미리보기 — 테스트는 카메라 대신 다른 위젯을 넣는다
typedef ScannerPreview = Widget Function(BuildContext context, ValueChanged<String> onCode);

/// E-1 바코드 찍기
class BarcodeScanScreen extends StatefulWidget {
  const BarcodeScanScreen({super.key, required this.loaders, required this.onGoSearch, this.preview});

  final Loaders loaders;
  final VoidCallback onGoSearch;

  /// 비면 MobileScanner (휴대폰 카메라)
  final ScannerPreview? preview;

  @override
  State<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends State<BarcodeScanScreen> {
  MobileScannerController? _camera;

  /// 읽은 바코드로 찾는 중
  bool _looking = false;

  /// 찾지 못한 바코드 (E-7 패널)
  String _unknown = '';

  @override
  void initState() {
    super.initState();
    if (widget.preview == null) {
      _camera = MobileScannerController(
        // 상자 뒷면 바코드만 (QR 은 상품 번호가 아니다)
        formats: const [BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.upcA, BarcodeFormat.upcE],
        detectionSpeed: DetectionSpeed.noDuplicates,
      );
    }
  }

  @override
  void dispose() {
    unawaited(_camera?.dispose());
    super.dispose();
  }

  void _onDetect(BarcodeCapture c) {
    for (final b in c.barcodes) {
      final v = b.rawValue ?? '';
      if (normalizeBarcode(v).isNotEmpty) {
        unawaited(_lookUp(v));
        return;
      }
    }
  }

  /// 바코드 → 상품 (하나면 상세, 여럿이면 목록, 없으면 E-7)
  Future<void> _lookUp(String raw) async {
    final code = normalizeBarcode(raw);
    if (code.isEmpty || _looking) return;
    setState(() => _looking = true); // STATE: 읽음 → 틀 안 "찾는 중…"
    unawaited(_camera?.stop());
    List<Kit> kits;
    try {
      kits = await widget.loaders.kitsByJan(code);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _looking = false);
      showToast(context, '$e');
      unawaited(_camera?.start());
      return;
    }
    if (!mounted) return;
    final nav = Navigator.of(context);
    if (kits.length == 1) {
      nav.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => KitDetailScreen(kit: kits.first, loaders: widget.loaders),
        ),
      );
    } else if (kits.isNotEmpty) {
      nav.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => BarcodeResultScreen(code: code, kits: kits, loaders: widget.loaders),
        ),
      );
    } else {
      setState(() {
        _looking = false;
        _unknown = code; // STATE: 모르는 바코드 → E-7 패널
      });
    }
  }

  void _retry() {
    setState(() => _unknown = ''); // STATE: 다시 찍기 → 카메라
    unawaited(_camera?.start());
  }

  void _goSearch() {
    Navigator.of(context).popUntil((r) => r.isFirst);
    widget.onGoSearch();
  }

  /// E-3 숫자 직접 넣기
  Future<void> _typeCode() async {
    final c = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('바코드 번호'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 13,
          decoration: const InputDecoration(hintText: '45…  /  49…'),
          onSubmitted: (v) => Navigator.pop(dialog, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(dialog, c.text), child: const Text('찾기')),
        ],
      ),
    ).whenComplete(c.dispose);
    if (code == null || !mounted) return;
    if (normalizeBarcode(code).isEmpty) {
      showToast(context, '13자리(또는 8 · 12자리) 숫자예요');
      return;
    }
    setState(() => _unknown = '');
    await _lookUp(code);
  }

  /// 사진 모드로: 이 화면을 닫고 휴대폰 카메라
  void _toPhoto() {
    final root = Navigator.of(context, rootNavigator: true);
    root.pop();
    openCamera(root.context, CameraMode.photo, loaders: widget.loaders, onGoSearch: widget.onGoSearch);
  }

  void _toAlbum() {
    final root = Navigator.of(context, rootNavigator: true);
    root.pop();
    openAlbum(root.context, loaders: widget.loaders, onGoSearch: widget.onGoSearch);
  }

  Widget _preview(BuildContext context) {
    if (widget.preview case final p?) return p(context, (v) => unawaited(_lookUp(v)));
    return MobileScanner(
      controller: _camera,
      onDetect: _onDetect,
      errorBuilder: (context, error) =>
          _CameraError(denied: error.errorCode == MobileScannerErrorCode.permissionDenied, onType: _typeCode),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                final frameW = box.maxWidth * 0.8;
                final frameH = frameW * 0.42;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    _preview(context), // E-1
                    IgnorePointer(child: CustomPaint(painter: _DimOutside(frameW, frameH))),
                    Center(
                      child: IgnorePointer(
                        child: SizedBox(
                          width: frameW,
                          height: frameH,
                          child: CustomPaint(
                            painter: _FrameCorners(),
                            child: _looking
                                ? const Center(
                                    child: _Bubble(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          MiniSpinner(size: 16, color: Gp.accent),
                                          SizedBox(width: 8),
                                          Text('찾는 중…', style: TextStyle(fontWeight: FontWeight.w600)), // E-4 P01
                                        ],
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            RaisedCircleButton(
                              tooltip: '닫기', // P03
                              size: 40,
                              onTap: () => Navigator.of(context).maybePop(),
                              child: const Icon(Icons.close, size: Gp.iM, color: Gp.ink),
                            ),
                            const Spacer(),
                            RaisedCircleButton(
                              tooltip: '번호 입력', // E-3
                              size: 40,
                              onTap: _typeCode,
                              child: const Icon(Icons.keyboard_outlined, size: Gp.iM, color: Gp.ink),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_unknown.isNotEmpty)
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 16,
                        child: _UnknownBarcode(
                          // E-7 P09
                          code: _unknown,
                          onReport: () => reportDataIssue(context, barcode: _unknown, kind: ReportKind.missingKit),
                          onRetry: _retry,
                          onSearch: _goSearch,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          ColoredBox(
            color: Gp.panel,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 14),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: '앨범', // E-5
                      onPressed: _toAlbum,
                      icon: const Icon(Icons.photo_library_outlined, color: Gp.ink),
                    ),
                    const Spacer(),
                    UnderlineTab(label: '사진', selected: false, onTap: _toPhoto), // E-2 P07
                    const SizedBox(width: 10),
                    UnderlineTab(label: '바코드', selected: true, onTap: () {}),
                    const Spacer(),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(color: const Color(0xEEFFFFFF), borderRadius: BorderRadius.circular(Gp.rSmall)),
    child: child,
  );
}

/// 카메라를 못 열었을 때 (권한 거절 · 카메라 없음) — 번호 입력으로
class _CameraError extends StatelessWidget {
  const _CameraError({required this.denied, required this.onType});
  final bool denied;
  final VoidCallback onType;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Gp.panel,
    child: EmptyView(
      icon: Icons.no_photography_outlined,
      message: denied ? '카메라 권한이 꺼져 있어요' : '카메라를 열지 못했어요',
      detail: denied ? '휴대폰 설정 › 애플리케이션 › Hobby Atlas › 권한' : '',
      action: OutlinedButton.icon(
        onPressed: onType,
        icon: const Icon(Icons.keyboard_outlined, size: Gp.iM),
        label: const Text('번호 입력'),
      ),
    ),
  );
}

/// E-7 이 바코드의 상품이 아직 없어요
class _UnknownBarcode extends StatelessWidget {
  const _UnknownBarcode({required this.code, required this.onReport, required this.onRetry, required this.onSearch});
  final String code;
  final VoidCallback onReport;
  final VoidCallback onRetry;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    Widget act(IconData icon, String tip, VoidCallback onTap) => IconButton(
      tooltip: tip,
      onPressed: onTap,
      icon: Icon(icon, color: Gp.ink),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
      decoration: BoxDecoration(color: Gp.panel, borderRadius: BorderRadius.circular(Gp.rLarge)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('이 바코드의 상품이 아직 없어요', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  code,
                  style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
                ),
              ],
            ),
          ),
          act(Icons.flag_outlined, '제보', onReport),
          act(Icons.search, '이름으로 찾기', onSearch),
          act(Icons.refresh, '다시 찍기', onRetry),
        ],
      ),
    );
  }
}

/// E-6 바코드 하나에 상품이 여럿 (재판 · 같은 JAN 의 다른 판)
class BarcodeResultScreen extends StatelessWidget {
  const BarcodeResultScreen({super.key, required this.code, required this.kits, this.loaders = const Loaders()});
  final String code;
  final List<Kit> kits;
  final Loaders loaders;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          code,
          style: const TextStyle(fontSize: Gp.t16, fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        children: [
          for (final k in kits)
            ThumbRow(
              image: k.image,
              title: k.name,
              titleLines: 2,
              subtitle: joinDot([channelOf(k.franchiseId).label, k.line, dateDot(k.date)]),
              onTap: () => openKitDetail(context, k, loaders: loaders, list: kits),
            ),
        ],
      ),
    );
  }
}

/// E-8 사진으로 찾기 — 사진을 보여 주고, 이름 · 설명으로 찾아 고른 구매함 상품에 사진을 붙인다
class PhotoFindScreen extends StatefulWidget {
  const PhotoFindScreen({super.key, required this.photo, required this.loaders, required this.onGoSearch});

  final Uint8List photo;
  final Loaders loaders;
  final VoidCallback onGoSearch;

  @override
  State<PhotoFindScreen> createState() => _PhotoFindScreenState();
}

class _PhotoFindScreenState extends State<PhotoFindScreen> {
  late Future<List<Kit>> _future = _load();

  Future<List<Kit>> _load() => widget.loaders.kits([for (final c in allChannels) c.id]);
  String _query = '';

  /// 이 화면에서 사진을 붙인 상품 (✓)
  final Set<String> _attached = {};

  (String, List<SentenceHit>)? _memo;

  List<SentenceHit> _hits(List<Kit> kits) {
    if (_memo case (final q, final h) when q == _query) return h;
    final h = sentenceSearch(_query, kits);
    _memo = (_query, h);
    return h;
  }

  /// E-9 이 상품에 사진 붙이기 (내 사진 목록 · 사진 벽 · 상세 사진 줄에 보인다)
  Future<void> _attach(Kit k) async {
    final store = Marks.read(context).store;
    final share = AccountScope.read(context).photos;
    final p = MyPhoto.create(kitId: k.id);
    await PhotoFiles.instance.write(p.file, widget.photo);
    store.addPhoto(p);
    share.syncSoon();
    if (!mounted) return;
    setState(() => _attached.add(k.id)); // STATE: 붙임 → ✓
    showToast(
      context,
      '「${k.name}」에 사진을 붙였어요',
      onUndo: () {
        store.removePhoto(p.id);
        share.syncSoon();
        unawaited(PhotoFiles.instance.delete(p.file));
        if (mounted) setState(() => _attached.remove(k.id));
      },
    );
  }

  Widget _row(Kit k, List<Kit> list) {
    final marks = Marks.of(context);
    final owned = marks.owned(k);
    final done = _attached.contains(k.id);
    return ThumbRow(
      image: k.image,
      title: k.name,
      subtitle: joinDot([channelOf(k.franchiseId).label, k.line]),
      onTap: () => openKitDetail(context, k, loaders: widget.loaders, list: list),
      trailing: done
          ? const Icon(Icons.check_circle, color: Gp.accent)
          : owned
          ? IconButton(
              tooltip: '사진 붙이기',
              onPressed: () => _attach(k),
              icon: const Icon(Icons.add_photo_alternate_outlined, color: Gp.ink),
            )
          : IconButton(
              tooltip: '구매함에 넣기', // 구매함 상품에만 붙인다 → 먼저 넣기
              onPressed: () => Marks.read(context).toggleOwn(context, k),
              icon: const Icon(Icons.bookmark_add_outlined, color: Gp.muted),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '사진으로 찾기',
          style: TextStyle(fontSize: Gp.t19, fontWeight: FontWeight.w600),
        ),
      ),
      body: FutureBuilder<List<Kit>>(
        future: _future,
        builder: (context, snap) {
          final kits = snap.data ?? const <Kit>[];
          final marks = Marks.of(context);
          final owned = [
            for (final k in kits)
              if (marks.owned(k)) k,
          ];
          final hits = _query.isEmpty ? const <SentenceHit>[] : _hits(kits);
          final byName = _query.isEmpty
              ? owned
              : [
                  for (final k in kits)
                    if (kitMatches(k, _query)) k,
                ].take(40).toList();
          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Gp.rLarge),
                  child: ColoredBox(
                    color: Gp.soft,
                    child: SizedBox(
                      height: 220,
                      child: Image.memory(widget.photo, fit: BoxFit.contain, gaplessPlayback: true),
                    ),
                  ),
                ),
              ),
              const Padding(
                // E-8 P09 — 사진 인식이 없다는 것을 그대로
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Icon(Icons.image_not_supported_outlined, size: Gp.iS, color: Gp.faint),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '사진으로 알아보기는 아직 없어요 · 이름이나 생김새로 찾아 주세요',
                        style: TextStyle(fontSize: Gp.t12, color: Gp.muted),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gp.gutter),
                child: TextField(
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: '이름으로 찾기',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (q) => setState(() => _query = q.trim()), // STATE: 찾기 → 후보 · 결과
                ),
              ),
              if (snap.connectionState != ConnectionState.done)
                const SizedBox(height: 160, child: LoadingView()) // E-10
              else if (snap.hasError)
                ErrorView(message: '${snap.error}', onRetry: () => setState(() => _future = _load()))
              else ...[
                if (hits.isNotEmpty)
                  SentenceCandidates(
                    hits: hits,
                    onTap: (k) => openKitDetail(context, k, loaders: widget.loaders),
                  ),
                if (_query.isEmpty && owned.isNotEmpty)
                  SectionHeader('구매함', subtitle: '${owned.length}개', padding: const EdgeInsets.fromLTRB(16, 18, 12, 4)),
                for (final k in byName) _row(k, byName),
                if (byName.isEmpty && hits.isEmpty)
                  EmptyView(
                    icon: _query.isEmpty ? Icons.bookmark_added_outlined : Icons.search_off,
                    message: _query.isEmpty ? '구매함이 비어 있어요' : '「$_query」와 일치하는 상품이 없어요',
                    action: _query.isEmpty
                        ? null
                        : OutlinedButton.icon(
                            onPressed: () => reportDataIssue(context, kind: ReportKind.missingKit, unitName: _query),
                            icon: const Icon(Icons.flag_outlined, size: Gp.iM),
                            label: const Text('없는 상품 제보'),
                          ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// 틀 바깥만 반투명 검정으로 (가운데 둥근 사각형 구멍)
class _DimOutside extends CustomPainter {
  const _DimOutside(this.w, this.h);
  final double w;
  final double h;

  @override
  void paint(Canvas canvas, Size s) {
    final hole = RRect.fromRectAndRadius(
      Rect.fromCenter(center: s.center(Offset.zero), width: w, height: h),
      const Radius.circular(Gp.rLarge),
    );
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & s)
      ..addRRect(hole);
    canvas.drawPath(path, Paint()..color = const Color(0x59000000));
  }

  @override
  bool shouldRepaint(_DimOutside old) => old.w != w || old.h != h;
}

/// 맞춤 틀의 네 모서리
class _FrameCorners extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const l = 26.0;
    const r = 18.0;
    final path = Path()
      ..moveTo(0, l)
      ..lineTo(0, r)
      ..arcToPoint(const Offset(r, 0), radius: const Radius.circular(r))
      ..lineTo(l, 0)
      ..moveTo(s.width - l, 0)
      ..lineTo(s.width - r, 0)
      ..arcToPoint(Offset(s.width, r), radius: const Radius.circular(r))
      ..lineTo(s.width, l)
      ..moveTo(s.width, s.height - l)
      ..lineTo(s.width, s.height - r)
      ..arcToPoint(Offset(s.width - r, s.height), radius: const Radius.circular(r))
      ..lineTo(s.width - l, s.height)
      ..moveTo(l, s.height)
      ..lineTo(r, s.height)
      ..arcToPoint(Offset(0, s.height - r), radius: const Radius.circular(r))
      ..lineTo(0, s.height - l);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_FrameCorners old) => false;
}
