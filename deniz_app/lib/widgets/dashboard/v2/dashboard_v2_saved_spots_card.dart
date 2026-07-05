import 'package:deniz_app/domain/dashboard_overview.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/services/dashboard_overview_service.dart';
import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/widgets/dashboard/v2/dashboard_v2_helpers.dart';
import 'package:deniz_app/widgets/premium/premium_card.dart';
import 'package:deniz_app/widgets/premium/premium_metric_chip.dart';
import 'package:flutter/material.dart';

class DashboardV2SavedSpotsCard extends StatelessWidget {
  const DashboardV2SavedSpotsCard({
    super.key,
    required this.summary,
    this.onMarineTap,
  });

  final DashboardSavedSpotsSummary summary;
  final VoidCallback? onMarineTap;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DashboardV2Helpers.cardHeader(kPremiumDashSpotsTitle),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: summary.hasData
                ? ListView.separated(
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: summary.items.take(3).length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSpacing.xs),
                    itemBuilder: (context, index) {
                      final spot = summary.items[index];
                      return _spotRow(spot);
                    },
                  )
                : DashboardV2Helpers.premiumEmpty(
                    message: kPremiumDashSpotsEmpty,
                    ctaLabel: kPremiumDashSpotsCta,
                    onCta: onMarineTap,
                    icon: Icons.bookmark_outline,
                    pattern: DashboardPlaceholderPattern.sparkline,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _spotRow(DashboardSavedSpotItem spot) {
    final updated = spot.lastReportAt ?? spot.updatedAt;
    final timeLabel = DashboardOverviewService.formatRelativeTime(updated);
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.borderSoft(alpha: 0.15)),
          ),
          child: Icon(
            spot.favorite ? Icons.star_rounded : Icons.place_outlined,
            size: 16,
            color: spot.favorite ? AppColors.accentAmber : AppColors.textMuted,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                spot.name,
                style: AppTextStyles.cardTitle.copyWith(fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                timeLabel,
                style: AppTextStyles.caption.copyWith(fontSize: 9),
              ),
            ],
          ),
        ),
        if (spot.score != null)
          PremiumMetricChip(
            label: kPremiumDashScoreLabel,
            value: '${spot.score}',
            accentColor: DashboardV2Helpers.scoreColor(spot.score),
          ),
      ],
    );
  }
}
