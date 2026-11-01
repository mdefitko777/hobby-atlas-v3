// 화면 조각 U: 친구 쪽 공용 — 아바타 사진 · 배경 · 사진 공개 범위 시트 · 공유 공간 · 알 수도 있는 친구 · 친구 상태 줄
// 앱 셸(S) · 친구 서랍(M) · 내 정보 / 친구 보기(I) · 친구 컬렉션(L)이 같이 쓴다.
// 데이터: 내 아바타 · 배경 = 기기 파일(UserStore.social) → Storage `<uid>/profile/…` (lib/sync/profile_images.dart),
//        친구 아바타 = 사진 벽 avatar_path 를 기기에 받아 둔 것, 공개 범위 = lib/sync/photo_share.dart,
//        공유 공간 = v2 get_state 의 members (SyncService.workspace, 읽기만), 알 수도 있는 친구 = gunpula_v3_suggest_friends.
// 서버 SQL: docs/supabase-v3-social.sql — 없으면 첫 글자 아바타 · 공개 범위 ⚠ · 알 수도 있는 친구 칸 숨김.
//
// ┌──────── 디자인 가이드 대응표: U 친구 쪽 공용 ──────────────────────────────────────┐
// │ 번호 │ Flutter 위젯명                     │ 비즈니스 명칭(한글)                    │ 원칙(P번호)   │
// │ U-1  │ MyAvatar (RingAvatar + 사진)        │ 내 아바타 (S-1 · M-2 · I-1) · 없으면 첫 글자 │ P04           │
// │ U-2  │ FriendAvatar                       │ 친구 아바타 (M-7 · I-1 친구 · I-9 목록)    │ P04           │
// │ U-3  │ ProfileCover                       │ 배경 사진 (I-1 머리 뒤)                  │ P02           │
// │ U-4  │ editProfileImage → 바텀 시트         │ 아바타 · 배경 바꾸기 · 지우기 (I-3)        │ P03 · P07     │
// │ U-5  │ 바텀 시트: 스위치 + 친구 체크 목록     │ 사진 공개 범위 (I-9 전체 끄기 · 친구별 숨기기) │ P05 · P07 │
// │ U-6  │ WorkspaceMembers                   │ 공유 공간 이름 · 멤버 · 역할 (I-5 · M-6, 읽기만) │ P06    │
// │ U-7  │ SuggestionsPanel (줄 + 👤+ · ×)      │ 알 수도 있는 친구 · 함께 아는 친구 n명 (M-5) │ P07 · P05   │
// │ U-8  │ FriendStatusLine                   │ 친구 상태 한 줄: 최근 담은 것 · 사진 (M-7)   │ P01           │
// └──────────────────────────────────────────────────────────────────────────────────┘
// 전환: 아바타 · 배경 · 공개 범위 → 덮기(바텀 시트). 친구 요청 → 토스트.
library;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show ImageSource;

import '../clock.dart';
import '../data/catalog.dart';
import '../data/photo_files.dart';
import '../data/social_local.dart';
import '../sync/account.dart';
import '../sync/friends_service.dart';
import '../sync/photo_share.dart';
import '../sync/sync_service.dart' show Workspace;
import '../theme.dart';
import '../widgets.dart';
import 't_photo_screen.dart' show PhotoChoice, askPhotoSource, photoPicker;

/// 기기 사진 파일을 동그라미에 — 파일이 없으면 [fallback]
class _FilePhoto extends StatefulWidget {
  const _FilePhoto({super.key, required this.file, required this.fallback});
  final String file;
  final Widget fallback;

  @override
  State<_FilePhoto> createState() => _FilePhotoState();
}

class _FilePhotoState extends State<_FilePhoto> {
  late Future<ImageProvider?> _img = PhotoFiles.instance.provider(widget.file);

  @override
  void didUpdateWidget(_FilePhoto old) {
    super.didUpdateWidget(old);
    if (old.file != widget.file) _img = PhotoFiles.instance.provider(widget.file);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ImageProvider?>(
    future: _img,
    builder: (context, snap) => switch (snap.data) {
      final img? => Image(
        image: img,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => widget.fallback,
      ),
      _ when snap.connectionState != ConnectionState.done => const ColoredBox(color: Gp.soft),
      _ => widget.fallback,
    },
  );
}

Widget _initial(String text, double size) => ColoredBox(
  color: Gp.panel,
  child: Center(
    child: Text(
      text,
      style: TextStyle(fontSize: size * 0.4, fontWeight: FontWeight.w700, color: Gp.ink),
    ),
  ),
);

/// U-1 내 아바타 — 사진(기기)이 있으면 사진, 없으면 이름 첫 글자 ([fallback] = 로그인 전 글자)
class MyAvatar extends StatelessWidget {
  const MyAvatar({super.key, this.fallback = '나', this.size = 56, this.ringWidth = 2.5, this.onTap, this.tooltip = ''});
  final String fallback;
  final double size;
  final double ringWidth;
  final VoidCallback? onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final account = AccountScope.of(context);
    return ListenableBuilder(
      listenable: account.store,
      builder: (context, _) {
        final text = account.signedIn ? account.initial : fallback;
        final img = account.store.social.image(ProfileImageKind.avatar);
        return RingAvatar(
          text: text,
          size: size,
          ringWidth: ringWidth,
          onTap: onTap,
          tooltip: tooltip,
          photo: img == null
              ? null
              : _FilePhoto(key: ValueKey('avatar-file-${img.file}'), file: img.file, fallback: _initial(text, size)),
        );
      },
    );
  }
}

/// U-2 친구 아바타 — 받아 둔 사진, 없으면 첫 글자
class FriendAvatar extends StatelessWidget {
  const FriendAvatar({super.key, required this.handle, required this.name, this.size = 42, this.ring = false});
  final String handle;
  final String name;
  final double size;

  /// 색 고리 큰 아바타 (I-1 친구 보기)
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final store = AccountScope.of(context).store;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final file = store.social.friendAvatars[handle];
        final label = name.isEmpty ? '?' : name;
        if (ring) {
          final text = label.characters.first;
          return RingAvatar(
            text: text,
            size: size,
            ringWidth: 3,
            photo: file == null
                ? null
                : _FilePhoto(key: ValueKey('friend-avatar-$handle'), file: file, fallback: _initial(text, size)),
          );
        }
        if (file == null) return CircleThumb(image: '', label: label, size: size);
        return Container(
          width: size,
          height: size,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Gp.soft,
            border: Border.all(color: Gp.line),
          ),
          child: _FilePhoto(
            key: ValueKey('friend-avatar-$handle'),
            file: file,
            fallback: CircleThumb(image: '', label: label, size: size),
          ),
        );
      },
    );
  }
}

/// U-3 배경 사진 — 내 것 [file](기기) 또는 친구 것 [path](Storage), 둘 다 없으면 회백색 띠
class ProfileCover extends StatefulWidget {
  const ProfileCover({super.key, this.file = '', this.path = '', this.height = 70});
  final String file;
  final String path;
  final double height;

  @override
  State<ProfileCover> createState() => _ProfileCoverState();
}

class _ProfileCoverState extends State<ProfileCover> {
  Future<ImageProvider?>? _img;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _img ??= _load();
  }

  @override
  void didUpdateWidget(ProfileCover old) {
    super.didUpdateWidget(old);
    if (old.file != widget.file || old.path != widget.path) _img = _load();
  }

  Future<ImageProvider?> _load() async {
    if (widget.file.isNotEmpty) return PhotoFiles.instance.provider(widget.file);
    if (widget.path.isEmpty) return null;
    try {
      return MemoryImage(await AccountScope.read(context).photos.image(widget.path));
    } on Object {
      return null; // 오프라인 · 서버 SQL 없음 → 띠만
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: widget.height,
    width: double.infinity,
    child: FutureBuilder<ImageProvider?>(
      future: _img,
      builder: (context, snap) => switch (snap.data) {
        final img? => Image(
          key: const ValueKey('profile-cover'),
          image: img,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => const ColoredBox(color: Gp.soft),
        ),
        _ => const ColoredBox(color: Gp.soft),
      },
    ),
  );
}

/// U-4 아바타 · 배경 바꾸기 — 카메라 · 갤러리 (· 지우기). 기기에 먼저, 로그인했으면 올린다
Future<void> editProfileImage(BuildContext context, ProfileImageKind kind) async {
  final account = AccountScope.read(context);
  final has = account.store.social.image(kind) != null || (account.friends.me?.imagePath(kind.key) ?? '').isNotEmpty;
  final choice = await askPhotoSource(context, remove: has);
  if (choice == null || !context.mounted) return;
  try {
    if (choice == PhotoChoice.remove) {
      await account.profileImages.removeMine(kind);
      return;
    }
    final bytes = await photoPicker(choice == PhotoChoice.camera ? ImageSource.camera : ImageSource.gallery);
    if (bytes == null || bytes.isEmpty) return;
    await account.profileImages.setMine(kind, bytes);
    if (context.mounted && account.profileImages.warn) showToast(context, '기기에만 저장했어요');
  } on FriendsFailure catch (e) {
    if (context.mounted) showToast(context, e.message);
  } on Object catch (e) {
    if (context.mounted) showToast(context, '사진을 가져오지 못했어요 ($e)');
  }
}

/// I-9 머리 아이콘 — 공개 · 일부 숨김 · 끔
IconData privacyIcon(SocialLocal s) =>
    !s.photosPublic ? Icons.lock_outline : (s.hiddenFrom.isEmpty ? Icons.group_outlined : Icons.group_remove_outlined);

/// U-5 사진 공개 범위 (I-9) — 스위치 하나 + 친구 체크 목록 (체크 = 내 사진을 볼 수 있음)
Future<void> showPhotoPrivacy(BuildContext context) {
  AccountScope.read(context).photos.pullPrivacy().ignore(); // 다른 기기에서 바꾼 것 · 서버가 지키는지
  return showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (_) => const _PrivacySheet());
}

class _PrivacySheet extends StatelessWidget {
  const _PrivacySheet();

  @override
  Widget build(BuildContext context) {
    final account = AccountScope.of(context); // 공개 범위 서버 상태가 바뀌면 다시 그림
    return ListenableBuilder(
      listenable: account.store,
      builder: (context, _) {
        final s = account.store.social;
        final pub = s.photosPublic;
        final hidden = {...s.hiddenFrom};
        void set({required bool public, required Set<String> hidden}) =>
            account.photos.setPrivacy(public: public, hidden: hidden).ignore(); // STATE: 공개 범위 → 기기 + 서버
        // 서버가 친구별 숨기기를 모름 → 지켜지지 않는다 (사진 공개 끄기는 앱이 사진을 내려서 지킨다)
        final unguarded = account.photos.privacyMissing && pub && hidden.isNotEmpty;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                SwitchListTile(
                  key: const ValueKey('privacy-public'),
                  secondary: Icon(pub ? Icons.photo_library_outlined : Icons.lock_outline, color: Gp.ink),
                  title: Row(
                    children: [
                      const Text('사진 공개'),
                      if (unguarded) ...[
                        const SizedBox(width: 6),
                        const Tooltip(
                          key: ValueKey('privacy-warn'),
                          message: '서버에 공개 범위가 아직 없어요 (docs/supabase-v3-social.sql)',
                          triggerMode: TooltipTriggerMode.tap,
                          child: Icon(Icons.warning_amber_rounded, size: Gp.iS, color: Gp.star),
                        ),
                      ],
                    ],
                  ),
                  value: pub,
                  activeThumbColor: Gp.accent,
                  onChanged: (v) => set(public: v, hidden: hidden),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                for (final f in account.friends.friends)
                  CheckboxListTile(
                    key: ValueKey('privacy-${f.handle}'),
                    secondary: FriendAvatar(handle: f.handle, name: f.name, size: 34),
                    title: Text(f.name),
                    subtitle: Text(
                      '@${f.handle}',
                      style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
                    ),
                    value: pub && !hidden.contains(f.handle),
                    activeColor: Gp.accent,
                    // 전체를 끄면 친구별 선택도 잠김 P05
                    onChanged: pub
                        ? (v) => set(
                            public: true,
                            hidden: v == true ? (hidden..remove(f.handle)) : (hidden..add(f.handle)),
                          )
                        : null,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 역할 → 아이콘 · 뜻 (v2 gunpula_v2_members.role)
(IconData, String) roleIcon(String role) => switch (role) {
  'owner' => (Icons.workspace_premium_outlined, '관리자'),
  'viewer' => (Icons.visibility_outlined, '보기만'),
  _ => (Icons.edit_outlined, '편집'),
};

/// U-6 공유 공간 (I-5 · M-6) — 이름 · 멤버 · 역할. 읽기만 (초대 코드 만들기는 서버 함수가 없어 없음)
class WorkspaceMembers extends StatelessWidget {
  const WorkspaceMembers({super.key, required this.workspace, this.onSelf});
  final Workspace workspace;

  /// 나를 누르면 (서랍 → 내 정보)
  final VoidCallback? onSelf;

  @override
  Widget build(BuildContext context) {
    final w = workspace;
    return Column(
      key: const ValueKey('workspace-members'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Row(
            children: [
              const Icon(Icons.home_outlined, size: Gp.iM, color: Gp.ink),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  w.name.isEmpty ? '공유 공간' : w.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: Gp.t14, fontWeight: FontWeight.w700),
                ),
              ),
              if (!w.canEdit)
                const Tooltip(
                  message: '읽기 전용',
                  child: Icon(Icons.lock_outline, size: Gp.iS, color: Gp.muted),
                ),
            ],
          ),
        ),
        for (final m in w.members)
          ListTile(
            dense: true,
            leading: m.isSelf
                ? MyAvatar(fallback: m.name.characters.isEmpty ? '나' : m.name.characters.first, size: 32, ringWidth: 2)
                : CircleThumb(image: '', label: m.name.isEmpty ? '?' : m.name, size: 36),
            title: Text(
              m.name,
              style: TextStyle(fontSize: Gp.t14, fontWeight: m.isSelf ? FontWeight.w700 : FontWeight.w400),
            ),
            trailing: Tooltip(
              message: roleIcon(m.role).$2,
              child: Icon(roleIcon(m.role).$1, size: Gp.iM, color: Gp.muted),
            ),
            onTap: m.isSelf ? onSelf : null,
          ),
      ],
    );
  }
}

/// U-7 알 수도 있는 친구 (M-5) — 서버 함수가 없거나 아무도 없으면 칸 자체가 없다
class SuggestionsPanel extends StatelessWidget {
  const SuggestionsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final account = AccountScope.of(context);
    final f = account.friends;
    if (!account.signedIn || f.suggestionsMissing) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: account.store,
      builder: (context, _) {
        final known = {
          for (final p in [...f.friends, ...f.incoming, ...f.outgoing]) p.handle,
        };
        final list = [
          for (final s in f.suggestions)
            if (!known.contains(s.profile.handle) &&
                !account.store.social.dismissedSuggestions.contains(s.profile.handle))
              s,
        ];
        if (list.isEmpty) return const SizedBox.shrink();
        return SectionPanel(
          key: const ValueKey('suggestions'),
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 2, 16, 2),
                child: Tooltip(
                  message: '알 수도 있는 친구',
                  child: Icon(Icons.person_search_outlined, size: Gp.iM, color: Gp.ink),
                ),
              ),
              for (final s in list.take(5))
                ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(16, 0, 4, 0),
                  leading: CircleThumb(image: '', label: s.profile.name, size: 40),
                  title: Text(s.profile.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '함께 아는 친구 ${s.mutual}명',
                    style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: ValueKey('suggest-add-${s.profile.handle}'),
                        tooltip: '친구 요청',
                        onPressed: () async {
                          try {
                            await f.request(s.profile.handle);
                            if (context.mounted) showToast(context, '${s.profile.name}님에게 친구 요청을 보냈어요');
                          } on FriendsFailure catch (e) {
                            if (context.mounted) showToast(context, e.message);
                          }
                        },
                        icon: const Icon(Icons.person_add_alt_1_outlined, color: Gp.accent),
                      ),
                      IconButton(
                        key: ValueKey('suggest-dismiss-${s.profile.handle}'),
                        tooltip: '닫기',
                        onPressed: () => account.store.social.dismissSuggestion(s.profile.handle), // 기기에만
                        icon: const Icon(Icons.close, size: 18, color: Gp.faint),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// 친구의 가장 최근 일 — 구매함 · 좋아요에 담은 것 또는 보이기로 둔 사진
class FriendEvent {
  const FriendEvent(this.kind, this.kitId, this.at);

  /// 'owned' · 'wanted' · 'photo'
  final String kind;
  final String kitId;
  final DateTime at;
}

FriendEvent? latestFriendEvent(FriendCollection? c, FriendWall? w) {
  FriendEvent? best;
  void consider(FriendEvent e) {
    if (best == null || e.at.isAfter(best!.at)) best = e;
  }

  for (final e in c?.items.entries ?? const <MapEntry<String, Map<String, Object?>>>[]) {
    final st = '${e.value['status'] ?? ''}';
    final at = DateTime.tryParse('${e.value['updated_at'] ?? ''}');
    if (at != null && (st == 'owned' || st == 'wanted')) consider(FriendEvent(st, e.key, at));
  }
  for (final p in w?.photos ?? const <FriendPhoto>[]) {
    final at = DateTime.tryParse(p.createdAt);
    if (at != null) consider(FriendEvent('photo', p.kitId, at));
  }
  return best;
}

/// [sinceIso] 뒤에 올라온 친구 사진 수 (처음 여는 것이면 0)
int newPhotoCount(FriendWall? w, String sinceIso) {
  final since = DateTime.tryParse(sinceIso);
  if (since == null || w == null) return 0;
  return w.photos.where((p) => DateTime.tryParse(p.createdAt)?.isAfter(since) ?? false).length;
}

/// U-8 친구 상태 한 줄 (M-7) — 아이콘 + 상품 이름 + 언제. 일이 없으면 [fallback]
class FriendStatusLine extends StatelessWidget {
  const FriendStatusLine({super.key, required this.event, required this.fallback});
  final FriendEvent? event;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: Gp.t12, color: Gp.muted);
    final e = event;
    if (e == null) return Text(fallback, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
    final name = Catalog.instance.byId[e.kitId]?.name ?? '';
    return Row(
      children: [
        switch (e.kind) {
          'owned' => const OwnedIcon(size: 12),
          'wanted' => const LikedIcon(size: 12),
          _ => const Icon(Icons.photo_camera_outlined, size: 13, color: Gp.muted),
        },
        const SizedBox(width: 4),
        if (name.isNotEmpty)
          Flexible(
            child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
          ),
        Text(
          '${name.isEmpty ? '' : ' · '}${timeAgo(e.at.toLocal(), now: appNow())}',
          style: const TextStyle(fontSize: Gp.t11, color: Gp.faint),
        ),
      ],
    );
  }
}
