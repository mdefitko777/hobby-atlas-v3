// 예고 상세의 「상품 소개」(J-8) — announcement-details.json 읽기(보일 것이 없으면 버튼 없음) · 버튼 하나로 펼치고 접기 ·
// 일본어 글 그대로(고를 수 있게) · 사진 누르면 크게 · 이 예고 시트에도 · 비공식은 늘 없음 · 360dp · 중국어 칸 이름.
// 위젯은 글자보다 Key · 타입으로 찾는다 (일본어 글은 데이터라 화면 언어와 상관없다).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/api.dart';
import 'package:hobby_atlas/clock.dart';
import 'package:hobby_atlas/data/announcement_details.dart';
import 'package:hobby_atlas/data/user_store.dart';
import 'package:hobby_atlas/detail_pane.dart';
import 'package:hobby_atlas/l10n/l10n.dart';
import 'package:hobby_atlas/marks.dart';
import 'package:hobby_atlas/models.dart';
import 'package:hobby_atlas/notifications/notify_store.dart';
import 'package:hobby_atlas/screens/j_announcement_screen.dart';
import 'package:hobby_atlas/theme.dart';
import 'package:hobby_atlas/widgets.dart';

final _hangul = RegExp(r'[가-힣]');

const _id = 'tamashii-news-2026-11-13-16258';

/// Gunpula data/announcement-details.json (2026-11-14 shape.md 의 실제 줄, 설명 · 구성품은 줄임)
final _file = <String, Object?>{
  'schema': 1,
  'updated_at': '2026-11-14T03:00:00.000Z',
  'extractor_version': 1,
  'details': {
    _id: {
      'page_url': 'https://tamashiiweb.com/item/16258/',
      'fetched_at': '2026-11-14',
      'extractor_version': 1,
      'lang': 'ja',
      'lead': 'メカデザイナー柳瀬敬之氏監修の下、決定版と言える造型＆彩色に飛行形態への変形機構を備えた初の合金完成品「ガンダムキュリオス」が登場。',
      'description': [
        '2027年に20周年を迎える『機動戦士ガンダム00』より「ガンダムキュリオス」がMETAL BUILD に登場！\n'
            '「GNアームズ」（別売り）と合体し、「GNアームズTYPE-K」（2026年12月予約開始予定）となる合体ギミックを搭載。',
      ],
      'spec': [
        {'label': '商品サイズ', 'value': '全高：約190mm'},
        {'label': '商品素材', 'value': 'ABS、ダイキャスト、PVC製'},
      ],
      'contents': ['本体', '交換用手首パーツ左右各4種', 'GNシールド', '専用台座一式'],
      'price_jpy': 38500,
      'price_text': '¥38,500（税込 / 送料・手数料別）',
      'sale_period_text': '2026年11月13日～',
      'sale_period_from': '2026-11-13',
      'sale_period_to': null,
      'release_kind': 'ship',
      'release_month': '2027-06',
      'release_text': '2027年6月発送予定',
      'sale_channel': '魂ウェブ商店販売商品',
      'gallery': [
        'https://tamashiiweb.com/storage/images/products/main/0d2428b1-21b4-41ab-9264-2d159613211f.webp',
        'https://tamashiiweb.com/storage/images/products/sub/85c2bce0-62f8-48aa-94d3-cae82d6b5718.webp',
        'https://d3bk8pkqsprcvh.cloudfront.net/x.jpg?Expires=1794590362&Signature=abc',
      ],
      'store_url': 'https://p-bandai.jp/item/item-1000258243/',
      'notes': ['※本商品の対象年齢は15才以上です。'],
      'error': null,
      'retry_after': null,
    },
    'tamashii-news-2026-05-01-99999': {
      'page_url': 'https://tamashiiweb.com/item/99999/',
      'fetched_at': '2026-11-14',
      'extractor_version': 1,
      'error': 'gone',
      'retry_after': '2026-12-14',
    },
  },
};

Announcement _ann({String id = _id, bool unofficial = false, String title = '', String linked = ''}) => Announcement(
  id: id,
  franchiseId: 'gundam',
  title: title.isEmpty ? '【機動戦士ガンダム00】「ガンダムキュリオス」がMETAL BUILDに登場！魂ウェブ商店にて11/13 18時より予約受付開始！' : title,
  status: '예약 시작',
  date: '2026-11-13',
  source: '魂ウェブ',
  image: '',
  hero: false,
  url: 'https://tamashiiweb.com/item/16258/',
  unofficial: unofficial,
  preorderAt: DateTime.utc(2026, 11, 13, 9).toLocal(),
  preorderDay: '2026-11-13',
  linkedKitId: linked,
);

const _toggle = ValueKey('ann-detail-toggle');
const _body = ValueKey('ann-detail-body');

Future<void> _pump(WidgetTester tester, Widget home, {Size size = const Size(390, 844)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildGpTheme(),
      builder: (context, child) => NotifyScope(
        store: NotifyStore.memory(),
        child: MarksHost(
          store: UserStore.memory(),
          child: PaneHost(child: child!),
        ),
      ),
      home: home,
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Loaders _loaders({List<Kit> kits = const []}) =>
    Loaders(kits: (_) async => kits, annDetails: () async => AnnDetail.parseFile(_file));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.tap(f);
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() => fixedNow = DateTime.utc(2026, 11, 14, 3).toLocal());
  tearDown(() {
    fixedNow = null;
    L10n.debugSet(AppLang.ko);
    BrokenImages.reset();
  });

  group('읽기', () {
    test('한 줄 → 모델: 글은 일본어 그대로 · 사양 (이름, 값) · 서명 붙은 사진 주소는 뺀다', () {
      final all = AnnDetail.parseFile(_file);
      expect(all.keys, [_id], reason: '읽기에 실패한 줄(error 만)은 버튼이 없다');
      final d = all[_id]!;
      expect(d.pageUrl, 'https://tamashiiweb.com/item/16258/');
      expect(d.lead, startsWith('メカデザイナー'));
      expect(d.description.single, contains('「GNアームズTYPE-K」（2026年12月予約開始予定）'));
      expect(d.description.single, contains('\n'), reason: '문단 안 줄바꿈은 그대로');
      expect(d.spec, [('商品サイズ', '全高：約190mm'), ('商品素材', 'ABS、ダイキャスト、PVC製')]);
      expect(d.contents, hasLength(4));
      expect(d.contents.first, '本体');
      expect((d.priceJpy, d.saleText, d.releaseKind, d.releaseMonth), (38500, '2026年11月13日～', 'ship', '2027-06'));
      expect(d.gallery, hasLength(2));
      expect(d.gallery.every((u) => u.startsWith('https://tamashiiweb.com/')), isTrue);
    });

    test('보일 것이 없으면 null — 맵이 아님 · 빈 글자뿐 · error 만, 내용이 있으면 error 가 있어도 보인다', () {
      expect(AnnDetail.fromJson('x'), isNull);
      expect(AnnDetail.fromJson(null), isNull);
      expect(
        AnnDetail.fromJson({
          'description': ['  '],
          'spec': [
            {'label': 'a', 'value': ''},
          ],
          'gallery': [],
        }),
        isNull,
      );
      expect(AnnDetail.fromJson({'error': 'gone'}), isNull);
      expect(AnnDetail.fromJson({'error': 'http 503', 'price_jpy': 33000})?.priceJpy, 33000);
      expect(AnnDetail.parseFile(null), isEmpty);
      expect(AnnDetail.parseFile({'details': 'x'}), isEmpty);
      // 상대 경로 사진은 전체 주소로
      expect(
        AnnDetail.fromJson({
          'gallery': ['./assets/a.jpg'],
        })!.gallery.single,
        startsWith('https://'),
      );
    });
  });

  group('화면 (웹 보기가 없는 위젯 테스트 = 요약 화면)', () {
    testWidgets('버튼 하나 — 누르면 그 자리에서 펼치고 · 다시 누르면 접는다', (tester) async {
      await _pump(tester, AnnouncementScreen(item: _ann(), loaders: _loaders()));
      expect(articleViewSupported, isFalse);
      expect(find.byKey(_toggle), findsOneWidget);
      expect(find.byKey(_body), findsNothing, reason: '처음엔 접혀 있다');

      await _tap(tester, find.byKey(_toggle));
      expect(find.byKey(_body), findsOneWidget);
      final body = find.byKey(_body);
      expect(find.descendant(of: body, matching: find.byType(SelectionArea)), findsOneWidget);
      expect(find.descendant(of: body, matching: find.byType(ImagePager)), findsOneWidget);
      expect(find.textContaining('GNアームズTYPE-K', skipOffstage: false), findsOneWidget);
      expect(find.text('全高：約190mm', skipOffstage: false), findsOneWidget);
      expect(find.text('・本体', skipOffstage: false), findsOneWidget);
      expect(find.text('¥38,500', skipOffstage: false), findsOneWidget);
      expect(find.text('2027.06', skipOffstage: false), findsOneWidget);
      // 예약 기간: 예고의 시각이 있으면 그것 (상품 페이지는 날짜만)
      expect(find.textContaining(RegExp(r'^2026\.11\.13 \d\d:\d\d ~$'), skipOffstage: false), findsOneWidget);
      expect(find.text('2026年11月13日～', skipOffstage: false), findsNothing);
      expect(find.byKey(const ValueKey('ann-detail-page'), skipOffstage: false), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _tap(tester, find.byKey(_toggle));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(_body), findsNothing);
    });

    testWidgets('상품 소개가 없는 예고 · 비공식 소식에는 버튼이 없다', (tester) async {
      await _pump(
        tester,
        AnnouncementScreen(
          key: const ValueKey('none'),
          item: _ann(id: 'other'),
          loaders: _loaders(),
        ),
      );
      expect(find.byKey(_toggle), findsNothing);
      await _pump(
        tester,
        AnnouncementScreen(key: const ValueKey('fan'), item: _ann(unofficial: true), loaders: _loaders()),
      );
      expect(find.byKey(_toggle), findsNothing);
      // 옛 Gunpula (파일 없음 · 404)
      await _pump(
        tester,
        AnnouncementScreen(
          key: const ValueKey('old'),
          item: _ann(),
          loaders: Loaders(kits: (_) async => const [], annDetails: () async => const {}),
        ),
      );
      expect(find.byKey(_toggle), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('사진을 누르면 크게 보기', (tester) async {
      await _pump(tester, AnnouncementScreen(item: _ann(), loaders: _loaders()));
      await _tap(tester, find.byKey(_toggle));
      await _tap(tester, find.descendant(of: find.byType(ImagePager), matching: find.byType(GestureDetector)).first);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ImageViewerScreen), findsOneWidget);
    });

    testWidgets('이 예고 시트에도 같은 버튼 · 이어진 상품이 「이 예고의 상품」에 (제목에 「」 이 없어도)', (tester) async {
      final kit = Kit.fromJson({
        'id': 'tamashii-16258',
        'franchiseId': 'gundam',
        'name': 'METAL BUILD 건담 큐리오스',
        'nameJa': 'METAL BUILD ガンダムキュリオス',
        'gallery': ['https://tamashiiweb.com/k1.webp'],
      })!;
      final item = _ann(title: 'METAL BUILD 新商品', linked: 'tamashii-16258');
      await _pump(
        tester,
        AnnouncementScreen(
          item: item,
          loaders: _loaders(kits: [kit]),
        ),
      );
      await _tap(tester, find.byIcon(Icons.info_outline));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(_toggle), findsNWidgets(2), reason: '요약 화면 + 이 예고 시트');
      expect(find.text('METAL BUILD 건담 큐리오스', skipOffstage: false), findsOneWidget);
      await _tap(tester, find.byKey(_toggle).last);
      expect(find.byKey(_body), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('360dp 에서 펼쳐도 넘치지 않는다 · 중국어 화면은 칸 이름만 중국어 (글은 일본어 그대로)', (tester) async {
      for (final lang in AppLang.values) {
        L10n.debugSet(lang);
        await _pump(
          tester,
          AnnouncementScreen(key: ValueKey(lang), item: _ann(), loaders: _loaders()),
          size: const Size(360, 640),
        );
        final label = tester.widget<ExpandRow>(find.byKey(_toggle)).title;
        expect(label, lang == AppLang.zh ? '商品介绍' : '상품 소개');
        await _tap(tester, find.byKey(_toggle));
        expect(tester.takeException(), isNull, reason: '$lang');
        if (lang == AppLang.zh) {
          final texts = tester.widgetList<Text>(
            find.descendant(of: find.byKey(_body), matching: find.byType(Text), skipOffstage: false),
          );
          expect(texts.map((t) => t.data ?? ''), everyElement(isNot(matches(_hangul))));
          expect(find.text('配件清单', skipOffstage: false), findsOneWidget);
          expect(find.text('规格', skipOffstage: false), findsOneWidget);
          expect(find.text('预计发货', skipOffstage: false), findsOneWidget);
        }
      }
    });
  });
}
