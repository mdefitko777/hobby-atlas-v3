// 종류별 도감 화면 (lib/screens/guide/line_guide.dart): 종류 카드 → 묶음 칸 · ♡ · 리본 · 찾기 · 정렬 · 상태 · 큰 묶음 · 화면 크기
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/channels.dart';
import 'package:hobby_atlas/api.dart';
import 'package:hobby_atlas/clock.dart';
import 'package:hobby_atlas/data/user_store.dart';
import 'package:hobby_atlas/detail_pane.dart';
import 'package:hobby_atlas/marks.dart';
import 'package:hobby_atlas/models.dart';
import 'package:hobby_atlas/screens/c_channel_screen.dart' show allChannelId;
import 'package:hobby_atlas/screens/guide/guide_parts.dart' show GuideWorkCard;
import 'package:hobby_atlas/screens/guide/line_guide.dart';
import 'package:hobby_atlas/theme.dart';
import 'package:hobby_atlas/widgets.dart';

import 'layout_test.dart' show fakeLoaders, sizes;
import 'support/line_kits.dart';

final _kits = [
  for (var i = 0; i < 5; i++) lineKit('h$i', date: i < 3 ? '2024-0${i + 1}-01' : '2023-0${i + 1}-01'),
  for (var i = 0; i < 3; i++) lineKit('m$i', line: 'MG', date: '2022-0${i + 1}-01'),
  lineKit('eg', line: 'EG'),
  lineKit('mgex', line: 'MGEX'),
  for (var i = 0; i < 3; i++) lineKit('p$i', channel: 'pokemon', line: '봉제인형', type: '인형'),
];

Loaders _loaders(List<Kit> kits) => Loaders(
  kits: (ids) async => [
    for (final k in kits)
      if (ids.contains(k.franchiseId)) k,
  ],
);

Future<void> _frames(WidgetTester t, [int n = 6]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 250));
  }
}

Future<UserStore> _show(WidgetTester t, Widget body, {Size size = const Size(390, 844), UserStore? store}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final s = store ?? UserStore.memory();
  await t.pumpWidget(
    MaterialApp(
      key: UniqueKey(), // 다시 그릴 때 앞 화면에서 쌓은 묶음 칸을 버린다
      theme: buildGpTheme(),
      builder: (context, child) => MarksHost(
        store: s,
        child: PaneHost(child: child!),
      ),
      home: Scaffold(body: body),
    ),
  );
  await _frames(t);
  return s;
}

Finder _card(String channel, String key) => find.byKey(ValueKey('line-$channel-$key'));
Finder _in(String kitId, IconData icon) =>
    find.descendant(of: find.byKey(ValueKey(kitId)), matching: find.byIcon(icon));

Future<void> _drain(WidgetTester t) => _frames(t, 14); // 토스트(2.5초)가 사라질 때까지

void main() {
  fixedNow = DateTime(2026, 10, 25, 21);

  testWidgets('종류 카드: 건담 등급 순서 · 작은 묶음 = 기타 · 수집 숫자', (t) async {
    await _show(t, LineGuideView(channel: 'gundam', loaders: _loaders(_kits)));
    expect(find.text('종류'), findsOneWidget);
    expect(_card('gundam', 'MG'), findsOneWidget);
    expect(_card('gundam', 'HG'), findsOneWidget);
    expect(_card('gundam', '기타'), findsOneWidget);
    expect(_card('gundam', 'EG'), findsNothing); // EG 1 · MGEX 1 → 기타
    expect(_card('pokemon', '봉제인형'), findsNothing); // 다른 채널은 안 보인다
    // MG → HG → 기타 (정해진 순서)
    final mg = t.getTopLeft(_card('gundam', 'MG'));
    final hg = t.getTopLeft(_card('gundam', 'HG'));
    final other = t.getTopLeft(_card('gundam', '기타'));
    expect(mg.dx < hg.dx && hg.dx < other.dx, isTrue);
    expect(find.text('수집 0 / 10'), findsOneWidget);
    expect(find.text('5개'), findsOneWidget);
    expect(t.takeException(), isNull);

    // G-10b ?
    await t.tap(find.byTooltip(HelpButton.tip));
    await t.pumpAndSettle();
    expect(find.text('종류별 도감'), findsOneWidget);
    expect(find.text('초록 테두리 = 구매함'), findsOneWidget);
  });

  testWidgets('종류 카드 그림: atlas-groups line_covers 의 공식 그림이 있으면 그것, 없으면 최근 상품', (t) async {
    lineCovers['gundam'] = {'MG': 'assets/test/mg-logo.png'};
    addTearDown(lineCovers.clear);
    await _show(t, LineGuideView(channel: 'gundam', loaders: _loaders(_kits)));
    expect(t.widget<GuideWorkCard>(_card('gundam', 'MG')).image, 'assets/test/mg-logo.png');
    expect(t.widget<GuideWorkCard>(_card('gundam', 'HG')).image, isNot('assets/test/mg-logo.png'));
  });

  testWidgets('묶음 열기 → 칸 격자 · 연도 머리 · ♡ / 리본이 단계와 숫자를 바꾼다', (t) async {
    final store = await _show(t, LineGuideView(channel: 'gundam', loaders: _loaders(_kits)));
    await t.tap(_card('gundam', 'HG'));
    await _frames(t);
    expect(find.text('수집 0 / 5'), findsOneWidget);
    expect(find.text('2024년'), findsOneWidget);
    expect(find.text('2023년'), findsOneWidget);
    expect(find.byType(TierCell), findsNWidgets(5));
    expect(find.text('2024.03.01'), findsOneWidget); // 칸 아래 발매일
    expect(t.widget<TierCell>(find.byKey(const ValueKey('h0'))).tier, CellTier.none);

    await t.tap(_in('h0', Icons.favorite_border)); // G-11a ♡
    await _frames(t, 2);
    expect(store.statusOf('h0'), CollectStatus.wanted);
    expect(t.widget<TierCell>(find.byKey(const ValueKey('h0'))).tier, CellTier.liked);

    await t.tap(_in('h0', Icons.add)); // 리본
    await _frames(t, 2);
    expect(store.statusOf('h0'), CollectStatus.owned);
    expect(t.widget<TierCell>(find.byKey(const ValueKey('h0'))).tier, CellTier.owned);
    expect(find.text('수집 1 / 5'), findsOneWidget); // 머리 숫자
    expect(find.text('수집 1 / 3'), findsOneWidget); // 2024년 머리
    await _drain(t);

    // 뒤로 → 카드 숫자도 바뀌어 있다
    await t.pageBack();
    await _frames(t);
    expect(find.text('수집 1 / 10'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('묶음 안 찾기 · 정렬(이름 → 연도 머리 없음) · 상태 거르기', (t) async {
    final store = UserStore.memory()..setStatus('h2', CollectStatus.owned);
    await _show(
      t,
      LineGroupScreen(channel: 'gundam', groupKey: 'HG', loaders: _loaders(_kits)),
      store: store,
    );
    expect(find.byType(TierCell), findsNWidgets(5));

    // G-11b 찾기
    await t.enterText(find.byType(TextField), 'h3');
    await _frames(t, 2);
    expect(find.byType(TierCell), findsOneWidget);
    expect(find.byKey(const ValueKey('h3')), findsOneWidget);
    await t.enterText(find.byType(TextField), '');
    await _frames(t, 2);

    // G-11c 정렬: 이름
    await t.tap(find.byTooltip('정렬'));
    await t.pumpAndSettle();
    await t.tap(find.text('이름'));
    await t.pumpAndSettle();
    expect(find.text('2024년'), findsNothing);
    expect(find.byType(TierCell), findsNWidgets(5));
    final first = t.getTopLeft(find.byKey(const ValueKey('h0')));
    final last = t.getTopLeft(find.byKey(const ValueKey('h4')));
    expect(first.dy < last.dy || (first.dy == last.dy && first.dx < last.dx), isTrue);

    // 상태: 구매함만
    await t.tap(find.byTooltip('필터'));
    await t.pumpAndSettle();
    expect(find.text('상태'), findsOneWidget);
    await t.tap(find.text('구매함').first);
    await t.pump();
    await t.tap(find.text('1개 보기'));
    await t.pumpAndSettle();
    expect(find.byType(TierCell), findsOneWidget);
    expect(find.byKey(const ValueKey('h2')), findsOneWidget);
    expect(t.widget<FilterButton>(find.byType(FilterButton)).count, 1);

    // 아직 → 4칸
    await t.tap(find.byTooltip('필터'));
    await t.pumpAndSettle();
    await t.tap(find.text('아직').first);
    await t.pump();
    await t.tap(find.text('4개 보기'));
    await t.pumpAndSettle();
    expect(find.byType(TierCell), findsNWidgets(4));
    expect(t.takeException(), isNull);
  });

  testWidgets('내 것만: 좋아요 · 구매함이 있는 묶음만 · 열면 내 것 상태', (t) async {
    final store = UserStore.memory()
      ..setStatus('m1', CollectStatus.owned)
      ..setStatus('eg', CollectStatus.wanted);
    await _show(
      t,
      LineGuideView(channel: 'gundam', loaders: _loaders(_kits), mineOnly: true),
      store: store,
    );
    expect(_card('gundam', 'MG'), findsOneWidget);
    expect(_card('gundam', '기타'), findsOneWidget);
    expect(_card('gundam', 'HG'), findsNothing);
    expect(find.text('좋아요 0 · 구매함 1'), findsOneWidget);
    await t.tap(_card('gundam', 'MG'));
    await _frames(t);
    expect(find.byType(TierCell), findsOneWidget); // 내 것 = m1 하나
    expect(t.widget<FilterButton>(find.byType(FilterButton)).count, 1);

    // 아무것도 없으면 안내
    await _show(t, LineGuideView(channel: 'gundam', loaders: _loaders(_kits), mineOnly: true));
    expect(find.text('아직 좋아요 · 구매한 상품이 없어요'), findsOneWidget);
  });

  testWidgets('찾기 글자: 상품으로 찾으면 찾은 수 + 묶음 안으로 이어진다', (t) async {
    await _show(t, LineGuideView(channel: 'gundam', loaders: _loaders(_kits), query: 'h3'));
    expect(_card('gundam', 'HG'), findsOneWidget);
    expect(_card('gundam', 'MG'), findsNothing);
    expect(find.text('찾은 1개'), findsOneWidget);
    await t.tap(_card('gundam', 'HG'));
    await _frames(t);
    expect(find.byType(TierCell), findsOneWidget);
    expect(find.widgetWithText(TextField, 'h3'), findsOneWidget);

    await _show(t, LineGuideView(channel: 'gundam', loaders: _loaders(_kits), query: 'zzz'));
    expect(find.text('이 조건의 칸이 없어요'), findsOneWidget);
  });

  testWidgets("'전체': 채널마다 묶음 · 머리를 누르면 그 채널 · 내 채널 없음 안내", (t) async {
    final picked = <String>[];
    await _show(
      t,
      LineGuideView(
        channel: allChannelId,
        loaders: _loaders(_kits),
        myChannels: const ['gundam', 'pokemon'],
        onPickChannel: picked.add,
      ),
    );
    expect(find.text('건담'), findsOneWidget);
    expect(find.text('포켓몬'), findsOneWidget);
    expect(_card('gundam', 'HG'), findsOneWidget);
    expect(_card('pokemon', '봉제인형'), findsOneWidget);
    await t.tap(find.text('포켓몬'));
    expect(picked, ['pokemon']);
    await t.tap(_card('pokemon', '봉제인형'));
    await _frames(t);
    expect(find.byType(TierCell), findsNWidgets(3));

    await _show(t, LineGuideView(channel: allChannelId, loaders: _loaders(_kits), myChannels: const []));
    expect(find.text('내 채널이 비어 있어요'), findsOneWidget);
  });

  testWidgets('큰 묶음 (HG 1400): 보이는 칸만 그리고 끝까지 스크롤된다', (t) async {
    final big = [
      for (var i = 0; i < 1400; i++)
        lineKit('b$i', date: '${2000 + i % 25}-${(i % 12 + 1).toString().padLeft(2, '0')}-01'),
    ];
    await _show(t, LineGroupScreen(channel: 'gundam', groupKey: 'HG', loaders: _loaders(big)));
    expect(find.text('수집 0 / 1400'), findsOneWidget);
    expect(find.byType(TierCell).evaluate().length, lessThan(80));
    for (var i = 0; i < 8; i++) {
      await t.fling(find.byType(CustomScrollView), const Offset(0, -4000), 6000);
      await _frames(t, 2);
    }
    expect(find.byType(TierCell).evaluate().length, lessThan(80));
    expect(t.takeException(), isNull);
  });

  group('화면 크기 (db.json)', () {
    for (final s in sizes.entries) {
      testWidgets(s.key, (t) async {
        await _show(
          t,
          LineGuideView(channel: 'gundam', loaders: fakeLoaders),
          size: s.value,
        );
        expect(t.takeException(), isNull);
        expect(_card('gundam', 'HG'), findsOneWidget);
        await t.tap(_card('gundam', 'HG'));
        await _frames(t);
        expect(t.takeException(), isNull);
        expect(find.byType(TierCell), findsWidgets);
        await _show(
          t,
          LineGuideView(channel: allChannelId, loaders: fakeLoaders),
          size: s.value,
        );
        expect(t.takeException(), isNull);
      });
    }
  });
}
