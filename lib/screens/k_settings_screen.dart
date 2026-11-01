// 화면 K: 설정 — 오른쪽 위 ⚙ 에서 열림 (내 정보와 따로)
//
// ┌──────── 디자인 가이드 대응표: K 설정 ──────────────────────────────────────────────┐
// │ 번호 │ Flutter 위젯명                     │ 비즈니스 명칭(한글)                    │ 원칙(P번호)   │
// │ K-0  │ ListTile × 3 (로그인 · 상태 · 로그아웃) │ 계정 · 동기화 (옛 Gunpula 와 같은 계정)   │ P01 · P05 · P10 │
// │ K-1  │ SwitchListTile × 2                 │ 새 소식 알림 · 내 채널 소식만 (준비 중)    │ P03 · P07     │
// │ K-2  │ ListTile → 바텀 시트(선택)          │ 언어                                   │ P04           │
// │ K-3  │ ListTile → 파일 · 붙여넣기 → 확인     │ 옛 Gunpula 에서 가져오기 · 백업          │ P10           │
// │ K-4  │ ListTile                           │ 상품 데이터 기준일 · 지금 새로 받기 · 버전 │ P10           │
// └──────────────────────────────────────────────────────────────────────────────────┘
// 전환: 앱 셸 ⚙ → 쌓기(push, 오른쪽에서). 언어 → 덮기(바텀 시트). 가져오기 → 덮기(시트 · 확인 대화상자).
// 로그인 → P 로그인 화면(쌓기). 로그아웃 → 확인 대화상자(덮기).
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/catalog.dart';
import '../data/user_store.dart';
import '../detail_pane.dart';
import '../sync/account.dart';
import '../sync/sync_service.dart';
import '../theme.dart';
import '../widgets.dart';
import 'p_sign_in_screen.dart';

void openSettings(BuildContext context) {
  openPage(context, const SettingsScreen());
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notify = true;
  bool _onlyMine = true;
  String _language = '한국어';
  bool _refreshing = false;

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
              subtitle: Text('config/supabase.json · 기기에만 저장 중'),
            )
          else if (!a.signedIn)
            ListTile(
              leading: const Icon(Icons.login),
              title: const Text('로그인'),
              subtitle: const Text('옛 Gunpula 앱과 같은 메일로 로그인하면 컬렉션이 그대로 와요'),
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
                  : TextButton(onPressed: () => sync.syncNow(reason: 'manual'), child: const Text('지금 동기화')),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('로그아웃'),
              onTap: _signOut,
            ),
          ],
        ],
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final cat = Catalog.instance;
    final me = UserStore.instance;
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
          SectionPanel(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader('알림 (준비 중)'),
                SwitchListTile(
                  // K-1 P03
                  secondary: const Icon(Icons.notifications_none),
                  title: const Text('새 소식 알림'),
                  subtitle: const Text('새 상품 · 예고 · 친구 소식'),
                  value: _notify,
                  activeThumbColor: Gp.accent,
                  onChanged: (v) => setState(() => _notify = v), // STATE: 알림 스위치
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.filter_alt_outlined),
                  title: const Text('내 채널 소식만'),
                  subtitle: const Text('관심 없는 IP의 알림은 받지 않아요'),
                  value: _onlyMine,
                  activeThumbColor: Gp.accent,
                  onChanged: _notify ? (v) => setState(() => _onlyMine = v) : null, // 알림이 꺼지면 함께 꺼짐 P05
                ),
              ],
            ),
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
