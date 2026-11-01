// Builds molds, flags and stock combos from Gunpula's data/bbx-database.json
// (mirrored from beyblade.phstudy.org by scripts/import_bbx_database.mjs).
//
// bbx-database.json has no phstudy group_id / fixed_burst / mode flags, so the
// loader derives them:
// - mold key: from the Japanese base name (set code and finish removed); a
//   `mold_key` field in the data wins if a future importer emits one.
// - placeholders: phstudy's "Ratchet-Integrated Blade" / "Ratchet-Integrated
//   Bits" filler ratchets, bit-set box "blades", empty or "■" names.
// - integrated blade / bit: molds that a stock series pairs with those fillers.
// - CX "blade" records listed next to a lock chip are pre-assembled copies;
//   CX Expand "X/Name" main blades are metal blade + over blade.
// - simple ratchets, ClockMirage and metal lock chips from fixed lists (with
//   `fixed_burst`, weight >= 3 g as data-driven backups).

import 'combo.dart';
import 'names.dart';
import 'parts.dart';

/// Ratchets without burst teeth (go-shoot `simple`, phstudy `fixed_burst`).
const simpleRatchetCodes = {'3-85', '4-55', '7-55', '9-65', 'M-65', 'M-85'};

/// Blades that accept only simple ratchets (ClockMirage; go-shoot `simple`).
const simpleOnlyBladeKeys = {'blade:クロックミラージュ'};

/// Metal lock chips (Beydex `unique`). Any lock chip weighing 3 g or more is
/// treated as metal too (plastic chips weigh 1.7 g in phstudy).
const metalLockChipKeys = {'lock_chip:ワルキューレ', 'lock_chip:エンペラー'};

/// Bits with an integrated ratchet (Turbo, Operate), as a backup to the
/// placeholder-ratchet detection.
const integratedBitKeys = {'bit:TR', 'bit:OP'};

/// Known data corrections: part_id -> mold key. Keep this short and explain
/// every entry.
///
/// phstudy's hidden CX-00 copies of BXG-70 Tiga Rage FT 3-60T (series
/// SR-PRD-080640-00M / -00RM / -00RRM, `collection_visible` false in every
/// locale) give their ratchet the pseudo codes 3-61 / 3-63 / 3-65 (phstudy
/// group ids that keep the copies apart). The box and the part description say
/// 3-60, and no 3-61 / 3-63 / 3-65 ratchet exists.
const partMoldOverrides = {
  'RC-PRD-080640-00M': 'ratchet:3-60',
  'RC-PRD-080640-00RM': 'ratchet:3-60',
  'RC-PRD-080640-00RRM': 'ratchet:3-60',
};

const _metalChipMinWeightG = 3.0;
final _ratchetCode = RegExp(r'^[0-9M]-\d\d$');

/// Whether a phstudy series is a full bey or a parts-only product.
enum SeriesKind { combo, partsOnly }

/// One phstudy series (stock combo or single-part product).
class StockSeries {
  const StockSeries({
    required this.id,
    required this.baseSetId,
    required this.names,
    required this.tags,
    required this.kind,
    required this.partIds,
    this.combo,
    this.reason = '',
    this.dataIssues = const [],
  });

  final String id;
  final String baseSetId;

  /// Names per language, set code kept (as printed on the box), width folded.
  final Map<String, String> names;
  final List<String> tags;
  final SeriesKind kind;

  /// The stock combo (null for [SeriesKind.partsOnly]).
  final Combo? combo;

  /// Real parts in the box (what "I own this kit" adds to the collection).
  final List<String> partIds;

  /// Why the series is parts-only (empty for combos).
  final String reason;

  /// Problems in the source data (dangling ids, untranslated names, ...).
  final List<String> dataIssues;
}

/// Where the data came from, for the attribution page.
class BbxSource {
  const BbxSource({required this.name, required this.url, required this.licence});
  final String name;
  final String url;
  final String licence;

  Map<String, String> toJson() => {'name': name, 'url': url, 'licence': licence};
}

const defaultBbxSources = [
  BbxSource(
    name: 'beyblade.phstudy.org (via Gunpula data/bbx-database.json)',
    url: 'https://beyblade.phstudy.org/',
    licence:
        'No licence stated; data mirrored from the official app. Personal use, names/stats only, images hotlinked.',
  ),
  BbxSource(
    name: 'solarisken/beyblade-x-tournament-lab core.js (rules engine ported to Dart)',
    url: 'https://github.com/solarisken/beyblade-x-tournament-lab',
    licence: 'MIT, Copyright (c) 2026 X Command Center contributors',
  ),
];

class BbxCatalog {
  BbxCatalog._({
    required this.variants,
    required this.molds,
    required this.series,
    required this.updatedAt,
    required this.sources,
    required this.dataIssues,
  }) : seriesById = {for (final s in series) s.id: s} {
    _computeRanges();
  }

  /// Every part record by phstudy part_id.
  final Map<String, PartVariant> variants;

  /// Every mold by key.
  final Map<String, PartMold> molds;

  /// Every phstudy series in data order.
  final List<StockSeries> series;
  final Map<String, StockSeries> seriesById;
  final String updatedAt;
  final List<BbxSource> sources;

  /// Catalogue-level data problems found while loading.
  final List<String> dataIssues;

  /// Highest single-part stat per slot (selectable parts), for bar scales.
  late final Map<Slot, BbxStats> slotStatMax;

  /// Highest stock-combo stat total, the phstudy "Series" stat range.
  late final BbxStats comboStatMax;

  /// The mold of a part_id, or the mold itself when given a mold key.
  PartMold? moldOf(String partIdOrMoldKey) {
    final v = variants[partIdOrMoldKey];
    return v != null ? molds[v.moldKey] : molds[partIdOrMoldKey];
  }

  /// The variant for a part_id, or the representative variant (oldest with a
  /// known weight) when given a mold key.
  PartVariant? variantFor(String partIdOrMoldKey) {
    final v = variants[partIdOrMoldKey];
    if (v != null) return v;
    final mold = molds[partIdOrMoldKey];
    return mold == null ? null : variants[mold.representativeId];
  }

  /// Molds of [slot], oldest first; only pickable ones by default.
  List<PartMold> moldsFor(Slot slot, {bool selectableOnly = true}) => [
    for (final m in molds.values)
      if (m.slot == slot && (!selectableOnly || m.selectable)) m,
  ];

  List<Combo> get stockCombos => [
    for (final s in series)
      if (s.combo != null) s.combo!,
  ];

  void _computeRanges() {
    final slotMax = <Slot, BbxStats>{};
    for (final v in variants.values) {
      final mold = molds[v.moldKey];
      if (mold == null || !mold.selectable) continue;
      slotMax[v.slot] = (slotMax[v.slot] ?? BbxStats.zero).max(v.stats);
    }
    slotStatMax = slotMax;
    var comboMax = BbxStats.zero;
    for (final c in stockCombos) {
      var sum = BbxStats.zero;
      for (final id in c.parts.values) {
        sum = sum + (variants[id]?.stats ?? BbxStats.zero);
      }
      comboMax = comboMax.max(sum);
    }
    comboStatMax = comboMax;
  }

  /// Builds the catalogue from decoded bbx-database.json.
  factory BbxCatalog.fromJson(Map<String, Object?> json) => _Loader(json).build();
}

// ─── loader ─────────────────────────────────────────────────────────────────

Map<String, Object?> _map(Object? v) => v is Map ? v.cast<String, Object?>() : const {};
List<Object?> _list(Object? v) => v is List ? v : const [];
String _str(Object? v) => v is String ? v : (v == null ? '' : '$v');

class _Raw {
  _Raw(this.slot, this.json);
  final Slot slot;
  final Map<String, Object?> json;
  late final String id = _str(json['part_id']);
  late final Map<String, String> fullNames = {
    for (final l in bbxLangs) l: stripSetPrefix(foldWidth(_str(_map(json['names'])[l]))),
  };
  late final Map<String, String> bases = {for (final l in bbxLangs) l: partBaseName(_str(_map(json['names'])[l]), l)};
  double? get weight => json['weight_g'] is num ? (json['weight_g'] as num).toDouble() : null;
  int? get order => json['collection_order'] is num ? (json['collection_order'] as num).toInt() : null;
  String? get rotation {
    final r = _map(json['stats'])['rotation'];
    return r == 'right' || r == 'left' ? r as String : null;
  }

  bool get emptyName {
    final b = bases['ja']!.isNotEmpty ? bases['ja']! : bases['en']!;
    return b.isEmpty || b == '■';
  }

  // Checked on the full names: base-name clean-up would cut "Blade" / "ブレード".
  bool get integratedBladeFiller =>
      slot == Slot.ratchet && (fullNames['en']!.contains('Integrated Blade') || fullNames['ja']!.contains('一体型ブレード'));
  bool get integratedBitFiller =>
      slot == Slot.ratchet && (fullNames['en']!.contains('Integrated Bit') || fullNames['ja']!.contains('一体型ビット'));
  bool get bitSetBox =>
      slot == Slot.blade &&
      (bases['ja']!.contains('ビットセット') ||
          bases['ja']!.contains('ビット4種セット') ||
          RegExp(r'Bit Set', caseSensitive: false).hasMatch(bases['en']!));
  bool get placeholder =>
      emptyName ||
      bitSetBox ||
      (slot == Slot.ratchet && !_ratchetCode.hasMatch(bases['en']!) && !_ratchetCode.hasMatch(bases['ja']!));

  late final String moldKey = () {
    final explicit = _str(json['mold_key']);
    if (explicit.isNotEmpty) return explicit.contains(':') ? explicit : '${slot.json}:$explicit';
    final fixed = partMoldOverrides[id];
    if (fixed != null) return fixed;
    if (placeholder) return '${slot.json}:#$id';
    final base = bases['ja']!.isNotEmpty ? bases['ja']! : bases['en']!;
    return '${slot.json}:${nameKey(base)}';
  }();
}

class _Loader {
  _Loader(this.json);
  final Map<String, Object?> json;
  final issues = <String>[];

  BbxCatalog build() {
    final raws = <String, _Raw>{};
    final partsJson = _map(json['parts']);
    for (final slot in Slot.values) {
      for (final p in _list(partsJson[slot.json])) {
        final r = _Raw(slot, _map(p));
        if (r.id.isEmpty) continue;
        if (raws.containsKey(r.id)) issues.add('duplicate part_id ${r.id}');
        raws[r.id] = r;
      }
    }

    // Series references, and what they tell us about molds.
    final seriesJson = [for (final s in _list(json['series'])) _map(s)];
    final integratedBladeMolds = <String>{};
    final integratedBitMolds = <String>{};
    final assembledIds = <String>{};
    final compositeOf = <String, List<String>>{}; // main-blade mold -> [metal, over]
    final tagsByMold = <String, Map<String, int>>{};
    _Raw? ref(Map<String, Object?> s, Slot slot) => raws[_str(s['${slot.json}_id'])];
    for (final s in seriesJson) {
      final blade = ref(s, Slot.blade), ratchet = ref(s, Slot.ratchet), bit = ref(s, Slot.bit);
      final main = ref(s, Slot.mainBlade);
      final metal = ref(s, Slot.metalBlade), over = ref(s, Slot.overBlade);
      if (ratchet != null && ratchet.integratedBladeFiller && blade != null) integratedBladeMolds.add(blade.moldKey);
      if (ratchet != null && ratchet.integratedBitFiller && bit != null) integratedBitMolds.add(bit.moldKey);
      if (blade != null && _str(s['lock_chip_id']).isNotEmpty) assembledIds.add(blade.id);
      if (main != null && metal != null && over != null) {
        final c = [metal.moldKey, over.moldKey];
        final prev = compositeOf[main.moldKey];
        if (prev != null && (prev[0] != c[0] || prev[1] != c[1])) {
          issues.add('main blade ${main.moldKey} is made of $prev in one series and $c in ${_str(s['series_id'])}');
        }
        compositeOf[main.moldKey] = c;
      }
      final lineTags = [
        for (final t in _list(s['tags']))
          if (t == 'bx' || t == 'ux' || t == 'cx') t as String,
      ];
      for (final slot in Slot.values) {
        final r = ref(s, slot);
        if (r == null) continue;
        final m = tagsByMold[r.moldKey] ??= {};
        for (final t in lineTags) {
          m[t] = (m[t] ?? 0) + 1;
        }
      }
    }

    // Variants.
    final variants = <String, PartVariant>{};
    for (final r in raws.values) {
      variants[r.id] = PartVariant(
        id: r.id,
        slot: r.slot,
        moldKey: r.moldKey,
        baseSetId: _str(r.json['base_set_id']),
        names: r.fullNames,
        stats: BbxStats.fromJson(r.json['stats']),
        color: _str(r.json['color']),
        rotation: r.rotation,
        height: _map(r.json['stats'])['height'] is num ? (_map(r.json['stats'])['height'] as num).round() : 0,
        weightG: r.weight,
        collectionOrder: r.order,
        image: _str(r.json['image_remote']).isNotEmpty ? _str(r.json['image_remote']) : _str(r.json['image']),
        imageFallback: _str(r.json['image_fallback']),
      );
    }

    // Molds.
    final byMold = <String, List<_Raw>>{};
    for (final r in raws.values) {
      (byMold[r.moldKey] ??= []).add(r);
    }
    final molds = <String, PartMold>{};
    for (final e in byMold.entries) {
      final list = e.value
        ..sort((a, b) {
          final c = (a.order ?? 1 << 30).compareTo(b.order ?? 1 << 30);
          return c != 0 ? c : a.id.compareTo(b.id);
        });
      final first = list.first;
      final slot = first.slot;
      final names = <String, String>{};
      for (final l in bbxLangs) {
        final counts = <String, int>{};
        for (final r in list) {
          final n = r.bases[l]!;
          if (n.isEmpty || (l == 'en' && hasCjk(n))) continue;
          counts[n] = (counts[n] ?? 0) + 1;
        }
        // Most common base name; ties go to the oldest release (insertion order).
        String? best;
        for (final c in counts.entries) {
          if (best == null || c.value > counts[best]!) best = c.key;
        }
        names[l] = best ?? first.bases[l]!;
      }
      final assembledCount = list.where((r) => assembledIds.contains(r.id)).length;
      if (assembledCount > 0 && assembledCount < list.length) {
        issues.add('mold ${e.key} mixes pre-assembled CX blade records with plain blades');
      }
      final tags = tagsByMold[e.key] ?? const {};
      var line = '';
      if (slot != Slot.ratchet && slot != Slot.bit) {
        var best = 0;
        for (final t in tags.entries) {
          if (t.value > best) (line, best) = (t.key, t.value);
        }
        if (line.isEmpty) {
          final prefix =
              RegExp(r'^[A-Z]+').firstMatch(first.json['base_set_id'] as String? ?? '')?.group(0)?.toLowerCase() ?? '';
          if (const {'bx', 'ux', 'cx'}.contains(prefix)) line = prefix;
        }
      }
      final coded = slot == Slot.ratchet || slot == Slot.bit || slot == Slot.assistBlade || slot == Slot.overBlade;
      final code = coded ? (names['en']!.isNotEmpty ? names['en']! : names['ja']!) : '';
      final rotation = list.map((r) => r.rotation).whereType<String>().firstOrNull;
      final rep = list.where((r) => r.weight != null).firstOrNull ?? first;
      molds[e.key] = PartMold(
        key: e.key,
        slot: slot,
        names: names,
        variantIds: [for (final r in list) r.id],
        representativeId: rep.id,
        stats: BbxStats.fromJson(rep.json['stats']),
        weightG: rep.weight,
        line: line,
        code: code,
        rotation: rotation,
        simpleRatchet:
            slot == Slot.ratchet &&
            (simpleRatchetCodes.contains(code) || list.any((r) => r.json['fixed_burst'] == true)),
        integratedBlade: slot == Slot.blade && integratedBladeMolds.contains(e.key),
        integratedBit: slot == Slot.bit && (integratedBitMolds.contains(e.key) || integratedBitKeys.contains(e.key)),
        simpleOnly:
            slot == Slot.blade &&
            (simpleOnlyBladeKeys.contains(e.key) || list.any((r) => r.json['simple_only'] == true)),
        metalLockChip:
            slot == Slot.lockChip &&
            (metalLockChipKeys.contains(e.key) || list.any((r) => (r.weight ?? 0) >= _metalChipMinWeightG)),
        placeholder: first.placeholder,
        assembled: slot == Slot.blade && assembledCount > 0,
        components: slot == Slot.mainBlade ? (compositeOf[e.key] ?? const []) : const [],
      );
    }

    // Series -> stock combos.
    final series = <StockSeries>[];
    for (final s in seriesJson) {
      series.add(_series(s, raws, molds));
    }

    return BbxCatalog._(
      variants: variants,
      molds: molds,
      series: series,
      updatedAt: _str(json['updated_at']),
      sources: _sources(),
      dataIssues: issues,
    );
  }

  List<BbxSource> _sources() {
    final raw = _list(json['sources']);
    if (raw.isEmpty) return defaultBbxSources;
    return [
      for (final s in raw)
        BbxSource(
          name: _str(_map(s)['name']),
          url: _str(_map(s)['url']),
          licence: _str(_map(s)['licence'] ?? _map(s)['license']),
        ),
    ];
  }

  StockSeries _series(Map<String, Object?> s, Map<String, _Raw> raws, Map<String, PartMold> molds) {
    final id = _str(s['series_id']);
    final dataIssues = <String>[];
    final found = <Slot, _Raw>{};
    for (final slot in Slot.values) {
      final pid = _str(s['${slot.json}_id']);
      if (pid.isEmpty) continue;
      final r = raws[pid];
      if (r == null) {
        dataIssues.add('${slot.json}_id $pid is not in parts');
      } else if (r.slot != slot) {
        dataIssues.add('${slot.json}_id $pid is a ${r.slot.json}');
      } else {
        found[slot] = r;
      }
    }
    bool real(Slot slot) {
      final r = found[slot];
      if (r == null) return false;
      final m = molds[r.moldKey]!;
      return !m.placeholder;
    }

    final names = {for (final l in bbxLangs) l: foldWidth(_str(_map(s['names'])[l]))};
    for (final e in found.entries) {
      final en = e.value.bases['en']!;
      if (!molds[e.value.moldKey]!.placeholder && hasCjk(en)) {
        dataIssues.add('${e.key.json} ${e.value.id} has an untranslated en name "$en"');
      }
    }

    // Pick the architecture from the layers present.
    Arch? arch;
    if (real(Slot.lockChip) && real(Slot.metalBlade) && real(Slot.overBlade)) {
      arch = Arch.cxExpand;
    } else if (real(Slot.lockChip) && real(Slot.mainBlade)) {
      arch = Arch.cx;
    } else if (real(Slot.blade) && molds[found[Slot.blade]!.moldKey]!.integratedBlade) {
      arch = Arch.integrated;
    } else if (real(Slot.blade)) {
      arch = Arch.standard;
    }
    final parts = <Slot, String>{};
    if (arch != null) {
      for (final slot in arch.slots) {
        if (real(slot)) parts[slot] = found[slot]!.id;
      }
    }
    final hasBit = parts.containsKey(Slot.bit);
    final ratchetOk =
        parts.containsKey(Slot.ratchet) ||
        (hasBit && molds[found[Slot.bit]!.moldKey]!.integratedBit) ||
        arch == Arch.integrated;
    if (arch != null && hasBit && ratchetOk) {
      return StockSeries(
        id: id,
        baseSetId: _str(s['base_set_id']),
        names: names,
        tags: [for (final t in _list(s['tags'])) '$t'],
        kind: SeriesKind.combo,
        partIds: [
          for (final slot in arch.slots)
            if (parts[slot] != null) parts[slot]!,
        ],
        combo: Combo(id: 'stock:$id', arch: arch, parts: parts, source: ComboSource.stock, seriesId: id),
        dataIssues: dataIssues,
      );
    }
    // Parts-only product (blade alone, bit set, lock chip, assist blade...).
    final realParts = [
      for (final slot in Slot.values)
        if (real(slot) && !molds[found[slot]!.moldKey]!.assembled && molds[found[slot]!.moldKey]!.components.isEmpty)
          found[slot]!,
    ];
    final what = realParts.isEmpty ? 'no resolvable part' : realParts.map((r) => r.slot.json).join(' + ');
    return StockSeries(
      id: id,
      baseSetId: _str(s['base_set_id']),
      names: names,
      tags: [for (final t in _list(s['tags'])) '$t'],
      kind: SeriesKind.partsOnly,
      partIds: [for (final r in realParts) r.id],
      reason: 'parts-only product: $what',
      dataIssues: dataIssues,
    );
  }
}
