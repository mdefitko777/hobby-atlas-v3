// Checks every phstudy series in a bbx-database.json with the BBX rules engine
// and prints a summary (same checks as test/bbx_real_db_test.dart).
//
//   dart run tool/bbx_check.dart <path to Gunpula data/bbx-database.json> [-v]
import 'dart:convert';
import 'dart:io';

import 'package:hobby_atlas/bbx/bbx.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('usage: dart run tool/bbx_check.dart <bbx-database.json> [-v]');
    exitCode = 64;
    return;
  }
  final verbose = args.contains('-v');
  final catalog = BbxCatalog.fromJson(jsonDecode(File(args.first).readAsStringSync()) as Map<String, Object?>);
  final report = checkStockSeries(catalog);
  stdout.writeln(report.summary());
  if (verbose) {
    for (final line in report.details) {
      stdout.writeln(line);
    }
  }
  if (args.contains('--molds')) {
    for (final slot in Slot.values) {
      final all = catalog.moldsFor(slot, selectableOnly: false);
      final pick = all.where((m) => m.selectable).toList();
      stdout.writeln(
        '${slot.json}: ${catalog.variants.values.where((v) => v.slot == slot).length} variants, '
        '${all.length} molds, ${pick.length} selectable',
      );
    }
    String list(bool Function(PartMold m) f) => catalog.molds.values.where(f).map((m) => m.key).join(', ');
    stdout.writeln('simpleRatchet: ${list((m) => m.simpleRatchet)}');
    stdout.writeln('simpleOnly: ${list((m) => m.simpleOnly)}');
    stdout.writeln('integratedBlade: ${list((m) => m.integratedBlade)}');
    stdout.writeln('integratedBit: ${list((m) => m.integratedBit)}');
    stdout.writeln('metalLockChip: ${list((m) => m.metalLockChip)}');
    stdout.writeln('assembled: ${list((m) => m.assembled)}');
    stdout.writeln('placeholder: ${list((m) => m.placeholder)}');
    stdout.writeln(
      'composite: ${catalog.molds.values.where((m) => m.components.isNotEmpty).map((m) => '${m.key}=${m.components.join('+')}').join(', ')}',
    );
    stdout.writeln('combo stat max: ${catalog.comboStatMax}');
    for (final slot in Slot.values) {
      stdout.writeln('  ${slot.json} max: ${catalog.slotStatMax[slot]}');
    }
    for (final slot in [Slot.blade, Slot.lockChip, Slot.mainBlade, Slot.metalBlade]) {
      stdout.writeln(
        '${slot.json} molds: ${catalog.moldsFor(slot).map((m) => '${m.name('ja')}/${m.name('en')}(${m.variantIds.length})').join(' | ')}',
      );
    }
  }
  for (final line in report.notes) {
    stdout.writeln('NOTE $line');
  }
  for (final line in catalog.dataIssues) {
    stdout.writeln('DATA $line');
  }
  for (final line in report.failures) {
    stdout.writeln('FAIL $line');
  }
  exitCode = report.failures.isEmpty ? 0 : 1;
}
