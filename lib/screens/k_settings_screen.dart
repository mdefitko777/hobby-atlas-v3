// 화면 K: 설정 — 오른쪽 위 ⚙ 에서 열림 (내 정보와 따로)
//
// ┌──────── 디자인 가이드 대응표: K 설정 ──────────────────────────────────────────────┐
// │ 번호 │ Flutter 위젯명                     │ 비즈니스 명칭(한글)                    │ 원칙(P번호)   │
// │ K-1  │ SwitchListTile × 2                 │ 새 소식 알림(휴대폰) · 내 채널 소식만      │ P03 · P07     │
// │ K-5  │ FilterChip 묶음 2개                 │ 알림 규칙: 관심 항목 · 세계관 전체          │ P04 · P05     │
// │ K-6  │ ListTile · 대화상자                  │ 마지막 확인 · 지금 확인 · 삼성 배터리 안내   │ P10           │
// │ K-2  │ ListTile → 바텀 시트(선택)          │ 언어                                   │ P04           │
// │ K-3  │ ListTile → 파일 · 붙여넣기 → 확인     │ 옛 Gunpula 에서 가져오기 · 백업          │ P10           │
// │ K-4  │ ListTile                           │ 상품 데이터 기준일 · 지금 새로 받기 · 버전 │ P10           │
// └──────────────────────────────────────────────────────────────────────────────────┘
// 전환: 앱 셸 ⚙ → 쌓기(push, 오른쪽에서). 언어 → 덮기(바텀 시트). 가져오기 → 덮기(시트 · 확인 대화상자).
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/catalog.dart';
import '../data/user_store.dart';
import '../detail_pane.dart';
import '../notifications/local_notifier.dart';
import '../notifications/notify_models.dart';
import '../notifications/notify_store.dart';
import '../theme.dart';
import '../widgets.dart';

void openSettings(BuildContext context) {
  openPage(context, const SettingsScreen());
}

/// 삼성 갤럭시: 오래 안 연 앱을 재워 12시간 확인이 멈추는 것을 막는 방법 (처음 알림을 켰을 때 한 번 · 설정에서 언제든)
Future<void> showBatteryHint(BuildContext context, NotifyStore notify) async {
  notify.markHintShown();
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('알림이 늦게 오면 (삼성 갤럭시)'),
      content: const SingleChildScrollView(
        child: Text(
          '갤럭시는 한동안 안 연 앱을 "절전 앱"으로 재워서, 12시간마다 하는 새 소식 확인이 멈출 수 있어요.\n\n'
          '1. 설정 › 배터리 › 백그라운드 사용 제한 › 절전 예외 앱 › + 에서 Hobby Atlas 추가\n'
          '   ("절전 앱" · "초절전 앱" 목록에 있으면 빼 주세요)\n'
          '2. 설정 › 애플리케이션 › Hobby Atlas › 배터리 › 제한 없음\n\n'
          '앱을 열 때도 한 번 더 확인하니, 못 받은 소식은 앱을 열면 알림 화면에 모여요.',
          style: TextStyle(height: 1.45),
        ),
      ),
      actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('알겠어요'))],
    ),
  );
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.notify});

  /// 알림 설정 한 벌 (기본: 앱 전체, 테스트는 NotifyStore.memory())
  final NotifyStore? notify;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  NotifyStore get _n => widget.notify ?? NotifyScope.read(context);
  String _language = '한국어';
  bool _refreshing = false;

  /// 휴대폰 설정에서 이 앱 알림이 켜져 있나 (안드로이드에서만, 모르면 null)
  bool? _permitted;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final p = await LocalNotifier.permitted();
    if (mounted && p != _permitted) setState(() => _permitted = p); // STATE: 휴대폰 알림 권한 → 안내 문구
  }

  /// K-1 새 소식 알림: 켜면 안드로이드 13+ 권한 창, 처음 켰으면 삼성 배터리 안내
  Future<void> _setNotify(bool on) async {
    final ok = await _n.setEnabled(on);
    if (!mounted) return;
    await _checkPermission();
    if (!mounted) return;
    if (!ok) {
      showToast(context, '알림 권한이 꺼져 있어요 · 휴대폰 설정 › 애플리케이션 › Hobby Atlas › 알림에서 켤 수 있어요');
    } else if (on && LocalNotifier.supported && !_n.config.hintShown) {
      await showBatteryHint(context, _n);
    } else if (on && !LocalNotifier.supported) {
      showToast(context, '웹 미리보기에서는 휴대폰 알림을 보내지 않아요 · 알림 화면에는 모여요');
    }
  }

  Future<void> _checkNow() async {
    final r = await _n.checkNow(force: true);
    if (!mounted) return;
    showToast(
      context,
      r == null ? '이미 확인 중이에요' : (r.error.isNotEmpty ? r.error : (r.liveCount == 0 ? '새 소식이 없어요' : '새 알림 ${r.liveCount}개')),
    );
  }

  Future<void> _pickLanguage() async {
    final l = await showPickSheet(
      // K-2 덮기 (정렬과 같은 시트)
      context,
      title: '언어',
      values: const ['한국어', '中文', 'English', '日本語'],
      current: _language,
      label: (l) => l,
    );
    if (l != null) setState(() => _language = l); // STATE: 언어 → 설정 줄 글자 (화면 번역은 없음)
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    final changed = await Catalog.instance.refresh(force: true);
    if (!mounted) return;
    setState(() => _refreshing = false);
    final c = Catalog.instance;
    showToast(context, changed ? '새로 받았어요 · ${c.kits.length}개' : (c.error.isEmpty ? '이미 최신이에요' : c.error));
  }

  // ── 옛 Gunpula 에서 가져오기 ──
  Future<void> _import() async {
    final how = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.file_open_outlined),
              title: const Text('백업 파일 고르기'),
              subtitle: const Text('옛 앱 설정 › 数据 › 导出收藏备份 으로 만든 gunpula-backup-….json'),
              onTap: () => Navigator.pop(context, 'file'),
            ),
            ListTile(
              leading: const Icon(Icons.content_paste),
              title: const Text('붙여넣기'),
              subtitle: const Text('복사해 둔 백업 JSON (도감 · 베이 부품 포함 내보내기)'),
              onTap: () => Navigator.pop(context, 'paste'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || how == null) return;
    String? text;
    if (how == 'file') {
      final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['json']);
      if (files.isEmpty) return;
      text = utf8.decode(await files.first.readAsBytes(), allowMalformed: true);
    } else {
      text = await _askPaste();
    }
    if (!mounted || text == null || text.trim().isEmpty) return;
    await Catalog.instance.ensureLoaded().catchError((Object _) {});
    final ImportPreview p;
    try {
      p = UserStore.instance.previewImport(text, Catalog.instance.byId.containsKey);
    } on FormatException catch (e) {
      if (mounted) showToast(context, e.message);
      return;
    }
    if (!mounted) return;
    if (p.isEmpty) {
      showToast(context, '가져올 기록이 없어요');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('이대로 가져올까요?'),
        content: Text(
          [
            if (p.member.isNotEmpty) '내 이름: ${p.member}',
            '구매함 ${p.owned} · 좋아요 ${p.wanted}${p.deleted > 0 ? ' · 지운 기록 ${p.deleted}' : ''}',
            if (p.unknown > 0) '지금 카탈로그에 없는 상품 ${p.unknown}개 (기록은 남겨 둬요)',
            if (p.guideManualLit.isNotEmpty) '도감 손으로 켠 기체 ${p.guideManualLit.length}',
            if (p.bbxOwnedParts.isNotEmpty) '베이 부품 ${p.bbxOwnedParts.length}',
            if (p.otherMembers.isNotEmpty) '다른 멤버(${p.otherMembers.keys.join(', ')})의 기록은 가져오지 않아요',
            '\n같은 상품은 더 최근에 바꾼 쪽을 남겨요.',
          ].join('\n'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('가져오기')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    UserStore.instance.applyImport(p);
    setState(() {});
    showToast(context, '가져왔어요 · 구매함 ${UserStore.instance.ownedCount} · 좋아요 ${UserStore.instance.wantedCount}');
  }

  Future<String?> _askPaste() {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('백업 JSON 붙여넣기'),
        content: TextField(
          controller: c,
          maxLines: 8,
          minLines: 4,
          decoration: const InputDecoration(hintText: '{"collection": …}', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('확인')),
        ],
      ),
    ).whenComplete(c.dispose);
  }

  /// 내 기록을 파일로 (토큰 · 비밀값은 원래 없음)
  Future<void> _export() async {
    final now = DateTime.now();
    final day = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final json = const JsonEncoder.withIndent(' ').convert({
      'exported_at': now.toUtc().toIso8601String(),
      'app': 'hobby-atlas-v3',
      ...UserStore.instance.toJson(),
    });
    try {
      final uri = await FilePicker.saveFile(
        fileName: 'hobby-atlas-backup-$day.json',
        bytes: Uint8List.fromList(utf8.encode(json)),
        mimeType: 'application/json',
      );
      if (mounted && uri != null) showToast(context, '백업을 저장했어요');
    } on Object catch (e) {
      if (mounted) showToast(context, '저장하지 못했어요: $e');
    }
  }

  /// K-1 · K-5 · K-6 알림
  Widget _notifySection() {
    final c = _n.config;
    Widget chip(String key) => FilterChip(
      label: Text(notifyRuleLabels[key] ?? key),
      selected: c.rule(key),
      showCheckmark: false,
      selectedColor: Gp.accent.withValues(alpha: 0.14),
      side: BorderSide(color: c.rule(key) ? Gp.accent : Gp.line),
      onSelected: (v) => _n.setRule(key, v), // STATE: 규칙 → 다음 확인부터 (저장)
    );
    Widget chips(String title, List<String> keys) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: Gp.t12, color: Gp.muted)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [for (final k in keys) chip(k)]),
        ],
      ),
    );
    final blocked = c.enabled && _permitted == false;
    return SectionPanel(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader('알림'),
          SwitchListTile(
            // K-1 P03
            secondary: const Icon(Icons.notifications_none),
            title: const Text('새 소식 알림'),
            subtitle: Text(
              blocked
                  ? '휴대폰 설정에서 이 앱 알림이 꺼져 있어요 (설정 › 애플리케이션 › Hobby Atlas › 알림)'
                  : '휴대폰 알림 · 12시간마다 + 앱을 열 때 확인 (끄면 알림 화면에만 모여요)',
            ),
            value: c.enabled && _permitted != false,
            activeThumbColor: Gp.accent,
            onChanged: _setNotify, // STATE: 알림 스위치 (저장 · 권한 요청)
          ),
          SwitchListTile(
            secondary: const Icon(Icons.filter_alt_outlined),
            title: const Text('내 채널 소식만'),
            subtitle: const Text('내 채널 밖 상품은 알리지 않아요 (좋아요한 상품은 늘)'),
            value: c.onlyMine,
            activeThumbColor: Gp.accent,
            onChanged: _n.setOnlyMine, // STATE: 채널 범위 (저장)
          ),
          chips('관심 항목', notifyInterestRules), // K-5
          chips('세계관 전체 (그 채널의 새 상품 전부)', notifyWorldRules),
          ListTile(
            // K-6
            leading: const Icon(Icons.history),
            title: const Text('새 소식 확인'),
            subtitle: Text(_n.statusLine),
            trailing: _n.checking
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : TextButton(onPressed: _checkNow, child: const Text('지금 확인')),
          ),
          if (LocalNotifier.supported)
            ListTile(
              leading: const Icon(Icons.battery_alert_outlined),
              title: const Text('알림이 늦게 오면 (삼성 갤럭시)'),
              subtitle: const Text('절전 예외 앱에 넣는 방법'),
              onTap: () => showBatteryHint(context, _n),
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'PB 예약 기간은 프리미엄 반다이 페이지의 Wayback 기록에서 읽은 값이라 늦거나 틀릴 수 있어요.',
              style: TextStyle(fontSize: Gp.t11, color: Gp.faint),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cat = Catalog.instance;
    final me = UserStore.instance;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '설정',
          style: TextStyle(fontSize: Gp.t19, fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          SectionPanel(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader('데이터'),
                ListTile(
                  // K-4
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: const Text('상품 데이터'),
                  subtitle: Text(
                    cat.kits.isEmpty
                        ? (cat.progress.isNotEmpty ? cat.progress : '아직 받지 않았어요')
                        : '기준일 ${cat.updatedAt} · ${cat.kits.length}개 · Gunpula',
                  ),
                  trailing: _refreshing
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : TextButton(onPressed: _refresh, child: const Text('지금 새로 받기')),
                ),
                ListTile(
                  // K-3 P10
                  leading: const Icon(Icons.move_down),
                  title: const Text('옛 Gunpula 에서 가져오기'),
                  subtitle: Text('지금 이 기기: 구매함 ${me.ownedCount} · 좋아요 ${me.wantedCount}'),
                  onTap: _import,
                ),
                ListTile(
                  leading: const Icon(Icons.save_alt),
                  title: const Text('백업 파일로 내보내기'),
                  subtitle: const Text('구매함 · 좋아요 · 도감 · 베이 부품'),
                  onTap: _export,
                ),
              ],
            ),
          ),
          ListenableBuilder(
            // 알림 설정은 NotifyStore 한 벌 (🔔 · 알림 화면과 같은 값, 기기에 저장)
            listenable: _n,
            builder: (context, _) => _notifySection(),
          ),
          SectionPanel(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader('앱'),
                ListTile(
                  leading: const Icon(Icons.language),
                  title: const Text('언어'),
                  trailing: Text('$_language ›', style: const TextStyle(color: Gp.muted)),
                  onTap: _pickLanguage, // K-2
                ),
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('버전'),
                  trailing: Text('Hobby Atlas v3 (개인용)', style: TextStyle(color: Gp.muted)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
