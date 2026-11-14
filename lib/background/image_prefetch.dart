// 새 소식 사진 미리 받기 — 뒤 확인(catalog_check_worker.dart)이 새 알림 · 새 상품을 찾으면 그 상품의 작은 그림만
// 그림 캐시(lib/data/net_image_files.dart)에 받아 둔다. 알림을 열면 사진이 바로 보이게.
//  - 주인은 거의 모바일 데이터: 작은 그림만(thumbs.json · Rebrickable 250 px, 원본 · 갤러리는 받지 않음) · 한 번에
//    [prefetchPerRun]장 · [prefetchRunBytes] · 하루 [prefetchDailyCap] (실제로 받은 바이트, 기기 시계 밤 12시에 다시)
//  - 받기는 WorkManager 한 번짜리 일: 「와이파이만」이면 unmetered 망에서만, 배터리 부족이면 안드로이드가 미룬다.
//    데이터 세이버는 다트에서 알 수 없다 (켜져 있으면 뒤 받기가 막혀 실패할 뿐 바이트는 세지 않는다)
//  - 주소는 기기 카탈로그(catalog_kits.json)의 표지 → thumbs.json 이 먼저 (알림 칸이 지금 그리는 주소라 캐시를 같이 쓴다).
//    카탈로그로 작은 판을 모르면 피드 상품의 thumb(Gunpula 가 2026-11-14 부터 싣는 작은 표지 — 이미 작은 그림이라 그대로),
//    그것도 없는 옛 피드면 레고만 kit id 로 Rebrickable 주소를 만들고, 나머지는 [queueKeep] 동안 줄에 두었다가
//    카탈로그가 새로 받힌 뒤에
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import '../data/blob_store.dart';
import '../data/catalog.dart' show Catalog;
import '../data/gunpula.dart' show manifestSignature, thumbsFile;
import '../data/net_image_files.dart';
import '../format.dart' show dayKey;
import '../json_util.dart';
import '../logic/image_size.dart';
import '../notifications/feed_rules.dart' show FeedEntry, feedThumb;
import '../notifications/local_notifier.dart';
import '../notifications/notify_models.dart';

const imagePrefetchKey = 'image_prefetch.json';
const imagePrefetchUniqueName = 'hobbyatlas-image-prefetch';
const imagePrefetchTask = 'imagePrefetch';

/// 하루에 받는 바이트 (모바일 데이터 기준 — 그림 중앙값 80 KB, 작은 그림은 그보다 작다)
const prefetchDailyCap = 15 * 1024 * 1024;

/// 한 번에 받는 장 수 · 바이트 (뒤 확인 3시간마다)
const prefetchPerRun = 40;
const prefetchRunBytes = 3 * 1024 * 1024;

/// 한 번에 잠깐의 실패가 이만큼이면 그만 (망이 끊긴 것 — 다음 확인에서 다시)
const prefetchMisses = 3;

/// 그림 주소를 아직 모르는 상품을 줄에 두는 기간 · 줄 길이
const queueKeep = Duration(days: 2);
const queueMax = 80;

/// 미리 받을 칸 긴 변(물리 px) — 알림 칸 52 dp × 화면 배율 3 을 64 단위로 (알림 화면이 같은 작은 그림 주소를 쓰게)
const prefetchPx = 192.0;

const _rebrickableSets = 'https://cdn.rebrickable.com/media/sets/';

/// 줄에 선 상품 하나
class PrefetchItem {
  const PrefetchItem(this.kitId, this.at, [this.thumb = '']);
  final String kitId;

  /// 줄에 선 때 — [queueKeep] 이 지나면 뺀다
  final DateTime at;

  /// 피드에 실린 작은 표지 (없으면 빈 글자)
  final String thumb;
}

/// image_prefetch.json — 기기에만 (계정에 맞추지 않음)
class PrefetchState {
  PrefetchState({this.day = '', this.bytes = 0, List<PrefetchItem>? queue, this.scanned = ''}) : queue = queue ?? [];

  /// [bytes] 를 센 날 (기기 시계 YYYY-MM-DD)
  String day;
  int bytes;
  final List<PrefetchItem> queue;

  /// 줄을 끝까지 본 때의 카탈로그 판 — 같으면 그림 주소를 모르는 상품을 다시 찾지 않는다 (20 MB 넘는 파일을 읽으므로)
  String scanned;

  int usedOn(DateTime now) => day == dayKey(now.toLocal()) ? bytes : 0;
  int leftOn(DateTime now) => math.max(0, prefetchDailyCap - usedOn(now));

  /// 받은 바이트를 센다 — 날이 바뀌었으면 0 부터
  void spend(int n, DateTime now) {
    final d = dayKey(now.toLocal());
    if (day != d) {
      day = d;
      bytes = 0;
    }
    bytes += n;
  }

  /// 새 상품을 줄 앞에 (이미 있으면 그대로) · 오래된 것은 뺀다. [thumbs] = 상품 id → 피드의 작은 표지.
  /// 줄에 있던 상품도 작은 표지를 새로 알면 적는다 (주소를 몰라 기다리던 것을 받을 수 있게). 새로 선 것 · 적은 것이 있으면 true
  bool enqueue(Iterable<String> ids, DateTime now, {Map<String, String> thumbs = const {}}) {
    queue.removeWhere((q) => now.difference(q.at) > queueKeep);
    var learned = false;
    for (var i = 0; i < queue.length; i++) {
      final q = queue[i];
      final t = thumbs[q.kitId] ?? '';
      if (q.thumb.isEmpty && t.isNotEmpty) {
        queue[i] = PrefetchItem(q.kitId, q.at, t);
        learned = true;
      }
    }
    final have = {for (final q in queue) q.kitId};
    final add = [
      for (final id in ids)
        if (id.isNotEmpty && have.add(id)) PrefetchItem(id, now, thumbs[id] ?? ''),
    ];
    queue.insertAll(0, add);
    if (queue.length > queueMax) queue.removeRange(queueMax, queue.length);
    final changed = add.isNotEmpty || learned;
    if (changed) scanned = '';
    return changed;
  }

  Map<String, Object?> toJson() => {
    'day': day,
    'bytes': bytes,
    'queue': [
      for (final q in queue) [q.kitId, q.at.toUtc().toIso8601String(), if (q.thumb.isNotEmpty) q.thumb],
    ],
    if (scanned.isNotEmpty) 'scanned': scanned,
  };

  static PrefetchState fromJson(Object? json) {
    final j = jMap(json);
    return PrefetchState(
      day: jStr(j['day']),
      bytes: j['bytes'] is num ? (j['bytes']! as num).toInt() : 0,
      queue: [
        for (final q in jList(j['queue']))
          if (q is List && (q.length == 2 || q.length == 3) && q[0] is String)
            if (DateTime.tryParse('${q[1]}') case final at?)
              PrefetchItem(q[0] as String, at, q.length == 3 ? feedThumb(q[2]) : ''),
      ],
      scanned: jStr(j['scanned']),
    );
  }
}

/// 이번 확인에서 새로 온 것 중 사진을 받아 둘 상품 → 피드의 작은 표지(없으면 빈 글자), 받을 순서대로.
/// 새 알림(읽지 않은 것, 예고 · 라이브 줄은 사진이 없다) 먼저, 그다음 내 채널의 새 상품(피드 added, 지난번에 본 날짜부터
/// 처음 보는 줄). 처음 실행은 지난 소식을 조용히 채우는 날이라 없음
Map<String, String> newPrefetchKits({
  required List<NoticeRecord> fresh,
  required List<FeedEntry> entries,
  required NotifyState before,
  required NotifyConfig config,
}) {
  final out = <String, String>{};
  void put(String id, String thumb) {
    if (out.containsKey(id)) {
      if (out[id]!.isEmpty) out[id] = thumb;
    } else if (out.length < prefetchPerRun) {
      out[id] = thumb;
    }
  }

  for (final r in fresh) {
    if (!r.seen && r.kitId.isNotEmpty && !r.isAnnStage && !r.isLive) put(r.kitId, r.thumb);
  }
  if (before.lastSeen.isNotEmpty) {
    final known = {for (final r in before.inbox) r.id, ...before.seenFeed};
    for (final e in entries) {
      if (e.date.compareTo(before.lastSeen) < 0) break; // 날짜 새것부터
      for (final it in e.items) {
        if (it.changeType != 'added' || !config.channels.contains(it.franchise)) continue;
        if (!known.contains('feed-${e.date}-${it.kitId}')) put(it.kitId, it.thumb);
      }
    }
  }
  return out;
}

/// 미리 받을 작은 그림 주소 — 작은 판을 모르면(원본뿐) null. [original] 을 모르는 레고는 kit id 로 원본 주소를 만든다
/// (점검 2026-11-14: 레고 28,597개 중 28,546개가 `lego-<세트 번호>` → `sets/<세트 번호>.jpg`, 나머지는 404 로 끝난다).
/// [feed] = 피드의 작은 표지 — 카탈로그 쪽으로 모를 때만 (알림 칸은 지금 카탈로그 쪽 주소로 그린다)
String? prefetchUrl(String kitId, String? original, ThumbIndex thumbs, [String feed = '']) {
  final src = (original == null || original.isEmpty) && kitId.startsWith('lego-')
      ? '$_rebrickableSets${kitId.substring(5)}.jpg'
      : (original ?? '');
  if (src.startsWith('https://')) {
    final small = imageThumbUrl(src, prefetchPx, thumbs);
    if (small != src) return small;
  }
  return feedThumb(feed).isEmpty ? null : feed;
}

/// 기기 카탈로그 글(catalog_kits.json, `[{"id":…,…,"image":…},…]`)에서 [ids] 의 표지 주소만 찾는다.
/// 뒤 일에서 20 MB 넘는 글을 통째로 풀면 메모리를 크게 쓰니, 그 상품 칸 안의 "image" 하나만 읽는다. 없으면 빠진다
Map<String, String> slimImages(String text, Iterable<String> ids) {
  final out = <String, String>{};
  for (final id in ids) {
    final at = text.indexOf('{"id":${jsonEncode(id)},');
    if (at < 0) continue;
    final next = text.indexOf('{"id":', at + 6);
    final end = next < 0 ? text.length : next;
    final key = text.indexOf('"image":"', at);
    if (key < 0 || key >= end) continue;
    final open = key + 8;
    var i = open + 1;
    while (i < end && text.codeUnitAt(i) != 0x22) {
      i += text.codeUnitAt(i) == 0x5C ? 2 : 1; // \" 는 글자 안
    }
    if (i >= end) continue;
    try {
      final url = jsonDecode(text.substring(open, i + 1));
      if (url is String && url.isNotEmpty) out[id] = url;
    } on FormatException {
      continue;
    }
  }
  return out;
}

/// 뒤 받기 일의 조건 — 「와이파이만」이면 요금이 붙지 않는 망에서만. 배터리가 부족하면 안드로이드가 미룬다
Constraints prefetchConstraints({required bool wifiOnly}) =>
    Constraints(networkType: wifiOnly ? NetworkType.unmetered : NetworkType.connected, requiresBatteryNotLow: true);

/// 뒤 받기 일 걸기 (기본: WorkManager). [replace] = 걸려 있는 일의 조건을 바꾼다 (설정을 바꿨을 때)
typedef SchedulePrefetch = Future<void> Function({required bool wifiOnly, bool replace});

Future<void> schedulePrefetchWork({required bool wifiOnly, bool replace = false}) async {
  if (!LocalNotifier.supported) return; // 웹 미리보기 · 테스트
  try {
    await Workmanager().registerOneOffTask(
      imagePrefetchUniqueName,
      imagePrefetchTask,
      constraints: prefetchConstraints(wifiOnly: wifiOnly),
      // 걸려 있는 일은 그대로 — 줄은 파일에 있어 그 일이 돌 때 새로 선 것도 받는다
      existingWorkPolicy: replace ? ExistingWorkPolicy.replace : ExistingWorkPolicy.keep,
    );
  } on Object catch (e) {
    debugPrint('[prefetch] WorkManager 등록 실패: $e');
  }
}

/// 확인이 끝난 뒤: 새로 온 상품을 줄에 세우고, 받을 것이 있으면 뒤 받기 일을 건다. 걸었으면 true.
/// [thumbs] = 상품 id → 피드의 작은 표지 ([newPrefetchKits])
///  - 오늘 몫을 다 썼으면 걸지 않는다 (줄은 남겨 둔다 — 밤 12시 뒤의 확인에서)
///  - 새로 선 것이 없어도, 그림 주소를 몰라 남은 상품이 있고 카탈로그가 새로 받혔으면([catalogSig] ≠ scanned) 다시
Future<bool> queueImagePrefetch(
  List<String> ids, {
  required bool wifiOnly,
  required DateTime now,
  String? catalogSig,
  Map<String, String> thumbs = const {},
  SchedulePrefetch? schedule,
}) async {
  final sig = catalogSig ?? await readCatalogSig();
  final run = await BlobStore.locked(imagePrefetchKey, () async {
    final s = PrefetchState.fromJson(_decode(await BlobStore.read(imagePrefetchKey)));
    final added = s.enqueue(ids, now, thumbs: thumbs);
    if (added) await BlobStore.write(imagePrefetchKey, jsonEncode(s.toJson()));
    return s.queue.isNotEmpty && s.leftOn(now) > 0 && (added || s.scanned != sig);
  });
  if (run) await (schedule ?? schedulePrefetchWork)(wifiOnly: wifiOnly);
  return run;
}

/// 설정을 바꿨을 때 — 줄이 남아 있으면 걸린 일의 조건(와이파이만 · 모바일 데이터도)을 바꿔 다시 건다
Future<void> reschedulePrefetch({required bool wifiOnly, SchedulePrefetch? schedule}) async {
  final s = PrefetchState.fromJson(_decode(await BlobStore.read(imagePrefetchKey)));
  if (s.queue.isEmpty) return;
  await (schedule ?? schedulePrefetchWork)(wifiOnly: wifiOnly, replace: true);
}

/// 기기 카탈로그의 판 (catalog_meta.json 의 manifest) — 없으면 빈 글자
Future<String> readCatalogSig() async {
  final meta = jMap(_decode(await BlobStore.read(Catalog.cacheMetaKey)));
  return meta['manifest'] == null ? '' : manifestSignature(meta['manifest']);
}

/// 그림 하나 받기 → 새로 받은 바이트 (이미 기기에 있으면 0, 다시 해 볼 실패면 null)
typedef FetchImage = Future<int?> Function(String url);

/// 기본: 그림 캐시에 받는다. 있으면 받지 않는다 (유효 기간이 지났어도 — 보일 때 캐시가 알아서 다시 묻는다).
/// 없는 그림(404 등)은 0 으로 끝내 줄에서 뺀다
Future<int?> fetchToImageCache(String url) async {
  final m = NetImageFiles.manager;
  try {
    if (await m.getFileFromCache(url) != null) return 0;
    final info = await m.downloadFile(url);
    return await info.file.length();
  } on Object catch (e) {
    return NetImageFiles.isTransient(e) ? null : 0;
  }
}

/// 한 번 받기의 결과 (로그 · 시험)
class PrefetchRun {
  const PrefetchRun({this.fetched = 0, this.bytes = 0, this.left = 0, this.urls = const []});
  final int fetched;
  final int bytes;

  /// 줄에 남은 상품 (주소를 모름 · 다시 해 볼 실패 · 한도)
  final int left;

  /// 받으려 한 주소 (시험용)
  final List<String> urls;
}

/// 뒤 받기 일 — 줄의 상품을 그림 주소로 바꿔 작은 그림만 받는다. [readText] · [fetch] 는 시험용
Future<PrefetchRun> runImagePrefetch({
  DateTime? now,
  FetchImage? fetch,
  Future<String?> Function(String key)? readText,
}) async {
  final at = now ?? DateTime.now();
  final read = readText ?? BlobStore.read;
  final s = PrefetchState.fromJson(_decode(await BlobStore.read(imagePrefetchKey)));
  s.queue.removeWhere((q) => at.difference(q.at) > queueKeep);
  final work = s.queue.isNotEmpty && s.leftOn(at) > 0;

  final done = <String>{};
  final urls = <String>[];
  var spent = 0;
  var fetched = 0;
  var misses = 0;
  // 오늘 몫을 다 썼으면 받지 않고 멈춘 것으로 — 밤 12시 뒤의 확인이 다시 건다
  var stopped = s.queue.isNotEmpty && !work;
  var catalogSig = '';
  if (work) {
    final sig = jMap(_decode(await read(Catalog.cacheMetaKey)))['manifest'];
    catalogSig = sig == null ? '' : manifestSignature(sig);
    final images = slimImages(await read(Catalog.cacheKitsKey) ?? '', [for (final q in s.queue) q.kitId]);
    final thumbsText = await read(Catalog.auxKey(thumbsFile));
    final thumbs = thumbsText == null || thumbsText.isEmpty ? ThumbIndex.none : parseThumbIndex(thumbsText);
    for (final q in s.queue) {
      if (fetched >= prefetchPerRun || spent >= prefetchRunBytes || spent >= s.leftOn(at)) {
        stopped = true;
        break;
      }
      final known = images[q.kitId];
      final url = prefetchUrl(q.kitId, known, thumbs, q.thumb);
      if (url == null) {
        // 표지는 아는데 작은 판이 없다 = 원본뿐 → 받지 않는다. 표지를 모르면 카탈로그가 새로 받힐 때까지 줄에
        if (known != null) done.add(q.kitId);
        continue;
      }
      urls.add(url);
      final n = await (fetch ?? fetchToImageCache)(url);
      if (n == null) {
        // 잠깐의 실패 — 끝까지 못 본 것으로 두어 다음 확인이 다시 건다 (판을 적으면 새것이 올 때까지 잊힌다).
        // 망이 끊겼으면 하나씩 15초를 기다리다 WorkManager 10분을 넘기니 [prefetchMisses]번이면 그만
        stopped = true;
        if (++misses >= prefetchMisses) break;
        continue;
      }
      done.add(q.kitId);
      spent += n;
      if (n > 0) fetched++;
    }
  }

  // 그 사이 확인이 줄에 세운 것을 잃지 않게 다시 읽어 합친다
  final left = await BlobStore.locked(imagePrefetchKey, () async {
    final disk = PrefetchState.fromJson(_decode(await BlobStore.read(imagePrefetchKey)));
    disk.queue.removeWhere((q) => done.contains(q.kitId) || at.difference(q.at) > queueKeep);
    if (spent > 0) disk.spend(spent, at);
    // 한도로 멈췄으면 끝까지 못 본 것 — 다음 확인이 다시 걸게 판을 적지 않는다
    if (stopped) {
      disk.scanned = '';
    } else if (work) {
      disk.scanned = catalogSig;
    }
    await BlobStore.write(imagePrefetchKey, jsonEncode(disk.toJson()));
    return disk.queue.length;
  });
  debugPrint('[prefetch] $fetched장 · ${spent ~/ 1024} KB · 남음 $left');
  return PrefetchRun(fetched: fetched, bytes: spent, left: left, urls: urls);
}

Object? _decode(String? text) {
  if (text == null || text.isEmpty) return null;
  try {
    return jsonDecode(text);
  } on FormatException {
    return null;
  }
}
