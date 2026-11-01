// 화면 I: 내 정보 — 프로필 · 수집 숫자 · 친구 추가(아이디) (친구 서랍 머리에서 열림, 설정은 K 화면)
// 같은 화면을 친구 보기로도 쓴다: 친구 이름을 누르면 그 친구의 숫자 (편집 없음, 친구 끊기)
// v3: 이름 · @아이디 · 친구는 Gunpula 계정(v3 get_me), 숫자는 내 기록(Marks). 게시물 · 사진 인증은 서버가 없어 숨김.
//
// ┌──────── 디자인 가이드 대응표: I 내 정보 ───────────────────────────────────────────┐
// │ 번호 │ Flutter 위젯명                     │ 비즈니스 명칭(한글)                    │ 원칙(P번호)   │
// │ I-1  │ 색 고리 큰 아바타 · 이름 · @아이디    │ 내 프로필 (계정 이름 · 아이디)           │ P04           │
// │ I-2  │ 안내 카드 + 버튼                     │ 로그인하기 · 아이디 정하기               │ P09 · P10     │
// │ I-3  │ 프로필 편집 → 바텀 시트(액션 목록)    │ 이름 바꾸기 · 아이디 바꾸기              │ P03 · P07     │
// │ I-4  │ 숫자 3칸 (누르면 이동)               │ 좋아요 · 도감 레벨 · 구매함 → 컬렉션      │ P01 · P07     │
// │ I-5  │ 내 @아이디 + 복사 · 버튼 2개          │ 친구 추가 (아이디로) · 받은 요청          │ P07 · P08     │
// │ I-11 │ 친구 숫자 → L 친구 컬렉션            │ 친구의 좋아요 · 구매함 · 도감 보기         │ P07           │
// │ I-12 │ OutlinedButton → 확인 대화상자        │ 친구 끊기                              │ P05           │
// │ I-8  │ LoadingView / ErrorView             │ 불러오는 중 · 오류                      │ P01 · P09     │
// └──────────────────────────────────────────────────────────────────────────────────┘
// 전환: 친구 서랍(M) 머리 아바타 → 쌓기(push, 오른쪽에서 · 넓은 화면은 오른쪽 칸). 숫자 → 닫고 컬렉션 탭(옆으로). 친구 → 쌓기. 편집 → 덮기.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../api.dart';
import '../channels.dart';
import '../marks.dart';
import '../detail_pane.dart';
import '../models.dart';
import '../sync/account.dart';
import '../sync/friends_service.dart' show FriendsFailure;
import '../theme.dart';
import '../widgets.dart';
import 'f_collection_screen.dart' show CollectionJump;
import 'l_friend_collection_screen.dart';
import 'p_sign_in_screen.dart';
import 'q_friend_sheets.dart';

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

class _ProfileData {
  const _ProfileData(this.profile, this.collection, this.lit);
  final Profile profile;
  final List<Kit> collection;

  /// 도감 점등 칸 수 (작품 도감의 수집 합)
  final int lit;
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

  /// 친구 보기: 계정에서 받은 최신 숫자 (계정 친구가 아니면 넘겨받은 그대로)
  Future<Member>? _friendFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    // STATE: 내 정보 · 내 채널 상품 · 도감 → 숫자
    _future = Future.wait([
      widget.loaders.profile(),
      widget.loaders.kits(widget.myChannels ?? [for (final c in allChannels) c.id]), // 내 채널 상품 전부 → Marks 로 셈
      widget.loaders.guideWorks(),
    ]).then((r) => _ProfileData(r[0] as Profile, r[1] as List<Kit>, litCount(r[2] as List<GuideWork>)));
    final f = widget.friend;
    if (f != null) {
      final account = AccountScope.read(context);
      final real = account.signedIn && account.friends.friends.any((x) => x.handle == f.handle);
      // STATE: 친구 컬렉션 받기 (get_friend_collection)
      _friendFuture = real ? loadFriendMember(account, f.handle, widget.loaders) : Future.value(f);
    }
  }

  void _jump(CollectionJump j) {
    Navigator.pop(context);
    widget.onJump?.call(j);
  }

  void _editProfile() {
    if (!ensureSignedIn(context)) return;
    showModalBottomSheet<void>(
      // I-3 덮기
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('이름 바꾸기'),
              subtitle: const Text('친구에게 보이는 이름'),
              onTap: () {
                Navigator.pop(sheet);
                askDisplayName(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.alternate_email),
              title: const Text('아이디 바꾸기'),
              subtitle: const Text('친구가 나를 찾는 @아이디'),
              onTap: () {
                Navigator.pop(sheet);
                askHandle(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _unfriend(Member m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('${m.name}님과 친구를 끊을까요?'),
        content: const Text('서로의 컬렉션이 더 이상 보이지 않아요. 다시 친구가 되려면 요청을 새로 보내야 해요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('취소')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Gp.danger),
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('친구 끊기'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await AccountScope.read(context).friends.remove(m.handle);
      if (!mounted) return;
      showToast(context, '${m.name}님과 친구를 끊었어요');
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
        title: Text(
          friend == null ? '내 정보' : '${friend.name}의 컬렉션',
          style: const TextStyle(fontSize: Gp.t19, fontWeight: FontWeight.w600),
        ),
      ),
      body: FutureBuilder<_ProfileData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingView(); // I-8
          if (snap.hasError) return ErrorView(message: '${snap.error}', onRetry: () => setState(_load));
          if (friend == null) return _mine(snap.data!.profile, snap.data!);
          return FutureBuilder<Member>(
            future: _friendFuture,
            builder: (context, fs) {
              if (fs.connectionState != ConnectionState.done) return const LoadingView();
              if (fs.hasError) return ErrorView(message: '${fs.error}', onRetry: () => setState(_load));
              return _friend(fs.data ?? friend);
            },
          );
        },
      ),
    );
  }

  Widget _mine(Profile p, _ProfileData d) {
    final scope = widget.myChannels;
    final marks = Marks.of(context); // 앱 전체 한 벌 — 홈에서 누른 ♡ · 리본도 숫자에 반영
    final account = AccountScope.of(context); // 로그인 · 아이디 · 친구가 바뀌면 다시 그림
    final mine = d.collection.where((k) => scope == null || scope.contains(k.franchiseId));
    final liked = mine.where(marks.liked).length;
    final owned = mine.where(marks.owned).length;
    final signedIn = account.signedIn;
    final name = signedIn ? account.displayName : p.name;
    final handle = signedIn ? account.handle : p.handle;
    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        _Header(
          name: name,
          subtitle: handle.isNotEmpty ? '@$handle' : (signedIn ? '아이디 없음' : '로그인 전'),
          avatarText: name.characters.isEmpty ? '나' : name.characters.first,
          tags: p.tags,
          onEdit: _editProfile,
        ),
        if (!signedIn)
          _Hint(
            // I-2 P09
            icon: Icons.cloud_outlined,
            text: '로그인 전이에요',
            action: '로그인',
            onTap: () => openSignIn(context),
          )
        else if (account.handle.isEmpty && !account.friends.unavailable)
          _Hint(
            icon: Icons.alternate_email,
            text: '아이디가 없어요',
            action: '아이디 정하기',
            onTap: () => askHandle(context),
          ),
        _Stats(
          liked: liked,
          lit: d.lit,
          verified: 0, // 사진 인증은 서버가 없어 아직 0
          owned: owned,
          spendKrw: signedIn ? marks.store.spendKrw : p.spendKrw,
          onJump: widget.onJump == null ? null : _jump, // I-4
        ),
        if (signedIn) _friendsPanel(account),
      ],
    );
  }

  /// I-5 친구 추가 (초대 코드 대신 내 @아이디)
  Widget _friendsPanel(Account account) {
    final f = account.friends;
    return SectionPanel(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            '친구',
            subtitle: f.unavailable ? '' : '${f.friends.length}명',
          ),
          if (account.handle.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
              decoration: BoxDecoration(color: Gp.bg, borderRadius: BorderRadius.circular(Gp.radius)),
              child: Row(
                children: [
                  const Text(
                    '내 아이디',
                    style: TextStyle(color: Gp.muted, fontSize: Gp.t12),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('@${account.handle}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    tooltip: '아이디 복사', // P07
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: '@${account.handle}'));
                      showToast(context, '아이디를 복사했어요 · 친구에게 보내 주세요');
                    },
                    icon: const Icon(Icons.content_copy_rounded, size: Gp.iM, color: Gp.muted),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => showAddFriend(context),
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: Gp.iM),
                  label: const Text('아이디로 친구 추가'),
                ),
                OutlinedButton.icon(
                  onPressed: () => showFriendRequests(context),
                  icon: Badge(
                    isLabelVisible: f.incoming.isNotEmpty,
                    label: Text('${f.incoming.length}'),
                    backgroundColor: Gp.accent,
                    child: const Icon(Icons.mail_outline, size: Gp.iM),
                  ),
                  label: const Text('친구 요청'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _friend(Member m) {
    final account = AccountScope.of(context);
    final real = account.signedIn && account.friends.friends.any((x) => x.handle == m.handle);
    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        _Header(
          name: m.name,
          subtitle: '@${m.handle}',
          avatarText: m.name.characters.isEmpty ? '?' : m.name.characters.first,
          tags: [if (m.role.isNotEmpty) m.role],
        ),
        _Stats(
          liked: m.liked,
          lit: m.lit,
          verified: m.verified,
          owned: m.owned,
          onJump: (j) => openFriendCollection(context, m, j, loaders: widget.loaders), // I-11
        ),
        if (real)
          Padding(
            // I-12 P05
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: OutlinedButton.icon(
              onPressed: () => _unfriend(m),
              style: OutlinedButton.styleFrom(foregroundColor: Gp.danger),
              icon: const Icon(Icons.person_remove_outlined, size: Gp.iM),
              label: const Text('친구 끊기'),
            ),
          ),
      ],
    );
  }
}

/// I-2 안내 카드 (로그인 · 아이디)
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
          Icon(icon, color: Gp.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: Gp.t12, height: 1.4)),
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
    required this.avatarText,
    required this.tags,
    this.onEdit,
  });
  final String name;

  /// @아이디 (없으면 안내 글)
  final String subtitle;
  final String avatarText;
  final List<String> tags;

  /// 없으면(친구 보기) 편집 버튼을 숨긴다
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final avatar = RingAvatar(text: avatarText, size: 76, ringWidth: 3);
    return ColoredBox(
      color: Gp.panel,
      child: Stack(
        children: [
          Column(
            children: [
              Container(height: 70, color: Gp.soft), // 배경(커버)
              const SizedBox(height: 56), // 아바타가 겹쳐 앉는 자리
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: Gp.t19, fontWeight: FontWeight.w700),
                ),
              ),
              Text(subtitle, style: const TextStyle(color: Gp.muted)),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 6, children: [for (final t in tags) TagPill(t)]), // P06
              ],
              if (onEdit != null) ...[
                const SizedBox(height: 14),
                OutlinedButton(
                  onPressed: onEdit, // I-3
                  style: OutlinedButton.styleFrom(
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(Gp.rSmall))),
                  ),
                  child: const Text('프로필 편집'),
                ),
              ],
              const SizedBox(height: 18),
            ],
          ),
          Positioned(top: 30, left: 0, right: 0, child: Center(child: avatar)), // I-1 P04
        ],
      ),
    );
  }
}

/// I-4 숫자 3칸 — 누르면 컬렉션 탭의 그 목록으로 (친구 보기에서는 숫자만)
class _Stats extends StatelessWidget {
  const _Stats({
    required this.liked,
    required this.lit,
    required this.verified,
    required this.owned,
    this.spendKrw,
    this.onJump,
  });
  final int liked;
  final int lit;

  /// 3점(내 사진 인증) 칸 수 = 배지 수
  final int verified;
  final int owned;
  final int? spendKrw;
  final ValueChanged<CollectionJump>? onJump;

  @override
  Widget build(BuildContext context) {
    Widget stat(String label, String value, CollectionJump j, {Widget? extra}) {
      final body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            FittedBox(
              // 좁은 화면에서는 줄여서 한 줄
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: const TextStyle(fontSize: Gp.t19, fontWeight: FontWeight.w700),
                  ),
                  ?extra,
                ],
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
                ),
                if (onJump != null) const Icon(Icons.chevron_right, size: Gp.iS, color: Gp.faint),
              ],
            ),
          ],
        ),
      );
      return Expanded(
        child: onJump == null
            ? body
            : InkWell(borderRadius: BorderRadius.circular(Gp.radius), onTap: () => onJump!(j), child: body),
      );
    }

    return SectionPanel(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              children: [
                stat('좋아요', '$liked', CollectionJump.liked),
                const VerticalDivider(width: 1, indent: 6, endIndent: 6),
                stat(
                  '도감 레벨',
                  'Lv.${guideLevel(lit, verified, owned: owned, liked: liked)}',
                  CollectionJump.guide,
                  extra: verified == 0
                      ? null // 사진 인증은 아직 서버가 없어 0 이면 배지를 숨긴다
                      : Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const VerifiedBadge(size: 16),
                              Text(
                                ' $verified',
                                style: const TextStyle(fontSize: Gp.t12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                ),
                const VerticalDivider(width: 1, indent: 6, endIndent: 6),
                stat('구매함', '$owned', CollectionJump.owned),
              ],
            ),
          ),
          if (spendKrw case final spend?) ...[
            const Divider(height: 20),
            Text(
              '구매 지출 합계 ${won(spend)}',
              style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
            ),
          ],
        ],
      ),
    );
  }
}
