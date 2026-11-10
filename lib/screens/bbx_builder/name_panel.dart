// T-4 이름 판 · 이름 적기 대화 상자 (화면 T 의 한 부분)
part of '../t_bbx_builder_screen.dart';

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
      decoration: InputDecoration(hintText: tr('이름')),
      onSubmitted: (v) => Navigator.pop(context, v.trim()),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('취소'))),
      FilledButton(onPressed: () => Navigator.pop(context, _ctrl.text.trim()), child: Text(tr('확인'))),
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
    final shown = boxName(combo, cat, lang: bbxNameLang);
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
            shown.isEmpty ? tr('부품을 골라 주세요') : shown,
            key: const Key('bbx-box-name'),
            style: TextStyle(fontSize: Gp.t19, fontWeight: FontWeight.w800, color: shown.isEmpty ? Gp.faint : Gp.ink),
          ),
          if (shown.isNotEmpty && others.isNotEmpty)
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
            if (missing.isNotEmpty)
              line(Icons.more_horiz, Gp.muted, trf('남은 칸: {slots}', {'slots': missing.join(' · ')})),
            if (legal) line(Icons.check_circle, Gp.own, tr('규칙에 맞는 조합이에요'), key: const Key('bbx-legal')),
            if (legal && short.isEmpty) line(Icons.bookmark, Gp.own, tr('내 부품으로 만들 수 있어요')),
            if (short.isNotEmpty)
              line(
                Icons.bookmark_border,
                Gp.muted,
                trf('없는 부품: {parts}', {'parts': short.map((m) => cat.molds[m.moldKey]!.name(bbxNameLang)).join(' · ')}),
              ),
          ],
        ],
      ),
    );
  }
}
