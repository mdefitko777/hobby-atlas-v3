// 건담 도감 (Atlas) 매핑: 작품 · 기체 · 상품 연결 · 시대 가드 · 옛 손으로 켜기 · 화수 · 박스 아트 · 도감 필터
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/data/derive.dart';
import 'package:hobby_atlas/data/gundam_atlas.dart';
import 'package:hobby_atlas/data/gunpula.dart';
import 'package:hobby_atlas/data/user_store.dart';
import 'package:hobby_atlas/filter_sheet.dart';
import 'package:hobby_atlas/models.dart';

import 'support/atlas_fixture.dart';

GundamAtlas _parse({Set<String> catalog = const {}}) => GundamAtlas.parse(
  fixture('atlas-gundam-ms.sample.json'),
  fixture('atlas-gundam-kit-ms.sample.json'),
  knownKit: (id) => id != 'not-in-catalog' && (catalog.isEmpty || catalog.contains(id)),
  workLogos: const {10: 'assets/gp/works/w10.webp'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GundamAtlas.parse', () {
    final a = _parse();

    test('작품: 시대 순서 → order, 기체 없는 작품은 뺀다', () {
      expect(a.works.map((w) => w.id), ['mobile-suit-gundam', 'v', 'seed', 'seed-destiny', '00', 'build-fighters']);
      expect(a.work('empty-work'), isNull);
      expect(a.work('seed')!.name, '기동전사 건담 SEED');
      expect(a.timeline('CE')!.name, '코즈믹 에라');
    });

    test('작품 안 기체 순서: 그 작품에서 처음 나온 것 → gget 순서 → id', () {
      expect(a.work('seed')!.unitIds, [
        'GAT-X105 Strike Gundam',
        'GAT-X102 Duel Gundam',
        'ZGMF-X10A Freedom Gundam',
        'GAT-X105+AQM/E-X01 Aile Strike Gundam', // works 가 없어 상품의 kit_works 로
        'LCAM-01XA Archangel',
      ]);
      expect(a.work('seed-destiny')!.unitIds, [
        'ZGMF-X42S Destiny Gundam',
        'GAT-X105 Strike Gundam',
        'ZGMF-X10A Freedom Gundam',
        'GAT-01A1+AQM/E-A4E1 Jet Dagger', // 작품 · 상품이 없어 gget 시리즈 번호(3300)로
      ]);
      expect(a.work('build-fighters')!.unitIds, [
        'GAT-X105B/FP Build Strike Gundam Full Package',
        'MS-06F Zaku II',
        'GAT-X102 Duel Gundam',
      ]);
    });

    test('칸이 될 수 없는 MS(그림 · 켜는 상품 둘 다 없음)는 빠진다', () {
      expect(a.units.containsKey('Estard Passenger Jet'), isFalse);
      expect(a.units.containsKey('Launcher Parts Only'), isFalse); // 부품 연결만 있음
      // 카탈로그에 없는 상품은 버리지만 gget 그림이 있으니 칸은 남는다
      expect(a.units['ZGMF-X10A Freedom Gundam']!.kits, isEmpty);
    });

    test('기체 → 상품: 역할 순 · 부품 / SD 는 칸을 켜지 않음 · 옛 이름(redirect)', () {
      final strike = a.units['GAT-X105 Strike Gundam']!;
      expect(strike.kitIds, [
        'hg-strike',
        'mg-strike',
        'set-strike-duel',
        'robot-strike',
        'parts-strike',
        'sd-musha-strike',
      ]);
      expect(strike.litKitIds, ['hg-strike', 'mg-strike', 'set-strike-duel', 'robot-strike']);
      expect(strike.name, '스트라이크 건담');
      expect(strike.sub, 'GAT-X105 · Strike Gundam');
      expect(strike.icon, 'assets/gp/units/g3000u00100.webp');
      expect(a.units['MS-06F Zaku II']!.kitIds, ['hg-zaku']); // "MS-06 Zaku II" → MS-06F
      expect(a.unitsByKit['set-strike-duel'], unorderedEquals(['GAT-X105 Strike Gundam', 'GAT-X102 Duel Gundam']));
      expect(a.unitsByKit.containsKey('parts-strike'), isFalse);
    });

    test('옛 손으로 켜기 (gget unit_id) → 그 id 를 가진 기체', () {
      expect(a.unitByGget[1300000900], 'GAT-X102 Duel Gundam'); // 듀얼의 두 번째 gget id
      expect(a.unitByGget[1300000100], 'GAT-X105 Strike Gundam');
      expect(a.unitsForGget([1300000800, 1300000900, 42]), {'GAT-X102 Duel Gundam'});
      expect(ggetSeriesOf(1304000300), 3040);
    });

    test('작품 로고: atlas-groups → gget 시리즈 번호로 만든 주소 → 없으면 그림 없음', () {
      expect(a.work('mobile-suit-gundam')!.image, 'assets/gp/works/w10.webp');
      expect(a.work('seed')!.image, 'https://img.kusoge.xyz/ggenet/series/logo_l_series_3000.webp');
      expect(a.work('seed')!.imageSource, isNotEmpty);
      expect(a.work('00')!.image, ''); // 공식 로고가 없으면 상품 사진으로 채우지 않는다
      expect(a.timelineImage('UC'), 'assets/gp/works/w10.webp');
    });
  });

  group('시대 가드', () {
    final a = _parse();

    test('SEED 작품에 GN- (00) · V2 (LM314) · 빌드 기체가 들어가지 않는다', () {
      for (final w in a.works.where((w) => w.timeline == 'CE')) {
        for (final id in w.unitIds) {
          expect(id.startsWith('GN'), isFalse, reason: '$id in ${w.id}');
          expect(RegExp(r'^LM[34]').hasMatch(id), isFalse, reason: '$id in ${w.id}');
          expect(a.units[id]!.era, 'CE', reason: '$id in ${w.id}');
        }
      }
      expect(a.units['GN-001 Gundam Exia']!.works, ['00']);
      expect(a.units['LM314V21 Victory Two Gundam']!.works, ['v']); // 마스터에 시대가 없어도 형식번호로
      expect(a.units['LM314V21 Victory Two Gundam']!.era, 'UC');
      expect(a.units['GAT-X105B/FP Build Strike Gundam Full Package']!.works, ['build-fighters']);
    });

    test('시대마다 그 시대 작품에는 그 시대 기체만 (빌드 · SD · 기타 작품은 누구나)', () {
      for (final w in a.works) {
        if (!canonEras.contains(w.timeline)) continue;
        for (final id in w.unitIds) {
          final u = a.units[id]!;
          expect(
            eraAllowed(workEra: w.timeline, unitEra: u.era, modelEra: eraByModel([id])),
            isTrue,
            reason: '$id (${u.era}) in ${w.id} (${w.timeline})',
          );
        }
      }
    });

    test('형식번호 규칙', () {
      expect(eraByModel(['GN-0000']), 'AD');
      expect(eraByModel(['GNX-603T']), 'AD');
      expect(eraByModel(['LM314V21']), 'UC');
      expect(eraByModel(['ZGMF-X10A']), 'CE');
      expect(eraByModel(['GAT-X105']), 'CE');
      expect(eraByModel(['ORB-01']), 'CE');
      expect(eraByModel(['MBF-P02']), 'CE');
      expect(eraByModel(['MBF-P05LM3']), 'CE'); // 가운데 LM3 은 V건담이 아니다
      expect(eraByModel(['XXXG-01W']), 'AC');
      expect(eraByModel(['OZ-00MS']), 'AC');
      expect(eraByModel(['ASW-G-08']), 'PD');
      expect(eraByModel(['XVX-016']), 'AS');
      expect(eraByModel(['MD-0031']), 'AS');
      expect(eraByModel(['RX-78-2']), '');
      expect(eraAllowed(workEra: 'CE', unitEra: '', modelEra: 'AD'), isFalse);
      expect(eraAllowed(workEra: 'BUILD', unitEra: 'AD', modelEra: 'AD'), isTrue);
      expect(eraAllowed(workEra: 'GQ', unitEra: 'UC', modelEra: ''), isTrue);
    });
  });

  group('gundam-chapters.json', () {
    final raw = fixture('atlas-gundam-chapters.sample.json');

    test('장(arcs) 순서 · 화수 범위 · 장이 없으면 기체가 적힌 화', () {
      final c = parseChapters(raw);
      expect(c['seed']!.map((x) => x.episodes), ['1–3화', '5화', '9–10화']);
      expect(c['seed']!.first.name, '그 이름은 건담');
      expect(c['mobile-suit-gundam']!.map((x) => x.episodes), ['1화']); // 기체 없는 2화는 빠짐
    });

    test('withChapters: 칸이 없는 MS(함선 클래스)는 빼고, 빈 장도 뺀다', () {
      final a = _parse().withChapters(parseChapters(raw));
      final seed = a.work('seed')!;
      expect(seed.chapters.map((c) => c.episodes), ['1–3화', '5화']);
      expect(seed.chapters.first.unitIds, ['GAT-X105 Strike Gundam', 'GAT-X102 Duel Gundam']);
    });

    test('기체 종류: unit_types 에 있으면 그 종류, 없으면 MS · MA', () {
      final a = _parse().withUnitTypes(parseUnitTypes(raw));
      expect(a.units['LCAM-01XA Archangel']!.type, '전함');
      expect(a.units['GAT-X105 Strike Gundam']!.type, 'MS · MA');
    });
  });

  group('박스 아트 → 대표 사진', () {
    final out = {
      for (final k in mapKitsJob({
        'raw': File('test/fixtures/kits-gundam-boxart.sample.json').readAsStringSync(),
        'boxart': File('test/fixtures/atlas-gundam-boxart.sample.json').readAsStringSync(),
      }))
        k['id']! as String: k,
    };

    test('상자 그림이 있으면 대표 사진, 원래 사진은 두 번째로 남긴다', () {
      final hg = out['hg-strike']!;
      expect(hg['image'], 'https://bandai-a.akamaihd.net/bc/img/model/b/1000000001_9.jpg');
      expect(hg['gallery'], [
        'https://bandai-a.akamaihd.net/bc/img/model/b/1000000001_9.jpg',
        '${gunpulaBase}app/assets/catalog/gundam/hg-strike.jpg',
        '${gunpulaBase}app/assets/catalog/gundam/hg-strike-2.jpg',
      ]);
    });

    test('가샤폰 대지(dp)도 대표 사진 · 확실하지 않은 것(maybe)은 사진 목록 끝에만 · 죽은 주소는 무시', () {
      expect(out['gsf-strike']!['image'], 'https://bandai-a.akamaihd.net/bc/img/model/b/1000000002_1.jpg');
      expect(out['pg-maybe']!['image'], '${gunpulaBase}app/assets/catalog/gundam/pg.jpg');
      expect(
        (out['pg-maybe']!['gallery']! as List).last,
        'https://bandai-a.akamaihd.net/bc/img/model/b/1000000003_4.jpg',
      );
      expect(out['dead-box']!['image'], '${gunpulaBase}app/assets/catalog/gundam/mg-duel.jpg');
      expect(out['no-art']!['image'], '${gunpulaBase}app/assets/catalog/gundam/rg-zaku.jpg');
    });

    test('박스 아트 파일이 없어도 예전처럼', () {
      final plain = mapKitsJob({'raw': File('test/fixtures/kits-gundam-boxart.sample.json').readAsStringSync()});
      expect(plain.first['image'], '${gunpulaBase}app/assets/catalog/gundam/hg-strike.jpg');
    });

    test('기기 캐시 이름: atlas/… 의 / 는 파일 이름에 넣지 않는다', () {
      expect(auxFiles, containsAll([atlasMsFile, atlasKitMsFile, atlasBoxartFile, atlasChaptersFile]));
      expect(auxFiles, isNot(contains('gget-units.json')));
      expect(mapOnlyAuxFiles, contains(atlasBoxartFile));
    });
  });

  group('도감 계산 (카탈로그 + 내 기록)', () {
    final me = UserStore.instance;
    setUp(() => loadAtlasFixture());
    tearDown(() {
      for (final id in fixtureKits.keys) {
        me.setStatus(id, CollectStatus.none);
      }
      for (final g in [...me.guideManualLit]) {
        me.setManualLit(g, false);
      }
    });

    test('작품 카드: 시대 묶음 · 수집 수 · 필터 재료', () async {
      me.setStatus('hg-strike', CollectStatus.owned);
      me.setStatus('hg-aile', CollectStatus.wanted);
      final works = await deriveGuideWorks();
      final seed = works.firstWhere((w) => w.id == 'seed');
      expect(seed.section, '코즈믹 에라');
      expect(seed.total, 5);
      expect(seed.owned, 1);
      expect(seed.liked, 1);
      expect(seed.grades, containsAll(['HG', 'MG', 'ROBOT魂', 'EX']));
      expect(seed.grades, isNot(contains('SD'))); // SD 캐릭터 연결은 칸을 켜지 않는다
      expect(seed.types, containsAll(['MS · MA', '전함']));
      expect(seed.boughtAt, isNotEmpty);
      expect(seed.keywords, contains('strike gundam'));
      expect(works.firstWhere((w) => w.id == '00').image, '');
    });

    test('기체 칸: 상품으로 켜짐 · 부품만 사면 안 켜짐 · 옛 손으로 켜기(gget id) 그대로', () async {
      me.setStatus('parts-strike', CollectStatus.owned);
      var units = await deriveGuideUnits('seed');
      expect(units.first.status, CollectStatus.none);
      expect(units.first.roleOf('parts-strike'), 'accessory_for');
      me.setStatus('set-strike-duel', CollectStatus.owned);
      units = await deriveGuideUnits('seed');
      expect(units.where((u) => u.status == CollectStatus.owned).map((u) => u.id), [
        'GAT-X105 Strike Gundam',
        'GAT-X102 Duel Gundam',
      ]);
      // 옛 Gunpula 에서 켠 칸: 프리덤의 gget id
      me.setManualLit(1300004200, true);
      units = await deriveGuideUnits('seed-destiny');
      expect(units.firstWhere((u) => u.id == 'ZGMF-X10A Freedom Gundam').status, CollectStatus.owned);
      expect(units.firstWhere((u) => u.id == 'ZGMF-X10A Freedom Gundam').ggetIds, [1300004200]);
    });

    test('화수 묶음 · 시대 카드 · 친구 비교', () async {
      final ch = await deriveGuideChapters('seed');
      expect(ch.map((c) => c.episodes), ['1–3화', '5화']);
      expect(await deriveGuideChapters('00'), isEmpty);
      final worlds = await deriveWorlds('gundam');
      expect(worlds.map((w) => w.id), ['gundam-uc', 'gundam-ce', 'gundam-ad', 'gundam-build']);
      expect(worlds[1].total, 7); // SEED 5 + DESTINY 의 데스티니 · 제트 대거 (스트라이크 · 프리덤은 한 번만)
      expect(worlds[0].image, 'assets/gp/works/w10.webp');
      final friend = await deriveFriendGuide(['set-strike-duel']);
      expect(friend, {'seed': 2, 'seed-destiny': 1, 'build-fighters': 1});
    });

    test('gundam-chapters.json 이 없으면(404) 화수 · 종류만 빠지고 나머지는 그대로', () async {
      loadAtlasFixture(chapters: false);
      expect(await deriveGuideChapters('seed'), isEmpty);
      final units = await deriveGuideUnits('seed');
      expect(units.length, 5);
      expect(units.every((u) => u.type == 'MS · MA'), isTrue);
    });
  });

  group('도감 필터', () {
    const items = [
      GuideFacet(name: '다', tiers: {GuideTier.owned}, grades: {'HG'}, kits: 3, boughtAt: '2026-10-01'),
      GuideFacet(name: '가', tiers: {GuideTier.none}, grades: {'MG', 'HG'}, kits: 1),
      GuideFacet(name: '나', tiers: {GuideTier.liked}, types: {'전함'}, kits: 0, group: 'CE'),
      GuideFacet(name: '라', tiers: {GuideTier.photo, GuideTier.owned}, grades: {'RG'}, kits: 5, boughtAt: '2026-11-01'),
    ];
    List<String> names(GuideFilter f) => [for (final x in f.apply(items, (x) => x)) x.name];

    test('단계 · 등급(여럿) · 종류 · 묶음 · 상품 있는 것만', () {
      expect(names(GuideFilter()), ['다', '가', '나', '라']);
      expect(names(GuideFilter()..tier = GuideTier.owned), ['다', '라']);
      expect(names(GuideFilter()..tier = GuideTier.none), ['가']);
      expect(names(GuideFilter()..grades.addAll(['MG', 'RG'])), ['가', '라']);
      expect(names(GuideFilter()..types.add('전함')), ['나']);
      expect(names(GuideFilter()..groups.add('CE')), ['나']);
      expect(names(GuideFilter()..withKits = true), ['다', '가', '라']);
      expect(
        (GuideFilter()
              ..withKits = true
              ..tier = GuideTier.liked)
            .count,
        2,
      );
    });

    test('정렬: 번호 · 이름 · 상품 수 · 최근 구매', () {
      expect(names(GuideFilter()..sort = GuideSort.name), ['가', '나', '다', '라']);
      expect(names(GuideFilter()..sort = GuideSort.kits), ['라', '다', '가', '나']);
      expect(names(GuideFilter()..sort = GuideSort.recent), ['라', '다', '가', '나']);
      final carried =
          (GuideFilter()
                ..groups.add('CE')
                ..grades.add('HG'))
              .copy(keepGroups: false);
      expect(carried.groups, isEmpty);
      expect(carried.grades, {'HG'});
    });
  });

  test('fixture 는 JSON 으로 읽힌다', () {
    for (final f in Directory('test/fixtures').listSync().whereType<File>().where((f) => f.path.contains('atlas-'))) {
      expect(() => jsonDecode(f.readAsStringSync()), returnsNormally);
    }
  });
}
