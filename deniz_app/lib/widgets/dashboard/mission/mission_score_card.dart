import 'package:deniz_app/domain/dashboard_overview.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/widgets/premium/navigation/premium_hero_widgets.dart';
import 'package:deniz_app/widgets/premium/premium_card.dart';
import 'package:deniz_app/widgets/premium/premium_empty_state.dart';
import 'package:deniz_app/widgets/premium/premium_metric_chip.dart';
import 'package:deniz_app/widgets/premium/premium_primary_button.dart';
import 'package:deniz_app/widgets/premium/premium_status_badge.dart';
import 'package:deniz_app/widgets/premium/settings/settings_ui_widgets.dart';
import 'package:flutter/material.dart';

class MissionScoreCard extends StatelessWidget {
  const MissionScoreCard({
    super.key,
    required this.report,
    required this.onMarineTap,
  });

  final DashboardMarineReportSummary report;
  final VoidCallback onMarineTap;

  @override
  Widget build(BuildContext context) {
    if (!report.hasData || report.missionScore == null) {
      return PremiumEmptyState(
        title: kMissionScoreTitle,
        subtitle: kMissionScoreEmpty,
        icon: Icons.radar_rounded,
        actionLabel: kMissionScoreCta,
        onAction: onMarineTap,
      );
    }

    final score = report.missionScore!;
    final decision = report.decisionLabel;

    return Semantics(
      label: kMissionScoreTitle,
      value: '$score',
      child: PremiumCard(
        glow: true,
        onTap: onMarineTap,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(kMissionScoreTitle, style: AppTextStyles.cardTitle),
                    if (settingsShowHelperTexts(context))
                      Text(kMissionScoreSubtitle, style: AppTextStyles.caption),
                  ],
                ),
              ),
              PremiumHeroGoScore(score: score, fontSize: 36),
            ],
          ),
          if (decision != null && decision.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            PremiumStatusBadge(
              label: '$kMissionDecisionLabel: $decision',
              tone: PremiumStatusTone.success,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              if (report.riskScore != null)
                PremiumMetricChip(
                  label: kMissionRiskLabel,
                  value: '${report.riskScore}',
                ),
              if (report.confidence != null)
                PremiumMetricChip(
                  label: kMissionConfidenceLabel,
                  value: report.confidence!.toStringAsFixed(2),
                ),
            ],
          ),
          if (settingsShowHelperTexts(context) &&
              report.bestActionTr != null &&
              report.bestActionTr!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '$kMissionBestActionLabel: ${report.bestActionTr}',
              style: AppTextStyles.caption,
              maxLines: 3,
            ),
          ] else if (settingsShowHelperTexts(context) &&
              report.advice.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(report.advice, style: AppTextStyles.caption, maxLines: 3),
          ],
          const SizedBox(height: AppSpacing.md),
          PremiumPrimaryButton(
            label: kMissionScoreCta,
            icon: Icons.analytics_outlined,
            onPressed: onMarineTap,
            expanded: true,
          ),
        ],
      ),
      ),
    );
  }
}
