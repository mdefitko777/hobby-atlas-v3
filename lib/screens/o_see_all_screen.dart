// 화면 O: 전체 목록 — 새 화면을 쌓지 않고 탭 안에서 바뀌는 보기
// 홈: 가로 줄 › (최근 추가 · 10월 발매 · 공식 예고 · 최근 본) → 홈 머리(아바타 · 채널 바 · 검색창) 아래만 이 목록.
// 검색: 검색 결과 · "전체 상품 둘러보기"도 같은 목록 (AI 후보는 맨 위 머리로).
// 홈 줄은 사진과 이름만(P08), 여기서는 가격 · 발매일까지 보이고, 오른쪽에서 나오는 필터 패널로 거른다.
//
// ┌──────── 디자인 가이드 대응표: O 전체 목록 ─────────────────────────────────────────┐
// │ 번호 │ Flutter 위젯명                     │ 비즈니스 명칭(한글)                    │ 원칙(P번호)   │
// │ O-1  │ ‹ + 제목 + 개수 · 필터 · 보기 전환    │ 어느 목록인지 · 돌아가기 · 격자/목록     │ P03 · P07     │
// │ O-2  │ 아래 시트(60%) · 네모 세그먼트 · 체크 2열 · 펼치는 줄 │ 필터: 내 상태 · 발매 · 판매 · 종류 · 라인 · 작품 · 가격 (lib/filter_sheet.dart) │ P06 · P08 · P01 · P05 │
// │ O-3  │ 고른 필터 한 줄 + showPickSheet      │ 지금 거르는 조건 · 정렬 4가지 (아래 시트)  │ P01 · P07     │
// │ O-4  │ 격자 ProductTile(+ ♡) / ThumbRow     │ 상품 (가격 · 발매일 보임) → D 상세       │ P08 · P07     │
// │ O-5  │ 밑줄 탭 + 16:9 카드                  │ 공식 예고: 공식 발표 · 상품화 확정 · 예약  │ P02 · P06     │
// │ O-6  │ 기록 지우기 → showDialog → 토스트     │ 최근 본 기록 비우기 (되돌리기)            │ P05 · P03     │
// │ O-7  │ 위 검색창 (이 목록 안에서만 찾기)      │ "최근 추가에서 찾기"                     │ P07 · P04     │
// │ O-8  │ EmptyView                          │ 거른 결과 · 찾은 결과 없음 · 기록 없음     │ P09           │
// └──────────────────────────────────────────────────────────────────────────────────┘
// 전환: 탭 안에서 바뀜(쌓지 않음) — ‹ 또는 뒤로 가기로 원래 화면. 칸 → 상세 쌓기. 필터 → 아래에서 덮기.
// 데이터는 부모 화면이 GET 한 목록을 그대로 쓴다(다시 부르지 않음).
import 'package:flutter/material.dart';

import '../api.dart';
import '../marks.dart';
import '../channels.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'd_kit_detail_screen.dart';
import 'j_announcement_screen.dart';
import '../filter_sheet.dart';

/// 홈에서 펼칠 수 있는 목록
enum HomeSection { recent, month, announcements, viewed }

enum KitSort { newest, release, priceLow, priceHigh }

extension on KitSort {
  String get label => switch (this) {
    KitSort.newest => '최신순',
    KitSort.release => '발매일순',
    KitSort.priceLow => '가격 낮은순',
    KitSort.priceHigh => '가격 높은순',
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
                  tools.filter.statusOf = Marks.read(context).statusOf;
                  final picked = await showFilterSheet(context, kits: pool!, initial: tools.filter);
                  if (picked != null) tools.setFilter(picked); // STATE: 필터 → 목록
                },
        ),
        ViewIconToggle(
          mine: !tools.grid,
          onChanged: (list) => tools.setGrid(!list), // STATE: 보기 방식
          allIcon: Icons.grid_view_outlined,
          mineIcon: Icons.view_list_outlined,
          allTip: '격자로 보기',
          mineTip: '목록으로 보기',
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
    this.loaders = const Loaders(),
  });

  /// 있으면 필터 · 격자/목록은 위 검색창 줄이 바꾼다 (이 목록 머리에서는 숨김)
  final ListTools? tools;

  final String title;

  /// 없으면 ‹ 를 숨긴다 (검색 탭 기본 목록)
  final VoidCallback? onBack;
  final String subtitle;
  final List<Kit> kits;

  /// 있으면 공식 예고 목록
  final List<Announcement>? announcements;

  /// 최근 본 기록 (지우기 버튼)
  final bool history;
  final KitSort sort;

  /// 위 검색창 글자 — 이 목록 안에서만 거른다 (O-7)
  final String query;

  /// 격자 위에 함께 스크롤되는 머리 (검색의 AI 후보)
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
  String _annStatus = '';

  List<Kit> get _kits => [
    for (final k in widget.kits)
      if (!_cleared.contains(k)) k,
  ];

  /// 지금 보이는 목록 (상세에서 좌우로 넘길 때 같은 순서)
  List<Kit> _shown = const [];

  List<Kit> _visibleKits() {
    _filter.statusOf = Marks.of(context).statusOf; // 좋아요 · 구매함으로 거르기
    final list = [
      for (final k in _kits)
        if (_filter.matches(k) && kitMatches(k, widget.query)) k,
    ];
    int price(Kit k, int none) => k.priceJpy ?? none;
    switch (_sort) {
      case KitSort.newest:
        break; // GET 정렬 그대로
      case KitSort.release:
        list.sort((a, b) => a.date.compareTo(b.date));
      case KitSort.priceLow:
        list.sort((a, b) => price(a, 1 << 30).compareTo(price(b, 1 << 30)));
      case KitSort.priceHigh:
        list.sort((a, b) => price(b, -1).compareTo(price(a, -1)));
    }
    return _shown = list;
  }

  Future<void> _clearHistory() async {
    final ok = await showDialog<bool>(
      // O-6 P05
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('최근 본 기록을 지울까요?'),
        content: const Text('상품은 그대로이고, 이 목록만 비워져요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('지우기')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _cleared = widget.kits); // STATE: 기록 지우기 → 빈 목록
    showToast(context, '최근 본 기록을 지웠어요', onUndo: () => setState(() => _cleared = const []));
  }

  /// O-2 아래에서 올라오는 필터 시트 (검색 · 전체 목록 공통 — lib/filter_sheet.dart)
  Future<void> _openFilter() async {
    final pool = [
      for (final k in _kits)
        if (kitMatches(k, widget.query)) k,
    ];
    _filter.statusOf = Marks.read(context).statusOf;
    final picked = await showFilterSheet(context, kits: pool, initial: _filter);
    if (picked != null) setState(() => _filter = picked); // STATE: 필터 → 목록
  }

  @override
  Widget build(BuildContext context) {
    final anns = widget.announcements;
    final count = anns != null ? anns.length : _kits.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          // O-1
          padding: const EdgeInsets.fromLTRB(4, 0, 8, 0),
          child: Row(
            children: [
              if (widget.onBack case final back?)
                IconButton(
                  tooltip: '돌아가기',
                  onPressed: back,
                  icon: const Icon(Icons.arrow_back_ios_new, size: Gp.iM),
                )
              else
                const SizedBox(width: 12),
              Container(width: 3, height: 16, color: Gp.accent), // 홈 줄 제목과 같은 색 막대
              const SizedBox(width: 8),
              Text(
                widget.title,
                style: const TextStyle(fontSize: Gp.t19, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  joinDot([widget.subtitle, '$count개']),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: Gp.t12, color: Gp.accent, fontWeight: FontWeight.w500),
                ),
              ),
              if (widget.history && _kits.isNotEmpty)
                TextButton(onPressed: _clearHistory, child: const Text('기록 지우기')), // O-6
              if (anns == null && _kits.isNotEmpty && widget.tools == null) ...[
                IconButton(
                  tooltip: '필터',
                  onPressed: _openFilter,
                  icon: Badge(
                    isLabelVisible: _filter.count > 0,
                    backgroundColor: Gp.accent,
                    label: Text('${_filter.count}'),
                    child: const Icon(Icons.tune, color: Gp.ink),
                  ),
                ),
                IconButton(
                  tooltip: _grid ? '목록으로 보기' : '격자로 보기',
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
        message: widget.history ? '최근 본 상품이 없어요' : '표시할 상품이 없어요',
        detail: widget.history ? '상품 상세를 열면 여기에 남아요' : '',
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
                ? Text(
                    '${visible.length}개',
                    style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
                  )
                : Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${labels.join(' · ')}  ${visible.length}개',
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
                title: '정렬',
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
      message: _filter.count > 0 ? '이 조건의 상품이 없어요' : '「${widget.query}」 결과가 ${widget.title}에 없어요',
      action: _filter.count > 0
          ? OutlinedButton(onPressed: () => setState(() => _filter = KitFilter()), child: const Text('필터 초기화'))
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
                    mainAxisExtent: cell + 76, // 사진 + 이름 두 줄 + 가격 · 날짜 한 줄
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

  Widget _tile(Kit k) => ProductTile(
    id: k.id,
    image: k.image,
    title: k.name,
    titleLines: 2,
    subtitle: joinDot([yen(k.priceJpy), dateDot(k.date)]),
    marks: QuickMarks(kit: k),
    onTap: () => openKitDetail(context, k, loaders: widget.loaders, list: _shown),
  );

  Widget _row(Kit k) => ThumbRow(
    id: k.id,
    image: k.image,
    title: k.name,
    titleLines: 2,
    size: 64,
    subtitle: joinDot([channelOf(k.franchiseId).label, kitWork(k), k.line]),
    tag: Marks.of(context).owned(k)
        ? '구매함'
        : Marks.of(context).liked(k)
        ? '좋아요'
        : '',
    trailing: Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(yen(k.priceJpy), style: const TextStyle(fontSize: Gp.t12)),
        Text(
          dateDot(k.date),
          style: const TextStyle(fontSize: Gp.t11, color: Gp.faint),
        ),
      ],
    ),
    onTap: () => openKitDetail(context, k, loaders: widget.loaders, list: _shown),
  );

  // ---------- 공식 예고 ----------

  Widget _announcementBody(List<Announcement> all0) {
    final q = widget.query.trim().toLowerCase();
    final all = [
      for (final a in all0)
        if (q.isEmpty || a.title.toLowerCase().contains(q)) a,
    ];
    final statuses = {for (final a in all) a.status}.toList(); // 나온 순서대로 한 번씩
    final list = [
      for (final a in all)
        if (_annStatus.isEmpty || a.status == _annStatus) a,
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
                for (final s in ['', ...statuses])
                  UnderlineTab(
                    label: s.isEmpty ? '전체' : s,
                    count: s.isEmpty ? all.length : all.where((a) => a.status == s).length,
                    fontSize: Gp.t14,
                    selected: _annStatus == s,
                    onTap: () => setState(() => _annStatus = s), // STATE: 상태 → 목록
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const EmptyView(icon: Icons.search_off, message: '이 조건의 예고가 없어요')
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
                              AspectRatio(aspectRatio: 16 / 9, child: PhotoThumb(a.image, radius: 12)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  SoftTag(a.status, color: stageColor(a.status)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      joinDot([channelOf(a.franchiseId).label, dateDot(a.date), a.source]),
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
