// 화면 K (설정 안의 페이지): 알림 — 설정 › 알림 줄 · 알림 화면 ⚙ 에서 열림
// 전에는 설정 한 화면에 규칙 칩이 줄줄이 있었다. 2026-11-12 주인이 고른 모양으로 나눔: 내 상품은 스위치, 새 상품은 채널마다 한 줄 → 채널 시트.
// 저장 모양(NotifyConfig)은 그대로 — 규칙 키 · 조건이 같아 전에 고른 설정이 그대로 온다.
//
// ┌──────── 디자인 가이드 대응표: K 설정 (알림) ───────────────────────────────────────┐
// │ 번호 │ Flutter 위젯명                     │ 비즈니스 명칭(한글)                    │ 원칙(P번호)   │
// │ K-1  │ SwitchListTile × 2                 │ 새 소식 알림(휴대폰) · 내 채널 소식만      │ P03 · P07     │
// │ K-8  │ SwitchListTile × 6                 │ 내 상품: 좋아요한 상품 소식 · 발매 D-7 · D-1 · 재판매 · 예약 도착 · 예약 시작 전 · 라이브 시작 전 │ P03 · P07 │
// │ K-9  │ ListTile(채널 그림 · 요약 · ›)       │ 새 상품 (채널별): 내 채널 → 더 많은 채널, 요약 = 전부 · SEED/00 · PB … · 끔 │ P01 · P06 │
// │ K-5  │ 아래 시트: SwitchListTile + 조건 줄  │ 채널 규칙: <채널> 전체 · SEED / 00 · PB · PB 예약 기간 · BBX + 골라서 알림(조건 시트) │ P04 · P05 │
// │ K-6  │ ListTile · 지금 확인                │ 마지막 확인 · 지금 확인 · 휴대폰 알림 권한  │ P10           │
// └──────────────────────────────────────────────────────────────────────────────────┘
// 전환: 설정 K-3 · 알림 화면 ⚙ → 쌓기(openPage, 도움말과 같은 길). 채널 줄 → 아래 시트(덮기) → 조건 추가 시트(덮기).
import 'package:flutter/material.dart';

import '../channels.dart';
import '../detail_pane.dart';
import '../l10n/l10n.dart';
import '../marks.dart';
import '../notifications/local_notifier.dart';
import '../notifications/notify_models.dart';
import '../notifications/notify_store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'notify_condition_sheet.dart';

/// 알림 페이지 열기 — [notify] 없으면 앱 전체 한 벌
void openNotifySettings(BuildContext context, {NotifyStore? notify}) =>
    openPage(context, NotifySettingsScreen(notify: notify));

/// 설정 줄 요약: "켜짐 · 규칙 10개" · "꺼짐". 규칙 = 켠 규칙 + 내가 만든 조건
String notifySummary(NotifyConfig c, {bool? permitted}) {
  if (!c.enabled || permitted == false) return tr('꺼짐');
  final n = notifyRuleDefaults.keys.where(c.rule).length + c.conditions.length;
  return '${tr('켜짐')} · ${trf('규칙 {n}개', {'n': n})}';
}

/// 채널 줄 요약에 쓰는 짧은 이름
const _shortRule = {'seed_00': 'SEED/00', 'premium_bandai': 'PB', 'pb_window': 'PB 예약', 'bbx': 'BBX'};

/// 좋아요한 PB 상품의 예약 기간은 채널 범위와 상관없이 본다 (feed_rules pbWindowRecords) — 건담 시트에 있지만 늘 센다
const _anyChannelRules = {'pb_window'};

/// 채널 줄 요약: "전부" · "SEED/00 · PB · 조건 2개" · "끔".
/// 내 채널 소식만이 켜져 있고 [mine] 이 아니면 규칙은 걸리지 않는다 (feed_rules ruleHits) — 그때는 조건만 센다
String channelNotifySummary(NotifyConfig c, String channel, {required bool mine}) {
  final rulesApply = !c.onlyMine || mine;
  final parts = <String>[];
  if (rulesApply && notifyWorldRules.contains(channel) && c.rule(channel)) {
    parts.add(tr('전부'));
  } else {
    for (final k in notifyChannelRules[channel] ?? const <String>[]) {
      if (c.rule(k) && (rulesApply || _anyChannelRules.contains(k))) parts.add(tr(_shortRule[k] ?? k));
    }
  }
  final n = c.conditions.where((x) => x.franchise == channel).length;
  if (n > 0) parts.add(trf('조건 {n}개', {'n': n}));
  return parts.isEmpty ? tr('끔') : parts.join(' · ');
}

class NotifySettingsScreen extends StatefulWidget {
  const NotifySettingsScreen({super.key, this.notify});

  /// 알림 설정 한 벌 (기본: 앱 전체, 테스트는 NotifyStore.memory())
  final NotifyStore? notify;

  @override
  State<NotifySettingsScreen> createState() => _NotifySettingsScreenState();
}

class _NotifySettingsScreenState extends State<NotifySettingsScreen> {
  late final NotifyStore _n = widget.notify ?? NotifyScope.read(context);

  /// 휴대폰 설정에서 이 앱 알림이 켜져 있나 (안드로이드에서만, 모르면 null)
  bool? _permitted;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final p = await LocalNotifier.permitted();
    if (mounted && p != _permitted) setState(() => _permitted = p); // STATE: 휴대폰 알림 권한 → 안내 줄
  }

  /// K-1 새 소식 알림: 켜면 안드로이드 13+ 권한 창
  Future<void> _setNotify(bool on) async {
    final ok = await _n.setEnabled(on);
    if (!mounted) return;
    await _checkPermission();
    if (!mounted) return;
    if (!ok) {
      showToast(context, tr('알림 권한이 꺼져 있어요 · 휴대폰 설정 › 애플리케이션 › Hobby Atlas › 알림에서 켤 수 있어요'));
    } else if (on && !LocalNotifier.supported) {
      showToast(context, tr('웹 미리보기에서는 휴대폰 알림을 보내지 않아요 · 알림 화면에는 모여요'));
    }
  }

  Future<void> _checkNow() async {
    final r = await _n.checkNow(force: true);
    if (!mounted) return;
    showToast(
      context,
      r == null
          ? tr('이미 확인 중이에요')
          : (r.error.isNotEmpty
                ? r.error
                : (r.liveCount == 0 ? tr('새 소식이 없어요') : trf('새 알림 {n}개', {'n': r.liveCount}))),
    );
  }

  Widget _ruleSwitch(String key, IconData icon, String hint) => SwitchListTile(
    key: Key('rule-$key'),
    secondary: Icon(icon),
    title: Text(notifyRuleLabel(key)),
    subtitle: Text(hint),
    value: _n.config.rule(key),
    activeThumbColor: Gp.accent,
    onChanged: (v) => _n.setRule(key, v), // STATE: 규칙 → 다음 확인부터 (저장)
  );

  Widget _channelRow(Channel ch, {required bool mine}) => ListTile(
    // K-9
    key: Key('notify-channel-${ch.id}'),
    leading: CircleThumb(image: ch.image, label: tr(ch.label), size: 32),
    title: Text(tr(ch.label)),
    subtitle: Text(channelNotifySummary(_n.config, ch.id, mine: mine)),
    trailing: const Icon(Icons.chevron_right, color: Gp.faint),
    onTap: () => showGpSheet<void>(
      context,
      tall: true,
      builder: (_) => _ChannelSheet(store: _n, channel: ch.id),
    ),
  );

  Widget _body(List<String> myChannels) {
    final c = _n.config;
    // 조건이 남아 있는 채널은 데이터가 빠져도 보인다 — 아니면 그 조건을 지울 곳이 없다
    final withConditions = {for (final x in c.conditions) x.franchise};
    final channels = [
      for (final ch in allChannels)
        if (ch.hasData || withConditions.contains(ch.id)) channelOf(ch.id), // 채널 그림 = 공식 그림(atlas-groups)이 있으면 그것
      for (final id in withConditions)
        if (!allChannels.any((ch) => ch.id == id)) channelOf(id),
    ];
    final mine = [for (final id in myChannels) ?channels.where((ch) => ch.id == id).firstOrNull];
    final more = [
      for (final ch in channels)
        if (!myChannels.contains(ch.id)) ch,
    ];
    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        SectionPanel(
          padding: const EdgeInsets.only(bottom: 6),
          child: Column(
            children: [
              SwitchListTile(
                // K-1 P03
                key: const Key('notify-enabled'),
                secondary: const Icon(Icons.notifications_none),
                title: Text(tr('새 소식 알림')),
                subtitle: c.enabled && _permitted == false ? Text(tr('휴대폰 설정에서 알림이 꺼져 있어요')) : null,
                value: c.enabled && _permitted != false,
                activeThumbColor: Gp.accent,
                onChanged: _setNotify, // STATE: 알림 스위치 (저장 · 권한 요청)
              ),
              SwitchListTile(
                key: const Key('notify-only-mine'),
                secondary: const Icon(Icons.filter_alt_outlined),
                title: Text(tr('내 채널 소식만')),
                value: c.onlyMine,
                activeThumbColor: Gp.accent,
                onChanged: _n.setOnlyMine, // STATE: 채널 범위 (저장)
              ),
            ],
          ),
        ),
        SectionPanel(
          // K-8 채널과 상관없이 내가 고른 상품
          padding: const EdgeInsets.only(bottom: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(tr('내 상품')),
              _ruleSwitch('wanted', Icons.favorite_border, tr('좋아요한 상품의 가격 · 발매일 · 판매처가 바뀌면')),
              _ruleSwitch('release_soon', Icons.today_outlined, tr('발매 D-7 · D-1 · 당일 (발매일이 정해진 것만)')),
              _ruleSwitch('restock', Icons.replay, tr('좋아요 · 구매함 상품의 재판매(再販) 소식')),
              _ruleSwitch('preorder_arrival', Icons.local_shipping_outlined, tr('예약한 상품의 도착 달 · 도착 날 (내가 적은 도착 예정)')),
              // 라이브와 같은 까닭으로 당일에 올라온 예약은 놓칠 수 있다 (GUNDAM.INFO 「本日11時」는 15분 전에 올라온다)
              _ruleSwitch(
                'preorder_soon',
                Icons.alarm,
                tr('알림 받는 예고 · 좋아요한 상품의 예약 시작 30분쯤 전 (시각이 정해진 것만 · 당일에 올라온 것은 놓칠 수 있어요)'),
              ),
              // 뒤 확인은 3시간마다(대기 모드면 더 늦다)라 시작 몇 시간 전에 올라온 라이브는 놓칠 수 있다 — 그대로 적어 둔다
              _ruleSwitch(
                'live_soon',
                Icons.live_tv_outlined,
                tr('내 채널 공식 라이브 시작 30분쯤 전 · 새로 올라온 라이브 (당일에 올라온 것은 앱을 열지 않으면 놓칠 수 있어요)'),
              ),
            ],
          ),
        ),
        SectionPanel(
          // K-9 새 상품은 채널마다 — 내 채널 먼저
          padding: const EdgeInsets.only(bottom: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(tr('새 상품 (채널별)')),
              for (final ch in mine) _channelRow(ch, mine: true),
              if (more.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
                  child: Text(
                    tr('더 많은 채널'),
                    style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
                  ),
                ),
                if (c.onlyMine)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    child: Text(
                      tr('내 채널 소식만이 켜져 있으면 이 채널들의 새 상품은 내가 만든 조건으로만 알려요'),
                      style: const TextStyle(fontSize: Gp.t12, color: Gp.faint),
                    ),
                  ),
                for (final ch in more) _channelRow(ch, mine: false),
              ],
            ],
          ),
        ),
        SectionPanel(
          padding: const EdgeInsets.only(bottom: 6),
          child: Column(
            children: [
              ListTile(
                // K-6
                leading: const Icon(Icons.history),
                title: Text(tr('새 소식 확인')),
                subtitle: Text(_n.shortStatus),
                trailing: _n.checking
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : TextButton(onPressed: _checkNow, child: Text(tr('지금 확인'))),
              ),
              if (_permitted == false)
                ListTile(
                  // 이 앱이 휴대폰 설정 화면을 열 수는 없다 (플러그인 없음) — 가는 길만
                  key: const Key('notify-permission'),
                  leading: const Icon(Icons.notifications_off_outlined, color: Gp.danger),
                  title: Text(tr('알림 권한이 꺼져 있어요 · 휴대폰 설정 › 애플리케이션 › Hobby Atlas › 알림에서 켤 수 있어요')),
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final myChannels = Marks.of(context).store.myChannels; // 내 채널이 바뀌면 다시 그림
    return Scaffold(
      appBar: AppBar(title: Text(tr('알림'))),
      // 알림 설정은 NotifyStore 한 벌 (🔔 · 알림 화면 · 설정 줄과 같은 값, 기기에 저장)
      body: ListenableBuilder(listenable: _n, builder: (context, _) => _body(myChannels)),
    );
  }
}

/// K-5 채널 시트: 그 채널 전체 · 채널 규칙 · 내가 만든 조건 (조건 고르기는 notify_condition_sheet 그대로)
class _ChannelSheet extends StatelessWidget {
  const _ChannelSheet({required this.store, required this.channel});
  final NotifyStore store;
  final String channel;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final c = store.config;
      final rules = [if (notifyWorldRules.contains(channel)) channel, ...?notifyChannelRules[channel]];
      return SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader(tr(channelOf(channel).label), padding: const EdgeInsets.fromLTRB(20, 0, 8, 4)),
                for (final k in rules)
                  SwitchListTile(
                    key: Key('rule-$k'),
                    title: Text(notifyRuleLabel(k)),
                    // PB 규칙은 키가 하나라 다른 채널의 PB 상품에도 같이 걸린다
                    subtitle: k == 'premium_bandai' || k == 'pb_window' ? Text(tr('다른 채널의 PB 상품도 같이 켜고 꺼요')) : null,
                    value: c.rule(k),
                    activeThumbColor: Gp.accent,
                    onChanged: (v) => store.setRule(k, v), // STATE: 규칙 (저장)
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                  child: Text(
                    tr('골라서 알림 (채널 · 작품 · 종류)'),
                    style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
                  ),
                ),
                for (final x in c.conditions)
                  if (x.franchise == channel)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.notifications_active_outlined, size: Gp.iM),
                      title: Text(conditionLabel(x)),
                      trailing: IconButton(
                        tooltip: tr('지우기'),
                        icon: const Icon(Icons.close, size: 18, color: Gp.faint),
                        onPressed: () => store.removeCondition(x.id), // STATE: 조건 지우기 (저장)
                      ),
                    ),
                ListTile(
                  key: const Key('notify-add-condition'),
                  dense: true,
                  leading: const Icon(Icons.add, size: Gp.iM, color: Gp.accent),
                  title: Text(tr('조건 추가'), style: const TextStyle(color: Gp.accent)),
                  onTap: () async {
                    final x = await pickNotifyCondition(context, channel: channel);
                    if (x != null) store.addCondition(x); // STATE: 조건 추가 (저장)
                  },
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
