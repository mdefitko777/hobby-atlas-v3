// 화면 H: 캘린더 — 내 채널의 발매일 · 공식 예고를 달력으로
//
// ┌──────── 디자인 가이드 대응표: H 캘린더 ────────────────────────────────────────────┐
// │ 번호 │ Flutter 위젯명                     │ 비즈니스 명칭(한글)                    │ 원칙(P번호)   │
// │ H-1  │ ChannelHeader                      │ 아바타 줄 + 내 채널 바 (C-0 공용)       │ P04 · P06     │
// │ H-2  │ ‹ 2026년 10월 › + 오늘              │ 달 넘기기 · 오늘로                      │ P03 · P07     │
// │ H-3  │ 7열 달력 + 날짜 아래 색 점 (뜻은 H-12) │ 파랑 발매 · 회색 예고 · 빨강 PB 마감 · 민트 산 날 │ P01 · P06 │
// │ H-9  │ ViewIconToggle 전체 · 내 일정        │ 좋아요 · 구매함 상품의 날짜만            │ P06           │
// │ H-9b │ 내 일정: 보라 점 예약 도착 · 주황 점 재판매 │ 예약한 상품 도착 예정 · 좋아요 상품 재판매 │ P01 · P06 │
// │ H-9c │ 💳 + 금액 줄 (내 일정 맨 위)          │ 이번 달 낼 돈: 이 달 도착 예정인 미결제 예약 합 │ P01      │
// │ H-11 │ FindBar (달력 위)                   │ 일정에서 찾기 + 상품 필터 (점 · 목록이 같이 좁혀짐) │ P04 · P07 │
// │ H-3b │ 전체 · 발매 · 예고 밑줄 탭            │ 일정 종류 거르기                        │ P06 · P07     │
// │ H-4  │ 날짜 누르기 (다시 누르면 해제)        │ 그날만 보기 / 한 달 전체 보기           │ P03           │
// │ H-5  │ 날짜별 묶음 목록 + 종류 알약 + D-n    │ 발매(검정 알약) · 예고 단계(회색 알약)   │ P01 · P02     │
// │ H-5b │ 예고 줄: 색 꼬리표 "21:00 라이브"     │ 공식 라이브 — 발표일이 아니라 방송하는 날에 (시간 미정은 없음) │ P01 │
// │ H-5c │ 예고 줄: 색 꼬리표 "18:00 예약 시작"  │ 예약 때를 아는 예고 — 발표일이 아니라 예약이 열리는 날에 │ P01 │
// │ H-6  │ "날짜 미정 · n월 중" 묶음            │ 날짜가 정해지지 않은 발매               │ P01 · P10     │
// │ H-7  │ LayoutBuilder ≥720dp                │ 넓은 화면: 달력 왼쪽 · 목록 오른쪽       │ 적응형        │
// │ H-8  │ LoadingView / ErrorView / EmptyView │ 불러오는 중 · 오류 · 이 달 일정 없음     │ P01 · P09     │
// │ H-12 │ 위 줄 ? (S-19, calendarHelp)        │ 아이콘 뜻 + 점 색 (달력 위 ? 를 합침)      │ P10 · P01     │
// └──────────────────────────────────────────────────────────────────────────────────┘
// 전환: 발매 줄 → D 상품 상세(쌓기). 예고 · 라이브 줄 → J 공식 예고 상세(쌓기).
// 왜 이렇게: 발매 정보를 목록 한구석이 아니라 날짜로 보게.
import 'package:flutter/material.dart';

import '../api.dart';
import '../channels.dart';
import '../l10n/l10n.dart';
import '../logic/announcement_match.dart';
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
    this.dot = Gp.accent,
    this.tag = '',
    this.due = 0,
    this.time = '',
    this.tagColor,
  });

  /// 라이브 줄: 시작 시각 '21:00' (알약 앞에 붙는다)
  final String time;

  /// 뜻이 색으로 정해진 꼬리표 (예약 · 재판매 · 라이브 단계 · 비공식) — 없으면 테두리 알약
  final Color? tagColor;

  /// 예약 도착 줄: 아직 낼 돈 (원)
  final int due;

  /// 달력 점 색: 파랑 발매 · 회색 예고 · 빨강 PB 예약 마감 · 민트 산 날
  final Color dot;

  /// 줄 알약 글자 (비면 발매 / 예고 단계) — 한국어 그대로 비교에 쓰고, 보일 때 tr
  final String tag;
  final String title;
  final String image;
  final String sub;

  /// 발매 상품 (확정된 발매일)
  final Kit? kit;

  /// 예고 · 공지 (공식 · 비공식)
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
    this.leading,
    this.loaders = const Loaders(),
  });

  final List<String> myChannels;
  final ValueChanged<List<String>> onMyChannelsChanged;
  final Widget? leading;
  final Loaders loaders;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> with ChannelScope {
  late Future<_CalData> _future;
  DateTime _month = DateTime(calendarToday.year, calendarToday.month);
  int? _day;

  /// 0 = 전체 · 1 = 발매 · 2 = 예고
  int _kind = 0;

  /// 전체 / 내 일정 (좋아요 · 구매함 상품의 날짜만)
  bool _mine = false;

  /// H-11 찾기 · 상품 필터. 필터를 고르면 상품 일정만 (예고에는 종류 · 가격 같은 값이 없다)
  final _find = KitFind();

  bool _hitAnn(Announcement a) =>
      _find.filter.count == 0 && (_find.query.isEmpty || a.title.toLowerCase().contains(_find.query.toLowerCase()));

  Future<void> _openFilter(_CalData d) async {
    if (await _find.openFilter(context, d.kits)) setState(() {}); // STATE: 필터 → 달력 점 · 목록
  }

  @override
  List<String> get myChannels => widget.myChannels;

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
    reloadScope();
  }

  @override
  void didUpdateWidget(CalendarScreen old) {
    super.didUpdateWidget(old);
    syncScope();
  }

  void _moveMonth(int delta) => setState(() {
    _month = DateTime(_month.year, _month.month + delta); // STATE: 달 → 달력 · 목록
    _day = null;
  });

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
              sub: tr('PB 예약 마감'),
              kit: k,
              day: dayOf(k.pbCloses),
              dot: Gp.danger,
              tag: 'PB',
            ),
          );
        }
        if (k.date.startsWith(ym)) {
          out.add(
            _Event(title: k.name, image: k.image, sub: joinDot([tr(k.line), kitPrice(k)]), kit: k, day: dayOf(k.date)),
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
                pre.due > 0 ? trf('낼 돈 {money}', {'money': won(pre.due)}) : (pre.paid ? tr('결제 완료') : ''),
              ]),
              kit: k,
              day: dayOf(pre.arrival),
              dot: Gp.reserve,
              tagColor: Gp.reserve,
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
                sub: joinDot([tr(e.label), if (e.dateEstimated) tr('날짜 짐작')]),
                kit: k,
                day: e.day,
                dot: Gp.resale,
                tagColor: Gp.resale,
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
              sub: joinDot([tr(k.line), k.seriesLabel]),
              kit: k,
              day: at.day,
              dot: Gp.own,
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
            sub: joinDot([tr(channelOf(k.franchiseId).label), tr(k.line), kitPrice(k)]),
            kit: k,
            day: dayOf(k.date),
          ),
      for (final a in d.announcements)
        // H-5b 라이브는 방송하는 날에 (시간 미정이면 announcementDay 가 비어 캘린더에 없다), 예약은 열리는 날에
        if (announcementDay(a) case final date when date.startsWith(ym) && _hitAnn(a))
          if (annLiveStage(a, appNow()) case final stage?)
            _Event(
              title: a.title,
              image: a.image,
              sub: a.source,
              ann: a,
              day: dayOf(date),
              dot: Gp.faint,
              tag: '라이브',
              time: liveClock(a.liveAt!),
              tagColor: liveColor(stage),
            )
          // H-5c 예약 때를 아는 예고는 예약이 열리는 날에 "18:00 예약 시작" (시각을 모르면 "예약 시작"만)
          else if (annPreorderStage(a, appNow()) case final pre?)
            _Event(
              title: a.title,
              image: a.image,
              sub: a.source,
              ann: a,
              day: dayOf(date),
              dot: Gp.faint,
              tag: '예약 시작',
              time: a.preorderAt == null ? '' : liveClock(a.preorderAt!),
              tagColor: preorderColor(pre),
            )
          else
            _Event(
              title: a.title,
              image: a.image,
              sub: a.source,
              ann: a,
              day: dayOf(date),
              dot: Gp.faint,
              tagColor: a.unofficial ? unofficialColor : null, // 예고 목록 꼬리표와 같은 색
            ),
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
              final dots = <int, Set<Color>>{};
              for (final e in events) {
                if (e.day case final d?) (dots[d] ??= {}).add(e.dot);
              }
              // H-10 달력 위에서 좌우로 밀면 달 넘기기
              final calendar0 = _MonthCalendar(
                month: _month,
                selected: _day,
                dots: dots,
                mine: _mine,
                onPrev: () => _moveMonth(-1),
                onNext: () => _moveMonth(1),
                onToday: () => setState(() {
                  _month = DateTime(calendarToday.year, calendarToday.month);
                  _day = null;
                }),
                onPick: (d) => setState(() => _day = _day == d ? null : d), // H-4 STATE: 날짜 → 목록
              );
              final calendar = GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragEnd: (d) {
                  final v = d.primaryVelocity ?? 0;
                  if (v < -250) _moveMonth(1);
                  if (v > 250) _moveMonth(-1);
                },
                child: calendar0,
              );
              return LayoutBuilder(
                builder: (context, box) {
                  if (box.maxWidth >= 720) {
                    // H-7 넓은 화면
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 380,
                          child: SingleChildScrollView(child: Column(children: [_tabs(snap.data!), calendar])),
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(child: ListView(children: _list(events))),
                      ],
                    );
                  }
                  return ListView(
                    padding: EdgeInsets.only(bottom: navClearance(context)),
                    children: [_tabs(snap.data!), calendar, ..._list(events)],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// H-11 찾기 + 필터 + 전체 / 내 일정 (홈의 검색창 · 전체 소식 / My Page 와 같은 줄)
  Widget _tabs(_CalData d) => FindBar(
    hint: tr('일정에서 찾기'),
    onQuery: (q) => setState(() => _find.query = q), // STATE: 찾기 → 달력 점 · 목록
    filterCount: _find.filter.count,
    onFilter: () => _openFilter(d),
    tools: [
      ViewIconToggle(
        mine: _mine,
        onChanged: (v) => setState(() => _mine = v),
        allIcon: Icons.calendar_month_outlined,
        allTip: tr('전체 일정'),
        mineTip: tr('내 일정'),
      ),
    ],
  );

  /// H-9c 이번 달 낼 돈 — 이 달에 도착 예정인 미결제 예약 (내 일정에서만, 날짜를 골라도 한 달 전체)
  Widget? _dueRow(List<_Event> all) {
    final dues = all.where((e) => e.tag == '예약' && e.due > 0).toList();
    if (!_mine || dues.isEmpty) return null;
    final total = dues.fold<int>(0, (s, e) => s + e.due);
    return Container(
      key: const ValueKey('month-due'),
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      decoration: BoxDecoration(
        color: Gp.reserve.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Gp.radius),
      ),
      child: Row(
        children: [
          const Icon(Icons.payments_outlined, size: Gp.iM, color: Gp.reserve),
          const SizedBox(width: 8),
          Text(
            trf('{m}월 낼 돈', {'m': _month.month}),
            style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
          ),
          const Spacer(),
          Text(
            won(total),
            style: const TextStyle(fontSize: Gp.t16, fontWeight: FontWeight.w700),
          ),
          Text(
            ' · ${trf('{n}건', {'n': dues.length})}',
            style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
          ),
        ],
      ),
    );
  }

  List<Widget> _list(List<_Event> all) {
    final due = _dueRow(all);
    final inDay = _day == null ? all : all.where((e) => e.day == _day).toList();
    final shown = _mine ? inDay : inDay.where((e) => _kind == 0 || (_kind == 1) == e.isRelease).toList();
    final kinds = Padding(
      // H-3b 종류 거르기
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
      child: Row(
        children: [
          for (final (i, label) in ['전체', '발매', '예고'].indexed)
            UnderlineTab(
              label: tr(label),
              count: switch (i) {
                1 => inDay.where((e) => e.isRelease).length,
                2 => inDay.where((e) => !e.isRelease).length,
                _ => inDay.length,
              },
              selected: _kind == i,
              onTap: () => setState(() => _kind = i), // STATE: 종류 → 목록
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
        ],
      ),
    );
    if (shown.isEmpty) {
      return [
        if (!_mine) kinds,
        ?due,
        EmptyView(
          // H-8 P09
          icon: Icons.event_busy_outlined,
          message: _find.active
              ? tr('이 조건의 일정이 없어요')
              : _mine
              ? trf('{m}월에는 좋아요 · 구매함 상품의 일정이 없어요', {'m': _month.month})
              : (_day == null
                    ? trf('{m}월에는 발매 · 예고 일정이 없어요', {'m': _month.month})
                    : trf('{m}월 {d}일에는 일정이 없어요', {'m': _month.month, 'd': _day})),
          detail: _day == null ? tr('다른 달로 넘기거나 채널을 바꿔 보세요') : tr('날짜를 다시 누르면 한 달 전체를 봐요'),
        ),
      ];
    }
    final days = (shown.map((e) => e.day).nonNulls.toSet().toList())..sort();
    final undated = shown.where((e) => e.day == null).toList();
    return [
      if (!_mine) kinds,
      ?due,
      if (_day != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            trf('{m}월 {d}일만 보는 중 · 날짜를 다시 누르면 한 달 전체', {'m': _month.month, 'd': _day}),
            style: const TextStyle(color: Gp.muted, fontSize: Gp.t12),
          ),
        ),
      for (final d in days) ...[
        _DayHeader(date: DateTime(_month.year, _month.month, d)), // H-5
        for (final e in shown.where((e) => e.day == d))
          _EventRow(event: e, dday: e.tag == '구매' ? '' : _dday(d), loaders: widget.loaders),
      ],
      if (undated.isNotEmpty) ...[
        SectionHeader(
          tr('날짜 미정'),
          subtitle: trf('{m}월 중', {'m': _month.month}),
          padding: const EdgeInsets.fromLTRB(16, 20, 12, 8),
        ), // H-6
        for (final e in undated) _EventRow(event: e, dday: '', loaders: widget.loaders),
      ],
    ];
  }

  /// D-n · D-DAY · 지난 날짜는 빈칸
  String _dday(int d) {
    final diff = DateTime(_month.year, _month.month, d).difference(calendarToday).inDays;
    if (diff == 0) return 'D-DAY';
    return diff > 0 ? 'D-$diff' : '';
  }
}

/// H-2 · H-3 달력
class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.month,
    required this.selected,
    required this.dots,
    required this.mine,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
    required this.onPick,
  });

  final DateTime month;
  final int? selected;

  /// 날짜 → 그날 점 색들 (글자 범례 없이 색으로, 뜻은 위 줄 ? 에 — calendarHelp)
  final Map<int, Set<Color>> dots;
  final bool mine;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final lead = first.weekday % 7; // 일요일 시작
    final isThisMonth = month.year == calendarToday.year && month.month == calendarToday.month;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
      decoration: BoxDecoration(
        color: Gp.panel,
        borderRadius: BorderRadius.circular(Gp.rLarge),
        border: Border.all(color: Gp.line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(tooltip: tr('이전 달'), onPressed: onPrev, icon: const Icon(Icons.chevron_left)), // H-2 P03
              Expanded(
                child: Text(
                  trf('{y}년 {m}월', {'y': month.year, 'm': month.month}),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: Gp.t16, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(tooltip: tr('다음 달'), onPressed: onNext, icon: const Icon(Icons.chevron_right)),
            ],
          ),
          if (!isThisMonth)
            TextButton(
              onPressed: onToday,
              child: Text(tr('오늘로'), style: const TextStyle(color: Gp.accent)),
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
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1,
            children: [
              for (var i = 0; i < lead; i++) const SizedBox(),
              for (var d = 1; d <= days; d++)
                _DayCell(
                  day: d,
                  today: isThisMonth && d == calendarToday.day,
                  selected: selected == d,
                  dots: dots[d] ?? const {},
                  sunday: (lead + d - 1) % 7 == 0,
                  onTap: () => onPick(d),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});
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
              // H-3 ● 발매일 · ○ 예고·공지
              height: 6,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final (i, c) in dots.take(3).indexed) ...[if (i > 0) const SizedBox(width: 3), _Dot(color: c)],
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
  const _DayHeader({required this.date});
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

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, required this.dday, required this.loaders});
  final _Event event;
  final String dday;
  final Loaders loaders;

  @override
  Widget build(BuildContext context) {
    final kit = event.kit;
    final ann = event.ann;
    return ThumbRow(
      // H-5 — 컬렉션·검색과 같은 줄
      id: kit?.id ?? ann?.id,
      image: event.image,
      title: event.title,
      subtitle: event.sub,
      // 발매 = 검정, 예고 = 회색, 비공식 = 호박색 (알약 글자 · 예고 단계는 한국어 값 — 보일 때 tr). 라이브는 시각을 앞에: "21:00 라이브",
      // 비공식이 전한 라이브는 "21:00 비공식 · 라이브" (색은 라이브 단계 그대로 — 예고 꼬리표 AnnTag 와 같게)
      tag: [
        if (event.time.isNotEmpty) event.time,
        if (event.tag.isNotEmpty)
          joinDot([if (ann?.unofficial ?? false) tr(unofficialLabel), tr(event.tag)])
        else
          tr(kit != null ? '발매' : (ann == null ? '예고' : annStageText(ann.status, unofficial: ann.unofficial))),
      ].join(' '),
      tagStrong: kit != null,
      tagColor: event.tagColor, // 예약 · 재판매 = 상세와 같은 색 꼬리표, 라이브 = 단계 색, 비공식 = 호박색
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      onTap: () {
        if (kit != null) {
          openKitDetail(context, kit, loaders: loaders);
        } else if (ann != null) {
          openAnnouncement(context, ann, loaders: loaders);
        }
      },
      trailing: dday.isEmpty ? null : DateTag(dday, urgent: dday == 'D-DAY' || event.tag == 'PB'),
    );
  }
}

/// H-12 ? 도움말 (위 줄 ? 의 "캘린더" 묶음 — s_app_shell.dart). 점 색 뜻도 여기에. 열 때마다 만든다 (화면 언어)
List<HelpItem> get calendarHelp => [
  HelpItem(Icons.tune, tr('필터')),
  HelpItem(Icons.calendar_month_outlined, tr('전체 일정')),
  HelpItem(Icons.person_outline, tr('내 일정 (좋아요 · 구매함)')),
  HelpItem.dot(Gp.accent, tr('발매')),
  HelpItem.dot(Gp.faint, tr('예고 · 공지 · 라이브 (시작하는 날)')), // 비공식 소식도 같은 점
  HelpItem.dot(Gp.danger, tr('PB 예약 마감 (내 일정)')),
  HelpItem.dot(Gp.own, tr('산 날 (내 일정)')),
  HelpItem.dot(Gp.reserve, tr('예약 도착 (내 일정)')),
  HelpItem.dot(Gp.resale, tr('재판매 (내 일정)')),
];
