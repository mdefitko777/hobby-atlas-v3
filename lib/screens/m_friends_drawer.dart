// 화면 M: 서랍 — 왼쪽 위 아바타를 누르거나, 홈에서 왼쪽 가장자리를 밀면 나온다 (QQ 옆 서랍처럼)
// 세 띠 (2026-11-22 주인 시안): 위 고정 = 내 프로필 요약(배경 사진 위 아바타 · 이름 · Lv, 누르면 I 내 정보),
//     가운데 = 줄 목록만 혼자 움직인다(좋아요 · 구매함 · 예약 / 친구 · 공유 카드, 스크롤바 없음), 아래 고정 = 아이콘 줄(밤 모드 · 사용법 · 설정).
// 친구(검색 · 친구 요청 · 목록 · ★ 특별 관심 소식)는 "친구" 줄이 여는 쌓기 화면 [FriendsPage].
// v3: 친구 · 요청은 Gunpula 계정(v3 get_me), 친구 숫자는 get_friend_collection, 친구 사진 · 아바타는 get_friend_wall,
//     알 수도 있는 친구는 gunpula_v3_suggest_friends(docs/supabase-v3-social.sql — 없으면 칸 숨김),
//     공용 조각은 u_social.dart. 공유 공간 탭은 뺐다 (2026-11-20 주인) — 친구 하나뿐이라 탭 줄도 없다.
// 2026-11-21 주인: 서랍 첫 화면을 메뉴 줄로 — 위 줄의 ⚙ · ? 와 탭의 공유 카드 · My Page 가 여기로 왔다.
//     머리의 "친구" 제목 · @아이디 · ? 는 뺐다 (아이디는 내 정보에서 복사).
// 2026-11-22 주인: 사용법 · 설정은 줄에서 빼 아래 고정 아이콘 줄로, 좋아요 · 구매함 · 예약 줄 끝에 내 것의 수
//     (내 정보 I-4 숫자 줄 · 그 줄이 여는 컬렉션 탭 목록과 같은 셈 — 내 채널 상품에서 Marks 로 센다).
//
// ┌──────── 디자인 가이드 대응표: M 서랍 ──────────────────────────────────────────────┐
// │ 번호 │ Flutter 위젯명                     │ 비즈니스 명칭(한글)                    │ 원칙(P번호)   │
// │ M-1  │ Drawer (아바타 · 홈 가장자리 밀기)    │ 서랍 열기 · 닫기(밖 누르기 · X)          │ P03 · P07     │
// │ M-2  │ 위 고정 띠: 배경 사진 위 색 고리 아바타 · 이름 · Lv · › │ 내 프로필 요약 → 내 정보 (배경 = 내 정보와 같은 사진, 없으면 옅은 그라데이션) │ P04 │
// │ M-3  │ 가운데 띠: 줄 목록 (아이콘 + 이름, 좋아요 · 구매함 · 예약은 줄 끝에 수) │ 좋아요 · 구매함 · 예약 → 컬렉션 탭 그 목록(수 = 그 목록의 내 것의 수) / 친구 · 공유 카드 (줄 목록만 움직인다) │ P06 · P07 │
// │ M-3b │ 친구 줄 끝 빨간 숫자 · 파란 점         │ 받은 친구 요청 수 · 지난번에 본 뒤 새 사진 │ P01           │
// │ M-4  │ GpSearchBar (카메라 없는 모드)        │ 친구 검색 (친구 화면)                    │ P07 · P04     │
// │ M-5  │ SuggestionsPanel (U-7) · 요청 줄      │ 알 수도 있는 친구(함께 아는 친구 n명) · 친구 요청 │ P07 · P05 │
// │ M-6  │ 접히는 그룹 (탭 줄 없음)              │ 친구                                   │ P06           │
// │ M-7  │ 친구 줄 (아바타 · 상태 한 줄 · Lv)    │ 친구 → 친구 프로필(I 친구 보기) · 새 사진 점 · ★ 특별 관심 │ P07 · P01 │
// │ M-8  │ 안내 + 로그인 버튼                   │ 로그인 전                              │ P09           │
// │ M-9  │ ★ 묶음 (SpecialFeed)                │ 특별 관심 친구가 최근 담은 것 (옛 My Page ★) │ P01         │
// │ M-10 │ 머리 오른쪽 + · ✕                   │ 아이디로 친구 추가 · 닫기                 │ P07 · P03     │
// │ M-11 │ 아래 고정 띠: 아이콘 줄               │ 밤 모드 · 사용법 · 설정                     │ P07 · P08 │
// └──────────────────────────────────────────────────────────────────────────────────┘
// 전환: 서랍 → 내 정보 · 친구 화면 · 공유 카드 · 사용법 · 설정(쌓기, 서랍은 닫힘) · 좋아요 · 구매함 · 예약(컬렉션 탭, 옆으로).
//       요청 · 추가 → 덮기(바텀 시트).
import 'package:flutter/material.dart';

import '../api.dart';
import '../channels.dart';
import '../clock.dart';
import '../data/catalog.dart';
import '../data/social_local.dart' show ProfileImageKind;
import '../data/user_store.dart';
import '../detail_pane.dart';
import '../l10n/l10n.dart';
import '../logic/friends.dart';
import '../logic/level_math.dart';
import '../marks.dart';
import '../models.dart';
import '../sync/account.dart';
import '../theme.dart';
import '../widgets.dart';
import 'd_kit_detail_screen.dart';
import 'f_collection_screen.dart' show CollectionJump;
import 'i_profile_screen.dart' show openFriend;
import 'k_settings_screen.dart' show openSettings;
import 'p_sign_in_screen.dart';
import 'q_friend_sheets.dart';
import 'u_social.dart';
import 'v_share_sheet.dart' show openCollectionShare;
import '../level.dart';

/// 친구별 지난번에 친구 화면을 본 뒤 새 사진 수
int _newPhotos(Account a, String handle, String seenBefore) => newPhotoCount(a.photos.walls[handle], seenBefore);

class FriendsDrawer extends StatefulWidget {
  const FriendsDrawer({
    super.key,
    required this.onOpenProfile,
    this.onJump,
    this.onHelp,
    this.myChannels,
    this.loaders = const Loaders(),
  });

  final VoidCallback onOpenProfile;

  /// 좋아요 · 구매함 · 예약 → 컬렉션 탭의 그 목록 (앱 셸)
  final ValueChanged<CollectionJump>? onJump;

  /// 줄 끝 수를 세는 범위 — 내 정보(I-4) · 컬렉션 탭 목록과 같게. 없으면 모든 채널
  final List<String>? myChannels;

  /// 사용법 (앱 셸이 모든 화면의 도움말을 모은다)
  final VoidCallback? onHelp;
  final Loaders loaders;

  @override
  State<FriendsDrawer> createState() => _FriendsDrawerState();
}

class _FriendsDrawerState extends State<FriendsDrawer> {
  late final Future<(Profile, int)> _future = _load();

  /// 줄 끝 수를 세는 상품 — 내 채널 상품 전부 (내 정보 I-4 와 같은 셈, 거기서 Marks 로 거른다).
  /// 메뉴 줄은 이것을 기다리지 않는다 — 받는 중 · 오프라인 · 실패면 수 자리만 빈다
  late final Future<List<Kit>> _kits = widget.loaders
      .kits(widget.myChannels ?? [for (final c in allChannels) c.id])
      .catchError((Object _) => const <Kit>[]);

  @override
  void initState() {
    super.initState();
    final a = AccountScope.read(context);
    if (!a.signedIn) return;
    // 친구 줄의 요청 수 · 새 사진 점. 사진 벽은 메모리에만 있어 여기서 받지 않으면 점이 뜰 수 없다
    // (친구 화면은 열 때 본 시각을 지금으로 바꾸므로, 거기서 받은 벽만으로는 늘 0)
    a.friends
        .refresh()
        .then((_) => a.photos.loadAllWalls([for (final f in a.friends.friends) f.handle]))
        .catchError((Object _) {});
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
      // 화면의 절반 (2026-11-21 주인: 접는 화면이라 절반이면 충분하다).
      // 접은 상태처럼 좁은 화면에서는 절반이 너무 좁아 못 읽으므로 300 을 밑바닥으로 둔다
      width: (width * 0.5).clamp(300.0, width * 0.88),
      backgroundColor: Gp.bg,
      shape: const RoundedRectangleBorder(),
      // 메뉴 줄은 기다리지 않는다 — 카탈로그를 처음 받는 중 · 오프라인 · 받기 실패에도 설정 · 사용법이 열려야 해서.
      // 내 정보 · 도감(레벨)을 기다리는 것은 머리의 이름 · Lv 뿐
      child: Column(
        children: [
          FutureBuilder<(Profile, int)>(
            future: _future,
            builder: (context, snap) => _header(snap.hasError ? null : snap.data, account),
          ),
          Expanded(child: _rows(account)),
          _bottomBar(),
        ],
      ),
    );
  }

  /// M-2 내 프로필 요약 — 바탕은 내 정보와 같은 배경 사진 (없으면 옅은 그라데이션).
  /// [data] 가 없으면(받는 중 · 실패) Lv 자리는 비워 두고 이름은 계정 이름만
  Widget _header((Profile, int)? data, Account account) {
    final p = data?.$1;
    final name = account.signedIn ? account.displayName : p?.name ?? '';
    final soft = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Gp.p.coverA, Gp.p.coverB, Gp.panel],
        ),
      ),
    );
    return Stack(
      children: [
        Positioned.fill(
          child: ListenableBuilder(
            // 내 정보에서 배경을 바꾸면 바로 따라간다
            listenable: account.store,
            builder: (context, _) => ProfileCover(
              file: account.store.social.image(ProfileImageKind.cover)?.file ?? '',
              height: double.infinity,
              empty: soft,
            ),
          ),
        ),
        Positioned.fill(
          // 사진 위에서도 이름이 읽히게 아래쪽만 옅은 흰 막
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Gp.glass.withValues(alpha: 0), Gp.glass],
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 6, 6, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                // M-10 제목 없이 오른쪽에 + · ✕
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: tr('아이디로 친구 추가'),
                    onPressed: () => showAddFriend(context),
                    icon: Icon(Icons.person_add_alt_1_outlined, color: Gp.ink),
                  ),
                  IconButton(
                    tooltip: tr('닫기'),
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: Gp.ink),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              InkWell(
                key: const ValueKey('drawer-profile'),
                borderRadius: BorderRadius.circular(Gp.radius),
                onTap: () => _close(widget.onOpenProfile),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      MyAvatar(fallback: p?.avatarText ?? '나'),
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
                            const SizedBox(height: 5),
                            if (data == null)
                              const SizedBox(height: 22) // Lv 칩 높이만큼 비워 둬 받은 뒤 줄이 움직이지 않게
                            else
                              LevelChip(
                                level: guideLevel(
                                  data.$2,
                                  0,
                                  owned: UserStore.instance.ownedCount,
                                  liked: UserStore.instance.wantedCount,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Gp.muted),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// M-3 가운데 띠 — 줄 목록만 혼자 움직인다 (머리 · 아래 아이콘 줄은 그대로 있다). 스크롤바는 두지 않는다.
  /// 줄 끝 수 = 내 것의 수, 친구 줄만 받은 요청 수 · 새 사진 점 (M-3b)
  Widget _rows(Account account) {
    final marks = Marks.of(context); // 좋아요 · 구매함을 적으면 수가 따라간다
    final incoming = account.incomingCount;
    final seen = account.store.social.friendsSeenAt;
    final freshPhotos = account.signedIn && account.friends.friends.any((f) => _newPhotos(account, f.handle, seen) > 0);
    Icon plain(IconData i) => Icon(i, size: Gp.iL, color: Gp.ink);
    void jump(CollectionJump j) => widget.onJump?.call(j);
    // 서랍은 닫히며 사라진다 — 여는 화면 · 시트(공유 카드는 레벨을 센 뒤에 열린다)는 서랍 밖 앱 셸의 Scaffold 기준으로
    final host = Scaffold.maybeOf(context)?.context ?? context;
    return ScrollConfiguration(
      // 스크롤바 없이 (2026-11-22 주인)
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: FutureBuilder<List<Kit>>(
        future: _kits,
        builder: (context, snap) {
          final counts = _counts(marks, snap.data);
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 4),
            children: [
              _row(
                'liked',
                LikedIcon(filled: false, size: Gp.iL),
                tr('좋아요'),
                () => jump(CollectionJump.liked),
                count: counts?.liked,
              ),
              _row(
                'owned',
                OwnedIcon(filled: false, size: Gp.iL),
                tr('구매함'),
                () => jump(CollectionJump.owned),
                count: counts?.owned,
              ),
              _row(
                'preorder',
                plain(preorderIcon),
                tr('예약'),
                () => jump(CollectionJump.preorder),
                count: counts?.preorder,
              ),
              Divider(height: 11, thickness: 0.5, color: Gp.line),
              _row(
                'friends',
                plain(Icons.people_outline),
                tr('친구'),
                () => openFriends(host, loaders: widget.loaders),
                trailing: incoming > 0
                    ? Badge(backgroundColor: Gp.danger, label: Text('$incoming')) // 받은 요청 = 빨간 숫자
                    : freshPhotos
                    // 새 사진 = 파란 점 (친구 줄과 같은 점) — 옛 서랍 머리 「새 사진 n」 대신
                    ? Badge(key: ValueKey('drawer-friends-new'), backgroundColor: Gp.accent, smallSize: 9)
                    : null,
              ),
              _row(
                'share',
                plain(Icons.ios_share),
                tr('공유 카드'),
                () => openCollectionShare(host, loaders: widget.loaders),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 좋아요 · 구매함 · 예약 줄 끝의 내 것의 수 — 내 정보(I-4)와 컬렉션 탭 목록(F `_inTab`)과 똑같은 셈:
  /// 내 채널 상품에서 Marks 로 거른다 (짝 상품은 한 줄, 내 채널이 아닌 상품은 세지 않는다).
  /// 상품을 아직 못 받았으면 null — 줄은 그대로 보이고 수 자리만 빈다
  ({int liked, int owned, int preorder})? _counts(Marks marks, List<Kit>? kits) {
    if (kits == null) return null;
    final scope = widget.myChannels;
    final mine = [
      for (final k in kits)
        if (scope == null || scope.contains(k.franchiseId)) k,
    ];
    return (
      liked: mine.where(marks.liked).length,
      owned: mine.where(marks.owned).length,
      // 예약 = 컬렉션 탭 예약 목록과 같은 셈 (좋아요이면서 기다리는 예약)
      preorder: mine.where((k) => marks.liked(k) && (marks.store.preorderOf(k.id)?.active ?? false)).length,
    );
  }

  /// M-3 줄 하나 — 아이콘 · 이름 · 오른쪽 끝 수(또는 요청 수 · 새 사진 점). 줄 사이 틈이 줄보다 커 보이지 않게 낮게
  Widget _row(String key, Widget icon, String label, VoidCallback onTap, {int? count, Widget? trailing}) => InkWell(
    key: ValueKey('drawer-$key'),
    onTap: () => _close(onTap),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(Gp.gutter, 1, 12, 1),
      child: SizedBox(
        height: 42,
        child: Row(
          children: [
            SizedBox(
              width: Gp.iL,
              child: Center(child: icon),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: Gp.t16)),
            ),
            if (count != null)
              Text(
                '$count',
                style: TextStyle(fontSize: Gp.t12, color: Gp.muted),
              ),
            ?trailing,
          ],
        ),
      ),
    ),
  );

  /// M-11 아래 고정 띠 — 아이콘만 (이름은 툴팁). 맨 앞은 밤 모드 (2026-11-22 부터 진짜로 켜진다).
  /// 손으로만 켜고 끈다 — 기기 설정을 따라가지 않는다 (주인이 그렇게 골랐다).
  Widget _bottomBar() {
    final host = Scaffold.maybeOf(context)?.context ?? context;
    return DecoratedBox(
      decoration: BoxDecoration(border: Border(top: Gp.bandLine)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(8, 0, 8, MediaQuery.paddingOf(context).bottom),
        child: Row(
          children: [
            // 앱 뿌리도 GpMode 를 듣고 앱 전체를 다시 만들지만, 이 단추는 자기 혼자서도 바뀐다
            // — 뿌리가 다시 만들어 주기를 기다리면 서랍을 띄워 놓은 채로는 아이콘이 늦게 따라온다
            ValueListenableBuilder<bool>(
              valueListenable: GpMode.notifier,
              builder: (context, dark, _) => ToolIcon(
                key: const ValueKey('drawer-night'),
                icon: dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                tip: dark ? tr('밝은 화면으로') : tr('밤 모드'),
                // 서랍은 닫지 않는다 — 켜 보고 바로 되돌릴 수 있게
                onTap: () => GpMode.set(!dark),
              ),
            ),
            ToolIcon(
              key: const ValueKey('drawer-help'),
              icon: Icons.help_outline,
              tip: tr('사용법'),
              onTap: () => _close(() => widget.onHelp?.call()),
            ),
            ToolIcon(
              key: const ValueKey('drawer-settings'),
              icon: Icons.settings_outlined,
              tip: tr('설정'),
              onTap: () => _close(() => openSettings(host)),
            ),
          ],
        ),
      ),
    );
  }
}

/// 친구 화면 열기 (서랍 · 내 정보의 친구 줄)
void openFriends(BuildContext context, {Loaders loaders = const Loaders()}) =>
    openPage(context, FriendsPage(loaders: loaders), id: 'friends');

/// 친구 화면 — 친구 검색 · 알 수도 있는 사람 · 친구 요청 · 친구 목록 · ★ 특별 관심 소식 (옛 친구 서랍 아래쪽)
class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key, this.loaders = const Loaders()});
  final Loaders loaders;

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  late final Future<Profile> _future = widget.loaders.profile();

  String _query = '';
  bool _collapsed = false;

  /// 지난번 친구 화면을 연 시각 — 그 뒤에 올라온 친구 사진 = 새 사진 (M-7 점)
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

  @override
  Widget build(BuildContext context) {
    final account = AccountScope.of(context); // 친구 · 요청이 바뀌면 다시 그림
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('친구')),
        actions: [
          IconButton(
            tooltip: tr('아이디로 친구 추가'),
            onPressed: () => showAddFriend(context),
            icon: Icon(Icons.person_add_alt_1_outlined, color: Gp.ink),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: FutureBuilder<Profile>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingView();
          final signedIn = account.signedIn;
          // 로그인하면 계정 친구, 아니면 가져온 프로필의 친구 (실제 앱에서는 비어 있음)
          final friends = signedIn
              ? [for (final f in account.friends.friends) friendMemberOf(f, account.friends.collections[f.handle])]
              : snap.data?.friends ?? const <Member>[];
          return ListView(
            padding: EdgeInsets.only(bottom: 24 + MediaQuery.paddingOf(context).bottom),
            children: [
              if (!signedIn)
                _signInHint()
              else ...[
                _search(),
                if (_query.isEmpty) const SuggestionsPanel(), // M-5
                _newFriends(account),
              ],
              _lists(friends, signedIn, account),
              if (signedIn && UserStore.instance.specialFriends.isNotEmpty)
                SectionPanel(
                  // M-9
                  padding: EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.star_rounded, size: Gp.iM, color: Gp.star),
                      SizedBox(height: 6),
                      SpecialFeed(),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// M-8 로그인 전
  Widget _signInHint() {
    return SectionPanel(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(
        children: [
          Expanded(
            child: Text(tr('로그인하면 친구를 볼 수 있어요'), style: const TextStyle(fontSize: Gp.t12, height: 1.4)),
          ),
          const SizedBox(width: 8),
          FilledButton(onPressed: () => openSignIn(context), child: Text(tr('로그인'))),
        ],
      ),
    );
  }

  /// M-4 친구 검색
  Widget _search() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: GpSearchBar(
        hint: tr('친구 검색'), // 검색 덮개와 같은 검색창 (카메라 없음)
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
            key: const ValueKey('friend-requests'),
            leading: Icon(Icons.person_add_alt_outlined, color: Gp.ink),
            title: Text(
              waiting == 0
                  ? tr('친구 요청')
                  : trf('친구 요청 {incoming} · 보냄 {outgoing}', {
                      'incoming': f.incoming.length,
                      'outgoing': f.outgoing.length,
                    }),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (f.incoming.isNotEmpty) Badge(backgroundColor: Gp.danger, label: Text('${f.incoming.length}')),
                Icon(Icons.chevron_right, color: Gp.faint),
              ],
            ),
            onTap: () => showFriendRequests(context),
          ),
        ],
      ),
    );
  }

  /// M-6 · M-7 친구 목록
  Widget _lists(List<Member> all, bool signedIn, Account account) {
    bool hit(Member m) => _query.isEmpty || m.name.contains(_query) || m.handle.contains(_query);
    final shown = all.where(hit).toList();
    final open = !_collapsed || _query.isNotEmpty;
    Widget friendRow(Member m) => ListTile(
      // M-7
      leading: Badge(
        // 새 사진 점
        key: ValueKey('friend-new-${m.handle}'),
        isLabelVisible: _newPhotos(account, m.handle, _seenBefore) > 0,
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
              style: TextStyle(fontSize: Gp.t12, color: Gp.muted),
            )
          : FriendStatusLine(
              // 최근 담은 것 · 올린 사진 (★ 소식과 같은 셈)
              event: signedIn
                  ? latestFriendEvent(account.friends.collections[m.handle], account.photos.walls[m.handle])
                  : null,
              fallback: m.liked + m.owned > 0
                  ? trf('@{handle} · 좋아요 {liked} · 구매함 {owned}', {
                      'handle': m.handle,
                      'liked': m.liked,
                      'owned': m.owned,
                    })
                  : '@${m.handle}',
            ),
      // ★ 특별 관심 — 이 화면 아래 ★ 묶음에 이 친구 소식이 뜬다 (기기에만)
      trailing: m.handle.isEmpty
          ? null
          : IconButton(
              tooltip: tr('특별 관심'),
              onPressed: () => setState(
                () => UserStore.instance.setSpecialFriend(
                  m.handle,
                  !UserStore.instance.specialFriends.contains(m.handle),
                ),
              ),
              icon: UserStore.instance.specialFriends.contains(m.handle)
                  ? Icon(Icons.star_rounded, color: Gp.star)
                  : Icon(Icons.star_border_rounded, color: Gp.faint),
            ),
      onTap: () => openFriend(context, m, loaders: widget.loaders),
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
                    child: Icon(Icons.arrow_right, color: Gp.muted),
                  ),
                  Text(tr('친구'), style: const TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(
                    '${shown.length}/${all.length}',
                    style: TextStyle(fontSize: Gp.t12, color: Gp.faint),
                  ),
                ],
              ),
            ),
          ),
          if (open && all.isEmpty && signedIn)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                tr('아직 친구가 없어요'),
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

/// M-9 특별 관심 — 친구 화면에서 ★ 한 친구들이 최근 담은 것 (옛 홈 My Page ★)
class SpecialFeed extends StatefulWidget {
  const SpecialFeed({super.key});

  @override
  State<SpecialFeed> createState() => _SpecialFeedState();
}

class _SpecialFeedState extends State<SpecialFeed> {
  bool _asked = false;

  @override
  Widget build(BuildContext context) {
    final account = AccountScope.of(context);
    final special = UserStore.instance.specialFriends;
    final empty = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Icon(Icons.star_border_rounded, size: Gp.iL, color: Gp.line),
    );
    if (!account.signedIn || special.isEmpty) return empty;
    final friends = account.friends;
    if (!_asked) {
      _asked = true;
      for (final h in special) {
        friends.collection(h).then((_) {}, onError: (Object _) {});
      }
    }
    final cat = Catalog.instance;
    final events = <(String name, String status, Kit kit, DateTime at)>[];
    for (final h in special) {
      final c = friends.collections[h];
      if (c == null) continue;
      for (final e in c.items.entries) {
        final kit = cat.byId[e.key];
        final at = DateTime.tryParse('${e.value['updated_at'] ?? ''}');
        final st = '${e.value['status'] ?? ''}';
        if (kit == null || at == null || (st != 'owned' && st != 'wanted')) continue;
        events.add((c.profile.name, st, kit, at.toLocal()));
      }
    }
    events.sort((a, b) => b.$4.compareTo(a.$4));
    if (events.isEmpty) return empty;
    return Column(
      children: [
        for (final (name, st, kit, at) in events.take(4))
          InkWell(
            onTap: () => openKitDetail(context, kit),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: Gp.soft,
                    child: Text(
                      name.isEmpty ? '?' : name.substring(0, 1),
                      style: TextStyle(fontSize: Gp.t12, color: Gp.ink),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    name,
                    style: const TextStyle(fontSize: Gp.t14, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 6),
                  st == 'owned' ? OwnedIcon(size: Gp.iS) : LikedIcon(),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      kit.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: Gp.t14),
                    ),
                  ),
                  Text(
                    timeAgo(at, now: appNow()),
                    style: TextStyle(fontSize: Gp.t11, color: Gp.faint),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// M 사용법의 "친구" 묶음 (서랍 › 사용법)
List<HelpItem> friendsHelp() => [
  HelpItem(Icons.person_add_alt_1_outlined, tr('아이디로 친구 추가')),
  HelpItem(Icons.person_add_alt_outlined, tr('받은 친구 요청')),
  HelpItem.dot(Gp.accent, tr('지난번에 본 뒤 새 사진')),
  HelpItem(Icons.star_rounded, tr('특별 관심 (친구 화면 아래 ★에 소식)'), color: Gp.star),
];
