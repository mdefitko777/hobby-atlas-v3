// 화면 B: 검색 — 아래 탭 "검색" = 상품 둘러보기(전체 · 종류 · 세대, 검색창 없음).
// 찾기는 위 줄 🔍 가 여는 검색 덮개(앱 전체를 덮는 쌓기 화면): 이름 · 번호 · 작품 · 기체, 또는 "말로 설명해서" 찾기.
// 상품 화면과 같은 모양 · 같은 필터 하나. 내 수집 진행(도감)은 컬렉션 탭 "도감" 에 있다.
//
// ┌──────── 디자인 가이드 대응표: B 검색 ──────────────────────────────────────────────┐
// │ 번호 │ Flutter 위젯명                     │ 비즈니스 명칭(한글)                    │ 원칙(P번호)   │
// │ B-1  │ ChannelHeader                      │ 검색 범위 = 내 채널 (C-0 공용)          │ P04 · P06     │
// │ B-0  │ openSearch → 쌓기 화면(앱 전체 덮기)  │ 검색 덮개: ← · 검색창(바로 커서) · 필터 · 격자 · 목록 │ P07 · P03 │
// │ B-2  │ GpSearchBar (지우기 + 카메라)       │ 검색창 (덮개에만) · 카메라 = 사진으로 찾기 │ P07 · P04     │
// │ B-3  │ Wrap(InputChip ×) — 검색어가 없을 때 │ 최근 검색어 (기기 저장 · 20개 · 되돌리기) │ P06 · P03     │
// │ B-4  │ 2열 목록 (×횟수) · 새 상품 줄         │ 자주 찾은 검색어 (내 검색 횟수) · 새 상품 │ P06 · P01     │
// │ B-5  │ 예시 문장 칩                        │ 설명으로 찾기 (낱말 표 · AI 아님)        │ P10 · P07     │
// │ B-6  │ ThumbRow + 일치도 %                 │ 설명에 맞는 상품 (맞은 단어 = 이유)      │ P01 · P09     │
// │ B-7  │ SectionListView (O 전체 목록 재사용) │ 검색 결과 · 필터 · 정렬 · 격자/목록      │ P08 · 적응형 │
// │ B-9  │ 탭 "전체" (처음) → SectionListView │ 내 채널 상품 전부                        │ P07 · P06     │
// │ B-17 │ ToolRow (상자 없는 아이콘 줄)        │ 필터 · 격자 · 목록 — ♡ · 구매함 · 발매 예정 · 나라는 필터 시트 맨 위 │ P07 · P04 │
// │ B-14 │ UnderlineTab 전체 · 종류 · 세대      │ 둘러보기 세 가지 (아이콘 줄 아래, 컬렉션 탭 줄과 같은 자리) │ P06 · P04 │
// │ B-15 │ 탭 "종류" · "세대" → TypeBrowse · EraBrowse (B-20 · B-21) │ 공식 그림 + 이름만 → 그 분류 상품 (같은 필터) │ P06 · P08 │
// │ B-16 │ B-14 줄 오른쪽 글자 단추 → 아래 시트   │ 레고 채널만: 레고 범위 (최근 정식 세트 · 전부) — 아이콘 줄은 세 칸 그대로 │ P06 · P10 │
// │ B-12 │ GuideHits (guide/guide_search.dart) │ 검색어에 맞는 작품 · 기체 → 도감(그 기체 시트) │ P07 · P06 │
// │ B-18 │ ThumbRow 몇 줄 (제목에 검색어)       │ 예고 · 라이브 · 예약 찾기 → 예고 상세 (넘기면 맞은 것 전부) │ P07 · P06 │
// │ B-13 │ 결과 위 "기체별로 묶기" + GroupedResults │ 결과를 기체별로 묶기 (상품 n · 가짐 m) — 검색창 줄 아이콘은 그대로 │ P01 · P07 │
// │ B-8  │ LoadingView / ErrorView / EmptyView │ 불러오는 중 · 오류 · 결과 없음          │ P01 · P09     │
// │ B-10 │ TagSearchSection (R 화면 파일)        │ 메자스타 · 프렌다 태그 · 게임 이름 찾기   │ P07 · P06     │
// │ B-11 │ 서랍 › 사용법 (S-19, searchHelp)     │ 아이콘 뜻 한 줄씩                      │ P10           │
// └──────────────────────────────────────────────────────────────────────────────────┘
// 검색은 기기 안: 받아 둔 Gunpula 목록에서 거른다. 설명으로 찾기 = lib/logic/sentence_search.dart (낱말 맞추기, 서버 · AI 없음).
// 서버가 없어 "인기 검색어" 순위는 만들지 않는다 → 내 검색 횟수(자주 찾은 검색어)와 이번 주 새 상품으로.
// 왜 이렇게: 정확한 이름을 몰라도 찾게 — 필터 입구를 여럿 두지 않고 검색창 하나(위 줄 🔍) + 말로 찾기.
// 탭마다 있던 검색창은 뺐다 (2026-11-21 주인): 화면이 좁아 보여서 — 찾기는 어느 탭에서나 위 줄 🔍 한 곳.
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../api.dart';
import '../data/user_store.dart';
import '../channels.dart';
import '../logic/data_labels.dart';
import '../logic/kit_rules.dart';
import '../logic/lego_scope.dart';
import '../logic/preorder_open.dart' show annShownDay;
import '../marks.dart';
import '../models.dart';
import '../logic/sentence_search.dart';
import '../theme.dart';
import '../widgets.dart';
import 'b_category_browse.dart';
import 'c_channel_screen.dart';
import 'd_kit_detail_screen.dart';
import 'guide/guide_search.dart';
import 'j_announcement_screen.dart' show openAnnouncement;
import 'o_see_all_screen.dart';
import 'r_mezastar_screen.dart' show TagSearchSection;

/// B-5 설명으로 찾기 예시 (실제 데이터에서 후보가 나오는 문장)
const sentenceExamples = ['샤아 전용 자쿠 HG', '수성의 마녀 에어리얼 HG', '이브이 인형', '드래곤 블레이드 베이'];

/// 중국어 화면의 예시 — 위와 같은 순서 · 같은 뜻 (설명으로 찾기가 중국어도 읽어 같은 낱말이 잡힌다, test/sentence_search_zh_test.dart)
const sentenceExamplesZh = ['夏亚专用 扎古 HG', '水星的魔女 风灵 HG', '伊布 玩偶', '龙 战刃 陀螺'];

/// B-0 검색 덮개 열기 — 아래 탭 · 카메라 단추 · 반반 화면까지 덮는 쌓기 화면 (위 줄 🔍 · 컬렉션 빈 화면 · 카메라 결과
/// 「이름으로 검색」 · 공유로 찾기). 내 채널은 기기 기록에서 읽어 덮개 안에서 채널을 고치면 바로 따라간다
Future<void> openSearch(
  BuildContext context, {
  String? channel,
  ValueChanged<String>? onChannelChanged,
  required ValueChanged<List<String>> onMyChannelsChanged,
  required VoidCallback onCamera,
  Loaders loaders = const Loaders(),
}) {
  final store = Marks.read(context).store;
  var picked = channel; // 덮개 안에서 고른 채널 — 다시 그려도(최근 검색 저장 등) 처음 채널로 돌아가지 않게
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        body: SafeArea(
          child: ListenableBuilder(
            listenable: store,
            builder: (context, _) => SearchScreen(
              overlay: true,
              myChannels: store.myChannels,
              onMyChannelsChanged: onMyChannelsChanged,
              channel: picked,
              onChannelChanged: (id) {
                picked = id;
                onChannelChanged?.call(id);
              },
              onCamera: onCamera,
              loaders: loaders,
            ),
          ),
        ),
      ),
    ),
  );
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.myChannels,
    required this.onMyChannelsChanged,
    this.channel,
    this.onChannelChanged,
    required this.onCamera,
    this.overlay = false,
    this.leading,
    this.loaders = const Loaders(),
  });

  final List<String> myChannels;
  final ValueChanged<List<String>> onMyChannelsChanged;

  /// 앱 셸이 든 이 탭의 채널 · 고르면 셸에 알림 (채널 맞춰 보기, ChannelScope)
  final String? channel;
  final ValueChanged<String>? onChannelChanged;

  /// 검색창 카메라 → 앱 셸의 찍어서 찾기 시트 (사진으로 찾기 입구)
  final VoidCallback onCamera;

  /// true = 검색 덮개(검색창 · 최근 검색 · 결과), false = 아래 탭(둘러보기만, 검색창 없음)
  final bool overlay;
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
  String? get shellChannel => widget.channel;

  @override
  ValueChanged<String>? get onShellChannel => widget.onChannelChanged;

  @override
  void loadScope(List<String> ids) {
    _future = widget.loaders.kits(ids); // STATE: 검색 범위(채널) → 상품
    _scopeIds = ids;
    _anns = null;
    _all = null;
    _future.then((k) {
      if (mounted) setState(() => _all = k); // 필터 시트가 셀 상품
    }, onError: (Object _) {});
  }

  /// 결과의 필터 · 격자/목록 (아이콘 줄)
  final _tools = ListTools();
  List<Kit>? _all;

  /// B-14 둘러보기 탭: 0 = 전체(처음), 1 = 종류, 2 = 세대
  int _view = 0;

  /// B-13 결과를 기체별로 묶기
  bool _grouped = false;

  /// B-12 · B-13 건담 도감 표 (처음 쓸 때 한 번)
  Future<GuideIndex>? _index;
  Future<GuideIndex> get _guideIndex =>
      _index ??= widget.loaders.guideIndex().catchError((Object _) => GuideIndex.empty);

  /// B-18 예고 · 라이브 · 예약 제목 찾기 — 캘린더 · 예고 목록의 찾기 칸을 빼며 여기로 (2026-11-21).
  /// 처음 쓸 때 한 번, 채널을 바꾸면 다시
  List<String> _scopeIds = const [];
  Future<List<Announcement>>? _anns;
  Future<List<Announcement>> get _announcements =>
      _anns ??= widget.loaders.announcements(_scopeIds).catchError((Object _) => <Announcement>[]);

  @override
  void initState() {
    super.initState();
    initScope();
  }

  @override
  void didUpdateWidget(SearchScreen old) {
    super.didUpdateWidget(old);
    syncScope();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

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
    showToast(context, trf('「{q}」 지웠어요', {'q': q}), onUndo: () => me.insertRecentSearch(i, q));
  }

  void _clearRecent(UserStore me) {
    final before = me.clearRecentSearches();
    showToast(context, tr('검색 기록을 지웠어요'), onUndo: () => me.restoreRecentSearches(before));
  }

  @override
  Widget build(BuildContext context) {
    // B-17 필터 · 격자 · 목록 — 검색어가 거른 상품 = 필터 시트가 셀 상품
    final tools = ListToolIcons(
      tools: _tools,
      pool: _all == null
          ? null
          : [
              for (final k in _all!)
                if (kitMatches(k, _query)) k,
            ],
    );
    final body = Expanded(
      child: FutureBuilder<List<Kit>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const LoadingView(); // B-8 P01
          }
          if (snap.hasError) {
            return ErrorView(message: '${snap.error}', onRetry: () => setState(reloadScope)); // B-8 P09
          }
          // 탭 = 둘러보기(B-14). 덮개 = 검색어가 없으면 최근 · 자주 찾은 · 설명으로 찾기(자판을 내려도 그대로), 있으면 결과
          if (!widget.overlay) return _browse(snap.data!);
          return _query.isEmpty ? _idle(snap.data!) : _results(snap.data!);
        },
      ),
    );
    final header = ChannelHeader(
      // B-1 P04
      leading: widget.leading,
      myChannels: widget.myChannels,
      selected: channel,
      onSelect: selectChannel,
      onMyChannelsChanged: widget.onMyChannelsChanged,
    );
    if (!widget.overlay) {
      // 아래 탭: 채널 바 · 아이콘 줄 · 전체 · 종류 · 세대 — 검색창은 위 줄 🔍 의 덮개에만
      return Column(
        children: [
          header,
          ToolRow(tools: [tools]),
          _viewTabs(), // B-14
          body,
        ],
      );
    }
    return Column(
      children: [
        Padding(
          // B-0 · B-2 ← · 검색창 · 아이콘 (아이콘 오른쪽 끝은 탭의 아이콘 줄과 같은 자리)
          padding: const EdgeInsets.fromLTRB(4, 6, 8, 4),
          child: Row(
            children: [
              IconButton(
                key: const ValueKey('search-close'),
                // 아이콘 칸(40)과 같은 너비 — 320dp 폰에서 글자를 넣으면(ⓧ 가 붙어) 줄이 넘쳤다
                visualDensity: VisualDensity.compact,
                tooltip: tr('뒤로'),
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back, color: Gp.ink),
              ),
              Expanded(
                child: GpSearchBar(
                  controller: _controller,
                  focusNode: _focus,
                  autofocus: true,
                  onChanged: (q) => setState(() => _query = q.trim()), // STATE: 검색어 → 결과 · 설명 후보
                  onSubmitted: _submit,
                  onCamera: widget.onCamera,
                ),
              ),
              const SizedBox(width: 4),
              tools,
            ],
          ),
        ),
        header,
        body,
      ],
    );
  }

  /// B-14 전체 · 종류 · 세대 (컬렉션의 좋아요 · 예약 · 구매함과 같은 밑줄 탭) + 레고 채널이면 B-16 범위
  Widget _viewTabs() => Padding(
    padding: const EdgeInsets.fromLTRB(6, 2, 6, 2),
    child: Row(
      children: [
        for (final (i, label) in const ['전체', '종류', '세대'].indexed)
          UnderlineTab(
            key: ValueKey('view-$i'),
            label: tr(label),
            fontSize: Gp.t16,
            selected: _view == i,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            onTap: () => setState(() => _view = i), // STATE: 둘러보기 → 전체 · 종류 · 세대
          ),
        if (channel == 'lego') ...[const Spacer(), _legoScopeButton()],
      ],
    ),
  );

  /// B-16 레고 범위 — 설정에 있던 것을 레고 채널 안으로 (2026-11-12). 아이콘 줄은 모든 탭이 세 칸까지라
  /// (test/find_filter_test.dart) 넷째 아이콘 대신 둘러보기 줄 오른쪽 글자 단추
  Widget _legoScopeButton() => Tooltip(
    message: tr('레고 범위'),
    child: TextButton.icon(
      key: const Key('lego-scope'),
      style: TextButton.styleFrom(foregroundColor: Gp.muted, padding: const EdgeInsets.symmetric(horizontal: 8)),
      icon: const Icon(Icons.toys_outlined, size: Gp.iS),
      label: Text(_legoScopeLabel(UserStore.instance.legoScope), style: const TextStyle(fontSize: Gp.t12)),
      onPressed: _pickLegoScope,
    ),
  );

  static String _legoScopeLabel(LegoScope v) => v == LegoScope.recent ? tr('최근 정식 세트') : tr('전부');

  Future<void> _pickLegoScope() async {
    // Catalog 가 듣는 것은 UserStore.instance (기기 저장 · 계정 맞추기 lego_scope)
    final me = UserStore.instance;
    final picked = await showGpSheet<LegoScope>(
      context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(tr('레고 범위'), padding: const EdgeInsets.fromLTRB(20, 0, 8, 4)),
            for (final v in LegoScope.values)
              ListTile(
                key: Key('lego-scope-${v.name}'),
                title: Text(_legoScopeLabel(v)),
                subtitle: Text(
                  v == LegoScope.all
                      ? tr('Rebrickable의 레고 전부 (굿즈 · 도서 · 옛 세트까지)')
                      : trf('{year}년부터 나온 정식 세트 · 미니피겨', {'year': legoRecentFromYear}),
                ),
                trailing: v == me.legoScope ? const Icon(Icons.check, color: Gp.accent) : null,
                onTap: () => Navigator.pop(sheet, v),
              ),
          ],
        ),
      ),
    );
    if (picked == null || picked == me.legoScope || !mounted) return;
    // STATE: 레고 범위 (저장 · 동기화) → Catalog 가 바로 다시 거르고, 이 화면은 그 목록을 다시 부른다.
    // 앱 셸은 보고 있는 탭을 다시 만들지 않는다 (만들면 고른 채널이 전체로 돌아간다 — Catalog.refilter)
    me.setLegoScope(picked);
    setState(reloadScope);
  }

  /// B-14 · B-15 둘러보기 본문 — 전체 = 상품 목록, 종류 · 세대 = 분류 칸 (같은 필터).
  /// 레고 범위가 바뀌면 통째로 새로 (종류 · 세대 칸은 채널이 바뀔 때만 다시 묶는다)
  Widget _browse(List<Kit> kits) => KeyedSubtree(key: ValueKey(UserStore.instance.legoScope), child: _browseView(kits));

  Widget _browseView(List<Kit> kits) => switch (_view) {
    1 => ListenableBuilder(
      // B-15 종류 (B-20 · 아이콘 줄 필터가 칸을 거른다)
      listenable: _tools,
      builder: (context, _) => TypeBrowse(
        channel: channel,
        loaders: widget.loaders,
        myChannels: widget.myChannels,
        onPickChannel: selectChannel,
        filter: _tools.filter,
      ),
    ),
    2 => ListenableBuilder(
      // B-15 세대 (B-21)
      listenable: _tools,
      builder: (context, _) => EraBrowse(
        channel: channel,
        loaders: widget.loaders,
        myChannels: widget.myChannels,
        onPickChannel: selectChannel,
        filter: _tools.filter,
      ),
    ),
    _ => SectionListView(
      // B-9 전체 상품
      key: const ValueKey('all'),
      tools: _tools,
      title: tr('전체 상품'),
      subtitle: channel == allChannelId ? '' : tr(channelOf(channel).label),
      kits: kits,
      loaders: widget.loaders,
    ),
  };

  /// 검색어가 없을 때: 최근 검색 · 자주 찾은 · 새로 들어온 · 설명으로 찾기
  Widget _idle(List<Kit> kits) {
    // 이 판을 눌러도 "검색창 밖을 누름"으로 치지 않게 — 칩을 누를 때 자판이 내려갔다 다시 올라오지 않는다
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
            tr('최근 검색'),
            padding: const EdgeInsets.fromLTRB(16, 16, 4, 10),
            trailing: IconButton(
              tooltip: tr('모두 지우기'),
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
          SectionHeader(tr('자주 찾은 검색어'), padding: const EdgeInsets.fromLTRB(16, 24, 12, 10)), // B-4 내 검색 횟수
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gp.gutter),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [freqCol(frequent.take(half)), const SizedBox(width: 16), freqCol(frequent.skip(half))],
            ),
          ),
        ],
        if (fresh.isNotEmpty) ...[
          SectionHeader(tr('새 상품'), subtitle: tr('이번 주'), padding: const EdgeInsets.fromLTRB(16, 24, 12, 4)), // B-4
          for (final k in fresh)
            ThumbRow(
              image: k.image,
              title: k.name,
              size: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              subtitle: joinDot([tr(channelOf(k.franchiseId).label), dataLabel(k.line)]),
              onTap: () => openKitDetail(context, k, loaders: widget.loaders, list: fresh),
            ),
        ],
        SectionHeader(tr('설명으로 찾기'), padding: const EdgeInsets.fromLTRB(16, 24, 12, 10)), // B-5 P10
        wrap([
          for (final example in byLang(ko: sentenceExamples, zh: sentenceExamplesZh))
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
    final anns = FutureBuilder<List<Announcement>>(
      future: _announcements,
      builder: (context, s) => _annHits(s.data ?? const []),
    );
    if (results.isEmpty && candidates.isEmpty) {
      return ListView(
        children: [
          tags,
          guide,
          anns,
          EmptyView(
            // B-8 P09
            icon: Icons.search_off,
            message: trf('「{q}」에 맞는 상품이 없어요', {'q': _query}),
            detail: channel == allChannelId
                ? tr('이름 대신 생김새 · 작품을 문장으로 적어 보세요')
                : trf('지금은 {channel} 안에서만 찾고 있어요', {'channel': tr(channelOf(channel).label)}),
            action: channel == allChannelId
                ? OutlinedButton(onPressed: () => _setQuery(''), child: Text(tr('검색어 지우기')))
                : OutlinedButton(onPressed: () => selectChannel(allChannelId), child: Text(tr('전체 채널에서 찾기'))),
          ),
        ],
      );
    }

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        tags,
        guide,
        anns,
        if (gundam)
          Align(
            // B-13 검색창 줄이 아니라 결과 위 (아이콘 줄은 세 칸 그대로)
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 8, 0),
              child: TextButton.icon(
                key: const ValueKey('group-toggle'),
                style: TextButton.styleFrom(
                  foregroundColor: _grouped ? Gp.accent : Gp.muted,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => setState(() => _grouped = !_grouped), // STATE: 결과 묶기
                icon: Icon(_grouped ? Icons.account_tree : Icons.account_tree_outlined, size: Gp.iS),
                label: Text(_grouped ? tr('기체별로 묶는 중') : tr('기체별로 묶기'), style: const TextStyle(fontSize: Gp.t12)),
              ),
            ),
          ),
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
      title: _query.isEmpty ? tr('전체 상품') : tr('검색 결과'),
      subtitle: channel == allChannelId ? '' : tr(channelOf(channel).label),
      kits: results,
      header: header,
      onBack: () {
        _setQuery(''); // STATE: 돌아가기 → 최근 검색 판
        _focus.requestFocus();
      },
      loaders: widget.loaders,
    );
  }

  /// B-18 제목에 검색어가 든 예고 (옛 캘린더 「일정에서 찾기」와 같은 맞추기) — 결과 위에 몇 줄만, 넘기면 다 본다
  Widget _annHits(List<Announcement> all) {
    final q = _query.toLowerCase();
    final hits = [
      for (final a in all)
        if (a.title.toLowerCase().contains(q)) a,
    ];
    if (q.isEmpty || hits.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const ValueKey('search-anns'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(tr('예고'), padding: const EdgeInsets.fromLTRB(16, 14, 12, 4)),
        for (final a in hits.take(5))
          ThumbRow(
            image: a.image,
            title: a.title,
            size: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            subtitle: joinDot([tr(channelOf(a.franchiseId).label), dateDot(annShownDay(a)), sourceLabel(a.source)]),
            onTap: () => openAnnouncement(context, a, loaders: widget.loaders, list: hits),
          ),
      ],
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
          Row(
            children: [
              const Icon(Icons.manage_search, size: Gp.iM, color: Gp.accent),
              const SizedBox(width: 6),
              Text(tr('설명에 맞는 상품'), style: const TextStyle(fontWeight: FontWeight.w700)),
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

/// B-11 사용법의 "검색" 묶음 (서랍 › 사용법 — s_app_shell.dart)
List<HelpItem> searchHelp() => [
  HelpItem(Icons.search, tr('검색 (위 줄 · 어느 탭에서나)')),
  HelpItem(Icons.photo_camera_outlined, tr('찍어서 찾기 (사진 · 바코드)')),
  HelpItem(Icons.tune, tr('필터 (좋아요 · 구매함 · 발매 예정 · 나라 · 종류 · 라인 · 작품 · 기간 · 가격) — 전체 · 종류 · 세대 · 검색 결과 공통')),
  HelpItem(Icons.grid_view_outlined, tr('격자로 보기')),
  HelpItem(Icons.bookmark_border, tr('구매함 (사진 왼쪽 위 리본 +)'), color: Gp.own),
  HelpItem(Icons.view_list_outlined, tr('목록으로 보기')),
  HelpItem(Icons.account_tree_outlined, tr('검색 결과를 기체별로 묶기')),
  HelpItem(Icons.manage_search, tr('설명으로 찾기 예')),
  HelpItem(Icons.toys_outlined, tr('레고 채널: 레고 범위 (최근 정식 세트 · 전부)')),
];
