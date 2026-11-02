// 메자스타 · 프렌다 태그 도감 — 데이터 매핑(작은 fixtures) · 검색 · 가짐 저장 · 화면
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/data/blob_store.dart';
import 'package:hobby_atlas/data/frienda_images.dart';
import 'package:hobby_atlas/data/tag_atlas.dart';
import 'package:hobby_atlas/data/user_store.dart';
import 'package:hobby_atlas/detail_pane.dart';
import 'package:hobby_atlas/logic/frienda_page.dart';
import 'package:hobby_atlas/marks.dart';
import 'package:hobby_atlas/screens/b_search_screen.dart';
import 'package:hobby_atlas/screens/r_mezastar_screen.dart';
import 'package:hobby_atlas/theme.dart';

import 'layout_test.dart' show fakeLoaders;

Object? _fixture(String name) => jsonDecode(File('test/fixtures/$name').readAsStringSync());

final _files = {
  mezastarIntlFile: _fixture('mezastar-intl.sample.json'),
  mezastarJpFile: _fixture('mezastar-jp.sample.json'),
  friendaFile: _fixture('pokemon-frienda.sample.json'),
};

TagRegion _region(String id) => mezastarRegions.firstWhere((r) => r.id == id);

/// 화면 테스트용: 인터넷 그림 주소를 지운다 (테스트에서 네트워크 그림을 받지 않게)
Object? _noImages(Object? v) => switch (v) {
  final Map<String, Object?> m => {
    for (final e in m.entries)
      if (!e.key.startsWith('img') && e.key != 'dex') e.key: _noImages(e.value),
  },
  final List<Object?> l => [for (final x in l) _noImages(x)],
  _ => v,
};

/// 공식 페이지 모양만 흉내 낸 짧은 HTML (실제 페이지는 저장소에 넣지 않는다)
String _friendaHtml(String section, List<(String no, String file)> items) =>
    '<html><body><section class="x" id="$section"><h3>トレジャー</h3><ul>'
    '${items.map((i) => '<li class="grid__item is-vertical"><a href="#" data-img="img/${i.$2}.webp"><img src="img/${i.$2}_thumb.webp" alt=""></a><p>${i.$1}</p><p>이름</p></li>').join()}'
    '</ul></section></body></html>';

Future<void> _pump(WidgetTester tester, Widget home, UserStore store) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildGpTheme(),
      builder: (context, child) => MarksHost(
        store: store,
        child: PaneHost(child: child!),
      ),
      home: home,
    ),
  );
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  group('매핑', () {
    test('메자스타 한국: 한국 인쇄만 · 한국어 이름 · 번호 · 등급 · 썸네일', () {
      final b = parseMezastar(_files[mezastarIntlFile], _region('KR'));
      expect(b.cards.map((c) => c.id), [
        'mz-intl:R-1-1@KR:stardust-1',
        'mz-intl:1-1-001@KR',
        'mz-intl:1-1-002@KR',
        'mz-intl:1-1-003@KR',
      ]);
      expect(b.sets.map((s) => s.id), ['mz-intl:stardust-1']); // 한국에 안 나온 탄 · 프로모는 없음
      expect(b.sets.single.name, '스타더스트 1탄');
      expect(b.sets.single.date, '2026-04-13');
      expect(b.defaultSet, 'mz-intl:stardust-1');
      final mewtwo = b.cards[1];
      expect(mewtwo.name, '뮤츠');
      expect(mewtwo.local, '뮤츠');
      expect(mewtwo.number, '1-1-001');
      expect(mewtwo.grade, 6);
      expect(mewtwo.badge, '★6');
      expect(mewtwo.rarityLabel, '슈퍼스타');
      expect(mewtwo.types, ['Psychic']);
      expect(mewtwo.image, startsWith('https://pokemontagstar.co.kr/'));
      // 크게 볼 그림 = 앞 · 뒤 (썸네일 아님) + 공식 팝업 주소
      expect(mewtwo.large, [
        'https://pokemontagstar.co.kr/data/goodsImages/17760475689.png',
        'https://pokemontagstar.co.kr/data/goodsImages/177604756810.png',
      ]);
      expect(mewtwo.url, 'https://pokemontagstar.co.kr/kr/sub/stage_pop.php?idx=176');
      expect(b.cards.first.rarity, 'regular');
    });

    test('메자스타 대만 · 홍콩: 지역 이름 · 인쇄별 탄 · 프로모 코드', () {
      final tw = parseMezastar(_files[mezastarIntlFile], _region('TW'));
      expect(tw.sets.map((s) => s.name), ['스타더스트 1탄', '스타더스트 3탄']);
      expect(tw.sets.last.local, '星塵第３彈');
      expect(tw.defaultSet, 'mz-intl:stardust-3');
      // 같은 피카츄(R-1-1)가 탄마다 다른 인쇄
      expect(tw.inSet('mz-intl:stardust-3').map((c) => c.id), contains('mz-intl:R-1-1@TC:stardust-3'));
      expect(tw.inSet('mz-intl:stardust-1').map((c) => c.id), isNot(contains('mz-intl:R-1-1@TC:stardust-3')));
      expect(tw.cards.firstWhere((c) => c.id == 'mz-intl:1-1-001@TC').local, '超夢');

      final hk = parseMezastar(_files[mezastarIntlFile], _region('HK'));
      final promo = hk.cards.firstWhere((c) => c.id == 'mz-intl:P-B-001@EN');
      expect(promo.number, 'P (B-001)');
      expect(promo.badge, '프로모');
      expect(promo.name, '세레비');
      expect(promo.image, contains('official-artwork/251.png')); // 그림 없는 인쇄 = 도감 번호 그림
      expect(hk.set('mz-intl:promo')!.extra, isTrue);
      expect(hk.defaultSet, 'mz-intl:stardust-3'); // 프로모가 아닌 가장 새 탄
    });

    test('메자스타 일본: 같은 번호의 다른 판 · 프로모 번호 · 탄 이름', () {
      final jp = parseMezastar(_files[mezastarJpFile], _region('JP'));
      final pika = jp.cards.where((c) => c.tagId == 'mz-jp:1-056').toList();
      expect(pika.length, 2);
      expect(pika.last.variant, 'Get in Battle Free Trial Special Edition');
      expect(pika.first.image, endsWith('1-056_thumb.png'));
      expect(jp.cards.firstWhere((c) => c.tagId == 'mz-jp:P-001').number, 'P-001');
      expect(jp.sets.map((s) => s.name), ['1탄', '고저스스타 5탄', '프로모 태그']);
      expect(jp.sets.first.local, '1弾');
      expect(jp.defaultSet, 'mz-jp:gorgeousstar-5');
    });

    test('프렌다: 픽 id · 한국어 탄 이름 · 최신 탄 · 등급', () {
      final f = parseFrienda(_files[friendaFile]);
      expect(f.cards.length, 6);
      expect(f.defaultSet, 'frienda:xt2');
      expect(f.sets.map((s) => s.name), ['1탄', '엑스트레저 2탄', '스페셜 프렌다 픽']);
      expect(f.sets.last.extra, isTrue);
      final c = f.cards.first;
      expect(c.id, 'frienda:1-1-001');
      expect(c.name, '코라이돈');
      expect(c.local, 'コライドン');
      expect(c.rarityLabel, '슈퍼 트레저');
      expect(c.badge, '★5');
      expect(c.image, contains('official-artwork/1007.png'));
      expect(f.cards.last.number, 'P-130');
    });
  });

  group('검색', () {
    final books = [
      for (final r in mezastarRegions) parseMezastar(_files[r.file], r),
      parseFrienda(_files[friendaFile]),
    ];

    test('이름 (한국어 · 일본어 · 영어) · 번호', () {
      expect(searchTags(books, '뮤츠').map((c) => c.region), ['KR', 'HK', 'TW']);
      expect(searchTags(books, 'Mewtwo').length, 3);
      expect(searchTags(books, 'ミュウツー').length, 3);
      expect(searchTags(books, '4-5-001').single.id, 'mz-jp:4-5-001@JA');
      expect(searchTags(books, '코라이돈').single.game, TagGame.frienda);
      expect(searchTags(books, '없는이름'), isEmpty);
    });

    test('게임 이름: 그 게임 안에서만 · 이름만 쓰면 입구', () {
      expect(gameInQuery('메자스타'), (TagGame.mezastar, ''));
      expect(gameInQuery('MEZASTAR'), (TagGame.mezastar, ''));
      expect(gameInQuery('メザスタ'), (TagGame.mezastar, ''));
      expect(gameInQuery('tagstar'), (TagGame.mezastar, ''));
      expect(gameInQuery('프렌다'), (TagGame.frienda, ''));
      expect(gameInQuery('frienda'), (TagGame.frienda, ''));
      expect(gameInQuery('フレンダ'), (TagGame.frienda, ''));
      expect(gameInQuery('피카츄'), isNull);
      expect(searchTags(books, '메자스타'), isEmpty);
      expect(searchTags(books, '프렌다 코라이돈').single.id, 'frienda:1-1-001');
      expect(searchTags(books, '메자스타 자시안').map((c) => c.game).toSet(), {TagGame.mezastar});
    });
  });

  group('가짐 저장', () {
    test('UserStore: tag_owned 가 local_state 에 · 백업 가져오기로 돌아온다', () {
      final a = UserStore.memory()..setTagOwned('mz-intl:1-1-001@KR', true);
      a.setTagOwned('frienda:1-1-001', true);
      a.setTagOwned('frienda:1-1-001', false);
      final json = a.toJson();
      expect((json['local_state']! as Map)['tag_owned'], ['mz-intl:1-1-001@KR']);
      final p = ImportPreview.parse(jsonEncode(json), (_) => true);
      expect(p.tagOwned, {'mz-intl:1-1-001@KR'});
      expect(p.isEmpty, isFalse);
      final b = UserStore.memory()..applyImport(p);
      expect(b.tagOwned, {'mz-intl:1-1-001@KR'});
    });

    test('BlobStore: / 가 든 키 (aux_atlas/…) 도 쓰고 읽는다', () async {
      final dir = await Directory.systemTemp.createTemp('blob_tag_');
      addTearDown(() => dir.delete(recursive: true));
      BlobStore.debugDirectory = dir;
      expect(await BlobStore.write('aux_$mezastarJpFile', '{"a":1}'), isTrue);
      expect(await BlobStore.read('aux_$mezastarJpFile'), '{"a":1}');
      expect(dir.listSync().whereType<Directory>(), isEmpty); // 하위 폴더를 만들지 않는다
      await BlobStore.delete('aux_$mezastarJpFile');
      expect(await BlobStore.read('aux_$mezastarJpFile'), isNull);
    });
  });

  group('프렌다 그림 (기기에서 공식 페이지 읽기)', () {
    test('탄 페이지: 인쇄 번호 → id (전각 · ★ → S) · 원더 · 스페셜: 그림 이름 → id', () {
      final set = friendaPageImages(
        _friendaHtml('friendapick', [('1-1-001', '1-1-001_kira'), ('１-１-００２★', '1-1-002s'), ('なし', 'x')]),
        Uri.parse('https://pokemonfrienda.com/new/1.html'),
      );
      expect(set.keys, ['frienda:1-1-001', 'frienda:1-1-002S']);
      expect(set['frienda:1-1-001']!.full, 'https://pokemonfrienda.com/new/img/1-1-001_kira.webp');
      expect(set['frienda:1-1-001']!.thumb, 'https://pokemonfrienda.com/new/img/1-1-001_kira_thumb.webp');
      final special = friendaPageImages(
        _friendaHtml('specialfriendapick', [('P', 'p53-ab12'), ('W', '3-2-W01')]),
        Uri.parse('https://pokemonfrienda.com/new/special/'),
      );
      expect(special.keys, ['frienda:P-053', 'frienda:3-2-W01']);
      expect(friendaPageImages('<html></html>', Uri.parse('https://pokemonfrienda.com/')), isEmpty);
    });
  });

  group('화면', () {
    setUp(() {
      TagAtlas.source = (file) async => _noImages(_files[file]);
      FriendaImages.instance.debugReset();
      FriendaImages.fetch = (_) async => null; // 기본: 인터넷 없음 → 공식 아트워크
    });

    testWidgets('도감: 찾기가 칸을 거르고 · 칸을 누르면 가짐', (tester) async {
      final store = UserStore.memory();
      await _pump(tester, const TagAtlasScreen(game: TagGame.mezastar, region: 'KR'), store);
      expect(find.byType(TagCell), findsNWidgets(4)); // 스타더스트 1탄 (한국)
      expect(find.text('수집 0 / 4'), findsWidgets);

      await tester.enterText(find.byType(TextField), '뮤츠');
      await _settle(tester);
      expect(find.byType(TagCell), findsOneWidget);
      expect(find.text('1-1-001'), findsOneWidget);

      await tester.tap(find.byType(TagCell));
      await _settle(tester);
      expect(store.tagOwned, {'mz-intl:1-1-001@KR'});
      expect(find.text('수집 1 / 4'), findsWidgets);
      expect(tester.widget<TagCell>(find.byType(TagCell)).owned, isTrue);

      // 지역 → 대만 (가장 새 탄 = 스타더스트 3탄)
      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.text('TW'));
      await _settle(tester);
      expect(find.text('루기아'), findsOneWidget);
      expect(find.text('수집 0 / 7'), findsOneWidget); // 대만 전체 (앱 바)
      expect(tester.takeException(), isNull);
    });

    testWidgets('태그 시트: 그림을 누르면 앞 · 뒤 크게 보기 · 공식 페이지 버튼', (tester) async {
      // 인터넷 그림 대신 없는 앱 그림 경로 (자리표시로 그려진다)
      Object? local(Object? v) => switch (v) {
        final Map<String, Object?> m => {
          for (final e in m.entries) e.key: e.key.startsWith('img') ? 'assets/test/${e.key}.png' : local(e.value),
        },
        final List<Object?> l => [for (final x in l) local(x)],
        _ => v,
      };
      TagAtlas.source = (file) async => local(_files[file]);
      final store = UserStore.memory();
      await _pump(tester, const TagAtlasScreen(game: TagGame.mezastar, region: 'KR'), store);
      await tester.longPress(find.byType(TagCell).at(1));
      await _settle(tester);
      expect(find.byTooltip('공식 페이지'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tag-image')));
      await _settle(tester);
      expect(find.byKey(const ValueKey('image-viewer')), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget); // 앞 · 뒤
      await tester.drag(find.byKey(const ValueKey('image-viewer')), const Offset(-400, 0));
      await _settle(tester);
      expect(find.text('2 / 2'), findsOneWidget);
      expect(store.tagOwned, isEmpty); // 보기만, 가짐은 그대로
      expect(tester.takeException(), isNull);
    });

    testWidgets('프렌다: 탄을 열면 그 탄의 공식 페이지 한 장만 읽어 칸 · 크게 보기에 그림', (tester) async {
      final asked = <Uri>[];
      FriendaImages.fetch = (page) async {
        asked.add(page);
        return _friendaHtml('friendapick', [('3-2-001', '3-2-001'), ('3-2-002', '3-2-002')]);
      };
      await _pump(tester, const TagAtlasScreen(game: TagGame.frienda), UserStore.memory());
      expect(asked, [Uri.parse('https://pokemonfrienda.com/new/xt2.html')]); // 엑스트레저 2탄만, #friendapick 없이
      final cell = tester.widget<TagCell>(find.byType(TagCell).first);
      expect(cell.card.image, 'https://pokemonfrienda.com/new/img/${cell.card.number}_thumb.webp');
      expect(cell.card.large, ['https://pokemonfrienda.com/new/img/${cell.card.number}.webp']);
      expect(FriendaImages.instance.of('frienda:1-1-001'), isNull); // 다른 탄은 열 때
      // 같은 탄을 다시 그려도 다시 받지 않는다 (7일)
      await tester.tap(find.byTooltip('목록으로 보기'));
      await _settle(tester);
      expect(asked, hasLength(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('도감: 필터 · 목록 보기 · 프렌다', (tester) async {
      final store = UserStore.memory()..setTagOwned('frienda:3-2-001', true);
      await _pump(tester, const TagAtlasScreen(game: TagGame.frienda), store);
      expect(find.byType(TagCell), findsNWidgets(2)); // 엑스트레저 2탄
      expect(find.text('KR'), findsNothing); // 프렌다는 지역 고르기 없음
      await tester.tap(find.byTooltip('목록으로 보기'));
      await _settle(tester);
      expect(find.byType(TagCell), findsNothing);
      expect(find.text('아르세우스'), findsOneWidget);
      await tester.tap(find.byTooltip('필터'));
      await _settle(tester);
      await tester.tap(find.text('아직'));
      await _settle(tester);
      await tester.tap(find.text('1개 보기'));
      await _settle(tester);
      expect(find.text('아르세우스'), findsNothing);
      expect(find.text('디아루가'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('검색 탭: 태그 이름 · 번호가 맞으면 태그 줄 · 게임 이름이면 도감 입구', (tester) async {
      final store = UserStore.memory();
      await _pump(
        tester,
        Scaffold(
          body: SearchScreen(
            myChannels: const ['gundam', 'pokemon'],
            onMyChannelsChanged: (_) {},
            onCamera: () {},
            loaders: fakeLoaders,
          ),
        ),
        store,
      );
      await tester.enterText(find.byType(TextField).first, '뮤츠');
      await _settle(tester);
      expect(find.text('태그 · 픽'), findsOneWidget);
      expect(find.text('뮤츠  1-1-001'), findsNWidgets(3)); // KR · HK · TW
      await tester.tap(find.text('뮤츠  1-1-001').first);
      await _settle(tester);
      await tester.tap(find.text('가짐으로 표시'));
      await _settle(tester);
      expect(store.tagOwned, {'mz-intl:1-1-001@KR'});
      await tester.tapAt(const Offset(195, 40)); // 시트 닫기
      await _settle(tester);

      await tester.enterText(find.byType(TextField).first, '4-5-001');
      await _settle(tester);
      expect(find.text('버드렉스  4-5-001'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '메자스타');
      await _settle(tester);
      expect(find.text('MEZASTAR'), findsOneWidget);
      await tester.tap(find.text('MEZASTAR'));
      await _settle(tester);
      expect(find.byType(TagAtlasScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
