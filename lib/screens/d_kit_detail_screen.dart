// 화면 D: 상품 상세 — 공식 사진 · 정가 · 정확한 버전 · 출처, 그리고 좋아요/구매함
//
// ┌──────── 디자인 가이드 대응표: D 상품 상세 ─────────────────────────────────────────┐
// │ 번호 │ Flutter 위젯명                     │ 비즈니스 명칭(한글)                    │ 원칙(P번호)   │
// │ D-1  │ RaisedCircleButton(‹)              │ 뒤로 (보던 화면 그대로)                 │ P03           │
// │ D-2  │ PageView + 점 표시                 │ 공식 사진 (여러 장 넘기기)              │ P02 · P08     │
// │ D-2b │ 사진 누르기 → openImageViewer       │ 크게 보기 (확대 · 넘기기)               │ P02 · P08     │
// │ D-2c │ SoftTag "참고 그림 · 같은 기체"       │ 공식 사진이 없는 상품 — 같은 기체 상품 사진  │ P02 · P09     │
// │ D-2d │ BrokenImages.keep                  │ 열리지 않는 사진은 빼기 (장 · 점 함께)    │ P09           │
// │ D-4  │ 제목 + 일본어 원래 이름              │ 상품명 (공식 사이트 검색용 원문)        │ P02           │
// │ D-5  │ Text(₩ · ¥) + 발매일 + 한정 표시     │ 한국 · 일본 정가 · 발매 · 한정/PB        │ P02 · P01     │
// │ D-5i │ 둘째 정가 줄 + ↗ (짝 상품만)          │ 같은 바코드의 다른 나라 정가 · 각 가게 페이지 │ P02 · P10   │
// │ D-5a │ Wrap(ChipButton …) 정가 아래 한 줄   │ 아직 적은 것이 없는 줄 대신 작은 버튼: 시세 찾아보기 · 예약 적기 · 구매가 적기 │ P08 · P07 │
// │ D-5b │ ChipButton(show_chart) → 바텀 시트 │ 국내 시세 찾아보기 (시세는 이 한 곳에만 · ↗ 는 공식 · 바깥 링크만) │ P01 · P08 │
// │ D-5c │ 구매함: 적었으면 "내 구매가" 줄, 아니면 칩 → 입력 시트 │ 내가 낸 돈 기록 (한 개 값 · 동기화 · 정가 ≈ 어림은 시트 안) │ P01 · P03 │
// │ D-5d │ KitPhotoStrip (T-8)                │ 구매함이면 이 상품의 내 사진 + 넣기       │ P07           │
// │ D-5e │ 리본 · ♡ 아이콘 + @아이디              │ 이 상품을 가진 · 좋아요한 친구 (선물 · 겹침) │ P01 · P07   │
// │ D-5f │ BuildStatusRow (단계 3칸 + 붓)        │ 조립 상태: 미조립 · 조립 중 · 완성 + 도색 (구매함) │ P01 · P03 │
// │ D-5g │ 적었으면 PreorderRow, 아니면 칩 → 예약 시트 · 📥 도착 │ 예약: 가게 · 낸 돈 · 결제 · 도착 예정 → 구매함으로 │ P01 · P03 │
// │ D-5h │ SoftTag 재판매 + 재판매 줄(날짜 · ↗)  │ 재판매(再販) 소식 (restocks.json, 없으면 숨김) │ P01 · P10   │
// │ D-6  │ 하단 고정 바: ♡ 좋아요 · 리본 구매함   │ 좋아요 · 구매함 (따로 켜고 끔, 앱 전체 한 벌) │ P03 · P04 │
// │ D-7  │ − n + (1–99)                       │ 수량: 좋아요 = 갖고 싶은 수 · 구매함 = 가진 수 │ P03 · P01 │
// │ D-8  │ 가로 스크롤 요약 줄 → 바텀 시트       │ 공식 정보 (요약 → 전체 표)              │ P08 · P06     │
// │ D-9  │ 시세 시트: 모은 시세 없음 · 플랫폼 3칸 │ 국내 시세 찾아보기 (Gunpula 에 시세 없음) │ P01 · P08   │
// │ D-10 │ 가로 ProductTile                   │ 같은 작품의 다른 상품                   │ P06           │
// │ D-11 │ 세로 사진 목록                      │ 상품 상세 (공식 사진 전부)              │ P02           │
// │ D-12 │ TextButton → reportDataIssue 시트   │ 정보 오류 제보 → GitHub 이슈(미리 채움)  │ P05 · P09     │
// │ D-13 │ LayoutBuilder ≥720dp                │ 넓은 화면: 사진 왼쪽 · 정보 오른쪽      │ 적응형        │
// │ D-14 │ 하단 고정 바 왼쪽: 복사 · 공식        │ 상품명 복사 · 공식 상품 페이지(출처)    │ P07 · P10     │
// │ D-15 │ 오른쪽 위 ? (뒤로 맞은편, 떠 있는 원) │ 아이콘 뜻 한 줄씩 (♡ · 리본 · 수량 · 제보) │ P10        │
// │ D-16 │ _GuideLink 줄 (기체 그림 · 이름 ›)    │ 도감에서 보기 → 그 작품 도감의 기체 시트   │ P07 · P06     │
// │ D-18 │ 오른쪽 위 공유 (떠 있는 원)           │ 이 상품 링크 보내기 → 앱이 있으면 상세로   │ P07           │
// │ D-17 │ _ManualLink 줄 (책 아이콘 · ›)        │ 공식 조립 설명서 → X 화면 (있는 상품만)   │ P10 · P07     │
// └──────────────────────────────────────────────────────────────────────────────────┘
// 전환: 홈 · 검색 · 설명 후보 · 바코드에서 쌓기(push, 오른쪽에서). 공식 정보 · 시세 · 구매가 → 덮기(바텀 시트).
// 좋아요 · 구매함은 화면 아래에 고정 — 길게 내려 읽어도 바로 누를 수 있다 (쇼핑 앱 상세와 같은 위치).
// 왜 이렇게: 내부 코드(GUNDAM_MERCH) · "보완 필요" · 수정 폼은 보이지 않게 — 정가 · 버전 · 출처만, 고칠 것은 "제보" 한 줄로.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../logic/build_status.dart' show needsAssembly;
import '../logic/friends.dart';
import '../logic/kit_link.dart';
import '../logic/kit_rules.dart' show kitPrice, shopUrl;
import '../logic/market.dart';
import '../logic/restock.dart';
import '../marks.dart';
import '../detail_pane.dart';
import '../channels.dart';
import '../l10n/l10n.dart';
import '../data/catalog.dart';
import '../sync/account.dart';
import '../data/user_store.dart';
import '../models.dart';
import '../report.dart';
import '../theme.dart';
import '../widgets.dart';
import 'guide/guide_search.dart' show openUnitInGuide;
import 't_photo_screen.dart' show KitPhotoStrip;
import 'x_manual_screen.dart' show openManual;

/// 상품 상세 열기 — 폰: 오른쪽에서 밀려 들어옴 / 넓은 화면: 오른쪽 칸 (detail_pane.dart)
/// [list] 를 주면 그 목록 안에서 좌우로 밀어 이전 · 다음 상품 (최근 추가 · 좋아요 · 검색 결과 …)
/// 한국 · 일본 짝 중 내 기록(좋아요 · 구매함)이 다른 쪽에 있으면 그쪽 상세를 연다 — 수량 · 구매가 · 예약 · 사진이
/// 그 id 에 붙어 있어서 (lib/marks.dart holderId)
void openKitDetail(BuildContext context, Kit kit, {Loaders loaders = const Loaders(), List<Kit> list = const []}) {
  final holder = Marks.maybeRead(context)?.holderId(kit) ?? kit.id;
  if (holder != kit.id) {
    if (Catalog.instance.byId[holder] case final h?) {
      list = [for (final k in list) k.id == kit.id ? h : k];
      kit = h;
    }
  }
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

/// 상세 정가 한 줄: 이름(한국 정가) · 짧은 이름(한국) · ₩ · ¥ 값 · 그 나라 가게 주소 · 테스트 열쇠(kr · jp)
typedef _PriceLine = ({String label, String short, String price, String url, String key});

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

  /// D-5h 이 상품의 재판매 소식 (파일이 없으면 빈 목록 → 칸 숨김)
  List<RestockEvent> _restocks = const [];

  @override
  void initState() {
    super.initState();
    // 최근 본 상품 (홈 맨 아래 줄) — 그리는 중에 알리지 않게 다음 프레임에
    WidgetsBinding.instance.addPostFrameCallback((_) => UserStore.instance.markViewed(widget.kit.id));
    widget.loaders.restocks().then((r) {
      if (mounted && r.of(k.id).isNotEmpty) setState(() => _restocks = r.of(k.id)); // STATE: 재판매 소식 → 꼬리표 · 줄
    }, onError: (Object _) {});
  }

  Future<void> _openUrl(String url) async {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && mounted) showToast(context, tr('열지 못했어요'));
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
              SectionHeader(tr('국내 시세'), padding: const EdgeInsets.fromLTRB(0, 0, 0, 12)),
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
            SectionHeader(tr('내 구매가'), padding: const EdgeInsets.fromLTRB(0, 0, 0, 12)),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              // 안 적은 동안 지출 합계에 들어가는 어림값 (정가 × 환율) — 상세 줄에서 빼고 여기에만
              decoration: InputDecoration(
                hintText: switch (Catalog.instance.listPriceKrw(k.id)) {
                  final int w => trf('정가로 ≈ {price}', {'price': won(w)}),
                  _ => tr('예: 38000'),
                },
                suffixText: tr('원'),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              trf('정가 {price} · 컬렉션 지출 합계에 들어가요', {'price': kitPrice(k)}),
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
                  v == null ? tr('구매가를 지웠어요') : trf('구매가 {price}을 적었어요', {'price': won(v)}),
                  onUndo: () {
                    setState(() => _paid = before);
                    UserStore.instance.setPurchasePrice(k.id, before);
                  },
                );
              },
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
              child: Text(tr('적기')),
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
    showToast(context, trf('{what}을(를) 복사했어요', {'what': what}));
  }

  /// 공식 상품 페이지 · 국내 시세 검색을 브라우저로. [url] 을 주면 그 주소 (짝 상품의 다른 나라 가게)
  Future<void> _external(String where, {String? url}) async {
    url ??= where == '공식 상품 페이지'
        ? k.officialUrl
        : marketSearchUrl(where, marketSearchName(nameKo: k.nameKo, nameJa: k.nameJa));
    if (url.isEmpty) {
      showToast(context, tr('공식 페이지 주소가 없는 상품이에요'));
      return;
    }
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && mounted) showToast(context, trf('{where}을(를) 열지 못했어요', {'where': tr(where)}));
  }

  /// D-5 · D-5i 정가 줄 — 그 나라 돈 그대로 (₩ 한국 · ¥ 일본, 환산하지 않음). 상품 나라의 정가가 먼저 크게.
  /// 짝 상품(같은 바코드)은 둘째 나라 정가도 작게, 줄마다 ↗ 로 그 나라 가게 페이지
  List<_PriceLine> get _priceLines {
    final twin = Catalog.instance.byId[k.twinId];
    final jp = k.region == 'jp';
    // 두 나라 출처 상품(both)은 제 주소 안에 두 나라 가게가 다 있다
    final krSide = jp ? twin : k;
    final jpSide = jp || k.region == 'both' ? k : twin;
    final lines = [
      if (k.priceKrw case final w?)
        (
          label: '한국 정가',
          short: '한국',
          price: wonSign(w),
          url: krSide == null ? '' : shopUrl(krSide, kr: true),
          key: 'kr',
        ),
      if (k.priceJpy case final p?)
        (label: '일본 정가', short: '일본', price: yen(p), url: jpSide == null ? '' : shopUrl(jpSide, kr: false), key: 'jp'),
    ];
    if (lines.isEmpty) {
      return [(label: k.region == 'kr' ? '한국 정가' : '일본 정가', short: '', price: tr('가격 미정'), url: '', key: '')];
    }
    return jp ? lines.reversed.toList() : lines;
  }

  /// D-12 정보 오류 제보 — 무엇이 틀렸나 고르고 GitHub 이슈로 (lib/report.dart)
  Future<void> _report() => reportDataIssue(context, kit: k);

  /// D-7 수량 (좋아요 · 구매함일 때) — 한 번 누를 때마다 저장 (동기화 · 컬렉션 합계)
  void _setQty(int q) => Marks.read(context).store.setQuantity(k.id, q); // STATE: 수량 (UserStore → Marks 다시 그림)

  /// 공식 정보 (요약 줄과 바텀 시트가 같은 목록을 쓴다)
  List<(String, String)> get _specs => [
    (tr('판매'), k.pb ? tr('PB 한정') : (k.limited ? tr('한정') : tr('일반 판매'))),
    (tr('분류'), tr(channelOf(k.franchiseId).label)),
    (tr('작품'), k.seriesLabel),
    (tr('제품 라인'), tr(k.line)),
    (tr('상품 유형'), tr(k.type)),
    (tr('스케일'), k.scale),
    (tr('발매'), dateDot(k.date)),
    (tr('정가'), kitPrice(k)),
    (tr('브랜드'), k.brands.map(tr).join(' · ')),
    if (k.pbOpens.isNotEmpty || k.pbCloses.isNotEmpty) (tr('PB 예약'), '${dateDot(k.pbOpens)} – ${dateDot(k.pbCloses)}'),
    (tr('바코드'), k.jan),
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
        onCopy: () => _copy(k.name, tr('상품명')),
        onOfficial: () => _external('공식 상품 페이지'),
      ),
      body: LayoutBuilder(
        builder: (context, box) {
          final wide = box.maxWidth >= detailWideBreakpoint; // D-13
          // D-2 · D-2b · D-2c · D-2d (예고 상품 소개 J-8 과 같은 사진 넘기기)
          final gallery = ImagePager(images: _images, label: tr(k.line), reference: k.imageRef);
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
                    tooltip: tr('뒤로'),
                    size: 40,
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const Icon(Icons.arrow_back_ios_new, size: Gp.iM, color: Gp.ink),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        RaisedCircleButton(
                          // D-18 P07
                          key: const ValueKey('share-kit'),
                          tooltip: tr('공유'),
                          size: 40,
                          onTap: _share,
                          child: const Icon(Icons.share_outlined, size: Gp.iM, color: Gp.ink),
                        ),
                        const SizedBox(width: 8),
                        HelpButton(title: tr('상품 상세'), items: detailHelp, raised: true), // D-15
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// D-18 이 상품 링크 보내기 — 받은 사람이 Hobby Atlas 가 있으면 이 상세로, 없으면 Gunpula 웹에서
  Future<void> _share() async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: kitShareText(name: k.name, kitId: k.id),
          subject: k.name,
        ),
      );
    } on Object {
      if (mounted) showToast(context, tr('공유하지 못했어요'));
    }
  }

  /// ↗ 그 나라 가게의 상품 페이지 (주소가 없으면 자리만)
  Widget _shopLink(_PriceLine p) => p.url.isEmpty
      ? const SizedBox(width: 8)
      : InkWell(
          key: ValueKey('price-link-${p.key}'),
          borderRadius: BorderRadius.circular(Gp.rSmall),
          onTap: () => _external('공식 상품 페이지', url: p.url),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(Icons.north_east, size: Gp.iS, color: Gp.muted, semanticLabel: tr('공식 상품 페이지')),
          ),
        );

  List<Widget> _info(BuildContext context) {
    final hasPreorder = Marks.of(context).store.preorderOf(k.id) != null;
    final prices = _priceLines;
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
            // 정가 = ₩ · ¥ 기호, 내 구매가 · 시세 = "…원" (섞여 보여도 무엇인지 알게)
            Text(
              tr(prices.first.label),
              style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
            ),
            const SizedBox(height: 2),
            // 좁은 화면에서는 다음 줄로 넘어가게 (Wrap)
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 10,
              runSpacing: 6,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      prices.first.price, // D-5 P02
                      style: const TextStyle(fontSize: Gp.t24, fontWeight: FontWeight.w700),
                    ),
                    if (prices.length > 1) _shopLink(prices.first),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    trf('발매 {date}', {'date': dateDot(k.date)}),
                    style: const TextStyle(color: Gp.muted, fontSize: Gp.t12),
                  ),
                ),
                if (k.limited) TagPill(tr('한정'), strong: true),
                if (k.pb) const TagPill('PB', strong: true),
                if (_restocks.any((e) => !e.quiet)) SoftTag(tr('재판매'), color: Gp.resale), // D-5h
              ],
            ),
            // D-5i 짝 상품의 다른 나라 정가 (한국 상품이면 "일본 ¥1,650 ↗")
            for (final p in prices.skip(1))
              Row(
                children: [
                  Text(
                    '${tr(p.short)} ${p.price}',
                    style: const TextStyle(fontSize: Gp.t14, color: Gp.muted),
                  ),
                  _shopLink(p),
                ],
              ),
            const SizedBox(height: 10),
            // 아직 적은 것이 없는 줄은 작은 버튼 한 줄로 (빈 줄 셋이 정가 아래를 회색 칸으로 채웠다), 적으면 그 줄이 나온다
            Wrap(
              key: const ValueKey('detail-chips'),
              spacing: 8,
              runSpacing: 8,
              children: [
                // D-5b 국내 시세 — Gunpula 에 모은 시세가 없어 늘 찾아보기 (숫자를 지어내지 않는다). 모은 시세가 생기면 그 줄로
                ChipButton(
                  key: const ValueKey('chip-market'),
                  icon: marketIcon,
                  label: tr('시세 찾아보기'),
                  onTap: _openMarket,
                ),
                if (!_owned && !hasPreorder)
                  ChipButton(
                    // D-5g
                    key: const ValueKey('chip-preorder'),
                    icon: preorderIcon,
                    color: Gp.reserve,
                    label: tr('예약 적기'),
                    onTap: () => showPreorderSheet(context, k),
                  ),
                if (_owned && _paid == null)
                  ChipButton(
                    // D-5c 정가로 어림한 값은 시트 안 입력칸에
                    key: const ValueKey('chip-paid'),
                    icon: paidIcon,
                    color: Gp.own,
                    label: tr('구매가 적기'),
                    onTap: _editPaid,
                  ),
              ],
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
            if (!_owned && hasPreorder) ...[
              const SizedBox(height: 8),
              PreorderRow(kit: k), // D-5g 예약 (좋아요와 구매함 사이)
            ],
            if (_owned) ...[
              if (_paid case final paid?) ...[
                const SizedBox(height: 8),
                // D-5c 구매함이면 내가 낸 돈
                InkWell(
                  key: const ValueKey('paid-row'),
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
                        const Icon(paidIcon, size: Gp.iS, color: Gp.own),
                        const SizedBox(width: 8),
                        Text(
                          tr('내 구매가'),
                          style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            won(paid),
                            style: const TextStyle(fontSize: Gp.t14, fontWeight: FontWeight.w600, color: Gp.ink),
                          ),
                        ),
                        Text(
                          tr('수정'),
                          style: const TextStyle(fontSize: Gp.t12, color: Gp.accent, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              if (needsAssembly(widget.kit)) ...[
                BuildStatusRow(kitId: widget.kit.id), // D-5f 조립 상태 (조립하는 상품만)
                const SizedBox(height: 8),
              ],
              KitPhotoStrip(kitId: widget.kit.id), // D-5d 내 사진 (사진 벽에도)
            ],
            _FriendsWithKit(kitId: widget.kit.id), // D-5e 이 상품을 가진 · 좋아요한 친구
            if (_restocks.isNotEmpty) _RestockList(events: _restocks, onOpen: _openUrl), // D-5h
          ],
        ),
      ),
      // 공식 정보: 가로 요약 줄 → 누르면 전체 표
      SectionPanel(
        padding: EdgeInsets.zero,
        child: _SpecStrip(specs: _specs, onTap: _openSpecs), // D-8 P08
      ),
      if (k.franchiseId == 'gundam') _GuideLink(kit: k, loaders: widget.loaders), // D-16
      if (k.manualId > 0) _ManualLink(kit: k), // D-17
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
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text(tr('관련 상품을 불러오지 못했어요'), style: const TextStyle(color: Gp.muted)),
              );
            }
            // 이 상품 · 그 짝(같은 상품의 다른 나라 쪽)은 빼고
            bool other(Kit r) => r.id != k.id && r.id != k.twinId;
            final same = snap.data!.where((r) => other(r) && r.series == k.series).toList();
            final rest = same.isNotEmpty ? same : snap.data!.where(other).toList();
            if (rest.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(same.isNotEmpty ? tr('같은 작품의 다른 상품') : tr('같은 채널의 다른 상품')), // D-10 P06
                SizedBox(
                  height: 148 + 32,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: Gp.gutter),
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
            SectionHeader(tr('상품 상세')), // D-11 P02
            for (final img in _images)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Gp.radius),
                  child: AppImage(img, fit: BoxFit.fitWidth, placeholder: tr(k.line)),
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
            label: Text(tr('정보가 틀렸나요? 제보하기'), style: const TextStyle(color: Gp.muted)),
          ),
        ),
      ),
    ];
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
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                tr('공식 정보'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: Gp.t19, fontWeight: FontWeight.w600),
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
        Row(
          children: [
            const Icon(Icons.info_outline, size: Gp.iS, color: Gp.faint),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                tr('모은 시세가 없어요 · 상품명으로 찾아보기'), // P09
                style: const TextStyle(color: Gp.muted),
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
                            tr(p), // p 는 시세 검색 주소를 고르는 값 — 보이는 곳에서만 번역
                            style: const TextStyle(fontSize: Gp.t12, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.north_east, size: Gp.iXS, color: Gp.muted),
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
            owned ? tr('가진 수') : tr('갖고 싶은 수'),
            style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
          ),
          const Spacer(),
          step(Icons.remove, tr('하나 빼기'), qty - 1),
          SizedBox(
            width: 28,
            child: Text(
              '$qty',
              key: const ValueKey('kit-qty'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: Gp.t16, fontWeight: FontWeight.w600),
            ),
          ),
          step(Icons.add, tr('하나 더'), qty + 1),
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
                small(Icons.content_copy_rounded, tr('복사'), onCopy), // P07
                small(Icons.north_east, tr('공식'), onOfficial), // P10 출처
                const SizedBox(width: 6),
                Expanded(
                  child: TogglePill(
                    // P03
                    label: tr('좋아요'),
                    icon: Icons.favorite_border,
                    activeIcon: Icons.favorite,
                    active: wanted,
                    onTap: onWanted,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TogglePill(
                    label: tr('구매함'),
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

/// D-5h 재판매 소식 줄 — 날짜 · 종류 · 출처(↗). 지난 것(quiet)은 옅게
class _RestockList extends StatelessWidget {
  const _RestockList({required this.events, required this.onOpen});
  final List<RestockEvent> events;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Column(
      key: const ValueKey('restock-list'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final e in events)
          InkWell(
            onTap: e.sourceUrl.isEmpty ? null : () => onOpen(e.sourceUrl),
            borderRadius: BorderRadius.circular(Gp.rSmall),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Icon(restockIcon, size: Gp.iS, color: e.quiet ? Gp.faint : Gp.resale),
                  const SizedBox(width: 8),
                  Text(
                    e.dateEstimated ? trf('{date} 쯤', {'date': dateDot(e.date)}) : dateDot(e.date),
                    style: TextStyle(fontSize: Gp.t14, fontWeight: FontWeight.w600, color: e.quiet ? Gp.faint : Gp.ink),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr(e.label),
                      style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
                    ),
                  ),
                  if (e.sourceUrl.isNotEmpty) const Icon(Icons.north_east, size: Gp.iXS, color: Gp.muted),
                ],
              ),
            ),
          ),
      ],
    ),
  );
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
              message: tr('갖고 있는 친구'),
              child: line(const OwnedIcon(size: Gp.iS, filled: true), f.owned),
            ),
          if (f.liked.isNotEmpty)
            Tooltip(
              message: tr('좋아요한 친구'),
              child: line(const LikedIcon(size: Gp.iS, filled: true), f.liked),
            ),
        ],
      ),
    );
  }
}

/// D-16 도감에서 보기 — 이 상품의 대표 기체 → 그 작품 도감의 기체 시트 (기체가 없으면 아무것도 안 보인다)
class _GuideLink extends StatefulWidget {
  const _GuideLink({required this.kit, required this.loaders});
  final Kit kit;
  final Loaders loaders;

  @override
  State<_GuideLink> createState() => _GuideLinkState();
}

class _GuideLinkState extends State<_GuideLink> {
  late final Future<GuideIndex> _index = widget.loaders.guideIndex().catchError((Object _) => GuideIndex.empty);

  @override
  Widget build(BuildContext context) => FutureBuilder<GuideIndex>(
    future: _index,
    builder: (context, snap) {
      final index = snap.data;
      final u = index?.unitOf(widget.kit.id);
      if (index == null || u == null || index.work(u.workId) == null) return const SizedBox.shrink();
      return SectionPanel(
        padding: EdgeInsets.zero,
        child: ThumbRow(
          key: const ValueKey('guide-link'),
          image: u.image,
          title: tr('도감에서 보기'),
          subtitle: joinDot([u.name, index.work(u.workId)!.name]),
          size: 44,
          trailing: const Icon(Icons.chevron_right, size: Gp.iM, color: Gp.muted),
          onTap: () => openUnitInGuide(context, index, u.id, loaders: widget.loaders),
        ),
      );
    },
  );
}

/// D-17 공식 조립 설명서 — 반다이 설명서 사이트에 이 상품의 설명서가 있을 때만
class _ManualLink extends StatelessWidget {
  const _ManualLink({required this.kit});
  final Kit kit;

  @override
  Widget build(BuildContext context) => SectionPanel(
    padding: EdgeInsets.zero,
    child: InkWell(
      key: const ValueKey('manual-link'),
      onTap: () => openManual(context, id: kit.manualId, kitName: kit.name),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const Icon(Icons.menu_book_outlined, size: Gp.iM, color: Gp.ink),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('조립 설명서'),
                    style: const TextStyle(fontSize: Gp.t14, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    tr('BANDAI HOBBY 공식'),
                    style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: Gp.iM, color: Gp.muted),
          ],
        ),
      ),
    ),
  );
}

/// D-15 ? 도움말 — 열 때마다 만든다 (고른 언어를 따라가게)
List<HelpItem> get detailHelp => [
  HelpItem(Icons.favorite_border, tr('좋아요 (갖고 싶은 것)')),
  HelpItem(Icons.bookmark_add_outlined, tr('구매함 (가진 것)'), color: Gp.own),
  HelpItem(Icons.add, tr('수량 (좋아요 = 갖고 싶은 수 · 구매함 = 가진 수)')),
  HelpItem(Icons.content_copy_rounded, tr('상품명 복사')),
  HelpItem(Icons.share_outlined, tr('이 상품 보내기 (받은 사람이 앱에서 바로 열기)')),
  HelpItem(Icons.north_east, tr('공식 상품 페이지')),
  HelpItem(marketIcon, tr('국내 시세 찾아보기'), color: Gp.accent),
  HelpItem(paidIcon, tr('내 구매가 (구매함)'), color: Gp.own),
  HelpItem(Icons.assignment_outlined, tr('공식 정보 전체')),
  HelpItem(Icons.menu_book_outlined, tr('공식 조립 설명서 (있는 상품만)')),
  HelpItem(Icons.flag_outlined, tr('정보 오류 제보')),
  HelpItem(Icons.add_a_photo_outlined, tr('내 사진 넣기 (구매함)')),
  ...kitProgressHelp(restock: true),
];
