// Beyblade X parts model: slots, architectures, variants (one phstudy part_id
// each) grouped into molds (recolours / metal coats / reprints of one shape).
// Pure Dart, no Flutter imports, so it can run in an isolate or a CLI tool.

/// A slot a part goes into. [json] is the key used by bbx-database.json
/// (`parts.<json>[]`, `series[].<json>_id`).
enum Slot {
  blade('blade'),
  ratchet('ratchet'),
  bit('bit'),
  lockChip('lock_chip'),
  mainBlade('main_blade'),
  assistBlade('assist_blade'),
  metalBlade('metal_blade'),
  overBlade('over_blade');

  const Slot(this.json);
  final String json;

  static Slot? fromJson(Object? value) {
    for (final s in values) {
      if (s.json == value || s.name == value) return s;
    }
    return null;
  }
}

/// How a bey is assembled.
/// - [standard]: blade + ratchet + bit (BX / UX)
/// - [integrated]: ratchet-integrated blade + bit (UX-19/20/21, BXG-63/71)
/// - [cx]: lock chip + main blade + assist blade + ratchet + bit
/// - [cxExpand]: lock chip + metal blade + over blade + assist blade + ratchet + bit
///
/// In every architecture an integrated bit (Turbo, Operate) fills the ratchet
/// slot as well, so the ratchet is then left empty.
enum Arch {
  standard([Slot.blade, Slot.ratchet, Slot.bit]),
  integrated([Slot.blade, Slot.bit]),
  cx([Slot.lockChip, Slot.mainBlade, Slot.assistBlade, Slot.ratchet, Slot.bit]),
  cxExpand([Slot.lockChip, Slot.metalBlade, Slot.overBlade, Slot.assistBlade, Slot.ratchet, Slot.bit]);

  const Arch(this.slots);

  /// Slots this architecture uses, top to bottom.
  final List<Slot> slots;

  /// Slots that must be filled; the ratchet is dropped when the bit is an
  /// integrated bit.
  List<Slot> requiredSlots({bool integratedBit = false}) => integratedBit
      ? [
          for (final s in slots)
            if (s != Slot.ratchet) s,
        ]
      : slots;

  static Arch? fromJson(Object? value) {
    for (final a in values) {
      if (a.name == value) return a;
    }
    return null;
  }
}

/// Official phstudy `defaultStatus` numbers of one part (or a sum of parts).
class BbxStats {
  const BbxStats({this.attack = 0, this.defense = 0, this.stamina = 0, this.dash = 0, this.burst = 0});

  final int attack;
  final int defense;
  final int stamina;
  final int dash;
  final int burst;

  static const zero = BbxStats();

  /// Stat names in display order, matching the phstudy keys.
  static const keys = ['attack', 'defense', 'stamina', 'dash', 'burst'];

  int operator [](String key) => switch (key) {
    'attack' => attack,
    'defense' => defense,
    'stamina' => stamina,
    'dash' => dash,
    'burst' => burst,
    _ => 0,
  };

  BbxStats operator +(BbxStats o) => BbxStats(
    attack: attack + o.attack,
    defense: defense + o.defense,
    stamina: stamina + o.stamina,
    dash: dash + o.dash,
    burst: burst + o.burst,
  );

  /// Element-wise maximum (for bar scales).
  BbxStats max(BbxStats o) => BbxStats(
    attack: attack > o.attack ? attack : o.attack,
    defense: defense > o.defense ? defense : o.defense,
    stamina: stamina > o.stamina ? stamina : o.stamina,
    dash: dash > o.dash ? dash : o.dash,
    burst: burst > o.burst ? burst : o.burst,
  );

  static BbxStats fromJson(Object? json) {
    if (json is! Map) return zero;
    int n(String k) => (json[k] is num) ? (json[k] as num).round() : 0;
    return BbxStats(
      attack: n('attack'),
      defense: n('defense'),
      stamina: n('stamina'),
      dash: n('dash'),
      burst: n('burst'),
    );
  }

  Map<String, int> toJson() => {for (final k in keys) k: this[k]};

  @override
  bool operator ==(Object other) => other is BbxStats && keys.every((k) => this[k] == other[k]);

  @override
  int get hashCode => Object.hashAll(keys.map((k) => this[k]));

  @override
  String toString() => 'BbxStats(${keys.map((k) => '$k ${this[k]}').join(', ')})';
}

/// One phstudy part record (one colour / edition of a mold).
class PartVariant {
  const PartVariant({
    required this.id,
    required this.slot,
    required this.moldKey,
    required this.baseSetId,
    required this.names,
    required this.stats,
    this.color = '',
    this.rotation,
    this.height = 0,
    this.weightG,
    this.collectionOrder,
    this.image = '',
    this.imageFallback = '',
  });

  /// phstudy `part_id` (stable; this is what collections and combos store).
  final String id;
  final Slot slot;
  final String moldKey;
  final String baseSetId;

  /// Full display names per language (set code removed, finish kept), e.g.
  /// `{'en': 'Sword Dran Metallic Coat: Gold', ...}`.
  final Map<String, String> names;
  final BbxStats stats;
  final String color;

  /// "right" / "left" for spinning layers, null for ratchets and bits.
  final String? rotation;

  /// phstudy `height` (ratchet height in 0.1 mm, assist blade height).
  final int height;

  /// Weight in grams from phstudy `part_weights.json`; null when unknown.
  /// Unknown is never treated as 0.
  final double? weightG;
  final int? collectionOrder;

  /// Hotlinked image URLs (never rehosted).
  final String image;
  final String imageFallback;
}

/// A mold: every variant that shares one shape. Rules (deck repetition,
/// owned counts) work on molds; stats and weight come from the variant a
/// combo actually uses.
class PartMold {
  PartMold({
    required this.key,
    required this.slot,
    required this.names,
    required this.variantIds,
    required this.representativeId,
    this.stats = BbxStats.zero,
    this.weightG,
    this.line = '',
    this.code = '',
    this.rotation,
    this.simpleRatchet = false,
    this.integratedBlade = false,
    this.integratedBit = false,
    this.simpleOnly = false,
    this.metalLockChip = false,
    this.placeholder = false,
    this.assembled = false,
    this.components = const [],
  });

  /// Stable key `<slot json>:<base name key>`, e.g. `blade:ドランソード`,
  /// `ratchet:3-60`, `bit:F`. Built from the Japanese base name (TT names are
  /// the most consistent across releases), unless the data gives `mold_key`.
  /// phstudy `group_id` is not used: it splits one mold into 3-60 / 3-62 /
  /// 3-64 and merges CX assembled blades with and without their assist blade.
  final String key;
  final Slot slot;

  /// Base names per language (set code and finish removed).
  final Map<String, String> names;

  /// phstudy part_ids of every variant, oldest first.
  final List<String> variantIds;

  /// The variant that stands for the mold when no colour is chosen: the
  /// oldest one with a known weight (else the oldest).
  final String representativeId;

  /// Stats of [representativeId]. Variants can differ (metal coats, modes);
  /// a combo always sums the variants it actually uses.
  final BbxStats stats;

  /// Weight of [representativeId] in grams, null when no variant is weighed.
  final double? weightG;

  /// Product line of the mold's releases: bx / ux / cx (empty for ratchets
  /// and bits, which every line shares).
  final String line;

  /// Short code for letter-coded parts: ratchet "3-60", bit "LF", assist "S",
  /// over blade "F". Empty for named parts.
  final String code;
  final String? rotation;

  /// Ratchet with no burst teeth: 3-85, 4-55, 7-55, 9-65, M-65, M-85 (phstudy
  /// `fixed_burst`). The only ratchets a [simpleOnly] blade accepts.
  final bool simpleRatchet;

  /// Blade with its ratchet moulded in; used in [Arch.integrated] with a bit.
  final bool integratedBlade;

  /// Bit with its ratchet moulded in (Turbo, Operate); fills both slots.
  final bool integratedBit;

  /// Blade that accepts only simple ratchets (ClockMirage).
  final bool simpleOnly;

  /// Metal lock chip (Valkyrie, Emperor): never repeats inside a deck.
  final bool metalLockChip;

  /// Not a real part: phstudy's "Ratchet-Integrated Blade/Bits" filler
  /// ratchets, bit-set box "blades", empty / "■" names. Never selectable.
  final bool placeholder;

  /// A pre-assembled record (the CX "blade" a stock CX kit lists next to its
  /// lock chip, main and assist blade). Its layers are the real parts.
  final bool assembled;

  /// For a CX Expand main-blade record ("F/Rage"): the metal blade and over
  /// blade molds it is made of. Owning it counts as owning both.
  final List<String> components;

  /// True when the mold can be picked for a combo.
  bool get selectable => !placeholder && !assembled && components.isEmpty;

  /// Base name in [lang], falling back to Japanese then English.
  String name(String lang) {
    final n = names[lang];
    if (n != null && n.isNotEmpty) return n;
    return names['ja']?.isNotEmpty == true ? names['ja']! : (names['en'] ?? key);
  }

  @override
  String toString() => 'PartMold($key)';
}
