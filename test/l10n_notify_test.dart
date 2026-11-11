// 중국어 화면 — 알림 묶음: 휴대폰 알림 글 · 채널 이름 · 알림 화면 · 캘린더 도움말이 고른 언어를 따른다
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/clock.dart';
import 'package:hobby_atlas/data/catalog.dart';
import 'package:hobby_atlas/l10n/l10n.dart';
import 'package:hobby_atlas/notifications/feed_rules.dart';
import 'package:hobby_atlas/notifications/local_notifier.dart';
import 'package:hobby_atlas/notifications/notify_models.dart';
import 'package:hobby_atlas/notifications/notify_store.dart';
import 'package:hobby_atlas/screens/h_calendar_screen.dart' show calendarHelp;
import 'package:hobby_atlas/screens/n_notifications_screen.dart';
import 'package:hobby_atlas/screens/notify_condition_sheet.dart' show conditionLabel;

import 'notify_screen_test.dart' show loadersFor, pumpApp, records;

final _hangul = RegExp(r'[가-힣]');

void main() {
  fixedNow = DateTime(2026, 10, 25, 21); // 테스트 알림이 「오늘」 묶음에 들어가게 (notify_screen_test.dart 와 같은 날)
  test('중국어: 휴대폰 알림 제목 · 둘째 줄 · 채널 이름', () {
    addTearDown(() => L10n.debugSet(AppLang.ko));
    L10n.debugSet(AppLang.zh);
    final it = FeedItem.fromJson({
      'kit_id': 'rg-sazabi',
      'franchise': 'gundam',
      'names': {'ko': '사자비', 'zh': '沙扎比'},
      'change_reasons': ['price'],
      'price_jpy': 4950,
    }, 'changed')!;
    expect(it.name, '沙扎比'); // 이름도 중국어 먼저
    expect(itemBody(it, wanted: true), '喜欢的商品 · 价格变动 ¥4,950');
    expect(catalogSummaryTitle(added: 6, changed: 2), '新商品 6 个 · 变动 2 个');
    final alerts = buildAlerts([
      for (var i = 0; i < 4; i++)
        NoticeRecord(
          id: 'feed-2026-11-01-k$i',
          kind: 'changed',
          kitId: 'k$i',
          title: '商品$i',
          body: '',
          at: DateTime.utc(2026, 11, 1),
          wanted: true,
        ),
    ]);
    expect(alerts.single.title, '4 个喜欢的商品有变动');
    expect(alerts.single.body, '「商品0」 · 「商品1」 和另外 2 个');
    for (final c in LocalNotifier.channels.values) {
      expect('${c.name} ${c.description}', isNot(matches(_hangul)));
    }
    expect(LocalNotifier.channels['catalog']!.id, 'catalog_updates'); // id 는 그대로
    expect(notifyRuleLabel('restock'), '再贩');
    expect(notifyRuleLabels['restock'], '재판매', reason: '저장 · 비교 값은 한국어 그대로');
    expect([for (final h in calendarHelp) h.text], everyElement(isNot(matches(_hangul))));
  });

  testWidgets('중국어: 알림 화면 글 (모두 읽음 · 탭 · 날짜 묶음)', (tester) async {
    addTearDown(() => L10n.debugSet(AppLang.ko));
    L10n.debugSet(AppLang.zh);
    final store = NotifyStore.memory(records: records);
    await pumpApp(
      tester,
      NotificationsScreen(
        myChannels: const ['gundam', 'beyblade', 'pokemon'],
        loaders: loadersFor(store),
        notify: store,
      ),
    );
    expect(find.text('通知'), findsOneWidget);
    expect(find.text('全部已读'), findsOneWidget);
    expect(find.text('今天'), findsOneWidget);
    expect(find.text('모두 읽음'), findsNothing);
    expect(find.text('还没检查过'), findsOneWidget); // 확인 상태 줄
  });

  group('알림함 줄은 보일 때 화면 언어로 (만들 때 언어에 묶이지 않는다)', () {
    final feedItem = {
      'kit_id': 'rg-sazabi',
      'franchise': 'gundam',
      'names': {'ko': '사자비', 'zh': '沙扎比', 'ja': 'サザビー'},
      'series_labels': {'ko': '역습의 샤아', 'zh': '逆袭的夏亚'},
      'change_reasons': ['price'],
      'price_jpy': 4950,
    };
    final entry = FeedEntry(date: '2026-11-01', items: const [], generatedAt: DateTime.utc(2026, 11, 1));
    final config = NotifyConfig(
      wanted: {'rg-sazabi'},
      followed: {'a1': const FollowedAnn(stage: 'announced', title: 'MG 사자비', franchise: 'gundam')},
    );

    /// 알림함 파일에 쓰고 다시 읽은 줄 (notify_state.json 과 같은 길)
    NoticeRecord saved(NoticeRecord r) => NoticeRecord.fromJson(jsonDecode(jsonEncode(r.toJson())))!;

    NoticeRecord make() => saved(recordForItem(FeedItem.fromJson(feedItem, 'changed')!, entry, config)!);
    NoticeRecord ann() => saved(
      annStageRecords(
        config,
        {
          'announcements': [
            {'id': 'a1', 'status': 'preorder_open'},
          ],
        },
        const {},
        DateTime.utc(2026, 11, 1),
      ).single,
    );

    test('한국어 화면에서 만든 줄 → 중국어 화면', () {
      addTearDown(() => L10n.debugSet(AppLang.ko));
      L10n.debugSet(AppLang.ko);
      final r = make();
      final a = ann();
      expect(r.body, '좋아요한 상품 · 가격 변경 ¥4,950 · 역습의 샤아');
      expect(a.body, '공식 발표 → 예약 시작');
      L10n.debugSet(AppLang.zh);
      expect(r.title, '沙扎比');
      expect(r.body, '喜欢的商品 · 价格变动 ¥4,950 · 逆袭的夏亚');
      expect(a.body, '${tr('공식 발표')} → ${tr('예약 시작')}');
      expect(a.body, isNot(matches(_hangul)));
    });

    test('중국어 화면에서 만든 줄 → 한국어 화면', () {
      addTearDown(() => L10n.debugSet(AppLang.ko));
      L10n.debugSet(AppLang.zh);
      final r = make();
      expect(r.body, '喜欢的商品 · 价格变动 ¥4,950 · 逆袭的夏亚');
      L10n.debugSet(AppLang.ko);
      expect(r.title, '사자비');
      expect(r.body, '좋아요한 상품 · 가격 변경 ¥4,950 · 역습의 샤아');
      expect(r.toJson()['body'], '喜欢的商品 · 价格变动 ¥4,950 · 逆袭的夏亚', reason: 'body 칸은 만들 때 글 그대로 (옛 앱 · 옛 판)');
    });

    test('조각이 없는 옛 줄은 저장된 글 그대로', () {
      addTearDown(() => L10n.debugSet(AppLang.ko));
      final old = NoticeRecord.fromJson({
        'id': 'feed-2026-10-01-k',
        'kind': 'changed',
        'kit': 'k',
        'title': '사자비',
        'body': '좋아요한 상품 · 가격 변경 ¥4,950',
        'at': '2026-10-01T00:00:00Z',
      })!;
      L10n.debugSet(AppLang.zh);
      expect(old.title, '사자비');
      expect(old.body, '좋아요한 상품 · 가격 변경 ¥4,950');
    });

    test('피드 이름의 HTML 엔티티는 푼다 (Pok&eacute;mon)', () {
      final it = FeedItem.fromJson({
        'kit_id': 'pokemon-center-4521329427874',
        'franchise': 'pokemon',
        'names': {'zh': '785 毛绒玩偶 Pok&eacute;mon fit 卡璞・鸣鸣', 'ja': '785 ぬいぐるみ Pok&eacute;mon fit カプ・コケコ'},
      }, 'added')!;
      expect(it.nameZh, '785 毛绒玩偶 Pokémon fit 卡璞・鸣鸣');
      expect(it.nameKo, '785 ぬいぐるみ Pokémon fit カプ・コケコ');
    });
  });

  test('알림 조건의 묶음 이름은 보일 때 화면 언어로 (고를 때 언어로 적힌 옛 조건도)', () {
    addTearDown(() {
      L10n.debugSet(AppLang.ko);
      Catalog.instance.debugSet(slim: const [], aux: const {});
    });
    Catalog.instance.debugSet(
      slim: const [],
      aux: {
        'atlas-groups.json': {
          'franchises': {
            'pokemon': [
              {
                'id': 'gen1',
                'labels': {'zh': '宝可梦 红·绿', 'ko': '포켓몬스터 레드·그린', 'en': 'Pokémon Red & Blue'},
              },
            ],
          },
        },
      },
    );
    // 한국어 화면에서 고른 조건 · 중국어 화면에서 고른 옛 조건 (scope_label 이 중국어)
    final fromKo = NotifyCondition(franchise: 'pokemon', scope: 'group:gen1', scopeLabel: '포켓몬스터 레드·그린');
    final fromZh = NotifyCondition.fromJson({'franchise': 'pokemon', 'scope': 'group:gen1', 'scope_label': '宝可梦 红·绿'})!;
    L10n.debugSet(AppLang.ko);
    for (final x in [fromKo, fromZh]) {
      expect(conditionLabel(x), '포켓몬 · 포켓몬스터 레드·그린 · 전부');
    }
    L10n.debugSet(AppLang.zh);
    for (final x in [fromKo, fromZh]) {
      expect(conditionLabel(x), '${tr('포켓몬')} · 宝可梦 红·绿 · ${tr('전부')}');
    }
    // 묶음을 못 찾으면(파일 전 · 없어진 묶음) 적어 둔 이름
    final gone = NotifyCondition(franchise: 'pokemon', scope: 'group:gen99', scopeLabel: '포켓몬스터 옛 세대');
    expect(conditionLabel(gone), contains('포켓몬스터 옛 세대'));
    expect(
      conditionMatches(
        fromZh,
        FeedItem.fromJson({
          'kit_id': 'k',
          'franchise': 'pokemon',
          'groups': ['gen1'],
        }, 'added')!,
      ),
      isTrue,
    );
  });
}
