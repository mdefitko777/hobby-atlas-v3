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
import 'package:hobby_atlas/notifications/feed_rules.dart';
import 'package:hobby_atlas/notifications/notify_models.dart';

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
    // 친구 도감 비교: 친구가 그 상품을 샀으면 그 작품에 1칸 이상
    if (withKit.kitIds.isNotEmpty) {
      final friend = await deriveFriendGuide([withKit.kitIds.first]);
      expect(friend[seed.id], greaterThanOrEqualTo(1));
    }
    expect(await deriveFriendGuide(const []), isEmpty);
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
  }, skip: skip);

  test('알림: 실제 update-feed-lite 30일 → 기본 규칙 · 처음 실행', () {
    final entries = parseFeed(jsonDecode(File('$dataDir/update-feed-lite.json').readAsStringSync()));
    expect(entries.length, greaterThan(10));
    final plan = planCheck(
      config: NotifyConfig(channels: const ['gundam', 'beyblade', 'pokemon']),
      state: NotifyState(),
      entries: entries,
      manifestSig: 'x',
      now: DateTime.parse('${entries.first.date}T12:00:00'),
    );
    expect(plan.records, isNotEmpty);
    expect(plan.records.every((r) => r.seen), isTrue);
    // 알림함 줄 → 화면: 카탈로그에 있는 상품이면 사진이 붙는다
    final notices = [for (final r in plan.records) noticeOf(r, Catalog.instance.byId[r.kitId])];
    expect(notices.where((n) => n.image.isNotEmpty).length, greaterThan(notices.length ~/ 2));
    // ignore: avoid_print
    print('알림 첫 실행 ${plan.records.length}줄 (${entries.first.date} 기준 7일): '
        '${plan.records.map((r) => r.franchise).toSet().join(',')}');
  }, skip: skip);

  // Gunpula 의 새 소식 파일(scripts/atlas/build_notify_feed.mjs)이 있는 데이터 폴더에서만 (Gunpula 브랜치 atlas/notify-feed)
  final atlasFile = File('$dataDir/atlas/notify-feed.json');
  test('알림: 새 소식 파일 ⊇ lite 피드 (알릴 만한 상품) · manifest 와 같은 판', () {
    final atlas = parseFeed(jsonDecode(atlasFile.readAsStringSync()));
    final lite = parseFeed(jsonDecode(File('$dataDir/update-feed-lite.json').readAsStringSync()));
    final manifest = jsonDecode(File('$dataDir/split/manifest.json').readAsStringSync());
    expect(feedMatches(atlas, manifest), isTrue);
    final atlasIds = {
      for (final e in atlas)
        for (final i in e.items) '${e.date}|${i.kitId}',
    };
    final liteIds = {
      for (final e in lite)
        if (e.date.compareTo(atlas.last.date) >= 0)
          for (final i in e.items)
            if (i.meaningful) '${e.date}|${i.kitId}',
    };
    expect(liteIds.difference(atlasIds), isEmpty);
    expect(atlas.expand((e) => e.items).every((i) => i.meaningful), isTrue); // 사진만 바뀐 것은 이미 빠져 있다
    // ignore: avoid_print
    print('새 소식 파일 ${atlas.length}일 ${atlasIds.length}개 · 같은 기간 lite ${liteIds.length}개');
  }, skip: skip ?? (atlasFile.existsSync() ? null : 'atlas/notify-feed.json 없음'));
}
