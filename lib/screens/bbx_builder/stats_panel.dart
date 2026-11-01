// T-6 능력치 (화면 T 의 한 부분)
part of '../t_bbx_builder_screen.dart';

class _StatsPanel extends StatelessWidget {
  const _StatsPanel({required this.stats, required this.catalog});
  final ComboStats stats;
  final BbxCatalog catalog;

  @override
  Widget build(BuildContext context) {
    final max = catalog.comboStatMax;
    final w = stats.weightG;
    final weight = w != null
        ? '무게 ${bbxGrams(w)}'
        : stats.unknownWeightSlots.isNotEmpty
        ? '무게 ${bbxGrams(stats.knownWeightG)}+ (모르는 칸: ${stats.unknownWeightSlots.map(bbxSlotLabel).join(' · ')})'
        : '무게 ${bbxGrams(stats.knownWeightG)} (아직 덜 고름)';
    return SectionPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            joinDot([weight, bbxSpinLabel(stats.spin)]),
            key: const Key('bbx-weight'),
            style: const TextStyle(fontSize: Gp.t12, color: Gp.muted, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          for (final k in BbxStats.keys)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: Text(
                      bbxStatLabels[k]!,
                      style: const TextStyle(fontSize: Gp.t12, color: Gp.muted),
                    ),
                  ),
                  Expanded(child: AccentBar(value: max[k] == 0 ? 0 : stats.stats[k] / max[k], height: 6)),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${stats.stats[k]}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: Gp.t12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
