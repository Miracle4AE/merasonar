import 'package:deniz_app/domain/dashboard_overview.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/map/widgets/marine/marine_report_cards.dart';
import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/widgets/premium/premium_card.dart';
import 'package:deniz_app/widgets/premium/premium_empty_state.dart';
import 'package:deniz_app/widgets/premium/premium_status_badge.dart';
import 'package:flutter/material.dart';

class MissionDecisionTimelinePanel extends StatelessWidget {
  const MissionDecisionTimelinePanel({
    super.key,
    required this.summary,
    required this.onMarineTap,
  });

  final DashboardTimelineSummary summary;
  final VoidCallback onMarineTap;

  @override
  Widget build(BuildContext context) {
    if (!summary.hasData) {
      return PremiumEmptyState(
        title: kMissionTimelineTitle,
        subtitle: kMissionTimelineEmpty,
        icon: Icons.schedule_outlined,
        actionLabel: kMissionScoreCta,
        onAction: onMarineTap,
      );
    }

    final best = summary.slots.isNotEmpty ? summary.slots.first : null;

    return PremiumCard(
      onTap: onMarineTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(kMissionTimelineTitle, style: AppTextStyles.cardTitle),
              ),
              if (best != null)
                PremiumStatusBadge(
                  label: kMissionTimelineBestWindow,
                  tone: PremiumStatusTone.success,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (final slot in summary.slots.take(6))
            _TimelineRow(
              time: slot.time,
              label: slot.label,
              decision: slot.decision,
              highlight: slot == best,
            ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.time,
    required this.label,
    required this.decision,
    this.highlight = false,
  });

  final String time;
  final String label;
  final String? decision;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final color = marineDecisionColor(decision);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Text(time, style: AppTextStyles.caption),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: highlight ? AppColors.accentTeal : null,
                fontWeight: highlight ? FontWeight.w600 : null,
              ),
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}
