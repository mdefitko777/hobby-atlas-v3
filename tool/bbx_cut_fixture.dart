// Cuts test/fixtures/bbx-database.sample.json out of Gunpula's real
// data/bbx-database.json: the series below plus every part they reference,
// unchanged, written as compact JSON.
//
//   dart run tool/bbx_cut_fixture.dart <bbx-database.json> [out]
import 'dart:convert';
import 'dart:io';

/// Each series is here for a reason the tests rely on.
const fixtureSeries = {
  'SR-PRD-910381-00': 'BX-01 Sword Dran 3-60F (standard)',
  'SR-EVE-910909-01': 'Sword Dran 3-60F Metallic Coat: Gold (recolour of BX-01)',
  'SR-PRD-912965-01': 'BX-14-01 Keel Shark 3-60LF',
  'SR-PRD-912965-02': 'BX-14-02 Keel Shark 4-80N (same blade mold as -01)',
  'SR-PRD-912965-03': 'BX-14-03 Sword Dran 3-80B',
  'SR-PRD-912965-04': 'BX-14-04 Scythe Incendio 4-80LF',
  'SR-PRD-912965-05': 'BX-14-05 Helm Knight 4-60LF',
  'SR-PRD-912965-06': 'BX-14-06 Arrow Wizard 3-60T',
  'SR-PRD-913108-06': 'BX-24-06 Arrow Wizard 4-80GB (ja box name has a kana typo)',
  'SR-PRD-939542-01': 'UX-10-01 Mail Knight 3-85BS (simple ratchet)',
  'SR-PRD-990154-01': 'UX-16-01 ClockMirage 9-65B (simple-only blade)',
  'SR-PRD-096160-00': 'UX-19 Bullet/Rocket Griffon H (integrated blade, unknown weight)',
  'SR-PRD-930358-00': 'Lightning L-Drago upper type (mode variant)',
  'SR-PRD-930358-01': 'Lightning L-Drago rapid-hit type (same mold)',
  'SR-PRD-939597-00': 'CX-01 DranBrave S6-60V (cx)',
  'SR-PRD-939627-01': 'CX-05-01 HellsReaper T4-70K',
  'SR-PRD-939627-02': 'CX-05-02 RhinoReaper C4-55D',
  'SR-PRD-939627-03': 'CX-05-03 HellsArc T3-85O',
  'SR-PRD-956976-00': 'CX-07 PegasusBlast ATr (integrated bit Turbo)',
  'SR-PRD-098775-01': 'CX-11-01 EmperorMight HOp (metal lock chip + Operate)',
  'SR-PRD-954316-00': 'BXH-14 ValkyrieVolt S4-70V (metal lock chip)',
  'SR-PRD-056225-00': 'BXC-21 KidHunt K4-70TK (no weights on record)',
  'SR-EVE-088899-00': 'BXH-22 RagnaRage FE4-55Y (cx expand)',
  'SR-PRD-097259-00': 'CX-13 BahamutBlitz BK1-50I (cx expand)',
  'SR-PRD-080640-00': 'BXG-70 TigaRage FT3-60T',
  'SR-PRD-080640-00M': 'hidden CX-00 Tiga copy with pseudo ratchet 3-61 (partMoldOverrides)',
  'SR-PRD-089193-01': 'BXG-50-01 bit set (parts-only, placeholder blade)',
  'SR-PRD-953715-00': 'BXH-17 lock chip only (parts-only, dangling ids)',
  'SR-FRB-CR2312-00': 'BXC-01 Feather Phoenix blade only (parts-only)',
};

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('usage: dart run tool/bbx_cut_fixture.dart <bbx-database.json> [out]');
    exitCode = 64;
    return;
  }
  final out = args.length > 1 ? args[1] : 'test/fixtures/bbx-database.sample.json';
  final db = jsonDecode(File(args.first).readAsStringSync()) as Map<String, Object?>;
  final series = <Map<String, Object?>>[
    for (final s in db['series'] as List)
      if (fixtureSeries.containsKey((s as Map)['series_id'])) s.cast<String, Object?>(),
  ];
  final missing = fixtureSeries.keys.where((id) => !series.any((s) => s['series_id'] == id));
  if (missing.isNotEmpty) stderr.writeln('not in source: ${missing.join(', ')}');
  final ids = <String>{
    for (final s in series)
      for (final e in s.entries)
        if (e.key.endsWith('_id') && e.key != 'series_id' && e.key != 'base_set_id' && '${e.value}'.isNotEmpty)
          '${e.value}',
  };
  final parts = <String, List<Object?>>{
    for (final e in (db['parts'] as Map).entries)
      '${e.key}': [
        for (final p in e.value as List)
          if (ids.contains((p as Map)['part_id'])) p,
      ],
  };
  final sets = {for (final s in series) s['base_set_id']};
  final doc = {
    '_note':
        'Cut from Gunpula data/bbx-database.json (updated_at ${db['updated_at']}) by tool/bbx_cut_fixture.dart; records unchanged.',
    'sources': [
      {
        'name': 'beyblade.phstudy.org (via Gunpula data/bbx-database.json)',
        'url': 'https://beyblade.phstudy.org/',
        'licence': 'No licence stated; data mirrored from the official app. Names/stats only, images hotlinked.',
      },
    ],
    'source': db['source'],
    'image_base': db['image_base'],
    'updated_at': db['updated_at'],
    'products': [
      for (final p in db['products'] as List)
        if (sets.contains((p as Map)['base_set_id'])) p,
    ],
    'series': series,
    'parts': parts,
  };
  final text = jsonEncode(doc);
  File(out).writeAsStringSync(text);
  stdout.writeln('${series.length} series, ${ids.length} part ids -> $out (${text.length} bytes)');
}
