// 화면 H: 캘린더 — 내 채널의 발매일 · 공식 예고를 달력으로
//
// ┌──────── 디자인 가이드 대응표: H 캘린더 ────────────────────────────────────────────┐
// │ 번호 │ Flutter 위젯명                     │ 비즈니스 명칭(한글)                    │ 원칙(P번호)   │
// │ H-1  │ ChannelHeader                      │ 아바타 줄 + 내 채널 바 (C-0 공용)       │ P04 · P06     │
// │ H-2  │ ‹ 2026년 10월 › + 오늘              │ 한 주 · 한 달 넘기기 · 오늘              │ P03 · P07     │
// │ H-3  │ 7열 달력 한 주 줄 + 날짜 아래 점 (뜻은 H-12) │ 파랑 = 내 좋아요 · 예약 상품 · 회색 = 그 밖의 일정 │ P01 · P06 │
// │ H-3c │ "한 달 보기" 손잡이 (누르기 · 밀기)    │ 한 주 ↔ 한 달 격자 펴고 접기 (애니메이션, 기억) │ P03 · P07 │
// │ H-9  │ ViewIconToggle 전체 · 내 일정        │ 좋아요 · 구매함 상품의 날짜만            │ P06           │
// │ H-9b │ 내 일정: 예약 도착 · 재판매 · PB 마감 · 구매 │ 예약한 상품 도착 예정 · 좋아요 상품 재판매 (둘째 줄 상태) │ P01 · P06 │
// │ H-9c │ ListSummary (내 일정 목록 맨 끝)      │ 이번 달 결제 예정: 이 달 도착 예정인 미결제 예약 합 │ P01      │
// │ H-11 │ ToolRow (달력 위, 상자 없는 아이콘 줄) │ 상품 필터 + 전체 일정 · 내 일정 (점 · 목록이 같이 좁혀짐) │ P04 · P07 │
// │ H-3b │ 전체 · 발매 · 예고 밑줄 탭            │ 일정 종류 거르기                        │ P06 · P07     │
// │ H-4  │ 날짜 누르기 (다시 누르면 해제)        │ 한 주: 목록을 그날로 옮기기 · 한 달: 그날만 보기 / 한 달 전체 보기 │ P03 │
// │ H-5  │ 날짜별 묶음 ThumbRow: 점(titleLead) · 제목 2줄 + "상태 · 출처/라인" + D-n │ 발매 · 예고 단계 (알약 없이 둘째 줄 옅은 글자) │ P01 · P02 │
// │ H-5b │ 예고 줄 둘째 줄 "21:00 라이브 · 출처"  │ 공식 라이브 — 발표일이 아니라 방송하는 날에 (시간 미정은 없음) │ P01 │
// │ H-5c │ 예고 줄 둘째 줄 "18:00 예약 시작 · 출처" │ 예약 때를 아는 예고 — 발표일이 아니라 예약이 열리는 날에 │ P01 │
// │ H-6  │ "날짜 미정 · n월 중" 묶음            │ 날짜가 정해지지 않은 발매               │ P01 · P10     │
// │ H-7  │ LayoutBuilder ≥720dp                │ 넓은 화면: 달력 왼쪽 · 목록 오른쪽       │ 적응형        │
// │ H-8  │ LoadingView / ErrorView / EmptyView │ 불러오는 중 · 오류 · 이 달 일정 없음     │ P01 · P09     │
// │ H-12 │ 서랍 › 사용법 (S-19, calendarHelp)   │ 아이콘 뜻 + 점 색                        │ P10 · P01     │
// └──────────────────────────────────────────────────────────────────────────────────┘
// 전환: 발매 줄 → D 상품 상세(쌓기). 예고 · 라이브 줄 → J 공식 예고 상세(쌓기).
// 왜 이렇게: 발매 정보를 목록 한구석이 아니라 날짜로 보게. 처음엔 한 주만 (목록이 위로 — 2026-11-20 주인), 달 격자는 손잡이로.
// 한 주일 때는 달력 · 종류 탭이 위에 남고 목록은 고른 날 · 오늘(이 주) · 그 주 첫날부터 (2026-11-20 주인: 한 주로 접었는데
//   목록이 1일부터라 이번 주를 찾아 내려야 했다). 그 주의 날을 누르면 목록이 그날로 간다 — 지난 날은 위로 밀면 보인다.
// 점 색은 둘뿐: 내 좋아요 · 예약 상품 = 파랑, 그 밖 = 회색 (예고 · 발매 · 재판매 … 색을 따로 외우지 않게, 종류는 줄 둘째 줄 글자로).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../api.dart';
import '../channels.dart';
import '../l10n/l10n.dart';
import '../logic/announcement_match.dart';
import '../logic/data_labels.dart';
import '../logic/kit_rules.dart' show kitPrice;
import '../logic/live_stream.dart';
import '../logic/preorder_open.dart';
import '../logic/restock.dart';
import '../marks.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'c_channel_screen.dart';
import 'd_kit_detail_screen.dart';
import '../logic/kit_meta.dart';
import 'j_announcement_screen.dart';
import '../clock.dart';

/// 프로토타입의 오늘
DateTime get calendarToday {
  final n = appNow();
  return DateTime(n.year, n.month, n.day);
}

List<String> get _weekdays =>
    byLang(ko: const ['일', '월', '화', '수', '목', '금', '토'], zh: const ['日', '一', '二', '三', '四', '五', '六']);

/// 달력 한 줄의 일정 (발매 상품 또는 예고)
class _Event {
  const _Event({
    required this.title,
    required this.image,
    required this.sub,
    this.kit,
    this.ann,
    this.day,
    this.mine = false,
    this.tag = '',
    this.due = 0,
    this.time = '',
  });

  /// 라이브 · 예약 시작 줄: 시각 '21:00' (상태 글 앞에 붙는다)
  final String time;

  /// 예약 도착 줄: 결제 예정 (원)
  final int due;

  /// 내 좋아요 · 예약 상품 → 파랑 점, 그 밖 → 회색 점 (달력 · 줄 같은 뜻)
  final bool mine;

  /// 상태 글 (비면 발매 / 예고 단계) — 한국어 그대로 비교에 쓰고, 보일 때 tr
  final String tag;
  final String title;
  final String image;
  final String sub;

  /// 발매 상품 (확정된 발매일)
  final Kit? kit;

  /// 예고 (공식 · 비공식)
  final Announcement? ann;

  bool get isRelease => kit != null;

  /// null = 날짜 미정(그 달 중)
  final int? day;
}

class _CalData {
  const _CalData(this.kits, this.announcements, [this.restocks = RestockIndex.empty]);
  final List<Kit> kits;
  final List<Announcement> announcements;

  /// 재판매 소식 (파일이 없으면 빈 묶음)
  final RestockIndex restocks;
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    super.key,
    required this.myChannels,
    required this.onMyChannelsChanged,
    this.channel,
    this.onChannelChanged,
    this.leading,
    this.loaders = const Loaders(),
  });

  final List<String> myChannels;
  final ValueChanged<List<String>> onMyChannelsChanged;

  /// 앱 셸이 든 이 탭의 채널 · 고르면 셸에 알림 (채널 맞춰 보기, ChannelScope)
  final String? channel;
  final ValueChanged<String>? onChannelChanged;
  final Widget? leading;
  final Loaders loaders;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

/// 달력 격자 한 줄(일요일 시작) — 이 달 [day] 일이 몇째 줄인가 · 이 달은 몇 줄인가
int _rowOf(DateTime month, int day) => (DateTime(month.year, month.month).weekday % 7 + day - 1) ~/ 7;
int _rowsOf(DateTime month) => _rowOf(month, DateTime(month.year, month.month + 1, 0).day) + 1;

class _CalendarScreenState extends State<CalendarScreen> with ChannelScope, SingleTickerProviderStateMixin {
  late Future<_CalData> _future;
  DateTime _month = DateTime(calendarToday.year, calendarToday.month);
  int? _day;

  /// H-3 접었을 때 보이는 한 주 (이 달 격자의 몇째 줄) — 처음은 오늘이 든 주
  int _row = _rowOf(calendarToday, calendarToday.day);

  /// H-3c 0 = 한 주 · 1 = 한 달 격자 (손잡이를 밀면 그 사이)
  late final AnimationController _open = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));

  /// 손잡이가 가는 쪽 (애니메이션 중에도 글 · ‹ › 뜻이 흔들리지 않게 값과 따로)
  /// 처음 값은 기기에 기억한 것 (local_state calendar_month_open, 처음 설치는 한 주) — initState 에서 읽는다
  bool _monthOpen = false;

  /// 0 = 전체 · 1 = 발매 · 2 = 예고
  int _kind = 0;

  /// 전체 / 내 일정 (좋아요 · 구매함 상품의 날짜만)
  bool _mine = false;

  /// H-11 상품 필터. 필터를 고르면 상품 일정만 (예고에는 종류 · 가격 같은 값이 없다)
  final _find = KitFind();

  /// H-4 한 주일 때 따로 밀리는 목록 · 그 목록의 기준 날 머리 · 마지막으로 맞춘 기준 (같으면 다시 옮기지 않는다 —
  /// 좋아요를 눌러 다시 그려도 내가 내린 자리가 튀지 않게)
  final _listCtrl = ScrollController();
  final _anchorKey = GlobalKey();
  String _anchorFor = '';

  /// 이번 그리기에서 기준 날 이후 머리가 있었나 (없으면 목록 끝으로)
  bool _anchorPlaced = false;

  /// 날짜를 골라 그날만 보는 것은 한 달일 때만 — 한 주일 때 고른 날은 목록 자리만 옮긴다
  int? get _filterDay => _monthOpen ? _day : null;

  /// 한 주 목록이 시작할 날: 고른 날 → 이 주에 든 오늘 → 그 주 첫날 (달이 걸친 주는 1일)
  int get _anchorDay {
    if (_day case final d?) return d;
    final today = calendarToday;
    if (today.year == _month.year && today.month == _month.month && _rowOf(_month, today.day) == _row) return today.day;
    return math.max(1, _row * 7 - DateTime(_month.year, _month.month).weekday % 7 + 1);
  }

  /// 예고는 필터 값(종류 · 가격 …)이 없다 — 필터를 고르면 상품 일정만
  bool get _showAnns => _find.filter.count == 0;

  Future<void> _openFilter(_CalData d) async {
    if (await _find.openFilter(context, d.kits)) setState(() {}); // STATE: 필터 → 달력 점 · 목록
  }

  @override
  List<String> get myChannels => widget.myChannels;

  @override
  String? get shellChannel => widget.channel;

  @override
  ValueChanged<String>? get onShellChannel => widget.onChannelChanged;

  @override
  void loadScope(List<String> ids) {
    // STATE: 채널 → 상품 · 공식 예고 → 달력 점 · 일정 목록
    _future = Future.wait([
      widget.loaders.kits(ids),
      widget.loaders.announcements(ids),
      widget.loaders.restocks().catchError((Object _) => RestockIndex.empty),
    ]).then((r) => _CalData(r[0] as List<Kit>, r[1] as List<Announcement>, r[2] as RestockIndex));
  }

  @override
  void initState() {
    super.initState();
    _monthOpen = Marks.maybeRead(context)?.store.calendarMonthOpen ?? false;
    _open.value = _monthOpen ? 1 : 0;
    initScope();
  }

  @override
  void dispose() {
    _open.dispose();
    _listCtrl.dispose();
    super.dispose();
  }

  /// H-4 한 주 목록을 기준 날 머리로 — 그 머리가 아직 안 그려졌으면(멀리 아래) 한 화면씩 내려 가며 찾는다.
  /// [key] 가 지난번과 같으면 하지 않는다. 같은 주에서 날만 바꾼 것이면 부드럽게
  void _keepAnchor(String key, String week) {
    if (key == _anchorFor) return;
    final animate = _anchorFor.startsWith('$week|');
    _anchorFor = key;
    var tries = 0;
    void step(Duration _) {
      if (!mounted || !_listCtrl.hasClients) return;
      final pos = _listCtrl.position;
      if (_anchorKey.currentContext case final ctx?) {
        Scrollable.ensureVisible(
          ctx,
          duration: animate ? const Duration(milliseconds: 250) : Duration.zero,
          curve: Curves.easeOutCubic,
        );
        return;
      }
      if (!_anchorPlaced) return _listCtrl.jumpTo(pos.maxScrollExtent); // 기준 날 뒤로 일정이 없으면 끝(가장 늦은 일정)으로
      if (pos.pixels >= pos.maxScrollExtent || ++tries > 60) return;
      _listCtrl.jumpTo(math.min(pos.pixels + pos.viewportDimension, pos.maxScrollExtent));
      WidgetsBinding.instance.addPostFrameCallback(step);
    }

    WidgetsBinding.instance.addPostFrameCallback(step);
  }

  @override
  void didUpdateWidget(CalendarScreen old) {
    super.didUpdateWidget(old);
    syncScope();
  }

  /// 그 달에서 처음 보일 주 — 이번 달이면 오늘이 든 주, 다른 달이면 첫 주
  int _firstRow(DateTime month) =>
      month.year == calendarToday.year && month.month == calendarToday.month ? _rowOf(month, calendarToday.day) : 0;

  void _moveMonth(int delta) => setState(() {
    _month = DateTime(_month.year, _month.month + delta); // STATE: 달 → 달력 · 목록
    _row = _firstRow(_month);
    _day = null;
  });

  /// H-2 한 주 넘기기 — 달 끝을 넘으면 옆 달의 첫 · 끝 주 (달이 걸친 주는 두 달에 한 줄씩, 펴 본 격자와 같은 줄)
  void _moveWeek(int delta) => setState(() {
    final r = _row + delta;
    if (r < 0) {
      _month = DateTime(_month.year, _month.month - 1); // STATE: 주 → 달력 · 목록
      _row = _rowsOf(_month) - 1;
    } else if (r >= _rowsOf(_month)) {
      _month = DateTime(_month.year, _month.month + 1);
      _row = 0;
    } else {
      _row = r;
    }
    _day = null;
  });

  void _move(int delta) => _monthOpen ? _moveMonth(delta) : _moveWeek(delta);

  /// H-3c 손잡이를 놓거나 눌렀을 때 — 펴기 · 접기 끝까지, 기억
  void _settleOpen(bool open) {
    _open.animateTo(open ? 1 : 0, curve: Curves.easeOutCubic);
    Marks.maybeRead(context)?.store.setCalendarMonthOpen(open);
    if (open) _anchorFor = ''; // 다시 접으면 새 한 주 목록을 기준 날로
    setState(() => _monthOpen = open); // STATE: 한 주 / 한 달 (기억) → 손잡이 글 · ‹ › 뜻
  }

  /// 이 달의 일정 — 'yyyy-mm-dd' 는 그날, 'yyyy-mm' 은 날짜 미정
  List<_Event> _events(_CalData d, Marks marks) {
    final ym = monthKey(_month);
    int? dayOf(String date) => date.length >= 10 ? int.tryParse(date.substring(8, 10)) : null;
    _find.filter.statusOf = marks.statusOf;
    if (_mine) {
      final me = marks.store;
      final out = <_Event>[];
      for (final k in d.kits) {
        final st = marks.statusOf(k);
        if (st == CollectStatus.none || !_find.hit(k)) continue;
        if (st == CollectStatus.wanted && k.pbCloses.startsWith(ym)) {
          out.add(
            _Event(
              title: k.name,
              image: k.image,
              sub: dataLabel(k.line),
              kit: k,
              day: dayOf(k.pbCloses),
              mine: true,
              tag: 'PB 예약 마감',
            ),
          );
        }
        if (k.date.startsWith(ym)) {
          out.add(
            _Event(
              title: k.name,
              image: k.image,
              sub: joinDot([dataLabel(k.line), kitPrice(k)]),
              kit: k,
              day: dayOf(k.date),
              mine: st == CollectStatus.wanted,
            ),
          );
        }
        // H-9b 예약 도착 예정 (하루까지 정하지 않았으면 날짜 미정)
        final pre = me.preorderOf(k.id);
        if (st == CollectStatus.wanted && pre != null && pre.active && pre.arrivalMonth == ym) {
          out.add(
            _Event(
              title: k.name,
              image: k.image,
              sub: joinDot([
                pre.shop,
                pre.due > 0 ? trf('결제 예정 {money}', {'money': won(pre.due)}) : (pre.paid ? tr('결제 완료') : ''),
              ]),
              kit: k,
              day: dayOf(pre.arrival),
              mine: true,
              tag: '예약',
              due: pre.due,
            ),
          );
        }
        // H-9b 좋아요한 상품의 재판매 (지난 것 · 쌓인 것은 빼고)
        if (st == CollectStatus.wanted) {
          for (final e in d.restocks.inMonth([k.id], _month)) {
            out.add(
              _Event(
                title: k.name,
                image: k.image,
                sub: joinDot([tr(e.label), if (e.dateEstimated) tr('추정 날짜')]),
                kit: k,
                day: e.day,
                mine: true,
                tag: '재판매',
              ),
            );
          }
        }
        final at = DateTime.tryParse('${me.entry(k.id)?['updated_at'] ?? ''}')?.toLocal();
        if (st == CollectStatus.owned && at != null && at.year == _month.year && at.month == _month.month) {
          out.add(
            _Event(
              title: k.name,
              image: k.image,
              sub: kitMetaLine(k, channel: false), // 라인 · 작품 (같은 말 한 번 — 컬렉션 줄과 같게)
              kit: k,
              day: at.day,
              tag: '구매',
            ),
          );
        }
      }
      return out;
    }
    return [
      for (final k in d.kits)
        if (k.date.startsWith(ym) && _find.hit(k))
          _Event(
            title: k.name,
            image: k.image,
            sub: joinDot([
              if (channel == allChannelId) tr(channelOf(k.franchiseId).label), // 한 채널이면 채널 바에 이미 있다
              dataLabel(k.line),
              kitPrice(k),
            ]),
            kit: k,
            day: dayOf(k.date),
            mine: marks.liked(k),
          ),
      for (final a in d.announcements)
        // H-5b 라이브는 방송하는 날에 (시간 미정이면 announcementDay 가 비어 캘린더에 없다), 예약은 열리는 날에
        if (announcementDay(a) case final date when date.startsWith(ym) && _showAnns)
          if (annLiveStage(a, appNow()) case final stage?)
            _Event(
              title: a.title,
              image: a.image,
              sub: sourceLabel(a.source),
              ann: a,
              day: dayOf(date),
              tag: stage == LiveStage.ended ? '다시보기' : (stage == LiveStage.live ? '라이브 중' : '라이브'),
              time: stage == LiveStage.ended ? '' : liveClock(a.liveAt!),
            )
          // H-5c 예약 때를 아는 예고는 예약이 열리는 날에 "18:00 예약 시작" (시각을 모르면 "예약 시작"만)
          else if (annPreorderStage(a, appNow()) case final pre?)
            _Event(
              title: a.title,
              image: a.image,
              sub: sourceLabel(a.source),
              ann: a,
              day: dayOf(date),
              tag: pre == PreorderStage.closed ? '예약 마감' : '예약 시작',
              time: a.preorderAt == null || pre == PreorderStage.closed ? '' : liveClock(a.preorderAt!),
            )
          else
            _Event(title: a.title, image: a.image, sub: sourceLabel(a.source), ann: a, day: dayOf(date)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ChannelHeader(
          // H-1 P04
          leading: widget.leading,
          myChannels: widget.myChannels,
          selected: channel,
          onSelect: selectChannel,
          onMyChannelsChanged: widget.onMyChannelsChanged,
        ),
        Expanded(
          child: FutureBuilder<_CalData>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return const LoadingView(); // H-8
              if (snap.hasError) {
                return ErrorView(message: '${snap.error}', onRetry: () => setState(reloadScope));
              }
              final events = _events(snap.data!, Marks.of(context));
              // H-3 날짜 점: 내 좋아요 · 예약 상품이 있으면 파랑, 다른 일정이 있으면 회색 (둘 다면 둘)
              final dots = <int, Set<Color>>{};
              for (final e in events) {
                if (e.day case final d?) (dots[d] ??= {}).add(e.mine ? Gp.accent : Gp.muted);
              }
              final calendar = GestureDetector(
                // H-10 달력 위에서 좌우로 밀면 넘기기 (접혀 있으면 한 주, 펴져 있으면 한 달)
                behavior: HitTestBehavior.translucent,
                onHorizontalDragEnd: (d) {
                  final v = d.primaryVelocity ?? 0;
                  if (v < -250) _move(1);
                  if (v > 250) _move(-1);
                },
                child: _MonthCalendar(
                  month: _month,
                  row: _row,
                  open: _open,
                  monthOpen: _monthOpen,
                  selected: _day,
                  dots: dots,
                  onPrev: () => _move(-1),
                  onNext: () => _move(1),
                  onToday: () => setState(() {
                    _month = DateTime(calendarToday.year, calendarToday.month);
                    _row = _firstRow(_month);
                    _day = null;
                  }),
                  // H-4 STATE: 날짜 → 목록 · 접으면 그 주
                  onPick: (d) => setState(() {
                    _day = _day == d ? null : d;
                    _row = _rowOf(_month, d);
                  }),
                  onSettle: _settleOpen,
                ),
              );
              return LayoutBuilder(
                builder: (context, box) {
                  final wide = box.maxWidth >= 720;
                  if (!_monthOpen) {
                    // H-4 한 주: 목록을 기준 날로 (주 · 날 · 거르기가 바뀔 때만)
                    final week = '${monthKey(_month)}/$_row/$wide';
                    _keepAnchor(
                      [week, _day, _kind, _mine, _find.filter.count, channel, identityHashCode(snap.data)].join('|'),
                      week,
                    );
                  }
                  if (wide) {
                    // H-7 넓은 화면
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 380,
                          child: SingleChildScrollView(child: Column(children: [_tabs(snap.data!), calendar])),
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(
                          child: ListView(controller: _listCtrl, children: [if (!_mine) _kinds(), ..._list(events)]),
                        ),
                      ],
                    );
                  }
                  if (!_monthOpen) {
                    // H-4 한 주: 아이콘 줄 · 달력 · 종류 탭은 위에 남고 목록만 밀린다 (작은 화면에서 펴는 중이면 위쪽도 밀린다)
                    return Column(
                      children: [
                        ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: box.maxHeight * 0.75),
                          child: SingleChildScrollView(
                            child: Column(children: [_tabs(snap.data!), calendar, if (!_mine) _kinds()]),
                          ),
                        ),
                        Expanded(
                          child: ListView(
                            key: const ValueKey('calendar-week-list'),
                            controller: _listCtrl,
                            padding: EdgeInsets.only(bottom: navClearance(context)),
                            children: _list(events),
                          ),
                        ),
                      ],
                    );
                  }
                  return ListView(
                    padding: EdgeInsets.only(bottom: navClearance(context)),
                    children: [_tabs(snap.data!), calendar, if (!_mine) _kinds(), ..._list(events)],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// H-11 필터 + 전체 / 내 일정 (다른 탭의 아이콘 줄과 같은 자리, 검색창 없이)
  Widget _tabs(_CalData d) => ToolRow(
    tools: [
      FilterButton(count: _find.filter.count, onTap: () => _openFilter(d)),
      ViewIconToggle(
        mine: _mine,
        onChanged: (v) => setState(() => _mine = v), // STATE: 전체 일정 ↔ 내 일정
        allIcon: Icons.calendar_month_outlined,
        allTip: tr('전체 일정'),
        mineTip: tr('내 일정'),
      ),
    ],
  );

  /// H-9c 이번 달 결제 예정 — 이 달에 도착 예정인 미결제 예약 (내 일정에서만, 날짜를 골라도 한 달 전체). 목록 맨 끝에
  Widget? _dueSummary(List<_Event> all) {
    final dues = all.where((e) => e.tag == '예약' && e.due > 0).toList();
    if (!_mine || dues.isEmpty) return null;
    return ListSummary(key: const ValueKey('month-due'), [
      (won(dues.fold<int>(0, (s, e) => s + e.due)), trf('{m}월 결제 예정', {'m': _month.month})),
      ('${dues.length}', tr('예약')),
    ]);
  }

  /// H-3b 종류 거르기 (내 일정에서는 없음)
  Widget _kinds() => Padding(
    padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
    child: Row(
      children: [
        for (final (i, label) in ['전체', '발매', '예고'].indexed)
          UnderlineTab(
            label: tr(label),
            selected: _kind == i,
            onTap: () => setState(() => _kind = i), // STATE: 종류 → 목록
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          ),
      ],
    ),
  );

  /// 일정 목록 (종류 탭 아래). 한 주일 때는 기준 날([_anchorDay]) 이후 첫 머리에 [_anchorKey]
  List<Widget> _list(List<_Event> all) {
    final due = _dueSummary(all);
    final day = _filterDay;
    final inDay = day == null ? all : all.where((e) => e.day == day).toList();
    final shown = _mine ? inDay : inDay.where((e) => _kind == 0 || (_kind == 1) == e.isRelease).toList();
    _anchorPlaced = false;
    if (shown.isEmpty) {
      return [
        EmptyView(
          // H-8 P09
          icon: Icons.event_busy_outlined,
          message: _find.active
              ? tr('이 조건의 일정이 없어요')
              : _mine
              ? trf('{m}월에는 좋아요 · 구매함 상품의 일정이 없어요', {'m': _month.month})
              : (day == null
                    ? trf('{m}월에는 발매 · 예고 일정이 없어요', {'m': _month.month})
                    : trf('{m}월 {d}일에는 일정이 없어요', {'m': _month.month, 'd': day})),
          detail: day == null ? tr('다른 달로 넘기거나 채널을 바꿔 보세요') : tr('날짜를 다시 누르면 한 달 전체를 봐요'),
        ),
        ?due,
      ];
    }
    final days = (shown.map((e) => e.day).nonNulls.toSet().toList())..sort();
    final undated = shown.where((e) => e.day == null).toList();
    // H-4 한 주: 기준 날 이후 첫 머리 (없으면 날짜 미정 머리, 그것도 없으면 목록 끝으로)
    final anchor = _monthOpen ? null : days.where((d) => d >= _anchorDay).firstOrNull;
    final anchorUndated = !_monthOpen && anchor == null && undated.isNotEmpty;
    _anchorPlaced = anchor != null || anchorUndated;
    return [
      if (day != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            trf('{m}월 {d}일만 보는 중 · 날짜를 다시 누르면 한 달 전체', {'m': _month.month, 'd': day}),
            style: const TextStyle(color: Gp.muted, fontSize: Gp.t12),
          ),
        ),
      for (final d in days) ...[
        _DayHeader(key: d == anchor ? _anchorKey : null, date: DateTime(_month.year, _month.month, d)), // H-5
        for (final e in shown.where((e) => e.day == d))
          _EventRow(key: _rowKey(e), event: e, dday: e.tag == '구매' ? '' : _dday(d), loaders: widget.loaders),
      ],
      if (undated.isNotEmpty) ...[
        SectionHeader(
          key: anchorUndated ? _anchorKey : null,
          tr('날짜 미정'),
          subtitle: trf('{m}월 중', {'m': _month.month}),
          padding: const EdgeInsets.fromLTRB(16, 20, 12, 8),
        ), // H-6
        for (final e in undated) _EventRow(key: _rowKey(e), event: e, dday: '', loaders: widget.loaders),
      ],
      ?due, // H-9c 다 본 뒤에 합계
    ];
  }

  /// 예고 줄은 한 번씩만 나온다 → 테스트가 id 로 찾게. 상품은 한 달에 여러 줄(PB 마감 · 발매 · 예약 도착)이라 키 없이
  Key? _rowKey(_Event e) => switch (e.ann) {
    final a? => ValueKey('event-${a.id}'),
    _ => null,
  };

  /// D-n · D-DAY · 지난 날짜는 빈칸
  String _dday(int d) {
    final diff = DateTime(_month.year, _month.month, d).difference(calendarToday).inDays;
    if (diff == 0) return 'D-DAY';
    return diff > 0 ? 'D-$diff' : '';
  }
}

/// H-2 · H-3 달력 — 접으면 한 주 줄, 손잡이(H-3c)로 한 달 격자까지 펴고 접는다
class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.month,
    required this.row,
    required this.open,
    required this.monthOpen,
    required this.selected,
    required this.dots,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
    required this.onPick,
    required this.onSettle,
  });

  final DateTime month;

  /// 접었을 때 보이는 주 (격자 몇째 줄)
  final int row;

  /// 0 = 한 주 · 1 = 한 달 (밀면 그 사이)
  final AnimationController open;

  /// 손잡이가 가는 쪽 — ‹ › 가 주인지 달인지 · 손잡이 글
  final bool monthOpen;
  final int? selected;

  /// 날짜 → 그날 점 색들 (글자 범례 없이 색으로, 뜻은 위 줄 ? 에 — calendarHelp)
  final Map<int, Set<Color>> dots;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final ValueChanged<int> onPick;
  final ValueChanged<bool> onSettle;

  @override
  Widget build(BuildContext context) {
    final days = DateTime(month.year, month.month + 1, 0).day;
    final lead = DateTime(month.year, month.month).weekday % 7; // 일요일 시작
    final rows = _rowsOf(month);
    final isThisMonth = month.year == calendarToday.year && month.month == calendarToday.month;
    final todayShown = isThisMonth && (monthOpen || row == _rowOf(month, calendarToday.day));
    Widget week(int r, double cell) => Row(
      children: [
        for (var c = 0; c < 7; c++)
          Expanded(
            child: SizedBox(
              height: cell,
              child: switch (r * 7 + c - lead + 1) {
                final d when d >= 1 && d <= days => _DayCell(
                  day: d,
                  today: isThisMonth && d == calendarToday.day,
                  selected: selected == d,
                  dots: dots[d] ?? const {},
                  sunday: c == 0,
                  onTap: () => onPick(d),
                ),
                _ => null,
              },
            ),
          ),
      ],
    );
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      decoration: BoxDecoration(
        color: Gp.panel,
        borderRadius: BorderRadius.circular(Gp.rLarge),
        border: Border.all(color: Gp.line),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          // 칸은 정사각 — 넓은 창 · 가로 폰에서 한 달이 화면을 다 덮지 않게 높이만 막는다
          final cell = (box.maxWidth / 7).clamp(36.0, 56.0);
          final travel = (rows - 1) * cell; // 한 주 → 한 달 펴지는 높이
          return Column(
            children: [
              Row(
                children: [
                  IconButton(
                    // H-2 P03
                    tooltip: tr(monthOpen ? '이전 달' : '이전 주'),
                    onPressed: onPrev,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      trf('{y}년 {m}월', {'y': month.year, 'm': month.month}),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: Gp.t16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    tooltip: tr(monthOpen ? '다음 달' : '다음 주'),
                    onPressed: onNext,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              if (!todayShown)
                TextButton(
                  onPressed: onToday,
                  child: Text(tr('오늘'), style: const TextStyle(color: Gp.accent)),
                ), // P07
              Row(
                children: [
                  for (final (i, w) in _weekdays.indexed)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          w,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: Gp.t12, color: i == 0 ? Gp.danger : Gp.faint),
                        ),
                      ),
                    ),
                ],
              ),
              AnimatedBuilder(
                animation: open,
                builder: (context, _) {
                  final t = open.value;
                  // 다 접혔으면 그 주 한 줄만 (가려진 날짜가 트리에 남지 않게), 펴는 중이면 달 격자를 그 주 자리에서 위아래로 연다
                  if (t == 0) return week(row, cell);
                  return SizedBox(
                    height: cell + travel * t,
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.topCenter,
                        minHeight: rows * cell,
                        maxHeight: rows * cell,
                        child: Transform.translate(
                          offset: Offset(0, -row * cell * (1 - t)),
                          child: Column(children: [for (var r = 0; r < rows; r++) week(r, cell)]),
                        ),
                      ),
                    ),
                  );
                },
              ),
              GestureDetector(
                // H-3c 손잡이: 누르면 펴기 · 접기, 아래로 밀면 펴고 위로 밀면 접는다
                key: const ValueKey('month-handle'),
                behavior: HitTestBehavior.opaque,
                onTap: () => onSettle(!monthOpen),
                onVerticalDragUpdate: (d) => open.value =
                    (open.value + (d.primaryDelta ?? 0) / travel.clamp(1.0, double.infinity)).clamp(0.0, 1.0),
                onVerticalDragEnd: (d) {
                  final v = d.primaryVelocity ?? 0;
                  onSettle(v.abs() > 300 ? v > 0 : open.value > 0.5);
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        monthOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        size: Gp.iS,
                        color: Gp.muted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        tr(monthOpen ? '한 주 보기' : '한 달 보기'),
                        style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({super.key, required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 6,
    height: 6,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.today,
    required this.selected,
    required this.dots,
    required this.sunday,
    required this.onTap,
  });

  final int day;
  final bool today;
  final bool selected;
  final Set<Color> dots;
  final bool sunday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      // 칸이 낮으면(작은 폰 · 가로) 통째로 줄인다
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? Gp.accent.withValues(alpha: 0.12) : null,
                border: today ? Border.all(color: Gp.ink, width: 1.2) : null, // 오늘
              ),
              child: Text(
                '$day',
                style: TextStyle(
                  fontSize: Gp.t14,
                  fontWeight: selected || today ? FontWeight.w700 : FontWeight.w400,
                  color: selected ? Gp.accent : (sunday ? Gp.danger : Gp.ink),
                ),
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              // H-3 ● 내 좋아요 · 예약 (파랑) · ● 그 밖 (회색) — 파랑이 앞
              height: 6,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final (i, c) in [
                    if (dots.contains(Gp.accent)) Gp.accent,
                    if (dots.contains(Gp.muted)) Gp.muted,
                  ].indexed) ...[if (i > 0) const SizedBox(width: 3), _Dot(color: c)],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({super.key, required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final md = '${date.month}.${date.day.toString().padLeft(2, '0')}';
    final wd = _weekdays[date.weekday % 7];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Text(
        byLang(ko: '$md ($wd)', zh: '$md（周$wd）'),
        style: const TextStyle(fontSize: Gp.t14, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// H-5 일정 줄 — 점 · 제목(2줄) / "상태 · 출처 또는 라인" 옅은 글자. 상태를 테두리 알약에 넣지 않는다 (2026-11-20 주인)
class _EventRow extends StatelessWidget {
  const _EventRow({super.key, required this.event, required this.dday, required this.loaders});
  final _Event event;
  final String dday;
  final Loaders loaders;

  /// 상태 글 — 발매 · 예고 단계 · "21:00 라이브" · "18:00 예약 시작" · 예약 · 재판매 · 구매 · PB 예약 마감.
  /// 비공식이 전한 것은 "비공식 · …" (예고 꼬리표 AnnTag 와 같은 순서). 단계 값은 한국어 그대로 — 보일 때 tr
  String get _status {
    final ann = event.ann;
    final text = event.tag.isNotEmpty
        ? joinDot([if (ann?.unofficial ?? false) tr(unofficialLabel), tr(event.tag)])
        : tr(event.kit != null ? '발매' : (ann == null ? '예고' : annStageText(ann.status, unofficial: ann.unofficial)));
    return [if (event.time.isNotEmpty) event.time, text].join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final kit = event.kit;
    final ann = event.ann;
    return ThumbRow(
      // H-5 — 컬렉션 · 검색과 같은 줄, 상태는 점 + 둘째 줄 글자 (테두리 알약 없이)
      id: kit?.id ?? ann?.id,
      image: event.image,
      title: event.title,
      titleLines: 2,
      titleLead: _Dot(
        key: ValueKey(event.mine ? 'event-dot-mine' : 'event-dot-other'),
        color: event.mine ? Gp.accent : Gp.muted,
      ),
      subtitle: joinDot([_status, event.sub]),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      onTap: () {
        if (kit != null) {
          openKitDetail(context, kit, loaders: loaders);
        } else if (ann != null) {
          openAnnouncement(context, ann, loaders: loaders);
        }
      },
      trailing: dday.isEmpty ? null : DateTag(dday, urgent: dday == 'D-DAY' || event.tag == 'PB 예약 마감'),
    );
  }
}

List<HelpItem> get calendarHelp => [
  HelpItem(Icons.tune, tr('필터')),
  HelpItem(Icons.calendar_month_outlined, tr('전체 일정')),
  HelpItem(Icons.person_outline, tr('내 일정 (좋아요 · 구매함)')),
  HelpItem(Icons.keyboard_arrow_down, tr('한 달 보기 (누르거나 아래로 밀기)')),
  HelpItem.dot(Gp.accent, tr('좋아요 · 예약한 상품')),
  HelpItem.dot(Gp.muted, tr('그 밖의 일정')), // 발매 · 예고 · 라이브 · 비공식 소식 · 구매한 날
];
