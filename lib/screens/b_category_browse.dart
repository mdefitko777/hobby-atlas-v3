// 화면 B (검색 탭 안의 보기): 종류 · 세대 둘러보기 — 상품 카탈로그처럼 분류 칸 = 공식 그림 + 이름만 (숫자 · 진행 없음)
// 검색 탭 위 줄 "전체 · 종류 · 세대" 의 두 보기. 칸을 누르면 그 분류의 상품 화면(B-23, b_category_products.dart).
//
// ┌──────── 디자인 가이드 대응표: B 검색 (종류 · 세대) ───────────────────────────────┐
// │ 번호 │  Flutter 위젯명                          │ 비즈니스 명칭(한글)                          │ 원칙(P번호) │
// │ B-20  │ 작은 묶음 머리 + CategoryTile 격자(한 줄 4칸) │ 종류: 프라모델 · 옛 등급 · SD · 완성품 피규어 · 식완 · 가샤폰 · 굿즈 … 묶음 안 라인 칸 (공식 로고 + 이름) │ P06 · P04 │
// │ B-20a │ 채널마다 SectionHeader(›) + 묶음들       │ '전체' 채널: 내 채널마다 한 덩어리 · 머리 누르면 그 채널 │ P06 · P07 │
// │ B-20b │ 검색 탭 필터(KitFilter) → 칸 거르기       │ 필터를 고르면 맞는 상품이 있는 칸만 · 연 상품 화면도 그 필터로 │ P07 · P01 │
// │ B-21  │ 작은 묶음 머리 + CategoryTile 격자       │ 세대: 건담 = 시대별 작품(공식 작품 로고) · 포켓몬 세대 · Fate 작품 · AC 시리즈 · 베이 라인 │ P06 · P04 │
// │ B-22  │ 첫 머리 ? (HelpButton)                  │ 종류 · 세대 보기 읽는 법                      │ P10         │
// │ B-24  │ LoadingView / ErrorView / EmptyView     │ 불러오는 중 · 오류 · 내 채널 없음 · 조건에 맞는 상품 없음 │ P01 · P09 │
// └──────────────────────────────────────────────────────────────────────────────────┘
// 전환: 칸 → B-23 분류 상품(쌓기) → D 상품 상세. '전체'의 채널 머리 → 검색 탭 채널 바꾸기.
// 데이터: 종류 = Loaders.kits → lib/logic/category_browse.dart typeSections (묶음 · 칸 순서 · 빈 칸 숨김),
//   세대 = 건담 Loaders.guideWorks + guideUnits(작품 기체의 상품) · 그 밖 Loaders.worlds(World.kitIds, 베이는 라인).
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../api.dart';
import '../channels.dart';
import '../logic/category_browse.dart';
import '../logic/short_names.dart';
import '../marks.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'b_category_products.dart';
import 'c_channel_screen.dart' show allChannelId;

/// 분류 칸 하나 (화면용) — 키 · 이름 · 그림 · 상품(새것부터)
class _Cat {
  const _Cat(this.key, this.name, this.image, this.kits);
  final String key;
  final String name;

  /// 공식 그림 (없으면 최근 상품 사진)
  final String image;
  final List<Kit> kits;
}

/// 채널 하나의 묶음들
typedef _Block = (String channel, List<(String, List<_Cat>)> sections);

/// B-20 종류 — 채널 상품을 라인 · 종류 칸으로, 칸은 묶음(프라모델 · SD · 완성품 …) 머리 아래
class TypeBrowse extends StatelessWidget {
  const TypeBrowse({
    super.key,
    required this.channel,
    required this.loaders,
    this.myChannels = const [],
    this.onPickChannel,
    this.filter,
  });

  final String channel;
  final Loaders loaders;

  /// '전체'일 때 보일 채널 (비었으면 안내)
  final List<String> myChannels;

  /// '전체'일 때 채널 머리를 누르면 (없으면 머리를 못 누른다)
  final ValueChanged<String>? onPickChannel;

  /// B-20b 검색 탭의 상품 필터 — 조건이 있으면 맞는 상품이 있는 칸만, 상품 화면도 이 필터로 시작
  final KitFilter? filter;

  @override
  Widget build(BuildContext context) => _CategoryBrowse(
    key: const ValueKey('type-browse'),
    era: false,
    channel: channel,
    loaders: loaders,
    myChannels: myChannels,
    onPickChannel: onPickChannel,
    filter: filter,
  );
}

/// B-21 세대 — 건담은 시대별 작품, 그 밖은 세대 · 작품 묶음
class EraBrowse extends StatelessWidget {
  const EraBrowse({
    super.key,
    required this.channel,
    required this.loaders,
    this.myChannels = const [],
    this.onPickChannel,
    this.filter,
  });

  final String channel;
  final Loaders loaders;
  final List<String> myChannels;
  final ValueChanged<String>? onPickChannel;
  final KitFilter? filter;

  @override
  Widget build(BuildContext context) => _CategoryBrowse(
    key: const ValueKey('era-browse'),
    era: true,
    channel: channel,
    loaders: loaders,
    myChannels: myChannels,
    onPickChannel: onPickChannel,
    filter: filter,
  );
}

class _CategoryBrowse extends StatefulWidget {
  const _CategoryBrowse({
    super.key,
    required this.era,
    required this.channel,
    required this.loaders,
    required this.myChannels,
    required this.onPickChannel,
    required this.filter,
  });

  final bool era;
  final String channel;
  final Loaders loaders;
  final List<String> myChannels;
  final ValueChanged<String>? onPickChannel;
  final KitFilter? filter;

  @override
  State<_CategoryBrowse> createState() => _CategoryBrowseState();
}

class _CategoryBrowseState extends State<_CategoryBrowse> {
  late Future<List<_Block>> _future = _load();

  bool get _all => widget.channel == allChannelId;
  List<String> get _channels => _all ? widget.myChannels : [widget.channel];

  @override
  void didUpdateWidget(_CategoryBrowse old) {
    super.didUpdateWidget(old);
    if (old.channel != widget.channel || old.era != widget.era || old.myChannels.join() != widget.myChannels.join()) {
      _future = _load(); // STATE: 채널 → 다시 묶기
    }
  }

  Future<List<_Block>> _load() async {
    final ids = _channels;
    if (ids.isEmpty) return const [];
    final kits = await widget.loaders.kits(ids); // STATE: 채널 상품
    final byChannel = <String, List<Kit>>{};
    for (final k in kits) {
      (byChannel[k.franchiseId] ??= []).add(k);
    }
    return [
      for (final id in ids)
        (
          id,
          widget.era ? await _eraSections(id, byChannel[id] ?? const []) : _typeSections(id, byChannel[id] ?? const []),
        ),
    ];
  }

  /// B-20 종류 묶음 — 그림 = 공식 라인 로고(lineCovers), 없으면 최근 상품
  List<(String, List<_Cat>)> _typeSections(String channel, List<Kit> kits) => [
    for (final s in typeSections(channel, kits))
      (s.title, [for (final e in s.entries) _Cat(e.key, e.label, lineCovers[channel]?[e.key] ?? e.cover, e.kits)]),
  ];

  /// B-21 세대 묶음 — 상품이 없는 칸은 숨긴다
  Future<List<(String, List<_Cat>)>> _eraSections(String channel, List<Kit> kits) async {
    final byId = {for (final k in kits) k.id: k};
    // 한국 짝이 있는 일본 상품은 목록에 없다 → 묶음이 일본 쪽 id 만 가져도 한국 쪽 카드로 (한 카드만)
    final byTwin = {
      for (final k in kits)
        if (k.twinId.isNotEmpty) k.twinId: k,
    };
    List<Kit> resolve(Iterable<String> ids) =>
        {for (final id in ids) ?(byId[id] ?? byTwin[id])}.toList()..sort(newestFirst);

    if (channel == 'gundam') {
      // 작품 = 그 작품 기체들에 연결된 상품
      final works = await widget.loaders.guideWorks(); // STATE: 건담 작품 목록
      final units = await Future.wait([
        for (final w in works) widget.loaders.guideUnits(w.id).catchError((Object _) => const <GuideUnit>[]),
      ]);
      final cats = <GuideWork, _Cat>{};
      for (final (i, w) in works.indexed) {
        final list = resolve([for (final u in units[i]) ...u.kitIds]);
        if (list.isNotEmpty) {
          cats[w] = _Cat(w.id, shortWorkName(w.name), w.image.isNotEmpty ? w.image : newestCover(list), list);
        }
      }
      return [
        for (final (title, ws) in workSections(cats.keys)) (title, [for (final w in ws) cats[w]!]),
      ];
    }
    final worlds = await widget.loaders.worlds(channel); // STATE: 채널의 세대 · 작품
    final cats = <_Cat>[];
    for (final w in worlds) {
      final list = w.kitIds.isNotEmpty || channel != 'beyblade'
          ? resolve(w.kitIds)
          : ([
              for (final k in kits)
                if (beyInWorld(k, w.id)) k,
            ]..sort(newestFirst));
      if (list.isEmpty) continue;
      // 베이 라인은 공식 라인 로고(BX · UX · CX)가 먼저
      final line = w.id.replaceFirst('beyblade-', '').toUpperCase();
      final logo = channel == 'beyblade' ? (lineCovers[channel]?[line]) : null;
      final name = shortWorldLabel(channel, w.id, w.label);
      cats.add(_Cat(w.id, name, logo ?? (w.image.isNotEmpty ? w.image : newestCover(list)), list));
    }
    return worldSections(channel, cats, (c) => c.key);
  }

  void _open(String channel, _Cat c, KitFilter? f) => openCategoryProducts(
    context,
    title: c.name,
    image: c.image,
    kits: c.kits,
    loaders: widget.loaders,
    filter: f?.copy(), // B-20b 검색 탭 필터를 복사해서 시작
    groupByUnit: widget.era && channel == 'gundam',
  );

  @override
  Widget build(BuildContext context) {
    if (_all && widget.myChannels.isEmpty) {
      return EmptyView(
        // B-24
        icon: Icons.auto_awesome_mosaic_outlined,
        message: tr('내 채널이 비어 있어요'),
        detail: tr('채널 관리에서 IP를 추가하면 둘러볼 수 있어요'),
      );
    }
    // B-20b 조건이 있을 때만 거른다 (내 상태는 Marks 로)
    final f = (widget.filter?.count ?? 0) > 0 ? widget.filter : null;
    if (f != null) f.statusOf = Marks.of(context).statusOf;
    return FutureBuilder<List<_Block>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const LoadingView(); // B-24
        if (snap.hasError) {
          return ErrorView(message: '${snap.error}', onRetry: () => setState(() => _future = _load()));
        }
        bool hit(_Cat c) => f == null || c.kits.any(f.matches);
        List<(String, List<_Cat>)> keep(List<(String, List<_Cat>)> sections) => [
          for (final (title, cats) in sections)
            if (cats.where(hit).toList() case final shown when shown.isNotEmpty) (title, shown),
        ];
        final blocks = <_Block>[
          for (final (ch, sections) in snap.data!)
            if (keep(sections) case final kept when kept.isNotEmpty) (ch, kept),
        ];
        if (blocks.isEmpty) {
          return f != null
              ? EmptyView(icon: Icons.search_off, message: tr('이 조건의 상품이 없어요')) // B-24
              : EmptyView(
                  icon: Icons.auto_awesome_mosaic_outlined,
                  message: _all
                      ? tr('아직 수록된 상품이 없어요')
                      : trf('{channel} 상품이 아직 없어요', {'channel': tr(channelOf(widget.channel).label)}),
                );
        }
        final help = HelpButton(
          title: widget.era ? tr('세대') : tr('종류'),
          items: categoryBrowseHelp(era: widget.era),
        ); // B-22
        var first = true;
        Widget? helpOnce() {
          if (!first) return null;
          first = false;
          return help;
        }

        return LayoutBuilder(
          builder: (context, box) => CustomScrollView(
            slivers: [
              for (final (ch, sections) in blocks) ...[
                if (_all)
                  SliverToBoxAdapter(
                    child: SectionHeader(
                      // B-20a
                      tr(channelOf(ch).label),
                      trailing: helpOnce(),
                      onMore: widget.onPickChannel == null ? null : () => widget.onPickChannel!(ch), // STATE: 채널 고르기
                      padding: const EdgeInsets.fromLTRB(16, 12, 4, 0),
                    ),
                  ),
                for (final (title, cats) in sections) ...[
                  SliverToBoxAdapter(child: _SubHead(tr(title), trailing: helpOnce())),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: Gp.gutter),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: categoryCols(box.maxWidth),
                        mainAxisSpacing: categoryGridGap,
                        crossAxisSpacing: categoryGridGap,
                        childAspectRatio: categoryTileAspect,
                      ),
                      delegate: SliverChildBuilderDelegate(childCount: cats.length, (context, i) {
                        final c = cats[i];
                        return CategoryTile(
                          // B-20 · B-21 공식 그림 + 이름만
                          key: ValueKey('cat-$ch-${c.key}'),
                          image: c.image,
                          name: tr(c.name),
                          onTap: () => _open(ch, c, f),
                        );
                      }),
                    ),
                  ),
                ],
              ],
              SliverToBoxAdapter(child: SizedBox(height: navClearance(context))),
            ],
          ),
        );
      },
    );
  }
}

/// 묶음 머리 (작은 글자) — 채널 머리(SectionHeader)보다 한 단 아래
class _SubHead extends StatelessWidget {
  const _SubHead(this.title, {this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(16, trailing == null ? 14 : 2, trailing == null ? 16 : 4, trailing == null ? 8 : 0),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: Gp.t14, fontWeight: FontWeight.w600, color: Gp.muted),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// B-22 종류 · 세대 ? — 칸 · 묶음 · 필터
List<HelpItem> categoryBrowseHelp({required bool era}) => [
  if (era) ...[
    HelpItem(Icons.auto_awesome_mosaic_outlined, tr('건담 = 시대별 작품 (공식 작품 로고)')),
    HelpItem(Icons.layers_outlined, tr('포켓몬 세대 · Fate 작품 · 아머드 코어 시리즈 · 베이 라인')),
  ] else ...[
    HelpItem(Icons.category_outlined, tr('공식 라인 · 상품 종류마다 한 칸 (그림 = 공식 로고, 없으면 최근 상품)')),
    HelpItem(Icons.view_module_outlined, tr('묶음: 프라모델 · SD · 완성품 피규어 · 식완 · 가샤폰 · 굿즈 …')),
    HelpItem(Icons.more_horiz, trf('{other} = 상품 {n}개가 안 되는 굿즈 종류', {'other': tr(lineOtherKey), 'n': lineMinGroup})),
  ],
  HelpItem(Icons.tune, tr('필터를 고르면 맞는 상품이 있는 칸만 · 연 화면도 그 필터로')),
  HelpItem(Icons.chevron_right, tr('칸을 누르면 그 상품 전부 (♡ · 리본 = 내 상태)')),
];
