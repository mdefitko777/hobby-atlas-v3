// 화면 B: 검색 — 이름 · 번호 · 작품, 또는 "말로 설명해서" 찾기
//
// ┌──────── 디자인 가이드 대응표: B 검색 ──────────────────────────────────────────────┐
// │ 번호 │ Flutter 위젯명                     │ 비즈니스 명칭(한글)                    │ 원칙(P번호)   │
// │ B-1  │ ChannelHeader                      │ 검색 범위 = 내 채널 (C-0 공용)          │ P04 · P06     │
// │ B-2  │ GpSearchBar (지우기 + 카메라)       │ 검색창(홈과 같은 모양)                 │ P07 · P04     │
// │ B-3  │ Wrap(InputChip ×) — 검색창을 누르면   │ 최근 검색어 (하나씩 · 전체 지우기)      │ P06 · P03     │
// │ B-4  │ 2열 번호 목록                       │ 인기 검색어 (1–3위 브랜드 색)           │ P06           │
// │ B-5  │ 예시 문장 칩                        │ AI에게 설명해서 찾기 (미리 쓴 가짜 응답) │ P10 · P07     │
// │ B-6  │ 가로 카드 + 일치도 %                │ AI 추천 후보                           │ P01 · P09     │
// │ B-7  │ SectionListView (O 전체 목록 재사용) │ 검색 결과 · 필터 · 정렬 · 격자/목록      │ P08 · 적응형 │
// │ B-9  │ 검색어 · 포커스 없을 때 같은 목록      │ 처음 화면 = 전체 상품 (내 채널 상품 전부)  │ P07 · P06     │
// │ B-8  │ LoadingView / ErrorView / EmptyView │ 불러오는 중 · 오류 · 결과 없음          │ P01 · P09     │
// └──────────────────────────────────────────────────────────────────────────────────┘
// 가짜 검색: GET /kits 로 받은 목록 안에서만 거른다(setState). 실제 검색 엔진 · AI 호출 없음.
// 현행 앱 문제: 정확한 이름을 모르면 못 찾음 · 필터 입구가 여러 개 → v2는 검색창 하나 + 말로 찾기.
import 'package:flutter/material.dart';

import '../api.dart';
import '../channels.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'c_channel_screen.dart';
import 'd_kit_detail_screen.dart';
import 'o_see_all_screen.dart';

/// 처음 보이는 최근 검색어 (가짜 기록 — 영구 저장 금지라 상수)
const initialRecentQueries = ['스트라이크 프리덤', 'RG 윙', '이브이', 'BX-01'];

/// 인기 검색어 (가짜 순위)
const popularQueries = ['에어리얼', 'RG 윙 건담 제로', '발바토스', '피카츄', 'MGEX', '레전드 건담', 'Hi-ν', '드랜 소드', '세이버', '나인볼'];

/// AI 가짜 응답: (트리거 낱말들, 예시 문장, 후보[(키트 id, 일치도, 이유)])
const aiAnswers = <(List<String>, String, List<(String, int, String)>)>[
  (
    ['날개'],
    '파란 날개 달린 SEED 건담',
    [('gu02', 94, '푸른 날개 8장 · SEED · 흰색/파랑'), ('gu06', 88, '같은 계열 기체의 SD 버전'), ('gu12', 61, 'SEED 주인공 기체 · 날개 없음')],
  ),
  (['잠', '자고'], '자고 있는 피카츄 피규어', [('po22', 96, '「잠자는 피카츄」 이름 일치'), ('po23', 64, '피카츄 · 봉제인형')]),
  (
    ['드래곤', '용'],
    '용 모양 블레이드 베이',
    [('be43', 90, '드랜(드래곤) 소드 · BX-00'), ('be48', 85, '드랜 소드 메탈 코트'), ('be47', 72, '코발트 드라군 · 용 모양 블레이드')],
  ),
];

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
  final List<String> _recent = [...initialRecentQueries];
  late Future<List<Kit>> _future;

  @override
  List<String> get myChannels => widget.myChannels;

  @override
  void loadScope(List<String> ids) {
    _future = widget.loaders.kits(ids); // STATE: 검색 범위(채널) → GET /kits
  }

  @override
  void initState() {
    super.initState();
    reloadScope();
    // 검색창을 누르면(포커스) 최근 · 인기 · AI 판, 벗어나면 다시 전체 상품
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
    setState(() => _query = q.trim()); // STATE: 검색어 → 결과 격자 · AI 후보
  }

  void _submit(String q) {
    final t = q.trim();
    if (t.isEmpty) return;
    setState(() {
      _recent
        ..remove(t)
        ..insert(0, t); // STATE: 검색어 → 최근 검색 맨 앞
    });
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: GpSearchBar(
            // B-2 P04
            controller: _controller,
            focusNode: _focus,
            onChanged: (q) => setState(() => _query = q.trim()),
            onSubmitted: _submit,
            onCamera: widget.onCamera,
          ),
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
              // B-9 검색어가 없으면: 검색창을 누른 동안 = 최근 · 인기 · AI, 아니면 = 전체 상품
              return _query.isEmpty && _focus.hasFocus ? _idle() : _results(snap.data!);
            },
          ),
        ),
      ],
    );
  }

  /// 검색어가 없을 때: 최근 검색 · 인기 검색어 · AI로 찾기
  Widget _idle() {
    // 이 판을 눌러도 "검색창 밖을 누름"으로 치지 않게 — 아니면 포커스가 먼저 풀려 판이 사라지고 누른 칩이 안 먹는다
    return TextFieldTapRegion(child: _idleList());
  }

  Widget _idleList() {
    return ListView(
      padding: EdgeInsets.only(bottom: navClearance(context)),
      children: [
        if (_recent.isNotEmpty) ...[
          SectionHeader(
            '최근 검색',
            padding: const EdgeInsets.fromLTRB(16, 16, 4, 10),
            trailing: TextButton(
              onPressed: () => setState(_recent.clear), // STATE: 최근 검색 → 비움
              child: const Text(
                '전체 삭제',
                style: TextStyle(color: Gp.muted, fontSize: Gp.t12),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final q in _recent)
                  InputChip(
                    // B-3 P03
                    label: Text(q),
                    onPressed: () => _setQuery(q),
                    onDeleted: () => setState(() => _recent.remove(q)),
                    deleteIcon: const Icon(Icons.close, size: Gp.iS),
                    backgroundColor: Gp.panel,
                    side: const BorderSide(color: Gp.line),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(Gp.rSmall))),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
        ],
        const SectionHeader('인기 검색어', padding: EdgeInsets.fromLTRB(16, 24, 12, 10)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: LayoutBuilder(
            builder: (context, box) {
              final half = (popularQueries.length / 2).ceil();
              Widget col(int from, int to) => Expanded(
                child: Column(
                  children: [
                    for (var i = from; i < to; i++)
                      InkWell(
                        onTap: () => _setQuery(popularQueries[i]),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 24,
                                child: Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: i < 3 ? Gp.accent : Gp.faint, // B-4 브랜드 포인트 색
                                  ),
                                ),
                              ),
                              Expanded(child: Text(popularQueries[i], maxLines: 1, overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              );
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [col(0, half), const SizedBox(width: 16), col(half, popularQueries.length)],
              );
            },
          ),
        ),
        const SectionHeader('AI에게 설명해서 찾기', padding: EdgeInsets.fromLTRB(16, 24, 12, 10)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Text(
            '정확한 이름이 기억나지 않으면 생김새나 작품을 문장으로 적어 보세요.', // B-5 P10
            style: TextStyle(color: Gp.muted.withValues(alpha: 0.9), fontSize: Gp.t12),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (_, example, _) in aiAnswers)
                ActionChip(
                  avatar: const Icon(Icons.auto_awesome, size: Gp.iS, color: Gp.accent),
                  label: Text(example),
                  onPressed: () => _setQuery(example),
                  backgroundColor: Gp.panel,
                  side: const BorderSide(color: Gp.line),
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(Gp.rSmall))),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// 검색어가 있을 때: AI 후보(있으면) + 결과 격자
  Widget _results(List<Kit> kits) {
    final results = kits.where((k) => kitMatches(k, _query)).toList(); // 검색어가 없으면(둘러보기) 전부
    final byId = {for (final k in kits) k.id: k};
    final ai = aiAnswers.where((a) => a.$1.any(_query.contains)).firstOrNull;
    final candidates = [
      if (ai != null)
        for (final (id, score, why) in ai.$3)
          if (byId[id] case final k?) (k, score, why),
    ];

    if (results.isEmpty && candidates.isEmpty) {
      return ListView(
        children: [
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

    // B-7 홈 전체 목록과 같은 목록 (필터 · 정렬 · 격자/목록), AI 후보는 맨 위 머리
    return SectionListView(
      key: const ValueKey('search'),
      title: _query.isEmpty ? '전체 상품' : '검색 결과',
      subtitle: channel == allChannelId ? '' : channelOf(channel).label,
      kits: results,
      header: candidates.isEmpty
          ? null
          : _AiCandidates(
              items: candidates,
              onTap: (k) => openKitDetail(context, k, loaders: widget.loaders),
            ), // B-6
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

/// B-6 AI 추천 후보 — 미리 쓴 가짜 응답
class _AiCandidates extends StatelessWidget {
  const _AiCandidates({required this.items, required this.onTap});
  final List<(Kit, int, String)> items;
  final ValueChanged<Kit> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
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
              Icon(Icons.auto_awesome, size: Gp.iM, color: Gp.accent),
              SizedBox(width: 6),
              Text('AI 추천 후보', style: TextStyle(fontWeight: FontWeight.w700)),
              Spacer(),
              Text(
                '설명과 닮은 순서',
                style: TextStyle(color: Gp.faint, fontSize: Gp.t12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final (k, score, why) in items)
            ThumbRow(
              // 카메라 결과의 다른 후보와 같은 줄
              image: k.image,
              title: k.name,
              subtitle: why,
              padding: const EdgeInsets.symmetric(vertical: 6),
              onTap: () => onTap(k),
              trailing: Text(
                '$score%', // 일치도 P01
                style: TextStyle(fontWeight: FontWeight.w700, color: score >= 85 ? Gp.accent : Gp.muted),
              ),
            ),
        ],
      ),
    );
  }
}
