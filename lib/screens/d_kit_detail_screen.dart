// 화면 D: 상품 상세 — 공식 사진 · 정가 · 정확한 버전 · 출처, 그리고 좋아요/구매함
//
// ┌──────── 디자인 가이드 대응표: D 상품 상세 ─────────────────────────────────────────┐
// │ 번호 │ Flutter 위젯명                     │ 비즈니스 명칭(한글)                    │ 원칙(P번호)   │
// │ D-1  │ RaisedCircleButton(‹)              │ 뒤로 (보던 화면 그대로)                 │ P03           │
// │ D-2  │ PageView + 점 표시                 │ 공식 사진 (여러 장 넘기기)              │ P02 · P08     │
// │ D-4  │ 제목 + 일본어 원래 이름              │ 상품명 (공식 사이트 검색용 원문)        │ P02           │
// │ D-5  │ Text(¥) + 발매일 + 한정 표시         │ 일본 정가 · 발매 · 한정/PB              │ P02 · P01     │
// │ D-5b │ 정가 아래 시세 한 줄 → 바텀 시트      │ 정가 ↔ 국내 시세 (시세는 이 한 곳에만)   │ P01 · P08     │
// │ D-5c │ 구매함일 때 "내 구매가" 줄 → 입력 시트 │ 내가 낸 돈 기록 (한 개 값 · 동기화)      │ P01 · P03     │
// │ D-5d │ KitPhotoStrip (T-8)                │ 구매함이면 이 상품의 내 사진 + 넣기       │ P07           │
// │ D-5e │ 리본 · ♡ 아이콘 + @아이디              │ 이 상품을 가진 · 좋아요한 친구 (선물 · 겹침) │ P01 · P07   │
// │ D-6  │ 하단 고정 바: ♡ 좋아요 · 리본 구매함   │ 좋아요 · 구매함 (따로 켜고 끔, 앱 전체 한 벌) │ P03 · P04 │
// │ D-7  │ − n + (1–99)                       │ 수량: 좋아요 = 갖고 싶은 수 · 구매함 = 가진 수 │ P03 · P01 │
// │ D-8  │ 가로 스크롤 요약 줄 → 바텀 시트       │ 공식 정보 (요약 → 전체 표)              │ P08 · P06     │
// │ D-9  │ 시세 시트: 모은 시세 없음 · 플랫폼 3칸 │ 국내 시세 찾아보기 (Gunpula 에 시세 없음) │ P01 · P08   │
// │ D-10 │ 가로 ProductTile (GET /kits)        │ 같은 작품의 다른 상품                   │ P06           │
// │ D-11 │ 세로 사진 목록                      │ 상품 상세 (공식 사진 전부)              │ P02           │
// │ D-12 │ TextButton → reportDataIssue 시트   │ 정보 오류 제보 → GitHub 이슈(미리 채움)  │ P05 · P09     │
// │ D-13 │ LayoutBuilder ≥720dp                │ 넓은 화면: 사진 왼쪽 · 정보 오른쪽      │ 적응형        │
// │ D-14 │ 하단 고정 바 왼쪽: 복사 · 공식        │ 상품명 복사 · 공식 상품 페이지(출처)    │ P07 · P10     │
// └──────────────────────────────────────────────────────────────────────────────────┘
// 전환: 홈 · 검색 · 설명 후보 · 바코드에서 쌓기(push, 오른쪽에서). 공식 정보 · 시세 · 구매가 → 덮기(바텀 시트).
// 좋아요 · 구매함은 화면 아래에 고정 — 길게 내려 읽어도 바로 누를 수 있다 (쇼핑 앱 상세와 같은 위치).
// 현행 앱 문제: 상세에 내부 코드(GUNDAM_MERCH)·"보완 필요"·수동 수정 폼이 그대로 보임
//              → v2는 사용자에게 필요한 정가 · 버전 · 출처만, 수정은 "제보" 한 줄로.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../logic/friends.dart';
import '../logic/market.dart';
import '../marks.dart';
import '../detail_pane.dart';
import '../channels.dart';
import '../data/catalog.dart';
import '../sync/account.dart';
import '../data/user_store.dart';
import '../models.dart';
import '../report.dart';
import '../theme.dart';
import '../widgets.dart';
import 't_photo_screen.dart' show KitPhotoStrip;

/// 상품 상세 열기 — 폰: 오른쪽에서 밀려 들어옴 / 넓은 화면: 오른쪽 칸 (detail_pane.dart)
/// [list] 를 주면 그 목록 안에서 좌우로 밀어 이전 · 다음 상품 (최근 추가 · 좋아요 · 검색 결과 …)
void openKitDetail(BuildContext context, Kit kit, {Loaders loaders = const Loaders(), List<Kit> list = const []}) {
  final i = list.indexWhere((k) => k.id == kit.id);
  openPage(
    context,
    i < 0 || list.length < 2
        ? KitDetailScreen(kit: kit, loaders: loaders)
        : KitPager(kits: list, index: i, loaders: loaders),
    id: kit.id,
  );
}

/// 상세를 좌우로 넘기기 — 사진 넘기기(안쪽)는 사진 위에서, 상품 넘기기는 사진 밖에서
class KitPager extends StatefulWidget {
  const KitPager({super.key, required this.kits, required this.index, this.loaders = const Loaders()});
  final List<Kit> kits;
  final int index;
  final Loaders loaders;

  @override
  State<KitPager> createState() => _KitPagerState();
}

class _KitPagerState extends State<KitPager> {
  late final _controller = PageController(initialPage: widget.index);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PageView.builder(
    controller: _controller,
    itemCount: widget.kits.length,
    itemBuilder: (context, i) =>
        KitDetailScreen(key: ValueKey(widget.kits[i].id), kit: widget.kits[i], loaders: widget.loaders),
  );
}

/// 넓은 화면 기준 (사진 왼쪽 · 정보 오른쪽)
const detailWideBreakpoint = 720.0;

class KitDetailScreen extends StatefulWidget {
  const KitDetailScreen({super.key, required this.kit, this.loaders = const Loaders()});

  final Kit kit;
  final Loaders loaders;

  @override
  State<KitDetailScreen> createState() => _KitDetailScreenState();
}

class _KitDetailScreenState extends State<KitDetailScreen> {
  // 좋아요 · 구매함은 따로 켜고 끈다 (둘 다 켤 수 있음)
  // 앱 전체 한 벌(Marks)에서 읽고 바꾼다 — 홈 카드 · 컬렉션과 같이 바뀜
  bool get _wanted => Marks.of(context).liked(k);
  bool get _owned => Marks.of(context).owned(k);
  late final Future<List<Kit>> _related = widget.loaders.kits([widget.kit.franchiseId]);

  Kit get k => widget.kit;

  @override
  void initState() {
    super.initState();
    // 최근 본 상품 (홈 맨 아래 줄) — 그리는 중에 알리지 않게 다음 프레임에
    WidgetsBinding.instance.addPostFrameCallback((_) => UserStore.instance.markViewed(widget.kit.id));
  }

  /// 내가 낸 돈 (구매함일 때) — 기기에 저장, 컬렉션 지출 합계에 들어간다
  late int? _paid = switch (UserStore.instance.entry(widget.kit.id)?['purchase_price']) {
    final num v => v.toInt(),
    _ => widget.kit.purchaseKrw,
  };

  /// D-9 국내 시세 자세히 (바텀 시트) — 시세는 이 한 곳에서만 보여 준다
  void _openMarket() {
    showGpSheet<void>(
      context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionHeader('국내 시세', padding: EdgeInsets.fromLTRB(0, 0, 0, 12)),
              _MarketCard(onOpen: _external),
            ],
          ),
        ),
      ),
    );
  }

  /// D-5c 내 구매가 입력 (바텀 시트 + 숫자 칸)
  void _editPaid() {
    final ctrl = TextEditingController(text: _paid?.toString() ?? '');
    showGpSheet<void>(
      context,
      tall: true,
      builder: (sheet) => Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.viewInsetsOf(sheet).bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader('내 구매가', padding: EdgeInsets.fromLTRB(0, 0, 0, 12)),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: '예: 38000', suffixText: '원'),
            ),
            const SizedBox(height: 6),
            Text(
              '정가 ${yen(k.priceJpy)} · 컬렉션 지출 합계에 들어가요',
              style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () {
                final v = int.tryParse(ctrl.text.replaceAll(',', '').trim());
                Navigator.pop(sheet);
                final before = _paid;
                setState(() => _paid = v); // STATE: 구매가 → 줄 금액
                UserStore.instance.setPurchasePrice(k.id, v); // 보관 장소 · 메모는 그대로
                showToast(
                  context,
                  v == null ? '구매가를 지웠어요' : '구매가 ${won(v)}을 적었어요',
                  onUndo: () {
                    setState(() => _paid = before);
                    UserStore.instance.setPurchasePrice(k.id, before);
                  },
                );
              },
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
              child: const Text('적기'),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleWanted() => Marks.read(context).toggleLike(context, k); // STATE: 좋아요 (앱 전체)

  void _toggleOwned() => Marks.read(context).toggleOwn(context, k); // STATE: 구매함 (앱 전체)

  void _copy(String text, String what) {
    Clipboard.setData(ClipboardData(text: text));
    showToast(context, '$what을(를) 복사했어요');
  }

  /// 공식 상품 페이지 · 국내 시세 검색을 브라우저로
  Future<void> _external(String where) async {
    final url = where == '공식 상품 페이지' ? k.officialUrl : marketSearchUrl(where, k.name);
    if (url.isEmpty) {
      showToast(context, '공식 페이지 주소가 없는 상품이에요');
      return;
    }
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && mounted) showToast(context, '$where을(를) 열지 못했어요');
  }

  /// D-12 정보 오류 제보 — 무엇이 틀렸나 고르고 GitHub 이슈로 (lib/report.dart)
  Future<void> _report() => reportDataIssue(context, kit: k);

  /// D-7 수량 (좋아요 · 구매함일 때) — 한 번 누를 때마다 저장 (동기화 · 컬렉션 합계)
  void _setQty(int q) => Marks.read(context).store.setQuantity(k.id, q); // STATE: 수량 (UserStore → Marks 다시 그림)

  /// 공식 정보 (요약 줄과 바텀 시트가 같은 목록을 쓴다)
  List<(String, String)> get _specs => [
    ('판매', k.pb ? 'PB 한정' : (k.limited ? '한정' : '일반 판매')),
    ('분류', channelOf(k.franchiseId).label),
    ('작품', k.series),
    ('제품 라인', k.line),
    ('상품 유형', k.type),
    ('스케일', k.scale),
    ('발매', dateDot(k.date)),
    ('정가', yen(k.priceJpy)),
    ('브랜드', k.brands.join(' · ')),
    if (k.pbOpens.isNotEmpty || k.pbCloses.isNotEmpty) ('PB 예약', '${dateDot(k.pbOpens)} – ${dateDot(k.pbCloses)}'),
    ('바코드', k.jan),
  ].where((e) => e.$2.isNotEmpty).toList();

  void _openSpecs() {
    showGpSheet<void>(
      // D-8 덮기
      context,
      tall: true,
      builder: (context) => _SpecSheet(specs: _specs),
    );
  }

  List<String> get _images => k.gallery.isEmpty ? [k.image] : k.gallery;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: _BottomActions(
        // D-6 · D-14
        wanted: _wanted,
        owned: _owned,
        onWanted: _toggleWanted,
        onOwned: _toggleOwned,
        onCopy: () => _copy(k.name, '상품명'),
        onOfficial: () => _external('공식 상품 페이지'),
      ),
      body: LayoutBuilder(
        builder: (context, box) {
          final wide = box.maxWidth >= detailWideBreakpoint; // D-13
          final gallery = _Gallery(images: _images, label: k.line);
          final info = _info(context);
          return Stack(
            children: [
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ColoredBox(
                        color: Gp.panel,
                        child: SafeArea(child: Center(child: gallery)),
                      ),
                    ),
                    SizedBox(
                      width: (box.maxWidth * 0.46).clamp(360.0, 560.0),
                      child: ListView(padding: const EdgeInsets.only(top: 56), children: info),
                    ),
                  ],
                )
              else
                ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    ColoredBox(
                      color: Gp.panel,
                      child: SafeArea(bottom: false, child: gallery),
                    ),
                    ...info,
                  ],
                ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: RaisedCircleButton(
                    // D-1 P03
                    tooltip: '뒤로',
                    size: 40,
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const Icon(Icons.arrow_back_ios_new, size: Gp.iM, color: Gp.ink),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _info(BuildContext context) {
    return [
      // 기본 정보: 이름 → 정가 → 시세 한 줄
      SectionPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              k.name, // D-4 P02
              style: const TextStyle(fontSize: Gp.t19, fontWeight: FontWeight.w600, height: 1.3),
            ),
            if (k.nameJa.isNotEmpty && k.nameJa != k.name) ...[
              const SizedBox(height: 3),
              Text(
                k.nameJa,
                style: const TextStyle(fontSize: Gp.t12, color: Gp.faint),
              ),
            ],
            const SizedBox(height: 14),
            // 엔화 = 일본 정가, 원화 = 국내 시세 · 내 구매가 (섞여 보여도 무엇인지 알게)
            const Text(
              '일본 정가',
              style: TextStyle(fontSize: Gp.t12, color: Gp.muted),
            ),
            const SizedBox(height: 2),
            // 좁은 화면에서는 다음 줄로 넘어가게 (Wrap)
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 10,
              runSpacing: 6,
              children: [
                Text(
                  yen(k.priceJpy), // D-5 P02
                  style: const TextStyle(fontSize: Gp.t24, fontWeight: FontWeight.w700),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    '발매 ${dateDot(k.date)}',
                    style: const TextStyle(color: Gp.muted, fontSize: Gp.t12),
                  ),
                ),
                if (k.limited) const TagPill('한정', strong: true),
                if (k.pb) const TagPill('PB', strong: true),
              ],
            ),
            const SizedBox(height: 10),
            // D-5b 정가 바로 아래 국내 시세 — 누르면 자세히(시트)
            InkWell(
              onTap: _openMarket,
              borderRadius: BorderRadius.circular(Gp.radius),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                decoration: BoxDecoration(color: Gp.bg, borderRadius: BorderRadius.circular(Gp.radius)),
                child: Row(
                  children: [
                    const Text(
                      '국내 시세',
                      style: TextStyle(fontSize: Gp.t12, color: Gp.muted),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        '모은 시세 없음 · 찾아보기', // Gunpula 에 국내 시세가 없다 — 숫자를 지어내지 않는다
                        style: TextStyle(fontSize: Gp.t14, color: Gp.muted),
                      ),
                    ),
                    const Icon(Icons.north_east, size: Gp.iS, color: Gp.muted),
                  ],
                ),
              ),
            ),
            if (_owned || _wanted) ...[
              const SizedBox(height: 8),
              _QtyRow(
                // D-7
                owned: _owned,
                qty: Marks.of(context).store.quantityOf(k.id),
                onChanged: _setQty,
              ),
            ],
            if (_owned) ...[
              const SizedBox(height: 8),
              // D-5c 구매함이면 내가 낸 돈
              InkWell(
                onTap: _editPaid,
                borderRadius: BorderRadius.circular(Gp.radius),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Gp.radius),
                    border: Border.all(color: Gp.line),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        '내 구매가',
                        style: TextStyle(fontSize: Gp.t12, color: Gp.muted),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _paid == null
                              ? switch (Catalog.instance.listPriceKrw(widget.kit.id)) {
                                  final int w => '안 적음 · 정가로 ≈ ${won(w)}',
                                  _ => '아직 안 적었어요',
                                }
                              : won(_paid!),
                          style: TextStyle(
                            fontSize: Gp.t14,
                            fontWeight: _paid == null ? FontWeight.w400 : FontWeight.w600,
                            color: _paid == null ? Gp.muted : Gp.ink,
                          ),
                        ),
                      ),
                      Text(
                        _paid == null ? '적기' : '수정',
                        style: const TextStyle(fontSize: Gp.t12, color: Gp.accent, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              KitPhotoStrip(kitId: widget.kit.id), // D-5d 내 사진 (사진 벽에도)
            ],
            _FriendsWithKit(kitId: widget.kit.id), // D-5e 이 상품을 가진 · 좋아요한 친구
          ],
        ),
      ),
      // 공식 정보: 가로 요약 줄 → 누르면 전체 표
      SectionPanel(
        padding: EdgeInsets.zero,
        child: _SpecStrip(specs: _specs, onTap: _openSpecs), // D-8 P08
      ),
      // 같은 작품의 다른 상품
      SectionPanel(
        padding: const EdgeInsets.only(bottom: 18),
        child: FutureBuilder<List<Kit>>(
          future: _related,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox(height: 120, child: LoadingView()); // P01
            }
            if (snap.hasError) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text('관련 상품을 불러오지 못했어요', style: TextStyle(color: Gp.muted)),
              );
            }
            final same = snap.data!.where((r) => r.id != k.id && r.series == k.series).toList();
            final rest = same.isNotEmpty ? same : snap.data!.where((r) => r.id != k.id).toList();
            if (rest.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(same.isNotEmpty ? '같은 작품의 다른 상품' : '같은 채널의 다른 상품'), // D-10 P06
                SizedBox(
                  height: 148 + 32,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: rest.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, i) => ProductTile(
                      image: rest[i].image,
                      title: rest[i].name,
                      imageWidth: 148,
                      onTap: () => openKitDetail(context, rest[i], loaders: widget.loaders),
                      marks: QuickMarks(kit: rest[i]),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      // 상품 상세: 공식 사진을 세로로 전부
      SectionPanel(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader('상품 상세'), // D-11 P02
            for (final img in _images)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Gp.radius),
                  child: AppImage(img, fit: BoxFit.fitWidth, placeholder: k.line),
                ),
              ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        child: Center(
          child: TextButton.icon(
            onPressed: _report, // D-12 P09
            icon: const Icon(Icons.flag_outlined, size: Gp.iM, color: Gp.muted),
            label: const Text('정보가 틀렸나요? 제보하기', style: TextStyle(color: Gp.muted)),
          ),
        ),
      ),
    ];
  }
}

/// D-2 공식 사진 넘기기 (정사각형, 전체가 보이게 contain)
class _Gallery extends StatefulWidget {
  const _Gallery({required this.images, required this.label});
  final List<String> images;
  final String label;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _page = i), // STATE: 사진 번호 → 점
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 56, 16, 28),
              child: AppImage(widget.images[i], fit: BoxFit.contain, placeholder: widget.label),
            ),
          ),
          if (widget.images.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              child: PageDots(count: widget.images.length, index: _page),
            ),
        ],
      ),
    );
  }
}

/// D-8 공식 정보 요약 줄 — 아이콘 + (값 / 이름) 칸들이 가로로 넘어가고, 누르면 전체 표
class _SpecStrip extends StatelessWidget {
  const _SpecStrip({required this.specs, required this.onTap});
  final List<(String, String)> specs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 72,
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 16, right: 6),
              child: Icon(Icons.assignment_outlined, size: Gp.iM, color: Gp.ink),
            ),
            Expanded(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: specs.length,
                separatorBuilder: (_, _) => const VerticalDivider(width: 1, indent: 18, endIndent: 18),
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(specs[i].$2, style: const TextStyle(fontSize: Gp.t14)),
                      const SizedBox(height: 3),
                      Text(
                        specs[i].$1,
                        style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 10),
              child: Icon(Icons.chevron_right, color: Gp.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// D-8 공식 정보 전체 (바텀 시트): 위 4칸은 회색 카드 2열, 나머지는 줄
class _SpecSheet extends StatelessWidget {
  const _SpecSheet({required this.specs});
  final List<(String, String)> specs;

  @override
  Widget build(BuildContext context) {
    final top = specs.take(4).toList();
    final rest = specs.skip(4).toList();
    Widget cell((String, String) e) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            e.$1,
            style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
          ),
          const SizedBox(height: 6),
          Text(e.$2, style: const TextStyle(fontSize: Gp.t14)),
        ],
      ),
    );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                '공식 정보',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: Gp.t19, fontWeight: FontWeight.w600),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(color: Gp.bg, borderRadius: BorderRadius.circular(Gp.radius)),
              child: Column(
                children: [
                  for (var r = 0; r < top.length; r += 2)
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: cell(top[r])),
                          const VerticalDivider(width: 1, indent: 12, endIndent: 12),
                          Expanded(child: r + 1 < top.length ? cell(top[r + 1]) : const SizedBox()),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            for (final e in rest)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(e.$1, style: const TextStyle(color: Gp.muted)),
                    ),
                    Expanded(
                      child: Text(e.$2, style: const TextStyle(fontSize: Gp.t14)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// D-9 시세 카드 — Gunpula 는 국내 시세를 모으지 않는다 → 그렇다고 말하고 플랫폼 3칸(상품명 검색)으로
class _MarketCard extends StatelessWidget {
  const _MarketCard({required this.onOpen});

  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Icon(Icons.info_outline, size: Gp.iS, color: Gp.faint),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                '모은 시세가 없어요 · 상품명으로 찾아보기', // P09
                style: TextStyle(color: Gp.muted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(height: 1),
        IntrinsicHeight(
          child: Row(
            children: [
              for (final (i, p) in marketPlatforms.indexed) ...[
                if (i > 0) const VerticalDivider(width: 1, indent: 12, endIndent: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => onOpen(p),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            p,
                            style: const TextStyle(fontSize: Gp.t12, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.north_east, size: 12, color: Gp.muted),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// D-7 수량 줄: 아이콘(♡ · 리본) + − n + (1–99)
class _QtyRow extends StatelessWidget {
  const _QtyRow({required this.owned, required this.qty, required this.onChanged});
  final bool owned;
  final int qty;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget step(IconData icon, String tip, int to) => IconButton(
      tooltip: tip,
      visualDensity: VisualDensity.compact,
      onPressed: to < 1 || to > 99 ? null : () => onChanged(to),
      icon: Icon(icon, size: Gp.iM),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 2, 4, 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Gp.radius),
        border: Border.all(color: Gp.line),
      ),
      child: Row(
        children: [
          Text(
            owned ? '가진 수' : '갖고 싶은 수',
            style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
          ),
          const Spacer(),
          step(Icons.remove, '하나 빼기', qty - 1),
          SizedBox(
            width: 28,
            child: Text(
              '$qty',
              key: const ValueKey('kit-qty'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: Gp.t16, fontWeight: FontWeight.w600),
            ),
          ),
          step(Icons.add, '하나 더', qty + 1),
        ],
      ),
    );
  }
}

/// D-6 · D-14 하단 고정 바 — 왼쪽: 복사 · 공식 / 오른쪽: 좋아요 · 구매함
class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.wanted,
    required this.owned,
    required this.onWanted,
    required this.onOwned,
    required this.onCopy,
    required this.onOfficial,
  });

  final bool wanted;
  final bool owned;
  final VoidCallback onWanted;
  final VoidCallback onOwned;
  final VoidCallback onCopy;
  final VoidCallback onOfficial;

  @override
  Widget build(BuildContext context) {
    Widget small(IconData icon, String label, VoidCallback onTap) => InkResponse(
      onTap: onTap,
      radius: 28,
      child: SizedBox(
        width: 52,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: Gp.iM, color: Gp.ink),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: Gp.t11, color: Gp.muted),
            ),
          ],
        ),
      ),
    );
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Gp.panel,
        border: Border(top: BorderSide(color: Gp.line)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                small(Icons.content_copy_rounded, '복사', onCopy), // P07
                small(Icons.north_east, '공식', onOfficial), // P10 출처
                const SizedBox(width: 6),
                Expanded(
                  child: TogglePill(
                    // P03
                    label: '좋아요',
                    icon: Icons.favorite_border,
                    activeIcon: Icons.favorite,
                    active: wanted,
                    onTap: onWanted,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TogglePill(
                    label: '구매함',
                    icon: Icons.bookmark_add_outlined, // 리본 + = 구매함 (상품 사진 위 리본과 같은 모양)
                    activeIcon: Icons.bookmark_added,
                    color: Gp.own,
                    active: owned,
                    onTap: onOwned,
                  ),
                ),
                const SizedBox(width: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// D-5e 이 상품을 가진 · 좋아요한 친구 (받아 둔 친구 컬렉션에서, 없으면 아무것도 안 보인다)
class _FriendsWithKit extends StatelessWidget {
  const _FriendsWithKit({required this.kitId});
  final String kitId;

  @override
  Widget build(BuildContext context) {
    final a = AccountScope.of(context);
    if (!a.signedIn) return const SizedBox.shrink();
    final f = friendsWithKit(a.friends.collections, kitId);
    if (f.owned.isEmpty && f.liked.isEmpty) return const SizedBox.shrink();
    Widget line(Widget icon, List<String> who) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              who.map((h) => '@$h').join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
            ),
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (f.owned.isNotEmpty)
            Tooltip(
              message: '갖고 있는 친구',
              child: line(const OwnedIcon(size: Gp.iS, filled: true), f.owned),
            ),
          if (f.liked.isNotEmpty)
            Tooltip(
              message: '좋아요한 친구',
              child: line(const LikedIcon(size: Gp.iS, filled: true), f.liked),
            ),
        ],
      ),
    );
  }
}
