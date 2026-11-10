// 상품 공유 링크 — 받은 사람이 누르면: Hobby Atlas 가 있으면 그 상품 상세로, 없으면 Gunpula 웹에서 그 상품
//   https://mdefitko777.github.io/Gunpula/app/open.html?kit=<kit_id>  (Gunpula 의 작은 넘김 페이지)
//   → 안드로이드: intent://kit/<kit_id>#Intent;scheme=hobbyatlas;package=com.mdefitko.hobbyatlas;… (앱이 없으면 웹 #kit=)
//   앱 안: hobbyatlas://kit/<kit_id> (AndroidManifest · MainActivity.kt → lib/share/share_intake.dart)

const kitLinkPage = 'https://mdefitko777.github.io/Gunpula/app/open.html';

/// 공유할 주소
String kitShareUrl(String kitId) => '$kitLinkPage?kit=${Uri.encodeQueryComponent(kitId)}';

/// 공유할 글: 이름 한 줄 + 주소 (메신저가 주소를 링크로 바꾼다)
String kitShareText({required String name, required String kitId}) => '$name\n${kitShareUrl(kitId)}';

final _idOk = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,159}$');
final _inText = RegExp(
  r'(?:https://mdefitko777\.github\.io/Gunpula/app/open\.html\?(?:[^\s#]*&)?kit=|hobbyatlas://kit/)([A-Za-z0-9._%-]+)',
);

/// 글 · 주소 안의 상품 링크 → kit_id (없거나 이상하면 null)
String? kitIdFromLink(String text) {
  final m = _inText.firstMatch(text);
  if (m == null) return null;
  final String id;
  try {
    id = Uri.decodeQueryComponent(m.group(1)!);
  } on ArgumentError {
    return null;
  }
  return _idOk.hasMatch(id) ? id : null;
}
