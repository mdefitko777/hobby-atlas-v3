// 밤 모드 — 두 벌의 색이 정말로 바뀌는지, 그리고 어디에도 낮 색이 얼어붙지 않았는지.
//
// 얼어붙음(freeze)이 이 기능의 유일한 진짜 함정이다: `static final x = TextStyle(color: Gp.ink)`
// 는 처음 한 번만 계산되므로 밤 모드를 켜도 낮 색 그대로 남는다. 아래 "두 번 그려 견주기"
// 테스트가 그것을 잡는다 — 색을 적어 두고 비교하지 않고, 같은 위젯을 낮 · 밤에 각각 그려
// 나온 색이 달라지는지만 본다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/detail_pane.dart';
import 'package:hobby_atlas/marks.dart';
import 'package:hobby_atlas/screens/s_app_shell.dart';
import 'package:hobby_atlas/screens/u_social.dart' show MyAvatar;
import 'package:hobby_atlas/theme.dart';
import 'package:hobby_atlas/widgets.dart';

import 'layout_test.dart' show fakeLoaders;

Future<void> _frames(WidgetTester tester, [int n = 8]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  setUp(() => GpMode.debugSet(false));
  tearDown(() => GpMode.debugSet(false));

  test('처음은 낮 · 켜면 밤 — 바탕은 깊은 회색이고 검정이 아니다', () {
    expect(GpMode.isDark, isFalse);
    expect(Gp.bg, const Color(0xFFFFFFFF));

    GpMode.debugSet(true);
    expect(GpMode.isDark, isTrue);
    expect(Gp.bg, const Color(0xFF121212));
    expect(Gp.bg, isNot(const Color(0xFF000000)), reason: '주인이 깊은 회색을 골랐다');
    expect(Gp.p.dark, isTrue);
  });

  test('밤의 글자색은 바탕 대비 4.5:1 (WCAG AA) 을 넘는다', () {
    GpMode.debugSet(true);
    double ratio(Color fg, Color bg) {
      final a = fg.computeLuminance(), b = bg.computeLuminance();
      return (max(a, b) + 0.05) / (min(a, b) + 0.05);
    }

    for (final (name, c) in [('ink', Gp.ink), ('muted', Gp.muted), ('faint', Gp.faint), ('accent', Gp.accent)]) {
      expect(ratio(c, Gp.bg), greaterThanOrEqualTo(4.5), reason: '$name 이 밤 바탕에서 안 읽힌다');
    }
  });

  test('크기 · 모서리 · 글자 크기는 두 벌이 같다 (색만 바뀐다)', () {
    final sizes = [Gp.radius, Gp.rSmall, Gp.rLarge, Gp.iS, Gp.iL, Gp.t14, Gp.t19, Gp.gutter];
    GpMode.debugSet(true);
    expect([Gp.radius, Gp.rSmall, Gp.rLarge, Gp.iS, Gp.iL, Gp.t14, Gp.t19, Gp.gutter], sizes);
  });

  test('테마도 따라 어두워진다', () {
    expect(buildGpTheme().brightness, Brightness.light);
    GpMode.debugSet(true);
    final t = buildGpTheme();
    expect(t.brightness, Brightness.dark);
    expect(t.scaffoldBackgroundColor, Gp.bg);
    expect(t.colorScheme.onPrimary, Gp.bg, reason: '밤에는 primary 가 밝아 그 위 글자는 바탕색이어야 보인다');
  });

  testWidgets('두 번 그려 견주기 — 같은 위젯이 낮과 밤에 다른 색으로 나온다 (얼어붙음 없음)', (tester) async {
    Future<Map<String, Color?>> paint() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildGpTheme(),
          home: Scaffold(
            body: Column(
              children: [
                GpSearchBar(hint: '찾기', onChanged: (_) {}),
                SoftTag('꼬리표'),
                SectionHeader('묶음'),
                LikedIcon(),
              ],
            ),
          ),
        ),
      );
      // MaterialApp 은 테마가 바뀔 때 AnimatedTheme 으로 200ms 넘어간다 (앱에서도 톡 튀지 않고
      // 부드럽게 바뀐다) — 다 넘어간 뒤를 봐야 색이 섞인 중간값을 읽지 않는다
      await tester.pumpAndSettle();
      return {
        'scaffold':
            tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor ??
            Theme.of(tester.element(find.byType(Scaffold))).scaffoldBackgroundColor,
        'field': tester.widget<TextField>(find.byType(TextField)).style?.color,
        'tag': tester.widget<SoftTag>(find.byType(SoftTag)).color,
        'liked': tester.widget<LikedIcon>(find.byType(LikedIcon)).color,
      };
    }

    final day = await paint();
    GpMode.debugSet(true);
    final night = await paint();

    for (final k in day.keys) {
      expect(night[k], isNotNull, reason: '$k 의 색을 못 읽었다 — 테스트가 헛돌고 있다');
      expect(night[k], isNot(day[k]), reason: '$k 가 낮 색으로 얼어붙었다 (static final 함정)');
    }
  });

  testWidgets('진짜 서랍 아래 줄: 밤 모드 · 사용법 · 설정 — 맨 앞이 밤 모드', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildGpTheme(),
        home: MarksHost(child: PaneHost(child: AppShell(loaders: fakeLoaders))),
      ),
    );
    await _frames(tester);
    await tester.tap(find.byType(MyAvatar).first);
    await _frames(tester);

    for (final k in ['drawer-night', 'drawer-help', 'drawer-settings']) {
      expect(find.byKey(ValueKey(k)), findsOneWidget, reason: '$k 이 서랍 아래 줄에 없다');
    }
    // 맨 앞 자리 — 가로 위치로 본다 (사용법보다 왼쪽)
    final night = tester.getTopLeft(find.byKey(const ValueKey('drawer-night'))).dx;
    final help = tester.getTopLeft(find.byKey(const ValueKey('drawer-help'))).dx;
    expect(night, lessThan(help));
    expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('drawer-night')));
    await _frames(tester);
    // 기기에 적어 두기가 실패해도 켠 것은 켜진다, 서랍은 닫히지 않는다
    expect(GpMode.isDark, isTrue);
    expect(find.byIcon(Icons.light_mode_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

double max(double a, double b) => a > b ? a : b;
double min(double a, double b) => a < b ? a : b;
