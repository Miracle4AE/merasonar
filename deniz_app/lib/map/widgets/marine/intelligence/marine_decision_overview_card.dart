import 'package:deniz_app/domain/marine_intelligence_report.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/map/widgets/marine/intelligence/marine_intelligence_helpers.dart';
import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/widgets/premium/navigation/premium_hero_widgets.dart';
import 'package:deniz_app/widgets/premium/premium_card.dart';
import 'package:deniz_app/widgets/premium/premium_empty_state.dart';
import 'package:deniz_app/widgets/premium/premium_metric_chip.dart';
import 'package:deniz_app/widgets/premium/premium_status_badge.dart';
import 'package:flutter/material.dart';

class MarineDecisionOverviewCard extends StatelessWidget {
  const MarineDecisionOverviewCard({
    super.key,
    this.report,
  });

  final MarineIntelligenceReport? report;

  @override
  Widget build(BuildContext context) {
    if (report == null) {
      return PremiumEmptyState(
        title: kMarineDecisionEmptyTitle,
        icon: Icons.analytics_outlined,
      );
    }

    final decision = report!.decision;
    final goScore = decision?.goScore ?? report!.fishingScore.suitabilityScore;
    final fishingDecision = decision?.fishingDecision;
    final color = marinePremiumDecisionColor(fishingDecision);
    final label = marineDecisionLabelTr(fishingDecision);
    final riskScore = report!.fishingScore.riskScore;
    final confidencePct =
        (report!.fishingScore.confidence * 100).clamp(0, 100).toStringAsFixed(0);

    return PremiumCard(
      glow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(kMarineSectionDecision, style: AppTextStyles.cardTitle),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${report!.coordinate.lat.toStringAsFixed(5)}, '
            '${report!.coordinate.lon.toStringAsFixed(5)}',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              PremiumHeroGoScore(score: goScore, color: color),
              const SizedBox(width: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(kMarineGoScoreLabel, style: AppTextStyles.caption),
              ),
              const Spacer(),
              PremiumStatusBadge(
                label: label,
                tone: _toneForDecision(fishingDecision),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              if (decision?.waitScore != null)
                PremiumMetricChip(
                  label: kMarineWaitScoreLabel,
                  value: '${decision!.waitScore}',
                ),
              PremiumMetricChip(
                label: kMarineRiskLabel,
                value: '$riskScore',
                accentColor: AppColors.accentAmber,
              ),
              PremiumMetricChip(
                label: kMarineConfidenceLabel,
                value: '$confidencePct%',
              ),
            ],
          ),
          if (decision?.bestActionTr != null &&
              decision!.bestActionTr!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(decision.bestActionTr!, style: AppTextStyles.cardTitle),
          ],
          if (decision?.shortSummaryTr != null &&
              decision!.shortSummaryTr!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(decision.shortSummaryTr!, style: AppTextStyles.caption),
          ],
        ],
      ),
    );
  }

  PremiumStatusTone _toneForDecision(String? decision) {
    switch (decision) {
      case 'excellent':
      case 'good':
        return PremiumStatusTone.success;
      case 'borderline':
        return PremiumStatusTone.warning;
      case 'poor':
      case 'unsafe':
        return PremiumStatusTone.danger;
      default:
        return PremiumStatusTone.neutral;
    }
  }
}
