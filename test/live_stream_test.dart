// 공식 라이브 — 기기 시계로 본 단계 · 꼬리표 글 · 예고 줄 세우기 · announcements.json 읽기 · 캘린더 자리 ·
// 시작 30분 전 알림 계획(걸기 · 다시 걸기 · 거두기) · 알림함 줄(처음 한 번만) · 규칙 스위치 · 중국어 화면.
// 시각은 기기 시간대로 만든다 (DateTime(…)) — 테스트 기계의 시간대가 달라도 같은 결과.
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
import 'package:hobby_atlas/logic/live_stream.dart';
import 'package:hobby_atlas/marks.dart';
import 'package:hobby_atlas/models.dart';
import 'package:hobby_atlas/notifications/feed_rules.dart';
import 'package:hobby_atlas/notifications/live_reminders.dart';
import 'package:hobby_atlas/notifications/notify_models.dart';
import 'package:hobby_atlas/notifications/notify_store.dart';
import 'package:hobby_atlas/screens/a_home_screen.dart';
import 'package:hobby_atlas/screens/h_calendar_screen.dart';
import 'package:hobby_atlas/screens/k_notify_settings.dart';
import 'package:hobby_atlas/screens/o_see_all_screen.dart';
import 'package:hobby_atlas/theme.dart';
import 'package:hobby_atlas/widgets.dart';

import 'layout_test.dart' show fakeLoaders;

final _hangul = RegExp(r'[가-힣]');

Announcement _ann(String id, {String date = '2026-11-12', DateTime? at, String state = '', String ch = 'gundam'}) =>
    Announcement(
      id: id,
      franchiseId: ch,
      title: id,
      status: '공식 발표',
      date: date,
      source: 'TAMASHII NATION 2026',
      image: '',
      hero: false,
      liveAt: at,
      liveState: state,
    );

/// Gunpula data/announcements.json 에서 잘라 낸 모양 (2026-11-12): 프리미엄 반다이 라이브 쇼핑 둘 · 유튜브 라이브 · 보통 뉴스
final _file = <String, Object?>{
  'announcements': [
    {
      'id': 'live-5b79e87f56',
      'franchise': 'gundam',
      'names': {'ja': 'TAMASHII NATION 2026 Live Stream from AKIHABARA DAY2', 'zh': null, 'ko': null},
      'status': 'announced',
      'announced_at': '2026-11-12',
      'source_type': 'news',
      'source_name': 'TAMASHII NATION 2026',
      'source_url': 'https://p-bandai.jp/contents/liveshopping20261114',
      'thumbnail_url': '../app/assets/announcements/live-5b79e87f56.webp',
      'video_id': null,
      'live_at': '2026-11-14T21:00:00+09:00',
      'live_state': 'upcoming',
    },
    {
      'id': 'live-ebd6d015a6',
      'franchise': 'gundam',
      'names': {'ja': 'TAMASHII NATION 2026 Live Stream from AKIHABARA DAY1'},
      'status': 'announced',
      'announced_at': '2026-11-12',
      'source_type': 'news',
      'source_name': 'TAMASHII NATION 2026',
      'source_url': 'https://p-bandai.jp/contents/liveshopping20261113',
      'thumbnail_url': '../app/assets/announcements/live-ebd6d015a6.webp',
      'live_at': '2026-11-13T21:00:00+09:00',
      'live_state': 'upcoming',
    },
    {
      'id': 'youtube-c3M7UKldpEA',
      'franchise': 'gundam',
      'names': {'ja': '教えて!ガンプラコンシェルジュ!! # 283'},
      'status': 'announced',
      'announced_at': '2026-11-07',
      'source_type': 'youtube',
      'source_name': 'THE GUNDAM BASE YouTube',
      'source_url': 'https://www.youtube.com/watch?v=c3M7UKldpEA',
      'thumbnail_url': '../app/assets/announcements/youtube-c3M7UKldpEA.jpg',
      'video_id': 'c3M7UKldpEA',
      'live_at': '2026-11-12T18:00:00+09:00',
      'live_state': 'upcoming', // 데이터는 아침에 적힌 값 — 저녁에는 기기 시계가 끝났다고 본다
    },
    {
      'id': 'gundam-official-i54a',
      'franchise': 'gundam',
      'names': {'ja': 'ROBOT魂 「シャイニングガンダム」 予約開始'},
      'status': 'preorder_open',
      'announced_at': '2026-11-12',
      'source_type': 'news',
      'source_name': 'GUNDAM.INFO',
      'source_url': 'https://gundam-official.com/news/i54a',
      'thumbnail_url': 'https://gundam-official.com/media/x.jpg',
    },
    {
      'id': 'live-pokemon',
      'franchise': 'pokemon',
      'names': {'ja': 'ポケモン生放送'},
      'status': 'announced',
      'announced_at': '2026-11-10',
      'source_type': 'youtube',
      'source_name': 'Pokémon YouTube',
      'live_at': null,
      'live_state': 'upcoming',
    },
  ],
};

/// DAY1 · DAY2 시작 (한 점 — 기기 시간대로 바꿔 쓴다)
final _day1 = DateTime.utc(2026, 11, 13, 12).toLocal();
final _day2 = DateTime.utc(2026, 11, 14, 12).toLocal();

Future<void> _pump(WidgetTester tester, Widget home, {NotifyStore? notify}) async {
  tester.view.physicalSize = const Size(390, 844);
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

  group('단계는 기기 시계로', () {
    final at = DateTime(2026, 11, 14, 21);
    LiveStage stage(String state, DateTime? at, DateTime now) => liveStageOf(state: state, at: at, now: now);

    test('시작 전 · 시작 ~ 2시간 · 2시간 뒤', () {
      expect(stage('upcoming', at, DateTime(2026, 11, 14, 20, 59)), LiveStage.upcoming);
      expect(stage('upcoming', at, at), LiveStage.live);
      expect(stage('upcoming', at, DateTime(2026, 11, 14, 22, 59)), LiveStage.live);
      expect(stage('upcoming', at, DateTime(2026, 11, 14, 23)), LiveStage.ended);
      // 데이터는 하루 한 번 — 며칠 묵은 upcoming · live 도 시계가 끝났다고 본다
      expect(stage('live', at, DateTime(2026, 11, 16)), LiveStage.ended);
    });

    test('데이터가 끝났다 · 하는 중이라고 하면 시각보다 먼저', () {
      expect(stage('ended', at, DateTime(2026, 11, 14, 20)), LiveStage.ended);
      expect(stage('live', at, DateTime(2026, 11, 14, 20, 50)), LiveStage.live); // 일찍 시작했다
    });

    test('시작 시각이 없으면 시간 미정 (끝난 것은 끝남)', () {
      final now = DateTime(2026, 11, 14);
      expect(stage('upcoming', null, now), LiveStage.undated);
      expect(stage('ended', null, now), LiveStage.ended);
      expect(stage('live', null, now), LiveStage.live);
    });

    test('live_at 은 기기 시간대의 한 점으로 읽는다', () {
      final t = parseLiveAt('2026-11-14T21:00:00+09:00')!;
      expect(t.isUtc, isFalse);
      expect(t.toUtc(), DateTime.utc(2026, 11, 14, 12));
      expect(parseLiveAt(null), isNull);
      expect(parseLiveAt(''), isNull);
      expect(parseLiveAt('곧'), isNull);
    });
  });

  group('꼬리표 글', () {
    final at = DateTime(2026, 11, 14, 21);
    String label(DateTime now, {String state = 'upcoming', DateTime? when}) {
      final t = when ?? at;
      return liveLabel(liveStageOf(state: state, at: t, now: now), t, now);
    }

    test('오늘 · 내일 · 그 밖은 날짜', () {
      expect(label(DateTime(2026, 11, 14, 9)), '라이브 · 오늘 21:00');
      expect(label(DateTime(2026, 11, 13, 23, 30)), '라이브 · 내일 21:00');
      expect(label(DateTime(2026, 11, 10)), '라이브 · 11/14 21:00');
      expect(label(DateTime(2026, 11, 14, 9), when: DateTime(2026, 11, 14, 9, 5)), '라이브 · 오늘 09:05');
    });

    test('하는 중 · 끝남 · 시간 미정', () {
      expect(label(DateTime(2026, 11, 14, 21, 30)), '라이브 중');
      expect(label(DateTime(2026, 11, 15)), '다시보기 · 11/14');
      expect(label(DateTime(2026, 11, 10), state: 'ended'), '다시보기 · 11/14');
      expect(liveLabel(LiveStage.undated, null, DateTime(2026, 11, 10)), '라이브 예정 · 시간 미정');
      expect(liveLabel(LiveStage.ended, null, DateTime(2026, 11, 10)), '다시보기');
    });

    test('중국어 화면', () {
      L10n.debugSet(AppLang.zh);
      expect(label(DateTime(2026, 11, 14, 9)), '直播 · 今天 21:00');
      expect(label(DateTime(2026, 11, 13, 9)), '直播 · 明天 21:00');
      expect(label(DateTime(2026, 11, 10)), '直播 · 11/14 21:00');
      expect(label(DateTime(2026, 11, 14, 21, 30)), '直播中');
      expect(label(DateTime(2026, 11, 15)), '回放 · 11/14');
      expect(liveLabel(LiveStage.undated, null, DateTime(2026, 11, 10)), '即将直播 · 时间未定');
    });
  });

  group('예고 줄 세우기 · 캘린더 자리', () {
    final now = DateTime(2026, 11, 13, 12);
    final list = [
      _ann('news-a'),
      _ann('ended', at: DateTime(2026, 11, 12, 10), state: 'ended'),
      _ann('day2', at: DateTime(2026, 11, 14, 21), state: 'upcoming'),
      _ann('undated', state: 'upcoming'),
      _ann('on-air', at: DateTime(2026, 11, 13, 11), state: 'upcoming'),
      _ann('day1', at: DateTime(2026, 11, 13, 21), state: 'upcoming'),
      _ann('news-b', date: '2026-11-01'),
    ];

    test('하는 중 · 곧 할 라이브가 맨 앞(시작 빠른 것부터) · 끝난 것 · 시간 미정 · 보통 예고는 받은 순서', () {
      expect(liveFirst(list, now).map((a) => a.id), ['on-air', 'day1', 'day2', 'news-a', 'ended', 'undated', 'news-b']);
      // 다 끝난 뒤에는 받은 순서 그대로
      expect(liveFirst(list, DateTime(2026, 11, 20)).map((a) => a.id), list.map((a) => a.id));
      // 같은 시각이면 받은 순서
      final same = [
        for (final id in ['b', 'a', 'c']) _ann(id, at: DateTime(2026, 11, 13, 21), state: 'upcoming'),
      ];
      expect(liveFirst(same, now).map((a) => a.id), ['b', 'a', 'c']);
    });

    test('캘린더: 라이브는 방송하는 날 · 시간 미정은 없음 · 보통 예고는 발표일', () {
      expect(announcementDay(list[0]), '2026-11-12');
      expect(announcementDay(list[2]), '2026-11-14'); // 발표는 11.12
      expect(announcementDay(list[3]), '');
      expect(liveClock(list[2].liveAt!), '21:00');
    });
  });

  group('announcements.json 읽기', () {
    setUp(() {
      Catalog.instance.debugSet(
        slim: [
          {'id': 'hg-1', 'franchiseId': 'gundam', 'name': 'HG', 'date': '2024'},
        ],
        // 빈 보조 파일도 같이 — 없으면 Catalog 가 인터넷에서 받으려 한다
        aux: {
          'announcements.json': _file,
          'kit-aliases.json': const <String, Object?>{},
          'exchange-rates.json': const <String, Object?>{},
          'atlas-groups.json': const <String, Object?>{},
        },
      );
    });
    tearDown(() => Catalog.instance.debugSet(slim: const [], aux: const {}));

    test('live_at · live_state → 모델, 유튜브는 video · 라이브 쇼핑은 원문 주소', () {
      final rows = [for (final m in _file['announcements']! as List) announcementOf(m as Map<String, Object?>)];
      final day2 = rows[0], yt = rows[2], news = rows[3], undated = rows[4];
      expect(day2.isStream, isTrue);
      expect(day2.liveAt, _day2);
      expect(day2.liveState, 'upcoming');
      expect(day2.video, '');
      expect(day2.url, 'https://p-bandai.jp/contents/liveshopping20261114');
      expect(yt.video, 'c3M7UKldpEA');
      expect(yt.liveAt!.toUtc(), DateTime.utc(2026, 11, 12, 9));
      expect(news.isStream, isFalse);
      expect(news.liveAt, isNull);
      expect(news.status, '예약 시작');
      expect(undated.isStream, isTrue);
      expect(undated.liveAt, isNull);
    });

    test('곧 할 라이브가 맨 앞 · 시계로 끝난 라이브는 발표일 순서로', () async {
      fixedNow = DateTime.utc(2026, 11, 13, 3).toLocal(); // DAY1 9시간 전, 유튜브 라이브는 어제 끝남
      final anns = await deriveAnnouncements(['gundam']);
      expect(anns.map((a) => a.id), [
        'live-ebd6d015a6',
        'live-5b79e87f56',
        'gundam-official-i54a',
        'youtube-c3M7UKldpEA',
      ]);
      expect(annLiveStage(anns[0], appNow()), LiveStage.upcoming);
      expect(annLiveStage(anns[3], appNow()), LiveStage.ended);
      expect(annLiveStage(anns[2], appNow()), isNull);
      expect(anns.every((a) => a.hero), isTrue, reason: '줄을 세운 뒤 앞에서부터 배너로');
      // 방송 중에는 그대로 맨 앞, 끝나면 뒤로
      fixedNow = _day1.add(const Duration(minutes: 30));
      expect((await deriveAnnouncements(['gundam'])).first.id, 'live-ebd6d015a6');
      fixedNow = _day1.add(const Duration(hours: 3));
      expect((await deriveAnnouncements(['gundam'])).first.id, 'live-5b79e87f56');
    });
  });

  group('시작 30분 전 알림 계획', () {
    final now = DateTime.utc(2026, 11, 13, 3).toLocal();
    final streams = parseLiveStreams(_file, now);
    const mine = ['gundam', 'beyblade'];
    LiveReminderPlan plan(
      Map<String, String> scheduled, {
      List<LiveStream>? list,
      DateTime? at,
      bool enabled = true,
      List<String> channels = mine,
      String lang = 'ko',
    }) => planLiveReminders(
      streams: list ?? streams,
      scheduled: scheduled,
      channels: channels,
      enabled: enabled,
      now: at ?? now,
      lang: lang,
    );
    LiveStream moved(LiveStream s, DateTime? at, {String state = 'upcoming'}) =>
        LiveStream(id: s.id, franchise: s.franchise, title: s.title, at: at, state: state, source: s.source);

    test('읽기: 아직 안 끝난 라이브만 (모든 채널)', () {
      expect(streams.map((s) => s.id), ['live-5b79e87f56', 'live-ebd6d015a6', 'live-pokemon']);
      expect(streams.first.at, _day2);
      expect(streams.first.source, 'TAMASHII NATION 2026');
      // 저장했다 다시 읽어도 같은 시각
      expect(LiveStream.fromJson(jsonDecode(jsonEncode(streams.first.toJson())))!.at, _day2);
    });

    test('내 채널의 시작 전 라이브를 30분 전에 — 시간 미정 · 다른 채널은 걸지 않는다', () {
      final p = plan(const {});
      expect(p.cancel, isEmpty);
      expect(p.schedule.map((r) => r.annId), ['live-5b79e87f56', 'live-ebd6d015a6']);
      final r = p.schedule.last;
      expect(r.at, _day1.subtract(const Duration(minutes: 30)));
      expect(r.id, liveReminderId('live-ebd6d015a6'));
      expect(r.id, isNot(p.schedule.first.id));
      expect(r.payload, 'ann:gundam:live-ebd6d015a6'); // 누르면 그 예고
      expect(r.title, '라이브 ${liveClock(_day1)} 시작');
      expect(r.body, 'TAMASHII NATION 2026 Live Stream from AKIHABARA DAY1 · TAMASHII NATION 2026');
      expect(p.scheduled.keys, ['live-5b79e87f56', 'live-ebd6d015a6']);
      // 이미 걸려 있으면 다시 걸지 않는다
      final again = plan(p.scheduled);
      expect(again.isEmpty, isTrue);
      expect(again.scheduled, p.scheduled);
    });

    test('시작 시각이 바뀌면 같은 id 로 다시 건다', () {
      final first = plan(const {});
      final later = _day1.add(const Duration(hours: 1));
      final p = plan(first.scheduled, list: [moved(streams[1], later), streams[0]]);
      expect(p.cancel, isEmpty);
      expect(p.schedule.single.id, liveReminderId('live-ebd6d015a6'));
      expect(p.schedule.single.at, later.subtract(const Duration(minutes: 30)));
      expect(p.scheduled['live-ebd6d015a6'], liveReminderSig(later, 'ko'));
    });

    test('사라짐 · 끝남 · 시간 미정이 됨 · 내 채널에서 빠짐 · 꺼짐 → 거둔다', () {
      final first = plan(const {});
      final day1 = liveReminderId('live-ebd6d015a6'), day2 = liveReminderId('live-5b79e87f56');
      expect(plan(first.scheduled, list: [streams[0]]).cancel, [day1]); // 목록에서 사라짐
      expect(
        plan(
          first.scheduled,
          list: [
            streams[0],
            moved(streams[1], _day1, state: 'ended'),
          ],
        ).cancel,
        [day1],
      );
      expect(plan(first.scheduled, list: [streams[0], moved(streams[1], null)]).cancel, [day1]);
      expect(plan(first.scheduled, at: _day1.add(const Duration(hours: 2))).cancel, [day1]); // 시계로 끝남
      final gone = plan(first.scheduled, channels: const ['pokemon']);
      expect(gone.cancel.toSet(), {day1, day2});
      expect(gone.schedule, isEmpty);
      expect(gone.scheduled, isEmpty);
      final off = plan(first.scheduled, enabled: false); // 새 소식 알림 · 규칙을 끔
      expect(off.cancel.toSet(), {day1, day2});
      expect(off.schedule, isEmpty);
      expect(off.scheduled, isEmpty);
    });

    test('지난 시각에는 걸지 않는다 · 이미 뜬 알림은 방송이 끝날 때까지 그대로', () {
      final soon = _day1.subtract(const Duration(minutes: 20)); // 알릴 시각이 10분 전에 지남
      expect(plan(const {}, at: soon).schedule.map((r) => r.annId), ['live-5b79e87f56']);
      expect(plan(const {}, at: _day1.subtract(const Duration(minutes: 30, seconds: 30))).schedule, hasLength(1));
      final first = plan(const {});
      for (final at in [soon, _day1.add(const Duration(minutes: 5))]) {
        final p = plan(first.scheduled, at: at);
        expect(p.isEmpty, isTrue, reason: '$at');
        expect(p.scheduled, first.scheduled);
      }
      // 시각이 당겨졌는데 새 알릴 시각이 이미 지났으면 옛 예약을 거둔다
      final pulled = plan(first.scheduled, list: [streams[0], moved(streams[1], now.add(const Duration(minutes: 10)))]);
      expect(pulled.cancel, [liveReminderId('live-ebd6d015a6')]);
      expect(pulled.schedule, isEmpty);
      expect(pulled.scheduled.keys, ['live-5b79e87f56']);
    });

    test('화면 언어를 바꾸면 새 언어로 다시 건다', () {
      final first = plan(const {});
      L10n.debugSet(AppLang.zh);
      final p = plan(first.scheduled, lang: 'zh');
      expect(p.cancel, isEmpty);
      expect(p.schedule, hasLength(2));
      expect(p.schedule.last.title, '直播 ${liveClock(_day1)} 开始');
      expect(p.schedule.last.title, isNot(matches(_hangul)));
    });
  });

  group('처음 보인 라이브 → 알림함 줄 (한 번만)', () {
    final now = DateTime.utc(2026, 11, 13, 3).toLocal();
    final config = NotifyConfig(channels: const ['gundam']);
    final streams = parseLiveStreams(_file, now);
    final seenBefore = NotifyState(liveKey: 'a1');

    test('라이브 예정 · 날짜 시각 — 누르면 그 예고', () {
      final plan = planCheck(
        config: config,
        state: seenBefore,
        entries: const [],
        manifestSig: '',
        now: now,
        streams: streams,
      );
      expect(plan.records.map((r) => r.id), ['stream-live-5b79e87f56', 'stream-live-ebd6d015a6']);
      final r = plan.records.last;
      expect(r.kind, 'live');
      expect(r.channel, 'live');
      expect(r.seen, isFalse);
      expect(r.body, '라이브 예정 · 11/${_day1.day} ${liveClock(_day1)} · TAMASHII NATION 2026');
      expect(NotifyState.isInboxId(r.id), isTrue);
      final alert = buildAlerts([r]).single;
      expect(alert.channel, 'live');
      expect(alert.title, '라이브 예정 · 11/${_day1.day} ${liveClock(_day1)}');
      expect(alert.body, 'TAMASHII NATION 2026 Live Stream from AKIHABARA DAY1');
      expect(alert.payload, 'ann:gundam:live-ebd6d015a6');
      final notice = noticeOf(NoticeRecord.fromJson(r.toJson())!, null);
      expect((notice.type, notice.annId, notice.franchiseId), (NoticeType.announce, 'live-ebd6d015a6', 'gundam'));
      // 시작 전 알림 계획도 같이
      expect(plan.reminders.schedule, hasLength(2));
      expect(plan.liveStreams, streams);
    });

    test('live_state 가 바뀌어도 · 알림함 줄이 지워져도 다시 알리지 않는다', () {
      final state = planCheck(
        config: config,
        state: seenBefore,
        entries: const [],
        manifestSig: '',
        now: now,
        streams: streams,
      ).applyTo(seenBefore);
      expect(state.liveStreams.map((s) => s.id), contains('live-ebd6d015a6'));
      final live = [
        for (final s in streams)
          LiveStream(id: s.id, franchise: s.franchise, title: s.title, at: s.at, state: 'live', source: s.source),
      ];
      final again = planCheck(
        config: config,
        state: state,
        entries: const [],
        manifestSig: '',
        now: now,
        streams: live,
      );
      expect(again.records, isEmpty);
      final pruned = NotifyState.fromJson(state.toJson())..inbox.clear();
      expect(
        planCheck(
          config: config,
          state: pruned,
          entries: const [],
          manifestSig: '',
          now: now,
          streams: streams,
        ).records,
        isEmpty,
      );
      // 저장 · 합치기에도 남는다
      final back = NotifyState.merge(NotifyState(), NotifyState.fromJson(jsonDecode(jsonEncode(state.toJson()))));
      expect(back.liveKey, 'a1');
      expect(back.liveScheduled.keys, state.liveScheduled.keys);
      expect(back.liveStreams.map((s) => s.at), state.liveStreams.map((s) => s.at));
    });

    test('처음 읽는 날은 조용히 · 규칙을 끄면 없음 · 시간 미정은 그렇게 적는다', () {
      final first = planCheck(
        config: config,
        state: NotifyState(),
        entries: const [],
        manifestSig: '',
        now: now,
        streams: streams,
      );
      expect(first.records, hasLength(2));
      expect(first.records.every((r) => r.seen), isTrue);
      expect(buildAlerts(first.records), isEmpty);

      final off = NotifyConfig(channels: const ['gundam'], rules: {liveRule: false});
      final p = planCheck(
        config: off,
        state: seenBefore,
        entries: const [],
        manifestSig: '',
        now: now,
        streams: streams,
      );
      expect(p.records, isEmpty);
      expect(p.reminders.schedule, isEmpty);
      // 새 소식 알림(휴대폰)만 끄면: 알림함에는 들어오고 시작 전 알림은 걸지 않는다
      final muted = NotifyConfig(channels: const ['gundam'], enabled: false);
      final q = planCheck(
        config: muted,
        state: seenBefore,
        entries: const [],
        manifestSig: '',
        now: now,
        streams: streams,
      );
      expect(q.records, hasLength(2));
      expect(q.reminders.schedule, isEmpty);

      final poke = NotifyConfig(channels: const ['pokemon']);
      final u = liveRecords(poke, streams, const {}, now).single;
      expect(u.body, '라이브 예정 · 시간 미정 · Pokémon YouTube');
      L10n.debugSet(AppLang.zh);
      expect(u.body, '即将直播 · 时间未定 · Pokémon YouTube');
    });
  });

  group('파일까지 한 바퀴 (runCatalogCheck)', () {
    late Directory dir;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('live_test');
      BlobStore.debugDirectory = dir;
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('예고 파일이 바뀐 때만 받아 걸고 · 못 건 것은 다음에 다시 · 규칙을 끄면 거둔다', () async {
      final config = NotifyConfig(channels: const ['gundam']);
      await BlobStore.write(notifyConfigKey, jsonEncode(config.toJson()));
      var body = jsonEncode(_file);
      String hash(String text) => sha256.convert(utf8.encode(text)).toString().substring(0, 16);
      final asked = <String>[];
      Future<String?> fetch(String path) async {
        asked.add(path);
        return switch (path) {
          'data/split/manifest.json' => jsonEncode({
            'updated_at': '2026-11-12',
            'total': 100,
            'files': {'announcements.json': hash(body)},
          }),
          announcementsPath => body,
          _ => null,
        };
      }

      final plans = <LiveReminderPlan>[];
      var fail = <String>{'live-5b79e87f56'};
      Future<Set<String>> apply(LiveReminderPlan p) async {
        plans.add(p);
        return fail;
      }

      Future<NotifyState> state() async => NotifyState.fromJson(jsonDecode((await BlobStore.read(notifyStateKey))!));
      final t0 = DateTime.utc(2026, 11, 13, 3).toLocal();

      await runCatalogCheck(now: t0, fetch: fetch, applyLive: apply);
      expect(asked, contains(announcementsPath));
      expect(plans.single.schedule.map((r) => r.annId), ['live-5b79e87f56', 'live-ebd6d015a6']);
      var s = await state();
      expect(s.liveKey, hash(body));
      expect(s.liveScheduled.keys, ['live-ebd6d015a6'], reason: '못 건 것은 걸려 있다고 적지 않는다');
      expect(s.inbox.where((r) => r.isLive).every((r) => r.seen), isTrue); // 처음 읽는 날은 조용히

      // 같은 파일: 다시 받지 않고, 못 걸었던 것만 다시 건다
      asked.clear();
      fail = {};
      await runCatalogCheck(now: t0.add(const Duration(minutes: 20)), fetch: fetch, applyLive: apply);
      expect(asked, isNot(contains(announcementsPath)));
      expect(plans.last.schedule.map((r) => r.annId), ['live-5b79e87f56']);
      s = await state();
      expect(s.liveScheduled.keys.toSet(), {'live-5b79e87f56', 'live-ebd6d015a6'});

      // 새 라이브가 올라왔다 → 받아서 알림함 줄(이번에는 울린다) + 예약, 그리고 DAY2 가 한 시간 늦춰졌다
      final next = jsonDecode(body) as Map<String, Object?>;
      final rows = next['announcements']! as List;
      (rows[0] as Map)['live_at'] = '2026-11-14T22:00:00+09:00';
      rows.add({
        'id': 'youtube-new',
        'franchise': 'gundam',
        'names': {'ja': 'ガンプラ新作発表会'},
        'status': 'announced',
        'announced_at': '2026-11-13',
        'source_type': 'youtube',
        'source_name': 'BANDAI SPIRITS YouTube',
        'video_id': 'new',
        'live_at': '2026-11-13T19:00:00+09:00',
        'live_state': 'upcoming',
      });
      body = jsonEncode(next);
      asked.clear();
      final r = await runCatalogCheck(now: t0.add(const Duration(minutes: 40)), fetch: fetch, applyLive: apply);
      expect(asked, contains(announcementsPath));
      expect(r.liveCount, 1);
      expect(plans.last.schedule.map((r) => r.annId).toSet(), {'live-5b79e87f56', 'youtube-new'});
      expect(plans.last.cancel, isEmpty);
      s = await state();
      expect(s.inbox.where((r) => !r.seen).single.id, 'stream-youtube-new');
      expect(s.liveScheduled['live-5b79e87f56'], liveReminderSig(DateTime.utc(2026, 11, 14, 13), 'ko'));

      // 규칙을 끄면 걸어 둔 것을 모두 거둔다 (예고 파일은 받지 않는다)
      config.rules[liveRule] = false;
      await BlobStore.write(notifyConfigKey, jsonEncode(config.toJson()));
      asked.clear();
      await runCatalogCheck(now: t0.add(const Duration(hours: 1)), fetch: fetch, applyLive: apply);
      expect(asked, isNot(contains(announcementsPath)));
      expect(plans.last.schedule, isEmpty);
      expect(plans.last.cancel, hasLength(3));
      expect((await state()).liveScheduled, isEmpty);
    });

    test('manifest 에 지문이 없으면(raw · 옛 판) 예고 파일을 받지 않는다', () async {
      await BlobStore.write(notifyConfigKey, jsonEncode(NotifyConfig(channels: const ['gundam']).toJson()));
      final asked = <String>[];
      Future<String?> fetch(String path) async {
        asked.add(path);
        return path.endsWith('manifest.json') ? jsonEncode({'updated_at': '2026-11-12', 'total': 100}) : null;
      }

      await runCatalogCheck(now: DateTime.utc(2026, 11, 13, 3), fetch: fetch, applyLive: (_) async => const {});
      expect(asked, isNot(contains(announcementsPath)));
    });
  });

  group('규칙 「라이브 시작 전」', () {
    test('처음부터 켜져 있고 설정 파일에 남는다', () {
      final c = NotifyConfig();
      expect(c.rule(liveRule), isTrue);
      expect(notifyMineRules, contains(liveRule));
      expect(notifyRuleLabel(liveRule), '라이브 시작 전');
      c.rules[liveRule] = false;
      expect(NotifyConfig.fromJson(jsonDecode(jsonEncode(c.toJson()))).rule(liveRule), isFalse);
      L10n.debugSet(AppLang.zh);
      expect(notifyRuleLabel(liveRule), '直播开始前');
    });

    testWidgets('알림 페이지 스위치 (한국어 · 중국어)', (tester) async {
      for (final lang in AppLang.values) {
        L10n.debugSet(lang);
        final store = NotifyStore.memory();
        tester.view.physicalSize = const Size(390, 2000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey(lang),
            theme: buildGpTheme(),
            builder: (context, child) => MarksHost(
              store: UserStore.memory(),
              child: PaneHost(child: child!),
            ),
            home: NotifySettingsScreen(notify: store),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        const key = Key('rule-live_soon');
        final tile = tester.widget<SwitchListTile>(find.byKey(key));
        expect(tile.value, isTrue);
        expect(find.descendant(of: find.byKey(key), matching: find.byIcon(Icons.live_tv_outlined)), findsOneWidget);
        if (lang == AppLang.zh) {
          final texts = tester.widgetList<Text>(find.descendant(of: find.byKey(key), matching: find.byType(Text)));
          expect(texts.map((t) => t.data ?? ''), everyElement(isNot(matches(_hangul))));
        }
        await tester.tap(find.byKey(key));
        await tester.pump();
        expect(store.config.rule(liveRule), isFalse);
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('화면', () {
    // fixture(sample-db.json) 의 ann10 = 2026-10-26 21:00 라이브
    const liveTag = ValueKey('live-tag-ann10');

    testWidgets('홈: 배너 · 공식 예고 줄에 라이브 꼬리표 (한국어 · 중국어)', (tester) async {
      fixedNow = DateTime(2026, 10, 25, 21);
      for (final lang in AppLang.values) {
        L10n.debugSet(lang);
        await _pump(
          tester,
          Scaffold(
            key: ValueKey(lang),
            body: HomeScreen(
              myChannels: const ['gundam'],
              onMyChannelsChanged: (_) {},
              onOpenSearch: () {},
              onCamera: () {},
              loaders: fakeLoaders,
            ),
          ),
        );
        await tester.scrollUntilVisible(find.byType(TagPill), 300, scrollable: find.byType(Scrollable).first);
        final onPhoto = tester.widget<TagPill>(find.byKey(liveTag).last);
        expect(onPhoto.text, lang == AppLang.zh ? '直播 · 明天 21:00' : '라이브 · 내일 21:00');
        expect(onPhoto.filled, isTrue, reason: '사진 위');
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('예고 목록: 단계 꼬리표 자리에 라이브 때 · 방송 중이면 빨강', (tester) async {
      fixedNow = DateTime(2026, 10, 26, 21, 30);
      final anns = await fakeLoaders.announcements(['gundam']);
      await _pump(
        tester,
        Scaffold(
          body: SectionListView(title: '공식 예고', announcements: anns, loaders: fakeLoaders),
        ),
      );
      final tag = tester.widget<SoftTag>(find.byKey(liveTag));
      expect(tag.text, '라이브 중');
      expect(tag.color, Gp.danger);
      expect(find.byType(SoftTag), findsWidgets); // 보통 예고는 단계 그대로
      expect(tester.takeException(), isNull);
    });

    testWidgets('캘린더: 라이브는 방송하는 날에 "21:00 라이브" · 시간 미정은 없음 (한국어 · 중국어)', (tester) async {
      fixedNow = DateTime(2026, 10, 25, 21);
      final loaders = Loaders(
        kits: (_) async => const [],
        announcements: (_) async => [
          _ann('live-27', date: '2026-10-20', at: DateTime(2026, 10, 27, 21), state: 'upcoming'),
          _ann('live-undated', date: '2026-10-20', state: 'upcoming'),
          _ann('live-nov', date: '2026-10-20', at: DateTime(2026, 11, 2, 20), state: 'upcoming'),
          _ann('news-20', date: '2026-10-20'),
        ],
      );
      for (final lang in AppLang.values) {
        L10n.debugSet(lang);
        await _pump(
          tester,
          Scaffold(
            key: ValueKey(lang),
            body: CalendarScreen(myChannels: const ['gundam'], onMyChannelsChanged: (_) {}, loaders: loaders),
          ),
        );
        final rows = {for (final r in tester.widgetList<ThumbRow>(find.byType(ThumbRow, skipOffstage: false))) r.id: r};
        expect(rows.keys.toSet(), {'live-27', 'news-20'});
        expect(rows['live-27']!.tag, lang == AppLang.zh ? '21:00 直播' : '21:00 라이브');
        expect(rows['live-27']!.tagColor, Gp.accent); // 곧 = 파랑 (발매 알약 · 예고 알약과 다른 색 꼬리표)
        expect(rows['news-20']!.tagColor, isNull);
        // 27일 줄 머리 아래에 있다 (발표일 20일이 아니라)
        final y = tester.getTopLeft(find.byWidget(rows['live-27']!, skipOffstage: false)).dy;
        expect(y, greaterThan(tester.getTopLeft(find.byWidget(rows['news-20']!, skipOffstage: false)).dy));
        expect(tester.takeException(), isNull);
      }
    });
  });
}
