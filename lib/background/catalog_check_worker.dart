// 새 소식 확인 — 12시간마다 WorkManager(인터넷 연결 시) + 앱을 열 때 · 돌아올 때 같은 함수.
//   1) data/split/manifest.json (176 B) 의 updated_at|total 이 지난번과 같으면 피드는 받지 않는다
//   2) 다르면 data/update-feed-lite.json 을 받아 지난번 본 날짜 이후만 거른다 (lib/notifications/feed_rules.dart)
//   3) notify_state.json 에 합쳐 쓰고, 알림이 켜져 있으면 휴대폰 알림
// 백그라운드에서는 notify_config.json(앱 화면이 써 둔 설정 · 내 채널 · 좋아요)만 읽는다. user.json · 카탈로그는 열지 않는다.
import 'dart:convert';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:workmanager/workmanager.dart';

import '../data/blob_store.dart';
import '../data/gunpula.dart' show gunpulaBase, gunpulaRawBase;
import '../notifications/feed_rules.dart';
import '../notifications/local_notifier.dart';
import '../notifications/notify_models.dart';

const catalogCheckUniqueName = 'hobbyatlas-catalog-check';
const catalogCheckTask = 'catalogCheck';

/// WorkManager 가 앱이 꺼져 있어도 부르는 입구 (반드시 최상위 함수 + entry-point 표시)
@pragma('vm:entry-point')
void catalogCheckDispatcher() {
  Workmanager().executeTask((task, input) async {
    DartPluginRegistrant.ensureInitialized();
    try {
      final r = await runCatalogCheck(background: true);
      debugPrint('[notify] 백그라운드 확인: 새 알림 ${r.liveCount} ${r.error}');
    } on Object catch (e) {
      debugPrint('[notify] 백그라운드 확인 실패: $e');
    }
    // 실패해도 true — 다시 시도는 다음 주기에 (Pages 가 잠깐 안 될 때 몰아서 다시 받지 않게)
    return true;
  });
}

/// 앱을 켤 때마다 부른다. 켜져 있으면 12시간 주기 등록(이미 있으면 그대로), 꺼져 있으면 지운다.
Future<void> scheduleCatalogCheck({required bool enabled}) async {
  if (!LocalNotifier.supported) return; // 웹 미리보기 · 테스트
  try {
    await Workmanager().initialize(catalogCheckDispatcher);
    if (enabled) {
      await Workmanager().registerPeriodicTask(
        catalogCheckUniqueName,
        catalogCheckTask,
        frequency: const Duration(hours: 12),
        initialDelay: const Duration(minutes: 30),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep, // 이미 있으면 그대로 (앱을 열 때마다 주기를 처음부터 다시 세지 않게)
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(minutes: 30),
      );
    } else {
      await Workmanager().cancelByUniqueName(catalogCheckUniqueName);
    }
  } on Object catch (e) {
    debugPrint('[notify] WorkManager 등록 실패: $e');
  }
}

/// Gunpula Pages 에서 글자 파일 하나 (안 되면 raw.githubusercontent). 실패하면 null.
typedef FetchText = Future<String?> Function(String path);

Future<String?> fetchGunpula(String path) async {
  for (final base in [gunpulaBase, gunpulaRawBase]) {
    try {
      final res = await http
          .get(
            Uri.parse('$base$path'),
            // 웹은 User-Agent 를 바꿀 수 없다
            headers: kIsWeb
                ? null
                : const {'User-Agent': 'HobbyAtlas/1.0 (Android; +https://github.com/mdefitko777/Gunpula)'},
          )
          .timeout(const Duration(seconds: 40));
      if (res.statusCode == 200) return utf8.decode(res.bodyBytes);
      debugPrint('[notify] $base$path → HTTP ${res.statusCode}');
    } on Exception catch (e) {
      debugPrint('[notify] $base$path → $e');
    }
  }
  return null;
}

/// 확인 한 번의 결과 (화면에 "새 알림 n" · 오류 문구)
class CheckOutcome {
  const CheckOutcome({required this.liveCount, required this.posted, this.error = ''});
  final int liveCount;
  final int posted;
  final String error;
}

Object? _decode(String? text) {
  if (text == null) return null;
  try {
    return jsonDecode(text);
  } on FormatException {
    return null;
  }
}

/// 파일 → 계산 → 파일 (+ 휴대폰 알림). 앱 화면 · 백그라운드 공통.
Future<CheckOutcome> runCatalogCheck({bool background = false, DateTime? now, FetchText? fetch}) async {
  final at = now ?? DateTime.now();
  final get = fetch ?? fetchGunpula;
  final config = NotifyConfig.fromJson(_decode(await BlobStore.read(notifyConfigKey)));
  final before = NotifyState.fromJson(_decode(await BlobStore.read(notifyStateKey)));

  var error = '';
  var sig = '';
  var entries = const <FeedEntry>[];
  final mText = await get('data/split/manifest.json');
  final manifest = _decode(mText);
  if (manifest is! Map<String, Object?>) {
    error = '인터넷에 연결하지 못했어요';
  } else {
    sig = '${manifest['updated_at']}|${manifest['total']}';
    if (sig != before.lastManifest || before.lastSeen.isEmpty) {
      final feed = _decode(await get('data/update-feed-lite.json'));
      if (feed == null) {
        error = '새 소식 파일을 받지 못했어요';
        sig = ''; // 다음에 다시 받기
      } else {
        entries = parseFeed(feed);
      }
    }
  }

  final plan = planCheck(config: config, state: before, entries: entries, manifestSig: sig, now: at, error: error);
  // 쓰기 직전에 파일을 다시 읽어 합친다 (그 사이 앱 화면 · 다른 확인이 썼을 수 있다)
  final disk = NotifyState.fromJson(_decode(await BlobStore.read(notifyStateKey)));
  final onDisk = {for (final r in disk.inbox) r.id};
  final fresh = [
    for (final r in plan.records)
      if (!onDisk.contains(r.id)) r,
  ];
  final next = NotifyState.merge(disk, plan.applyTo(before))..prune(at);
  await BlobStore.write(notifyStateKey, jsonEncode(next.toJson()));

  var posted = 0;
  if (config.enabled && LocalNotifier.supported) {
    final alerts = buildAlerts(fresh);
    await LocalNotifier.post(alerts, foreground: !background);
    posted = alerts.length;
  }
  return CheckOutcome(liveCount: fresh.where((r) => !r.seen).length, posted: posted, error: error);
}
