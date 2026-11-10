// 점검(2026-11-09): 반다이 상품 사진은 _1 … _10 번호를 짐작해 만든 주소라 세 장 중 한 장꼴로 없다(404)
// → 상세 사진 넘기기 · 크게 보기에서 열리지 않은 장과 점을 뺀다 (D-2d)
// 점검(2026-11-11): 목록 사진(PhotoThumb)은 대표 사진이 막히면(Fandom 박스 아트 · Cloudflare) 회색 칸 대신 그 상품의 다음 사진
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/models.dart';
import 'package:hobby_atlas/widgets/images.dart';

/// 지금 그려진 앱 안 그림 경로들
List<String> _assets(WidgetTester tester) => [
  for (final i in tester.widgetList<Image>(find.byType(Image)))
    if (i.image case final AssetImage a) a.assetName,
];

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }
}

void main() {
  setUp(BrokenImages.reset);
  setUp(ImageAlternates.reset);

  test('열리지 않은 사진만 빼고, 다 빠지면 첫 장은 남긴다', () {
    const all = ['a.jpg', 'b.jpg', 'c.jpg'];
    expect(BrokenImages.keep(all), all);
    BrokenImages.mark('b.jpg');
    expect(BrokenImages.keep(all), ['a.jpg', 'c.jpg']);
    BrokenImages.mark('a.jpg');
    BrokenImages.mark('c.jpg');
    expect(BrokenImages.keep(all), ['a.jpg'], reason: '이름 자리표시가 보이도록 한 장');
    expect(BrokenImages.keep(const []), isEmpty);
  });

  testWidgets('크게 보기: 열리지 않은 사진이 생기면 장 수가 줄어든다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ImageViewerScreen(images: ['assets/x-1.png', 'assets/x-2.png', 'assets/x-3.png'])),
    );
    expect(find.text('1 / 3'), findsOneWidget);
    BrokenImages.mark('assets/x-2.png');
    await tester.pump();
    expect(find.text('1 / 2'), findsOneWidget);
  });

  group('목록 사진: 다음 사진으로', () {
    const cover = 'assets/gp/kits/none-cover.jpg'; // 없는 그림 = 열리지 않는 대표 사진
    const second = 'assets/gp/kits/none-second.jpg';
    const ok = 'assets/gp/kits/ar35.jpg';
    setUp(() {
      final k = Kit.fromSlim(
        {
          'id': 'k',
          'name': 'HG 테스트',
          'image': cover,
          'gallery': [cover, second, ok],
        },
        recentSince: '',
        monthPrefix: '',
      );
      ImageAlternates.source = () => {'k': k};
    });

    testWidgets('대표 · 둘째 사진이 안 열리면 셋째 사진', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox.square(dimension: 80, child: PhotoThumb(cover))));
      await _settle(tester);
      expect(_assets(tester), [cover, second, ok], reason: '안 열린 그림 안에 다음 그림');
      expect(BrokenImages.has(cover) && BrokenImages.has(second), isTrue);

      // 목록을 다시 그려도 막힌 주소는 다시 부르지 않고 바로 열리는 사진
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(const MaterialApp(home: SizedBox.square(dimension: 80, child: PhotoThumb(cover))));
      expect(_assets(tester), [ok]);
    });

    testWidgets('상세 · 크게 보기(AppImage 기본)는 다음 사진으로 바꾸지 않는다 — 그 장을 빼는 쪽', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox.square(dimension: 80, child: AppImage(cover))));
      await _settle(tester);
      expect(_assets(tester), [cover]);
      expect(find.byType(ColoredBox), findsWidgets); // 회색 자리표시
    });

    testWidgets('다음 사진이 없으면 이름 자리표시', (tester) async {
      ImageAlternates.source = () => const {};
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox.square(dimension: 80, child: AppImage(cover, placeholder: 'HG', nextOnError: true)),
        ),
      );
      await _settle(tester);
      expect(find.text('HG'), findsOneWidget);
    });
  });
}
