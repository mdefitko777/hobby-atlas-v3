// 인터넷 그림 받기 · 기기 캐시 — 상품 사진 · 예고 그림을 모두 이 캐시로 받는다 (그리는 쪽은 lib/widgets/images.dart).
// 점검(2026-11-14, 한국 집 인터넷): 그림 서버는 빠르다(154장 중앙값 0.26초). 느렸던 건 앱 쪽 기본 캐시:
//  · 200장까지만 남겨 알림 · 최근 추가 · 홈 줄 · 예고만으로 넘쳐 매번 다시 받았다
//  · 서버가 정한 유효 시간(반다이 5분 · Pages 10분 · 건담 공식 15초)이 지나면 보일 때마다 다시 받고(반다이는 ETag 가 없어 통째로)
//    다시 풀었다. 그 다시 받기가 동시 10개 줄을 차지해 처음 보는 그림이 뒤로 밀렸다
//  · 시간 제한이 없어 멈춘 서버 하나가 줄 한 칸을 2분쯤 붙잡을 수 있었다
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
// cached_network_image 가 쓰는 캐시 패키지 (pubspec.lock 3.4.6, 간접 의존). 패치(Shorebird)는 pubspec 을 바꿀 수 없어
// 직접 의존으로 올리지 않았다 — 다음 APK 릴리스 때 pubspec 에 `flutter_cache_manager: ^3.4.6` 을 넣고 이 ignore 를 지운다
// ignore: depend_on_referenced_packages
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;

import 'net_image_files_io.dart' if (dart.library.js_interop) 'net_image_files_web.dart' as impl;

abstract final class NetImageFiles {
  /// 기본 캐시(DefaultCacheManager)와 같은 이름 — 이미 받아 둔 그림 파일과 목록을 버리지 않는다
  static const cacheKey = 'libCachedImageData';

  /// 받은 그림을 서버에 다시 묻지 않는 기간. 사진 저장소(gunpula-img-N)는 내용이 바뀌면 주소가 바뀌고,
  /// 공식 사진이 같은 주소에서 바뀌는 일은 드물다
  static const keepFor = Duration(days: 30);

  /// 기기에 남기는 그림 수 · 이만큼 안 본 그림은 지운다 (중앙값 약 80 KB → 2000장 ≈ 160 MB)
  static const maxFiles = 2000;
  static const unusedFor = Duration(days: 60);

  static BaseCacheManager? _manager;

  static BaseCacheManager get manager => _manager ??= CacheManager(
    Config(
      cacheKey,
      stalePeriod: unusedFor,
      maxNrOfCacheObjects: maxFiles,
      fileService: ImageFileService(impl.createImageClient()),
    ),
  );

  @visibleForTesting
  static set manager(BaseCacheManager m) => _manager = m;

  /// 미리 받기 — 안드로이드에서만 (테스트 · 웹 미리보기는 하지 않는다)
  static bool prefetchOn = impl.prefetchOn;
  static final _prefetched = <String>{};

  /// 다음에 열 화면의 위쪽 그림을 기기에 받아 둔다 (풀지는 않는다). 앱을 켠 동안 같은 주소는 한 번만.
  /// 지금 화면 그림이 먼저 줄을 서도록 2초 뒤에
  static void prefetch(Iterable<String> urls, {int limit = 16}) {
    if (!prefetchOn) return;
    final todo = [
      for (final u in urls)
        if (u.startsWith('http') && !_prefetched.contains(u)) u,
    ].take(limit).toList();
    if (todo.isEmpty) return;
    _prefetched.addAll(todo);
    Timer(const Duration(seconds: 2), () {
      for (final u in todo) {
        if (!ImageHosts.isDown(u)) unawaited(manager.getSingleFile(u).then((_) {}, onError: (Object _) {}));
      }
    });
  }

  /// 잠깐의 실패(시간 초과 · 연결 끊김 · 멈춘 서버 · 서버 5xx) — 그 주소를 「열리지 않는 사진」으로 기억하지 않는다
  static bool isTransient(Object error) =>
      error is TimeoutException ||
      error is http.ClientException ||
      error is ImageHostDown ||
      (error is HttpExceptionWithStatus && error.statusCode >= 500);
}

/// 멈춘 그림 서버 — 사이에 답 한 번 없이 [strikes]번 시간 안에 답하지 않은 서버는 [downFor] 동안 바로 실패시켜
/// 줄을 막지 않게 한다 (그동안 목록 사진은 다른 서버의 같은 상품 사진으로 — images.dart). 앱을 켠 동안만 기억.
/// 한 번 느린 것으로는 쉬지 않는다 — 폰 쪽 LTE 가 잠깐 끊겨도 모든 서버가 한 번씩 늦기 때문.
/// github.io 는 사진 저장소 4곳 · 데이터가 한 호스트라 저장소(첫 경로)까지 나눠 본다
abstract final class ImageHosts {
  static const downFor = Duration(minutes: 1);
  static const strikes = 2;
  static final _misses = <String, int>{};
  static final _downUntil = <String, DateTime>{};

  @visibleForTesting
  static DateTime Function() now = DateTime.now;

  /// 서버 단위 — `호스트` (github.io 는 `호스트/저장소`)
  static String siteOf(Uri uri) {
    if (!uri.host.endsWith('.github.io')) return uri.host;
    final seg = uri.pathSegments;
    return seg.isEmpty ? uri.host : '${uri.host}/${seg.first}';
  }

  static bool isDown(String url) {
    if (_downUntil.isEmpty) return false; // 목록 사진마다 그릴 때 부르므로 주소를 풀기 전에
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final site = siteOf(uri);
    final until = _downUntil[site];
    if (until == null) return false;
    if (now().isBefore(until)) return true;
    _downUntil.remove(site);
    _misses.remove(site);
    return false;
  }

  static void stalled(String site) {
    final n = _misses[site] = (_misses[site] ?? 0) + 1;
    if (n >= strikes) _downUntil[site] = now().add(downFor);
  }

  static void ok(String site) {
    _misses.remove(site);
    _downUntil.remove(site);
  }

  @visibleForTesting
  static void reset() {
    _misses.clear();
    _downUntil.clear();
    now = DateTime.now;
  }
}

/// 멈춘 서버라 묻지 않고 바로 실패
class ImageHostDown implements Exception {
  const ImageHostDown(this.site);
  final String site;

  @override
  String toString() => 'ImageHostDown($site)';
}

/// 그림 받기: 같은 연결을 다시 쓰는 클라이언트 하나 · 동시 16개 · 시간 제한 · 긴 유효 기간
class ImageFileService extends FileService {
  ImageFileService(
    this._client, {
    this.headerTimeout = const Duration(seconds: 15),
    this.idleTimeout = const Duration(seconds: 15),
  }) {
    // 기본 10 — 그림이 작고(중앙값 80 KB) 서버가 여럿이라 한 화면 그림을 한 번에 받게
    concurrentFetches = 16;
  }

  final http.Client _client;

  /// 요청부터 답 머리까지 (연결 8초는 클라이언트 쪽)
  final Duration headerTimeout;

  /// 받는 도중 이만큼 아무것도 오지 않으면 끊는다
  final Duration idleTimeout;

  @override
  Future<FileServiceResponse> get(String url, {Map<String, String>? headers}) async {
    final uri = Uri.parse(url);
    final site = ImageHosts.siteOf(uri);
    if (ImageHosts.isDown(url)) throw ImageHostDown(site);
    final req = http.Request('GET', uri);
    if (headers != null) req.headers.addAll(headers);
    final http.StreamedResponse res;
    try {
      res = await _client.send(req).timeout(headerTimeout);
    } on Object catch (e) {
      if (e is TimeoutException || (e is http.ClientException && e.message.contains('timed out'))) {
        ImageHosts.stalled(site);
      }
      rethrow;
    }
    ImageHosts.ok(site);
    return _ImageResponse(HttpGetResponse(res), site, idleTimeout);
  }
}

/// 서버 답 그대로 + 유효 기간은 적어도 [NetImageFiles.keepFor] · 받는 도중 멈추면 끊기
class _ImageResponse implements FileServiceResponse {
  _ImageResponse(this._inner, this._site, this._idle);
  final HttpGetResponse _inner;
  final String _site;
  final Duration _idle;
  final _received = DateTime.now();

  @override
  Stream<List<int>> get content => _inner.content.timeout(
    _idle,
    onTimeout: (sink) {
      ImageHosts.stalled(_site);
      sink.addError(TimeoutException('image body stalled', _idle));
    },
  );

  @override
  int? get contentLength => _inner.contentLength;

  @override
  int get statusCode => _inner.statusCode;

  @override
  DateTime get validTill {
    final floor = _received.add(NetImageFiles.keepFor);
    final server = _inner.validTill;
    return server.isAfter(floor) ? server : floor;
  }

  @override
  String? get eTag => _inner.eTag;

  @override
  String get fileExtension => _inner.fileExtension;
}
