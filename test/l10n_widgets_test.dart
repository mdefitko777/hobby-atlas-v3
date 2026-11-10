// 공용 위젯의 기본 글이 중국어 화면에서 바뀌나 (시트 · 빈 목록 · 요약 · 도움말 버튼)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/l10n/l10n.dart';
import 'package:hobby_atlas/widgets/help.dart';
import 'package:hobby_atlas/widgets/sheets.dart';
import 'package:hobby_atlas/widgets/states.dart';

void main() {
  testWidgets('중국어 화면: 고르는 시트 · 빈 목록 기본 글', (t) async {
    L10n.debugSet(AppLang.zh);
    addTearDown(() => L10n.debugSet(AppLang.ko));
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Expanded(
                child: GpPickSheet(
                  title: 'x',
                  hits: 3,
                  noHitLabel: '',
                  onApply: () {},
                  onReset: () {},
                  children: [
                    CheckGrid(values: const ['식완'], selected: const {}, countOf: (_) => 1, onToggle: (_) {}),
                  ],
                ),
              ),
              const Expanded(child: EmptyView()),
            ],
          ),
        ),
      ),
    );
    expect(find.text('重置'), findsOneWidget);
    expect(find.text('查看 3 个'), findsOneWidget);
    expect(find.text('食玩'), findsOneWidget, reason: '자료 값은 보이는 자리에서만 번역');
    expect(find.text('没有可显示的内容'), findsOneWidget);
    expect(pickSummary({}), '全部');
    expect(pickSummary({'식완', 'HG'}), '食玩 等另 1 个');
    expect(HelpButton.tip, '帮助');
  });

  test('한국어 화면은 그대로', () {
    L10n.debugSet(AppLang.ko);
    expect(pickSummary({'식완', 'HG'}), '식완 외 1');
    expect(HelpButton.tip, '도움말');
  });
}
