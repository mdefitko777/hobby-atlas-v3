// 설명으로 찾기 — 중국어로 친 문장도 한국어 문장과 같은 뜻으로 (화면 언어와 상관없이), 이유는 화면 언어로
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/data/gunpula.dart';
import 'package:hobby_atlas/l10n/l10n.dart';
import 'package:hobby_atlas/l10n/zh_text.dart';
import 'package:hobby_atlas/logic/sentence_search.dart';
import 'package:hobby_atlas/models.dart';
import 'package:hobby_atlas/screens/b_search_screen.dart' show sentenceExamples, sentenceExamplesZh;

Kit kit(
  String id, {
  String name = '',
  String nameJa = '',
  String nameZh = '',
  String franchise = 'gundam',
  String series = '',
  String seriesKey = '',
  String line = '',
  String type = '',
  String date = '',
  String blob = '',
  List<String> zhWords = const [],
}) => Kit(
  id: id,
  franchiseId: franchise,
  name: name.isEmpty ? id : name,
  nameJa: nameJa,
  nameZh: nameZh,
  series: series,
  line: line,
  type: type,
  scale: '',
  universe: '',
  date: date,
  priceJpy: null,
  image: '',
  gallery: const [],
  limited: false,
  pb: false,
  status: CollectStatus.none,
  wantedQty: 0,
  recent: false,
  month: false,
  market: null,
  // 실제 데이터처럼 중국어 낱말(search_zh)은 키워드 뒤쪽에 (lib/data/gunpula.dart mapKitsJob)
  keywords: zhWords,
  zhKeywordsFrom: 0,
  seriesKey: seriesKey,
  blob: blob,
);

Set<String> _labels(String s) => {for (final c in parseSentence(s).concepts) c.label};

void main() {
  final kits = [
    kit('a', name: 'HG 샤아 전용 자쿠II', series: '초대', seriesKey: 'uc_first', line: 'HG', type: '프라모델', date: '2026-01'),
    kit('b', name: 'MG ザク ウォーリア', seriesKey: 'seed', line: 'MG', type: '프라모델', date: '2025-05'),
    kit('c', name: 'HG 건담 에어리얼', seriesKey: 'witch', line: 'HG', type: '프라모델', date: '2024-01'),
    kit('d', name: 'ピカチュウ ぬいぐるみ', franchise: 'pokemon', line: '봉제인형', type: '인형'),
    kit('e', name: '자쿠 아크릴 스탠드', type: '굿즈', date: '2027-01'),
    kit('f', name: '드랜 소드 3-60F', franchise: 'beyblade', line: 'BX', type: '배틀 토이'),
  ];

  test('중국어 표기도 한국어와 같은 뜻으로 묶는다', () {
    expect(_labels('夏亚专用扎古 HG'), _labels('샤아 전용 자쿠 HG'));
    expect(_labels('红色的高达'), {'빨강', '건담'});
    expect(_labels('红 高达'), {'빨강', '건담'});
    expect(_labels('有翅膀的白色高达 MG'), {'날개', '흰색', '건담', 'MG'});
    expect(_labels('粘土人'), {'넨도로이드'});
    expect(_labels('皮卡丘 毛绒玩偶'), _labels('피카츄 봉제인형'));
    expect(_labels('扭蛋 手办 周边'), {'가샤폰', '피규어', '굿즈'});
    expect(_labels('水星的魔女 风灵'), {'수성', '에어리얼'});
    expect(_labels('逆袭的夏亚'), {'역샤'}, reason: '긴 표기 먼저 — 夏亚 만 따로 잡지 않는다');
    expect(_labels('龙 战刃 陀螺'), {'드래곤', '블레이드', '베이블레이드'});
  });

  test('중국어 한 글자는 띄어 쓴 낱말 · 한 글자끼리 덩어리일 때만 뜻으로', () {
    expect(_labels('红高达'), {'빨강', '건담'}, reason: '高达 를 지우면 红 만 남는다');
    expect(_labels('黑金 高达'), {'검정', '금색', '건담'});
    expect(_labels('找龙 陀螺'), {'드래곤', '베이블레이드'});
    expect(_labels('帮我找红的高达'), {'빨강', '건담'}, reason: '두 글자 군말(帮我找)을 먼저 지워야 红 이 혼자 남는다');
    expect(_labels('一个红的 扎古'), {'빨강', '자쿠'});
    expect(_labels('有点粉的 粘土人'), {'분홍', '넨도로이드'});
    expect(_labels('奥伯龙 粘土人'), {'넨도로이드'}, reason: '奥伯龙 의 龙 은 드래곤이 아니다');
    expect(parseSentence('奥伯龙 粘土人').words, ['奥伯龙']);
    expect(_labels('闪粉 亚克力'), isEmpty);
    expect(_labels('金属 扎古'), {'메탈', '자쿠'});
  });

  test('중국어 이름이 상품 글자에 있어도 한 글자로 잘못 맞추지 않는다 (奥伯龙 · 金属)', () {
    // 실제 데이터처럼 blob 에 한국어 · 일본어 · 중국어 이름이 다 들어 있다 (lib/data/gunpula.dart)
    Kit nendo(String id, String ko, String ja, String zh, String date) => kit(
      id,
      name: ko,
      nameJa: ja,
      nameZh: zh,
      franchise: 'fate',
      line: '넨도로이드',
      type: '피규어',
      date: date,
      blob: '$ko $ja 넨도로이드 피규어 $zh'.toLowerCase(),
    );
    final oberon = [
      nendo('goodsmile-fate-14196', '넨도로이드 프리텐더/오베론', 'ねんどろいど プリテンダー/オベロン', '粘土人 Pretender / 奥伯龙', '2027-03'),
      nendo('g35138', '넨도로이드 오베론 영기재림 Ver.', 'ねんどろいど オベロン 霊基再臨Ver.', '粘土人 奥伯龙 灵基再临Ver.', '2027-02'),
    ];
    final dragons = [
      for (var i = 0; i < 5; i++)
        nendo('dragon-$i', '넨도로이드 칸나 드래곤 Ver.$i', 'ねんどろいど カンナ ドラゴンVer.$i', '粘土人 康娜 龙Ver.$i', '2020-0${i + 1}'),
    ];
    final all = [...oberon, ...dragons];
    final hits = sentenceSearch('드래곤 넨도로이드', all);
    expect(hits.map((h) => h.kit.id), isNot(contains(startsWith('goodsmile-fate'))));
    expect(hits.map((h) => h.kit.id).toSet(), {for (final k in dragons) k.id});
    expect(hits.every((h) => h.score == 100), isTrue);
    for (final h in sentenceSearch('드래곤 넨도로이드', all, limit: 99)) {
      if (h.kit.id.startsWith('dragon')) continue;
      expect(h.matched, isNot(contains('드래곤')), reason: h.kit.id);
    }

    final metal = kit(
      'acvi-4934054088706',
      name: '팬텀 C01-GAEA 레드 메탈 Ver.',
      nameJa: 'ファンタズマ C01-GAEA レッドメタルVer.',
      nameZh: '幻影 C01-GAEA 红色金属Ver.',
      franchise: 'armored_core',
      blob: '팬텀 c01-gaea 레드 메탈 ver. ファンタズマ c01-gaea レッドメタルver. 幻影 c01-gaea 红色金属ver.',
    );
    final gold = kit('acvi-gold', name: '팬텀 골드 Ver.', nameZh: '幻影 金色Ver.', franchise: 'armored_core');
    expect(sentenceSearch('금색 아머드 코어', [metal, gold]).map((h) => h.kit.id), ['acvi-gold']);
    expect(sentenceSearch('金色 装甲核心', [metal, gold]).map((h) => h.kit.id), ['acvi-gold']);
    expect(sentenceSearch('금색 아머드 코어', [metal]), isEmpty);
  });

  group('중국어 이름의 일부를 한국어 · 일본어 낱말로 맞추지 않는다 (2026-11-11 실제 데이터)', () {
    Kit poke(String id, String ko, String zh, {List<String> zhWords = const [], String type = '인형'}) =>
        kit(id, name: ko, nameZh: zh, franchise: 'pokemon', type: type, zhWords: zhWords, blob: '$ko $zh');
    final eevee = poke('pokemon-kr-132147673', '포켓몬센터 보들보들 봉제인형 이브이', '宝可梦中心 软绵绵 毛绒玩偶 伊布');
    final eeveelutions = [
      poke('pokemon-kr-137529057', '포켓몬센터 반짝반짝☆ 글리터 봉제인형 샤미드', '宝可梦中心 闪闪亮亮☆ 闪粉 毛绒玩偶 水伊布'),
      poke('pokemon-kr-131038482', '포켓몬센터 보들보들 봉제인형 에브이', '宝可梦中心 软绵绵 毛绒玩偶 太阳伊布'),
      poke('pokemon-kr-128563818', '포켓몬센터 카라비너 마스코트 쥬피썬더', '宝可梦中心 登山扣 挂件 雷伊布'),
      poke(
        'pokemon-center-4521329339771',
        '470 봉제인형 Pokémon fit 리피아',
        '470 毛绒玩偶 宝可梦 fit 叶伊布',
        zhWords: ['毛绒公仔', '葉伊布', '叶精灵'],
      ),
    ];

    test('이브이 인형 — 水伊布 · 太阳伊布 · 雷伊布 · 葉伊布 는 이브이가 아니다', () {
      for (final q in ['이브이 인형', '伊布 玩偶']) {
        final hits = sentenceSearch(q, [eevee, ...eeveelutions], limit: 99);
        expect(hits.first.kit.id, eevee.id, reason: q);
        expect(hits.first.score, 100, reason: q);
        for (final h in hits.skip(1)) {
          expect(h.matched, isNot(contains('이브이')), reason: '$q ${h.kit.id}');
        }
      }
    });

    test('저스티스 — 正义女神高达(아스트레아)는 아니다', () {
      final astraea = kit(
        'pbandai-wb-1000255655',
        name: 'MG 1/100 건담 아스트레아+프로토 GN 트윈 브로드 블레이드',
        nameJa: 'ＭＧ 1 / 100 ガンダムアストレア＋プロトＧＮツインブロードブレイド',
        nameZh: 'MG 1 / 100 正义女神高达+原型GN双阔刃剑',
        zhWords: ['Astraea'],
      );
      final justice = kit('tamashii-14747', name: '저스티스 건담(리얼 타입 컬러)', nameZh: '正义高达(写实配色)');
      for (final q in ['저스티스 건담', '正义 高达']) {
        expect(sentenceSearch(q, [astraea, justice]).map((h) => h.kit.id), [justice.id], reason: q);
      }
    });

    test('드래곤 · 파랑 · 날개 · 보라 · 스트라이크 — search_zh 와 중국어 이름의 한자는 일본어 낱말이 아니다', () {
      final brachio = kit(
        'beyblade-x-cx18',
        name: 'CX-18 랜덤 부스터 브라키오윕 셀렉트',
        nameJa: 'CX-18 ランダムブースター ブラキオウィップセレクト',
        nameZh: 'CX-18 随机补充包 腕龙鞭打精选',
        franchise: 'beyblade',
        zhWords: ['腕龍鞭打', 'Brachio Whip', '腕龙古鞭'],
      );
      final dragoon = kit(
        'beyblade-x-bx00-drgs',
        name: 'BX-00 드라군스톰 4-60RA',
        nameJa: 'BX-00 ドラグーンストーム4-60RA',
        nameZh: 'BX-00 龙骑士4-60RA',
        franchise: 'beyblade',
        zhWords: ['青龙', '青龙风暴', 'Dragoon', '龍騎士'],
      );
      final jurassic = kit(
        'beyblade-x-bx00-jsq',
        name: 'BX-00 【B4 스토어 한정】 쥬라기 월드 스피노사우루스 / 케찰코아틀루스',
        nameJa: 'BX-00 【B4ストア限定】 ジュラシック・ワールド スピノサウルス / ケツァルコアトルス',
        nameZh: 'BX-00 【B4商店限定】 侏罗纪世界 棘龙 / 风神翼龙',
        franchise: 'beyblade',
      );
      final charizard = poke('pokemon-kr-charizard', '포켓몬센터 봉제인형 리자몽', '宝可梦中心 毛绒玩偶 喷火龙', zhWords: ['噴火龍']);
      final murasaki = kit(
        'goodsmile-fate-g1140864',
        name: '무라사키 시키부: 바니걸 스타일',
        nameJa: 'Murasaki Shikibu: Bunny Girl Style',
        nameZh: '紫式部: 兔女郎风格',
        franchise: 'fate',
        type: '피규어',
      );
      final whiteBase = kit(
        'converge-sb01',
        name: 'FW GUNDAM CONVERGE SB 페가수스급 강습양륙함 2번함 화이트 베이스',
        nameJa: 'FW GUNDAM CONVERGE SB ペガサス級強襲揚陸艦2番艦 ホワイトベース',
        nameZh: 'FW GUNDAM CONVERGE SB 飞马级强袭登陆舰2号舰 白色基地',
      );
      final strike = kit('tamashii-16166', name: '스트라이크건담 ENGINEERING EDITION', nameZh: '强袭高达 ENGINEERING EDITION');
      final all = [brachio, dragoon, jurassic, charizard, murasaki, whiteBase, strike];
      List<String> idsWith(String q, String label) => [
        for (final h in sentenceSearch(q, all, limit: 99))
          if (h.matched.contains(label)) h.kit.id,
      ];
      expect(idsWith('드래곤 블레이드 베이', '드래곤'), [dragoon.id], reason: '腕龍鞭打 의 龍');
      expect(idsWith('드래곤 인형', '드래곤'), isNot(contains(charizard.id)), reason: '噴火龍 의 龍');
      expect(idsWith('파란 드래곤 베이', '파랑'), isEmpty, reason: '青龙 의 青');
      expect(idsWith('날개 베이', '날개'), isEmpty, reason: '风神翼龙 의 翼');
      expect(idsWith('보라색 피규어', '보라'), isEmpty, reason: '紫式部 의 紫');
      expect(idsWith('스트라이크 건담', '스트라이크'), [strike.id], reason: '强袭登陆舰');
      expect(idsWith('强袭 高达', '스트라이크'), [strike.id]);
    });

    test('일본어 이름의 한 글자 한자는 그대로 뜻으로 (赤 · 龍)', () {
      final red = kit('jp-red', name: 'HG 赤いザク', line: 'HG');
      final ryu = kit('jp-ryu', name: '포켓몬 용', nameJa: 'ポケモン 龍のぬいぐるみ', franchise: 'pokemon', type: '인형');
      expect(sentenceSearch('빨간 자쿠', [red]).single.score, 100);
      expect(sentenceSearch('드래곤 인형', [ryu]).single.score, 100);
    });

    test('실제 데이터 모양(mapKitsJob): 중국어 낱말은 키워드 뒤쪽 · 이브이 문장에 샤미드가 안 나온다', () {
      Map<String, Object?> raw(String id, String ko, String zh, List<String> searchZh) => {
        'kit_id': id,
        'franchise': 'pokemon',
        'names': {'ja': ko, 'en': ko, 'zh': zh, 'ko': ko},
        'series': {
          'key': 'pokemon',
          'labels': {'zh': '宝可梦', 'en': 'Pokemon', 'ja': 'ポケモン', 'ko': '포켓몬'},
        },
        'search_zh': searchZh,
      };
      final kits = [
        for (final j in mapKitsJob({
          'raw': jsonEncode({
            'kits': [
              raw('pokemon-kr-132147673', '포켓몬센터 보들보들 봉제인형 이브이', '宝可梦中心 软绵绵 毛绒玩偶 伊布', ['伊布']),
              raw('pokemon-kr-137529057', '포켓몬센터 반짝반짝☆ 글리터 봉제인형 샤미드', '宝可梦中心 闪闪亮亮☆ 闪粉 毛绒玩偶 水伊布', ['水精灵']),
            ],
          }),
        }))
          Kit.fromSlim(j, recentSince: '', monthPrefix: '2026-11'),
      ];
      final showers = kits.last;
      expect(showers.keywords.skip(showers.zhKeywordsFrom), containsAll(['水精灵', '宝可梦']));
      expect(showers.keywords.take(showers.zhKeywordsFrom), isNot(contains('水精灵')));
      expect(showers.blob, contains('水精灵'), reason: '이름 찾기(blob)에는 그대로');
      final hits = sentenceSearch('이브이 인형', kits, limit: 99);
      expect(
        [
          for (final h in hits)
            if (h.matched.contains('이브이')) h.kit.id,
        ],
        ['pokemon-kr-132147673'],
      );
    });
  });

  test('찾기 화면 예시 문장의 중국어도 같은 뜻 (중국어 화면 예시 = sentenceExamplesZh)', () {
    expect(sentenceExamplesZh, hasLength(sentenceExamples.length));
    for (var i = 0; i < sentenceExamples.length; i++) {
      expect(_labels(sentenceExamplesZh[i]), _labels(sentenceExamples[i]), reason: sentenceExamplesZh[i]);
    }
  });

  test('중국어 군말은 버리고 남는 낱말만', () {
    final q = parseSentence('帮我找一个有翅膀的白色高达');
    expect(q.words, isEmpty);
    expect(parseSentence('请找 RX-78 拼装模型').words, ['rx-78']);
  });

  test('중국어 문장으로 찾아도 한국어와 같은 후보', () {
    expect(sentenceSearch('夏亚专用 扎古 HG', kits).first.kit.id, sentenceSearch('샤아 전용 자쿠 HG', kits).first.kit.id);
    expect(sentenceSearch('夏亚专用 扎古 HG', kits).first.score, 100);
    expect(sentenceSearch('扎古 MG', kits).first.kit.id, 'b');
    expect(sentenceSearch('水星的魔女 风灵', kits).first.kit.id, 'c');
    expect(sentenceSearch('皮卡丘 玩偶', kits).map((h) => h.kit.id), ['d']);
    expect(sentenceSearch('龙 陀螺', kits).first.kit.id, 'f');
    expect(sentenceSearch('高达 宝可梦', kits), isEmpty); // 채널만 맞은 것은 빼기
  });

  test('중국어 이름만 있는 상품도 중국어 낱말로', () {
    final zhOnly = [kit('z', name: 'RG 키트', nameZh: 'RG 自由高达 新生', line: 'RG', type: '프라모델')];
    expect(sentenceSearch('自由 RG', zhOnly).single.score, 100);
    expect(sentenceSearch('新生 RG', zhOnly).single.score, 100);
  });

  test('이유: 뜻 이름은 화면 언어로, 친 낱말은 그대로', () {
    addTearDown(() => L10n.debugSet(AppLang.ko));
    final hit = sentenceSearch('샤아 전용 자쿠 HG', kits).first;
    L10n.debugSet(AppLang.ko);
    expect(hit.reason.split(' · ').toSet(), {'샤아', '자쿠', 'HG'});
    L10n.debugSet(AppLang.zh);
    expect(hit.reason.split(' · ').toSet(), {'夏亚', '扎古', 'HG'});
    expect(hit.matched, containsAll(['샤아', '자쿠', 'HG']), reason: '비교용 값은 한국어 그대로');
  });

  test('한글이 든 뜻 이름은 모두 번역 표에 있다', () {
    final hangul = RegExp(r'[가-힣]');
    final missing = [
      for (final c in sentenceConcepts)
        if (hangul.hasMatch(c.label) && !zhText.containsKey(c.label)) c.label,
    ];
    expect(missing, isEmpty);
  });
}
