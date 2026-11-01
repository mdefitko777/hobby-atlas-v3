// Gunpula 실제 데이터 모양으로 매핑 · 도감 · 베이블레이드 계산을 확인한다.
// 데이터 폴더(split/ 와 보조 json)가 있을 때만 돈다:
//   flutter test test/real_data_test.dart --dart-define=GUNPULA_DATA=<Gunpula data 폴더>
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/data/catalog.dart';
import 'package:hobby_atlas/data/derive.dart';
import 'package:hobby_atlas/data/gunpula.dart';
import 'package:hobby_atlas/data/user_store.dart';
import 'package:hobby_atlas/models.dart';

const dataDir = String.fromEnvironment('GUNPULA_DATA');

void main() {
  final skip = dataDir.isEmpty || !Directory(dataDir).existsSync() ? 'GUNPULA_DATA 없음' : null;

  setUpAll(() {
    if (skip != null) return;
    String read(String f) => File('$dataDir/$f').readAsStringSync();
    final slim = <Map<String, Object?>>[
      for (final f in franchiseIds)
        ...mapKitsJob({'raw': read('split/kits-$f.json'), 'grades': read('grades.json'), 'firstSeen': read('kit-first-seen.json')}),
    ];
    Catalog.instance.debugSet(
      slim: slim,
      aux: {
        for (final f in auxFiles)
          if (File('$dataDir/$f').existsSync()) f: jsonDecode(read(f)),
      },
    );
  });

  test('상품 매핑: 이름 · 사진 주소 · JAN · 정렬', () {
    final c = Catalog.instance;
    expect(c.kits.length, greaterThan(8000));
    expect(c.kits.where((k) => k.image.isEmpty).length, lessThan(100));
    expect(c.kits.where((k) => k.image.startsWith('./')), isEmpty);
    expect(c.kits.where((k) => k.jan.isNotEmpty).length, greaterThan(3000));
    // 발매일 새것부터, 발매일 없는 것은 끝
    expect(c.kits.last.date, '');
    expect(c.kits.where((k) => k.recent), isNotEmpty);
    final hg = c.byId['hg-hg-1-144-4580886844760000'];
    if (hg != null) {
      expect(hg.line, 'HG');
      expect(hg.type, '프라모델');
      expect(hg.jan, '4580886844760');
      expect(hg.image, startsWith('${gunpulaBase}app/assets/catalog/gundam/'));
    }
    expect(kitMatches(c.kits.firstWhere((k) => k.jan.isNotEmpty), c.kits.firstWhere((k) => k.jan.isNotEmpty).jan), isTrue);
  }, skip: skip);

  test('건담 도감: 작품 묶음 · 기체 · 내 기록으로 점등', () async {
    final works = await deriveGuideWorks();
    expect(works.length, greaterThan(90));
    expect(works.first.section, isNotEmpty);
    final seed = works.firstWhere((w) => w.name.contains('SEED'));
    final units = await deriveGuideUnits(seed.id);
    expect(units, isNotEmpty);
    final withKit = units.firstWhere((u) => u.kitIds.isNotEmpty, orElse: () => units.first);
    if (withKit.kitIds.isNotEmpty) {
      UserStore.instance.setStatus(withKit.kitIds.first, CollectStatus.owned);
      final again = await deriveGuideUnits(seed.id);
      expect(again.firstWhere((u) => u.id == withKit.id).status, CollectStatus.owned);
      UserStore.instance.setStatus(withKit.kitIds.first, CollectStatus.none);
    }
    // ignore: avoid_print
    print('도감 작품 ${works.length}개, ${seed.name} 기체 ${units.length}개 (상품 연결 ${units.where((u) => u.kitIds.isNotEmpty).length})');
  }, skip: skip);

  test('베이블레이드: 상품마다 부품 · 세계관 줄', () async {
    final tops = await deriveBbxTops();
    expect(tops.length, greaterThan(150));
    expect(tops.where((t) => t.parts.isNotEmpty).length, greaterThan(100));
    final lines = await deriveWorlds('beyblade');
    expect(lines.map((w) => w.label), contains('BX 라인'));
    // ignore: avoid_print
    print('BBX ${tops.length}개, 부품 있는 것 ${tops.where((t) => t.parts.isNotEmpty).length}, 줄 ${lines.map((w) => w.label).join(',')}');
  }, skip: skip);

  test('세계관 · 공식 예고 · 알림', () async {
    expect(await deriveWorlds('gundam'), isNotEmpty);
    expect(await deriveWorlds('pokemon'), isNotEmpty);
    final anns = await deriveAnnouncements(['gundam', 'pokemon', 'fate', 'beyblade', 'armored_core']);
    expect(anns, isNotEmpty);
    expect(anns.first.title, isNotEmpty);
    expect(anns.where((a) => a.hero).length, lessThanOrEqualTo(6));
    expect(await deriveNotifications(), isNotEmpty);
  }, skip: skip);
}
