// 새 소식 확인 — 12시간마다 WorkManager(인터넷 연결 시) + 앱을 열 때 · 돌아올 때 같은 함수.
//   1) data/split/manifest.json (176 B) 의 updated_at|total(+ content_hash) 이 지난번과 같으면 피드는 받지 않는다
//   2) 다르면 data/atlas/notify-feed.json (날짜마다 알릴 만한 변화 전부) 을 받는다. 아직 없거나 manifest 보다 옛 판이면
//      data/update-feed-lite.json (날짜마다 20개까지) 으로 채운다 — 지난번 본 날짜 이후만 거른다 (lib/notifications/feed_rules.dart)
//   3) 같은 판의 피드를 못 받았으면(Pages · Gunpula Atlas 작업이 늦음) manifest 를 "다 봤다"고 적지 않는다 → 다음 확인에서 다시
//   3b) 알림 받는 공식 예고가 있으면 data/announcements.json 도 받아 단계가 넘어간 것을 알림으로
//   4) notify_state.json 에 합쳐 쓰고(잠금 · 다시 읽어 합치기), 알림이 켜져 있으면 휴대폰 알림
// 백그라운드에서는 notify_config.json(앱 화면이 써 둔 설정 · 내 채널 · 좋아요)만 읽는다. user.json · 카탈로그는 열지 않는다.
import 'dart:convert';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:workmanager/workmanager.dart';

import '../data/blob_store.dart';
import '../data/gunpula.dart' show gunpulaBase, gunpulaRawBase, gunpulaUserAgent, manifestSignature;
import '../notifications/feed_rules.dart';
import '../notifications/local_notifier.dart';
import '../notifications/notify_models.dart';

const catalogCheckUniqueName = 'hobbyatlas-catalog-check';
const catalogCheckTask = 'catalogCheck';

/// Gunpula 새 소식 파일 (scripts/atlas/build_notify_feed.mjs — 날짜마다 알릴 만한 변화 전부, 개수 제한 없음)
const notifyFeedPath = 'data/atlas/notify-feed.json';

/// 공식 예고 (알림 받기를 누른 예고의 단계를 본다)
const announcementsPath = 'data/announcements.json';

/// 예전 피드 (날짜마다 추가 20 · 변경 20개까지) — 위 파일이 아직 없거나 늦을 때만
const liteFeedPath = 'data/update-feed-lite.json';

/// 새 lite 피드는 왔는데 새 소식 파일이 아직 옛 판이면, 피드를 만든 뒤 이만큼은 다시 받아 본다
/// (Gunpula 의 Atlas 작업은 카탈로그 갱신이 끝난 뒤 몇 분 늦게 올린다)
const atlasGrace = Duration(hours: 2);

/// manifest 와 같은 판의 피드를 이만큼 못 받으면 그만 기다린다 (사진만 다시 받은 날처럼 피드가 안 바뀌는 갱신)
const pendingLimit = Duration(hours: 6);

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
          .get(Uri.parse('$base$path'), headers: kIsWeb ? null : const {'User-Agent': gunpulaUserAgent})
          .timeout(const Duration(seconds: 40));
      if (res.statusCode == 200) return utf8.decode(res.bodyBytes);
      debugPrint('[notify] $base$path → HTTP ${res.statusCode}');
      if (res.statusCode == 404 && path == notifyFeedPath) return null; // 아직 Gunpula 에 없는 파일 — raw 도 같다
    } on Exception catch (e) {
      debugPrint('[notify] $base$path → $e');
    }
  }
  return null;
}

/// 확인 한 번의 결과 (화면에 "새 알림 n" · 오류 문구)
class CheckOutcome {
  const CheckOutcome({required this.liveCount, required this.posted, this.error = '', this.source = ''});
  final int liveCount;
  final int posted;
  final String error;

  /// 읽은 피드 (atlas · lite · atlas+lite, 받지 않았으면 빈 글자)
  final String source;
}

/// 피드 받기의 결과
class FeedLoad {
  const FeedLoad({required this.entries, required this.source, required this.settled});

  /// 날짜 새것부터 (못 받았으면 빈 목록)
  final List<FeedEntry> entries;

  /// atlas · lite · atlas+lite · 빈 글자(둘 다 못 받음)
  final String source;

  /// true = 이 manifest 와 같은 판을 다 봤다 → lastManifest 를 적는다. false = 다음 확인에서 다시 받는다.
  final bool settled;
}

/// 새 소식 파일 먼저, 같은 판이 아니면 lite 피드로 채운다.
///  - 새 소식 파일이 manifest 와 같은 판 → 그것만 (lite 는 받지 않는다)
///  - 새 소식 파일이 없음(404: Gunpula 에 아직 안 들어감) → lite 만, lite 가 같은 판이면 다 본 것으로
///  - 새 소식 파일이 옛 판 → 날짜별로 합쳐 지금 알릴 것은 알리고, lite 를 만든 지 [atlasGrace] 안이면 다시 받아 본다
///    (그 사이 늘어난 상품은 같은 날짜의 seenFeed 에 없으니 다음 확인에서 알림이 된다)
Future<FeedLoad> loadFeed(FetchText get, Map<String, Object?> manifest, DateTime now) async {
  final atlasJson = _decode(await get(notifyFeedPath));
  final atlas = atlasJson is Map<String, Object?> && atlasJson['schema'] == 1 ? parseFeed(atlasJson) : null;
  if (atlas != null && feedMatches(atlas, manifest)) return FeedLoad(entries: atlas, source: 'atlas', settled: true);
  final liteJson = _decode(await get(liteFeedPath));
  final lite = liteJson is Map<String, Object?> ? parseFeed(liteJson) : null;
  if (lite == null) {
    return FeedLoad(entries: atlas ?? const [], source: atlas == null ? '' : 'atlas', settled: false);
  }
  final entries = atlas == null ? lite : combineFeeds(atlas, lite);
  final source = atlas == null ? 'lite' : 'atlas+lite';
  if (!feedMatches(lite, manifest)) return FeedLoad(entries: entries, source: source, settled: false);
  final made = lite.first.generatedAt;
  final waitedEnough = made == null || now.toUtc().difference(made) > atlasGrace;
  return FeedLoad(entries: entries, source: source, settled: atlas == null || waitedEnough);
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
  var source = '';
  var pending = before.pending;
  var entries = const <FeedEntry>[];
  final manifest = _decode(await get('data/split/manifest.json'));
  if (manifest is! Map<String, Object?>) {
    error = '인터넷에 연결하지 못했어요';
  } else {
    sig = manifestSignature(manifest); // updated_at|total (+ |content_hash)
    if (sig != before.lastManifest || before.lastSeen.isEmpty) {
      final f = await loadFeed(get, manifest, at);
      entries = f.entries;
      source = f.source;
      if (f.source.isEmpty) {
        error = '새 소식 파일을 받지 못했어요';
        sig = ''; // 다음에 다시 받기
      } else if (!f.settled) {
        // 같은 판을 아직 못 받았다 → 다음 확인에서 다시. 처음 본 뒤 [pendingLimit] 이 지나면 그만 기다린다.
        final since = pending.startsWith('$sig|') ? DateTime.tryParse(pending.substring(sig.length + 1)) : null;
        if (since == null) {
          pending = '$sig|${at.toUtc().toIso8601String()}';
          sig = '';
        } else if (at.difference(since) < pendingLimit) {
          sig = '';
        } else {
          pending = '';
        }
      } else {
        pending = '';
      }
    }
  }

  // 알림 받는 예고가 있으면 예고 파일도 (단계가 넘어갔는지)
  final announcements = config.followed.isEmpty ? null : _decode(await get(announcementsPath));
  final plan = planCheck(
    announcements: announcements,
    config: config,
    state: before,
    entries: entries,
    manifestSig: sig,
    now: at,
    error: error,
    source: source,
    pending: pending,
  );
  // 쓰기 직전에 잠그고 파일을 다시 읽어 합친다 (그 사이 앱 화면 · 다른 확인이 썼을 수 있다)
  final fresh = await BlobStore.locked(notifyStateKey, () async {
    final disk = NotifyState.fromJson(_decode(await BlobStore.read(notifyStateKey)));
    final onDisk = {for (final r in disk.inbox) r.id};
    final next = NotifyState.merge(disk, plan.applyTo(before))..prune(at);
    await BlobStore.write(notifyStateKey, jsonEncode(next.toJson()));
    return [
      for (final r in plan.records)
        if (!onDisk.contains(r.id)) r,
    ];
  });

  var posted = 0;
  if (config.enabled && LocalNotifier.supported) {
    final alerts = buildAlerts(fresh);
    await LocalNotifier.post(alerts, foreground: !background);
    posted = alerts.length;
  }
  return CheckOutcome(liveCount: fresh.where((r) => !r.seen).length, posted: posted, error: error, source: source);
}
