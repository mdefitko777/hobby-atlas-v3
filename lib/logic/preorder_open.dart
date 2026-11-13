// 예고의 예약 시작 때 — 지금 단계(시작 전 · 예약 중 · 마감) · 꼬리표 글 · 상세 한 줄 · 캘린더 자리 (순수 Dart)
// 데이터(announcements.json preorder_at · preorder_date · preorder_end_at · preorder_end_date)는 하루 한 번 적혀
// status 를 그대로 믿지 않고 기기 시계로 다시 본다 (live_stream.dart 와 같은 까닭).
// 이름 preorder.dart 는 내가 적은 예약(도착 예정)이 이미 쓴다 — 이쪽은 공식 예약이 열리는 때.
import '../format.dart';
import '../l10n/l10n.dart';
import '../models.dart';
import 'live_stream.dart';

/// 예약의 지금 단계 — 시작 전 · 예약 중 · 마감
enum PreorderStage { upcoming, open, closed }

/// 날짜만 있는 값(preorder_date · preorder_end_date)은 일본 날짜다 — 기기 시계를 일본 날짜로 바꿔 견준다
/// (한국과 같은 시간대지만, 다른 시간대의 기기에서도 시작일을 하루 일찍 · 늦게 보지 않게)
String jstDay(DateTime now) => dayKey(now.toUtc().add(const Duration(hours: 9)));

/// [at] = 시작 시각 · [day] = 시작일(시각을 모를 때), [endAt] · [endDay] = 마감.
/// 예약 때를 모르거나 이미 발매된 예고는 null (단계 글 그대로).
///  - 마감: 마감 시각이 지남 · 마감일만 알면 그다음 날부터 (마감 시각을 모른다)
///  - 시작 전: 시작 시각 전 · 시작일만 알면 그 전날까지 (00:00 으로 치지 않는다 — 몇 시에 열지 모른다)
///  - 예약 중: 그 밖 — 데이터가 아직 상품화 확정이라고 해도 시각이 지났으면
PreorderStage? preorderStageOf({
  required String status,
  required DateTime now,
  DateTime? at,
  String day = '',
  DateTime? endAt,
  String endDay = '',
}) {
  if ((at == null && day.isEmpty) || status == '발매') return null;
  final today = jstDay(now);
  if (endAt != null ? !now.isBefore(endAt) : (endDay.isNotEmpty && today.compareTo(endDay) > 0)) {
    return PreorderStage.closed;
  }
  if (at != null ? now.isBefore(at) : day.compareTo(today) > 0) return PreorderStage.upcoming;
  return PreorderStage.open;
}

/// 예고의 예약 단계 — 라이브 예고 · 예약 때를 모르는 예고는 null
PreorderStage? annPreorderStage(Announcement a, DateTime now) => a.isStream
    ? null
    : preorderStageOf(
        status: a.status,
        now: now,
        at: a.preorderAt,
        day: a.preorderDay,
        endAt: a.preorderEndAt,
        endDay: a.preorderEndDay,
      );

/// '2026-11-20' → '11.20' (라이브 때와 같은 모양)
String _md(String day) {
  final m = RegExp(r'^\d{4}-(\d{2})-(\d{2})').firstMatch(day);
  return m == null ? '' : '${int.parse(m.group(1)!)}.${int.parse(m.group(2)!)}';
}

/// 시작 · 마감 때 글: 시각을 알면 오늘 18:00 · 11.20 12:00, 날짜만 알면 11.20
String _when(DateTime? at, String day, DateTime now, {bool relative = true}) =>
    at != null ? liveWhen(at, now, relative: relative) : _md(day);

/// 꼬리표 글: 예약 · 오늘 18:00 / 예약 · 11.20 / 예약 시작 (· ~11.30 마감) / 예약 마감.
/// 마감이 23:59 면 날짜만 (그날 끝까지) — 꼬리표는 날짜 · 출처와 한 줄이라 「비공식 · 예약 시작 · ~11.30 23:59 마감」은
/// 360dp 폰에서 넘쳤다. 다른 시각이면 시각까지, 상세 한 줄(preorderLine)은 늘 시각까지
String preorderLabel(Announcement a, PreorderStage stage, DateTime now) => switch (stage) {
  PreorderStage.upcoming => trf('예약 · {when}', {'when': _when(a.preorderAt, a.preorderDay, now)}),
  PreorderStage.open => switch (a.preorderEndAt) {
    final end? when end.hour != 23 || end.minute != 59 => trf('예약 시작 · ~{when} 마감', {'when': liveWhen(end, now)}),
    final end? => trf('예약 시작 · ~{when} 마감', {'when': _md(dayKey(end))}),
    null when a.preorderEndDay.isNotEmpty => trf('예약 시작 · ~{when} 마감', {'when': _md(a.preorderEndDay)}),
    null => tr('예약 시작'),
  },
  PreorderStage.closed => tr('예약 마감'),
};

/// 상세 한 줄: 예약 시작 11.13 18:00 · 마감 11.20 23:59 (늘 날짜로 — 오래 열어 두는 화면). 예약 때를 모르면 빈 글자
String preorderLine(Announcement a, DateTime now) {
  final start = _when(a.preorderAt, a.preorderDay, now, relative: false);
  if (start.isEmpty) return '';
  final end = _when(a.preorderEndAt, a.preorderEndDay, now, relative: false);
  return joinDot([
    trf('예약 시작 {when}', {'when': start}),
    if (end.isNotEmpty) trf('마감 {when}', {'when': end}),
  ]);
}

/// 예약이 열리는 날 ('2026-11-13') — 시작 시각이 있으면 그 날(기기 시간대), 없으면 시작일. 모르면 빈 글자
String preorderDayOf(Announcement a) => a.preorderAt != null ? dayKey(a.preorderAt!) : a.preorderDay;

/// 목록 · 상세 · 캘린더에 보이는 예고 날짜: 예약 때를 아는 예고는 예약이 열리는 날, 아니면 발표일.
/// 魂ウェブ 는 전날 저녁에 「내일 12時より」를 올려 발표일로 두면 예약이 하루 일찍 열리는 것처럼 보였다 (2026-11-13).
/// 줄 세우기는 발표일 그대로 (deriveAnnouncements)
String annShownDay(Announcement a) {
  final day = preorderDayOf(a);
  return day.isNotEmpty && a.status != '발매' ? day : a.date;
}

/// 상품 소개의 예약 기간: '2026.11.13 18:00 ~' · '2026.11.13 18:00 ~ 2026.11.20 23:59' · 시각을 모르면 날짜만.
/// 예약 때를 모르면 빈 글자 (상품 페이지 글을 그대로 쓴다)
String preorderPeriod(Announcement a) {
  String point(DateTime? at, String day) => at != null ? '${dateDot(dayKey(at))} ${liveClock(at)}' : dateDot(day);
  final start = point(a.preorderAt, a.preorderDay);
  if (start.isEmpty) return '';
  final end = point(a.preorderEndAt, a.preorderEndDay);
  return end.isEmpty ? '$start ~' : '$start ~ $end';
}
