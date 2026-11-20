// 이펙트 채널 (Gunpula 계약 2026-11-15): 등급 TAMASHII_EFFECT · GSC_SIMPLE_EFFECT · grades.json 이름의 새 등급 → 라인 · 유형 ·
// 맞춰 쓰는 피규어 라인, 작품이 없는 상품의 종류 · 이펙트 종류(이펙트 갈래) · 도감 묶음, 일본 가게의 ¥ 정가, 알림 피드의 종류,
// 채널 · 알림 · 중국어 · 설명으로 찾기의 채널 말
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/channels.dart';
import 'package:hobby_atlas/data/catalog.dart';
import 'package:hobby_atlas/data/derive.dart';
import 'package:hobby_atlas/data/gunpula.dart';
import 'package:hobby_atlas/l10n/l10n.dart';
import 'package:hobby_atlas/logic/category_browse.dart';
import 'package:hobby_atlas/logic/kit_filter.dart';
import 'package:hobby_atlas/logic/kit_rules.dart';
import 'package:hobby_atlas/logic/sentence_search.dart';
import 'package:hobby_atlas/models.dart';
import 'package:hobby_atlas/notifications/feed_rules.dart';
import 'package:hobby_atlas/notifications/notify_models.dart';
import 'package:hobby_atlas/screens/c_channel_screen.dart';
import 'package:hobby_atlas/theme.dart';
import 'package:hobby_atlas/widgets.dart' show CircleThumb;

// Gunpula kits-effects.json 레코드 모양 (gp-effects fc799bb2) — work_title · universe 는 없고, series 는 이펙트 갈래
const _kinds = {
  'smoke': {'ko': '연기', 'zh': '烟雾'},
  'impact': {'ko': '임팩트', 'zh': '冲击'},
  'thunder': {'ko': '번개', 'zh': '雷电'},
  'flame': {'ko': '불꽃', 'zh': '火焰'},
  'wind': {'ko': '바람', 'zh': '风'},
};

Map<String, Object?> _rec(
  String id,
  String code, {
  required String kind,
  String subline = '',
  String ja = '',
  int? jpy,
  String date = '2025-06-20',
  String source = 'tamashii_effect_jp',
}) => {
  'kit_id': id,
  'franchise': 'effects',
  'grade_code': code,
  'subline': subline,
  'names': {'ja': ja.isEmpty ? id : ja},
  'release_date': date,
  'price_jpy': jpy,
  'images': {'box_art_url': 'https://example.test/$id.jpg', 'box_art_source_id': source},
  'source_urls': ['https://example.test/item/$id'],
  'source_refs': [
    {'source_id': source, 'url': 'https://example.test/item/$id'},
  ],
  'universe': null,
  'work_title': null,
  'series': {'key': 'effects_$kind', 'labels': _kinds[kind]},
};

// grades.json 의 이펙트 등급 (Gunpula 와 같은 모양 — 새 등급은 name_ko · name_zh 가 온다)
final _grades = jsonEncode({
  'grades': [
    {'code': 'TAMASHII_EFFECT', 'name_ko': '魂EFFECT 이펙트', 'name_zh': '魂EFFECT 特效件', 'category': 'other'},
    {'code': 'GSC_SIMPLE_EFFECT', 'name_ko': 'THE 심플 이펙트', 'name_zh': 'THE 简易特效件', 'category': 'other'},
    {'code': 'MODEROID_EFFECT', 'name_ko': 'MODEROID 이펙트', 'name_zh': 'MODEROID 特效件', 'category': 'other'},
    {'code': 'HG', 'name_ko': '하이 그레이드', 'name_zh': '高等级 / HG', 'category': 'core'},
  ],
});

List<Map<String, Object?>> _slim(List<Map<String, Object?>> recs) => mapKitsJob({
  'raw': jsonEncode({'kits': recs}),
  'grades': _grades,
});

List<Kit> _map(List<Map<String, Object?>> recs) => [
  for (final m in _slim(recs)) Kit.fromSlim(m, recentSince: '', monthPrefix: '2026-11'),
];

final _recs = [
  _rec(
    'tamashii-effect-smoke',
    'TAMASHII_EFFECT',
    kind: 'smoke',
    subline: 'S.H.Figuarts',
    ja: '魂EFFECT 煙 for S.H.Figuarts',
    jpy: 3300,
  ),
  _rec('tamashii-effect-impact', 'TAMASHII_EFFECT', kind: 'impact', ja: '魂EFFECT 衝撃 for S.H.Figuarts', jpy: 3850),
  _rec(
    'tamashii-effect-old-smoke',
    'TAMASHII_EFFECT',
    kind: 'smoke',
    subline: '魂EFFECT',
    ja: '魂EFFECT SMOKE White Ver.',
    date: '2012-05-26',
  ),
  _rec(
    'tamashii-effect-thunder',
    'TAMASHII_EFFECT',
    kind: 'thunder',
    subline: '魂EFFECT',
    ja: '魂EFFECT THUNDER Yellow Ver.',
    jpy: 2200,
    date: '2015-03-28',
  ),
  _rec(
    'goodsmile-effects-g1139373',
    'GSC_SIMPLE_EFFECT',
    kind: 'flame',
    subline: 'THE シンプルエフェクト',
    ja: 'THE シンプルエフェクト《炎》RED',
    jpy: 1700,
    source: 'good_smile_effects_jp',
  ),
  _rec(
    'goodsmile-effects-g9023',
    'MODEROID_EFFECT',
    kind: 'wind',
    subline: 'MODEROID',
    ja: 'MODEROID ウインドエフェクト',
    jpy: 1450,
    source: 'good_smile_effects_jp',
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final kits = _map(_recs);
  Kit byId(String id) => kits.firstWhere((k) => k.id == id);

  test('등급 → 라인 · 유형 · 맞춰 쓰는 피규어 라인(세부 시리즈) · 브랜드 · 엔 정가', () {
    final smoke = byId('tamashii-effect-smoke');
    expect(smoke.franchiseId, 'effects');
    expect((smoke.line, smoke.type, smoke.subline), ('魂EFFECT', '이펙트', 'S.H.Figuarts'));
    expect(byId('tamashii-effect-impact').subline, 'S.H.Figuarts', reason: 'subline 이 비면 이름의 for S.H.Figuarts');
    expect(byId('tamashii-effect-old-smoke').subline, '', reason: '옛 魂EFFECT: subline 이 라인 이름뿐');
    expect(smoke.brands, ['TAMASHII NATIONS'], reason: '출처 tamashii_effect_jp');
    expect((smoke.series, smoke.seriesKey), ('연기', 'effects_smoke'), reason: 'series 는 이펙트 갈래');
    final gsc = byId('goodsmile-effects-g1139373');
    expect((gsc.line, gsc.type, gsc.subline), ('the simple effect', '이펙트', ''), reason: 'THE シンプルエフェクト 는 라인 이름');
    expect(gsc.brands, ['Good Smile']);
    // Gunpula 가 채널 이름을 붙인 다른 출처로 내도 브랜드는 같은 사이트 것
    expect(brandOfSource('tamashii_web_effects_jp'), 'TAMASHII NATIONS');
    expect(brandOfSource('good_smile_effects_global'), 'Good Smile');
    expect(brandOfSource('unknown_shop_jp'), isNull);
  });

  test('앱 표에 없는 이펙트 등급: 라인은 grades.json name_ko (코드 그대로가 아니다), 유형은 이펙트, 중국어는 name_zh', () {
    final wind = byId('goodsmile-effects-g9023');
    expect((wind.line, wind.type, wind.subline), ('MODEROID 이펙트', '이펙트', ''));
    expect(kits.every((k) => k.type == '이펙트'), isTrue, reason: '이펙트 채널은 등급과 상관없이 유형 이펙트');
    expect(kits.map((k) => k.line), isNot(contains(matches(RegExp(r'^[A-Z_]+$')))));
    expect(lineLabel('MODEROID_EFFECT', '', ''), 'MODEROID 이펙트');
    expect(gradeZhNames['MODEROID 이펙트'], 'MODEROID 特效件');
    expect(lineLabel('TAMASHII_EFFECT', '', ''), '魂EFFECT', reason: '앱 표의 이름이 먼저');
    expect(lineLabel('HG', '', ''), 'HG', reason: '코드 그대로가 이름인 건프라 등급은 grades.json 이름으로 바꾸지 않는다');
  });

  test('알림 피드의 종류(FeedItem.line)도 grades.json 이름이라 상품 라인과 같다', () {
    final it = FeedItem.fromJson({
      'kit_id': 'goodsmile-effects-g9023',
      'franchise': 'effects',
      'grade_code': 'MODEROID_EFFECT',
      'subline': 'MODEROID',
      'name_ja': 'MODEROID ウインドエフェクト',
      'names': {'ja': 'MODEROID ウインドエフェクト'},
    }, 'added')!;
    expect(it.line, byId('goodsmile-effects-g9023').line);
    expect(conditionMatches(const NotifyCondition(franchise: 'effects', line: 'MODEROID 이펙트'), it), isTrue);
  });

  test('가격: 일본 가게 ¥ 그대로 (환산 없음) · 가격 없는 옛 상품은 가격 미정 · 필터의 나라 · 돈 칸은 숨김', () {
    expect(kits.map((k) => k.region).toSet(), {'jp'});
    expect(kitPrice(byId('tamashii-effect-smoke')), '¥3,300');
    expect(byId('tamashii-effect-smoke').priceKrw, isNull);
    expect(kitPrice(byId('tamashii-effect-old-smoke')), '가격 미정');
    expect(hasBothRegions(kits), isFalse);
    expect(hasBothCurrencies(kits), isFalse);
  });

  test('종류 둘러보기: 한 묶음 이펙트 안 라인 칸, 작품 자리의 값은 이펙트 갈래라 「이펙트 종류」 라고 부른다', () {
    final secs = typeSections('effects', kits);
    expect(secs.map((s) => s.title), ['이펙트']);
    expect(kits.map(lineGroupKey).toSet(), {'魂EFFECT', 'the simple effect', 'MODEROID 이펙트'});
    expect(secs.single.entries.first.key, '魂EFFECT', reason: '작은 칸(하나뿐인 라인)은 기타로 모인다');
    expect(secs.single.entries.first.kits.first.id, 'tamashii-effect-smoke', reason: '새것부터');
    expect(valueCounts(kits.map(kitWork)).map((e) => e.$1).toSet(), {'연기', '임팩트', '번개', '불꽃', '바람'});
    expect(kitWorkTitle(kits), '이펙트 종류');
    expect(kitWorkTitle([byId('tamashii-effect-smoke')]), '이펙트 종류');
    expect(kitWorkTitle(const []), '작품');
    expect(worldSectionOf('effects', 'effects-effects_smoke'), '이펙트 종류');
    expect(noWorkChannels, contains('effects'));
    expect(kits.map(noWorkGroupKey).toSet(), {
      'effects_smoke',
      'effects_impact',
      'effects_thunder',
      'effects_flame',
      'effects_wind',
    });
  });

  test('세대 탭 · 도감: atlas 묶음이 없으면 이펙트 갈래로 묶고, 빈 · null 이름이 없다', () async {
    Catalog.instance.debugSet(slim: _slim(_recs), aux: {'atlas-groups.json': <String, Object?>{}});
    addTearDown(Catalog.instance.debugForget);
    final worlds = await deriveWorlds('effects');
    expect(worlds.map((w) => (w.id, w.label, w.kitIds.length)), [
      ('effects-effects_smoke', '연기', 2),
      ('effects-effects_wind', '바람', 1),
      ('effects-effects_thunder', '번개', 1),
      ('effects-effects_flame', '불꽃', 1),
      ('effects-effects_impact', '임팩트', 1),
    ]);
    expect(worlds.every((w) => w.label.isNotEmpty && w.label != 'null' && w.image.isNotEmpty), isTrue);
    expect(worlds.map((w) => worldSectionOf('effects', w.id)).toSet(), {'이펙트 종류'});
    // series 가 없는 레코드는 세부 시리즈 · 라인으로
    final bare = {..._recs.first}..remove('series');
    expect(noWorkGroupKey(_map([bare]).single), 'S.H.Figuarts');
    // atlas 묶음이 생기면 그것이 먼저
    Catalog.instance.debugSet(
      slim: _slim(_recs),
      aux: {
        'atlas-groups.json': {
          'franchises': {
            'effects': [
              {
                'id': 'smoke',
                'labels': {'ko': '연기'},
                'kit_ids': ['tamashii-effect-smoke', 'tamashii-effect-old-smoke'],
              },
            ],
          },
        },
      },
    );
    expect((await deriveWorlds('effects')).map((w) => w.id), ['effects-smoke']);
  });

  test('채널 · 알림 규칙 · 중국어 · 설명으로 찾기', () {
    expect(channelOf('effects').label, '이펙트');
    expect(defaultMyChannels, isNot(contains('effects')), reason: '닌텐도처럼 고르기 전엔 받지 않는다');
    expect(franchiseIds, contains('effects'));
    expect(notifyWorldRules, contains('effects'));
    expect(notifyRuleDefaults['effects'], isFalse);
    expect(notifyRuleLabels['effects'], '이펙트 전체');
    final concept = sentenceConcepts.firstWhere((c) => c.label == '이펙트');
    expect(concept.field, ConceptField.franchise);
    expect(concept.look, ['effects']);
    L10n.debugSet(AppLang.zh);
    addTearDown(() => L10n.debugSet(AppLang.ko));
    expect(tr('이펙트'), '特效件');
    expect(tr('이펙트 전체'), '全部特效件');
    expect(tr(worldSectionOf('effects', 'effects-x')), '特效类别');
    expect(kitPrice(byId('tamashii-effect-smoke')), '¥3,300');
  });

  testWidgets('채널 관리 360dp: 이펙트 칸(그림 없으면 첫 글자)까지 넘치지 않고, 누르면 내 채널에', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    List<String>? picked;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildGpTheme(),
        home: ChannelManagerScreen(initial: defaultMyChannels, onChanged: (ids) => picked = ids),
      ),
    );
    await tester.pump();
    expect(find.byType(CircleThumb, skipOffstage: false), findsNWidgets(allChannels.length));
    final effects = find.byWidgetPredicate(
      (w) => w is CircleThumb && w.label == channelOf('effects').label,
      skipOffstage: false,
    );
    await tester.ensureVisible(effects);
    await tester.pump();
    await tester.tap(effects);
    await tester.pump();
    expect(picked, [...defaultMyChannels, 'effects']);
    expect(tester.takeException(), isNull);
  });
}
