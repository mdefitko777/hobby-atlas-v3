// 화면 B: 검색 — 이름 · 번호 · 작품, 또는 "말로 설명해서" 찾기
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
// │ B-9  │ 검색어 · 포커스 없을 때 같은 목록      │ 처음 화면 = 전체 상품 (내 채널 상품 전부)  │ P07 · P06     │
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
import '../theme.dart';
import '../widgets.dart';
import 'c_channel_screen.dart';
import 'd_kit_detail_screen.dart';
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
    this.leading,
    this.loaders = const Loaders(),
  });

  final List<String> myChannels;
  final ValueChanged<List<String>> onMyChannelsChanged;

  /// 검색창 카메라 → 앱 셸의 찍어서 찾기 시트
  final VoidCallback onCamera;

  /// 값이 바뀌면 검색창에 커서를 둔다 (홈 검색 알약에서 넘어올 때)
  final int focusTick;
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
    showToast(context, '「$q」을(를) 지웠어요', onUndo: () => me.insertRecentSearch(i, q));
  }

  void _clearRecent(UserStore me) {
    final before = me.clearRecentSearches();
    showToast(context, '검색 기록을 지웠어요', onUndo: () => me.restoreRecentSearches(before));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_focus.hasFocus && _query.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_query.isNotEmpty) _setQuery('');
        _focus.unfocus(); // 뒤로 = 판 닫고 전체 상품
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
          tools: [
            ListToolIcons(
              tools: _tools,
              pool: _all == null
                  ? null
                  : [
                      for (final k in _all!)
                        if (kitMatches(k, _query)) k,
                    ],
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
              // B-9 검색어가 없으면: 검색창을 누른 동안 = 최근 · 자주 찾은 · 설명으로 찾기, 아니면 = 전체 상품
              return _query.isEmpty && _focus.hasFocus ? _idle(snap.data!) : _results(snap.data!);
            },
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
    if (results.isEmpty && candidates.isEmpty) {
      return ListView(
        children: [
          tags,
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

    // B-7 홈 전체 목록과 같은 목록 (필터 · 정렬 · 격자/목록), 설명 후보는 맨 위 머리
    return SectionListView(
      key: const ValueKey('search'),
      tools: _tools,
      title: _query.isEmpty ? '전체 상품' : '검색 결과',
      subtitle: channel == allChannelId ? '' : channelOf(channel).label,
      kits: results,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          tags,
          if (candidates.isNotEmpty)
            SentenceCandidates(
              hits: candidates,
              onTap: (k) =>
                  openKitDetail(context, k, loaders: widget.loaders, list: [for (final h in candidates) h.kit]),
            ), // B-6
        ],
      ),
      onBack: _query.isEmpty
          ? null // 처음 화면(전체 상품)에는 돌아갈 곳이 없음
          : () {
              _setQuery(''); // STATE: 돌아가기 → 전체 상품
              _focus.unfocus();
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

/// B-11 ? 도움말 (위 줄 ? 의 "검색" 묶음 — s_app_shell.dart)
const searchHelp = <HelpItem>[
  HelpItem(Icons.photo_camera_outlined, '찍어서 찾기 (사진 · 바코드)'),
  HelpItem(Icons.tune, '필터'),
  HelpItem(Icons.grid_view_outlined, '격자로 보기'),
  HelpItem(Icons.view_list_outlined, '목록으로 보기'),
  HelpItem(Icons.manage_search, '설명으로 찾기 예'),
];
