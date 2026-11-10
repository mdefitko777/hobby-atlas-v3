// 진짜 백엔드 — Gunpula 의 Supabase 프로젝트 (옛 앱과 같은 계정 · 같은 데이터). RPC · 로그인 · 사진 Storage(photos 버킷).
// supabase_flutter 를 부르는 곳은 이 파일 하나뿐이다. 테스트는 이 파일을 쓰지 않는다 (가짜 RpcClient · AuthService).
//
// 주소 · anon key: config/supabase.json (앱 자산). 옛 앱 app/sync-config.js 와 같은 공개용 값이다 —
// 데이터는 RLS 와 authenticated 전용 RPC 가 지키고, 이 key 를 숨겨서 지키는 게 아니다.
// `--dart-define=SUPABASE_URL=… --dart-define=SUPABASE_ANON_KEY=…` 를 주면 그 값이 먼저다.
// 세션(refresh token)은 flutter_secure_storage 에만 둔다. 로그에 찍지 않는다 (debug: false).
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/l10n.dart';
import 'photo_share.dart';
import 'rpc.dart';

class BackendConfig {
  const BackendConfig(this.url, this.anonKey);
  final String url;
  final String anonKey;

  bool get valid => url.startsWith('https://') && anonKey.isNotEmpty;

  static const asset = 'config/supabase.json';

  static Future<BackendConfig> load() async {
    const url = String.fromEnvironment('SUPABASE_URL');
    const key = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (url.isNotEmpty && key.isNotEmpty) return const BackendConfig(url, key);
    try {
      final j = jsonDecode(await rootBundle.loadString(asset));
      if (j is Map) return BackendConfig('${j['url'] ?? ''}'.replaceAll(RegExp(r'/+$'), ''), '${j['anon_key'] ?? ''}');
    } on Object {
      // 자산이 없거나 깨짐 → 계정 없이 쓴다
    }
    return const BackendConfig('', '');
  }
}

/// Supabase 세션을 안드로이드 키스토어로 암호화해 보관
class _SecureSessionStorage extends LocalStorage {
  const _SecureSessionStorage();

  static const _key = 'hobbyatlas.supabase.session.v1';
  static const _storage = FlutterSecureStorage();

  @override
  Future<void> initialize() async {}

  Future<String?> _read() async {
    try {
      return await _storage.read(key: _key);
    } on Object {
      return null;
    }
  }

  @override
  Future<bool> hasAccessToken() async => (await _read()) != null;

  @override
  Future<String?> accessToken() => _read();

  @override
  Future<void> removePersistedSession() async {
    try {
      await _storage.delete(key: _key);
    } on Object {
      // 지울 게 없음
    }
  }

  @override
  Future<void> persistSession(String persistSessionString) => _storage.write(key: _key, value: persistSessionString);
}

/// 로그인 상태 + 초기화. [start] 를 한 번 부른다 (main.dart).
class SupabaseAuthService extends ChangeNotifier implements AuthService {
  SupabaseClient? _client;
  StreamSubscription<AuthState>? _sub;
  bool _ready = false;
  bool _available = false;
  final _readyCompleter = Completer<void>();

  /// 초기화가 끝날 때 (설정이 없어도 끝난다)
  Future<void> get whenReady => _readyCompleter.future;

  SupabaseClient? get client => _client;

  Future<void> start() async {
    if (_ready || _client != null) return;
    final cfg = await BackendConfig.load();
    if (cfg.valid) {
      try {
        await Supabase.initialize(
          url: cfg.url,
          publishableKey: cfg.anonKey,
          debug: false, // 세션 · 토큰이 로그에 남지 않게
          authOptions: const FlutterAuthClientOptions(
            authFlowType: AuthFlowType.implicit, // 메일의 6자리 코드를 직접 넣는다 (옛 앱 /otp → /verify 와 같음)
            detectSessionInUri: false,
            localStorage: _SecureSessionStorage(),
          ),
        );
        _client = Supabase.instance.client;
        _sub = _client!.auth.onAuthStateChange.listen((_) => notifyListeners(), onError: (Object _) {});
        _available = true;
      } on Object {
        _available = false;
      }
    }
    _ready = true;
    if (!_readyCompleter.isCompleted) _readyCompleter.complete();
    notifyListeners();
  }

  @override
  bool get available => _available;

  @override
  bool get ready => _ready;

  @override
  bool get signedIn => _client?.auth.currentSession != null;

  @override
  String get email => _client?.auth.currentUser?.email ?? '';

  @override
  String get userId => _client?.auth.currentSession?.user.id ?? '';

  GoTrueClient get _auth {
    final c = _client;
    if (c == null) throw AuthFailure(tr('계정 연결 설정이 없어요 (config/supabase.json)'));
    return c.auth;
  }

  @override
  Future<void> sendCode(String email) => _guard(() => _auth.signInWithOtp(email: email.trim(), shouldCreateUser: true));

  @override
  Future<void> verifyCode(String email, String code) => _guard(() async {
    await _auth.verifyOTP(type: OtpType.email, email: email.trim(), token: code.trim());
    notifyListeners();
  });

  @override
  Future<void> signOut() async {
    try {
      await _client?.auth.signOut(scope: SignOutScope.local);
    } on Object {
      // 오프라인이어도 기기에서는 로그아웃
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

Future<void> _guard(Future<void> Function() f) async {
  try {
    await f();
  } on AuthException catch (e) {
    throw AuthFailure(authMessage(e.code, e.message, e.statusCode));
  } on http.ClientException {
    throw AuthFailure(tr('인터넷에 연결되지 않았어요'));
  } on TimeoutException {
    throw AuthFailure(tr('인터넷에 연결되지 않았어요'));
  }
}

/// GoTrue 오류 → 한국어 (자주 나는 것만)
@visibleForTesting
String authMessage(String? code, String message, String? status) {
  final m = message.toLowerCase();
  if (code == 'otp_expired' || m.contains('expired') || (m.contains('invalid') && m.contains('token'))) {
    return tr('코드가 틀렸거나 시간이 지났어요. 새 코드를 받아 주세요');
  }
  if (code == 'over_request_rate_limit' || m.contains('only request this after')) {
    final s = RegExp(r'after (\d+) second').firstMatch(m)?.group(1);
    return s == null ? tr('조금 뒤에 다시 보낼 수 있어요') : trf('{n}초 뒤에 다시 보낼 수 있어요', {'n': s});
  }
  if (code == 'over_email_send_rate_limit' || m.contains('rate limit')) {
    return tr('메일을 너무 자주 보냈어요. 한 시간쯤 뒤에 다시 해 주세요 (Supabase 기본 메일은 시간당 몇 통만 보내요)');
  }
  if (code == 'email_address_not_authorized' || m.contains('not authorized') || m.contains('error sending')) {
    return tr(
      '메일을 보내지 못했어요. Supabase 기본 메일은 프로젝트 팀원 주소로만 가요 — Supabase › Authentication › SMTP 에 메일 서비스를 연결해야 다른 사람도 받을 수 있어요',
    );
  }
  if (code == 'email_address_invalid' || code == 'validation_failed') return tr('메일 주소를 확인해 주세요');
  if (code == 'signup_disabled' || m.contains('signups not allowed')) return tr('이 프로젝트는 새 계정 만들기가 꺼져 있어요');
  if (status == null) return tr('인터넷에 연결되지 않았어요');
  return message;
}

/// RPC — `POST /rest/v1/rpc/<fn>` 를 로그인한 사람의 토큰으로
class SupabaseRpc implements RpcClient {
  SupabaseRpc(this._auth);
  final SupabaseAuthService _auth;

  @override
  Future<Object?> call(String fn, [Map<String, Object?> params = const {}]) async {
    await _auth.whenReady;
    final client = _auth.client;
    if (client == null) throw RpcException('42501', tr('계정 연결 설정이 없어요'));
    if (client.auth.currentSession == null) throw RpcException('42501', tr('로그인이 필요해요'));
    try {
      final Object? r = await client.rpc<Object?>(fn, params: params).timeout(const Duration(seconds: 25));
      return r;
    } on PostgrestException catch (e) {
      throw RpcException(e.code ?? '', e.message);
    } on AuthException catch (e) {
      // 토큰 새로 받기 실패: 네트워크면 오프라인, 아니면 로그인 풀림
      if (e is AuthRetryableFetchException || e.statusCode == null) throw OfflineException(tr('인터넷에 연결되지 않았어요'));
      throw RpcException('42501', e.message);
    } on http.ClientException {
      throw OfflineException(tr('인터넷에 연결되지 않았어요'));
    } on TimeoutException {
      throw OfflineException(tr('서버가 답하지 않아요'));
    }
  }
}

/// 사진 Storage — `photos` 버킷 (docs/supabase-v3-photos.sql). 경로 `<user_id>/<photo_id>.jpg`, 쓰기는 내 폴더만 · 읽기는 나 + 친구.
class SupabasePhotoStorage implements PhotoStorage {
  SupabasePhotoStorage(this._auth);
  final SupabaseAuthService _auth;

  static const bucket = 'photos';

  Future<StorageFileApi> _api() async {
    await _auth.whenReady;
    final client = _auth.client;
    if (client == null || client.auth.currentSession == null) throw OfflineException(tr('로그인이 필요해요'));
    return client.storage.from(bucket);
  }

  Future<T> _guardStorage<T>(Future<T> Function(StorageFileApi api) f) async {
    try {
      return await f(await _api()).timeout(const Duration(seconds: 40));
    } on StorageException catch (e) {
      throw PhotoStorageException(e.message, status: e.statusCode ?? '');
    } on http.ClientException {
      throw OfflineException(tr('인터넷에 연결되지 않았어요'));
    } on TimeoutException {
      throw OfflineException(tr('서버가 답하지 않아요'));
    }
  }

  @override
  Future<void> upload(String path, Uint8List bytes) => _guardStorage(
    (api) => api.uploadBinary(path, bytes, fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true)),
  );

  @override
  Future<void> remove(List<String> paths) => _guardStorage((api) => api.remove(paths));

  @override
  Future<Uint8List> download(String path) => _guardStorage((api) => api.download(path));
}
