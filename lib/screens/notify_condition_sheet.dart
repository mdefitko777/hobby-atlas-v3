// 알림 조건 만들기 시트 — 채널 → 작품(캐릭터 · 세대) → 종류, 둘째 · 셋째는 '전부' 가 기본.
//   작품: 건담 = 상품의 series key (SEED · 00 …), 그 밖 = 도감 묶음(atlas: 마도카 캐릭터 · Fate 작품 · 포켓몬 세대)
//   종류: 그 채널 상품의 라인 이름 (HG · 넨도로이드 …), 상품이 많은 것부터
import 'package:flutter/material.dart';

import '../channels.dart';
import '../data/catalog.dart';
import '../data/derive.dart' show atlasGroupLabel, deriveWorlds;
import '../l10n/l10n.dart';
import '../logic/category_browse.dart' show isBeyLineWorld;
import '../models.dart' show Kit;
import '../notifications/notify_models.dart';
import '../theme.dart';
import '../widgets.dart';

/// 조건 하나를 골라 돌려준다 (닫으면 null). [channel] 을 주면 그 채널로 정해 두고 채널 줄은 숨긴다 (알림 › 채널 시트)
Future<NotifyCondition?> pickNotifyCondition(BuildContext context, {String? channel}) => showGpSheet<NotifyCondition>(
  context,
  heightFactor: gpSheetHeight,
  builder: (_) => _ConditionSheet(channel: channel),
);

class _ConditionSheet extends StatefulWidget {
  const _ConditionSheet({this.channel});
  final String? channel;

  @override
  State<_ConditionSheet> createState() => _ConditionSheetState();
}

class _ConditionSheetState extends State<_ConditionSheet> {
  String? _channel;

  /// (scope, 이름) — 빈 scope = 전부
  List<(String, String)> _scopes = const [];
  List<String> _lines = const [];
  (String, String) _scope = ('', '');
  String _line = '';

  @override
  void initState() {
    super.initState();
    if (widget.channel case final id?) {
      _select(id);
      _loadScopes(id);
    }
  }

  void _select(String id) {
    _channel = id;
    _scope = ('', '');
    _line = '';
    _scopes = const [];
    _lines = _linesOf(id);
  }

  Future<void> _loadScopes(String id) async {
    final scopes = await _scopesOf(id);
    if (mounted && _channel == id) setState(() => _scopes = scopes);
  }

  void _pickChannel(String id) {
    setState(() => _select(id));
    _loadScopes(id);
  }

  static List<String> _linesOf(String channel) {
    final count = <String, int>{};
    for (final k in Catalog.instance.kits) {
      if (k.franchiseId == channel && k.line.isNotEmpty) count[k.line] = (count[k.line] ?? 0) + 1;
    }
    return (count.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).map((e) => e.key).toList();
  }

  static Future<List<(String, String)>> _scopesOf(String channel) async {
    if (channel == 'gundam') {
      final count = <String, int>{};
      final label = <String, String>{};
      for (final k in Catalog.instance.kits) {
        if (k.franchiseId != 'gundam' || k.seriesKey.isEmpty || k.seriesKey == 'other') continue;
        count[k.seriesKey] = (count[k.seriesKey] ?? 0) + 1;
        label[k.seriesKey] = k.series; // 조건에는 한국어 이름 (보일 때 scopeShown)
      }
      final keys = count.keys.toList()..sort((a, b) => count[b]!.compareTo(count[a]!));
      return [for (final key in keys) ('series:$key', label[key]!)];
    }
    // 베이 = 블레이더 묶음만 (라인 BX · UX · CX 는 종류에서 고른다).
    // 조건에는 묶음 id 와 한국어 이름 (보일 때 scopeShown 이 화면 언어로)
    final worlds = await deriveWorlds(channel);
    return [
      for (final w in worlds)
        if (w.total > 0 && !(channel == 'beyblade' && isBeyLineWorld(w.id)))
          if (w.id.substring(channel.length + 1) case final id)
            ('group:$id', atlasGroupLabel(channel, id, zh: false) ?? w.label),
    ];
  }

  Widget _chip(String label, bool on, VoidCallback onTap) => ChoiceChip(
    label: Text(label),
    selected: on,
    showCheckmark: false,
    selectedColor: Gp.accent.withValues(alpha: 0.14),
    side: BorderSide(color: on ? Gp.accent : Gp.line),
    onSelected: (_) => onTap(),
  );

  Widget _step(String title, List<Widget> chips) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
        ),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: chips),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final ch = _channel;
    return SafeArea(
      top: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(tr('알림 조건 추가'), padding: const EdgeInsets.fromLTRB(20, 0, 8, 4)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              children: [
                if (widget.channel == null)
                  _step(tr('채널'), [
                    for (final c in allChannels)
                      if (c.hasData) _chip(tr(c.label), ch == c.id, () => _pickChannel(c.id)),
                  ]),
                if (ch != null && _scopes.isNotEmpty)
                  _step(
                    switch (ch) {
                      'madoka' => tr('캐릭터'),
                      'beyblade' => tr('블레이더'),
                      'lego' || 'nintendo' => tr('시리즈'),
                      'pokemon' => tr('세대'),
                      _ => tr('작품'),
                    },
                    [
                      _chip(tr('전부'), _scope.$1.isEmpty, () => setState(() => _scope = ('', ''))),
                      for (final s in _scopes)
                        _chip(scopeShown(ch, s.$1, s.$2), _scope.$1 == s.$1, () => setState(() => _scope = s)),
                    ],
                  ),
                if (ch != null && _lines.isNotEmpty)
                  _step(tr('종류'), [
                    _chip(tr('전부'), _line.isEmpty, () => setState(() => _line = '')),
                    // 라인 이름은 조건 값(한국어 그대로 저장 · 비교) — 보일 때만 번역
                    for (final l in _lines) _chip(tr(l), _line == l, () => setState(() => _line = l)),
                  ]),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: GradientButton(
              label: ch == null ? tr('채널을 골라 주세요') : tr('추가'),
              onPressed: ch == null
                  ? null
                  : () => Navigator.pop(
                      context,
                      NotifyCondition(franchise: ch, scope: _scope.$1, scopeLabel: _scope.$2, line: _line),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 조건 한 줄 글자: "건담 · SEED · HG" (빈 칸 = 전부)
String conditionLabel(NotifyCondition x) => [
  tr(channelOf(x.franchise).label),
  x.scope.isEmpty ? tr('전부') : scopeShown(x.franchise, x.scope, x.scopeLabel),
  x.line.isEmpty ? tr('전부') : tr(x.line),
].join(' · ');

/// 작품 이름 (화면) — 조건에는 한국어 이름을 저장하고 (기기 · 언어가 바뀌어도 같은 값), 보일 때 화면 언어로:
///   series: = 상품의 중국어 작품 이름 / group: = atlas 묶음 이름 (전에 중국어 화면에서 고른 조건도 id 로 다시 찾는다)
/// 찾지 못하면 적어 둔 이름 그대로
String scopeShown(String franchise, String scope, String label) {
  if (scope.startsWith('group:')) {
    return atlasGroupLabel(franchise, scope.substring('group:'.length), zh: L10n.isZh) ?? label;
  }
  if (!L10n.isZh || !scope.startsWith('series:')) return label;
  return _seriesZhByKey()[scope.substring('series:'.length)] ?? label;
}

List<Kit>? _seriesZhOf;
Map<String, String> _seriesZh = const {};

/// series key → 중국어 작품 이름 (카탈로그가 바뀔 때만 다시 만든다 — 시트 칩마다 전체 상품을 돌지 않게)
Map<String, String> _seriesZhByKey() {
  final kits = Catalog.instance.kits;
  if (!identical(kits, _seriesZhOf)) {
    _seriesZhOf = kits;
    _seriesZh = {
      for (final k in kits)
        if (k.seriesKey.isNotEmpty && k.seriesZh.isNotEmpty) k.seriesKey: k.seriesZh,
    };
  }
  return _seriesZh;
}
