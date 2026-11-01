// 수집 레벨 한 벌 — 왼쪽 위 아바타 옆 Lv · 레벨 시트 · 도감 화면이 같은 막대 · 같은 ? 를 쓴다.
// 경험치: 구매 10 · 도감 새 칸 5 · 사진 인증 3 · 좋아요 0 (models.dart collectorXp)
import 'package:flutter/material.dart';

import 'api.dart';
import 'data/user_store.dart';
import 'marks.dart';
import 'models.dart';
import 'theme.dart';
import 'widgets.dart';

/// 레벨 색 — 10레벨마다 바뀐다: 회색 · 초록 · 파랑 · 보라 · 금색 · 빨강(50+)
Color levelColor(int level) => Gp.levelTiers[(level ~/ 10).clamp(0, Gp.levelTiers.length - 1)];

/// Lv 표 (레벨 색) — My Page · 도감 레벨 막대 · 친구 서랍
class LevelChip extends StatelessWidget {
  const LevelChip({super.key, required this.level, this.small = false});
  final int level;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 6 : 9, vertical: small ? 1 : 3),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(Gp.rSmall), color: levelColor(level)),
      child: Text(
        'Lv.$level',
        style: TextStyle(fontSize: small ? Gp.t11 : Gp.t12, fontWeight: FontWeight.w700, color: Colors.white),
      ),
    );
  }
}

/// 도감 칸 단계 — 흑백 · 컬러(좋아요) · 초록 테두리(구매) · 도는 고리(사진 인증)
enum CellTier { none, liked, owned, photo }

/// 단계별 칸 틀 (도감 칸 · ? 견본 공통)
Widget tierFrame(CellTier tier, Widget child, {double radius = 12}) {
  final photo = tier == CellTier.photo;
  final inner = Container(
    decoration: BoxDecoration(
      color: Gp.panel,
      borderRadius: BorderRadius.circular(photo ? radius - 2 : radius),
      border: switch (tier) {
        CellTier.photo => null,
        CellTier.owned => Border.all(color: Gp.own, width: 2.2), // 가진 것 = 민트
        _ => Border.all(color: Gp.line),
      },
    ),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
  return photo ? AccentRing(radius: radius, spin: true, child: inner) : inner;
}

/// 칸 안 그림: 내 사진이면 꽉 채우고, 아니면 공식 그림 (없음 = 흑백)
Widget cellImage(CellTier tier, String image, String? photo) => tier == CellTier.photo && photo != null
    ? AppImage(photo)
    : Padding(
        padding: const EdgeInsets.all(6),
        child: AppImage(image, fit: BoxFit.contain, grayscale: tier == CellTier.none),
      );

/// 레벨 시트의 한 칸 (도감 작품 · 세대 · 라인)
typedef LitSeries = ({String title, String image, int owned, int total});

/// 레벨 계산 재료
class LevelData {
  const LevelData({required this.owned, required this.lit, required this.series});
  final int owned;
  final int lit;
  final List<LitSeries> series;

  int get xp => collectorXp(owned: owned, lit: lit);
}

/// 내 채널의 도감에서 켜진 칸을 모은다 (건담 = 작품, 그 밖 = 세계관 묶음)
Future<LevelData> loadLevel(Loaders loaders) async {
  final me = UserStore.instance;
  final series = <LitSeries>[];
  var lit = 0;
  try {
    for (final w in await loaders.guideWorks()) {
      lit += w.owned;
      if (w.owned > 0) series.add((title: w.name, image: w.image, owned: w.owned, total: w.total));
    }
  } on Object {
    // 도감 데이터가 없으면 구매 수만으로
  }
  for (final ch in me.myChannels.where((c) => c != 'gundam')) {
    try {
      for (final w in await loaders.worlds(ch)) {
        if (w.owned > 0) series.add((title: w.label, image: w.image, owned: w.owned, total: w.total));
      }
    } on Object {
      // 그 채널만 건너뛴다
    }
  }
  series.sort((a, b) => b.owned.compareTo(a.owned));
  return LevelData(owned: me.ownedCount, lit: lit, series: series);
}

/// 레벨 막대 — Lv 표 · 경험치 막대 · 남은 양 · ? (도감 화면 · 레벨 시트 공통)
class LevelBar extends StatelessWidget {
  const LevelBar({super.key, required this.xp, this.padding = const EdgeInsets.fromLTRB(16, 6, 16, 12)});
  final int xp;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final lv = levelOf(xp);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
            child: LevelChip(key: ValueKey(lv.level), level: lv.level),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: lv.need == 0 ? 0 : lv.into / lv.need),
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => AccentBar(value: v, height: 6),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${lv.into} / ${lv.need}',
            style: const TextStyle(fontSize: Gp.t11, color: Gp.muted),
          ),
          const LevelHelpButton(),
        ],
      ),
    );
  }
}

/// ? — 칸 단계와 경험치만 짧게 (레벨 시트 · 도감 같은 내용)
class LevelHelpButton extends StatelessWidget {
  const LevelHelpButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: '레벨 · 도감',
    visualDensity: VisualDensity.compact,
    onPressed: () =>
        showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (_) => const _LevelHelp()),
    icon: const Icon(Icons.help_outline, size: Gp.iM, color: Gp.muted),
  );
}

class _LevelHelp extends StatelessWidget {
  const _LevelHelp();

  static const _sample = 'assets/gp/units/g3000u00100.webp';

  @override
  Widget build(BuildContext context) {
    Widget row(Widget cell, String label, String xp) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox.square(dimension: 40, child: cell),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: Gp.t14)),
          ),
          Text(
            xp,
            style: const TextStyle(fontSize: Gp.t14, fontWeight: FontWeight.w700, color: Gp.accent),
          ),
        ],
      ),
    );
    Widget tier(CellTier t) => tierFrame(t, cellImage(t, _sample, null), radius: 9);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            row(tier(CellTier.liked), '♡ 좋아요', '0'),
            row(tier(CellTier.owned), '구매함', '+10'),
            row(const Icon(Icons.grid_view_rounded, color: Gp.own, size: Gp.iL), '도감 새 칸', '+5'),
            row(tier(CellTier.photo), '사진 인증', '+3'),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final (i, lv) in const [1, 10, 20, 30, 40, 50].indexed) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: Center(child: LevelChip(level: lv, small: true)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 왼쪽 위 아바타 옆 Lv — 누르면 레벨 시트
class LevelButton extends StatefulWidget {
  const LevelButton({super.key, required this.loaders});
  final Loaders loaders;

  @override
  State<LevelButton> createState() => _LevelButtonState();
}

class _LevelButtonState extends State<LevelButton> {
  Future<LevelData>? _data;
  int _rev = -1;

  @override
  Widget build(BuildContext context) {
    final rev = Marks.of(context).version; // 구매함이 바뀌면 다시 센다
    if (rev != _rev || _data == null) {
      _rev = rev;
      _data = loadLevel(widget.loaders);
    }
    return FutureBuilder<LevelData>(
      future: _data,
      builder: (context, snap) {
        final xp = snap.data?.xp ?? collectorXp(owned: UserStore.instance.ownedCount);
        return InkWell(
          borderRadius: BorderRadius.circular(Gp.rSmall),
          onTap: () => showLevelSheet(context, widget.loaders),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: LevelChip(level: levelOf(xp).level),
          ),
        );
      },
    );
  }
}

/// 레벨 시트 — 막대 + 켜진 도감 (작품 그림 · 모은 칸 / 전체)
Future<void> showLevelSheet(BuildContext context, Loaders loaders) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => FractionallySizedBox(
    heightFactor: 0.6,
    child: FutureBuilder<LevelData>(
      future: loadLevel(loaders),
      builder: (context, snap) {
        final d = snap.data;
        if (d == null) return const LoadingView();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LevelBar(xp: d.xp, padding: const EdgeInsets.fromLTRB(16, 0, 8, 8)),
            const Divider(height: 1),
            Expanded(
              child: d.series.isEmpty
                  ? const Center(child: Icon(Icons.grid_view_rounded, size: 40, color: Gp.line))
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.82,
                      ),
                      itemCount: d.series.length,
                      itemBuilder: (context, i) {
                        final s = d.series[i];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: tierFrame(
                                CellTier.owned,
                                Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: AppImage(s.image, fit: BoxFit.contain),
                                ),
                                radius: 10,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              s.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: Gp.t12),
                            ),
                            Text(
                              '${s.owned} / ${s.total}',
                              style: const TextStyle(fontSize: Gp.t12, fontWeight: FontWeight.w700, color: Gp.own),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        );
      },
    ),
  ),
);

/// 레벨 막대 (구매함이 바뀌면 다시 센다) — 도감 화면 위쪽
class LiveLevelBar extends StatefulWidget {
  const LiveLevelBar({super.key, required this.loaders});
  final Loaders loaders;

  @override
  State<LiveLevelBar> createState() => _LiveLevelBarState();
}

class _LiveLevelBarState extends State<LiveLevelBar> {
  Future<LevelData>? _data;
  int _rev = -1;

  @override
  Widget build(BuildContext context) {
    final rev = Marks.of(context).version;
    if (rev != _rev || _data == null) {
      _rev = rev;
      _data = loadLevel(widget.loaders);
    }
    return FutureBuilder<LevelData>(
      future: _data,
      builder: (context, snap) => LevelBar(xp: snap.data?.xp ?? collectorXp(owned: UserStore.instance.ownedCount)),
    );
  }
}
