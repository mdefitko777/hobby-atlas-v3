// 공식 라이브 알림 — 규칙 「라이브 시작 전」(live_soon) 하나로:
//   · 처음 보인 라이브 → 알림함 줄 `stream-<예고 id>` ("라이브 예정 · 11.14 21:00"). id 에 상태를 넣지 않아
//     live_state 가 upcoming → live → ended 로 바뀌어도 다시 울리지 않는다
//   · 시작 30분 전 휴대폰 알림 → 안드로이드에 미리 맡겨 둔다 (LocalNotifier.applyLive, 앱이 꺼져 있어도 뜬다).
//     무엇을 걸고 · 다시 걸고 · 거둘지는 여기서 정한다 (planLiveReminders)
// 라이브는 announcements.json 에서만 온다. 그 파일은 예고 파일 지문이 바뀐 때만 받고(catalog_check_worker.dart),
// 받은 라이브는 notify_state.json 에 적어 둔다 → 규칙 · 내 채널 · 언어가 바뀌면 파일을 다시 받지 않고 계획만 다시.
// 이 파일은 Flutter 위젯을 쓰지 않는다 (백그라운드 isolate · 단위 테스트).
import '../data/gunpula.dart' show pickName;
import '../json_util.dart';
import '../l10n/l10n.dart';
import '../logic/live_stream.dart';
import 'notify_models.dart';

/// 규칙 키 (notify_models.dart notifyRuleDefaults)
const liveRule = 'live_soon';

/// 시작 얼마 전에 알릴지
const liveLead = Duration(minutes: 30);

/// 이보다 가까운 시각에는 걸지 않는다 — 지난 시각은 플러그인이 받지 않고(ArgumentError), 바로 뜨는 알림은 「라이브 예정」 줄이 맡는다
const liveMargin = Duration(minutes: 1);

/// announcements.json 을 푼 값에서 아직 안 끝난 라이브 (live_state · live_at 이 있는 줄). 모든 채널 —
/// 내 채널은 계획할 때 거른다 (채널을 바꿔도 파일을 다시 받지 않게)
List<LiveStream> parseLiveStreams(Object? announcements, DateTime now) => [
  for (final a in jList(jMap(announcements)['announcements']))
    if (jMap(a) case final m when jStr(m['id']).isNotEmpty && (m['live_state'] is String || m['live_at'] is String))
      if (LiveStream(
            id: jStr(m['id']),
            franchise: jStr(m['franchise']),
            title: pickName(m['names']),
            titleZh: pickName(m['names'], const ['zh']),
            at: parseLiveAt(m['live_at']),
            state: jStr(m['live_state']).isEmpty ? 'upcoming' : jStr(m['live_state']),
            source: jStr(m['source_name']),
          )
          case final s when s.stage(now) != LiveStage.ended)
        s,
];

/// 처음 보인 라이브 → 알림함 줄. 곧 할 것(시간 미정 포함)만 — 이미 하는 중 · 끝난 것은 넣지 않는다.
/// [known] = 알림함 줄 id + 지난번에 본 라이브(`stream-<id>`). [quiet] = 처음 받는 날: 읽음으로만 (휴대폰 알림 없음)
List<NoticeRecord> liveRecords(
  NotifyConfig config,
  List<LiveStream> streams,
  Set<String> known,
  DateTime now, {
  bool quiet = false,
}) {
  if (!config.rule(liveRule)) return const [];
  return [
    for (final s in streams)
      if (config.channels.contains(s.franchise) && !known.contains('stream-${s.id}'))
        if (s.stage(now) case LiveStage.upcoming || LiveStage.undated)
          () {
            final parts = [
              // 알림함 줄은 오래 남는다 → 오늘 · 내일이 아니라 날짜로
              s.at == null
                  ? const NoticePart.key('라이브 예정 · 시간 미정')
                  : NoticePart.key('라이브 예정 · {when}', {'when': liveWhen(s.at!, now, relative: false)}),
              if (s.source.isNotEmpty) NoticePart.value(s.source),
            ];
            return NoticeRecord(
              id: 'stream-${s.id}',
              kind: 'live',
              kitId: '',
              annId: s.id,
              title: s.title,
              titlePart: NoticePart.value(s.title, s.titleZh),
              body: parts.map((p) => p.shown).join(' · '),
              bodyParts: parts,
              at: now.toUtc(),
              franchise: s.franchise,
              seen: quiet,
            );
          }(),
  ];
}

/// 걸어 둘 시작 전 알림 하나
class LiveReminder {
  const LiveReminder({
    required this.annId,
    required this.id,
    required this.at,
    required this.title,
    required this.body,
    required this.payload,
  });

  final String annId;

  /// 휴대폰 알림 id — 예고 id 에서 만든다 (같은 id 로 다시 걸면 앞의 것을 바꿔 쓴다)
  final int id;

  /// 띄울 시각 (시작 [liveLead] 전)
  final DateTime at;
  final String title;
  final String body;

  /// `ann:<franchise>:<예고 id>` → 누르면 그 예고 (앱 셸)
  final String payload;
}

/// 시작 전 알림 계획 — [schedule] 을 걸고 [cancel] 을 거둔 뒤 [scheduled] 를 notify_state.json 에 적는다
class LiveReminderPlan {
  const LiveReminderPlan({this.schedule = const [], this.cancel = const [], this.scheduled = const {}});
  final List<LiveReminder> schedule;

  /// 거둘 휴대폰 알림 id (아직 안 뜬 예약도, 이미 떠 있는 알림도 지워진다)
  final List<int> cancel;

  /// 걸려 있는 것: 예고 id → `<시작 시각 UTC>|<언어>` ([liveReminderSig])
  final Map<String, String> scheduled;

  bool get isEmpty => schedule.isEmpty && cancel.isEmpty;
}

int liveReminderId(String annId) => stableId('live:$annId');

/// 걸어 둔 알림의 지문 — 시작 시각이 바뀌거나 화면 언어를 바꾸면 달라져 다시 건다
String liveReminderSig(DateTime at, String lang) => '${at.toUtc().toIso8601String()}|$lang';

/// [streams](지금 아는 라이브) · [scheduled](걸려 있는 것)를 견주어 걸 것 · 거둘 것을 정한다.
///  - 건다: 내 채널 · 시작 시각이 있고 · 아직 시작 전 · 알릴 시각(시작 30분 전)이 [liveMargin] 넘게 남은 것.
///    걸려 있지 않거나 지문이 다르면(시각이 바뀜 · 언어를 바꿈) 다시
///  - 거둔다: [enabled] 가 꺼짐(새 소식 알림 · 규칙) · 목록에서 사라짐 · 끝남 · 내 채널에서 빠짐 · 시간 미정이 됨 ·
///    시각이 바뀌었는데 새 알릴 시각이 이미 지남(당겨져 벌써 하는 중인 것 포함)
///  - 그대로: 알릴 시각이 지났고(떴거나 곧 뜬다) 아직 안 끝난 것 — 거두면 떠 있는 알림이 지워진다
LiveReminderPlan planLiveReminders({
  required List<LiveStream> streams,
  required Map<String, String> scheduled,
  required List<String> channels,
  required bool enabled,
  required DateTime now,
  String lang = 'ko',
}) {
  final byId = {
    for (final s in streams)
      if (enabled && channels.contains(s.franchise)) s.id: s,
  };
  final next = <String, String>{};
  final schedule = <LiveReminder>[];
  final cancel = <int>[];
  for (final e in scheduled.entries) {
    final s = byId[e.key];
    final at = s?.at;
    if (s == null || at == null || s.stage(now) == LiveStage.ended) {
      cancel.add(liveReminderId(e.key));
      continue;
    }
    final sameTime = e.value.split('|').first == at.toUtc().toIso8601String();
    // 이제는 새로 걸 수 없다 — 알릴 시각이 지났거나 이미 하는 중
    final late = !_canRemind(at, now) || s.stage(now) != LiveStage.upcoming;
    if (e.value == liveReminderSig(at, lang) || (sameTime && late)) {
      next[e.key] = e.value; // 언어만 바뀌었는데 이미 떴으면 그대로 둔다
    } else if (late) {
      // 옛 시각에 걸린 것 — 새 시각에는 이미 늦었다. 당겨져서 벌써 하는 중일 때도 거둔다
      // (그대로 두면 옛 시각 30분 전에 "라이브 21:00 시작"이 뒤늦게 뜬다)
      cancel.add(liveReminderId(e.key));
    }
  }
  for (final s in byId.values) {
    final at = s.at;
    if (at == null || next.containsKey(s.id) || s.stage(now) != LiveStage.upcoming || !_canRemind(at, now)) continue;
    next[s.id] = liveReminderSig(at, lang);
    schedule.add(
      LiveReminder(
        annId: s.id,
        id: liveReminderId(s.id),
        at: at.subtract(liveLead),
        title: trf('라이브 {time} 시작', {'time': liveClock(at)}),
        body: liveReminderBody(s),
        payload: 'ann:${s.franchise}:${s.id}',
      ),
    );
  }
  return LiveReminderPlan(schedule: schedule, cancel: cancel, scheduled: next);
}

bool _canRemind(DateTime at, DateTime now) => at.subtract(liveLead).isAfter(now.add(liveMargin));

/// 휴대폰 알림 둘째 줄: 방송 이름 · 출처
String liveReminderBody(LiveStream s) => [s.shown, if (s.source.isNotEmpty) s.source].join(' · ');
