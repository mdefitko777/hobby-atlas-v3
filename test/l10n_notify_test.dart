// 중국어 화면 — 알림 묶음: 휴대폰 알림 글 · 채널 이름 · 알림 화면 · 캘린더 도움말이 고른 언어를 따른다
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/clock.dart';
import 'package:hobby_atlas/l10n/l10n.dart';
import 'package:hobby_atlas/notifications/feed_rules.dart';
import 'package:hobby_atlas/notifications/local_notifier.dart';
import 'package:hobby_atlas/notifications/notify_models.dart';
import 'package:hobby_atlas/notifications/notify_store.dart';
import 'package:hobby_atlas/screens/h_calendar_screen.dart' show calendarHelp;
import 'package:hobby_atlas/screens/n_notifications_screen.dart';

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
    expect(alerts.single.body, '「商品0」 · 「商品1」 还有 2 个');
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
}
