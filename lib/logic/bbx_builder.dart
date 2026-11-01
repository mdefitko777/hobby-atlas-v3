// 베이 조합 만들기의 규칙 · 글자 (화면 T 가 쓴다) — 규칙 엔진(lib/bbx/)의 결과를 한국어 한 줄로, 구성 · 조합 만들기, 덱 검사.
// 화면 없이 테스트할 수 있는 순수 Dart.
import '../bbx/bbx.dart';
import '../data/user_store.dart';

String bbxSlotLabel(Slot s) => switch (s) {
  Slot.blade => '블레이드',
  Slot.ratchet => '래칫',
  Slot.bit => '비트',
  Slot.lockChip => '락 칩',
  Slot.mainBlade => '메인 블레이드',
  Slot.assistBlade => '어시스트 블레이드',
  Slot.metalBlade => '메탈 블레이드',
  Slot.overBlade => '오버 블레이드',
};

const bbxStatLabels = {'attack': '공격', 'defense': '방어', 'stamina': '지구력', 'dash': '대시', 'burst': '버스트 저항'};
const bbxStatShort = {'attack': '공', 'defense': '방', 'stamina': '지', 'dash': '대', 'burst': '버'};

String bbxSpinLabel(String? r) => switch (r) {
  'right' => '오른쪽 회전',
  'left' => '왼쪽 회전',
  _ => '',
};

String bbxGrams(double? g) => g == null ? '' : '${g.toStringAsFixed(1)}g';

String bbxProfileLabel(String id) => switch (id) {
  'wbo' => 'WBO 3on3',
  'free' => '자유',
  _ => 'TT 3on3',
};

String bbxProfileHint(String id) => switch (id) {
  'wbo' => '같은 부품은 덱에 한 번만 (락 칩 포함)',
  'free' => '부품이 겹쳐도 돼요',
  _ => '같은 부품은 덱에 한 번만 · 플라스틱 락 칩은 겹쳐도 돼요',
};

/// 엔진의 이유(영어 · 코드) → 한국어 한 줄
String bbxIssueText(RuleIssue i, BbxCatalog cat) {
  final mold = i.moldKey == null ? null : cat.molds[i.moldKey!];
  final n = mold?.name('ko') ?? '';
  final s = i.slot == null ? '' : bbxSlotLabel(i.slot!);
  return switch (i.code) {
    IssueCode.unknownPart => '$s: 데이터에 없는 부품이에요',
    IssueCode.wrongSlot => '$n: ${mold == null ? '' : bbxSlotLabel(mold.slot)} 부품이라 $s 칸에 못 끼워요',
    IssueCode.notAPart => '$s: 실제 부품이 아닌 기록이에요',
    IssueCode.compositeMainBlade => '$n: 메탈 블레이드 + 오버 블레이드라 CX 확장으로 만들어요',
    IssueCode.extraSlot => '$s 칸이 없는 구성이에요',
    IssueCode.missingSlot => '$s 칸이 비었어요',
    IssueCode.integratedBladeNeedsIntegratedArch => '$n: 래칫이 붙은 블레이드라 래칫을 따로 끼울 수 없어요',
    IssueCode.notAnIntegratedBlade => '$n: 래칫이 따로 필요한 블레이드예요',
    IssueCode.integratedBitOnIntegratedBlade => '래칫이 붙은 블레이드에는 래칫이 붙은 비트($n)를 끼울 수 없어요',
    IssueCode.ratchetWithIntegratedBit => '$n: 래칫이 붙은 비트라 래칫을 빼야 해요',
    IssueCode.simpleOnlyNeedsSimpleRatchet => '이 블레이드는 단순 래칫(${simpleRatchetCodes.join(' · ')})만 맞아요 — $n 은 안 돼요',
    IssueCode.simpleOnlyWithIntegratedBit => '이 블레이드는 단순 래칫만 맞아요 — 래칫이 붙은 비트($n)는 안 돼요',
    IssueCode.deckSize => '덱은 조합 3개예요',
    IssueCode.unknownCombo => '지운 조합이 덱에 남아 있어요',
    IssueCode.beyIncomplete => '${_beyNo(i)}번 조합이 덜 만들어졌어요',
    IssueCode.beyIllegal => '${_beyNo(i)}번 조합이 규칙에 안 맞아요',
    IssueCode.notEnoughParts => '$n: 가진 개수로는 동시에 못 만들어요',
    IssueCode.repeatedMold => '$n — ${[for (final b in i.beys) '${b + 1}번'].join(' · ')} 조합에 겹쳐요',
  };
}

String _beyNo(RuleIssue i) => i.beys.isEmpty ? '' : '${i.beys.first + 1}';

/// 조합 이름 (내가 붙인 이름, 없으면 한국어 상자 이름)
String bbxComboTitle(Combo c, BbxCatalog cat) {
  final nick = c.nickname?.trim() ?? '';
  if (nick.isNotEmpty) return nick;
  final box = boxName(c, cat, lang: 'ko');
  return box.isEmpty ? '빈 조합' : box;
}

/// 맨 위 부품의 사진 (블레이드 · 메인 · 메탈)
String bbxTopImage(Combo c, BbxCatalog cat) {
  for (final s in const [Slot.blade, Slot.mainBlade, Slot.metalBlade, Slot.lockChip, Slot.bit]) {
    final v = c.parts[s] == null ? null : cat.variantFor(c.parts[s]!);
    if (v != null) return v.image;
  }
  return '';
}

/// 규칙 오류 (빈 칸은 빼고)
List<RuleIssue> bbxRuleErrors(Combo c, BbxCatalog cat) => [
  for (final i in comboIssues(c, cat))
    if (i.isError && i.code != IssueCode.missingSlot) i,
];

/// 구성 고르기: BX·UX 는 블레이드에 따라 기본 / 래칫 일체형이 정해진다
enum BbxFrame { bx, cx, cxExpand }

extension BbxFrameLabel on BbxFrame {
  String get label => switch (this) {
    BbxFrame.bx => 'BX · UX',
    BbxFrame.cx => 'CX',
    BbxFrame.cxExpand => 'CX 확장',
  };
}

BbxFrame bbxFrameOf(Arch a) => switch (a) {
  Arch.cx => BbxFrame.cx,
  Arch.cxExpand => BbxFrame.cxExpand,
  _ => BbxFrame.bx,
};

Arch bbxArchFor(BbxFrame f, Map<Slot, String> parts, BbxCatalog cat) => switch (f) {
  BbxFrame.cx => Arch.cx,
  BbxFrame.cxExpand => Arch.cxExpand,
  BbxFrame.bx => (cat.moldOf(parts[Slot.blade] ?? '')?.integratedBlade ?? false) ? Arch.integrated : Arch.standard,
};

Combo bbxComboFor(String id, BbxFrame f, Map<Slot, String> parts, BbxCatalog cat) {
  final arch = bbxArchFor(f, parts, cat);
  return Combo(
    id: id,
    arch: arch,
    parts: {
      for (final s in arch.slots)
        if (parts[s] != null) s: parts[s]!,
    },
  );
}

String bbxNewId(String prefix) => '$prefix${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

/// 덱 한 벌의 검사 결과 (칸 번호 0–2 기준)
class DeckCheck {
  DeckCheck._(this.lines, this.conflictSlots, this.legal);

  /// (오류인가, 한국어 한 줄)
  final List<(bool, String)> lines;

  /// 다른 칸과 부품이 겹치는 칸
  final Set<int> conflictSlots;

  /// 3칸이 다 차고 규칙에 맞음
  final bool legal;

  static DeckCheck of(Deck deck, UserStore store, BbxCatalog cat, BbxInventory inv) {
    final positions = <int>[];
    final beys = <Combo>[];
    final lines = <(bool, String)>[];
    for (final (i, id) in deck.comboIds.indexed) {
      if (id.isEmpty) continue;
      final c = store.bbxCombo(id);
      if (c == null) {
        lines.add((true, '${i + 1}번: 지운 조합이에요'));
        continue;
      }
      positions.add(i);
      beys.add(c);
    }
    final report = validateDeck(beys, cat, profile: RulesProfile.byId(deck.rulesProfile));
    final conflicts = <int>{};
    for (final (n, c) in beys.indexed) {
      final pos = positions[n] + 1;
      if (!isCompleteBey(c, cat)) {
        lines.add((true, '$pos번: 덜 만들어진 조합이에요'));
      } else if (bbxRuleErrors(c, cat).firstOrNull case final e?) {
        lines.add((true, '$pos번: ${bbxIssueText(e, cat)}'));
      }
    }
    for (final i in report.issues) {
      if (i.code != IssueCode.repeatedMold) continue; // 크기 · 칸마다 오류는 위에서 한국어로
      final slots = [for (final b in i.beys) positions[b]];
      conflicts.addAll(slots);
      lines.add((true, bbxIssueText(RuleIssue(i.code, i.message, slot: i.slot, moldKey: i.moldKey, beys: slots), cat)));
    }
    final full = beys.length == 3 && !lines.any((l) => l.$1);
    final legal = full && report.legal;
    if (beys.length < 3) lines.add((false, '조합 ${beys.length} / 3'));
    if (legal) {
      lines.add((false, '규칙에 맞는 덱이에요'));
      final short = shortfall(beys, inv);
      lines.add((
        false,
        short.isEmpty
            ? '내 부품으로 셋 다 만들 수 있어요'
            : '동시에 만들려면 모자라요: ${short.map((m) => '${cat.molds[m.moldKey]!.name('ko')} ${m.have}/${m.need}').join(' · ')}',
      ));
    }
    return DeckCheck._(lines, conflicts, legal);
  }
}
