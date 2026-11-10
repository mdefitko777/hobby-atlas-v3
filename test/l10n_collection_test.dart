// 중국어 화면 — 묶음 "collection": 컬렉션 탭 · 도움말 · 친구 · 계정 오류 글이 중국어로 나오나
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/clock.dart';
import 'package:hobby_atlas/data/user_store.dart';
import 'package:hobby_atlas/detail_pane.dart';
import 'package:hobby_atlas/l10n/l10n.dart';
import 'package:hobby_atlas/marks.dart';
import 'package:hobby_atlas/screens/f_collection_screen.dart';
import 'package:hobby_atlas/screens/m_friends_drawer.dart';
import 'package:hobby_atlas/sync/friends_service.dart';
import 'package:hobby_atlas/sync/rpc.dart';
import 'package:hobby_atlas/sync/supabase_backend.dart';
import 'package:hobby_atlas/theme.dart';

import 'layout_test.dart' show fakeLoaders;

void main() {
  fixedNow = DateTime(2026, 10, 25, 21);

  setUp(() => L10n.debugSet(AppLang.zh));
  tearDown(() => L10n.debugSet(AppLang.ko));

  testWidgets('컬렉션 화면 — 탭 이름 · 구매함 요약 줄이 중국어', (tester) async {
    addTearDown(() => L10n.debugSet(AppLang.ko));
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildGpTheme(),
        builder: (context, child) => MarksHost(
          store: UserStore.memory(),
          child: PaneHost(child: child!),
        ),
        home: Scaffold(
          body: CollectionScreen(
            myChannels: const ['gundam'],
            onMyChannelsChanged: (_) {},
            onGoSearch: () {},
            loaders: fakeLoaders,
          ),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.textContaining('喜欢', findRichText: true), findsWidgets);
    expect(find.textContaining('已购', findRichText: true), findsWidgets);
    expect(find.textContaining('图鉴', findRichText: true), findsWidgets);
    expect(find.textContaining('구매함', findRichText: true), findsNothing);

    await tester.tap(find.byKey(const ValueKey('tab-owned')));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.textContaining('支出 ', findRichText: true), findsWidgets);
    expect(find.textContaining('지출', findRichText: true), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('도움말 · 친구 · 계정 오류 글', () {
    expect(collectionHelp().map((i) => i.text), contains('回收站（30 天内可恢复）'));
    expect(friendsHelp().map((i) => i.text), contains('用 ID 加好友'));
    expect(friendlyError(const RpcException('P0001', 'already friends')), '已经是好友了');
    expect(authMessage(null, 'only request this after 42 seconds', '429'), '42 秒后可以再发送');
    L10n.debugSet(AppLang.ko);
    expect(friendlyError(const RpcException('P0001', 'already friends')), '이미 친구예요');
  });
}
