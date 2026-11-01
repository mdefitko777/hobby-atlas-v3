// 화면 T 베이 조합 만들기 — 실제 bbx-database.json 에서 잘라 낸 fixture 로
// 맞는 조합 · 안 맞는 조합(이유) · 저장 → 다시 읽기 · 덱의 겹치는 부품.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/api.dart';
import 'package:hobby_atlas/bbx/bbx.dart';
import 'package:hobby_atlas/data/bbx_builder_data.dart';
import 'package:hobby_atlas/data/user_store.dart';
import 'package:hobby_atlas/marks.dart';
import 'package:hobby_atlas/models.dart';
import 'package:hobby_atlas/screens/t_bbx_builder_screen.dart';
import 'package:hobby_atlas/theme.dart';
import 'package:hobby_atlas/widgets.dart';

// fixture 의 part_id (test/bbx_rules_test.dart 와 같음)
const swordDran = 'BL-PRD-910381-00', keelShark = 'BL-PRD-912965-01', helmKnight = 'BL-PRD-912965-05';
const arrowWizard = 'BL-PRD-912965-06', clockMirage = 'BL-PRD-990154-01';
const r360 = 'RC-PRD-910381-00', r380 = 'RC-PRD-912965-03', r455 = 'RC-PRD-939627-02';
const bitF = 'BT-PRD-910381-00', bitB = 'BT-PRD-912965-03', bitLF = 'BT-PRD-912965-01', bitT = 'BT-PRD-912965-06';

late BbxBuilderData data;
BbxCatalog get cat => data.catalog;

Map<String, Object?> _fixture() {
  final json = jsonDecode(File('test/fixtures/bbx-database.sample.json').readAsStringSync()) as Map<String, Object?>;
  // 테스트는 인터넷 사진을 받지 않는다 → 사진 칸은 자리표시
  for (final list in (json['parts']! as Map).values) {
    for (final p in list as List) {
      (p as Map)
        ..['image'] = ''
        ..['image_remote'] = ''
        ..['image_fallback'] = '';
    }
  }
  return json;
}

Future<void> _pump(WidgetTester tester, UserStore store) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildGpTheme(),
      builder: (context, child) => MarksHost(store: store, child: child!),
      home: BbxBuilderScreen(loaders: Loaders(bbxBuilder: () async => data)),
    ),
  );
  await tester.pumpAndSettle();
}

/// 칸을 눌러 시트에서 찾아 고르기
Future<void> _choose(WidgetTester tester, Slot slot, String partId, {String? search}) async {
  await tester.tap(find.byKey(Key('bbx-slot-${slot.json}')));
  await tester.pumpAndSettle();
  final mold = cat.moldOf(partId)!;
  await tester.enterText(
    find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextField)),
    search ?? mold.name('en'),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('bbx-pick-${mold.key}')));
  await tester.pumpAndSettle();
}

Finder _tab(String label) => find.byWidgetPredicate((w) => w is UnderlineTab && w.label == label);

/// 토스트(2.5초)가 남은 채 끝나지 않게
Future<void> _drainToasts(WidgetTester tester) => tester.pump(const Duration(seconds: 3));

Combo _c(String id, String nick, Map<Slot, String> parts) =>
    Combo(id: id, arch: Arch.standard, parts: parts, nickname: nick);

void main() {
  setUpAll(() => data = BbxBuilderData.fromJson(_fixture()));

  testWidgets('맞는 조합: 블레이드 → 래칫 → 비트를 고르면 상자 이름 · 규칙 ✓ · 무게 · 보유 표시', (tester) async {
    final store = UserStore.memory()..setBbxPart(swordDran, true);
    await _pump(tester, store);
    expect(find.text('부품을 골라 주세요'), findsOneWidget);

    await _choose(tester, Slot.blade, swordDran);
    // 가진 블레이드 → 칸에 책갈피
    expect(
      find.descendant(of: find.byKey(const Key('bbx-slot-blade')), matching: find.byType(OwnedIcon)),
      findsOneWidget,
    );
    expect(find.textContaining('남은 칸: 래칫 · 비트'), findsOneWidget);

    await _choose(tester, Slot.ratchet, r360, search: '3-60');
    await _choose(tester, Slot.bit, bitF, search: cat.moldOf(bitF)!.name('ko'));

    final combo = Combo(
      id: 'x',
      arch: Arch.standard,
      parts: {Slot.blade: swordDran, Slot.ratchet: r360, Slot.bit: bitF},
    );
    expect(isLegalBey(combo, cat), isTrue);
    final ko = boxName(combo, cat, lang: 'ko');
    expect(ko, contains('3-60F'));
    expect(tester.widget<Text>(find.byKey(const Key('bbx-box-name'))).data, ko);
    expect(find.textContaining(boxName(combo, cat)), findsOneWidget); // 일본 상자 이름 (ドランソード3-60F)
    expect(find.byKey(const Key('bbx-legal')), findsOneWidget);
    expect(find.byKey(const Key('bbx-issue-simpleOnlyNeedsSimpleRatchet')), findsNothing);
    // 래칫 · 비트는 없으니 "없는 부품"
    expect(find.textContaining('없는 부품:'), findsOneWidget);
    final weight = comboStats(combo, cat).weightG;
    if (weight != null) expect(find.textContaining('${weight.toStringAsFixed(1)}g'), findsOneWidget);
  });

  testWidgets('안 맞는 조합: 클락 미라주 + 3-60 → 단순 래칫 이유 · 시트에서 미리 ⊘', (tester) async {
    final store = UserStore.memory();
    await _pump(tester, store);
    await _choose(tester, Slot.blade, clockMirage);

    // 래칫 시트: 3-60 은 지금 조합과 안 맞음(⊘), 9-65(단순 래칫)는 괜찮음
    await tester.tap(find.byKey(const Key('bbx-slot-ratchet')));
    await tester.pumpAndSettle();
    await tester.enterText(find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextField)), '3-60');
    await tester.pumpAndSettle();
    final row360 = find.byKey(Key('bbx-pick-${cat.moldOf(r360)!.key}'));
    expect(find.descendant(of: row360, matching: find.byIcon(Icons.block)), findsOneWidget);
    await tester.tap(row360);
    await tester.pumpAndSettle();
    await _choose(tester, Slot.bit, bitF, search: cat.moldOf(bitF)!.name('ko'));

    final reason = find.byKey(const Key('bbx-issue-simpleOnlyNeedsSimpleRatchet'));
    expect(reason, findsOneWidget);
    expect(find.descendant(of: reason, matching: find.textContaining('단순 래칫')), findsOneWidget);
    expect(find.byKey(const Key('bbx-legal')), findsNothing);

    // 래칫을 단순 래칫으로 바꾸면 맞는 조합
    await tester.tap(find.descendant(of: find.byKey(const Key('bbx-slot-ratchet')), matching: find.byTooltip('비우기')));
    await tester.pumpAndSettle();
    await _choose(tester, Slot.ratchet, 'RC-PRD-990154-01', search: '9-65');
    expect(reason, findsNothing);
    expect(find.byKey(const Key('bbx-legal')), findsOneWidget);
  });

  testWidgets('저장 → user.json 모양으로 다시 읽기 → 불러오기 · 이름 바꾸기 · 지우기(되돌리기)', (tester) async {
    final store = UserStore.memory();
    await _pump(tester, store);
    await _choose(tester, Slot.blade, swordDran);
    await _choose(tester, Slot.ratchet, r360, search: '3-60');
    await _choose(tester, Slot.bit, bitF, search: cat.moldOf(bitF)!.name('ko'));
    await tester.tap(find.byKey(const Key('bbx-save')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('bbx-name-field')), '내 드랜');
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(store.bbxCombos, hasLength(1));
    final saved = store.bbxCombos.single;
    expect(saved.nickname, '내 드랜');
    expect(saved.arch, Arch.standard);
    expect(saved.parts, {Slot.blade: swordDran, Slot.ratchet: r360, Slot.bit: bitF});
    await _drainToasts(tester);

    // 기기 저장 파일(local_state.bbx_combos)로 갔다가 새 저장소로 다시 읽기
    final file = jsonDecode(jsonEncode(store.toJson())) as Map<String, Object?>;
    expect((file['local_state']! as Map)['bbx_combos'], hasLength(1));
    final again = UserStore.memory()..debugLoadJson(file);
    expect(again.bbxCombos.single.signature, saved.signature);
    expect(again.bbxCombos.single.nickname, '내 드랜');

    await _pump(tester, again);
    await tester.tap(_tab('저장'));
    await tester.pumpAndSettle();
    expect(find.text('내 드랜'), findsOneWidget);
    await tester.tap(find.byKey(Key('bbx-saved-${saved.id}')));
    await tester.pumpAndSettle();
    // 만들기 탭에 그대로 불러옴 (고쳐 저장)
    expect(tester.widget<Text>(find.byKey(const Key('bbx-box-name'))).data, boxName(saved, cat, lang: 'ko'));
    expect(find.byKey(const Key('bbx-legal')), findsOneWidget);
    expect(find.text('고쳐 저장'), findsOneWidget);

    // 이름 바꾸기
    await tester.tap(_tab('저장'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('이름 바꾸기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('bbx-name-field')), '새 이름');
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(again.bbxCombos.single.nickname, '새 이름');

    // 지우기 → 되돌리기
    await tester.tap(find.byTooltip('지우기'));
    await tester.pumpAndSettle();
    expect(again.bbxCombos, isEmpty);
    expect(find.text('저장한 조합이 없어요'), findsOneWidget);
    await tester.tap(find.text('되돌리기'));
    await tester.pumpAndSettle();
    expect(again.bbxCombos.single.nickname, '새 이름');
    await _drainToasts(tester);
  });

  testWidgets('덱: 3칸에 같은 래칫이 겹치면 빨간 줄 · 바꾸면 규칙에 맞는 덱', (tester) async {
    final store = UserStore.memory()
      ..saveBbxCombo(_c('a', '드랜', {Slot.blade: swordDran, Slot.ratchet: r360, Slot.bit: bitF}))
      ..saveBbxCombo(_c('b', '샤크', {Slot.blade: keelShark, Slot.ratchet: r360, Slot.bit: bitLF}))
      ..saveBbxCombo(_c('c', '나이트', {Slot.blade: helmKnight, Slot.ratchet: r380, Slot.bit: bitB}))
      ..saveBbxCombo(_c('d', '위저드', {Slot.blade: arrowWizard, Slot.ratchet: r455, Slot.bit: bitT}));
    await _pump(tester, store);
    await tester.tap(_tab('덱'));
    await tester.pumpAndSettle();
    expect(find.text('덱이 없어요'), findsOneWidget);
    await tester.tap(find.byTooltip('덱 만들기'));
    await tester.pumpAndSettle();
    expect(store.bbxDecks, hasLength(1));
    final deckId = store.bbxDecks.single.id;
    expect(store.bbxDecks.single.comboIds, ['', '', '']);

    Future<void> put(int i, String name) async {
      await tester.tap(find.byKey(Key('bbx-deck-$deckId-$i')));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(BottomSheet), matching: find.text(name)));
      await tester.pumpAndSettle();
    }

    await put(0, '드랜');
    await put(1, '샤크');
    await put(2, '나이트');
    expect(store.bbxDecks.single.comboIds, ['a', 'b', 'c']);
    final r360Name = cat.moldOf(r360)!.name('ko');
    expect(find.text('$r360Name — 1번 · 2번 조합에 겹쳐요'), findsOneWidget);
    expect(find.text('규칙에 맞는 덱이에요'), findsNothing);

    // 엔진과 같은 판단
    final report = validateDeck([store.bbxCombo('a')!, store.bbxCombo('b')!, store.bbxCombo('c')!], cat);
    expect(report.issues.map((i) => i.code), contains(IssueCode.repeatedMold));

    await put(1, '위저드');
    expect(find.textContaining('겹쳐요'), findsNothing);
    expect(find.text('규칙에 맞는 덱이에요'), findsOneWidget);

    // 자유 규칙이면 겹쳐도 됨
    await put(1, '샤크');
    await tester.tap(find.text('자유'));
    await tester.pumpAndSettle();
    expect(store.bbxDecks.single.rulesProfile, 'free');
    expect(find.textContaining('겹쳐요'), findsNothing);

    // 덱에 넣은 조합을 지우면 그 칸이 빈다
    store.deleteBbxCombo('b');
    await tester.pumpAndSettle();
    expect(store.bbxDecks.single.comboIds, ['a', '', 'c']);
    expect(find.text('조합 2 / 3'), findsOneWidget);
  });

  test('가진 부품 = 켠 부품 + 구매함 상품의 부품 (도감과 같은 규칙)', () {
    final me = UserStore.memory()..setBbxPart(bitF, true);
    final kitId = data.kitSets.entries.firstWhere((e) => e.value == 'BX-01').key;
    expect(data.inventory(me).ownedCount(swordDran), 0);
    me.setStatus(kitId, CollectStatus.owned);
    final inv = data.inventory(me);
    expect(inv.ownedCount(swordDran), greaterThan(0));
    expect(inv.ownedCount(r360), greaterThan(0));
    expect(inv.ownedCount(bitF), greaterThan(0));
    expect(
      canBuild(
        Combo(id: 'x', arch: Arch.standard, parts: {Slot.blade: swordDran, Slot.ratchet: r360, Slot.bit: bitF}),
        inv,
      ),
      isTrue,
    );
  });

  test('백업 가져오기: 베이 조합 · 덱도 (기기에 있는 id 는 그대로)', () {
    final src = UserStore.memory()
      ..saveBbxCombo(_c('a', '드랜', {Slot.blade: swordDran, Slot.ratchet: r360, Slot.bit: bitF}))
      ..saveBbxDeck(const Deck(id: 'd1', name: '덱', comboIds: ['a']));
    final text = jsonEncode(src.toJson());
    final dst = UserStore.memory()..saveBbxCombo(_c('a', '내 것', {Slot.blade: keelShark}));
    final p = dst.previewImport(text, (_) => true);
    expect(p.isEmpty, isFalse);
    dst.applyImport(p);
    expect(dst.bbxCombos.single.nickname, '내 것');
    expect(dst.bbxDecks.single.comboIds, ['a', '', '']);
  });
}
