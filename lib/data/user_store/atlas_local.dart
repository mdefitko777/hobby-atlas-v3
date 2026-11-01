// 도감 쪽 기기 기록 — 베이 부품 · 베이 연결 · 베이 조합 · 덱 · 도감 손으로 켜기 · 메자스타 · 프렌다 태그 (payload 에 넣지 않음)
part of '../user_store.dart';

mixin _AtlasLocal on ChangeNotifier {
  void _changed();
  String _now();

  // 옛 앱에서 기기에만 있던 값 (백업 · 클라우드에 없음)
  final Set<String> bbxOwnedParts = {};
  final Map<String, String> bbxManualMap = {};
  final Set<int> guideManualLit = {};

  /// 베이 조합 만들기(lib/screens/t_bbx_builder_screen.dart)에서 저장한 조합 — 최근 저장한 것부터. 기기에만
  final List<Combo> bbxCombos = [];

  /// 3on3 덱 — comboIds 는 늘 3칸, 빈 칸은 ''. 기기에만
  final List<Deck> bbxDecks = [];

  /// 가진 메자스타 태그 · 프렌다 픽 (Gunpula atlas 의 인쇄 id `mz-intl:1-1-001@KR` · 픽 id `frienda:1-1-001`). 기기에만
  final Set<String> tagOwned = {};

  void setBbxPart(String partId, bool have) {
    if (have ? bbxOwnedParts.add(partId) : bbxOwnedParts.remove(partId)) _changed();
  }

  /// 메자스타 태그 · 프렌다 픽 가짐 표시
  void setTagOwned(String id, bool have) {
    if (have ? tagOwned.add(id) : tagOwned.remove(id)) _changed();
  }

  void setManualLit(int unitId, bool lit) {
    if (lit ? guideManualLit.add(unitId) : guideManualLit.remove(unitId)) _changed();
  }

  // ── 베이 조합 · 덱 ──
  Combo? bbxCombo(String id) => bbxCombos.where((c) => c.id == id).firstOrNull;

  /// 같은 id 가 있으면 그 자리에서 바꾸고, 없으면 맨 앞에 넣는다
  void saveBbxCombo(Combo c) {
    final i = bbxCombos.indexWhere((x) => x.id == c.id);
    i < 0 ? bbxCombos.insert(0, c) : bbxCombos[i] = c;
    _changed();
  }

  void renameBbxCombo(String id, String name) {
    final i = bbxCombos.indexWhere((x) => x.id == id);
    if (i < 0) return;
    final n = name.trim();
    final old = bbxCombos[i];
    // copyWith 는 null 을 "그대로"로 읽어 이름 지우기를 못 한다 → 새로 만든다
    bbxCombos[i] = Combo.fromJson({...old.toJson(), 'nickname': n.isEmpty ? null : n, 'updated_at': _now()})!;
    _changed();
  }

  /// 조합을 지우면 그 조합을 넣은 덱 칸도 비운다
  void deleteBbxCombo(String id) {
    final before = bbxCombos.length;
    bbxCombos.removeWhere((c) => c.id == id);
    if (bbxCombos.length == before) return;
    for (final (i, d) in bbxDecks.indexed) {
      if (d.comboIds.contains(id)) bbxDecks[i] = _withIds(d, [for (final c in d.comboIds) c == id ? '' : c]);
    }
    _changed();
  }

  /// 같은 id 가 있으면 그 자리에서 바꾸고, 없으면 끝에 넣는다
  void saveBbxDeck(Deck d) {
    final i = bbxDecks.indexWhere((x) => x.id == d.id);
    i < 0 ? bbxDecks.add(_deck3(d)) : bbxDecks[i] = _deck3(d);
    _changed();
  }

  void deleteBbxDeck(String id) {
    final before = bbxDecks.length;
    bbxDecks.removeWhere((d) => d.id == id);
    if (bbxDecks.length != before) _changed();
  }

  /// 되돌리기: 지우기 전 목록 그대로
  void restoreBbx(List<Combo> combos, List<Deck> decks) {
    bbxCombos
      ..clear()
      ..addAll(combos);
    bbxDecks
      ..clear()
      ..addAll(decks);
    _changed();
  }
}

Deck _withIds(Deck d, List<String> ids) => Deck(id: d.id, name: d.name, rulesProfile: d.rulesProfile, comboIds: ids);

/// 덱 칸은 늘 3개 (모자라면 '' · 넘치면 자름)
Deck _deck3(Deck d) =>
    d.comboIds.length == 3 ? d : _withIds(d, [for (var i = 0; i < 3; i++) i < d.comboIds.length ? d.comboIds[i] : '']);

/// 저장 파일의 guide_manual_lit (숫자 · 숫자 글자) → gget unit_id
Iterable<int> _manualLitFrom(Object? raw) => jList(raw).map((v) => v is num ? v.toInt() : int.tryParse('$v')).nonNulls;
