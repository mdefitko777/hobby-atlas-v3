// 설명으로 찾기 — 중국어로 친 문장도 한국어 문장과 같은 뜻으로 (화면 언어와 상관없이), 이유는 화면 언어로
import 'package:flutter_test/flutter_test.dart';
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
