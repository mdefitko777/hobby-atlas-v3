// 화면 K: 설정 — 오른쪽 위 ⚙ 에서 열림 (내 정보와 따로)
//
// ┌──────── 디자인 가이드 대응표: K 설정 ──────────────────────────────────────────────┐
// │ 번호 │ Flutter 위젯명                     │ 비즈니스 명칭(한글)                    │ 원칙(P번호)   │
// │ K-0  │ ListTile × 3 (로그인 · 상태 · 로그아웃) │ 계정 · 동기화 (옛 Gunpula 와 같은 계정)   │ P01 · P05 · P10 │
// │ K-1  │ SwitchListTile × 2                 │ 새 소식 알림(휴대폰) · 내 채널 소식만      │ P03 · P07     │
// │ K-5  │ FilterChip 묶음 2개                 │ 알림 규칙: 관심 항목 · 세계관 전체          │ P04 · P05     │
// │ K-6  │ ListTile · 대화상자                  │ 마지막 확인 · 지금 확인                  │ P10           │
// │ K-2  │ ListTile → 고르는 시트              │ 언어: 한국어(기본) · 中文                │ P04 · P10     │
// │ K-4  │ ListTile                           │ 상품 데이터 기준일 · 지금 새로 받기 · 버전 │ P10           │
// │ K-7  │ ListTile → HelpScreen(쌓기)          │ 도움말: 도감 칸(늘 컬러 · ♡ · 리본 · 내 사진) · 색 · 데이터 출처 · 알림 · 업데이트 │ P10 │
// └──────────────────────────────────────────────────────────────────────────────────┘
// 전환: 앱 셸 ⚙ → 쌓기(push, 오른쪽에서). 도움말 → 쌓기.
// 언어: 한국어(기본) · 中文. 중국어면 화면 글(lib/l10n) · 상품 이름(Gunpula names.zh) · 공지 번역(ML Kit 일→중) · 알림이 중국어.
// 기기마다 따로 고른다 (lang.json, 계정에 맞추지 않음).
// 로그인 → P 로그인 화면(쌓기). 로그아웃 → 확인 대화상자(덮기).

import 'package:flutter/material.dart';

import '../data/catalog.dart';
import '../detail_pane.dart';
import '../l10n/l10n.dart';
import '../sync/account.dart';
import '../sync/sync_service.dart';
import '../notifications/local_notifier.dart';
import '../notifications/notify_models.dart';
import '../notifications/notify_store.dart';
import '../theme.dart';
import '../update/update_ui.dart';
import '../widgets.dart';
import 'notify_condition_sheet.dart';
import 'p_sign_in_screen.dart';
import '../data/user_store.dart' show UserStore;
import '../logic/lego_scope.dart';

void openSettings(BuildContext context) {
  openPage(context, const SettingsScreen());
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

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    final changed = await Catalog.instance.refresh(force: true);
    if (!mounted) return;
    setState(() => _refreshing = false);
    final c = Catalog.instance;
    showToast(
      context,
      changed ? trf('새로 받았어요 · {n}개', {'n': c.kits.length}) : (c.error.isEmpty ? tr('이미 최신이에요') : c.error),
    );
  }

  /// K-2 언어 고르기 — 고르면 L10n 이 앱 전체를 그 언어로 다시 만든다 (main.dart)
  Future<void> _pickLanguage(BuildContext context) async {
    final picked = await showGpSheet<AppLang>(
      context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (lang, label) in const [(AppLang.ko, '한국어'), (AppLang.zh, '中文 (简体)')])
              ListTile(
                key: Key('language-${lang.name}'),
                title: Text(label),
                trailing: L10n.current == lang ? const Icon(Icons.check, color: Gp.accent) : null,
                onTap: () => Navigator.pop(sheet, lang),
              ),
          ],
        ),
      ),
    );
    if (picked != null) await L10n.set(picked);
  }

  Future<void> _signOut() async {
    final account = AccountScope.read(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(tr('로그아웃할까요?')),
        content: Text(
          '${account.store.cloudDirty ? tr('아직 올리지 못한 변경이 있어요. 로그아웃해도 이 기기에는 남지만, 다시 로그인할 때까지 다른 기기에는 보이지 않아요.') : tr('이 기기의 구매함 · 좋아요는 그대로 남아요.')}'
          '\n\n${tr('다른 계정으로 로그인하면 이 기기의 구매함 · 좋아요는 그 계정 것으로 바뀌어요 (지금 계정 것은 서버에 그대로 있어요).')}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(tr('취소'))),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text(tr('로그아웃'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await account.signOut();
    if (mounted) showToast(context, tr('로그아웃했어요'));
  }

  /// K-0 계정 · 동기화
  Widget _accountPanel(Account a) {
    final sync = a.sync;
    final busy = sync.phase == SyncPhase.syncing;
    final syncLine = [sync.statusLine, if (a.deviceState.statusLine.isNotEmpty) a.deviceState.statusLine].join('\n');
    return SectionPanel(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(tr('계정 · 동기화')),
          if (!a.ready)
            ListTile(leading: const Icon(Icons.cloud_outlined), title: Text(tr('계정 확인 중…')))
          else if (!a.available)
            ListTile(
              leading: const Icon(Icons.cloud_off_outlined),
              title: Text(tr('계정 연결 설정이 없어요')),
              subtitle: Text(tr('기기에만 저장 중')),
            )
          else if (!a.signedIn)
            ListTile(
              leading: const Icon(Icons.login),
              title: Text(tr('로그인')),
              subtitle: Text(tr('옛 앱과 같은 메일로')),
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
              title: Text(a.email.isEmpty ? tr('로그인됨') : a.email),
              subtitle: Text(syncLine),
              isThreeLine: syncLine.contains('\n'),
              trailing: busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : TextButton(
                      onPressed: () {
                        sync.syncNow(reason: 'manual');
                        a.deviceState.syncNow().ignore(); // 베이 · 도감 손으로 켜기 등 기기 기록 · 내 사진 목록도
                        a.photoRestore.restore().ignore();
                      },
                      child: Text(tr('지금 동기화')),
                    ),
            ),
            ListTile(leading: const Icon(Icons.logout), title: Text(tr('로그아웃')), onTap: _signOut),
          ],
        ],
      ),
    );
  }

  /// K-1 · K-5 · K-6 알림
  Widget _notifySection() {
    final c = _n.config;
    Widget chip(String key) => FilterChip(
      label: Text(tr(notifyRuleLabels[key] ?? key)),
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
          SectionHeader(tr('알림')),
          SwitchListTile(
            // K-1 P03
            secondary: const Icon(Icons.notifications_none),
            title: Text(tr('새 소식 알림')),
            subtitle: blocked ? Text(tr('휴대폰 설정에서 알림이 꺼져 있어요')) : null,
            value: c.enabled && _permitted != false,
            activeThumbColor: Gp.accent,
            onChanged: _setNotify, // STATE: 알림 스위치 (저장 · 권한 요청)
          ),
          SwitchListTile(
            secondary: const Icon(Icons.filter_alt_outlined),
            title: Text(tr('내 채널 소식만')),
            value: c.onlyMine,
            activeThumbColor: Gp.accent,
            onChanged: _n.setOnlyMine, // STATE: 채널 범위 (저장)
          ),
          // K-5 어떤 새 상품이 나오면 알릴지 (켠 것만)
          chips(tr('이런 새 상품이 나오면 알림'), notifyInterestRules),
          chips(tr('이 채널 새 상품은 전부 알림'), notifyWorldRules),
          // 내가 만든 조건: 채널 · 작품(캐릭터) · 종류
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
            child: Text(
              tr('골라서 알림 (채널 · 작품 · 종류)'),
              style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
            ),
          ),
          for (final x in c.conditions)
            ListTile(
              dense: true,
              leading: const Icon(Icons.notifications_active_outlined, size: 20),
              title: Text(conditionLabel(x)),
              trailing: IconButton(
                tooltip: tr('지우기'),
                icon: const Icon(Icons.close, size: 18, color: Gp.faint),
                onPressed: () => _n.removeCondition(x.id), // STATE: 조건 지우기 (저장)
              ),
            ),
          ListTile(
            dense: true,
            leading: const Icon(Icons.add, size: 20, color: Gp.accent),
            title: Text(tr('조건 추가'), style: const TextStyle(color: Gp.accent)),
            onTap: () async {
              final x = await pickNotifyCondition(context);
              if (x != null) _n.addCondition(x); // STATE: 조건 추가 (저장)
            },
          ),
          ListTile(
            // K-6
            leading: const Icon(Icons.history),
            title: Text(tr('새 소식 확인')),
            subtitle: Text(_n.shortStatus),
            trailing: _n.checking
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : TextButton(onPressed: _checkNow, child: Text(tr('지금 확인'))),
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
      appBar: AppBar(title: Text(tr('설정'))),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          _accountPanel(account),
          SectionPanel(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(tr('데이터')),
                ListTile(
                  // K-4
                  leading: const Icon(Icons.storage_outlined), // 상자 = 미조립과 겹치지 않게
                  title: Text(tr('상품 데이터')),
                  subtitle: Text(
                    cat.kits.isEmpty
                        ? (cat.progress.isNotEmpty ? cat.progress : tr('아직 받지 않았어요'))
                        : trf('{date} · {n}개', {'date': dateDot(cat.updatedAt), 'n': cat.kits.length}),
                  ),
                  trailing: _refreshing
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : TextButton(onPressed: _refresh, child: Text(tr('지금 새로 받기'))),
                ),
                // 레고: 최근 정식 세트(2015~, 굿즈 · 책 · 폴리백 빼고) · 전부 (Rebrickable 2.8만 개)
                ListTile(
                  leading: const Icon(Icons.toys_outlined),
                  title: Text(tr('레고 범위')),
                  subtitle: Text(
                    UserStore.instance.legoScope == LegoScope.all
                        ? tr('Rebrickable 의 레고 전부 (굿즈 · 책 · 옛 세트까지)')
                        : trf('{year}년부터 나온 정식 세트 · 미니피규어', {'year': legoRecentFromYear}),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: SquareSegments<LegoScope>(
                    values: LegoScope.values,
                    current: UserStore.instance.legoScope,
                    child: (v) => Text(v == LegoScope.recent ? tr('최근 정식 세트') : tr('전부')),
                    // STATE: 레고 범위 (저장 · 동기화) — 목록은 Catalog 가 UserStore 를 듣고 다시 거른다
                    onPick: (v) => setState(() => UserStore.instance.setLegoScope(v)),
                  ),
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
                SectionHeader(tr('앱')),
                ListTile(
                  // K-2 화면 언어 — 한국어(기본) · 中文. 고르면 앱 전체가 그 언어로 다시 열린다 (lib/l10n)
                  key: const Key('settings-language'),
                  leading: const Icon(Icons.language),
                  title: Text(tr('언어')),
                  subtitle: Text(tr('화면 · 상품 이름 · 공지 번역 · 알림')),
                  trailing: Text(L10n.isZh ? '中文' : '한국어', style: const TextStyle(color: Gp.muted)),
                  onTap: () => _pickLanguage(context),
                ),
                ListTile(
                  // K-7
                  leading: const Icon(Icons.help_outline),
                  title: Text(tr('도움말')),
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
            Stack(
              fit: StackFit.expand,
              children: [
                // 늘 같은 색 — 상태는 표시로만
                Center(
                  child: Icon(icon, size: Gp.iM, color: Gp.ink),
                ),
                tierMarks(t, size: 14),
              ],
            ),
            radius: Gp.rSmall,
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
      appBar: AppBar(title: Text(tr('도움말'))),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          SectionPanel(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(tr('도감 칸')),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    cell(CellTier.none, Icons.image_outlined, tr('아직')),
                    cell(CellTier.liked, Icons.image_outlined, tr('♡ 좋아요')),
                    cell(CellTier.owned, Icons.image_outlined, tr('리본 구매함')),
                    cell(CellTier.photo, Icons.photo_camera_outlined, tr('내 사진')),
                  ],
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Gp.gutter),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [dot(Gp.accent, tr('파랑 = 고름 · 좋아요')), dot(Gp.own, tr('민트 = 가진 것'))],
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
                SectionHeader(tr('데이터')),
                tip(
                  Icons.cloud_download_outlined,
                  tr('상품 정보'),
                  tr('Gunpula 가 공식 사이트에서 매일 모아요 (BANDAI SPIRITS · 포켓몬센터 …)'),
                ),
                tip(Icons.toys_outlined, tr('레고 정보'), tr('Rebrickable (rebrickable.com) 의 레고 카탈로그 데이터를 써요')),
                tip(Icons.payments_outlined, tr('가격'), tr('일본 정가만 · 국내 시세는 상세에서 검색으로')),
                tip(Icons.flag_outlined, tr('틀린 정보'), tr('상품 상세 맨 아래 › 제보 (GitHub)')),
              ],
            ),
          ),
          SectionPanel(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(tr('알림')),
                tip(Icons.schedule, tr('12시간마다 확인'), tr('앱을 열 때도 한 번 더')),
                tip(Icons.today_outlined, tr('좋아요한 상품'), tr('발매 D-7 · D-1 · 당일 (발매일이 정해진 것만)')),
              ],
            ),
          ),
          SectionPanel(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(tr('앱 업데이트')),
                tip(Icons.system_update_outlined, tr('위 줄 ⬇ · 설정 › 앱 › 버전'), tr('새 빌드를 받아 안드로이드 설치 창으로')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
