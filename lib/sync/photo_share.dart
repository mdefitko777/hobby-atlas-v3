// 사진 공유 — 친구에게 보이기를 켠 내 사진을 Supabase Storage(photos 버킷)에 올리고, 친구의 사진 벽을 받는다.
// 서버: docs/supabase-v3-photos.sql (버킷 + Storage RLS + gunpula_v3_put_photo · delete_photo · get_friend_wall).
// 그 SQL 을 아직 안 돌린 프로젝트면 [PhotoShareService.missing] — 사진은 기기에만 두고 화면에 ⚠ 하나만 보인다.
// Storage 를 부르는 진짜 코드는 supabase_backend.dart (SupabasePhotoStorage), 테스트는 가짜(test/support/fake_backend.dart).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/photo_files.dart';
import '../data/user_store.dart';
import '../json_util.dart';
import 'friends_service.dart' show normalizeHandle;
import 'rpc.dart';

/// Storage 실패. [status] = HTTP 상태 글자 (예: '404', '403')
class PhotoStorageException implements Exception {
  const PhotoStorageException(this.message, {this.status = ''});
  final String message;
  final String status;

  /// 버킷 · 정책이 아직 없음 (SQL 을 안 돌림) — 다시 해도 안 된다
  bool get notSetUp {
    final m = message.toLowerCase();
    return m.contains('bucket not found') || m.contains('row-level security') || m.contains('not set up');
  }

  @override
  String toString() => status.isEmpty ? message : '$message ($status)';
}

/// Supabase Storage 한 겹 (photos 버킷)
abstract interface class PhotoStorage {
  Future<void> upload(String path, Uint8List bytes);
  Future<void> remove(List<String> paths);
  Future<Uint8List> download(String path);
}

/// 백엔드 없음 (테스트 · 설정 없음)
class NoPhotoStorage implements PhotoStorage {
  const NoPhotoStorage();

  static const _e = PhotoStorageException('photo storage not set up');

  @override
  Future<void> upload(String path, Uint8List bytes) => Future.error(_e);
  @override
  Future<void> remove(List<String> paths) => Future.error(_e);
  @override
  Future<Uint8List> download(String path) => Future.error(_e);
}

/// 친구가 보이기로 둔 사진 한 장
class FriendPhoto {
  const FriendPhoto({
    required this.id,
    required this.path,
    required this.owner,
    this.kitId = '',
    this.unitId = '',
    this.watermark = true,
    this.createdAt = '',
  });

  final String id;

  /// Storage 경로 `<user_id>/<id>.jpg`
  final String path;

  /// 올린 친구의 @아이디 (워터마크 글자)
  final String owner;
  final String kitId;
  final String unitId;
  final bool watermark;
  final String createdAt;

  static FriendPhoto? parse(Object? raw, String owner) {
    final m = jMap(raw);
    final id = jStr(m['id']);
    final path = jStr(m['path']);
    if (id.isEmpty || path.isEmpty) return null;
    return FriendPhoto(
      id: id,
      path: path,
      owner: owner,
      kitId: jStr(m['kit_id']),
      unitId: jStr(m['unit_id']),
      watermark: m['watermark'] != false,
      createdAt: jStr(m['created_at']),
    );
  }
}

/// 친구 사진 벽 + 취향 태그. [missing] = 서버에 사진 공유가 아직 없음 (그러면 친구의 구매함 사진으로 채운다)
class FriendWall {
  const FriendWall({this.photos = const [], this.tags = const [], this.missing = false, this.offline = false});
  final List<FriendPhoto> photos;
  final List<String> tags;
  final bool missing;
  final bool offline;
}

enum PhotoShareState { idle, syncing, missing, offline, error }

class PhotoShareService extends ChangeNotifier {
  PhotoShareService({
    required RpcClient Function() rpc,
    required this.storage,
    required this.auth,
    required this.store,
    this.debounce = const Duration(milliseconds: 900),
  }) : _rpc = rpc;

  final RpcClient Function() _rpc;
  final PhotoStorage storage;
  final AuthService auth;
  final UserStore store;
  final Duration debounce;

  PhotoShareState state = PhotoShareState.idle;

  /// 마지막 실패 문장 (⚠ 툴팁)
  String message = '';

  /// 서버에 버킷 · 함수가 없음 → 사진은 기기에만
  bool get missing => state == PhotoShareState.missing;

  /// 화면에 ⚠ 를 띄울지 (올리지 못한 사진이 있을 때만)
  bool get warn => state == PhotoShareState.missing || state == PhotoShareState.error;

  final Map<String, FriendWall> walls = {};
  final Map<String, Uint8List> _images = {};
  Timer? _timer;
  Future<void>? _running;
  bool _again = false;

  static String pathOf(String userId, String photoId) => '$userId/$photoId.jpg';

  /// 바꾼 뒤 조금 있다가 올리기 · 내리기
  void syncSoon() {
    _timer?.cancel();
    _timer = Timer(debounce, () => sync().ignore());
  }

  /// 친구에게 보이기 켠 것 → 올림, 끈 것 · 지운 것 → 내림. 겹쳐 부르면 끝난 뒤 한 번 더
  Future<void> sync() {
    if (_running != null) {
      _again = true;
      return _running!;
    }
    final f = _running = _sync().whenComplete(() {
      _running = null;
      if (_again) {
        _again = false;
        sync().ignore();
      }
    });
    return f;
  }

  void _set(PhotoShareState s, [String m = '']) {
    if (state == s && message == m) return;
    state = s;
    message = m;
    notifyListeners();
  }

  Future<void> _sync() async {
    if (!auth.signedIn || auth.userId.isEmpty) return;
    final uid = auth.userId;
    final work = [
      for (final p in store.allPhotos)
        if (_needsUpload(p, uid) || _needsRemove(p, uid)) p,
    ];
    if (work.isEmpty) {
      if (state == PhotoShareState.syncing || state == PhotoShareState.offline) _set(PhotoShareState.idle);
      return;
    }
    _set(PhotoShareState.syncing);
    try {
      for (final p in work) {
        if (_needsRemove(p, uid)) {
          await _rpc()('gunpula_v3_delete_photo', {'p_photo_id': p.id});
          await storage.remove([pathOf(uid, p.id)]);
          if (p.deleted) {
            store.purgePhoto(p.id);
          } else {
            store.updatePhoto(p.copyWith(uploadedTo: ''));
          }
        } else {
          final bytes = await PhotoFiles.instance.read(p.file);
          if (bytes == null) continue; // 파일이 사라졌다 — 올릴 수 없음
          await storage.upload(pathOf(uid, p.id), bytes);
          await _rpc()('gunpula_v3_put_photo', {
            'p_photo_id': p.id,
            'p_kit_id': p.kitId,
            'p_unit_id': p.unitId,
            'p_watermark': p.watermark,
            'p_created_at': p.createdAt.isEmpty ? null : p.createdAt,
          });
          store.updatePhoto(p.copyWith(uploadedTo: uid));
        }
      }
      _set(PhotoShareState.idle);
    } on PhotoStorageException catch (e) {
      _set(e.notSetUp ? PhotoShareState.missing : PhotoShareState.error, e.message);
    } on RpcException catch (e) {
      _set(e.isMissingFunction ? PhotoShareState.missing : PhotoShareState.error, e.message);
    } on OfflineException catch (e) {
      _set(PhotoShareState.offline, e.message);
    } on Object catch (e) {
      _set(PhotoShareState.error, '$e');
    }
  }

  /// 같은 계정에 아직 안 올라감 (워터마크 · 상품을 바꾸면 uploadedTo 를 비워 다시 올린다)
  bool _needsUpload(MyPhoto p, String uid) => p.shared && !p.deleted && p.uploadedTo != uid;

  /// 이 계정에 올라가 있는데 숨겼거나 지웠다
  bool _needsRemove(MyPhoto p, String uid) => p.uploadedTo == uid && (!p.shared || p.deleted);

  /// 친구의 사진 벽 — 실패해도 던지지 않는다 (빈 벽 + missing/offline)
  Future<FriendWall> friendWall(String handle, {bool force = false}) async {
    final h = normalizeHandle(handle);
    final cached = walls[h];
    if (cached != null && !force) return cached;
    FriendWall wall;
    try {
      final m = jMap(await _rpc()('gunpula_v3_get_friend_wall', {'p_handle': h}));
      wall = FriendWall(
        photos: [for (final x in jList(m['photos'])) ?FriendPhoto.parse(x, h)],
        tags: jList(m['tags']).whereType<String>().toList(),
      );
    } on RpcException catch (e) {
      wall = FriendWall(missing: e.isMissingFunction);
    } on OfflineException {
      return const FriendWall(offline: true); // 다음에 다시
    }
    walls[h] = wall;
    return wall;
  }

  /// 친구 사진 받기 (메모리에 남겨 둔다)
  Future<Uint8List> friendImage(FriendPhoto p) async {
    final hit = _images[p.path];
    if (hit != null) return hit;
    final b = await storage.download(p.path);
    _images[p.path] = b;
    return b;
  }

  void clear() {
    walls.clear();
    _images.clear();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
