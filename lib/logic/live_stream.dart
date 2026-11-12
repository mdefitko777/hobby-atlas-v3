// 공식 라이브(예고 중 방송) — 지금 단계 · 꼬리표 글 · 예고 줄 세우기 · 캘린더 자리 (순수 Dart)
// 데이터의 live_state 는 하루 한 번(Gunpula 작업 때) 적힌 값이라 그대로 믿지 않고 기기 시계로 다시 본다.
import '../format.dart';
import '../json_util.dart';
import '../l10n/l10n.dart';
import '../models.dart';

/// 라이브의 지금 단계. undated = 아직 안 했는데 시작 시각을 모른다 (시간 미정)
enum LiveStage { upcoming, live, ended, undated }

/// 끝나는 시각은 데이터에 없다 — Gunpula 도 시작 2시간 뒤를 끝으로 본다 (announcements.json notes, 2026-11-12)
const liveLength = Duration(hours: 2);

/// live_at ('2026-11-14T21:00:00+09:00') → 기기 시간대. 없거나 모양이 다르면 null
DateTime? parseLiveAt(Object? v) => DateTime.tryParse(jStr(v))?.toLocal();

/// [state] = 데이터의 live_state (upcoming · live · ended), [at] = 시작 시각.
/// 끝남: 데이터가 끝났다고 했거나 시작 2시간이 지남 / 하는 중: 시작 ~ 2시간, 또는 데이터가 하는 중이라고 함
LiveStage liveStageOf({required String state, required DateTime? at, required DateTime now}) {
  if (state == 'ended') return LiveStage.ended;
  if (at == null) return state == 'live' ? LiveStage.live : LiveStage.undated;
  if (!now.isBefore(at.add(liveLength))) return LiveStage.ended;
  if (!now.isBefore(at) || state == 'live') return LiveStage.live;
  return LiveStage.upcoming;
}

/// 예고의 라이브 단계 — 라이브가 아닌 예고는 null
LiveStage? annLiveStage(Announcement a, DateTime now) =>
    a.isStream ? liveStageOf(state: a.liveState, at: a.liveAt, now: now) : null;

/// '21:00'
String liveClock(DateTime at) => shortDateTime(at).split(' ').last;

/// 시작 때: 오늘 21:00 · 내일 21:00 · 11/14 21:00 ([relative] 를 끄면 늘 날짜 — 알림함처럼 오래 남는 글)
String liveWhen(DateTime at, DateTime now, {bool relative = true}) {
  final days = DateTime(at.year, at.month, at.day).difference(DateTime(now.year, now.month, now.day)).inDays;
  final time = liveClock(at);
  if (relative && days == 0) return trf('오늘 {time}', {'time': time});
  if (relative && days == 1) return trf('내일 {time}', {'time': time});
  return '${at.month}/${at.day} $time';
}

/// 꼬리표 글: 라이브 · 오늘 21:00 / 라이브 중 / 다시보기 · 11/12 / 라이브 예정 · 시간 미정
String liveLabel(LiveStage stage, DateTime? at, DateTime now) => switch (stage) {
  LiveStage.upcoming when at != null => trf('라이브 · {when}', {'when': liveWhen(at, now)}),
  LiveStage.live => tr('라이브 중'),
  LiveStage.ended => at == null ? tr('다시보기') : trf('다시보기 · {date}', {'date': '${at.month}/${at.day}'}),
  _ => tr('라이브 예정 · 시간 미정'),
};

/// 예고 줄 세우기: 곧 할 · 하는 중인 라이브가 맨 앞 (시작 빠른 것부터).
/// 끝난 라이브 · 보통 예고는 받은 순서(발표일 새것부터) 그대로. 시간 미정도 그대로 둔다 —
/// 끝났는지 시계로 알 수 없어, 앞에 두면 데이터가 끝났다고 할 때까지 맨 앞에 남는다
List<Announcement> liveFirst(List<Announcement> list, DateTime now) {
  bool ahead(Announcement a) => switch (annLiveStage(a, now)) {
    LiveStage.upcoming || LiveStage.live => true,
    _ => false,
  };
  final front = list.where(ahead).toList();
  // 같은 시각이면 받은 순서 (List.sort 는 순서를 지켜 주지 않는다)
  final order = {for (final (i, a) in front.indexed) a.id: i};
  front.sort((a, b) {
    final x = a.liveAt, y = b.liveAt;
    final c = x == null || y == null ? (x == null ? 1 : 0) - (y == null ? 1 : 0) : x.compareTo(y);
    return c != 0 ? c : order[a.id]!.compareTo(order[b.id]!);
  });
  return [...front, ...list.where((a) => !ahead(a))];
}

/// 캘린더 자리 ('2026-11-14'): 라이브는 발표한 날이 아니라 방송하는 날, 시간 미정이면 캘린더에 없다(빈 글자).
/// 라이브가 아닌 예고는 발표일 그대로
String announcementDay(Announcement a) => !a.isStream ? a.date : (a.liveAt == null ? '' : dayKey(a.liveAt!));
