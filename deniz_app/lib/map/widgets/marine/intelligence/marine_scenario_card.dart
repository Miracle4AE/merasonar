import 'package:deniz_app/domain/marine_intelligence_report.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/map/widgets/marine/intelligence/marine_intelligence_helpers.dart';
import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/widgets/premium/premium_card.dart';
import 'package:deniz_app/widgets/premium/premium_status_badge.dart';
import 'package:flutter/material.dart';

class MarineScenarioCard extends StatelessWidget {
  const MarineScenarioCard({
    super.key,
    required this.scenario,
    this.mostSensitiveFactorTr,
  });

  final MarineScenarioBundle scenario;
  final String? mostSensitiveFactorTr;

  @override
  Widget build(BuildContext context) {
    if (scenario.items.isEmpty) return const SizedBox.shrink();

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(kMarineSectionScenario, style: AppTextStyles.cardTitle),
          if (mostSensitiveFactorTr != null &&
              mostSensitiveFactorTr!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '$kMarineMostSensitivePrefix $mostSensitiveFactorTr',
              style: AppTextStyles.caption.copyWith(color: AppColors.accentAmber),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          for (final item in scenario.items) _ScenarioRow(item: item),
        ],
      ),
    );
  }
}

class _ScenarioRow extends StatelessWidget {
  const _ScenarioRow({required this.item});

  final MarineScenarioItem item;

  @override
  Widget build(BuildContext context) {
    final label = marineDecisionLabelTr(item.decision);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.titleTr, style: AppTextStyles.cardTitle),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              PremiumStatusBadge(
                label: label,
                tone: PremiumStatusTone.neutral,
              ),
              Text(
                '$kMarineGoScoreDeltaLabel: ${formatMarineDeltaScore(item.deltaGoScore)}',
                style: AppTextStyles.caption,
              ),
              Text(
                '$kMarineRiskDeltaLabel: ${formatMarineDeltaScore(item.deltaRiskScore)}',
                style: AppTextStyles.caption,
              ),
            ],
          ),
          if (item.deltaSummaryTr != null && item.deltaSummaryTr!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(item.deltaSummaryTr!, style: AppTextStyles.caption),
            ),
        ],
      ),
    );
  }
}
