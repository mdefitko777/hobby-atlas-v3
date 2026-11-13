// 예약 시작 때 (announcements.json preorder_at · preorder_date · preorder_end_*) — 읽기 · 기기 시계로 본 단계(시간대 · 지난 시각) ·
// 꼬리표 글 · 상세 한 줄 · 캘린더 자리 · 이어진 상품 · 예약 시작 30분 전 알림 계획(알림 받는 예고 · 좋아요한 상품) ·
// 파일까지 한 바퀴 · 화면(예고 목록 · 상세 · 캘린더 · 홈 · 알림 페이지, 360dp · 중국어).
// 시각은 UTC 한 점으로 만든다 — 테스트 기계의 시간대가 달라도 같은 결과.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/api.dart';
import 'package:hobby_atlas/background/catalog_check_worker.dart';
import 'package:hobby_atlas/clock.dart';
import 'package:hobby_atlas/data/blob_store.dart';
import 'package:hobby_atlas/data/catalog.dart';
import 'package:hobby_atlas/data/derive.dart';
import 'package:hobby_atlas/data/user_store.dart';
import 'package:hobby_atlas/detail_pane.dart';
import 'package:hobby_atlas/l10n/l10n.dart';
import 'package:hobby_atlas/logic/announcement_match.dart';
import 'package:hobby_atlas/logic/live_stream.dart';
import 'package:hobby_atlas/logic/preorder_open.dart';
import 'package:hobby_atlas/marks.dart';
import 'package:hobby_atlas/models.dart';
import 'package:hobby_atlas/notifications/feed_rules.dart';
import 'package:hobby_atlas/notifications/live_reminders.dart';
import 'package:hobby_atlas/notifications/notify_models.dart';
import 'package:hobby_atlas/notifications/notify_store.dart';
import 'package:hobby_atlas/notifications/preorder_reminders.dart';
import 'package:hobby_atlas/screens/a_home_screen.dart';
import 'package:hobby_atlas/screens/h_calendar_screen.dart';
import 'package:hobby_atlas/screens/j_announcement_screen.dart';
import 'package:hobby_atlas/screens/k_notify_settings.dart';
import 'package:hobby_atlas/screens/o_see_all_screen.dart';
import 'package:hobby_atlas/theme.dart';
import 'package:hobby_atlas/widgets.dart';

import 'layout_test.dart' show fakeLoaders;

final _hangul = RegExp(r'[가-힣]');

/// 11/13 18:00 JST = 09:00 UTC (魂ウェブ キュリオス)
final _open = DateTime.utc(2026, 11, 13, 9);

/// Gunpula data/announcements.json 한 줄 (2026-11-14 shape.md 의 실제 줄)
Map<String, Object?> _kyrios({Map<String, Object?> extra = const {}}) => {
  'id': 'tamashii-news-2026-11-13-16258',
  'franchise': 'gundam',
  'names': {'ja': '【機動戦士ガンダム00】「ガンダムキュリオス」がMETAL BUILDに登場！魂ウェブ商店にて11/13 18時より予約受付開始！'},
  'status': 'preorder_open',
  'announced_at': '2026-11-13',
  'source_type': 'news',
  'source_name': '魂ウェブ',
  'source_url': 'https://tamashiiweb.com/item/16258/',
  'linked_kit_id': 'tamashii-16258',
  'preorder_at': '2026-11-13T18:00:00+09:00',
  'preorder_date': '2026-11-13',
  'preorder_basis': 'title',
  ...extra,
};

Announcement _ann(
  String id, {
  String status = '예약 시작',
  DateTime? at,
  String day = '',
  DateTime? endAt,
  String endDay = '',
  bool unofficial = false,
  String date = '2026-11-12',
  String title = '',
  bool hero = false,
  String linked = '',
}) => Announcement(
  id: id,
  franchiseId: 'gundam',
  title: title.isEmpty ? id : title,
  status: status,
  date: date,
  source: '魂ウェブ',
  image: '',
  hero: hero,
  unofficial: unofficial,
  preorderAt: at?.toLocal(),
  preorderDay: day,
  preorderEndAt: endAt?.toLocal(),
  preorderEndDay: endDay,
  linkedKitId: linked,
);

Future<void> _pump(WidgetTester tester, Widget home, {NotifyStore? notify, Size size = const Size(390, 844)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildGpTheme(),
      builder: (context, child) => NotifyScope(
        store: notify ?? NotifyStore.memory(),
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

void main() {
  tearDown(() {
    fixedNow = null;
    L10n.debugSet(AppLang.ko);
  });

  group('읽기', () {
    test('preorder_* · linked_kit_id → 모델 (+09:00 은 한 점), 홈 배너 · 화면 모델 JSON 에도 남는다', () {
      final a = announcementOf(
        _kyrios(extra: {'preorder_end_at': '2026-11-20T23:59:00+09:00', 'preorder_end_date': '2026-11-20'}),
      );
      expect(a.preorderAt!.toUtc(), _open);
      expect(a.preorderAt!.isUtc, isFalse, reason: '기기 시간대로');
      expect(a.preorderDay, '2026-11-13');
      expect(a.preorderEndAt!.toUtc(), DateTime.utc(2026, 11, 20, 14, 59));
      expect(a.preorderEndDay, '2026-11-20');
      expect(a.linkedKitId, 'tamashii-16258');
      expect(a.status, '예약 시작');
      expect(a.isStream, isFalse, reason: 'live_at 이 아니다 — 라이브로 보지 않는다');
      final hero = a.asHero();
      expect(
        (hero.preorderAt, hero.preorderDay, hero.preorderEndAt, hero.linkedKitId),
        (a.preorderAt, '2026-11-13', a.preorderEndAt, 'tamashii-16258'),
      );
      final back = Announcement.fromJson({
        'id': a.id,
        'preorderAt': '2026-11-13T18:00:00+09:00',
        'preorderDay': '2026-11-13',
        'linkedKitId': 'k',
      })!;
      expect((back.preorderAt!.toUtc(), back.preorderDay, back.linkedKitId), (_open, '2026-11-13', 'k'));
    });

    test('옛 파일(필드 없음) · 모양이 다른 값은 빈 값 → 예고 단계 그대로', () {
      final old = Map.of(_kyrios())
        ..remove('preorder_at')
        ..remove('preorder_date')
        ..remove('linked_kit_id');
      final a = announcementOf(old);
      expect((a.preorderAt, a.preorderDay, a.linkedKitId), (null, '', ''));
      expect(annPreorderStage(a, _open), isNull);
      expect(annShownDay(a), '2026-11-13');
      final bad = announcementOf(_kyrios(extra: {'preorder_at': '11/13 18時', 'preorder_date': '2026/11/13'}));
      expect((bad.preorderAt, bad.preorderDay), (null, ''));
    });

    test('합쳐진 옛 상품 id 는 남은 id 로', () {
      final before = Catalog.instance.aliases;
      addTearDown(() => Catalog.instance.aliases = before);
      Catalog.instance.aliases = {'tamashii-16258': 'tamashii-16258-new'};
      expect(announcementOf(_kyrios()).linkedKitId, 'tamashii-16258-new');
    });

    test('예약 줄은 라이브로 읽히지 않는다 (parseLiveStreams)', () {
      expect(
        parseLiveStreams({
          'announcements': [_kyrios()],
        }, _open),
        isEmpty,
      );
    });
  });

  group('단계는 기기 시계로', () {
    PreorderStage? stage(DateTime now, {String status = '예약 시작', DateTime? endAt, String endDay = ''}) =>
        preorderStageOf(status: status, now: now, at: _open, day: '2026-11-13', endAt: endAt, endDay: endDay);

    test('시작 전 · 시작 뒤 — 데이터가 아직 상품화 확정이어도 시각이 지났으면 예약 중', () {
      expect(stage(_open.subtract(const Duration(minutes: 1))), PreorderStage.upcoming);
      expect(stage(_open), PreorderStage.open);
      expect(stage(_open, status: '상품화 확정'), PreorderStage.open);
      expect(stage(_open.subtract(const Duration(hours: 1)), status: '상품화 확정'), PreorderStage.upcoming);
      expect(stage(_open, status: '발매'), isNull, reason: '발매된 예고는 발매 그대로');
      expect(
        preorderStageOf(status: '예약 시작', now: _open),
        isNull,
        reason: '예약 때를 모름',
      );
    });

    test('마감: 마감 시각이 지나면 · 마감일만 알면 그다음 일본 날짜부터', () {
      final end = DateTime.utc(2026, 11, 20, 14, 59); // 11/20 23:59 JST
      expect(stage(end.subtract(const Duration(seconds: 1)), endAt: end), PreorderStage.open);
      expect(stage(end, endAt: end), PreorderStage.closed);
      expect(stage(DateTime.utc(2026, 11, 20, 14, 59), endDay: '2026-11-20'), PreorderStage.open);
      expect(stage(DateTime.utc(2026, 11, 20, 15), endDay: '2026-11-20'), PreorderStage.closed); // 11/21 00:00 JST
    });

    test('날짜만 아는 예약: 그 전날까지 시작 전, 그날 00:00 부터 예약 중 (일본 날짜, 기기 시간대와 상관없이)', () {
      PreorderStage? dayOnly(DateTime now) => preorderStageOf(status: '예약 시작', now: now, day: '2026-11-20');
      expect(dayOnly(DateTime.utc(2026, 11, 19, 14, 59)), PreorderStage.upcoming); // 11/19 23:59 JST
      expect(dayOnly(DateTime.utc(2026, 11, 19, 15)), PreorderStage.open); // 11/20 00:00 JST
      expect(jstDay(DateTime.utc(2026, 11, 12, 15, 30)), '2026-11-13');
      expect(jstDay(DateTime.utc(2026, 11, 13, 14, 59)), '2026-11-13');
    });

    test('라이브 예고는 예약 단계를 보지 않는다', () {
      final live = Announcement(
        id: 'live',
        franchiseId: 'gundam',
        title: 'live',
        status: '예약 시작',
        date: '2026-11-12',
        source: '',
        image: '',
        hero: false,
        liveAt: _open,
        liveState: 'upcoming',
        preorderAt: _open,
      );
      expect(annPreorderStage(live, _open.subtract(const Duration(hours: 1))), isNull);
    });
  });

  group('꼬리표 글 · 상세 한 줄 · 예약 기간', () {
    // 11/13 10:00 KST 기기 — 오늘 · 내일 · 날짜
    final now = DateTime.utc(2026, 11, 13, 1);
    final today = _ann('a', at: _open, day: '2026-11-13');
    final tomorrow = _ann('b', at: DateTime.utc(2026, 11, 14, 3), day: '2026-11-14');
    final later = _ann('c', at: DateTime.utc(2026, 11, 20, 3), day: '2026-11-20');
    final dayOnly = _ann('d', day: '2026-11-20');
    final window = _ann(
      'e',
      at: DateTime.utc(2026, 11, 12, 3),
      day: '2026-11-12',
      endAt: DateTime(2026, 11, 30, 23, 59),
      endDay: '2026-11-30',
    );
    String label(Announcement a) => preorderLabel(a, annPreorderStage(a, now)!, now);

    test('시작 전: 예약 · 오늘 18:00 / 내일 / 11.20 12:00 / 시각을 모르면 11.20', () {
      expect(label(today), '예약 · 오늘 ${liveClock(_open.toLocal())}');
      expect(label(tomorrow), startsWith('예약 · 내일 '));
      expect(label(later), '예약 · 11.20 ${liveClock(later.preorderAt!)}');
      expect(label(dayOnly), '예약 · 11.20');
    });

    test('예약 중: 예약 시작 · 마감을 알면 ~11.30 23:59 마감 · 지나면 예약 마감', () {
      final opened = DateTime.utc(2026, 11, 13, 10);
      expect(preorderLabel(today, PreorderStage.open, opened), '예약 시작');
      // 23:59 마감은 날짜만 (꼬리표는 한 줄) · 다른 시각이면 시각까지
      expect(preorderLabel(window, annPreorderStage(window, opened)!, opened), '예약 시작 · ~11.30 마감');
      final at10 = _ann('g', day: '2026-11-12', endAt: DateTime.utc(2026, 11, 30, 1));
      expect(preorderLabel(at10, PreorderStage.open, opened), '예약 시작 · ~11.30 ${liveClock(at10.preorderEndAt!)} 마감');
      final dayEnd = _ann('f', day: '2026-11-12', endDay: '2026-11-30');
      expect(preorderLabel(dayEnd, PreorderStage.open, opened), '예약 시작 · ~11.30 마감');
      final after = DateTime.utc(2026, 12, 1);
      expect(annPreorderStage(window, after), PreorderStage.closed);
      expect(preorderLabel(window, PreorderStage.closed, after), '예약 마감');
    });

    test('상세 한 줄 · 상품 소개의 예약 기간 (늘 날짜)', () {
      final c = liveClock(_open.toLocal());
      expect(preorderLine(today, now), '예약 시작 11.13 $c');
      expect(preorderLine(dayOnly, now), '예약 시작 11.20');
      expect(
        preorderLine(window, now),
        '예약 시작 11.12 ${liveClock(window.preorderAt!)} · 마감 11.30 ${liveClock(window.preorderEndAt!)}',
      );
      expect(preorderLine(_ann('none'), now), '');
      expect(preorderPeriod(today), '2026.11.13 $c ~');
      expect(preorderPeriod(dayOnly), '2026.11.20 ~');
      expect(preorderPeriod(window), endsWith(' ~ 2026.11.30 ${liveClock(window.preorderEndAt!)}'));
      expect(preorderPeriod(_ann('none')), '');
    });

    test('중국어 화면', () {
      L10n.debugSet(AppLang.zh);
      expect(label(today), '预订 · 今天 ${liveClock(_open.toLocal())}');
      expect(label(dayOnly), '预订 · 11.20');
      final opened = DateTime.utc(2026, 11, 13, 10);
      expect(preorderLabel(today, PreorderStage.open, opened), '开始预订');
      expect(preorderLabel(window, PreorderStage.open, opened), '开始预订 · ~11.30 截止');
      expect(preorderLabel(window, PreorderStage.closed, opened), '预订截止');
      expect(preorderLine(window, now), startsWith('开始预订 11.12 '));
      expect(preorderLine(window, now), contains(' · 截止 11.30 '));
      for (final s in [label(today), preorderLine(window, now), preorderLabel(window, PreorderStage.open, opened)]) {
        expect(s, isNot(matches(_hangul)));
      }
    });

    test('보이는 날짜 · 캘린더 자리: 예약이 열리는 날 (발표일이 아니라), 발매된 예고 · 모르면 발표일', () {
      final eve = _ann('eve', at: _open, day: '2026-11-13', date: '2026-11-12');
      expect(annShownDay(eve), '2026-11-13');
      expect(announcementDay(eve), '2026-11-13');
      expect(announcementDay(_ann('d2', day: '2026-11-20')), '2026-11-20');
      expect(announcementDay(_ann('rel', status: '발매', day: '2026-11-20')), '2026-11-12');
      expect(announcementDay(_ann('none')), '2026-11-12');
    });
  });

  test('이 예고의 상품: 이어 둔 상품이 먼저 · 제목으로 찾은 상품은 한 번만', () {
    Kit kit(String id, String nameJa) =>
        Kit.fromJson({'id': id, 'franchiseId': 'gundam', 'name': nameJa, 'nameJa': nameJa})!;
    final kits = [
      kit('tamashii-16259', 'METAL BUILD ガンダムキュリオス 試作'),
      kit('tamashii-16258', 'METAL BUILD ガンダムキュリオス'),
      kit('other', 'HG ガンダムデュナメス'),
    ];
    final a = announcementOf(_kyrios());
    expect(annKits(a, kits).map((k) => k.id), ['tamashii-16258', 'tamashii-16259']);
    expect(annKits(_ann('x', title: '「ガンダムデュナメス」'), kits).map((k) => k.id), ['other']);
    expect(annKits(_ann('y', title: 'no brackets', linked: 'missing'), kits), isEmpty);
  });

  group('예약 시작 30분 전 알림 계획', () {
    final now = DateTime.utc(2026, 11, 13, 1); // 10:00 KST
    final file = {
      'announcements': [
        _kyrios(),
        // 좋아요한 상품의 PB 예약 (알림 받기는 안 누름)
        {
          'id': 'pbandai-1',
          'franchise': 'gundam',
          'names': {'ja': 'HG ジム・スナイパー【再販】'},
          'status': 'preorder_open',
          'announced_at': '2026-11-12',
          'source_name': 'プレミアムバンダイ',
          'linked_kit_id': 'pb-kit',
          'preorder_at': '2026-11-14T11:00:00+09:00',
        },
        // 날짜만 — 알리지 않는다
        {
          'id': 'day-only',
          'franchise': 'gundam',
          'names': {'ja': 'D'},
          'status': 'preorder_open',
          'announced_at': '2026-11-12',
          'preorder_date': '2026-11-20',
        },
        // 이미 지난 지 하루 넘음 · 발매 · 라이브
        {
          'id': 'old',
          'franchise': 'gundam',
          'names': {'ja': 'O'},
          'preorder_at': '2026-11-10T11:00:00+09:00',
        },
        {'id': 'rel', 'franchise': 'gundam', 'status': 'released', 'preorder_at': '2026-11-20T11:00:00+09:00'},
        {
          'id': 'live',
          'franchise': 'gundam',
          'live_at': '2026-11-20T21:00:00+09:00',
          'preorder_at': '2026-11-20T11:00:00+09:00',
        },
        // 비공식 — 「비공식 · 」
        {
          'id': 'fan-1',
          'franchise': 'pokemon',
          'names': {'ja': 'F', 'zh': 'F中'},
          'unofficial': true,
          'preorder_at': '2026-11-20T12:00:00+09:00',
        },
      ],
      'replaced': {'tamashii-reveal-0abb669c96': 'tamashii-news-2026-11-13-16258'},
    };
    final opens = parsePreorderOpens(file, now);
    LiveReminderPlan plan(
      Map<String, String> scheduled, {
      List<PreorderOpen>? list,
      DateTime? at,
      Set<String> followed = const {'tamashii-news-2026-11-13-16258', 'fan-1'},
      Set<String> wanted = const {'pb-kit'},
      bool enabled = true,
      String lang = 'ko',
    }) => planPreorderReminders(
      opens: list ?? opens,
      scheduled: scheduled,
      followed: followed,
      wanted: wanted,
      enabled: enabled,
      now: at ?? now,
      lang: lang,
    );

    test('읽기: 시각이 있는 예약만 (라이브 · 발매 · 하루 넘게 지난 것 · 날짜만은 빼고), 이어받은 옛 id 와 같이', () {
      expect(opens.map((o) => o.id), ['tamashii-news-2026-11-13-16258', 'pbandai-1', 'fan-1']);
      final k = opens.first;
      expect(k.at.toUtc(), _open);
      expect(k.kitId, 'tamashii-16258');
      expect(k.replaces, ['tamashii-reveal-0abb669c96']);
      expect(opens.last.unofficial, isTrue);
      final back = PreorderOpen.fromJson(jsonDecode(jsonEncode(k.toJson())))!;
      expect((back.at.toUtc(), back.kitId, back.source), (_open, k.kitId, '魂ウェブ'));
      expect(back.replaces, k.replaces);
      // 열린 뒤 하루까지는 들고 있다 (떠 있는 알림을 지우지 않게)
      expect(parsePreorderOpens(file, _open.add(const Duration(hours: 23))).map((o) => o.id), contains(k.id));
      expect(parsePreorderOpens(file, _open.add(const Duration(days: 1))).map((o) => o.id), isNot(contains(k.id)));
    });

    test('알림 받는 예고 · 좋아요한 상품의 예약을 30분 전에 (채널과 상관없이) — 예고 채널 · 누르면 그 예고', () {
      final p = plan(const {});
      expect(p.cancel, isEmpty);
      expect(p.schedule.map((r) => r.annId), ['tamashii-news-2026-11-13-16258', 'pbandai-1', 'fan-1']);
      final r = p.schedule.first;
      expect(r.at.toUtc(), _open.subtract(const Duration(minutes: 30)));
      expect(r.id, preorderReminderId(r.annId));
      expect(r.id, isNot(liveReminderId(r.annId)), reason: '라이브 알림 id 와 겹치지 않는다');
      expect(r.channel, 'ann');
      expect(r.payload, 'ann:gundam:tamashii-news-2026-11-13-16258');
      expect(r.title, '예약 ${liveClock(_open.toLocal())} 시작');
      expect(r.body, startsWith('【機動戦士ガンダム00】'));
      expect(r.body, endsWith(' · 魂ウェブ'));
      expect(p.schedule.last.title, startsWith('비공식 · 예약 '));
      // 이미 걸려 있으면 다시 걸지 않는다
      expect(plan(p.scheduled).isEmpty, isTrue);
    });

    test('누구: 알림 받기 안 누름 · 좋아요 아님 → 없음, 옛 id 로 누른 것은 이어받은 예고로', () {
      expect(plan(const {}, followed: const {}, wanted: const {}).schedule, isEmpty);
      final old = plan(const {}, followed: const {'tamashii-reveal-0abb669c96'}, wanted: const {});
      expect(old.schedule.single.annId, 'tamashii-news-2026-11-13-16258');
      expect(
        plan(const {}, followed: const {}, wanted: const {'tamashii-16258'}).schedule.single.annId,
        opens.first.id,
      );
    });

    test('좋아요를 바꾸면 바로 다시 계획할까: 아직 알릴 수 있는 예약의 상품이 들거나 빠질 때만', () {
      const kit = 'tamashii-16258';
      expect(preorderWantedTouched(opens, const {}, const {kit}, now), isTrue, reason: '좋아요를 누름');
      expect(preorderWantedTouched(opens, const {kit}, const {}, now), isTrue, reason: '좋아요를 뺌');
      expect(preorderWantedTouched(opens, const {}, const {'other'}, now), isFalse, reason: '예약과 상관없는 상품');
      expect(preorderWantedTouched(opens, const {kit}, const {kit, 'other'}, now), isFalse);
      // 알릴 시각(30분 전)이 지났으면 다시 계획해도 걸 것이 없다
      expect(preorderWantedTouched(opens, const {}, const {kit}, _open.subtract(const Duration(minutes: 20))), isFalse);
    });

    test('알림 받기를 바꾸면 바로 다시 계획할까: 예약 시각이 있는 예고 · 걸려 있는 것 · 아직 안 읽음만', () {
      const id = 'tamashii-news-2026-11-13-16258';
      bool touched(String annId, {Map<String, String> scheduled = const {}, bool read = true, DateTime? at}) =>
          preorderFollowTouched(opens, scheduled, annId, read: read, now: at ?? now);
      expect(touched(id), isTrue);
      expect(touched('tamashii-reveal-0abb669c96'), isTrue, reason: '옛 id 로 누름');
      expect(touched('no-time'), isFalse, reason: '예약 시각이 없는 예고 — 예고 파일을 받지 않는다');
      expect(touched('no-time', read: false), isTrue, reason: '아직 한 번도 안 읽음');
      expect(touched('gone', scheduled: {'gone': 'x'}), isTrue, reason: '걸려 있는 것을 거둔다');
      expect(touched(id, at: _open.subtract(const Duration(minutes: 20))), isFalse, reason: '알릴 시각이 지남');
    });

    test('시각이 바뀌면 다시 · 알림 받기를 끔 · 규칙 · 새 소식 알림을 끔 · 지난 시각 → 거둔다', () {
      final first = plan(const {});
      final id = preorderReminderId('tamashii-news-2026-11-13-16258');
      final later = _open.add(const Duration(hours: 1));
      final moved = plan(
        first.scheduled,
        list: [
          PreorderOpen(id: opens.first.id, franchise: 'gundam', title: 't', at: later.toLocal()),
          ...opens.skip(1),
        ],
      );
      expect(moved.schedule.single.id, id);
      expect(moved.schedule.single.at.toUtc(), later.subtract(const Duration(minutes: 30)));
      expect(plan(first.scheduled, followed: const {'fan-1'}).cancel, [id]);
      final off = plan(first.scheduled, enabled: false);
      expect(off.cancel, hasLength(3));
      expect(off.scheduled, isEmpty);
      // 알릴 시각이 지났으면 새로 걸지 않고, 걸린 것(이미 떴다)은 하루 동안 그대로
      expect(
        plan(const {}, at: _open.subtract(const Duration(minutes: 20))).schedule.map((r) => r.annId),
        isNot(contains(opens.first.id)),
      );
      final shown = plan(first.scheduled, at: _open.add(const Duration(hours: 2)));
      expect(shown.cancel, isEmpty);
      expect(shown.scheduled.keys, contains(opens.first.id));
      final gone = plan(
        first.scheduled,
        list: parsePreorderOpens(file, _open.add(const Duration(days: 2))),
        at: _open.add(const Duration(days: 2)),
      );
      expect(gone.cancel, contains(id));
    });

    test('planCheck: 규칙은 처음부터 켜짐 · 알림함 줄은 만들지 않는다 · 상태 파일에 남는다', () {
      final config = NotifyConfig(
        channels: const ['beyblade'],
        followed: {opens.first.id: const FollowedAnn(stage: 'preorder_open', title: 't', franchise: 'gundam')},
      );
      expect(config.rule(preorderRule), isTrue);
      final c = planCheck(
        config: config,
        state: NotifyState(liveKey: 'a1'),
        entries: const [],
        manifestSig: '',
        now: now,
        opens: opens,
      );
      expect(c.records, isEmpty);
      expect(c.preorderReminders.schedule.single.annId, opens.first.id);
      expect(c.allReminders.schedule.single.channel, 'ann');
      final state = NotifyState.fromJson(jsonDecode(jsonEncode(c.applyTo(NotifyState(liveKey: 'a1')).toJson())));
      expect(state.preorderRead, isTrue);
      expect(state.preorderOpens.map((o) => o.id), opens.map((o) => o.id));
      expect(state.preorderScheduled.keys, [opens.first.id]);
      // 빈 목록이어도 읽었다고 남는다 · 옛 상태 파일은 아직 안 읽음
      expect(NotifyState.fromJson(NotifyState(preorderRead: true).toJson()).preorderRead, isTrue);
      expect(NotifyState.fromJson(const {'live_key': 'a1'}).preorderRead, isFalse);
      // 규칙을 끄면 거둔다
      config.rules[preorderRule] = false;
      final off = planCheck(config: config, state: state, entries: const [], manifestSig: '', now: now);
      expect(off.preorderReminders.cancel, [preorderReminderId(opens.first.id)]);
    });

    test('규칙 이름 · 알림 페이지 자리 (한국어 · 중국어)', () {
      expect(notifyMineRules.indexOf(preorderRule), notifyMineRules.indexOf(liveRule) - 1, reason: '라이브 시작 전 바로 앞');
      expect(notifyInterestRules, contains(preorderRule));
      expect(notifyRuleLabel(preorderRule), '예약 시작 전');
      L10n.debugSet(AppLang.zh);
      expect(notifyRuleLabel(preorderRule), '预订开始前');
      expect(plan(const {}, lang: 'zh').schedule.first.title, '预订 ${liveClock(_open.toLocal())} 开始');
    });
  });

  group('파일까지 한 바퀴 (runCatalogCheck)', () {
    late Directory dir;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('preorder_test');
      BlobStore.debugDirectory = dir;
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('좋아요한 상품의 예약: 예고 파일을 받아 걸고 · 같은 파일은 다시 받지 않는다 · 이 기능 전 기기는 한 번 받는다', () async {
      // 라이브 규칙은 끔 — 예약 때문에만 받는지 본다
      final config = NotifyConfig(channels: const ['gundam'], wanted: {'tamashii-16258'}, rules: {liveRule: false});
      await BlobStore.write(notifyConfigKey, jsonEncode(config.toJson()));
      final body = jsonEncode({
        'announcements': [_kyrios()],
      });
      final hash = sha256.convert(utf8.encode(body)).toString().substring(0, 16);
      final asked = <String>[];
      Future<String?> fetch(String path) async {
        asked.add(path);
        return switch (path) {
          'data/split/manifest.json' => jsonEncode({
            'updated_at': '2026-11-13',
            'total': 100,
            'files': {'announcements.json': hash},
          }),
          announcementsPath => body,
          _ => null,
        };
      }

      final plans = <LiveReminderPlan>[];
      Future<Set<String>> apply(LiveReminderPlan p) async {
        plans.add(p);
        return const {};
      }

      Future<NotifyState> state() async => NotifyState.fromJson(jsonDecode((await BlobStore.read(notifyStateKey))!));
      final t0 = DateTime.utc(2026, 11, 13, 1);
      await runCatalogCheck(now: t0, fetch: fetch, applyLive: apply);
      expect(asked, contains(announcementsPath));
      final r = plans.single.schedule.single;
      expect((r.annId, r.channel), ('tamashii-news-2026-11-13-16258', 'ann'));
      var s = await state();
      expect(s.preorderScheduled.keys, ['tamashii-news-2026-11-13-16258']);
      expect(s.preorderRead, isTrue);

      asked.clear();
      await runCatalogCheck(now: t0.add(const Duration(minutes: 20)), fetch: fetch, applyLive: apply);
      expect(asked, isNot(contains(announcementsPath)));
      expect(plans.last.isEmpty, isTrue);

      // 이 기능 전 기기: 라이브가 지문을 적어 두었지만 예약은 아직 안 읽음 → 파일이 그대로여도 한 번 받는다
      await BlobStore.write(notifyStateKey, jsonEncode({'last_check_at': '2026-11-12T00:00:00Z', 'live_key': hash}));
      asked.clear();
      await runCatalogCheck(now: t0.add(const Duration(minutes: 40)), fetch: fetch, applyLive: apply);
      expect(asked, contains(announcementsPath));
      s = await state();
      expect(s.preorderScheduled.keys, ['tamashii-news-2026-11-13-16258']);
    });
  });

  group('화면', () {
    final now = DateTime.utc(2026, 11, 13, 1); // 10:00 KST
    const longTitle = '【機動戦士ガンダム00】「ガンダムキュリオス」がMETAL BUILDに登場！魂ウェブ商店にて11/13 18時より予約受付開始！';
    List<Announcement> anns() => [
      _ann('pre-today', at: _open, day: '2026-11-13', title: longTitle, hero: true),
      _ann('pre-day', day: '2026-11-20', title: longTitle, hero: true, unofficial: true),
      _ann(
        'pre-window',
        at: DateTime.utc(2026, 11, 12, 3),
        day: '2026-11-12',
        endAt: DateTime(2026, 11, 30, 23, 59),
        endDay: '2026-11-30',
        title: longTitle,
        unofficial: true,
      ),
      _ann('news', status: '공식 발표', date: '2026-11-13'),
    ];
    String clock(DateTime utc) => liveClock(utc.toLocal());

    testWidgets('예고 목록: 예약 꼬리표 (때 · 색) · 날짜는 열리는 날 — 360dp 에서 넘치지 않는다 (한국어 · 중국어)', (tester) async {
      fixedNow = now.toLocal();
      for (final lang in AppLang.values) {
        L10n.debugSet(lang);
        await _pump(
          tester,
          Scaffold(
            key: ValueKey(lang),
            body: SectionListView(title: '예고', announcements: anns(), loaders: const Loaders()),
          ),
          size: const Size(360, 1200),
        );
        expect(tester.takeException(), isNull);
        final zh = lang == AppLang.zh;
        final today = tester.widget<SoftTag>(find.byKey(const ValueKey('preorder-tag-pre-today')));
        expect(today.text, zh ? '预订 · 今天 ${clock(_open)}' : '예약 · 오늘 ${clock(_open)}');
        expect(today.color, Gp.accent);
        final day = tester.widget<SoftTag>(find.byKey(const ValueKey('preorder-tag-pre-day')));
        expect(day.text, zh ? '非官方 · 预订 · 11.20' : '비공식 · 예약 · 11.20');
        final window = tester.widget<SoftTag>(find.byKey(const ValueKey('preorder-tag-pre-window')));
        expect(window.color, Gp.own);
        expect(window.text, zh ? '非官方 · 开始预订 · ~11.30 截止' : '비공식 · 예약 시작 · ~11.30 마감');
        final r = tester.getRect(find.byKey(const ValueKey('preorder-tag-pre-window')));
        expect(r.right, lessThanOrEqualTo(360));
        expect(find.textContaining('2026.11.20'), findsOneWidget, reason: '발표일 11.12 가 아니라 예약이 열리는 날');
        expect(find.byKey(const ValueKey('preorder-tag-news')), findsNothing);
      }
    });

    testWidgets('지난 시각 · 마감: 시계가 지나면 「예약 시작」 · 「예약 마감」', (tester) async {
      fixedNow = DateTime.utc(2026, 12, 2).toLocal();
      await _pump(
        tester,
        Scaffold(
          body: SectionListView(title: '예고', announcements: anns(), loaders: const Loaders()),
        ),
      );
      expect(tester.widget<SoftTag>(find.byKey(const ValueKey('preorder-tag-pre-today'))).text, '예약 시작');
      final closed = tester.widget<SoftTag>(find.byKey(const ValueKey('preorder-tag-pre-window')));
      expect((closed.text, closed.color), ('비공식 · 예약 마감', Gp.muted));
    });

    testWidgets('예고 상세: 위 띠 꼬리표 · 「예약 시작 · 마감」 한 줄 (360dp, 한국어 · 중국어)', (tester) async {
      fixedNow = now.toLocal();
      for (final lang in AppLang.values) {
        L10n.debugSet(lang);
        for (final a in anns().take(3)) {
          await _pump(
            tester,
            AnnouncementScreen(key: ValueKey('$lang-${a.id}'), item: a, loaders: const Loaders()),
            size: const Size(360, 640),
          );
          expect(tester.takeException(), isNull, reason: '$lang ${a.id}');
          expect(find.byKey(ValueKey('preorder-tag-${a.id}')), findsOneWidget);
          final line = tester.widget<Text>(
            find.descendant(of: find.byKey(const ValueKey('preorder-line')), matching: find.byType(Text)),
          );
          expect(line.data, startsWith(lang == AppLang.zh ? '开始预订 ' : '예약 시작 '));
          if (a.id == 'pre-window') expect(line.data, contains(lang == AppLang.zh ? ' · 截止 11.30' : ' · 마감 11.30'));
        }
      }
      await _pump(tester, AnnouncementScreen(key: const ValueKey('news'), item: anns().last, loaders: const Loaders()));
      expect(find.byKey(const ValueKey('preorder-line')), findsNothing);
    });

    testWidgets('알림 받기: 30분 전 알림을 걸 수 있으면 그렇게 말한다', (tester) async {
      fixedNow = now.toLocal();
      final notify = NotifyStore.memory();
      await _pump(
        tester,
        AnnouncementScreen(item: anns().first, loaders: const Loaders()),
        notify: notify,
      );
      await tester.tap(find.byIcon(Icons.notifications_none));
      await tester.pump();
      expect(notify.isFollowing('pre-today'), isTrue);
      expect(find.text('예약 시작 30분쯤 전에 알려 드릴게요'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('캘린더: 예약은 열리는 날에 「18:00 예약 시작」 · 시각을 모르면 「예약 시작」 (한국어 · 중국어)', (tester) async {
      fixedNow = now.toLocal();
      final loaders = Loaders(kits: (_) async => const [], announcements: (_) async => anns());
      for (final lang in AppLang.values) {
        L10n.debugSet(lang);
        await _pump(
          tester,
          Scaffold(
            key: ValueKey(lang),
            body: CalendarScreen(myChannels: const ['gundam'], onMyChannelsChanged: (_) {}, loaders: loaders),
          ),
          size: const Size(360, 1400),
        );
        expect(tester.takeException(), isNull);
        final rows = {for (final r in tester.widgetList<ThumbRow>(find.byType(ThumbRow, skipOffstage: false))) r.id: r};
        final zh = lang == AppLang.zh;
        expect(rows['pre-today']!.tag, zh ? '${clock(_open)} 开始预订' : '${clock(_open)} 예약 시작');
        expect(rows['pre-today']!.tagColor, Gp.accent);
        expect(rows['pre-day']!.tag, zh ? '非官方 · 开始预订' : '비공식 · 예약 시작');
        // 20일 줄 머리 아래 (발표일 12일이 아니라)
        final y = tester.getTopLeft(find.byWidget(rows['pre-day']!, skipOffstage: false)).dy;
        expect(y, greaterThan(tester.getTopLeft(find.byWidget(rows['pre-today']!, skipOffstage: false)).dy));
      }
    });

    testWidgets('홈: 아직 안 열린 예약은 사진 위에 때 (360dp)', (tester) async {
      fixedNow = now.toLocal();
      await _pump(
        tester,
        Scaffold(
          body: HomeScreen(
            myChannels: const ['gundam'],
            onMyChannelsChanged: (_) {},
            onOpenSearch: () {},
            onCamera: () {},
            loaders: Loaders(kits: fakeLoaders.kits, announcements: (_) async => anns()),
          ),
        ),
        size: const Size(360, 640),
      );
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.byType(TagPill).first, 300, scrollable: find.byType(Scrollable).first);
      final pill = tester.widgetList<TagPill>(find.byKey(const ValueKey('preorder-tag-pre-today'))).last;
      expect(pill.text, '예약 · 오늘 ${clock(_open)}');
      expect(pill.filled, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('알림 페이지: 「예약 시작 전」 스위치는 라이브 바로 앞 (한국어 · 중국어)', (tester) async {
      for (final lang in AppLang.values) {
        L10n.debugSet(lang);
        final store = NotifyStore.memory();
        await _pump(
          tester,
          NotifySettingsScreen(key: ValueKey(lang), notify: store),
          size: const Size(390, 2000),
        );
        const key = Key('rule-preorder_soon');
        expect(tester.widget<SwitchListTile>(find.byKey(key)).value, isTrue);
        expect(find.descendant(of: find.byKey(key), matching: find.byIcon(Icons.alarm)), findsOneWidget);
        expect(
          tester.getTopLeft(find.byKey(key)).dy,
          lessThan(tester.getTopLeft(find.byKey(const Key('rule-live_soon'))).dy),
        );
        if (lang == AppLang.zh) {
          final texts = tester.widgetList<Text>(find.descendant(of: find.byKey(key), matching: find.byType(Text)));
          expect(texts.map((t) => t.data ?? ''), everyElement(isNot(matches(_hangul))));
        }
        await tester.tap(find.byKey(key));
        await tester.pump();
        expect(store.config.rule(preorderRule), isFalse);
        expect(tester.takeException(), isNull);
      }
    });
  });
}
