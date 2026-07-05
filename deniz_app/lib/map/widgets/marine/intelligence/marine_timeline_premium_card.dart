import 'package:deniz_app/domain/marine_intelligence_report.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/map/widgets/marine/intelligence/marine_intelligence_helpers.dart';
import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/theme/app_radius.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/utils/layout_breakpoints.dart';
import 'package:deniz_app/widgets/premium/premium_card.dart';
import 'package:deniz_app/widgets/premium/premium_status_badge.dart';
import 'package:flutter/material.dart';

class MarineTimelinePremiumCard extends StatelessWidget {
  const MarineTimelinePremiumCard({
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
    if (items.isEmpty) return const SizedBox.shrink();

    final horizontal = !useMobileLayout(context);

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(kMarineSectionDecisionTimeline, style: AppTextStyles.cardTitle),
          const SizedBox(height: AppSpacing.md),
          if (horizontal)
            SizedBox(
              height: 132,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, i) => SizedBox(
                  width: 168,
                  child: _TimelineSlot(
                    item: items[i],
                    highlight: _isHighlighted(items[i], i),
                    compact: true,
                  ),
                ),
              ),
            )
          else
            for (var i = 0; i < items.length; i++)
              Padding(
                padding: EdgeInsets.only(
                  bottom: i < items.length - 1 ? AppSpacing.sm : 0,
                ),
                child: _TimelineSlot(
                  item: items[i],
                  highlight: _isHighlighted(items[i], i),
                ),
              ),
        ],
      ),
    );
  }
}

class _TimelineSlot extends StatelessWidget {
  const _TimelineSlot({
    required this.item,
    required this.highlight,
    this.compact = false,
  });

  final MarineDecisionTimelineItem item;
  final bool highlight;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = marinePremiumDecisionColor(item.decision);
    final label = marineDecisionLabelTr(item.decision);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: highlight
            ? color.withValues(alpha: 0.08)
            : AppColors.surfaceElevated.withValues(alpha: 0.35),
        borderRadius: AppRadius.card,
        border: Border.all(
          color: highlight
              ? color.withValues(alpha: 0.45)
              : AppColors.borderSoft(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (compact)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.time,
                  style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
                ),
                if (highlight) ...[
                  const SizedBox(height: 4),
                  PremiumStatusBadge(
                    label: kMarineTimelineBestSlot,
                    tone: PremiumStatusTone.success,
                  ),
                ],
              ],
            )
          else
            Row(
              children: [
                Text(
                  item.time,
                  style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
                ),
                if (highlight) ...[
                  const Spacer(),
                  PremiumStatusBadge(
                    label: kMarineTimelineBestSlot,
                    tone: PremiumStatusTone.success,
                  ),
                ],
              ],
            ),
          const SizedBox(height: 4),
          Text(
            '${item.goScore ?? '—'} · $label',
            style: AppTextStyles.cardTitle.copyWith(color: color, fontSize: 13),
          ),
          if (item.riskScore != null)
            Text(
              '$kMarineRiskLabel: ${item.riskScore}',
              style: AppTextStyles.caption,
            ),
          if (!compact &&
              item.reasonTr != null &&
              item.reasonTr!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              item.reasonTr!,
              style: AppTextStyles.caption,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
