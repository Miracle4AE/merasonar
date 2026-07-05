import 'package:deniz_app/domain/marine_intelligence_report.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/map/widgets/marine/intelligence/marine_intelligence_helpers.dart';
import 'package:flutter/material.dart';

/// Saatlik karar zaman çizelgesi — hourly forecast serisine bağlanabilir.
class MarineForecastTimeline extends StatelessWidget {
  const MarineForecastTimeline({
    super.key,
    required this.items,
  });

  final List<MarineDecisionTimelineItem> items;

  bool _isHighlighted(MarineDecisionTimelineItem item, int index) {
    if (item.isBestSlot) return (item.goScore ?? 0) >= 50;
    if (items.any((e) => e.isBestSlot)) return false;
    var bestIdx = 0;
    var bestScore = items.first.goScore ?? -1;
    for (var i = 1; i < items.length; i++) {
      final score = items[i].goScore ?? -1;
      if (score > bestScore) {
        bestScore = score;
        bestIdx = i;
      }
    }
    return index == bestIdx && (item.goScore ?? 0) >= 60;
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text(kMarinePlaceholderFuture, style: const TextStyle(color: Colors.white54));
    }
    return Card(
      color: const Color(0xFF142434),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              kMarineSectionDecisionTimeline,
              style: const TextStyle(
                color: Color(0xFF80DEEA),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < items.length; i++)
              _TimelineRow(
                item: items[i],
                highlight: _isHighlighted(items[i], i),
              ),
          ],
        ),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.item,
    this.highlight = false,
  });

  final MarineDecisionTimelineItem item;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final color = marinePremiumDecisionColor(item.decision);
    final label = marineDecisionLabelTr(item.decision);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: highlight ? const EdgeInsets.all(8) : EdgeInsets.zero,
      decoration: highlight
          ? BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Text(
              item.time,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${item.goScore ?? '—'}',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: TextStyle(color: color, fontSize: 12),
                    ),
                    if (item.riskScore != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        'Risk ${item.riskScore}',
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                    if (highlight) ...[
                      const SizedBox(width: 8),
                      Text(
                        kMarineTimelineBestSlot,
                        style: TextStyle(color: color, fontSize: 10),
                      ),
                    ],
                  ],
                ),
                if (item.reasonTr != null && item.reasonTr!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      item.reasonTr!,
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
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
