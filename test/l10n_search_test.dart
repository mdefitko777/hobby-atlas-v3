// 중국어 화면 — 묶음 "search" (아래 탭 · 찍어서 찾기 시트 · 채널 관리 · 홈 · 검색 도움말)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/l10n/l10n.dart';
import 'package:hobby_atlas/screens/a_home_screen.dart' show currentMonthTitle, homeHelp;
import 'package:hobby_atlas/screens/b_search_screen.dart' show searchHelp;
import 'package:hobby_atlas/screens/c_channel_screen.dart';
import 'package:hobby_atlas/screens/s_app_shell.dart' show AddSheet;
import 'package:hobby_atlas/theme.dart';

void main() {
  setUp(() => L10n.debugSet(AppLang.zh));
  tearDown(() => L10n.debugSet(AppLang.ko));

  testWidgets('찍어서 찾기 시트가 중국어로 나온다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildGpTheme(),
        home: Scaffold(body: AddSheet(onPick: (_) {})),
      ),
    );
    expect(find.text('用照片找'), findsOneWidget);
    expect(find.text('扫条形码'), findsOneWidget);
    expect(find.text('从相册选'), findsOneWidget);
    expect(find.textContaining(RegExp(r'[가-힣]')), findsNothing);
  });

  testWidgets('채널 관리 — 묶음 이름과 채널 이름이 중국어', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildGpTheme(),
        home: ChannelManagerScreen(initial: const ['gundam'], onChanged: (_) {}),
      ),
    );
    expect(find.text('我的频道'), findsOneWidget);
    expect(find.text('更多频道'), findsOneWidget);
    expect(find.text('高达'), findsOneWidget);
    expect(find.text('宝可梦'), findsOneWidget);
  });

  test('홈 · 검색 도움말과 이번 달 줄 제목이 언어를 따라간다', () {
    expect(homeHelp.map((i) => i.text), contains('全部动态'));
    expect(searchHelp().map((i) => i.text), contains('搜索结果按机体分组'));
    expect(currentMonthTitle, endsWith('月发售'));
    L10n.debugSet(AppLang.ko);
    expect(searchHelp().map((i) => i.text), contains('검색 결과를 기체별로 묶기'));
    expect(currentMonthTitle, endsWith('월 발매'));
  });
}
