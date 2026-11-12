// 레고 보기 범위 — 최근 정식 세트 (2015~, 번호 4~6자리, 폴리백 · 굿즈 · 책 빼고) · 고르는 곳 = 검색 탭 레고 채널
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/clock.dart';
import 'package:hobby_atlas/data/catalog.dart';
import 'package:hobby_atlas/data/user_store.dart';
import 'package:hobby_atlas/detail_pane.dart';
import 'package:hobby_atlas/l10n/l10n.dart';
import 'package:hobby_atlas/logic/lego_scope.dart';
import 'package:hobby_atlas/marks.dart';
import 'package:hobby_atlas/screens/b_search_screen.dart';
import 'package:hobby_atlas/sync/device_state.dart';
import 'package:hobby_atlas/theme.dart';
import 'package:hobby_atlas/widgets.dart';

import 'layout_test.dart' show fakeLoaders;

Map<String, Object?> lego(String number, String date, {String code = 'LEGO_SET', String series = 'lego_city'}) => {
  'franchiseId': 'lego',
  'number': number,
  'date': date,
  'gradeCode': code,
  'seriesKey': series,
};

void main() {
  test('정식 세트만', () {
    expect(legoRecentSet(lego('60347', '2022')), isTrue); // 시티 슈퍼마켓
    expect(legoRecentSet(lego('10446', '2025', series: 'lego_duplo')), isTrue); // 듀플로 (부품이 적어도)
    expect(legoRecentSet(lego('75192', '2017', series: 'lego_star_wars')), isTrue);
    expect(legoRecentSet(lego('6089', '2014')), isFalse); // 2015년 전
    expect(legoRecentSet(lego('30712', '2025')), isFalse); // 폴리백
    expect(legoRecentSet(lego('2D001164', '2024')), isFalse); // 잡지 부록
    expect(legoRecentSet(lego('5008073', '2024')), isFalse); // 7자리 굿즈 번호
    expect(legoRecentSet(lego('853990', '2020', code: 'LEGO_GEAR', series: 'lego_gear')), isFalse);
    expect(legoRecentSet(lego('40639', '2023', series: 'lego_promotional')), isFalse);
    expect(
      legoRecentSet(lego('71045-3', '2024', code: 'LEGO_MINIFIG', series: 'lego_collectible_minifigures')),
      isTrue,
    );
  });

  test('범위 밖 레고도 id 로는 찾는다 (좋아요 · 구매함) — 둘러보는 목록에서만 빠진다', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    Map<String, Object?> slim(String id, String number, String date, {String code = 'LEGO_SET'}) => {
      ...lego(number, date, code: code),
      'id': id,
      'name': id,
      'line': '세트',
      'type': '레고',
    };
    UserStore.instance.setLegoScope(LegoScope.recent);
    Catalog.instance.debugSet(
      slim: [
        slim('lego-75192-1', '75192', '2017'),
        slim('lego-6089-1', '6089', '2014'),
        {'id': 'hg-1', 'franchiseId': 'gundam', 'name': 'HG', 'date': '2024'},
      ],
      aux: const {},
    );
    final c = Catalog.instance;
    expect(c.kits.map((k) => k.id), unorderedEquals(['lego-75192-1', 'hg-1']));
    expect(c.byId['lego-6089-1'], isNotNull); // 2014 세트를 구매함에 넣어 두었어도 보인다
    expect(c.hiddenByScope('lego-6089-1'), isTrue);
    expect(c.hiddenByScope('lego-75192-1'), isFalse);
    UserStore.instance.setLegoScope(LegoScope.all); // Catalog 가 듣고 목록만 다시 거른다
    expect(c.kits.map((k) => k.id), contains('lego-6089-1'));
    // 조용히: 앱 셸이 보고 있는 탭(범위를 고른 검색 탭 레고 채널)을 다시 만들지 않는다
    expect(c.lastChangeQuiet, isTrue);
    expect(c.hiddenByScope('lego-6089-1'), isFalse);
    UserStore.instance.setLegoScope(LegoScope.recent);
    expect(c.kits.map((k) => k.id), isNot(contains('lego-6089-1')));
  });

  test('처음 값(최근 정식 세트)도 기기 상태에 적는다 — 빠지면 다른 기기의 "전부"가 되살아난다', () {
    UserStore.instance.setLegoScope(LegoScope.recent);
    final local = UserStore.instance.toJson()['local_state'] as Map;
    expect(local['lego_scope'], 'recent');
  });

  testWidgets('검색 탭 레고 채널: 둘러보기 줄 오른쪽에서 범위를 고른다 (검색창 줄 아이콘은 세 칸 그대로)', (tester) async {
    fixedNow = DateTime(2026, 10, 25, 21);
    UserStore.instance.setLegoScope(LegoScope.recent);
    addTearDown(() => UserStore.instance.setLegoScope(LegoScope.recent));
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
          body: SearchScreen(
            myChannels: const ['gundam', 'lego'],
            onMyChannelsChanged: (_) {},
            onCamera: () {},
            loaders: fakeLoaders,
          ),
        ),
      ),
    );
    Future<void> settle() async {
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    await settle();
    const button = Key('lego-scope');
    expect(find.byKey(button), findsNothing, reason: '레고 채널에서만');
    await tester.tap(find.byWidgetPredicate((w) => w is UnderlineTab && w.label == tr('레고')));
    await settle();
    expect(find.byKey(button), findsOneWidget);
    final row = find.byType(ToolRow).first;
    expect(find.descendant(of: row, matching: find.byType(ToolIcon)), findsNWidgets(3));

    final before = UserStore.instance.revision;
    await tester.tap(find.byKey(button));
    await settle();
    await tester.tap(find.byKey(const Key('lego-scope-all')));
    await settle();
    expect(UserStore.instance.legoScope, LegoScope.all);
    expect(UserStore.instance.revision, greaterThan(before)); // 저장 · 계정 맞추기 (lego_scope)
    expect((UserStore.instance.toJson()['local_state'] as Map)['lego_scope'], 'all');
    expect(builtInDeviceSections.map((s) => s.key), contains('lego_scope'));
    expect(find.descendant(of: find.byKey(button), matching: find.text(tr('전부'))), findsOneWidget);
    expect(find.byKey(button), findsOneWidget, reason: '고른 채널(레고)은 그대로');
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}
