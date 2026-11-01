// 화면 G: 도감 — 컬렉션의 다른 보기. 모은 만큼 칸에 불이 켜진다.
//
// ┌──────── 디자인 가이드 대응표: G 도감 ──────────────────────────────────────────────┐
// │ 번호 │ Flutter 위젯명                     │ 비즈니스 명칭(한글)                    │ 원칙(P번호)   │
// │ G-1  │ 채널 타일 격자                      │ '전체'일 때: 도감을 볼 IP 고르기         │ P06           │
// │ G-2  │ ? 버튼 → 바텀 시트                 │ 도감 읽는 법 (긴 범례 줄 대신)           │ P10 · P08     │
// │ G-3  │ 섹션별 작품 카드 + 진행 막대          │ 건담 작품 도감 (수집 n/전체)            │ P01 · P06     │
// │ G-4  │ 기체 칸 격자 (4단계)                 │ 흑백 → ♡ 컬러 → 리본 컬러·초록 테두리 → 내 사진·도는 고리 │ P01 · P04 │
// │ G-4a │ Lv 막대 (좋아요 1 · 구매 2 · 사진 3점) │ 하나 더할 때마다 오르는 작품 레벨        │ P01           │
// │ G-4b │ 칸 위 MarkOverlay (리본 · ♡)          │ 칸에서 바로 좋아요 · 구매함 (상품 사진과 같음) │ P07 · P04 │
// │ G-5  │ 바텀 시트: 기체 → 대응 상품           │ 이 기체의 상품 → 상품 상세              │ P07           │
// │ G-5b │ 시트의 TogglePill 3개                │ 좋아요 · 구매함 · 내 사진 (가짜 저장)    │ P03 · P07     │
// │ G-5c │ 바텀 시트(카메라 · 최근 사진) → 확인  │ 이 기체가 찍힌 사진이어야 켜짐 (가짜 판정) │ P05 · P09   │
// │ G-6  │ 베이 칸 + n/3 · 부품 시트            │ 베이블레이드 X 도감 (부품 3개)          │ P01           │
// │ G-7  │ 세대 · 작품 카드 + 진행 막대          │ 포켓몬 세대 · Fate 작품 · AC 세대       │ P01           │
// │ G-8  │ LoadingView / ErrorView / EmptyView │ 불러오는 중 · 오류 · 정리 안 된 작품     │ P01 · P09     │
// │ G-9  │ FindBar (컬렉션 · 작품 도감 위)       │ 도감에서 찾기 + 필터(전체 · 켜진 것 · 아직) │ P04 · P07   │
// └──────────────────────────────────────────────────────────────────────────────────┘
// 전환: 작품 카드 → 작품 도감(쌓기) → 기체 시트(덮기) → D 상품 상세(쌓기). 베이 → 부품 시트(덮기).
//       기체 시트 → 사진 고르기(덮기) → 확인 중(대화 상자) → 토스트.
import 'package:flutter/material.dart';

import '../api.dart';
import '../detail_pane.dart';
import '../filter_sheet.dart';
import '../level.dart';
import '../channels.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'c_channel_screen.dart';
import 'd_kit_detail_screen.dart';
import 'e_camera_screen.dart' show albumScenes;

class GuideView extends StatelessWidget {
  const GuideView({
    super.key,
    required this.channel,
    required this.myChannels,
    required this.onPickChannel,
    required this.loaders,
    this.query = '',
    this.lit = LitState.any,
  });

  final String channel;
  final List<String> myChannels;
  final ValueChanged<String> onPickChannel;
  final Loaders loaders;

  /// G-9 찾기 · 필터 (컬렉션의 FindBar)
  final String query;
  final LitState lit;

  @override
  Widget build(BuildContext context) {
    if (channel == allChannelId) return _ChannelPicker(myChannels: myChannels, onPick: onPickChannel);
    final find = _Find(query, lit);
    return switch (channel) {
      'gundam' => _GundamGuide(loaders: loaders, find: find),
      'beyblade' => _BbxGuide(loaders: loaders, find: find),
      _ => _WorldGuide(channel: channel, loaders: loaders, find: find),
    };
  }
}

/// G-9 이름에 찾는 글자가 있고 · 켜짐 조건에 맞나
class _Find {
  const _Find(this.query, this.lit);
  final String query;
  final LitState lit;

  bool get active => query.isNotEmpty || lit != LitState.any;
  bool hit(String name, bool lit) =>
      (query.isEmpty || name.toLowerCase().contains(query.toLowerCase())) && this.lit.hit(lit);
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

/// G-3 건담 작품 도감
class _GundamGuide extends StatefulWidget {
  const _GundamGuide({required this.loaders, this.find = const _Find('', LitState.any)});
  final Loaders loaders;
  final _Find find;

  @override
  State<_GundamGuide> createState() => _GundamGuideState();
}

class _GundamGuideState extends State<_GundamGuide> {
  late Future<List<GuideWork>> _future = widget.loaders.guideWorks(); // STATE: GET /guideWorks

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<GuideWork>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const LoadingView(); // G-8
        if (snap.hasError) {
          return ErrorView(
            message: '${snap.error}',
            onRetry: () => setState(() => _future = widget.loaders.guideWorks()),
          );
        }
        if (snap.data!.isEmpty) return const EmptyView(message: '도감 작품이 아직 없어요');
        final works = [
          for (final w in snap.data!)
            if (widget.find.hit(w.name, w.owned > 0)) w,
        ];
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
                          onTap: () => openPage(context, WorkGuideScreen(work: w, loaders: widget.loaders)),
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

/// G-4 작품 하나의 기체 칸
class WorkGuideScreen extends StatefulWidget {
  const WorkGuideScreen({super.key, required this.work, required this.loaders});
  final GuideWork work;
  final Loaders loaders;

  @override
  State<WorkGuideScreen> createState() => _WorkGuideScreenState();
}

class _WorkGuideScreenState extends State<WorkGuideScreen> {
  late Future<List<GuideUnit>> _future = _load();
  List<GuideUnit> _units = const [];

  // 이 화면에서 바꾼 상태 (가짜 — 저장하지 않음). 처음 값은 GET 결과에서.
  final Set<String> _liked = {};
  final Set<String> _owned = {};

  /// G-9 이 작품 안에서 찾기 · 필터
  String _query = '';
  LitState _lit = LitState.any;

  /// 기체 id → 내가 올린 사진. 그 기체가 찍힌 사진일 때만 들어간다
  final Map<String, String> _photos = {};

  Future<List<GuideUnit>> _load() => widget.loaders.guideUnits(widget.work.id).then((units) {
    // STATE: GET /guideUnits?workId= → 칸 + 처음 단계
    _units = units;
    _liked
      ..clear()
      ..addAll([
        for (final u in units)
          if (u.status == CollectStatus.wanted) u.id,
      ]);
    _owned
      ..clear()
      ..addAll([
        for (final u in units)
          if (u.status == CollectStatus.owned) u.id,
      ]);
    return units;
  });

  CellTier _tierOf(GuideUnit u) => _photos.containsKey(u.id)
      ? CellTier.photo
      : _owned.contains(u.id)
      ? CellTier.owned
      : _liked.contains(u.id)
      ? CellTier.liked
      : CellTier.none;

  /// 상태 바꾸기 + 토스트(되돌리기). 레벨이 오르면 토스트에 같이 알린다
  void _change(String message, VoidCallback apply) {
    final liked = {..._liked};
    final owned = {..._owned};
    final photos = {..._photos};
    setState(apply); // STATE: 칸 단계 → 색 · 테두리 · 고리 (레벨은 위 막대가 다시 센다)
    showToast(
      context,
      message,
      onUndo: () => setState(() {
        _liked
          ..clear()
          ..addAll(liked);
        _owned
          ..clear()
          ..addAll(owned);
        _photos
          ..clear()
          ..addAll(photos);
      }),
    );
  }

  void _toggleLike(GuideUnit u) {
    final on = !_liked.contains(u.id);
    _change(on ? '「${u.name}」 좋아요' : '좋아요를 취소했어요', () => on ? _liked.add(u.id) : _liked.remove(u.id));
  }

  void _toggleOwn(GuideUnit u) {
    final on = !_owned.contains(u.id);
    final hadPhoto = _photos.containsKey(u.id);
    _change(on ? '「${u.name}」 구매함에 넣었어요' : (hadPhoto ? '구매함에서 뺐어요 · 내 사진도 내렸어요' : '구매함에서 뺐어요'), () {
      if (on) {
        _owned.add(u.id);
      } else {
        _owned.remove(u.id);
        _photos.remove(u.id); // 안 가진 기체에 인증 사진은 남기지 않는다
      }
    });
  }

  void _setPhoto(GuideUnit u, String? photo) {
    _change(photo == null ? '「${u.name}」의 내 사진을 내렸어요' : '사진에서 「${u.name}」을(를) 찾았어요 · 인증 완료', () {
      if (photo == null) {
        _photos.remove(u.id);
      } else {
        _photos[u.id] = photo;
        _owned.add(u.id); // 사진이 있으면 가진 것
      }
    });
  }

  /// G-5c 내 사진 올리기: 카메라 · 최근 사진 → 사진 속 기체 확인(가짜) → 맞을 때만 켜짐
  Future<void> _uploadPhoto(GuideUnit u) async {
    // 가짜 판정 기준: 이 기체의 상품 사진 = "이 기체가 찍힌 사진"
    var mine = <String>[];
    try {
      mine = [for (final k in await widget.loaders.kitsByIds(u.kitIds)) k.image];
    } catch (_) {}
    if (mine.isEmpty) mine = [u.image];
    if (!mounted) return;
    final others = [
      for (final a in albumScenes)
        if (!mine.contains(a.photo)) a.photo,
    ];
    final album = [...others.take(1), ...mine.take(2), ...others.skip(1)].take(6).toList();
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PhotoSourceSheet(unit: u, album: album, cameraShot: mine.first),
    );
    if (picked == null || !mounted) return;
    final nav = Navigator.of(context, rootNavigator: true);
    showDialog<void>(context: context, barrierDismissible: false, builder: (_) => const _CheckingDialog());
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    nav.pop();
    if (!mounted) return;
    if (mine.contains(picked)) {
      _setPhoto(u, picked);
    } else {
      showToast(context, '사진에서 「${u.name}」을(를) 찾지 못했어요 · 기체가 잘 보이는 사진을 골라 주세요'); // P09
    }
  }

  void _openUnit(GuideUnit u) {
    VoidCallback close(BuildContext sheet, VoidCallback f) => () {
      Navigator.pop(sheet);
      f();
    };
    showModalBottomSheet<void>(
      // G-5 덮기
      context: context,
      isScrollControlled: true,
      builder: (sheet) => _UnitSheet(
        unit: u,
        tier: _tierOf(u),
        liked: _liked.contains(u.id),
        photo: _photos[u.id],
        onLike: close(sheet, () => _toggleLike(u)),
        onOwn: close(sheet, () => _toggleOwn(u)),
        onPhoto: close(sheet, () => _uploadPhoto(u)),
        onRemovePhoto: close(sheet, () => _setPhoto(u, null)),
        loaders: widget.loaders,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.work;
    final ownedNow = _units.isEmpty ? w.owned : _units.where((u) => _tierOf(u).index >= CellTier.owned.index).length;
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
          final find = _Find(_query, _lit);
          final units = [
            for (final u in all)
              if (find.hit(u.name, _tierOf(u) != CellTier.none)) u,
          ];
          if (all.isEmpty) {
            return EmptyView(
              // G-8 P09
              icon: Icons.grid_view,
              message: '이 작품은 아직 기체 정리가 안 됐어요',
              detail: '정리되면 기체마다 칸이 생기고, 모은 만큼 불이 켜져요',
              action: OutlinedButton(onPressed: () => showToast(context, '정리 요청을 보냈어요'), child: const Text('정리 요청하기')),
            );
          }
          return LayoutBuilder(
            builder: (context, box) => ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                LiveLevelBar(loaders: widget.loaders), // G-4a 수집 레벨 (아바타 옆 Lv 와 같은 막대)
                FindBar(
                  // G-9
                  hint: '${widget.work.name}에서 찾기',
                  onQuery: (q) => setState(() => _query = q), // STATE: 찾기 → 칸 거르기
                  filterCount: _lit == LitState.any ? 0 : 1,
                  onFilter: () async {
                    final v = await showLitFilterSheet(context, initial: _lit);
                    if (v != null) setState(() => _lit = v); // STATE: 켜짐 필터 → 칸 거르기
                  },
                ),
                if (units.isEmpty) _noHit,
                Padding(
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
                          image: u.image,
                          name: u.name,
                          tier: _tierOf(u),
                          photo: _photos[u.id],
                          liked: _liked.contains(u.id),
                          onTap: () => _openUnit(u),
                          onLike: () => _toggleLike(u), // G-4b
                          onOwn: () => _toggleOwn(u),
                        ),
                    ],
                  ),
                ),
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

/// G-5 기체 → 좋아요 · 구매함 · 내 사진 + 대응 상품
class _UnitSheet extends StatefulWidget {
  const _UnitSheet({
    required this.unit,
    required this.tier,
    required this.liked,
    required this.photo,
    required this.onLike,
    required this.onOwn,
    required this.onPhoto,
    required this.onRemovePhoto,
    required this.loaders,
  });
  final GuideUnit unit;
  final CellTier tier;
  final bool liked;
  final String? photo;
  final VoidCallback onLike;
  final VoidCallback onOwn;
  final VoidCallback onPhoto;
  final VoidCallback onRemovePhoto;
  final Loaders loaders;

  @override
  State<_UnitSheet> createState() => _UnitSheetState();
}

class _UnitSheetState extends State<_UnitSheet> {
  // 한 번만 부른다 (시트가 다시 그려져도 요청이 반복되지 않게)
  late final Future<List<Kit>> _kits = widget.loaders.kitsByIds(widget.unit.kitIds); // STATE: GET /kits?id=

  @override
  Widget build(BuildContext context) {
    final unit = widget.unit;
    final tier = widget.tier;
    final owned = tier.index >= CellTier.owned.index;
    final status = switch (tier) {
      CellTier.photo => '구매함 · 내 사진으로 인증됨',
      CellTier.owned => '구매함',
      CellTier.liked => '좋아요',
      CellTier.none => '아직 없음',
    };
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox.square(
                  dimension: 64,
                  child: tierFrame(tier, cellImage(tier, unit.image, widget.photo), radius: 12),
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
            // G-5b 한 단계씩: 좋아요 → 구매함 → 내 사진
            Row(
              children: [
                Expanded(
                  child: TogglePill(
                    label: '좋아요',
                    icon: Icons.favorite_border,
                    activeIcon: Icons.favorite,
                    active: widget.liked,
                    onTap: widget.onLike,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TogglePill(
                    label: '구매함',
                    icon: Icons.bookmark_add_outlined,
                    activeIcon: Icons.bookmark_added,
                    color: Gp.own,
                    active: owned,
                    onTap: widget.onOwn,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TogglePill(
                    label: '내 사진',
                    icon: Icons.add_a_photo_outlined,
                    activeIcon: Icons.workspace_premium,
                    color: Gp.own,
                    active: widget.photo != null,
                    onTap: widget.onPhoto, // G-5c
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.photo == null ? '이 기체가 찍힌 내 사진을 올리면 칸에 색 고리가 돌아요' : '도감 칸에 이 사진이 보여요 · 다시 누르면 사진 바꾸기',
                    style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
                  ),
                ),
                if (widget.photo != null)
                  TextButton(
                    onPressed: widget.onRemovePhoto,
                    style: TextButton.styleFrom(foregroundColor: Gp.muted, visualDensity: VisualDensity.compact),
                    child: const Text('사진 내리기'),
                  ),
              ],
            ),
            const SectionHeader('이 기체의 상품', padding: EdgeInsets.fromLTRB(0, 10, 0, 10)),
            FutureBuilder<List<Kit>>(
              future: _kits,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const SizedBox(height: 90, child: Center(child: MiniSpinner()));
                }
                if (snap.hasError) {
                  return const Text('상품을 불러오지 못했어요', style: TextStyle(color: Gp.muted));
                }
                final kits = snap.data!;
                if (kits.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      '대응 상품이 아직 없어요 · 새로 나오면 홈에 먼저 알려 드려요', // P09
                      style: TextStyle(color: Gp.muted),
                    ),
                  );
                }
                return SizedBox(
                  height: 130 + 32,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: kits.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, i) => ProductTile(
                      image: kits[i].image,
                      title: kits[i].name,
                      imageWidth: 130,
                      onTap: () {
                        Navigator.pop(context);
                        openKitDetail(context, kits[i], loaders: widget.loaders);
                      },
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// G-5c 사진 고르기: 카메라로 찍기 · 최근 사진 (가짜 앨범)
class _PhotoSourceSheet extends StatelessWidget {
  const _PhotoSourceSheet({required this.unit, required this.album, required this.cameraShot});
  final GuideUnit unit;
  final List<String> album;

  /// 카메라로 찍으면 나오는 미리 정한 사진
  final String cameraShot;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              '「${unit.name}」 내 사진 올리기',
              subtitle: '내가 가진 이 기체가 찍힌 사진이어야 칸이 켜져요',
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.photo_camera_outlined, color: Gp.ink),
              title: const Text('카메라로 찍기'),
              onTap: () => Navigator.pop(context, cameraShot),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(0, 4, 0, 10),
              child: Text(
                '최근 사진',
                style: TextStyle(fontSize: Gp.t12, color: Gp.muted),
              ),
            ),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              children: [
                for (final ph in album)
                  GestureDetector(onTap: () => Navigator.pop(context, ph), child: PhotoThumb(ph, radius: 8)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 사진 속 기체 확인 중 (가짜 1.1초)
class _CheckingDialog extends StatelessWidget {
  const _CheckingDialog();

  @override
  Widget build(BuildContext context) {
    return const AlertDialog(
      content: Row(
        children: [
          MiniSpinner(color: Gp.accent),
          SizedBox(width: 16),
          Expanded(child: Text('사진 속 기체를 확인하고 있어요')),
        ],
      ),
    );
  }
}

/// G-6 베이블레이드 X 도감
class _BbxGuide extends StatefulWidget {
  const _BbxGuide({required this.loaders, this.find = const _Find('', LitState.any)});
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
        final tops = [
          for (final t in snap.data!)
            if (widget.find.hit(t.name, t.owned > 0)) t,
        ];
        if (tops.isEmpty) return _noHit;
        final done = tops.where((t) => t.total > 0 && t.owned >= t.total).length;
        return LayoutBuilder(
          builder: (context, box) => ListView(
            padding: EdgeInsets.only(bottom: navClearance(context)),
            children: [
              SectionHeader(
                '베이',
                trailing: const LevelHelpButton(),
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
  const _WorldGuide({required this.channel, required this.loaders, this.find = const _Find('', LitState.any)});
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
        final worlds = [
          for (final w in snap.data!)
            if (widget.find.hit(w.label, w.owned > 0)) w,
        ];
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
                        onTap: () => showSoon(context, '${w.label} 도감'),
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
