// 건담 도감 테스트용: test/fixtures/atlas-*.sample.json 을 카탈로그에 넣는다 (네트워크 없이)
import 'dart:convert';
import 'dart:io';

import 'package:hobby_atlas/data/catalog.dart';
import 'package:hobby_atlas/data/gundam_atlas.dart';

Object? fixture(String name) => jsonDecode(File('test/fixtures/$name').readAsStringSync());

/// 상품 (kit_id → [이름, 등급])
const fixtureKits = {
  'hg-strike': ['HG 스트라이크 건담', 'HG'],
  'mg-strike': ['MG 스트라이크 건담', 'MG'],
  'robot-strike': ['ROBOT魂 스트라이크 건담', 'ROBOT魂'],
  'set-strike-duel': ['HG 스트라이크 & 듀얼 세트', 'HG'],
  'parts-strike': ['스트라이크 확장 파츠', '굿즈'],
  'sd-musha-strike': ['SD 무사 스트라이크', 'SD'],
  'hg-aile': ['HG 에일 스트라이크', 'HG'],
  'hg-destiny': ['HG 데스티니 건담', 'HG'],
  'hg-zaku': ['HG 자쿠II', 'HG'],
  'parts-launcher': ['런처 파츠', '굿즈'],
  'hg-build-strike-fp': ['HG 빌드 스트라이크 풀 패키지', 'HG'],
  'ex-archangel': ['EX 아크엔젤', 'EX'],
};

/// [chapters] = false 면 gundam-chapters.json 이 아직 없는 때 (404)
void loadAtlasFixture({bool chapters = true}) {
  Catalog.instance.debugSet(
    slim: [
      for (final (i, e) in fixtureKits.entries.indexed)
        {
          'id': e.key,
          'franchiseId': 'gundam',
          'name': e.value[0],
          'line': e.value[1],
          'type': '프라모델',
          'date': '2024-${(i % 9 + 1).toString().padLeft(2, '0')}-01',
          'image': 'assets/gp/kits/ar35.jpg',
          'blob': e.value[0].toLowerCase(),
        },
    ],
    aux: {
      atlasMsFile: fixture('atlas-gundam-ms.sample.json'),
      atlasKitMsFile: fixture('atlas-gundam-kit-ms.sample.json'),
      atlasChaptersFile: chapters ? fixture('atlas-gundam-chapters.sample.json') : null,
      'atlas-groups.json': {
        'franchises': {
          'gundam_timeline': [
            {
              'id': 'uc',
              'works': [
                {'work_id': 10, 'image': 'assets/gp/works/w10.webp'},
                {'work_id': 1500, 'image': 'assets/gp/works/w1500.webp'},
              ],
            },
            {
              'id': 'seed',
              'works': [
                {'work_id': 3000, 'image': 'assets/gp/works/w3000.webp'},
              ],
            },
          ],
        },
      },
      'kit-aliases.json': const <String, Object?>{},
      'exchange-rates.json': const <String, Object?>{},
    },
  );
}
