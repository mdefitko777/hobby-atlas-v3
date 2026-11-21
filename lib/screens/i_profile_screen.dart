// 화면 I: 내 정보 — 배경 사진 · 프로필 카드 · 좋아요 · 구매함 · 예약 금액 · 구매 금액 · 내 사진 · 친구 (서랍 머리 › 에서 열림, 설정은 K 화면)
// 같은 화면을 친구 보기로도 쓴다: 친구 이름을 누르면 그 친구의 숫자 · 사진 · 태그 (편집 없음, 친구 끊기)
// v3: 이름 · @아이디 · 친구는 Gunpula 계정(v3 get_me), 숫자는 내 기록(Marks), 태그는 preferences.tags,
//     사진 벽은 직접 찍은 사진만 (공식 상품 사진은 넣지 않는다). 친구 사진은 Storage(docs/supabase-v3-photos.sql).
//     아바타 · 배경 · 사진 공개 범위는 u_social.dart (서버 = docs/supabase-v3-social.sql, 없으면 기기에만). 공유 공간 칸은 뺐다 (2026-11-20).
// 2026-11-21 주인 시안: 맨 위 배경 사진(아래로 당기면 늘어나며 커지고 놓으면 돌아옴) 위에 둥근 흰 카드가 겹쳐 앉고,
//     그 아래 회색 틈 · 목록 줄 · 맨 아래 공유 카드 | 프로필 편집 두 단추. 옛 숫자 칸 · AppBar 공유 · ? 는 이 줄들로.
//
// ┌──────── 디자인 가이드 대응표: I 내 정보 ───────────────────────────────────────────┐
// │ 번호 │ Flutter 위젯명                     │ 비즈니스 명칭(한글)                    │ 원칙(P번호)   │
// │ I-1  │ SliverAppBar(stretch) 배경 사진 + 둥근 흰 카드 │ 배경 사진(당기면 커짐) · 색 고리 아바타 · 이름 · Lv · @아이디 복사 (U-1 · U-3) │ P04 · P02 │
// │ I-2  │ 카드 아래 한 줄 + ›                  │ 한 줄 소개 = 내 취향 태그 (친구에게도 보임) → 태그 고치기 │ P06 │
// │ I-3  │ 프로필 편집 단추 → 바텀 시트(액션 목록) │ 프로필 사진 · 배경 사진 · 이름 · 아이디 · 태그 바꾸기 │ P03 · P07 │
// │ I-4  │ 목록 줄 (아이콘 · 이름 · 값 · ›)       │ 좋아요 n · 구매함 n · 예약 금액 · 구매 금액(이번 달) → 컬렉션 탭 그 목록 │ P01 · P07 │
// │ I-14 │ 공유 카드 단추 → V 공유 카드          │ 내 컬렉션 카드 (그림으로 공유 · 저장)      │ P07 · P10     │
// │ I-5  │ 친구 줄 (n · 빨간 요청 수 · +)        │ 친구 화면(M) · 아이디로 친구 추가          │ P07 · P08     │
// │ I-6  │ 내 사진 줄 + 2열 미리 보기 (T-1)      │ 사진 벽: 직접 찍은 사진만 · › = 전부 · 사진 넣기 │ P02 · P06 │
// │ I-7  │ 사진 칸 → T 사진 보기                │ 친구에게 보이기 · 워터마크 저장            │ P05 · P10     │
// │ I-9  │ 👥/🔒 아이콘 → 바텀 시트(U-5)         │ 사진 공개 범위 (전체 끄기 · 친구별 숨기기)  │ P05 · P07     │
// │ I-13 │ 안내 카드 + 버튼                     │ 로그인하기 · 아이디 정하기                │ P09 · P10     │
// │ I-11 │ 친구 보기 줄 → L 친구 컬렉션          │ 친구의 좋아요 · 구매함 · 도감 비교(+사진 수) │ P07           │
// │ I-12 │ OutlinedButton → 확인 대화상자        │ 친구 끊기                              │ P05           │
// │ I-8  │ LoadingView / ErrorView             │ 불러오는 중 · 오류                      │ P01 · P09     │
// │ I-15 │ 서랍 › 사용법 (profileHelp)          │ 줄 · 단추 · 사진 벽 아이콘 뜻             │ P10           │
// └──────────────────────────────────────────────────────────────────────────────────┘
// 전환: 서랍(M) 머리 › → 쌓기(push, 오른쪽에서 · 넓은 화면은 오른쪽 칸). 숫자 줄 → 닫고 컬렉션 탭(옆으로).
//       친구 줄 → 친구 화면(쌓기). 사진 → 쌓기(T). 편집 · 태그 · 사진 넣기 · 아바타 · 배경 · 공개 범위 → 덮기(바텀 시트).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../api.dart';
import '../channels.dart';
import '../clock.dart';
import '../data/user_store.dart';
import '../data/social_local.dart' show ProfileImageKind;
import '../detail_pane.dart';
import '../l10n/l10n.dart';
import '../level.dart';
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
import 'm_friends_drawer.dart' show openFriends;
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
              row(
                Icons.account_circle_outlined,
                tr('프로필 사진'),
                () => editProfileImage(context, ProfileImageKind.avatar),
              ),
              row(Icons.wallpaper_outlined, tr('배경 사진'), () => editProfileImage(context, ProfileImageKind.cover)),
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
        content: Text(tr('서로의 컬렉션 · 사진이 더 이상 보이지 않아요')),
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
      body: FutureBuilder<_ProfileData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return _plain(const LoadingView()); // I-8
          if (snap.hasError) {
            return _plain(ErrorView(message: errorText(snap.error ?? ''), onRetry: () => setState(_load)));
          }
          if (friend == null) return _mine(snap.data!.profile, snap.data!);
          return FutureBuilder<_FriendData>(
            future: _friendFuture,
            builder: (context, fs) {
              if (fs.connectionState != ConnectionState.done) return _plain(const LoadingView());
              if (fs.hasError) {
                return _plain(ErrorView(message: errorText(fs.error ?? ''), onRetry: () => setState(_load)));
              }
              return _friend(fs.data ?? _FriendData(friend, const FriendWall()));
            },
          );
        },
      ),
    );
  }

  /// 불러오는 중 · 오류 — 배경 사진이 아직 없으니 보통 AppBar 로 (뒤로 가기)
  Widget _plain(Widget body) => Column(
    children: [
      AppBar(title: widget.friend == null ? Text(tr('내 정보')) : null),
      Expanded(child: body),
    ],
  );

  /// I-1 배경 사진(당기면 늘어나며 커진다) + 둥근 흰 카드 + [children]
  Widget _page({required Widget cover, required Widget card, required List<Widget> children}) {
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    return CustomScrollView(
      // 끝에서 더 당기면 늘어나고 놓으면 돌아온다 (안드로이드도 같게)
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        SliverAppBar(
          expandedHeight: 190,
          stretch: true,
          automaticallyImplyLeading: false,
          backgroundColor: Gp.panel,
          surfaceTintColor: Colors.transparent,
          leading: canPop
              ? Center(
                  child: RaisedCircleButton(
                    // 사진 위에서도 보이게 흰 원
                    tooltip: tr('뒤로'),
                    onTap: () => Navigator.maybePop(context),
                    child: Icon(Icons.arrow_back, size: Gp.iM, color: Gp.ink),
                  ),
                )
              : null,
          flexibleSpace: FlexibleSpaceBar(stretchModes: const [StretchMode.zoomBackground], background: cover),
          bottom: PreferredSize(
            // 카드 윗부분이 사진 위에 겹쳐 앉는다
            preferredSize: const Size.fromHeight(Gp.rLarge),
            child: Container(
              height: Gp.rLarge,
              decoration: BoxDecoration(
                color: Gp.panel,
                borderRadius: BorderRadius.vertical(top: Radius.circular(Gp.rLarge)),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(child: card),
        SliverList.list(children: children),
        SliverToBoxAdapter(child: SizedBox(height: 32 + MediaQuery.paddingOf(context).bottom)),
      ],
    );
  }

  /// 내 것 · 친구 것 배경 사진 — 없으면 서랍 머리와 같은 옅은 그라데이션
  // static final 로 두면 밤 모드를 켠 뒤에도 처음 만든 색 그대로 얼어붙는다 → getter
  static Widget get _softCover => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Gp.p.coverA, Gp.p.coverB, Gp.panel],
      ),
    ),
  );

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
    // 예약 금액 = 기다리는 예약의 결제 예정 합 (컬렉션 예약 목록 끝 합계와 같은 셈)
    final due = store.activePreorders.values.fold<int>(0, (s, pre) => s + pre.due);
    final month = store.spendInMonth(appNow());

    // I-6 사진 벽: 직접 찍은 사진만
    final photos = store.photos;
    final tags = _myTags(store.profileTags, account);

    return _page(
      cover: ProfileCover(
        file: store.social.image(ProfileImageKind.cover)?.file ?? '',
        height: double.infinity,
        empty: _softCover,
      ),
      card: _Card(
        name: name,
        handle: handle,
        noHandle: tr(signedIn ? '아이디 없음' : '로그인 전'),
        avatar: MyAvatar(fallback: name.characters.isEmpty ? tr('나') : name.characters.first, size: 64, ringWidth: 3),
        level: level,
        onLevel: jump == null ? null : () => jump(CollectionJump.guide),
        tags: tags,
        onTags: _editTags,
      ),
      children: [
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
        const _Gap(),
        _Row(
          // I-4 숫자 줄 → 컬렉션 탭 그 목록
          key: const ValueKey('profile-liked'),
          icon: LikedIcon(filled: false, size: Gp.iL),
          label: tr('좋아요'),
          value: '$liked',
          onTap: jump == null ? null : () => jump(CollectionJump.liked),
        ),
        _Row(
          key: const ValueKey('profile-owned'),
          icon: OwnedIcon(filled: false, size: Gp.iL),
          label: tr('구매함'),
          value: '$owned',
          onTap: jump == null ? null : () => jump(CollectionJump.owned),
        ),
        _Row(
          key: const ValueKey('profile-preorder'),
          icon: Icon(preorderIcon, size: Gp.iL, color: Gp.ink),
          label: tr('예약 금액'),
          value: won(due),
          onTap: jump == null ? null : () => jump(CollectionJump.preorder),
        ),
        _Row(
          key: const ValueKey('profile-spend'),
          icon: Icon(Icons.account_balance_wallet_outlined, size: Gp.iL, color: Gp.ink),
          label: tr('구매 금액'),
          sub: month > 0 ? trf('이번 달 {money}', {'money': won(month)}) : '',
          value: won(store.spendKrw),
          onTap: jump == null ? null : () => jump(CollectionJump.owned),
        ),
        const _Gap(),
        _Row(
          // I-6 · I-7 내 사진 — 미리 보기 2열, › = 사진 벽 전부
          key: const ValueKey('profile-photos'),
          icon: Icon(Icons.photo_library_outlined, size: Gp.iL, color: Gp.ink),
          label: tr('내 사진'),
          value: '${photos.length}',
          extra: [
            if (signedIn && photos.any((ph) => ph.shared) && photoWarn(account.photos).isNotEmpty)
              Tooltip(
                key: const ValueKey('photo-warn'),
                message: photoWarn(account.photos),
                triggerMode: TooltipTriggerMode.tap,
                child: Icon(Icons.warning_amber_rounded, size: Gp.iS, color: Gp.star),
              ),
            if (signedIn) _privacyButton(store),
            IconButton(
              tooltip: tr('사진 넣기'),
              visualDensity: VisualDensity.compact,
              onPressed: () => addMyPhoto(context),
              icon: Icon(Icons.add_a_photo_outlined, size: Gp.iM, color: Gp.ink),
            ),
          ],
          onTap: () => _openPhotos(account, store),
        ),
        _PhotoPreview(tiles: [for (final ph in photos.take(4)) MyPhotoTile(ph)]),
        if (signedIn) ...[
          const _Gap(),
          _Row(
            // I-5 친구 → 친구 화면 (요청 · 목록) · 아이디로 추가
            key: const ValueKey('profile-friends'),
            icon: Icon(Icons.people_outline, size: Gp.iL, color: Gp.ink),
            label: tr('친구'),
            value: account.friends.unavailable ? '' : '${account.friends.friends.length}',
            badge: account.incomingCount,
            extra: [
              IconButton(
                tooltip: tr('아이디로 친구 추가'),
                visualDensity: VisualDensity.compact,
                onPressed: () => showAddFriend(context),
                icon: Icon(Icons.person_add_alt_1_outlined, size: Gp.iM, color: Gp.ink),
              ),
            ],
            onTap: () => openFriends(context, loaders: widget.loaders),
          ),
        ],
        Padding(
          // I-14 공유 카드 · I-3 프로필 편집
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('profile-share'),
                  onPressed: () => openCollectionShare(context, loaders: widget.loaders),
                  icon: const Icon(Icons.ios_share, size: Gp.iM),
                  label: Text(tr('공유 카드')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey('profile-edit'),
                  onPressed: _editProfile,
                  icon: const Icon(Icons.edit_outlined, size: Gp.iM),
                  label: Text(tr('프로필 편집')),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// I-9 사진 공개 범위
  Widget _privacyButton(UserStore store) => IconButton(
    key: const ValueKey('photo-privacy'),
    tooltip: tr('공개 범위'),
    visualDensity: VisualDensity.compact,
    onPressed: () => showPhotoPrivacy(context),
    icon: Icon(privacyIcon(store.social), size: Gp.iM, color: Gp.muted),
  );

  /// 사진 벽 전부 (넣기 · 공개 범위 · ⚠ 는 같은 조각 — t_photo_screen.dart PhotoWall)
  void _openPhotos(Account account, UserStore store) => openPage(
    context,
    _PhotosPage(
      title: tr('내 사진'),
      wall: (context) {
        final s = Marks.of(context).store; // 넣고 지우면 바로
        final a = AccountScope.of(context);
        return PhotoWall(
          warn: a.signedIn && s.photos.any((ph) => ph.shared) ? photoWarn(a.photos) : '',
          extra: a.signedIn ? _privacyButton(s) : null,
          onAdd: () => addMyPhoto(context),
          tiles: [for (final ph in s.photos) MyPhotoTile(ph)],
        );
      },
    ),
  );

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
    final photos = d.wall.photos;
    return _page(
      cover: ProfileCover(path: d.wall.coverPath, height: double.infinity, empty: _softCover),
      card: _Card(
        name: m.name,
        handle: m.handle,
        noHandle: '',
        avatar: FriendAvatar(handle: m.handle, name: m.name, size: 64, ring: true),
        level: guideLevel(m.lit, 0, owned: m.owned),
        onLevel: () => open(CollectionJump.guide),
        tags: d.wall.tags,
      ),
      children: [
        const _Gap(),
        _Row(
          key: const ValueKey('profile-liked'),
          icon: LikedIcon(filled: false, size: Gp.iL),
          label: tr('좋아요'),
          value: '${m.liked}',
          onTap: () => open(CollectionJump.liked),
        ),
        _Row(
          key: const ValueKey('profile-owned'),
          icon: OwnedIcon(filled: false, size: Gp.iL),
          label: tr('구매함'),
          value: '${m.owned}',
          onTap: () => open(CollectionJump.owned),
        ),
        _Row(
          key: const ValueKey('profile-guide'),
          icon: Icon(Icons.auto_awesome_mosaic_outlined, size: Gp.iL, color: Gp.ink),
          label: tr('도감'),
          value: '${m.lit}',
          onTap: () => open(CollectionJump.guide),
        ),
        const _Gap(),
        _Row(
          // I-6 친구가 공개한 사진만
          key: const ValueKey('profile-photos'),
          icon: Icon(Icons.photo_library_outlined, size: Gp.iL, color: Gp.ink),
          label: tr('사진'),
          value: '${photos.length}',
          onTap: photos.isEmpty
              ? null
              : () => openPage(
                  context,
                  _PhotosPage(
                    title: m.name,
                    wall: (_) => PhotoWall(tiles: [for (final ph in photos) FriendPhotoTile(ph)]),
                  ),
                ),
        ),
        _PhotoPreview(tiles: [for (final ph in photos.take(4)) FriendPhotoTile(ph)]),
        if (real)
          Padding(
            // I-12 P05
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
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

/// I-1 사진 위에 겹쳐 앉는 흰 카드 — 왼쪽 색 고리 아바타 · 이름 · Lv · @아이디(복사) · 한 줄 소개(취향 태그)
class _Card extends StatelessWidget {
  const _Card({
    required this.name,
    required this.handle,
    required this.noHandle,
    required this.avatar,
    required this.level,
    required this.tags,
    this.onLevel,
    this.onTags,
  });
  final String name;
  final String handle;

  /// 아이디가 없을 때 글 (친구 보기는 빈 글자)
  final String noHandle;
  final Widget avatar;
  final int level;
  final List<String> tags;

  /// Lv 누르면 (도감)
  final VoidCallback? onLevel;

  /// 없으면(친구 보기) 소개 줄에 › 가 없다
  final VoidCallback? onTags;

  @override
  Widget build(BuildContext context) {
    final chip = LevelChip(level: level);
    return ColoredBox(
      color: Gp.panel,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gp.gutter, 0, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                avatar,
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
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
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              handle.isNotEmpty ? '@$handle' : noHandle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: Gp.t12, color: Gp.muted),
                            ),
                          ),
                          if (handle.isNotEmpty)
                            IconButton(
                              tooltip: tr('아이디 복사'), // P07
                              visualDensity: VisualDensity.compact,
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: '@$handle'));
                                showToast(context, tr('아이디를 복사했어요'));
                              },
                              icon: Icon(Icons.content_copy_rounded, size: Gp.iS, color: Gp.muted),
                            )
                          else
                            const SizedBox(height: 40),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            InkWell(
              // I-2 한 줄 소개 = 취향 태그 (친구에게도 보임)
              key: const ValueKey('profile-tags'),
              borderRadius: BorderRadius.circular(Gp.rSmall),
              onTap: onTags,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(2, 8, 4, 8),
                child: Row(
                  children: [
                    Icon(Icons.sell_outlined, size: Gp.iS, color: Gp.muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tags.isEmpty ? tr('취향 태그') : tags.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: Gp.t14, color: tags.isEmpty ? Gp.faint : Gp.ink),
                      ),
                    ),
                    if (onTags != null) Icon(Icons.chevron_right, color: Gp.faint),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 카드 · 묶음 사이 회색 틈
class _Gap extends StatelessWidget {
  const _Gap();

  @override
  Widget build(BuildContext context) => SizedBox(height: 8, child: ColoredBox(color: Gp.soft));
}

/// 목록 한 줄 — 아이콘 · 이름(· 작은 둘째 줄) · 값 · [extra] 아이콘 · ›
class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.sub = '',
    this.extra = const [],
    this.badge = 0,
    this.onTap,
  });
  final Widget icon;
  final String label;
  final String value;
  final String sub;
  final List<Widget> extra;

  /// > 0 이면 빨간 숫자 (받은 친구 요청)
  final int badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Gp.panel,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gp.gutter, 6, 8, 6),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              children: [
                SizedBox(
                  width: Gp.iL,
                  child: Center(child: icon),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label, style: const TextStyle(fontSize: Gp.t16)),
                      if (sub.isNotEmpty)
                        Text(
                          sub,
                          style: TextStyle(fontSize: Gp.t12, color: Gp.muted),
                        ),
                    ],
                  ),
                ),
                if (badge > 0) ...[Badge(backgroundColor: Gp.danger, label: Text('$badge')), const SizedBox(width: 8)],
                Text(
                  value,
                  style: TextStyle(fontSize: Gp.t14, color: Gp.muted),
                ),
                ...extra,
                if (onTap != null) Icon(Icons.chevron_right, color: Gp.faint) else const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 사진 미리 보기 2열 (4장까지) — 없으면 흐린 아이콘 하나
class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({required this.tiles});
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Gp.panel,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gp.gutter, 2, Gp.gutter, 12),
        child: tiles.isEmpty
            ? Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Icon(Icons.photo_outlined, size: Gp.iL, color: Gp.line),
              )
            : GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                children: tiles,
              ),
      ),
    );
  }
}

/// 사진 벽 전부 (내 사진 · 친구 사진의 ›)
class _PhotosPage extends StatelessWidget {
  const _PhotosPage({required this.title, required this.wall});
  final String title;
  final WidgetBuilder wall;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: ListView(children: [Builder(builder: wall)]),
  );
}

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
                style: TextStyle(fontSize: Gp.t12, color: Gp.muted),
              ),
              const Spacer(),
              IconButton(
                tooltip: tr('저장'),
                onPressed: () {
                  _add(); // 적어 두고 + 를 안 눌렀어도 넣는다
                  Navigator.pop(context, _tags);
                },
                icon: Icon(Icons.check, size: Gp.iL, color: Gp.accent),
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
                        Icon(Icons.close, size: Gp.iXS, color: Gp.faint),
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
                tooltip: tr('태그 추가'),
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

/// I-15 사용법의 "내 정보" 묶음 (서랍 › 사용법)
List<HelpItem> profileHelp() => [
  HelpItem(Icons.ios_share, tr('공유 카드 (그림으로 공유 · 저장)')),
  HelpItem(Icons.edit_outlined, tr('프로필 편집 (프로필 사진 · 배경 사진 · 이름 · 아이디 · 태그)')),
  HelpItem(Icons.sell_outlined, tr('취향 태그')),
  HelpItem.widget(LikedIcon(size: Gp.iL), tr('좋아요 수 → 컬렉션')),
  HelpItem.widget(OwnedIcon(size: Gp.iL), tr('구매함 수 → 컬렉션')),
  HelpItem(preorderIcon, tr('예약 금액 (결제 예정 합)')),
  HelpItem(Icons.account_balance_wallet_outlined, tr('구매 금액 (총 지출 · 이번 달)')),
  HelpItem(Icons.people_outline, tr('친구 (빨간 숫자 = 받은 친구 요청)')),
  HelpItem(Icons.person_add_alt_1_outlined, tr('아이디로 친구 추가')),
  HelpItem(Icons.content_copy_rounded, tr('내 아이디 복사')),
  HelpItem(Icons.add_a_photo_outlined, tr('사진 넣기 (사진 벽)')),
  HelpItem(Icons.group_outlined, tr('사진 공개 범위')),
  HelpItem(Icons.lock_outline, tr('사진 공개 끔')),
  HelpItem(Icons.warning_amber_rounded, tr('올리지 못한 사진 있음'), color: Gp.star),
];

/// I-15 사용법의 "친구 보기" 묶음
List<HelpItem> friendProfileHelp() => [
  HelpItem.widget(LikedIcon(size: Gp.iL), tr('친구의 좋아요')),
  HelpItem.widget(OwnedIcon(size: Gp.iL), tr('친구의 구매함')),
  HelpItem(Icons.auto_awesome_mosaic_outlined, tr('도감 비교')),
  HelpItem(Icons.photo_library_outlined, tr('친구가 공개한 사진')),
  HelpItem(Icons.person_remove_outlined, tr('친구 끊기')),
];
