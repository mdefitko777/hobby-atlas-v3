// Every phstudy stock combo in the real Gunpula bbx-database.json must be
// complete, legal and named like its box. Runs only when the file is given:
//   flutter test test/bbx_real_db_test.dart --dart-define=BBX_DB=<path to data/bbx-database.json>
//
// Known data quirks (all documented, none hide a rules failure):
// - 18 series are parts-only products (blade-only BXC boxes, bit sets, plus-one
//   bit campaigns, a lock chip, an assist blade), not beys. Two of them
//   reference part ids that are missing from parts (BXH-17, BXC-14).
// - phstudy's hidden CX-00 Tiga copies use pseudo ratchet codes 3-61/3-63/3-65
//   (corrected by partMoldOverrides to 3-60, as the box says).
// - BX-24-06's Japanese box name has a small/large kana typo (ウイザード).
// - English names mix Takara Tomy and Hasbro names for the same layer (Hells /
//   Incendio, Brave / Courage), some part names are untranslated, and Korean
//   spellings vary, so en / ko match rates are below 100% by data, not rules.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/bbx/bbx.dart';

const dbPath = String.fromEnvironment('BBX_DB');

void main() {
  final skip = dbPath.isEmpty || !File(dbPath).existsSync() ? 'BBX_DB not given' : null;
  late BbxCatalog cat;
  late StockAudit audit;

  setUpAll(() {
    if (skip != null) return;
    cat = BbxCatalog.fromJson(jsonDecode(File(dbPath).readAsStringSync()) as Map<String, Object?>);
    audit = checkStockSeries(cat);
    // ignore: avoid_print
    print(audit.summary());
    for (final n in audit.notes) {
      // ignore: avoid_print
      print('note: $n');
    }
    for (final f in audit.failures) {
      // ignore: avoid_print
      print('FAIL: $f');
    }
  });

  test('every stock combo is complete, legal and named like its box', () {
    expect(audit.total, cat.series.length);
    expect(audit.combos + audit.partsOnly, audit.total);
    expect(audit.failures, isEmpty);
    expect(audit.passed, audit.combos);
    expect(audit.combos, greaterThan(250));
    for (final arch in Arch.values) {
      expect(audit.byArch[arch] ?? 0, greaterThan(0), reason: '${arch.name} has stock combos');
    }
  }, skip: skip);

  test('parts-only series are single-part products with a reason', () {
    for (final s in cat.series.where((s) => s.kind == SeriesKind.partsOnly)) {
      expect(s.reason, startsWith('parts-only product'), reason: s.id);
      expect(s.partIds.length, lessThanOrEqualTo(2), reason: '${s.id} ${s.names['en']}');
      final slots = {for (final id in s.partIds) cat.variants[id]!.slot};
      expect(slots.containsAll({Slot.ratchet, Slot.bit}), isFalse, reason: s.id);
    }
  }, skip: skip);

  test('flags and molds look right on the full catalogue', () {
    expect(
      cat.moldsFor(Slot.ratchet).where((m) => m.simpleRatchet).map((m) => m.code).toSet(),
      containsAll(['3-85', '4-55', '7-55', '9-65', 'M-85']),
    );
    expect(cat.moldsFor(Slot.ratchet).every((m) => RegExp(r'^[0-9M]-\d\d$').hasMatch(m.code)), isTrue);
    expect(cat.moldsFor(Slot.bit).where((m) => m.integratedBit).map((m) => m.key).toSet(), {'bit:TR', 'bit:OP'});
    expect(cat.moldsFor(Slot.lockChip).where((m) => m.metalLockChip).map((m) => m.key).toSet(), {
      'lock_chip:ワルキューレ',
      'lock_chip:エンペラー',
    });
    expect(cat.moldsFor(Slot.blade).where((m) => m.simpleOnly).map((m) => m.key), ['blade:クロックミラージュ']);
    expect(cat.moldsFor(Slot.blade).where((m) => m.integratedBlade), hasLength(greaterThanOrEqualTo(4)));
    expect(cat.molds.values.where((m) => m.components.isNotEmpty), hasLength(greaterThanOrEqualTo(6)));
    expect(cat.dataIssues, isEmpty);
    // every variant of a selectable mold is in the same slot and the mold is named
    for (final m in cat.molds.values.where((m) => m.selectable)) {
      expect(m.variantIds.every((id) => cat.variants[id]!.slot == m.slot), isTrue, reason: m.key);
      expect(m.name('ja'), isNotEmpty, reason: m.key);
    }
    // ignore: avoid_print
    print([for (final s in Slot.values) '${s.json} ${cat.moldsFor(s).length}'].join(', '));
  }, skip: skip);

  test('every stock combo can be built from its own kit', () {
    for (final s in cat.series.where((s) => s.combo != null)) {
      final inv = BbxInventory(cat, series: {s.id: 1});
      expect(canBuild(s.combo!, inv), isTrue, reason: s.id);
    }
  }, skip: skip);
}
