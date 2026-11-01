// 친구 시트 — 아이디로 친구 추가 · 받은/보낸 요청 · 내 아이디 · 이름 (Gunpula v3 친구)
//
// ┌──────── 디자인 가이드 대응표: Q 친구 시트 ─────────────────────────────────────────┐
// │ 번호 │ Flutter 위젯명                     │ 비즈니스 명칭(한글)                    │ 원칙(P번호)   │
// │ Q-1  │ 바텀 시트: 내 @아이디 + 복사          │ 내 아이디 알려 주기 (초대 코드 대신)     │ P07 · P08     │
// │ Q-2  │ TextField(@아이디) + 찾기 → 한 줄     │ 아이디로 친구 찾기 → 요청 · 수락 · 취소   │ P07 · P05     │
// │ Q-3  │ 바텀 시트: 받은 요청(수락·거절) · 보낸 요청(취소) │ 친구 요청                  │ P01 · P05     │
// │ Q-4  │ AlertDialog + TextField             │ 아이디 정하기 · 이름 바꾸기              │ P10           │
// └──────────────────────────────────────────────────────────────────────────────────┘
// 친구가 되면 서로의 구매함 · 좋아요를 읽기만 한다 (쓰기 · 집 사진은 안 보임 — 서버가 막음).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData, FilteringTextInputFormatter;

import '../sync/account.dart';
import '../sync/friends_service.dart';
import '../theme.dart';
import '../widgets.dart';
import 'p_sign_in_screen.dart';

/// 로그인이 필요하면 로그인 화면으로 보내고 false
bool ensureSignedIn(BuildContext context) {
  final a = AccountScope.read(context);
  if (a.signedIn) return true;
  openSignIn(context);
  return false;
}

/// Q-4 아이디 정하기 · 바꾸기 — 정했으면 true
Future<bool> askHandle(BuildContext context) async {
  final ok = await showDialog<bool>(context: context, builder: (_) => const _TextAskDialog(handle: true));
  if (ok == true && context.mounted) showToast(context, '아이디를 정했어요 · @${AccountScope.read(context).handle}');
  return ok == true;
}

/// Q-4 친구에게 보이는 이름 바꾸기
Future<void> askDisplayName(BuildContext context) async {
  final ok = await showDialog<bool>(context: context, builder: (_) => const _TextAskDialog(handle: false));
  if (ok == true && context.mounted) showToast(context, '이름을 바꿨어요');
}

/// 글자 하나 묻는 대화상자 (컨트롤러를 대화상자가 갖고 있어 닫히는 애니메이션 중에도 안전)
class _TextAskDialog extends StatefulWidget {
  const _TextAskDialog({required this.handle});

  /// true = 아이디, false = 이름
  final bool handle;

  @override
  State<_TextAskDialog> createState() => _TextAskDialogState();
}

class _TextAskDialogState extends State<_TextAskDialog> {
  late final Account _account = AccountScope.read(context);
  late final TextEditingController _c = TextEditingController(
    text: widget.handle ? _account.handle : (_account.displayName == '나' ? '' : _account.displayName),
  );
  String _error = '';
  bool _busy = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true; // STATE: 저장 중 → 버튼 잠김
      _error = '';
    });
    try {
      if (widget.handle) {
        await _account.friends.claimHandle(_c.text);
      } else {
        await _account.friends.setDisplayName(_c.text);
      }
      if (mounted) Navigator.pop(context, true);
    } on FriendsFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.handle;
    return AlertDialog(
      title: Text(h ? (_account.handle.isEmpty ? '내 아이디 정하기' : '아이디 바꾸기') : '이름 바꾸기'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            h ? '친구가 이 아이디로 나를 찾아요. 영문 소문자 · 숫자 · _ 3–20자.' : '친구 목록에 보이는 이름이에요.',
            style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _c,
            autofocus: true,
            enabled: !_busy,
            maxLength: h ? 21 : 40,
            inputFormatters: h ? [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_@]'))] : null,
            decoration: InputDecoration(
              prefixText: h ? '@' : null,
              counterText: '',
              errorText: _error.isEmpty ? null : _error,
              errorMaxLines: 3,
            ),
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: const Text('취소')),
        FilledButton(onPressed: _busy ? null : _save, child: Text(h ? '정하기' : '저장')),
      ],
    );
  }
}

/// Q-1 · Q-2 아이디로 친구 추가
Future<void> showAddFriend(BuildContext context) async {
  if (!ensureSignedIn(context)) return;
  await showGpSheet<void>(context, keyboard: true, builder: (_) => const _AddFriendSheet());
}

class _AddFriendSheet extends StatefulWidget {
  const _AddFriendSheet();

  @override
  State<_AddFriendSheet> createState() => _AddFriendSheetState();
}

class _AddFriendSheetState extends State<_AddFriendSheet> {
  final _q = TextEditingController();
  bool _busy = false;
  String _error = '';
  FriendSearch? _found;
  bool _searched = false;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _go(Future<void> Function() f) async {
    setState(() {
      _busy = true; // STATE: 찾는 중
      _error = '';
    });
    try {
      await f();
    } on FriendsFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _search() => _go(() async {
    final r = await AccountScope.read(context).friends.search(_q.text);
    if (mounted) {
      setState(() {
        _found = r; // STATE: 찾은 사람 한 줄
        _searched = true;
      });
    }
  });

  /// 요청 · 수락 · 취소 뒤 관계를 다시 본다
  void _act(Future<void> Function(FriendsService f) f, String done) => _go(() async {
    final friends = AccountScope.read(context).friends;
    await f(friends);
    final again = await friends.search(_found!.profile.handle);
    if (!mounted) return;
    setState(() => _found = again);
    showToast(context, done);
  });

  @override
  Widget build(BuildContext context) {
    final account = AccountScope.of(context);
    final mine = account.handle;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader('아이디로 친구 추가', padding: EdgeInsets.fromLTRB(0, 0, 0, 10)),
            Container(
              // Q-1
              padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
              decoration: BoxDecoration(color: Gp.bg, borderRadius: BorderRadius.circular(Gp.radius)),
              child: Row(
                children: [
                  const Text(
                    '내 아이디',
                    style: TextStyle(color: Gp.muted, fontSize: Gp.t12),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      mine.isEmpty ? '아직 없어요' : '@$mine',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (mine.isEmpty)
                    TextButton(onPressed: () => askHandle(context), child: const Text('정하기'))
                  else
                    IconButton(
                      tooltip: '아이디 복사', // P07
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: '@$mine'));
                        showToast(context, '아이디를 복사했어요 · 친구에게 보내 주세요');
                      },
                      icon: const Icon(Icons.content_copy_rounded, size: Gp.iM, color: Gp.muted),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              // Q-2
              children: [
                Expanded(
                  child: TextField(
                    controller: _q,
                    enabled: !_busy,
                    textInputAction: TextInputAction.search,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_@]'))],
                    onSubmitted: (_) => _search(),
                    decoration: const InputDecoration(
                      hintText: '친구 아이디',
                      prefixText: '@',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _busy ? null : _search, child: const Text('찾기')),
              ],
            ),
            if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_error, style: const TextStyle(color: Gp.danger)),
              ),
            if (_searched && _found == null && _error.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('그 아이디를 가진 사람이 없어요', style: TextStyle(color: Gp.muted)),
              ),
            if (_found case final f?) _result(f),
          ],
        ),
      ),
    );
  }

  Widget _result(FriendSearch f) {
    final p = f.profile;
    final Widget action = switch (f.relation) {
      'self' => const TagPill('나예요'),
      'friends' => const TagPill('이미 친구'),
      'outgoing' => OutlinedButton(
        onPressed: _busy ? null : () => _act((s) => s.remove(p.handle), '요청을 취소했어요'),
        child: const Text('요청 취소'),
      ),
      'incoming' => FilledButton(
        onPressed: _busy ? null : () => _act((s) => s.respond(p.handle, accept: true), '${p.name}님과 친구가 됐어요'),
        child: const Text('수락'),
      ),
      _ => FilledButton(
        onPressed: _busy ? null : () => _act((s) => s.request(p.handle), '${p.name}님에게 친구 요청을 보냈어요'),
        child: const Text('친구 요청'),
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleThumb(image: '', label: p.name, size: 42),
        title: Text(p.name),
        subtitle: Text(
          '@${p.handle}',
          style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
        ),
        trailing: action,
      ),
    );
  }
}

/// Q-3 받은 · 보낸 친구 요청
Future<void> showFriendRequests(BuildContext context) async {
  if (!ensureSignedIn(context)) return;
  AccountScope.read(context).friends.refresh().ignore(); // 열 때 한 번 새로
  await showGpSheet<void>(context, tall: true, builder: (_) => const _RequestsSheet());
}

class _RequestsSheet extends StatefulWidget {
  const _RequestsSheet();

  @override
  State<_RequestsSheet> createState() => _RequestsSheetState();
}

class _RequestsSheetState extends State<_RequestsSheet> {
  final Set<String> _busy = {};

  Future<void> _do(String handle, Future<void> Function(FriendsService f) f, String done) async {
    setState(() => _busy.add(handle)); // STATE: 그 줄 버튼 잠김
    try {
      await f(AccountScope.read(context).friends);
      if (mounted) showToast(context, done);
    } on FriendsFailure catch (e) {
      if (mounted) showToast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy.remove(handle));
    }
  }

  @override
  Widget build(BuildContext context) {
    final friends = AccountScope.of(context).friends;
    final incoming = friends.incoming;
    final outgoing = friends.outgoing;
    Widget person(PublicProfile p, List<Widget> actions) => ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: CircleThumb(image: '', label: p.name, size: 40),
      title: Text(p.name),
      subtitle: Text(
        '@${p.handle}',
        style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
      ),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: actions),
    );
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            const SectionHeader('받은 친구 요청', padding: EdgeInsets.fromLTRB(16, 0, 16, 4)),
            if (incoming.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  '받은 요청이 없어요',
                  style: TextStyle(color: Gp.muted, fontSize: Gp.t12),
                ),
              ),
            for (final p in incoming)
              person(p, [
                TextButton(
                  onPressed: _busy.contains(p.handle)
                      ? null
                      : () => _do(p.handle, (f) => f.respond(p.handle, accept: false), '요청을 거절했어요'),
                  child: const Text('거절'),
                ),
                FilledButton(
                  onPressed: _busy.contains(p.handle)
                      ? null
                      : () => _do(p.handle, (f) => f.respond(p.handle, accept: true), '${p.name}님과 친구가 됐어요'),
                  child: const Text('수락'),
                ),
              ]),
            const SectionHeader('보낸 요청', padding: EdgeInsets.fromLTRB(16, 18, 16, 4)),
            if (outgoing.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  '기다리는 요청이 없어요',
                  style: TextStyle(color: Gp.muted, fontSize: Gp.t12),
                ),
              ),
            for (final p in outgoing)
              person(p, [
                OutlinedButton(
                  onPressed: _busy.contains(p.handle)
                      ? null
                      : () => _do(p.handle, (f) => f.remove(p.handle), '요청을 취소했어요'),
                  child: const Text('취소'),
                ),
              ]),
          ],
        ),
      ),
    );
  }
}
