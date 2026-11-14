// G-4 작품 하나의 기체 칸 · G-5 기체 시트 (상품 · 손으로 켜기 · 내 사진)
import 'package:flutter/material.dart';

import '../../api.dart';
import '../../data/gundam_atlas.dart' show episodesLabel, roleLabels;
import '../../l10n/l10n.dart';
import '../../level.dart';
import '../../logic/short_names.dart' show shortWorkName;
import '../../logic/collection_rules.dart' show bestStatus;
import '../../marks.dart';
import '../../models.dart';
import '../../report.dart';
import '../../theme.dart';
import '../../widgets.dart';
import '../d_kit_detail_screen.dart';
import '../t_photo_screen.dart' show addMyPhoto, deleteMyPhoto;
import '../v_share_sheet.dart' show openGuideShare;
import 'guide_parts.dart';

/// G-4 작품 하나의 기체 칸
class WorkGuideScreen extends StatefulWidget {
  const WorkGuideScreen({
    super.key,
    required this.work,
    required this.loaders,
    this.initialQuery = '',
    this.initialFilter,
    this.focusUnit,
  });
  final GuideWork work;
  final Loaders loaders;

  /// 열자마자 이 기체의 시트 (도감 탭 검색의 기체 줄 · 상품 상세 "도감에서 보기")
  final String? focusUnit;

  /// 작품 도감에서 찾던 말 · 도감 필터(시대 빼고)를 이어받는다
  final String initialQuery;
  final GuideFilter? initialFilter;

  @override
  State<WorkGuideScreen> createState() => _WorkGuideScreenState();
}

class _WorkGuideScreenState extends State<WorkGuideScreen> {
  late Future<List<GuideUnit>> _future = _load();
  List<GuideUnit> _units = const [];

  /// 이 작품 기체들의 상품 — 칸 단계 · ♡ · 리본을 바로 바꾸려고 한 번에 받아 둔다
  Map<String, Kit> _kits = const {};

  /// G-9 이 작품 안에서 찾기 · 도감 필터
  late String _query = widget.initialQuery;
  late GuideFilter _filter = widget.initialFilter?.copy() ?? GuideFilter();

  /// G-4c 화수 · 장 묶음 (gundam-chapters.json 이 없으면 비어 있고 보기 단추도 없다)
  List<GuideChapter> _chapters = const [];

  /// true = 화수별 보기, false = 한 격자
  bool _byChapter = false;

  /// 기체 id → 내 사진 (AppImage 경로 `local:파일`). UserStore 의 내 사진에서 — 기체 칸 · 사진 벽이 같은 사진
  final Map<String, String> _photos = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _photos
      ..clear()
      ..addAll({
        for (final p in Marks.of(context).store.photos.reversed) // 새것이 이기도록 오래된 것부터
          if (p.unitId.isNotEmpty) p.unitId: '$localPhotoPrefix${p.file}',
      });
  }

  Future<List<GuideUnit>> _load() async {
    // STATE: 작품의 기체 → 칸, 칸마다 상품
    final units = await widget.loaders.guideUnits(widget.work.id);
    final ids = {for (final u in units) ...u.kitIds}.toList();
    var kits = <String, Kit>{};
    if (ids.isNotEmpty) {
      try {
        kits = {for (final k in await widget.loaders.kitsByIds(ids)) k.id: k};
      } on Object {
        // 상품을 못 받아도 칸은 보인다 (불러온 때 상태로)
      }
    }
    var chapters = const <GuideChapter>[];
    try {
      chapters = await widget.loaders.guideChapters(widget.work.id); // STATE: 작품의 장(챕터)
    } on Object {
      // 화수 데이터가 없으면(404) 화수별 보기만 숨긴다
    }
    _units = units;
    _kits = kits;
    _chapters = chapters;
    if (units.where((u) => u.id == widget.focusUnit).firstOrNull case final u?) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openUnit(u); // 칸들이 그려진 뒤 그 기체 시트
      });
    }
    return units;
  }

  List<Kit> _kitsOf(GuideUnit u, {bool litOnly = false}) => [
    for (final id in litOnly ? u.litKitIds : u.kitIds) ?_kits[id],
  ];

  /// 기체 칸 → 도감 필터 재료 (상태 · 상품 라인 · 기체 종류 · 상품 수 · 최근 구매)
  GuideFacet _facet(Marks m, GuideUnit u) {
    final tier = _tierOf(m, u);
    final kits = _kitsOf(u, litOnly: true);
    var bought = '';
    for (final k in kits) {
      if (!m.owned(k)) continue;
      final at = m.store.entry(k.id)?['updated_at'];
      if (at is String && at.compareTo(bought) > 0) bought = at;
    }
    return GuideFacet(
      name: u.name,
      tiers: {
        switch (tier) {
          CellTier.none => GuideTier.none,
          CellTier.liked => GuideTier.liked,
          CellTier.owned => GuideTier.owned,
          CellTier.photo => GuideTier.photo,
        },
        if (tier == CellTier.photo) GuideTier.owned, // 사진 인증 칸도 구매함으로 찾힌다
      },
      grades: {
        for (final k in kits)
          if (k.line.isNotEmpty) k.line,
      },
      types: {if (u.type.isNotEmpty) u.type},
      kits: u.litKitIds.length,
      boughtAt: bought,
    );
  }

  bool _manual(Marks m, GuideUnit u) => u.ggetIds.any(m.store.guideManualLit.contains);

  /// 칸 단계: 내 사진 > 구매함(상품 · 손으로 켜기) > 좋아요 > 없음 — 내 기록에서 바로 센다
  CellTier _tierOf(Marks m, GuideUnit u) {
    if (_photos.containsKey(u.id)) return CellTier.photo;
    final kits = _kitsOf(u, litOnly: true);
    final s = kits.isNotEmpty
        ? bestStatus(kits.map(m.statusOf))
        : (u.ggetIds.isEmpty ? u.status : CollectStatus.none); // 상품을 못 받았으면 불러온 때 상태
    if (s == CollectStatus.owned || _manual(m, u)) return CellTier.owned;
    return s == CollectStatus.wanted ? CellTier.liked : CellTier.none;
  }

  /// 손으로 켜기 (상품이 없는 기체 · 옛 Gunpula 기록과 같은 gget id 로 기기에 저장)
  void _setManual(GuideUnit u, bool on) {
    if (u.ggetIds.isEmpty) return;
    final store = Marks.read(context).store;
    void apply(bool v) {
      if (v) {
        store.setManualLit(u.ggetIds.first, true);
      } else {
        for (final g in u.ggetIds) {
          store.setManualLit(g, false);
        }
      }
    }

    apply(on); // STATE: 손으로 켜기 → 칸 단계 (Marks 가 다시 그린다)
    if (!on) setState(() => _photos.remove(u.id)); // 안 가진 기체에 인증 사진은 남기지 않는다
    showToast(context, on ? trf('「{name}」 칸을 켰어요', {'name': u.name}) : tr('손으로 켠 칸을 껐어요'), onUndo: () => apply(!on));
  }

  /// G-4b 칸의 리본: 손으로 켠 칸이면 끄기 · 상품이 하나면 그 상품 · 없으면 손으로 켜기 · 여럿이면 시트
  void _own(GuideUnit u) {
    final m = Marks.read(context);
    final kits = _kitsOf(u, litOnly: true);
    if (_manual(m, u)) return _setManual(u, false);
    if (kits.length == 1) {
      if (m.owned(kits.first)) setState(() => _photos.remove(u.id));
      return m.toggleOwn(context, kits.first);
    }
    if (kits.isEmpty && u.ggetIds.isNotEmpty) return _setManual(u, true);
    _openUnit(u);
  }

  /// G-4b 칸의 ♡: 상품이 하나면 그 상품, 아니면 시트에서 고른다
  void _like(GuideUnit u) {
    final kits = _kitsOf(u, litOnly: true);
    if (kits.length == 1) return Marks.read(context).toggleLike(context, kits.first);
    _openUnit(u);
  }

  /// 사진 내리기 — 이 기체에 붙인 내 사진을 지운다 (사진 벽에서도)
  void _removePhoto(GuideUnit u) {
    for (final p in Marks.read(context).store.photos.where((p) => p.unitId == u.id)) {
      deleteMyPhoto(context, p).ignore();
    }
    showToast(context, trf('「{name}」의 내 사진을 내렸어요', {'name': u.name}));
  }

  /// G-5c 내 사진 올리기: 카메라 · 갤러리 → 기기에 저장 (사진 벽 · 칸이 같이 바뀐다). 사진이 있으면 가진 것
  Future<void> _uploadPhoto(GuideUnit u) async {
    final store = Marks.read(context).store;
    final kit = [
      for (final id in u.kitIds)
        if (store.statusOf(id) == CollectStatus.owned) id,
    ].firstOrNull;
    final p = await addMyPhoto(context, unitId: u.id, kitId: kit ?? u.kitIds.firstOrNull ?? '');
    if (p == null || !mounted) return;
    setState(() {}); // STATE: 내 사진 → 도는 고리
    showToast(context, trf('「{name}」 내 사진', {'name': u.name}));
  }

  /// G-4d 작품 진행 카드 — 칸을 다 받은 뒤 지금 단계로
  Future<void> _shareGuide() async {
    final units = await _future.catchError((Object _) => const <GuideUnit>[]);
    if (!mounted || units.isEmpty) return;
    final m = Marks.read(context);
    await openGuideShare(context, work: widget.work, tiers: [for (final u in units) _tierOf(m, u)]);
  }

  void _openUnit(GuideUnit u) {
    showGpSheet<void>(
      // G-5 덮기
      context,
      tall: true,
      builder: (sheet) => _UnitSheet(
        unit: u,
        kits: _kitsOf(u),
        tierOf: (m) => _tierOf(m, u),
        photo: _photos[u.id],
        onManual: (on) => _setManual(u, on),
        onPhoto: () {
          Navigator.pop(sheet);
          _uploadPhoto(u);
        },
        onRemovePhoto: () {
          Navigator.pop(sheet);
          _removePhoto(u);
        },
        loaders: widget.loaders,
      ),
    );
  }

  Widget _grid(BoxConstraints box, Marks m, List<GuideUnit> units) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: Gp.gutter),
    child: GridView.count(
      crossAxisCount: guideCols(box.maxWidth, 110),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.72,
      children: [
        for (final u in units)
          GuideCell(
            // G-4 P01
            key: ValueKey(u.id),
            image: u.image,
            name: u.name,
            tier: _tierOf(m, u),
            photo: _photos[u.id],
            liked: _kitsOf(u, litOnly: true).any(m.liked),
            onTap: () => _openUnit(u),
            onLike: () => _like(u), // G-4b
            onOwn: () => _own(u),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final w = widget.work;
    final m = Marks.of(context); // 좋아요 · 구매함 · 손으로 켜기가 바뀌면 칸이 바로 바뀐다
    final ownedNow = _units.isEmpty ? w.owned : _units.where((u) => _tierOf(m, u).index >= CellTier.owned.index).length;
    return Scaffold(
      appBar: AppBar(
        title: BarTitle(
          shortWorkName(w.name),
          count: trf('수집 {owned} / {total}', {'owned': ownedNow, 'total': w.total}),
        ),
        actions: [
          ToolIcon(
            // G-4d 작품 진행 카드 (그림으로 공유 · 저장)
            key: const ValueKey('guide-share'),
            icon: Icons.ios_share,
            tip: tr('공유 카드'),
            onTap: _shareGuide,
          ),
          HelpButton(title: tr('작품 도감'), items: workGuideHelp()), // G-2
          const SizedBox(width: 6),
        ],
      ),
      body: FutureBuilder<List<GuideUnit>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingView();
          if (snap.hasError) {
            return ErrorView(message: '${snap.error}', onRetry: () => setState(() => _future = _load()));
          }
          final all = snap.data!;
          if (all.isEmpty) {
            return EmptyView(
              // G-8 P09 · 정리 요청 = Gunpula 데이터 저장소에 이슈 (lib/report.dart)
              icon: Icons.grid_view,
              message: tr('이 작품은 아직 기체 정리가 안 됐어요'),
              action: OutlinedButton(
                onPressed: () => reportDataIssue(context, unitName: widget.work.name, kind: ReportKind.guide),
                child: Text(tr('정리 요청')),
              ),
            );
          }
          // G-9 이름 · 형식번호로 찾기 + 도감 필터
          final found = [
            for (final u in all)
              if (_query.isEmpty || '${u.name} ${u.nameEn} ${u.keywords}'.toLowerCase().contains(_query.toLowerCase()))
                u,
          ];
          final pool = [for (final u in found) _facet(m, u)];
          final units = _filter.apply(found, (u) => _facet(m, u));
          final byId = {for (final u in units) u.id: u};
          final chapterView = _byChapter && _chapters.isNotEmpty;
          return LayoutBuilder(
            builder: (context, box) => ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                LiveLevelBar(loaders: widget.loaders), // G-4a 수집 레벨 (아바타 옆 Lv 와 같은 막대)
                FindBar(
                  // G-9
                  hint: trf('{name}에서 찾기', {'name': shortWorkName(widget.work.name)}),
                  initial: widget.initialQuery,
                  onQuery: (q) => setState(() => _query = q), // STATE: 찾기 → 칸 거르기
                  filterCount: _filter.count,
                  onFilter: () async {
                    final f = await showGuideFilterSheet(context, pool: pool, initial: _filter, groupLabel: tr('묶음'));
                    if (f != null) setState(() => _filter = f); // STATE: 도감 필터 → 칸 거르기 · 정렬
                  },
                  tools: [
                    if (_chapters.isNotEmpty)
                      ViewIconToggle(
                        // G-4c
                        mine: _byChapter,
                        onChanged: (v) => setState(() => _byChapter = v), // STATE: 한 격자 ↔ 화수별
                        allIcon: Icons.grid_view_outlined,
                        mineIcon: Icons.format_list_numbered,
                        allTip: tr('한 격자'),
                        mineTip: tr('화수별'),
                      ),
                  ],
                ),
                if (units.isEmpty) guideNoHit,
                if (!chapterView)
                  _grid(box, m, units)
                else
                  // G-4c 화수 · 장마다 그때 나온 기체 (한 기체가 여러 장에 나올 수 있다)
                  for (final c in _chapters)
                    if ([for (final id in c.unitIds) ?byId[id]] case final list when list.isNotEmpty) ...[
                      SectionHeader(
                        joinDot([episodesLabel(c.episodes), c.name]),
                        padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                      ),
                      _grid(box, m, list),
                    ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// G-5 기체 시트: 칸 단계 · 손으로 켜기 · 내 사진 + 이 기체의 상품 전부(등급 · 사진 · ♡ · 구매함)
class _UnitSheet extends StatelessWidget {
  const _UnitSheet({
    required this.unit,
    required this.kits,
    required this.tierOf,
    required this.photo,
    required this.onManual,
    required this.onPhoto,
    required this.onRemovePhoto,
    required this.loaders,
  });
  final GuideUnit unit;

  /// 연결된 상품 (그 기체 → 세트 → 완성품 → 부품 · SD 순)
  final List<Kit> kits;

  /// 내 기록으로 지금 칸 단계 (시트 안에서 ♡ · 리본을 누르면 바로 바뀐다)
  final CellTier Function(Marks m) tierOf;
  final String? photo;
  final ValueChanged<bool> onManual;
  final VoidCallback onPhoto;
  final VoidCallback onRemovePhoto;
  final Loaders loaders;

  @override
  Widget build(BuildContext context) {
    final m = Marks.of(context);
    final tier = tierOf(m);
    final manual = unit.ggetIds.any(m.store.guideManualLit.contains);
    final status = switch (tier) {
      CellTier.photo => tr('구매함 · 내 사진으로 인증됨'),
      CellTier.owned => manual ? tr('구매함 · 손으로 켬') : tr('구매함'),
      CellTier.liked => tr('좋아요'),
      CellTier.none => tr('아직 없음'),
    };
    final lit = [
      for (final k in kits)
        if (unit.litKitIds.contains(k.id)) k,
    ];
    final related = [
      for (final k in kits)
        if (!unit.litKitIds.contains(k.id)) k,
    ];
    Widget kitRow(Kit k) => _KitLine(
      kit: k,
      role: unit.roleOf(k.id),
      onTap: () {
        Navigator.pop(context);
        openKitDetail(context, k, loaders: loaders, list: kits); // D 상품 상세 (이 기체 상품끼리 좌우로 넘김)
      },
    );
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: kits.length > 3 ? 0.7 : 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.92,
      builder: (context, scroll) => SafeArea(
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Row(
              children: [
                SizedBox.square(
                  dimension: 64,
                  child: tierFrame(tier, cellImage(tier, unit.image, photo), radius: Gp.radius),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        unit.name,
                        style: const TextStyle(fontSize: Gp.t16, fontWeight: FontWeight.w600),
                      ),
                      if (unit.nameEn.isNotEmpty)
                        Text(
                          unit.nameEn,
                          style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
                        ),
                      Text(
                        status,
                        style: TextStyle(
                          fontSize: Gp.t12,
                          color: switch (tier) {
                            CellTier.none => Gp.faint,
                            CellTier.liked => Gp.accent,
                            _ => Gp.own,
                          },
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // G-5b 손으로 켜기(상품 없이 · gget 기체만) · 내 사진
            Row(
              children: [
                if (unit.ggetIds.isNotEmpty) ...[
                  Expanded(
                    child: TogglePill(
                      label: tr('손으로 켜기'),
                      icon: Icons.bookmark_add_outlined,
                      activeIcon: Icons.bookmark_added,
                      color: Gp.own,
                      active: manual,
                      onTap: () => onManual(!manual), // STATE: 손으로 켜기 (기기에 저장)
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: TogglePill(
                    label: tr('내 사진'),
                    icon: Icons.add_a_photo_outlined,
                    activeIcon: Icons.workspace_premium,
                    color: Gp.own,
                    active: photo != null,
                    onTap: onPhoto, // G-5c
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    photo == null ? '' : tr('다시 누르면 사진 바꾸기'),
                    style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
                  ),
                ),
                if (photo != null)
                  TextButton(
                    onPressed: onRemovePhoto,
                    style: TextButton.styleFrom(foregroundColor: Gp.muted, visualDensity: VisualDensity.compact),
                    child: Text(tr('사진 내리기')),
                  ),
              ],
            ),
            SectionHeader(
              tr('이 기체의 상품'), // 상품 개수는 쓰지 않는다 (docs/terms.md 분류 상품 개수)
              padding: const EdgeInsets.fromLTRB(0, 14, 0, 4),
              // G-5d 빠진 상품 제보 → Gunpula 이슈 (lib/report.dart)
              trailing: ToolIcon(
                icon: Icons.flag_outlined,
                tip: tr('빠진 상품 제보'),
                onTap: () => reportDataIssue(context, unitName: unit.name, kind: ReportKind.missingKit),
              ),
            ),
            if (lit.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  tr('대응 상품 아직 없음 · 나오면 홈에 먼저 떠요'), // P09
                  style: const TextStyle(color: Gp.muted),
                ),
              ),
            for (final k in lit) kitRow(k),
            if (related.isNotEmpty) ...[
              SectionHeader(
                tr('관련 상품'),
                subtitle: tr('부품 · SD 캐릭터 — 칸은 켜지지 않아요'),
                padding: const EdgeInsets.fromLTRB(0, 14, 0, 4),
              ),
              for (final k in related) kitRow(k),
            ],
          ],
        ),
      ),
    );
  }
}

/// G-5a 기체 시트의 상품 한 줄: 사진 · 이름 · 등급 줄 · ♡ · 구매함
class _KitLine extends StatelessWidget {
  const _KitLine({required this.kit, required this.role, required this.onTap});
  final Kit kit;
  final String role;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ThumbRow(
      image: kit.image,
      title: kit.name,
      tag: tr(roleLabels[role] ?? ''),
      subtitle: joinDot([tr(kit.line), kit.scale, if (kit.date.length >= 7) dateDot(kit.date.substring(0, 7))]),
      size: 52,
      padding: const EdgeInsets.symmetric(vertical: 6),
      onTap: onTap,
      trailing: KitMarkButtons(kit: kit),
    );
  }
}

/// G-2 작품 도감 ? — 칸 표시(레벨 시트와 같은 그림, 늘 컬러) + 찾기 줄 · 기체 시트 아이콘
List<HelpItem> workGuideHelp() => [
  ...tierHelpItems(),
  HelpItem.group(tr('아이콘')),
  HelpItem(Icons.ios_share, tr('공유 카드 (그림으로 공유 · 저장)')),
  HelpItem(Icons.tune, tr('도감 필터')),
  HelpItem(Icons.grid_view_outlined, tr('한 격자')),
  HelpItem(Icons.format_list_numbered, tr('화수별')),
  HelpItem(Icons.bookmark_add_outlined, tr('손으로 켜기 (상품 없이)'), color: Gp.own),
  HelpItem(Icons.add_a_photo_outlined, tr('내 사진 (사진 인증)'), color: Gp.own),
  HelpItem(Icons.flag_outlined, tr('빠진 상품 제보')),
];
