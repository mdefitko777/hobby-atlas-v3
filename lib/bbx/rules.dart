// Beyblade X build rules: completeness, part compatibility, 3on3 deck checks,
// owned-quantity checks, box-style names and stat / weight sums.
//
// Ported to Dart from solarisken/beyblade-x-tournament-lab core.js
// (isCompleteBey, getBeyPartIds, canSupplyPartIds, canBuildBey,
// canBuildTogether, validateDeck, beyName, aggregateStats, rules profiles) and
// extended with the phstudy data model (molds, variants), integrated bits,
// simple-ratchet-only blades, CX Expand and lock-chip profiles
// (research.md §4 "Rules to implement").
//
// Original licence of the ported code:
//
// MIT License
//
// Copyright (c) 2026 X Command Center contributors
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import 'catalog.dart';
import 'combo.dart';
import 'names.dart';
import 'parts.dart';

// ─── issues ─────────────────────────────────────────────────────────────────

enum Severity { error, warning }

/// Machine-readable reason; the UI maps it to localised text.
enum IssueCode {
  // one bey
  unknownPart,
  wrongSlot,
  notAPart,
  compositeMainBlade,
  extraSlot,
  missingSlot,
  integratedBladeNeedsIntegratedArch,
  notAnIntegratedBlade,
  integratedBitOnIntegratedBlade,
  ratchetWithIntegratedBit,
  simpleOnlyNeedsSimpleRatchet,
  simpleOnlyWithIntegratedBit,
  // deck
  deckSize,
  unknownCombo,
  beyIncomplete,
  beyIllegal,
  notEnoughParts,
  repeatedMold,
}

class RuleIssue {
  const RuleIssue(
    this.code,
    this.message, {
    this.severity = Severity.error,
    this.slot,
    this.moldKey,
    this.beys = const [],
  });

  final IssueCode code;
  final Severity severity;
  final String message;
  final Slot? slot;
  final String? moldKey;

  /// 0-based positions of the beys in a deck this issue is about.
  final List<int> beys;

  bool get isError => severity == Severity.error;

  @override
  String toString() => '${severity.name}:${code.name}: $message';
}

// ─── one bey ────────────────────────────────────────────────────────────────

/// Molds of the filled slots that resolve to a pickable part of that slot.
Map<Slot, PartMold> resolvedMolds(Combo combo, BbxCatalog catalog) {
  final out = <Slot, PartMold>{};
  for (final e in combo.parts.entries) {
    final mold = catalog.moldOf(e.value);
    if (mold != null && mold.slot == e.key && mold.selectable) out[e.key] = mold;
  }
  return out;
}

/// Slots [combo] must fill (the ratchet is dropped for an integrated bit).
List<Slot> requiredSlotsOf(Combo combo, BbxCatalog catalog) {
  final bit = catalog.moldOf(combo.parts[Slot.bit] ?? '');
  return combo.arch.requiredSlots(integratedBit: bit != null && bit.slot == Slot.bit && bit.integratedBit);
}

/// Every required slot is filled with a real part of that slot
/// (core.js `isCompleteBey`). Says nothing about compatibility.
bool isCompleteBey(Combo combo, BbxCatalog catalog) {
  final molds = resolvedMolds(combo, catalog);
  return requiredSlotsOf(combo, catalog).every(molds.containsKey);
}

/// Everything wrong with one bey: unknown / misplaced parts, missing slots and
/// part-compatibility rules. Warnings flag combinations the sources do not
/// settle.
List<RuleIssue> comboIssues(Combo combo, BbxCatalog catalog) {
  final issues = <RuleIssue>[];
  final arch = combo.arch;
  final molds = <Slot, PartMold>{};
  for (final e in combo.parts.entries) {
    final slot = e.key;
    if (!arch.slots.contains(slot)) {
      issues.add(
        RuleIssue(
          IssueCode.extraSlot,
          arch == Arch.integrated && slot == Slot.ratchet
              ? 'An integrated blade has its own ratchet; remove the ratchet.'
              : 'A ${arch.name} bey has no ${slot.json} slot.',
          slot: slot,
        ),
      );
      continue;
    }
    final mold = catalog.moldOf(e.value);
    if (mold == null) {
      issues.add(RuleIssue(IssueCode.unknownPart, 'Unknown part ${e.value}.', slot: slot));
    } else if (mold.slot != slot) {
      issues.add(
        RuleIssue(
          IssueCode.wrongSlot,
          '${mold.name('en')} is a ${mold.slot.json}, not a ${slot.json}.',
          slot: slot,
          moldKey: mold.key,
        ),
      );
    } else if (mold.components.isNotEmpty) {
      issues.add(
        RuleIssue(
          IssueCode.compositeMainBlade,
          '${mold.name('en')} is a metal blade + over blade; build it as cxExpand.',
          slot: slot,
          moldKey: mold.key,
        ),
      );
    } else if (!mold.selectable) {
      issues.add(
        RuleIssue(IssueCode.notAPart, '${e.value} is a placeholder record, not a part.', slot: slot, moldKey: mold.key),
      );
    } else {
      molds[slot] = mold;
    }
  }

  final bit = molds[Slot.bit];
  final integratedBit = bit?.integratedBit ?? false;
  for (final slot in arch.requiredSlots(integratedBit: integratedBit)) {
    if (!combo.parts.containsKey(slot)) {
      issues.add(RuleIssue(IssueCode.missingSlot, 'Missing ${slot.json}.', slot: slot));
    }
  }
  if (integratedBit && combo.parts.containsKey(Slot.ratchet) && arch.slots.contains(Slot.ratchet)) {
    issues.add(
      RuleIssue(
        IssueCode.ratchetWithIntegratedBit,
        '${bit!.name('en')} has its ratchet built in; remove the ratchet.',
        slot: Slot.ratchet,
        moldKey: bit.key,
      ),
    );
  }

  final blade = molds[Slot.blade];
  if (blade != null) {
    if (arch == Arch.standard && blade.integratedBlade) {
      issues.add(
        RuleIssue(
          IssueCode.integratedBladeNeedsIntegratedArch,
          '${blade.name('en')} has its ratchet built in; build it as integrated (blade + bit).',
          slot: Slot.blade,
          moldKey: blade.key,
        ),
      );
    }
    if (arch == Arch.integrated && !blade.integratedBlade) {
      issues.add(
        RuleIssue(
          IssueCode.notAnIntegratedBlade,
          '${blade.name('en')} needs a ratchet; build it as standard.',
          slot: Slot.blade,
          moldKey: blade.key,
        ),
      );
    }
    if (blade.integratedBlade && integratedBit) {
      issues.add(
        RuleIssue(
          IssueCode.integratedBitOnIntegratedBlade,
          'An integrated bit (${bit!.name('en')}) cannot go on an integrated blade (${blade.name('en')}).',
          slot: Slot.bit,
          moldKey: bit.key,
        ),
      );
    }
    if (blade.simpleOnly) {
      final ratchet = molds[Slot.ratchet];
      if (ratchet != null && !ratchet.simpleRatchet) {
        issues.add(
          RuleIssue(
            IssueCode.simpleOnlyNeedsSimpleRatchet,
            '${blade.name('en')} takes only simple ratchets (${simpleRatchetCodes.join(', ')}), not ${ratchet.code}.',
            slot: Slot.ratchet,
            moldKey: ratchet.key,
          ),
        );
      }
      if (integratedBit) {
        issues.add(
          RuleIssue(
            IssueCode.simpleOnlyWithIntegratedBit,
            '${blade.name('en')} with an integrated bit is not covered by the sources; check the current regulation.',
            severity: Severity.warning,
            slot: Slot.bit,
            moldKey: bit!.key,
          ),
        );
      }
    }
  }
  return issues;
}

/// Complete and free of rule errors (warnings allowed).
bool isLegalBey(Combo combo, BbxCatalog catalog) => !comboIssues(combo, catalog).any((i) => i.isError);

// ─── box names ──────────────────────────────────────────────────────────────

/// Box-style name in [lang] (ja / ko / zh / en), e.g. ja "ドランソード3-60F",
/// "ドランブレイブS 6-60V", "ラグナレイジFE 4-55Y"; en "Sword Dran 3-60F".
///
/// Pattern (research §4): standard `{Blade} {ratchet}{bit}`, CX
/// `{Chip}{Main} {Assist}{ratchet}{bit}`, Expand
/// `{Chip}{Metal} {Over}{Assist}{ratchet}{bit}`; spacing follows each
/// language's boxes. English CX boxes are not consistent about chip / main
/// order ("Courage Dran" vs "Phoenix Flare"); [mainFirst] picks the Hasbro
/// order. Empty slots are skipped, so a half-built combo still gets a name.
String boxName(Combo combo, BbxCatalog catalog, {String lang = 'ja', bool mainFirst = false}) {
  if (!bbxLangs.contains(lang)) lang = 'en';
  String piece(Slot slot) {
    final mold = catalog.moldOf(combo.parts[slot] ?? '');
    if (mold == null || mold.slot != slot) return '';
    return mold.code.isNotEmpty ? mold.code : mold.name(lang);
  }

  final tail = '${piece(Slot.ratchet)}${piece(Slot.bit)}';
  final bitIsIntegrated = catalog.moldOf(combo.parts[Slot.bit] ?? '')?.integratedBit ?? false;
  String join(List<String> parts) => parts.where((p) => p.isNotEmpty).join(' ');
  final glued = lang == 'ja' || lang == 'zh';
  switch (combo.arch) {
    case Arch.standard:
    case Arch.integrated:
      final blade = piece(Slot.blade);
      return lang == 'ja' ? '$blade$tail' : join([blade, tail]);
    case Arch.cx:
    case Arch.cxExpand:
      final chip = piece(Slot.lockChip);
      final top = combo.arch == Arch.cx ? piece(Slot.mainBlade) : piece(Slot.metalBlade);
      final letters = '${combo.arch == Arch.cxExpand ? piece(Slot.overBlade) : ''}${piece(Slot.assistBlade)}';
      final head = glued ? '$chip$top' : join(mainFirst ? [top, chip] : [chip, top]);
      return switch (lang) {
        'ja' => bitIsIntegrated ? '$head$letters$tail' : join(['$head$letters', tail]),
        'ko' => join([head, '$letters$tail']),
        'zh' => join([head, '$letters$tail']),
        _ => join([head, letters, tail]),
      };
  }
}

// ─── stats ──────────────────────────────────────────────────────────────────

class ComboStats {
  const ComboStats({
    required this.stats,
    required this.knownWeightG,
    required this.unknownWeightSlots,
    required this.complete,
    this.spin,
  });

  /// Sum of phstudy `defaultStatus` over the filled slots.
  final BbxStats stats;

  /// Sum of the weights that are known.
  final double knownWeightG;

  /// Filled slots whose part has no weight on record.
  final List<Slot> unknownWeightSlots;

  /// Every required slot is filled.
  final bool complete;

  /// "right" / "left" from the top layer.
  final String? spin;

  /// Total weight, or null when any slot is empty or has no weight. An
  /// unknown weight is never counted as 0.
  double? get weightG => complete && unknownWeightSlots.isEmpty ? double.parse(knownWeightG.toStringAsFixed(1)) : null;
}

/// Stats and weight of the variants [combo] uses.
ComboStats comboStats(Combo combo, BbxCatalog catalog) {
  var stats = BbxStats.zero;
  var known = 0.0;
  final unknown = <Slot>[];
  String? spin;
  for (final slot in combo.arch.slots) {
    final id = combo.parts[slot];
    if (id == null) continue;
    final v = catalog.variantFor(id);
    if (v == null || v.slot != slot) {
      unknown.add(slot);
      continue;
    }
    stats = stats + v.stats;
    if (v.weightG == null) {
      unknown.add(slot);
    } else {
      known += v.weightG!;
    }
    if (spin == null && (slot == Slot.blade || slot == Slot.mainBlade || slot == Slot.metalBlade)) spin = v.rotation;
  }
  return ComboStats(
    stats: stats,
    knownWeightG: known,
    unknownWeightSlots: unknown,
    complete: isCompleteBey(combo, catalog),
    spin: spin,
  );
}

// ─── owned quantities ───────────────────────────────────────────────────────

/// Owned quantities per mold. Built from part counts and/or whole-kit counts
/// (core.js `getInventoryCounts`: looseParts + ownedProducts). A CX Expand
/// "X/Name" main-blade record counts as its metal blade + over blade;
/// placeholder and pre-assembled records count as nothing.
class BbxInventory {
  BbxInventory(this.catalog, {Map<String, int> parts = const {}, Map<String, int> series = const {}}) {
    for (final e in parts.entries) {
      _add(e.key, e.value);
    }
    for (final e in series.entries) {
      final s = catalog.seriesById[e.key];
      if (s == null) {
        unknownIds.add(e.key);
        continue;
      }
      for (final id in s.partIds) {
        _add(id, e.value);
      }
    }
  }

  /// Counts the [include] statuses of [owned] (owned only by default; pass
  /// shipping too for "+coming" views).
  factory BbxInventory.fromOwnedParts(
    BbxCatalog catalog,
    Iterable<OwnedPart> owned, {
    Set<OwnStatus> include = const {OwnStatus.owned},
  }) {
    final counts = <String, int>{};
    for (final p in owned) {
      if (include.contains(p.status)) counts[p.variantId] = (counts[p.variantId] ?? 0) + 1;
    }
    return BbxInventory(catalog, parts: counts);
  }

  final BbxCatalog catalog;
  final Map<String, int> _molds = {};
  final Map<String, int> _variants = {};

  /// Part or series ids that are not in the catalogue (ignored).
  final List<String> unknownIds = [];

  void _add(String partId, int qty) {
    if (qty <= 0) return;
    final v = catalog.variants[partId];
    final mold = v == null ? null : catalog.molds[v.moldKey];
    if (mold == null) {
      unknownIds.add(partId);
      return;
    }
    _variants[partId] = (_variants[partId] ?? 0) + qty;
    if (mold.components.isNotEmpty) {
      for (final key in mold.components) {
        _molds[key] = (_molds[key] ?? 0) + qty;
      }
    } else if (mold.selectable) {
      _molds[mold.key] = (_molds[mold.key] ?? 0) + qty;
    }
  }

  /// How many of a mold are owned (all colours together). Accepts a mold key
  /// or any of its part_ids.
  int ownedCount(String moldKeyOrPartId) {
    final mold = catalog.moldOf(moldKeyOrPartId);
    return mold == null ? 0 : (_molds[mold.key] ?? 0);
  }

  /// How many of one exact variant (part_id) are owned.
  int variantCount(String partId) => _variants[partId] ?? 0;

  Map<String, int> get moldCounts => Map.unmodifiable(_molds);
}

/// A mold the collection is short of.
class MissingPart {
  const MissingPart({required this.slot, required this.moldKey, required this.need, required this.have});
  final Slot slot;
  final String moldKey;
  final int need;
  final int have;
  int get short => need - have;

  @override
  String toString() => 'MissingPart($moldKey need $need have $have)';
}

/// Molds needed by [combos] built at the same time, with the count of each.
Map<String, int> moldNeeds(Iterable<Combo> combos, BbxCatalog catalog) {
  final need = <String, int>{};
  for (final c in combos) {
    final molds = resolvedMolds(c, catalog);
    for (final slot in requiredSlotsOf(c, catalog)) {
      final m = molds[slot];
      if (m != null) need[m.key] = (need[m.key] ?? 0) + 1;
    }
  }
  return need;
}

/// What the collection lacks to build all [combos] at once (core.js
/// `canSupplyPartIds`, at mold level so any colour will do).
List<MissingPart> shortfall(Iterable<Combo> combos, BbxInventory inventory) {
  final out = <MissingPart>[];
  for (final e in moldNeeds(combos, inventory.catalog).entries) {
    final have = inventory.ownedCount(e.key);
    if (have < e.value) {
      out.add(MissingPart(slot: inventory.catalog.molds[e.key]!.slot, moldKey: e.key, need: e.value, have: have));
    }
  }
  return out;
}

/// Parts missing for one combo.
List<MissingPart> missingFor(Combo combo, BbxInventory inventory) => shortfall([combo], inventory);

/// Complete and every part owned (core.js `canBuildBey`).
bool canBuild(Combo combo, BbxInventory inventory) =>
    isCompleteBey(combo, inventory.catalog) && missingFor(combo, inventory).isEmpty;

/// All complete and the owned quantities cover every bey at the same time
/// (core.js `canBuildTogether`).
bool canBuildTogether(Iterable<Combo> combos, BbxInventory inventory) =>
    combos.every((c) => isCompleteBey(c, inventory.catalog)) && shortfall(combos, inventory).isEmpty;

// ─── decks ──────────────────────────────────────────────────────────────────

/// Whether a lock chip may appear in more than one bey of a deck.
enum LockChipRepeat {
  /// Any lock chip may repeat.
  any,

  /// Plastic lock chips may repeat; metal ones (Valkyrie, Emperor) may not.
  plainOnly,

  /// Lock chips count like every other part: no repeats.
  none,
}

/// A deck rule set (core.js `profiles`).
class RulesProfile {
  const RulesProfile({
    required this.id,
    required this.name,
    this.deckSize = 3,
    this.noDuplicateMolds = true,
    this.lockChips = LockChipRepeat.plainOnly,
    this.note = '',
  });

  final String id;
  final String name;
  final int deckSize;

  /// No mold may appear in two beys; recolours count as the same mold.
  final bool noDuplicateMolds;
  final LockChipRepeat lockChips;
  final String note;

  /// Free play: three beys you can build at once, repeats allowed.
  static const free = RulesProfile(
    id: 'free',
    name: 'Free play',
    noDuplicateMolds: false,
    lockChips: LockChipRepeat.any,
    note: 'core.js "lab" profile.',
  );

  /// Takara Tomy 3on3: no repeated molds; plain lock chips may repeat.
  static const tt = RulesProfile(
    id: 'tt',
    name: 'Takara Tomy 3on3',
    note:
        'core.js "tt-v12" (basicLockRepeats) + Beydex "unique" metal lock chips. The TT regulation PDF is image-only and was not checked.',
  );

  /// WBO 3on3: no repeated molds, lock chips included.
  static const wbo = RulesProfile(
    id: 'wbo',
    name: 'WBO 3on3',
    lockChips: LockChipRepeat.none,
    note:
        'Sources disagree on lock chips (core.js lets plain ones repeat); this profile is the strict reading. worldbeyblade.org was not reachable to confirm.',
  );

  static const all = [free, tt, wbo];

  /// Profile by id; unknown ids fall back to [tt].
  static RulesProfile byId(String? id) => all.where((p) => p.id == id).firstOrNull ?? tt;
}

class DeckReport {
  const DeckReport(this.issues);
  final List<RuleIssue> issues;
  bool get legal => !issues.any((i) => i.isError);
  List<RuleIssue> get errors => [
    for (final i in issues)
      if (i.isError) i,
  ];
  List<RuleIssue> get warnings => [
    for (final i in issues)
      if (!i.isError) i,
  ];
}

/// Checks a deck (core.js `validateDeck`): size, every bey complete and legal,
/// mold repetition under [profile], and — when [inventory] is given — that the
/// owned quantities cover all beys at once.
DeckReport validateDeck(
  List<Combo> beys,
  BbxCatalog catalog, {
  RulesProfile profile = RulesProfile.tt,
  BbxInventory? inventory,
}) {
  final issues = <RuleIssue>[];
  if (beys.length != profile.deckSize) {
    issues.add(RuleIssue(IssueCode.deckSize, 'A deck must contain ${profile.deckSize} beys (has ${beys.length}).'));
  }
  for (var i = 0; i < beys.length; i++) {
    if (!isCompleteBey(beys[i], catalog)) {
      issues.add(RuleIssue(IssueCode.beyIncomplete, 'Bey ${i + 1} is incomplete.', beys: [i]));
    }
    for (final issue in comboIssues(beys[i], catalog)) {
      if (issue.code == IssueCode.missingSlot) continue; // covered by beyIncomplete
      issues.add(
        RuleIssue(
          issue.isError ? IssueCode.beyIllegal : issue.code,
          'Bey ${i + 1}: ${issue.message}',
          severity: issue.severity,
          slot: issue.slot,
          moldKey: issue.moldKey,
          beys: [i],
        ),
      );
    }
  }
  if (inventory != null && beys.every((b) => isCompleteBey(b, catalog))) {
    final short = shortfall(beys, inventory);
    for (final m in short) {
      issues.add(
        RuleIssue(
          IssueCode.notEnoughParts,
          'Owned quantities cannot build all beys at once: ${catalog.molds[m.moldKey]!.name('en')} needs ${m.need}, owned ${m.have}.',
          slot: m.slot,
          moldKey: m.moldKey,
        ),
      );
    }
  }
  if (profile.noDuplicateMolds) {
    final seen = <String, int>{};
    final reported = <String>{};
    for (var i = 0; i < beys.length; i++) {
      final molds = resolvedMolds(beys[i], catalog);
      for (final slot in requiredSlotsOf(beys[i], catalog)) {
        final m = molds[slot];
        if (m == null) continue;
        if (slot == Slot.lockChip) {
          if (profile.lockChips == LockChipRepeat.any) continue;
          if (profile.lockChips == LockChipRepeat.plainOnly && !m.metalLockChip) continue;
        }
        final first = seen[m.key];
        if (first == null) {
          seen[m.key] = i;
        } else if (first != i && reported.add('${m.key}@$i')) {
          issues.add(
            RuleIssue(
              IssueCode.repeatedMold,
              '${m.name('en')} repeats in bey ${first + 1} and bey ${i + 1}.',
              slot: slot,
              moldKey: m.key,
              beys: [first, i],
            ),
          );
        }
      }
    }
  }
  return DeckReport(issues);
}

/// [validateDeck] for a saved [Deck], resolving its combo ids.
DeckReport validateDeckRecord(Deck deck, Map<String, Combo> combosById, BbxCatalog catalog, {BbxInventory? inventory}) {
  final beys = <Combo>[];
  final missing = <RuleIssue>[];
  for (final id in deck.comboIds) {
    final c = combosById[id];
    if (c == null) {
      missing.add(RuleIssue(IssueCode.unknownCombo, 'Combo $id no longer exists.'));
    } else {
      beys.add(c);
    }
  }
  final report = validateDeck(beys, catalog, profile: RulesProfile.byId(deck.rulesProfile), inventory: inventory);
  return DeckReport([...missing, ...report.issues]);
}
