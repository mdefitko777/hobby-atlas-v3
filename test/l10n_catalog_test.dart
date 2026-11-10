// 중국어 화면 — 상품 필터 · 숫자 · 날짜 · 조립 상태 (묶음 catalog)
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/l10n/l10n.dart';
import 'package:hobby_atlas/logic/announcement_match.dart';
import 'package:hobby_atlas/logic/build_status.dart';
import 'package:hobby_atlas/models.dart';
import 'package:hobby_atlas/theme.dart';
import 'package:hobby_atlas/widgets.dart';

void main() {
  setUp(() => L10n.debugSet(AppLang.zh));
  tearDown(() => L10n.debugSet(AppLang.ko));

  test('숫자 · 날짜 · 필터 글이 중국어로', () {
    expect(yen(null), '价格未定');
    expect(yen(3850), '¥3,850');
    expect(won(41000), '41,000 韩元');
    expect(wonShort(184000), '18.4万');
    final now = DateTime(2026, 11, 11, 12);
    expect(timeAgo(now.subtract(const Duration(minutes: 3)), now: now), '3 分钟前');
    expect(timeAgo(now.subtract(const Duration(days: 1)), now: now), '昨天');
    expect(periodLabel('2023-01', ''), '2023.01 起');
    expect(BuildStage.built.label, '已完成');
    final f = KitFilter(lines: {'MS 앙상블'}, types: {'굿즈'}, works: {'기동전사 건담'}, workNames: {'기동전사 건담': '机动战士高达'});
    expect(f.labels, containsAll(['MS ENSEMBLE', '周边', '机动战士高达']));
    // 거르기 값은 한국어 그대로
    expect(f.lines, {'MS 앙상블'});
  });

  test('같은 IP 묶음 이름은 작품 중국어 이름 (고르기는 한국어 series)', () {
    Kit kit(Map<String, Object?> j) => Kit.fromSlim(j, recentSince: '', monthPrefix: '');
    final a = kit({'id': 'a', 'franchiseId': 'gundam', 'name': 'A', 'series': '기동전사 건담', 'seriesZh': '机动战士高达'});
    final b = kit({'id': 'b', 'franchiseId': 'gundam', 'name': 'B', 'series': '기동전사 건담', 'date': '2026-01'});
    final r = sameIpKits([a], [a, b]);
    expect(r.label, '机动战士高达');
    expect(r.kits.map((k) => k.id), ['b']);
  });

  testWidgets('필터 시트: 제목 · 줄 이름이 중국어', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final kits = [
      Kit.fromJson({'id': 'k1', 'franchiseId': 'gundam', 'name': 'K1', 'type': '굿즈', 'line': '굿즈', 'date': '2025-03'})!,
    ];
    await t.pumpWidget(
      MaterialApp(
        theme: buildGpTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => unawaited(showFilterSheet(context, kits: kits, initial: KitFilter())),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.text('筛选'), findsOneWidget);
    expect(find.text('即将发售'), findsOneWidget);
    expect(find.text('产品线'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
