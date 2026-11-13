// 휴대폰 알림 (flutter_local_notifications) — 안드로이드에서만. 웹 미리보기 · 테스트(Windows)에서는 아무것도 하지 않는다.
// 채널(안드로이드 설정 › 알림에서 따로 끌 수 있는 묶음): 새 상품 · 변경 / 좋아요한 상품 / PB 예약 / 재판매 / 예약 도착 / 라이브
// 누르면 payload 로 이동: kit:<kit_id> → 상품 상세, ann:<franchise>:<id> → 공식 예고, inbox → 알림 화면 (앱 셸이 [taps] 를 듣는다)
// 라이브 시작 전 알림만 미리 걸어 둔다 (zonedSchedule — AndroidManifest 의 ScheduledNotification…Receiver 가 띄우고, 재부팅 뒤 다시 건다)
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../l10n/l10n.dart';
import '../theme.dart';
import 'feed_rules.dart' show SystemAlert;
import 'live_reminders.dart';

class LocalNotifier {
  LocalNotifier._();

  /// 안드로이드 기기에서만 (kIsWeb 먼저 — 웹에서는 dart:io Platform 을 부르면 안 된다)
  static bool get supported => !kIsWeb && Platform.isAndroid;

  /// 알림을 눌러 들어온 payload — 앱 셸이 처리하고 null 로 되돌린다
  static final taps = ValueNotifier<String?>(null);

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  /// res/drawable/ic_stat_notify.xml (흰 실루엣 종). res/raw/keep.xml 로 R8 이 지우지 않게 해 두었다.
  static const _icon = 'ic_stat_notify';

  /// 채널 이름 · 설명은 고른 화면 언어로 (id 는 그대로 — 같은 id 로 다시 만들면 안드로이드가 이름만 바꾼다)
  static Map<String, AndroidNotificationChannel> get channels => {
    'catalog': AndroidNotificationChannel(
      'catalog_updates',
      tr('새 상품 · 변경'),
      description: tr('내 채널과 알림 규칙(PB · SEED/00 · BBX …)에 맞는 새 상품과 바뀐 상품'),
    ),
    'wanted': AndroidNotificationChannel(
      'wanted_changes',
      tr('좋아요한 상품'),
      description: tr('좋아요한 상품의 가격 · 발매일 · 판매처가 바뀌면'),
      importance: Importance.high,
    ),
    'pb': AndroidNotificationChannel(
      'pb_windows',
      tr('프리미엄 반다이 예약'),
      description: tr('좋아요한 PB 상품의 예약 시작 · 마감 임박 (Wayback 기록이라 늦거나 틀릴 수 있어요)'),
      importance: Importance.high,
    ),
    'restock': AndroidNotificationChannel(
      'restocks',
      tr('재판매'),
      description: tr('좋아요 · 구매함 상품의 재판매(再販) 소식'),
      importance: Importance.high,
    ),
    'preorder': AndroidNotificationChannel(
      'preorder_arrivals',
      tr('예약 도착'),
      description: tr('예약한 상품의 도착 달 · 도착 날 (내가 적은 도착 예정)'),
      importance: Importance.high,
    ),
    'ann': AndroidNotificationChannel(
      'announcement_stages',
      // 채널 id 는 그대로 (바꾸면 사용자가 꺼 둔 설정이 풀린다). 이름 · 설명은 init · renameChannels 가 같은 id 로 바꿔 쓴다.
      // 비공식 소식도 이 채널로 와서 「공식」을 뺐다
      tr('알림 받는 예고'),
      description: tr('알림 받기를 누른 예고가 상품화 확정 · 예약 시작 · 발매로 넘어가면'),
      importance: Importance.high,
    ),
    'live': AndroidNotificationChannel(
      'live_streams',
      tr('라이브'),
      description: tr('내 채널 공식 라이브: 새로 올라온 라이브 · 시작 30분쯤 전'),
      importance: Importance.high,
    ),
  };

  /// [foreground] = 앱 화면 쪽 (누르기 · 앱을 연 알림을 받는다). 백그라운드 확인은 false.
  static Future<void> init({bool foreground = true}) async {
    if (!supported || _ready) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(android: AndroidInitializationSettings(_icon)),
        onDidReceiveNotificationResponse: foreground ? (r) => taps.value = _payload(r.payload) : null,
      );
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      for (final c in channels.values) {
        await android?.createNotificationChannel(c);
      }
      _ready = true;
      if (foreground) {
        // 앱이 꺼져 있을 때 알림을 눌러 켠 경우
        final launch = await _plugin.getNotificationAppLaunchDetails();
        if (launch?.didNotificationLaunchApp ?? false) taps.value = _payload(launch!.notificationResponse?.payload);
      }
    } on Object catch (e) {
      debugPrint('[notify] 알림 준비 실패: $e');
    }
  }

  /// 화면 언어를 바꾼 뒤: 같은 id 로 채널을 다시 만들어 이름 · 설명만 새 언어로 (안드로이드가 중요도 · 사용자가 끈 설정은 그대로 둔다).
  /// 아직 준비 전이면 할 일 없음 — init 이 그때의 언어로 만든다
  static Future<void> renameChannels() async {
    if (!supported || !_ready) return;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      for (final c in channels.values) {
        await android?.createNotificationChannel(c);
      }
    } on Object catch (e) {
      debugPrint('[notify] 채널 이름을 바꾸지 못함: $e');
    }
  }

  static String _payload(String? p) => (p == null || p.isEmpty) ? 'inbox' : p;

  /// 안드로이드 13+ POST_NOTIFICATIONS 권한 창. 12 이하는 바로 true.
  static Future<bool> requestPermission() async {
    if (!supported) return false;
    await init();
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? false;
    } on Object catch (e) {
      debugPrint('[notify] 권한 요청 실패: $e');
      return false;
    }
  }

  /// 지금 알림을 보낼 수 있나 (설정에서 꺼 두었으면 false). 모르면 null.
  static Future<bool?> permitted() async {
    if (!supported) return null;
    await init();
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return await android?.areNotificationsEnabled();
    } on Object {
      return null;
    }
  }

  static Future<void> post(List<SystemAlert> alerts, {bool foreground = true}) async {
    if (!supported || alerts.isEmpty) return;
    await init(foreground: foreground);
    final all = channels;
    for (final a in alerts) {
      try {
        await _plugin.show(
          id: a.id,
          title: a.title,
          body: a.body,
          payload: a.payload,
          notificationDetails: _details(all[a.channel] ?? all['catalog']!, a.body),
        );
      } on Object catch (e) {
        debugPrint('[notify] 알림을 띄우지 못함: $e');
      }
    }
  }

  static NotificationDetails _details(AndroidNotificationChannel ch, String body) => NotificationDetails(
    android: AndroidNotificationDetails(
      ch.id,
      ch.name,
      channelDescription: ch.description,
      importance: ch.importance,
      priority: ch.importance == Importance.high ? Priority.high : Priority.defaultPriority,
      styleInformation: BigTextStyleInformation(body),
      color: Gp.accent,
      category: AndroidNotificationCategory.recommendation,
    ),
  );

  /// 라이브 · 예약 시작 전 알림을 계획대로 걸고 거둔다 (live_reminders.dart planStartReminders). 걸지 못한 예고 id 를 돌려준다 →
  /// 부르는 쪽이 "걸려 있음"에서 빼 두어 다음 확인에서 다시 건다.
  /// inexactAllowWhileIdle: 정확한 알람 권한(SCHEDULE_EXACT_ALARM · 안드로이드 12+ 는 따로 허락)을 쓰지 않는다 —
  /// 대신 몇 분 늦게 뜰 수 있다 (30분 전 알림이라 괜찮다). 시각은 UTC 한 점으로 넘겨 시간대 표(tz database)가 필요 없다
  static Future<Set<String>> applyLive(LiveReminderPlan plan, {bool foreground = true}) async {
    if (!supported || plan.isEmpty) return const {};
    await init(foreground: foreground);
    for (final id in plan.cancel) {
      try {
        await _plugin.cancel(id: id);
      } on Object catch (e) {
        debugPrint('[notify] 라이브 알림을 거두지 못함: $e');
      }
    }
    final all = channels;
    final failed = <String>{};
    for (final r in plan.schedule) {
      final ch = all[r.channel] ?? all['live']!; // 예약 시작 전 = 예고 채널
      try {
        await _plugin.zonedSchedule(
          id: r.id,
          title: r.title,
          body: r.body,
          payload: r.payload,
          scheduledDate: tz.TZDateTime.from(r.at, tz.UTC),
          notificationDetails: _details(ch, r.body),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } on Object catch (e) {
        debugPrint('[notify] 라이브 알림을 걸지 못함: $e');
        failed.add(r.annId);
      }
    }
    return failed;
  }
}
