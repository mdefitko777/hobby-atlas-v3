// 화면 K: 설정 — 오른쪽 위 ⚙ 에서 열림 (내 정보와 따로)
//
// ┌──────── 디자인 가이드 대응표: K 설정 ──────────────────────────────────────────────┐
// │ 번호 │ Flutter 위젯명                     │ 비즈니스 명칭(한글)                    │ 원칙(P번호)   │
// │ K-0  │ ListTile × 3 (로그인 · 상태 · 로그아웃) │ 계정 · 동기화 (옛 Gunpula 와 같은 계정)   │ P01 · P05 · P10 │
// │ K-1  │ SwitchListTile × 2                 │ 새 소식 알림(휴대폰) · 내 채널 소식만      │ P03 · P07     │
// │ K-5  │ FilterChip 묶음 2개                 │ 알림 규칙: 관심 항목 · 세계관 전체          │ P04 · P05     │
// │ K-6  │ ListTile · 대화상자                  │ 마지막 확인 · 지금 확인 · 삼성 배터리 안내   │ P10           │
// │ K-2  │ ListTile (고르기 없음)               │ 언어: 화면 한국어 · 상품 이름 한국어 우선 │ P04 · P10     │
// │ K-3  │ ListTile → 파일 · 붙여넣기 → 확인     │ 옛 Gunpula 에서 가져오기 · 백업          │ P10           │
// │ K-4  │ ListTile                           │ 상품 데이터 기준일 · 지금 새로 받기 · 버전 │ P10           │
// │ K-7  │ ListTile → HelpScreen(쌓기)          │ 도움말: 도감 칸 4단계 · 색 · 데이터 출처 · 알림 · 업데이트 │ P10 │
// └──────────────────────────────────────────────────────────────────────────────────┘
// 전환: 앱 셸 ⚙ → 쌓기(push, 오른쪽에서). 도움말 → 쌓기. 가져오기 → 덮기(시트 · 확인 대화상자).
// 언어: 화면 번역은 없다 (한국어만). 상품 이름은 Gunpula 이름 중 한국어 → 일본어 → 영어 순 — 고르는 척하지 않는다.
// 로그인 → P 로그인 화면(쌓기). 로그아웃 → 확인 대화상자(덮기).
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/catalog.dart';
import '../data/user_store.dart';
import '../detail_pane.dart';
import '../level.dart' show CellTier, tierFrame;
import '../sync/account.dart';
import '../sync/sync_service.dart';
import '../notifications/local_notifier.dart';
import '../notifications/notify_models.dart';
import '../notifications/notify_store.dart';
import '../theme.dart';
import '../update/update_ui.dart';
import '../widgets.dart';
import 'p_sign_in_screen.dart';

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
  late final NotifyStore _n = widget.notify ?? NotifyScope.read(context);
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
      r == null
          ? '이미 확인 중이에요'
          : (r.error.isNotEmpty ? r.error : (r.liveCount == 0 ? '새 소식이 없어요' : '새 알림 ${r.liveCount}개')),
    );
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
    final signedIn = AccountScope.read(context).signedIn;
    showToast(
      context,
      '가져왔어요 · 구매함 ${UserStore.instance.ownedCount} · 좋아요 ${UserStore.instance.wantedCount}'
      '${signedIn ? ' · 계정에도 올려요' : ''}',
    );
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

  Future<void> _signOut() async {
    final account = AccountScope.read(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('로그아웃할까요?'),
        content: Text(
          '${account.store.cloudDirty ? '아직 올리지 못한 변경이 있어요. 로그아웃해도 이 기기에는 남지만, '
                    '다시 로그인할 때까지 다른 기기에는 보이지 않아요.' : '이 기기의 구매함 · 좋아요는 그대로 남아요.'}'
          '\n\n다른 계정으로 로그인하면 이 기기의 구매함 · 좋아요는 그 계정 것으로 바뀌어요 (지금 계정 것은 서버에 그대로 있어요).',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('로그아웃')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await account.signOut();
    if (mounted) showToast(context, '로그아웃했어요');
  }

  /// K-0 계정 · 동기화
  Widget _accountPanel(Account a) {
    final sync = a.sync;
    final busy = sync.phase == SyncPhase.syncing;
    return SectionPanel(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader('계정 · 동기화'),
          if (!a.ready)
            const ListTile(leading: Icon(Icons.cloud_outlined), title: Text('계정 확인 중…'))
          else if (!a.available)
            const ListTile(
              leading: Icon(Icons.cloud_off_outlined),
              title: Text('계정 연결 설정이 없어요'),
              subtitle: Text('기기에만 저장 중'),
            )
          else if (!a.signedIn)
            ListTile(
              leading: const Icon(Icons.login),
              title: const Text('로그인'),
              subtitle: const Text('옛 앱과 같은 메일로'),
              trailing: const Icon(Icons.chevron_right, color: Gp.faint),
              onTap: () => openSignIn(context),
            )
          else ...[
            ListTile(
              leading: Icon(switch (sync.phase) {
                SyncPhase.offline => Icons.cloud_off_outlined,
                SyncPhase.error => Icons.error_outline,
                _ => Icons.cloud_done_outlined,
              }, color: sync.phase == SyncPhase.error ? Gp.danger : null),
              title: Text(a.email.isEmpty ? '로그인됨' : a.email),
              subtitle: Text(sync.statusLine),
              isThreeLine: sync.statusLine.contains('\n'),
              trailing: busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : TextButton(
                      onPressed: () => sync.syncNow(reason: 'manual'),
                      child: const Text('지금 동기화'),
                    ),
            ),
            ListTile(leading: const Icon(Icons.logout), title: const Text('로그아웃'), onTap: _signOut),
          ],
        ],
      ),
    );
  }

  /// 내 기록을 파일로 (토큰 · 비밀값은 원래 없음)
  Future<void> _export() async {
    final now = DateTime.now();
    final day = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final json = const JsonEncoder.withIndent(
      ' ',
    ).convert({'exported_at': now.toUtc().toIso8601String(), 'app': 'hobby-atlas-v3', ...UserStore.instance.toJson()});
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
          Text(
            title,
            style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
          ),
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
            subtitle: blocked ? const Text('휴대폰 설정에서 알림이 꺼져 있어요') : null,
            value: c.enabled && _permitted != false,
            activeThumbColor: Gp.accent,
            onChanged: _setNotify, // STATE: 알림 스위치 (저장 · 권한 요청)
          ),
          SwitchListTile(
            secondary: const Icon(Icons.filter_alt_outlined),
            title: const Text('내 채널 소식만'),
            value: c.onlyMine,
            activeThumbColor: Gp.accent,
            onChanged: _n.setOnlyMine, // STATE: 채널 범위 (저장)
          ),
          // K-5 어떤 새 상품이 나오면 알릴지 (켠 것만)
          chips('이런 새 상품이 나오면 알림', notifyInterestRules),
          chips('이 채널 새 상품은 전부 알림', notifyWorldRules),
          ListTile(
            // K-6
            leading: const Icon(Icons.history),
            title: const Text('새 소식 확인'),
            subtitle: Text(_n.shortStatus),
            trailing: _n.checking
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : TextButton(onPressed: _checkNow, child: const Text('지금 확인')),
          ),
          if (LocalNotifier.supported)
            ListTile(
              leading: const Icon(Icons.battery_alert_outlined),
              title: const Text('알림이 늦게 오면 (삼성 갤럭시)'),
              onTap: () => showBatteryHint(context, _n),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cat = Catalog.instance;
    final account = AccountScope.of(context); // 로그인 · 동기화 상태가 바뀌면 다시 그림
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
          _accountPanel(account),
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
                        : '${dateDot(cat.updatedAt)} · ${cat.kits.length}개',
                  ),
                  trailing: _refreshing
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : TextButton(onPressed: _refresh, child: const Text('지금 새로 받기')),
                ),
                ListTile(
                  // K-3 P10
                  leading: const Icon(Icons.move_down),
                  title: const Text('옛 Gunpula 에서 가져오기'),
                  onTap: _import,
                ),
                ListTile(leading: const Icon(Icons.save_alt), title: const Text('백업 파일로 내보내기'), onTap: _export),
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
                const ListTile(
                  // K-2 화면 번역 없음 — 있는 그대로
                  leading: Icon(Icons.language),
                  title: Text('언어'),
                  subtitle: Text('상품 이름 한국어 → 日本語 → English'),
                  trailing: Text('한국어', style: TextStyle(color: Gp.muted)),
                ),
                ListTile(
                  // K-7
                  leading: const Icon(Icons.help_outline),
                  title: const Text('도움말'),
                  trailing: const Icon(Icons.chevron_right, color: Gp.faint),
                  onTap: () => openPage(context, const HelpScreen()),
                ),
                const VersionTile(), // 지금 빌드 · 업데이트 확인
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// K-7 도움말 — 짧게: 도감 칸 · 색 · 데이터 출처 · 알림 · 업데이트
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Widget cell(CellTier t, IconData icon, String label) => Column(
      children: [
        SizedBox.square(
          dimension: 44,
          child: tierFrame(
            t,
            Center(
              child: Icon(icon, size: Gp.iM, color: t == CellTier.none ? Gp.faint : Gp.ink),
            ),
            radius: 10,
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: Gp.t12)),
      ],
    );
    Widget tip(IconData icon, String title, String body) =>
        ListTile(leading: Icon(icon), title: Text(title), subtitle: Text(body));
    Widget dot(Color c, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: Gp.t12)),
      ],
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '도움말',
          style: TextStyle(fontSize: Gp.t19, fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          SectionPanel(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader('도감 칸'),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    cell(CellTier.none, Icons.help_outline, '아직'),
                    cell(CellTier.liked, Icons.favorite_border, '좋아요'),
                    cell(CellTier.owned, Icons.bookmark_added_outlined, '구매함'),
                    cell(CellTier.photo, Icons.photo_camera_outlined, '내 사진'),
                  ],
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [dot(Gp.accent, '파랑 = 고름 · 좋아요'), dot(Gp.own, '민트 = 가진 것')],
                  ),
                ),
              ],
            ),
          ),
          SectionPanel(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader('데이터'),
                tip(Icons.cloud_download_outlined, '상품 정보', 'Gunpula 가 공식 사이트에서 매일 모아요 (BANDAI SPIRITS · 포켓몬센터 …)'),
                tip(Icons.payments_outlined, '가격', '일본 정가만 · 국내 시세는 상세에서 검색으로'),
                tip(Icons.flag_outlined, '틀린 정보', '상품 상세 맨 아래 › 제보 (GitHub)'),
              ],
            ),
          ),
          SectionPanel(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader('알림'),
                tip(Icons.schedule, '12시간마다 확인', '앱을 열 때도 한 번 더'),
                tip(Icons.event_available_outlined, '좋아요한 상품', '발매 D-7 · D-1 · 당일 (발매일이 정해진 것만)'),
                tip(Icons.battery_alert_outlined, '늦게 오면', '설정 › 알림 › 삼성 갤럭시 안내'),
              ],
            ),
          ),
          SectionPanel(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader('앱 업데이트'),
                tip(Icons.system_update_outlined, '위 줄 ⬇ · 설정 › 앱 › 버전', '새 빌드를 받아 안드로이드 설치 창으로'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
