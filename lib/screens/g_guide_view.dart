// 화면 G: 도감 — 컬렉션의 다른 보기. 모은 만큼 칸에 불이 켜진다.
//
// ┌──────── 디자인 가이드 대응표: G 도감 ──────────────────────────────────────────────┐
// │ 번호 │ Flutter 위젯명                     │ 비즈니스 명칭(한글)                    │ 원칙(P번호)   │
// │ G-1  │ 채널 타일 격자                      │ '전체'일 때: 도감을 볼 IP 고르기         │ P06           │
// │ G-2  │ ? 버튼 → 바텀 시트                 │ 도감 읽는 법 (긴 범례 줄 대신)           │ P10 · P08     │
// │ G-3  │ 시대 섹션 + 작품 카드 + 진행 막대     │ 건담 작품 도감 (Atlas 시대 → 작품, 수집 n/전체) │ P01 · P06 │
// │ G-4  │ 기체 칸 격자 (4단계)                 │ 흑백 → ♡ 컬러 → 리본 컬러·초록 테두리 → 내 사진·도는 고리 │ P01 · P04 │
// │ G-4a │ Lv 막대 (좋아요 1 · 구매 2 · 사진 3점) │ 하나 더할 때마다 오르는 작품 레벨        │ P01           │
// │ G-4b │ 칸 위 MarkOverlay (리본 · ♡)          │ 상품 하나면 그 상품 · 없으면 손으로 켜기 · 여럿이면 시트 │ P07 · P04 │
// │ G-4c │ ViewIconToggle + 장마다 SectionHeader · 칸 격자 │ 화수별 보기 (gundam-chapters 가 있을 때만) │ P01 · P07 │
// │ G-5  │ 바텀 시트(끌어 올리기): 기체 → 상품    │ 이 기체의 상품 전부 → 상품 상세          │ P07           │
// │ G-5a │ ThumbRow + ♡ · 책갈피 아이콘          │ 상품 줄: 등급 · 축척 · 발매월 · 바로 좋아요 · 구매함 │ P07 · P04 │
// │ G-5b │ 시트의 TogglePill 2개                │ 손으로 켜기(기기 저장) · 내 사진          │ P03 · P07     │
// │ G-5c │ 바텀 시트(카메라 · 갤러리) (T-2)      │ 이 기체의 내 사진 → 사진 벽에도 (기기 저장) │ P05 · P07   │
// │ G-6  │ 베이 칸 + n/3 · 부품 시트            │ 베이블레이드 X 도감 (부품 3개)          │ P01           │
// │ G-6a │ 🔧 ToolIcon (베이 머리줄)            │ 조합 만들기 (화면 T) — 블레이드 · 래칫 · 비트 · 덱 │ P07     │
// │ G-7  │ 세대 · 작품 카드 + 진행 막대          │ 포켓몬 세대 · Fate 작품 · AC 세대       │ P01           │
// │ G-7b │ TagGameCards (포켓몬 세대 위)         │ MEZASTAR · Frienda 태그 도감 입구 (R)   │ P06           │
// │ G-7a │ SectionListView (쌓기)              │ 묶음 카드 → 그 묶음 상품 (찾기 · 필터 · 격자/목록) │ P07 │
// │ G-8  │ LoadingView / ErrorView / EmptyView │ 불러오는 중 · 오류 · 정리 안 된 작품(정리 요청) │ P01 · P09 │
// │ G-5d │ 기체 시트 ⚑                          │ 빠진 상품 제보 (GitHub 이슈)             │ P07           │
// │ G-9  │ FindBar + GuideFilterSheet(60% 시트) │ 도감에서 찾기(작품 · 기체 이름 · 형식번호) + 도감 필터: 단계(아직 · ♡ · 구매함 · 내 사진) · 상품 있는 것만 · 등급 · 종류 · 시대 · 정렬 │ P04 · P07 · P01 │
// └──────────────────────────────────────────────────────────────────────────────────┘
// 전환: 🔧 → T 베이 조합 만들기(쌓기). 작품 카드 → 작품 도감(쌓기) → 기체 시트(덮기) → D 상품 상세(쌓기, 이 기체 상품끼리 좌우). 베이 → 부품 시트(덮기).
//       기체 시트 → 사진 고르기(덮기, T-2) → 토스트.
// 데이터: lib/data/derive.dart 건담 도감 ← lib/data/gundam_atlas.dart (data/atlas/gundam-ms · gundam-kit-ms · gundam-chapters).
//       작품 · 시대 카드 그림 = 공식 작품 로고 (주소 · 출처는 데이터 쪽 GundamAtlas 가 정한다).
import 'package:flutter/material.dart';

import '../api.dart';
import '../detail_pane.dart';
import '../report.dart';
import '../level.dart';
import '../marks.dart';
import '../channels.dart';
import '../data/gundam_atlas.dart' show roleLabels;
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'c_channel_screen.dart';
import 'd_kit_detail_screen.dart';
import 't_bbx_builder_screen.dart';
import 'r_mezastar_screen.dart' show TagGameCards;
import 'o_see_all_screen.dart' show SectionListView;
import 't_photo_screen.dart' show addMyPhoto, deleteMyPhoto;

class GuideView extends StatelessWidget {
  const GuideView({
    super.key,
    required this.channel,
    required this.myChannels,
    required this.onPickChannel,
    required this.loaders,
    this.query = '',
    this.filter,
  });

  final String channel;
  final List<String> myChannels;
  final ValueChanged<String> onPickChannel;
  final Loaders loaders;

  /// G-9 찾기 (컬렉션의 FindBar 글자)
  final String query;

  /// G-9 도감 필터 — 컬렉션의 필터 아이콘이 이 조건을 바꾸고, 도감은 지금 칸들을 [GuideFilterController.pool] 에 채운다
  final GuideFilterController? filter;

  @override
  Widget build(BuildContext context) {
    if (channel == allChannelId) return _ChannelPicker(myChannels: myChannels, onPick: onPickChannel);
    final ctrl = filter ?? GuideFilterController();
    return ListenableBuilder(
      listenable: ctrl,
      builder: (context, _) {
        final find = _Find(query, ctrl);
        return switch (channel) {
          'gundam' => _GundamGuide(loaders: loaders, find: find),
          'beyblade' => _BbxGuide(loaders: loaders, find: find),
          _ => _WorldGuide(channel: channel, loaders: loaders, find: find),
        };
      },
    );
  }
}

/// G-9 찾기 글자 + 도감 필터
class _Find {
  _Find(this.query, [GuideFilterController? ctrl]) : ctrl = ctrl ?? GuideFilterController();
  final String query;
  final GuideFilterController ctrl;

  GuideFilter get filter => ctrl.filter;
  bool get active => query.isNotEmpty || filter.active;
  bool hitName(String text) => query.isEmpty || text.toLowerCase().contains(query.toLowerCase());

  /// 찾기 + 필터 + 정렬. [pool] 은 필터 시트가 셀 재료로 남긴다 (찾기 글자로 거른 뒤)
  List<T> apply<T>(
    List<T> items,
    String Function(T) text,
    GuideFacet Function(T) facet, {
    String groupLabel = '묶음',
    bool photo = false,
  }) {
    final found = [
      for (final x in items)
        if (hitName(text(x))) x,
    ];
    ctrl
      ..pool = [for (final x in found) facet(x)]
      ..groupLabel = groupLabel
      ..photoTier = photo;
    return filter.apply(found, facet);
  }
}

/// 찾기 · 필터에 맞는 것이 없을 때
const _noHit = EmptyView(icon: Icons.search_off, message: '이 조건의 칸이 없어요');

/// G-1 '전체'일 때: IP 고르기
class _ChannelPicker extends StatelessWidget {
  const _ChannelPicker({required this.myChannels, required this.onPick});
  final List<String> myChannels;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    if (myChannels.isEmpty) {
      return const EmptyView(
        icon: Icons.auto_awesome_mosaic_outlined,
        message: '내 채널이 비어 있어요',
        detail: '채널 관리에서 IP를 추가하면 도감을 볼 수 있어요',
      );
    }
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, navClearance(context)),
      children: [
        const Text('어느 도감을 볼까요?', style: TextStyle(color: Gp.muted)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            for (final id in myChannels)
              GestureDetector(
                onTap: () => onPick(id), // STATE: 채널 선택 → 그 IP 도감
                child: Container(
                  decoration: Gp.raised(),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleThumb(image: channelOf(id).image, label: channelOf(id).label, size: 46),
                      const SizedBox(height: 8),
                      Text(
                        channelOf(id).label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: Gp.t12),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// 진행 막대 + "n/전체"
class _Progress extends StatelessWidget {
  const _Progress({required this.owned, required this.total});
  final int owned;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AccentBar(value: total == 0 ? 0 : owned / total, color: Gp.own),
        ),
        const SizedBox(width: 8),
        Text(
          '$owned/$total',
          style: const TextStyle(fontSize: Gp.t11, color: Gp.muted),
        ),
      ],
    );
  }
}

/// 작품 · 세대 카드 (이미지 + 이름 + 진행)
class _WorkCard extends StatelessWidget {
  const _WorkCard({
    required this.image,
    required this.name,
    required this.owned,
    required this.total,
    required this.onTap,
    this.subtitle = '',
    this.fit = BoxFit.contain,
  });

  final String image;
  final String name;
  final String subtitle;
  final int owned;
  final int total;
  final VoidCallback onTap;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Gp.panel,
          borderRadius: BorderRadius.circular(Gp.radius),
          border: Border.all(color: Gp.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(fit == BoxFit.contain ? 10 : 0),
                child: AppImage(image, fit: fit, placeholder: name),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: Gp.t12, fontWeight: FontWeight.w600),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: Gp.t11, color: Gp.faint),
                    ),
                  const SizedBox(height: 6),
                  _Progress(owned: owned, total: total), // P01
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

int _cols(double w, double min) => (w / min).floor().clamp(2, 6);

/// G-3 건담 작품 도감 (시대 묶음 → 작품 카드)
class _GundamGuide extends StatefulWidget {
  const _GundamGuide({required this.loaders, required this.find});
  final Loaders loaders;
  final _Find find;

  @override
  State<_GundamGuide> createState() => _GundamGuideState();
}

class _GundamGuideState extends State<_GundamGuide> {
  late Future<List<GuideWork>> _future = widget.loaders.guideWorks(); // STATE: GET /guideWorks

  /// 마지막으로 센 내 기록 버전 — 좋아요 · 구매함 · 손으로 켜기가 바뀌면 수집 숫자를 다시 센다
  int _seen = -1;

  void _open(GuideWork w) {
    final q = widget.find.query.toLowerCase();
    // 작품 이름이 아니라 기체 이름으로 찾은 것이면 작품 안에서도 그 말로 거른다
    final carry = q.isNotEmpty && !w.name.toLowerCase().contains(q);
    openPage(
      context,
      WorkGuideScreen(
        work: w,
        loaders: widget.loaders,
        initialQuery: carry ? widget.find.query : '',
        initialFilter: widget.find.filter.copy(keepGroups: false), // 등급 · 단계 · 정렬을 이어받는다
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = Marks.of(context).version;
    if (v != _seen) {
      // STATE: 내 기록이 바뀜 → 다시 센다 (세는 동안 앞 숫자를 그대로 보여 준다)
      if (_seen != -1) _future = widget.loaders.guideWorks();
      _seen = v;
    }
    return FutureBuilder<List<GuideWork>>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData && !snap.hasError) return const LoadingView(); // G-8
        if (snap.hasError) {
          return ErrorView(
            message: '${snap.error}',
            onRetry: () => setState(() => _future = widget.loaders.guideWorks()),
          );
        }
        if (snap.data!.isEmpty) return const EmptyView(message: '도감 작품이 아직 없어요');
        // G-9 작품 이름 · 기체 이름 · 형식번호로 찾기 + 도감 필터(단계 · 등급 · 종류 · 시대 · 정렬)
        final works = widget.find.apply(snap.data!, (w) => '${w.name} ${w.keywords}', _workFacet, groupLabel: '시대');
        if (works.isEmpty) return _noHit;
        final sections = <String, List<GuideWork>>{};
        for (final w in works) {
          (sections[w.section] ??= []).add(w);
        }
        return LayoutBuilder(
          builder: (context, box) => ListView(
            padding: EdgeInsets.only(bottom: navClearance(context)),
            children: [
              for (final e in sections.entries) ...[
                SectionHeader(
                  e.key,
                  trailing: e.key == sections.keys.first ? const LevelHelpButton() : null, // G-2
                  subtitle:
                      '수집 ${e.value.fold(0, (s, w) => s + w.owned)}'
                      ' / ${e.value.fold(0, (s, w) => s + w.total)}',
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.count(
                    crossAxisCount: _cols(box.maxWidth, 120),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.82,
                    children: [
                      for (final w in e.value)
                        _WorkCard(
                          // G-3 P06
                          image: w.image,
                          name: w.name,
                          owned: w.owned,
                          total: w.total,
                          onTap: () => _open(w),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// 작품 카드 → 도감 필터 재료 (구매가 없으면 '아직', 좋아요 · 구매가 있으면 그 단계)
GuideFacet _workFacet(GuideWork w) => GuideFacet(
  name: w.name,
  tiers: {if (w.owned == 0) GuideTier.none, if (w.liked > 0) GuideTier.liked, if (w.owned > 0) GuideTier.owned},
  grades: w.grades.toSet(),
  types: w.types.toSet(),
  group: w.section,
  kits: w.kits,
  boughtAt: w.boughtAt,
);

/// 상품 상태 여러 개 중 가장 높은 것 (구매함 > 좋아요 > 없음)
CollectStatus _bestOf(Iterable<CollectStatus> all) {
  var best = CollectStatus.none;
  for (final s in all) {
    if (s == CollectStatus.owned) return s;
    if (s == CollectStatus.wanted) best = s;
  }
  return best;
}

/// G-4 작품 하나의 기체 칸
class WorkGuideScreen extends StatefulWidget {
  const WorkGuideScreen({
    super.key,
    required this.work,
    required this.loaders,
    this.initialQuery = '',
    this.initialFilter,
  });
  final GuideWork work;
  final Loaders loaders;

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
    // STATE: GET /guideUnits?workId= → 칸, GET /kits?id= → 칸마다 상품
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
      chapters = await widget.loaders.guideChapters(widget.work.id); // STATE: GET /guideChapters?workId=
    } on Object {
      // 화수 데이터가 없으면(404) 화수별 보기만 숨긴다
    }
    _units = units;
    _kits = kits;
    _chapters = chapters;
    return units;
  }

  List<Kit> _kitsOf(GuideUnit u, {bool litOnly = false}) => [
    for (final id in litOnly ? u.litKitIds : u.kitIds) ?_kits[id],
  ];

  /// 기체 칸 → 도감 필터 재료 (단계 · 상품 등급 · 종류 · 상품 수 · 최근 구매)
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
        ? _bestOf(kits.map(m.statusOf))
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
    showToast(context, on ? '「${u.name}」 칸을 켰어요' : '손으로 켠 칸을 껐어요', onUndo: () => apply(!on));
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
    showToast(context, '「${u.name}」의 내 사진을 내렸어요');
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
    showToast(context, '「${u.name}」 내 사진');
  }

  void _openUnit(GuideUnit u) {
    showModalBottomSheet<void>(
      // G-5 덮기
      context: context,
      isScrollControlled: true,
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
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: GridView.count(
      crossAxisCount: _cols(box.maxWidth, 110),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.72,
      children: [
        for (final u in units)
          _LitCell(
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              w.name,
              style: const TextStyle(fontSize: Gp.t16, fontWeight: FontWeight.w600),
            ),
            Text(
              '수집 $ownedNow / ${w.total}',
              style: const TextStyle(fontSize: Gp.t12, color: Gp.own, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: const [LevelHelpButton(), SizedBox(width: 6)], // G-2
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
              message: '이 작품은 아직 기체 정리가 안 됐어요',
              action: OutlinedButton(
                onPressed: () => reportDataIssue(context, unitName: widget.work.name, kind: ReportKind.guide),
                child: const Text('정리 요청'),
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
                  hint: '${widget.work.name}에서 찾기',
                  initial: widget.initialQuery,
                  onQuery: (q) => setState(() => _query = q), // STATE: 찾기 → 칸 거르기
                  filterCount: _filter.count,
                  onFilter: () async {
                    final f = await showGuideFilterSheet(context, pool: pool, initial: _filter, groupLabel: '묶음');
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
                        allTip: '한 격자',
                        mineTip: '화수별',
                      ),
                  ],
                ),
                if (units.isEmpty) _noHit,
                if (!chapterView)
                  _grid(box, m, units)
                else
                  // G-4c 화수 · 장마다 그때 나온 기체 (한 기체가 여러 장에 나올 수 있다)
                  for (final c in _chapters)
                    if ([for (final id in c.unitIds) ?byId[id]] case final list when list.isNotEmpty) ...[
                      SectionHeader(
                        [c.episodes, c.name].where((x) => x.isNotEmpty).join(' · '),
                        subtitle:
                            '수집 ${list.where((u) => _tierOf(m, u).index >= CellTier.owned.index).length}'
                            ' / ${list.length}',
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

/// 도감 칸 한 개 — 단계가 오르면 톡 튀어 오른다
class _LitCell extends StatefulWidget {
  const _LitCell({
    super.key,
    required this.image,
    required this.name,
    required this.tier,
    required this.onTap,
    this.photo,
    this.badge = '',
    this.liked = false,
    this.onLike,
    this.onOwn,
  });

  final String image;
  final String name;
  final CellTier tier;
  final VoidCallback onTap;

  /// 내가 올린 사진 (있으면 칸 그림 대신 보여 준다)
  final String? photo;
  final String badge;
  final bool liked;

  /// 주면 칸 오른쪽 아래에 ♡ + 버튼
  final VoidCallback? onLike;
  final VoidCallback? onOwn;

  @override
  State<_LitCell> createState() => _LitCellState();
}

class _LitCellState extends State<_LitCell> with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
    value: 1,
  );
  late final Animation<double> _scale = _pop.drive(
    Tween(begin: 0.86, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)),
  );

  @override
  void didUpdateWidget(_LitCell old) {
    super.didUpdateWidget(old);
    if (widget.tier.index > old.tier.index) _pop.forward(from: 0); // 한 단계 올라감
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tier;
    final content = Stack(
      fit: StackFit.expand,
      children: [
        cellImage(t, widget.image, widget.photo),
        if (widget.badge.isNotEmpty) Positioned(right: 5, top: 5, child: TagPill(widget.badge, filled: true)),
        if (t == CellTier.photo)
          const Positioned(right: 4, bottom: 4, child: VerifiedBadge()) // 3점 = 배지
        else if (widget.onLike != null && widget.onOwn != null)
          Positioned.fill(
            child: MarkOverlay(
              size: 22,
              liked: widget.liked,
              owned: t.index >= CellTier.owned.index,
              onLike: widget.onLike!,
              onOwn: widget.onOwn!,
            ),
          ),
      ],
    );
    return GestureDetector(
      onTap: widget.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: ScaleTransition(scale: _scale, child: tierFrame(t, content)),
              ),
            ),
          ),
          const SizedBox(height: 5),
          SizedBox(
            height: 30,
            child: Text(
              widget.name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: Gp.t12, color: t == CellTier.none ? Gp.muted : Gp.ink, height: 1.25),
            ),
          ),
        ],
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
      CellTier.photo => '구매함 · 내 사진으로 인증됨',
      CellTier.owned => manual ? '구매함 · 손으로 켬' : '구매함',
      CellTier.liked => '좋아요',
      CellTier.none => '아직 없음',
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
                      label: '손으로 켜기',
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
                    label: '내 사진',
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
                    photo == null ? '' : '다시 누르면 사진 바꾸기',
                    style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
                  ),
                ),
                if (photo != null)
                  TextButton(
                    onPressed: onRemovePhoto,
                    style: TextButton.styleFrom(foregroundColor: Gp.muted, visualDensity: VisualDensity.compact),
                    child: const Text('사진 내리기'),
                  ),
              ],
            ),
            SectionHeader(
              '이 기체의 상품',
              subtitle: lit.isEmpty ? '' : '${lit.length}개',
              padding: const EdgeInsets.fromLTRB(0, 14, 0, 4),
              // G-5d 빠진 상품 제보 → Gunpula 이슈 (lib/report.dart)
              trailing: ToolIcon(
                icon: Icons.flag_outlined,
                tip: '빠진 상품 제보',
                onTap: () => reportDataIssue(context, unitName: unit.name, kind: ReportKind.missingKit),
              ),
            ),
            if (lit.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  '대응 상품이 아직 없어요 · 새로 나오면 홈에 먼저 알려 드려요', // P09
                  style: TextStyle(color: Gp.muted),
                ),
              ),
            for (final k in lit) kitRow(k),
            if (related.isNotEmpty) ...[
              SectionHeader(
                '관련 상품',
                subtitle: '부품 · SD 캐릭터 — 칸은 켜지지 않아요',
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
    final m = Marks.of(context);
    final liked = m.liked(kit);
    final owned = m.owned(kit);
    return ThumbRow(
      image: kit.image,
      title: kit.name,
      tag: roleLabels[role] ?? '',
      subtitle: [
        kit.line,
        if (kit.scale.isNotEmpty) kit.scale,
        if (kit.date.length >= 7) kit.date.substring(0, 7).replaceAll('-', '.'),
      ].where((s) => s.isNotEmpty).join(' · '),
      size: 52,
      padding: const EdgeInsets.symmetric(vertical: 6),
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: '좋아요',
            onPressed: () => Marks.read(context).toggleLike(context, kit),
            icon: LikedIcon(filled: liked, size: Gp.iM, color: liked ? Gp.accent : Gp.muted),
          ),
          IconButton(
            tooltip: '구매함',
            onPressed: () => Marks.read(context).toggleOwn(context, kit),
            icon: OwnedIcon(filled: owned, size: Gp.iM, color: owned ? Gp.own : Gp.muted),
          ),
        ],
      ),
    );
  }
}

/// G-6 베이블레이드 X 도감
class _BbxGuide extends StatefulWidget {
  const _BbxGuide({required this.loaders, required this.find});
  final Loaders loaders;
  final _Find find;

  @override
  State<_BbxGuide> createState() => _BbxGuideState();
}

class _BbxGuideState extends State<_BbxGuide> {
  late Future<List<BbxTop>> _future = widget.loaders.bbxTops(); // STATE: GET /bbxTops

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<BbxTop>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const LoadingView();
        if (snap.hasError) {
          return ErrorView(message: '${snap.error}', onRetry: () => setState(() => _future = widget.loaders.bbxTops()));
        }
        if (snap.data!.isEmpty) return const EmptyView(message: '베이 도감이 아직 없어요');
        final m = Marks.of(context);
        // G-9 찾기 + 도감 필터 (단계 = 부품 다 모음 · 상품 좋아요, 라인 = BX · UX · CX)
        final tops = widget.find.apply(
          snap.data!,
          (t) => t.name,
          (t) => GuideFacet(
            name: t.name,
            tiers: {
              if (t.total > 0 && t.owned >= t.total) GuideTier.owned else GuideTier.none,
              if (t.kitIds.any((id) => m.store.statusOf(id) == CollectStatus.wanted)) GuideTier.liked,
            },
            grades: {if (t.line.isNotEmpty) t.line},
            kits: t.kitIds.length,
            boughtAt: [
              for (final id in t.kitIds) '${m.store.entry(id)?['updated_at'] ?? ''}',
            ].fold('', (a, b) => b.compareTo(a) > 0 ? b : a),
          ),
        );
        if (tops.isEmpty) return _noHit;
        final done = tops.where((t) => t.total > 0 && t.owned >= t.total).length;
        return LayoutBuilder(
          builder: (context, box) => ListView(
            padding: EdgeInsets.only(bottom: navClearance(context)),
            children: [
              SectionHeader(
                '베이',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ToolIcon(
                      // G-6a → T 조합 만들기
                      icon: Icons.build_outlined,
                      tip: '조합 만들기',
                      onTap: () => Navigator.of(
                        context,
                      ).push(MaterialPageRoute<void>(builder: (_) => BbxBuilderScreen(loaders: widget.loaders))),
                    ),
                    const LevelHelpButton(),
                  ],
                ),
                subtitle: '완성 $done / ${tops.length}',
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.count(
                  crossAxisCount: _cols(box.maxWidth, 110),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.7,
                  children: [
                    for (final t in tops)
                      _LitCell(
                        // G-6 P01
                        image: t.image,
                        name: t.name,
                        tier: t.total > 0 && t.owned >= t.total ? CellTier.owned : CellTier.none,
                        badge: '${t.owned}/${t.total}',
                        onTap: () => showModalBottomSheet<void>(
                          context: context,
                          builder: (_) => _TopSheet(top: t),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TopSheet extends StatelessWidget {
  const _TopSheet({required this.top});
  final BbxTop top;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              top.name,
              style: const TextStyle(fontSize: Gp.t16, fontWeight: FontWeight.w600),
            ),
            Text(
              '부품 ${top.owned} / ${top.total} 보유',
              style: const TextStyle(fontSize: Gp.t12, color: Gp.own, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            for (final p in top.parts)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox.square(
                      dimension: 52,
                      child: AppImage(p.image, fit: BoxFit.contain, grayscale: !p.have),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.typeLabel,
                            style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
                          ),
                          Text(p.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    Text(
                      p.have ? '보유' : '미보유',
                      style: TextStyle(fontWeight: FontWeight.w600, color: p.have ? Gp.own : Gp.faint),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// G-7 포켓몬 세대 · Fate 작품 · AC 세대
class _WorldGuide extends StatefulWidget {
  const _WorldGuide({required this.channel, required this.loaders, required this.find});
  final String channel;
  final Loaders loaders;
  final _Find find;

  @override
  State<_WorldGuide> createState() => _WorldGuideState();
}

class _WorldGuideState extends State<_WorldGuide> {
  late Future<List<World>> _future = widget.loaders.worlds(widget.channel);

  @override
  void didUpdateWidget(_WorldGuide old) {
    super.didUpdateWidget(old);
    if (old.channel != widget.channel) _future = widget.loaders.worlds(widget.channel);
  }

  @override
  Widget build(BuildContext context) {
    final label = channelOf(widget.channel).label;
    return FutureBuilder<List<World>>(
      future: _future, // STATE: GET /worlds?franchiseId= → 카드
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const LoadingView();
        if (snap.hasError) {
          return ErrorView(
            message: '${snap.error}',
            onRetry: () => setState(() => _future = widget.loaders.worlds(widget.channel)),
          );
        }
        // G-9 찾기 + 도감 필터 (단계 · 상품 있는 것 · 정렬)
        final worlds = widget.find.apply(
          snap.data!,
          (w) => '${w.label} ${w.subtitle}',
          (w) => GuideFacet(
            name: w.label,
            tiers: {if (w.owned > 0) GuideTier.owned else GuideTier.none},
            kits: w.kitIds.length,
          ),
        );
        if (worlds.isEmpty && widget.find.active) return _noHit;
        if (worlds.isEmpty) {
          return EmptyView(
            // G-8 P09
            icon: Icons.auto_awesome_mosaic_outlined,
            message: '$label 도감은 아직 준비 중이에요',
            detail: '상품이 수록되면 도감 칸이 생겨요',
          );
        }
        final pokemon = widget.channel == 'pokemon';
        return LayoutBuilder(
          builder: (context, box) => ListView(
            padding: EdgeInsets.only(bottom: navClearance(context)),
            children: [
              if (pokemon) const TagGameCards(), // G-7b → R 태그 도감
              SectionHeader(
                pokemon ? '세대' : (widget.channel == 'fate' ? '작품' : '게임 세대'),
                subtitle:
                    '수집 ${worlds.fold(0, (s, w) => s + w.owned)}'
                    ' / ${worlds.fold(0, (s, w) => s + w.total)}',
                padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.count(
                  crossAxisCount: _cols(box.maxWidth, 120),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.78,
                  children: [
                    for (final w in worlds)
                      _WorkCard(
                        // G-7 P01
                        image: w.image,
                        name: w.label,
                        subtitle: w.subtitle,
                        owned: w.owned,
                        total: w.total,
                        fit: pokemon ? BoxFit.contain : BoxFit.cover,
                        onTap: () => openPage(context, _WorldKitsPage(world: w, loaders: widget.loaders)), // G-7a
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// G-7a 세계관 묶음 → 그 묶음 상품 (전체 목록과 같은 찾기 · 필터 · 격자/목록)
class _WorldKitsPage extends StatefulWidget {
  const _WorldKitsPage({required this.world, required this.loaders});
  final World world;
  final Loaders loaders;

  @override
  State<_WorldKitsPage> createState() => _WorldKitsPageState();
}

class _WorldKitsPageState extends State<_WorldKitsPage> {
  late final Future<List<Kit>> _future = widget.loaders.kitsByIds(widget.world.kitIds); // STATE: GET /kits?id=

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: FutureBuilder<List<Kit>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingView();
          if (snap.hasError) return ErrorView(message: '${snap.error}', onRetry: () => Navigator.pop(context));
          return SectionListView(
            title: widget.world.label,
            subtitle: widget.world.subtitle,
            kits: snap.data!,
            onBack: () => Navigator.pop(context),
            loaders: widget.loaders,
          );
        },
      ),
    ),
  );
}
