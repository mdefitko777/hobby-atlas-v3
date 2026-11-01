// Data QA: run the rules engine over every phstudy series (stock combo) and
// compare the generated box name with the name printed on the box.
// Used by test/bbx_real_db_test.dart and tool/bbx_check.dart.

import 'catalog.dart';
import 'names.dart';
import 'parts.dart';
import 'rules.dart';

/// How well a generated box name matches the printed one.
enum NameMatch { none, loose, exact }

/// Compares the generated box name with the series name (set code, finish,
/// spacing and case ignored; [NameMatch.loose] also ignores small / large
/// kana). For English either chip / main order is accepted.
NameMatch boxNameMatch(StockSeries series, BbxCatalog catalog, String lang) {
  final combo = series.combo;
  if (combo == null) return NameMatch.none;
  final printed = baseName(series.names[lang] ?? '', lang);
  if (printed.isEmpty) return NameMatch.none;
  final generated = [
    boxName(combo, catalog, lang: lang),
    if (lang == 'en') boxName(combo, catalog, lang: lang, mainFirst: true),
  ];
  if (generated.any((g) => nameKey(g) == nameKey(printed))) return NameMatch.exact;
  if (generated.any((g) => looseNameKey(g) == looseNameKey(printed))) return NameMatch.loose;
  return NameMatch.none;
}

bool boxNameMatches(StockSeries series, BbxCatalog catalog, String lang) =>
    boxNameMatch(series, catalog, lang) != NameMatch.none;

class StockAudit {
  StockAudit({required this.total, required this.combos, required this.partsOnly});

  final int total;
  final int combos;
  final int partsOnly;
  int legal = 0;
  int namedJa = 0;
  final Map<String, int> namedByLang = {for (final l in bbxLangs) l: 0};
  final Map<Arch, int> byArch = {};
  final List<String> failures = [];

  /// Passing combos that rely on a documented data quirk.
  final List<String> notes = [];
  final List<String> details = [];

  int get passed => combos - failures.length;

  String summary() {
    final arch = byArch.entries.map((e) => '${e.key.name} ${e.value}').join(', ');
    final names = namedByLang.entries.map((e) => '${e.key} ${e.value}/$combos').join(', ');
    return 'series $total = stock combos $combos + parts-only $partsOnly; '
        'combos passing (complete + legal + ja box name) $passed/$combos; '
        'legal $legal/$combos; box name match $names; arch: $arch';
  }
}

/// Checks every series: each stock combo must be complete, free of rule
/// errors and named like its box (Japanese, the Takara Tomy original).
StockAudit checkStockSeries(BbxCatalog catalog) {
  final combos = catalog.series.where((s) => s.combo != null).toList();
  final audit = StockAudit(
    total: catalog.series.length,
    combos: combos.length,
    partsOnly: catalog.series.length - combos.length,
  );
  for (final s in catalog.series) {
    final c = s.combo;
    if (c == null) {
      audit.details.add(
        'parts-only ${s.id} "${s.names['en']}": ${s.reason}${s.dataIssues.isEmpty ? '' : ' [data: ${s.dataIssues.join('; ')}]'}',
      );
      continue;
    }
    audit.byArch[c.arch] = (audit.byArch[c.arch] ?? 0) + 1;
    for (final id in c.parts.values) {
      final fixed = partMoldOverrides[id];
      if (fixed != null) {
        audit.notes.add('${s.id}: part $id "${catalog.variants[id]?.names['en']}" read as $fixed (partMoldOverrides)');
      }
    }
    final reasons = <String>[];
    if (!isCompleteBey(c, catalog)) reasons.add('incomplete');
    final errors = comboIssues(c, catalog).where((i) => i.isError).toList();
    if (errors.isEmpty && reasons.isEmpty) audit.legal++;
    reasons.addAll(errors.map((e) => e.message));
    for (final l in bbxLangs) {
      if (boxNameMatches(s, catalog, l)) audit.namedByLang[l] = audit.namedByLang[l]! + 1;
    }
    final ja = boxNameMatch(s, catalog, 'ja');
    if (ja != NameMatch.none) {
      audit.namedJa++;
      if (ja == NameMatch.loose) {
        audit.notes.add(
          '${s.id}: printed ja name "${s.names['ja']}" has a kana typo; generated "${boxName(c, catalog)}"',
        );
      }
    } else {
      reasons.add('box name "${boxName(c, catalog)}" vs "${baseName(s.names['ja'] ?? '', 'ja')}"');
    }
    final line =
        '${s.id} ${c.arch.name} "${s.names['ja']}" -> ${boxName(c, catalog)} / ${boxName(c, catalog, lang: 'en')}';
    if (reasons.isEmpty) {
      audit.details.add('ok $line');
    } else {
      audit.failures.add('$line: ${reasons.join('; ')}');
    }
    for (final l in ['en', 'ko', 'zh']) {
      if (!boxNameMatches(s, catalog, l)) {
        audit.details.add('  name-$l ${s.id}: "${boxName(c, catalog, lang: l)}" vs "${baseName(s.names[l] ?? '', l)}"');
      }
    }
  }
  return audit;
}
