// 예약 시작 전 알림 — 규칙 「예약 시작 전」(preorder_soon) 하나로, 예약이 열리기 30분 전 휴대폰 알림:
//   · 누구: 알림 받는 예고(채널과 상관없이) + 좋아요한 상품(linked_kit_id)의 예약. 시각(preorder_at)을 아는 것만 —
//     날짜만 아는 것은 몇 시에 열지 몰라 알리지 않는다 (00:00 으로 치면 한밤에 울린다). 마감도 알리지 않는다
//   · 알림함 줄은 만들지 않는다 — 알림 받는 예고는 「예약 시작」 단계 알림이 따로 온다
//   · 걸기 · 다시 걸기 · 거두기는 라이브와 같은 계획(live_reminders.dart planStartReminders), 안드로이드 채널은 예고(ann)
// 예약 시각은 예고 파일을 받을 때 notify_state.json 에 적어 둔다 → 알림 받기 · 좋아요 · 규칙이 바뀌면 파일을 다시 받지 않고 계획만.
// 이 파일은 Flutter 위젯을 쓰지 않는다 (백그라운드 isolate · 단위 테스트).
import '../data/gunpula.dart' show pickName;
import '../json_util.dart';
import '../l10n/l10n.dart';
import '../logic/announcement_match.dart' show annReplacedOf, unofficialLabel;
import '../logic/live_stream.dart';
import 'live_reminders.dart';
import 'notify_models.dart';

/// 규칙 키 (notify_models.dart notifyRuleDefaults)
const preorderRule = 'preorder_soon';

/// 열린 뒤 이만큼은 들고 있다 — 그 사이 떠 있는 알림을 지우지 않고, 지나면 목록에서 빼며 거둔다
const preorderKeep = Duration(days: 1);

int preorderReminderId(String annId) => stableId('preorder:$annId');

/// announcements.json 을 푼 값에서 예약 시각(preorder_at)이 있고 열린 지 [preorderKeep] 이 안 지난 예고. 모든 채널 ·
/// 모든 예고 — 누구 것인지는 계획할 때 거른다 (알림 받기 · 좋아요를 바꿔도 파일을 다시 받지 않게). 라이브 · 발매된 예고는 뺀다
List<PreorderOpen> parsePreorderOpens(Object? announcements, DateTime now) {
  final heirs = <String, List<String>>{};
  for (final e in annReplacedOf(announcements).entries) {
    (heirs[e.value] ??= []).add(e.key);
  }
  return [
    for (final a in jList(jMap(announcements)['announcements']))
      if (jMap(a) case final m
          when jStr(m['id']).isNotEmpty &&
              m['live_state'] == null &&
              m['live_at'] == null &&
              jStr(m['status']) != 'released')
        if (parseLiveAt(m['preorder_at']) case final at? when now.isBefore(at.add(preorderKeep)))
          PreorderOpen(
            id: jStr(m['id']),
            franchise: jStr(m['franchise']),
            title: pickName(m['names']),
            titleZh: pickName(m['names'], const ['zh']),
            at: at,
            kitId: jStr(m['linked_kit_id']),
            source: jStr(m['source_name']),
            replaces: heirs[jStr(m['id'])] ?? const [],
            unofficial: m['unofficial'] == true,
          ),
  ];
}

/// 이 예약을 알릴까 — 알림 받는 예고(옛 id 로 눌러 둔 것 포함) · 좋아요한 상품의 예약
bool preorderWatched(PreorderOpen p, {required Set<String> followed, required Set<String> wanted}) =>
    followed.contains(p.id) || p.replaces.any(followed.contains) || (p.kitId.isNotEmpty && wanted.contains(p.kitId));

/// 좋아요를 바꿔 아직 알릴 수 있는 예약(이어진 상품)이 들거나 빠졌나 — 그러면 앱이 다음 확인을 기다리지 않고 계획을 다시 한다
/// (예약 1시간 전에 좋아요를 눌러도 30분 전 알림이 걸리게)
bool preorderWantedTouched(List<PreorderOpen> opens, Set<String> before, Set<String> after, DateTime now) => opens.any(
  (p) =>
      p.kitId.isNotEmpty && before.contains(p.kitId) != after.contains(p.kitId) && p.at.subtract(liveLead).isAfter(now),
);

/// 알림 받기를 누르거나 껐을 때 계획을 다시 할까 — 그 예고(옛 id 포함)에 아직 알릴 수 있는 예약이 있거나 이미 걸려 있을 때,
/// 예약 시각을 아직 한 번도 안 읽었을 때만. 아니면 확인(예고 파일 받기)을 일부러 돌리지 않는다
bool preorderFollowTouched(
  List<PreorderOpen> opens,
  Map<String, String> scheduled,
  String annId, {
  required bool read,
  required DateTime now,
}) =>
    !read ||
    scheduled.containsKey(annId) ||
    opens.any((p) => (p.id == annId || p.replaces.contains(annId)) && p.at.subtract(liveLead).isAfter(now));

/// 예약 시작 전 알림 계획 — [opens](아는 예약) 중 [followed] · [wanted] 에 드는 것을 시작 30분 전에.
/// 거두기 · 다시 걸기는 라이브와 같다 (planStartReminders). [enabled] = 새 소식 알림 · 규칙이 켜짐
LiveReminderPlan planPreorderReminders({
  required List<PreorderOpen> opens,
  required Map<String, String> scheduled,
  required Set<String> followed,
  required Set<String> wanted,
  required bool enabled,
  required DateTime now,
  String lang = 'ko',
}) => planStartReminders(
  [
    for (final p in opens)
      if (enabled && preorderWatched(p, followed: followed, wanted: wanted))
        StartTarget(
          id: p.id,
          at: p.at,
          upcoming: now.isBefore(p.at),
          ended: !now.isBefore(p.at.add(preorderKeep)),
          replaces: p.replaces,
          reminder: (at) => LiveReminder(
            annId: p.id,
            id: preorderReminderId(p.id),
            at: at.subtract(liveLead),
            // 비공식 소식은 「비공식 · 예약 18:00 시작」 (알림 받는 예고 단계 알림과 같게)
            title: [
              if (p.unofficial) tr(unofficialLabel),
              trf('예약 {time} 시작', {'time': liveClock(at)}),
            ].join(' · '),
            body: [p.shown, if (p.source.isNotEmpty) p.source].join(' · '),
            payload: 'ann:${p.franchise}:${p.id}',
            channel: 'ann',
          ),
        ),
  ],
  scheduled: scheduled,
  now: now,
  lang: lang,
  idOf: preorderReminderId,
);
