// 계정 한 벌 — 로그인 · 동기화 · 친구를 앱 전체가 같이 본다 (MarksHost 와 같은 방식: 위쪽 InheritedNotifier).
// 화면은 AccountScope.of(context) 로 읽는다. 위에 AccountScope 가 없으면(테스트) 로그아웃 상태의 Account.instance.
library;

import 'package:flutter/widgets.dart';

import '../data/user_store.dart';
import 'friends_service.dart';
import 'photo_share.dart';
import 'profile_images.dart';
import 'rpc.dart';
import 'sync_service.dart';

class Account extends ChangeNotifier {
  Account({
    required this.auth,
    required RpcClient rpc,
    PhotoStorage storage = const NoPhotoStorage(),
    UserStore? store,
    Duration debounce = const Duration(milliseconds: 700),
    Duration pollEvery = const Duration(seconds: 15),
    DateTime Function()? clock,
  }) : _rpc = rpc,
       store = store ?? UserStore.instance {
    friends = FriendsService(() => _rpc);
    sync = SyncService(
      auth: auth,
      rpc: () => _rpc,
      store: this.store,
      friends: friends,
      debounce: debounce,
      pollEvery: pollEvery,
      clock: clock,
    );
    photos = PhotoShareService(rpc: () => _rpc, storage: storage, auth: auth, store: this.store);
    profileImages = ProfileImageService(
      storage: storage,
      auth: auth,
      store: this.store,
      friends: friends,
      photos: photos,
      clock: clock,
    );
    auth.addListener(notifyListeners);
    friends.addListener(notifyListeners);
    sync.addListener(notifyListeners);
    photos.addListener(notifyListeners);
    profileImages.addListener(notifyListeners);
    auth.addListener(_photosOnSignIn);
    friends.addListener(_onMe);
  }

  /// 로그인하면 못 올린 사진을 올린다 (로그아웃 동안 친구에게 보이기로 둔 것) · 못 보낸 공개 범위도
  void _photosOnSignIn() {
    if (!auth.signedIn) return;
    photos.sync().ignore();
    photos.pushPrivacy().ignore();
  }

  MeState? _lastMe;

  /// 내 프로필(get_me)을 새로 받을 때마다 아바타 · 배경을 맞춘다 (할 일이 없으면 서버를 부르지 않는다)
  void _onMe() {
    final me = friends.me;
    if (me == null || identical(me, _lastMe)) return;
    _lastMe = me;
    profileImages.sync().ignore();
  }

  /// 백엔드 없음 (테스트 · 설정 파일 없음) — 늘 로그아웃
  factory Account.offline() => Account(auth: NoAuth(), rpc: const NoBackendRpc());

  /// 앱 전체 하나 — main.dart 가 진짜 백엔드로 바꿔 끼운다
  static Account instance = Account.offline();

  final AuthService auth;
  final RpcClient _rpc;
  final UserStore store;
  late final FriendsService friends;
  late final SyncService sync;

  /// 사진 공유 (친구에게 보이기 → Storage) · 친구 사진 벽 · 공개 범위
  late final PhotoShareService photos;

  /// 아바타 · 배경 사진 (내 것 · 친구 것 기기 캐시)
  late final ProfileImageService profileImages;

  /// 로그인 · 기록 변경을 듣기 시작 (한 번)
  void start() => sync.start();

  bool get available => auth.available;
  bool get ready => auth.ready;
  bool get signedIn => auth.signedIn;
  String get email => auth.email;

  /// 친구가 찾는 아이디 (아직 없으면 '')
  String get handle => friends.me?.handle ?? '';

  /// 화면에 보일 내 이름: v3 이름 → 공유 공간 이름 → 아이디 → 메일 앞부분 → '나'
  String get displayName {
    final me = friends.me;
    for (final n in [
      me?.displayName ?? '',
      sync.workspace?.selfName ?? '',
      store.member == 'member' ? '' : store.member,
      me?.handle ?? '',
      email.contains('@') ? email.substring(0, email.indexOf('@')) : '',
    ]) {
      if (n.trim().isNotEmpty) return n.trim();
    }
    return '나';
  }

  /// 아바타 한 글자
  String get initial {
    final n = displayName;
    return n.isEmpty ? '나' : String.fromCharCode(n.runes.first).toUpperCase();
  }

  /// 받은 친구 요청 수 (🔔 배지)
  int get incomingCount => signedIn ? friends.incoming.length : 0;

  Future<void> sendCode(String email) => auth.sendCode(email);
  Future<void> verifyCode(String email, String code) => auth.verifyCode(email, code);

  /// 로그아웃 — 기기의 기록은 그대로 둔다 (옛 앱과 같음)
  Future<void> signOut() async {
    await auth.signOut();
    friends.clear();
    photos.clear();
  }

  @override
  void dispose() {
    auth.removeListener(notifyListeners);
    auth.removeListener(_photosOnSignIn);
    friends.removeListener(notifyListeners);
    sync.removeListener(notifyListeners);
    photos.removeListener(notifyListeners);
    friends.removeListener(_onMe);
    profileImages.removeListener(notifyListeners);
    profileImages.dispose();
    photos.dispose();
    sync.dispose();
    friends.dispose();
    super.dispose();
  }
}

/// 앱 맨 위 (main.dart 의 MaterialApp.builder)
class AccountScope extends InheritedNotifier<Account> {
  const AccountScope({super.key, required Account account, required super.child}) : super(notifier: account);

  /// 그리는 중에 — 바뀌면 다시 그려진다. 위에 없으면 Account.instance (다시 그려지지 않음)
  static Account of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AccountScope>()?.notifier ?? Account.instance;

  /// 누를 때(콜백)에
  static Account read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AccountScope>()?.notifier ?? Account.instance;
}
