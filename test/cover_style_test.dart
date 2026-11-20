// 분류 칸 그림의 모양 · 바탕색 (Gunpula atlas-groups.json kind · bg · fg / cover_kind · cover_bg · cover_fg, 2026-11-20 계약)
// 과 흰 바탕 시험 스위치(PAGE_WHITE)가 꺼져 있으면 전과 같은 색인지
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/channels.dart';
import 'package:hobby_atlas/data/catalog.dart';
import 'package:hobby_atlas/data/derive.dart';
import 'package:hobby_atlas/models.dart';
import 'package:hobby_atlas/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('CoverStyle.parse: logo · key_visual · picture, #rrggbb, fg 가 없으면 바탕 밝기로', () {
    expect(CoverStyle.parse(), isNull, reason: '옛 데이터');
    final logo = CoverStyle.parse(kind: 'logo', bg: '#70bbe9', fg: 'dark')!;
    expect([logo.logo, logo.bg, logo.lightFg], [true, 0xFF70BBE9, false]);
    expect(CoverStyle.parse(kind: 'key_visual')!.logo, isFalse);
    expect(CoverStyle.parse(kind: 'picture', bg: '#000000', fg: 'light')!.lightFg, isTrue);
    expect(CoverStyle.parse(bg: '#030000')!.lightFg, isTrue, reason: 'fg 가 빠졌으면 짙은 바탕 = 흰 글자');
    expect(CoverStyle.parse(bg: '#ffffff')!.lightFg, isFalse);
    expect(parseHexColor('#ffe101'), 0xFFFFE101);
    expect(parseHexColor('ffe101'), 0xFFFFE101);
    for (final bad in [null, '', '#fff', 'red', '#gggggg', 12]) {
      expect(parseHexColor(bad), isNull, reason: '$bad');
    }
  });

  test('atlas-groups.json: line_covers · channels · franchises 의 모양 · 바탕색 (빠진 칸 · 옛 글자 모양도 받는다)', () async {
    addTearDown(Catalog.instance.debugForget);
    addTearDown(lineCovers.clear);
    addTearDown(lineCoverStyles.clear);
    addTearDown(channelCovers.clear);
    addTearDown(channelCoverStyles.clear);
    Catalog.instance.debugSet(
      // 상품 하나 — 카탈로그가 받은 것으로 보게 (비었으면 세대 묶음을 만들 때 받으러 간다)
      slim: const [
        {'id': 'p1', 'franchiseId': 'pokemon', 'name': 'p1'},
      ],
      aux: {
        'atlas-groups.json': {
          'channels': {
            'pokemon': {
              'image': './assets/atlas/covers/channel-pokemon.png',
              'cover_kind': 'logo',
              'cover_bg': '#fcf3cf',
              'cover_fg': 'dark',
            },
            'gundam': {'image': './assets/atlas/covers/channel-gundam.png', 'cover_kind': 'picture'},
          },
          'line_covers': {
            'beyblade': {
              'BX': {
                'image': './assets/atlas/covers/line-beyblade-bx.png',
                'kind': 'logo',
                'bg': '#70bbe9',
                'fg': 'dark',
              },
              'UX': './assets/atlas/covers/line-beyblade-ux.png', // 옛 글자 모양
            },
          },
          'franchises': {
            'pokemon': [
              {
                'id': 'gen1',
                'labels': {'ko': '1세대'},
                'image': './assets/atlas/covers/pokemon-gen1.webp',
                'cover_kind': 'picture',
                'cover_bg': '#958a75',
                'cover_fg': 'dark',
                'kit_ids': ['p1'],
              },
              {
                'id': 'gen2',
                'labels': {'ko': '2세대'},
                'image': './assets/atlas/covers/pokemon-gen2.png',
                'kit_ids': ['p2'],
              },
            ],
          },
        },
      },
    );
    await pumpEventQueue();
    expect(lineCovers['beyblade']!.keys, containsAll(['BX', 'UX']));
    final bx = lineCoverStyles['beyblade']!['BX']!;
    expect([bx.logo, bx.bg, bx.lightFg], [true, 0xFF70BBE9, false]);
    expect(lineCoverStyles['beyblade'], isNot(contains('UX')));

    final pokemon = channelOf('pokemon');
    expect(pokemon.image, endsWith('channel-pokemon.png'));
    expect([pokemon.cover?.logo, pokemon.cover?.bg], [true, 0xFFFCF3CF]);
    expect(channelOf('gundam').cover?.logo, isFalse);
    expect(channelOf('beyblade').cover, isNull, reason: '앱 안 기본 그림');

    final worlds = await deriveWorlds('pokemon');
    final gen1 = worlds.firstWhere((w) => w.id == 'pokemon-gen1');
    expect([gen1.cover?.logo, gen1.cover?.bg], [false, 0xFF958A75]);
    expect(worlds.firstWhere((w) => w.id == 'pokemon-gen2').cover, isNull);
  });

  test('페이지는 흰 바탕 — 층은 머리카락 줄, 흰 면 안 작은 상자는 soft', () {
    expect(Gp.bg, const Color(0xFFFFFFFF));
    expect(buildGpTheme().scaffoldBackgroundColor, const Color(0xFFFFFFFF));
    expect(Gp.bandLine.width, 0.5);
    expect(Gp.photoEdge.width, 0.5);
    expect(Gp.soft, isNot(Gp.bg), reason: '안쪽 상자가 흰 면에 녹지 않게');
  });
}
