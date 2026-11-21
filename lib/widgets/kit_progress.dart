// 예약 조각 — 상세 줄 · 편집 시트 · 도착 → 구매함 · 바코드 겹침 경고 (규칙은 lib/logic/)
// 기록은 UserStore local_state 'preorders' (수집 기록 items 와 따로 — lib/data/user_store/kit_progress.dart).
// 조립 상태(build_status) 칸 · 단추는 2026-11-20 주인 결정으로 뺐다 — 기록 · 동기화는 그대로 둔다
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;

import '../format.dart';
import '../l10n/l10n.dart';
import '../logic/collection_rules.dart' show ScanDupKind, scanDuplicate;
import '../logic/preorder.dart';
import '../marks.dart';
import '../models.dart';
import '../theme.dart';
import 'buttons.dart';
import 'feedback.dart';
import 'help.dart';
import 'icons.dart';
import 'sections.dart';
import 'sheets.dart';

// ── 예약 ──
/// ? 도움말 줄 — 예약 · 도착 · 재판매 (컬렉션 · 상세가 같이 쓴다). 조립 상태는 화면에서 뺐다 (2026-11-20, 기록은 남김)
List<HelpItem> kitProgressHelp({bool restock = false}) => [
  HelpItem(preorderIcon, tr('예약'), color: Gp.reserve),
  HelpItem(arrivedIcon, tr('도착했어요 → 구매함으로'), color: Gp.reserve),
  if (restock) HelpItem(restockIcon, tr('재판매 소식'), color: Gp.resale),
];

/// 예약 한 줄 요약: "프리미엄 반다이 · 8,800원 · 2026.12 도착 · 미결제"
String preorderSummary(Preorder p) => joinDot([
  p.shop,
  if (p.price != null) won(p.price!),
  if (p.arrival.isNotEmpty) trf('{date} 도착', {'date': arrivalLabel(p.arrival)}),
  if (p.arrivedAt.isNotEmpty) tr('도착했어요') else (p.paid ? tr('결제 완료') : tr('미결제')),
]);

/// D-5g 상세 줄 (구매함이 아닐 때): 적어 둔 예약 요약. 오른쪽 📥 = 도착했어요.
/// 예약이 없으면 줄 대신 상세의 작은 버튼 줄에 「예약 적기」(ChipButton)가 있다 — 여기서는 아무것도 그리지 않는다
class PreorderRow extends StatelessWidget {
  const PreorderRow({super.key, required this.kit});
  final Kit kit;

  @override
  Widget build(BuildContext context) {
    final p = Marks.of(context).store.preorderOf(kit.id);
    if (p == null) return const SizedBox.shrink();
    return InkWell(
      key: const ValueKey('preorder-row'),
      onTap: () => showPreorderSheet(context, kit),
      borderRadius: BorderRadius.circular(Gp.radius),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        constraints: const BoxConstraints(minHeight: 44),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Gp.radius),
          border: Border.all(color: Gp.reserve.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Icon(preorderIcon, size: Gp.iS, color: Gp.reserve),
            const SizedBox(width: 8),
            Text(
              tr('예약'),
              style: TextStyle(fontSize: Gp.t12, color: Gp.muted),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                preorderSummary(p),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: Gp.t14, fontWeight: FontWeight.w600, color: Gp.ink),
              ),
            ),
            if (p.active)
              IconButton(
                key: const ValueKey('preorder-arrived'),
                tooltip: tr('도착했어요'),
                onPressed: () => markPreorderArrived(context, kit),
                icon: Icon(arrivedIcon, size: Gp.iM, color: Gp.reserve),
              )
            else
              Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.edit_outlined, size: Gp.iS, color: Gp.accent),
              ),
          ],
        ),
      ),
    );
  }
}

int? _won(String t) {
  final v = int.tryParse(t.replaceAll(RegExp(r'[^0-9]'), ''));
  return v == null || v <= 0 ? null : v;
}

/// D-5g 예약 적기 · 고치기 (바텀 시트) — 가게 · 총액 · 예약금 · 결제 상태 · 도착 예정. 좋아요가 아니면 좋아요도 켠다
Future<void> showPreorderSheet(BuildContext context, Kit kit) => showGpSheet<void>(
  context,
  keyboard: true,
  builder: (_) => _PreorderSheet(kit: kit, host: context),
);

/// 예약 시트 — 글자 칸은 이 State 가 가진다 (시트가 닫히는 동안에도 살아 있게)
class _PreorderSheet extends StatefulWidget {
  const _PreorderSheet({required this.kit, required this.host});
  final Kit kit;

  /// 토스트를 띄울 화면 (시트는 닫힌 뒤)
  final BuildContext host;

  @override
  State<_PreorderSheet> createState() => _PreorderSheetState();
}

class _PreorderSheetState extends State<_PreorderSheet> {
  late final Marks _marks = Marks.read(context);
  late final Preorder? _old = _marks.store.preorderOf(widget.kit.id);
  late final _shop = TextEditingController(text: _old?.shop ?? '');
  late final _price = TextEditingController(text: _old?.price?.toString() ?? '');
  late final _deposit = TextEditingController(text: _old?.deposit?.toString() ?? '');
  late final _arrival = TextEditingController(text: _old?.arrival ?? '');
  late bool _paid = _old?.paid ?? false;

  @override
  void dispose() {
    for (final c in [_shop, _price, _deposit, _arrival]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _field(String key, TextEditingController c, String hint, {bool number = false, String suffix = ''}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextField(
      key: ValueKey('pre-$key'),
      controller: c,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      inputFormatters: number ? [FilteringTextInputFormatter.digitsOnly] : null,
      decoration: InputDecoration(hintText: hint, suffixText: suffix.isEmpty ? null : suffix),
    ),
  );

  void _delete() {
    final store = _marks.store;
    final kit = widget.kit;
    final old = _old;
    Navigator.pop(context);
    store.putPreorder(kit.id, null); // STATE: 예약 지움 (deleted 로 남김)
    if (widget.host.mounted) {
      showToast(widget.host, tr('예약을 지웠어요'), onUndo: () => store.putPreorder(kit.id, old));
    }
  }

  void _save() {
    final a = normalizeArrival(_arrival.text);
    if (_arrival.text.trim().isNotEmpty && a.isEmpty) {
      showToast(widget.host, tr('도착 예정은 2026-12 또는 2026-12-15처럼 적어요'));
      return;
    }
    final next = Preorder(
      shop: _shop.text.trim(),
      price: _won(_price.text),
      deposit: _won(_deposit.text),
      paid: _paid,
      arrival: a,
      arrivedAt: _old?.arrivedAt ?? '',
    );
    final kit = widget.kit;
    Navigator.pop(context);
    if (!_marks.liked(kit) && !_marks.owned(kit)) _marks.set(kit, liked: true); // 예약 = 좋아요 + 예약 기록
    _marks.store.putPreorder(kit.id, next); // STATE: 예약 (기기 local_state)
    if (widget.host.mounted) {
      showToast(widget.host, _old == null ? trf('「{name}」 예약을 적었어요', {'name': kit.name}) : tr('예약을 고쳤어요'));
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            tr('예약'),
            subtitle: widget.kit.name,
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
            trailing: _old == null
                ? null
                : IconButton(
                    tooltip: tr('예약 지우기'),
                    onPressed: _delete,
                    icon: Icon(Icons.delete_outline, size: Gp.iM, color: Gp.danger),
                  ),
          ),
          _field('shop', _shop, tr('가게 (예: 프리미엄 반다이)')),
          Row(
            children: [
              Expanded(child: _field('price', _price, tr('총액'), number: true, suffix: tr('원'))),
              const SizedBox(width: 8),
              Expanded(child: _field('deposit', _deposit, tr('예약금'), number: true, suffix: tr('원'))),
            ],
          ),
          _field('arrival', _arrival, tr('도착 예정 (2026-12 · 2026-12-15)')),
          SquareSegments<bool>(
            values: const [false, true],
            current: _paid,
            onPick: (v) => setState(() => _paid = v), // STATE: 결제 상태 (시트 안)
            child: (v) => Text(v ? tr('결제 완료') : tr('미결제')),
          ),
          const SizedBox(height: 14),
          GradientButton(label: tr('저장'), onPressed: _save),
        ],
      ),
    ),
  );
}

/// 예약한 상품이 왔다 → 구매함으로 옮길지 묻는다 (옮기면 예약 총액이 내 구매가)
Future<void> markPreorderArrived(BuildContext context, Kit kit) async {
  final store = Marks.read(context).store;
  final p = store.preorderOf(kit.id);
  if (p == null) return;
  final toOwned = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(tr('도착했어요')),
      content: Text(
        p.price == null ? tr('구매함으로 옮길까요?') : '${tr('구매함으로 옮길까요?')}\n${trf('내 구매가 {price}', {'price': won(p.price!)})}',
        style: const TextStyle(fontSize: Gp.t14),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(tr('도착만'))),
        FilledButton(
          key: const ValueKey('arrived-to-owned'),
          onPressed: () => Navigator.pop(dialog, true),
          child: Text(tr('구매함으로')),
        ),
      ],
    ),
  );
  if (toOwned == null || !context.mounted) return;
  final before = store.preorderArrived(kit.id, toOwned: toOwned); // STATE: 예약 → 도착 (· 구매함)
  if (before == null) return;
  showToast(
    context,
    toOwned ? trf('「{name}」 구매함에 넣었어요', {'name': kit.name}) : tr('도착했다고 적었어요'),
    onUndo: () => store.undoArrival(kit.id, before),
  );
}

// ── 바코드 겹침 경고 (E-6b) ──
/// 바코드로 찾은 상품이 이미 내 컬렉션에 있으면 상세를 열기 전에 시트로 알린다.
/// true = 상세 열기, false = 닫음(다시 찍기). 겹치는 것이 없으면 바로 true
Future<bool> warnIfCollected(BuildContext context, List<Kit> kits) async {
  final marks = Marks.read(context);
  final d = scanDuplicate(kits, marks.store, marks.statusOf);
  if (d == null) return true;
  final (Widget icon, String head, String detail) = switch (d.kind) {
    ScanDupKind.owned => (OwnedIcon(size: Gp.iL), trf('이미 구매함에 있어요 ×{n}', {'n': d.quantity}), ''),
    ScanDupKind.preorder => (
      Icon(preorderIcon, size: Gp.iL, color: Gp.reserve),
      tr('이미 예약했어요'),
      preorderSummary(d.preorder!),
    ),
    ScanDupKind.liked => (LikedIcon(size: Gp.iL), tr('좋아요한 상품이에요'), ''),
  };
  final open = await showGpSheet<bool>(
    context,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          key: const ValueKey('scan-dup'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                icon,
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    head,
                    style: const TextStyle(fontSize: Gp.t16, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              d.kit.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: Gp.t14),
            ),
            if (detail.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                detail,
                style: TextStyle(fontSize: Gp.t12, color: Gp.muted),
              ),
            ],
            const SizedBox(height: 14),
            GradientButton(label: tr('상세 보기'), onPressed: () => Navigator.pop(sheet, true)),
            TextButton.icon(
              onPressed: () => Navigator.pop(sheet, false),
              icon: const Icon(Icons.qr_code_scanner, size: Gp.iM),
              label: Text(tr('다시 찍기')),
            ),
          ],
        ),
      ),
    ),
  );
  return open ?? false;
}
