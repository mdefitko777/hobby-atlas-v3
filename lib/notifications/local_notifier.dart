// 휴대폰 알림 (flutter_local_notifications) — 안드로이드에서만. 웹 미리보기 · 테스트(Windows)에서는 아무것도 하지 않는다.
// 채널(안드로이드 설정 › 알림에서 따로 끌 수 있는 묶음): 새 상품 · 변경 / 좋아요한 상품 / PB 예약
// 누르면 payload 로 이동: kit:<kit_id> → 상품 상세, inbox → 알림 화면 (앱 셸이 [taps] 를 듣는다)
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../theme.dart';
import 'feed_rules.dart' show SystemAlert;

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

  static const channels = <String, AndroidNotificationChannel>{
    'catalog': AndroidNotificationChannel(
      'catalog_updates',
      '새 상품 · 변경',
      description: '내 채널과 알림 규칙(PB · SEED/00 · BBX …)에 맞는 새 상품과 바뀐 상품',
    ),
    'wanted': AndroidNotificationChannel(
      'wanted_changes',
      '좋아요한 상품',
      description: '좋아요한 상품의 가격 · 발매일 · 판매처가 바뀌면',
      importance: Importance.high,
    ),
    'pb': AndroidNotificationChannel(
      'pb_windows',
      '프리미엄 반다이 예약',
      description: '좋아요한 PB 상품의 예약 시작 · 마감 임박 (Wayback 기록이라 늦거나 틀릴 수 있어요)',
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
    for (final a in alerts) {
      final ch = channels[a.channel] ?? channels['catalog']!;
      try {
        await _plugin.show(
          id: a.id,
          title: a.title,
          body: a.body,
          payload: a.payload,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              ch.id,
              ch.name,
              channelDescription: ch.description,
              importance: ch.importance,
              priority: ch.importance == Importance.high ? Priority.high : Priority.defaultPriority,
              styleInformation: BigTextStyleInformation(a.body),
              color: Gp.accent,
              category: AndroidNotificationCategory.recommendation,
            ),
          ),
        );
      } on Object catch (e) {
        debugPrint('[notify] 알림을 띄우지 못함: $e');
      }
    }
  }
}
