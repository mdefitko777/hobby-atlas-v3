// 친구 쪽 2차 — 아바타 · 배경, 사진 공개 범위, 공유 공간, 알 수도 있는 친구, 새 사진 · 상태 줄, 도감 비교 사진 수.
// 가짜 서버 · 가짜 Storage · 메모리 사진 파일만 쓴다 (docs/supabase-v3-social.sql 의 규칙을 fake_backend 가 흉내).
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/api.dart';
import 'package:hobby_atlas/clock.dart';
import 'package:hobby_atlas/data/photo_files.dart';
import 'package:hobby_atlas/data/social_local.dart';
import 'package:hobby_atlas/data/user_store.dart';
import 'package:hobby_atlas/detail_pane.dart';
import 'package:hobby_atlas/marks.dart';
import 'package:hobby_atlas/models.dart';
import 'package:hobby_atlas/screens/f_collection_screen.dart' show CollectionJump;
import 'package:hobby_atlas/screens/i_profile_screen.dart';
import 'package:hobby_atlas/screens/l_friend_collection_screen.dart';
import 'package:hobby_atlas/screens/m_friends_drawer.dart';
import 'package:hobby_atlas/screens/t_photo_screen.dart';
import 'package:hobby_atlas/screens/u_social.dart';
import 'package:hobby_atlas/sync/account.dart';
import 'package:hobby_atlas/sync/photo_share.dart';
import 'package:hobby_atlas/sync/profile_images.dart';
import 'package:hobby_atlas/sync/sync_service.dart';
import 'package:hobby_atlas/theme.dart';

import 'support/fake_backend.dart';

const _profile = Profile(
  name: '나',
  handle: '',
  avatarText: '나',
  tags: [],
  spendKrw: 0,
  workspace: '',
  inviteCode: '',
  members: [],
  showcase: [],
  friends: [],
  suggested: [],
);

const _work = GuideWork(id: 'w1', section: '우주세기', name: '기동전사 건담', image: '', total: 10, owned: 1);

final _loaders = Loaders(
  kits: (_) async => const [],
  collection: () async => const [],
  kitsByIds: (_) async => const [],
  worlds: (_) async => const [],
  guideWorks: () async => const [_work],
  guideUnits: (_) async => const [],
  bbxTops: () async => const [],
  announcements: (_) async => const [],
  profile: () async => _profile,
  notifications: () async => const [],
  friendGuide: (ids) async => {'w1': ids.length},
);

final _jpeg = Uint8List.fromList(List.generate(64, (i) => i));
final _jpeg2 = Uint8List.fromList(List.generate(64, (i) => 255 - i));

void main() {
  late FakeServer server;
  late FakeAuth auth;
  late FakePhotoStorage storage;
  late MemoryPhotoFiles files;
  late Account account;
  late UserStore store;

  String uid() => auth.userId;

  setUp(() {
    files = MemoryPhotoFiles();
    PhotoFiles.instance = files;
    server = FakeServer(v2Payload: null, handle: 'bbang', displayName: '빵빵한빵디');
    server.users['dongsaeng'] = (
      name: '동생',
      collection: {
        'items': {
          'a': {'status': 'wanted', 'updated_at': '2026-02-01T00:00:00Z'},
        },
      },
    );
    server.users['cousin'] = (name: '사촌', collection: const {});
    server.friends.add('dongsaeng');
    auth = FakeAuth(signedIn: true);
    storage = FakePhotoStorage();
    store = UserStore.memory();
    account = Account(auth: auth, rpc: server, storage: storage, store: store);
  });

  tearDown(() {
    account.dispose();
    fixedNow = null;
    photoPicker = (_) async => null;
  });

  Future<void> show(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        key: UniqueKey(),
        theme: buildGpTheme(),
        builder: (context, child) => AccountScope(
          account: account,
          child: MarksHost(
            store: store,
            child: PaneHost(child: child!),
          ),
        ),
        home: home,
      ),
    );
    await settle(tester);
  }

  Future<void> loadMe(WidgetTester tester) async {
    account.friends.refresh().ignore();
    await settle(tester);
  }

  Widget drawerHost() => Scaffold(
    drawer: FriendsDrawer(loaders: _loaders, onOpenProfile: () {}, onOpenFriend: (_) {}),
    body: Builder(
      builder: (c) => TextButton(onPressed: () => Scaffold.of(c).openDrawer(), child: const Text('열기')),
    ),
  );

  Future<void> openDrawer(WidgetTester tester) async {
    await show(tester, drawerHost());
    await tester.tap(find.text('열기'));
    await settle(tester);
    await settle(tester);
  }

  group('I-3 아바타 · 배경', () {
    testWidgets('갤러리에서 고르면 기기 + Storage <uid>/profile/avatar.jpg + preferences.avatar · 머리에 사진', (tester) async {
      photoPicker = (_) async => _jpeg;
      await loadMe(tester);
      await show(tester, ProfileScreen(loaders: _loaders, onJump: (_) {}));
      expect(find.text('빵'), findsOneWidget); // 사진 전엔 첫 글자
      await tester.tap(find.byTooltip('프로필 편집'));
      await settle(tester);
      await tester.tap(find.text('아바타'));
      await settle(tester);
      expect(find.text('지우기'), findsNothing); // 아직 사진이 없음
      await tester.tap(find.text('갤러리'));
      await settle(tester);
      final img = store.social.image(ProfileImageKind.avatar)!;
      expect(files.files[img.file], _jpeg);
      final path = '${uid()}/profile/avatar.jpg';
      expect(storage.objects[path], _jpeg);
      expect(server.preferences['avatar'], path);
      expect(server.preferences['avatar_at'], img.at);
      expect(img.uploadedTo, uid());
      expect(find.byKey(ValueKey('avatar-file-${img.file}')), findsOneWidget);
      // 저장 파일에도
      final local = store.toJson()['local_state']! as Map;
      expect(((local['profile_images'] as Map)['avatar'] as Map)['file'], img.file);

      // 배경
      photoPicker = (_) async => _jpeg2;
      await tester.tap(find.byTooltip('프로필 편집'));
      await settle(tester);
      await tester.tap(find.text('배경'));
      await settle(tester);
      await tester.tap(find.text('갤러리'));
      await settle(tester);
      expect(storage.objects['${uid()}/profile/cover.jpg'], _jpeg2);
      expect(server.preferences['cover'], '${uid()}/profile/cover.jpg');
      expect(server.preferences['avatar'], path); // 합쳐서 보냄 — 아바타는 그대로
      expect(find.byKey(const ValueKey('profile-cover')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('서버에 버킷이 없으면 기기에만 · 사진은 그대로 보인다', (tester) async {
      storage.missingBucket = true;
      photoPicker = (_) async => _jpeg;
      await loadMe(tester);
      await show(tester, ProfileScreen(loaders: _loaders, onJump: (_) {}));
      await tester.tap(find.byTooltip('프로필 편집'));
      await settle(tester);
      await tester.tap(find.text('아바타'));
      await settle(tester);
      await tester.tap(find.text('갤러리'));
      await settle(tester);
      final img = store.social.image(ProfileImageKind.avatar)!;
      expect(img.uploadedTo, '');
      expect(account.profileImages.state, ProfileImageState.missing);
      expect(server.preferences.containsKey('avatar'), isFalse);
      expect(find.byKey(ValueKey('avatar-file-${img.file}')), findsOneWidget);
      expect(find.text('기기에만 저장했어요'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('기기 파일이 사라졌으면 첫 글자로', (tester) async {
      store.social.setImage(ProfileImageKind.avatar, const ProfileImage(file: 'gone.jpg', at: '2026-11-01T00:00:00Z'));
      auth.signedIn = false;
      await show(tester, const Center(child: MyAvatar(fallback: 'A')));
      expect(find.text('A'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('다른 기기에서 바꾼 아바타는 받아서 기기에 둔다 · 지우면 서버에서도', () async {
      final path = '${uid()}/profile/avatar.jpg';
      storage.objects[path] = _jpeg;
      server.preferences = {'avatar': path, 'avatar_at': '2026-11-01T09:00:00Z'};
      await account.friends.refresh();
      await account.profileImages.sync();
      final img = store.social.image(ProfileImageKind.avatar)!;
      expect(img.at, '2026-11-01T09:00:00Z');
      expect(files.files[img.file], _jpeg);
      expect(storage.uploads, isEmpty); // 받기만

      await account.profileImages.removeMine(ProfileImageKind.avatar);
      expect(store.social.image(ProfileImageKind.avatar), isNull);
      expect(server.preferences['avatar'], '');
      expect(storage.objects.containsKey(path), isFalse);
      expect(files.files.containsKey(img.file), isFalse);
    });

    test('친구 아바타: 사진 벽의 avatar_path 를 기기에 받아 두고, 오프라인이면 받아 둔 것 그대로', () async {
      server.friendPrefs['dongsaeng'] = {'avatar': 'uid-d/profile/avatar.jpg', 'avatar_at': 't1'};
      storage.objects['uid-d/profile/avatar.jpg'] = _jpeg;
      await account.friends.refresh();
      await account.photos.loadAllWalls(['dongsaeng']);
      await account.profileImages.cacheFriendAvatars();
      final f = store.social.friendAvatars['dongsaeng']!;
      expect(files.files[f], _jpeg);

      // 바뀌었는데 오프라인 → 옛것 그대로
      server.friendPrefs['dongsaeng'] = {'avatar': 'uid-d/profile/avatar.jpg', 'avatar_at': 't2'};
      account.photos.clear();
      await account.photos.loadAllWalls(['dongsaeng']);
      storage.offline = true;
      await account.profileImages.cacheFriendAvatars();
      expect(store.social.friendAvatars['dongsaeng'], f);

      // 친구를 끊으면 지운다
      await account.profileImages.forgetFriendsExcept({});
      expect(store.social.friendAvatars, isEmpty);
      expect(files.files.containsKey(f), isFalse);
    });
  });

  group('I-9 사진 공개 범위', () {
    test('친구별 숨기기 → 서버 숨김 목록 · 숨긴 친구는 벽도 파일도 못 본다', () async {
      await account.friends.refresh();
      store.addPhoto(const MyPhoto(id: 'p1', file: 'p1.jpg', createdAt: '2026-11-01T00:00:00Z'));
      files.files['p1.jpg'] = _jpeg;
      await account.photos.sync();
      expect(server.myPhotos.keys, ['p1']);

      await account.photos.setPrivacy(public: true, hidden: {'dongsaeng'});
      expect(server.privacyOf['bbang']!.hidden, {'dongsaeng'});
      expect(store.social.privacyDirty, isFalse);
      expect(account.photos.privacy, PrivacyState.synced);
      expect(server.myWallAs('dongsaeng'), isEmpty);
      expect(server.myWallAs('cousin'), ['p1']);
      final photoPath = PhotoShareService.pathOf(uid(), 'p1');
      expect(server.canReadObject(owner: 'bbang', viewer: 'dongsaeng', path: photoPath), isFalse);
      expect(server.canReadObject(owner: 'bbang', viewer: 'dongsaeng', path: '${uid()}/profile/avatar.jpg'), isTrue);
      // 사진은 내리지 않는다 (서버가 지킨다)
      expect(storage.objects.containsKey(photoPath), isTrue);

      // 전체 끄기
      await account.photos.setPrivacy(public: false, hidden: {'dongsaeng'});
      expect(server.myWallAs('cousin'), isEmpty);
      final local = store.toJson()['local_state']! as Map;
      expect(local['photo_privacy'], {
        'public': false,
        'hidden_from': ['dongsaeng'],
        'dirty': false,
      });
    });

    test('친구가 나를 숨겼으면 그 친구 벽은 비어 있다', () async {
      server.friendPhotos['dongsaeng'] = [
        {'id': 'f1', 'path': 'uid-d/f1.jpg', 'created_at': '2026-11-01T00:00:00Z'},
      ];
      server.privacyOf['dongsaeng'] = (public: true, hidden: {'bbang'});
      final wall = await account.photos.friendWall('dongsaeng', force: true);
      expect(wall.photos, isEmpty);
      server.privacyOf.remove('dongsaeng');
      expect((await account.photos.friendWall('dongsaeng', force: true)).photos, hasLength(1));
    });

    test('서버에 공개 범위가 없으면: 전체 끄기는 올린 사진을 내려서 지키고, 다시 켜면 올린다', () async {
      server.missing.addAll(['gunpula_v3_set_photo_privacy', 'gunpula_v3_get_photo_privacy']);
      await account.friends.refresh();
      store.addPhoto(const MyPhoto(id: 'p1', file: 'p1.jpg', createdAt: '2026-11-01T00:00:00Z'));
      files.files['p1.jpg'] = _jpeg;
      await account.photos.sync();
      expect(storage.objects, hasLength(1));

      await account.photos.setPrivacy(public: false, hidden: {});
      await account.photos.sync();
      expect(account.photos.privacyMissing, isTrue);
      expect(store.social.privacyDirty, isTrue); // 다음에 다시 보낸다
      expect(storage.objects, isEmpty);
      expect(server.myPhotos, isEmpty);
      expect(store.photo('p1')!.shared, isTrue); // 사진 하나하나의 설정은 그대로

      await account.photos.setPrivacy(public: true, hidden: {});
      await account.photos.sync();
      expect(server.myPhotos.keys, ['p1']);
    });

    testWidgets('시트: 친구 체크를 풀면 숨김 · 전체를 끄면 친구 체크가 잠김 · 서버가 없으면 ⚠', (tester) async {
      await loadMe(tester);
      await show(tester, ProfileScreen(loaders: _loaders, onJump: (_) {}));
      await tester.tap(find.byKey(const ValueKey('photo-privacy')));
      await settle(tester);
      expect(find.text('사진 공개'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('privacy-dongsaeng')));
      await settle(tester);
      expect(store.social.hiddenFrom, {'dongsaeng'});
      expect(server.privacyOf['bbang']!.hidden, {'dongsaeng'});
      expect(find.byKey(const ValueKey('privacy-warn')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('privacy-public')));
      await settle(tester);
      expect(store.social.photosPublic, isFalse);
      final box = tester.widget<CheckboxListTile>(find.byKey(const ValueKey('privacy-dongsaeng')));
      expect(box.onChanged, isNull);
      expect(box.value, isFalse);

      // 서버 함수가 없는 프로젝트: 친구별 숨기기는 지켜지지 않으니 ⚠
      server.missing.add('gunpula_v3_set_photo_privacy');
      await tester.tap(find.byKey(const ValueKey('privacy-public')));
      await settle(tester);
      expect(account.photos.privacyMissing, isTrue);
      expect(find.byKey(const ValueKey('privacy-warn')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('I-5 · M-6 공유 공간', () {
    Workspace ws() => Workspace.parse({
      'workspace_name': '우리집 컬렉션',
      'revision': 3,
      'can_edit': true,
      'members': [
        {'name': '빵빵한빵디', 'role': 'owner', 'is_self': true},
        {'name': '동생', 'role': 'viewer', 'is_self': false},
      ],
    })!;

    testWidgets('공유 공간이 있으면 서랍에 탭 · 멤버와 역할, 내 정보에도', (tester) async {
      account.sync.workspace = ws();
      await openDrawer(tester);
      expect(find.byKey(const ValueKey('tab-space')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tab-space')));
      await settle(tester);
      expect(find.byKey(const ValueKey('workspace-members')), findsOneWidget);
      expect(find.text('우리집 컬렉션'), findsOneWidget);
      expect(find.byTooltip('관리자'), findsOneWidget);
      expect(find.byTooltip('보기만'), findsOneWidget);

      await show(tester, ProfileScreen(loaders: _loaders, onJump: (_) {}));
      await tester.scrollUntilVisible(find.byKey(const ValueKey('workspace-members')), 200);
      expect(find.byKey(const ValueKey('workspace-members')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('공유 공간이 없는 계정이면 탭도 칸도 없다', (tester) async {
      await openDrawer(tester);
      expect(find.byKey(const ValueKey('tab-space')), findsNothing);
      expect(find.byKey(const ValueKey('workspace-members')), findsNothing);
      await show(tester, ProfileScreen(loaders: _loaders, onJump: (_) {}));
      expect(find.byKey(const ValueKey('workspace-members')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('M-5 알 수도 있는 친구', () {
    testWidgets('친구의 친구 · 함께 아는 친구 수 · 요청 보내면 사라짐 · ×는 기기에 남는다', (tester) async {
      server.users['aunt'] = (name: '이모', collection: const {});
      server.friendsOf['dongsaeng'] = {'bbang', 'cousin', 'aunt'};
      await openDrawer(tester);
      expect(find.byKey(const ValueKey('suggestions')), findsOneWidget);
      expect(find.text('사촌'), findsOneWidget);
      expect(find.text('함께 아는 친구 1명'), findsNWidgets(2));
      await tester.tap(find.byKey(const ValueKey('suggest-add-cousin')));
      await settle(tester);
      expect(server.outgoing, contains('cousin'));
      expect(find.text('사촌'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('suggest-dismiss-aunt')));
      await settle(tester);
      expect(store.social.dismissedSuggestions, {'aunt'});
      expect((store.toJson()['local_state']! as Map)['dismissed_suggestions'], ['aunt']);
      expect(find.byKey(const ValueKey('suggestions')), findsNothing); // 남은 사람이 없으면 칸도 없다
      expect(tester.takeException(), isNull);
    });

    testWidgets('서버에 suggest_friends 가 없으면 칸을 숨긴다', (tester) async {
      server.friendsOf['dongsaeng'] = {'cousin'};
      server.missing.add('gunpula_v3_suggest_friends');
      await openDrawer(tester);
      expect(account.friends.suggestionsMissing, isTrue);
      expect(find.byKey(const ValueKey('suggestions')), findsNothing);
      expect(find.text('동생'), findsOneWidget); // 나머지는 그대로
      expect(tester.takeException(), isNull);
    });
  });

  group('M-3 · M-7 새 사진 · 상태 줄', () {
    testWidgets('지난번 연 뒤 올라온 친구 사진 = 새 사진 n · 친구 줄에 점 · 상태 줄은 가장 최근 일', (tester) async {
      fixedNow = DateTime.utc(2026, 11, 2, 12);
      store.social.setFriendsSeenAt('2026-11-01T00:00:00Z');
      server.friendPhotos['dongsaeng'] = [
        {'id': 'f2', 'path': 'uid-d/f2.jpg', 'kit_id': '', 'created_at': '2026-11-01T12:00:00Z'},
        {'id': 'f1', 'path': 'uid-d/f1.jpg', 'kit_id': '', 'created_at': '2026-10-30T00:00:00Z'},
      ];
      await openDrawer(tester);
      expect(find.text('새 사진 1'), findsOneWidget);
      expect(tester.widget<Badge>(find.byKey(const ValueKey('friend-new-dongsaeng'))).isLabelVisible, isTrue);
      final status = tester.widget<FriendStatusLine>(find.byType(FriendStatusLine));
      expect(status.event?.kind, 'photo'); // 사진(11/1)이 좋아요(2/1)보다 늦다
      expect(store.social.friendsSeenAt, '2026-11-02T12:00:00.000Z'); // 이번에 연 시각

      // 다시 열면 그 사진은 새것이 아니다
      await openDrawer(tester);
      expect(find.text('새 사진 1'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('처음 여는 서랍엔 새 사진 표시가 없다', (tester) async {
      server.friendPhotos['dongsaeng'] = [
        {'id': 'f1', 'path': 'uid-d/f1.jpg', 'created_at': '2026-11-01T12:00:00Z'},
      ];
      await openDrawer(tester);
      expect(find.byKey(const ValueKey('chip-new-photos')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    test('latestFriendEvent · newPhotoCount', () {
      const wall = FriendWall(
        photos: [FriendPhoto(id: 'f', path: 'u/f.jpg', owner: 'd', kitId: 'k', createdAt: '2026-01-01T00:00:00Z')],
      );
      expect(latestFriendEvent(null, wall)?.kind, 'photo');
      expect(latestFriendEvent(null, null), isNull);
      expect(newPhotoCount(wall, ''), 0);
      expect(newPhotoCount(wall, '2025-12-31T00:00:00Z'), 1);
      expect(newPhotoCount(wall, '2026-01-02T00:00:00Z'), 0);
    });
  });

  testWidgets('L-3 도감 비교: 친구 사진 수 · 작품별 사진 수', (tester) async {
    const friend = Member(
      name: '동생',
      handle: 'dongsaeng',
      role: '친구',
      self: false,
      liked: 0,
      lit: 1,
      owned: 1,
      guide: {'w1': 1},
    );
    await show(
      tester,
      const FriendCollectionScreen(
        friend: friend,
        initial: CollectionJump.guide,
        photoKitIds: ['b', '', 'c'],
      ).withLoaders(_loaders),
    );
    expect(find.byKey(const ValueKey('friend-photo-count')), findsOneWidget);
    expect(find.text(' 3'), findsOneWidget); // 사진 3장
    expect(find.byKey(const ValueKey('work-photos-w1')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const ValueKey('work-photos-w1'))).data, ' 2'); // 상품을 이은 2장
    expect(tester.takeException(), isNull);
  });

  test('다른 계정: 앞 계정 아바타는 새 계정에 올리지 않고, 공개 범위 · 친구 아바타도 비운다', () async {
    files.files['a.jpg'] = _jpeg;
    files.files['friend-d-1.jpg'] = _jpeg;
    store.social
      ..setImage(
        ProfileImageKind.avatar,
        const ProfileImage(file: 'a.jpg', at: 't', uploadedTo: 'uid:other@example.com'),
      )
      ..setPrivacy(public: false, hidden: {'x'})
      ..setFriendAvatar('dongsaeng', 'friend-d-1.jpg');
    await account.friends.refresh();
    await account.profileImages.sync();
    expect(store.social.image(ProfileImageKind.avatar), isNull);
    expect(storage.uploads, isEmpty);
    expect(files.files.containsKey('a.jpg'), isFalse);
    store.social.resetForAccount();
    await Future<void>.delayed(Duration.zero);
    expect((store.social.photosPublic, store.social.privacyDirty), (true, false));
    expect(store.social.hiddenFrom, isEmpty);
    expect(store.social.friendAvatars, isEmpty);
    expect(files.files.containsKey('friend-d-1.jpg'), isFalse);
  });

  test('SocialLocal: 저장 → 다시 읽기, 위험한 파일 이름은 버린다', () {
    store.social
      ..setImage(ProfileImageKind.avatar, const ProfileImage(file: 'profile-avatar-x.jpg', at: 't', uploadedTo: 'u'))
      ..setPrivacy(public: false, hidden: {'dongsaeng'})
      ..dismissSuggestion('cousin')
      ..setFriendsSeenAt('2026-11-01T00:00:00Z')
      ..setFriendAvatar('dongsaeng', 'friend-dongsaeng-1.jpg');
    final again = UserStore.memory()..debugLoadJson(store.toJson());
    final s = again.social;
    expect(s.image(ProfileImageKind.avatar)?.uploadedTo, 'u');
    expect((s.photosPublic, s.privacyDirty), (false, true));
    expect(s.hiddenFrom, {'dongsaeng'});
    expect(s.dismissedSuggestions, {'cousin'});
    expect(s.friendsSeenAt, '2026-11-01T00:00:00Z');
    expect(s.friendAvatars, {'dongsaeng': 'friend-dongsaeng-1.jpg'});
    final bad = UserStore.memory()
      ..debugLoadJson({
        'local_state': {
          'profile_images': {
            'avatar': {'file': '../x.jpg', 'at': 't'},
          },
          'friend_avatars': {'x': '../../y.jpg'},
        },
      });
    expect(bad.social.image(ProfileImageKind.avatar), isNull);
    expect(bad.social.friendAvatars, isEmpty);
    expect(bad.social.photosPublic, isTrue); // 키가 없으면 공개
  });
}

extension on FriendCollectionScreen {
  FriendCollectionScreen withLoaders(Loaders l) =>
      FriendCollectionScreen(friend: friend, initial: initial, photoKitIds: photoKitIds, loaders: l);
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
