// 공식 예고 상세: 제목 「」 으로 상품 찾기 · 알림 받기(단계가 넘어가면 알림) · 요약 화면(웹 보기가 없을 때)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/api.dart';
import 'package:hobby_atlas/data/user_store.dart';
import 'package:hobby_atlas/detail_pane.dart';
import 'package:hobby_atlas/logic/announcement_match.dart';
import 'package:hobby_atlas/marks.dart';
import 'package:hobby_atlas/models.dart';
import 'package:hobby_atlas/notifications/feed_rules.dart';
import 'package:hobby_atlas/notifications/notify_models.dart';
import 'package:hobby_atlas/notifications/notify_store.dart';
import 'package:hobby_atlas/screens/j_announcement_screen.dart';
import 'package:hobby_atlas/theme.dart';

Kit _kit(String id, String nameJa, {String name = '', String date = '2026-12'}) =>
    Kit.fromJson({'id': id, 'franchiseId': 'gundam', 'name': name.isEmpty ? nameJa : name, 'nameJa': nameJa, 'date': date})!;

const _ann = Announcement(
  id: 'tamashii-news-2026-10-05-16191',
  franchiseId: 'gundam',
  title: '【機動戦士ガンダムSEED FREEDOM】「ブラックナイトスコードカルラ」がMETAL ROBOT魂に登場！',
  status: '상품화 확정',
  date: '2026-10-05',
  source: '魂ウェブ',
  image: '',
  hero: false,
  url: 'https://tamashiiweb.com/item/16191/',
);

void main() {
  group('제목 「」 → 상품', () {
    final kits = [
      _kit('a', 'METAL ROBOT魂 ＜SIDE MS＞ ブラックナイトスコード カルラ', date: '2027-03'),
      _kit('b', 'HG 1/144 ブラックナイトスコード カルラ', date: '2024-05'),
      _kit('c', 'HG 1/144 ライジングフリーダムガンダム'),
    ];

    test('띄어쓰기 · 전각 기호를 무시하고, 『작품』 은 쓰지 않는다 · 새것부터', () {
      expect(matchAnnouncementKits(_ann.title, kits).map((k) => k.id), ['a', 'b']);
    });

    test('「」 가 없거나 너무 짧으면 없음', () {
      expect(matchAnnouncementKits('『機動戦士ガンダムSEED FREEDOM』 新商品', kits), isEmpty);
      expect(matchAnnouncementKits('「HG」', kits), isEmpty);
    });

    test('전각 영숫자 → 반각', () {
      expect(foldName('ＸＡＲＸ－０ ＧＵＮＤＡＭ'), 'xarx0gundam');
      expect(matchAnnouncementKits('「XARX-0 GUNDAM ZERO」が登場', [_kit('z', 'GUNDAM UNIVERSE ＸＡＲＸ－０ ＧＵＮＤＡＭ ＺＥＲＯ')]), hasLength(1));
    });
  });

  group('알림 받기 → 단계가 넘어가면 알림함 줄', () {
    final now = DateTime.utc(2026, 11, 2, 9);
    final config = NotifyConfig(
      followed: {_ann.id: const FollowedAnn(stage: 'product_confirmed', title: 'カルラ', franchise: 'gundam')},
    );
    Map<String, Object?> file(String status) => {
      'announcements': [
        {'id': _ann.id, 'status': status},
      ],
    };

    test('같은 단계 · 뒤로 간 단계는 알리지 않는다', () {
      expect(annStageRecords(config, file('product_confirmed'), {}, now), isEmpty);
      expect(annStageRecords(config, file('announced'), {}, now), isEmpty);
    });

    test('예약 시작이 되면 한 줄 → 휴대폰 알림은 예고로 바로', () {
      final rs = annStageRecords(config, file('preorder_open'), {}, now);
      expect(rs, hasLength(1));
      final r = rs.single;
      expect(r.id, 'ann-${_ann.id}-preorder_open');
      expect(r.body, '상품화 확정 → 예약 시작');
      expect(r.channel, 'ann');
      expect(r.wanted, isTrue);
      final alerts = buildAlerts(rs);
      expect(alerts.single.payload, 'ann:gundam:${_ann.id}');
      expect(alerts.single.title, startsWith('예약 시작'));
      // 이미 알림함에 있으면 다시 만들지 않는다
      expect(annStageRecords(config, file('preorder_open'), {r.id}, now), isEmpty);
      // 저장했다 다시 읽어도 같은 줄
      expect(NoticeRecord.fromJson(r.toJson())!.annId, _ann.id);
    });

    test('planCheck 에 들어간다 · 설정 파일에 저장된다', () {
      final plan = planCheck(
        config: config,
        state: NotifyState(lastSeen: '2026-11-01'),
        entries: const [],
        manifestSig: '',
        now: now,
        announcements: file('released'),
      );
      expect(plan.records.map((r) => r.id), ['ann-${_ann.id}-released']);
      final back = NotifyConfig.fromJson(config.toJson());
      expect(back.followed[_ann.id]?.stage, 'product_confirmed');
    });
  });

  testWidgets('웹 보기가 없으면 요약 · 알림 받기 누르면 저장 · 이 예고 시트에 찾은 상품', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final notify = NotifyStore.memory();
    final loaders = Loaders(kits: (_) async => [_kit('a', 'METAL ROBOT魂 ブラックナイトスコード カルラ')]);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildGpTheme(),
        builder: (context, child) => NotifyScope(
          store: notify,
          child: MarksHost(store: UserStore.memory(), child: PaneHost(child: child!)),
        ),
        home: const SizedBox(),
      ),
    );
    openAnnouncement(tester.element(find.byType(SizedBox).first), _ann, loaders: loaders);
    await tester.pumpAndSettle();

    expect(articleViewSupported, isFalse); // 위젯 테스트에는 웹 보기가 없다
    expect(find.text('상품화 확정'), findsWidgets); // 위 띠 + 요약 단계 줄
    expect(find.text('이 예고 · 상품 1'), findsOneWidget);

    await tester.tap(find.text('알림 받기'));
    await tester.pump();
    expect(notify.isFollowing(_ann.id), isTrue);
    expect(notify.config.followed[_ann.id]?.stage, 'product_confirmed');
    expect(find.text('알림 받는 중'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));

    await tester.tap(find.text('이 예고 · 상품 1'));
    await tester.pumpAndSettle();
    expect(find.text('이 예고의 상품'), findsOneWidget);
    expect(find.text('METAL ROBOT魂 ブラックナイトスコード カルラ'), findsOneWidget);
  });
}
