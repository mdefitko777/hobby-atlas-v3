// 내 사진 되찾기 (lib/sync/photo_restore.dart) — 가짜 서버 · 가짜 Storage · 메모리 사진 파일만 쓴다.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/data/photo_files.dart';
import 'package:hobby_atlas/data/user_store.dart';
import 'package:hobby_atlas/sync/account.dart';

import 'support/fake_backend.dart';

final _jpeg = Uint8List.fromList(List.generate(32, (i) => i));

void main() {
  late FakeServer server;
  late FakePhotoStorage storage;
  late MemoryPhotoFiles files;
  late UserStore store;
  late Account account;
  const uid = 'uid:me@example.com';

  setUp(() {
    server = FakeServer();
    storage = FakePhotoStorage();
    files = MemoryPhotoFiles();
    PhotoFiles.instance = files;
    store = UserStore.memory();
    account = Account(auth: FakeAuth(signedIn: true), rpc: server, storage: storage, store: store);
    // 다른 기기에서 올려 둔 사진 두 장
    for (final (id, at) in [('pold', '2026-10-01T00:00:00Z'), ('pnew', '2026-10-05T00:00:00Z')]) {
      server.myPhotos[id] = {'p_photo_id': id, 'p_kit_id': 'kit-$id', 'p_unit_id': '', 'p_watermark': true, 'p_created_at': at};
      storage.objects['$uid/$id.jpg'] = _jpeg;
    }
  });

  tearDown(() => account.dispose());

  test('다시 설치: 서버 목록 → 사진 목록에 (새것부터), 파일은 처음 볼 때 받는다', () async {
    expect(await account.photoRestore.restore(), 2);
    expect([for (final p in store.photos) p.id], ['pnew', 'pold']);
    final p = store.photo('pnew')!;
    expect(p.restored, isTrue);
    expect(p.uploadedTo, uid);
    expect(p.kitId, 'kit-pnew');
    expect(files.files, isEmpty, reason: '바로 다 받지 않는다');

    expect(await PhotoFiles.instance.providerOrFetch(p.file), isNotNull);
    expect(files.files[p.file], _jpeg);
    // 두 번째는 기기 파일 (Storage 를 다시 부르지 않음)
    storage.offline = true;
    expect(await PhotoFiles.instance.readOrFetch(p.file), _jpeg);

    // 다시 맞춰도 겹치지 않는다
    storage.offline = false;
    expect(await account.photoRestore.restore(), 0);
    expect(store.photos, hasLength(2));
  });

  test('되찾은 사진을 지우면 서버(목록 · Storage)에서도 내린다', () async {
    await account.photoRestore.restore();
    store.removePhoto('pold');
    expect(store.photos.map((p) => p.id), ['pnew']);
    await account.photos.sync();
    expect(server.myPhotos.keys, ['pnew']);
    expect(storage.objects.keys, ['$uid/pnew.jpg']);
    expect(store.allPhotos.map((p) => p.id), ['pnew']);
  });

  test('되찾은 사진을 친구에게 숨기면: 먼저 기기에 받아 두고 서버에서 내린다', () async {
    await account.photoRestore.restore();
    store.updatePhoto(store.photo('pnew')!.copyWith(shared: false));
    await account.photos.sync();
    expect(files.files['pnew.jpg'], _jpeg);
    expect(server.myPhotos.keys, ['pold']);
    expect(store.photo('pnew')!.uploadedTo, '');
  });

  test('다른 기기에서 지운 사진: 되찾은 것은 빼고, 이 기기에서 찍은 것은 "안 올림"으로 남긴다', () async {
    await account.photoRestore.restore();
    await files.write('pold.jpg', _jpeg);
    store.addPhoto(MyPhoto(id: 'pmine', file: 'pmine.jpg', createdAt: '2026-10-09T00:00:00Z', uploadedTo: uid));
    server.myPhotos.remove('pold');
    await account.photoRestore.restore();
    expect(store.photo('pold'), isNull);
    expect(files.files.containsKey('pold.jpg'), isFalse);
    final mine = store.photo('pmine')!;
    expect(mine.uploadedTo, '');
    expect(mine.shared, isFalse);
  });

  test('서버에 함수가 없거나 오프라인이면 아무것도 안 한다', () async {
    server.missing.add('gunpula_v3_get_my_photos');
    expect(await account.photoRestore.restore(), 0);
    expect(account.photoRestore.missing, isTrue);
    server
      ..missing.clear()
      ..offline = true;
    expect(await account.photoRestore.restore(), 0);
    expect(store.photos, isEmpty);
  });

  test('로그인하면 스스로 되찾는다', () async {
    final auth = FakeAuth();
    final s = UserStore.memory();
    final acc = Account(auth: auth, rpc: server, storage: storage, store: s);
    auth.signedIn = true;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(s.photos.map((p) => p.id), ['pnew', 'pold']);
    acc.dispose();
  });
}
