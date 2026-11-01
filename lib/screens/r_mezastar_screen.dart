// 화면 R: 포켓몬 메자스타 · 프렌다 태그 도감 — 지역 · 탄을 고르고, 가진 태그를 눌러 켠다.
//
// ┌──────── 디자인 가이드 대응표: R 태그 도감 ─────────────────────────────────────────┐
// │ 번호 │ Flutter 위젯명                     │ 비즈니스 명칭(한글)                    │ 원칙(P번호)   │
// │ R-1  │ TagGameCards (도감 › 포켓몬 위쪽)    │ MEZASTAR · Frienda 입구 + 가진 수       │ P06 · P01     │
// │ R-2  │ SquareSegments (KR · JP · HK · TW)  │ 메자스타 지역 고르기                     │ P04           │
// │ R-3  │ ToolRow [검색창][필터][격자 · 목록]   │ 이 도감에서 찾기 (다른 탭과 같은 줄)      │ P04 · P07     │
// │ R-4  │ 가로 탄 칸 + 진행 막대               │ 탄 · 시리즈 고르기 (가짐 n / 전체)        │ P01 · P06     │
// │ R-5  │ 태그 칸 격자 (tierFrame · cellImage) │ 흑백 = 아직 · 컬러 + 민트 테두리 = 가짐   │ P01 · P04     │
// │ R-5b │ 칸 누르기 → 토스트(되돌리기)          │ 가짐 켜기 · 끄기                        │ P03 · P07     │
// │ R-6  │ 바텀 시트 (길게 누르기 · 목록 줄)     │ 태그 정보 · 가짐 버튼                    │ P07 · P10     │
// │ R-7  │ 필터 시트 (가짐 · 등급 · 타입)        │ 네모 세그먼트 + 네모 체크 칸             │ P04 · P08     │
// │ R-8  │ TagSearchSection (B 검색 결과 위)    │ 검색 탭에서 태그 · 게임 이름 찾기         │ P07 · P06     │
// │ R-9  │ LoadingView / ErrorView / EmptyView │ 불러오는 중 · 오류 · 맞는 태그 없음       │ P01 · P09     │
// └──────────────────────────────────────────────────────────────────────────────────┘
// 전환: 도감 카드 → R(쌓기) → 태그 시트(덮기). 검색 결과 줄 → 태그 시트(덮기) → R(쌓기).
// 가짐 = UserStore.tagOwned (기기에만 · 백업 파일에 들어감). 키 = Gunpula atlas 의 인쇄 id · 픽 id.
import 'package:flutter/material.dart';

import '../data/tag_atlas.dart';
import '../detail_pane.dart';
import '../level.dart';
import '../marks.dart';
import '../theme.dart';
import '../widgets.dart';

/// R 열기 (도감 카드 · 검색 결과)
void openTagAtlas(BuildContext context, TagGame game, {String? region, String query = '', String? setId}) =>
    openPage(context, TagAtlasScreen(game: game, region: region, query: query, setId: setId));

/// 가진 태그 수 (게임별) — 데이터를 풀지 않고 id 머리로 센다
int ownedTagCount(Set<String> owned, TagGame game) =>
    owned.where((id) => game == TagGame.frienda ? id.startsWith('frienda:') : id.startsWith('mz-')).length;

// ── R-1 입구 카드 ─────────────────────────────────────────────────────────────────

class TagGameCards extends StatelessWidget {
  const TagGameCards({super.key, this.padding = const EdgeInsets.fromLTRB(16, 10, 16, 0), this.only});
  final EdgeInsets padding;

  /// 하나만 (검색에서 게임 이름을 썼을 때)
  final TagGame? only;

  @override
  Widget build(BuildContext context) {
    final owned = Marks.of(context).store.tagOwned;
    final games = only == null ? TagGame.values : [only!];
    return Padding(
      padding: padding,
      child: Row(
        children: [
          for (final (i, g) in games.indexed) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: _GameCard(game: g, owned: ownedTagCount(owned, g), onTap: () => openTagAtlas(context, g)),
            ),
          ],
        ],
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.game, required this.owned, required this.onTap});
  final TagGame game;
  final int owned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(Gp.radius),
      onTap: onTap, // STATE: 입구 → R 태그 도감
      child: Ink(
        decoration: Gp.raised(),
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Gp.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(Gp.rSmall),
              ),
              child: Icon(
                game == TagGame.mezastar ? Icons.style_outlined : Icons.catching_pokemon,
                color: Gp.accent,
                size: Gp.iL,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: Gp.t14, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    owned > 0 ? '가짐 $owned' : game.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: Gp.t11, color: owned > 0 ? Gp.own : Gp.faint),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Gp.muted, size: Gp.iM),
          ],
        ),
      ),
    ),
  );
}

// ── R-7 필터 ──────────────────────────────────────────────────────────────────────

/// 도감 안 필터 (저장하지 않음)
class TagFilter {
  TagFilter({Set<String>? rarities, Set<String>? types, this.owned = LitState.any})
    : rarities = rarities ?? {},
      types = types ?? {};
  final Set<String> rarities;
  final Set<String> types;
  LitState owned;

  int get count => rarities.length + types.length + (owned == LitState.any ? 0 : 1);

  TagFilter copy() => TagFilter(rarities: {...rarities}, types: {...types}, owned: owned);

  bool hit(TagCard c, bool have) =>
      owned.hit(have) &&
      (rarities.isEmpty || rarities.contains(c.rarity)) &&
      (types.isEmpty || c.types.any(types.contains));
}

Future<TagFilter?> _showTagFilter(
  BuildContext context, {
  required List<TagCard> cards,
  required Set<String> owned,
  required TagFilter initial,
}) => showModalBottomSheet<TagFilter>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Gp.panel,
  builder: (_) => FractionallySizedBox(
    heightFactor: 0.62,
    child: _TagFilterSheet(cards: cards, owned: owned, initial: initial),
  ),
);

class _TagFilterSheet extends StatefulWidget {
  const _TagFilterSheet({required this.cards, required this.owned, required this.initial});
  final List<TagCard> cards;
  final Set<String> owned;
  final TagFilter initial;

  @override
  State<_TagFilterSheet> createState() => _TagFilterSheetState();
}

class _TagFilterSheetState extends State<_TagFilterSheet> {
  late final TagFilter _draft = widget.initial.copy();

  int _hits(TagFilter f) => widget.cards.where((c) => f.hit(c, widget.owned.contains(c.id))).length;

  void _toggle(Set<String> s, String v) => setState(() => s.contains(v) ? s.remove(v) : s.add(v));

  @override
  Widget build(BuildContext context) {
    final rarities = {for (final c in widget.cards) c.rarity}.where((r) => r.isNotEmpty).toList()
      ..sort((a, b) => _rank(a).compareTo(_rank(b)));
    final types = [
      for (final t in typeLabels.keys)
        if (widget.cards.any((c) => c.types.contains(t))) t,
    ];
    final hits = _hits(_draft);
    Widget title(String s) => Padding(
      padding: const EdgeInsets.fromLTRB(2, 16, 0, 8),
      child: Text(
        s,
        style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
      ),
    );
    return SafeArea(
      top: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 8, 4),
            child: Row(
              children: [
                const Text(
                  '필터',
                  style: TextStyle(fontSize: Gp.t16, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() {
                    _draft
                      ..rarities.clear()
                      ..types.clear()
                      ..owned = LitState.any;
                  }),
                  child: const Text('초기화', style: TextStyle(color: Gp.muted)),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              children: [
                SquareSegments<LitState>(
                  values: LitState.values,
                  current: _draft.owned,
                  child: (v) => switch (v) {
                    LitState.any => const Text('전체'),
                    LitState.lit => const OwnedIcon(size: Gp.iS),
                    LitState.unlit => const Text('아직'),
                  },
                  onPick: (v) => setState(() => _draft.owned = v),
                ),
                title('등급'),
                _SquareChecks(
                  values: rarities,
                  label: (r) => rarityLabels[r] ?? r,
                  selected: _draft.rarities,
                  count: (r) => widget.cards.where((c) => c.rarity == r).length,
                  onToggle: (r) => _toggle(_draft.rarities, r),
                ),
                if (types.isNotEmpty) ...[
                  title('타입'),
                  _SquareChecks(
                    values: types,
                    label: (t) => typeLabels[t] ?? t,
                    selected: _draft.types,
                    count: (t) => widget.cards.where((c) => c.types.contains(t)).length,
                    onToggle: (t) => _toggle(_draft.types, t),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: GradientButton(
              label: hits == 0 ? '맞는 태그 없음' : '$hits개 보기', // P01 고르는 동안 개수
              onPressed: hits == 0 ? null : () => Navigator.pop(context, _draft),
            ),
          ),
        ],
      ),
    );
  }
}

int _rank(String rarity) {
  final i = rarityOrder.indexOf(rarity);
  return i < 0 ? rarityOrder.length : i;
}

/// 네모 체크 칸 (글자 + 개수) — 여러 개 고름
class _SquareChecks extends StatelessWidget {
  const _SquareChecks({
    required this.values,
    required this.label,
    required this.selected,
    required this.count,
    required this.onToggle,
  });
  final List<String> values;
  final String Function(String) label;
  final Set<String> selected;
  final int Function(String) count;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final v in values)
        Material(
          color: selected.contains(v) ? Gp.accent.withValues(alpha: 0.12) : Gp.panel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Gp.rSmall),
            side: BorderSide(color: selected.contains(v) ? Gp.accent : Gp.line),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(Gp.rSmall),
            onTap: () => onToggle(v),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: label(v)),
                    TextSpan(
                      text: ' ${count(v)}',
                      style: const TextStyle(fontSize: Gp.t11, color: Gp.faint),
                    ),
                  ],
                ),
                style: TextStyle(
                  fontSize: Gp.t12,
                  fontWeight: selected.contains(v) ? FontWeight.w700 : FontWeight.w400,
                  color: selected.contains(v) ? Gp.accent : Gp.ink,
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

// ── R 태그 도감 화면 ───────────────────────────────────────────────────────────────

class TagAtlasScreen extends StatefulWidget {
  const TagAtlasScreen({super.key, required this.game, this.region, this.query = '', this.setId});
  final TagGame game;

  /// KR · JP · HK · TW (메자스타)
  final String? region;

  /// 처음 검색어 (검색 탭에서 넘어올 때) — 있으면 전체 탄에서 찾는다
  final String query;
  final String? setId;

  @override
  State<TagAtlasScreen> createState() => _TagAtlasScreenState();
}

class _TagAtlasScreenState extends State<TagAtlasScreen> {
  late TagRegion _region = widget.game.regions.firstWhere(
    (r) => r.id == widget.region,
    orElse: () => widget.game.regions.first,
  );
  late Future<TagBook> _future = TagAtlas.book(widget.game, _region);

  /// 고른 탄 (null = 전체). [_setChosen] 이 false 면 처음 값(가장 새 탄 · 검색어가 있으면 전체)
  String? _set;
  bool _setChosen = false;

  late final _ctrl = TextEditingController(text: widget.query);
  late String _query = widget.query.trim();
  TagFilter _filter = TagFilter();
  bool _list = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _pickRegion(TagRegion r) {
    if (r.id == _region.id) return;
    setState(() {
      _region = r; // STATE: 지역 → 그 지역 도감 다시 읽기
      _future = TagAtlas.book(widget.game, r);
      _setChosen = false;
      _set = null;
    });
  }

  String? _setOf(TagBook b) {
    if (_setChosen) return _set;
    if (widget.setId != null && b.set(widget.setId!) != null) return widget.setId;
    return _query.isNotEmpty ? null : b.defaultSet;
  }

  void _toggle(TagCard c) {
    final store = Marks.read(context).store;
    final on = !store.tagOwned.contains(c.id);
    store.setTagOwned(c.id, on); // STATE: 가짐 → 칸 색 · 테두리 · 수집 수
    showToast(context, on ? '「${c.name}」 가짐' : '「${c.name}」 가짐을 취소했어요', onUndo: () => store.setTagOwned(c.id, !on));
  }

  @override
  Widget build(BuildContext context) {
    final owned = Marks.of(context).store.tagOwned;
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<TagBook>(
          future: _future,
          builder: (context, snap) {
            final b = snap.data;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.game == TagGame.mezastar ? '${widget.game.label} ${_region.id}' : widget.game.label,
                  style: const TextStyle(fontSize: Gp.t16, fontWeight: FontWeight.w600),
                ),
                if (b != null)
                  Text(
                    '수집 ${b.cards.where((c) => owned.contains(c.id)).length} / ${b.cards.length}',
                    style: const TextStyle(fontSize: Gp.t12, color: Gp.own, fontWeight: FontWeight.w500),
                  ),
              ],
            );
          },
        ),
      ),
      body: FutureBuilder<TagBook>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingView(); // R-9
          if (snap.hasError) {
            return ErrorView(
              message: '${snap.error}',
              onRetry: () => setState(() => _future = TagAtlas.book(widget.game, _region)),
            );
          }
          return _body(snap.data!, owned);
        },
      ),
    );
  }

  Widget _body(TagBook book, Set<String> owned) {
    final setId = _setOf(book);
    final inSet = book.inSet(setId);
    final cards = [
      for (final c in inSet)
        if (c.matches(_query) && _filter.hit(c, owned.contains(c.id))) c,
    ];
    final s = setId == null ? null : book.set(setId);
    final haveInSet = inSet.where((c) => owned.contains(c.id)).length;
    final bottom = MediaQuery.paddingOf(context).bottom + 32;
    return CustomScrollView(
      slivers: [
        if (widget.game.regions.length > 1)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
              child: SquareSegments<TagRegion>(
                // R-2
                values: widget.game.regions,
                current: _region,
                child: (r) => Tooltip(message: r.label, child: Text(r.id)),
                onPick: _pickRegion,
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: ToolRow(
            // R-3 다른 탭과 같은 줄: [검색창][필터][격자 · 목록]
            field: GpSearchBar(
              controller: _ctrl,
              hint: '이름 · 번호로 찾기',
              onChanged: (v) => setState(() => _query = v.trim()), // STATE: 찾기 → 칸 거르기
            ),
            tools: [
              FilterButton(
                count: _filter.count,
                onTap: () async {
                  final f = await _showTagFilter(context, cards: inSet, owned: owned, initial: _filter);
                  if (f != null) setState(() => _filter = f); // STATE: 필터 → 칸 거르기
                },
              ),
              ViewIconToggle(
                mine: _list,
                onChanged: (v) => setState(() => _list = v), // STATE: 보기 방식
                allIcon: Icons.grid_view_outlined,
                mineIcon: Icons.view_list_outlined,
                allTip: '격자로 보기',
                mineTip: '목록으로 보기',
              ),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: _SetStrip(
            // R-4
            book: book,
            current: setId,
            owned: owned,
            onPick: (id) => setState(() {
              _setChosen = true; // STATE: 탄 → 그 탄의 칸
              _set = id;
            }),
          ),
        ),
        SliverToBoxAdapter(
          child: SectionHeader(
            s?.name ?? '전체',
            subtitle: joinDot([
              '수집 $haveInSet / ${inSet.length}',
              if (s != null && s.date.isNotEmpty) dateDot(s.date),
              if (s != null && s.local != s.name) s.local,
            ]),
            trailing: const LevelHelpButton(),
            padding: const EdgeInsets.fromLTRB(16, 14, 4, 8),
          ),
        ),
        if (cards.isEmpty)
          SliverToBoxAdapter(
            child: EmptyView(
              // R-9 P09
              icon: Icons.search_off,
              message: '이 조건의 태그가 없어요',
              action: setId != null && _query.isNotEmpty
                  ? OutlinedButton(
                      onPressed: () => setState(() {
                        _setChosen = true;
                        _set = null;
                      }),
                      child: const Text('전체 탄에서 찾기'),
                    )
                  : null,
            ),
          )
        else if (_list)
          SliverPadding(
            padding: EdgeInsets.only(bottom: bottom),
            sliver: SliverList.builder(
              itemCount: cards.length,
              itemBuilder: (context, i) {
                final c = cards[i];
                final have = owned.contains(c.id);
                return ThumbRow(
                  image: c.image,
                  title: c.name,
                  subtitle: joinDot([c.number, c.badge, if (c.local != c.name) c.local]),
                  onTap: () => showTagSheet(context, c, book: book),
                  trailing: IconButton(
                    tooltip: have ? '가짐 취소' : '가짐',
                    onPressed: () => _toggle(c),
                    icon: OwnedIcon(filled: have, size: Gp.iL, color: have ? Gp.own : Gp.faint),
                  ),
                );
              },
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, bottom),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 118,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.66,
              ),
              itemCount: cards.length,
              itemBuilder: (context, i) {
                final c = cards[i];
                return TagCell(
                  // R-5 P01
                  card: c,
                  owned: owned.contains(c.id),
                  onTap: () => _toggle(c), // R-5b
                  onLongPress: () => showTagSheet(context, c, book: book), // R-6
                );
              },
            ),
          ),
      ],
    );
  }
}

/// R-4 탄 고르기 — [전체] + 새 탄부터, 프로모 · 원더 같은 묶음은 끝
class _SetStrip extends StatelessWidget {
  const _SetStrip({required this.book, required this.current, required this.owned, required this.onPick});
  final TagBook book;
  final String? current;
  final Set<String> owned;
  final ValueChanged<String?> onPick;

  @override
  Widget build(BuildContext context) {
    final sets = [...book.sets.where((s) => !s.extra).toList().reversed, ...book.sets.where((s) => s.extra)];
    Widget tile(String? id, String name) {
      final cards = book.inSet(id);
      final have = cards.where((c) => owned.contains(c.id)).length;
      final on = id == current;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Material(
          color: on ? Gp.accent.withValues(alpha: 0.08) : Gp.panel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Gp.radius),
            side: BorderSide(color: on ? Gp.accent : Gp.line, width: on ? 1.6 : 1),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(Gp.radius),
            onTap: () => onPick(id),
            child: SizedBox(
              width: 116,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: Gp.t12,
                        fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                        color: on ? Gp.accent : Gp.ink,
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: AccentBar(value: cards.isEmpty ? 0 : have / cards.length, color: Gp.own),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$have/${cards.length}',
                          style: const TextStyle(fontSize: Gp.t11, color: Gp.muted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 58,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [tile(null, '전체'), for (final s in sets) tile(s.id, s.name)],
      ),
    );
  }
}

/// R-5 태그 칸 — 아직 = 흑백, 가짐 = 컬러 + 민트 테두리 (건담 도감 칸과 같은 틀)
class TagCell extends StatelessWidget {
  const TagCell({super.key, required this.card, required this.owned, required this.onTap, this.onLongPress});
  final TagCard card;
  final bool owned;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final tier = owned ? CellTier.owned : CellTier.none;
    return Semantics(
      button: true,
      selected: owned,
      label: '${card.name} ${card.number}',
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: AnimatedScale(
                scale: owned ? 1 : 0.96,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                child: tierFrame(
                  tier,
                  Stack(
                    fit: StackFit.expand,
                    children: [
                      cellImage(tier, card.image, null),
                      if (card.badge.isNotEmpty) Positioned(left: 4, top: 4, child: TagPill(card.badge, filled: true)),
                      if (owned) const Positioned(right: 4, bottom: 4, child: OwnedIcon(size: Gp.iM)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              card.number,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: Gp.t11, color: Gp.faint),
            ),
            Text(
              card.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: Gp.t12, color: owned ? Gp.ink : Gp.muted),
            ),
          ],
        ),
      ),
    );
  }
}

// ── R-6 태그 시트 ─────────────────────────────────────────────────────────────────

/// 태그 정보 + 가짐 버튼. [onOpenBook] = 검색 탭에서 열었을 때 "도감에서 보기"
Future<void> showTagSheet(BuildContext context, TagCard card, {TagBook? book, VoidCallback? onOpenBook}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Gp.panel,
      builder: (_) => _TagSheet(card: card, book: book, onOpenBook: onOpenBook),
    );

class _TagSheet extends StatelessWidget {
  const _TagSheet({required this.card, this.book, this.onOpenBook});
  final TagCard card;
  final TagBook? book;
  final VoidCallback? onOpenBook;

  @override
  Widget build(BuildContext context) {
    final store = Marks.of(context).store; // 가짐이 바뀌면 시트도 다시 그린다
    final have = store.tagOwned.contains(card.id);
    final sets = [for (final id in card.setIds) book?.set(id)?.name ?? id.substring(id.indexOf(':') + 1)];
    final where = card.game == TagGame.mezastar ? '${card.game.label} ${card.region}' : card.game.label;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 200,
              child: tierFrame(
                have ? CellTier.owned : CellTier.none,
                cellImage(have ? CellTier.owned : CellTier.none, card.image, null),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    card.name,
                    style: const TextStyle(fontSize: Gp.t19, fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  card.number,
                  style: const TextStyle(fontSize: Gp.t14, color: Gp.muted, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            if (card.local.isNotEmpty && card.local != card.name)
              Text(
                card.local,
                style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                SoftTag(where, color: Gp.ink),
                if (card.badge.isNotEmpty) SoftTag(card.badge, color: Gp.star),
                if (card.grade != null && card.rarityLabel.isNotEmpty) SoftTag(card.rarityLabel, color: Gp.star),
                for (final t in card.types) SoftTag(typeLabels[t] ?? t),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              joinDot([...sets, card.variant]),
              style: const TextStyle(fontSize: Gp.t12, color: Gp.faint),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TogglePill(
                    label: have ? '가짐' : '가짐으로 표시',
                    icon: Icons.bookmark_border,
                    activeIcon: Icons.bookmark,
                    active: have,
                    color: Gp.own,
                    onTap: () => store.setTagOwned(card.id, !have), // STATE: 가짐 켜기 · 끄기
                  ),
                ),
                if (onOpenBook != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Gp.radius)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        onOpenBook!();
                      },
                      icon: const Icon(Icons.grid_view_outlined, size: Gp.iM),
                      label: const Text('도감에서 보기'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── R-8 검색 탭의 태그 결과 ─────────────────────────────────────────────────────────

/// B 검색 결과 위: 게임 이름(메자스타 · 프렌다 …)을 쓰면 입구 카드, 태그 이름 · 번호가 맞으면 태그 줄.
/// [tags] = false 면 입구 카드만 (포켓몬이 아닌 채널에서 찾는 중)
class TagSearchSection extends StatefulWidget {
  const TagSearchSection({super.key, required this.query, this.tags = true});
  final String query;
  final bool tags;

  @override
  State<TagSearchSection> createState() => _TagSearchSectionState();
}

class _TagSearchSectionState extends State<TagSearchSection> {
  Future<List<TagBook>>? _books;
  bool _more = false;
  bool _empty = false;
  String _lastQuery = '';

  static const _few = 5;

  @override
  Widget build(BuildContext context) {
    final q = widget.query.trim();
    if (q != _lastQuery) {
      _lastQuery = q;
      _more = false;
      if (_empty) _books = null; // 아직 못 받았으면 다음 검색어에서 다시
    }
    if (q.isEmpty) return const SizedBox.shrink();
    final game = gameInQuery(q);
    if (!widget.tags) return game == null ? const SizedBox.shrink() : TagGameCards(only: game.$1);
    _books ??= TagAtlas.all(); // 검색어를 처음 쓸 때 한 번 읽는다
    return FutureBuilder<List<TagBook>>(
      future: _books,
      builder: (context, snap) {
        final books = snap.data ?? const <TagBook>[];
        _empty = snap.connectionState == ConnectionState.done && books.isEmpty;
        final hits = searchTags(books, q, limit: 40);
        if (game == null && hits.isEmpty) return const SizedBox.shrink();
        final owned = Marks.of(context).store.tagOwned;
        TagBook? bookOf(TagCard c) => books.where((b) => b.game == c.game && b.region.id == c.region).firstOrNull;
        final shown = _more ? hits : hits.take(_few).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (game != null) TagGameCards(only: game.$1),
            if (hits.isNotEmpty)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                padding: const EdgeInsets.fromLTRB(0, 10, 0, 6),
                decoration: BoxDecoration(
                  color: Gp.panel,
                  borderRadius: BorderRadius.circular(Gp.rLarge),
                  border: Border.all(color: Gp.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
                      child: Row(
                        children: [
                          const Icon(Icons.style_outlined, size: Gp.iM, color: Gp.accent),
                          const SizedBox(width: 6),
                          const Text('태그 · 픽', style: TextStyle(fontWeight: FontWeight.w700)),
                          const Spacer(),
                          Text(
                            '${hits.length}${hits.length >= 40 ? '+' : ''}개',
                            style: const TextStyle(color: Gp.faint, fontSize: Gp.t12),
                          ),
                        ],
                      ),
                    ),
                    for (final c in shown)
                      () {
                        final b = bookOf(c);
                        final have = owned.contains(c.id);
                        final setName = c.setIds.isEmpty ? '' : (b?.set(c.setIds.first)?.name ?? '');
                        return ThumbRow(
                          image: c.image,
                          title: '${c.name}  ${c.number}',
                          subtitle: joinDot([
                            c.game == TagGame.mezastar ? '${c.game.label} ${c.region}' : c.game.label,
                            setName,
                            c.badge,
                          ]),
                          size: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                          onTap: () => showTagSheet(
                            context,
                            c,
                            book: b,
                            onOpenBook: () => openTagAtlas(context, c.game, region: c.region, query: c.number),
                          ),
                          trailing: IconButton(
                            tooltip: have ? '가짐 취소' : '가짐',
                            onPressed: () => Marks.read(context).store.setTagOwned(c.id, !have),
                            icon: OwnedIcon(filled: have, size: Gp.iL, color: have ? Gp.own : Gp.faint),
                          ),
                        );
                      }(),
                    if (hits.length > _few && !_more)
                      TextButton(
                        onPressed: () => setState(() => _more = true), // STATE: 태그 결과 더 보기
                        child: Text('${hits.length - _few}개 더 보기', style: const TextStyle(fontSize: Gp.t12)),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
