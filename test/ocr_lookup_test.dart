// 글자로 찾기 (사진 글자 · 공유로 받은 글 · 주소) — 순수 규칙. lib/logic/ocr_lookup.dart · url_lookup.dart · lib/share/share_intake.dart
// 실제 데이터로도 (있을 때만): flutter test test/ocr_lookup_test.dart --dart-define=GUNPULA_DATA=<Gunpula data 폴더>
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/data/gunpula.dart';
import 'package:hobby_atlas/l10n/l10n.dart';
import 'package:hobby_atlas/logic/ocr_lookup.dart';
import 'package:hobby_atlas/logic/url_lookup.dart';
import 'package:hobby_atlas/models.dart';
import 'package:hobby_atlas/share/share_intake.dart';

const dataDir = String.fromEnvironment('GUNPULA_DATA');

/// 실제 데이터와 같은 모양의 상품 (이름 = 한국어, nameJa = 일본어)
Kit k(
  String id,
  String name,
  String nameJa, {
  String line = '',
  String scale = '',
  String jan = '',
  String franchise = 'gundam',
  List<String> urls = const [],
  String date = '',
}) => Kit(
  id: id,
  franchiseId: franchise,
  name: name,
  nameJa: nameJa,
  series: '',
  line: line,
  type: '프라모델',
  scale: scale,
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
  jan: jan,
  officialUrl: urls.isEmpty ? '' : urls.first,
  sourceUrls: urls,
);

final catalog = [
  k(
    'hg-hg-1-144-4573102630308000',
    'HG 1 / 144 건담エアリアル',
    'HG 1 / 144 ガンダムエアリアル',
    line: 'HG',
    scale: '1/144',
    jan: '4573102630308',
    urls: [
      'https://www.bandaispirits.co.jp/products/search/detail.php?prd_id=4573102630308000&grp_id=5325',
      'https://p-bandai.jp/item/item-1000188677/',
    ],
    date: '2022-10',
  ),
  k(
    'hg-hg-1-144-4573102650962000',
    'HG 1 / 144 건담エアリアル(改修型)',
    'HG 1 / 144 ガンダムエアリアル(改修型)',
    line: 'HG',
    scale: '1/144',
    jan: '4573102650962',
    date: '2023-04',
  ),
  k('rg-rg-1-144-4549660303633000', 'RG 1 / 144 사자비', 'RG 1 / 144 サザビー', line: 'RG', scale: '1/144', date: '2019-11'),
  k(
    'hg-hguc-1-144-4543112544995000',
    'HGUC 1 / 144 사자비',
    'HGUC 1 / 144 サザビー',
    line: 'HG',
    scale: '1/144',
    date: '2008-01',
  ),
  k('mg-mg-msn-04-4902425770727000', 'MG MSN-04 사자비', 'MG MSN-04 サザビー', line: 'MG', scale: '1/100', date: '2000-03'),
  k('mg-mg-1-100-4543112480835000', 'MG 1 / 100 스트라이크 프리덤건담', 'MG 1 / 100 ストライクフリーダムガンダム', line: 'MG', scale: '1/100'),
  k('hg-hg-1-144-4543112341136000', 'HG 1 / 144 스트라이크 프리덤건담', 'HG 1 / 144 ストライクフリーダムガンダム', line: 'HG', scale: '1/144'),
  k('ng-1-144-4902425086590000', '1 / 144 건담', '1 / 144 ガンダム', line: 'NG', scale: '1/144'),
  k(
    'beyblade-x-bx01',
    'BX-01 드란 소드 3-60F',
    'BX-01 ドランソード3-60F',
    line: 'BX',
    franchise: 'beyblade',
    urls: ['https://beyblade.takaratomy.co.jp/beyblade-x/lineup/bx01.html'],
  ),
  k('beyblade-x-bx22', 'BX-22 ドランソード3-60F エントリーパッケージ', '', line: 'BX', franchise: 'beyblade'),
  k(
    'goodsmile-fate-g1145956',
    'Fate / Grand Order Moon Cancer / Jade Rabbit 1 / 7 Scale Figure',
    '',
    franchise: 'fate',
    scale: '1/7',
    urls: ['https://www.goodsmile.com/en/product/1145956'],
  ),
  k(
    'acvi-4934054065004',
    '아머드 코어 ウェポンユニット018',
    'アーマード・コア ウェポンユニット018',
    franchise: 'armored_core',
    line: 'V.I.',
    jan: '4934054065004',
    urls: ['https://shop.kotobukiya.co.jp/shop/g/g4934054065004/'],
  ),
];

/// ML Kit 이 상자 · 화면에서 읽어 오는 모양 그대로 (줄마다, 잡음 포함)
const aerialBox = '''
機動戦士ガンダム 水星の魔女
HG
1/144
XVX-016
GUNDAM AERIAL
ガンダム・エアリアル
BANDAI SPIRITS
対象年齢15才以上
©創通・サンライズ・MBS''';

const sazabiBox = '''
REAL GRADE
RG 1/144
MSN-04
SAZABI
サザビー
逆襲のシャア''';

const bx01Box = '''
BEYBLADE X
BX-01
スターター
ドランソード 3-60F
DRANSWORD
TAKARA TOMY
¥1,980(税込)''';

const pbandaiShot = '''
12:34 5G 87%
プレミアムバンダイ
ＨＧ １／１４４ ガンダムエアリアル(改修型)
¥2,970(税込)
予約受付中
カートに入れる''';

const bunjangShot = '''
반다이 HG 에어리얼 건담 미개봉
25,000원
채팅하기''';

const janBack = '''
BANDAI SPIRITS
4 573102 630308
MADE IN JAPAN
株式会社BANDAI SPIRITS 東京都港区''';

List<String> ids(List<OcrCandidate> c) => [for (final x in c) x.kit.id];

void main() {
  group('글자 고치기', () {
    test('전각 → 반각 · 줄표 · 로마 숫자 · 가타카나 장음', () {
      expect(normalizeOcr('ＨＧ １／１４４ ＲＸ－７８－２'), 'HG 1/144 RX-78-2');
      expect(normalizeOcr('RX—78ー2'), 'RX-78-2'); // OCR 이 하이픈을 장음 · 긴 줄표로
      expect(normalizeOcr('ザクⅡ改'), 'ザクII改');
      expect(foldKey('サザビ一'), foldKey('サザビー')); // 장음을 한자 一 로 읽어도
      expect(foldKey('ガンダム・エアリアル'), 'ガンダムエアリアル');
      expect(foldKey('RX-78-2'), 'rx782');
    });

    test('JAN 검사 숫자', () {
      expect(validEan('4573102630308'), isTrue);
      expect(validEan('4573102630309'), isFalse);
      expect(validEan('4934054065004'), isTrue);
    });
  });

  group('조각 뽑기', () {
    test('상자 앞면: 등급 · 축척 · 형식번호 · 이름, 회사 · 경고 · 저작권은 버림', () {
      final t = extractOcrTokens(aerialBox);
      final byKind = {for (final x in t) x.toString()};
      expect(byKind, containsAll(['grade:HG', 'scale:1/144', 'model:XVX-016', 'word:ガンダム・エアリアル', 'word:水星の魔女']));
      expect(t.where((x) => x.kind == OcrKind.grade).single.group, 'HG');
      expect(t.map((x) => x.label), isNot(contains(contains('BANDAI'))));
      expect(t.map((x) => x.label), isNot(contains(contains('15'))));
      expect(t.map((x) => x.label), isNot(contains(contains('サンライズ'))));
    });

    test('등급 묶음: REAL GRADE · RG → RG, HGUC → HG', () {
      final t = extractOcrTokens('REAL GRADE\nHGUC 1/144');
      expect(
        {
          for (final x in t)
            if (x.kind == OcrKind.grade) x.group,
        },
        {'RG', 'HG'},
      );
    });

    test('스크린숏: 시각 · 배터리 · 가격 · 가게 버튼은 지우고 전각 이름은 고친다', () {
      final t = extractOcrTokens(pbandaiShot);
      expect(t.map((x) => x.toString()), ['grade:HG', 'scale:1/144', 'word:ガンダムエアリアル', 'word:改修型']);
    });

    test('중고 장터 (한국어): 가격 · 미개봉 · 채팅은 버린다', () {
      final t = extractOcrTokens(bunjangShot);
      expect(t.map((x) => x.toString()), ['grade:HG', 'word:에어리얼', 'word:건담']);
    });

    test('JAN: 띄어 쓴 바코드 숫자 · 검사 숫자가 틀리면 버림', () {
      expect(extractOcrTokens(janBack).map((x) => x.toString()), ['jan:4573102630308']);
      expect(extractOcrTokens('4 573102 630309').where((x) => x.kind == OcrKind.jan), isEmpty);
    });

    test('베이블레이드: BX 번호 · 라쳇 비트 · 이름', () {
      final t = extractOcrTokens(bx01Box);
      expect(t.map((x) => x.toString()), containsAll(['bbx:BX-01', 'bbx:3-60F', 'word:ドランソード']));
      expect(t.map((x) => x.label), isNot(contains(contains('1,980'))));
    });

    test('형식번호 무늬: ZGMF-X10A · GN-001 · RX-0 · MS-06S, 숫자뿐 · 날짜는 아님', () {
      final t = extractOcrTokens('ZGMF-X10A GN-001 RX-0 MS-06S 2024-05 VER-2');
      expect(
        [
          for (final x in t)
            if (x.kind == OcrKind.model) x.label,
        ],
        ['ZGMF-X10A', 'GN-001', 'RX-0', 'MS-06S'],
      );
    });
  });

  group('후보 고르기', () {
    final index = OcrIndex(catalog);

    test('상자 앞면 → HG 에어리얼이 첫째, 개수형 · 다른 상품은 아래', () {
      final c = index.lookUp(extractOcrTokens(aerialBox));
      expect(c.first.kit.id, 'hg-hg-1-144-4573102630308000');
      expect(c.first.score, greaterThanOrEqualTo(85));
      expect(c.first.reason, contains('1/144'));
      expect(c.first.exact, isFalse); // JAN 이 아니면 100% 가 아니다
      expect(c.first.score, lessThan(100));
      // 이름만 짧게 맞는 옛 키트(1/144 건담)는 낮게
      final plain = c.where((x) => x.kit.id == 'ng-1-144-4902425086590000').firstOrNull;
      expect(plain == null || plain.score < 50, isTrue);
    });

    test('RG 상자 → RG 사자비, HGUC · MG 는 등급 · 축척이 달라 아래', () {
      final c = index.lookUp(extractOcrTokens(sazabiBox));
      expect(c.first.kit.id, 'rg-rg-1-144-4549660303633000');
      final hg = c.firstWhere((x) => x.kit.id == 'hg-hguc-1-144-4543112544995000', orElse: () => c.last);
      expect(hg.score, lessThan(c.first.score));
    });

    test('스크린숏의 "(改修型)" → 개수형이 첫째', () {
      final c = index.lookUp(extractOcrTokens(pbandaiShot));
      expect(c.first.kit.id, 'hg-hg-1-144-4573102650962000');
      expect(c.first.score, greaterThan(c[1].score));
    });

    test('베이: 같은 드란소드 3-60F 라도 BX 번호가 다르면 크게 깎는다', () {
      final c = index.lookUp(extractOcrTokens(bx01Box));
      expect(c.first.kit.id, 'beyblade-x-bx01');
      final bx22 = c.where((x) => x.kit.id == 'beyblade-x-bx22').firstOrNull;
      expect(bx22 == null || bx22.score < c.first.score / 2, isTrue);
    });

    test('한국어 글: 기체 별명 표(에어리얼 → エアリアル)로 일본어 이름도 맞춘다', () {
      final c = index.lookUp(extractOcrTokens(bunjangShot));
      expect(c.first.kit.id, 'hg-hg-1-144-4573102630308000');
      expect(c.first.reason, contains('エアリアル'));
    });

    test('JAN 이 같으면 100% (맨 앞)', () {
      final c = index.lookUp(extractOcrTokens('$janBack\nRG サザビー'));
      expect(c.first.kit.id, 'hg-hg-1-144-4573102630308000');
      expect(c.first.score, 100);
      expect(c.first.exact, isTrue);
      expect(c.first.reason, 'JAN 4573102630308');
    });

    test('조각을 끄면 후보가 바뀐다 (칩 누르기)', () {
      final t = extractOcrTokens('HG 1/144 ストライクフリーダムガンダム\nMG');
      final both = index.lookUp(t);
      final onlyMg = index.lookUp([
        for (final x in t)
          if (x.label != 'HG' && x.label != '1/144') x,
      ]);
      expect(both.first.kit.line, 'HG');
      expect(onlyMg.first.kit.line, 'MG');
    });

    test('아무것도 안 맞으면 빈 목록 (가짜 후보 없음)', () {
      expect(index.lookUp(extractOcrTokens('今日の天気は晴れです\nWEATHER')), isEmpty);
      expect(index.lookUp(const []), isEmpty);
    });

    test('건담 도감: 이름에 형식번호가 없어도 형식번호 ↔ 상품 연결로 찾는다', () {
      final ms = {
        'ms': [
          {
            'id': 'XVX-016 Gundam Aerial',
            'model_numbers': ['XVX-016'],
          },
          {'id': 'MSN-04 Sazabi'},
        ],
      };
      final km = {
        'links': {
          'hg-hg-1-144-4573102630308000': [
            {'ms': 'XVX-016 Gundam Aerial', 'role': 'main'},
          ],
          'rg-rg-1-144-4549660303633000': [
            {'ms': 'MSN-04 Sazabi', 'role': 'main'},
          ],
          'hg-hg-1-144-4573102650962000': [
            {'ms': 'XVX-016 Gundam Aerial', 'role': 'accessory_for'}, // 부품 연결은 안 셈
          ],
        },
      };
      final models = atlasModelIndex(ms, km);
      expect(models['xvx016'], ['hg-hg-1-144-4573102630308000']);
      expect(models['msn04'], ['rg-rg-1-144-4549660303633000']); // MS id 앞의 형식번호
      final withAtlas = OcrIndex(catalog, models: models);
      final c = withAtlas.lookUp(extractOcrTokens('XVX-016\nHG 1/144'));
      expect(c.first.kit.id, 'hg-hg-1-144-4573102630308000');
      expect(c.first.reason, contains('XVX-016'));
      // 도감이 없으면 형식번호만으로는 후보가 없다
      expect(index.lookUp(extractOcrTokens('XVX-016\nHG 1/144')), isEmpty);
    });

    test('같은 상품 목록이면 찾기 표를 다시 만들지 않는다', () {
      final a = OcrIndex.of(catalog);
      expect(identical(OcrIndex.of(catalog), a), isTrue);
      expect(identical(OcrIndex.of([...catalog.reversed]), a), isFalse);
    });

    test('찾기 표는 화면 언어와 상관없이 한국어 · 일본어 · 중국어 이름을 다 넣는다 (중국어 화면에서 한국어 상자 글자)', () {
      addTearDown(() => L10n.debugSet(AppLang.ko));
      Kit named(String id, Map<String, String> names) => Kit(
        id: id,
        franchiseId: 'gundam',
        name: names['ko']!,
        nameJa: names['ja']!,
        nameZh: names['zh']!,
        series: '',
        line: 'HG',
        type: '프라모델',
        scale: '1/144',
        universe: '',
        date: '',
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
      );
      final kits = [
        named('hg-hgce-1-144-4549660094272000', {
          'ko': 'HGCE 1/144 스트라이크 프리덤건담',
          'ja': 'HGCE 1 / 144 ストライクフリーダムガンダム',
          'zh': 'HGCE 1 / 144 强袭自由高达',
        }),
        named('hg-hguc-1-144-1-2-ver-gft-4543112934925000', {
          'ko': 'HGUC 1/144 유니콘 건담 1호기 & 2호기 Ver.GFT [스트라이크스 오다이바 세트]',
          'ja': 'HGUC 1 / 144 ユニコーンガンダム1号機&2号機 Ver.GFT [ストライクス オダイバセット]',
          'zh': 'HGUC 1 / 144 独角兽高达1号机&2号机 Ver.GFT [STRIKES 台场套装]',
        }),
      ];
      L10n.debugSet(AppLang.ko);
      final rowsKo = ocrRows(kits);
      final built = OcrIndex.of(kits);
      L10n.debugSet(AppLang.zh);
      expect(ocrRows(kits), rowsKo, reason: '언어를 바꿔도 같은 줄 → 지난 표를 다시 써도 된다');
      expect(identical(OcrIndex.of(kits), built), isTrue);
      for (final index in [built, OcrIndex(kits)]) {
        final ko = index.lookUp(extractOcrTokens('스트라이크 프리덤건담\n1/144'));
        expect(ko.first.kit.id, 'hg-hgce-1-144-4549660094272000');
        expect(ko.first.score, greaterThanOrEqualTo(80));
        final zh = index.lookUp(extractOcrTokens('强袭自由高达\nHGCE 1/144'));
        expect(zh.first.kit.id, 'hg-hgce-1-144-4549660094272000');
      }
    });
  });

  group('주소로 찾기', () {
    final urls = UrlIndex(catalog);

    test('주소 열쇠: https · www · 언어 칸 · 끝 / · 추적 값을 뗀다', () {
      expect(
        urlKey('https://www.goodsmile.com/ja/product/1145956/?utm_source=x'),
        urlKey('https://goodsmile.com/en/product/1145956'),
      );
      expect(
        urlKey('https://www.bandaispirits.co.jp/products/search/detail.php?grp_id=1&prd_id=4573102630308000'),
        urlKey('https://www.bandaispirits.co.jp/products/search/detail.php?prd_id=4573102630308000'),
      );
      expect(urlKey('not a url'), '');
      expect(isListingUrl('https://beyblade.takaratomy.co.jp/beyblade-x/lineup/'), isTrue);
      expect(isListingUrl('https://www.bandaispirits.co.jp/products/search/detail.php?prd_id=1'), isFalse);
    });

    test('출처 주소와 같으면 그 상품 (프리미엄 반다이 · 베이 · 굿스마일)', () {
      expect(
        urls.find('https://p-bandai.jp/item/item-1000188677/?spec=pc').single.kit.id,
        'hg-hg-1-144-4573102630308000',
      );
      expect(
        urls.find('https://beyblade.takaratomy.co.jp/beyblade-x/lineup/bx01.html').single.kit.id,
        'beyblade-x-bx01',
      );
      expect(urls.find('https://www.goodsmile.com/ja/product/1145956').single.how, '주소');
    });

    test('주소 안 JAN → 바코드가 같은 상품 (가샤폰 · 코토부키야 · 반다이 스피리츠)', () {
      final h = urls.find('https://gashapon.jp/products/detail.php?jan_code=4573102650962000');
      expect(h.single.kit.id, 'hg-hg-1-144-4573102650962000');
      expect(h.single.how, 'JAN 4573102650962');
      expect(urls.find('https://shop.kotobukiya.co.jp/shop/g/g4934054065004/').single.kit.id, 'acvi-4934054065004');
    });

    test('가게 앱의 공유 글 (이름 + 주소) 안에서 주소를 찾는다', () {
      const shared = 'HG 1/144 ガンダムエアリアル | プレミアムバンダイ https://p-bandai.jp/item/item-1000188677/';
      expect(urlsIn(shared), ['https://p-bandai.jp/item/item-1000188677/']);
      expect(urls.findInText(shared).single.kit.id, 'hg-hg-1-144-4573102630308000');
      expect(urls.findInText('https://example.com/nothing'), isEmpty);
      // 주소를 못 찾으면 글자 조각으로 (아마존처럼 짧은 주소 + 제목)
      const amazon = 'Amazon.co.jp: BANDAI SPIRITS HG 1/144 ガンダムエアリアル : ホビー https://amzn.asia/d/abc123';
      expect(urls.findInText(amazon), isEmpty);
      expect(OcrIndex(catalog).lookUp(extractOcrTokens(amazon)).first.kit.id, 'hg-hg-1-144-4573102630308000');
    });
  });

  group('공유로 받은 것', () {
    test('MainActivity 가 보낸 모양 → 사진 · 글 (모르는 것은 null)', () {
      final img = sharedItemFrom({'type': 'image', 'path': '/cache/a.png'});
      expect((img! as SharedImage).path, '/cache/a.png');
      final text = sharedItemFrom({'type': 'text', 'text': ' HG エアリアル https://p-bandai.jp/item/item-1/ '});
      expect((text! as SharedText).text, startsWith('HG'));
      expect(sharedItemFrom(null), isNull);
      expect(sharedItemFrom({'type': 'video', 'path': '/x.mp4'}), isNull);
      expect(sharedItemFrom({'type': 'text', 'text': '  '}), isNull);
    });

    test('공유로 켜졌을 때 처음 것("initial") · 켜져 있을 때 온 것("shared") → incoming', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(shareChannel, (call) async {
        if (call.method == 'initial') return {'type': 'text', 'text': 'RG サザビー'};
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(shareChannel, null));
      ShareIntake.instance.debugReset();
      final got = <SharedItem>[];
      void listen() {
        final v = ShareIntake.instance.incoming.value;
        if (v != null) got.add(v);
      }

      ShareIntake.instance.incoming.addListener(listen);
      await ShareIntake.instance.start();
      // 안드로이드 → Flutter: 켜져 있을 때 온 공유
      await messenger.handlePlatformMessage(
        shareChannel.name,
        shareChannel.codec.encodeMethodCall(const MethodCall('shared', {'type': 'image', 'path': '/cache/shot.png'})),
        (_) {},
      );
      ShareIntake.instance.incoming.removeListener(listen);
      expect(got.whereType<SharedText>().single.text, 'RG サザビー');
      expect(got.whereType<SharedImage>().single.path, '/cache/shot.png');
      expect(ShareIntake.instance.take(), isNotNull);
      expect(ShareIntake.instance.take(), isNull); // 꺼내면 비운다
    });
  });

  group('실제 데이터', () {
    final skip = dataDir.isEmpty || !Directory(dataDir).existsSync() ? 'GUNPULA_DATA 없음' : null;
    late List<Kit> kits;
    late OcrIndex index;

    setUpAll(() {
      if (skip != null) return;
      String read(String f) => File('$dataDir/$f').readAsStringSync();
      kits = [
        for (final f in franchiseIds)
          for (final j in mapKitsJob({
            'raw': read('split/kits-$f.json'),
            'grades': read('grades.json'),
            'firstSeen': read('kit-first-seen.json'),
          }))
            Kit.fromSlim(j, recentSince: '', monthPrefix: '2026-11'),
      ];
      final atlas = File('$dataDir/atlas/gundam-ms.json');
      final models = atlas.existsSync()
          ? atlasModelIndex(jsonDecode(atlas.readAsStringSync()), jsonDecode(read('atlas/gundam-kit-ms.json')))
          : const <String, List<String>>{};
      index = OcrIndex(kits, models: models);
    });

    test('상자 · 스크린숏 · 한국어 글 → 첫째 후보', () {
      expect(index.lookUp(extractOcrTokens(aerialBox)).first.kit.id, 'hg-hg-1-144-4573102630308000');
      expect(index.lookUp(extractOcrTokens(sazabiBox)).first.kit.line, 'RG');
      expect(index.lookUp(extractOcrTokens(bx01Box)).first.kit.id, 'beyblade-x-bx01');
      expect(index.lookUp(extractOcrTokens(pbandaiShot)).first.kit.id, 'hg-hg-1-144-4573102650962000');
      expect(index.lookUp(extractOcrTokens(bunjangShot)).first.kit.id, 'hg-hg-1-144-4573102630308000');
      expect(index.lookUp(extractOcrTokens(janBack)).single.score, 100);
    }, skip: skip);

    test('출처 주소 (매핑의 sourceUrls): 둘째 출처인 프리미엄 반다이 주소로도', () {
      final urls = UrlIndex(kits);
      expect(urls.find('https://p-bandai.jp/item/item-1000188677/').first.kit.id, 'hg-hg-1-144-4573102630308000');
      expect(kits.where((k) => k.sourceUrls.any(isListingUrl)), isEmpty);
    }, skip: skip);

    test('빠르기: 약 9천 개에서 한 번 찾기 < 200ms', () {
      final sw = Stopwatch()..start();
      for (final s in [aerialBox, sazabiBox, bx01Box, pbandaiShot, bunjangShot]) {
        index.lookUp(extractOcrTokens(s));
      }
      expect(sw.elapsedMilliseconds / 5, lessThan(200));
    }, skip: skip);
  });
}
