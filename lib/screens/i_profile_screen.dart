// 화면 I: 내 정보 — 프로필 · 취향 태그 · 수집 숫자 · 사진 벽 · 친구 추가(아이디) (친구 서랍 머리에서 열림, 설정은 K 화면)
// 같은 화면을 친구 보기로도 쓴다: 친구 이름을 누르면 그 친구의 숫자 · 사진 벽 · 태그 (편집 없음, 친구 끊기)
// v3: 이름 · @아이디 · 친구는 Gunpula 계정(v3 get_me), 숫자는 내 기록(Marks), 태그는 preferences.tags,
//     사진 벽은 직접 찍은 사진만 (공식 상품 사진은 넣지 않는다). 친구 사진은 Storage(docs/supabase-v3-photos.sql).
//     아바타 · 배경 · 사진 공개 범위 · 공유 공간은 u_social.dart (서버 = docs/supabase-v3-social.sql, 없으면 기기에만).
// 숫자 · 아이콘은 My Page(A-21)와 같은 모양: ♡ | 리본, 이번 달 | 총 지출을 평평한 한 줄에 (떠 있는 판 없음).
//
// ┌──────── 디자인 가이드 대응표: I 내 정보 ───────────────────────────────────────────┐
// │ 번호 │ Flutter 위젯명                     │ 비즈니스 명칭(한글)                    │ 원칙(P번호)   │
// │ I-1  │ 배경 사진 위 색 고리 큰 아바타(사진) · 이름 · Lv · @아이디 │ 내 프로필 (U-1 · U-3)  │ P04 · P02  │
// │ I-2  │ TagPill 줄                          │ 내 취향 태그 (친구에게도 보임)            │ P06           │
// │ I-3  │ ✎ 아이콘 → 바텀 시트(액션 목록)       │ 아바타 · 배경 · 이름 · 아이디 · 태그 바꾸기 │ P03 · P07     │
// │ I-4  │ 떠 있는 숫자 묶음 2개 (아이콘 + 숫자)  │ ♡ · 리본 · 미조립 → 컬렉션 / 이번 달 · 총 지출 │ P01 · P07   │
// │ I-14 │ 머리 공유 아이콘 → V 공유 카드        │ 내 컬렉션 카드 (그림으로 공유 · 저장)      │ P07 · P10     │
// │ I-5  │ 친구 줄: 👥 n · 추가 · 요청 아이콘     │ 친구 추가 (아이디로) · 받은 요청 · 내 아이디 복사 │ P07 · P08 │
// │ I-5b │ WorkspaceMembers (U-6, 있을 때만)    │ 공유 공간 이름 · 멤버 · 역할 (읽기만)       │ P06 · P08     │
// │ I-6  │ PhotoWall 3열 (T-1)                 │ 사진 벽: 직접 찍은 사진만                   │ P02 · P06     │
// │ I-7  │ 사진 칸 → T 사진 보기                │ 친구에게 보이기 · 워터마크 저장            │ P05 · P10     │
// │ I-9  │ 👥/🔒 아이콘 → 바텀 시트(U-5)         │ 사진 공개 범위 (전체 끄기 · 친구별 숨기기)  │ P05 · P07     │
// │ I-13 │ 안내 카드 + 버튼                     │ 로그인하기 · 아이디 정하기                │ P09 · P10     │
// │ I-11 │ 친구 숫자 → L 친구 컬렉션            │ 친구의 좋아요 · 구매함 · 도감 비교(+사진 수) │ P07           │
// │ I-12 │ OutlinedButton → 확인 대화상자        │ 친구 끊기                              │ P05           │
// │ I-8  │ LoadingView / ErrorView             │ 불러오는 중 · 오류                      │ P01 · P09     │
// │ I-15 │ AppBar 오른쪽 ? (HelpButton)       │ 숫자 · 편집 · 친구 · 사진 벽 아이콘 뜻     │ P10           │
// └──────────────────────────────────────────────────────────────────────────────────┘
// 전환: 친구 서랍(M) 머리 아바타 → 쌓기(push, 오른쪽에서 · 넓은 화면은 오른쪽 칸). 숫자 → 닫고 컬렉션 탭(옆으로).
//       친구 → 쌓기. 사진 → 쌓기(T). 편집 · 태그 · 사진 넣기 · 아바타 · 배경 · 공개 범위 → 덮기(바텀 시트).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../api.dart';
import '../channels.dart';
import '../clock.dart';
import '../data/social_local.dart' show ProfileImageKind;
import '../detail_pane.dart';
import '../l10n/l10n.dart';
import '../level.dart';
import '../logic/build_status.dart';
import '../logic/level_math.dart';
import '../marks.dart';
import '../models.dart';
import '../sync/account.dart';
import '../sync/friends_service.dart' show FriendsFailure;
import '../sync/photo_share.dart';
import '../theme.dart';
import '../widgets.dart';
import 'f_collection_screen.dart' show CollectionJump;
import 'l_friend_collection_screen.dart';
import 'p_sign_in_screen.dart';
import 'q_friend_sheets.dart';
import 't_photo_screen.dart';
import 'u_social.dart';
import 'v_share_sheet.dart' show openCollectionShare;

void openProfile(
  BuildContext context, {
  Loaders loaders = const Loaders(),
  ValueChanged<CollectionJump>? onJump,
  List<String>? myChannels,
}) {
  openPage(context, ProfileScreen(loaders: loaders, onJump: onJump, myChannels: myChannels));
}

/// 친구 프로필 (같은 화면, 보기 전용)
void openFriend(BuildContext context, Member friend, {Loaders loaders = const Loaders()}) {
  openPage(
    context,
    ProfileScreen(loaders: loaders, friend: friend),
    id: friend.handle,
  );
}

/// 친구의 컬렉션을 계정에서 받아 화면 모델로 (프로필 · 친구 컬렉션이 같이 쓴다)
Future<Member> loadFriendMember(Account account, String handle, Loaders loaders, {bool force = true}) async {
  final c = await account.friends.collection(handle, force: force);
  Map<String, int> guide = const {};
  try {
    guide = await loaders.friendGuide(c.ownedIds).timeout(const Duration(seconds: 8));
  } on Object {
    // 도감 데이터가 아직 없으면 0
  }
  return Member(
    name: c.profile.name,
    handle: c.profile.handle,
    role: '친구',
    self: false,
    liked: c.likedIds.length,
    lit: guide.values.fold(0, (s, n) => s + n),
    owned: c.ownedIds.length,
    likedIds: c.likedIds,
    ownedIds: c.ownedIds,
    guide: guide,
  );
}

/// 취향 태그 한도
const _maxTags = 8;
const _maxTagLength = 12;

class _ProfileData {
  const _ProfileData(this.profile, this.collection, this.lit);
  final Profile profile;
  final List<Kit> collection;

  /// 도감 점등 칸 수 (작품 도감의 수집 합)
  final int lit;
}

/// 친구 보기: 숫자 · 사진 벽(+태그)
class _FriendData {
  const _FriendData(this.member, this.wall);
  final Member member;
  final FriendWall wall;
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.loaders = const Loaders(), this.onJump, this.friend, this.myChannels});
  final Loaders loaders;

  /// 주면 숫자를 내 채널 안에서만 센다 (컬렉션 탭 '전체'와 같은 범위)
  final List<String>? myChannels;

  /// 숫자를 누르면 이 화면을 닫고 컬렉션 탭의 그 목록으로
  final ValueChanged<CollectionJump>? onJump;

  /// 있으면 친구 보기
  final Member? friend;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<_ProfileData> _future;

  /// 친구 보기: 계정에서 받은 최신 숫자 · 사진 벽 (계정 친구가 아니면 넘겨받은 그대로)
  Future<_FriendData>? _friendFuture;

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.friend == null) {
      // 못 올린 사진이 있으면 다시 (서버에 사진 공유가 없으면 ⚠ 가 켜진다)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) AccountScope.read(context).photos.sync().ignore();
      });
    }
  }

  void _load() {
    // STATE: 내 정보 · 내 채널 상품 · 도감 → 숫자
    _future = Future.wait([
      widget.loaders.profile(),
      widget.loaders.kits(widget.myChannels ?? [for (final c in allChannels) c.id]), // 내 채널 상품 전부 → Marks 로 셈
      widget.loaders.guideWorks(),
    ]).then((r) => _ProfileData(r[0] as Profile, r[1] as List<Kit>, litCount(r[2] as List<GuideWork>)));
    final f = widget.friend;
    if (f != null) _friendFuture = _loadFriend(f);
  }

  Future<_FriendData> _loadFriend(Member f) async {
    final account = AccountScope.read(context);
    final real = account.signedIn && account.friends.friends.any((x) => x.handle == f.handle);
    // STATE: 친구 컬렉션(get_friend_collection) · 사진 벽(get_friend_wall, 없으면 빈 벽)
    final results = await Future.wait<Object>([
      real ? loadFriendMember(account, f.handle, widget.loaders) : Future.value(f),
      real ? account.photos.friendWall(f.handle, force: true) : Future.value(const FriendWall()),
    ]);
    final m = results[0] as Member;
    if (real) await account.profileImages.cacheFriendAvatars(); // I-1 친구 아바타 (사진 벽의 avatar_path)
    return _FriendData(m, results[1] as FriendWall);
  }

  void _jump(CollectionJump j) {
    Navigator.pop(context);
    widget.onJump?.call(j);
  }

  /// I-3 이름 · 아이디 · 태그
  void _editProfile() {
    showGpSheet<void>(
      // I-3 덮기
      context,
      builder: (sheet) {
        Widget row(IconData icon, String label, VoidCallback onTap) => ListTile(
          leading: Icon(icon, size: Gp.iM),
          title: Text(label, style: const TextStyle(fontSize: Gp.t14)),
          onTap: () {
            Navigator.pop(sheet);
            onTap();
          },
        );
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              row(Icons.account_circle_outlined, tr('아바타'), () => editProfileImage(context, ProfileImageKind.avatar)),
              row(Icons.wallpaper_outlined, tr('배경'), () => editProfileImage(context, ProfileImageKind.cover)),
              row(Icons.edit_outlined, tr('이름'), () {
                if (ensureSignedIn(context)) askDisplayName(context);
              }),
              row(Icons.alternate_email, tr('아이디'), () {
                if (ensureSignedIn(context)) askHandle(context);
              }),
              row(Icons.sell_outlined, tr('취향 태그'), _editTags),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  /// I-2 취향 태그 고치기 — 기기에 두고, 로그인했으면 v3 preferences.tags 에도
  Future<void> _editTags() async {
    final store = Marks.read(context).store;
    final account = AccountScope.read(context);
    final next = await showGpSheet<List<String>>(
      context,
      tall: true,
      builder: (_) => _TagSheet(initial: _myTags(store.profileTags, account)),
    );
    if (next == null || !mounted) return;
    store.setProfileTags(next);
    if (!account.signedIn) return;
    try {
      await account.friends.setTags(next);
    } on FriendsFailure catch (e) {
      if (mounted) showToast(context, e.message);
    }
  }

  /// 기기에 정한 태그 → 없으면 서버(다른 기기에서 정한 것)
  List<String> _myTags(List<String> local, Account account) =>
      local.isNotEmpty ? local : (account.signedIn ? account.friends.me?.tags ?? const [] : const []);

  Future<void> _unfriend(Member m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(trf('{name}님과 친구를 끊을까요?', {'name': m.name})),
        content: Text(tr('서로의 컬렉션 · 사진이 더 이상 보이지 않아요.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(tr('취소'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Gp.danger),
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(tr('친구 끊기')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await AccountScope.read(context).friends.remove(m.handle);
      if (!mounted) return;
      showToast(context, trf('{name}님과 친구를 끊었어요', {'name': m.name}));
      Navigator.of(context).maybePop();
    } on FriendsFailure catch (e) {
      if (mounted) showToast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final friend = widget.friend;
    return Scaffold(
      appBar: AppBar(
        title: friend == null ? Text(tr('내 정보')) : null,
        actions: [
          if (friend == null)
            IconButton(
              // I-14 공유 카드
              key: const ValueKey('profile-share'),
              tooltip: tr('공유 카드'),
              onPressed: () => openCollectionShare(context, loaders: widget.loaders),
              icon: const Icon(Icons.ios_share, size: Gp.iL),
            ),
          // I-15 ?
          HelpButton(
            title: tr(friend == null ? '내 정보' : '친구'),
            items: friend == null ? profileHelp() : friendProfileHelp(),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: FutureBuilder<_ProfileData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingView(); // I-8
          if (snap.hasError) return ErrorView(message: '${snap.error}', onRetry: () => setState(_load));
          if (friend == null) return _mine(snap.data!.profile, snap.data!);
          return FutureBuilder<_FriendData>(
            future: _friendFuture,
            builder: (context, fs) {
              if (fs.connectionState != ConnectionState.done) return const LoadingView();
              if (fs.hasError) return ErrorView(message: '${fs.error}', onRetry: () => setState(_load));
              return _friend(fs.data ?? _FriendData(friend, const FriendWall()));
            },
          );
        },
      ),
    );
  }

  Widget _mine(Profile p, _ProfileData d) {
    final scope = widget.myChannels;
    final marks = Marks.of(context); // 앱 전체 한 벌 — 홈에서 누른 ♡ · 리본 · 새 사진도 반영
    final store = marks.store;
    final account = AccountScope.of(context); // 로그인 · 아이디 · 친구 · 사진 공유가 바뀌면 다시 그림
    final mine = d.collection.where((k) => scope == null || scope.contains(k.franchiseId));
    final liked = mine.where(marks.liked).length;
    final owned = mine.where(marks.owned).length;
    final signedIn = account.signedIn;
    final name = signedIn ? account.displayName : p.name;
    final handle = signedIn ? account.handle : p.handle;
    final level = guideLevel(d.lit, 0, owned: store.ownedCount); // 왼쪽 위 Lv 와 같은 셈 (lib/level.dart)
    final jump = widget.onJump == null ? null : _jump;

    // I-6 사진 벽: 직접 찍은 사진만
    final photos = store.photos;

    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        _Header(
          name: name,
          subtitle: handle.isNotEmpty ? '@$handle' : tr(signedIn ? '아이디 없음' : '로그인 전'),
          avatar: MyAvatar(fallback: name.characters.isEmpty ? tr('나') : name.characters.first, size: 76, ringWidth: 3),
          cover: ProfileCover(file: store.social.image(ProfileImageKind.cover)?.file ?? ''),
          level: level,
          onLevel: jump == null ? null : () => jump(CollectionJump.guide),
          tags: _myTags(store.profileTags, account),
          onEdit: _editProfile,
        ),
        if (!signedIn)
          _Hint(
            // I-13 P09
            icon: Icons.cloud_outlined,
            text: tr('로그인 전이에요'),
            action: tr('로그인'),
            onTap: () => openSignIn(context),
          )
        else if (account.handle.isEmpty && !account.friends.unavailable)
          _Hint(
            icon: Icons.alternate_email,
            text: tr('아이디가 없어요'),
            action: tr('아이디 정하기'),
            onTap: () => askHandle(context),
          ),
        Padding(
          // I-4 My Page 와 같은 두 묶음 (lib/widgets/stats.dart)
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: CollectionStats(
            liked: liked,
            owned: owned,
            backlog: backlogCount([
              for (final k in mine)
                if (marks.owned(k) && needsAssembly(k)) k.id,
            ], store.stageOf),
            month: store.spendInMonth(appNow()),
            total: store.spendKrw,
            onLiked: jump == null ? null : () => jump(CollectionJump.liked),
            onOwned: jump == null ? null : () => jump(CollectionJump.owned),
            onBacklog: jump == null ? null : () => jump(CollectionJump.backlog),
          ),
        ),
        PhotoWall(
          // I-6 · I-7
          warn: signedIn && photos.any((ph) => ph.shared) ? photoWarn(account.photos) : '',
          extra: signedIn
              ? IconButton(
                  // I-9 공개 범위
                  key: const ValueKey('photo-privacy'),
                  tooltip: tr('공개 범위'),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => showPhotoPrivacy(context),
                  icon: Icon(privacyIcon(store.social), size: Gp.iM, color: Gp.muted),
                )
              : null,
          onAdd: () => addMyPhoto(context),
          tiles: [for (final ph in photos) MyPhotoTile(ph)],
        ),
        if (signedIn) _friendsPanel(account),
        if (signedIn && account.sync.workspace != null)
          SectionPanel(
            // I-5b 공유 공간 (읽기만)
            padding: const EdgeInsets.only(bottom: 6),
            child: WorkspaceMembers(workspace: account.sync.workspace!),
          ),
      ],
    );
  }

  /// I-5 친구 줄 — 👥 n · 아이디로 추가 · 받은 요청 / 내 @아이디 복사
  Widget _friendsPanel(Account account) {
    final f = account.friends;
    return SectionPanel(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.group_outlined, size: Gp.iM, color: Gp.ink),
              const SizedBox(width: 6),
              if (!f.unavailable)
                Text(
                  '${f.friends.length}',
                  style: const TextStyle(fontSize: Gp.t14, fontWeight: FontWeight.w700),
                ),
              const Spacer(),
              IconButton(
                tooltip: tr('아이디로 친구 추가'),
                onPressed: () => showAddFriend(context),
                icon: const Icon(Icons.person_add_alt_1_outlined, size: Gp.iL, color: Gp.ink),
              ),
              IconButton(
                tooltip: tr('친구 요청'),
                onPressed: () => showFriendRequests(context),
                icon: Badge(
                  isLabelVisible: f.incoming.isNotEmpty,
                  label: Text('${f.incoming.length}'),
                  backgroundColor: Gp.accent,
                  child: const Icon(Icons.mail_outline, size: Gp.iL, color: Gp.ink),
                ),
              ),
            ],
          ),
          if (account.handle.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 8, top: 2),
              padding: const EdgeInsets.fromLTRB(12, 2, 2, 2),
              decoration: BoxDecoration(color: Gp.bg, borderRadius: BorderRadius.circular(Gp.radius)),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '@${account.handle}',
                      style: const TextStyle(fontSize: Gp.t14, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: tr('아이디 복사'), // P07
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: '@${account.handle}'));
                      showToast(context, tr('아이디를 복사했어요'));
                    },
                    icon: const Icon(Icons.content_copy_rounded, size: Gp.iM, color: Gp.muted),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _friend(_FriendData d) {
    final m = d.member;
    final account = AccountScope.of(context);
    final real = account.signedIn && account.friends.friends.any((x) => x.handle == m.handle);
    // I-11 · L-3 도감 비교에 친구 사진 수도
    void open(CollectionJump j) => openFriendCollection(
      context,
      m,
      j,
      loaders: widget.loaders,
      photoKitIds: [for (final ph in d.wall.photos) ph.kitId],
    );
    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        _Header(
          name: m.name,
          subtitle: '@${m.handle}',
          avatar: FriendAvatar(handle: m.handle, name: m.name, size: 76, ring: true),
          cover: ProfileCover(path: d.wall.coverPath),
          level: guideLevel(m.lit, 0, owned: m.owned),
          onLevel: () => open(CollectionJump.guide),
          tags: d.wall.tags,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: StatGroups(
            groups: [
              [
                StatCell(const LikedIcon(), '${m.liked}', tr('좋아요'), onTap: () => open(CollectionJump.liked)),
                StatCell(const OwnedIcon(), '${m.owned}', tr('구매함'), onTap: () => open(CollectionJump.owned)),
              ],
              [
                StatCell(
                  const Icon(Icons.auto_awesome_mosaic_outlined, size: Gp.iS, color: Gp.muted),
                  '${m.lit}',
                  tr('도감'),
                  onTap: () => open(CollectionJump.guide),
                ),
                StatCell(
                  const Icon(Icons.photo_library_outlined, size: Gp.iS, color: Gp.muted),
                  '${d.wall.photos.length}',
                  tr('사진'),
                ),
              ],
            ],
          ),
        ),
        PhotoWall(
          // I-6 친구가 보이기로 둔 사진만
          tiles: [for (final ph in d.wall.photos) FriendPhotoTile(ph)],
        ),
        if (real)
          Padding(
            // I-12 P05
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: OutlinedButton.icon(
              onPressed: () => _unfriend(m),
              style: OutlinedButton.styleFrom(foregroundColor: Gp.danger),
              icon: const Icon(Icons.person_remove_outlined, size: Gp.iM),
              label: Text(tr('친구 끊기')),
            ),
          ),
      ],
    );
  }
}

/// I-13 안내 카드 (로그인 · 아이디)
class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text, required this.action, required this.onTap});
  final IconData icon;
  final String text;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SectionPanel(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(
        children: [
          Icon(icon, size: Gp.iL, color: Gp.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: Gp.t14)),
          ),
          const SizedBox(width: 8),
          FilledButton(onPressed: onTap, child: Text(action)),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.subtitle,
    required this.avatar,
    required this.cover,
    required this.level,
    required this.tags,
    this.onLevel,
    this.onEdit,
  });
  final String name;

  /// @아이디 (없으면 안내 글)
  final String subtitle;

  /// I-1 색 고리 큰 아바타 (사진 · 첫 글자)
  final Widget avatar;

  /// 배경 사진 (70 높이 띠)
  final Widget cover;
  final int level;
  final List<String> tags;

  /// Lv 누르면 (도감)
  final VoidCallback? onLevel;

  /// 없으면(친구 보기) 편집 아이콘을 숨긴다
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final chip = LevelChip(level: level);
    return ColoredBox(
      color: Gp.panel,
      child: Stack(
        children: [
          Column(
            children: [
              cover, // 배경(커버)
              const SizedBox(height: 56), // 아바타가 겹쳐 앉는 자리
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gp.gutter),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: Gp.t19, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    onLevel == null
                        ? chip
                        : InkWell(borderRadius: BorderRadius.circular(Gp.rSmall), onTap: onLevel, child: chip),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
              ),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Gp.gutter),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: [for (final t in tags) TagPill(t)], // I-2 P06
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
          Positioned(top: 30, left: 0, right: 0, child: Center(child: avatar)), // I-1 P04
          if (onEdit != null)
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                tooltip: tr('프로필 편집'), // I-3
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: Gp.iM, color: Gp.ink),
              ),
            ),
        ],
      ),
    );
  }
}

/// 숫자 한 칸: 아이콘 + 숫자 (뜻은 툴팁)
/// I-2 취향 태그 시트 — 적고 + · 꼬리표 누르면 빼기 · ✓ 로 저장
class _TagSheet extends StatefulWidget {
  const _TagSheet({required this.initial});
  final List<String> initial;

  @override
  State<_TagSheet> createState() => _TagSheetState();
}

class _TagSheetState extends State<_TagSheet> {
  late final List<String> _tags = [...widget.initial];
  final _ctl = TextEditingController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _add() {
    final t = _ctl.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (t.isEmpty || _tags.contains(t) || _tags.length >= _maxTags) return;
    setState(() {
      _tags.add(t.length > _maxTagLength ? t.substring(0, _maxTagLength) : t); // STATE: 태그 → 꼬리표 줄
      _ctl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.sell_outlined, size: Gp.iM),
              const SizedBox(width: 6),
              Text(
                '${_tags.length}/$_maxTags',
                style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
              ),
              const Spacer(),
              IconButton(
                tooltip: tr('저장'),
                onPressed: () {
                  _add(); // 적어 두고 + 를 안 눌렀어도 넣는다
                  Navigator.pop(context, _tags);
                },
                icon: const Icon(Icons.check, size: Gp.iL, color: Gp.accent),
              ),
            ],
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in _tags)
                InkWell(
                  borderRadius: BorderRadius.circular(Gp.rSmall),
                  onTap: () => setState(() => _tags.remove(t)),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(Gp.rSmall),
                      border: Border.all(color: Gp.line),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(t, style: const TextStyle(fontSize: Gp.t12)),
                        const SizedBox(width: 2),
                        const Icon(Icons.close, size: Gp.iXS, color: Gp.faint),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _ctl,
            maxLength: _maxTagLength,
            enabled: _tags.length < _maxTags,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _add(),
            decoration: InputDecoration(
              hintText: tr('건담 · 베이블레이드 …'),
              counterText: '',
              suffixIcon: IconButton(
                tooltip: tr('태그 더하기'),
                onPressed: _add,
                icon: const Icon(Icons.add, size: Gp.iM),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// I-15 ? 도움말 — 내 정보
List<HelpItem> profileHelp() => [
  HelpItem(Icons.ios_share, tr('공유 카드 (그림으로 공유 · 저장)')),
  HelpItem(Icons.edit_outlined, tr('프로필 편집 (아바타 · 배경 · 이름 · 아이디 · 태그)')),
  HelpItem.widget(const LikedIcon(size: Gp.iL), tr('좋아요 수 → 컬렉션')),
  HelpItem.widget(const OwnedIcon(size: Gp.iL), tr('구매함 수 → 컬렉션')),
  HelpItem(Icons.inventory_2_outlined, tr('미조립 수 → 구매함')),
  HelpItem(Icons.calendar_month_outlined, tr('이번 달 지출')),
  HelpItem(Icons.account_balance_wallet_outlined, tr('총 지출')),
  HelpItem(Icons.person_add_alt_1_outlined, tr('아이디로 친구 추가')),
  HelpItem(Icons.mail_outline, tr('받은 친구 요청')),
  HelpItem(Icons.content_copy_rounded, tr('내 아이디 복사')),
  HelpItem(Icons.add_a_photo_outlined, tr('사진 넣기 (사진 벽)')),
  HelpItem(Icons.group_outlined, tr('사진 공개 범위')),
  HelpItem(Icons.lock_outline, tr('사진 공개 끔')),
  HelpItem(Icons.warning_amber_rounded, tr('올리지 못한 사진 있음'), color: Gp.star),
];

/// I-15 ? 도움말 — 친구 보기
List<HelpItem> friendProfileHelp() => [
  HelpItem.widget(const LikedIcon(size: Gp.iL), tr('친구의 좋아요')),
  HelpItem.widget(const OwnedIcon(size: Gp.iL), tr('친구의 구매함')),
  HelpItem(Icons.auto_awesome_mosaic_outlined, tr('도감 비교')),
  HelpItem(Icons.photo_library_outlined, tr('친구가 보이기로 둔 사진')),
  HelpItem(Icons.person_remove_outlined, tr('친구 끊기')),
];
