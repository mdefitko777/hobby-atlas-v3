// 내 사진 되찾기 — 다시 설치했거나 다른 기기에서 로그인했을 때, 서버에 올라가 있는 내 사진(친구에게 보이기를 켠 것)을
// 사진 목록(UserStore.photos)에 다시 넣는다. 파일은 처음 볼 때 Storage `photos/<user_id>/<id>.jpg` 에서 받아
// 앱 문서 폴더 photos/ 에 둔다 (PhotoFiles.readOrFetch — 사진 벽 · 도감 칸 · 상품 상세 그대로).
// 서버: docs/supabase-v3-sync.sql 의 gunpula_v3_get_my_photos. 없으면(옛 SQL) 아무것도 안 한다.
// 지우기는 원래 길 그대로: 되찾은 사진도 uploadedTo = 이 계정이라 지우면 photo_share.dart 가 서버에서 내린다.
// 다른 기기에서 지워 서버 목록에서 빠진 사진: 되찾은 것이면 이 기기에서도 뺀다, 이 기기에서 찍은 것이면 남기고 "안 올림"으로.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/photo_files.dart';
import '../data/social_local.dart' show safeFileName;
import '../data/user_store.dart';
import '../json_util.dart';
import 'photo_share.dart';
import 'rpc.dart';

class PhotoRestoreService {
  PhotoRestoreService({required RpcClient Function() rpc, required this.storage, required this.auth, required this.store})
    : _rpc = rpc;

  final RpcClient Function() _rpc;
  final PhotoStorage storage;
  final AuthService auth;
  final UserStore store;

  /// 서버에 get_my_photos 가 없음 (다음 로그인 때 다시 물어본다)
  bool missing = false;
  Future<int>? _running;

  /// 사진 id 로 쓸 수 있는 글자 (파일 이름 · Storage 경로에 그대로 들어간다)
  static final _safeId = RegExp(r'^[A-Za-z0-9_-]{1,80}$');

  /// 서버 목록과 맞춘다 — 새로 넣은 사진 수. 겹쳐 부르면 도는 것을 같이 기다린다. 실패해도 던지지 않는다
  Future<int> restore() => _running ??= _restore().whenComplete(() => _running = null);

  Future<int> _restore() async {
    if (!auth.signedIn || auth.userId.isEmpty) return 0;
    final uid = auth.userId;
    await store.load();
    // 부르기 전 모습 — 응답을 기다리는 사이 올라간 사진을 "서버에서 빠짐"으로 보지 않게
    final before = {
      for (final p in store.allPhotos)
        if (p.uploadedTo == uid && !p.deleted) p.id,
    };
    final Object? raw;
    try {
      raw = await _rpc()('gunpula_v3_get_my_photos');
    } on RpcException catch (e) {
      if (e.isMissingFunction) missing = true;
      return 0;
    } on OfflineException {
      return 0;
    }
    missing = false;
    if (auth.userId != uid) return 0;
    final server = <String, Map<String, Object?>>{};
    for (final x in jList(raw)) {
      final m = jMap(x);
      final id = jStr(m['id']);
      if (_safeId.hasMatch(id) && safeFileName('$id.jpg')) server[id] = m;
    }
    final have = {for (final p in store.allPhotos) p.id};
    store.addRestoredPhotos([
      for (final e in server.entries)
        if (!have.contains(e.key))
          MyPhoto(
            id: e.key,
            file: '${e.key}.jpg',
            createdAt: jStr(e.value['created_at']),
            kitId: jStr(e.value['kit_id']),
            unitId: jStr(e.value['unit_id']),
            watermark: e.value['watermark'] != false,
            uploadedTo: uid,
            restored: true,
          ),
    ]);
    // 다른 기기에서 지웠다 (서버 목록에서 빠짐)
    for (final id in before) {
      if (server.containsKey(id)) continue;
      final p = store.photo(id);
      if (p == null || p.uploadedTo != uid || p.deleted) continue;
      if (p.restored) {
        store.purgePhoto(id);
        unawaited(PhotoFiles.instance.delete(p.file));
      } else {
        store.updatePhoto(p.copyWith(uploadedTo: '', shared: false));
      }
    }
    return server.keys.where((id) => !have.contains(id)).length;
  }

  /// 기기에 없는 사진 파일 받기 (PhotoFiles.fetchMissing) — 이 계정에 올라가 있는 내 사진만
  Future<Uint8List?> fetch(String file) async {
    final uid = auth.userId;
    if (!auth.signedIn || uid.isEmpty) return null;
    final p = store.allPhotos.where((x) => x.file == file).firstOrNull;
    if (p == null || !(p.uploadedTo == uid || (p.restored && p.uploadedTo.isEmpty))) return null;
    try {
      return await storage.download(PhotoShareService.pathOf(uid, p.id));
    } on Object {
      return null; // 오프라인 · 없음 → 회색 칸, 다음에 다시
    }
  }
}
