// 점검(2026-11-09): 반다이 상품 사진은 _1 … _10 번호를 짐작해 만든 주소라 세 장 중 한 장꼴로 없다(404)
// → 상세 사진 넘기기 · 크게 보기에서 열리지 않은 장과 점을 뺀다 (D-2d)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/widgets/images.dart';

void main() {
  setUp(BrokenImages.reset);

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
}
