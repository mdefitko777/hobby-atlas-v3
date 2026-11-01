// 화면 M: 친구 서랍 — 왼쪽 위 아바타를 누르거나, 홈에서 왼쪽 가장자리를 밀면 나온다 (QQ 옆 서랍처럼)
// 위: 내 프로필 요약(아바타를 한 번 더 누르면 I 내 정보) · 아래: 친구 (검색 · 새 친구 요청 · 목록)
// v3: 친구 · 요청은 Gunpula 계정(v3 get_me), 친구 숫자는 get_friend_collection. 알 수도 있는 친구 · 공유 공간 탭은 서버가 없어 뺐다.
//
// ┌──────── 디자인 가이드 대응표: M 친구 서랍 ─────────────────────────────────────────┐
// │ 번호 │ Flutter 위젯명                     │ 비즈니스 명칭(한글)                    │ 원칙(P번호)   │
// │ M-1  │ Drawer (아바타 · 홈 가장자리 밀기)    │ 친구 서랍 열기 · 닫기(밖 누르기 · X)     │ P03 · P07     │
// │ M-2  │ 색 고리 아바타 · 이름 · Lv          │ 내 프로필 요약 → 내 정보                │ P04           │
// │ M-3  │ 알약 버튼 (요청이 있을 때만)          │ 새 친구 요청 n건                        │ P01           │
// │ M-4  │ GpSearchBar (카메라 없는 모드)        │ 친구 검색 (홈 · 검색과 같은 검색창)       │ P07 · P04     │
// │ M-5  │ ListTile + 배지 · 친구 추가          │ 새 친구(받은 · 보낸 요청) · 아이디로 추가  │ P07 · P01     │
// │ M-6  │ 접히는 그룹                         │ 친구 n명                               │ P06           │
// │ M-7  │ 친구 줄 (좋아요 · 구매함 수)          │ 친구 → 친구 프로필(I 친구 보기)          │ P07           │
// │ M-8  │ 안내 + 로그인 버튼                   │ 로그인 전                              │ P09           │
// └──────────────────────────────────────────────────────────────────────────────────┘
// 전환: 서랍 → 내 정보 · 친구 프로필(쌓기, 서랍은 닫힘). 요청 · 추가 → 덮기(바텀 시트).
import 'package:flutter/material.dart';

import '../api.dart';
import '../data/user_store.dart';
import '../models.dart';
import '../sync/account.dart';
import '../sync/friends_service.dart';
import '../theme.dart';
import '../widgets.dart';
import 'p_sign_in_screen.dart';
import 'q_friend_sheets.dart';
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

  @override
  void initState() {
    super.initState();
    // 열 때마다: 친구 · 요청 새로 + 친구 숫자 (실패해도 받아 둔 것으로 그린다)
    final a = AccountScope.read(context);
    if (a.signedIn) {
      a.friends.refresh().then((_) => a.friends.loadAllCollections(force: true)).catchError((Object _) {});
    }
  }

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
              _header(p, lit, account),
              if (!signedIn) _signInHint() else ...[_search(), _newFriends(account)],
              _lists(friends, signedIn),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  /// M-2 내 프로필 요약 (QQ 서랍 머리처럼, 다만 밝은 바탕)
  Widget _header(Profile p, int lit, Account account) {
    final signedIn = account.signedIn;
    final name = signedIn ? account.displayName : p.name;
    final handle = signedIn ? account.handle : p.handle;
    final incoming = account.incomingCount;
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
                  RingAvatar(text: signedIn ? account.initial : p.avatarText),
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
                          handle.isNotEmpty ? '@$handle' : (signedIn ? '아이디 없음 · 내 정보에서 정하기' : '로그인 전'),
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
          if (incoming > 0) ...[
            const SizedBox(height: 10),
            Center(
              child: ActionChip(
                // M-3
                avatar: const Icon(Icons.notifications_none, size: Gp.iS, color: Gp.accent),
                label: Text('친구 요청 $incoming건'),
                backgroundColor: Gp.panel,
                side: const BorderSide(color: Gp.line),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(Gp.rSmall))),
                onPressed: () => showFriendRequests(context),
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
            child: Text('로그인하면 동생 · 친구를 아이디로 추가하고 서로의 컬렉션을 볼 수 있어요', style: TextStyle(fontSize: Gp.t12, height: 1.4)),
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
            title: const Text('새 친구'),
            subtitle: Text(
              f.unavailable
                  ? '서버에 친구 기능이 아직 없어요'
                  : waiting == 0
                  ? '받은 요청 없음'
                  : '받은 요청 ${f.incoming.length} · 보낸 요청 ${f.outgoing.length}',
              style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (f.incoming.isNotEmpty) Badge(backgroundColor: Gp.accent, label: Text('${f.incoming.length}')),
                const Icon(Icons.chevron_right, color: Gp.faint),
              ],
            ),
            onTap: () => showFriendRequests(context),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            leading: const Icon(Icons.alternate_email, color: Gp.ink),
            title: const Text('아이디로 친구 추가'),
            subtitle: Text(
              account.handle.isEmpty ? '내 아이디부터 정해요' : '내 아이디 @${account.handle}',
              style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
            ),
            trailing: const Icon(Icons.chevron_right, color: Gp.faint),
            onTap: () => showAddFriend(context),
          ),
        ],
      ),
    );
  }

  /// M-6 · M-7 친구 목록
  Widget _lists(List<Member> all, bool signedIn) {
    bool hit(Member m) => _query.isEmpty || m.name.contains(_query) || m.handle.contains(_query);
    final shown = all.where(hit).toList();
    final open = !_collapsed || _query.isNotEmpty;
    Widget friendRow(Member m) => ListTile(
      // M-7
      leading: CircleThumb(image: '', label: m.name, size: 42),
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
      subtitle: Text(
        m.status.isNotEmpty
            ? m.status
            : (m.liked + m.owned > 0 ? '@${m.handle} · 좋아요 ${m.liked} · 구매함 ${m.owned}' : '@${m.handle}'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
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
                '아직 친구가 없어요 · 위의 "아이디로 친구 추가"에서 동생 · 친구의 아이디를 넣어 보세요',
                style: TextStyle(fontSize: Gp.t12, color: Gp.muted),
              ),
            ),
          if (open)
            for (final m in shown) friendRow(m),
        ],
      ),
    );
  }
}
