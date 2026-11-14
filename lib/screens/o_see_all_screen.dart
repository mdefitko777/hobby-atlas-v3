// 화면 O: 전체 목록 — 새 화면을 쌓지 않고 탭 안에서 바뀌는 보기
// 홈: 가로 줄 › (최근 추가 · 10월 발매 · 공식 예고 · 최근 본) → 홈 머리(아바타 · 채널 바 · 검색창) 아래만 이 목록.
// 검색: 검색 결과 · "전체 상품 둘러보기"도 같은 목록 (설명 후보는 맨 위 머리로).
// 홈 줄은 사진과 이름만(P08), 여기서는 가격 · 발매일까지 보이고, 오른쪽에서 나오는 필터 패널로 거른다.
//
// ┌──────── 디자인 가이드 대응표: O 전체 목록 ─────────────────────────────────────────┐
// │ 번호 │ Flutter 위젯명                     │ 비즈니스 명칭(한글)                    │ 원칙(P번호)   │
// │ O-1  │ ‹ + 제목 · 필터 · 보기 전환          │ 어느 목록인지 · 돌아가기 · 격자/목록     │ P03 · P07     │
// │ O-2  │ 아래 시트(60%) · 네모 세그먼트 · 체크 2열 · 펼치는 줄 │ 필터: 내 상태 · 발매 · 판매 · 종류 · 라인 · 작품 · 가격 (lib/widgets/kit_filter_sheet.dart) │ P06 · P08 · P01 · P05 │
// │ O-3  │ 고른 필터 한 줄 + showPickSheet      │ 지금 거르는 조건 · 정렬 4가지 (아래 시트)  │ P01 · P07     │
// │ O-4  │ 격자 ProductTile(+ ♡) / ThumbRow     │ 상품 (정가 ₩ · ¥ · 발매일 보임) → D 상세  │ P08 · P07     │
// │ O-5  │ 밑줄 탭 + 16:9 카드 (AnnTag)         │ 예고: 공식 발표 · 상품화 확정 · 예약(열리는 때 · 날) · 비공식(있을 때만) · 라이브(곧 할 것이 맨 앞) │ P02 · P06 │
// │ O-6  │ 기록 지우기 → showDialog → 토스트     │ 최근 본 기록 비우기 (기기 기록 · 되돌리기)  │ P05 · P03     │
// │ O-7  │ 위 검색창 (이 목록 안에서만 찾기)      │ "최근 추가에서 찾기"                     │ P07 · P04     │
// │ O-8  │ EmptyView                          │ 거른 결과 · 찾은 결과 없음 · 기록 없음     │ P09           │
// └──────────────────────────────────────────────────────────────────────────────────┘
// 전환: 탭 안에서 바뀜(쌓지 않음) — ‹ 또는 뒤로 가기로 원래 화면. 칸 → 상세 쌓기. 필터 → 아래에서 덮기.
// 데이터는 부모 화면이 받은 목록을 그대로 쓴다(다시 받지 않음).
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../api.dart';
import '../data/catalog.dart';
import '../logic/announcement_match.dart';
import '../logic/kit_rules.dart';
import '../logic/preorder_open.dart' show annShownDay;
import '../marks.dart';
import '../channels.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'd_kit_detail_screen.dart';
import 'j_announcement_screen.dart';

/// 홈에서 펼칠 수 있는 목록
enum HomeSection { recent, month, announcements, viewed }

enum KitSort { newest, release, priceLow, priceHigh }

extension on KitSort {
  String get label => switch (this) {
    KitSort.newest => tr('최신순'),
    KitSort.release => tr('발매일순'),
    KitSort.priceLow => tr('가격 낮은순'),
    KitSort.priceHigh => tr('가격 높은순'),
  };
}

/// 목록의 필터 · 격자/목록 — 위 검색창 줄의 아이콘(ListToolIcons)이 바꾼다 (홈 전체 목록 · 검색 결과)
class ListTools extends ChangeNotifier {
  KitFilter filter = KitFilter();
  bool grid = true;

  void setFilter(KitFilter f) {
    filter = f;
    notifyListeners();
  }

  void setGrid(bool g) {
    grid = g;
    notifyListeners();
  }
}

/// 검색창 줄 오른쪽 세 칸: 필터 · 격자 · 목록. [pool] = 필터 시트가 개수를 세는 상품 (null 이면 필터 없음 = 옅게)
class ListToolIcons extends StatelessWidget {
  const ListToolIcons({super.key, required this.tools, required this.pool});
  final ListTools tools;
  final List<Kit>? pool;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: tools,
    builder: (context, _) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilterButton(
          count: tools.filter.count,
          onTap: pool == null
              ? null
              : () async {
                  final picked = await pickKitFilter(context, pool: pool!, current: tools.filter);
                  if (picked != null) tools.setFilter(picked); // STATE: 필터 → 목록
                },
        ),
        ViewIconToggle(
          mine: !tools.grid,
          onChanged: (list) => tools.setGrid(!list), // STATE: 보기 방식
          allIcon: Icons.grid_view_outlined,
          mineIcon: Icons.view_list_outlined,
          allTip: tr('격자로 보기'),
          mineTip: tr('목록으로 보기'),
        ),
      ],
    ),
  );
}

class SectionListView extends StatefulWidget {
  const SectionListView({
    super.key,
    required this.title,
    this.onBack,
    this.subtitle = '',
    this.kits = const [],
    this.announcements,
    this.history = false,
    this.sort = KitSort.newest,
    this.query = '',
    this.header,
    this.tools,
    this.titleRow = true,
    this.loaders = const Loaders(),
  });

  /// false = 맨 위 제목 줄(O-1)을 숨긴다 — 제목이 AppBar 에 있는 화면 (검색 탭 분류 상품 B-23)
  final bool titleRow;

  /// 있으면 필터 · 격자/목록은 위 검색창 줄이 바꾼다 (이 목록 머리에서는 숨김)
  final ListTools? tools;

  final String title;

  /// 없으면 ‹ 를 숨긴다 (검색 탭 기본 목록)
  final VoidCallback? onBack;
  final String subtitle;
  final List<Kit> kits;

  /// 있으면 예고 목록 (공식 · 비공식)
  final List<Announcement>? announcements;

  /// 최근 본 기록 (지우기 버튼)
  final bool history;
  final KitSort sort;

  /// 위 검색창 글자 — 이 목록 안에서만 거른다 (O-7)
  final String query;

  /// 격자 위에 함께 스크롤되는 머리 (검색의 설명 후보)
  final Widget? header;
  final Loaders loaders;

  @override
  State<SectionListView> createState() => _SectionListViewState();
}

class _SectionListViewState extends State<SectionListView> {
  late KitSort _sort = widget.sort;
  KitFilter _ownFilter = KitFilter();
  bool _ownGrid = true;
  List<Kit> _cleared = const []; // 최근 본: 지운 기록

  // 위 검색창 줄이 갖고 있으면 그쪽 값 (ListTools)
  KitFilter get _filter => widget.tools?.filter ?? _ownFilter;
  set _filter(KitFilter f) => widget.tools == null ? _ownFilter = f : widget.tools!.setFilter(f);
  bool get _grid => widget.tools?.grid ?? _ownGrid;
  set _grid(bool g) => widget.tools == null ? _ownGrid = g : widget.tools!.setGrid(g);

  void _onTools() => setState(() {});

  @override
  void initState() {
    super.initState();
    widget.tools?.addListener(_onTools);
  }

  @override
  void didUpdateWidget(SectionListView old) {
    super.didUpdateWidget(old);
    if (old.tools != widget.tools) {
      old.tools?.removeListener(_onTools);
      widget.tools?.addListener(_onTools);
    }
  }

  @override
  void dispose() {
    widget.tools?.removeListener(_onTools);
    super.dispose();
  }

  /// 예고 목록 탭: '' 전체 · 단계 글 · 비공식 (lib/logic/announcement_match.dart announcementTabs)
  String _annTab = '';

  /// 한국 · 일본 짝이 둘 다 들었으면 한 카드만 (도감 묶음 · 받은 id 목록은 둘 다 가질 수 있다)
  List<Kit> get _kits => mergeTwins([
    for (final k in widget.kits)
      if (!_cleared.contains(k)) k,
  ]);

  /// 지금 보이는 목록 (상세에서 좌우로 넘길 때 같은 순서)
  List<Kit> _shown = const [];

  List<Kit> _visibleKits() {
    _filter.statusOf = Marks.of(context).statusOf; // 좋아요 · 구매함으로 거르기
    // 한 나라만 보면 짝 상품은 그 나라 쪽으로 (일본 = 일본 포켓몬센터 상품, 정가 ¥ 먼저)
    final byId = Catalog.instance.byId;
    final list = [
      for (final k in _kits)
        if (_filter.matches(k) && kitMatches(k, widget.query)) _filter.region.shownIn(k, byId),
    ];
    // 가격순: 고른 돈(없으면 원)의 정가로 먼저, 다른 돈만 있는 상품은 그 뒤에 그 돈으로 — 환산해 섞지 않는다
    final currency = currencyFor(list, _filter.preferredCurrency);
    switch (_sort) {
      case KitSort.newest:
        break; // GET 정렬 그대로
      case KitSort.release:
        list.sort((a, b) => a.date.compareTo(b.date));
      case KitSort.priceLow:
        list.sort((a, b) => comparePrice(a, b, currency));
      case KitSort.priceHigh:
        list.sort((a, b) => comparePrice(a, b, currency, high: true));
    }
    return _shown = list;
  }

  Future<void> _clearHistory() async {
    final ok = await showDialog<bool>(
      // O-6 P05
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('최근 본 기록을 지울까요?')),
        content: Text(tr('상품은 그대로이고, 이 목록만 비워져요.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('취소'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('지우기'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final me = Marks.read(context).store;
    final before = me.clearRecentViewed(); // 기기의 최근 본 기록 (홈 줄도 같이 비워진다)
    setState(() => _cleared = widget.kits); // STATE: 기록 지우기 → 빈 목록
    showToast(
      context,
      tr('최근 본 기록을 지웠어요'),
      onUndo: () {
        me.restoreRecentViewed(before);
        if (mounted) setState(() => _cleared = const []);
      },
    );
  }

  /// O-2 아래에서 올라오는 필터 시트 (검색 · 전체 목록 공통 — lib/widgets/kit_filter_sheet.dart)
  Future<void> _openFilter() async {
    final pool = [
      for (final k in _kits)
        if (kitMatches(k, widget.query)) k,
    ];
    final picked = await pickKitFilter(context, pool: pool, current: _filter);
    if (picked != null) setState(() => _filter = picked); // STATE: 필터 → 목록
  }

  @override
  Widget build(BuildContext context) {
    final anns = widget.announcements;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.titleRow)
          Padding(
            // O-1
            padding: const EdgeInsets.fromLTRB(4, 0, 8, 0),
            child: Row(
              children: [
                if (widget.onBack case final back?)
                  IconButton(
                    tooltip: tr('돌아가기'),
                    onPressed: back,
                    icon: const Icon(Icons.arrow_back_ios_new, size: Gp.iM),
                  )
                else
                  const SizedBox(width: 12),
                Container(width: 3, height: 16, color: Gp.accent), // 홈 줄 제목과 같은 색 막대
                const SizedBox(width: 8),
                Text(
                  tr(widget.title),
                  style: const TextStyle(fontSize: Gp.t19, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                // 개수는 쓰지 않는다 (분류마다 몇 개인지는 보지 않기, 2026-11-14)
                Expanded(
                  child: Text(
                    widget.subtitle,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: Gp.t12, color: Gp.accent, fontWeight: FontWeight.w500),
                  ),
                ),
                if (widget.history && _kits.isNotEmpty)
                  TextButton(onPressed: _clearHistory, child: Text(tr('기록 지우기'))), // O-6
                if (anns == null && _kits.isNotEmpty && widget.tools == null) ...[
                  IconButton(
                    tooltip: tr('필터'),
                    onPressed: _openFilter,
                    icon: Badge(
                      isLabelVisible: _filter.count > 0,
                      backgroundColor: Gp.accent,
                      label: Text('${_filter.count}'),
                      child: const Icon(Icons.tune, color: Gp.ink),
                    ),
                  ),
                  IconButton(
                    tooltip: _grid ? tr('목록으로 보기') : tr('격자로 보기'),
                    onPressed: () => setState(() => _grid = !_grid), // STATE: 보기 방식
                    icon: Icon(_grid ? Icons.view_list_outlined : Icons.grid_view_outlined, color: Gp.muted),
                  ),
                ],
              ],
            ),
          ),
        Expanded(child: anns != null ? _announcementBody(anns) : _kitBody()),
      ],
    );
  }

  // ---------- 상품 ----------

  Widget _kitBody() {
    if (_kits.isEmpty) {
      return EmptyView(
        // O-8
        icon: widget.history ? Icons.history : Icons.inbox_outlined,
        message: widget.history ? tr('최근 본 상품이 없어요') : tr('표시할 상품이 없어요'),
        detail: widget.history ? tr('상품 상세를 열면 여기에 남아요') : '',
      );
    }
    final visible = _visibleKits();
    final labels = _filter.labels;
    final bar = Padding(
      // O-3 고른 조건 + 정렬
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: labels.isEmpty
                ? const SizedBox.shrink()
                : Row(
                    children: [
                      Flexible(
                        child: Text(
                          labels.map(tr).join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: Gp.t12, color: Gp.accent),
                        ),
                      ),
                      InkWell(
                        onTap: () => setState(() => _filter = KitFilter()), // STATE: 필터 초기화
                        child: const SizedBox.square(
                          // 누르는 자리 40
                          dimension: 40,
                          child: Icon(Icons.close, size: Gp.iS, color: Gp.muted),
                        ),
                      ),
                    ],
                  ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(Gp.radius),
            onTap: () async {
              final s = await showPickSheet(
                context,
                title: tr('정렬'),
                values: KitSort.values,
                current: _sort,
                label: (s) => s.label,
              );
              if (s != null) setState(() => _sort = s); // STATE: 정렬 → 순서
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.swap_vert, size: Gp.iM, color: Gp.muted),
                  const SizedBox(width: 2),
                  Text(
                    _sort.label,
                    style: const TextStyle(fontSize: Gp.t12, color: Gp.ink),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    final empty = EmptyView(
      // O-8
      icon: Icons.search_off,
      message: _filter.count > 0
          ? tr('이 조건의 상품이 없어요')
          : trf('「{q}」 결과가 {name}에 없어요', {'q': widget.query, 'name': tr(widget.title)}),
      action: _filter.count > 0
          ? OutlinedButton(onPressed: () => setState(() => _filter = KitFilter()), child: Text(tr('필터 초기화')))
          : null,
    );
    return LayoutBuilder(
      builder: (context, box) {
        // 폰에서 한 줄 3개 (홈 줄과 같은 크기)
        final cols = (box.maxWidth / 125).floor().clamp(3, 7);
        final cell = (box.maxWidth - 32 - (cols - 1) * 10) / cols;
        return CustomScrollView(
          slivers: [
            if (widget.header case final h?) SliverToBoxAdapter(child: h),
            SliverToBoxAdapter(child: bar),
            if (visible.isEmpty)
              SliverFillRemaining(hasScrollBody: false, child: empty)
            else if (_grid)
              SliverPadding(
                // O-4
                padding: EdgeInsets.fromLTRB(16, 4, 16, navClearance(context)),
                sliver: SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 10,
                    // 사진 + 이름 두 줄 + 가격 · 날짜 한 줄 (+ 한국 · 일본 정가가 다 있는 상품이 있으면 작은 둘째 정가 줄)
                    mainAxisExtent: cell + 76 + (visible.any((k) => kitPriceParts(k).length > 1) ? 16 : 0),
                  ),
                  itemCount: visible.length,
                  itemBuilder: (context, i) => _tile(visible[i]),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.only(top: 4, bottom: navClearance(context)),
                sliver: SliverList.builder(itemCount: visible.length, itemBuilder: (context, i) => _row(visible[i])),
              ),
          ],
        );
      },
    );
  }

  /// 정가가 둘(₩ · ¥)이면 360dp 칸(약 100dp)에 날짜와 한 줄로 다 들어가지 않아 둘째 정가는 아래 작은 줄로
  Widget _tile(Kit k) {
    final p = kitPriceParts(k);
    return ProductTile(
      id: k.id,
      image: k.image,
      title: k.name,
      titleLines: 2,
      subtitle: joinDot([p.firstOrNull ?? tr('가격 미정'), dateDot(k.date)]),
      note: p.length > 1 ? p[1] : '',
      marks: QuickMarks(kit: k),
      onTap: () => openKitDetail(context, k, loaders: widget.loaders, list: _shown),
    );
  }

  Widget _row(Kit k) => ThumbRow(
    id: k.id,
    image: k.image,
    title: k.name,
    titleLines: 2,
    size: 64,
    subtitle: joinDot([
      tr(channelOf(k.franchiseId).label),
      kitWork(k) == k.series ? k.seriesLabel : kitWork(k),
      tr(k.line),
    ]),
    tag: Marks.of(context).owned(k)
        ? tr('구매함')
        : Marks.of(context).liked(k)
        ? tr('좋아요')
        : '',
    trailing: Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        KitPriceLines(k),
        Text(
          dateDot(k.date),
          style: const TextStyle(fontSize: Gp.t11, color: Gp.faint),
        ),
      ],
    ),
    onTap: () => openKitDetail(context, k, loaders: widget.loaders, list: _shown),
  );

  // ---------- 예고 (공식 · 비공식) ----------

  Widget _announcementBody(List<Announcement> all0) {
    final q = widget.query.trim().toLowerCase();
    final all = [
      for (final a in all0)
        if (q.isEmpty || a.title.toLowerCase().contains(q)) a,
    ];
    final list = [
      for (final a in all)
        if (inAnnTab(a, _annTab)) a,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          // O-5 밑줄 탭 (채널 바 · 컬렉션과 같은 부품)
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final t in announcementTabs(all))
                  UnderlineTab(
                    key: ValueKey('ann-tab-${t.tab}'),
                    label: t.tab.isEmpty ? tr('전체') : tr(t.tab),
                    count: t.count,
                    fontSize: Gp.t14,
                    selected: _annTab == t.tab,
                    onTap: () => setState(() => _annTab = t.tab), // STATE: 상태 → 목록
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? EmptyView(icon: Icons.search_off, message: tr('이 조건의 예고가 없어요'))
              : LayoutBuilder(
                  builder: (context, box) {
                    final cols = box.maxWidth >= 720 ? 2 : 1;
                    final cell = (box.maxWidth - 32 - (cols - 1) * 14) / cols;
                    return GridView.builder(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, navClearance(context)),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        mainAxisSpacing: 18,
                        crossAxisSpacing: 14,
                        mainAxisExtent: cell * 9 / 16 + 76,
                      ),
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final a = list[i];
                        return GestureDetector(
                          onTap: () => openAnnouncement(context, a, loaders: widget.loaders, list: list),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AspectRatio(aspectRatio: 16 / 9, child: PhotoThumb(a.image)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  AnnTag(a),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      joinDot([tr(channelOf(a.franchiseId).label), dateDot(annShownDay(a)), a.source]),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                a.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: Gp.t14, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}
