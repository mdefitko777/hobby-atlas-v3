// 화면 H: 캘린더 — 내 채널의 발매일 · 공식 예고를 달력으로
//
// ┌──────── 디자인 가이드 대응표: H 캘린더 ────────────────────────────────────────────┐
// │ 번호 │ Flutter 위젯명                     │ 비즈니스 명칭(한글)                    │ 원칙(P번호)   │
// │ H-1  │ ChannelHeader                      │ 아바타 줄 + 내 채널 바 (C-0 공용)       │ P04 · P06     │
// │ H-2  │ ‹ 2026년 10월 › + 오늘              │ 달 넘기기 · 오늘로                      │ P03 · P07     │
// │ H-3  │ 7열 달력 + 날짜 아래 ● · ○ + 범례     │ ● 발매일(확정) · ○ 예고·공지가 있는 날    │ P01 · P06     │
// │ H-3b │ 전체 · 발매 · 예고 밑줄 탭            │ 일정 종류 거르기                        │ P06 · P07     │
// │ H-4  │ 날짜 누르기 (다시 누르면 해제)        │ 그날만 보기 / 한 달 전체 보기           │ P03           │
// │ H-5  │ 날짜별 묶음 목록 + 종류 알약 + D-n    │ 발매(검정 알약) · 예고 단계(회색 알약)   │ P01 · P02     │
// │ H-6  │ "날짜 미정 · n월 중" 묶음            │ 날짜가 정해지지 않은 발매               │ P01 · P10     │
// │ H-7  │ LayoutBuilder ≥720dp                │ 넓은 화면: 달력 왼쪽 · 목록 오른쪽       │ 적응형        │
// │ H-8  │ LoadingView / ErrorView / EmptyView │ 불러오는 중 · 오류 · 이 달 일정 없음     │ P01 · P09     │
// └──────────────────────────────────────────────────────────────────────────────────┘
// 전환: 발매 줄 → D 상품 상세(쌓기). 예고 줄 → J 공식 예고 상세(쌓기).
// 현행 앱 문제: 발매 정보가 "최근" 화면 탭 안 "이번 달 발매"에만 있고 날짜로 볼 수 없음.
import 'package:flutter/material.dart';

import '../api.dart';
import '../channels.dart';
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

const _weekdays = ['일', '월', '화', '수', '목', '금', '토'];

/// 달력 한 줄의 일정 (발매 상품 또는 공식 예고)
class _Event {
  const _Event({required this.title, required this.image, required this.sub, this.kit, this.ann, this.day});
  final String title;
  final String image;
  final String sub;

  /// 발매 상품 (확정된 발매일)
  final Kit? kit;

  /// 공식 예고 · 공지
  final Announcement? ann;

  bool get isRelease => kit != null;

  /// null = 날짜 미정(그 달 중)
  final int? day;
}

class _CalData {
  const _CalData(this.kits, this.announcements);
  final List<Kit> kits;
  final List<Announcement> announcements;
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

  @override
  List<String> get myChannels => widget.myChannels;

  @override
  void loadScope(List<String> ids) {
    // STATE: 채널 → GET /kits · /announcements → 달력 점 · 일정 목록
    _future = Future.wait([
      widget.loaders.kits(ids),
      widget.loaders.announcements(ids),
    ]).then((r) => _CalData(r[0] as List<Kit>, r[1] as List<Announcement>));
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
  List<_Event> _events(_CalData d) {
    final ym = '${_month.year}-${_month.month.toString().padLeft(2, '0')}';
    int? dayOf(String date) => date.length >= 10 ? int.tryParse(date.substring(8, 10)) : null;
    return [
      for (final k in d.kits)
        if (k.date.startsWith(ym))
          _Event(
            title: k.name,
            image: k.image,
            sub: joinDot([channelOf(k.franchiseId).label, k.line, yen(k.priceJpy)]),
            kit: k,
            day: dayOf(k.date),
          ),
      for (final a in d.announcements)
        if (a.date.startsWith(ym)) _Event(title: a.title, image: a.image, sub: a.source, ann: a, day: dayOf(a.date)),
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
              final events = _events(snap.data!);
              final calendar = _MonthCalendar(
                month: _month,
                selected: _day,
                releaseDays: {
                  for (final e in events)
                    if (e.isRelease) ?e.day,
                },
                noticeDays: {
                  for (final e in events)
                    if (!e.isRelease) ?e.day,
                },
                onPrev: () => _moveMonth(-1),
                onNext: () => _moveMonth(1),
                onToday: () => setState(() {
                  _month = DateTime(calendarToday.year, calendarToday.month);
                  _day = null;
                }),
                onPick: (d) => setState(() => _day = _day == d ? null : d), // H-4 STATE: 날짜 → 목록
              );
              return LayoutBuilder(
                builder: (context, box) {
                  if (box.maxWidth >= 720) {
                    // H-7 넓은 화면
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 380, child: SingleChildScrollView(child: calendar)),
                        const VerticalDivider(width: 1),
                        Expanded(child: ListView(children: _list(events))),
                      ],
                    );
                  }
                  return ListView(
                    padding: EdgeInsets.only(bottom: navClearance(context)),
                    children: [calendar, ..._list(events)],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  List<Widget> _list(List<_Event> all) {
    final inDay = _day == null ? all : all.where((e) => e.day == _day).toList();
    final shown = inDay.where((e) => _kind == 0 || (_kind == 1) == e.isRelease).toList();
    final kinds = Padding(
      // H-3b 종류 거르기
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
      child: Row(
        children: [
          for (final (i, label) in ['전체', '발매', '예고'].indexed)
            UnderlineTab(
              label: label,
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
        kinds,
        EmptyView(
          // H-8 P09
          icon: Icons.event_busy_outlined,
          message: _day == null ? '${_month.month}월에는 발매 · 예고 일정이 없어요' : '${_month.month}월 $_day일에는 일정이 없어요',
          detail: _day == null ? '다른 달로 넘기거나 채널을 바꿔 보세요' : '날짜를 다시 누르면 한 달 전체를 봐요',
        ),
      ];
    }
    final days = (shown.map((e) => e.day).nonNulls.toSet().toList())..sort();
    final undated = shown.where((e) => e.day == null).toList();
    return [
      kinds,
      if (_day != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            '${_month.month}월 $_day일만 보는 중 · 날짜를 다시 누르면 한 달 전체',
            style: const TextStyle(color: Gp.muted, fontSize: Gp.t12),
          ),
        ),
      for (final d in days) ...[
        _DayHeader(date: DateTime(_month.year, _month.month, d)), // H-5
        for (final e in shown.where((e) => e.day == d)) _EventRow(event: e, dday: _dday(d), loaders: widget.loaders),
      ],
      if (undated.isNotEmpty) ...[
        SectionHeader(
          '날짜 미정',
          subtitle: '${_month.month}월 중',
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
    required this.releaseDays,
    required this.noticeDays,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
    required this.onPick,
  });

  final DateTime month;
  final int? selected;

  /// ● 발매일이 있는 날 · ○ 예고 · 공지가 있는 날
  final Set<int> releaseDays;
  final Set<int> noticeDays;
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Gp.line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(tooltip: '이전 달', onPressed: onPrev, icon: const Icon(Icons.chevron_left)), // H-2 P03
              Expanded(
                child: Text(
                  '${month.year}년 ${month.month}월',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: Gp.t16, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(tooltip: '다음 달', onPressed: onNext, icon: const Icon(Icons.chevron_right)),
            ],
          ),
          if (!isThisMonth)
            TextButton(
              onPressed: onToday,
              child: const Text('오늘로', style: TextStyle(color: Gp.accent)),
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
                  release: releaseDays.contains(d),
                  notice: noticeDays.contains(d),
                  sunday: (lead + d - 1) % 7 == 0,
                  onTap: () => onPick(d),
                ),
            ],
          ),
          // 범례 (P10)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Dot(filled: true),
                SizedBox(width: 5),
                Text(
                  '발매일',
                  style: TextStyle(fontSize: Gp.t12, color: Gp.muted),
                ),
                SizedBox(width: 16),
                _Dot(filled: false),
                SizedBox(width: 5),
                Text(
                  '예고 · 공지',
                  style: TextStyle(fontSize: Gp.t12, color: Gp.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ● 발매일(브랜드 색 채움) · ○ 예고·공지(회색 테두리)
class _Dot extends StatelessWidget {
  const _Dot({required this.filled});
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? Gp.accent : null,
        border: filled ? null : Border.all(color: Gp.muted, width: 1.2),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.today,
    required this.selected,
    required this.release,
    required this.notice,
    required this.sunday,
    required this.onTap,
  });

  final int day;
  final bool today;
  final bool selected;
  final bool release;
  final bool notice;
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
                  if (release) const _Dot(filled: true),
                  if (release && notice) const SizedBox(width: 3),
                  if (notice) const _Dot(filled: false),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Text(
        '${date.month}.${date.day.toString().padLeft(2, '0')} (${_weekdays[date.weekday % 7]})',
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
      tag: kit != null ? '발매' : (ann?.status ?? '예고'), // 확정 발매 = 검정 알약, 예고 단계 = 회색 알약
      tagStrong: kit != null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      onTap: () {
        if (kit != null) {
          openKitDetail(context, kit, loaders: loaders);
        } else if (ann != null) {
          openAnnouncement(context, ann, loaders: loaders);
        }
      },
      trailing: dday.isEmpty
          ? null
          : Text(
              dday,
              style: const TextStyle(fontWeight: FontWeight.w700, color: Gp.accent, fontSize: Gp.t12),
            ),
    );
  }
}
