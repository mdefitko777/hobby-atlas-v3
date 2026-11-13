// 점검(2026-11-14): 그림이 칸 크기로 풀리는지 · 크게 보기만 원본인지 · 작은 그림이 안 되면 원본으로 가는지 ·
// 알림 목록이 보이는 줄만 만드는지
// (images.dart AppImage · BoxDecodeImage, n_notifications_screen.dart)
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_cache_manager/flutter_cache_manager.dart'
    show BaseCacheManager, FileResponse, HttpExceptionWithStatus;
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/clock.dart';
import 'package:hobby_atlas/data/net_image_files.dart';
import 'package:hobby_atlas/logic/image_size.dart';
import 'package:hobby_atlas/notifications/notify_models.dart';
import 'package:hobby_atlas/notifications/notify_store.dart';
import 'package:hobby_atlas/screens/n_notifications_screen.dart';
import 'package:hobby_atlas/widgets/images.dart';

import 'notify_screen_test.dart' show loadersFor, pumpApp;

/// 받지 않는 캐시 — 그림 위젯이 무엇을 부르는지만 본다
class _NoNet extends Fake implements BaseCacheManager {
  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) => const Stream.empty();
}

/// [fail] 에 있는 주소만 그 오류로 실패하는 캐시
class _FailNet extends Fake implements BaseCacheManager {
  _FailNet(this.fail);
  final Map<String, Object> fail;
  final asked = <String>[];

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) {
    asked.add(url);
    final e = fail[url];
    return e == null ? const Stream.empty() : Stream.error(e);
  }
}

const _bandai = 'https://bandai-a.akamaihd.net/bc/img/model/b/1000000000_1.jpg';
const _bandaiThumb =
    'https://mdefitko777.github.io/gunpula-img-3/thumbs/web/bandai-a.akamaihd.net/0123456789abcdef.webp';

/// 그림 받기는 진짜 비동기라 잠깐 실제로 기다린 뒤 다시 그린다 (작은 그림 실패 → 원본)
Future<void> _settleNet(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump();
  }
}

String _urlOf(ImageProvider p) => ((p is BoxDecodeImage ? p.inner : p) as CachedNetworkImageProvider).url;

List<ImageProvider> _providers(WidgetTester tester) => [
  for (final i in tester.widgetList<Image>(find.byType(Image))) i.image,
];

Future<void> _pumpBox(WidgetTester tester, Widget child, {double w = 52, double h = 52}) async {
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: SizedBox(width: w, height: h, child: child),
      ),
    ),
  );
}

/// [w]×[h] PNG (진짜로 풀어 보려고)
Future<Uint8List> _png(int w, int h) async {
  final rec = ui.PictureRecorder();
  ui.Canvas(rec).drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), Paint()..color = Colors.blue);
  final img = await rec.endRecording().toImage(w, h);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  return data!.buffer.asUint8List();
}

Future<ui.Image> _resolve(ImageProvider provider) {
  final done = Completer<ui.Image>();
  provider
      .resolve(ImageConfiguration.empty)
      .addListener(ImageStreamListener((info, _) => done.complete(info.image), onError: done.completeError));
  return done.future;
}

void main() {
  setUp(() {
    NetImageFiles.manager = _NoNet();
    BrokenImages.reset();
    ImageAlternates.reset();
    ImageAlternates.source = () => const {};
    ImageHosts.reset();
    ThumbIndex.current = ThumbIndex.none;
  });
  tearDown(() => ThumbIndex.current = ThumbIndex.none);

  testWidgets('알림 사진 칸(52 dp, 3배 화면)은 192 px 로 풀고, 받는 동안은 바로 회색 칸', (tester) async {
    await _pumpBox(tester, const PhotoThumb(_bandai));
    final p = _providers(tester).single;
    expect(p, isA<BoxDecodeImage>());
    final box = p as BoxDecodeImage;
    expect((box.width, box.height, box.fit), (192.0, 192.0, DecodeFit.cover));
    expect((box.inner as CachedNetworkImageProvider).url, _bandai);
    expect((box.inner as CachedNetworkImageProvider).cacheManager, same(NetImageFiles.manager));
    // 560² 원본 → 192² (예전에는 560² 그대로 = 픽셀 8.5배)
    expect(decodeSize(560, 560, box.width, box.height, box.fit), (width: 192, height: 192));
    expect(find.byType(ColoredBox), findsWidgets);
  });

  testWidgets('레고 표지는 작은 그림 주소로 받는다', (tester) async {
    await _pumpBox(tester, const PhotoThumb('https://cdn.rebrickable.com/media/sets/31209-1.jpg'));
    final box = _providers(tester).single as BoxDecodeImage;
    expect(
      (box.inner as CachedNetworkImageProvider).url,
      'https://cdn.rebrickable.com/media/thumbs/sets/31209-1.jpg/250x250p.jpg',
    );
  });

  testWidgets('크게 보기는 원본 그대로 (두 손가락으로 키운다)', (tester) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: ImageViewerScreen(images: [_bandai])));
    expect(_providers(tester).single, isA<CachedNetworkImageProvider>());
  });

  testWidgets('예고 배너: 흐리게 깔 뒤 그림은 1/4 크기로만 푼다', (tester) async {
    await _pumpBox(tester, const BlurFitImage(_bandai), w: 360, h: 200);
    final boxes = _providers(tester).whereType<BoxDecodeImage>().toList();
    expect(boxes, hasLength(2));
    final blurred = boxes.firstWhere((b) => b.fit == DecodeFit.cover);
    final sharp = boxes.firstWhere((b) => b.fit == DecodeFit.contain);
    expect((sharp.width, sharp.height), (1088.0, 640.0));
    expect((blurred.width, blurred.height), (320.0, 192.0));
  });

  testWidgets('BoxDecodeImage 는 정말 그 크기로 푼다 — 잘라 채우기 · 안에 맞추기', (tester) async {
    await tester.runAsync(() async {
      final png = await _png(400, 200);
      final cover = await _resolve(BoxDecodeImage(MemoryImage(png), width: 100, height: 100, fit: DecodeFit.cover));
      expect((cover.width, cover.height), (200, 100));
      final contain = await _resolve(BoxDecodeImage(MemoryImage(png), width: 100, height: 100, fit: DecodeFit.contain));
      expect((contain.width, contain.height), (100, 50));
      final small = await _resolve(BoxDecodeImage(MemoryImage(png), width: 640, height: 640, fit: DecodeFit.cover));
      expect((small.width, small.height), (400, 200), reason: '칸보다 작으면 키우지 않는다');
    });
  });

  testWidgets('알림 300줄: 목록은 보이는 줄만 만든다', (tester) async {
    fixedNow = DateTime(2026, 10, 25, 21);
    final at = DateTime(2026, 10, 25, 7);
    final store = NotifyStore.memory(
      records: [
        for (var i = 0; i < 300; i++)
          NoticeRecord(
            id: 'feed-2026-10-25-k$i',
            kind: 'added',
            kitId: 'k$i',
            title: '상품 $i',
            body: '새로 수록',
            at: at.subtract(Duration(hours: i)),
            franchise: 'gundam',
          ),
      ],
    );
    await pumpApp(tester, NotificationsScreen(myChannels: const ['gundam'], loaders: loadersFor(store), notify: store));
    final list = tester.widget<ListView>(find.byType(ListView));
    expect(list.childrenDelegate, isA<SliverChildBuilderDelegate>());
    final delegate = list.childrenDelegate as SliverChildBuilderDelegate;
    expect(delegate.childCount, greaterThan(300)); // 머리 줄 + 묶음 + 300
    // 알림 줄은 열쇠로 자리를 찾는다 — 위에 새 알림이 들어와도 밀던 줄이 제 상태를 지킨다
    // 맨 위 확인 시각 · 「오늘」 머리 뒤 여섯째 알림
    expect(delegate.findChildIndexCallback!(const ValueKey('feed-2026-10-25-k5')), 7);
    expect(delegate.findChildIndexCallback!(const ValueKey('없는 알림')), isNull);
    expect(find.byType(Dismissible).evaluate().length, lessThan(30));
    expect(find.text('상품 0'), findsOneWidget);
  });

  group('Gunpula 작은 그림 (data/thumbs.json)', () {
    setUp(() {
      ThumbIndex.current = const ThumbIndex(thumbs: {_bandai: _bandaiThumb});
      // 앞 시험에서 받다 만 같은 주소가 메모리 캐시에 남아 있으면 그것을 기다리기만 한다
      PaintingBinding.instance.imageCache
        ..clear()
        ..clearLiveImages();
    });

    testWidgets('알림 칸은 작은 그림으로 받고, 크게 보기 · 상세 사진 넘기기는 원본', (tester) async {
      await _pumpBox(tester, const PhotoThumb(_bandai));
      expect(_urlOf(_providers(tester).single), _bandaiThumb);

      await tester.pumpWidget(const MaterialApp(home: ImageViewerScreen(images: [_bandai])));
      expect(_urlOf(_providers(tester).single), _bandai);

      tester.view.physicalSize = const Size(1080, 2340);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ImagePager(images: [_bandai], label: ''),
          ),
        ),
      );
      expect(_urlOf(_providers(tester).single), _bandai);
    });

    testWidgets('작은 그림이 없으면(404) 원본으로 — 작은 그림만 「열리지 않는 사진」', (tester) async {
      final net = _FailNet({_bandaiThumb: const HttpExceptionWithStatus(404, 'gone')});
      NetImageFiles.manager = net;
      await _pumpBox(tester, const PhotoThumb(_bandai));
      await _settleNet(tester);
      expect(net.asked, [_bandaiThumb, _bandai]);
      expect(_urlOf(_providers(tester).last), _bandai, reason: '실패한 작은 그림 칸 안에 원본');
      expect(BrokenImages.has(_bandaiThumb), isTrue);
      expect(BrokenImages.has(_bandai), isFalse);
    });

    testWidgets('작은 그림 서버가 잠깐 늦으면 원본으로 — 아무것도 기억하지 않는다', (tester) async {
      final net = _FailNet({_bandaiThumb: TimeoutException('slow')});
      NetImageFiles.manager = net;
      await _pumpBox(tester, const PhotoThumb(_bandai));
      await _settleNet(tester);
      expect(net.asked, [_bandaiThumb, _bandai]);
      expect(BrokenImages.has(_bandaiThumb), isFalse);

      // 다시 그리면 작은 그림부터 다시
      await tester.pumpWidget(const SizedBox());
      await _pumpBox(tester, const PhotoThumb(_bandai));
      expect(_urlOf(_providers(tester).single), _bandaiThumb);
    });
  });
}
