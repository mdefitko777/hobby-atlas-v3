// 내 정보 — 이름 · 아이디 · 친구는 계정에서, 숫자는 기기 기록에서
part of '../derive.dart';

Future<Profile> deriveProfile() async {
  final a = Account.instance;
  final name = a.signedIn ? a.displayName : (_me.member == 'member' ? '나' : _me.member);
  return Profile(
    name: name,
    handle: a.handle,
    avatarText: name.characters.isEmpty ? '나' : name.characters.first,
    tags: List.of(_me.profileTags), // 내 정보 화면은 UserStore · 계정에서 바로 읽는다
    spendKrw: _me.spendKrw,
    workspace: a.sync.workspace?.name ?? '',
    inviteCode: '',
    members: const [],
    showcase: const [],
    friends: [
      for (final f in a.signedIn ? a.friends.friends : const <PublicProfile>[])
        friendMemberOf(f, a.friends.collections[f.handle]),
    ],
    suggested: const [],
  );
}

extension on String {
  // flutter 의 characters 패키지 없이 첫 글자 (한글 · 영문은 code unit 하나)
  List<String> get characters => runes.map(String.fromCharCode).toList();
}
