// 점검(2026-11-14): 그림 받기 — 서버가 정한 짧은 유효 시간(반다이 5분 · Pages 10분)을 30일로 늘리고,
// 두 번 멈춘 서버는 시간 제한으로 끊은 뒤 잠깐 바로 실패시켜 다른 그림의 줄을 막지 않는다 (lib/data/net_image_files.dart)
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_cache_manager/flutter_cache_manager.dart' show HttpExceptionWithStatus;
import 'package:hobby_atlas/data/net_image_files.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _url = 'https://bandai-a.akamaihd.net/bc/img/model/b/1000000000_1.jpg';

void main() {
  setUp(ImageHosts.reset);

  test('짧은 max-age 도 30일은 다시 묻지 않는다 · 더 긴 것은 그대로', () async {
    final service = ImageFileService(
      MockClient((req) async => http.Response('jpg', 200, headers: {'cache-control': 'max-age=300'})),
    );
    final short = await service.get(_url);
    expect(short.validTill.difference(DateTime.now()).inDays, greaterThanOrEqualTo(29));
    expect(service.concurrentFetches, 16);

    final long = await ImageFileService(
      MockClient((req) async => http.Response('jpg', 200, headers: {'cache-control': 'max-age=${86400 * 90}'})),
    ).get(_url);
    expect(long.validTill.difference(DateTime.now()).inDays, greaterThanOrEqualTo(89));
  });

  test('답이 없는 서버: 두 번 늦으면 잠깐 바로 실패 → 지나면 다시 묻는다 · 한 번은 쉬지 않는다', () async {
    var calls = 0;
    final hang = Completer<http.StreamedResponse>();
    final service = ImageFileService(
      MockClient.streaming((req, body) {
        calls++;
        return hang.future;
      }),
      headerTimeout: const Duration(milliseconds: 20),
    );
    await expectLater(service.get(_url), throwsA(isA<TimeoutException>()));
    expect(ImageHosts.isDown(_url), isFalse, reason: '한 번 느린 것으로는 쉬지 않는다');
    await expectLater(service.get('$_url?1'), throwsA(isA<TimeoutException>()));
    expect(ImageHosts.isDown(_url), isTrue);
    expect(ImageHosts.isDown('https://mdefitko777.github.io/gunpula-img-1/a.jpg'), isFalse, reason: '다른 서버는 그대로');

    // 같은 서버의 다른 그림은 묻지 않고 바로
    await expectLater(service.get('$_url?2'), throwsA(isA<ImageHostDown>()));
    expect(calls, 2);

    final later = DateTime.now().add(ImageHosts.downFor + const Duration(seconds: 1));
    ImageHosts.now = () => later;
    expect(ImageHosts.isDown(_url), isFalse);
  });

  test('github.io 는 사진 저장소마다 따로 — 한 저장소가 멈춰도 다른 저장소 · 데이터 그림은 그대로', () {
    const img1 = 'https://mdefitko777.github.io/gunpula-img-1/catalog/a.jpg';
    ImageHosts.stalled(ImageHosts.siteOf(Uri.parse(img1)));
    ImageHosts.stalled(ImageHosts.siteOf(Uri.parse(img1)));
    expect(ImageHosts.isDown(img1), isTrue);
    expect(ImageHosts.isDown('https://mdefitko777.github.io/gunpula-img-3/thumbs/repo/a.jpg.webp'), isFalse);
    expect(ImageHosts.isDown('https://mdefitko777.github.io/Gunpula/app/assets/announcements/x.jpg'), isFalse);
  });

  test('사이에 한 번 답하면 다시 처음부터 센다', () {
    const site = 'bandai-a.akamaihd.net';
    ImageHosts.stalled(site);
    ImageHosts.ok(site);
    ImageHosts.stalled(site);
    expect(ImageHosts.isDown(_url), isFalse);
  });

  test('받는 도중 멈추면 끊는다 — 머리는 오는 서버라 쉬게 하지는 않는다', () async {
    final bodies = <StreamController<List<int>>>[];
    final service = ImageFileService(
      MockClient.streaming((req, _) async {
        final body = StreamController<List<int>>()..add([1, 2, 3]);
        bodies.add(body);
        return http.StreamedResponse(body.stream, 200);
      }),
      idleTimeout: const Duration(milliseconds: 20),
    );
    for (var i = 0; i < 2; i++) {
      final res = await service.get('$_url?$i');
      await expectLater(res.content.toList(), throwsA(isA<TimeoutException>()));
    }
    expect(ImageHosts.isDown(_url), isFalse);
    for (final b in bodies) {
      await b.close();
    }
  });

  test('잠깐의 실패만 기억하지 않는다 — 404 · 깨진 그림은 「열리지 않는 사진」', () {
    expect(NetImageFiles.isTransient(TimeoutException('t')), isTrue);
    expect(NetImageFiles.isTransient(http.ClientException('Connection closed')), isTrue);
    expect(NetImageFiles.isTransient(const ImageHostDown('x')), isTrue);
    expect(NetImageFiles.isTransient(const HttpExceptionWithStatus(503, 'busy')), isTrue);
    expect(NetImageFiles.isTransient(const HttpExceptionWithStatus(404, 'gone')), isFalse);
    expect(NetImageFiles.isTransient(Exception('Invalid image data')), isFalse);
  });
}
