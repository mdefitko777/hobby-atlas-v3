// 수집 레벨 한 벌 — 왼쪽 위 아바타 옆 Lv · 레벨 시트 · 도감 화면이 같은 막대 · 같은 ? 를 쓴다.
// 경험치: 구매 10 · 도감 새 칸 5 · 사진 인증 3 · 좋아요 0 (lib/logic/level_math.dart collectorXp)
import 'package:flutter/material.dart';

import 'api.dart';
import 'data/user_store.dart';
import 'l10n/l10n.dart';
import 'logic/level_math.dart';
import 'marks.dart';
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
      // 레벨 색은 그대로, 위쪽을 조금 밝게 + 같은 색 그림자 (빛 받은 듯)
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Gp.rSmall),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(levelColor(level), Colors.white, 0.25)!, levelColor(level)],
        ),
        boxShadow: [
          BoxShadow(color: levelColor(level).withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Text(
        'Lv.$level',
        style: TextStyle(fontSize: small ? Gp.t11 : Gp.t12, fontWeight: FontWeight.w700, color: Colors.white),
      ),
    );
  }
}

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

/// ? — 칸 단계와 경험치만 짧게 (레벨 시트 · 도감 같은 내용). 모양은 다른 화면의 ? (HelpButton) 와 같다
class LevelHelpButton extends StatelessWidget {
  const LevelHelpButton({super.key});

  @override
  Widget build(BuildContext context) => HelpButton.sheet(title: tr('레벨 · 도감'), builder: (_) => const _LevelHelp());
}

const _tierSample = 'assets/gp/units/g3000u00100.webp';

/// 도감 칸 견본 (늘 컬러 + 켜진 표시) — ? 도움말 줄 · 레벨 시트 · 설정 도움말
Widget tierSample(CellTier t, {double size = 32}) => SizedBox.square(
  dimension: size,
  child: tierFrame(
    t,
    Stack(
      fit: StackFit.expand,
      children: [
        cellImage(t, _tierSample, null),
        tierMarks(t, size: size * 0.36),
      ],
    ),
    radius: Gp.rSmall,
  ),
);

/// 도감 칸 그림 한 개 (? 도움말 줄)
Widget tierHelpCell(CellTier t) => tierSample(t);

/// 도감 칸 표시 + 경험치 — 컬렉션 · 작품 도감의 ? 에 같이 넣는다
List<HelpItem> tierHelpItems() => [
  HelpItem.widget(tierHelpCell(CellTier.none), tr('그림 그대로 = 아직 (칸은 늘 컬러)')),
  HelpItem.widget(tierHelpCell(CellTier.liked), tr('♡ = 좋아요 · 0')),
  HelpItem.widget(tierHelpCell(CellTier.owned), tr('리본 = 구매함 · +10')),
  HelpItem(Icons.grid_view_rounded, tr('도감 새 칸 · +5'), color: Gp.own),
  HelpItem.widget(tierHelpCell(CellTier.photo), tr('내 사진 + 도는 고리 = 사진 인증 · +3')),
];

class _LevelHelp extends StatelessWidget {
  const _LevelHelp();

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
    Widget tier(CellTier t) => tierSample(t, size: 40);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            row(tier(CellTier.liked), tr('♡ 좋아요'), '0'),
            row(tier(CellTier.owned), tr('구매함'), '+10'),
            row(const Icon(Icons.grid_view_rounded, color: Gp.own, size: Gp.iL), tr('도감 새 칸'), '+5'),
            row(tier(CellTier.photo), tr('사진 인증'), '+3'),
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
Future<void> showLevelSheet(BuildContext context, Loaders loaders) => showGpSheet<void>(
  context,
  heightFactor: gpSheetHeight,
  builder: (_) => FutureBuilder<LevelData>(
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
                ? const Center(
                    child: Icon(Icons.grid_view_rounded, size: Gp.iXL, color: Gp.line),
                  )
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
                              radius: Gp.radius,
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
