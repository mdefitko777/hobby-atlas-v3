// 닌텐도 채널 (Gunpula 계약 2026-11-14): 등급 NIN_GAME · NIN_HW · NIN_AMIIBO · NIN_GOODS → 라인 · 유형 · 기종 ·
// 종류 둘러보기 묶음, 한국 가게뿐인 상품의 ₩ 정가, 설명으로 찾기의 채널 말
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/channels.dart';
import 'package:hobby_atlas/data/gunpula.dart';
import 'package:hobby_atlas/l10n/l10n.dart';
import 'package:hobby_atlas/logic/category_browse.dart';
import 'package:hobby_atlas/logic/kit_filter.dart';
import 'package:hobby_atlas/logic/kit_rules.dart';
import 'package:hobby_atlas/models.dart';
import 'package:hobby_atlas/notifications/notify_models.dart';
import 'package:hobby_atlas/screens/c_channel_screen.dart';
import 'package:hobby_atlas/theme.dart';
import 'package:hobby_atlas/widgets.dart' show CircleThumb;

Map<String, Object?> _rec(String id, String code, {String? subline, int? krw, String goodsKind = ''}) => {
  'kit_id': id,
  'franchise': 'nintendo',
  'grade_code': code,
  'subline': ?subline,
  'names': {'ko': id, 'ja': id, 'zh': id, 'en': id},
  'series': {
    'key': 'nintendo_metroid',
    'labels': {'ko': '메트로이드', 'zh': '银河战士'},
  },
  'universe': 'Nintendo',
  'release_date': '2025-12-04',
  'price_jpy': null,
  'price_krw': ?krw,
  if (goodsKind.isNotEmpty) ...{'category': 'goods', 'goods_kind': goodsKind},
  'source_refs': [
    {'source_id': 'nintendo_store_kr', 'url': 'https://store.nintendo.co.kr/$id'},
  ],
};

List<Kit> _map(List<Map<String, Object?>> recs) => [
  for (final m in mapKitsJob({
    'raw': jsonEncode({'kits': recs}),
  }))
    Kit.fromSlim(m, recentSince: '', monthPrefix: '2026-11'),
];

void main() {
  final kits = _map([
    _rec('nintendo-kr-14917', 'NIN_GAME', subline: 'Nintendo Switch 2', krw: 74800),
    _rec('nintendo-kr-15000', 'NIN_GAME', subline: 'Nintendo Switch', krw: 64800),
    _rec('nintendo-kr-16000', 'NIN_HW', subline: 'Nintendo Switch 2', krw: 498000),
    _rec('nintendo-kr-amiibo-350', 'NIN_AMIIBO', subline: '슈퍼 스매시브라더스 시리즈'),
    _rec('nintendo-kr-17000', 'NIN_GOODS', subline: '닌텐도 스토어', krw: 25000, goodsKind: 'accessory'),
  ]);
  Kit byId(String id) => kits.firstWhere((k) => k.id == id);

  test('등급 → 라인 · 유형 · 기종(세부 시리즈) · 브랜드 · 원 정가', () {
    final game = byId('nintendo-kr-14917');
    expect(game.franchiseId, 'nintendo');
    expect((game.line, game.type, game.subline), ('게임', '게임', 'Nintendo Switch 2'));
    expect(byId('nintendo-kr-15000').subline, 'Nintendo Switch');
    expect(game.priceKrw, 74800);
    expect(game.priceJpy, isNull);
    expect(game.brands, ['Nintendo']);
    final hw = byId('nintendo-kr-16000');
    expect((hw.line, hw.type), ('본체 · 주변기기', '본체 · 주변기기'));
    final amiibo = byId('nintendo-kr-amiibo-350');
    expect((amiibo.line, amiibo.type, amiibo.subline), ('amiibo', '피규어', '슈퍼 스매시브라더스 시리즈'));
    final goods = byId('nintendo-kr-17000');
    expect((goods.type, goods.goodsKind), ('굿즈', '액세서리'));
  });

  test('종류 둘러보기: 게임 → 본체 · 주변기기 → amiibo → 굿즈 순서', () {
    final secs = typeSections('nintendo', kits);
    expect(secs.map((s) => s.title), ['게임', '본체 · 주변기기', 'amiibo', '굿즈']);
    expect(secs.first.entries.single.kits, hasLength(2), reason: '게임 칸이 영상 · 책 묶음의 게임 칸으로 새지 않는다');
    expect(worldSectionOf('nintendo', 'nintendo-nintendo_mario'), '시리즈');
  });

  test('가격: 한국 가게뿐이라 ₩ 정가 그대로, 플래티넘 포인트 굿즈는 가격 미정 · 필터의 나라 · 돈 칸은 숨김', () {
    expect(kits.map((k) => k.region).toSet(), {'kr'}, reason: 'nintendo_store_kr · nintendo_kr 는 _kr 출처');
    expect(saleRegion(['nintendo_kr']), 'kr');
    expect(kitPrice(byId('nintendo-kr-14917')), '₩74,800');
    expect(kitPrice(byId('nintendo-kr-amiibo-350')), '가격 미정');
    expect(hasBothRegions(kits), isFalse);
    expect(hasBothCurrencies(kits), isFalse);
  });

  test('채널 · 알림 규칙 · 중국어', () {
    expect(channelOf('nintendo').label, '닌텐도');
    expect(notifyWorldRules, contains('nintendo'));
    expect(notifyRuleLabels['nintendo'], '닌텐도 전체');
    L10n.debugSet(AppLang.zh);
    addTearDown(() => L10n.debugSet(AppLang.ko));
    expect(tr('닌텐도'), '任天堂');
    expect(tr('닌텐도 전체'), '全部任天堂');
    expect(tr('본체 · 주변기기'), '主机 · 配件');
    expect(tr('채널 맞춰 보기'), '频道同步');
    expect(kitPrice(byId('nintendo-kr-14917')), '₩74,800');
    // 데이터 값: 한국 가게 브랜드 · amiibo 시리즈 (세부 시리즈 칸은 tr 로 보인다)
    expect(tr('반다이남코코리아'), '万代南梦宫韩国');
    expect(tr('아카데미과학'), '爱德美科学');
    expect(tr(byId('nintendo-kr-amiibo-350').subline), '任天堂明星大乱斗系列');
  });

  testWidgets('채널 관리 360dp: 닌텐도 칸(그림 없으면 첫 글자)까지 넘치지 않고, 누르면 내 채널에', (tester) async {
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
    final tiles = find.byType(CircleThumb, skipOffstage: false);
    expect(tiles, findsNWidgets(allChannels.length));
    final nintendo = find.byWidgetPredicate(
      (w) => w is CircleThumb && w.label == channelOf('nintendo').label,
      skipOffstage: false,
    );
    await tester.ensureVisible(nintendo);
    await tester.pump();
    await tester.tap(nintendo);
    await tester.pump();
    expect(picked, [...defaultMyChannels, 'nintendo']);
    expect(tester.takeException(), isNull);
  });
}
