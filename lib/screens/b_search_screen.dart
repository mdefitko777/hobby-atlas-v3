// 화면 B: 도감 · 검색 (아래 탭 "도감") — 검색어가 없으면 도감으로 둘러보기, 있으면 이름 · 번호 · 작품 · 기체, 또는 "말로 설명해서" 찾기.
// v3: 검색과 도감을 한 탭으로 합쳤다 (컬렉션의 도감 보기를 이리로 옮김).
//
// ┌──────── 디자인 가이드 대응표: B 검색 ──────────────────────────────────────────────┐
// │ 번호 │ Flutter 위젯명                     │ 비즈니스 명칭(한글)                    │ 원칙(P번호)   │
// │ B-1  │ ChannelHeader                      │ 검색 범위 = 내 채널 (C-0 공용)          │ P04 · P06     │
// │ B-2  │ GpSearchBar (지우기 + 카메라)       │ 검색창(홈과 같은 모양)                 │ P07 · P04     │
// │ B-3  │ Wrap(InputChip ×) — 검색창을 누르면   │ 최근 검색어 (기기 저장 · 20개 · 되돌리기) │ P06 · P03     │
// │ B-4  │ 2열 목록 (×횟수) · 새 상품 줄         │ 자주 찾은 (내 검색 횟수) · 새로 들어온    │ P06 · P01     │
// │ B-5  │ 예시 문장 칩                        │ 설명으로 찾기 (낱말 표 · AI 아님)        │ P10 · P07     │
// │ B-6  │ ThumbRow + 일치도 %                 │ 설명과 겹친 상품 (맞은 낱말 = 이유)      │ P01 · P09     │
// │ B-7  │ SectionListView (O 전체 목록 재사용) │ 검색 결과 · 필터 · 정렬 · 격자/목록      │ P08 · 적응형 │
// │ B-9  │ 줄 "전체 상품 n개 ›" → SectionListView │ 내 채널 상품 전부 (옛 처음 화면)          │ P07 · P06     │
// │ B-14 │ GuideView (g_guide_view.dart)       │ 처음 화면 = 도감 둘러보기 (G-1 … G-9)     │ P06 · P01     │
// │ B-15 │ ViewIconToggle 세대 · 종류 (검색창 줄) │ 도감 두 가지: 세대(작품 · 시대 · 게임) / 종류(HG · MG … · 인형 …, G-10) │ P06 · P07 │
// │ B-12 │ GuideHits (guide/guide_search.dart) │ 검색어에 맞는 작품 · 기체 → 도감(그 기체 시트) │ P07 · P06 │
// │ B-13 │ ToolIcon 기체별 + GroupedResults     │ 결과를 기체별로 묶기 (상품 n · 가짐 m)     │ P01 · P07     │
// │ B-8  │ LoadingView / ErrorView / EmptyView │ 불러오는 중 · 오류 · 결과 없음          │ P01 · P09     │
// │ B-10 │ TagSearchSection (R 화면 파일)        │ 메자스타 · 프렌다 태그 · 게임 이름 찾기   │ P07 · P06     │
// │ B-11 │ 위 줄 ? (S-19, searchHelp)          │ 검색창 줄 아이콘 뜻 한 줄씩              │ P10           │
// └──────────────────────────────────────────────────────────────────────────────────┘
// 검색은 기기 안: 받아 둔 Gunpula 목록에서 거른다. 설명으로 찾기 = lib/logic/sentence_search.dart (낱말 맞추기, 서버 · AI 없음).
// 서버가 없어 "인기 검색어" 순위는 만들지 않는다 → 내 검색 횟수(자주 찾은)와 이번 주 새 상품으로.
// 현행 앱 문제: 정확한 이름을 모르면 못 찾음 · 필터 입구가 여러 개 → v2는 검색창 하나 + 말로 찾기.
import 'package:flutter/material.dart';

import '../api.dart';
import '../data/user_store.dart';
import '../channels.dart';
import '../logic/kit_rules.dart';
import '../marks.dart';
import '../models.dart';
import '../logic/sentence_search.dart';
import '../level.dart' show tierHelpItems;
import '../theme.dart';
import '../widgets.dart';
import 'c_channel_screen.dart';
import 'd_kit_detail_screen.dart';
import 'g_guide_view.dart';
import 'guide/guide_search.dart';
import 'guide/line_guide.dart';
import 'o_see_all_screen.dart';
import 'r_mezastar_screen.dart' show TagSearchSection;

/// B-5 설명으로 찾기 예시 (실제 데이터에서 후보가 나오는 문장)
const sentenceExamples = ['샤아 전용 자쿠 HG', '수성의 마녀 에어리얼 HG', '이브이 인형', '드래곤 블레이드 베이'];

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.myChannels,
    required this.onMyChannelsChanged,
    required this.onCamera,
    this.focusTick = 0,
    this.browseTick = 0,
    this.leading,
    this.loaders = const Loaders(),
  });

  final List<String> myChannels;
  final ValueChanged<List<String>> onMyChannelsChanged;

  /// 검색창 카메라 → 앱 셸의 찍어서 찾기 시트
  final VoidCallback onCamera;

  /// 값이 바뀌면 검색창에 커서를 둔다 (홈 검색 알약에서 넘어올 때)
  final int focusTick;

  /// 값이 바뀌면 검색어를 지우고 도감 둘러보기로 (내 정보 Lv · 도감 숫자에서 넘어올 때)
  final int browseTick;
  final Widget? leading;
  final Loaders loaders;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with ChannelScope {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  String _query = '';
  late Future<List<Kit>> _future;

  /// 설명으로 찾기 결과 (같은 검색어 · 같은 목록이면 다시 세지 않는다 — 8,800개 × 낱말)
  (String, List<Kit>, List<SentenceHit>)? _sentence;

  List<SentenceHit> _sentenceHits(List<Kit> kits) {
    final memo = _sentence;
    if (memo != null && memo.$1 == _query && identical(memo.$2, kits)) return memo.$3;
    final hits = sentenceSearch(_query, kits);
    _sentence = (_query, kits, hits);
    return hits;
  }

  @override
  List<String> get myChannels => widget.myChannels;

  @override
  void loadScope(List<String> ids) {
    _future = widget.loaders.kits(ids); // STATE: 검색 범위(채널) → GET /kits
    _all = null;
    _future.then((k) {
      if (mounted) setState(() => _all = k); // 필터 시트가 셀 상품
    }, onError: (Object _) {});
  }

  /// 결과의 필터 · 격자/목록 (검색창 줄 아이콘)
  final _tools = ListTools();
  List<Kit>? _all;

  /// B-14 둘러보기(도감)의 필터 — 단계(아직 · ♡ · 구매함 · 내 사진 = 내 진행) · 등급 · 종류 · 시대 · 정렬
  final _guideFilter = GuideFilterController();

  /// B-9 "전체 상품" 목록을 펼쳤나 (검색어 없이)
  bool _allProducts = false;

  /// B-13 결과를 기체별로 묶기
  bool _grouped = false;

  /// B-15 도감 둘러보기 축: false = 세대(작품 · 시대 · 게임), true = 종류(등급 · 상품 종류)
  bool _byType = false;

  /// B-15 종류 도감에서 내가 좋아요 · 구매함한 것이 있는 묶음만 (필터 버튼)
  bool _mineOnly = false;

  /// B-12 · B-13 건담 도감 표 (처음 쓸 때 한 번)
  Future<GuideIndex>? _index;
  Future<GuideIndex> get _guideIndex =>
      _index ??= widget.loaders.guideIndex().catchError((Object _) => GuideIndex.empty);

  @override
  void initState() {
    super.initState();
    reloadScope();
    // 검색창을 누르면(포커스) 최근 · 자주 찾은 · 설명으로 찾기 판, 벗어나면 다시 전체 상품
    _focus.addListener(() => setState(() {})); // STATE: 포커스 → 보여 줄 판
  }

  @override
  void didUpdateWidget(SearchScreen old) {
    super.didUpdateWidget(old);
    syncScope();
    if (widget.focusTick != old.focusTick) _focus.requestFocus();
    if (widget.browseTick != old.browseTick) {
      _setQuery(''); // STATE: 내 정보 → 도감 둘러보기
      _focus.unfocus();
      _allProducts = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _guideFilter.dispose();
    super.dispose();
  }

  /// 검색어도 포커스도 없고 전체 상품도 안 펼쳤으면 = 도감 둘러보기
  bool get _browsing => _query.isEmpty && !_focus.hasFocus && !_allProducts;

  void _setQuery(String q) {
    _controller.text = q;
    _controller.selection = TextSelection.collapsed(offset: q.length);
    setState(() => _query = q.trim()); // STATE: 검색어 → 결과 격자 · 설명 후보
  }

  /// 검색어를 남긴다 (최근 검색 맨 앞 + 횟수, 기기에 저장)
  void _submit(String q) {
    final t = q.trim();
    if (t.isEmpty) return;
    Marks.read(context).store.addRecentSearch(t); // STATE: 검색어 → 최근 검색 · 자주 찾은 (UserStore → 다시 그림)
  }

  /// 칩 · 줄을 눌러 검색 = 검색창에 넣고 남기기
  void _search(String q) {
    _setQuery(q);
    _submit(q);
  }

  void _removeRecent(UserStore me, String q) {
    final i = me.removeRecentSearch(q);
    if (i < 0) return;
    showToast(context, '「$q」을(를) 지웠어요', onUndo: () => me.insertRecentSearch(i, q));
  }

  void _clearRecent(UserStore me) {
    final before = me.clearRecentSearches();
    showToast(context, '검색 기록을 지웠어요', onUndo: () => me.restoreRecentSearches(before));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _browsing,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_query.isNotEmpty) _setQuery('');
        _focus.unfocus(); // 뒤로 = 판 닫고 도감
        setState(() => _allProducts = false);
      },
      child: _page(),
    );
  }

  Widget _page() {
    return Column(
      children: [
        ChannelHeader(
          // B-1 P04
          leading: widget.leading,
          myChannels: widget.myChannels,
          selected: channel,
          onSelect: selectChannel,
          onMyChannelsChanged: widget.onMyChannelsChanged,
        ),
        ToolRow(
          // B-2 P04 모든 탭과 같은 줄: [검색창][필터][격자 · 목록]
          field: GpSearchBar(
            controller: _controller,
            focusNode: _focus,
            onChanged: (q) => setState(() => _query = q.trim()),
            onSubmitted: _submit,
            onCamera: widget.onCamera,
          ),
          tools: _browsing
              ? [
                  _byType
                      ? FilterButton(
                          // B-15 종류 도감: 전부 · 내 것만
                          count: _mineOnly ? 1 : 0,
                          onTap: () async {
                            final v = await showPickSheet<bool>(
                              context,
                              title: '종류 도감',
                              values: const [false, true],
                              current: _mineOnly,
                              label: (m) => m ? '내 것만 (좋아요 · 구매함)' : '전부',
                            );
                            if (v != null) setState(() => _mineOnly = v); // STATE: 내 것만 → 묶음
                          },
                        )
                      : FilterButton(
                          // B-14 도감 필터 ('전체' 채널은 고르기 판이라 없음)
                          count: _guideFilter.filter.count,
                          onTap: channel == allChannelId
                              ? null
                              : () async {
                                  await _guideFilter.openSheet(context); // STATE: 도감 필터 → 칸
                                  if (mounted) setState(() {});
                                },
                        ),
                  ViewIconToggle(
                    // B-15
                    mine: _byType,
                    onChanged: (v) => setState(() => _byType = v), // STATE: 도감 축 → 세대 ↔ 종류
                    allIcon: Icons.auto_awesome_mosaic_outlined,
                    mineIcon: Icons.category_outlined,
                    allTip: '세대별 도감',
                    mineTip: '종류별 도감',
                  ),
                ]
              : [
                  ListToolIcons(
                    tools: _tools,
                    pool: _all == null
                        ? null
                        : [
                            for (final k in _all!)
                              if (kitMatches(k, _query)) k,
                          ],
                  ),
                  if (_query.isNotEmpty && (channel == allChannelId || channel == 'gundam'))
                    ToolIcon(
                      // B-13
                      icon: Icons.account_tree_outlined,
                      tip: '기체별로 묶기',
                      on: _grouped,
                      onTap: () => setState(() => _grouped = !_grouped), // STATE: 결과 묶기
                    ),
                ],
        ),
        Expanded(
          child: FutureBuilder<List<Kit>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const LoadingView(); // B-8 P01
              }
              if (snap.hasError) {
                return ErrorView(message: '${snap.error}', onRetry: () => setState(reloadScope)); // B-8 P09
              }
              // 검색어가 없으면: 검색창을 누른 동안 = 최근 · 자주 찾은 · 설명으로 찾기, 아니면 = 도감(B-14) · 전체 상품(B-9)
              if (_browsing) return _browse(snap.data!);
              return _query.isEmpty && _focus.hasFocus ? _idle(snap.data!) : _results(snap.data!);
            },
          ),
        ),
      ],
    );
  }

  /// B-14 처음 화면: 맨 위 "전체 상품 n개 ›"(B-9) + 도감 (채널 '전체' = IP 고르기)
  Widget _browse(List<Kit> kits) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          key: const ValueKey('all-products'),
          onTap: () => setState(() => _allProducts = true), // STATE: 전체 상품 펼치기
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
            child: Row(
              children: [
                const Icon(Icons.view_agenda_outlined, size: Gp.iS, color: Gp.muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '전체 상품 ${kits.length}개',
                    style: const TextStyle(fontSize: Gp.t14, color: Gp.muted),
                  ),
                ),
                const Icon(Icons.chevron_right, size: Gp.iM, color: Gp.muted),
              ],
            ),
          ),
        ),
        Expanded(
          child: _byType
              ? LineGuideView(
                  // B-15 종류별 도감 (G-10)
                  channel: channel,
                  loaders: widget.loaders,
                  mineOnly: _mineOnly,
                  myChannels: widget.myChannels,
                  onPickChannel: selectChannel,
                )
              : GuideView(
                  channel: channel,
                  myChannels: widget.myChannels,
                  onPickChannel: selectChannel,
                  loaders: widget.loaders,
                  filter: _guideFilter,
                ),
        ),
      ],
    );
  }

  /// 검색어가 없을 때: 최근 검색 · 자주 찾은 · 새로 들어온 · 설명으로 찾기
  Widget _idle(List<Kit> kits) {
    // 이 판을 눌러도 "검색창 밖을 누름"으로 치지 않게 — 아니면 포커스가 먼저 풀려 판이 사라지고 누른 칩이 안 먹는다
    return TextFieldTapRegion(child: _idleList(kits));
  }

  Widget _chip(String label, {IconData? icon, VoidCallback? onDeleted, required VoidCallback onTap}) => InputChip(
    avatar: icon == null ? null : Icon(icon, size: Gp.iS, color: Gp.accent),
    label: Text(label),
    onPressed: onTap,
    onDeleted: onDeleted,
    deleteIcon: const Icon(Icons.close, size: Gp.iS),
    backgroundColor: Gp.panel,
    side: const BorderSide(color: Gp.line),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(Gp.rSmall))),
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact,
  );

  Widget _idleList(List<Kit> kits) {
    final me = Marks.of(context).store; // 최근 검색 · 횟수가 바뀌면 다시 그림
    final recent = me.recentSearches;
    final frequent = me.frequentSearches();
    final half = (frequent.length / 2).ceil();
    final fresh = newThisWeek(kits);
    Widget wrap(List<Widget> children) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gp.gutter),
      child: Wrap(spacing: 8, runSpacing: 8, children: children),
    );
    Widget freqCol(Iterable<MapEntry<String, int>> part) => Expanded(
      child: Column(
        children: [
          for (final e in part)
            InkWell(
              onTap: () => _search(e.key),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Row(
                  children: [
                    Expanded(child: Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Text(
                      '×${e.value}', // 내가 찾은 횟수 (순위 아님)
                      style: const TextStyle(fontSize: Gp.t12, color: Gp.faint),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
    return ListView(
      padding: EdgeInsets.only(bottom: navClearance(context)),
      children: [
        if (recent.isNotEmpty) ...[
          SectionHeader(
            '최근 검색',
            padding: const EdgeInsets.fromLTRB(16, 16, 4, 10),
            trailing: IconButton(
              tooltip: '전체 삭제',
              visualDensity: VisualDensity.compact,
              onPressed: () => _clearRecent(me),
              icon: const Icon(Icons.delete_sweep_outlined, size: Gp.iM, color: Gp.muted),
            ),
          ),
          wrap([
            for (final q in recent) _chip(q, onTap: () => _search(q), onDeleted: () => _removeRecent(me, q)), // B-3 P03
          ]),
        ],
        if (frequent.isNotEmpty) ...[
          const SectionHeader('자주 찾은', padding: EdgeInsets.fromLTRB(16, 24, 12, 10)), // B-4 내 검색 횟수
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gp.gutter),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [freqCol(frequent.take(half)), const SizedBox(width: 16), freqCol(frequent.skip(half))],
            ),
          ),
        ],
        if (fresh.isNotEmpty) ...[
          const SectionHeader('새로 들어온', subtitle: '이번 주', padding: EdgeInsets.fromLTRB(16, 24, 12, 4)), // B-4
          for (final k in fresh)
            ThumbRow(
              image: k.image,
              title: k.name,
              size: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              subtitle: joinDot([channelOf(k.franchiseId).label, k.line]),
              onTap: () => openKitDetail(context, k, loaders: widget.loaders, list: fresh),
            ),
        ],
        const SectionHeader('설명으로 찾기', padding: EdgeInsets.fromLTRB(16, 24, 12, 10)), // B-5 P10
        wrap([
          for (final example in sentenceExamples)
            _chip(example, icon: Icons.manage_search, onTap: () => _search(example)),
        ]),
      ],
    );
  }

  /// 검색어가 있을 때: 설명과 겹친 상품(낱말이 둘 이상이면) + 결과 격자
  Widget _results(List<Kit> kits) {
    final results = kits.where((k) => kitMatches(k, _query)).toList(); // 검색어가 없으면(둘러보기) 전부
    final candidates = _query.isEmpty ? const <SentenceHit>[] : _sentenceHits(kits);

    // B-10 메자스타 · 프렌다 태그 (포켓몬 · 전체 채널에서), 게임 이름이면 도감 입구
    final tags = TagSearchSection(query: _query, tags: channel == allChannelId || channel == 'pokemon');
    // B-12 건담 작품 · 기체 (건담 · 전체 채널에서)
    final gundam = _query.isNotEmpty && (channel == allChannelId || channel == 'gundam');
    final guide = !gundam
        ? const SizedBox.shrink()
        : FutureBuilder<GuideIndex>(
            future: _guideIndex,
            builder: (context, s) => s.data == null
                ? const SizedBox.shrink()
                : GuideHits(index: s.data!, query: _query, loaders: widget.loaders),
          );
    if (results.isEmpty && candidates.isEmpty) {
      return ListView(
        children: [
          tags,
          guide,
          EmptyView(
            // B-8 P09
            icon: Icons.search_off,
            message: '「$_query」와 일치하는 상품이 없어요',
            detail: channel == allChannelId
                ? '이름 대신 생김새·작품을 문장으로 적어 보세요'
                : '지금은 ${channelOf(channel).label} 안에서만 찾고 있어요',
            action: channel == allChannelId
                ? OutlinedButton(onPressed: () => _setQuery(''), child: const Text('검색어 지우기'))
                : OutlinedButton(onPressed: () => selectChannel(allChannelId), child: const Text('전체 채널에서 찾기')),
          ),
        ],
      );
    }

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        tags,
        guide,
        if (candidates.isNotEmpty)
          SentenceCandidates(
            hits: candidates,
            onTap: (k) => openKitDetail(context, k, loaders: widget.loaders, list: [for (final h in candidates) h.kit]),
          ), // B-6
      ],
    );
    if (_grouped && gundam) {
      // B-13 기체별 (필터는 위 줄 그대로)
      return FutureBuilder<GuideIndex>(
        future: _guideIndex,
        builder: (context, s) => s.data == null
            ? const LoadingView()
            : ListenableBuilder(
                listenable: _tools,
                builder: (context, _) => GroupedResults(
                  kits: results.where(_tools.filter.matches).toList(),
                  index: s.data!,
                  loaders: widget.loaders,
                  header: header,
                ),
              ),
      );
    }

    // B-7 홈 전체 목록과 같은 목록 (필터 · 정렬 · 격자/목록), 설명 후보는 맨 위 머리
    return SectionListView(
      key: const ValueKey('search'),
      tools: _tools,
      title: _query.isEmpty ? '전체 상품' : '검색 결과',
      subtitle: channel == allChannelId ? '' : channelOf(channel).label,
      kits: results,
      header: header,
      onBack: () {
        _setQuery(''); // STATE: 돌아가기 → 도감 둘러보기
        _focus.unfocus();
        setState(() => _allProducts = false);
      },
      loaders: widget.loaders,
    );
  }
}

/// B-6 설명과 겹친 상품 — 맞은 낱말 / 전체 낱말 = 일치도, 맞은 낱말 = 이유 (사진 찾기 화면도 같이 쓴다)
class SentenceCandidates extends StatelessWidget {
  const SentenceCandidates({
    super.key,
    required this.hits,
    required this.onTap,
    this.margin = const EdgeInsets.fromLTRB(16, 10, 16, 0),
  });
  final List<SentenceHit> hits;
  final ValueChanged<Kit> onTap;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: Gp.panel,
        borderRadius: BorderRadius.circular(Gp.rLarge),
        border: Border.all(color: Gp.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.manage_search, size: Gp.iM, color: Gp.accent),
              SizedBox(width: 6),
              Text('설명과 겹친 상품', style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          for (final h in hits)
            ThumbRow(
              image: h.kit.image,
              title: h.kit.name,
              subtitle: h.reason, // 맞은 낱말
              padding: const EdgeInsets.symmetric(vertical: 6),
              onTap: () => onTap(h.kit),
              trailing: Text(
                '${h.score}%', // 일치도 P01
                style: TextStyle(fontWeight: FontWeight.w700, color: h.score >= 85 ? Gp.accent : Gp.muted),
              ),
            ),
        ],
      ),
    );
  }
}

/// B-11 ? 도움말 (위 줄 ? 의 "도감" 묶음 — s_app_shell.dart). 도감 칸 단계는 lib/level.dart 와 같은 그림
List<HelpItem> searchHelp() => [
  const HelpItem(Icons.photo_camera_outlined, '찍어서 찾기 (사진 · 바코드)'),
  const HelpItem(Icons.tune, '필터 (도감: 단계 = 내 진행 · 등급 · 종류 · 시대)'),
  const HelpItem(Icons.auto_awesome_mosaic_outlined, '세대별 도감 (작품 · 시대 · 게임)'),
  const HelpItem(Icons.category_outlined, '종류별 도감 (HG · MG … · 인형 · 피규어 …)'),
  const HelpItem(Icons.view_agenda_outlined, '전체 상품 목록'),
  const HelpItem(Icons.grid_view_outlined, '격자로 보기'),
  const HelpItem(Icons.view_list_outlined, '목록으로 보기'),
  const HelpItem(Icons.account_tree_outlined, '검색 결과를 기체별로 묶기'),
  const HelpItem(Icons.manage_search, '설명으로 찾기 예'),
  const HelpItem(Icons.build_outlined, '베이 조합 만들기 (베이 도감)'),
  const HelpItem.group('도감 칸'),
  ...tierHelpItems(),
];
