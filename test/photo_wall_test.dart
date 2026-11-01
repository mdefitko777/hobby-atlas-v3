// 사진 벽 · 사진 보기 · 친구 사진 · 취향 태그 — 가짜 서버 · 가짜 Storage · 메모리 사진 파일만 쓴다.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/api.dart';
import 'package:hobby_atlas/data/photo_files.dart';
import 'package:hobby_atlas/data/user_store.dart';
import 'package:hobby_atlas/detail_pane.dart';
import 'package:hobby_atlas/marks.dart';
import 'package:hobby_atlas/models.dart';
import 'package:hobby_atlas/screens/i_profile_screen.dart';
import 'package:hobby_atlas/screens/t_photo_screen.dart';
import 'package:hobby_atlas/sync/account.dart';
import 'package:hobby_atlas/sync/photo_share.dart';
import 'package:hobby_atlas/theme.dart';
import 'package:image_picker/image_picker.dart';

import 'support/fake_backend.dart';

const _profile = Profile(name: '나', handle: '', avatarText: '나', tags: [], spendKrw: 0, workspace: '', friends: []);

Kit _kit(String id) => Kit.fromJson({'id': id, 'franchiseId': 'gundam', 'name': '상품 $id', 'line': 'HG', 'image': ''})!;

final _kits = [
  for (final id in ['k1', 'k2', 'a', 'b']) _kit(id),
];

final _loaders = Loaders(
  kits: (_) async => _kits,
  collection: () async => const [],
  kitsByIds: (ids) async => [
    for (final k in _kits)
      if (ids.contains(k.id)) k,
  ],
  worlds: (_) async => const [],
  guideWorks: () async => const [],
  guideUnits: (_) async => const [],
  bbxTops: () async => const [],
  announcements: (_) async => const [],
  profile: () async => _profile,
  notifications: () async => const [],
  friendGuide: (_) async => const {},
);

final _jpeg = Uint8List.fromList(List.generate(64, (i) => i));

void main() {
  late FakeServer server;
  late FakeAuth auth;
  late FakePhotoStorage storage;
  late MemoryPhotoFiles files;
  late Account account;
  late UserStore store;

  setUp(() {
    files = MemoryPhotoFiles();
    PhotoFiles.instance = files;
    server = FakeServer(v2Payload: null, handle: 'bbang', displayName: '빵빵한빵디');
    server.users['dongsaeng'] = (
      name: '동생',
      collection: {
        'items': {
          'a': {'status': 'wanted', 'updated_at': '2026-02-01T00:00:00Z'},
          'b': {'status': 'owned', 'updated_at': '2026-02-02T00:00:00Z'},
        },
      },
    );
    server.friends.add('dongsaeng');
    auth = FakeAuth(signedIn: true);
    storage = FakePhotoStorage();
    store = UserStore.memory();
    account = Account(auth: auth, rpc: server, storage: storage, store: store);
  });

  tearDown(() => account.dispose());

  Future<void> show(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        key: UniqueKey(), // 같은 테스트에서 화면을 바꿔 그릴 때 새 Navigator
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

  /// 기기에 사진 하나 (친구에게 보이기 켬)
  MyPhoto addPhoto({String id = 'p1', String kitId = '', String uploadedTo = ''}) {
    final p = MyPhoto(id: id, file: '$id.jpg', createdAt: '2026-11-01T00:00:00Z', kitId: kitId, uploadedTo: uploadedTo);
    files.files[p.file] = _jpeg;
    store.addPhoto(p);
    return p;
  }

  testWidgets('사진 벽: 내 사진이 없으면 구매함 상품 사진으로 채운다', (tester) async {
    store
      ..setStatus('k1', CollectStatus.owned)
      ..setStatus('k2', CollectStatus.owned)
      ..setStatus('a', CollectStatus.wanted);
    await loadMe(tester);
    await show(tester, ProfileScreen(loaders: _loaders, onJump: (_) {}));
    expect(find.byKey(const ValueKey('kit-photo-k1')), findsOneWidget);
    expect(find.byKey(const ValueKey('kit-photo-k2')), findsOneWidget);
    expect(find.byKey(const ValueKey('kit-photo-a')), findsNothing); // 좋아요는 벽에 없음
    expect(find.byType(MyPhotoTile), findsNothing);
    // My Page 와 같은 아이콘 숫자 (♡ 1 · 리본 2)
    expect(find.byTooltip('좋아요'), findsOneWidget);
    expect(find.byTooltip('구매함'), findsOneWidget);
    expect(find.byTooltip('이번 달 지출'), findsOneWidget);
    expect(find.byTooltip('총 지출'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('사진 넣기: 갤러리에서 고르면 맨 앞 칸 · 친구에게 보이기면 Storage 에 올림', (tester) async {
    store.setStatus('k1', CollectStatus.owned);
    ImageSource? asked;
    photoPicker = (s) async {
      asked = s;
      return _jpeg;
    };
    addTearDown(() => photoPicker = (_) async => null);
    await loadMe(tester);
    await show(tester, ProfileScreen(loaders: _loaders, onJump: (_) {}));
    await tester.tap(find.byTooltip('사진 넣기'));
    await settle(tester);
    await tester.tap(find.text('갤러리'));
    await settle(tester);
    expect(asked, ImageSource.gallery);
    expect(store.photos, hasLength(1));
    final p = store.photos.single;
    expect(files.files[p.file], _jpeg);
    // 내 사진이 상품 사진보다 앞 (왼쪽 위)
    final mine = tester.getTopLeft(find.byKey(ValueKey('my-photo-${p.id}')));
    final kit = tester.getTopLeft(find.byKey(const ValueKey('kit-photo-k1')));
    expect(mine.dx < kit.dx || mine.dy < kit.dy, isTrue);
    // 0.9초 뒤 올림: Storage <user_id>/<id>.jpg + put_photo
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);
    expect(storage.objects.keys, ['${auth.userId}/${p.id}.jpg']);
    expect(server.myPhotos.keys, [p.id]);
    expect(store.photo(p.id)!.uploadedTo, auth.userId);
    expect(tester.takeException(), isNull);
  });

  testWidgets('친구에게 보이기를 끄면 기록에 남고 서버에서 내린다', (tester) async {
    await loadMe(tester);
    final p = addPhoto();
    account.photos.sync().ignore(); // 가짜 서버는 pump 로 진행된다 (await 하면 멈춤)
    await settle(tester);
    expect(storage.objects, hasLength(1));
    await show(tester, PhotoViewScreen(mine: p.id));
    expect(find.text('친구에게 보이기'), findsOneWidget);
    expect(find.text('HA · @bbang'), findsWidgets); // 워터마크 스위치 + 미리보기
    await tester.tap(find.byKey(const ValueKey('photo-shared')));
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);
    expect(store.photo(p.id)!.shared, isFalse);
    final saved = (store.toJson()['local_state']! as Map)['photos'] as List;
    expect((saved.single as Map)['shared'], false);
    expect(storage.objects, isEmpty);
    expect(server.myPhotos, isEmpty);
    expect(store.photo(p.id)!.uploadedTo, '');
    expect(tester.takeException(), isNull);
  });

  testWidgets('친구 보기: 친구가 보이기로 둔 사진 · 태그 · ♡/리본 숫자', (tester) async {
    server.friendPhotos['dongsaeng'] = [
      {'id': 'f1', 'path': 'uid-d/f1.jpg', 'kit_id': 'b', 'watermark': true},
    ];
    server.friendTags['dongsaeng'] = ['건담', 'HG'];
    storage.objects['uid-d/f1.jpg'] = _jpeg;
    await loadMe(tester);
    const friend = Member(name: '동생', handle: 'dongsaeng', role: '친구', self: false, liked: 0, lit: 0, owned: 0);
    await show(tester, ProfileScreen(friend: friend, loaders: _loaders));
    expect(find.byKey(const ValueKey('friend-photo-f1')), findsOneWidget);
    expect(find.byKey(const ValueKey('kit-photo-b')), findsNothing); // 사진을 붙인 상품은 한 번만
    expect(find.text('건담'), findsOneWidget);
    expect(find.text('@dongsaeng'), findsOneWidget);
    expect(find.byTooltip('좋아요'), findsOneWidget);
    expect(server.count('gunpula_v3_get_friend_wall'), 1);
    await tester.tap(find.byKey(const ValueKey('friend-photo-f1')));
    await settle(tester);
    expect(find.byType(PhotoViewScreen), findsOneWidget);
    expect(find.text('HA · @dongsaeng'), findsOneWidget); // 친구가 정한 워터마크
    expect(find.text('친구에게 보이기'), findsNothing); // 친구 사진은 스위치 없음
    expect(tester.takeException(), isNull);
  });

  testWidgets('서버에 사진 공유가 없으면: 사진은 기기에 · ⚠ · 친구는 구매함 사진', (tester) async {
    storage.missingBucket = true;
    server.missing.add('gunpula_v3_get_friend_wall');
    await loadMe(tester);
    final p = addPhoto();
    await show(tester, ProfileScreen(loaders: _loaders, onJump: (_) {}));
    await settle(tester);
    expect(account.photos.state, PhotoShareState.missing);
    expect(find.byKey(const ValueKey('photo-warn')), findsOneWidget);
    expect(find.byKey(ValueKey('my-photo-${p.id}')), findsOneWidget);
    expect(store.photo(p.id)!.uploadedTo, '');
    expect(tester.takeException(), isNull);

    // 친구 보기: get_friend_wall 이 없어도 친구 구매함 상품으로
    const friend = Member(name: '동생', handle: 'dongsaeng', role: '친구', self: false, liked: 0, lit: 0, owned: 0);
    await show(tester, ProfileScreen(friend: friend, loaders: _loaders));
    expect(find.byKey(const ValueKey('kit-photo-b')), findsOneWidget);
    expect(find.byType(FriendPhotoTile), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('취향 태그: 고치면 기기 + v3 preferences.tags', (tester) async {
    await loadMe(tester);
    await show(tester, ProfileScreen(loaders: _loaders, onJump: (_) {}));
    await tester.tap(find.byTooltip('프로필 편집'));
    await settle(tester);
    await tester.tap(find.text('취향 태그'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), '건담');
    await tester.tap(find.byTooltip('태그 더하기'));
    await settle(tester);
    await tester.tap(find.byTooltip('저장'));
    await settle(tester);
    expect(store.profileTags, ['건담']);
    expect(server.preferences['tags'], ['건담']);
    expect(find.text('건담'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('UserStore: 사진 · 태그가 local_state 로 저장되고, 올라간 사진은 지워도 내릴 때까지 남는다', () {
    final s = UserStore.memory()
      ..addPhoto(const MyPhoto(id: 'p1', file: 'p1.jpg', createdAt: '', uploadedTo: 'u1'))
      ..addPhoto(const MyPhoto(id: 'p2', file: 'p2.jpg', createdAt: ''))
      ..setProfileTags(['건담']);
    final local = s.toJson()['local_state']! as Map;
    expect((local['photos'] as List).length, 2);
    expect(local['profile_tags'], ['건담']);
    s
      ..removePhoto('p2')
      ..removePhoto('p1');
    expect(s.photos, isEmpty);
    expect(s.allPhotos.single.deleted, isTrue); // 서버에서 내린 뒤 purgePhoto
    expect(MyPhoto.fromJson({'id': 'x', 'file': '../evil.jpg'}), isNull);
  });

  testWidgets('워터마크 저장: 같은 크기의 PNG', (tester) async {
    await tester.runAsync(() async {
      final rec = ui.PictureRecorder();
      Canvas(rec).drawRect(const Rect.fromLTWH(0, 0, 120, 80), Paint()..color = const Color(0xFF1C86D9));
      final img = await rec.endRecording().toImage(120, 80);
      final png = (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
      final out = await composeWatermark(png, 'HA · @bbang');
      final decoded = (await (await ui.instantiateImageCodec(out)).getNextFrame()).image;
      expect((decoded.width, decoded.height), (120, 80));
      expect(out, isNot(png));
    });
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
