// 화면 B (검색 탭에서 쌓는 화면): 분류 상품 — 종류 · 세대 칸(B-20 · B-21)을 누르면 그 상품 전부.
// 검색 결과와 같은 줄(검색창 + 필터 + 격자/목록) · 같은 격자/목록(O 전체 목록 SectionListView) — 내 상태는 칸 위 ♡ · 리본뿐.
//
// ┌──────── 디자인 가이드 대응표: B 검색 (분류 상품) ──────────────────────────────────┐
// │ 번호 │  Flutter 위젯명                          │ 비즈니스 명칭(한글)                          │ 원칙(P번호) │
// │ B-23  │ AppBar 제목 + 작은 공식 로고              │ 어느 분류인지 (HG · 기동전사 건담 · 1세대 …)   │ P03 · P06   │
// │ B-23a │ ToolRow(GpSearchBar + ListToolIcons)    │ 이 분류 안에서 찾기 · 필터(상태 = 좋아요 · 구매함 · 아직 …) · 격자/목록 — 검색 결과와 같은 줄 │ P04 · P07 │
// │ B-23b │ UnderlineTab 줄 (가로 스크롤)            │ 세부 시리즈: 전체 · HGUC · HGCE … · PB 한정 (상품 2개 이상인 것만) │ P06 · P07 │
// │ B-23c │ SectionListView (O-3 · O-4 재사용)       │ 상품 격자/목록 · 정렬 (♡ · 리본 = 내 상태)    │ P04 · P08   │
// │ B-23d │ TextButton "기체별로 묶기" + GroupedResults │ 건담 작품: 기체별로 묶기 (B-13 과 같은 목록)  │ P01 · P07   │
// │ B-23e │ AppBar ? (HelpButton)                  │ 이 화면 아이콘 뜻                            │ P10         │
// └──────────────────────────────────────────────────────────────────────────────────┘
// 전환: 분류 칸 → 이 화면(쌓기) → D 상품 상세(쌓기, 보이는 상품끼리 좌우). 필터 → 아래 시트.
// 데이터: 앞 화면이 고른 상품을 그대로 받는다 (다시 부르지 않음). 기체별로 묶기만 Loaders.guideIndex 를 처음 켤 때 한 번.
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../api.dart';
import '../detail_pane.dart';
import '../logic/category_browse.dart';
import '../logic/kit_rules.dart' show kitMatches;
import '../marks.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'guide/guide_search.dart' show GroupedResults;
import 'o_see_all_screen.dart';

/// B-23 분류 상품 열기 — [kits] 새것부터, [filter] 처음 필터(복사해서 쓴다), [groupByUnit] 건담 작품이면 기체별로 묶기
void openCategoryProducts(
  BuildContext context, {
  required String title,
  required List<Kit> kits,
  String image = '',
  Loaders loaders = const Loaders(),
  KitFilter? filter,
  bool groupByUnit = false,
}) => openPage(
  context,
  CategoryProductsScreen(
    title: title,
    image: image,
    kits: kits,
    loaders: loaders,
    filter: filter,
    groupByUnit: groupByUnit,
  ),
);

/// B-23 분류 하나의 상품 (검색 결과와 같은 줄 · 같은 격자/목록)
class CategoryProductsScreen extends StatefulWidget {
  const CategoryProductsScreen({
    super.key,
    required this.title,
    required this.kits,
    this.image = '',
    this.loaders = const Loaders(),
    this.filter,
    this.groupByUnit = false,
  });

  final String title;

  /// 제목 옆 작은 공식 그림 (없으면 글자만)
  final String image;
  final List<Kit> kits;
  final Loaders loaders;

  /// 처음 필터 (검색 탭에서 고른 것 — 복사해서 쓰므로 여기서 바꿔도 검색 탭은 그대로)
  final KitFilter? filter;

  /// 건담 작품: "기체별로 묶기" 단추
  final bool groupByUnit;

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  late final _tools = ListTools()..filter = widget.filter?.copy() ?? KitFilter();
  final _controller = TextEditingController();
  String _query = '';

  /// B-23b 고른 세부 시리즈 ('' = 전체)
  String _choice = '';
  late final _choices = sublineChoices(widget.kits);

  /// B-23d 기체별로 묶기
  bool _grouped = false;
  Future<GuideIndex>? _index;

  @override
  void dispose() {
    _tools.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kits = kitsOfChoice(widget.kits, _choice);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (widget.image.isNotEmpty) ...[
              // B-23 작은 공식 로고
              SizedBox(width: 44, height: 28, child: AppImage(widget.image, fit: BoxFit.contain)),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                tr(widget.title),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: Gp.t16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        actions: [
          HelpButton(
            title: tr(widget.title),
            items: categoryProductsHelp(groupByUnit: widget.groupByUnit),
          ), // B-23e
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ToolRow(
            // B-23a 검색 결과와 같은 줄
            field: GpSearchBar(
              controller: _controller,
              hint: trf('{name}에서 찾기', {'name': tr(widget.title)}),
              onChanged: (q) => setState(() => _query = q.trim()), // STATE: 찾기 → 상품
            ),
            tools: [
              ListToolIcons(
                tools: _tools,
                pool: [
                  for (final k in kits)
                    if (kitMatches(k, _query)) k,
                ],
              ),
            ],
          ),
          if (_choices.isNotEmpty || widget.groupByUnit) _choiceRow(),
          Expanded(child: _grouped ? _groupedBody(kits) : _listBody(kits)),
        ],
      ),
    );
  }

  /// B-23b 세부 시리즈 줄 (+ B-23d 기체별로 묶기)
  Widget _choiceRow() => Padding(
    padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
    child: Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (_choices.isNotEmpty)
                  for (final c in ['', ..._choices])
                    UnderlineTab(
                      key: ValueKey('sub-$c'),
                      label: c.isEmpty ? tr('전체') : tr(c),
                      fontSize: Gp.t14,
                      selected: _choice == c,
                      onTap: () => setState(() => _choice = c), // STATE: 세부 시리즈 → 상품
                    ),
              ],
            ),
          ),
        ),
        if (widget.groupByUnit)
          TextButton.icon(
            key: const ValueKey('group-toggle'),
            style: TextButton.styleFrom(
              foregroundColor: _grouped ? Gp.accent : Gp.muted,
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () => setState(() {
              _grouped = !_grouped; // STATE: 기체별로 묶기
              _index ??= widget.loaders.guideIndex().catchError((Object _) => GuideIndex.empty);
            }),
            icon: Icon(_grouped ? Icons.account_tree : Icons.account_tree_outlined, size: Gp.iS),
            label: Text(_grouped ? tr('기체별로 묶는 중') : tr('기체별로 묶기'), style: const TextStyle(fontSize: Gp.t12)),
          ),
      ],
    ),
  );

  /// B-23c 검색 결과와 같은 격자/목록 (필터 · 정렬 · 찾기)
  Widget _listBody(List<Kit> kits) => SectionListView(
    tools: _tools,
    titleRow: false,
    title: tr(widget.title),
    kits: kits,
    query: _query,
    loaders: widget.loaders,
  );

  /// B-23d 기체별 (필터 · 찾기는 위 줄 그대로)
  Widget _groupedBody(List<Kit> kits) => FutureBuilder<GuideIndex>(
    future: _index,
    builder: (context, s) {
      if (s.data == null) return const LoadingView();
      final m = Marks.of(context);
      return ListenableBuilder(
        listenable: _tools,
        builder: (context, _) {
          final f = _tools.filter..statusOf = m.statusOf;
          final shown = [
            for (final k in kits)
              if (f.matches(k) && kitMatches(k, _query)) k,
          ];
          if (shown.isEmpty) return EmptyView(icon: Icons.search_off, message: tr('이 조건의 상품이 없어요'));
          return GroupedResults(kits: shown, index: s.data!, loaders: widget.loaders);
        },
      );
    },
  );
}

/// B-23e 분류 상품 ? — 검색 결과와 같은 아이콘
List<HelpItem> categoryProductsHelp({bool groupByUnit = false}) => [
  HelpItem(Icons.tune, tr('필터 (상태: 좋아요 · 구매함 · 아직 · 발매 · 판매 · 종류 · 가격)')),
  HelpItem(Icons.grid_view_outlined, tr('격자로 보기')),
  HelpItem(Icons.view_list_outlined, tr('목록으로 보기')),
  HelpItem(Icons.swap_vert, tr('정렬: 최신 · 발매일 · 가격')),
  HelpItem(Icons.segment, trf('위 줄 = 세부 시리즈 (HGUC · HGCE … · {pb})', {'pb': tr(pbChoice)})),
  if (groupByUnit) HelpItem(Icons.account_tree_outlined, tr('기체별로 묶기')),
  HelpItem.group(tr('상품 사진 위')),
  HelpItem(Icons.favorite_border, tr('좋아요 (사진 왼쪽 아래)'), color: Gp.accent),
  HelpItem(Icons.bookmark_border, tr('구매함 (사진 왼쪽 위 리본)'), color: Gp.own),
];
