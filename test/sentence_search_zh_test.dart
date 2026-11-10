// 설명으로 찾기 — 중국어로 친 문장도 한국어 문장과 같은 뜻으로 (화면 언어와 상관없이), 이유는 화면 언어로
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/l10n/l10n.dart';
import 'package:hobby_atlas/l10n/zh_text.dart';
import 'package:hobby_atlas/logic/sentence_search.dart';
import 'package:hobby_atlas/models.dart';

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
  keywords: const [],
  seriesKey: seriesKey,
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

  test('찾기 화면 예시 문장의 중국어도 같은 뜻', () {
    const pairs = {
      '샤아 전용 자쿠 HG': '夏亚专用 扎古 HG',
      '수성의 마녀 에어리얼 HG': '水星的魔女 风灵 HG',
      '이브이 인형': '伊布 玩偶',
      '드래곤 블레이드 베이': '龙 战刃 陀螺',
    };
    pairs.forEach((ko, zh) => expect(_labels(zh), _labels(ko), reason: zh));
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
