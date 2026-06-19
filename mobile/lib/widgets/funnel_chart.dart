import 'package:flutter/material.dart';

import '../models/metrics.dart';

/// Lightweight, dependency-free funnel visualization.
///
/// Renders one horizontal bar per [FunnelStage] with width proportional to
/// its share of the largest bucket. Avoids pulling in chart packages so the
/// app stays small and the data updates instantly on pull-to-refresh.
class FunnelChart extends StatelessWidget {
  final List<FunnelStage> stages;
  final int max;

  const FunnelChart({super.key, required this.stages, required this.max});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (stages.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No funnel data yet',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < stages.length; i++)
          _FunnelRow(
            stage: stages[i],
            max: max,
            color: _colorFor(i),
            isLast: i == stages.length - 1,
          ),
      ],
    );
  }

  /// Color ramp from cool to warm as the lead moves closer to "active".
  Color _colorFor(int index) {
    const palette = [
      Color(0xFF94A3B8), // new - gray
      Color(0xFF0EA5E9), // initial - sky
      Color(0xFF3B82F6), // interested - blue
      Color(0xFFF59E0B), // pricing - amber
      Color(0xFFF97316), // ready - orange
      Color(0xFFEAB308), // payment - yellow
      Color(0xFF22C55E), // active - green
    ];
    return palette[index.clamp(0, palette.length - 1)];
  }
}

class _FunnelRow extends StatelessWidget {
  final FunnelStage stage;
  final int max;
  final Color color;
  final bool isLast;

  const _FunnelRow({
    required this.stage,
    required this.max,
    required this.color,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = max <= 0 ? 0.0 : (stage.count / max).clamp(0.0, 1.0);
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                stage.label,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              Text(
                '${stage.count}',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Stack(
            children: [
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: theme.dividerColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              FractionallySizedBox(
                widthFactor: ratio == 0 ? 0.0 : ratio,
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
