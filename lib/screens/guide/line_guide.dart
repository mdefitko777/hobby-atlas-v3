// G-10 종류별 도감 — 세대 · 작품 축(G-3 · G-7) 옆의 두 번째 축: 채널 상품을 라인 · 굿즈 종류 카드로 → 묶음 칸(G-11)
//
// ┌──────── 디자인 가이드 대응표: G 도감 (종류별) ─────────────────────────────────────┐
// │ 번호  │ Flutter 위젯명                          │ 비즈니스 명칭(한글)                          │ 원칙(P번호) │
// │ G-10  │ SectionHeader + 종류 카드 SliverGrid + 진행 막대 │ 종류별 도감: 라인 · 굿즈 종류 묶음 (수집 n/전체) │ P01 · P06 │
// │ G-10a │ 채널마다 SectionHeader(›) + 종류 카드     │ '전체'일 때: 채널별 종류 묶음 · 머리 누르면 그 채널 │ P06     │
// │ G-10b │ 머리 ? (HelpButton)                     │ 종류별 도감 읽는 법 (칸 단계 · 기타 묶음)      │ P10         │
// │ G-11  │ 상품 칸 격자 (TierCell · SliverGrid)     │ 묶음 하나의 상품 전부: 흑백 → ♡ 컬러 → 구매함 초록 테두리 │ P01 · P04 │
// │ G-11a │ 칸 위 MarkOverlay (리본 · ♡)             │ 바로 좋아요 · 구매함 (토스트 되돌리기)         │ P07 · P03   │
// │ G-11b │ FindBar + 상태 GpPickSheet              │ 묶음 안에서 찾기 + 전체 · 내 것 · 좋아요 · 구매함 · 아직 │ P07 · P01 │
// │ G-11c │ ToolIcon(정렬) → showPickSheet          │ 발매일 최신 · 오래된 · 이름                  │ P07         │
// │ G-11d │ 발매 연도 SectionHeader                  │ 발매일 정렬일 때 연도마다 수집 n/전체          │ P01 · P06   │
// │ G-11e │ AppBar ? (HelpButton)                  │ 칸 단계 · 아이콘 뜻                          │ P10         │
// │ G-12  │ LoadingView / ErrorView / EmptyView     │ 불러오는 중 · 오류 · 상품 없음 · 찾기 결과 없음  │ P01 · P09   │
// └──────────────────────────────────────────────────────────────────────────────────┘
// 전환(종류별): 종류 카드 → G-11 묶음 칸(쌓기) → D 상품 상세(쌓기, 보이는 칸끼리 좌우).
// 데이터(종류별): Loaders.kits([채널]) → lib/logic/line_guide.dart lineGroups (라인 · 굿즈 세부 종류 · 작은 묶음 = 기타).
import 'package:flutter/material.dart';

import '../../api.dart';
import '../../channels.dart';
import '../../detail_pane.dart';
import '../../level.dart' show tierHelpCell;
import '../../logic/kit_rules.dart' show kitMatches;
import '../../logic/line_guide.dart';
import '../../marks.dart';
import '../../models.dart';
import '../../theme.dart';
import '../../widgets.dart';
import '../c_channel_screen.dart' show allChannelId;
import '../d_kit_detail_screen.dart' show openKitDetail;
import 'guide_parts.dart';

export '../../logic/line_guide.dart' show LineSort, LineStatus;

/// 칸 아래 이름 두 줄 + 발매일 한 줄
const _captionHeight = 48.0;

/// G-10 종류별 도감 — [channel] 의 상품을 라인 · 굿즈 종류 카드로. [allChannelId] 면 채널마다 한 묶음(G-10a)
class LineGuideView extends StatefulWidget {
  const LineGuideView({
    super.key,
    required this.channel,
    required this.loaders,
    this.query = '',
    this.mineOnly = false,
    this.myChannels,
    this.onPickChannel,
  });

  final String channel;
  final Loaders loaders;

  /// 찾기 글자 — 묶음 이름이나 상품(Kit.blob)에 맞는 묶음만, 상품으로 찾았으면 묶음 안에서도 그 말로
  final String query;

  /// 좋아요 · 구매함이 있는 묶음만 (열면 '내 것' 상태로)
  final bool mineOnly;

  /// '전체'일 때 보일 채널 (null = 상품이 있는 채널 전부, 빈 목록 = 내 채널 없음 안내)
  final List<String>? myChannels;

  /// '전체'일 때 채널 머리를 누르면 (없으면 머리를 못 누른다)
  final ValueChanged<String>? onPickChannel;

  @override
  State<LineGuideView> createState() => _LineGuideViewState();
}

class _LineGuideViewState extends State<LineGuideView> {
  late Future<List<Kit>> _future = _load();

  /// 마지막으로 묶은 상품 · 내 기록 버전 (같으면 다시 묶지 않는다)
  List<Kit>? _src;
  int _seen = -1;
  Map<String, List<LineGroup>> _groups = const {};

  List<String> get _channels => widget.channel != allChannelId
      ? [widget.channel]
      : widget.myChannels ??
            [
              for (final c in allChannels)
                if (c.hasData) c.id,
            ];

  Future<List<Kit>> _load() {
    final ids = _channels;
    return ids.isEmpty ? Future.value(const <Kit>[]) : widget.loaders.kits(ids); // STATE: GET /kits?franchiseId=
  }

  @override
  void didUpdateWidget(LineGuideView old) {
    super.didUpdateWidget(old);
    final channelsChanged = old.channel != widget.channel || old.myChannels?.join() != widget.myChannels?.join();
    if (channelsChanged) {
      _future = _load();
      _src = null;
    }
  }

  /// 채널 → 종류 묶음 (상품이 바뀌거나 내 기록이 바뀌면 다시 센다)
  Map<String, List<LineGroup>> _grouped(List<Kit> kits, Marks m) {
    if (identical(kits, _src) && m.version == _seen) return _groups;
    final byChannel = <String, List<Kit>>{};
    for (final k in kits) {
      (byChannel[k.franchiseId] ??= []).add(k);
    }
    _src = kits;
    _seen = m.version;
    return _groups = {for (final id in _channels) id: lineGroups(id, byChannel[id] ?? const [], status: m.statusOf)};
  }

  void _open(String channel, LineGroup g, bool carry) => openLineGroup(
    context,
    channel,
    g.key,
    loaders: widget.loaders,
    query: carry ? widget.query : '',
    status: widget.mineOnly ? LineStatus.mine : LineStatus.all,
  );

  @override
  Widget build(BuildContext context) {
    if (widget.channel == allChannelId && _channels.isEmpty) {
      return const EmptyView(
        icon: Icons.auto_awesome_mosaic_outlined,
        message: '내 채널이 비어 있어요',
        detail: '채널 관리에서 IP를 추가하면 도감을 볼 수 있어요',
      );
    }
    final m = Marks.of(context); // 좋아요 · 구매함이 바뀌면 카드 숫자도 바로
    return FutureBuilder<List<Kit>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const LoadingView(); // G-12
        if (snap.hasError) {
          return ErrorView(message: '${snap.error}', onRetry: () => setState(() => _future = _load()));
        }
        final grouped = _grouped(snap.data!, m);
        final q = widget.query.trim().toLowerCase();
        // 채널 → 보이는 카드 (묶음 · 찾은 수 · 찾던 말을 묶음 안으로 넘길지)
        final shown = <String, List<_Hit>>{};
        for (final e in grouped.entries) {
          final hits = <_Hit>[];
          for (final g in e.value) {
            if (widget.mineOnly && !g.mine) continue;
            if (q.isEmpty || g.label.toLowerCase().contains(q)) {
              hits.add(_Hit(g, g.total, false));
              continue;
            }
            final n = g.kits.where((k) => kitMatches(k, q)).length;
            if (n > 0) hits.add(_Hit(g, n, true));
          }
          if (hits.isNotEmpty) shown[e.key] = hits;
        }
        if (shown.isEmpty) {
          if (q.isNotEmpty) return guideNoHit;
          if (widget.mineOnly) {
            return const EmptyView(
              icon: Icons.favorite_border,
              message: '아직 좋아요 · 구매한 상품이 없어요',
              detail: '♡ 나 리본을 누르면 그 종류 카드가 생겨요',
            );
          }
          return EmptyView(
            icon: Icons.auto_awesome_mosaic_outlined,
            message: widget.channel == allChannelId
                ? '아직 수록된 상품이 없어요'
                : '${channelOf(widget.channel).label} 상품이 아직 없어요',
          );
        }
        final all = widget.channel == allChannelId;
        return LayoutBuilder(
          builder: (context, box) => CustomScrollView(
            slivers: [
              for (final (i, e) in shown.entries.indexed) ...[
                SliverToBoxAdapter(
                  child: SectionHeader(
                    all ? channelOf(e.key).label : '종류',
                    subtitle:
                        '수집 ${e.value.fold(0, (s, h) => s + h.group.owned)}'
                        ' / ${e.value.fold(0, (s, h) => s + h.group.total)}',
                    trailing: i == 0 ? HelpButton(title: '종류별 도감', items: lineGuideHelp()) : null, // G-10b
                    onMore: all && widget.onPickChannel != null
                        ? () =>
                              widget.onPickChannel!(e.key) // G-10a STATE: 채널 고르기
                        : null,
                    padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: Gp.gutter),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: guideCols(box.maxWidth, 120),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.78,
                    ),
                    delegate: SliverChildBuilderDelegate(childCount: e.value.length, (context, j) {
                      final h = e.value[j];
                      final g = h.group;
                      return GuideWorkCard(
                        // G-10 P01
                        key: ValueKey('line-${e.key}-${g.key}'),
                        image: lineCovers[e.key]?[g.key] ?? g.cover, // G-10 공식 로고 · 대표 그림, 없으면 최근 상품
                        name: g.label,
                        subtitle: h.carry
                            ? '찾은 ${h.count}개'
                            : (widget.mineOnly ? '좋아요 ${g.liked} · 구매함 ${g.owned}' : '${g.total}개'),
                        owned: g.owned,
                        total: g.total,
                        onTap: () => _open(e.key, g, h.carry),
                      );
                    }),
                  ),
                ),
              ],
              SliverToBoxAdapter(child: SizedBox(height: navClearance(context))),
            ],
          ),
        );
      },
    );
  }
}

/// 보이는 카드 하나: 묶음 · 찾은 상품 수 · 찾던 말을 묶음 안으로 넘길지(상품으로 찾았을 때)
class _Hit {
  const _Hit(this.group, this.count, this.carry);
  final LineGroup group;
  final int count;
  final bool carry;
}

/// G-11 종류 묶음 하나 열기 — [query] 묶음 안 찾기 글자, [status] 처음 상태 거르기
void openLineGroup(
  BuildContext context,
  String channel,
  String groupKey, {
  Loaders loaders = const Loaders(),
  String query = '',
  LineStatus status = LineStatus.all,
}) => openPage(
  context,
  LineGroupScreen(channel: channel, groupKey: groupKey, loaders: loaders, initialQuery: query, initialStatus: status),
);

/// G-11 종류 묶음 하나의 상품 칸 (찾기 · 상태 · 정렬 · 발매 연도)
class LineGroupScreen extends StatefulWidget {
  const LineGroupScreen({
    super.key,
    required this.channel,
    required this.groupKey,
    this.loaders = const Loaders(),
    this.initialQuery = '',
    this.initialStatus = LineStatus.all,
  });

  final String channel;
  final String groupKey;
  final Loaders loaders;
  final String initialQuery;
  final LineStatus initialStatus;

  @override
  State<LineGroupScreen> createState() => _LineGroupScreenState();
}

class _LineGroupScreenState extends State<LineGroupScreen> {
  late Future<List<Kit>> _future = widget.loaders.kits([widget.channel]); // STATE: GET /kits?franchiseId=

  /// 받은 상품 → 이 묶음 (묶음 모양은 내 기록과 상관없어 한 번만)
  List<Kit>? _src;
  LineGroup? _group;

  late String _query = widget.initialQuery;
  late LineStatus _status = widget.initialStatus;
  LineSort _sort = LineSort.newest;

  String get _label => lineGroupLabel(widget.groupKey);

  LineGroup? _groupOf(List<Kit> kits) {
    if (!identical(kits, _src)) {
      _src = kits;
      _group = lineGroupOf(lineGroups(widget.channel, kits), widget.groupKey);
    }
    return _group;
  }

  bool _hit(Kit k) => kitMatches(k, _query);

  Future<void> _openSort() async {
    final s = await showPickSheet<LineSort>(
      context,
      title: '정렬',
      values: LineSort.values,
      current: _sort,
      label: (v) => v.label,
    );
    if (s != null) setState(() => _sort = s); // STATE: 정렬 → 칸 순서 · 연도 머리
  }

  Future<void> _openFilter(List<Kit> kits) async {
    final m = Marks.read(context);
    final s = await showGpSheet<LineStatus>(
      context,
      heightFactor: gpSheetHeight,
      builder: (_) =>
          _StatusSheet(initial: _status, countOf: (f) => kits.where((k) => f.matches(m.statusOf(k)) && _hit(k)).length),
    );
    if (s != null) setState(() => _status = s); // STATE: 상태 거르기 → 칸
  }

  Scaffold _shell(Widget body, {String count = ''}) => Scaffold(
    appBar: AppBar(
      title: BarTitle(_label, count: count),
      actions: [
        HelpButton(title: '종류별 도감', items: lineGroupHelp()), // G-11e
        const SizedBox(width: 6),
      ],
    ),
    body: body,
  );

  @override
  Widget build(BuildContext context) {
    final m = Marks.of(context); // ♡ · 리본을 누르면 칸 단계 · 숫자가 바로 바뀐다
    return FutureBuilder<List<Kit>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return _shell(const LoadingView()); // G-12
        if (snap.hasError) {
          return _shell(
            ErrorView(
              message: '${snap.error}',
              onRetry: () => setState(() => _future = widget.loaders.kits([widget.channel])),
            ),
          );
        }
        final g = _groupOf(snap.data!);
        if (g == null) {
          return _shell(const EmptyView(icon: Icons.grid_view, message: '이 종류의 상품이 없어요'));
        }
        final kits = lineKits(g.kits, status: m.statusOf, matches: _hit, filter: _status, sort: _sort);
        final owned = g.kits.where(m.owned).length;
        return _shell(
          count: '수집 $owned / ${g.total}',
          LayoutBuilder(
            builder: (context, box) {
              final cols = guideCols(box.maxWidth, 110);
              final cellW = (box.maxWidth - Gp.gutter * 2 - (cols - 1) * 10) / cols;
              Widget grid(List<Kit> list) => SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: Gp.gutter),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    mainAxisExtent: cellW + 5 + _captionHeight,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    childCount: list.length,
                    (context, i) => _KitCell(kit: list[i], onTap: () => _openKit(list[i], kits)),
                  ),
                ),
              );
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: FindBar(
                      // G-11b
                      hint: '$_label에서 찾기',
                      initial: widget.initialQuery,
                      onQuery: (q) => setState(() => _query = q), // STATE: 찾기 → 칸 거르기
                      filterCount: _status == LineStatus.all ? 0 : 1,
                      onFilter: () => _openFilter(g.kits),
                      tools: [
                        // G-11c
                        ToolIcon(icon: Icons.swap_vert, tip: '정렬', onTap: _openSort),
                      ],
                    ),
                  ),
                  if (kits.isEmpty)
                    const SliverFillRemaining(hasScrollBody: false, child: guideNoHit)
                  else if (!_sort.byDate)
                    grid(kits)
                  else
                    // G-11d 발매 연도마다
                    for (final (year, list) in byReleaseYear(kits)) ...[
                      SliverToBoxAdapter(
                        child: SectionHeader(
                          year,
                          subtitle: '수집 ${list.where(m.owned).length} / ${list.length}',
                          padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                        ),
                      ),
                      grid(list),
                    ],
                  SliverToBoxAdapter(child: SizedBox(height: 32 + MediaQuery.paddingOf(context).bottom)),
                ],
              );
            },
          ),
        );
      },
    );
  }

  /// D 상품 상세 — 지금 보이는 칸끼리 좌우로 넘김
  void _openKit(Kit k, List<Kit> shown) => openKitDetail(context, k, loaders: widget.loaders, list: shown);
}

/// G-11 상품 칸 하나 — 내 기록 단계 + 리본 · ♡ + 이름 · 발매일
class _KitCell extends StatelessWidget {
  const _KitCell({required this.kit, required this.onTap});
  final Kit kit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = Marks.of(context);
    final s = m.statusOf(kit);
    final tier = switch (s) {
      CollectStatus.owned => CellTier.owned,
      CollectStatus.wanted => CellTier.liked,
      CollectStatus.none => CellTier.none,
    };
    return TierCell(
      key: ValueKey(kit.id),
      image: kit.image,
      tier: tier,
      onTap: onTap,
      overlays: [
        if (kit.pb || kit.limited) Positioned(right: 5, top: 5, child: TagPill(kit.pb ? 'PB' : '한정', filled: true)),
        Positioned.fill(
          child: MarkOverlay(
            // G-11a
            size: 22,
            liked: s == CollectStatus.wanted,
            owned: s == CollectStatus.owned,
            onLike: () => Marks.read(context).toggleLike(context, kit), // STATE: ♡ → 칸 컬러
            onOwn: () => Marks.read(context).toggleOwn(context, kit), // STATE: 리본 → 초록 테두리
          ),
        ),
      ],
      caption: SizedBox(
        height: _captionHeight,
        child: Column(
          children: [
            Text(
              kit.name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: Gp.t12, color: tier == CellTier.none ? Gp.muted : Gp.ink, height: 1.25),
            ),
            Text(
              kit.date.isEmpty ? '발매일 미정' : dateDot(kit.date),
              maxLines: 1,
              style: const TextStyle(fontSize: Gp.t11, color: Gp.faint),
            ),
          ],
        ),
      ),
    );
  }
}

/// G-11b 상태 거르기 시트 — 고르는 동안 맞는 상품 수
class _StatusSheet extends StatefulWidget {
  const _StatusSheet({required this.initial, required this.countOf});
  final LineStatus initial;
  final int Function(LineStatus) countOf;

  @override
  State<_StatusSheet> createState() => _StatusSheetState();
}

class _StatusSheetState extends State<_StatusSheet> {
  late LineStatus _draft = widget.initial;

  @override
  Widget build(BuildContext context) => GpPickSheet(
    title: '상태',
    hits: widget.countOf(_draft),
    noHitLabel: '맞는 상품 없음',
    onApply: () => Navigator.pop(context, _draft),
    onReset: () => setState(() => _draft = LineStatus.all),
    children: [
      SquareSegments<LineStatus>(
        values: LineStatus.values,
        current: _draft,
        child: (v) => Text(v.label),
        onPick: (v) => setState(() => _draft = v),
      ),
      const SizedBox(height: 12),
      for (final v in LineStatus.values)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  v.label,
                  style: TextStyle(fontSize: Gp.t14, color: v == _draft ? Gp.accent : Gp.ink),
                ),
              ),
              Text(
                '${widget.countOf(v)}개',
                style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
              ),
            ],
          ),
        ),
    ],
  );
}

/// G-10b 종류별 도감 ? — 카드 · 칸 단계 · 기타 묶음
List<HelpItem> lineGuideHelp() => [
  HelpItem.widget(tierHelpCell(CellTier.none), '흑백 = 아직'),
  HelpItem.widget(tierHelpCell(CellTier.liked), '컬러 = ♡ 좋아요'),
  HelpItem.widget(tierHelpCell(CellTier.owned), '초록 테두리 = 구매함'),
  const HelpItem.group('카드'),
  const HelpItem(Icons.category_outlined, '라인(HG · MG …) · 굿즈 종류마다 한 장'),
  const HelpItem(Icons.more_horiz, '기타 = 상품 $lineMinGroup개가 안 되는 작은 묶음'),
];

/// G-11e 묶음 칸 ? — 칸 단계 + 찾기 줄 · 칸 위 아이콘
List<HelpItem> lineGroupHelp() => [
  HelpItem.widget(tierHelpCell(CellTier.none), '흑백 = 아직'),
  HelpItem.widget(tierHelpCell(CellTier.liked), '컬러 = ♡ 좋아요'),
  HelpItem.widget(tierHelpCell(CellTier.owned), '초록 테두리 = 구매함'),
  const HelpItem.group('아이콘'),
  const HelpItem(Icons.favorite_border, '좋아요 (칸 왼쪽 아래)', color: Gp.accent),
  const HelpItem(Icons.bookmark_border, '구매함 (칸 왼쪽 위 리본)', color: Gp.own),
  const HelpItem(Icons.tune, '상태: 전체 · 내 것 · 좋아요 · 구매함 · 아직'),
  const HelpItem(Icons.swap_vert, '정렬: 발매일 최신 · 오래된 · 이름'),
];
