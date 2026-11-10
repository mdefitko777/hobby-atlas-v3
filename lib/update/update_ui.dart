// 앱 업데이트 화면 조각 — 위 줄 ⬇ 아이콘 · 업데이트 시트(바뀐 점 · 받기 진행률) · 앱을 열 때 한 번 묻기
import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets.dart';
import 'app_update.dart';

/// 위 줄 🔔 옆 — 새 빌드가 있을 때만 보인다 (빨간 점). 누르면 업데이트 시트
class UpdateButton extends StatelessWidget {
  const UpdateButton({super.key, this.update});
  final AppUpdate? update;

  @override
  Widget build(BuildContext context) {
    final u = update ?? AppUpdate.instance;
    return ListenableBuilder(
      listenable: u,
      builder: (context, _) {
        final info = u.available;
        if (info == null) return const SizedBox.shrink();
        return IconButton(
          tooltip: '업데이트',
          onPressed: () => showUpdateSheet(context, info, update: u),
          icon: Badge(
            smallSize: 8,
            backgroundColor: Gp.danger,
            child: Icon(u.progress == null ? Icons.system_update_alt : Icons.downloading, color: Gp.ink),
          ),
        );
      },
    );
  }
}

/// 앱을 열 때: 큰 업데이트이고 아직 안 물어본 빌드면 시트 한 번 (나중에 → ⬇ 아이콘만 남음)
Future<void> askUpdateOnce(BuildContext context, {AppUpdate? update}) async {
  final u = update ?? AppUpdate.instance;
  final info = await u.check();
  if (info == null || !await u.shouldAsk(info) || !context.mounted) return;
  await u.markAsked(info);
  if (context.mounted) await showUpdateSheet(context, info, update: u);
}

AppLifecycleListener? _resumeWatch;

/// 앱으로 돌아올 때 ⬇ 확인 (한 시간에 한 번 — 켤 때 오프라인이라 못 봤으면 돌아올 때 바로 다시). 앱 셸이 한 번 부른다.
void watchUpdateOnResume({AppUpdate? update}) {
  if (!AppUpdate.supported) return;
  _resumeWatch ??= AppLifecycleListener(onResume: () => (update ?? AppUpdate.instance).check().ignore());
}

/// 업데이트 시트 — 바뀐 점 + [나중에 · 업데이트]. 받는 동안 진행률, 다 받으면 안드로이드 설치 창
Future<void> showUpdateSheet(BuildContext context, UpdateInfo info, {AppUpdate? update}) {
  final u = update ?? AppUpdate.instance;
  return showGpSheet<void>(
    context,
    tall: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
        child: ListenableBuilder(
          listenable: u,
          builder: (context, _) {
            final p = u.progress;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.system_update_alt, color: Gp.accent, size: Gp.iL),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        '새 버전이 있어요',
                        style: TextStyle(fontSize: Gp.t16, fontWeight: FontWeight.w700),
                      ),
                    ),
                    SoftTag(info.versionLabel),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  joinDot(['지금 $appVersionLabel', dateDot(info.builtAt), info.sizeLabel]),
                  style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
                ),
                if (info.notes.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text(
                    '바뀐 점',
                    style: TextStyle(fontSize: Gp.t12, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  for (final n in info.notes)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '· $n',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: Gp.t12, color: Gp.ink, height: 1.4),
                      ),
                    ),
                ],
                if (u.error.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    u.error,
                    style: const TextStyle(fontSize: Gp.t12, color: Gp.danger),
                  ),
                ],
                const SizedBox(height: 18),
                if (p != null) ...[
                  // STATE: 받는 중 → 진행률
                  ClipRRect(
                    borderRadius: BorderRadius.circular(Gp.rSmall),
                    child: LinearProgressIndicator(value: p / 100, minHeight: 6),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '받는 중 $p% · 다 받으면 설치 창이 떠요',
                    style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
                  ),
                ] else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(sheet),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(46),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.all(Radius.circular(Gp.radius)),
                            ),
                          ),
                          child: const Text('나중에'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GradientButton(
                          label: '업데이트',
                          onPressed: AppUpdate.supported ? () => u.start(info) : null, // STATE: 받기 시작
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 8),
                const Text(
                  '처음 한 번은 "이 출처의 앱 설치 허용"을 켜야 해요 · 내 기록은 그대로예요',
                  style: TextStyle(fontSize: Gp.t11, color: Gp.faint),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

/// 설정 › 앱 › 버전 — 지금 빌드 + 누르면 업데이트 확인
class VersionTile extends StatefulWidget {
  const VersionTile({super.key, this.update});
  final AppUpdate? update;

  @override
  State<VersionTile> createState() => _VersionTileState();
}

class _VersionTileState extends State<VersionTile> {
  bool _checking = false;

  Future<void> _check() async {
    final u = widget.update ?? AppUpdate.instance;
    if (!AppUpdate.supported) {
      showToast(context, '이 빌드는 앱 안 업데이트를 쓰지 않아요');
      return;
    }
    setState(() => _checking = true); // STATE: 확인 중
    final info = await u.check(force: true);
    if (!mounted) return;
    setState(() => _checking = false);
    if (info == null) {
      // 못 받은 것을 「최신」이라고 하지 않는다
      showToast(context, u.checkFailed ? '업데이트를 확인하지 못했어요 · 인터넷 연결을 확인해 주세요' : '최신 버전이에요');
    } else {
      await showUpdateSheet(context, info, update: u);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.update ?? AppUpdate.instance;
    return ListenableBuilder(
      listenable: u,
      builder: (context, _) => ListTile(
        leading: const Icon(Icons.info_outline),
        title: const Text('버전'),
        subtitle: Text(
          u.available == null
              ? 'Hobby Atlas · $appVersionLabel'
              : 'Hobby Atlas · $appVersionLabel → ${u.available!.versionLabel} 있음',
        ),
        trailing: _checking
            ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : Text('업데이트 확인 ›', style: TextStyle(color: u.available == null ? Gp.muted : Gp.accent)),
        onTap: _checking ? null : _check,
      ),
    );
  }
}
