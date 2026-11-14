// 작품 · 세대 칸의 짧은 이름 (순수 Dart) — 칸마다 같은 머리("기동전사 건담" · "포켓몬스터")가 먼저 보이지 않게.
// 보이는 곳(칸 · 제목)에서만 부르고, 찾기 · 알림 조건 · 데이터는 원래 이름 그대로.
// category_browse.dart 와 따로 둔 까닭: 그 파일의 한국어 글은 모두 칸 이름이라 번역 표 검사(browse_l10n_test)가 읽는데,
// 여기 머리 글은 화면에 나오는 이름이 아니다
import 'category_browse.dart' show worldSectionOf;

/// 건담 작품 이름의 반복되는 머리 — 거의 모든 칸이 "기동전사 건담 …" 이라 칸마다 같은 말이 먼저 보였다 (2026-11-14 주인 요청)
const _workPrefixes = ['기동전사 건담', '机动战士高达', '機動戦士ガンダム'];

/// 뒤에 건담이 붙는 작품의 "기동전사" (기동전사 Z건담 → Z건담)
const _workPrefixesShort = ['기동전사', '机动战士', '機動戦士'];
final _gundamWord = RegExp(r'건담|高达|ガンダム|gundam', caseSensitive: false);

/// 작품 칸 · 제목에 보일 이름 — "기동전사 건담 SEED" → "SEED", "기동전사 Z건담" → "Z건담".
/// 첫 작품 "기동전사 건담" 은 남는 것이 없어 그대로 둔다 ("퍼스트" 같은 새 말을 만들지 않고, 칸에는 공식 로고도 있다).
/// 찾기 · 알림 조건 · 데이터는 원래 이름 그대로 (GuideWork.name)
String shortWorkName(String name) {
  final s = name.replaceAll(RegExp(r'\s+'), ' ').trim();
  for (final p in _workPrefixes) {
    if (!s.startsWith(p)) continue;
    final rest = s.substring(p.length).trim();
    return rest.isEmpty ? s : rest;
  }
  for (final p in _workPrefixesShort) {
    if (!s.startsWith(p)) continue;
    final rest = s.substring(p.length).trim();
    if (_gundamWord.hasMatch(rest)) return rest;
  }
  return s;
}

/// 포켓몬 본편 세대 이름의 머리 (atlas-groups labels — 중국어 gen7 만 精灵宝可梦)
const _pokemonPrefixes = ['포켓몬스터', '精灵宝可梦', '宝可梦', 'ポケットモンスター'];

/// 세대 칸 · 제목에 보일 이름 — 포켓몬 본편 세대(gen1 …)는 "포켓몬스터 레드·그린" → "레드·그린".
/// 공통 굿즈 묶음(여러 세대 포켓몬 굿즈 …)과 다른 채널은 그대로. [worldId] = World.id ('pokemon-gen1')
String shortWorldLabel(String channel, String worldId, String label) {
  if (channel != 'pokemon' || worldSectionOf(channel, worldId) != '본편 세대') return label;
  final s = label.replaceAll(RegExp(r'\s+'), ' ').trim();
  for (final p in _pokemonPrefixes) {
    if (!s.startsWith(p)) continue;
    final rest = s.substring(p.length).trim();
    return rest.isEmpty ? s : rest;
  }
  return s;
}
