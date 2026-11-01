// 화면 P: 로그인 — 설정(K) · 내 정보(I) · 친구 서랍(M)에서 열림
//
// ┌──────── 디자인 가이드 대응표: P 로그인 ────────────────────────────────────────────┐
// │ 번호 │ Flutter 위젯명                     │ 비즈니스 명칭(한글)                    │ 원칙(P번호)   │
// │ P-1  │ TextField(메일) + FilledButton      │ 메일로 6자리 코드 받기                  │ P07           │
// │ P-2  │ TextField(숫자 6자리) + FilledButton │ 코드 넣고 로그인                        │ P07 · P05     │
// │ P-3  │ 안내 글 · 오류 글                    │ 옛 Gunpula 와 같은 계정 · 메일이 안 올 때  │ P09 · P10     │
// └──────────────────────────────────────────────────────────────────────────────────┘
// 전환: 쌓기(push). 로그인되면 닫히고, 동기화가 옛 앱 컬렉션을 받아 온다.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;

import '../detail_pane.dart';
import '../sync/account.dart';
import '../sync/rpc.dart';
import '../theme.dart';
import '../widgets.dart';

void openSignIn(BuildContext context) => openPage(context, const SignInScreen());

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _sent = false;
  bool _busy = false;
  String _error = '';

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  bool get _emailOk => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_email.text.trim());

  Future<void> _run(Future<void> Function() f) async {
    setState(() {
      _busy = true; // STATE: 보내는 중 → 버튼 잠김
      _error = '';
    });
    try {
      await f();
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on Object catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _send() {
    if (!_emailOk) {
      setState(() => _error = '메일 주소를 확인해 주세요');
      return;
    }
    _run(() async {
      await AccountScope.read(context).sendCode(_email.text);
      if (mounted) setState(() => _sent = true); // STATE: 코드 보냄 → 코드 칸
    });
  }

  void _verify() {
    if (_code.text.trim().length < 6) {
      setState(() => _error = '메일에 온 6자리 코드를 넣어 주세요');
      return;
    }
    _run(() async {
      final account = AccountScope.read(context);
      await account.verifyCode(_email.text, _code.text);
      if (!mounted) return;
      showToast(context, '로그인했어요 · 컬렉션을 받아 오는 중');
      Navigator.of(context).maybePop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final account = AccountScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('로그인')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          const Text(
            '옛 Gunpula 앱과 같은 메일이면 구매함 · 좋아요가 그대로 와요 · 두 앱이 15초쯤 안에 맞춰져요',
            style: TextStyle(color: Gp.muted, height: 1.45),
          ),
          const SizedBox(height: 18),
          if (!account.available && account.ready)
            const Text('계정 연결 설정이 없어요 (config/supabase.json)', style: TextStyle(color: Gp.danger)),
          TextField(
            // P-1
            controller: _email,
            enabled: !_sent && !_busy,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _send(),
            decoration: const InputDecoration(labelText: '메일', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          if (!_sent)
            FilledButton(
              onPressed: _busy ? null : _send,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
              child: Text(_busy ? '보내는 중…' : '코드 받기'),
            )
          else ...[
            TextField(
              // P-2
              controller: _code,
              enabled: !_busy,
              autofocus: true,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 10,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _verify(),
              decoration: const InputDecoration(labelText: '메일로 온 코드', border: OutlineInputBorder(), counterText: ''),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: _busy ? null : _verify,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
              child: Text(_busy ? '확인 중…' : '로그인'),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _sent = false; // STATE: 메일 다시 쓰기
                      _code.clear();
                    }),
              child: const Text('메일 바꾸기 · 코드 다시 받기'),
            ),
          ],
          if (_error.isNotEmpty)
            Padding(
              // P-3 P09
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error, style: const TextStyle(color: Gp.danger, height: 1.4)),
            ),
          const SizedBox(height: 24),
          const Text(
            '메일이 안 오면 스팸함 · 1분 뒤 다시 · 처음 쓰는 메일은 새 계정 (동생 · 친구는 각자 메일)',
            style: TextStyle(fontSize: Gp.t12, color: Gp.faint, height: 1.45),
          ),
        ],
      ),
    );
  }
}
