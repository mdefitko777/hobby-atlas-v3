// 화면 R: 포켓몬 메자스타 · 프렌다 태그 도감 — 지역 · 탄을 고르고, 상품처럼 ♡ 좋아요 · 구매함을 켠다.
//
// ┌──────── 디자인 가이드 대응표: R 태그 도감 ─────────────────────────────────────────┐
// │ 번호 │ Flutter 위젯명                     │ 비즈니스 명칭(한글)                    │ 원칙(P번호)   │
// │ R-1  │ TagGameCards (CategoryTile)        │ 도감 › 포켓몬 '태그' 줄: MEZASTAR · Frienda 입구 (그림 + 이름만) │ P06 │
// │ R-2  │ SquareSegments (KR · JP · HK · TW)  │ 메자스타 지역 고르기                     │ P04           │
// │ R-3  │ ToolRow [검색창][필터][격자 · 목록]   │ 이 도감에서 찾기 (다른 탭과 같은 줄)      │ P04 · P07     │
// │ R-4  │ 가로 탄 칸 + 진행 막대               │ 탄 · 시리즈 고르기 (구매함 n / 전체)      │ P01 · P06     │
// │ R-5  │ TagCell 격자 (TierCell, 늘 컬러)     │ 아직 = 그림 그대로 · ♡ = 좋아요 · 리본 + 옅은 민트 테두리 = 구매함 │ P01 · P04 │
// │ R-5b │ 칸 누르기 → 태그 상세 (R-6)           │ 상품 칸과 같음: 누르면 상세              │ P07 · P08     │
// │ R-5c │ FriendaImages (기기에서 공식 페이지)  │ 프렌다 픽 그림: 탄을 열면 받아 7일 보관     │ P02 · P01     │
// │ R-5d │ 칸 위 MarkOverlay (리본 · ♡)        │ 바로 구매함 · 좋아요 → 토스트(되돌리기)   │ P03 · P07     │
// │ R-6  │ 바텀 시트 showTagSheet (칸 · 줄)    │ 태그 상세: 큰 그림 · 이름 · 번호 · 탄 · 등급 │ P07 · P10   │
// │ R-6a │ 시트의 TogglePill 2개 (♡ · 리본)     │ 좋아요 · 구매함 (상품 상세와 같은 버튼)   │ P03 · P07     │
// │ R-6b │ 시트 그림 누르기 → openImageViewer  │ 공식 그림 크게 (앞 · 뒤 넘기기, 확대)     │ P02 · P08     │
// │ R-6c │ 시트 ↗ 공식 페이지 (앱 밖 브라우저)  │ 프렌다 픽 목록 · 태그스타 팝업            │ P09           │
// │ R-7  │ 필터 시트 (전체 · ♡ · 리본 · 아직 없음 · 등급 · 타입) │ 상품 필터와 같은 상태 줄(MineStateLabel) + 네모 체크 칸 │ P04 · P08 │
// │ R-8  │ TagSearchSection (B 검색 결과 위)    │ 검색 탭에서 태그 · 게임 이름 찾기         │ P07 · P06     │
// │ R-8b │ TagRow + TagMarkButtons (♡ · 리본)  │ 목록 · 검색 · 컬렉션 줄의 좋아요 · 구매함  │ P03 · P07     │
// │ R-9  │ LoadingView / ErrorView / EmptyView │ 불러오는 중 · 오류 · 맞는 태그 없음       │ P01 · P09     │
// │ R-10 │ AppBar 오른쪽 ? (HelpButton)       │ 칸 색 · 누르기 · 아이콘 뜻 한 줄씩        │ P10           │
// │ R-11 │ TagCollectionSection (F 컬렉션 안)  │ 좋아요 · 구매함 탭 끝의 "태그 · 픽" 줄    │ P06 · P01     │
// └──────────────────────────────────────────────────────────────────────────────────┘
// 전환: 도감 카드 → R(쌓기) → 태그 시트(덮기). 검색 결과 · 컬렉션 줄 → 태그 시트(덮기) → R(쌓기).
// 구매함 = UserStore.tagOwned · 좋아요 = tagLiked (기기 · 계정 기기 기록, payload 밖). 키 = Gunpula atlas 의 인쇄 id · 픽 id.
// 한 태그에 상태 하나 (상품과 같음): 구매함을 켜면 좋아요에서 빠지고, 좋아요를 켜면 구매함에서 빠진다.
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../channels.dart' show lineCovers;
import '../data/frienda_images.dart';
import '../data/tag_atlas.dart';
import '../data/user_store.dart' show UserStore;
import '../detail_pane.dart';
import '../level.dart';
import '../marks.dart';
import '../models.dart' show CollectStatus;
import '../theme.dart';
import '../widgets.dart';
import 'c_channel_screen.dart' show allChannelId;

/// R 열기 (도감 카드 · 검색 결과)
void openTagAtlas(BuildContext context, TagGame game, {String? region, String query = '', String? setId}) =>
    openPage(context, TagAtlasScreen(game: game, region: region, query: query, setId: setId));

/// 태그 수 (게임별) — 데이터를 풀지 않고 id 머리로 센다. 구매함 · 좋아요 모음 어느 쪽이든
int ownedTagCount(Set<String> ids, TagGame game) =>
    ids.where((id) => game == TagGame.frienda ? id.startsWith('frienda:') : id.startsWith('mz-')).length;

/// 좋아요만 (구매함이 이긴다 — 두 기기에서 따로 켜 둘 다 든 것은 구매함)
Set<String> likedOnlyTags(Set<String> liked, Set<String> owned) => liked.difference(owned);

/// 칸 단계 — 상품 도감 칸과 같다 (늘 컬러 · ♡ · 리본)
CellTier tagTier(CollectStatus s) => switch (s) {
  CollectStatus.owned => CellTier.owned,
  CollectStatus.wanted => CellTier.liked,
  CollectStatus.none => CellTier.none,
};

/// ♡ 누르기 + 토스트(되돌리기) — 상품 Marks.toggleLike 와 같은 말
void toggleTagLike(BuildContext context, TagCard c) {
  final store = Marks.read(context).store;
  final before = store.tagStatus(c.id);
  store.setTagMark(c.id, liked: before != CollectStatus.wanted); // STATE: 좋아요 → 칸 ♡ · 컬렉션 좋아요
  showToast(
    context,
    before == CollectStatus.wanted
        ? '좋아요를 취소했어요'
        : before == CollectStatus.owned
        ? '「${c.name}」 구매함 → 좋아요로 옮겼어요'
        : '「${c.name}」 좋아요',
    onUndo: () => store.setTagStatus(c.id, before),
  );
}

/// 리본 누르기 + 토스트(되돌리기) — 상품 Marks.toggleOwn 과 같은 말
void toggleTagOwn(BuildContext context, TagCard c) {
  final store = Marks.read(context).store;
  final before = store.tagStatus(c.id);
  store.setTagMark(c.id, owned: before != CollectStatus.owned); // STATE: 구매함 → 칸 리본 · 수집 수
  showToast(
    context,
    before == CollectStatus.owned ? '구매함에서 뺐어요' : '「${c.name}」 구매함에 넣었어요',
    onUndo: () => store.setTagStatus(c.id, before),
  );
}

// ── R-1 입구 카드 ─────────────────────────────────────────────────────────────────

/// R-1 태그 도감 입구 — 분류 칸(CategoryTile) 한 벌: 그림 + 이름만 (숫자 없음)
class TagGameCards extends StatelessWidget {
  const TagGameCards({super.key, this.padding = const EdgeInsets.fromLTRB(16, 10, 16, 0), this.only});
  final EdgeInsets padding;

  /// 하나만 (검색에서 게임 이름을 썼을 때)
  final TagGame? only;

  @override
  Widget build(BuildContext context) => CategoryGrid(
    padding: padding,
    children: [
      for (final g in only == null ? TagGame.values : [only!])
        CategoryTile(
          image: tagGameCover(g),
          icon: g == TagGame.mezastar ? Icons.style_outlined : Icons.catching_pokemon,
          name: g.label,
          onTap: () => openTagAtlas(context, g), // STATE: 입구 → R 태그 도감
        ),
    ],
  );
}

/// 태그 게임 공식 그림 — atlas-groups.json line_covers.pokemon 에 게임 이름(MEZASTAR · Frienda)이 있으면, 없으면 빈 값(아이콘)
String tagGameCover(TagGame g) => lineCovers['pokemon']?[g.label] ?? '';

// ── R-7 필터 ──────────────────────────────────────────────────────────────────────

/// 상태 거르기 — 전체 · 좋아요 · 구매함 · 아직 없음 (상품 필터 MineState 와 같은 순서 · 같은 말)
enum TagMarkFilter {
  any,
  liked,
  owned,
  none;

  MineState get mine => switch (this) {
    any => MineState.any,
    liked => MineState.liked,
    owned => MineState.owned,
    none => MineState.none,
  };

  bool hit(CollectStatus s) => switch (this) {
    any => true,
    liked => s == CollectStatus.wanted,
    owned => s == CollectStatus.owned,
    none => s == CollectStatus.none,
  };
}

/// 도감 안 필터 (저장하지 않음)
class TagFilter {
  TagFilter({Set<String>? rarities, Set<String>? types, this.mark = TagMarkFilter.any})
    : rarities = rarities ?? {},
      types = types ?? {};
  final Set<String> rarities;
  final Set<String> types;
  TagMarkFilter mark;

  int get count => rarities.length + types.length + (mark == TagMarkFilter.any ? 0 : 1);

  TagFilter copy() => TagFilter(rarities: {...rarities}, types: {...types}, mark: mark);

  bool hit(TagCard c, CollectStatus s) =>
      mark.hit(s) &&
      (rarities.isEmpty || rarities.contains(c.rarity)) &&
      (types.isEmpty || c.types.any(types.contains));
}

Future<TagFilter?> _showTagFilter(
  BuildContext context, {
  required List<TagCard> cards,
  required CollectStatus Function(String id) status,
  required TagFilter initial,
}) => showGpSheet<TagFilter>(
  context,
  heightFactor: gpSheetHeight,
  builder: (_) => _TagFilterSheet(cards: cards, status: status, initial: initial),
);

class _TagFilterSheet extends StatefulWidget {
  const _TagFilterSheet({required this.cards, required this.status, required this.initial});
  final List<TagCard> cards;
  final CollectStatus Function(String id) status;
  final TagFilter initial;

  @override
  State<_TagFilterSheet> createState() => _TagFilterSheetState();
}

class _TagFilterSheetState extends State<_TagFilterSheet> {
  late final TagFilter _draft = widget.initial.copy();

  int _hits(TagFilter f) => widget.cards.where((c) => f.hit(c, widget.status(c.id))).length;

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
    return GpPickSheet(
      title: '필터',
      hits: hits,
      noHitLabel: '맞는 태그 없음',
      onApply: () => Navigator.pop(context, _draft),
      onReset: () => setState(() {
        _draft
          ..rarities.clear()
          ..types.clear()
          ..mark = TagMarkFilter.any;
      }),
      children: [
        SquareSegments<TagMarkFilter>(
          values: TagMarkFilter.values,
          current: _draft.mark,
          child: (v) => MineStateLabel(v.mine), // 상품 필터와 같은 줄
          onPick: (v) => setState(() => _draft.mark = v),
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

  /// R-5c 프렌다 그림을 마지막으로 부탁한 탄 (같은 탄은 한 번만)
  String? _imagesFor;

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

  @override
  Widget build(BuildContext context) {
    final store = Marks.of(context).store; // 좋아요 · 구매함이 바뀌면 다시 그린다
    final owned = store.tagOwned;
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<TagBook>(
          future: _future,
          builder: (context, snap) {
            final b = snap.data;
            return BarTitle(
              widget.game == TagGame.mezastar ? '${widget.game.label} ${_region.id}' : widget.game.label,
              count: b == null ? '' : '수집 ${b.cards.where((c) => owned.contains(c.id)).length} / ${b.cards.length}',
            );
          },
        ),
        actions: [
          HelpButton(title: widget.game.label, items: tagHelp()),
          const SizedBox(width: 6),
        ], // R-10
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
          // R-5c 프렌다 그림이 도착하면 칸을 다시 그린다
          return ListenableBuilder(
            listenable: FriendaImages.instance,
            builder: (context, _) => _body(snap.data!, store),
          );
        },
      ),
    );
  }

  Widget _body(TagBook book, UserStore store) {
    final owned = store.tagOwned;
    final setId = _setOf(book);
    final images = FriendaImages.instance;
    final raw = book.inSet(setId);
    if (book.game == TagGame.frienda && _imagesFor != (setId ?? '')) {
      _imagesFor = setId ?? '';
      images.ensureFor(raw); // STATE: 이 탄의 공식 페이지 → 그림 (기기 캐시 7일)
    }
    final inSet = [for (final c in raw) images.apply(c)];
    final cards = [
      for (final c in inSet)
        if (c.matches(_query) && _filter.hit(c, store.tagStatus(c.id))) c,
    ];
    final s = setId == null ? null : book.set(setId);
    // 수집 = 구매함 (상품 도감과 같음) · 좋아요는 따로 센다
    final haveInSet = inSet.where((c) => owned.contains(c.id)).length;
    final likedInSet = inSet.where((c) => store.tagStatus(c.id) == CollectStatus.wanted).length;
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
                  final f = await _showTagFilter(context, cards: inSet, status: store.tagStatus, initial: _filter);
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
              if (likedInSet > 0) '좋아요 $likedInSet',
              if (s != null && s.date.isNotEmpty) dateDot(s.date),
              if (s != null && s.local != s.name) s.local,
            ]),
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
                return TagRow(
                  // R-8b 상품 줄과 같은 ♡ · 리본
                  card: c,
                  title: c.name,
                  subtitle: joinDot([c.number, c.badge, if (c.local != c.name) c.local]),
                  size: 56,
                  onTap: () => showTagSheet(context, c, book: book), // R-6
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
                  status: store.tagStatus(c.id),
                  onTap: () => showTagSheet(context, c, book: book), // R-5b → R-6
                  onLike: () => toggleTagLike(context, c), // R-5d
                  onOwn: () => toggleTagOwn(context, c),
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
        padding: const EdgeInsets.symmetric(horizontal: Gp.gutter),
        children: [tile(null, '전체'), for (final s in sets) tile(s.id, s.name)],
      ),
    );
  }
}

/// R-5 태그 칸 — 상품 도감 칸과 같은 TierCell (늘 컬러): 좋아요 = ♡ · 구매함 = 리본 + 옅은 민트 테두리.
/// [onLike] · [onOwn] 을 주면 칸 위에 상품 칸과 같은 누르는 ♡ · 리본 (R-5d), 없으면 켜진 표시만
class TagCell extends StatelessWidget {
  const TagCell({
    super.key,
    required this.card,
    required this.status,
    required this.onTap,
    this.onLike,
    this.onOwn,
    this.onLongPress,
  });
  final TagCard card;
  final CollectStatus status;
  final VoidCallback onTap;
  final VoidCallback? onLike;
  final VoidCallback? onOwn;
  final VoidCallback? onLongPress;

  bool get owned => status == CollectStatus.owned;
  bool get liked => status == CollectStatus.wanted;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: owned || liked,
    label: '${card.name} ${card.number}',
    child: TierCell(
      image: card.image,
      tier: tagTier(status),
      square: false,
      gap: 4,
      onTap: onTap,
      onLongPress: onLongPress,
      overlays: [
        // 등급은 오른쪽 위 (왼쪽은 리본 · ♡ 자리 — GuideCell 과 같음)
        if (card.badge.isNotEmpty) Positioned(right: 4, top: 4, child: TagPill(card.badge, filled: true)),
        if (onLike != null && onOwn != null)
          Positioned.fill(
            child: MarkOverlay(size: 22, liked: liked, owned: owned, onLike: onLike!, onOwn: onOwn!),
          )
        else
          tierMarks(tagTier(status)),
      ],
      caption: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
            style: const TextStyle(fontSize: Gp.t12, color: Gp.ink),
          ),
        ],
      ),
    ),
  );
}

// ── R-6 태그 시트 ─────────────────────────────────────────────────────────────────

/// 태그 상세 — 큰 그림 · 이름 · 번호 · 탄 · 등급 + ♡ 좋아요 · 구매함 (상품 상세와 같은 버튼).
/// [onOpenBook] = 검색 · 컬렉션에서 열었을 때 "도감에서 보기"
Future<void> showTagSheet(BuildContext context, TagCard card, {TagBook? book, VoidCallback? onOpenBook}) =>
    showGpSheet<void>(
      context,
      tall: true,
      builder: (_) => _TagSheet(card: card, book: book, onOpenBook: onOpenBook),
    );

class _TagSheet extends StatelessWidget {
  const _TagSheet({required this.card, this.book, this.onOpenBook});
  final TagCard card;
  final TagBook? book;
  final VoidCallback? onOpenBook;

  @override
  Widget build(BuildContext context) {
    final status = Marks.of(context).store.tagStatus(card.id); // 바뀌면 시트도 다시 그린다
    final tier = tagTier(status);
    final sets = [for (final id in card.setIds) book?.set(id)?.name ?? id.substring(id.indexOf(':') + 1)];
    final where = card.game == TagGame.mezastar ? '${card.game.label} ${card.region}' : card.game.label;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              // R-6b 크게 보기 (앞 · 뒤)
              key: const ValueKey('tag-image'),
              onTap: () =>
                  openImageViewer(context, card.large.isNotEmpty ? card.large : [card.image], label: card.name),
              child: SizedBox(
                height: 240,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    tierFrame(tier, cellImage(tier, card.large.firstOrNull ?? card.image, null)),
                    const Positioned(
                      right: 8,
                      bottom: 8,
                      child: Icon(Icons.zoom_out_map, size: Gp.iS, color: Gp.muted),
                    ),
                  ],
                ),
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
                if (card.url.isNotEmpty)
                  IconButton(
                    // R-6c
                    tooltip: '공식 페이지',
                    visualDensity: VisualDensity.compact,
                    onPressed: () async {
                      final ok = await launchUrl(Uri.parse(card.url), mode: LaunchMode.externalApplication);
                      if (!ok && context.mounted) showToast(context, '열지 못했어요');
                    },
                    icon: const Icon(Icons.open_in_new, size: Gp.iM, color: Gp.muted),
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
                    // R-6a 상품 상세와 같은 두 버튼
                    label: '좋아요',
                    icon: Icons.favorite_border,
                    activeIcon: Icons.favorite,
                    active: status == CollectStatus.wanted,
                    onTap: () => toggleTagLike(context, card),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TogglePill(
                    label: '구매함',
                    icon: Icons.bookmark_add_outlined, // 리본 + = 구매함 (칸 위 리본과 같은 모양)
                    activeIcon: Icons.bookmark_added,
                    color: Gp.own,
                    active: status == CollectStatus.owned,
                    onTap: () => toggleTagOwn(context, card),
                  ),
                ),
              ],
            ),
            if (onOpenBook != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
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
            ],
          ],
        ),
      ),
    );
  }
}

// ── R-8b 태그 줄 (목록 보기 · 검색 · 컬렉션) ─────────────────────────────────────────────

/// 줄 오른쪽 ♡ · 리본 두 개 — 상품 줄의 KitMarkButtons 와 같은 모양 (켜짐 = 채운 색, 꺼짐 = 회색 테두리)
class TagMarkButtons extends StatelessWidget {
  const TagMarkButtons({super.key, required this.card});
  final TagCard card;

  @override
  Widget build(BuildContext context) {
    final s = Marks.of(context).store.tagStatus(card.id);
    final liked = s == CollectStatus.wanted;
    final owned = s == CollectStatus.owned;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: '좋아요',
          visualDensity: VisualDensity.compact,
          onPressed: () => toggleTagLike(context, card),
          icon: LikedIcon(filled: liked, size: Gp.iM, color: liked ? Gp.accent : Gp.muted),
        ),
        IconButton(
          tooltip: '구매함',
          visualDensity: VisualDensity.compact,
          onPressed: () => toggleTagOwn(context, card),
          icon: OwnedIcon(filled: owned, size: Gp.iM, color: owned ? Gp.own : Gp.muted),
        ),
      ],
    );
  }
}

/// 태그 한 줄 — 그림 · 이름 · 부제 + 오른쪽 ♡ · 리본. 누르면 [onTap] (보통 태그 상세)
class TagRow extends StatelessWidget {
  const TagRow({
    super.key,
    required this.card,
    required this.title,
    required this.onTap,
    this.subtitle = '',
    this.size = 48,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
  });
  final TagCard card;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final double size;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => ThumbRow(
    image: card.image,
    title: title,
    subtitle: subtitle,
    size: size,
    padding: padding,
    onTap: onTap,
    trailing: TagMarkButtons(card: card),
  );
}

/// 검색 · 컬렉션 줄의 부제: 게임(지역) · 탄 · 등급
String _tagWhere(TagCard c, TagBook? b) => joinDot([
  c.game == TagGame.mezastar ? '${c.game.label} ${c.region}' : c.game.label,
  c.setIds.isEmpty ? '' : (b?.set(c.setIds.first)?.name ?? ''),
  c.badge,
]);

/// 이 카드가 든 도감 (게임 · 지역이 같은 것)
TagBook? _bookOf(List<TagBook> books, TagCard c) =>
    books.where((b) => b.game == c.game && b.region.id == c.region).firstOrNull;

/// 검색 · 컬렉션 줄 누르기 → 태그 상세 (+ 도감에서 보기)
void _openTagFrom(BuildContext context, TagCard c, TagBook? b) => showTagSheet(
  context,
  c,
  book: b,
  onOpenBook: () => openTagAtlas(context, c.game, region: c.region, query: c.number),
);

/// 태그 · 픽 상자 (둥근 판 + 머리 줄 "태그 · 픽  n개") — 검색 결과 · 컬렉션이 같은 모양
class _TagBox extends StatelessWidget {
  const _TagBox({required this.count, required this.children});
  final String count;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
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
                count,
                style: const TextStyle(color: Gp.faint, fontSize: Gp.t12),
              ),
            ],
          ),
        ),
        ...children,
      ],
    ),
  );
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
        final shown = _more ? hits : hits.take(_few).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (game != null) TagGameCards(only: game.$1),
            if (hits.isNotEmpty)
              _TagBox(
                count: '${hits.length}${hits.length >= 40 ? '+' : ''}개',
                children: [
                  for (final c in shown.map(FriendaImages.instance.apply))
                    TagRow(
                      // R-8b
                      card: c,
                      title: '${c.name}  ${c.number}',
                      subtitle: _tagWhere(c, _bookOf(books, c)),
                      onTap: () => _openTagFrom(context, c, _bookOf(books, c)),
                    ),
                  if (hits.length > _few && !_more)
                    TextButton(
                      onPressed: () => setState(() => _more = true), // STATE: 태그 결과 더 보기
                      child: Text('${hits.length - _few}개 더 보기', style: const TextStyle(fontSize: Gp.t12)),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}

// ── R-11 컬렉션 탭의 태그 ──────────────────────────────────────────────────────────

/// F 컬렉션 좋아요 · 구매함 탭 끝: 내 태그 · 픽 줄 (검색 결과와 같은 상자 · 같은 줄).
/// [owned] = 구매함 탭(아니면 좋아요 탭) · [query] = 컬렉션 찾기 글자 · [channel] = 고른 채널 (전체 · 포켓몬만 보인다).
/// 없으면 아무것도 그리지 않는다. 최근에 켠 것부터
class TagCollectionSection extends StatefulWidget {
  const TagCollectionSection({super.key, required this.owned, this.query = '', this.channel = allChannelId});
  final bool owned;
  final String query;
  final String channel;

  /// 태그가 들어갈 채널인가 (전체 · 포켓몬)
  static bool showsIn(String channel) => channel == allChannelId || channel == 'pokemon';

  @override
  State<TagCollectionSection> createState() => _TagCollectionSectionState();
}

class _TagCollectionSectionState extends State<TagCollectionSection> {
  Future<List<TagBook>>? _books;
  bool _more = false;

  static const _few = 10;

  @override
  Widget build(BuildContext context) {
    if (!TagCollectionSection.showsIn(widget.channel)) return const SizedBox.shrink();
    final store = Marks.of(context).store;
    final ids = widget.owned ? store.tagOwned : likedOnlyTags(store.tagLiked, store.tagOwned);
    if (ids.isEmpty) return const SizedBox.shrink();
    _books ??= TagAtlas.all(); // 내 태그가 있을 때만 한 번 읽는다
    return FutureBuilder<List<TagBook>>(
      future: _books,
      builder: (context, snap) {
        final books = snap.data ?? const <TagBook>[];
        final byId = {
          for (final b in books)
            for (final c in b.cards) c.id: c,
        };
        final q = widget.query.trim();
        final cards = [
          for (final id in ids.toList().reversed) // 나중에 켠 것부터
            if (byId[id] case final c? when c.matches(q)) FriendaImages.instance.apply(c),
        ];
        if (cards.isEmpty) return const SizedBox.shrink();
        final shown = _more ? cards : cards.take(_few).toList();
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _TagBox(
            count: '${cards.length}개',
            children: [
              for (final c in shown)
                TagRow(
                  // R-8b
                  card: c,
                  title: '${c.name}  ${c.number}',
                  subtitle: _tagWhere(c, _bookOf(books, c)),
                  onTap: () => _openTagFrom(context, c, _bookOf(books, c)),
                ),
              if (cards.length > _few && !_more)
                TextButton(
                  onPressed: () => setState(() => _more = true), // STATE: 컬렉션 태그 더 보기
                  child: Text('${cards.length - _few}개 더 보기', style: const TextStyle(fontSize: Gp.t12)),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// R-10 ? 도움말 — 칸 색 (상품 도감 칸과 같은 그림) · 누르기 · 찾기 줄 아이콘
List<HelpItem> tagHelp() => [
  HelpItem.widget(tierHelpCell(CellTier.none), '그림 그대로 = 아직 (칸은 늘 컬러)'),
  HelpItem.widget(tierHelpCell(CellTier.liked), '♡ = 좋아요'),
  HelpItem.widget(tierHelpCell(CellTier.owned), '리본 = 구매함 (수집 수)'),
  const HelpItem(Icons.bookmark_add_outlined, '칸 왼쪽 위 리본 = 구매함 켜고 끄기', color: Gp.own),
  const HelpItem(Icons.favorite_border, '칸 왼쪽 아래 ♡ = 좋아요 켜고 끄기', color: Gp.accent),
  const HelpItem(Icons.touch_app_outlined, '칸 누르기 = 태그 상세 (좋아요 · 구매함 버튼)'),
  const HelpItem(Icons.zoom_out_map, '상세의 그림 누르기 = 크게 보기 (앞 · 뒤)'),
  const HelpItem(Icons.open_in_new, '공식 페이지 (브라우저)'),
  const HelpItem(Icons.tune, '필터 (상품 필터와 같은 상태 줄 · 등급 · 타입)'),
  const HelpItem(Icons.grid_view_outlined, '격자로 보기'),
  const HelpItem(Icons.view_list_outlined, '목록으로 보기 (줄 오른쪽 ♡ · 리본)'),
];
