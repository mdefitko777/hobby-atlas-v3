// T-5 부품 칸 · 부품 고르기 시트 (화면 T 의 한 부분)
part of '../t_bbx_builder_screen.dart';

/// 부품 한 줄의 보조 글: 라인 · 회전 · 무게 · 색 수 · 능력치
String _moldInfo(PartMold m, PartVariant? v) => joinDot([
  m.line.toUpperCase(),
  bbxSpinLabel(v?.rotation ?? m.rotation),
  bbxGrams(v?.weightG ?? m.weightG),
  if (m.variantIds.length > 1) trf('{n}색', {'n': m.variantIds.length}),
  [
    for (final k in BbxStats.keys)
      if ((v?.stats ?? m.stats)[k] > 0) '${tr(bbxStatShort[k]!)}${(v?.stats ?? m.stats)[k]}',
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
                  : AppImage(v.image, fit: BoxFit.contain, placeholder: m?.name(bbxNameLang) ?? ''),
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
                    m?.name(bbxNameLang) ?? tr('고르기'),
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
              Tooltip(
                message: tr('보유'),
                child: const OwnedIcon(size: Gp.iM),
              ),
            if (m != null)
              IconButton(
                tooltip: tr('비우기'),
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
              subtitle: trf('{n}종 · 보유 {owned}', {'n': all.length, 'owned': ownedN}),
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
              trailing: ToolIcon(
                // T-5a P07
                icon: _ownedOnly ? Icons.bookmark : Icons.bookmark_border,
                tip: tr('가진 부품만'),
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
              child: GpSearchBar(hint: tr('이름 · 코드로 찾기'), onChanged: (v) => setState(() => _query = v.trim())),
            ),
            Expanded(
              child: molds.isEmpty
                  ? EmptyView(
                      message: _ownedOnly
                          ? trf('가진 {slot}가 없어요', {'slot': bbxSlotLabel(widget.slot)})
                          : tr('찾는 부품이 없어요'),
                      detail: _ownedOnly ? tr('도감에서 가진 부품을 켜면 여기 보여요') : '',
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
              child: AppImage(
                v?.image ?? '',
                fit: BoxFit.contain,
                grayscale: !owned,
                placeholder: mold.name(bbxNameLang),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mold.name(bbxNameLang),
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
              Tooltip(
                // T-5b P05
                message: tr('지금 조합과 안 맞아요'),
                child: const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(Icons.block, size: Gp.iS, color: Gp.danger),
                ),
              ),
            if (owned)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Tooltip(
                  message: tr('보유'),
                  child: const OwnedIcon(size: Gp.iM),
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
