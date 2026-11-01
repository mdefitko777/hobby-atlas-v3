// 진짜 백엔드 파일(supabase_backend.dart · main.dart)이 컴파일되는지 + 설정 자산 + 로그인 오류 문장.
// 네트워크는 쓰지 않는다 (Supabase.initialize 를 부르지 않음).
import 'package:flutter_test/flutter_test.dart';
import 'package:hobby_atlas/main.dart' show HobbyAtlasApp;
import 'package:hobby_atlas/sync/supabase_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('config/supabase.json: Gunpula 프로젝트 주소 + anon key (공개용 값)', () async {
    final c = await BackendConfig.load();
    expect(c.valid, isTrue);
    expect(c.url, startsWith('https://'));
    expect(c.url, endsWith('.supabase.co'));
    // anon 역할의 JWT 여야 한다 (service_role 같은 비밀 key 가 들어가면 안 됨)
    final payload = c.anonKey.split('.');
    expect(payload.length, 3);
    expect(String.fromCharCodes(_b64(payload[1])), contains('"role":"anon"'));
  });

  test('로그인 오류 → 한국어', () {
    expect(authMessage('otp_expired', 'Token has expired or is invalid', '403'), contains('코드가 틀렸거나'));
    expect(
      authMessage(
        'over_request_rate_limit',
        'For security purposes, you can only request this after 42 seconds.',
        '429',
      ),
      '42초 뒤에 다시 보낼 수 있어요',
    );
    expect(authMessage('over_email_send_rate_limit', 'Email rate limit exceeded', '429'), contains('너무 자주'));
    expect(authMessage('email_address_not_authorized', 'Email address not authorized', '400'), contains('SMTP'));
    expect(authMessage(null, 'Error sending magic link email', '500'), contains('SMTP'));
    expect(authMessage(null, 'Failed host lookup', null), '인터넷에 연결되지 않았어요');
  });

  test('앱이 컴파일된다', () => expect(const HobbyAtlasApp(), isNotNull));
}

List<int> _b64(String s) {
  var t = s.replaceAll('-', '+').replaceAll('_', '/');
  while (t.length % 4 != 0) {
    t += '=';
  }
  return Uri.parse('data:application/octet-stream;base64,$t').data!.contentAsBytes();
}
