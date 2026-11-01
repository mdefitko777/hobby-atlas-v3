// 화면 F: 컬렉션 — 좋아요 · 구매함 (목록 | 도감)
//
// ┌──────── 디자인 가이드 대응표: F 컬렉션 ────────────────────────────────────────────┐
// │ 번호 │ Flutter 위젯명                     │ 비즈니스 명칭(한글)                    │ 원칙(P번호)   │
// │ F-1  │ ChannelHeader                      │ 아바타 줄 + 내 채널 바 (C-0 공용)       │ P04 · P06     │
// │ F-2  │ 밑줄 탭 2개 + 개수                   │ 좋아요 · 구매함                          │ P06 · P01     │
// │ F-3  │ 아이콘 두 개 (목록 · 도감)            │ 보기 방식 전환                          │ P07           │
// │ F-4  │ Text(합계)                         │ 좋아요 정가 합계 · 구매함 지출 합계       │ P01           │
// │ F-5  │ ListView 줄 (사진 · 이름 · 가격)      │ 컬렉션 목록 → 상품 상세                 │ P08           │
// │ F-6  │ 편집 → 체크박스 + 선택 삭제           │ 정리하기 (편집 모드에서만 삭제 보임)     │ P05 · P03     │
// │ F-7  │ showDialog(확인) → 토스트(되돌리기)   │ 삭제 전 확인 · 바로 되돌리기             │ P05 · P03     │
// │ F-8  │ GuideView (g_guide_view.dart)       │ 도감 — 모은 만큼 불이 켜지는 칸          │ P01 · P06     │
// │ F-9  │ LoadingView / ErrorView / EmptyView │ 불러오는 중 · 오류 · 빈 컬렉션           │ P01 · P09     │
// │ F-10 │ 🗑 아이콘(개수 배지) → 바텀 시트      │ 휴지통: 지운 상품 복원 (손 미끄러짐 대비)  │ P03 · P05     │
// │ F-11 │ jumpTick (내 정보 숫자에서)          │ 좋아요 · 구매함 · 도감으로 바로 이동       │ P07           │
// │ F-12 │ FindBar (탭 아래)                   │ 이 탭 · 도감에서 찾기 + 필터              │ P04 · P07     │
// └──────────────────────────────────────────────────────────────────────────────────┘
// 전환: 줄 → D 상품 상세(쌓기). 빈 상태 "검색하러 가기" → 검색 탭(옆으로).
// 현행 앱 문제: 컬렉션 화면에 빨간 "전체 삭제"가 늘 보임(실수 위험) · 도감이 따로 떨어진 화면
//              → v2는 편집 모드에서만 삭제, 도감은 컬렉션의 다른 보기.
import 'package:flutter/material.dart';

import '../api.dart';
import '../marks.dart';
import '../channels.dart';
import '../data/user_store.dart';
import '../filter_sheet.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'c_channel_screen.dart';
import 'd_kit_detail_screen.dart';
import 'g_guide_view.dart';

/// 내 정보 숫자를 눌렀을 때 열 곳
enum CollectionJump { liked, owned, guide }

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

  /// true = 구매함 탭, false = 좋아요 탭
  bool _ownedTab = false;

  /// true = 도감 보기, false = 목록 보기
  bool _guide = false;
  bool _editing = false;
  final Set<String> _selected = {};

  /// F-12 찾기 · 필터 (목록 = 상품 필터, 도감 = 켜짐 필터)
  String _query = '';
  KitFilter _filter = KitFilter();
  LitState _lit = LitState.any;

  /// 휴지통: 지운 상품 id → 어느 탭에서 지웠나 (true = 구매함). 지우기 = 앱 전체 Marks 에서 끄기
  final Map<String, bool> _removed = {};

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
      _ownedTab = widget.jump == CollectionJump.owned;
      _guide = widget.jump == CollectionJump.guide;
      _editing = false;
      _selected.clear();
      if (channel != allChannelId) selectChannel(allChannelId);
    }
  }

  /// F-10 휴지통 — 이 화면에서 지운 상품 (앱을 끄면 비워진다)
  void _openTrash(List<Kit> all) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) {
          final gone = all.where((k) => _removed.containsKey(k.id)).toList();
          void restore(Iterable<String> ids, String msg) {
            final list = [...ids];
            final marks = Marks.read(context);
            for (final k in all.where((k) => list.contains(k.id))) {
              _removed[k.id]! ? marks.set(k, owned: true) : marks.set(k, liked: true); // 앱 전체에 다시 켜기
            }
            setState(() => list.forEach(_removed.remove)); // STATE: 복원 → 목록에 다시
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
                              tag: _removed[k.id]! ? '구매함' : '좋아요',
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
  List<Kit> _inTab(List<Kit> all) {
    final ids = scopeIds;
    final marks = Marks.of(context);
    return all.where((k) => (_ownedTab ? marks.owned(k) : marks.liked(k)) && ids.contains(k.franchiseId)).toList();
  }

  List<Kit> _visible(List<Kit> all) {
    _filter.statusOf = Marks.of(context).statusOf;
    return [
      for (final k in _inTab(all))
        if (kitMatches(k, _query) && _filter.matches(k)) k,
    ];
  }

  /// F-12 필터 시트 — 목록: 상품 필터(검색 화면과 같은 시트), 도감: 켜짐
  Future<void> _openFilter(List<Kit> all) async {
    if (_guide) {
      final v = await showLitFilterSheet(context, initial: _lit);
      if (v != null) setState(() => _lit = v); // STATE: 켜짐 필터 → 도감 칸
      return;
    }
    _filter.statusOf = Marks.read(context).statusOf;
    final pool = [
      for (final k in _inTab(all))
        if (kitMatches(k, _query)) k,
    ];
    final picked = await showFilterSheet(context, kits: pool, initial: _filter);
    if (picked != null) setState(() => _filter = picked); // STATE: 필터 → 목록
  }

  Future<void> _deleteSelected() async {
    final n = _selected.length;
    final ok = await showDialog<bool>(
      // F-7 P05
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$n개를 ${_ownedTab ? '구매함' : '좋아요'}에서 삭제할까요?'),
        content: const Text('내 컬렉션에서만 빠져요. 실수로 지웠다면 휴지통(🗑)에서 30일 동안 되살릴 수 있어요.'),
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
    setState(() {
      for (final id in gone) {
        _removed[id] = tab; // STATE: 선택 → 목록에서 빠지고 휴지통으로
      }
      _selected.clear();
      _editing = false;
    });
    if (!mounted) return;
    showToast(
      context,
      '$n개를 삭제했어요',
      onUndo: () {
        apply(true);
        setState(() => gone.forEach(_removed.remove));
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
              final ids = scopeIds;
              final marks = Marks.of(context);
              int count(CollectStatus s) => all
                  .where(
                    (k) => ids.contains(k.franchiseId) && (s == CollectStatus.owned ? marks.owned(k) : marks.liked(k)),
                  )
                  .length;
              return Column(
                children: [
                  _TopRow(
                    wantedCount: count(CollectStatus.wanted),
                    ownedCount: count(CollectStatus.owned),
                    ownedTab: _ownedTab,
                    guide: _guide,
                    onTab: (owned) => setState(() {
                      _ownedTab = owned; // STATE: 탭 → 목록 내용
                      _selected.clear();
                      _editing = false;
                    }),
                    onGuide: (g) => setState(() {
                      _guide = g; // STATE: 보기 방식 → 목록 ↔ 도감
                      _editing = false;
                    }),
                  ),
                  if (!_guide || channel != allChannelId)
                    FindBar(
                      // F-12
                      hint: _guide ? '도감에서 찾기' : (_ownedTab ? '구매함에서 찾기' : '좋아요에서 찾기'),
                      onQuery: (q) => setState(() => _query = q), // STATE: 찾기 → 목록 · 도감
                      filterCount: _guide ? (_lit == LitState.any ? 0 : 1) : _filter.count,
                      onFilter: () => _openFilter(all),
                    ),
                  Expanded(
                    child: _guide
                        ? GuideView(
                            // F-8
                            channel: channel,
                            myChannels: widget.myChannels,
                            onPickChannel: selectChannel,
                            loaders: widget.loaders,
                            query: _query,
                            lit: _lit,
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
    if (kits.isEmpty && (_query.isNotEmpty || _filter.count > 0)) {
      return EmptyView(
        // F-12 찾기 · 필터 결과 없음
        icon: Icons.search_off,
        message: '이 조건의 상품이 없어요',
        action: _filter.count > 0
            ? OutlinedButton(onPressed: () => setState(() => _filter = KitFilter()), child: const Text('필터 초기화'))
            : null,
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
    final total = kits.fold<int>(0, (s, k) => s + (k.priceJpy ?? 0));
    final pieces = kits.length;
    final spent = kits.fold<int>(0, (s, k) => s + (_paid(k) ?? 0)); // 구매함: 내가 낸 돈 합 (기기에 적은 값)
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
                      _ownedTab ? '${kits.length}개 · 지출 합계 ${won(spent)}' : '합계 ${yen(total)} · $pieces개', // F-4 P01
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
                  subtitle: joinDot([channelOf(k.franchiseId).label, k.line, k.series]),
                  leading: _editing
                      ? Icon(
                          _selected.contains(k.id) ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: _selected.contains(k.id) ? Gp.accent : Gp.faint,
                        )
                      : null,
                  onTap: _editing
                      ? () => setState(() => _selected.contains(k.id) ? _selected.remove(k.id) : _selected.add(k.id))
                      : () => openKitDetail(context, k, loaders: widget.loaders),
                  trailing: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (_ownedTab) ...[
                        // 구매함: 내가 낸 돈 (없으면 안내) · 아래에 정가
                        Text(
                          _paid(k) == null ? '구매가 미입력' : won(_paid(k)!),
                          style: TextStyle(
                            fontSize: Gp.t14,
                            fontWeight: _paid(k) == null ? FontWeight.w400 : FontWeight.w600,
                            color: _paid(k) == null ? Gp.faint : Gp.ink,
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

  /// 기기에 적은 구매가 (없으면 상품의 값)
  int? _paid(Kit k) => switch (UserStore.instance.entry(k.id)?['purchase_price']) {
    final num v => v.toInt(),
    _ => k.purchaseKrw,
  };

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
        if (dir == DismissDirection.startToEnd) {
          _ownedTab ? marks.toggleLike(context, k) : marks.toggleOwn(context, k); // STATE: 옮기기 (토스트 되돌리기)
        } else {
          final wasOwned = _ownedTab;
          marks.set(k, liked: false, owned: false); // STATE: 빼기
          showToast(
            context,
            wasOwned ? '구매함에서 뺐어요' : '좋아요에서 뺐어요',
            onUndo: () => wasOwned ? marks.set(k, owned: true) : marks.set(k, liked: true),
          );
        }
        return false; // 목록은 Marks 가 바뀌면 다시 그려진다
      },
      child: row,
    );
  }
}

/// F-2 · F-3 좋아요 | 구매함 탭 + 목록/도감 전환
class _TopRow extends StatelessWidget {
  const _TopRow({
    required this.wantedCount,
    required this.ownedCount,
    required this.ownedTab,
    required this.guide,
    required this.onTab,
    required this.onGuide,
  });

  final int wantedCount;
  final int ownedCount;
  final bool ownedTab;
  final bool guide;
  final ValueChanged<bool> onTab;
  final ValueChanged<bool> onGuide;

  @override
  Widget build(BuildContext context) {
    Widget tab(String label, int n, bool owned) => UnderlineTab(
      // 채널 바와 같은 밑줄 탭
      label: label,
      count: n,
      fontSize: Gp.t16,
      selected: !guide && ownedTab == owned,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      onTap: () {
        onGuide(false);
        onTab(owned);
      },
    );

    Widget icon(IconData i, String tip, bool on, VoidCallback onTap) => IconButton(
      tooltip: tip,
      onPressed: onTap,
      icon: Icon(i, color: on ? Gp.ink : Gp.faint),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 2, 6, 2),
      child: Row(
        children: [
          tab('좋아요', wantedCount, false), // F-2 P06
          tab('구매함', ownedCount, true),
          const Spacer(),
          icon(Icons.view_agenda_outlined, '목록', !guide, () => onGuide(false)), // F-3 P07
          icon(Icons.auto_awesome_mosaic_outlined, '도감', guide, () => onGuide(true)),
        ],
      ),
    );
  }
}
