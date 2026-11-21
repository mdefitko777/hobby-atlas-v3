// 화면 F: 컬렉션 — 좋아요 · 예약 · 구매함 · 도감 (내 것과 내 수집 진행은 여기, 상품 둘러보기는 검색 탭)
//
// ┌──────── 디자인 가이드 대응표: F 컬렉션 ────────────────────────────────────────────┐
// │ 번호 │ Flutter 위젯명                     │ 비즈니스 명칭(한글)                    │ 원칙(P번호)   │
// │ F-1  │ ChannelHeader                      │ 아바타 줄 + 내 채널 바 (C-0 공용)       │ P04 · P06     │
// │ F-2  │ 밑줄 없는 탭 3–4개 (수 없이)          │ 좋아요 · 예약(있을 때만) · 구매함 · 도감 — 아이콘과 한 줄, 글자는 채널 바보다 작게 │ P06 │
// │ F-8  │ 탭 "도감" → GuideView (g_guide_view) │ 내 수집 진행: 작품 · 세대 → 기체 칸 (전부 컬러, ♡ · 리본 표시) │ P01 · P06 │
// │ F-4  │ ListSummary (목록 맨 끝)             │ 상품 수 · 정가 합계(₩ · ¥ 따로) · 구매함 지출 합계 · 예약 결제 예정 (× 수량) │ P01 · P08 │
// │ F-5  │ ListView 줄 (사진 · 이름 · 가격)      │ 컬렉션 목록 → 상품 상세 · 부제 라인 · 작품 (같은 말 한 번) │ P08     │
// │ F-5d │ 예약 탭 줄: 가게 · 도착 · 결제 예정 + 📥 │ 예약 목록 · 도착하면 구매함으로 (밀기도 같음) │ P01 · P03  │
// │ F-6  │ 편집 → 체크박스 + 선택 지우기         │ 정리하기 (편집 모드에서만 지우기 보임)   │ P05 · P03     │
// │ F-7  │ showDialog(확인) → 토스트(되돌리기)   │ 지우기 전 확인 · 바로 되돌리기           │ P05 · P03     │
// │ F-9  │ LoadingView / ErrorView / EmptyView │ 불러오는 중 · 오류 · 빈 컬렉션           │ P01 · P09     │
// │ F-10 │ 🗑 아이콘(개수 배지) → 바텀 시트      │ 휴지통: 지운 상품 복원 (기기 저장 · 30일)  │ P03 · P05     │
// │ F-11 │ jumpTick (서랍 · 내 정보 숫자에서)    │ 좋아요 · 예약 · 구매함 · 도감으로 바로 이동 │ P07           │
// │ F-12 │ ToolRow(leading: 탭 줄, tools:) · CollapsingHeader(step 2) │ 탭 줄 왼쪽 · 「이어 씀 n ×」(CarryNote) · [필터][휴지통][편집] 오른쪽 한 줄 — 다른 탭과 같은 자리 (공유 카드 · ? 는 서랍으로) │ P04 · P07 │
// │ F-13 │ 서랍 › 사용법 (S-19, collectionHelp) │ 필터 · 휴지통 · 편집 · 예약 아이콘 뜻     │ P10 · P01     │
// └──────────────────────────────────────────────────────────────────────────────────┘
// 전환: 줄 → D 상품 상세(쌓기). 빈 상태 "검색하러 가기" → 검색 덮개(쌓기).
// 왜 이렇게: 빨간 "전체 지우기"를 늘 보이지 않게(실수 위험) 편집 모드에서만 지우기, 도감은 따로 된 화면이 아니라 컬렉션의 탭 하나.
// 탭 옆 수 · 목록 위 "7개 · 합계" 줄 · 조립 상태 칸은 뺐다 (2026-11-20 주인: 목록 머리는 조용하게) — 합계는 목록을 다 본 뒤 맨 끝에.
import 'package:flutter/material.dart';

import '../api.dart';
import '../logic/collection_rules.dart';
import '../logic/kit_meta.dart';
import '../logic/kit_rules.dart' show kitPrice, priceTotals;
import '../logic/preorder.dart';
import '../marks.dart';
import '../channels.dart';
import '../data/catalog.dart';
import '../l10n/l10n.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'c_channel_screen.dart';
import 'd_kit_detail_screen.dart';
import 'g_guide_view.dart';
import 'r_mezastar_screen.dart' show TagCollectionSection;

/// 내 정보 숫자를 눌렀을 때 열 곳 (guide = 아래 탭 "도감" — 앱 셸이 탭을 바꾼다)
enum CollectionJump { liked, preorder, owned, guide }

/// 목록 탭: 좋아요 · 예약(좋아요 중 예약 기록이 있는 것) · 구매함
enum _Tab { liked, preorder, owned }

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({
    super.key,
    required this.myChannels,
    required this.onMyChannelsChanged,
    this.channel,
    this.onChannelChanged,
    required this.onGoSearch,
    this.leading,
    this.loaders = const Loaders(),
    this.jump = CollectionJump.liked,
    this.jumpTick = 0,
  });

  final List<String> myChannels;
  final ValueChanged<List<String>> onMyChannelsChanged;

  /// 앱 셸이 든 이 탭의 채널 · 고르면 셸에 알림 (채널 맞춰 보기, ChannelScope)
  final String? channel;
  final ValueChanged<String>? onChannelChanged;
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

  /// F-5 건담 줄 부제의 공식 작품 이름 ([kitWorkName]) — 건담 상품이 목록에 있을 때 한 번 받는다. 받기 전 · 못 받으면 series 이름
  GuideIndex _works = GuideIndex.empty;
  bool _worksAsked = false;

  void _askWorks(List<Kit> kits) {
    if (_worksAsked || !kits.any((k) => k.franchiseId == 'gundam')) return;
    _worksAsked = true;
    widget.loaders.guideIndex().then(
      (i) {
        if (mounted) setState(() => _works = i); // STATE: 도감 작품 이름 → 줄 부제
      },
      onError: (Object _) {}, // 건담 도감이 없는 기기 — series 이름 그대로
    );
  }

  bool _editing = false;
  final Set<String> _selected = {};

  /// F-12 찾기 · 상품 필터
  final _find = KitFind();

  /// F-8 도감 탭을 보고 있나 (좋아요 · 예약 · 구매함 대신)
  bool _guide = false;

  /// F-8 도감 필터 (상품 필터와 같은 모양의 시트 — lib/widgets/guide_filter_sheet.dart)
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
  String? get shellChannel => widget.channel;

  @override
  ValueChanged<String>? get onShellChannel => widget.onChannelChanged;

  @override
  void loadScope(List<String> ids) {
    _future = widget.loaders.kits(ids); // STATE: 내 채널 상품 → 좋아요 · 구매함은 Marks 로 거름 (홈에서 누른 ♡ 도 보임)
  }

  @override
  void initState() {
    super.initState();
    initScope();
  }

  @override
  void didUpdateWidget(CollectionScreen old) {
    super.didUpdateWidget(old);
    syncScope();
    if (widget.jumpTick != old.jumpTick) {
      // STATE: 내 정보 숫자 → 전체 채널 + 그 탭/보기
      _tab = switch (widget.jump) {
        CollectionJump.owned => _Tab.owned,
        CollectionJump.preorder => _Tab.preorder,
        _ => _Tab.liked,
      };
      _guide = widget.jump == CollectionJump.guide;
      _editing = false;
      _selected.clear();
      // 셸도 이 탭을 전체로 바꿔 둔다(_jumpTo) — 여기서 셸에 다시 알리면 셸이 그리는 중에 setState 가 된다
      if (channel != allChannelId) {
        channel = allChannelId;
        reloadScope();
      }
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
                    tr('휴지통'),
                    subtitle: tr('지운 상품은 30일 동안 여기서 복원할 수 있어요'),
                    padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
                    trailing: gone.isEmpty
                        ? null
                        : TextButton(
                            onPressed: () => restore(gone.map((k) => k.id), trf('{n}개를 모두 복원했어요', {'n': gone.length})),
                            child: Text(tr('모두 복원')),
                          ),
                  ),
                  if (gone.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                      child: Text(tr('지운 상품이 없어요'), style: const TextStyle(color: Gp.muted)),
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
                              tag: tr(removed[k.id]! ? '구매함' : '좋아요'),
                              onTap: () => restore([k.id], trf('「{name}」 복원했어요', {'name': k.name})),
                              trailing: Text(
                                tr('복원'),
                                style: const TextStyle(color: Gp.accent, fontWeight: FontWeight.w600),
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
    return [
      for (final k in _inTab(all))
        if (_find.hit(k)) k,
    ];
  }

  /// F-12 필터 시트 — 검색 화면과 같은 상품 필터 (도감 탭이면 도감 필터)
  Future<void> _openFilter(List<Kit> all) async {
    if (_guide) {
      await _guideFilter.openSheet(context); // STATE: 도감 필터 → 칸
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
        title: Text(_ownedTab ? trf('{n}개를 구매함에서 지울까요?', {'n': n}) : trf('{n}개를 좋아요에서 지울까요?', {'n': n})),
        content: Text(tr('내 컬렉션에서만 빠져요 · 🗑 휴지통에서 30일 안에 복원할 수 있어요')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('취소'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('지우기'))),
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
      trf('{n}개를 지웠어요', {'n': n}),
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
                  CollapsingHeader(
                    // 채널 바가 접힌 뒤에도 더 내려 읽으면 이 줄까지 접힌다 (S-13 둘째 겹)
                    step: 2,
                    child: ToolRow(
                      // F-12 탭 줄과 아이콘이 한 줄 — 따로 두면 아이콘만 뜬 빈 띠가 생겼다 (2026-11-21 주인)
                      leading: _TopRow(
                        // F-2
                        hasPreorder: _inTab(all, _Tab.preorder).isNotEmpty,
                        tab: _guide ? null : _tab,
                        onTab: (t) => setState(() {
                          _tab = t; // STATE: 탭 → 목록 내용
                          _guide = false;
                          _selected.clear();
                          _editing = false;
                        }),
                        onGuide: () => setState(() {
                          _guide = true; // STATE: 도감 탭
                          _editing = false;
                        }),
                      ),
                      tools: [
                        // 작품을 바꿔 이어 쓴 조건이 있으면 필터 아이콘 왼쪽에 글자 + × (상품 필터만 — 도감 필터는 따로)
                        if (!_guide)
                          CarryNote(
                            carry: _find.carry,
                            onChanged: (c) => setState(() => _find.apply(c)), // STATE: 이어 쓴 조건 지우기 → 목록
                          ),
                        FilterButton(
                          count: _guide ? _guideFilter.filter.count : _find.filter.count,
                          // 도감 '전체' = 채널 고르기 칸이라 필터가 없다 — 내 채널이 하나면 그 도감이 바로 열려 필터도 된다 (G-1)
                          onTap: _guide && channel == allChannelId && myChannels.length != 1
                              ? null
                              : () => _openFilter(all),
                        ),
                        ToolIcon(
                          // F-10 휴지통 (지운 수 배지)
                          icon: Icons.delete_outline,
                          tip: tr('휴지통'),
                          badge: _removed.length,
                          onTap: () => _openTrash(all),
                        ),
                        if (!_guide)
                          ToolIcon(
                            // F-6 편집 → 체크박스 · 지우기 바 (도감에는 지울 줄이 없다)
                            icon: _editing ? Icons.done : Icons.checklist,
                            tip: tr(_editing ? '완료' : '편집'),
                            onTap: () => setState(() {
                              _editing = !_editing; // STATE: 편집 → 체크박스 · 지우기 바
                              _selected.clear();
                            }),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _guide
                        ? GuideView(
                            // F-8
                            channel: channel,
                            myChannels: widget.myChannels,
                            onPickChannel: selectChannel,
                            loaders: widget.loaders,
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
    if (kits.isEmpty && _find.active) {
      return EmptyView(
        // F-12 찾기 · 필터 결과 없음
        icon: Icons.search_off,
        message: tr('이 조건의 상품이 없어요'),
        action: _find.filter.count > 0
            ? OutlinedButton(onPressed: () => setState(() => _find.filter = KitFilter()), child: Text(tr('필터 초기화')))
            : null,
      );
    }
    if (kits.isEmpty && _tab == _Tab.preorder) {
      return EmptyView(icon: preorderIcon, message: tr('기다리는 예약이 없어요'), detail: tr('상품 상세의 예약 칸에 적으면 여기에 모여요'));
    }
    if (kits.isEmpty) {
      final empty = EmptyView(
        // F-9 P09
        icon: _ownedTab ? Icons.bookmark_added_outlined : Icons.favorite_border, // 구매함 = 리본, 좋아요 = ♡
        message: tr(_ownedTab ? '아직 구매함에 넣은 상품이 없어요' : '아직 좋아요에 담은 상품이 없어요'),
        detail: channel == allChannelId
            ? tr('상품 상세에서 좋아요 · 구매함을 누르면 여기에 모여요')
            : trf('{channel} 채널에는 아직 없어요', {'channel': tr(channelOf(channel).label)}),
        action: _removed.isEmpty
            ? OutlinedButton.icon(
                onPressed: widget.onGoSearch,
                icon: const Icon(Icons.search, size: Gp.iM),
                label: Text(tr('검색하러 가기')),
              )
            : OutlinedButton.icon(
                onPressed: () => _openTrash(all), // 다 지웠어도 휴지통은 열 수 있게
                icon: const Icon(Icons.delete_outline, size: Gp.iM),
                label: Text(trf('휴지통 ({n})', {'n': _removed.length})),
              ),
      );
      // R-11 상품은 없어도 좋아요 · 구매함한 태그 · 픽은 보인다
      final store = Marks.of(context).store;
      final tags = _ownedTab ? store.tagOwned : store.tagLiked;
      if (tags.isEmpty || !TagCollectionSection.showsIn(channel)) return empty;
      return ListView(
        padding: EdgeInsets.only(bottom: navClearance(context)),
        children: [
          SizedBox(height: 280, child: empty),
          TagCollectionSection(owned: _ownedTab, channel: channel),
        ],
      );
    }
    // F-4 합계 × 수량 (좋아요 = 갖고 싶은 수, 구매함 = 보유 수) — 목록 맨 끝에
    final me = Marks.of(context).store;
    // 좋아요 합계: 상품마다 제 나라 정가 하나로 (원 · 엔 따로, 환산하지 않음)
    final total = priceTotals(kits, (k) => me.quantityOf(k.id));
    final pieces = kits.fold<int>(0, (s, k) => s + me.quantityOf(k.id));
    final spent = kits.fold<int>(
      0,
      (s, k) => s + (_paid(k).krw ?? 0) * me.quantityOf(k.id),
    ); // 적은 구매가, 없으면 한국 정가(없으면 일본 정가 × 환율) — 합계에만 (내 정보 총 지출과 같은 셈)
    final pre = {for (final k in kits) k.id: ?me.preorderOf(k.id)};
    final due = pre.values.fold<int>(0, (s, p) => s + p.due);
    final summary = ListSummary(key: const ValueKey('list-summary'), switch (_tab) {
      _Tab.owned => [('$pieces', tr('상품 수')), (won(spent), tr('지출 합계'))],
      _Tab.preorder => [('${kits.length}', tr('예약')), if (due > 0) (won(due), tr('결제 예정'))],
      _Tab.liked => [
        ('$pieces', tr('상품 수')),
        if (total.krw > 0) (wonSign(total.krw), tr('정가 합계')),
        if (total.jpy > 0) (yen(total.jpy), tr('정가 합계')),
      ],
    });
    _askWorks(kits);
    final mixed = channel == allChannelId; // 한 채널만 보면 채널 이름은 채널 바에 이미 있다
    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.only(bottom: navClearance(context) + (_editing ? 60 : 0)),
          children: [
            const SizedBox(height: 4),
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
                  tag: _tab == _Tab.liked && (pre[k.id]?.active ?? false) ? tr('예약') : '',
                  tagColor: Gp.reserve,
                  subtitle: _tab == _Tab.preorder
                      ? joinDot([
                          pre[k.id]?.shop ?? '',
                          if (pre[k.id]?.arrival case final a? when a.isNotEmpty)
                            trf('{date} 도착', {'date': arrivalLabel(a)}),
                        ])
                      : joinDot([
                          if (me.quantityOf(k.id) > 1) '×${me.quantityOf(k.id)}', // D-7 수량
                          kitMetaLine(k, work: kitWorkName(k, _works), channel: mixed),
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
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (_ownedTab) ...[
                              // 구매함: 적은 구매가, 안 적었으면 정가 그대로 (₩ · ¥, 환산한 ≈ 값은 보이지 않는다)
                              switch (_paid(k)) {
                                (krw: null, estimate: _) => Text(
                                  tr('구매가 미입력'),
                                  style: const TextStyle(fontSize: Gp.t14, color: Gp.faint),
                                ),
                                (krw: _, estimate: true) => KitPriceLines(
                                  k,
                                  style: const TextStyle(fontSize: Gp.t14, color: Gp.faint),
                                ),
                                (krw: final int w, estimate: false) => Text(
                                  won(w),
                                  style: const TextStyle(fontSize: Gp.t14, fontWeight: FontWeight.w600),
                                ),
                              },
                              if (!_paid(k).estimate)
                                Text(
                                  trf('정가 {money}', {'money': kitPrice(k)}),
                                  style: const TextStyle(fontSize: Gp.t11, color: Gp.faint),
                                ),
                            ] else
                              KitPriceLines(k),
                          ],
                        ),
                ),
              ),
            summary, // F-4 다 본 뒤에 합계
            // R-11 메자스타 · 프렌다 태그 (전체 · 포켓몬 채널, r_mezastar_screen.dart)
            if (_tab != _Tab.preorder) TagCollectionSection(owned: _ownedTab, channel: channel),
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
                  child: Text(tr(_selected.length == kits.length ? '모두 해제' : '모두 선택')),
                ),
                const Spacer(),
                OutlinedButton(
                  onPressed: _selected.isEmpty ? null : _deleteSelected, // F-6 P05
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Gp.panel,
                    foregroundColor: Gp.danger,
                    side: BorderSide(color: _selected.isEmpty ? Gp.line : Gp.danger),
                  ),
                  child: Text(trf('지우기 ({n})', {'n': _selected.length})),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// F-5d 예약 탭 줄 오른쪽: 총액 · 결제 예정(없으면 결제 완료) + 📥 도착
  Widget _preTrailing(Kit k, Preorder? p) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (p?.price case final v?)
            Text(
              won(v),
              style: const TextStyle(fontSize: Gp.t14, fontWeight: FontWeight.w600),
            )
          else
            KitPriceLines(
              k,
              style: const TextStyle(fontSize: Gp.t14, fontWeight: FontWeight.w600),
            ),
          // 작은 폰(320)에서 「결제 예정 123,456원」 이 이름 칸을 밀어내지 않게 — 넘치면 글자만 줄인다
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 128),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                (p?.due ?? 0) > 0
                    ? trf('결제 예정 {money}', {'money': won(p!.due)})
                    : tr(p?.paid ?? false ? '결제 완료' : '미결제'),
                style: TextStyle(fontSize: Gp.t11, color: (p?.due ?? 0) > 0 ? Gp.reserve : Gp.faint),
              ),
            ),
          ),
        ],
      ),
      if (!_editing)
        IconButton(
          tooltip: tr('도착했어요'),
          onPressed: () => markPreorderArrived(context, k),
          icon: const Icon(arrivedIcon, size: Gp.iM, color: Gp.reserve),
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
          ? bg(Gp.accent, Icons.favorite, tr('좋아요로'), Alignment.centerLeft)
          : bg(Gp.own, Icons.bookmark, tr('구매함으로'), Alignment.centerLeft),
      secondaryBackground: bg(Gp.danger, Icons.delete_outline, tr('빼기'), Alignment.centerRight),
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
            tr(wasOwned ? '구매함에서 뺐어요' : '좋아요에서 뺐어요'),
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

/// F-2 좋아요 | 예약 | 구매함 | 도감 탭 (수 없이 — 합계는 목록 맨 끝). 예약 탭은 예약이 있거나 고른 때만. [tab] null = 도감.
/// 채널 바보다 작은 글자 · 밑줄 없이 — 한 화면에 밑줄은 채널 바에만 (2026-11-21 주인)
class _TopRow extends StatelessWidget {
  const _TopRow({required this.hasPreorder, required this.tab, required this.onTab, required this.onGuide});

  final bool hasPreorder;
  final _Tab? tab;
  final ValueChanged<_Tab> onTab;
  final VoidCallback onGuide;

  @override
  Widget build(BuildContext context) {
    // 첫 탭 글자는 채널 바 글자와 같은 자리 (ToolRow 가 왼쪽 16 을 준다 — 둘러보기 탭 줄과 같게)
    Widget one(String label, _Tab t, {bool first = false}) => UnderlineTab(
      key: ValueKey('tab-${t.name}'),
      label: label,
      fontSize: 13,
      underline: false,
      selected: tab == t,
      padding: EdgeInsets.fromLTRB(first ? 0 : 8, 8, 8, 8),
      onTap: () => onTab(t),
    );

    // 작은 폰(320) · 큰 글씨에서 탭 네 개가 넘치면 옆으로 밀어 본다 (왼쪽 정렬 그대로).
    // 옆 여백은 ToolRow 가 가지므로 여기서는 위아래만
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          one(tr('좋아요'), _Tab.liked, first: true), // F-2 P06
          if (hasPreorder || tab == _Tab.preorder) one(tr('예약'), _Tab.preorder),
          one(tr('구매함'), _Tab.owned),
          UnderlineTab(
            // F-8 도감 (내 진행은 칸으로)
            key: const ValueKey('tab-guide'),
            label: tr('도감'),
            fontSize: 13,
            underline: false,
            selected: tab == null,
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            onTap: onGuide,
          ),
        ],
      ),
    );
  }
}

/// F-13 사용법의 "컬렉션" 묶음 (서랍 › 사용법 — s_app_shell.dart). 도감 칸 · 아이콘은 도감 묶음에
List<HelpItem> collectionHelp() => [
  HelpItem(Icons.tune, tr('필터')),
  HelpItem(Icons.delete_outline, tr('휴지통 (30일 동안 복원)')),
  HelpItem(Icons.checklist, tr('편집 (골라서 지우기)')),
  ...kitProgressHelp(), // 예약 · 도착
];
