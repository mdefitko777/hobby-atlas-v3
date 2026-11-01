// 화면 E: 찍어서 찾기 — 카메라(사진 · 바코드) · 앨범 → AI 후보 결과
//
// ┌──────── 디자인 가이드 대응표: E 찍어서 찾기 ───────────────────────────────────────┐
// │ 번호 │ Flutter 위젯명                     │ 비즈니스 명칭(한글)                    │ 원칙(P번호)   │
// │ E-1  │ 사진 + 맞춤 틀 + 바깥 어둡게          │ 카메라 화면 (가짜 미리보기)             │ P02 · P10     │
// │ E-2  │ 사진 | 바코드 전환                   │ 찍는 방식 고르기                        │ P07 · P06     │
// │ E-3  │ RaisedCircleButton(셔터)            │ 찍기                                   │ P07           │
// │ E-4  │ 틀 안 "비교하는 중…"                 │ 분석 중 표시 (약 1초, 가짜)             │ P01           │
// │ E-5  │ showModalBottomSheet 사진 격자       │ 앨범에서 선택                          │ P07           │
// │ E-6  │ 큰 카드 + 일치도 막대 + 이유          │ 가장 닮은 상품 (AI 가짜 응답)           │ P01 · P10     │
// │ E-7  │ 상세 보기 · 좋아요에 담기               │ 다음 할 일 (상세로 / 바로 좋아요)          │ P07 · P03     │
// │ E-8  │ 작은 줄 목록                         │ 다른 후보                              │ P06           │
// │ E-9  │ 이름으로 검색 · 다시 찍기             │ 못 찾았을 때 빠져나갈 길                │ P09 · P03     │
// │ E-10 │ LoadingView / ErrorView / EmptyView  │ 후보 불러오기 3상태 (GET /kits?id=)      │ P01 · P09     │
// └──────────────────────────────────────────────────────────────────────────────────┘
// 전환: 앱 셸 카메라 버튼 → 추가 시트 → E 카메라(아래에서 올라옴, 쌓기) → 결과(바꿔 쌓기)
//       → D 상품 상세(쌓기). 앨범은 덮기(바텀 시트) → 결과.
// 실제 카메라 · 이미지 인식 · AI 호출 없음: 찍는 장면과 후보는 아래 상수로 미리 정해 둔다.
import 'package:flutter/material.dart';

import '../api.dart';
import '../marks.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'd_kit_detail_screen.dart';

enum CameraMode { photo, barcode }

/// 미리 정한 장면: 미리보기 사진 + AI 후보(키트 id, 일치도, 이유)
class CameraScene {
  const CameraScene({required this.photo, required this.candidates, this.barcode = ''});
  final String photo;
  final List<(String, int, String)> candidates;
  final String barcode;
}

const photoScene = CameraScene(
  photo: 'assets/gp/kits/gu02.jpg',
  candidates: [
    ('gu02', 94, '날개 모양 · 흰색/파랑 배색 · 상자 로고가 일치'),
    ('gu06', 81, '같은 기체의 SD(MGSD) 버전'),
    ('gu12', 57, '같은 SEED 계열 기체 · 날개 없음'),
  ],
);

const barcodeScene = CameraScene(
  photo: 'assets/gp/kits/gu03.jpg',
  barcode: '4573102720030',
  candidates: [('gu03', 100, '바코드 4573102720030 이 정확히 일치')],
);

/// 앨범의 "최근 사진" — 고르면 그 장면으로 결과
const albumScenes = <CameraScene>[
  CameraScene(
    photo: 'assets/gp/kits/gu04.jpg',
    candidates: [('gu04', 91, '흰색/파랑 몸체 · Witch from Mercury 로고'), ('gu05', 63, '같은 작품의 다른 기체')],
  ),
  CameraScene(
    photo: 'assets/gp/kits/po19.png',
    candidates: [('po19', 93, '이브이 · 큰 사이즈 포켓프라'), ('po21', 48, '같은 포켓프라 Quick!! 라인')],
  ),
  CameraScene(
    photo: 'assets/gp/kits/be43.png',
    candidates: [('be43', 88, '드랜 소드 블레이드 모양'), ('be48', 84, '같은 블레이드의 메탈 코트')],
  ),
  CameraScene(photo: 'assets/gp/kits/fa30.jpg', candidates: [('fa30', 90, '검은 갑옷 세이버 · figma 상자')]),
  CameraScene(
    photo: 'assets/gp/kits/gu10.jpg',
    candidates: [('gu10', 89, '흰 날개 · W 계열 배색'), ('gu09', 41, '같은 RG/MG 계열 변형 기체')],
  ),
  CameraScene(photo: 'assets/gp/kits/ar37.jpg', candidates: [('ar37', 86, '흰색 기체 + 대형 부스터(V.O.B)')]),
];

/// 카메라 열기 (아래에서 올라오는 전체 화면)
void openCamera(BuildContext context, CameraMode mode, {required Loaders loaders, required VoidCallback onGoSearch}) {
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => CameraScreen(mode: mode, loaders: loaders, onGoSearch: onGoSearch),
    ),
  );
}

/// E-5 앨범에서 선택 (바텀 시트) → 결과
void openAlbum(BuildContext context, {required Loaders loaders, required VoidCallback onGoSearch}) {
  final nav = Navigator.of(context, rootNavigator: true);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                '최근 사진',
                style: TextStyle(fontSize: Gp.t16, fontWeight: FontWeight.w600),
              ),
            ),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              children: [
                for (final scene in albumScenes)
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(sheet);
                      nav.push(
                        MaterialPageRoute<void>(
                          builder: (_) => CameraResultScreen(scene: scene, loaders: loaders, onGoSearch: onGoSearch),
                        ),
                      );
                    },
                    child: PhotoThumb(scene.photo, radius: 8),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key, required this.mode, required this.loaders, required this.onGoSearch});

  final CameraMode mode;
  final Loaders loaders;
  final VoidCallback onGoSearch;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraMode _mode = widget.mode;
  bool _analyzing = false;

  CameraScene get _scene => _mode == CameraMode.photo ? photoScene : barcodeScene;

  Future<void> _shoot() async {
    setState(() => _analyzing = true); // STATE: 찍음 → 틀 안 "비교하는 중…"
    // 가짜 분석 시간 (실제 인식 없음)
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => CameraResultScreen(scene: _scene, loaders: widget.loaders, onGoSearch: widget.onGoSearch),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final barcode = _mode == CameraMode.barcode;
    return Scaffold(
      backgroundColor: Gp.panel,
      body: Column(
        children: [
          // E-1 미리보기
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                final frameW = box.maxWidth * (barcode ? 0.8 : 0.72);
                final frameH = barcode ? frameW * 0.42 : frameW;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    AppImage(_scene.photo),
                    // 틀 바깥을 살짝 어둡게
                    CustomPaint(painter: _DimOutside(frameW, frameH)),
                    Center(
                      child: SizedBox(
                        width: frameW,
                        height: frameH,
                        child: CustomPaint(
                          painter: _FrameCorners(),
                          child: _analyzing
                              ? Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xEEFFFFFF),
                                      borderRadius: BorderRadius.circular(Gp.rSmall),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        MiniSpinner(size: 16, color: Gp.accent),
                                        SizedBox(width: 8),
                                        Text(
                                          'AI가 비교하는 중…', // E-4 P01
                                          style: TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                    // 위: 닫기 + 안내
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                RaisedCircleButton(
                                  tooltip: '닫기', // P03
                                  size: 40,
                                  onTap: () => Navigator.of(context).maybePop(),
                                  child: const Icon(Icons.close, size: Gp.iM, color: Gp.ink),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: Gp.glass,
                                borderRadius: BorderRadius.circular(Gp.rSmall),
                              ),
                              child: Text(
                                barcode ? '상자 뒷면 바코드를 가로 틀에 맞춰 주세요' : '상자나 실물을 네모 안에 맞춰 주세요', // P10
                                style: const TextStyle(fontSize: Gp.t12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          // 아래: 흰 조작 영역
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      UnderlineTab(
                        // E-2 P07
                        label: '사진',
                        selected: !barcode,
                        onTap: () => setState(() => _mode = CameraMode.photo),
                      ),
                      const SizedBox(width: 10),
                      UnderlineTab(
                        label: '바코드',
                        selected: barcode,
                        onTap: () => setState(() => _mode = CameraMode.barcode), // STATE: 모드 → 틀 모양
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          // 카메라를 닫은 뒤에도 쓸 수 있는 맨 바깥 화면 기준으로 앨범을 연다
                          final root = Navigator.of(context, rootNavigator: true);
                          root.pop();
                          openAlbum(root.context, loaders: widget.loaders, onGoSearch: widget.onGoSearch);
                        },
                        child: SizedBox.square(
                          dimension: 46,
                          child: PhotoThumb(albumScenes.first.photo, radius: 10), // E-5
                        ),
                      ),
                      const Spacer(),
                      RaisedCircleButton(
                        // E-3 P07
                        tooltip: '찍기',
                        size: 72,
                        onTap: _analyzing ? () {} : _shoot,
                        child: Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Gp.ink, width: 2),
                          ),
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 46),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
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
      const Radius.circular(18),
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
      // 왼쪽 위
      ..moveTo(0, l)
      ..lineTo(0, r)
      ..arcToPoint(const Offset(r, 0), radius: const Radius.circular(r))
      ..lineTo(l, 0)
      // 오른쪽 위
      ..moveTo(s.width - l, 0)
      ..lineTo(s.width - r, 0)
      ..arcToPoint(Offset(s.width, r), radius: const Radius.circular(r))
      ..lineTo(s.width, l)
      // 오른쪽 아래
      ..moveTo(s.width, s.height - l)
      ..lineTo(s.width, s.height - r)
      ..arcToPoint(Offset(s.width - r, s.height), radius: const Radius.circular(r))
      ..lineTo(s.width - l, s.height)
      // 왼쪽 아래
      ..moveTo(l, s.height)
      ..lineTo(r, s.height)
      ..arcToPoint(Offset(0, s.height - r), radius: const Radius.circular(r))
      ..lineTo(0, s.height - l);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_FrameCorners old) => false;
}

/// 찍은 결과 — 가장 닮은 상품 + 다른 후보
class CameraResultScreen extends StatefulWidget {
  const CameraResultScreen({super.key, required this.scene, required this.loaders, required this.onGoSearch});

  final CameraScene scene;
  final Loaders loaders;
  final VoidCallback onGoSearch;

  @override
  State<CameraResultScreen> createState() => _CameraResultScreenState();
}

class _CameraResultScreenState extends State<CameraResultScreen> {
  late Future<List<Kit>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    // STATE: 장면의 후보 id → GET /kits?id= → 카드
    _future = widget.loaders.kitsByIds([for (final c in widget.scene.candidates) c.$1]);
  }

  void _retake() {
    final mode = widget.scene.barcode.isEmpty ? CameraMode.photo : CameraMode.barcode;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => CameraScreen(mode: mode, loaders: widget.loaders, onGoSearch: widget.onGoSearch),
      ),
    );
  }

  void _goSearch() {
    Navigator.of(context).popUntil((r) => r.isFirst);
    widget.onGoSearch();
  }

  @override
  Widget build(BuildContext context) {
    final scene = widget.scene;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '찾은 결과',
          style: TextStyle(fontSize: Gp.t19, fontWeight: FontWeight.w600),
        ),
      ),
      body: FutureBuilder<List<Kit>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const LoadingView(label: '후보를 불러오는 중…'); // E-10 P01
          }
          if (snap.hasError) {
            return ErrorView(message: '${snap.error}', onRetry: () => setState(_load)); // P09
          }
          final byId = {for (final k in snap.data!) k.id: k};
          final found = [
            for (final (id, score, why) in scene.candidates)
              if (byId[id] case final k?) (k, score, why),
          ];
          if (found.isEmpty) {
            return EmptyView(
              // E-10 P09
              icon: Icons.image_search,
              message: '닮은 상품을 찾지 못했어요',
              detail: '밝은 곳에서 상자 앞면이 보이게 다시 찍어 보세요',
              action: OutlinedButton(onPressed: _retake, child: const Text('다시 찍기')),
            );
          }
          final (best, score, why) = found.first;
          final others = found.skip(1).toList();
          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              // 찍은 사진 + 다시 찍기
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 8, 12),
                child: Row(
                  children: [
                    SizedBox.square(dimension: 52, child: PhotoThumb(scene.photo, radius: 10)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        scene.barcode.isEmpty ? '사진과 가장 닮은 상품' : '바코드 ${scene.barcode}',
                        style: const TextStyle(color: Gp.muted),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _retake, // E-9 P03
                      icon: const Icon(Icons.photo_camera_outlined, size: Gp.iM),
                      label: const Text('다시 찍기'),
                    ),
                  ],
                ),
              ),
              // E-6 가장 닮은 상품
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Gp.panel,
                  borderRadius: BorderRadius.circular(Gp.rLarge),
                  border: Border.all(color: Gp.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GestureDetector(
                      onTap: () => openKitDetail(context, best, loaders: widget.loaders),
                      child: AspectRatio(aspectRatio: 1.25, child: PhotoThumb(best.image)),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      best.name,
                      style: const TextStyle(fontSize: Gp.t19, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      joinDot([best.line, best.series, if (best.date.length >= 4) best.date.substring(0, 4)]),
                      style: const TextStyle(color: Gp.muted, fontSize: Gp.t12),
                    ),
                    const SizedBox(height: 14),
                    _MatchBar(score: score), // P01
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, size: Gp.iS, color: Gp.accent),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            why,
                            style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
                          ), // P10
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => openKitDetail(context, best, loaders: widget.loaders), // E-7
                            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                            child: const Text('상세 보기'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TogglePill(
                            // E-7 P03 — 상세의 좋아요 버튼과 같은 부품
                            label: '좋아요',
                            icon: Icons.favorite_border,
                            activeIcon: Icons.favorite,
                            active: Marks.of(context).liked(best), // 앱 전체 한 벌
                            onTap: () => Marks.read(context).toggleLike(context, best),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (others.isNotEmpty) ...[
                const SectionHeader('다른 후보', padding: EdgeInsets.fromLTRB(16, 24, 12, 8)), // E-8
                for (final (k, s, w) in others)
                  ThumbRow(
                    image: k.image,
                    title: k.name,
                    subtitle: w,
                    onTap: () => openKitDetail(context, k, loaders: widget.loaders),
                    trailing: Text(
                      '$s%',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: Gp.muted),
                    ),
                  ),
              ],
              // E-9 못 찾았을 때
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
                child: Column(
                  children: [
                    const Text('찾는 상품이 없나요?', style: TextStyle(color: Gp.muted)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _goSearch, // P09
                          icon: const Icon(Icons.search, size: Gp.iM),
                          label: const Text('이름으로 검색'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _retake,
                          icon: const Icon(Icons.photo_camera_outlined, size: Gp.iM),
                          label: const Text('다시 찍기'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 일치도 막대 (브랜드 색)
class _MatchBar extends StatelessWidget {
  const _MatchBar({required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          '일치도',
          style: TextStyle(fontSize: Gp.t12, color: Gp.muted),
        ),
        const SizedBox(width: 10),
        Expanded(child: AccentBar(value: score / 100, height: 6)),
        const SizedBox(width: 10),
        Text(
          '$score%',
          style: const TextStyle(fontWeight: FontWeight.w700, color: Gp.accent),
        ),
      ],
    );
  }
}
