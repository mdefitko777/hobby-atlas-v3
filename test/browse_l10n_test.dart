// 중국어 화면 — 둘러보기 묶음(채널 · 종류 · 세대 묶음 · 건담 도감 꼬리표 · 메자스타 · 프렌다)의 이름표가 번역되나.
// 묶기 · 비교에 쓰는 값은 한국어 그대로인지도 본다.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/channels.dart';
import 'package:hobby_atlas/data/gundam_atlas.dart';
import 'package:hobby_atlas/data/tag_atlas.dart';
import 'package:hobby_atlas/l10n/l10n.dart';
import 'package:hobby_atlas/l10n/zh_text.dart';
import 'package:hobby_atlas/logic/category_browse.dart';

import 'support/line_kits.dart';

final _hangul = RegExp(r'[가-힣]');
Object? _fixture(String name) => jsonDecode(File('test/fixtures/$name').readAsStringSync());

void main() {
  tearDown(() => L10n.debugSet(AppLang.ko));

  test('이름표 표의 한국어는 모두 번역 표에 있다', () {
    final labels = [
      for (final c in allChannels) c.label,
      ...roleLabels.values,
      ...unitTypeLabels.values,
      ...rarityLabels.values,
      ...typeLabels.values,
      for (final r in [...mezastarRegions, friendaRegion]) r.label,
      pbChoice,
      lineOtherKey,
    ];
    // 종류 · 세대 묶음 이름과 칸 이름은 category_browse.dart 안 글자 그대로 (모두 화면에 나온다)
    final src = File('lib/logic/category_browse.dart').readAsLinesSync().where((l) => !l.trimLeft().startsWith('//'));
    for (final m in RegExp(r"'([^'\n]*[가-힣][^'\n]*)'").allMatches(src.join('\n'))) {
      labels.add(m[1]!);
    }
    expect([
      for (final l in labels)
        if (_hangul.hasMatch(l) && !zhText.containsKey(l)) l,
    ], isEmpty);
  });

  test('중국어 화면: 칸 이름 · 화수 · 부제는 중국어, 키는 한국어 그대로', () {
    L10n.debugSet(AppLang.zh);
    final kits = [
      for (var i = 0; i < 3; i++) lineKit('g$i', line: '굿즈', type: '굿즈', goodsKind: '의류'),
      lineKit('p', line: '옵션 파츠'),
    ];
    final secs = typeSections('gundam', kits);
    expect(secs.map((s) => s.title), ['프라모델', '굿즈'], reason: '묶음 이름은 화면에서 tr()');
    expect([for (final s in secs) ...s.entries.map((e) => (e.key, e.label))], [('옵션 파츠', '配件包'), ('의류', '服饰')]);
    expect(tr(channelOf('pokemon').label), '宝可梦');
    expect(tr(worldSectionOf('pokemon', 'pokemon-gen1')), '正篇世代');
    expect((episodesLabel('1–3화'), episodesLabel('12화'), episodesLabel('')), ('第1–3集', '第12集', ''));
    expect(TagGame.frienda.subtitle, 'Frienda 卡');

    L10n.debugSet(AppLang.ko);
    expect((episodesLabel('1–3화'), lineGroupLabel('의류'), TagGame.frienda.subtitle), ('1–3화', '의류', '프렌다 픽'));
  });

  test('태그 도감: 중국어 화면이면 데이터의 중국어 이름 · 탄 이름', () {
    final kr = parseMezastar(_fixture('mezastar-intl.sample.json'), mezastarRegions.first);
    final jp = parseMezastar(_fixture('mezastar-jp.sample.json'), mezastarRegions[1]);
    final f = parseFrienda(_fixture('pokemon-frienda.sample.json'));
    final pika = kr.cards.firstWhere((c) => c.dex == 25);
    expect((pika.name, kr.sets.first.name), ('피카츄', '스타더스트 1탄'));

    L10n.debugSet(AppLang.zh);
    expect((pika.name, pika.nameKo, kr.sets.first.name), ('皮卡丘', '피카츄', '星塵第1彈'));
    expect(jp.sets.map((s) => s.name), ['第1弹', 'Gorgeous Star Set 5', '活动卡匣']);
    expect(f.sets.first.name, '第1弹');
    final star = jp.cards.firstWhere((c) => c.grade == null && c.rarity.isNotEmpty, orElse: () => jp.cards.first);
    expect(_hangul.hasMatch(star.badge), isFalse);
    // 그림만 바꿔도 두 언어 이름이 그대로
    expect(pika.withImages(image: 'x', large: const []).name, '皮卡丘');
  });
}
