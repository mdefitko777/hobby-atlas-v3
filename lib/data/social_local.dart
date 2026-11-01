// 친구 쪽 기기 기록 — 내 아바타 · 배경 사진, 사진 공개 범위, 알 수도 있는 친구 닫음, 친구 서랍 본 시각, 친구 아바타 캐시.
// UserStore 의 local_state 안에 키 다섯 개로 들어간다 (UserStore.social). 동기화 payload 에는 넣지 않는다.
//   profile_images        {avatar|cover: {file, at, uploaded_to}}  — 사진 파일은 PhotoFiles(photos/ 폴더)
//   photo_privacy         {public, hidden_from: [@아이디], dirty}   — 서버 = gunpula_v3_set_photo_privacy
//   dismissed_suggestions [@아이디]                                 — 알 수도 있는 친구 × (기기에만)
//   friends_seen_at       ISO 시각                                  — 친구 서랍을 마지막으로 연 때 ("새 사진 n")
//   friend_avatars        {@아이디: 파일 이름}                       — 친구 아바타 (오프라인에서도 보이게)
library;

import 'package:flutter/foundation.dart';

import '../json_util.dart';
import 'photo_files.dart';

/// 프로필 사진 종류 — Storage 경로 `<user_id>/profile/<kind>.jpg`
enum ProfileImageKind {
  avatar,
  cover;

  String get key => name;
}

/// 내 아바타 · 배경 사진 한 장 (기기 파일 + 어디까지 올렸나)
@immutable
class ProfileImage {
  const ProfileImage({required this.file, required this.at, this.uploadedTo = ''});

  /// photos/ 폴더 안 파일 이름. 바꿀 때마다 새 이름 (이미지 캐시가 옛 그림을 보이지 않게)
  final String file;

  /// 고른 시각 (UTC ISO) — 서버 preferences 의 `<kind>_at` 과 비교해 새것을 쓴다
  final String at;

  /// 올라가 있는 계정 (Supabase user id) — '' = 아직
  final String uploadedTo;

  ProfileImage copyWith({String? uploadedTo}) =>
      ProfileImage(file: file, at: at, uploadedTo: uploadedTo ?? this.uploadedTo);

  Map<String, Object?> toJson() => {'file': file, 'at': at, if (uploadedTo.isNotEmpty) 'uploaded_to': uploadedTo};

  static ProfileImage? fromJson(Object? raw) {
    final m = jMap(raw);
    final file = jStr(m['file']);
    if (!safeFileName(file)) return null;
    return ProfileImage(file: file, at: jStr(m['at']), uploadedTo: jStr(m['uploaded_to']));
  }
}

/// photos/ 밖으로 나가지 않는 파일 이름
bool safeFileName(String f) => f.isNotEmpty && !f.contains('/') && !f.contains(r'\') && !f.contains('..');

class SocialLocal {
  SocialLocal(this._changed);

  final VoidCallback _changed;

  final Map<ProfileImageKind, ProfileImage> _images = {};

  /// 사진 공개 (끄면 친구 누구에게도 내 사진이 안 보인다)
  bool photosPublic = true;

  /// 내 사진을 보지 못하게 한 친구 (@아이디)
  final Set<String> hiddenFrom = {};

  /// 공개 범위를 바꿨는데 서버에 아직 못 보냄
  bool privacyDirty = false;

  /// 알 수도 있는 친구에서 × 로 닫은 사람
  final Set<String> dismissedSuggestions = {};

  /// 친구 서랍을 마지막으로 연 시각 (UTC ISO, 처음이면 '')
  String friendsSeenAt = '';

  /// 친구 @아이디 → 받아 둔 아바타 파일 (이름에 버전이 들어 있다)
  final Map<String, String> friendAvatars = {};

  ProfileImage? image(ProfileImageKind k) => _images[k];

  void load(Map<String, Object?> local) {
    _images.clear();
    final imgs = jMap(local['profile_images']);
    for (final k in ProfileImageKind.values) {
      if (ProfileImage.fromJson(imgs[k.key]) case final p?) _images[k] = p;
    }
    final pv = jMap(local['photo_privacy']);
    photosPublic = pv['public'] != false;
    hiddenFrom
      ..clear()
      ..addAll(jList(pv['hidden_from']).whereType<String>());
    privacyDirty = pv['dirty'] == true;
    dismissedSuggestions
      ..clear()
      ..addAll(jList(local['dismissed_suggestions']).whereType<String>());
    friendsSeenAt = jStr(local['friends_seen_at']);
    friendAvatars
      ..clear()
      ..addAll({
        for (final e in jMap(local['friend_avatars']).entries)
          if (safeFileName(jStr(e.value))) e.key: jStr(e.value),
      });
  }

  Map<String, Object?> toJson() => {
    'profile_images': {for (final e in _images.entries) e.key.key: e.value.toJson()},
    'photo_privacy': {'public': photosPublic, 'hidden_from': hiddenFrom.toList(), 'dirty': privacyDirty},
    'dismissed_suggestions': dismissedSuggestions.toList(),
    'friends_seen_at': friendsSeenAt,
    'friend_avatars': friendAvatars,
  };

  /// null = 지움
  void setImage(ProfileImageKind k, ProfileImage? p) {
    if (p == null) {
      if (_images.remove(k) == null) return;
    } else {
      _images[k] = p;
    }
    _changed();
  }

  /// 공개 범위 바꾸기 — [dirty] = 서버에 보낼 것
  void setPrivacy({required bool public, required Set<String> hidden, bool dirty = true}) {
    if (public == photosPublic && setEquals(hidden, hiddenFrom) && dirty == privacyDirty) return;
    photosPublic = public;
    hiddenFrom
      ..clear()
      ..addAll(hidden);
    privacyDirty = dirty;
    _changed();
  }

  void dismissSuggestion(String handle) {
    if (dismissedSuggestions.add(handle)) _changed();
  }

  void setFriendsSeenAt(String iso) {
    if (iso == friendsSeenAt) return;
    friendsSeenAt = iso;
    _changed();
  }

  /// 다른 계정으로 로그인했다 → 계정에 딸린 것(공개 범위 · 닫은 추천 · 서랍 본 시각 · 친구 아바타 목록)을 비운다.
  /// 내 아바타 · 배경은 uploaded_to 로 가려 ProfileImageService 가 정리한다.
  void resetForAccount() {
    photosPublic = true;
    hiddenFrom.clear();
    privacyDirty = false;
    dismissedSuggestions.clear();
    friendsSeenAt = '';
    for (final f in friendAvatars.values) {
      PhotoFiles.instance.delete(f).ignore();
    }
    friendAvatars.clear();
    _changed();
  }

  /// null = 지움
  void setFriendAvatar(String handle, String? file) {
    if (friendAvatars[handle] == file) return;
    file == null ? friendAvatars.remove(handle) : friendAvatars[handle] = file;
    _changed();
  }
}
