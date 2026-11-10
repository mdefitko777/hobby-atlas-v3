// 내 숫자 줄 — My Page(A-21) · 내 정보(I-4) 공용: 평평한 한 줄 (수집 ♡ · 리본 · 미조립 | 돈 이번 달 · 총).
// 떠 있는 판 · 굵은 숫자로 튀어나오지 않게 — 바탕 위에 아이콘 + 숫자만, 묶음 사이 가는 세로 줄
import 'package:flutter/material.dart';

import '../format.dart';
import '../l10n/l10n.dart';
import '../logic/build_status.dart' show BuildStage;
import '../theme.dart';
import 'icons.dart';
import 'kit_progress.dart' show buildStageIcon;

/// 숫자 칸 하나 — 아이콘(18 높이) + 숫자 t14 (보통 굵기 · 옅은 색), 길게 누르면 [tip]
class StatCell {
  const StatCell(this.icon, this.value, this.tip, {this.onTap});
  final Widget icon;
  final String value;
  final String tip;
  final VoidCallback? onTap;
}

/// 숫자 묶음들 — 묶음 사이 가는 세로 줄, 칸 너비는 묶음마다 같게(flex = 칸 수). [trailing] = 줄 끝 (공유 카드)
class StatGroups extends StatelessWidget {
  const StatGroups({super.key, required this.groups, this.trailing});
  final List<List<StatCell>> groups;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    Widget cell(StatCell c) => Expanded(
      child: Tooltip(
        message: c.tip,
        child: InkWell(
          onTap: c.onTap,
          borderRadius: BorderRadius.circular(Gp.radius),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Column(
              children: [
                SizedBox(height: 18, child: Center(child: c.icon)),
                const SizedBox(height: 3),
                Text(
                  c.value,
                  style: const TextStyle(fontSize: Gp.t14, color: Gp.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    Widget group(List<StatCell> cells) => Expanded(
      flex: cells.length,
      child: Material(
        type: MaterialType.transparency,
        child: Row(children: [for (final c in cells) cell(c)]),
      ),
    );
    return IntrinsicHeight(
      child: Row(
        children: [
          for (var i = 0; i < groups.length; i++) ...[
            if (i > 0) const VerticalDivider(width: 17, indent: 12, endIndent: 12),
            group(groups[i]),
          ],
          ?trailing,
        ],
      ),
    );
  }
}

/// 내 수집 · 지출 숫자 다섯 칸 (♡ · 리본 · 미조립 | 이번 달 · 총 지출) — 누르면 그 목록
class CollectionStats extends StatelessWidget {
  const CollectionStats({
    super.key,
    required this.liked,
    required this.owned,
    required this.backlog,
    required this.month,
    required this.total,
    this.onLiked,
    this.onOwned,
    this.onBacklog,
    this.onShare,
  });
  final int liked, owned, backlog, month, total;
  final VoidCallback? onLiked, onOwned, onBacklog;

  /// 주면 줄 끝에 공유 카드 아이콘
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) => StatGroups(
    groups: [
      [
        StatCell(const LikedIcon(), '$liked', tr('좋아요'), onTap: onLiked),
        StatCell(const OwnedIcon(), '$owned', tr('구매함'), onTap: onOwned),
        StatCell(
          Icon(buildStageIcon(BuildStage.unbuilt), size: Gp.iS, color: Gp.muted),
          '$backlog',
          tr('미조립'),
          onTap: onBacklog,
        ),
      ],
      [
        StatCell(
          const Icon(Icons.calendar_month_outlined, size: Gp.iS, color: Gp.muted),
          wonShort(month),
          tr('이번 달 지출'),
        ),
        StatCell(
          const Icon(Icons.account_balance_wallet_outlined, size: Gp.iS, color: Gp.muted),
          wonShort(total),
          tr('총 지출'),
        ),
      ],
    ],
    trailing: onShare == null
        ? null
        : IconButton(
            key: const ValueKey('mypage-share'),
            tooltip: tr('공유 카드'),
            visualDensity: VisualDensity.compact,
            onPressed: onShare,
            icon: const Icon(Icons.ios_share, size: Gp.iM, color: Gp.muted),
          ),
  );
}
