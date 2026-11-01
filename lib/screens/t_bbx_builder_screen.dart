// 화면 T: 베이 조합 만들기 — 도감 › 베이블레이드 X 의 🔧 에서 연다.
// 블레이드(CX 는 락 칩 · 메인 · 어시스트) → 래칫 → 비트를 고르면 규칙 엔진(lib/bbx/, solarisken core.js 이식)이
// 맞는 조합인지 · 상자 이름 · 능력치 · 무게를 바로 보여 준다. 저장한 조합 3개로 3on3 덱을 짜면 겹치는 부품을 짚어 준다.
// 저장 = 기기에만 (UserStore.bbxCombos · bbxDecks → user.json local_state.bbx_combos · bbx_decks).
//
// ┌──────── 디자인 가이드 대응표: T 베이 조합 만들기 ──────────────────────────────────┐
// │ 번호 │ Flutter 위젯명                     │ 비즈니스 명칭(한글)                    │ 원칙(P번호)   │
// │ T-1  │ AppBar + ToolIcon(책갈피)           │ 가진 부품만 보기 (고르기 시트에도 같은 값) │ P07 · P04     │
// │ T-2  │ UnderlineTab 3개                    │ 만들기 · 저장 n · 덱 n                  │ P06           │
// │ T-3  │ SquareSegments                     │ BX·UX / CX / CX 확장 (구성 바꾸기)      │ P04 · P08     │
// │ T-4  │ 이름 판 + 규칙 줄                    │ 상자 이름(한 · 일 · 영) · 맞음 ✓ / 안 맞는 이유 │ P01 · P09 │
// │ T-5  │ 칸 줄(사진 · 이름 · 무게) → 아래 시트 │ 부품 칸 → 부품 고르기 (사진 · 종류 · 보유 책갈피) │ P07 · P01 │
// │ T-5a │ 시트의 GpSearchBar + ToolIcon        │ 부품 찾기 · 가진 것만                   │ P07           │
// │ T-5b │ 시트 줄의 ⊘                         │ 지금 조합과 안 맞는 부품 (미리 알림)      │ P05           │
// │ T-6  │ AccentBar 5줄 + 무게 · 회전          │ 공격 · 방어 · 지구력 · 대시 · 버스트 저항 합 │ P01       │
// │ T-7  │ GradientButton → 이름 대화 상자      │ 조합 저장 (고친 조합은 그 자리에 다시)    │ P03           │
// │ T-8  │ 저장 목록 줄 + ✎ · 🗑 → 토스트       │ 조합 불러오기 · 이름 바꾸기 · 지우기(되돌리기) │ P03 · P05 │
// │ T-9  │ 덱 판: 세그먼트 + 3칸 + 규칙 줄       │ 3on3 덱 (TT · WBO · 자유) · 겹치는 부품 빨간 테두리 │ P05 · P09 │
// │ T-10 │ LoadingView / ErrorView / EmptyView │ 부품 받는 중 · 오류 · 저장 · 덱 없음      │ P09           │
// │ T-11 │ AppBar 오른쪽 ? (HelpButton)       │ 부품 · 규칙 · 저장 · 덱 아이콘 뜻 한 줄씩  │ P10           │
// └──────────────────────────────────────────────────────────────────────────────────┘
// 전환: 도감(G-6) → 이 화면(쌓기) → 부품 고르기(아래에서 덮기). 저장 줄 → 만들기 탭(옆으로). 덱 칸 → 조합 고르기(덮기).
// 나눈 곳 (part): bbx_builder/name_panel · part_picker · stats_panel · saved_decks
library;

import 'package:flutter/material.dart';

import '../api.dart';
import '../bbx/bbx.dart';
import '../data/bbx_builder_data.dart';
import '../data/user_store.dart';
import '../logic/bbx_builder.dart';
import '../marks.dart';
import '../theme.dart';
import '../widgets.dart';

part 'bbx_builder/name_panel.dart';
part 'bbx_builder/part_picker.dart';
part 'bbx_builder/saved_decks.dart';
part 'bbx_builder/stats_panel.dart';

// ── 화면 ─────────────────────────────────────────────────────────────────────

class BbxBuilderScreen extends StatefulWidget {
  const BbxBuilderScreen({super.key, this.loaders = const Loaders()});
  final Loaders loaders;

  @override
  State<BbxBuilderScreen> createState() => _BbxBuilderScreenState();
}

class _BbxBuilderScreenState extends State<BbxBuilderScreen> {
  late Future<BbxBuilderData> _future = widget.loaders.bbxBuilder(); // STATE: GET /bbxBuilder
  int _tab = 0;

  /// T-1 가진 부품만
  bool _ownedOnly = false;

  // 만들기 — 구성을 바꿔도 고른 부품은 칸마다 남겨 둔다 (다시 돌아오면 그대로)
  BbxFrame _frame = BbxFrame.bx;
  final Map<Slot, String> _parts = {};

  /// 저장 목록에서 불러온 조합 (저장하면 그 자리에서 고친다)
  String? _editingId;

  UserStore get _store => Marks.read(context).store;

  @override
  Widget build(BuildContext context) {
    final store = Marks.of(context).store; // 저장 · 덱이 바뀌면 다시 그린다
    return Scaffold(
      appBar: AppBar(
        title: const Text('베이 조합'),
        actions: [
          ToolIcon(
            // T-1 P07
            icon: _ownedOnly ? Icons.bookmark : Icons.bookmark_border,
            tip: '가진 부품만',
            on: _ownedOnly,
            color: _ownedOnly ? Gp.own : null,
            onTap: () => setState(() => _ownedOnly = !_ownedOnly),
          ),
          const HelpButton(title: '베이 조합', items: bbxBuilderHelp), // T-11
          const SizedBox(width: 6),
        ],
      ),
      body: FutureBuilder<BbxBuilderData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingView(label: '베이 부품 불러오는 중…');
          if (snap.hasError) {
            return ErrorView(
              message: '${snap.error}',
              onRetry: () => setState(() => _future = widget.loaders.bbxBuilder()),
            );
          }
          final data = snap.data!;
          final inv = data.inventory(store);
          return Column(
            children: [
              SizedBox(
                // T-2 P06
                height: 40,
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    for (final (i, (label, count)) in [
                      ('만들기', null),
                      ('저장', store.bbxCombos.length),
                      ('덱', store.bbxDecks.length),
                    ].indexed)
                      UnderlineTab(
                        label: label,
                        count: count,
                        selected: _tab == i,
                        onTap: () => setState(() => _tab = i),
                      ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: switch (_tab) {
                  1 => _savedTab(data, inv, store),
                  2 => _DeckTab(data: data, inventory: inv, store: store),
                  _ => _buildTab(data, inv),
                },
              ),
            ],
          );
        },
      ),
    );
  }

  // ── 만들기 ──
  Combo _draft(BbxCatalog cat) => bbxComboFor(_editingId ?? 'draft', _frame, _parts, cat);

  Widget _buildTab(BbxBuilderData data, BbxInventory inv) {
    final cat = data.catalog;
    final combo = _draft(cat);
    final stats = comboStats(combo, cat);
    final bitMold = cat.moldOf(_parts[Slot.bit] ?? '');
    final integratedBit = combo.arch.slots.contains(Slot.bit) && (bitMold?.integratedBit ?? false);
    final editing = _editingId == null ? null : _store.bbxCombo(_editingId!);
    return ListView(
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: SquareSegments<BbxFrame>(
                  // T-3 P04
                  values: BbxFrame.values,
                  current: _frame,
                  child: (f) => Text(f.label),
                  onPick: (f) => setState(() => _frame = f),
                ),
              ),
              ToolIcon(
                icon: Icons.restart_alt,
                tip: '새로 만들기',
                on: _parts.isNotEmpty || _editingId != null,
                onTap: () => setState(() {
                  _parts.clear();
                  _editingId = null;
                }),
              ),
            ],
          ),
        ),
        _NamePanel(combo: combo, catalog: cat, inventory: inv, editingName: editing?.nickname),
        SectionPanel(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              for (final slot in combo.arch.slots) ...[
                if (slot == Slot.ratchet && integratedBit && _parts[Slot.ratchet] == null)
                  const _FixedRow(label: '래칫', text: '비트에 붙어 있어요')
                else
                  _SlotRow(
                    // T-5 P07
                    key: Key('bbx-slot-${slot.json}'),
                    slot: slot,
                    partId: _parts[slot],
                    catalog: cat,
                    inventory: inv,
                    onTap: () => _pick(slot, data, inv),
                    onClear: () => setState(() => _parts.remove(slot)),
                  ),
                if (slot == Slot.blade && combo.arch == Arch.integrated)
                  const _FixedRow(label: '래칫', text: '블레이드에 붙어 있어요'),
              ],
            ],
          ),
        ),
        if (_parts.isNotEmpty) _StatsPanel(stats: stats, catalog: cat),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: GradientButton(
            // T-7 P03
            key: const Key('bbx-save'),
            label: editing != null ? '고쳐 저장' : '저장',
            onPressed: combo.parts.isEmpty ? null : () => _save(cat),
          ),
        ),
      ],
    );
  }

  Future<void> _pick(Slot slot, BbxBuilderData data, BbxInventory inv) async {
    final picked = await showGpSheet<PartMold>(
      context,
      tall: true,
      builder: (_) => _PartPickerSheet(
        slot: slot,
        catalog: data.catalog,
        inventory: inv,
        selectedMold: data.catalog.moldOf(_parts[slot] ?? '')?.key,
        ownedOnly: _ownedOnly,
        onOwnedOnly: (v) => setState(() => _ownedOnly = v),
        breaks: (m) {
          final cat = data.catalog;
          final now = bbxRuleErrors(_draft(cat), cat).length;
          final trial = bbxComboFor('trial', _frame, {..._parts, slot: m.key}, cat);
          return bbxRuleErrors(trial, cat).length > now;
        },
      ),
    );
    if (picked == null || !mounted) return;
    // 가진 색이 있으면 그 색(무게 · 사진이 내 것), 없으면 대표 색
    final id = picked.variantIds.where((v) => inv.variantCount(v) > 0).firstOrNull ?? picked.representativeId;
    setState(() => _parts[slot] = id);
  }

  Future<void> _save(BbxCatalog cat) async {
    final store = _store;
    final now = DateTime.now().toUtc();
    final editing = _editingId == null ? null : store.bbxCombo(_editingId!);
    if (editing != null) {
      final c = bbxComboFor(editing.id, _frame, _parts, cat);
      store.saveBbxCombo(editing.copyWith(arch: c.arch, parts: c.parts, updatedAt: now));
      showToast(context, '고쳐 저장했어요');
      return;
    }
    final name = await _askName(
      context,
      title: '조합 저장',
      initial: boxName(_draft(cat), cat, lang: 'ko'),
    );
    if (name == null || !mounted) return;
    final c = bbxComboFor(bbxNewId('c'), _frame, _parts, cat);
    store.saveBbxCombo(
      Combo(
        id: c.id,
        arch: c.arch,
        parts: c.parts,
        nickname: name.isEmpty ? null : name,
        createdAt: now,
        updatedAt: now,
      ),
    );
    setState(() => _editingId = c.id);
    showToast(context, '저장했어요');
  }

  void _load(Combo c) => setState(() {
    _frame = bbxFrameOf(c.arch);
    _parts
      ..clear()
      ..addAll(c.parts);
    _editingId = c.id;
    _tab = 0;
  });

  // ── 저장 ──
  Widget _savedTab(BbxBuilderData data, BbxInventory inv, UserStore store) {
    final cat = data.catalog;
    if (store.bbxCombos.isEmpty) {
      return const EmptyView(message: '저장한 조합이 없어요', detail: '만들기에서 부품을 고르고 저장해 보세요', icon: Icons.bookmark_border);
    }
    return ListView(
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 24),
      children: [
        for (final c in store.bbxCombos)
          _SavedRow(
            // T-8 P03 · P05
            key: Key('bbx-saved-${c.id}'),
            combo: c,
            catalog: cat,
            inventory: inv,
            current: c.id == _editingId,
            onTap: () => _load(c),
            onRename: () async {
              final name = await _askName(context, title: '이름 바꾸기', initial: bbxComboTitle(c, cat));
              if (name != null) store.renameBbxCombo(c.id, name);
            },
            onDelete: () {
              final combos = List.of(store.bbxCombos), decks = List.of(store.bbxDecks);
              store.deleteBbxCombo(c.id);
              if (_editingId == c.id) setState(() => _editingId = null);
              showToast(context, '‘${bbxComboTitle(c, cat)}’ 지웠어요', onUndo: () => store.restoreBbx(combos, decks));
            },
          ),
      ],
    );
  }
}

/// T-11 ? 도움말
const bbxBuilderHelp = <HelpItem>[
  HelpItem(Icons.bookmark_border, '가진 부품만 (고르기 시트도)'),
  HelpItem(Icons.restart_alt, '새로 만들기'),
  HelpItem(Icons.link, '붙어 있는 칸 (따로 못 고름)'),
  HelpItem(Icons.block, '지금 조합과 안 맞음', color: Gp.danger),
  HelpItem(Icons.check_circle, '규칙에 맞음', color: Gp.own),
  HelpItem(Icons.bookmark, '내 부품으로 만들 수 있음', color: Gp.own),
  HelpItem(Icons.edit_outlined, '이름 바꾸기'),
  HelpItem(Icons.delete_outline, '지우기 (되돌리기 있음)'),
  HelpItem(Icons.add, '덱 만들기 (3on3)'),
];
