// Saved combos, decks and owned part instances (local-first records). The
// shape follows research §4 "Data model"; the bey shape and the deck idea come
// from solarisken/beyblade-x-tournament-lab core.js (MIT, see rules.dart).

import 'parts.dart';

/// Where a combo came from.
enum ComboSource { custom, stock, meta }

/// One bey. [parts] maps each filled slot to a phstudy part_id (any variant
/// stands for its mold) or, when no colour was chosen, to a mold key.
class Combo {
  Combo({
    required this.id,
    required this.arch,
    required Map<Slot, String> parts,
    this.nickname,
    this.favorite = false,
    this.rating = 0,
    this.tags = const [],
    this.notes = '',
    this.source = ComboSource.custom,
    this.seriesId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : parts = Map.unmodifiable(parts),
       createdAt = createdAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
       updatedAt = updatedAt ?? createdAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  final String id;
  final Arch arch;
  final Map<Slot, String> parts;
  final String? nickname;
  final bool favorite;

  /// 0 (unrated) to 5.
  final int rating;
  final List<String> tags;
  final String notes;
  final ComboSource source;

  /// phstudy series id for [ComboSource.stock].
  final String? seriesId;
  final DateTime createdAt;
  final DateTime updatedAt;

  String? operator [](Slot slot) => parts[slot];

  Combo copyWith({
    Arch? arch,
    Map<Slot, String>? parts,
    String? nickname,
    bool? favorite,
    int? rating,
    List<String>? tags,
    String? notes,
    DateTime? updatedAt,
  }) => Combo(
    id: id,
    arch: arch ?? this.arch,
    parts: parts ?? this.parts,
    nickname: nickname ?? this.nickname,
    favorite: favorite ?? this.favorite,
    rating: rating ?? this.rating,
    tags: tags ?? this.tags,
    notes: notes ?? this.notes,
    source: source,
    seriesId: seriesId,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// Same arch and the same filled slots (ignores nickname etc.).
  String get signature =>
      '${arch.name}:${[for (final s in Slot.values)
        if (parts[s] != null) '${s.json}=${parts[s]}'].join('|')}';

  Map<String, Object?> toJson() => {
    'id': id,
    'arch': arch.name,
    'parts': {for (final e in parts.entries) e.key.json: e.value},
    if (nickname != null) 'nickname': nickname,
    if (favorite) 'favorite': true,
    if (rating != 0) 'rating': rating,
    if (tags.isNotEmpty) 'tags': tags,
    if (notes.isNotEmpty) 'notes': notes,
    'source': source.name,
    if (seriesId != null) 'series_id': seriesId,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  static Combo? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final arch = Arch.fromJson(json['arch']);
    if (id is! String || arch == null) return null;
    final raw = json['parts'];
    final parts = <Slot, String>{};
    if (raw is Map) {
      for (final e in raw.entries) {
        final slot = Slot.fromJson(e.key);
        if (slot != null && e.value is String && (e.value as String).isNotEmpty) parts[slot] = e.value as String;
      }
    }
    final source = ComboSource.values.where((s) => s.name == json['source']).firstOrNull ?? ComboSource.custom;
    return Combo(
      id: id,
      arch: arch,
      parts: parts,
      nickname: json['nickname'] is String ? json['nickname'] as String : null,
      favorite: json['favorite'] == true,
      rating: json['rating'] is int ? (json['rating'] as int).clamp(0, 5) : 0,
      tags: [if (json['tags'] is List) ...(json['tags'] as List).whereType<String>()],
      notes: json['notes'] is String ? json['notes'] as String : '',
      source: source,
      seriesId: json['series_id'] is String ? json['series_id'] as String : null,
      createdAt: DateTime.tryParse('${json['created_at']}'),
      updatedAt: DateTime.tryParse('${json['updated_at']}'),
    );
  }

  @override
  String toString() => 'Combo($id, $signature)';
}

/// A 3on3 deck: an ordered list of saved combo ids plus the rules profile id
/// it is checked against (see `RulesProfile`).
class Deck {
  const Deck({required this.id, required this.name, required this.comboIds, this.rulesProfile = 'tt'});

  final String id;
  final String name;
  final String rulesProfile;
  final List<String> comboIds;

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'rules_profile': rulesProfile, 'combo_ids': comboIds};

  static Deck? fromJson(Object? json) {
    if (json is! Map || json['id'] is! String) return null;
    return Deck(
      id: json['id'] as String,
      name: json['name'] is String ? json['name'] as String : '',
      rulesProfile: json['rules_profile'] is String ? json['rules_profile'] as String : 'tt',
      comboIds: [if (json['combo_ids'] is List) ...(json['combo_ids'] as List).whereType<String>()],
    );
  }
}

/// State of one physical part in the collection.
enum OwnStatus { owned, shipping, wish }

/// One physical part (or a wish for one). [variantId] is the phstudy part_id;
/// [fromSeriesId] records that it came with a whole kit.
class OwnedPart {
  const OwnedPart({
    required this.instanceId,
    required this.variantId,
    this.status = OwnStatus.owned,
    this.fromSeriesId,
    this.note = '',
  });

  final String instanceId;
  final String variantId;
  final OwnStatus status;
  final String? fromSeriesId;
  final String note;

  Map<String, Object?> toJson() => {
    'instance_id': instanceId,
    'variant_id': variantId,
    'status': status.name,
    if (fromSeriesId != null) 'from_series_id': fromSeriesId,
    if (note.isNotEmpty) 'note': note,
  };

  static OwnedPart? fromJson(Object? json) {
    if (json is! Map || json['instance_id'] is! String || json['variant_id'] is! String) return null;
    return OwnedPart(
      instanceId: json['instance_id'] as String,
      variantId: json['variant_id'] as String,
      status: OwnStatus.values.where((s) => s.name == json['status']).firstOrNull ?? OwnStatus.owned,
      fromSeriesId: json['from_series_id'] is String ? json['from_series_id'] as String : null,
      note: json['note'] is String ? json['note'] as String : '',
    );
  }
}
