// 화면 B (검색 탭 안의 보기): 종류 · 세대 둘러보기 — 왼쪽 묶음 목록 + 오른쪽 분류 칸 (공식 로고, 없으면 가장 새 상품 사진 + 이름)
// 검색 탭 위 줄 "전체 · 종류 · 세대" 의 두 보기. 칸을 누르면 그 분류의 상품 화면(B-23, b_category_products.dart).
//
// ┌──────── 디자인 가이드 대응표: B 검색 (종류 · 세대) ───────────────────────────────┐
// │ 번호 │  Flutter 위젯명                          │ 비즈니스 명칭(한글)                          │ 원칙(P번호) │
// │ B-20  │ 왼쪽 묶음 목록 + CategoryTile 격자       │ 종류: 프라모델 · 기타 등급 · SD건담 · 완성품 · 가샤폰 · 식완 · 굿즈 … 고른 묶음의 칸만 │ P06 · P04 │
// │ B-20a │ 묶음 목록 안 채널 머리(›)                │ '전체' 채널: 내 채널마다 그 아래 묶음 · 머리 누르면 그 채널 │ P06 · P07 │
// │ B-20b │ 검색 탭 필터(KitFilter) → 칸 거르기       │ 필터를 고르면 맞는 상품이 있는 칸만 · 연 상품 화면도 그 필터로 │ P07 · P01 │
// │ B-20c │ SideDirectory 펴기 · 접기 (밀기 + 손잡이) │ 펴면 한 줄 3칸, 접으면 화면 가득 4칸 · 펴 둔 상태는 기기에 기억 (도감과 같은 틀) │ P06 · P03 │
// │ B-21  │ 왼쪽 묶음 목록 + CategoryTile 격자       │ 세대: 건담 = 시대별 작품(공식 작품 로고) · 포켓몬 세대 · Fate 작품 · AC 작품 · 베이 라인 · 레고 테마 │ P06 · P04 │
// │ B-22  │ 서랍 › 사용법 (categoryBrowseHelp)       │ 종류 · 세대 보기 읽는 법 (칸 머리 ? 는 서랍으로 옮김) │ P10    │
// │ B-24  │ LoadingView / ErrorView / EmptyView     │ 불러오는 중 · 오류 · 내 채널 없음 · 조건에 맞는 상품 없음 │ P01 · P09 │
// └──────────────────────────────────────────────────────────────────────────────────┘
// 전환: 칸 → B-23 분류 상품(쌓기) → D 상품 상세. 묶음 목록의 채널 머리 → 검색 탭 채널 바꾸기.
// 칸 그림 (CategoryTile, 반다이 남코 Collectibles 칸처럼 칸 가득): 공식 로고(lineCovers · 작품 로고 · atlas 표지)는 그 브랜드
//   바탕색 위에, 없으면 그 칸의 가장 새 상품 사진, 사진도 없으면 채널 색 위 종류 아이콘(lineIcons → cellKind). 2026-11-19 의
//   "사진 대신 아이콘" 결정은 주인이 2026-11-20 되돌렸다 (칸이 꽉 차 로고 · 사진이 섞여도 모양이 같다). 회색 칸 · 숫자 · 진행 없음.
// 틀: 왼쪽 목록 · 펴기 · 접기 · 칸 크기 = lib/widgets/side_directory.dart (도감 G 와 한 벌).
// 데이터: 종류 = Loaders.kits → lib/logic/category_browse.dart typeSections (묶음 · 칸 순서 · 빈 칸 숨김),
//   세대 = 건담 Loaders.guideWorks + guideUnits(작품 기체의 상품) · 그 밖 Loaders.worlds(World.kitIds, 베이는 라인).
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../api.dart';
import '../channels.dart';
import '../logic/category_browse.dart';
import '../logic/data_labels.dart';
import '../logic/short_names.dart';
import '../marks.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'b_category_products.dart';
import 'c_channel_screen.dart' show allChannelId;

/// 분류 칸 하나 (화면용) — 키 · 이름 · 공식 그림과 그 모양 · 로고가 없을 때의 사진 · 아이콘 종류 · 상품(새것부터)
class _Cat {
  const _Cat(this.key, this.name, this.logo, this.kind, this.kits, {this.style, this.photo = ''});
  final String key;
  final String name;

  /// 공식 로고 · 표지 ('' = 없음 → [photo], 그것도 없으면 [kind] 아이콘)
  final String logo;
  final CoverStyle? style;

  /// 칸의 가장 새 상품 사진 (로고가 없을 때 칸 가득)
  final String photo;
  final String kind;
  final List<Kit> kits;
}

/// 묶음 하나 (묶음 이름 · 칸들)
typedef _Group = (String title, List<_Cat> cats);

/// 채널 하나의 묶음들
typedef _Block = (String channel, List<_Group> groups);

/// 칸 아이콘 종류 → 테두리 아이콘 하나 (로고 · 사진이 없는 칸의 채널 색 위). 종류 이름은 Gunpula line_icons 와 같다 (category_browse cellKinds)
IconData categoryKindIcon(String kind) => switch (kind) {
  'goods' => Icons.shopping_bag_outlined,
  'plush' => Icons.cruelty_free_outlined,
  'figure' => Icons.accessibility_new_outlined,
  'prize' => Icons.emoji_events_outlined,
  'game' => Icons.sports_esports_outlined,
  'hardware' => Icons.devices_outlined,
  'card' => Icons.style_outlined,
  'apparel' => Icons.checkroom_outlined,
  'food' => Icons.cookie_outlined,
  'capsule' => Icons.egg_outlined,
  'plamo' => Icons.extension_outlined,
  _ => Icons.category_outlined,
};

/// B-20 종류 — 채널 상품을 라인 · 종류 칸으로, 칸은 묶음(프라모델 · SD · 완성품 …)마다
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

  /// '전체'일 때 묶음 목록의 채널 머리를 누르면 (없으면 머리를 못 누른다)
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

  /// 고른 묶음 '채널/묶음 이름' — 없거나 필터로 사라졌으면 첫 묶음
  String _pick = '';

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

  /// B-20 종류 묶음 — 그림 = 공식 라인 로고(lineCovers), 없으면 가장 새 상품 사진(TypeEntry.cover), 그것도 없으면 종류 아이콘
  /// (Gunpula line_icons → 칸 키 → 상품 유형)
  List<_Group> _typeSections(String channel, List<Kit> kits) => [
    for (final s in typeSections(channel, kits))
      (
        s.title,
        [
          for (final e in s.entries)
            _Cat(
              e.key,
              e.label,
              lineCovers[channel]?[e.key] ?? '',
              cellKind(e.key, e.kits, listed: lineIcons[channel]?[e.key]),
              e.kits,
              style: lineCoverStyles[channel]?[e.key],
              photo: e.cover,
            ),
        ],
      ),
  ];

  /// B-21 세대 묶음 — 상품이 없는 칸은 숨긴다
  Future<List<_Group>> _eraSections(String channel, List<Kit> kits) async {
    final byId = {for (final k in kits) k.id: k};
    // 한국 짝이 있는 일본 상품은 목록에 없다 → 묶음이 일본 쪽 id 만 가져도 한국 쪽 카드로 (한 카드만)
    final byTwin = {
      for (final k in kits)
        if (k.twinId.isNotEmpty) k.twinId: k,
    };
    List<Kit> resolve(Iterable<String> ids) =>
        {for (final id in ids) ?(byId[id] ?? byTwin[id])}.toList()..sort(newestFirst);

    if (channel == 'gundam') {
      // 작품 = 그 작품 기체들에 연결된 상품. 그림 = 공식 작품 로고 (GuideWork.image 는 로고만)
      final works = await widget.loaders.guideWorks(); // STATE: 건담 작품 목록
      final units = await Future.wait([
        for (final w in works) widget.loaders.guideUnits(w.id).catchError((Object _) => const <GuideUnit>[]),
      ]);
      final cats = <GuideWork, _Cat>{};
      for (final (i, w) in works.indexed) {
        final list = resolve([for (final u in units[i]) ...u.kitIds]);
        if (list.isNotEmpty) {
          cats[w] = _Cat(
            w.id,
            dataLabel(shortWorkName(w.name)),
            w.image,
            cellKind('', list),
            list,
            photo: newestCover(list),
          );
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
      final name = dataLabel(shortWorldLabel(channel, w.id, w.label));
      // 베이 라인 · 작품이 없는 채널(이펙트)은 공식 라인 로고, 그 밖은 atlas 공식 표지 (로고 · 키 비주얼).
      // 묶음 그림이 「가장 새 상품 사진」이면 로고 자리가 아니라 사진 자리로 — 칸의 상품에서 다시 고른다
      final covers = lineCovers[channel] ?? const <String, String>{};
      final styles = lineCoverStyles[channel] ?? const <String, CoverStyle>{};
      final lineKey = channel == 'beyblade' && isBeyLineWorld(w.id)
          ? w.id.replaceFirst('beyblade-', '').toUpperCase()
          : noWorkChannels.contains(channel)
          // 로고 표 키는 라인 값 (묶음 id 뒤쪽) — 보이는 이름은 dataLabel 로 바뀌어 맞지 않는다
          ? (covers.containsKey(w.id.substring(channel.length + 1)) ? w.id.substring(channel.length + 1) : w.label)
          : null;
      final atlas = lineKey == null && isAtlasCover(w.image);
      cats.add(
        _Cat(
          w.id,
          name,
          lineKey != null ? (covers[lineKey] ?? '') : (atlas ? w.image : ''),
          cellKind('', list),
          list,
          style: lineKey != null ? styles[lineKey] : (atlas ? w.cover : null),
          photo: newestCover(list),
        ),
      );
    }
    return worldSections(channel, cats, (c) => c.key);
  }

  void _open(String channel, _Cat c, KitFilter? f) => openCategoryProducts(
    context,
    title: c.name,
    image: c.logo,
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
        detail: tr('채널 관리에서 채널을 추가하면 둘러볼 수 있어요'),
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
        final blocks = <_Block>[
          for (final (ch, groups) in snap.data!)
            if ([
                  for (final (title, cats) in groups)
                    if (cats.where(hit).toList() case final shown when shown.isNotEmpty) (title, shown),
                ]
                case final kept when kept.isNotEmpty)
              (ch, kept),
        ];
        if (blocks.isEmpty) {
          return f != null
              ? EmptyView(icon: Icons.search_off, message: tr('이 조건의 상품이 없어요')) // B-24
              : EmptyView(
                  icon: Icons.auto_awesome_mosaic_outlined,
                  message: _all
                      ? tr('아직 상품이 없어요')
                      : trf('{channel} 상품이 아직 없어요', {'channel': tr(channelOf(widget.channel).label)}),
                );
        }
        final groups = [
          for (final (ch, gs) in blocks)
            for (final (title, cats) in gs) (ch, title, cats),
        ];
        final cur = groups.firstWhere((g) => '${g.$1}/${g.$2}' == _pick, orElse: () => groups.first);
        return SideDirectory(
          // B-20c 펴 둔 상태는 기기에 기억 (종류 · 세대 같이, 도감은 따로)
          initialOpen: Marks.maybeRead(context)?.store.browseDirOpen ?? true,
          onOpenChanged: (open) => Marks.maybeRead(context)?.store.setBrowseDirOpen(open),
          rows: _directory(blocks, cur),
          pane: (context, pane) => _cells(pane, cur, f),
        );
      },
    );
  }

  /// B-20 · B-21 왼쪽 묶음 목록 ('전체'면 채널 머리 아래 그 채널 묶음)
  List<Widget> _directory(List<_Block> blocks, (String, String, List<_Cat>) cur) => [
    for (final (ch, groups) in blocks) ...[
      if (_all)
        SideDirHead(
          // B-20a
          key: ValueKey('dir-ch-$ch'),
          label: tr(channelOf(ch).label),
          onTap: widget.onPickChannel == null ? null : () => widget.onPickChannel!(ch), // STATE: 채널 고르기
        ),
      for (final (title, _) in groups)
        SideDirItem(
          key: ValueKey('dir-$ch-$title'),
          label: tr(title),
          selected: cur.$1 == ch && cur.$2 == title,
          onTap: () => setState(() => _pick = '$ch/$title'), // STATE: 묶음 → 오른쪽 칸
        ),
    ],
  ];

  /// 고른 묶음의 칸 — 머리(손잡이 · 묶음 이름) + 격자. 펴면 3칸, 접으면 4칸 (폰)
  Widget _cells(SidePane pane, (String, String, List<_Cat>) cur, KitFilter? f) {
    final (ch, title, cats) = cur;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        pane.head(_all ? '${tr(channelOf(ch).label)} · ${tr(title)}' : tr(title)),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              final g = SideGrid.of(context, box.maxWidth, open: pane.open);
              return CustomScrollView(
                // 묶음을 바꾸면 맨 위부터
                key: ValueKey('cells-$ch/$title'),
                slivers: [
                  g.sliver(cats.length, (context, i) {
                    final c = cats[i];
                    return CategoryTile(
                      // B-20 · B-21 공식 로고(없으면 가장 새 상품 사진 · 채널 색 위 종류 아이콘) + 이름만
                      key: ValueKey('cat-$ch-${c.key}'),
                      image: c.logo,
                      style: c.style,
                      photo: c.photo,
                      color: Gp.channelColor(ch),
                      icon: categoryKindIcon(c.kind),
                      name: c.name,
                      onTap: () => _open(ch, c, f),
                    );
                  }),
                  SliverToBoxAdapter(child: SizedBox(height: navClearance(context))),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// B-22 사용법의 종류 · 세대 묶음 — 묶음 목록 · 칸 · 필터
List<HelpItem> categoryBrowseHelp({required bool era}) => [
  HelpItem(Icons.menu_open, tr('왼쪽 묶음을 누르면 그 묶음의 칸만 · 밀어서 펴고 접기')),
  if (era) ...[
    HelpItem(Icons.auto_awesome_mosaic_outlined, tr('건담 = 시대별 작품 (공식 작품 로고)')),
    HelpItem(Icons.layers_outlined, tr('포켓몬 세대 · Fate 작품 · 아머드 코어 작품 · 베이 라인 · 레고 테마')),
  ] else ...[
    HelpItem(Icons.category_outlined, tr('공식 라인 · 상품 종류마다 한 칸 (그림 = 공식 로고, 없으면 가장 새 상품 사진)')),
    HelpItem(Icons.more_horiz, trf('{other} = 상품 {n}개가 안 되는 굿즈 종류', {'other': tr(lineOtherKey), 'n': lineMinGroup})),
  ],
  HelpItem(Icons.tune, tr('필터를 고르면 맞는 상품이 있는 칸만 · 연 화면도 그 필터로')),
  HelpItem(Icons.chevron_right, tr('칸을 누르면 그 상품 전부')),
];
