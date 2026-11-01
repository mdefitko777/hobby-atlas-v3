// 아바타 · 배경 사진 (I-3) — 기기 파일이 먼저, 로그인했으면 Storage photos 버킷 `<user_id>/profile/avatar.jpg` · `cover.jpg`
// 에 올리고 경로를 v3 preferences.avatar · cover (+ _at 고른 시각) 에 적는다 (update_profile 은 preferences 를 통째로
// 바꾸므로 FriendsService.setProfileImage 가 합쳐서 보낸다).
// 다른 기기에서 바꿨으면(서버 _at 이 다름) 받아서 기기에 둔다. 친구 아바타는 사진 벽(get_friend_wall)의 avatar_path 로
// 받아 기기에 남긴다 (오프라인에서도 보이게). 못 받으면 첫 글자 아바타.
// 서버: docs/supabase-v3-photos.sql(버킷 · 쓰기 정책) + docs/supabase-v3-social.sql(친구 읽기 · 경로 전달).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/photo_files.dart';
import '../data/social_local.dart';
import '../data/user_store.dart';
import 'friends_service.dart';
import 'photo_share.dart';
import 'rpc.dart';

enum ProfileImageState { idle, syncing, missing, offline, error }

class ProfileImageService extends ChangeNotifier {
  ProfileImageService({
    required this.storage,
    required this.auth,
    required this.store,
    required this.friends,
    required this.photos,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final PhotoStorage storage;
  final AuthService auth;
  final UserStore store;
  final FriendsService friends;
  final PhotoShareService photos;
  final DateTime Function() _clock;

  ProfileImageState state = ProfileImageState.idle;
  String message = '';

  /// 못 올린 아바타 · 배경이 있어 ⚠ 를 띄울지
  bool get warn => state == ProfileImageState.missing || state == ProfileImageState.error;

  Future<void>? _running;
  bool _again = false;

  static String pathOf(String userId, ProfileImageKind k) => '$userId/profile/${k.key}.jpg';

  void _set(ProfileImageState s, [String m = '']) {
    if (state == s && message == m) return;
    state = s;
    message = m;
    notifyListeners();
  }

  /// 새 사진 고름 → 기기에 (새 파일 이름) → 로그인했으면 올림
  Future<void> setMine(ProfileImageKind k, Uint8List bytes) async {
    final now = _clock().toUtc();
    final file = 'profile-${k.key}-${now.millisecondsSinceEpoch.toRadixString(36)}.jpg';
    await PhotoFiles.instance.write(file, bytes);
    final old = store.social.image(k);
    store.social.setImage(k, ProfileImage(file: file, at: now.toIso8601String()));
    if (old != null && old.file != file) await PhotoFiles.instance.delete(old.file);
    await sync();
  }

  /// 지우기 — 기기에서 빼고, 서버에 있으면 내린다 (오프라인이면 던진다: 친구에게 계속 보이면 안 되므로)
  Future<void> removeMine(ProfileImageKind k) async {
    final uid = auth.userId;
    final serverHas = auth.signedIn && (friends.me?.imagePath(k.key) ?? '').isNotEmpty;
    if (serverHas) {
      await friends.setProfileImage(k.key, '', '');
      try {
        await storage.remove([pathOf(uid, k)]);
      } on Object {
        // 경로가 preferences 에서 빠졌으니 친구 앱은 더 부르지 않는다 — 파일은 다음에 같은 이름으로 덮인다
      }
    }
    final old = store.social.image(k);
    store.social.setImage(k, null);
    if (old != null) await PhotoFiles.instance.delete(old.file);
  }

  /// 기기 ↔ 서버 맞추기. 겹쳐 부르면 끝난 뒤 한 번 더. 할 일이 없으면 서버를 부르지 않는다.
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

  Future<void> _sync() async {
    final me = friends.me;
    if (!auth.signedIn || auth.userId.isEmpty || me == null) return;
    final uid = auth.userId;
    try {
      for (final k in ProfileImageKind.values) {
        final local = store.social.image(k);
        final serverPath = me.imagePath(k.key);
        final serverAt = me.imageAt(k.key);
        var mine = local;
        if (mine != null && mine.uploadedTo.isNotEmpty && mine.uploadedTo != uid) {
          // 앞 계정의 사진 — 이 계정에 올리지 않는다
          store.social.setImage(k, null);
          await PhotoFiles.instance.delete(mine.file);
          mine = null;
        }
        if (mine != null && mine.uploadedTo != uid) {
          if (serverAt.isNotEmpty && serverAt.compareTo(mine.at) > 0) {
            await _download(k, serverPath, serverAt, uid, old: mine); // 다른 기기에서 더 늦게 바꿈
            continue;
          }
          final bytes = await PhotoFiles.instance.read(mine.file);
          if (bytes == null) {
            store.social.setImage(k, null);
            continue;
          }
          _set(ProfileImageState.syncing);
          await storage.upload(pathOf(uid, k), bytes);
          await friends.setProfileImage(k.key, pathOf(uid, k), mine.at);
          store.social.setImage(k, mine.copyWith(uploadedTo: uid));
        } else if (serverPath.isNotEmpty && (mine == null || mine.at != serverAt)) {
          await _download(k, serverPath, serverAt, uid, old: mine);
        } else if (serverPath.isEmpty && mine != null && mine.uploadedTo == uid) {
          // 다른 기기에서 지웠다
          store.social.setImage(k, null);
          await PhotoFiles.instance.delete(mine.file);
        }
      }
      _set(ProfileImageState.idle);
    } on PhotoStorageException catch (e) {
      _set(e.notSetUp ? ProfileImageState.missing : ProfileImageState.error, e.message);
    } on FriendsFailure catch (e) {
      _set(ProfileImageState.error, e.message);
    } on OfflineException catch (e) {
      _set(ProfileImageState.offline, e.message);
    } on Object catch (e) {
      _set(ProfileImageState.error, '$e');
    }
  }

  Future<void> _download(ProfileImageKind k, String path, String at, String uid, {ProfileImage? old}) async {
    _set(ProfileImageState.syncing);
    final bytes = await storage.download(path);
    final file = 'profile-${k.key}-${_version(at)}.jpg';
    await PhotoFiles.instance.write(file, bytes);
    store.social.setImage(k, ProfileImage(file: file, at: at, uploadedTo: uid));
    if (old != null && old.file != file) await PhotoFiles.instance.delete(old.file);
  }

  /// 친구 아바타를 기기에 받아 둔다 (사진 벽 avatar_path · avatar_at 기준, 바뀐 것만) — 실패하면 받아 둔 것 그대로
  Future<void> cacheFriendAvatars() async {
    for (final e in photos.walls.entries) {
      final h = e.key;
      final w = e.value;
      if (w.offline || w.missing) continue;
      final had = store.social.friendAvatars[h];
      if (w.avatarPath.isEmpty) {
        if (had != null) {
          store.social.setFriendAvatar(h, null);
          await PhotoFiles.instance.delete(had);
        }
        continue;
      }
      final file = 'friend-${_safe(h)}-${_version(w.avatarAt.isEmpty ? w.avatarPath : w.avatarAt)}.jpg';
      if (had == file) continue;
      try {
        final bytes = await photos.image(w.avatarPath);
        await PhotoFiles.instance.write(file, bytes);
        store.social.setFriendAvatar(h, file);
        if (had != null) await PhotoFiles.instance.delete(had);
      } on Object {
        // 다음에 다시 (첫 글자 아바타)
      }
    }
  }

  /// 친구 목록에서 빠진 사람의 아바타 지우기
  Future<void> forgetFriendsExcept(Set<String> keep) async {
    for (final h in [...store.social.friendAvatars.keys]) {
      if (keep.contains(h)) continue;
      final f = store.social.friendAvatars[h]!;
      store.social.setFriendAvatar(h, null);
      await PhotoFiles.instance.delete(f);
    }
  }
}

/// 파일 이름에 쓸 짧은 버전 (같은 시각 → 같은 이름, 실행마다 같음: FNV-1a 32비트)
String _version(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0xffffffff;
  }
  return h.toRadixString(36);
}

String _safe(String h) => h.replaceAll(RegExp(r'[^a-z0-9_]'), '_');
