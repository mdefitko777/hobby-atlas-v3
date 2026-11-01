// 화면 F: 컬렉션 — 좋아요 · 구매함 (목록 | 도감)
//
// ┌──────── 디자인 가이드 대응표: F 컬렉션 ────────────────────────────────────────────┐
// │ 번호 │ Flutter 위젯명                     │ 비즈니스 명칭(한글)                    │ 원칙(P번호)   │
// │ F-1  │ ChannelHeader                      │ 아바타 줄 + 내 채널 바 (C-0 공용)       │ P04 · P06     │
// │ F-2  │ 밑줄 탭 2–3개 + 개수                 │ 좋아요 · 예약(있을 때만) · 구매함         │ P06 · P01     │
// │ F-2b │ SquareSegments (구매함 탭)           │ 조립 상태로 거르기: 전체 · 미조립 n · 조립 중 · 완성 │ P01 · P06 │
// │ F-3  │ 아이콘 두 개 (목록 · 도감, 검색창 줄) │ 보기 방식 전환                          │ P07           │
// │ F-4  │ Text(합계)                         │ 좋아요 정가 합계 · 구매함 지출 합계 (× 수량) │ P01         │
// │ F-5  │ ListView 줄 (사진 · 이름 · 가격)      │ 컬렉션 목록 → 상품 상세                 │ P08           │
// │ F-5c │ 줄 오른쪽 BuildStatusButton          │ 조립 상태 바로 바꾸기 (누름 = 다음 단계 · 길게 = 도색) │ P03 · P07 │
// │ F-5d │ 예약 탭 줄: 가게 · 도착 · 낼 돈 + 📥   │ 예약 목록 · 도착하면 구매함으로 (밀기도 같음) │ P01 · P03  │
// │ F-6  │ 편집 → 체크박스 + 선택 삭제           │ 정리하기 (편집 모드에서만 삭제 보임)     │ P05 · P03     │
// │ F-7  │ showDialog(확인) → 토스트(되돌리기)   │ 삭제 전 확인 · 바로 되돌리기             │ P05 · P03     │
// │ F-8  │ GuideView (g_guide_view.dart)       │ 도감 — 모은 만큼 불이 켜지는 칸          │ P01 · P06     │
// │ F-9  │ LoadingView / ErrorView / EmptyView │ 불러오는 중 · 오류 · 빈 컬렉션           │ P01 · P09     │
// │ F-10 │ 🗑 아이콘(개수 배지) → 바텀 시트      │ 휴지통: 지운 상품 복원 (기기 저장 · 30일)  │ P03 · P05     │
// │ F-11 │ jumpTick (내 정보 숫자에서)          │ 좋아요 · 구매함 · 도감으로 바로 이동       │ P07           │
// │ F-12 │ FindBar (탭 아래)                   │ 이 탭 · 도감에서 찾기 + 필터(도감 = GuideFilterSheet) │ P04 · P07 │
// └──────────────────────────────────────────────────────────────────────────────────┘
// 전환: 줄 → D 상품 상세(쌓기). 빈 상태 "검색하러 가기" → 검색 탭(옆으로).
// 현행 앱 문제: 컬렉션 화면에 빨간 "전체 삭제"가 늘 보임(실수 위험) · 도감이 따로 떨어진 화면
//              → v2는 편집 모드에서만 삭제, 도감은 컬렉션의 다른 보기.
import 'package:flutter/material.dart';

import '../api.dart';
import '../logic/build_status.dart';
import '../logic/collection_rules.dart';
import '../logic/preorder.dart';
import '../marks.dart';
import '../channels.dart';
import '../data/catalog.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'c_channel_screen.dart';
import 'd_kit_detail_screen.dart';
import 'g_guide_view.dart';

/// 내 정보 숫자를 눌렀을 때 열 곳 (backlog = 구매함 탭 · 미조립만)
enum CollectionJump { liked, owned, guide, backlog }

/// 목록 탭: 좋아요 · 예약(좋아요 중 예약 기록이 있는 것) · 구매함
enum _Tab { liked, preorder, owned }

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({
    super.key,
    required this.myChannels,
    required this.onMyChannelsChanged,
    required this.onGoSearch,
    this.leading,
    this.loaders = const Loaders(),
    this.jump = CollectionJump.liked,
    this.jumpTick = 0,
  });

  final List<String> myChannels;
  final ValueChanged<List<String>> onMyChannelsChanged;
  final VoidCallback onGoSearch;
  final Widget? leading;
  final Loaders loaders;

  /// [jumpTick]이 바뀔 때마다 [jump] 로 이동 (F-11)
  final CollectionJump jump;
  final int jumpTick;

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> with ChannelScope {
  late Future<List<Kit>> _future;

  _Tab _tab = _Tab.liked;

  /// true = 구매함 탭
  bool get _ownedTab => _tab == _Tab.owned;

  /// F-2b 구매함 탭 조립 상태 거르기 (0 = 전체, 1.. = BuildStage)
  int _build = 0;

  /// true = 도감 보기, false = 목록 보기
  bool _guide = false;
  bool _editing = false;
  final Set<String> _selected = {};

  /// F-12 찾기 · 필터 (목록 = 상품 필터, 도감 = 도감 필터)
  final _find = KitFind();
  final _guideFilter = GuideFilterController();

  @override
  void dispose() {
    _guideFilter.dispose();
    super.dispose();
  }

  /// 휴지통 (UserStore.trash, 기기에 30일): 지운 상품 id → 어느 탭에서 지웠나 (true = 구매함).
  /// 그 사이 다른 화면에서 다시 좋아요 · 구매함에 넣은 상품은 빼고 보여 준다. 지우기 = 앱 전체 Marks 에서 끄기
  Map<String, bool> get _removed => trashView(Marks.read(context).store);

  @override
  List<String> get myChannels => widget.myChannels;

  @override
  void loadScope(List<String> ids) {
    _future = widget.loaders.kits(ids); // STATE: GET /kits(내 채널) → 좋아요 · 구매함은 Marks 로 거름 (홈에서 누른 ♡ 도 보임)
  }

  @override
  void initState() {
    super.initState();
    reloadScope();
  }

  @override
  void didUpdateWidget(CollectionScreen old) {
    super.didUpdateWidget(old);
    syncScope();
    if (widget.jumpTick != old.jumpTick) {
      // STATE: 내 정보 숫자 → 전체 채널 + 그 탭/보기
      _tab = switch (widget.jump) {
        CollectionJump.owned || CollectionJump.backlog => _Tab.owned,
        _ => _Tab.liked,
      };
      _build = widget.jump == CollectionJump.backlog ? BuildStage.unbuilt.index + 1 : 0;
      _guide = widget.jump == CollectionJump.guide;
      _editing = false;
      _selected.clear();
      if (channel != allChannelId) selectChannel(allChannelId);
    }
  }

  /// F-10 휴지통 — 지운 상품 (기기에 저장, 30일 지나면 버림)
  void _openTrash(List<Kit> all) {
    final me = Marks.read(context).store..purgeTrash(DateTime.now());
    showGpSheet<void>(
      context,
      tall: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) {
          final removed = _removed;
          final gone = all.where((k) => removed.containsKey(k.id)).toList();
          void restore(Iterable<String> ids, String msg) {
            final list = [...ids];
            final marks = Marks.read(context);
            for (final k in all.where((k) => list.contains(k.id))) {
              removed[k.id]! ? marks.set(k, owned: true) : marks.set(k, liked: true); // 앱 전체에 다시 켜기
            }
            me.trashRemove(list); // STATE: 복원 → 목록에 다시 (UserStore → 다시 그림)
            setSheet(() {});
            showToast(context, msg);
          }

          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * 0.7),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionHeader(
                    '휴지통',
                    subtitle: '지운 상품은 30일 동안 여기서 되살릴 수 있어요',
                    padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
                    trailing: gone.isEmpty
                        ? null
                        : TextButton(
                            onPressed: () => restore(gone.map((k) => k.id), '${gone.length}개를 모두 복원했어요'),
                            child: const Text('모두 복원'),
                          ),
                  ),
                  if (gone.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 28),
                      child: Text('지운 상품이 없어요', style: TextStyle(color: Gp.muted)),
                    )
                  else
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.only(bottom: 12),
                        children: [
                          for (final k in gone)
                            ThumbRow(
                              image: k.image,
                              title: k.name,
                              size: 52,
                              tag: removed[k.id]! ? '구매함' : '좋아요',
                              onTap: () => restore([k.id], '「${k.name}」을(를) 복원했어요'),
                              trailing: const Text(
                                '복원',
                                style: TextStyle(color: Gp.accent, fontWeight: FontWeight.w600),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 이 탭 · 이 채널의 상품 (찾기 · 필터 전)
  List<Kit> _inTab(List<Kit> all, [_Tab? tab]) {
    final ids = scopeIds;
    final marks = Marks.of(context);
    final t = tab ?? _tab;
    bool inTab(Kit k) => switch (t) {
      _Tab.owned => marks.owned(k),
      _Tab.liked => marks.liked(k),
      _Tab.preorder => marks.liked(k) && (marks.store.preorderOf(k.id)?.active ?? false),
    };
    return all.where((k) => inTab(k) && ids.contains(k.franchiseId)).toList();
  }

  List<Kit> _visible(List<Kit> all) {
    _find.watch(context);
    final stage = _ownedTab ? buildFilterAt(_build) : null;
    final store = Marks.of(context).store;
    return [
      for (final k in _inTab(all))
        if (_find.hit(k) && (stage == null || store.stageOf(k.id) == stage)) k,
    ];
  }

  /// F-12 필터 시트 — 목록: 상품 필터(검색 화면과 같은 시트), 도감: 도감 필터(단계 · 등급 · 종류 · 시대 · 정렬)
  Future<void> _openFilter(List<Kit> all) async {
    if (_guide) {
      await _guideFilter.openSheet(context); // STATE: 도감 필터 → 도감 칸 (단계 · 등급 · 종류 · 시대 · 정렬)
      if (mounted) setState(() {});
      return;
    }
    if (await _find.openFilter(context, _inTab(all))) setState(() {}); // STATE: 필터 → 목록
  }

  Future<void> _deleteSelected() async {
    final n = _selected.length;
    final ok = await showDialog<bool>(
      // F-7 P05
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$n개를 ${_ownedTab ? '구매함' : '좋아요'}에서 삭제할까요?'),
        content: const Text('내 컬렉션에서만 빠져요 · 🗑 휴지통에서 30일 안에 되살려요'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final gone = {..._selected};
    final tab = _ownedTab;
    final marks = Marks.read(context);
    final kits = (await _future).where((k) => gone.contains(k.id)).toList();
    void apply(bool on) {
      for (final k in kits) {
        tab ? marks.set(k, owned: on) : marks.set(k, liked: on); // 앱 전체에서 끄기/켜기
      }
    }

    apply(false);
    marks.store.trashAdd(gone, owned: tab); // STATE: 선택 → 목록에서 빠지고 휴지통으로 (기기에 저장)
    setState(() {
      _selected.clear();
      _editing = false;
    });
    if (!mounted) return;
    showToast(
      context,
      '$n개를 삭제했어요',
      onUndo: () {
        apply(true);
        marks.store.trashRemove(gone);
      },
    ); // P03
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ChannelHeader(
          // F-1 P04
          leading: widget.leading,
          myChannels: widget.myChannels,
          selected: channel,
          onSelect: selectChannel,
          onMyChannelsChanged: widget.onMyChannelsChanged,
        ),
        Expanded(
          child: FutureBuilder<List<Kit>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const LoadingView(); // F-9 P01
              }
              if (snap.hasError) {
                return ErrorView(message: '${snap.error}', onRetry: () => setState(reloadScope));
              }
              final all = snap.data!;
              return Column(
                children: [
                  _TopRow(
                    counts: {for (final t in _Tab.values) t: _inTab(all, t).length},
                    tab: _tab,
                    guide: _guide,
                    onTab: (t) => setState(() {
                      _tab = t; // STATE: 탭 → 목록 내용
                      _selected.clear();
                      _editing = false;
                    }),
                    onGuide: (g) => setState(() {
                      _guide = g; // STATE: 보기 방식 → 목록 ↔ 도감
                      _editing = false;
                    }),
                  ),
                  FindBar(
                    // F-12 모든 탭과 같은 줄: [검색창][필터][목록 · 도감]
                    hint: _guide
                        ? '도감에서 찾기'
                        : switch (_tab) {
                            _Tab.owned => '구매함에서 찾기',
                            _Tab.preorder => '예약에서 찾기',
                            _Tab.liked => '좋아요에서 찾기',
                          },
                    onQuery: (q) => setState(() => _find.query = q), // STATE: 찾기 → 목록 · 도감
                    filterCount: _guide ? _guideFilter.filter.count : _find.filter.count,
                    onFilter: _guide && channel == allChannelId ? null : () => _openFilter(all),
                    tools: [
                      ViewIconToggle(
                        // F-3
                        mine: _guide,
                        onChanged: (g) => setState(() {
                          _guide = g; // STATE: 보기 방식 → 목록 ↔ 도감
                          _editing = false;
                        }),
                        allIcon: Icons.view_agenda_outlined,
                        mineIcon: Icons.auto_awesome_mosaic_outlined,
                        allTip: '목록',
                        mineTip: '도감',
                      ),
                    ],
                  ),
                  Expanded(
                    child: _guide
                        ? GuideView(
                            // F-8
                            channel: channel,
                            myChannels: widget.myChannels,
                            onPickChannel: selectChannel,
                            loaders: widget.loaders,
                            query: _find.query,
                            filter: _guideFilter,
                          )
                        : _list(_visible(all), all),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _list(List<Kit> kits, List<Kit> all) {
    final trash = IconButton(
      // F-10
      tooltip: '휴지통',
      onPressed: () => _openTrash(all),
      icon: Badge(
        isLabelVisible: _removed.isNotEmpty,
        backgroundColor: Gp.accent,
        label: Text('${_removed.length}'),
        child: const Icon(Icons.delete_outline, color: Gp.muted, size: Gp.iM),
      ),
    );
    final stages = _ownedTab ? _stageSegments(all) : null; // F-2b
    if (kits.isEmpty && (_find.active || _build != 0)) {
      if (_build != 0 && !_find.active) {
        return ListView(
          children: [
            ?stages,
            const EmptyView(icon: Icons.inventory_2_outlined, message: '이 상태의 상품이 없어요'),
          ],
        );
      }
      return EmptyView(
        // F-12 찾기 · 필터 결과 없음
        icon: Icons.search_off,
        message: '이 조건의 상품이 없어요',
        action: _find.filter.count > 0
            ? OutlinedButton(onPressed: () => setState(() => _find.filter = KitFilter()), child: const Text('필터 초기화'))
            : null,
      );
    }
    if (kits.isEmpty && _tab == _Tab.preorder) {
      return const EmptyView(
        icon: Icons.event_available_outlined,
        message: '기다리는 예약이 없어요',
        detail: '상품 상세의 예약 칸에 적으면 여기에 모여요',
      );
    }
    if (kits.isEmpty) {
      return EmptyView(
        // F-9 P09
        icon: _ownedTab ? Icons.bookmark_added_outlined : Icons.favorite_border, // 구매함 = 리본, 좋아요 = ♡
        message: _ownedTab ? '아직 구매함에 넣은 상품이 없어요' : '아직 좋아요에 담은 상품이 없어요',
        detail: channel == allChannelId ? '상품 상세에서 좋아요 · 구매함을 누르면 여기에 모여요' : '${channelOf(channel).label} 채널에는 아직 없어요',
        action: _removed.isEmpty
            ? OutlinedButton.icon(
                onPressed: widget.onGoSearch,
                icon: const Icon(Icons.search, size: Gp.iM),
                label: const Text('검색하러 가기'),
              )
            : OutlinedButton.icon(
                onPressed: () => _openTrash(all), // 다 지웠어도 휴지통은 열 수 있게
                icon: const Icon(Icons.delete_outline, size: Gp.iM),
                label: Text('휴지통 (${_removed.length})'),
              ),
      );
    }
    // F-4 합계 × 수량 (좋아요 = 갖고 싶은 수, 구매함 = 가진 수)
    final me = Marks.of(context).store;
    final total = kits.fold<int>(0, (s, k) => s + (k.priceJpy ?? 0) * me.quantityOf(k.id));
    final pieces = kits.fold<int>(0, (s, k) => s + me.quantityOf(k.id));
    final spent = kits.fold<int>(0, (s, k) => s + (_paid(k).krw ?? 0) * me.quantityOf(k.id)); // 적은 구매가, 없으면 정가 × 환율
    final pre = {for (final k in kits) k.id: ?me.preorderOf(k.id)};
    final due = pre.values.fold<int>(0, (s, p) => s + p.due);
    final backlog = backlogCount(_inTab(all).map((k) => k.id), me.stageOf);
    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.only(bottom: navClearance(context) + (_editing ? 60 : 0)),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      switch (_tab) {
                        _Tab.owned => joinDot(['$pieces개', '지출 합계 ${won(spent)}', if (backlog > 0) '미조립 $backlog']),
                        _Tab.preorder => joinDot(['${kits.length}건', if (due > 0) '낼 돈 ${won(due)}']),
                        _Tab.liked => '합계 ${yen(total)} · $pieces개',
                      }, // F-4 P01
                      style: const TextStyle(color: Gp.muted, fontSize: Gp.t12),
                    ),
                  ),
                  trash,
                  TextButton(
                    onPressed: () => setState(() {
                      _editing = !_editing; // STATE: 편집 → 체크박스 · 삭제 바
                      _selected.clear();
                    }),
                    child: Text(_editing ? '완료' : '편집'), // F-6
                  ),
                ],
              ),
            ),
            ?stages,
            for (final k in kits)
              _swipe(
                k,
                ThumbRow(
                  // F-5 P08 — 검색·캘린더와 같은 줄
                  id: k.id,
                  image: k.image,
                  title: k.name,
                  titleLines: 2,
                  size: 68,
                  tag: _tab == _Tab.liked && (pre[k.id]?.active ?? false) ? '예약' : '',
                  subtitle: _tab == _Tab.preorder
                      ? joinDot([
                          pre[k.id]?.shop ?? '',
                          if (pre[k.id]?.arrival case final a? when a.isNotEmpty) '${arrivalLabel(a)} 도착',
                        ])
                      : joinDot([
                          if (me.quantityOf(k.id) > 1) '×${me.quantityOf(k.id)}', // D-7 수량
                          channelOf(k.franchiseId).label,
                          k.line,
                          k.series,
                        ]),
                  leading: _editing
                      ? Icon(
                          _selected.contains(k.id) ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: _selected.contains(k.id) ? Gp.accent : Gp.faint,
                        )
                      : null,
                  onTap: _editing
                      ? () => setState(() => _selected.contains(k.id) ? _selected.remove(k.id) : _selected.add(k.id))
                      : () => openKitDetail(context, k, loaders: widget.loaders),
                  trailing: _tab == _Tab.preorder
                      ? _preTrailing(k, pre[k.id])
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (_ownedTab) ...[
                                  // 구매함: 적은 구매가 (없으면 정가 × 환율을 옅게 ≈) · 아래에 정가
                                  Text(
                                    switch (_paid(k)) {
                                      (krw: null, estimate: _) => '구매가 미입력',
                                      (krw: final int w, estimate: true) => '≈ ${won(w)}',
                                      (krw: final int w, estimate: false) => won(w),
                                    },
                                    style: TextStyle(
                                      fontSize: Gp.t14,
                                      fontWeight: _paid(k).estimate ? FontWeight.w400 : FontWeight.w600,
                                      color: _paid(k).estimate ? Gp.faint : Gp.ink,
                                    ),
                                  ),
                                  Text(
                                    '정가 ${yen(k.priceJpy)}',
                                    style: const TextStyle(fontSize: Gp.t11, color: Gp.faint),
                                  ),
                                ] else
                                  Text(yen(k.priceJpy), style: const TextStyle(fontSize: Gp.t12)),
                              ],
                            ),
                            if (_ownedTab && !_editing) BuildStatusButton(kitId: k.id), // F-5c
                          ],
                        ),
                ),
              ),
          ],
        ),
        if (_editing)
          Positioned(
            left: 16,
            right: 16,
            bottom: navClearance(context) - 30,
            child: Row(
              children: [
                TextButton(
                  onPressed: () => setState(() {
                    if (_selected.length == kits.length) {
                      _selected.clear();
                    } else {
                      _selected.addAll(kits.map((k) => k.id));
                    }
                  }),
                  child: Text(_selected.length == kits.length ? '모두 해제' : '모두 선택'),
                ),
                const Spacer(),
                OutlinedButton(
                  onPressed: _selected.isEmpty ? null : _deleteSelected, // F-6 P05
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Gp.panel,
                    foregroundColor: Gp.danger,
                    side: BorderSide(color: _selected.isEmpty ? Gp.line : Gp.danger),
                  ),
                  child: Text('삭제 (${_selected.length})'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// F-2b 조립 상태 세그먼트 (구매함 탭) — 칸마다 개수, 미조립 = 쌓인 것
  Widget _stageSegments(List<Kit> all) {
    final store = Marks.of(context).store;
    final counts = stageCounts(_inTab(all).map((k) => k.id), store.stageOf);
    final total = counts.values.fold(0, (a, b) => a + b);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: SquareSegments<int>(
        key: const ValueKey('build-filter'),
        values: [for (var i = 0; i <= BuildStage.values.length; i++) i],
        current: _build,
        onPick: (i) => setState(() => _build = i), // STATE: 조립 상태 거르기 → 목록
        child: (i) => Text(switch (buildFilterAt(i)) {
          null => '전체 $total',
          final s => '${s.label} ${counts[s]}',
        }),
      ),
    );
  }

  /// F-5d 예약 탭 줄 오른쪽: 총액 · 낼 돈(없으면 결제 완료) + 📥 도착
  Widget _preTrailing(Kit k, Preorder? p) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            p?.price == null ? yen(k.priceJpy) : won(p!.price!),
            style: const TextStyle(fontSize: Gp.t14, fontWeight: FontWeight.w600),
          ),
          Text(
            (p?.due ?? 0) > 0 ? '낼 돈 ${won(p!.due)}' : (p?.paid ?? false ? '결제 완료' : '미결제'),
            style: TextStyle(fontSize: Gp.t11, color: (p?.due ?? 0) > 0 ? Gp.reserve : Gp.faint),
          ),
        ],
      ),
      if (!_editing)
        IconButton(
          tooltip: '도착했어요',
          onPressed: () => markPreorderArrived(context, k),
          icon: const Icon(Icons.move_to_inbox_outlined, size: Gp.iM, color: Gp.reserve),
        ),
    ],
  );

  /// 적은 구매가, 없으면 정가 × 환율 (estimate)
  ({int? krw, bool estimate}) _paid(Kit k) => Catalog.instance.paidOf(k);

  /// F-5b 줄 밀기 — 오른쪽: 좋아요 ↔ 구매함 옮기기 · 왼쪽: 빼기 (토스트로 되돌리기). 편집 중에는 끔
  Widget _swipe(Kit k, Widget row) {
    if (_editing) return row;
    final marks = Marks.read(context);
    Widget bg(Color c, IconData icon, String label, Alignment a) => Container(
      color: c.withValues(alpha: 0.14),
      alignment: a,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: c, size: Gp.iM),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: Gp.t12),
          ),
        ],
      ),
    );
    return Dismissible(
      key: ValueKey('swipe-${k.id}'),
      background: _ownedTab
          ? bg(Gp.accent, Icons.favorite, '좋아요로', Alignment.centerLeft)
          : bg(Gp.own, Icons.bookmark, '구매함으로', Alignment.centerLeft),
      secondaryBackground: bg(Gp.danger, Icons.delete_outline, '빼기', Alignment.centerRight),
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.startToEnd && _tab == _Tab.preorder) {
          await markPreorderArrived(context, k); // 예약 → 도착 (· 구매함, 예약 총액 = 구매가)
          return false;
        }
        if (dir == DismissDirection.startToEnd) {
          _ownedTab ? marks.toggleLike(context, k) : marks.toggleOwn(context, k); // STATE: 옮기기 (토스트 되돌리기)
        } else {
          final wasOwned = _ownedTab;
          marks.set(k, liked: false, owned: false); // STATE: 빼기 → 휴지통
          marks.store.trashAdd([k.id], owned: wasOwned);
          showToast(
            context,
            wasOwned ? '구매함에서 뺐어요' : '좋아요에서 뺐어요',
            onUndo: () {
              wasOwned ? marks.set(k, owned: true) : marks.set(k, liked: true);
              marks.store.trashRemove([k.id]);
            },
          );
        }
        return false; // 목록은 Marks 가 바뀌면 다시 그려진다
      },
      child: row,
    );
  }
}

/// F-2 · F-3 좋아요 | 예약 | 구매함 탭 + 목록/도감 전환. 예약 탭은 예약이 있거나 고른 때만
class _TopRow extends StatelessWidget {
  const _TopRow({
    required this.counts,
    required this.tab,
    required this.guide,
    required this.onTab,
    required this.onGuide,
  });

  final Map<_Tab, int> counts;
  final _Tab tab;
  final bool guide;
  final ValueChanged<_Tab> onTab;
  final ValueChanged<bool> onGuide;

  @override
  Widget build(BuildContext context) {
    Widget one(String label, _Tab t) => UnderlineTab(
      // 채널 바와 같은 밑줄 탭
      key: ValueKey('tab-${t.name}'),
      label: label,
      count: counts[t] ?? 0,
      fontSize: Gp.t16,
      selected: !guide && tab == t,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      onTap: () {
        onGuide(false);
        onTab(t);
      },
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 2, 6, 2),
      child: Row(
        children: [
          one('좋아요', _Tab.liked), // F-2 P06
          if ((counts[_Tab.preorder] ?? 0) > 0 || tab == _Tab.preorder) one('예약', _Tab.preorder),
          one('구매함', _Tab.owned),
        ],
      ),
    );
  }
}
