// 화면 M: 친구 서랍 — 왼쪽 위 아바타를 누르거나, 홈에서 왼쪽 가장자리를 밀면 나온다 (QQ 옆 서랍처럼)
// 위: 내 프로필 요약(아바타를 한 번 더 누르면 I 내 정보) · 아래: 친구 (검색 · 새 친구 요청 · 목록)
// v3: 친구 · 요청은 Gunpula 계정(v3 get_me), 친구 숫자는 get_friend_collection, 친구 사진 · 아바타는 get_friend_wall,
//     알 수도 있는 친구는 gunpula_v3_suggest_friends(docs/supabase-v3-social.sql — 없으면 칸 숨김),
//     공유 공간은 v2 get_state 의 멤버(읽기만, 공유 공간이 없는 계정은 탭 숨김). 공용 조각은 u_social.dart.
//
// ┌──────── 디자인 가이드 대응표: M 친구 서랍 ─────────────────────────────────────────┐
// │ 번호 │ Flutter 위젯명                     │ 비즈니스 명칭(한글)                    │ 원칙(P번호)   │
// │ M-1  │ Drawer (아바타 · 홈 가장자리 밀기)    │ 친구 서랍 열기 · 닫기(밖 누르기 · X)     │ P03 · P07     │
// │ M-2  │ 색 고리 아바타(사진) · 이름 · Lv      │ 내 프로필 요약 → 내 정보                │ P04           │
// │ M-3  │ 각진 칩 (있을 때만)                  │ 친구 요청 n건 · 새 사진 n (지난번 연 뒤)  │ P01           │
// │ M-4  │ GpSearchBar (카메라 없는 모드)        │ 친구 검색 (홈 · 검색과 같은 검색창)       │ P07 · P04     │
// │ M-5  │ SuggestionsPanel (U-7) · 요청 줄      │ 알 수도 있는 친구(함께 아는 친구 n명) · 친구 요청 │ P07 · P05 │
// │ M-6  │ 밑줄 탭 + 접히는 그룹                │ 친구 | 공유 공간(멤버 · 역할, U-6)        │ P06           │
// │ M-7  │ 친구 줄 (아바타 · 상태 한 줄 · Lv)    │ 친구 → 친구 프로필(I 친구 보기) · 새 사진 점 │ P07 · P01    │
// │ M-8  │ 안내 + 로그인 버튼                   │ 로그인 전                              │ P09           │
// └──────────────────────────────────────────────────────────────────────────────────┘
// 전환: 서랍 → 내 정보 · 친구 프로필(쌓기, 서랍은 닫힘). 요청 · 추가 → 덮기(바텀 시트).
import 'package:flutter/material.dart';

import '../api.dart';
import '../clock.dart';
import '../data/user_store.dart';
import '../models.dart';
import '../sync/account.dart';
import '../sync/friends_service.dart';
import '../theme.dart';
import '../widgets.dart';
import 'p_sign_in_screen.dart';
import 'q_friend_sheets.dart';
import 'u_social.dart';
import '../level.dart';

class FriendsDrawer extends StatefulWidget {
  const FriendsDrawer({
    super.key,
    required this.onOpenProfile,
    required this.onOpenFriend,
    this.loaders = const Loaders(),
  });

  final VoidCallback onOpenProfile;
  final ValueChanged<Member> onOpenFriend;
  final Loaders loaders;

  @override
  State<FriendsDrawer> createState() => _FriendsDrawerState();
}

/// 계정 친구 → 화면 모델 (숫자는 받아 둔 컬렉션에서)
Member friendMemberOf(PublicProfile f, FriendCollection? c) => Member(
  name: f.name,
  handle: f.handle,
  role: '친구',
  self: false,
  liked: c?.likedIds.length ?? 0,
  lit: 0,
  owned: c?.ownedIds.length ?? 0,
  likedIds: c?.likedIds ?? const [],
  ownedIds: c?.ownedIds ?? const [],
);

class _FriendsDrawerState extends State<FriendsDrawer> {
  late Future<(Profile, int)> _future = _load();

  String _query = '';
  bool _collapsed = false;

  /// M-6 공유 공간 탭
  bool _spaceTab = false;

  /// 지난번 서랍을 연 시각 — 그 뒤에 올라온 친구 사진 = 새 사진 (M-3)
  late final String _seenBefore;

  @override
  void initState() {
    super.initState();
    final a = AccountScope.read(context);
    _seenBefore = a.store.social.friendsSeenAt;
    if (!a.signedIn) return;
    final now = appNow().toUtc().toIso8601String();
    WidgetsBinding.instance.addPostFrameCallback((_) => a.store.social.setFriendsSeenAt(now)); // 그리는 중에 알리지 않게
    // 열 때마다: 친구 · 요청 새로 → 친구 숫자 · 사진 벽(새 사진 · 상태 · 아바타). 실패해도 받아 둔 것으로 그린다
    a.friends
        .refresh()
        .then((_) async {
          await a.friends.loadAllCollections(force: true);
          final handles = [for (final f in a.friends.friends) f.handle];
          await a.photos.loadAllWalls(handles);
          await a.profileImages.cacheFriendAvatars();
          await a.profileImages.forgetFriendsExcept(handles.toSet());
        })
        .catchError((Object _) {});
    a.friends.loadSuggestions().ignore(); // M-5
  }

  /// 친구별 새 사진 수
  int _newPhotos(Account a, String handle) => newPhotoCount(a.photos.walls[handle], _seenBefore);

  Future<(Profile, int)> _load() async {
    // STATE: 내 정보 · 도감 → 내 요약 (레벨)
    final r = await Future.wait([widget.loaders.profile(), widget.loaders.guideWorks()]);
    final works = r[1] as List<GuideWork>;
    return (r[0] as Profile, litCount(works));
  }

  /// 서랍을 닫고 열기
  void _close(VoidCallback then) {
    Navigator.pop(context);
    then();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final account = AccountScope.of(context); // 친구 · 요청이 바뀌면 다시 그림
    return Drawer(
      // M-1
      width: width < 420 ? width * 0.88 : 380,
      backgroundColor: Gp.bg,
      shape: const RoundedRectangleBorder(),
      child: FutureBuilder<(Profile, int)>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingView();
          if (snap.hasError) {
            return ErrorView(message: '${snap.error}', onRetry: () => setState(() => _future = _load()));
          }
          final (p, lit) = snap.data!;
          final signedIn = account.signedIn;
          // 로그인하면 계정 친구, 아니면 가져온 프로필의 친구 (실제 앱에서는 비어 있음)
          final friends = signedIn
              ? [for (final f in account.friends.friends) friendMemberOf(f, account.friends.collections[f.handle])]
              : p.friends;
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              _header(p, lit, account, friends),
              if (!signedIn)
                _signInHint()
              else ...[
                _search(),
                if (_query.isEmpty) const SuggestionsPanel(), // M-5
                _newFriends(account),
              ],
              _lists(friends, signedIn, account),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  /// M-2 내 프로필 요약 (QQ 서랍 머리처럼, 다만 밝은 바탕)
  Widget _header(Profile p, int lit, Account account, List<Member> friends) {
    final signedIn = account.signedIn;
    final name = signedIn ? account.displayName : p.name;
    final handle = signedIn ? account.handle : p.handle;
    final incoming = account.incomingCount;
    // M-3 새 사진: 누르면 가장 많이 올린 친구로
    final fresh = signedIn
        ? ([
            for (final f in friends)
              if (_newPhotos(account, f.handle) > 0) (f, _newPhotos(account, f.handle)),
          ]..sort((a, b) => b.$2.compareTo(a.$2)))
        : const <(Member, int)>[];
    final newPhotos = fresh.fold(0, (s, e) => s + e.$2);
    Widget chip(Key key, IconData icon, String label, VoidCallback onTap) => ActionChip(
      key: key,
      avatar: Icon(icon, size: Gp.iS, color: Gp.accent),
      label: Text(label),
      backgroundColor: Gp.panel,
      side: const BorderSide(color: Gp.line),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(Gp.rSmall))),
      onPressed: onTap,
    );
    return Container(
      padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 6, 6, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE9F3FB), Color(0xFFE8F8F3), Gp.panel],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '친구',
                style: TextStyle(fontSize: Gp.t19, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              IconButton(
                tooltip: '아이디로 친구 추가',
                onPressed: () => showAddFriend(context),
                icon: const Icon(Icons.person_add_alt_1_outlined, color: Gp.ink),
              ),
              IconButton(
                tooltip: '닫기',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Gp.ink),
              ),
            ],
          ),
          const SizedBox(height: 6),
          InkWell(
            borderRadius: BorderRadius.circular(Gp.radius),
            onTap: () => _close(widget.onOpenProfile),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  MyAvatar(fallback: p.avatarText),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: Gp.t16, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          handle.isNotEmpty ? '@$handle' : (signedIn ? '아이디 없음' : '로그인 전'),
                          style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
                        ),
                        const SizedBox(height: 5),
                        LevelChip(
                          level: guideLevel(
                            lit,
                            0,
                            owned: UserStore.instance.ownedCount,
                            liked: UserStore.instance.wantedCount,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Gp.faint),
                ],
              ),
            ),
          ),
          if (incoming > 0 || newPhotos > 0) ...[
            const SizedBox(height: 10),
            Center(
              child: Wrap(
                // M-3
                spacing: 8,
                children: [
                  if (incoming > 0)
                    chip(
                      const ValueKey('chip-requests'),
                      Icons.notifications_none,
                      '친구 요청 $incoming건',
                      () => showFriendRequests(context),
                    ),
                  if (newPhotos > 0)
                    chip(
                      const ValueKey('chip-new-photos'),
                      Icons.photo_library_outlined,
                      '새 사진 $newPhotos',
                      () => _close(() => widget.onOpenFriend(fresh.first.$1)),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// M-8 로그인 전
  Widget _signInHint() {
    return SectionPanel(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(
        children: [
          const Expanded(
            child: Text('로그인하면 친구를 볼 수 있어요', style: TextStyle(fontSize: Gp.t12, height: 1.4)),
          ),
          const SizedBox(width: 8),
          FilledButton(onPressed: () => openSignIn(context), child: const Text('로그인')),
        ],
      ),
    );
  }

  /// M-4 친구 검색
  Widget _search() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: GpSearchBar(
        hint: '친구 검색', // 홈 · 검색과 같은 검색창 (카메라 없음)
        onChanged: (v) => setState(() => _query = v.trim()), // STATE: 검색어 → 아래 목록 거르기
      ),
    );
  }

  /// M-5 새 친구 · 아이디로 추가
  Widget _newFriends(Account account) {
    final f = account.friends;
    final waiting = f.incoming.length + f.outgoing.length;
    return SectionPanel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.person_add_alt_outlined, color: Gp.ink),
            title: Text(waiting == 0 ? '친구 요청' : '친구 요청 ${f.incoming.length} · 보냄 ${f.outgoing.length}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (f.incoming.isNotEmpty) Badge(backgroundColor: Gp.accent, label: Text('${f.incoming.length}')),
                const Icon(Icons.chevron_right, color: Gp.faint),
              ],
            ),
            onTap: () => showFriendRequests(context),
          ),
        ],
      ),
    );
  }

  /// M-6 · M-7 친구 목록 | 공유 공간
  Widget _lists(List<Member> all, bool signedIn, Account account) {
    bool hit(Member m) => _query.isEmpty || m.name.contains(_query) || m.handle.contains(_query);
    final shown = all.where(hit).toList();
    final open = !_collapsed || _query.isNotEmpty;
    final workspace = signedIn ? account.sync.workspace : null; // 없는 계정이면 탭 자체가 없다
    final space = workspace != null && _spaceTab;
    Widget friendRow(Member m) => ListTile(
      // M-7
      leading: Badge(
        // 새 사진 점
        key: ValueKey('friend-new-${m.handle}'),
        isLabelVisible: _newPhotos(account, m.handle) > 0,
        backgroundColor: Gp.accent,
        smallSize: 9,
        child: FriendAvatar(handle: m.handle, name: m.name),
      ),
      title: Row(
        children: [
          Flexible(child: Text(m.name, overflow: TextOverflow.ellipsis)),
          if (m.lit + m.owned > 0) ...[
            const SizedBox(width: 6),
            LevelChip(
              level: guideLevel(m.lit, m.verified, owned: m.owned, liked: m.liked),
              small: true,
            ),
          ],
        ],
      ),
      subtitle: m.status.isNotEmpty
          ? Text(
              m.status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
            )
          : FriendStatusLine(
              // 최근 담은 것 · 올린 사진 (My Page ★ 와 같은 셈)
              event: signedIn
                  ? latestFriendEvent(account.friends.collections[m.handle], account.photos.walls[m.handle])
                  : null,
              fallback: m.liked + m.owned > 0 ? '@${m.handle} · 좋아요 ${m.liked} · 구매함 ${m.owned}' : '@${m.handle}',
            ),
      // ★ 특별 관심 — My Page ★ 에 이 친구 소식이 뜬다 (기기에만)
      trailing: m.handle.isEmpty
          ? null
          : IconButton(
              tooltip: '특별 관심',
              onPressed: () => setState(
                () => UserStore.instance.setSpecialFriend(
                  m.handle,
                  !UserStore.instance.specialFriends.contains(m.handle),
                ),
              ),
              icon: UserStore.instance.specialFriends.contains(m.handle)
                  ? const Icon(Icons.star_rounded, color: Gp.star)
                  : const Icon(Icons.star_border_rounded, color: Gp.faint),
            ),
      onTap: () => _close(() => widget.onOpenFriend(m)),
    );
    // 특별 관심이 위로
    shown.sort(
      (a, b) =>
          (UserStore.instance.specialFriends.contains(b.handle) ? 1 : 0) -
          (UserStore.instance.specialFriends.contains(a.handle) ? 1 : 0),
    );
    return SectionPanel(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (workspace != null)
            Padding(
              // M-6 친구 | 공유 공간
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
              child: Row(
                children: [
                  UnderlineTab(
                    label: '친구',
                    count: all.length,
                    selected: !space,
                    onTap: () => setState(() => _spaceTab = false), // STATE: 탭 → 친구
                  ),
                  UnderlineTab(
                    key: const ValueKey('tab-space'),
                    label: '공유 공간',
                    count: workspace.members.length,
                    selected: space,
                    onTap: () => setState(() => _spaceTab = true), // STATE: 탭 → 공유 공간
                  ),
                ],
              ),
            ),
          if (space)
            WorkspaceMembers(workspace: workspace, onSelf: () => _close(widget.onOpenProfile))
          else ...[
            InkWell(
              onTap: () => setState(() => _collapsed = open), // STATE: 그룹 접기
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 16, 10),
                child: Row(
                  children: [
                    AnimatedRotation(
                      turns: open ? 0.25 : 0,
                      duration: const Duration(milliseconds: 150),
                      child: const Icon(Icons.arrow_right, color: Gp.muted),
                    ),
                    const Text('친구', style: TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text(
                      '${shown.length}/${all.length}',
                      style: const TextStyle(fontSize: Gp.t12, color: Gp.faint),
                    ),
                  ],
                ),
              ),
            ),
            if (open && all.isEmpty && signedIn)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  '아직 친구가 없어요',
                  style: TextStyle(fontSize: Gp.t12, color: Gp.muted),
                ),
              ),
            if (open)
              for (final m in shown) friendRow(m),
          ],
        ],
      ),
    );
  }
}
