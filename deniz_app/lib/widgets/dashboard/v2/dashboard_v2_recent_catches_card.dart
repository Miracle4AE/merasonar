import 'package:deniz_app/domain/dashboard_overview.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/widgets/dashboard/v2/dashboard_v2_helpers.dart';
import 'package:deniz_app/widgets/premium/premium_card.dart';
import 'package:flutter/material.dart';

class DashboardV2RecentCatchesCard extends StatelessWidget {
  const DashboardV2RecentCatchesCard({
    super.key,
    required this.summary,
    this.onMarineTap,
  });

  final DashboardRecentCatchesSummary summary;
  final VoidCallback? onMarineTap;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DashboardV2Helpers.cardHeader(kPremiumDashCatchesTitle),
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
                      final c = summary.items[index];
                      return _catchRow(c);
                    },
                  )
                : DashboardV2Helpers.premiumEmpty(
                    message: kPremiumDashCatchesEmptyLong,
                    ctaLabel: kPremiumDashCatchesCta,
                    onCta: onMarineTap,
                    icon: Icons.set_meal_outlined,
                    pattern: DashboardPlaceholderPattern.sparkline,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _catchRow(DashboardCatchItem c) {
    final weight = c.weightKg != null
        ? '${c.weightKg!.toStringAsFixed(1)} kg'
        : null;
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(
            Icons.set_meal_outlined,
            size: 16,
            color: AppColors.accentTeal,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c.species,
                style: AppTextStyles.cardTitle.copyWith(fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                [
                  ?weight,
                  if (c.caughtAt.isNotEmpty) c.caughtAt,
                ].join(' · '),
                style: AppTextStyles.caption.copyWith(fontSize: 9),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
