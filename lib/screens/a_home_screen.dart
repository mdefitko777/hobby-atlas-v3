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
// └──────────────────────────────────────────────────────────────────────────────────┘
// 전환: A-2 → 검색 탭(옆으로). › → 같은 탭 안에서 O 전체 목록(위쪽 머리 · 검색창은 그대로, 뒤로 = 홈). 상품 카드 → D 상품 상세(쌓기). 배너 · 예고 카드 → J 공식 예고 상세(쌓기).
// 줄 안에는 날짜·가격을 쓰지 않는다 — 궁금하면 눌러서 상세에서 본다 (P08).
// 현행 앱 문제: 홈 = 버전 번호·총 개수·IP 입구 카드 → v2 홈 = "내 채널의 새 소식"만.
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
import 'f_collection_screen.dart' show CollectionJump;
import 'j_announcement_screen.dart';
import 'o_see_all_screen.dart';

/// 최근 본 상품 — 상세를 열 때마다 기기에 남긴다. 아직 없으면 가짜 데이터(db.json) 예시
List<String> get recentViewedIds => UserStore.instance.recentViewed.isNotEmpty
    ? UserStore.instance.recentViewed
    : const ['gu03', 'be43', 'po21', 'fa30', 'ar35'];

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
  HomeSection.limited => '한정 · PB',
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

  /// 전체 목록일 때 검색창 = 그 목록 안에서만 찾기 (O-7)
  final _searchCtrl = TextEditingController();
  String _query = '';

  void _openSection(HomeSection s) => setState(() {
    _section = s; // STATE: › → 홈 아래쪽이 전체 목록으로
    _searchCtrl.clear();
    _query = '';
  });

  void _closeSection() => setState(() {
    _section = null; // STATE: ‹ · 뒤로 → 홈
    _searchCtrl.clear();
    _query = '';
  });

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
          child: FutureBuilder<_HomeData>(
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
      ],
    );
  }

  Widget _body(_HomeData data) {
    final search = Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: _section == null
          ? GpSearchBar(onTap: widget.onOpenSearch, onCamera: widget.onCamera) // A-2 P04
          : GpSearchBar(
              // O-7 이 목록 안에서만
              controller: _searchCtrl,
              hint: '${_titleOf(_section!)}에서 찾기',
              onChanged: (v) => setState(() => _query = v), // STATE: 검색어 → 목록 거르기
              onCamera: widget.onCamera,
            ),
    );
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

    final byId = {for (final k in data.kits) k.id: k};
    _Item kitItem(Kit k) => _Item(k.image, k.name, kit: k);
    final recent = [
      for (final k in data.kits)
        if (k.recent) k,
    ];
    final month = [
      for (final k in data.kits)
        if (k.month) k,
    ];
    final viewed = [for (final id in recentViewedIds) ?byId[id]];
    final limited = [
      for (final k in data.kits)
        if (k.pb || k.limited) k,
    ];
    final lists = {
      HomeSection.recent: recent,
      HomeSection.month: month,
      HomeSection.viewed: viewed,
      HomeSection.limited: limited,
    };

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

    final shortcuts = <_Shortcut>[
      _Shortcut(Icons.grid_view_rounded, '도감', () => widget.onJump?.call(CollectionJump.guide), mine: true),
      _Shortcut(
        Icons.calendar_month_outlined,
        currentMonthTitle.replaceAll(' 발매', ''),
        () => _openSection(HomeSection.month),
      ),
      _Shortcut(Icons.workspace_premium_outlined, '한정 · PB', () => _openSection(HomeSection.limited)),
      _Shortcut(Icons.campaign_outlined, '공식 예고', () => _openSection(HomeSection.announcements)),
    ];

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
          _MyBoard(kits: data.kits, scope: scopeIds, loaders: widget.loaders, onJump: widget.onJump), // A-10
          _ShortcutRow(items: shortcuts), // A-11
          if (heroes.isNotEmpty)
            ColoredBox(
              color: Gp.panel,
              child: _HeroBanner(
                // A-3
                items: heroes,
                onTap: (a) => openAnnouncement(context, a, loaders: widget.loaders),
              ),
            ),
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
        // 넓은 창에서는 너무 커지지 않게 높이 제한 (적응형)
        // 넓은 창 · 가로 폰에서는 화면 높이의 절반을 넘지 않게 (적응형)
        final maxH = (MediaQuery.sizeOf(context).height * 0.5).clamp(160.0, 420.0);
        final imageHeight = (box.maxWidth * 9 / 16).clamp(160.0, maxH);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: imageHeight + 78,
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
                    return GestureDetector(
                      onTap: () => widget.onTap(a),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: imageHeight, width: double.infinity, child: AppImage(a.image)),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${a.status} · ${channelOf(a.franchiseId).label}', // A-4 P01
                                  style: const TextStyle(
                                    fontSize: Gp.t11,
                                    letterSpacing: 0.8,
                                    color: Gp.muted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  a.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: Gp.t19, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 20, 18),
              child: PageDots(count: widget.items.length, index: _page, center: false),
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
    final width = row.wide ? 232.0 : 148.0;
    final aspect = row.wide ? 232 / 132 : 1.0;
    return SizedBox(
      height: width / aspect + 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: row.items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
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
                openKitDetail(context, kit, loaders: loaders);
              } else if (ann != null) {
                openAnnouncement(context, ann, loaders: loaders);
              }
            },
            marks: kit == null ? null : QuickMarks(kit: kit), // A-9 P07
          );
        },
      ),
    );
  }
}

/// A-10 내 보드 — 홈에서 "내 것"이 보이는 칸: 숫자 · 가장 급한 것 2개 · 도감 진행 1줄
class _MyBoard extends StatefulWidget {
  const _MyBoard({required this.kits, required this.scope, required this.loaders, this.onJump});
  final List<Kit> kits;
  final List<String> scope;
  final Loaders loaders;
  final ValueChanged<CollectionJump>? onJump;

  @override
  State<_MyBoard> createState() => _MyBoardState();
}

/// 도감 한 줄 (가장 많이 켠 작품 · 세대)
typedef _Lit = ({String label, int owned, int total});

class _MyBoardState extends State<_MyBoard> {
  late Future<_Lit?> _lit = _loadLit();

  @override
  void didUpdateWidget(_MyBoard old) {
    super.didUpdateWidget(old);
    if (old.scope.join() != widget.scope.join()) _lit = _loadLit();
  }

  Future<_Lit?> _loadLit() async {
    try {
      if (widget.scope.contains('gundam')) {
        final works = [...await widget.loaders.guideWorks()]..sort((a, b) => b.owned.compareTo(a.owned));
        final w = works.where((w) => w.owned > 0).firstOrNull;
        return w == null ? null : (label: w.name, owned: w.owned, total: w.total);
      }
      if (widget.scope.isEmpty) return null;
      final worlds = [...await widget.loaders.worlds(widget.scope.first)]..sort((a, b) => b.owned.compareTo(a.owned));
      final w = worlds.where((w) => w.owned > 0).firstOrNull;
      return w == null ? null : (label: w.label, owned: w.owned, total: w.total);
    } on Object {
      return null;
    }
  }

  /// 좋아요 · 구매함 중 날짜가 다가오는 것 (PB 예약 마감 > 발매일)
  List<(Kit, String, bool)> _upcoming(Marks marks) {
    final now = appNow();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final out = <(String, Kit, String, bool)>[];
    for (final k in widget.kits) {
      final st = marks.statusOf(k);
      if (st == CollectStatus.none) continue;
      if (st == CollectStatus.wanted && k.pbCloses.length >= 10 && k.pbCloses.compareTo(today) >= 0) {
        final d = DateTime.parse(k.pbCloses).difference(DateTime(now.year, now.month, now.day)).inDays;
        out.add((k.pbCloses, k, d == 0 ? '오늘 예약 마감' : '예약 마감 D-$d', true));
      } else if (k.date.length == 10 && k.date.compareTo(today) >= 0) {
        out.add((k.date, k, '${dateDot(k.date.substring(5))} 발매', false));
      } else if (k.date.length == 7 && k.date.compareTo(today.substring(0, 7)) >= 0) {
        out.add(('${k.date}-99', k, '${int.parse(k.date.substring(5))}월 발매', false));
      }
    }
    out.sort((a, b) => a.$1.compareTo(b.$1));
    return [for (final e in out.take(2)) (e.$2, e.$3, e.$4)];
  }

  @override
  Widget build(BuildContext context) {
    final marks = Marks.of(context); // 좋아요 · 구매함이 바뀌면 다시 그린다
    final me = UserStore.instance;
    final soon = _upcoming(marks);
    Widget count(String label, int n, CollectionJump j) => InkWell(
      onTap: () => widget.onJump?.call(j),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '$label '),
              TextSpan(
                text: '$n',
                style: const TextStyle(fontWeight: FontWeight.w700, color: Gp.ink),
              ),
            ],
          ),
          style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
        ),
      ),
    );
    return SectionPanel(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                '내 보드',
                style: TextStyle(fontSize: Gp.t16, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              count('구매', me.ownedCount, CollectionJump.owned),
              count('좋아요', me.wantedCount, CollectionJump.liked),
            ],
          ),
          const SizedBox(height: 8),
          if (soon.isEmpty)
            const Text(
              '좋아요한 상품의 예약 마감 · 발매일이 여기 먼저 떠요',
              style: TextStyle(fontSize: Gp.t12, color: Gp.faint),
            )
          else
            for (final (k, label, urgent) in soon)
              InkWell(
                onTap: () => openKitDetail(context, k, loaders: widget.loaders),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          k.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: Gp.t14),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: Gp.t12,
                          fontWeight: FontWeight.w600,
                          color: urgent ? Gp.danger : Gp.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 6),
          FutureBuilder<_Lit?>(
            future: _lit,
            builder: (context, snap) {
              final lit = snap.data;
              return InkWell(
                onTap: () => widget.onJump?.call(CollectionJump.guide),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: lit == null
                      ? const Text(
                          '도감: 구매함에 넣으면 칸이 켜져요 ›',
                          style: TextStyle(fontSize: Gp.t12, color: Gp.faint),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '도감 · ${lit.label}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
                                  ),
                                ),
                                Text(
                                  '${lit.owned}/${lit.total}',
                                  style: const TextStyle(fontSize: Gp.t12, fontWeight: FontWeight.w700, color: Gp.own),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: lit.total == 0 ? 0 : lit.owned / lit.total,
                                minHeight: 5,
                                backgroundColor: Gp.soft,
                                color: Gp.own,
                              ),
                            ),
                          ],
                        ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 바로 가기 한 칸
class _Shortcut {
  const _Shortcut(this.icon, this.label, this.onTap, {this.mine = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// 내 기록으로 가는 칸은 민트(가진 것 색)
  final bool mine;
}

/// A-11 아이콘 4칸 — 한 줄만 (8칸이면 배너 · 새 상품이 둘째 화면으로 밀린다)
class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({required this.items});
  final List<_Shortcut> items;

  @override
  Widget build(BuildContext context) {
    return SectionPanel(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
      child: Row(
        children: [
          for (final it in items)
            Expanded(
              child: InkWell(
                onTap: it.onTap,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: (it.mine ? Gp.own : Gp.accent).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(it.icon, size: 22, color: it.mine ? Gp.own : Gp.accent),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        it.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: Gp.t12, color: Gp.ink),
                      ),
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
