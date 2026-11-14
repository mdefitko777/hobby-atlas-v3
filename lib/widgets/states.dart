// 불러오는 중 · 오류 · 빈 목록 — GET 을 쓰는 화면은 모두 이 세 상태를 그린다 (P01 · P09)
import 'package:flutter/material.dart';

import '../data/catalog.dart' show Catalog;
import '../l10n/l10n.dart';
import '../theme.dart';

/// 로딩 상태
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label});

  /// 없으면 '불러오는 중…' — 막 더한 채널을 받는 중이면 「{channel} 상품 받는 중 · 3.2 MB」
  /// (채널은 고르면 그때 처음 받아서, 큰 채널은 몇십 초 걸린다). 한 줄로 — 상세의 120 높이 칸에도 들어가게
  final String? label;

  @override
  Widget build(BuildContext context) {
    if (label case final l?) return _body(l);
    final c = Catalog.instance;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => c.channelStep.isEmpty
          ? _body(tr('불러오는 중…'))
          : _body('${c.channelStep} · ${(c.channelBytes / (1024 * 1024)).toStringAsFixed(1)} MB', oneLine: true),
    );
  }

  Widget _body(String text, {bool oneLine = false}) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniSpinner(),
          const SizedBox(height: 12),
          Text(
            text,
            maxLines: oneLine ? 1 : null,
            overflow: oneLine ? TextOverflow.ellipsis : null,
            style: const TextStyle(color: Gp.muted),
          ),
        ],
      ),
    ),
  );
}

/// 오류 상태: 무엇이 잘못됐는지 + 다시 시도 버튼
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, this.title, this.message = '', required this.onRetry});

  /// 없으면 '정보를 불러오지 못했어요'
  final String? title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: Gp.iXL, color: Gp.ink),
            const SizedBox(height: 12),
            Text(
              title ?? tr('정보를 불러오지 못했어요'),
              style: const TextStyle(fontSize: Gp.t16, fontWeight: FontWeight.w700),
            ),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Gp.muted),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: Gp.iM),
              label: Text(tr('다시 시도')),
            ),
          ],
        ),
      ),
    );
  }
}

/// 빈 상태: 왜 비었는지 + (있으면) 다음에 할 일 버튼
class EmptyView extends StatelessWidget {
  const EmptyView({super.key, this.message, this.detail = '', this.icon = Icons.inbox_outlined, this.action});

  /// 없으면 '표시할 항목이 없어요'
  final String? message;
  final String detail;
  final IconData icon;

  /// 예: 필터 초기화 · 채널 추가 버튼
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: Gp.iXL, color: Gp.faint),
            const SizedBox(height: 12),
            Text(
              message ?? tr('표시할 항목이 없어요'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (detail.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Gp.muted),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 14), action!],
          ],
        ),
      ),
    );
  }
}

/// 작은 돌아가는 원 — 불러오기 · 확인 중 (LoadingView · 시트 · 대화 상자 공통)
class MiniSpinner extends StatelessWidget {
  const MiniSpinner({super.key, this.size = 22, this.color = Gp.ink});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CircularProgressIndicator(strokeWidth: size * 0.11, color: color),
  );
}
