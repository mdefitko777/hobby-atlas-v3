// 화면 E-18 생김새로 찾기 — 사진 · 공유로 찾기(E-8) 안의 칸. 사진 속 물건과 생김새가 비슷한 상품을 기기 안에서 고른다.
// 처음 한 번 모델 · 표를 받고(약 105 MB), 그다음부터는 사진을 열면 바로 비교한다. 사진은 밖으로 나가지 않는다.
// 같은 기체 · 같은 포켓몬은 잘 찾지만 HG / RG / MG · 색 바꾼 판은 섞이므로 후보를 칸으로 보여 주고 고르게 한다.
// 글자(E-13)로도 걸린 상품은 앞으로. 채널 칩으로 한 채널 안에서만 (온 채널이 기본, lib/logic/visual_pick.dart),
// 표의 옛 kit_id 는 지금 id 로 풀어서 찾는다 (이름이 바뀐 베이가 1위인데 빠지던 일, 2026-11-14).
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../api.dart';
import '../channels.dart';
import '../logic/photo_crop.dart';
import '../logic/visual_pick.dart';
import '../ml/visual_search.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'd_kit_detail_screen.dart';

/// E-18 생김새가 비슷한 상품 (이 기기에서 못 하면 아무것도 그리지 않는다)
class VisualMatches extends StatefulWidget {
  const VisualMatches({
    super.key,
    required this.photo,
    required this.kits,
    required this.loaders,
    this.textIds = const {},
    this.crop = fullCrop,
    this.channel,
  });

  final Uint8List photo;

  /// 고른 틀 (E-19) — 바뀌면 다시 비교
  final CropBox crop;

  /// 사진 찾기를 연 채널 (null · 전체 = 칩 「전체」). 후보에 그 채널 상품이 없으면 전체로
  final String? channel;

  /// 모든 채널 상품 (id → 상품)
  final List<Kit> kits;
  final Loaders loaders;

  /// 글자 · 주소로 이미 걸린 상품 — 앞으로
  final Set<String> textIds;

  @override
  State<VisualMatches> createState() => _VisualMatchesState();
}

class _VisualMatchesState extends State<VisualMatches> {
  final _vs = VisualSearch.instance;

  /// 표의 모든 상품, 비슷한 순서 (칩을 바꿔도 다시 비교하지 않는다)
  List<VisualHit>? _hits;
  bool _running = false;
  String _error = '';

  /// 고른 채널 칩 (null = 전체) · 사람이 골랐나 (안 골랐으면 첫 결과에서 [VisualMatches.channel] 로)
  String? _pick;
  bool _picked = false;

  @override
  void initState() {
    super.initState();
    _vs.addListener(_changed);
    // 이미 받아 둔 것을 확인했으면 바로 비교 (확인은 앱을 켠 뒤 한 번 — 파일 확인을 기다리지 않는다)
    if (_vs.state == VisualState.ready) unawaited(_run());
    unawaited(_vs.check().then((_) => _changed()));
  }

  @override
  void didUpdateWidget(VisualMatches old) {
    super.didUpdateWidget(old);
    if (old.crop != widget.crop && _vs.state == VisualState.ready) {
      _hits = null; // 틀이 바뀜 → 다시 비교 (비교 중이면 끝난 뒤 _run 이 한 번 더)
      unawaited(_run());
    }
  }

  @override
  void dispose() {
    _vs.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {
      // STATE: 받기 · 진행 → 칸. 새 모델을 받는 중이면 옛 모델 후보는 버린다
      if (_vs.state != VisualState.ready) _hits = null;
    });
    if (_vs.state == VisualState.ready && _hits == null && !_running) unawaited(_run());
  }

  Future<void> _run() async {
    if (_running) return;
    _running = true;
    _error = '';
    final crop = widget.crop;
    try {
      final alias = await widget.loaders.kitAliases().catchError((Object _) => const <String, String>{});
      final hits = await _vs.search(widget.photo, crop: crop, alias: alias);
      if (mounted) setState(() => _hits = hits); // STATE: 비교 끝 → 후보 칸
    } on Object catch (e) {
      if (mounted) setState(() => _error = '$e'); // STATE: 비교 실패
    } finally {
      _running = false;
    }
    // 비교하는 동안 틀을 또 바꿨으면 새 틀로 한 번 더
    if (mounted && crop != widget.crop) {
      setState(() => _hits = null); // STATE: 새 틀 → 다시 비교
      unawaited(_run());
    }
  }

  Future<void> _remove() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('생김새 모델 지우기')),
        content: Text(tr('받아 둔 모델과 표(약 105 MB)를 지워요. 다시 쓰려면 또 받아야 해요.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('그대로'))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('지우기'))),
        ],
      ),
    );
    if (ok != true) return;
    await _vs.remove();
    if (mounted) setState(() => _hits = null); // STATE: 지움 → 받기 칸
  }

  String get _size => switch (_vs.downloadBytes) {
    final b? when b > 0 => trf('약 {mb} MB', {'mb': (b / 1e6).round()}),
    _ => trf('약 {mb} MB', {'mb': 105}),
  };

  String get _upgradeSize => trf('약 {mb} MB', {'mb': ((_vs.upgradeBytes ?? 0) / 1e6).round()});

  @override
  Widget build(BuildContext context) {
    final head = SectionHeader(
      tr('생김새가 비슷한 상품'),
      subtitle: _vs.state == VisualState.ready && _hits != null ? tr('고르세요') : '',
      padding: const EdgeInsets.fromLTRB(Gp.gutter, 18, 4, 8),
      trailing: _vs.state == VisualState.ready
          ? IconButton(
              key: const ValueKey('visual-remove'),
              tooltip: tr('생김새 모델 지우기'),
              visualDensity: VisualDensity.compact,
              onPressed: _remove,
              icon: const Icon(Icons.delete_outline, size: Gp.iM, color: Gp.faint),
            )
          : null,
    );
    final body = switch (_vs.state) {
      VisualState.unsupported => null,
      VisualState.absent => _Offer(
        key: const ValueKey('visual-install'),
        text: trf('사진 속 모양으로도 찾기 · 처음 한 번 모델 받기 ({size}, 와이파이 권장)', {'size': _size}),
        onTap: _vs.install,
      ),
      VisualState.downloading => _Progress(value: _vs.progress),
      VisualState.failed => _Note(
        icon: Icons.cloud_off,
        text: trf('모델을 받지 못했어요 · {error}', {'error': _vs.error}),
        action: TextButton(onPressed: _vs.install, child: Text(tr('다시'))),
      ),
      VisualState.ready when _error.isNotEmpty => _Note(
        icon: Icons.error_outline,
        text: tr('생김새를 비교하지 못했어요'),
        action: TextButton(onPressed: _run, child: Text(tr('다시'))),
      ),
      VisualState.ready when _hits == null => _Note(icon: null, text: tr('생김새 비교 중…')),
      VisualState.ready => _grid(context, _hits!),
    };
    if (body == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        head,
        if (_vs.state == VisualState.ready && _vs.upgradeBytes != null)
          Padding(
            // 새 모델: 받아 둔 모델은 받기가 끝날 때까지 그대로 쓴다
            padding: const EdgeInsets.only(bottom: 10),
            child: _Offer(
              key: const ValueKey('visual-upgrade'),
              text: trf('새 생김새 모델이 있어요 ({size}, 와이파이 권장)', {'size': _upgradeSize}),
              onTap: _vs.install,
            ),
          ),
        body,
      ],
    );
  }

  Widget _grid(BuildContext context, List<VisualHit> hits) {
    final byId = {for (final k in widget.kits) k.id: k};
    final ranked = [for (final h in hits) ?byId[h.kitId]];
    final channels = visualChannels(ranked.map((k) => k.franchiseId));
    if (!_picked) {
      final c = widget.channel;
      _pick = c != null && channels.contains(c) ? c : null;
    }
    final pick = channels.contains(_pick) ? _pick : null;
    final found = visualTop(ranked, pick, (k) => k.franchiseId);
    // 글자로도 걸린 상품을 앞으로 (순서는 그대로)
    final kits = [
      ...found.where((k) => widget.textIds.contains(k.id)),
      ...found.where((k) => !widget.textIds.contains(k.id)),
    ];
    if (kits.isEmpty) return _Note(icon: Icons.image_not_supported_outlined, text: tr('비슷한 상품을 못 찾았어요'));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (channels.length > 1)
          SizedBox(
            height: 44,
            child: ListView(
              // 채널 칩: 후보에 먼저 나온 채널부터
              key: const ValueKey('visual-channels'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(Gp.gutter, 0, Gp.gutter, 10),
              children: [
                for (final c in [null, ...channels])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _ChannelChip(
                      key: ValueKey('visual-channel-${c ?? 'all'}'),
                      label: c == null ? tr('전체') : tr(channelOf(c).label),
                      on: c == pick,
                      onTap: () => setState(() {
                        _pick = c; // STATE: 채널 칩 → 그 채널 후보
                        _picked = true;
                      }),
                    ),
                  ),
              ],
            ),
          ),
        _kitGrid(context, kits),
      ],
    );
  }

  Widget _kitGrid(BuildContext context, List<Kit> kits) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gp.gutter),
      child: GridView.builder(
        key: const ValueKey('visual-grid'),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 12,
          childAspectRatio: 0.74,
        ),
        itemCount: kits.length,
        itemBuilder: (context, i) => ProductTile(
          image: kits[i].image,
          title: kits[i].name,
          titleLines: 2,
          id: kits[i].id,
          marks: QuickMarks(kit: kits[i]),
          onTap: () => openKitDetail(context, kits[i], loaders: widget.loaders, list: kits),
        ),
      ),
    );
  }
}

/// 아직 안 받음 · 새 모델: 한 줄 설명 + 받기
class _Offer extends StatelessWidget {
  const _Offer({super.key, required this.text, required this.onTap});
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: Gp.gutter),
    padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
    decoration: BoxDecoration(color: Gp.soft, borderRadius: BorderRadius.circular(Gp.radius)),
    child: Row(
      children: [
        const Icon(Icons.image_search, size: Gp.iM, color: Gp.accent),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: Gp.t12, color: Gp.muted, height: 1.4),
          ),
        ),
        const SizedBox(width: 6),
        FilledButton.tonal(onPressed: onTap, child: Text(tr('받기'))),
      ],
    ),
  );
}

class _Progress extends StatelessWidget {
  const _Progress({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: Gp.gutter),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(value: value, minHeight: 4, color: Gp.accent, backgroundColor: Gp.soft),
        ),
        const SizedBox(height: 6),
        Text(
          trf('모델 받는 중… {p}%', {'p': (value * 100).round()}),
          style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
        ),
      ],
    ),
  );
}

/// 상태 한 줄 (아이콘 없으면 도는 표시)
class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text, this.action});
  final IconData? icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: Gp.gutter),
    child: Row(
      children: [
        if (icon == null)
          const MiniSpinner(size: Gp.iS, color: Gp.accent)
        else
          Icon(icon, size: Gp.iS, color: Gp.faint),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
          ),
        ),
        ?action,
      ],
    ),
  );
}

/// 채널 칩 하나 — 켜짐: 파랑 글자 + 옅은 파랑 바탕 (E-12 글자 조각과 같은 모양)
class _ChannelChip extends StatelessWidget {
  const _ChannelChip({super.key, required this.label, required this.on, required this.onTap});
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: on,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Gp.rSmall),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: on ? Gp.accent.withValues(alpha: 0.08) : Gp.panel,
          borderRadius: BorderRadius.circular(Gp.rSmall),
          border: Border.all(color: on ? Gp.accent.withValues(alpha: 0.3) : Gp.line),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: Gp.t12,
            fontWeight: on ? FontWeight.w700 : FontWeight.w500,
            color: on ? Gp.accent : Gp.muted,
          ),
        ),
      ),
    ),
  );
}
