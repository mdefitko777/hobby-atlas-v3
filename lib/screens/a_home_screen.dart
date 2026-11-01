// 화면 A: 홈 — 큰 배너(공식 예고) + 종류별 가로 스크롤 줄
//
// ┌──────── 디자인 가이드 대응표: A 홈 ────────────────────────────────────────────────┐
// │ 번호 │ Flutter 위젯명                     │ 비즈니스 명칭(한글)                    │ 원칙(P번호)   │
// │ A-1  │ ChannelHeader                      │ 아바타 줄 + 내 채널 바 (C-0 공용)       │ P04 · P06     │
// │ A-2  │ GpSearchBar 입구 (탭하면 검색 탭)   │ 검색창(검색 화면과 같은 모양) · 카메라  │ P07 · P04     │
// │ A-3  │ PageView(화면 끝까지) + 점 표시     │ 공식 예고 배너 (4초마다 다음 장, 끝없이) │ P08 · P02     │
// │ A-4  │ 배너 아래 상태 · 제목               │ 예고 상태(공식 발표·상품화 확정·예약)   │ P01           │
// │ A-5  │ SectionHeader (색 막대 + ›)         │ 줄 이름 · 전체 보기 → O 전체 목록(홈 안)  │ P06 · P07     │
// │ A-6  │ 가로 ListView + ProductTile         │ 최근 추가 · 10월 발매 · 공식 예고 · 최근 본 │ P08        │
// │ A-7  │ LoadingView / ErrorView / EmptyView │ 불러오는 중 · 오류 · 빈 채널           │ P01 · P09     │
// │ A-8  │ 흰 띠(섹션마다) + 회백색 틈          │ 줄과 줄 사이 층 구분                   │ P08 · P04     │
// │ A-9  │ ProductTile 의 QuickMarks (리본 · ♡)  │ 좋아요 · 구매함 바로 담기 (앱 전체 한 벌)  │ P07 · P04     │
// │ A-26 │ 위 줄 ? (S-19, homeHelp)            │ 검색창 줄 아이콘 뜻 한 줄씩              │ P10           │
// └──────────────────────────────────────────────────────────────────────────────────┘
// 전환: A-2 → 검색 탭(옆으로). › → 같은 탭 안에서 O 전체 목록(위쪽 머리 · 검색창은 그대로, 뒤로 = 홈). 상품 카드 → D 상품 상세(쌓기). 배너 · 예고 카드 → J 공식 예고 상세(쌓기).
// 줄 안에는 날짜·가격을 쓰지 않는다 — 궁금하면 눌러서 상세에서 본다 (P08).
// 현행 앱 문제: 홈 = 버전 번호·총 개수·IP 입구 카드 → v2 홈 = "내 채널의 새 소식"만.
import '../logic/kit_rules.dart';
import 'dart:async' show Timer;

import 'package:flutter/material.dart';

import '../api.dart';
import '../channels.dart';
import '../clock.dart';
import '../data/catalog.dart';
import '../data/user_store.dart';
import '../marks.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'c_channel_screen.dart';
import 'd_kit_detail_screen.dart';
import 'a_my_page.dart';
import 'f_collection_screen.dart' show CollectionJump;
import 'j_announcement_screen.dart';
import 'o_see_all_screen.dart';

/// 최근 본 상품 — 상세를 열 때마다 기기에 남긴다. 아직 본 것이 없으면 빈 줄(줄 자체가 안 보임)
List<String> get recentViewedIds => UserStore.instance.recentViewed;

/// 이번 달 발매 줄 제목
String get currentMonthTitle => '${appNow().month}월 발매';

/// "최근 추가" 기간 = 데이터에 가장 늦게 들어온 날 기준 3일 (Gunpula 갱신이 멈추면 그 날짜에 머문다)
String get recentRangeLabel {
  final c = Catalog.instance;
  if (c.recentSince.isEmpty) return '최근 3일';
  String md(String d) => '${d.substring(5, 7)}.${d.substring(8, 10)}';
  return '${md(c.recentSince)} – ${md(c.recentUntil)}';
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.myChannels,
    required this.onMyChannelsChanged,
    required this.onOpenSearch,
    required this.onCamera,
    this.onJump,
    this.leading,
    this.loaders = const Loaders(),
  });

  /// 내 보드 · 도감 아이콘 → 컬렉션 탭 (앱 셸)
  final ValueChanged<CollectionJump>? onJump;

  final List<String> myChannels;
  final ValueChanged<List<String>> onMyChannelsChanged;
  final VoidCallback onOpenSearch;

  /// 검색창 카메라 → 앱 셸의 찍어서 찾기 시트
  final VoidCallback onCamera;
  final Widget? leading;
  final Loaders loaders;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeData {
  const _HomeData(this.kits, this.announcements);
  final List<Kit> kits;
  final List<Announcement> announcements;
}

/// 가로 줄 한 칸 (사진 + 이름). [kit]이 있으면 상품(상세 · 좋아요 담기), 없으면 공식 예고
class _Item {
  const _Item(this.image, this.title, {this.kit, this.ann});
  final String image;
  final String title;
  final Kit? kit;
  final Announcement? ann;
}

/// 전체 목록 제목
String _titleOf(HomeSection s) => switch (s) {
  HomeSection.recent => '최근 추가',
  HomeSection.month => currentMonthTitle,
  HomeSection.announcements => '공식 예고',
  HomeSection.viewed => '최근 본',
};

/// 가로 줄 하나
class _Row {
  const _Row(this.title, this.items, {required this.onMore, this.subtitle = '', this.wide = false});
  final String title;

  /// › → O 전체 목록
  final VoidCallback onMore;
  final List<_Item> items;
  final String subtitle;
  final bool wide;
}

class _HomeScreenState extends State<HomeScreen> with ChannelScope {
  late Future<_HomeData> _future;

  /// null = 홈, 아니면 홈 안에서 펼친 전체 목록 (O)
  HomeSection? _section;

  /// 전체 소식 / My Page
  bool _mine = false;

  /// My Page 안에서 찾기 · 필터 (좋아요 · 구매함에서만)
  final _mineFind = KitFind();

  void _setMine(bool v) => setState(() {
    _mine = v; // STATE: 전체 소식 ↔ My Page (찾기 · 필터는 비운다)
    _mineFind.clear();
  });

  Future<void> _openMineFilter() async {
    final me = UserStore.instance;
    final cat = Catalog.instance;
    final pool = [
      for (final id in me.idsWith(const {CollectStatus.wanted, CollectStatus.owned})) ?cat.byId[id],
    ];
    final picked = await pickKitFilter(context, pool: pool, current: _mineFind.filter);
    if (picked != null) setState(() => _mineFind.filter = picked); // STATE: 필터 → My Page 목록
  }

  /// 전체 목록일 때 검색창 = 그 목록 안에서만 찾기 (O-7)
  final _searchCtrl = TextEditingController();
  String _query = '';

  /// 전체 목록의 필터 · 격자/목록 (위 검색창 줄 아이콘이 바꾼다)
  var _listTools = ListTools();

  /// 홈 가로 줄(최근 추가 · 이번 달 · 최근 본) 필터 — 검색창 줄의 필터 아이콘
  KitFilter _homeFilter = KitFilter();

  void _openSection(HomeSection s) => setState(() {
    _section = s; // STATE: › → 홈 아래쪽이 전체 목록으로
    _searchCtrl.clear();
    _query = '';
    _listTools = ListTools();
  });

  void _closeSection() => setState(() {
    _section = null; // STATE: ‹ · 뒤로 → 홈
    _searchCtrl.clear();
    _query = '';
  });

  Future<void> _openHomeFilter(List<Kit> pool) async {
    final picked = await pickKitFilter(context, pool: pool, current: _homeFilter);
    if (picked != null) setState(() => _homeFilter = picked); // STATE: 필터 → 홈 가로 줄
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  List<String> get myChannels => widget.myChannels;

  @override
  void loadScope(List<String> ids) {
    // STATE: 선택 채널 → GET /kits · /announcements → 배너 + 가로 줄
    _future = Future.wait([
      widget.loaders.kits(ids),
      widget.loaders.announcements(ids),
    ]).then((r) => _HomeData(r[0] as List<Kit>, r[1] as List<Announcement>));
  }

  @override
  void initState() {
    super.initState();
    reloadScope();
  }

  @override
  void didUpdateWidget(HomeScreen old) {
    super.didUpdateWidget(old);
    syncScope();
  }

  @override
  Widget build(BuildContext context) {
    // 전체 목록을 펼친 상태에서 뒤로 가기 = 홈으로 (앱을 닫지 않음)
    return PopScope(
      canPop: _section == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeSection();
      },
      child: _page(),
    );
  }

  Widget _page() {
    return Column(
      children: [
        ChannelHeader(
          // A-1 P04
          leading: widget.leading,
          myChannels: widget.myChannels,
          selected: channel,
          onSelect: selectChannel,
          onMyChannelsChanged: widget.onMyChannelsChanged,
        ),
        Expanded(
          // 내용을 좌우로 밀면 옆 채널 (전체 · 건담 · 베이블레이드 X …)
          child: channelSwipe(
            FutureBuilder<_HomeData>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const LoadingView(); // A-7 P01
                }
                if (snap.hasError) {
                  return ErrorView(
                    // A-7 P09
                    message: '${snap.error}',
                    onRetry: () => setState(reloadScope),
                  );
                }
                return _body(snap.data!);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _body(_HomeData data) {
    final byId = {for (final k in data.kits) k.id: k};
    _homeFilter.statusOf = Marks.of(context).statusOf;
    bool home(Kit k) => _homeFilter.matches(k); // A-11 홈 필터
    final recent = [
      for (final k in data.kits)
        if (k.recent && home(k)) k,
    ];
    final month = [
      for (final k in data.kits)
        if (k.month && home(k)) k,
    ];
    final viewed = [
      for (final id in recentViewedIds)
        if (byId[id] case final k? when home(k)) k,
    ];
    final lists = {HomeSection.recent: recent, HomeSection.month: month, HomeSection.viewed: viewed};
    // A-2 검색창 줄 — 모든 탭과 같은 줄: [검색창][필터][보기 두 칸]
    final mineToggle = ViewIconToggle(mine: _mine, onChanged: _setMine); // A-10 전체 소식 · My Page
    final Widget search;
    if (_section case final sec?) {
      search = ToolRow(
        field: GpSearchBar(
          // O-7 이 목록 안에서만
          controller: _searchCtrl,
          hint: '${_titleOf(sec)}에서 찾기',
          onChanged: (v) => setState(() => _query = v), // STATE: 검색어 → 목록 거르기
          onCamera: widget.onCamera,
        ),
        tools: [
          ListToolIcons(
            tools: _listTools,
            pool: sec == HomeSection.announcements
                ? null
                : [
                    for (final k in lists[sec] ?? const <Kit>[])
                      if (kitMatches(k, _query)) k,
                  ],
          ),
        ],
      );
    } else if (_mine) {
      search = FindBar(
        // A-25 My Page 안에서 찾기 + 필터
        key: const ValueKey('mine-find'),
        hint: '내 것에서 찾기',
        onQuery: (q) => setState(() => _mineFind.query = q),
        filterCount: _mineFind.filter.count,
        onFilter: _openMineFilter,
        tools: [mineToggle],
      );
    } else {
      search = ToolRow(
        field: GpSearchBar(onTap: widget.onOpenSearch, onCamera: widget.onCamera), // A-2 P04 → 검색 탭
        tools: [
          FilterButton(count: _homeFilter.count, onTap: () => _openHomeFilter(data.kits)), // A-11
          mineToggle,
        ],
      );
    }
    final ids = scopeIds;
    if (data.kits.isEmpty && data.announcements.isEmpty) {
      final noData = ids.isNotEmpty && ids.every((id) => !channelOf(id).hasData);
      return ListView(
        children: [
          search,
          EmptyView(
            // A-7 P09
            icon: Icons.auto_awesome_outlined,
            message: ids.isEmpty
                ? '내 채널이 비어 있어요'
                : noData
                ? '${channelOf(ids.first).label}은(는) 아직 수록된 상품이 없어요'
                : '새 소식이 없어요',
            detail: ids.isEmpty ? '채널 관리에서 관심 IP를 추가하세요' : '상품이 들어오면 여기에 먼저 보여요',
            action: channel == allChannelId
                ? null
                : OutlinedButton(onPressed: () => selectChannel(allChannelId), child: const Text('전체 보기')),
          ),
        ],
      );
    }

    _Item kitItem(Kit k) => _Item(k.image, k.name, kit: k);

    // O 전체 목록 (홈 위쪽은 그대로, 아래만 바뀜)
    if (_section case final sec?) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          search,
          Expanded(
            child: SectionListView(
              key: ValueKey(sec),
              title: _titleOf(sec),
              subtitle: joinDot([
                if (channel != allChannelId) channelOf(channel).label,
                if (sec == HomeSection.recent) recentRangeLabel,
              ]),
              kits: lists[sec] ?? const [],
              announcements: sec == HomeSection.announcements ? data.announcements : null,
              history: sec == HomeSection.viewed,
              sort: sec == HomeSection.month ? KitSort.release : KitSort.newest,
              query: _query,
              tools: _listTools,
              onBack: _closeSection,
              loaders: widget.loaders,
            ),
          ),
        ],
      );
    }

    final rows = [
      _Row(
        '최근 추가',
        [for (final k in recent) kitItem(k)],
        subtitle: joinDot([
          recentRangeLabel,
          if (Catalog.instance.updatedAt.length >= 10) '데이터 ${dateDot(Catalog.instance.updatedAt.substring(5))}',
        ]),
        onMore: () => _openSection(HomeSection.recent),
      ),
      _Row(currentMonthTitle, [for (final k in month) kitItem(k)], onMore: () => _openSection(HomeSection.month)),
      _Row(
        '공식 예고',
        [for (final a in data.announcements) _Item(a.image, a.title, ann: a)],
        wide: true,
        onMore: () => _openSection(HomeSection.announcements),
      ),
      _Row('최근 본', [for (final k in viewed) kitItem(k)], onMore: () => _openSection(HomeSection.viewed)),
    ];
    final heroes = data.announcements.where((a) => a.hero).toList();

    // 당겨서 새로 고침 = Gunpula 새 데이터 확인 (바뀌면 앱 셸이 화면을 다시 불러온다)
    return RefreshIndicator(
      onRefresh: () async {
        final changed = await Catalog.instance.refresh();
        if (!changed && mounted) setState(reloadScope);
      },
      child: ListView(
        padding: EdgeInsets.only(bottom: navClearance(context)),
        children: [
          search,
          if (_mine)
            MyPageView(
              // A-20~25
              loaders: widget.loaders,
              onJump: widget.onJump,
              query: _mineFind.query,
              filter: _mineFind.filter,
            ),
          if (!_mine && heroes.isNotEmpty)
            _HeroBanner(
              // A-3 떠 있는 카드
              items: heroes,
              onTap: (a) => openAnnouncement(context, a, loaders: widget.loaders, list: heroes),
            ),
          if (!_mine)
            for (final row in rows)
              if (row.items.isNotEmpty)
                SectionPanel(
                  // A-8 흰 띠 + 회백색 틈 = 층 구분 (상세와 같은 부품)
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(
                        // A-5 P06
                        row.title,
                        subtitle: row.subtitle,
                        onMore: row.onMore, // → O 전체 목록
                      ),
                      _HorizontalRow(row: row, loaders: widget.loaders), // A-6 P08
                    ],
                  ),
                ),
        ],
      ),
    );
  }
}

/// A-3 공식 예고 배너 — 화면 끝까지 꽉 찬 16:9 사진, 아래에 상태와 제목
class _HeroBanner extends StatefulWidget {
  const _HeroBanner({required this.items, required this.onTap});
  final List<Announcement> items;
  final ValueChanged<Announcement> onTap;

  @override
  State<_HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<_HeroBanner> {
  /// 끝없이 넘기기: 아주 큰 쪽 번호에서 시작해 % 개수
  static const _loops = 1000;
  late final _controller = PageController(initialPage: widget.items.length * _loops);
  int _page = 0;
  Timer? _timer;

  /// 4초마다 다음 장 (손으로 넘기면 그때부터 다시 4초)
  void _restart() {
    _timer?.cancel();
    if (widget.items.length < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_controller.hasClients) {
        _controller.nextPage(duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        // 화면 끝까지가 아니라 양옆을 띄운 카드. 사진은 자르지 않고 16:9 칸 안에 전체(남는 곳은 옅은 바탕)
        final cardW = box.maxWidth - 32;
        final maxH = (MediaQuery.sizeOf(context).height * 0.3).clamp(140.0, 300.0);
        final imageH = (cardW * 9 / 16).clamp(120.0, maxH);
        return Column(
          children: [
            SizedBox(
              height: imageH + 40 + 18,
              child: NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (n is ScrollStartNotification && n.dragDetails != null) _timer?.cancel();
                  if (n is ScrollEndNotification) _restart();
                  return false;
                },
                child: PageView.builder(
                  controller: _controller,
                  itemCount: widget.items.length < 2 ? widget.items.length : null, // null = 끝없이
                  onPageChanged: (i) => setState(() => _page = i % widget.items.length), // STATE: 넘긴 쪽 → 점 표시
                  itemBuilder: (context, i) {
                    final a = widget.items[i % widget.items.length];
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
                      child: Material(
                        color: Gp.panel,
                        elevation: 3,
                        shadowColor: Gp.shadow,
                        borderRadius: BorderRadius.circular(Gp.rLarge),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => widget.onTap(a),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                height: imageH,
                                child: BlurFitImage(a.image), // 남는 곳 = 같은 사진을 흐리고 어둡게
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                                child: Row(
                                  children: [
                                    SoftTag(a.status, color: stageColor(a.status)), // A-4 P01 단계 = 다른 꼬리표와 같은 모양
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        a.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: Gp.t14, fontWeight: FontWeight.w600),
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
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PageDots(count: widget.items.length, index: _page),
            ),
          ],
        );
      },
    );
  }
}

/// A-6 가로 스크롤 줄 — ProductTile (사진 + 이름 한 줄, 날짜·가격 없음)
class _HorizontalRow extends StatelessWidget {
  const _HorizontalRow({required this.row, required this.loaders});
  final _Row row;
  final Loaders loaders;

  @override
  Widget build(BuildContext context) {
    // 공식 예고는 가로로 긴 배너 사진
    // 상품은 한 화면에 3개가 보이게 (양옆 16 · 사이 10), 공식 예고는 가로로 긴 배너
    final third = ((MediaQuery.sizeOf(context).width - 32 - 20) / 3).clamp(92.0, 150.0);
    final width = row.wide ? 232.0 : third;
    final aspect = row.wide ? 232 / 132 : 1.0;
    return SizedBox(
      height: width / aspect + 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Gp.gutter),
        itemCount: row.items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final item = row.items[i];
          final kit = item.kit;
          return ProductTile(
            image: item.image,
            title: item.title,
            imageWidth: width,
            imageAspect: aspect,
            id: kit?.id ?? item.ann?.id,
            onTap: () {
              final ann = item.ann;
              if (kit != null) {
                openKitDetail(context, kit, loaders: loaders, list: [for (final it in row.items) ?it.kit]);
              } else if (ann != null) {
                openAnnouncement(context, ann, loaders: loaders, list: [for (final it in row.items) ?it.ann]);
              }
            },
            marks: kit == null ? null : QuickMarks(kit: kit), // A-9 P07
          );
        },
      ),
    );
  }
}

/// A-26 ? 도움말 (위 줄 ? 의 "홈" 묶음 — s_app_shell.dart)
const homeHelp = <HelpItem>[
  HelpItem(Icons.photo_camera_outlined, '찍어서 찾기'),
  HelpItem(Icons.tune, '필터'),
  HelpItem(Icons.newspaper_outlined, '전체 소식'),
  HelpItem(Icons.person_outline, 'My Page (내 것 · ★ 친구)'),
  HelpItem(Icons.grid_view_outlined, '격자 · 목록 (전체 보기 안)'),
];
