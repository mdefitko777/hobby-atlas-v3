// 화면 O: 전체 목록 — 새 화면을 쌓지 않고 탭 안에서 바뀌는 보기
// 홈: 가로 줄 › (최근 추가 · 10월 발매 · 공식 예고 · 최근 본) → 홈 머리(아바타 · 채널 바 · 검색창) 아래만 이 목록.
// 검색: 검색 결과 · "전체 상품 둘러보기"도 같은 목록 (AI 후보는 맨 위 머리로).
// 홈 줄은 사진과 이름만(P08), 여기서는 가격 · 발매일까지 보이고, 오른쪽에서 나오는 필터 패널로 거른다.
//
// ┌──────── 디자인 가이드 대응표: O 전체 목록 ─────────────────────────────────────────┐
// │ 번호 │ Flutter 위젯명                     │ 비즈니스 명칭(한글)                    │ 원칙(P번호)   │
// │ O-1  │ ‹ + 제목 + 개수 · 필터 · 보기 전환    │ 어느 목록인지 · 돌아가기 · 격자/목록     │ P03 · P07     │
// │ O-2  │ 오른쪽 패널(showGeneralDialog) · 접히는 칸 + 체크 · 초기화 · n개 보기 │ 필터: 작품 · 종류 · 라인 · 가격 · 발매 (칸마다 개수 = 다른 조건을 건 뒤의 개수) │ P06 · P08 · P01 · P05 │
// │ O-3  │ 고른 필터 한 줄 + showPickSheet      │ 지금 거르는 조건 · 정렬 4가지 (아래 시트)  │ P01 · P07     │
// │ O-4  │ 격자 ProductTile(+ ♡) / ThumbRow     │ 상품 (가격 · 발매일 보임) → D 상세       │ P08 · P07     │
// │ O-5  │ 밑줄 탭 + 16:9 카드                  │ 공식 예고: 공식 발표 · 상품화 확정 · 예약  │ P02 · P06     │
// │ O-6  │ 기록 지우기 → showDialog → 토스트     │ 최근 본 기록 비우기 (되돌리기)            │ P05 · P03     │
// │ O-7  │ 위 검색창 (이 목록 안에서만 찾기)      │ "최근 추가에서 찾기"                     │ P07 · P04     │
// │ O-8  │ EmptyView                          │ 거른 결과 · 찾은 결과 없음 · 기록 없음     │ P09           │
// └──────────────────────────────────────────────────────────────────────────────────┘
// 전환: 탭 안에서 바뀜(쌓지 않음) — ‹ 또는 뒤로 가기로 원래 화면. 칸 → 상세 쌓기. 필터 → 오른쪽에서 덮기.
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
import '../clock.dart';

/// 홈에서 펼칠 수 있는 목록
enum HomeSection { recent, month, announcements, viewed, limited }

enum KitSort { newest, release, priceLow, priceHigh }

extension on KitSort {
  String get label => switch (this) {
    KitSort.newest => '최신순',
    KitSort.release => '발매일순',
    KitSort.priceLow => '가격 낮은순',
    KitSort.priceHigh => '가격 높은순',
  };
}

enum PriceBand { any, under3k, mid, over10k }

enum ReleaseState { any, released, upcoming }

extension on PriceBand {
  String get label => switch (this) {
    PriceBand.any => '전체',
    PriceBand.under3k => '¥3,000 이하',
    PriceBand.mid => '¥3,000 – ¥10,000',
    PriceBand.over10k => '¥10,000 이상',
  };

  bool hit(int? p) => switch (this) {
    PriceBand.any => true,
    PriceBand.under3k => p != null && p <= 3000,
    PriceBand.mid => p != null && p > 3000 && p <= 10000,
    PriceBand.over10k => p != null && p > 10000,
  };
}

extension on ReleaseState {
  String get label => switch (this) {
    ReleaseState.any => '전체',
    ReleaseState.released => '발매됨',
    ReleaseState.upcoming => '발매 예정',
  };
}

/// 프로토타입의 오늘 (캘린더와 같음) — 발매됨/예정 나누기
String get _today => appNow().toIso8601String().substring(0, 10);

/// O-2 필터 조건 (가짜 저장 없음, 이 목록 안에서만)
class KitFilter {
  KitFilter({
    Set<String>? works,
    Set<String>? types,
    Set<String>? lines,
    this.price = PriceBand.any,
    this.release = ReleaseState.any,
  }) : works = works ?? {},
       types = types ?? {},
       lines = lines ?? {};

  final Set<String> works;
  final Set<String> types;
  final Set<String> lines;
  PriceBand price;
  ReleaseState release;

  KitFilter copy() =>
      KitFilter(works: {...works}, types: {...types}, lines: {...lines}, price: price, release: release);

  int get count =>
      works.length +
      types.length +
      lines.length +
      (price == PriceBand.any ? 0 : 1) +
      (release == ReleaseState.any ? 0 : 1);

  bool matches(Kit k) =>
      (works.isEmpty || works.contains(kitWork(k))) &&
      (types.isEmpty || types.contains(k.type)) &&
      (lines.isEmpty || lines.contains(k.line)) &&
      price.hit(k.priceJpy) &&
      switch (release) {
        ReleaseState.any => true,
        ReleaseState.released => k.date.compareTo(_today) <= 0,
        ReleaseState.upcoming => k.date.compareTo(_today) > 0,
      };

  /// 고른 조건 한 줄 ("SEED · HG · ¥3,000 이하")
  List<String> get labels => [
    ...works,
    ...types,
    ...lines,
    if (price != PriceBand.any) price.label,
    if (release != ReleaseState.any) release.label,
  ];
}

/// 값별 개수, 많은 순
List<(String, int)> _counts(Iterable<String> values) {
  final m = <String, int>{};
  for (final v in values) {
    if (v.isNotEmpty) m[v] = (m[v] ?? 0) + 1;
  }
  return [for (final e in m.entries) (e.key, e.value)]..sort((a, b) => b.$2.compareTo(a.$2));
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
    this.loaders = const Loaders(),
  });

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
  KitFilter _filter = KitFilter();
  List<Kit> _cleared = const []; // 최근 본: 지운 기록
  bool _grid = true;
  String _annStatus = '';

  List<Kit> get _kits => [
    for (final k in widget.kits)
      if (!_cleared.contains(k)) k,
  ];

  List<Kit> _visibleKits() {
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
    return list;
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

  /// O-2 오른쪽에서 나오는 필터 패널
  Future<void> _openFilter() async {
    final pool = [
      for (final k in _kits)
        if (kitMatches(k, widget.query)) k,
    ];
    final picked = await showGeneralDialog<KitFilter>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '필터 닫기',
      barrierColor: const Color(0x52000000),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, _, _) => _FilterPanel(kits: pool, initial: _filter),
      transitionBuilder: (_, a, _, child) => SlideTransition(
        position: Tween(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );
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
                IconButton(tooltip: '돌아가기', onPressed: back, icon: const Icon(Icons.arrow_back_ios_new, size: 18))
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
              if (anns == null && _kits.isNotEmpty) ...[
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
                          child: Icon(Icons.close, size: 16, color: Gp.muted),
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
                  const Icon(Icons.swap_vert, size: 18, color: Gp.muted),
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
        final cols = (box.maxWidth / 170).floor().clamp(2, 5);
        final cell = (box.maxWidth - 32 - (cols - 1) * 12) / cols;
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
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 12,
                    mainAxisExtent: cell + 80, // 사진 + 이름 두 줄 + 가격 · 날짜 한 줄
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
    onTap: () => openKitDetail(context, k, loaders: widget.loaders),
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
    onTap: () => openKitDetail(context, k, loaders: widget.loaders),
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
                          onTap: () => openAnnouncement(context, a, loaders: widget.loaders),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AspectRatio(aspectRatio: 16 / 9, child: PhotoThumb(a.image, radius: 12)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  TagPill(a.status, strong: a.status == '예약 시작'),
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

/// O-2 필터 패널 — 오른쪽에서 나와 화면의 85%를 덮는다. 접히는 칸마다 체크, 아래 초기화 · n개 보기.
class _FilterPanel extends StatefulWidget {
  const _FilterPanel({required this.kits, required this.initial});
  final List<Kit> kits;
  final KitFilter initial;

  @override
  State<_FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<_FilterPanel> {
  late final KitFilter _draft = widget.initial.copy();

  /// 펼친 칸 (처음엔 작품만)
  final Set<String> _open = {'작품'};

  void _toggle(Set<String> set, String v) => setState(() => set.contains(v) ? set.remove(v) : set.add(v));

  @override
  Widget build(BuildContext context) {
    final kits = widget.kits;
    final hits = kits.where(_draft.matches).length;
    final width = MediaQuery.sizeOf(context).width;

    Widget section(String title, String summary, List<Widget> children) {
      final open = _open.contains(title);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => open ? _open.remove(title) : _open.add(title)), // STATE: 칸 접기
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
              child: Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: Gp.t14),
                  ),
                  const Spacer(),
                  Text(
                    summary,
                    style: const TextStyle(fontSize: Gp.t12, color: Gp.accent),
                  ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: const Icon(Icons.expand_more, color: Gp.muted),
                  ),
                ],
              ),
            ),
          ),
          if (open)
            ColoredBox(
              color: Gp.bg,
              child: Column(children: children),
            ),
          const Divider(height: 1),
        ],
      );
    }

    Widget check(String label, int n, bool on, VoidCallback onTap) => InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 11, 18, 11),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: Gp.t14)),
            ),
            Text(
              '$n',
              style: const TextStyle(fontSize: Gp.t12, color: Gp.faint),
            ),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: on ? Gp.accent : Gp.panel,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: on ? Gp.accent : Gp.line),
              ),
              child: on ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
            ),
          ],
        ),
      ),
    );

    String summary(Set<String> s) => s.isEmpty ? '전체' : (s.length == 1 ? s.first : '${s.first} 외 ${s.length - 1}');

    // 칸 순서는 전체 개수 순으로 고정, 숫자는 "다른 칸의 조건 + 이 값"일 때 개수 (0이면 흐리게)
    Widget checks(Set<String> set, List<(String, int)> values, Set<String> Function(KitFilter) facet) => Column(
      children: [
        for (final (v, _) in values)
          Opacity(
            opacity: _facetCount(facet, v) == 0 && !set.contains(v) ? 0.4 : 1,
            child: check(v, _facetCount(facet, v), set.contains(v), () => _toggle(set, v)),
          ),
      ],
    );

    Widget radios<T>(List<T> values, T current, String Function(T) label, ValueChanged<T> onPick) => Column(
      children: [for (final v in values) check(label(v), _countFor(v), current == v, () => setState(() => onPick(v)))],
    );

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Gp.panel,
        child: SizedBox(
          width: width < 480 ? width * 0.85 : 400,
          height: double.infinity,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
                  child: Row(
                    children: [
                      const Text(
                        '필터',
                        style: TextStyle(fontSize: Gp.t19, fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      IconButton(tooltip: '닫기', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                    ],
                  ),
                ),
                const Divider(height: 1), // 다른 화면과 같은 옅은 실선
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      section('작품', summary(_draft.works), [
                        checks(_draft.works, _counts(kits.map(kitWork)), (f) => f.works),
                      ]),
                      section('종류', summary(_draft.types), [
                        checks(_draft.types, _counts(kits.map((k) => k.type)), (f) => f.types),
                      ]),
                      section('라인', summary(_draft.lines), [
                        checks(_draft.lines, _counts(kits.map((k) => k.line)), (f) => f.lines),
                      ]),
                      section('가격', _draft.price.label, [
                        radios(PriceBand.values, _draft.price, (p) => p.label, (p) => _draft.price = p),
                      ]),
                      section('발매', _draft.release.label, [
                        radios(ReleaseState.values, _draft.release, (r) => r.label, (r) => _draft.release = r),
                      ]),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => setState(() {
                            final empty = KitFilter(); // STATE: 초기화 → 모두 전체
                            _draft.works.clear();
                            _draft.types.clear();
                            _draft.lines.clear();
                            _draft.price = empty.price;
                            _draft.release = empty.release;
                          }),
                          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('초기화'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: hits == 0 ? null : () => Navigator.pop(context, _draft),
                          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                          child: Text(hits == 0 ? '맞는 상품 없음' : '$hits개 보기'), // P01 고르는 동안 개수
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 작품 · 종류 · 라인 한 값을 골랐을 때 개수 (같은 칸의 다른 선택은 빼고, 다른 칸 조건은 그대로)
  int _facetCount(Set<String> Function(KitFilter) facet, String v) {
    final f = _draft.copy();
    facet(f)
      ..clear()
      ..add(v);
    return widget.kits.where(f.matches).length;
  }

  /// 가격 · 발매 한 칸을 골랐을 때 개수 (다른 조건은 그대로)
  int _countFor(Object? v) {
    final f = _draft.copy();
    if (v is PriceBand) f.price = v;
    if (v is ReleaseState) f.release = v;
    return widget.kits.where(f.matches).length;
  }
}
