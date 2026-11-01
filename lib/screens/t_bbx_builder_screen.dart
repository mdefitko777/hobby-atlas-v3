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
// └──────────────────────────────────────────────────────────────────────────────────┘
// 전환: 도감(G-6) → 이 화면(쌓기) → 부품 고르기(아래에서 덮기). 저장 줄 → 만들기 탭(옆으로). 덱 칸 → 조합 고르기(덮기).
import 'package:flutter/material.dart';

import '../api.dart';
import '../bbx/bbx.dart';
import '../data/bbx_builder_data.dart';
import '../data/user_store.dart';
import '../marks.dart';
import '../theme.dart';
import '../logic/bbx_builder.dart';
import '../widgets.dart';

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
          const SizedBox(width: 8),
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
    final picked = await showModalBottomSheet<PartMold>(
      context: context,
      isScrollControlled: true,
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

/// 이름 적기 대화 상자 (저장 · 이름 바꾸기 · 덱 이름)
Future<String?> _askName(BuildContext context, {required String title, String initial = ''}) => showDialog<String>(
  context: context,
  builder: (_) => _NameDialog(title: title, initial: initial),
);

/// 글자칸 컨트롤러를 대화 상자가 닫히는 애니메이션이 끝난 뒤에 버리도록 State 가 가진다
class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title, required this.initial});
  final String title;
  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _ctrl = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      key: const Key('bbx-name-field'),
      controller: _ctrl,
      autofocus: true,
      maxLength: 40,
      decoration: const InputDecoration(hintText: '이름'),
      onSubmitted: (v) => Navigator.pop(context, v.trim()),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
      FilledButton(onPressed: () => Navigator.pop(context, _ctrl.text.trim()), child: const Text('확인')),
    ],
  );
}

// ── T-4 이름 판 ──────────────────────────────────────────────────────────────

class _NamePanel extends StatelessWidget {
  const _NamePanel({required this.combo, required this.catalog, required this.inventory, this.editingName});
  final Combo combo;
  final BbxCatalog catalog;
  final BbxInventory inventory;
  final String? editingName;

  @override
  Widget build(BuildContext context) {
    final cat = catalog;
    final ko = boxName(combo, cat, lang: 'ko');
    final others = joinDot([boxName(combo, cat), boxName(combo, cat, lang: 'en')]);
    final issues = comboIssues(combo, cat);
    final errors = [
      for (final i in issues)
        if (i.isError && i.code != IssueCode.missingSlot) i,
    ];
    final missing = [
      for (final i in issues)
        if (i.code == IssueCode.missingSlot && i.slot != null) bbxSlotLabel(i.slot!),
    ];
    final legal = errors.isEmpty && missing.isEmpty;
    final short = legal ? missingFor(combo, inventory) : const <MissingPart>[];
    Widget line(IconData icon, Color color, String text, {Key? key}) => Padding(
      key: key,
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: Gp.iS, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: Gp.t12, color: color, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
    return SectionPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (editingName != null && editingName!.isNotEmpty)
            Text(
              editingName!,
              style: const TextStyle(fontSize: Gp.t12, color: Gp.accent, fontWeight: FontWeight.w600),
            ),
          Text(
            ko.isEmpty ? '부품을 골라 주세요' : ko,
            key: const Key('bbx-box-name'),
            style: TextStyle(fontSize: Gp.t19, fontWeight: FontWeight.w800, color: ko.isEmpty ? Gp.faint : Gp.ink),
          ),
          if (ko.isNotEmpty && others.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                others,
                style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
              ),
            ),
          if (combo.parts.isNotEmpty) ...[
            for (final e in errors)
              line(Icons.block, Gp.danger, bbxIssueText(e, cat), key: Key('bbx-issue-${e.code.name}')),
            if (missing.isNotEmpty) line(Icons.more_horiz, Gp.muted, '남은 칸: ${missing.join(' · ')}'),
            if (legal) line(Icons.check_circle, Gp.own, '규칙에 맞는 조합이에요', key: const Key('bbx-legal')),
            if (legal && short.isEmpty) line(Icons.bookmark, Gp.own, '내 부품으로 만들 수 있어요'),
            if (short.isNotEmpty)
              line(
                Icons.bookmark_border,
                Gp.muted,
                '없는 부품: ${short.map((m) => cat.molds[m.moldKey]!.name('ko')).join(' · ')}',
              ),
          ],
        ],
      ),
    );
  }
}

// ── T-5 부품 칸 ──────────────────────────────────────────────────────────────

/// 부품 한 줄의 보조 글: 라인 · 회전 · 무게 · 색 수 · 능력치
String _moldInfo(PartMold m, PartVariant? v) => joinDot([
  m.line.toUpperCase(),
  bbxSpinLabel(v?.rotation ?? m.rotation),
  bbxGrams(v?.weightG ?? m.weightG),
  if (m.variantIds.length > 1) '${m.variantIds.length}색',
  [
    for (final k in BbxStats.keys)
      if ((v?.stats ?? m.stats)[k] > 0) '${bbxStatShort[k]}${(v?.stats ?? m.stats)[k]}',
  ].join(' '),
]);

class _SlotRow extends StatelessWidget {
  const _SlotRow({
    super.key,
    required this.slot,
    required this.partId,
    required this.catalog,
    required this.inventory,
    required this.onTap,
    required this.onClear,
  });
  final Slot slot;
  final String? partId;
  final BbxCatalog catalog;
  final BbxInventory inventory;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final v = partId == null ? null : catalog.variantFor(partId!);
    final m = partId == null ? null : catalog.moldOf(partId!);
    final owned = m != null && inventory.ownedCount(m.key) > 0;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: Gp.soft, borderRadius: BorderRadius.circular(Gp.rSmall)),
              clipBehavior: Clip.antiAlias,
              child: v == null
                  ? const Icon(Icons.add, color: Gp.faint, size: Gp.iM)
                  : AppImage(v.image, fit: BoxFit.contain, placeholder: m?.name('ko') ?? ''),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bbxSlotLabel(slot),
                    style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
                  ),
                  Text(
                    m?.name('ko') ?? '고르기',
                    style: TextStyle(fontWeight: FontWeight.w600, color: m == null ? Gp.faint : Gp.ink),
                  ),
                  if (m != null)
                    Text(
                      _moldInfo(m, v),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: Gp.t11, color: Gp.faint),
                    ),
                ],
              ),
            ),
            if (owned)
              const Tooltip(
                message: '보유',
                child: OwnedIcon(size: Gp.iM),
              ),
            if (m != null)
              IconButton(
                tooltip: '비우기',
                onPressed: onClear,
                icon: const Icon(Icons.close, size: Gp.iM, color: Gp.faint),
              )
            else
              const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(Icons.chevron_right, color: Gp.faint),
              ),
          ],
        ),
      ),
    );
  }
}

/// 고를 수 없는 칸 (래칫이 블레이드 · 비트에 붙어 있음)
class _FixedRow extends StatelessWidget {
  const _FixedRow({required this.label, required this.text});
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: Row(
      children: [
        const SizedBox(
          width: 52,
          child: Icon(Icons.link, color: Gp.faint, size: Gp.iM),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
              ),
              Text(text, style: const TextStyle(color: Gp.faint)),
            ],
          ),
        ),
      ],
    ),
  );
}

/// T-5 부품 고르기 시트
class _PartPickerSheet extends StatefulWidget {
  const _PartPickerSheet({
    required this.slot,
    required this.catalog,
    required this.inventory,
    required this.ownedOnly,
    required this.onOwnedOnly,
    required this.breaks,
    this.selectedMold,
  });
  final Slot slot;
  final BbxCatalog catalog;
  final BbxInventory inventory;
  final bool ownedOnly;
  final ValueChanged<bool> onOwnedOnly;

  /// 이 부품을 끼우면 지금보다 규칙 오류가 늘어나나
  final bool Function(PartMold) breaks;
  final String? selectedMold;

  @override
  State<_PartPickerSheet> createState() => _PartPickerSheetState();
}

class _PartPickerSheetState extends State<_PartPickerSheet> {
  late bool _ownedOnly = widget.ownedOnly;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final inv = widget.inventory;
    final q = nameKey(_query);
    final all = widget.catalog.moldsFor(widget.slot);
    final molds = [
      for (final m in all)
        if ((!_ownedOnly || inv.ownedCount(m.key) > 0) &&
            (q.isEmpty || m.names.values.any((n) => nameKey(n).contains(q)) || nameKey(m.code).contains(q)))
          m,
    ];
    final ownedN = all.where((m) => inv.ownedCount(m.key) > 0).length;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              bbxSlotLabel(widget.slot),
              subtitle: '${all.length}종 · 보유 $ownedN',
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
              trailing: ToolIcon(
                // T-5a P07
                icon: _ownedOnly ? Icons.bookmark : Icons.bookmark_border,
                tip: '가진 부품만',
                on: _ownedOnly,
                color: _ownedOnly ? Gp.own : null,
                onTap: () {
                  setState(() => _ownedOnly = !_ownedOnly);
                  widget.onOwnedOnly(_ownedOnly);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: GpSearchBar(hint: '이름 · 코드로 찾기', onChanged: (v) => setState(() => _query = v.trim())),
            ),
            Expanded(
              child: molds.isEmpty
                  ? EmptyView(
                      message: _ownedOnly ? '가진 ${bbxSlotLabel(widget.slot)}가 없어요' : '찾는 부품이 없어요',
                      detail: _ownedOnly ? '도감에서 가진 부품을 켜면 여기 보여요' : '',
                      icon: Icons.search_off,
                    )
                  : ListView.builder(
                      itemCount: molds.length,
                      itemBuilder: (context, i) => _PickRow(
                        mold: molds[i],
                        catalog: widget.catalog,
                        owned: inv.ownedCount(molds[i].key) > 0,
                        selected: molds[i].key == widget.selectedMold,
                        breaks: widget.breaks(molds[i]),
                        onTap: () => Navigator.pop(context, molds[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickRow extends StatelessWidget {
  const _PickRow({
    required this.mold,
    required this.catalog,
    required this.owned,
    required this.selected,
    required this.breaks,
    required this.onTap,
  });
  final PartMold mold;
  final BbxCatalog catalog;
  final bool owned;
  final bool selected;
  final bool breaks;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final v = catalog.variantFor(mold.key);
    return InkWell(
      key: Key('bbx-pick-${mold.key}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 52,
              child: AppImage(v?.image ?? '', fit: BoxFit.contain, grayscale: !owned, placeholder: mold.name('ko')),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mold.name('ko'),
                    style: TextStyle(fontWeight: FontWeight.w600, color: selected ? Gp.accent : Gp.ink),
                  ),
                  Text(
                    _moldInfo(mold, v),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
                  ),
                ],
              ),
            ),
            if (breaks)
              const Tooltip(
                // T-5b P05
                message: '지금 조합과 안 맞아요',
                child: Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(Icons.block, size: Gp.iS, color: Gp.danger),
                ),
              ),
            if (owned)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Tooltip(
                  message: '보유',
                  child: OwnedIcon(size: Gp.iM),
                ),
              ),
            if (selected)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.check, size: Gp.iM, color: Gp.accent),
              ),
          ],
        ),
      ),
    );
  }
}

// ── T-6 능력치 ────────────────────────────────────────────────────────────────

class _StatsPanel extends StatelessWidget {
  const _StatsPanel({required this.stats, required this.catalog});
  final ComboStats stats;
  final BbxCatalog catalog;

  @override
  Widget build(BuildContext context) {
    final max = catalog.comboStatMax;
    final w = stats.weightG;
    final weight = w != null
        ? '무게 ${bbxGrams(w)}'
        : stats.unknownWeightSlots.isNotEmpty
        ? '무게 ${bbxGrams(stats.knownWeightG)}+ (모르는 칸: ${stats.unknownWeightSlots.map(bbxSlotLabel).join(' · ')})'
        : '무게 ${bbxGrams(stats.knownWeightG)} (아직 덜 고름)';
    return SectionPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            joinDot([weight, bbxSpinLabel(stats.spin)]),
            key: const Key('bbx-weight'),
            style: const TextStyle(fontSize: Gp.t12, color: Gp.muted, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          for (final k in BbxStats.keys)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: Text(
                      bbxStatLabels[k]!,
                      style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
                    ),
                  ),
                  Expanded(child: AccentBar(value: max[k] == 0 ? 0 : stats.stats[k] / max[k], height: 6)),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${stats.stats[k]}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: Gp.t12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── T-8 저장 목록 ─────────────────────────────────────────────────────────────

class _SavedRow extends StatelessWidget {
  const _SavedRow({
    super.key,
    required this.combo,
    required this.catalog,
    required this.inventory,
    required this.current,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });
  final Combo combo;
  final BbxCatalog catalog;
  final BbxInventory inventory;
  final bool current;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cat = catalog;
    final title = bbxComboTitle(combo, cat);
    final box = boxName(combo, cat, lang: 'ko');
    final legal = isLegalBey(combo, cat);
    final buildable = legal && canBuild(combo, inventory);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
        child: Row(
          children: [
            SizedBox.square(dimension: 48, child: AppImage(bbxTopImage(combo, cat), fit: BoxFit.contain)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w600, color: current ? Gp.accent : Gp.ink),
                  ),
                  if (box.isNotEmpty && box != title)
                    Text(
                      box,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
                    ),
                ],
              ),
            ),
            Tooltip(
              message: legal ? '규칙에 맞음' : '규칙에 안 맞음',
              child: Icon(legal ? Icons.check_circle : Icons.block, size: Gp.iS, color: legal ? Gp.own : Gp.danger),
            ),
            if (buildable)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Tooltip(message: '내 부품으로 만들 수 있음', child: OwnedIcon()),
              ),
            IconButton(
              tooltip: '이름 바꾸기',
              onPressed: onRename,
              icon: const Icon(Icons.edit_outlined, size: Gp.iM, color: Gp.muted),
            ),
            IconButton(
              tooltip: '지우기',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, size: Gp.iM, color: Gp.muted),
            ),
          ],
        ),
      ),
    );
  }
}

// ── T-9 덱 ───────────────────────────────────────────────────────────────────

class _DeckTab extends StatelessWidget {
  const _DeckTab({required this.data, required this.inventory, required this.store});
  final BbxBuilderData data;
  final BbxInventory inventory;
  final UserStore store;

  @override
  Widget build(BuildContext context) {
    final add = ToolIcon(
      icon: Icons.add,
      tip: '덱 만들기',
      onTap: () => store.saveBbxDeck(
        Deck(id: bbxNewId('d'), name: '덱 ${store.bbxDecks.length + 1}', comboIds: const ['', '', '']),
      ),
    );
    if (store.bbxDecks.isEmpty) {
      return EmptyView(
        message: '덱이 없어요',
        detail: '저장한 조합 3개로 3on3 덱을 짜요 · 같은 부품은 한 번만',
        icon: Icons.layers_outlined,
        action: add,
      );
    }
    return ListView(
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 24),
      children: [
        SectionHeader(
          '덱',
          subtitle: '조합 3개 · 같은 부품은 한 번만',
          trailing: add,
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
        ),
        for (final d in store.bbxDecks)
          _DeckCard(key: Key('bbx-deck-${d.id}'), deck: d, data: data, inventory: inventory, store: store),
      ],
    );
  }
}

class _DeckCard extends StatelessWidget {
  const _DeckCard({super.key, required this.deck, required this.data, required this.inventory, required this.store});
  final Deck deck;
  final BbxBuilderData data;
  final BbxInventory inventory;
  final UserStore store;

  void _put(int i, String id) {
    final ids = [...deck.comboIds]..[i] = id;
    store.saveBbxDeck(Deck(id: deck.id, name: deck.name, rulesProfile: deck.rulesProfile, comboIds: ids));
  }

  @override
  Widget build(BuildContext context) {
    final cat = data.catalog;
    final check = DeckCheck.of(deck, store, cat, inventory);
    return SectionPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  deck.name.isEmpty ? '덱' : deck.name,
                  style: const TextStyle(fontSize: Gp.t16, fontWeight: FontWeight.w700),
                ),
              ),
              Icon(
                check.legal ? Icons.check_circle : Icons.block,
                size: Gp.iS,
                color: check.legal ? Gp.own : (check.lines.any((l) => l.$1) ? Gp.danger : Gp.faint),
              ),
              IconButton(
                tooltip: '이름 바꾸기',
                onPressed: () async {
                  final name = await _askName(context, title: '덱 이름', initial: deck.name);
                  if (name == null) return;
                  store.saveBbxDeck(
                    Deck(id: deck.id, name: name, rulesProfile: deck.rulesProfile, comboIds: deck.comboIds),
                  );
                },
                icon: const Icon(Icons.edit_outlined, size: Gp.iM, color: Gp.muted),
              ),
              IconButton(
                tooltip: '덱 지우기',
                onPressed: () {
                  final combos = List.of(store.bbxCombos), decks = List.of(store.bbxDecks);
                  store.deleteBbxDeck(deck.id);
                  showToast(context, '덱을 지웠어요', onUndo: () => store.restoreBbx(combos, decks));
                },
                icon: const Icon(Icons.delete_outline, size: Gp.iM, color: Gp.muted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SquareSegments<String>(
            values: const ['tt', 'wbo', 'free'],
            current: RulesProfile.byId(deck.rulesProfile).id,
            child: (p) => Text(bbxProfileLabel(p)),
            onPick: (p) =>
                store.saveBbxDeck(Deck(id: deck.id, name: deck.name, rulesProfile: p, comboIds: deck.comboIds)),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 6),
            child: Text(
              bbxProfileHint(RulesProfile.byId(deck.rulesProfile).id),
              style: const TextStyle(fontSize: Gp.t11, color: Gp.faint),
            ),
          ),
          for (var i = 0; i < 3; i++) _deckSlot(context, i, cat, check.conflictSlots.contains(i)),
          for (final (error, text) in check.lines)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    error ? Icons.block : Icons.check,
                    size: Gp.iS,
                    color: error ? Gp.danger : (check.legal ? Gp.own : Gp.faint),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      text,
                      style: TextStyle(fontSize: Gp.t12, color: error ? Gp.danger : Gp.muted),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _deckSlot(BuildContext context, int i, BbxCatalog cat, bool conflict) {
    final id = deck.comboIds[i];
    final c = id.isEmpty ? null : store.bbxCombo(id);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Material(
        color: Gp.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Gp.radius),
          side: BorderSide(color: conflict ? Gp.danger : Gp.line, width: conflict ? 1.5 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('bbx-deck-${deck.id}-$i'),
          onTap: () async {
            if (store.bbxCombos.isEmpty) {
              showToast(context, '먼저 조합을 저장해 주세요');
              return;
            }
            final picked = await showPickSheet<String>(
              context,
              title: '${i + 1}번 조합',
              values: ['', for (final x in store.bbxCombos) x.id],
              current: id,
              label: (v) => v.isEmpty ? '비우기' : bbxComboTitle(store.bbxCombo(v)!, cat),
            );
            if (picked != null) _put(i, picked);
          },
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    '${i + 1}',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w800, color: conflict ? Gp.danger : Gp.muted),
                  ),
                ),
                SizedBox.square(
                  dimension: 40,
                  child: c == null ? null : AppImage(bbxTopImage(c, cat), fit: BoxFit.contain),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    c == null ? '조합 고르기' : bbxComboTitle(c, cat),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w600, color: c == null ? Gp.faint : Gp.ink),
                  ),
                ),
                const Icon(Icons.chevron_right, color: Gp.faint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
