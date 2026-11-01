// Supabase RPC 한 겹 — 동기화 · 친구 코드는 이 인터페이스만 본다.
// 진짜는 lib/sync/supabase_backend.dart (supabase_flutter), 테스트는 가짜(test/support/fake_backend.dart).
// 서버 함수는 Gunpula 저장소 docs/supabase-setup-v2.sql · v3.sql (모두 authenticated 에게만 열려 있음).
library;

import 'package:flutter/foundation.dart';

/// 서버 함수 호출 실패. [code] = Postgres SQLSTATE (예: '40001' 리비전 충돌, '42501' 권한 · 로그인 없음)
class RpcException implements Exception {
  const RpcException(this.code, this.message);
  final String code;
  final String message;

  /// v3 save_state 의 낙관적 잠금 충돌
  bool get isRevisionConflict => code == '40001';

  /// 로그인이 풀렸거나 권한 없음
  bool get isAuth => code == '42501' || code == 'PGRST301' || code == '401';

  /// 서버에 그 함수가 아직 없음 (SQL 을 안 돌린 프로젝트)
  bool get isMissingFunction => code == 'PGRST202' || code == '42883' || message.contains('does not exist');

  @override
  String toString() => code.isEmpty ? message : '$message ($code)';
}

/// 인터넷 · 서버에 닿지 못함 (다시 연결되면 다시 보낸다)
class OfflineException implements Exception {
  const OfflineException(this.message);
  final String message;

  @override
  String toString() => message;
}

abstract interface class RpcClient {
  /// `POST /rest/v1/rpc/<fn>` — 결과 JSON (jsonb null 이면 null)
  Future<Object?> call(String fn, [Map<String, Object?> params = const {}]);
}

/// 백엔드 설정이 없을 때 (테스트 · config 없음)
class NoBackendRpc implements RpcClient {
  const NoBackendRpc();

  @override
  Future<Object?> call(String fn, [Map<String, Object?> params = const {}]) =>
      Future.error(const RpcException('42501', '로그인이 필요해요'));
}

/// 로그인 (Supabase GoTrue 이메일 코드 OTP — 옛 앱 app/auth.js 와 같은 방식)
abstract interface class AuthService implements Listenable {
  /// 백엔드 설정(config/supabase.json)이 있는지
  bool get available;

  /// 저장된 세션을 다 읽었는지 (그 전에는 로그인 여부를 모른다)
  bool get ready;
  bool get signedIn;
  String get email;

  /// 메일로 6자리 코드 보내기 (처음 쓰는 메일이면 계정이 만들어진다)
  Future<void> sendCode(String email);

  /// 코드 확인 → 로그인
  Future<void> verifyCode(String email, String code);
  Future<void> signOut();
}

/// 설정이 없을 때 — 늘 로그아웃
class NoAuth extends ChangeNotifier implements AuthService {
  @override
  bool get available => false;
  @override
  bool get ready => true;
  @override
  bool get signedIn => false;
  @override
  String get email => '';
  @override
  Future<void> sendCode(String email) => Future.error(const AuthFailure('계정 연결 설정이 없어요 (config/supabase.json)'));
  @override
  Future<void> verifyCode(String email, String code) => sendCode(email);
  @override
  Future<void> signOut() async {}
}

/// 로그인 실패 — 화면에 그대로 보여 줄 문장
class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;

  @override
  String toString() => message;
}
