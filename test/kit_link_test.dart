// D-18 상품 공유 링크 — 만들기 · 읽기 · 받은 링크로 그 상품 상세 열기
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/data/user_store.dart';
import 'package:hobby_atlas/detail_pane.dart';
import 'package:hobby_atlas/logic/kit_link.dart';
import 'package:hobby_atlas/marks.dart';
import 'package:hobby_atlas/screens/d_kit_detail_screen.dart';
import 'package:hobby_atlas/screens/e_photo_find_screen.dart';
import 'package:hobby_atlas/share/share_intake.dart';
import 'package:hobby_atlas/theme.dart';

import 'layout_test.dart' show fakeLoaders;

void main() {
  test('링크 만들기 · 읽기 (앱 주소 · 웹 주소 · 글 안)', () {
    const id = 'rg-rg-1-144-ew-4573102619747000';
    expect(kitShareUrl(id), 'https://mdefitko777.github.io/Gunpula/app/open.html?kit=$id');
    expect(kitIdFromLink(kitShareUrl(id)), id);
    expect(kitIdFromLink('hobbyatlas://kit/$id'), id);
    expect(kitIdFromLink(kitShareText(name: 'RG 1/144 윙 건담 제로 EW용 확장 이펙트 유닛', kitId: id)), id);
    expect(
      kitIdFromLink('https://mdefitko777.github.io/Gunpula/app/open.html?x=1&kit=pbandai-wb-1000252948'),
      'pbandai-wb-1000252948',
    );
    expect(kitIdFromLink('https://p-bandai.jp/item/item-1000252948/'), isNull);
    expect(kitIdFromLink('hobbyatlas://kit/..%2F..'), isNull, reason: '이상한 id 는 버린다');
  });

  test('MainActivity 가 보낸 {type: kit} · 링크가 든 글 → 상품 링크', () {
    expect(sharedItemFrom({'type': 'kit', 'id': 'gu12'}), isA<SharedKitLink>().having((s) => s.kitId, 'kitId', 'gu12'));
    final fromText = sharedItemFrom({'type': 'text', 'text': '건담\n${kitShareUrl('gu12')}'});
    expect(fromText, isA<SharedKitLink>().having((s) => s.kitId, 'kitId', 'gu12'));
    expect(sharedItemFrom({'type': 'text', 'text': 'HG 건담 https://p-bandai.jp/item/1'}), isA<SharedText>());
    expect(sharedItemFrom({'type': 'kit', 'id': ''}), isNull);
  });

  testWidgets('받은 링크 → 그 상품 상세, 없는 상품이면 알림', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildGpTheme(),
        builder: (context, child) => MarksHost(
          store: UserStore.memory(),
          child: PaneHost(child: child!),
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await openShared(ctx, const SharedKitLink('nope'), loaders: fakeLoaders, onGoSearch: () {});
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(KitDetailScreen), findsNothing);
    expect(find.textContaining('이 상품을 찾지 못했어요'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));

    await openShared(ctx, const SharedKitLink('gu12'), loaders: fakeLoaders, onGoSearch: () {});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(KitDetailScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('share-kit')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
