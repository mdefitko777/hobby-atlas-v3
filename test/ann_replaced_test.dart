// 공식 쪽이 이어받은 예고 — 홈 배너는 공식 먼저 · announcements.json `replaced`(옛 id → 새 id)로
// 알림 받는 예고 옮기기 · 단계 알림 · 옛 id 링크 열기 · 옛 id 로 걸어 둔 라이브 알림.
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/api.dart';
import 'package:hobby_atlas/logic/announcement_match.dart';
import 'package:hobby_atlas/models.dart';
import 'package:hobby_atlas/notifications/feed_rules.dart';
import 'package:hobby_atlas/notifications/live_reminders.dart';
import 'package:hobby_atlas/notifications/notify_models.dart';
import 'package:hobby_atlas/notifications/notify_store.dart';

Announcement _ann(String id, {bool unofficial = false, bool image = true}) => Announcement(
  id: id,
  franchiseId: 'gundam',
  title: id,
  status: '공식 발표',
  date: '2026-11-13',
  source: '',
  image: image ? 'https://example.com/$id.jpg' : '',
  hero: false,
  unofficial: unofficial,
);

/// Gunpula data/announcements.json 한 줄 모양
Map<String, Object?> _row(String id, {String status = 'announced', bool unofficial = false, String? liveAt}) => {
  'id': id,
  'franchise': 'gundam',
  'names': {'ja': 'HG 新商品'},
  'status': status,
  'announced_at': '2026-11-13',
  'source_name': unofficial ? '電撃ホビーウェブ' : '魂ウェブ',
  if (unofficial) 'unofficial': true,
  if (liveAt != null) ...{'live_at': liveAt, 'live_state': 'upcoming'},
};

FollowedAnn _follow(String stage) => FollowedAnn(stage: stage, title: 'HG 新商品', franchise: 'gundam');

void main() {
  group('홈 배너 (A-3): 공식 먼저, 모자랄 때만 비공식', () {
    test('사진 있는 공식이 6개 넘으면 비공식은 줄 앞에 있어도 오르지 않는다', () {
      final list = [_ann('fan-1', unofficial: true), for (var i = 0; i < 7; i++) _ann('news-$i')];
      expect(annHeroIds(list), {for (var i = 0; i < 6; i++) 'news-$i'});
    });

    test('공식이 모자라면 비공식으로 채운다 (각각 줄 순서) · 사진 없는 것은 빼고', () {
      final list = [
        _ann('fan-1', unofficial: true),
        _ann('news-1'),
        _ann('news-2', image: false),
        _ann('fan-2', unofficial: true, image: false),
        _ann('fan-3', unofficial: true),
        _ann('news-3'),
      ];
      expect(annHeroIds(list).toList(), ['news-1', 'news-3', 'fan-1', 'fan-3']);
      expect(annHeroIds(list, max: 3).toList(), ['news-1', 'news-3', 'fan-1']);
    });

    test('배너 순서: 비공식이 줄 앞에 있어도 공식 뒤 · 사진 있는 공식이 하나도 없으면 비공식만', () {
      List<String> order(List<Announcement> list) {
        final ids = annHeroIds(list);
        return [
          for (final a in annHeroes([for (final a in list) ids.contains(a.id) ? a.asHero() : a])) a.id,
        ];
      }

      expect(order([_ann('fan-1', unofficial: true), _ann('news-1'), _ann('fan-2', unofficial: true)]), [
        'news-1',
        'fan-1',
        'fan-2',
      ]);
      expect(order([_ann('news-1', image: false), _ann('fan-1', unofficial: true), _ann('fan-2', unofficial: true)]), [
        'fan-1',
        'fan-2',
      ]);
      expect(order([_ann('news-1', image: false), _ann('fan-1', unofficial: true, image: false)]), isEmpty);
    });
  });

  group('replaced 지도 읽기', () {
    test('없거나 모양이 다르면 빈 지도 (옛 파일)', () {
      expect(annReplacedOf(null), isEmpty);
      expect(annReplacedOf({'announcements': []}), isEmpty);
      expect(annReplacedOf({'replaced': []}), isEmpty);
      expect(annReplacedOf({'replaced': 'x'}), isEmpty);
    });

    test('사슬은 끝 id 로 · 고리 · 자기 자신 · 글자가 아닌 값은 버린다', () {
      final m = annReplacedOf({
        'replaced': {'a': 'b', 'b': 'c', 'x': 'y', 'y': 'x', 's': 's', 'n': 3, 'e': ''},
      });
      expect(m, {'a': 'c', 'b': 'c'});
    });
  });

  group('알림 받는 예고 옮기기', () {
    test('옛 id → 새 id, 단계는 그대로 · 옮길 것이 없으면 null · 새 id 를 이미 받고 있으면 그쪽', () {
      final followed = {'fan-1': _follow('announced'), 'news-2': _follow('product_confirmed')};
      expect(moveAnnIds(followed, const {}), isNull);
      expect(moveAnnIds(followed, {'gone': 'news-9'}), isNull);
      final moved = moveAnnIds(followed, {'fan-1': 'news-9'})!;
      expect(moved.keys, unorderedEquals(['news-9', 'news-2']));
      expect(moved['news-9']!.stage, 'announced');
      final both = moveAnnIds({'fan-1': 'a', 'news-9': 'b'}, {'fan-1': 'news-9'})!;
      expect(both, {'news-9': 'b'});
    });

    test('앱: 한 번만 옮겨 적고(같은 지도를 다시 받으면 쓰지 않는다) · 뒤 작업이 먼저 넣은 단계 줄만큼 올린다', () {
      final store = NotifyStore.memory(
        config: NotifyConfig(followed: {'fan-1': _follow('announced')}),
        records: [
          NoticeRecord(
            id: 'ann-news-9-preorder_open',
            kind: 'ann_stage',
            kitId: '',
            annId: 'news-9',
            title: 'HG 新商品',
            body: '',
            at: DateTime.utc(2026, 11, 13),
            franchise: 'gundam',
            reasons: const ['preorder_open'],
          ),
        ],
      );
      var writes = 0;
      store.addListener(() => writes++);
      expect(store.adoptReplaced({'fan-1': 'news-9'}), isTrue);
      expect(store.isFollowing('fan-1'), isFalse);
      expect(store.isFollowing('news-9'), isTrue);
      expect(store.config.followed['news-9']!.stage, 'preorder_open', reason: '이미 울린 단계는 다시 울리지 않게');
      expect(writes, 1);
      expect(store.adoptReplaced({'fan-1': 'news-9'}), isFalse);
      expect(store.adoptReplaced(const {}), isFalse);
      expect(writes, 1);
    });

    test('뒤 작업: 옮기기 전이어도 이어받은 예고의 단계로 한 번 울린다 (새 id 로)', () {
      final config = NotifyConfig(followed: {'fan-1': _follow('announced')});
      final file = {
        'announcements': [_row('news-9', status: 'preorder_open')],
        'replaced': {'fan-1': 'news-9'},
      };
      final now = DateTime.utc(2026, 11, 13, 9);
      final r = annStageRecords(config, file, {}, now).single;
      expect(r.id, 'ann-news-9-preorder_open');
      expect(r.annId, 'news-9');
      expect(r.unofficial, isFalse);
      expect(r.body, '공식 발표 → 예약 시작');
      expect(buildAlerts([r]).single.payload, 'ann:gundam:news-9');
      expect(annStageRecords(config, file, {r.id}, now), isEmpty, reason: '알림함에 있으면 다시 울리지 않는다');
      // 지도가 없는 옛 파일: 옛 id 를 못 찾으니 조용히
      expect(annStageRecords(config, {'announcements': file['announcements']}, {}, now), isEmpty);
    });
  });

  group('옛 id 링크 (알림 · 라이브 알림의 ann:<채널>:<id>)', () {
    test('옛 id 면 이어받은 예고를 연다', () async {
      final loaders = Loaders(
        announcements: (_) async => [_ann('news-9')],
        annReplaced: () async => {'fan-1': 'news-9'},
      );
      expect((await findAnnouncement(loaders, 'gundam', 'fan-1'))?.id, 'news-9');
      expect((await findAnnouncement(loaders, 'gundam', 'news-9'))?.id, 'news-9');
    });
  });

  group('라이브: 옛 id 로 알린 · 걸어 둔 것', () {
    final now = DateTime.utc(2026, 11, 13, 3); // 한국 12:00
    final config = NotifyConfig(channels: ['gundam'], rules: {liveRule: true});
    final file = {
      'announcements': [_row('news-9', liveAt: '2026-11-13T21:00:00+09:00')],
      'replaced': {'fan-1': 'news-9'},
    };

    test('읽을 때 이어받은 옛 id 를 적어 두고(저장해도 남는다) · 옛 id 로 알린 라이브는 다시 알리지 않는다', () {
      final s = parseLiveStreams(file, now).single;
      expect(s.replaces, ['fan-1']);
      expect(LiveStream.fromJson(s.toJson())!.replaces, ['fan-1']);
      expect(liveRecords(config, [s], {'stream-fan-1'}, now), isEmpty);
      expect(liveRecords(config, [s], {}, now).single.id, 'stream-news-9');
    });

    LiveReminderPlan plan(Map<String, String> scheduled, DateTime at) => planLiveReminders(
      streams: parseLiveStreams(file, at),
      scheduled: scheduled,
      channels: const ['gundam'],
      enabled: true,
      now: at,
    );
    final start = DateTime.utc(2026, 11, 13, 12);
    final sig = liveReminderSig(start, 'ko');

    test('아직 안 떴으면 옛 id 를 거두고 새 id 로 다시 건다', () {
      final p = plan({'fan-1': sig}, now);
      expect(p.cancel, [liveReminderId('fan-1')]);
      expect(p.schedule.single.annId, 'news-9');
      expect(p.schedule.single.payload, 'ann:gundam:news-9');
      expect(p.scheduled, {'news-9': sig});
    });

    test('이미 떴으면(시작 30분 전이 지남) 옛 id 그대로 — 떠 있는 알림을 지우지 않고 새로 또 걸지 않는다', () {
      final p = plan({'fan-1': sig}, start.subtract(const Duration(minutes: 10)));
      expect(p.cancel, isEmpty);
      expect(p.schedule, isEmpty);
      expect(p.scheduled, {'fan-1': sig});
    });

    test('새 id 로도 걸려 있으면 옛 것은 거둔다 (두 번 뜨지 않게)', () {
      final p = plan({'fan-1': sig, 'news-9': sig}, now);
      expect(p.cancel, [liveReminderId('fan-1')]);
      expect(p.schedule, isEmpty);
      expect(p.scheduled, {'news-9': sig});
    });
  });
}
