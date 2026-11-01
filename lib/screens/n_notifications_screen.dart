// 화면 N: 알림 — 오른쪽 위 🔔 에서 열림
//
// ┌──────── 디자인 가이드 대응표: N 알림 ──────────────────────────────────────────────┐
// │ 번호 │ Flutter 위젯명                     │ 비즈니스 명칭(한글)                    │ 원칙(P번호)   │
// │ N-1  │ 밑줄 탭 4개 + 안 읽은 수             │ 전체 · 상품(발매·예약·시세) · 예고 · 친구 │ P06 · P01     │
// │ N-2  │ 날짜 묶음 머리                       │ 오늘 · 이번 주 · 이전                   │ P08           │
// │ N-3  │ 알림 줄: 사진 · 제목 · 한 줄 · 시간 · 점 │ 안 읽음 = 굵은 제목 + 하늘색 점          │ P01 · P04     │
// │ N-4  │ 줄 누르기 → 읽음 + 이동               │ 상품 상세 · 공고 · 친구 프로필 · 친구 요청 │ P07          │
// │ N-5  │ Dismissible → 토스트(되돌리기)        │ 밀어서 지우기                           │ P03 · P05     │
// │ N-6  │ AppBar: 모두 읽음 · ⚙                │ 한 번에 읽음 · 알림 설정(K)              │ P07           │
// │ N-9  │ RefreshIndicator                   │ 당겨서 새 소식 확인                      │ P10           │
// │ N-7  │ 바텀 시트: 수락 · 거절                │ 친구 요청 응답 (Gunpula v3 respond_friend) │ P05        │
// │ N-8  │ 친구 줄 (사진 = 상품)                │ 내 좋아요를 친구가 이미 가짐 → 상품 상세   │ P01 · P09     │
// │ N-8  │ LoadingView / ErrorView / EmptyView │ 불러오는 중 · 오류 · 알림 없음           │ P01 · P09     │
// └──────────────────────────────────────────────────────────────────────────────────┘
// 전환: 🔔 → 쌓기(push, 오른쪽에서). 줄 → 각 화면 쌓기. 요청 → 덮기(바텀 시트).
// 범위: 내 채널의 상품 + 좋아요한 상품 · PB 예약(채널과 무관) + 친구 알림. 목록은 알림함(lib/notifications),
// 읽음 · 지움은 기기에 저장된다 (NotifyStore — 🔔 숫자와 같은 값). 받은 친구 요청(계정 get_me)은 맨 위에 "수락 · 거절".
import 'package:flutter/material.dart';

import '../api.dart';
import '../data/catalog.dart';
import '../data/user_store.dart';
import '../detail_pane.dart';
import '../channels.dart';
import '../logic/friends.dart';
import '../models.dart';
import '../sync/account.dart';
import '../sync/friends_service.dart' show FriendsFailure;
import '../notifications/notify_store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'd_kit_detail_screen.dart';
import 'i_profile_screen.dart';
import 'j_announcement_screen.dart';
import 'k_settings_screen.dart';
import '../clock.dart';

/// 프로토타입의 "지금" (캘린더의 오늘과 같은 날 저녁)
DateTime get noticeNow => appNow();

void openNotifications(
  BuildContext context, {
  required List<String> myChannels,
  Loaders loaders = const Loaders(),
  NotifyStore? notify,
}) {
  openPage(context, NotificationsScreen(myChannels: myChannels, loaders: loaders, notify: notify));
}

enum _Tab { all, goods, announce, friends }

extension on NoticeType {
  _Tab get tab => switch (this) {
    NoticeType.release || NoticeType.reserve || NoticeType.price => _Tab.goods,
    NoticeType.announce => _Tab.announce,
    NoticeType.friend || NoticeType.request => _Tab.friends,
  };

  IconData get icon => switch (this) {
    NoticeType.release => Icons.event_available_outlined,
    NoticeType.reserve => Icons.shopping_bag_outlined,
    NoticeType.price => Icons.trending_up,
    NoticeType.announce => Icons.campaign_outlined,
    NoticeType.friend => Icons.people_outline,
    NoticeType.request => Icons.person_add_alt_1_outlined,
  };
}

/// "3시간 전" · "어제" · "10.16"
String noticeTime(DateTime at) => timeAgo(at, now: noticeNow);

String _groupOf(DateTime at) {
  final days = DateTime(
    noticeNow.year,
    noticeNow.month,
    noticeNow.day,
  ).difference(DateTime(at.year, at.month, at.day)).inDays;
  if (days <= 0) return '오늘';
  if (days < 7) return '이번 주';
  return '이전';
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.myChannels, this.loaders = const Loaders(), this.notify});
  final List<String> myChannels;
  final Loaders loaders;

  /// 읽음 · 지움을 적는 곳 (기본: 앱 전체 한 벌, 테스트는 NotifyStore.memory())
  final NotifyStore? notify;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  /// 처음 쓸 때(initState) 한 번 찾아 둔다 — dispose 에서 위쪽 위젯을 찾으면 안 된다
  late final NotifyStore _store = widget.notify ?? NotifyScope.read(context);
  late Future<List<AppNotice>> _future = widget.loaders.notifications(); // STATE: 알림함
  late int _rev = _store.inboxRevision;
  _Tab _tab = _Tab.all;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStore);
    // 열 때 받은 친구 요청을 한 번 새로 (실패해도 받아 둔 것으로 보여 준다)
    final a = AccountScope.read(context);
    if (a.signedIn) {
      // 친구 컬렉션도 받아 "친구가 이미 갖고 있어요" 줄을 만든다 (N-8)
      a.friends.refresh().then(
        (_) => Future.wait([
          for (final f in a.friends.friends) a.friends.collection(f.handle).then((_) {}, onError: (Object _) {}),
        ]),
        onError: (Object _) {},
      );
    }
  }

  /// N-8 내가 좋아요한 상품을 친구가 이미 갖고 있다 → 겹쳐 사지 않게 · 같이 보기 (id `own-<아이디>-<kit_id>`)
  List<AppNotice> _overlaps(Account account) {
    if (!account.signedIn) return const [];
    final byId = Catalog.instance.byId;
    return [
      for (final o in likedOwnedByFriends(
        account.friends.collections,
        UserStore.instance.idsWith(const {CollectStatus.wanted}).toSet(),
      ))
        if (byId[o.kitId] case final k?)
          AppNotice(
            id: 'own-${o.handle}-${o.kitId}',
            type: NoticeType.friend,
            title: k.name,
            body: '${o.name.isEmpty ? '@${o.handle}' : o.name}님이 이미 갖고 있어요',
            image: k.image,
            at: noticeNow,
            read: false,
            kitId: k.id,
          ),
    ];
  }

  @override
  void dispose() {
    _store.removeListener(_onStore);
    super.dispose();
  }

  /// 알림함이 바뀌면(백그라운드 확인 · 당겨서 새로 고침) 목록을 다시, 읽음 · 지움만 바뀌면 다시 그리기만
  void _onStore() {
    if (!mounted) return;
    setState(() {
      if (_store.inboxRevision != _rev) {
        _rev = _store.inboxRevision;
        _future = widget.loaders.notifications(); // STATE: 새 알림 → 목록 다시
      }
    });
  }

  bool _isRead(AppNotice n) => _store.isRead(n.id, fallback: n.read);

  /// 계정의 받은 친구 요청 → 알림 줄 (id 'req-<아이디>')
  List<AppNotice> _requests(Account account) => [
    if (account.signedIn)
      for (final p in account.friends.incoming)
        AppNotice(
          id: 'req-${p.handle}',
          type: NoticeType.request,
          title: '${p.name}님의 친구 요청',
          body: '@${p.handle} · 수락하면 서로의 구매함 · 좋아요를 볼 수 있어요',
          image: '',
          at: noticeNow,
          read: false,
          friend: p.handle,
        ),
  ];

  /// 받은 친구 요청이 맨 앞 + 내 채널 범위(설정 › 내 채널 소식만) + 지우지 않은 것.
  /// franchiseId 가 빈 것(좋아요 · PB 예약 · 친구)은 늘 보인다.
  List<AppNotice> _scoped(List<AppNotice> all, List<AppNotice> requests) => [
    ...requests,
    ...all.where((n) => n.franchiseId.isEmpty || !_store.config.onlyMine || widget.myChannels.contains(n.franchiseId)),
  ].where((n) => !_store.isDismissed(n.id)).toList();

  void _readAll(List<AppNotice> list) {
    final ids = [
      for (final n in list)
        if (!_isRead(n)) n.id,
    ];
    if (ids.isEmpty) return;
    _store.setRead(ids, true); // STATE: 모두 읽음 → 점 · 굵은 글씨 사라짐 · 🔔 숫자 0 (저장)
    showToast(context, '${ids.length}개를 읽음으로 표시했어요', onUndo: () => _store.setRead(ids, false));
  }

  void _remove(AppNotice n) {
    final wasRead = _isRead(n);
    _store.setDismissed(n.id, true); // STATE: 밀어서 지우기 → 목록에서 빠짐 (저장)
    showToast(
      context,
      '알림을 지웠어요',
      onUndo: () {
        _store.setDismissed(n.id, false);
        if (!wasRead) _store.setRead([n.id], false);
      },
    );
  }

  /// N-4 읽음 + 이동
  Future<void> _open(AppNotice n) async {
    _store.setRead([n.id], true); // STATE: 누름 → 읽음 (저장)
    try {
      if (n.type == NoticeType.request) return _answerRequest(n);
      if (n.kitId.isNotEmpty) {
        final kits = await widget.loaders.kitsByIds([n.kitId]);
        if (!mounted) return;
        if (kits.isNotEmpty) {
          openKitDetail(context, kits.first, loaders: widget.loaders);
        } else {
          showToast(context, '이 상품은 지금 카탈로그에 없어요');
        }
      } else if (n.annId.isNotEmpty) {
        final anns = await widget.loaders.announcements([n.franchiseId]);
        final a = anns.where((a) => a.id == n.annId).firstOrNull;
        if (mounted && a != null) openAnnouncement(context, a, loaders: widget.loaders);
      } else if (n.friend.isNotEmpty) {
        final p = await widget.loaders.profile();
        final f = p.friends.where((f) => f.handle == n.friend).firstOrNull;
        if (!mounted) return;
        if (f == null) {
          showToast(context, '@${n.friend} 님의 프로필을 찾지 못했어요');
        } else {
          openFriend(context, f, loaders: widget.loaders);
        }
      }
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message); // P09
    }
  }

  /// 계정 요청이면 서버에 답한다 (가짜 데이터 요청은 목록에서만 빠짐)
  Future<void> _respond(AppNotice n, {required bool accept}) async {
    final account = AccountScope.read(context);
    final real = n.id.startsWith('req-') && account.signedIn;
    if (!real) {
      if (accept) {
        _store.setDismissed(n.id, true);
        showToast(context, '친구가 됐어요 · 친구 서랍에서 볼 수 있어요');
      } else {
        _remove(n);
      }
      return;
    }
    try {
      await account.friends.respond(n.friend, accept: accept);
      if (mounted) showToast(context, accept ? '친구가 됐어요 · 친구 서랍에서 볼 수 있어요' : '요청을 거절했어요');
    } on FriendsFailure catch (e) {
      if (mounted) showToast(context, e.message);
    }
  }

  /// N-7 친구 요청 응답
  void _answerRequest(AppNotice n) {
    showGpSheet<void>(
      context,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(n.title, subtitle: n.body, padding: const EdgeInsets.fromLTRB(0, 0, 0, 14)),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(sheet);
                        _respond(n, accept: false);
                      },
                      child: const Text('거절'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(sheet);
                        _respond(n, accept: true);
                      },
                      child: const Text('수락'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final account = AccountScope.of(context);
    final requests = [..._requests(account), ..._overlaps(account)]; // 요청 · 친구 컬렉션이 바뀌면 다시 그림
    return FutureBuilder<List<AppNotice>>(
      future: _future,
      builder: (context, snap) {
        final scoped = _scoped(snap.hasData ? snap.data! : const [], requests);
        final list = _tab == _Tab.all ? scoped : scoped.where((n) => n.type.tab == _tab).toList();
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              '알림',
              style: TextStyle(fontSize: Gp.t19, fontWeight: FontWeight.w600),
            ),
            actions: [
              TextButton(
                onPressed: list.any((n) => !_isRead(n)) ? () => _readAll(list) : null, // N-6
                child: const Text('모두 읽음'),
              ),
              IconButton(
                tooltip: '알림 설정',
                onPressed: () => openSettings(context),
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
          body: switch (snap) {
            // 다시 부르는 중에는 앞 목록을 그대로 (깜빡이지 않게)
            _ when snap.hasData => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _tabs(scoped),
                Expanded(
                  child: RefreshIndicator(
                    // N-9 당겨서 지금 확인
                    onRefresh: () => _store.checkNow(force: true),
                    child: _list(list),
                  ),
                ),
              ],
            ),
            _ when snap.connectionState != ConnectionState.done => const LoadingView(), // N-8
            _ => ErrorView(
              message: '${snap.error}',
              onRetry: () => setState(() => _future = widget.loaders.notifications()),
            ),
          },
        );
      },
    );
  }

  /// N-1 탭 + 안 읽은 수
  Widget _tabs(List<AppNotice> scoped) {
    int unread(_Tab t) => scoped.where((n) => !_isRead(n) && (t == _Tab.all || n.type.tab == t)).length;
    Widget tab(String label, _Tab t) => UnderlineTab(
      label: label,
      count: unread(t) == 0 ? null : unread(t),
      selected: _tab == t,
      onTap: () => setState(() => _tab = t), // STATE: 탭 → 목록 거르기
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
      child: SingleChildScrollView(
        // 좁은 화면에서는 옆으로 밀기
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [tab('전체', _Tab.all), tab('상품', _Tab.goods), tab('예고', _Tab.announce), tab('친구', _Tab.friends)],
        ),
      ),
    );
  }

  Widget _list(List<AppNotice> list) {
    if (list.isEmpty) {
      // 당겨서 새로 고침이 되도록 스크롤 가능한 빈 화면
      return LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: box.maxHeight,
            child: EmptyView(
              // N-8 P09
              icon: Icons.notifications_none,
              message: '새 알림이 없어요',
              detail: '알림 규칙(PB · SEED/00 · BBX …)에 맞는 내 채널 새 상품, 좋아요한 상품의 변화와 PB 예약 기간이 여기에 모여요\n${_store.statusLine}',
            ),
          ),
        ),
      );
    }
    final groups = <String, List<AppNotice>>{};
    for (final n in list) {
      (groups[n.id.startsWith('req-') ? '친구 요청' : _groupOf(n.at)] ??= []).add(n);
    }
    final channels = widget.myChannels.map((id) => channelOf(id).label).join(' · ');
    final scope = _store.config.onlyMine ? '내 채널($channels)' : '모든 채널';
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Text(
            '$scope 소식 · 좋아요한 상품 · 왼쪽으로 밀면 지워요\n${_store.statusLine}',
            style: const TextStyle(fontSize: Gp.t12, color: Gp.faint),
          ),
        ),
        for (final e in groups.entries) ...[
          SectionHeader(e.key, padding: const EdgeInsets.fromLTRB(16, 16, 16, 6)), // N-2
          for (final n in e.value)
            Dismissible(
              // N-5
              key: ValueKey(n.id),
              direction: DismissDirection.endToStart,
              onDismissed: (_) => _remove(n),
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                color: Gp.soft,
                child: const Icon(Icons.delete_outline, color: Gp.danger),
              ),
              child: _NoticeRow(
                notice: n,
                read: _isRead(n),
                time: n.id.startsWith('req-') ? '누르면 수락 · 거절' : noticeTime(n.at),
                onTap: () => _open(n),
              ),
            ),
        ],
      ],
    );
  }
}

/// N-3 알림 한 줄
class _NoticeRow extends StatelessWidget {
  const _NoticeRow({required this.notice, required this.read, required this.time, required this.onTap});
  final AppNotice notice;
  final bool read;

  /// "3시간 전" · 친구 요청은 "누르면 수락 · 거절"
  final String time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = notice;
    final person = n.type == NoticeType.request || (n.type == NoticeType.friend && n.image.isEmpty);
    final thumb = SizedBox.square(
      dimension: 52,
      child: person
          ? CircleThumb(image: '', label: n.title.characters.first, size: 52)
          : PhotoThumb(n.image, radius: 10),
    );
    return InkWell(
      onTap: onTap,
      child: Container(
        color: read ? null : Gp.accent.withValues(alpha: 0.04),
        padding: const EdgeInsets.fromLTRB(16, 10, 14, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                thumb,
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Gp.panel,
                      border: Border.all(color: Gp.line),
                    ),
                    child: Icon(n.type.icon, size: 13, color: Gp.ink),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: Gp.t14, fontWeight: read ? FontWeight.w400 : FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    n.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: Gp.t12, color: Gp.muted, height: 1.35),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    time,
                    style: const TextStyle(fontSize: Gp.t11, color: Gp.faint),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedOpacity(
              opacity: read ? 0 : 1,
              duration: const Duration(milliseconds: 200),
              child: Container(
                margin: const EdgeInsets.only(top: 6),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Gp.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
