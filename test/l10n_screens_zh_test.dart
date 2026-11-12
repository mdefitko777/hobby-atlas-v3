// 중국어 화면 둘러보기 — 주요 화면을 중국어로 그리고, 툴팁 단추 · 밑줄 탭(· 몇 화면은 목록 줄 · 글자 단추)을 하나씩
// 눌러 열리는 시트 · 화면까지 보이는 글(Text · RichText · 툴팁)을 모아 한글이 남았나 본다.
// 남아도 되는 한글 = fixture 데이터(상품 · 친구 이름 …, 데이터에 한국어 이름만 있는 것)와 [_allowed] 뿐.
// sample-db.json 의 글 중 번역 표에 있는 것(종류 '프라모델' · 작품 '포켓몬' 등)은 화면에서 tr 을 거쳐야 하므로
// 데이터로 치지 않는다. 그 밖의 fixture(메자스타 · 베이 · 건담 도감 원본)는 자기 zh 칸이 따로 있어 통째로 데이터.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/api.dart';
import 'package:hobby_atlas/clock.dart';
import 'package:hobby_atlas/data/bbx_builder_data.dart';
import 'package:hobby_atlas/data/frienda_images.dart';
import 'package:hobby_atlas/data/tag_atlas.dart';
import 'package:hobby_atlas/data/user_store.dart';
import 'package:hobby_atlas/detail_pane.dart';
import 'package:hobby_atlas/l10n/l10n.dart';
import 'package:hobby_atlas/l10n/zh_text.dart';
import 'package:hobby_atlas/marks.dart';
import 'package:hobby_atlas/models.dart';
import 'package:hobby_atlas/notifications/notify_store.dart';
import 'package:hobby_atlas/screens/b_search_screen.dart';
import 'package:hobby_atlas/screens/c_channel_screen.dart';
import 'package:hobby_atlas/screens/d_kit_detail_screen.dart';
import 'package:hobby_atlas/screens/f_collection_screen.dart';
import 'package:hobby_atlas/screens/g_guide_view.dart';
import 'package:hobby_atlas/screens/h_calendar_screen.dart';
import 'package:hobby_atlas/screens/i_profile_screen.dart';
import 'package:hobby_atlas/screens/j_announcement_screen.dart';
import 'package:hobby_atlas/screens/k_notify_settings.dart';
import 'package:hobby_atlas/screens/k_settings_screen.dart';
import 'package:hobby_atlas/screens/l_friend_collection_screen.dart';
import 'package:hobby_atlas/screens/m_friends_drawer.dart';
import 'package:hobby_atlas/screens/n_notifications_screen.dart';
import 'package:hobby_atlas/screens/p_sign_in_screen.dart';
import 'package:hobby_atlas/screens/r_mezastar_screen.dart';
import 'package:hobby_atlas/screens/s_app_shell.dart';
import 'package:hobby_atlas/screens/t_bbx_builder_screen.dart';
import 'package:hobby_atlas/sync/account.dart';
import 'package:hobby_atlas/theme.dart';
import 'package:hobby_atlas/widgets.dart';

import 'layout_test.dart' show db, fakeLoaders;
import 'support/atlas_fixture.dart';
import 'support/fake_backend.dart';

final _hangul = RegExp(r'[가-힣]');
const _noHit = '없는검색어';

/// 눌러 보지 않는 툴팁 — 카메라 · 밖으로 나가는 링크 · 공유 (플러그인이 없는 테스트에서 멈춘다)
final _skipTips = {'찍어서 찾기', '공식 상품 페이지', '공유', '공유 카드', '사진 추가'}.map(tr).toSet();

/// 한글이 남아도 되는 화면 글
const _allowed = {
  '한국어', // 설정 › 언어 시트: 언어 이름은 그 언어로 (中文（简体） 과 짝)
};

/// fixture 파일들에 든 한국어 글 = 데이터 이름
Set<String> _fixtureData() {
  final out = <String>{};
  void walk(Object? v, {bool all = false}) {
    if (v is String) {
      if (_hangul.hasMatch(v) && (all || !zhText.containsKey(v))) out.add(v);
    } else if (v is Map) {
      v.forEach((k, e) {
        walk(k, all: all);
        walk(e, all: all);
      });
    } else if (v is List) {
      for (final e in v) {
        walk(e, all: all);
      }
    }
  }

  // 가짜 알림의 제목 · 본문은 이미 만들어진 글 (진짜 앱은 만들 때 tr — lib/notifications/feed_rules.dart)
  for (final n in db['notifications']! as List) {
    for (final v in [(n as Map)['title'], n['body']]) {
      if (v is String && _hangul.hasMatch(v)) out.add(v);
    }
  }
  for (final f in Directory('test/fixtures').listSync().whereType<File>()) {
    if (f.path.endsWith('.json')) walk(jsonDecode(f.readAsStringSync()), all: !f.path.endsWith('sample-db.json'));
  }
  for (final e in fixtureKits.values) {
    walk(e.first);
  }
  walk(['빵빵한빵디', '곰돌', '친구B', _noHit]); // 가짜 서버 이름 (아래 setUp) · 검색어
  return out;
}

/// 지금 그려진 글 전부 (화면 밖으로 밀린 탭 · 툴팁 포함)
Set<String> _strings(WidgetTester t) => {
  for (final w in t.allWidgets)
    if (w is Text)
      w.data ?? w.textSpan?.toPlainText() ?? ''
    else if (w is RichText)
      w.text.toPlainText()
    else if (w is Tooltip)
      w.message ?? w.richMessage?.toPlainText() ?? '',
};

void main() {
  fixedNow = DateTime(2026, 10, 25, 21);
  final data = _fixtureData().toList()..sort((a, b) => b.length.compareTo(a.length));
  final kits = (db['kits']! as List).map(Kit.fromJson).nonNulls.toList();
  final profile = Profile.fromJson(db['profile'])!;
  final seed = (db['guideWorks']! as List).map(GuideWork.fromJson).nonNulls.firstWhere((w) => w.id == 'w3000');
  final announcement = (db['announcements']! as List).map(Announcement.fromJson).nonNulls.first;
  final found = <String, Set<String>>{}; // 남은 한글 글 → 화면 (테스트 하나마다)

  /// 데이터 이름을 지우고도 한글이 남은 글
  String? leftover(String s) {
    if (!_hangul.hasMatch(s) || _allowed.contains(s)) return null;
    // 아바타 첫 글자 (데이터 이름의 첫 글자)
    if (s.length == 1 && data.any((d) => d.startsWith(s))) return null;
    var rest = s;
    for (final d in data) {
      if (rest.contains(d)) rest = rest.replaceAll(d, '');
    }
    return _hangul.hasMatch(rest) ? s : null;
  }

  late Account account;

  setUp(() {
    L10n.debugSet(AppLang.zh);
    addTearDown(() => L10n.debugSet(AppLang.ko));
    found.clear();
    addTearDown(() {
      final lines = [for (final e in found.entries) '${e.key}  ← ${e.value.take(3).join(', ')}']..sort();
      expect(lines, isEmpty, reason: '중국어 화면에 남은 한국어 — tr / trf 로 감싸고 lib/l10n/zh/ 에 번역을 넣는다');
    });
    final server = FakeServer(v2Payload: null, handle: 'bbang', displayName: '빵빵한빵디');
    server.users['gomdol'] = (name: '곰돌', collection: const {});
    server.users['friend_b'] = (name: '친구B', collection: const {});
    server.friends.add('gomdol');
    server.incoming.add('friend_b');
    account = Account(auth: FakeAuth(signedIn: true), rpc: server, store: UserStore.memory());
    addTearDown(account.dispose);
  });

  Future<void> settle(WidgetTester t, [int n = 6]) async {
    for (var i = 0; i < n; i++) {
      await t.pump(const Duration(milliseconds: 300));
    }
  }

  void snap(WidgetTester t, String screen) {
    for (final s in _strings(t)) {
      final l = leftover(s);
      if (l != null) (found[l] ??= {}).add(screen);
    }
  }

  Future<void> show(WidgetTester t, String screen, Widget home, {UserStore? store}) async {
    t.view.physicalSize = const Size(390, 2000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(const SizedBox()); // 앞 화면의 Navigator 를 비운다
    await t.pumpWidget(
      MaterialApp(
        theme: buildGpTheme(),
        locale: L10n.locale,
        builder: (context, child) => AccountScope(
          account: account,
          child: MarksHost(
            store: store ?? account.store,
            child: PaneHost(child: child!),
          ),
        ),
        home: home,
      ),
    );
    await settle(t);
    snap(t, screen);
  }

  Future<void> tap(WidgetTester t, String screen, Finder f) async {
    if (f.evaluate().isEmpty) return;
    await t.tap(f.first, warnIfMissed: false);
    await settle(t);
    snap(t, screen);
    t.takeException();
  }

  /// 화면을 그린 뒤, 툴팁 단추 · 밑줄 탭을 하나씩 (매번 새로 그린 화면에서) 눌러 본다.
  /// [rows] = 목록 줄 · 글자 단추도 하나씩 (설정 · 내 정보처럼 시트가 줄 뒤에 있는 화면)
  Future<void> explore(
    WidgetTester t,
    String screen,
    Widget Function() build, {
    UserStore? store,
    bool rows = false,
  }) async {
    await show(t, screen, build(), store: store);
    if (rows) {
      bool row(Widget w) => w is ListTile || w is TextButton || w is OutlinedButton || w is FilledButton;
      final n = t.allWidgets.where(row).length;
      for (var i = 0; i < n; i++) {
        await show(t, '$screen › 줄 $i', build(), store: store);
        final f = find.byWidgetPredicate(row);
        if (f.evaluate().length <= i) continue;
        // 데이터 새로 받기는 누르지 않는다 (인터넷에 닿으려 한다)
        if (find.descendant(of: f.at(i), matching: find.text(tr('지금 새로 받기'))).evaluate().isNotEmpty) continue;
        await tap(t, '$screen › 줄 $i', f.at(i));
      }
      await show(t, screen, build(), store: store);
    }
    final tips = {
      for (final w in t.allWidgets)
        if (w is Tooltip && w.message != null && !_skipTips.contains(w.message)) w.message!,
    };
    final tabs = {
      for (final w in t.allWidgets)
        if (w is UnderlineTab) w.label,
    };
    for (final tip in tips) {
      await show(t, '$screen › $tip', build(), store: store);
      await tap(t, '$screen › $tip', find.byTooltip(tip));
    }
    await show(t, screen, build(), store: store);
    for (final tab in tabs) {
      await tap(t, '$screen › $tab', find.byWidgetPredicate((w) => w is UnderlineTab && w.label == tab));
    }
  }

  const mine = ['gundam', 'beyblade', 'pokemon'];

  test('작품 이름에 zh 가 없으면 번역 표의 이름표로 (포켓몬 · 한정), 묶기 값은 그대로', () {
    final po = kits.firstWhere((k) => k.id == 'po19');
    expect((po.series, po.seriesLabel), ('포켓몬', '宝可梦'));
    expect(trData('없는 작품 이름'), '없는 작품 이름');
    L10n.debugSet(AppLang.ko);
    expect((po.seriesLabel, trData('한정')), ('포켓몬', '한정'));
  });

  testWidgets('앱 셸: 홈 · 검색 · 캘린더 · 컬렉션 · 친구 서랍', (t) async {
    await show(t, '홈', AppShell(loaders: fakeLoaders, notify: NotifyStore.memory()));
    for (final (name, icon) in [
      ('검색', Icons.search),
      ('캘린더', Icons.calendar_today_outlined),
      ('컬렉션', Icons.auto_awesome_mosaic_outlined),
    ]) {
      await tap(t, name, find.byIcon(icon).last);
    }
    await show(t, '홈', AppShell(loaders: fakeLoaders, notify: NotifyStore.memory()));
    await tap(t, '친구 서랍', find.byTooltip(tr('친구 · 내 정보')));
    await show(t, '홈', AppShell(loaders: fakeLoaders, notify: NotifyStore.memory()));
    await tap(t, '추가 시트', find.byIcon(Icons.photo_camera_outlined));
  });

  testWidgets('홈 (단추마다)', (t) async {
    await explore(t, '홈', () => AppShell(loaders: fakeLoaders, notify: NotifyStore.memory()));
  });

  Widget search() => Scaffold(
    body: SearchScreen(myChannels: mine, onMyChannelsChanged: (_) {}, onCamera: () {}, loaders: fakeLoaders),
  );

  testWidgets('검색: 탭 · 검색어 · 기체별 묶기 · 결과 없음', (t) async {
    await explore(t, '검색', search);
    for (final v in ['view-1', 'view-2']) {
      await tap(t, '검색 $v', find.byKey(ValueKey(v)));
    }
    await show(t, '검색', search());
    await t.enterText(find.byType(TextField), '스트라이크');
    await settle(t);
    snap(t, '검색어');
    await tap(t, '기체별 묶기', find.byKey(const ValueKey('group-toggle')));
    await t.enterText(find.byType(TextField), _noHit);
    await settle(t);
    snap(t, '검색 결과 없음');
    // 레고 채널: 둘러보기 줄 오른쪽 범위 · 그 시트
    await show(
      t,
      '검색 레고',
      Scaffold(
        body: SearchScreen(
          myChannels: const ['lego'],
          onMyChannelsChanged: (_) {},
          onCamera: () {},
          loaders: fakeLoaders,
        ),
      ),
    );
    await tap(t, '검색 레고', find.byWidgetPredicate((w) => w is UnderlineTab && w.label == tr('레고')));
    await tap(t, '레고 범위', find.byKey(const Key('lego-scope')));
  });

  testWidgets('상품 상세', (t) async {
    for (final id in ['gu02', 'gu12', 'be43', 'po19', 'fa34']) {
      final kit = kits.where((k) => k.id == id).firstOrNull ?? kits.first;
      await explore(t, '상세 $id', () => KitDetailScreen(kit: kit, loaders: fakeLoaders));
    }
  });

  testWidgets('설정 · 로그인', (t) async {
    await explore(t, '설정', () => SettingsScreen(notify: NotifyStore.memory()), rows: true);
    await explore(t, '알림 설정', () => NotifySettingsScreen(notify: NotifyStore.memory()), rows: true);
    await show(t, '도움말', const HelpScreen());
    await show(t, '로그인', const SignInScreen());
  });

  testWidgets('알림', (t) async {
    await explore(
      t,
      '알림',
      () => NotificationsScreen(myChannels: mine, loaders: fakeLoaders, notify: NotifyStore.memory()),
      rows: true,
    );
  });

  testWidgets('컬렉션 탭', (t) async {
    Widget build() => Scaffold(
      body: CollectionScreen(myChannels: mine, onMyChannelsChanged: (_) {}, onGoSearch: () {}, loaders: fakeLoaders),
    );
    await explore(t, '컬렉션', build);
    await show(t, '컬렉션', build());
    for (final k in ['tab-preorder', 'tab-owned', 'tab-guide']) {
      await tap(t, '컬렉션 $k', find.byKey(ValueKey(k)));
    }
  });

  testWidgets('캘린더', (t) async {
    await explore(
      t,
      '캘린더',
      () => Scaffold(
        body: CalendarScreen(myChannels: mine, onMyChannelsChanged: (_) {}, loaders: fakeLoaders),
      ),
    );
  });

  testWidgets('채널 고르기', (t) async {
    await show(t, '채널 고르기', ChannelManagerScreen(initial: mine, onChanged: (_) {}));
  });

  testWidgets('도감: 작품 도감 · 건담 도감 · 베이 도감', (t) async {
    await explore(t, '작품 도감', () => WorkGuideScreen(work: seed, loaders: fakeLoaders));
    loadAtlasFixture();
    for (final ch in ['gundam', 'beyblade', 'pokemon']) {
      await explore(
        t,
        '도감 $ch',
        () => Scaffold(
          body: GuideView(channel: ch, myChannels: mine, onPickChannel: (_) {}, loaders: fakeLoaders),
        ),
        store: UserStore.instance,
      );
    }
  });

  testWidgets('내 정보 · 친구 컬렉션 · 공고', (t) async {
    await explore(t, '내 정보', () => ProfileScreen(loaders: fakeLoaders, onJump: (_) {}), rows: true);
    await explore(t, '친구 컬렉션', () => FriendCollectionScreen(friend: profile.friends.first, loaders: fakeLoaders));
    await explore(t, '공고', () => AnnouncementScreen(item: announcement, loaders: fakeLoaders));
  });

  testWidgets('친구 서랍 (계정)', (t) async {
    await show(
      t,
      '친구 서랍',
      Scaffold(
        drawer: FriendsDrawer(loaders: fakeLoaders, onOpenProfile: () {}, onOpenFriend: (_) {}),
        body: Builder(
          builder: (c) => TextButton(onPressed: () => Scaffold.of(c).openDrawer(), child: const Text('open')),
        ),
      ),
    );
    await tap(t, '친구 서랍', find.text('open'));
    for (final w in [
      for (final w in t.allWidgets)
        if (w is Tooltip && w.message != null) w.message!,
    ]) {
      await tap(t, '친구 서랍 › $w', find.byTooltip(w));
    }
  });

  testWidgets('베이 조합 만들기', (t) async {
    final bbx = BbxBuilderData.fromJson(
      jsonDecode(File('test/fixtures/bbx-database.sample.json').readAsStringSync()) as Map<String, Object?>,
    );
    await explore(t, '베이 조합', () => BbxBuilderScreen(loaders: Loaders(bbxBuilder: () async => bbx)));
  });

  testWidgets('메자스타 · 프렌다 도감', (t) async {
    final files = {
      for (final f in [mezastarIntlFile, mezastarJpFile, friendaFile])
        f: jsonDecode(
          File('test/fixtures/${f.split('/').last.replaceAll('.json', '.sample.json')}').readAsStringSync(),
        ),
    };
    TagAtlas.source = (file) async => files[file];
    FriendaImages.instance.debugReset();
    FriendaImages.fetch = (_) async => null;
    await explore(t, '메자스타', () => const TagAtlasScreen(game: TagGame.mezastar, region: 'KR'));
    await explore(t, '메자스타 JP', () => const TagAtlasScreen(game: TagGame.mezastar, region: 'JP'));
    await explore(t, '프렌다', () => const TagAtlasScreen(game: TagGame.frienda));
  });
}
