// 중국어 화면 — 베이 조합 만들기 · 규칙 이유 글이 중국어로 나오나 (묶음 bbx, lib/l10n/zh/bbx.dart)
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/api.dart';
import 'package:hobby_atlas/bbx/bbx.dart';
import 'package:hobby_atlas/data/bbx_builder_data.dart';
import 'package:hobby_atlas/data/user_store.dart';
import 'package:hobby_atlas/l10n/l10n.dart';
import 'package:hobby_atlas/logic/bbx_builder.dart';
import 'package:hobby_atlas/marks.dart';
import 'package:hobby_atlas/screens/t_bbx_builder_screen.dart';
import 'package:hobby_atlas/theme.dart';

void main() {
  late BbxBuilderData data;
  setUpAll(() {
    final json = jsonDecode(File('test/fixtures/bbx-database.sample.json').readAsStringSync()) as Map<String, Object?>;
    data = BbxBuilderData.fromJson(json);
  });

  test('칸 이름 · 규칙 이유가 고른 언어를 따른다', () {
    addTearDown(() => L10n.debugSet(AppLang.ko));
    const issue = RuleIssue(IssueCode.missingSlot, 'missing ratchet', slot: Slot.ratchet);
    L10n.debugSet(AppLang.ko);
    expect(bbxSlotLabel(Slot.blade), '블레이드');
    expect(bbxIssueText(issue, data.catalog), '래칫 칸이 비었어요');
    L10n.debugSet(AppLang.zh);
    expect(bbxSlotLabel(Slot.blade), '战刃');
    expect(bbxIssueText(issue, data.catalog), '棘轮槽是空的');
    expect(bbxProfileLabel('free'), '自由');
  });

  testWidgets('중국어 화면: 조합 만들기 첫 화면', (tester) async {
    addTearDown(() => L10n.debugSet(AppLang.ko));
    L10n.debugSet(AppLang.zh);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = UserStore.memory();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildGpTheme(),
        builder: (context, child) => MarksHost(store: store, child: child!),
        home: BbxBuilderScreen(loaders: Loaders(bbxBuilder: () async => data)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('陀螺组合'), findsOneWidget);
    expect(find.text('选个零件吧'), findsOneWidget);
    expect(find.text('부품을 골라 주세요'), findsNothing);
  });
}
