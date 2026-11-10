// T-8 저장 목록 · T-9 덱 (화면 T 의 한 부분)
part of '../t_bbx_builder_screen.dart';

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
    final box = boxName(combo, cat, lang: bbxNameLang);
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
              message: legal ? tr('규칙에 맞음') : tr('규칙에 안 맞음'),
              child: Icon(legal ? Icons.check_circle : Icons.block, size: Gp.iS, color: legal ? Gp.own : Gp.danger),
            ),
            if (buildable)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Tooltip(message: tr('내 부품으로 만들 수 있음'), child: const OwnedIcon()),
              ),
            IconButton(
              tooltip: tr('이름 바꾸기'),
              onPressed: onRename,
              icon: const Icon(Icons.edit_outlined, size: Gp.iM, color: Gp.muted),
            ),
            IconButton(
              tooltip: tr('지우기'),
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
      tip: tr('덱 만들기'),
      onTap: () => store.saveBbxDeck(
        Deck(id: bbxNewId('d'), name: trf('덱 {n}', {'n': store.bbxDecks.length + 1}), comboIds: const ['', '', '']),
      ),
    );
    if (store.bbxDecks.isEmpty) {
      return EmptyView(
        message: tr('덱이 없어요'),
        detail: tr('저장한 조합 3개로 3on3 덱을 짜요 · 같은 부품은 한 번만'),
        icon: Icons.layers_outlined,
        action: add,
      );
    }
    return ListView(
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 24),
      children: [
        SectionHeader(
          tr('덱'),
          subtitle: tr('조합 3개 · 같은 부품은 한 번만'),
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
                  deck.name.isEmpty ? tr('덱') : deck.name,
                  style: const TextStyle(fontSize: Gp.t16, fontWeight: FontWeight.w700),
                ),
              ),
              Icon(
                check.legal ? Icons.check_circle : Icons.block,
                size: Gp.iS,
                color: check.legal ? Gp.own : (check.lines.any((l) => l.$1) ? Gp.danger : Gp.faint),
              ),
              IconButton(
                tooltip: tr('이름 바꾸기'),
                onPressed: () async {
                  final name = await _askName(context, title: tr('덱 이름'), initial: deck.name);
                  if (name == null) return;
                  store.saveBbxDeck(
                    Deck(id: deck.id, name: name, rulesProfile: deck.rulesProfile, comboIds: deck.comboIds),
                  );
                },
                icon: const Icon(Icons.edit_outlined, size: Gp.iM, color: Gp.muted),
              ),
              IconButton(
                tooltip: tr('덱 지우기'),
                onPressed: () {
                  final combos = List.of(store.bbxCombos), decks = List.of(store.bbxDecks);
                  store.deleteBbxDeck(deck.id);
                  showToast(context, tr('덱을 지웠어요'), onUndo: () => store.restoreBbx(combos, decks));
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
              showToast(context, tr('먼저 조합을 저장해 주세요'));
              return;
            }
            final picked = await showPickSheet<String>(
              context,
              title: trf('{n}번 조합', {'n': i + 1}),
              values: ['', for (final x in store.bbxCombos) x.id],
              current: id,
              label: (v) => v.isEmpty ? tr('비우기') : bbxComboTitle(store.bbxCombo(v)!, cat),
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
                    c == null ? tr('조합 고르기') : bbxComboTitle(c, cat),
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
