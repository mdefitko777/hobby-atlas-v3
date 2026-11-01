// 내 정보 쪽 기기 기록 — 내 사진 · 취향 태그 · 특별 관심 친구 — UserStore 의 한 부분
// (친구 쪽 아바타 · 공개 범위 등은 lib/data/social_local.dart 의 SocialLocal)
part of '../user_store.dart';

mixin _ProfileLocal on ChangeNotifier {
  void _changed();

  /// 특별 관심 친구 (@아이디) — My Page ★ 에 이 사람들 소식만. 기기에만
  final Set<String> specialFriends = {};

  /// 내 사진 (사진 벽 · 도감 칸 · 상품 상세). 지운 것도 서버에서 내릴 때까지 [MyPhoto.deleted] 로 남는다
  final List<MyPhoto> _photos = [];

  /// 내 취향 태그 (내 정보 머리) — 로그인하면 v3 preferences.tags 에도
  final List<String> profileTags = [];

  void setSpecialFriend(String handle, bool on) {
    if (on ? specialFriends.add(handle) : specialFriends.remove(handle)) _changed();
  }

  /// 보이는 내 사진 — 새것부터
  List<MyPhoto> get photos => [
    for (final p in _photos)
      if (!p.deleted) p,
  ];

  /// 지운 것까지 (서버에서 내릴 것 찾기 — 사진 공유만 본다)
  List<MyPhoto> get allPhotos => List.unmodifiable(_photos);

  MyPhoto? photo(String id) => _photos.where((p) => p.id == id).firstOrNull;

  void addPhoto(MyPhoto p) {
    _photos.insert(0, p);
    _changed();
  }

  /// 같은 id 를 바꿔 끼운다 (친구에게 보이기 · 워터마크 · 상품 잇기 · 올림 표시)
  void updatePhoto(MyPhoto p) {
    final i = _photos.indexWhere((x) => x.id == p.id);
    if (i < 0) return;
    _photos[i] = p;
    _changed();
  }

  /// 지우기 — 서버에 올라가 있으면 내릴 때까지 '지움'으로 남긴다
  void removePhoto(String id) {
    final p = photo(id);
    if (p == null) return;
    if (p.uploadedTo.isEmpty) {
      _photos.remove(p);
      _changed();
    } else {
      updatePhoto(p.copyWith(deleted: true));
    }
  }

  /// 서버에서 내렸다 → 목록에서 뺀다
  void purgePhoto(String id) {
    final before = _photos.length;
    _photos.removeWhere((p) => p.id == id);
    if (_photos.length != before) _changed();
  }

  void setProfileTags(List<String> tags) {
    if (listEquals(tags, profileTags)) return;
    profileTags
      ..clear()
      ..addAll(tags);
    _changed();
  }
}
