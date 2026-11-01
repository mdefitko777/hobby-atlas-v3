// BBX build rules on a fixture cut from the real Gunpula bbx-database.json
// (test/fixtures/bbx-database.sample.json, made by tool/bbx_cut_fixture.dart).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/bbx/bbx.dart';

late BbxCatalog cat;

Combo stock(String seriesId) => cat.seriesById[seriesId]!.combo!;

Combo bey(Arch arch, Map<Slot, String> parts, {String id = 'c'}) => Combo(id: id, arch: arch, parts: parts);

List<IssueCode> errorsOf(Combo c) => [
  for (final i in comboIssues(c, cat))
    if (i.isError) i.code,
];

// Part ids from the fixture.
const swordDran = 'BL-PRD-910381-00', swordDranGold = 'BL-EVE-910909-01', swordDranB = 'BL-PRD-912965-03';
const keelShark = 'BL-PRD-912965-01', helmKnight = 'BL-PRD-912965-05', arrowWizard = 'BL-PRD-912965-06';
const clockMirage = 'BL-PRD-990154-01', bulletGriffon = 'BL-PRD-096160-00';
const r360 = 'RC-PRD-910381-00',
    r380 = 'RC-PRD-912965-03',
    r385 = 'RC-PRD-939542-01',
    r965 = 'RC-PRD-990154-01',
    r455 = 'RC-PRD-939627-02';
const bitF = 'BT-PRD-910381-00', bitB = 'BT-PRD-912965-03', bitLF = 'BT-PRD-912965-01', bitT = 'BT-PRD-912965-06';
const turbo = 'BT-PRD-956976-00', operate = 'BT-PRD-098775-01';
const chipDran = 'LC-PRD-939597-00', chipRhino = 'LC-PRD-939627-02', chipIncendio = 'LC-PRD-939627-01';
const chipEmperor = 'LC-PRD-098775-01', chipValkyrie = 'LC-PRD-954316-00';
const mainCourage = 'MB-PRD-939597-00',
    mainReaper = 'MB-PRD-939627-01',
    mainArc = 'MB-PRD-939627-03',
    mainMight = 'MB-PRD-098775-01';
const assistS = 'AB-PRD-939597-00', assistT = 'AB-PRD-939627-01', assistC = 'AB-PRD-939627-02';
const metalRage = 'ME-EVE-088899-00', overF = 'OV-EVE-088899-00', mainFRage = 'MB-EVE-088899-00';
const assembledCourageDran = 'BL-PRD-939597-00';

void main() {
  setUpAll(() {
    final json = jsonDecode(File('test/fixtures/bbx-database.sample.json').readAsStringSync()) as Map<String, Object?>;
    cat = BbxCatalog.fromJson(json);
  });

  group('names', () {
    test('base names drop set code, finish and editions in every language', () {
      expect(baseName('BXH-25-01 Strike Dran Metallic Coat: Gold', 'en'), 'Strike Dran');
      expect(baseName('BX-07 Sword Dran Special Ver.', 'en'), 'Sword Dran');
      expect(baseName('BXG-49 Arrow Wizard Version 2.0', 'en'), 'Arrow Wizard');
      expect(baseName('BXG-07-00 Lightning L-Drago (upper type)', 'en'), 'Lightning L-Drago');
      expect(baseName('BXH-22 ラグナレイジFE メタルコート:ゴールド', 'ja'), 'ラグナレイジFE');
      expect(baseName('BXG-71-02 DMMくじLAST CHANCE賞 バイソンバローDB メタルコート:ホワイト', 'ja'), 'バイソンバローDB');
      expect(baseName('BXH-17 ドラン クリアブラックVer.', 'ja'), 'ドラン');
      expect(baseName('BX-01 드랜 소드 홀로 스티커 버전', 'ko'), '드랜 소드');
      expect(baseName('BX-01 蒼龍神劍 金屬塗層:燦金', 'zh'), '蒼龍神劍');
      expect(baseName('BXH-14> 戰神', 'zh'), '戰神');
      expect(partBaseName('BXG-52 Sword Dran 1-60V Metallic Coat: Black J League Ver.', 'en'), 'Sword Dran');
      expect(baseName(r'BXG-39-02 ワイバーンホバー \n メタルコート:バイオレット', 'ja'), 'ワイバーンホバー');
    });

    test('width folding and keys', () {
      expect(foldWidth('F／Rage　Ｘ'), 'F/Rage X');
      expect(nameKey('Sword Dran'), 'SWORDDRAN');
      expect(looseNameKey('ウイザードアロー'), looseNameKey('ウィザードアロー'));
      expect(nameKey('ウイザードアロー') == nameKey('ウィザードアロー'), isFalse);
    });
  });

  group('catalogue', () {
    test('series split into stock combos and parts-only products', () {
      expect(cat.series, hasLength(29));
      expect(cat.stockCombos, hasLength(26));
      final partsOnly = cat.series.where((s) => s.kind == SeriesKind.partsOnly).map((s) => s.id).toSet();
      expect(partsOnly, {'SR-PRD-089193-01', 'SR-PRD-953715-00', 'SR-FRB-CR2312-00'});
      final lockOnly = cat.seriesById['SR-PRD-953715-00']!;
      expect(lockOnly.partIds, ['LC-PRD-953715-00']);
      expect(lockOnly.dataIssues, hasLength(5)); // dangling part ids in the source
      expect(cat.seriesById['SR-PRD-089193-01']!.partIds, ['BT-PRD-089193-01']); // the box "blade" is a placeholder
      expect(cat.sources, isNotEmpty);
    });

    test('recolours, reprints and modes share one mold', () {
      expect(cat.moldOf(swordDran), same(cat.moldOf(swordDranGold)));
      expect(cat.moldOf(swordDran), same(cat.moldOf(swordDranB)));
      expect(cat.moldOf(swordDran)!.key, 'blade:ドランソード');
      expect(cat.moldOf(swordDran)!.name('en'), 'Sword Dran');
      expect(cat.moldOf('BL-PRD-930358-00'), same(cat.moldOf('BL-PRD-930358-01'))); // L-Drago upper / rapid-hit
      expect(cat.moldOf(r360)!.key, 'ratchet:3-60');
      expect(cat.moldOf('RC-PRD-080640-00M')!.key, 'ratchet:3-60'); // pseudo "3-61", partMoldOverrides
      expect(cat.moldOf(bitF)!.key, 'bit:F');
      expect(cat.moldOf(overF)!.key, 'over_blade:F'); // same letter, different slot
      expect(cat.moldOf(assistT)!.key == cat.moldOf(bitT)!.key, isFalse);
      expect(cat.moldOf('ratchet:3-60'), same(cat.moldOf(r360))); // mold keys resolve too
    });

    test('flags derived from the data', () {
      expect(cat.moldOf(r385)!.simpleRatchet, isTrue);
      expect(cat.moldOf(r965)!.simpleRatchet, isTrue);
      expect(cat.moldOf(r455)!.simpleRatchet, isTrue);
      expect(cat.moldOf(r360)!.simpleRatchet, isFalse);
      expect(cat.moldOf(clockMirage)!.simpleOnly, isTrue);
      expect(cat.moldOf(swordDran)!.simpleOnly, isFalse);
      expect(cat.moldOf(bulletGriffon)!.integratedBlade, isTrue);
      expect(cat.moldOf(turbo)!.integratedBit, isTrue);
      expect(cat.moldOf(operate)!.integratedBit, isTrue);
      expect(cat.moldOf(bitF)!.integratedBit, isFalse);
      expect(cat.moldOf(chipEmperor)!.metalLockChip, isTrue);
      expect(cat.moldOf(chipValkyrie)!.metalLockChip, isTrue);
      expect(cat.moldOf(chipDran)!.metalLockChip, isFalse);
      expect(cat.moldOf(swordDran)!.line, 'bx');
      expect(cat.moldOf(chipDran)!.line, 'cx');
      expect(cat.moldOf(r360)!.line, '');
    });

    test('placeholders, pre-assembled CX blades and Expand main blades are not pickable', () {
      expect(cat.moldOf('RC-PRD-096160-00')!.placeholder, isTrue); // Ratchet-Integrated Blade
      expect(cat.moldOf('RC-PRD-956976-00')!.placeholder, isTrue); // Ratchet-Integrated Bits
      expect(cat.moldOf('BL-PRD-089193-01')!.placeholder, isTrue); // bit-set box
      expect(cat.moldOf(assembledCourageDran)!.assembled, isTrue);
      expect(cat.moldOf(mainFRage)!.components, ['metal_blade:レイジ', 'over_blade:F']);
      expect(cat.moldOf('MB-PRD-097259-00')!.components, ['metal_blade:ブリッツ', 'over_blade:B']);
      final blades = cat.moldsFor(Slot.blade).map((m) => m.key);
      expect(blades, contains('blade:ドランソード'));
      expect(blades, isNot(contains('blade:ドランブレイブS')));
      expect(cat.moldsFor(Slot.mainBlade).every((m) => m.components.isEmpty), isTrue);
      expect(cat.moldsFor(Slot.ratchet).every((m) => RegExp(r'^[0-9M]-\d\d$').hasMatch(m.code)), isTrue);
    });

    test('stock combos pick the right architecture', () {
      expect(stock('SR-PRD-910381-00').arch, Arch.standard);
      expect(stock('SR-PRD-096160-00').arch, Arch.integrated);
      expect(stock('SR-PRD-096160-00').parts.keys, unorderedEquals([Slot.blade, Slot.bit]));
      expect(stock('SR-PRD-939597-00').arch, Arch.cx);
      expect(stock('SR-PRD-939597-00').parts.containsKey(Slot.blade), isFalse); // not the assembled record
      expect(stock('SR-PRD-956976-00').parts.containsKey(Slot.ratchet), isFalse); // Turbo
      expect(stock('SR-EVE-088899-00').arch, Arch.cxExpand);
      expect(stock('SR-EVE-088899-00').parts[Slot.metalBlade], metalRage);
      expect(stock('SR-EVE-088899-00').parts.containsKey(Slot.mainBlade), isFalse);
      expect(stock('SR-PRD-910381-00').source, ComboSource.stock);
      expect(stock('SR-PRD-910381-00').seriesId, 'SR-PRD-910381-00');
    });

    test('every fixture stock combo passes the audit', () {
      final audit = checkStockSeries(cat);
      expect(audit.failures, isEmpty);
      expect(audit.passed, 26);
      expect(audit.byArch, {Arch.standard: 13, Arch.integrated: 1, Arch.cx: 8, Arch.cxExpand: 4});
      expect(audit.notes.where((n) => n.contains('kana typo')), hasLength(1));
    });
  });

  group('one bey', () {
    test('completeness per architecture (core.js isCompleteBey)', () {
      expect(
        isCompleteBey(bey(Arch.standard, {Slot.blade: swordDran, Slot.ratchet: r360, Slot.bit: bitF}), cat),
        isTrue,
      );
      expect(isCompleteBey(bey(Arch.standard, {Slot.blade: swordDran, Slot.bit: bitF}), cat), isFalse);
      expect(isCompleteBey(bey(Arch.integrated, {Slot.blade: bulletGriffon, Slot.bit: bitF}), cat), isTrue);
      expect(isCompleteBey(bey(Arch.integrated, {Slot.blade: bulletGriffon}), cat), isFalse);
      expect(
        isCompleteBey(
          bey(Arch.cx, {
            Slot.lockChip: chipDran,
            Slot.mainBlade: mainCourage,
            Slot.assistBlade: assistS,
            Slot.ratchet: r360,
            Slot.bit: bitF,
          }),
          cat,
        ),
        isTrue,
      );
      expect(
        isCompleteBey(
          bey(Arch.cx, {Slot.lockChip: chipDran, Slot.mainBlade: mainCourage, Slot.ratchet: r360, Slot.bit: bitF}),
          cat,
        ),
        isFalse,
      );
      expect(
        isCompleteBey(
          bey(Arch.cxExpand, {
            Slot.lockChip: chipDran,
            Slot.metalBlade: metalRage,
            Slot.overBlade: overF,
            Slot.assistBlade: assistS,
            Slot.ratchet: r360,
            Slot.bit: bitF,
          }),
          cat,
        ),
        isTrue,
      );
      // over blade needs its metal blade
      expect(
        isCompleteBey(
          bey(Arch.cxExpand, {
            Slot.lockChip: chipDran,
            Slot.overBlade: overF,
            Slot.assistBlade: assistS,
            Slot.ratchet: r360,
            Slot.bit: bitF,
          }),
          cat,
        ),
        isFalse,
      );
      // an integrated bit fills the ratchet slot too
      expect(isCompleteBey(bey(Arch.standard, {Slot.blade: swordDran, Slot.bit: turbo}), cat), isTrue);
      expect(
        isCompleteBey(
          bey(Arch.cx, {
            Slot.lockChip: chipDran,
            Slot.mainBlade: mainCourage,
            Slot.assistBlade: assistS,
            Slot.bit: operate,
          }),
          cat,
        ),
        isTrue,
      );
    });

    test('legal custom combos: CX layers interchange, ratchets and bits are shared', () {
      expect(
        errorsOf(
          bey(Arch.cx, {
            Slot.lockChip: chipRhino,
            Slot.mainBlade: mainArc,
            Slot.assistBlade: assistS,
            Slot.ratchet: r360,
            Slot.bit: bitB,
          }),
        ),
        isEmpty,
      );
      expect(
        errorsOf(
          bey(Arch.cxExpand, {
            Slot.lockChip: chipEmperor,
            Slot.metalBlade: metalRage,
            Slot.overBlade: overF,
            Slot.assistBlade: assistC,
            Slot.bit: turbo,
          }),
        ),
        isEmpty,
      );
      expect(errorsOf(bey(Arch.standard, {Slot.blade: swordDran, Slot.bit: turbo})), isEmpty);
      expect(errorsOf(bey(Arch.integrated, {Slot.blade: bulletGriffon, Slot.bit: bitLF})), isEmpty);
    });

    test('integrated blades and bits', () {
      expect(errorsOf(bey(Arch.standard, {Slot.blade: bulletGriffon, Slot.ratchet: r360, Slot.bit: bitF})), [
        IssueCode.integratedBladeNeedsIntegratedArch,
      ]);
      expect(errorsOf(bey(Arch.integrated, {Slot.blade: swordDran, Slot.bit: bitF})), [IssueCode.notAnIntegratedBlade]);
      expect(errorsOf(bey(Arch.integrated, {Slot.blade: bulletGriffon, Slot.ratchet: r360, Slot.bit: bitF})), [
        IssueCode.extraSlot,
      ]);
      expect(errorsOf(bey(Arch.integrated, {Slot.blade: bulletGriffon, Slot.bit: turbo})), [
        IssueCode.integratedBitOnIntegratedBlade,
      ]);
      expect(errorsOf(bey(Arch.standard, {Slot.blade: swordDran, Slot.ratchet: r360, Slot.bit: turbo})), [
        IssueCode.ratchetWithIntegratedBit,
      ]);
    });

    test('ClockMirage takes only simple ratchets', () {
      expect(errorsOf(bey(Arch.standard, {Slot.blade: clockMirage, Slot.ratchet: r360, Slot.bit: bitB})), [
        IssueCode.simpleOnlyNeedsSimpleRatchet,
      ]);
      for (final r in [r385, r965, r455]) {
        expect(errorsOf(bey(Arch.standard, {Slot.blade: clockMirage, Slot.ratchet: r, Slot.bit: bitB})), isEmpty);
      }
      final withTurbo = comboIssues(bey(Arch.standard, {Slot.blade: clockMirage, Slot.bit: turbo}), cat);
      expect(withTurbo.map((i) => i.code), [IssueCode.simpleOnlyWithIntegratedBit]);
      expect(withTurbo.single.severity, Severity.warning);
      expect(isLegalBey(bey(Arch.standard, {Slot.blade: clockMirage, Slot.bit: turbo}), cat), isTrue);
    });

    test('unknown, misplaced and non-part records', () {
      expect(errorsOf(bey(Arch.standard, {Slot.blade: 'BL-NOPE', Slot.ratchet: r360, Slot.bit: bitF})), [
        IssueCode.unknownPart,
      ]);
      expect(errorsOf(bey(Arch.standard, {Slot.blade: r360, Slot.ratchet: r360, Slot.bit: bitF})), [
        IssueCode.wrongSlot,
      ]);
      expect(errorsOf(bey(Arch.standard, {Slot.blade: assembledCourageDran, Slot.ratchet: r360, Slot.bit: bitF})), [
        IssueCode.notAPart,
      ]);
      expect(errorsOf(bey(Arch.standard, {Slot.blade: 'BL-PRD-089193-01', Slot.ratchet: r360, Slot.bit: bitF})), [
        IssueCode.notAPart,
      ]);
      expect(
        errorsOf(
          bey(Arch.cx, {
            Slot.lockChip: chipDran,
            Slot.mainBlade: mainFRage,
            Slot.assistBlade: assistS,
            Slot.ratchet: r360,
            Slot.bit: bitF,
          }),
        ),
        [IssueCode.compositeMainBlade],
      );
      expect(
        errorsOf(
          bey(Arch.standard, {Slot.blade: swordDran, Slot.ratchet: r360, Slot.bit: bitF, Slot.lockChip: chipDran}),
        ),
        [IssueCode.extraSlot],
      );
      expect(errorsOf(bey(Arch.standard, {Slot.blade: swordDran, Slot.ratchet: r360})), [IssueCode.missingSlot]);
    });
  });

  group('box names', () {
    test('stock combos in each language', () {
      final bx01 = stock('SR-PRD-910381-00');
      expect(boxName(bx01, cat), 'ドランソード3-60F');
      expect(boxName(bx01, cat, lang: 'en'), 'Sword Dran 3-60F');
      expect(boxName(bx01, cat, lang: 'ko'), '드랜 소드 3-60F');
      expect(boxName(bx01, cat, lang: 'zh'), '蒼龍神劍 3-60F');
      final cx01 = stock('SR-PRD-939597-00');
      expect(boxName(cx01, cat), 'ドランブレイブS 6-60V');
      expect(boxName(cx01, cat, lang: 'en'), 'Dran Courage S 6-60V');
      expect(boxName(cx01, cat, lang: 'en', mainFirst: true), 'Courage Dran S 6-60V');
      expect(boxName(cx01, cat, lang: 'ko'), '드랜 브레이브 S6-60V');
      expect(boxName(cx01, cat, lang: 'zh'), '蒼龍勇氣 S6-60V');
      expect(boxName(stock('SR-EVE-088899-00'), cat), 'ラグナレイジFE 4-55Y');
      expect(boxName(stock('SR-EVE-088899-00'), cat, lang: 'en', mainFirst: true), 'Rage Ragna FE 4-55Y');
      expect(boxName(stock('SR-PRD-096160-00'), cat), 'バレットグリフォンH');
      expect(boxName(stock('SR-PRD-098775-01'), cat), 'エンペラーマイトHOp');
      expect(boxName(stock('SR-PRD-956976-00'), cat, lang: 'zh'), '天馬爆擊 ATr');
    });

    test('custom and half-built combos; assist and bit letters stay apart', () {
      final c = bey(Arch.cx, {
        Slot.lockChip: chipIncendio,
        Slot.mainBlade: mainReaper,
        Slot.assistBlade: assistT,
        Slot.ratchet: r360,
        Slot.bit: bitT,
      });
      expect(boxName(c, cat), 'ヘルズリーパーT 3-60T');
      expect(boxName(bey(Arch.standard, {Slot.blade: swordDran}), cat, lang: 'en'), 'Sword Dran');
      expect(
        boxName(bey(Arch.standard, {Slot.blade: swordDranGold, Slot.ratchet: r380, Slot.bit: bitB}), cat, lang: 'en'),
        'Sword Dran 3-80B',
      );
    });

    test('box-name match ignores the finish and tolerates a kana typo', () {
      expect(boxNameMatch(cat.seriesById['SR-EVE-910909-01']!, cat, 'ja'), NameMatch.exact);
      expect(boxNameMatch(cat.seriesById['SR-PRD-913108-06']!, cat, 'ja'), NameMatch.loose);
      expect(boxNameMatch(cat.seriesById['SR-PRD-939627-03']!, cat, 'en'), NameMatch.none); // en mixes Hells / Incendio
    });
  });

  group('stats and weight', () {
    test('sums the variants used', () {
      final s = comboStats(stock('SR-PRD-910381-00'), cat);
      expect(s.stats, const BbxStats(attack: 110, defense: 49, stamina: 36, dash: 35, burst: 80));
      expect(s.weightG, 43.3);
      expect(s.spin, 'right');
      expect(
        comboStats(
          bey(Arch.standard, {Slot.blade: 'BL-PRD-930358-00', Slot.ratchet: r360, Slot.bit: bitF}),
          cat,
        ).stats.attack,
        110,
      );
      expect(
        comboStats(
          bey(Arch.standard, {Slot.blade: 'BL-PRD-930358-01', Slot.ratchet: r360, Slot.bit: bitF}),
          cat,
        ).stats.attack,
        105,
      );
    });

    test('a mold stands in with its oldest weighed variant', () {
      final mold = cat.moldOf(swordDran)!;
      expect(mold.representativeId, swordDran); // BX-01, before the gold coat
      expect(mold.weightG, 34.8);
      expect(mold.stats.attack, 55);
      expect(cat.moldOf(bulletGriffon)!.weightG, isNull);
      final byMold = bey(Arch.standard, {Slot.blade: 'blade:ドランソード', Slot.ratchet: 'ratchet:3-60', Slot.bit: 'bit:F'});
      expect(isLegalBey(byMold, cat), isTrue);
      expect(comboStats(byMold, cat).weightG, 43.3);
      expect(boxName(byMold, cat), 'ドランソード3-60F');
    });

    test('unknown weight is not 0', () {
      final griffon = comboStats(stock('SR-PRD-096160-00'), cat);
      expect(griffon.weightG, isNull);
      expect(griffon.knownWeightG, 2.6);
      expect(griffon.unknownWeightSlots, [Slot.blade]);
      final kid = comboStats(stock('SR-PRD-056225-00'), cat);
      expect(kid.weightG, isNull);
      expect(kid.unknownWeightSlots, hasLength(5));
      expect(kid.stats.attack, greaterThan(0));
      // incomplete: no total even when the filled parts are weighed
      expect(comboStats(bey(Arch.standard, {Slot.blade: swordDran, Slot.ratchet: r360}), cat).weightG, isNull);
      final cx = comboStats(stock('SR-PRD-939597-00'), cat);
      expect(cx.weightG, 45.8); // 1.7 + 31.2 + 4.6 + 6.2 + 2.1
    });

    test('bar scales', () {
      for (final c in cat.stockCombos) {
        final s = comboStats(c, cat).stats;
        for (final k in BbxStats.keys) {
          expect(s[k], lessThanOrEqualTo(cat.comboStatMax[k]));
        }
      }
      expect(cat.slotStatMax[Slot.blade]!.attack, greaterThanOrEqualTo(60));
    });
  });

  group('owned quantities', () {
    test('ownedCount sums colours; kits add their parts', () {
      final inv = BbxInventory(cat, series: {'SR-PRD-910381-00': 1}, parts: {swordDranGold: 1, 'BL-NOPE': 1});
      expect(inv.ownedCount(swordDran), 2);
      expect(inv.ownedCount('blade:ドランソード'), 2);
      expect(inv.variantCount(swordDran), 1);
      expect(inv.ownedCount(r360), 1);
      expect(inv.ownedCount(keelShark), 0);
      expect(inv.unknownIds, ['BL-NOPE']);
    });

    test('Expand main-blade records count as metal + over; assembled records count as nothing', () {
      final inv = BbxInventory(cat, parts: {mainFRage: 1, assembledCourageDran: 1});
      expect(inv.ownedCount(metalRage), 1);
      expect(inv.ownedCount(overF), 1);
      expect(inv.ownedCount(mainFRage), 0);
      expect(inv.ownedCount(assembledCourageDran), 0);
      expect(inv.moldCounts, hasLength(2));
      final kit = BbxInventory(cat, series: {'SR-EVE-088899-00': 1});
      expect(canBuild(stock('SR-EVE-088899-00'), kit), isTrue);
      expect(kit.ownedCount(mainFRage), 0);
    });

    test('missingFor / canBuild / canBuildTogether (core.js canBuildTogether)', () {
      final inv = BbxInventory(cat, series: {'SR-PRD-910381-00': 1, 'SR-PRD-912965-01': 1});
      final bx01 = stock('SR-PRD-910381-00');
      final keel = stock('SR-PRD-912965-01');
      expect(canBuild(bx01, inv), isTrue);
      expect(canBuild(keel, inv), isTrue);
      expect(canBuildTogether([bx01, keel], inv), isTrue);
      final keelOnF = bey(Arch.standard, {Slot.blade: keelShark, Slot.ratchet: r360, Slot.bit: bitF});
      expect(canBuild(keelOnF, inv), isTrue);
      expect(canBuildTogether([bx01, keelOnF], inv), isFalse); // one F bit, needed twice
      final short = shortfall([bx01, keelOnF], inv);
      expect(short.map((m) => m.moldKey), ['bit:F']);
      expect(short.single.need, 2);
      expect(short.single.have, 1);
      final missing = missingFor(stock('SR-PRD-939542-01'), inv);
      expect(missing.map((m) => m.slot), unorderedEquals([Slot.blade, Slot.ratchet, Slot.bit]));
      expect(canBuild(bey(Arch.standard, {Slot.blade: swordDran, Slot.ratchet: r360}), inv), isFalse); // incomplete
    });

    test('owned part records: only owned counts by default', () {
      final parts = [
        const OwnedPart(instanceId: 'a', variantId: swordDran),
        const OwnedPart(instanceId: 'b', variantId: swordDranGold, status: OwnStatus.shipping),
        const OwnedPart(instanceId: 'c', variantId: r360, status: OwnStatus.wish),
      ];
      expect(BbxInventory.fromOwnedParts(cat, parts).ownedCount(swordDran), 1);
      expect(
        BbxInventory.fromOwnedParts(cat, parts, include: {OwnStatus.owned, OwnStatus.shipping}).ownedCount(swordDran),
        2,
      );
      expect(BbxInventory.fromOwnedParts(cat, parts).ownedCount(r360), 0);
    });
  });

  group('decks', () {
    final legalTrio = [
      'SR-PRD-912965-01',
      'SR-PRD-912965-03',
      'SR-PRD-939542-01',
    ]; // Keel 3-60LF, Sword 3-80B, Mail 3-85BS

    test('a legal 3on3 deck under every profile', () {
      final beys = [for (final id in legalTrio) stock(id)];
      for (final p in RulesProfile.all) {
        expect(validateDeck(beys, cat, profile: p).issues, isEmpty, reason: p.id);
      }
      final inv = BbxInventory(cat, series: {for (final id in legalTrio) id: 1});
      expect(validateDeck(beys, cat, inventory: inv).legal, isTrue);
    });

    test('deck size, incomplete and illegal beys', () {
      final two = validateDeck([stock('SR-PRD-912965-01'), stock('SR-PRD-912965-03')], cat);
      expect(two.errors.map((i) => i.code), [IssueCode.deckSize]);
      final bad = validateDeck([
        stock('SR-PRD-912965-01'),
        bey(Arch.standard, {Slot.blade: swordDran, Slot.ratchet: r380}),
        bey(Arch.standard, {Slot.blade: clockMirage, Slot.ratchet: 'RC-PRD-912965-05', Slot.bit: bitB}),
      ], cat);
      expect(bad.errors.map((i) => i.code), [IssueCode.beyIncomplete, IssueCode.beyIllegal]);
      expect(bad.errors.first.beys, [1]);
      expect(bad.errors.last.beys, [2]);
    });

    test('no mold may repeat; recolours count as the same mold', () {
      final beys = [
        stock('SR-EVE-910909-01'),
        stock('SR-PRD-912965-03'),
        stock('SR-PRD-939542-01'),
      ]; // gold Sword Dran + Sword Dran
      final tt = validateDeck(beys, cat);
      expect(tt.errors.map((i) => i.code), [IssueCode.repeatedMold]);
      expect(tt.errors.single.moldKey, 'blade:ドランソード');
      expect(tt.errors.single.beys, [0, 1]);
      expect(validateDeck(beys, cat, profile: RulesProfile.free).legal, isTrue);
      // the two L-Drago modes are one blade
      final modes = [stock('SR-PRD-930358-00'), stock('SR-PRD-930358-01'), stock('SR-PRD-939542-01')];
      expect(
        validateDeck(modes, cat).errors.map((i) => i.moldKey),
        containsAll(['blade:ライトニングエルドラゴ', 'ratchet:1-60', 'bit:F']),
      );
    });

    test('lock chips: TT lets plain chips repeat, WBO does not, metal chips never', () {
      final dranTwice = [
        stock('SR-PRD-939597-00'), // Dran chip
        bey(Arch.cx, {
          Slot.lockChip: chipDran,
          Slot.mainBlade: mainReaper,
          Slot.assistBlade: assistC,
          Slot.ratchet: r455,
          Slot.bit: 'BT-PRD-939627-02',
        }),
        stock('SR-PRD-912965-04'),
      ];
      expect(validateDeck(dranTwice, cat, profile: RulesProfile.tt).legal, isTrue);
      final wbo = validateDeck(dranTwice, cat, profile: RulesProfile.wbo);
      expect(wbo.errors.map((i) => i.moldKey), ['lock_chip:ドラン']);
      expect(validateDeck(dranTwice, cat, profile: RulesProfile.free).legal, isTrue);

      final emperorTwice = [
        stock('SR-PRD-098775-01'), // Emperor + Operate
        bey(Arch.cx, {
          Slot.lockChip: chipEmperor,
          Slot.mainBlade: mainArc,
          Slot.assistBlade: assistC,
          Slot.ratchet: r385,
          Slot.bit: bitB,
        }),
        stock('SR-PRD-912965-01'),
      ];
      final tt = validateDeck(emperorTwice, cat, profile: RulesProfile.tt);
      expect(tt.errors.map((i) => i.moldKey), ['lock_chip:エンペラー']);
      expect(validateDeck(emperorTwice, cat, profile: RulesProfile.free).legal, isTrue);
    });

    test('owned quantities must cover all three beys at once', () {
      final beys = [for (final id in legalTrio) stock(id)];
      final inv = BbxInventory(cat, series: {'SR-PRD-912965-01': 1, 'SR-PRD-912965-03': 1});
      final r = validateDeck(beys, cat, inventory: inv);
      expect(r.errors.map((i) => i.code).toSet(), {IssueCode.notEnoughParts});
      expect(r.errors.map((i) => i.moldKey), unorderedEquals(['blade:ナイトメイル', 'ratchet:3-85', 'bit:BS']));
    });

    test('saved decks resolve combo ids and their profile', () {
      final combos = {for (final id in legalTrio) id: stock(id)};
      final deck = Deck(id: 'd1', name: 'Main', comboIds: [...legalTrio], rulesProfile: 'wbo');
      expect(validateDeckRecord(deck, combos, cat).legal, isTrue);
      final gone = Deck(id: 'd2', name: 'Old', comboIds: [legalTrio[0], legalTrio[1], 'deleted']);
      expect(validateDeckRecord(gone, combos, cat).errors.map((i) => i.code), [
        IssueCode.unknownCombo,
        IssueCode.deckSize,
      ]);
      expect(RulesProfile.byId('nope'), same(RulesProfile.tt));
      expect(RulesProfile.byId('wbo').lockChips, LockChipRepeat.none);
    });
  });

  group('records', () {
    test('Combo / Deck / OwnedPart JSON round trip', () {
      final c = Combo(
        id: 'c1',
        arch: Arch.cx,
        parts: {
          Slot.lockChip: chipDran,
          Slot.mainBlade: mainCourage,
          Slot.assistBlade: assistS,
          Slot.ratchet: r360,
          Slot.bit: bitF,
        },
        nickname: 'Dran',
        favorite: true,
        rating: 4,
        tags: ['attack'],
        notes: 'x',
        createdAt: DateTime.utc(2026, 11, 1),
      );
      final back = Combo.fromJson(jsonDecode(jsonEncode(c.toJson())))!;
      expect(back.signature, c.signature);
      expect(back.nickname, 'Dran');
      expect(back.favorite, isTrue);
      expect(back.rating, 4);
      expect(back.tags, ['attack']);
      expect(back.createdAt, DateTime.utc(2026, 11, 1));
      expect(back.updatedAt, DateTime.utc(2026, 11, 1));
      expect(Combo.fromJson({'id': 'x', 'arch': 'nope'}), isNull);
      final d = Deck.fromJson(
        jsonDecode(jsonEncode(const Deck(id: 'd', name: 'n', comboIds: ['a', 'b', 'c'], rulesProfile: 'wbo').toJson())),
      )!;
      expect(d.comboIds, ['a', 'b', 'c']);
      expect(d.rulesProfile, 'wbo');
      final o = OwnedPart.fromJson(
        jsonDecode(
          jsonEncode(
            const OwnedPart(
              instanceId: 'i',
              variantId: swordDran,
              status: OwnStatus.shipping,
              fromSeriesId: 'SR-PRD-910381-00',
            ).toJson(),
          ),
        ),
      )!;
      expect(o.status, OwnStatus.shipping);
      expect(o.fromSeriesId, 'SR-PRD-910381-00');
    });
  });
}
