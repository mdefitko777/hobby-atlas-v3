// 화면 A: 홈 — 큰 배너(예고) + 종류별 가로 스크롤 줄
//
// ┌──────── 디자인 가이드 대응표: A 홈 ────────────────────────────────────────────────┐
// │ 번호 │ Flutter 위젯명                     │ 비즈니스 명칭(한글)                    │ 원칙(P번호)   │
// │ A-1  │ ChannelHeader                      │ 아바타 줄 + 내 채널 바 (C-0 공용)       │ P04 · P06     │
// │ A-2  │ ToolRow (상자 없는 아이콘 줄)        │ 필터 (전체 보기 안: 필터 · 격자 · 목록) — 검색창은 위 줄 🔍, My Page 는 서랍 좋아요 · 구매함 · 예약으로 │ P07 · P04 │
// │ A-3  │ PageView(화면 끝까지) + 점 표시     │ 예고 배너 (공식 먼저 · 모자라면 비공식, 4초마다 다음 장, 끝없이) │ P08 · P02     │
// │ A-4  │ 배너 아래 AnnTag · 제목             │ 예고 상태(공식 발표·상품화 확정·예약) · 라이브 · 예약 때 · 비공식 │ P01 │
// │ A-5  │ SectionHeader (색 막대 + ›)         │ 줄 이름 · 전체 보기 → O 전체 목록(홈 안)  │ P06 · P07     │
// │ A-6  │ 가로 ListView + ProductTile         │ 새 상품 · 10월 발매 · 공식 예고(비공식이 섞이면 예고) · 최근 본 (사진 + 이름 두 줄) │ P08 │
// │ A-7  │ LoadingView / ErrorView / EmptyView │ 불러오는 중 · 오류 · 빈 채널           │ P01 · P09     │
// │ A-8  │ 흰 띠(섹션마다) + 머리카락 줄        │ 줄과 줄 사이 층 구분                   │ P08 · P04     │
// │ A-9  │ ProductTile 의 QuickMarks (리본 · ♡)  │ 좋아요 · 구매함 바로 담기 (앱 전체 한 벌)  │ P07 · P04     │
// │ A-26 │ 서랍 › 사용법 (S-19, homeHelp)       │ 아이콘 뜻 한 줄씩                      │ P10           │
// └──────────────────────────────────────────────────────────────────────────────────┘
// 전환: › → 같은 탭 안에서 O 전체 목록(위쪽 머리 · 아이콘 줄은 그대로, 뒤로 = 홈). 상품 카드 → D 상품 상세(쌓기). 배너 · 예고 카드 → J 공식 예고 상세(쌓기).
// 줄 안에는 날짜·가격을 쓰지 않는다 — 궁금하면 눌러서 상세에서 본다 (P08).
// 왜 이렇게: 홈은 버전 번호 · 총 개수 · IP 입구 카드 대신 "내 채널의 새 소식"만.
import '../l10n/l10n.dart';
import '../logic/announcement_match.dart';
import '../logic/preorder_open.dart';

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
import 'j_announcement_screen.dart';
import 'o_see_all_screen.dart';

/// 최근 본 상품 — 상세를 열 때마다 기기에 남긴다. 아직 본 것이 없으면 빈 줄(줄 자체가 안 보임)
List<String> get recentViewedIds => UserStore.instance.recentViewed;

/// 이번 달 발매 줄 제목
String get currentMonthTitle => trf('{m}월 발매', {'m': appNow().month});

/// "새 상품" 기간 = 데이터에 가장 늦게 들어온 날 기준 3일 (Gunpula 갱신이 멈추면 그 날짜에 머문다)
String get recentRangeLabel {
  final c = Catalog.instance;
  if (c.recentSince.isEmpty) return tr('최근 3일');
  String md(String d) => '${d.substring(5, 7)}.${d.substring(8, 10)}';
  return '${md(c.recentSince)} – ${md(c.recentUntil)}';
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.myChannels,
    required this.onMyChannelsChanged,
    this.channel,
    this.onChannelChanged,
    this.leading,
    this.loaders = const Loaders(),
  });

  final List<String> myChannels;
  final ValueChanged<List<String>> onMyChannelsChanged;

  /// 앱 셸이 든 이 탭의 채널 · 고르면 셸에 알림 (채널 맞춰 보기, ChannelScope)
  final String? channel;
  final ValueChanged<String>? onChannelChanged;
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

/// 가로 줄 한 칸 (사진 + 이름). [kit]이 있으면 상품(상세 · 리본 + · ♡), 없으면 공식 예고
class _Item {
  const _Item(this.image, this.title, {this.kit, this.ann});
  final String image;
  final String title;
  final Kit? kit;
  final Announcement? ann;
}

/// 전체 목록 제목 — 예고 줄은 비공식 소식이 섞였으면 「예고」, 공식뿐이면 「공식 예고」 ([anns] = 지금 채널의 예고)
String _titleOf(HomeSection s, List<Announcement> anns) => switch (s) {
  HomeSection.recent => tr('새 상품'),
  HomeSection.month => currentMonthTitle,
  HomeSection.announcements => tr(annSectionTitle(anns)),
  HomeSection.viewed => tr('최근 본 상품'),
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

  /// 전체 목록의 필터 · 격자/목록 (위 아이콘 줄이 바꾼다)
  var _listTools = ListTools();

  /// 홈 가로 줄(새 상품 · 이번 달 · 최근 본) 필터 — 아이콘 줄의 필터
  KitFilter _homeFilter = KitFilter();

  void _openSection(HomeSection s) => setState(() {
    _section = s; // STATE: › → 홈 아래쪽이 전체 목록으로
    _listTools = ListTools();
  });

  void _closeSection() => setState(() => _section = null); // STATE: ‹ · 뒤로 → 홈

  Future<void> _openHomeFilter(List<Kit> pool) async {
    final picked = await pickKitFilter(context, pool: pool, current: _homeFilter);
    if (picked != null) setState(() => _homeFilter = picked); // STATE: 필터 → 홈 가로 줄
  }

  @override
  List<String> get myChannels => widget.myChannels;

  @override
  String? get shellChannel => widget.channel;

  @override
  ValueChanged<String>? get onShellChannel => widget.onChannelChanged;

  @override
  void loadScope(List<String> ids) {
    // STATE: 선택 채널 → 상품 · 공식 예고 → 배너 + 가로 줄
    _future = Future.wait([
      widget.loaders.kits(ids),
      widget.loaders.announcements(ids),
    ]).then((r) => _HomeData(r[0] as List<Kit>, r[1] as List<Announcement>));
  }

  @override
  void initState() {
    super.initState();
    initScope();
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
    // A-2 아이콘 줄 — 모든 탭과 같은 자리(오른쪽 끝), 검색창 없이
    final tools = ToolRow(
      tools: [
        if (_section case final sec?)
          ListToolIcons(tools: _listTools, pool: sec == HomeSection.announcements ? null : lists[sec] ?? const [])
        else
          FilterButton(count: _homeFilter.count, onTap: () => _openHomeFilter(data.kits)), // A-11
      ],
    );
    final ids = scopeIds;
    if (data.kits.isEmpty && data.announcements.isEmpty) {
      final noData = ids.isNotEmpty && ids.every((id) => !channelOf(id).hasData);
      return _pinned(
        tools,
        ListView(
          children: [
            EmptyView(
              // A-7 P09
              icon: Icons.auto_awesome_outlined,
              message: ids.isEmpty
                  ? tr('내 채널이 비어 있어요')
                  : noData
                  ? trf('{channel} 상품이 아직 없어요', {'channel': tr(channelOf(ids.first).label)})
                  : tr('새 소식이 없어요'),
              detail: ids.isEmpty ? tr('채널 관리에서 채널을 추가해 보세요') : tr('상품이 들어오면 여기에 먼저 보여요'),
              action: channel == allChannelId
                  ? null
                  : OutlinedButton(onPressed: () => selectChannel(allChannelId), child: Text(tr('전체 보기'))),
            ),
          ],
        ),
      );
    }

    _Item kitItem(Kit k) => _Item(k.image, k.name, kit: k);

    // O 전체 목록 (홈 위쪽은 그대로, 아래만 바뀜)
    if (_section case final sec?) {
      return _pinned(
        tools,
        SectionListView(
          key: ValueKey(sec),
          title: _titleOf(sec, data.announcements),
          subtitle: joinDot([
            if (channel != allChannelId) tr(channelOf(channel).label),
            if (sec == HomeSection.recent) recentRangeLabel,
          ]),
          kits: lists[sec] ?? const [],
          announcements: sec == HomeSection.announcements ? data.announcements : null,
          history: sec == HomeSection.viewed,
          sort: sec == HomeSection.month ? KitSort.release : KitSort.newest,
          tools: _listTools,
          onBack: _closeSection,
          loaders: widget.loaders,
        ),
      );
    }

    final rows = [
      _Row(
        tr('새 상품'),
        [for (final k in recent) kitItem(k)],
        subtitle: joinDot([
          recentRangeLabel,
          if (Catalog.instance.updatedAt.length >= 10)
            trf('데이터 {date}', {'date': dateDot(Catalog.instance.updatedAt.substring(5))}),
        ]),
        onMore: () => _openSection(HomeSection.recent),
      ),
      _Row(currentMonthTitle, [for (final k in month) kitItem(k)], onMore: () => _openSection(HomeSection.month)),
      _Row(
        _titleOf(HomeSection.announcements, data.announcements),
        [for (final a in data.announcements) _Item(a.image, a.title, ann: a)],
        wide: true,
        onMore: () => _openSection(HomeSection.announcements),
      ),
      _Row(tr('최근 본 상품'), [for (final k in viewed) kitItem(k)], onMore: () => _openSection(HomeSection.viewed)),
    ];
    final heroes = annHeroes(data.announcements); // 공식 먼저, 채운 비공식은 뒤

    // 당겨서 새로 고침 = Gunpula 새 데이터 확인 (바뀌면 앱 셸이 화면을 다시 불러온다)
    return _pinned(
      tools,
      RefreshIndicator(
        onRefresh: () async {
          final changed = await Catalog.instance.refresh();
          if (!changed && mounted) setState(reloadScope);
        },
        child: ListView(
          padding: EdgeInsets.only(bottom: navClearance(context)),
          children: [
            if (heroes.isNotEmpty)
              _HeroBanner(
                // A-3 떠 있는 카드
                items: heroes,
                onTap: (a) => openAnnouncement(context, a, loaders: widget.loaders, list: heroes),
              ),
            for (final row in rows)
              if (row.items.isNotEmpty)
                SectionPanel(
                  // A-8 흰 띠 + 머리카락 줄 = 층 구분 (상세와 같은 부품)
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
      ),
    );
  }

  /// A-2 아이콘 줄은 목록 밖 위에 고정 — 한참 내려 읽으면 채널 바만 접히고(S-13) 아이콘 줄은 남는다 (네 탭 같게)
  Widget _pinned(Widget tools, Widget list) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      tools,
      Expanded(child: list),
    ],
  );
}

/// A-3 예고 배너 — 화면 끝까지 꽉 찬 16:9 사진, 아래에 상태와 제목.
/// 사진 있는 공식 예고가 먼저, 모자랄 때만 비공식 (lib/logic/announcement_match.dart annHeroIds)
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
                                    AnnTag(a), // A-4 P01 단계(라이브면 때) = 다른 꼬리표와 같은 모양
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

/// A-6 가로 스크롤 줄 — ProductTile (사진 + 이름 두 줄, 날짜·가격 없음)
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
    // 화면 밖 몇 칸도 미리 받아 둔다 — 옆으로 밀거나 「전체 보기」를 열면 바로 보이게
    prefetchImages(context, [for (final it in row.items.take(12)) it.image], size: width);
    return SizedBox(
      height: productTileHeight(context, width, imageAspect: aspect), // 이름 두 줄 (글자 크기 설정을 따른다)
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Gp.gutter),
        itemCount: row.items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final item = row.items[i];
          final kit = item.kit;
          final ann = item.ann;
          return ProductTile(
            image: item.image,
            title: item.title,
            imageWidth: width,
            imageAspect: aspect,
            id: kit?.id ?? item.ann?.id,
            onTap: () {
              if (kit != null) {
                openKitDetail(context, kit, loaders: loaders, list: [for (final it in row.items) ?it.kit]);
              } else if (ann != null) {
                openAnnouncement(context, ann, loaders: loaders, list: [for (final it in row.items) ?it.ann]);
              }
            },
            // A-9 P07 상품 = 리본 · ♡ / 라이브 예고 · 아직 안 열린 예약 = 사진 귀퉁이에 때 / 비공식 소식 = 「비공식」
            // (보통 예고는 사진 + 이름만)
            marks: kit != null
                ? QuickMarks(kit: kit)
                : ann != null &&
                      (ann.isStream || ann.unofficial || annPreorderStage(ann, appNow()) == PreorderStage.upcoming)
                ? Align(
                    alignment: Alignment.topLeft,
                    child: Padding(padding: const EdgeInsets.all(6), child: AnnTag(ann, onPhoto: true)),
                  )
                : null,
          );
        },
      ),
    );
  }
}

/// A-26 사용법의 "홈" 묶음 (서랍 › 사용법 — s_app_shell.dart)
List<HelpItem> get homeHelp => [
  HelpItem(Icons.photo_camera_outlined, tr('찍어서 찾기')),
  HelpItem(Icons.tune, tr('필터')),
  HelpItem(Icons.bookmark_border, tr('구매함 (사진 왼쪽 위 리본 +)'), color: Gp.own),
  HelpItem(Icons.grid_view_outlined, tr('격자 · 목록 (전체 보기 안)')),
];
