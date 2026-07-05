import 'package:deniz_app/domain/dashboard_overview.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/widgets/dashboard/v2/dashboard_v2_helpers.dart';
import 'package:deniz_app/widgets/premium/premium_card.dart';
import 'package:flutter/material.dart';

class DashboardV2SummaryCard extends StatelessWidget {
  const DashboardV2SummaryCard({
    super.key,
    required this.report,
    this.onMarineTap,
  });

  final DashboardMarineReportSummary report;
  final VoidCallback? onMarineTap;

  @override
  Widget build(BuildContext context) {
    final hasData = report.hasData;

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DashboardV2Helpers.cardHeader(kPremiumDashSummaryTitle),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: hasData ? _dataView() : _emptyView(),
          ),
        ],
      ),
    );
  }

  Widget _emptyView() {
    return DashboardV2Helpers.premiumEmpty(
      message: kPremiumDashMarineEmpty,
      ctaLabel: kPremiumDashMarineCta,
      onCta: onMarineTap,
      pattern: DashboardPlaceholderPattern.sparkline,
    );
  }

  Widget _dataView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tight = constraints.maxHeight < 96;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (report.advice.isNotEmpty)
                    _bullet(report.advice, maxLines: tight ? 1 : 2),
                  if (!tight &&
                      report.bestActionTr != null &&
                      report.bestActionTr!.isNotEmpty)
                    _bullet(report.bestActionTr!, maxLines: 1),
                  if (!tight && report.decisionLabel != null)
                    _bullet(
                      '$kMissionDecisionLabel: ${report.decisionLabel}',
                      maxLines: 1,
                    ),
                ],
              ),
            ),
            SizedBox(
              height: tight ? 34 : 40,
              child: Row(
                children: [
                  _metricBox(
                    'Rüzgar',
                    report.windLabel ??
                        report.weatherLabel ??
                        kPremiumDashPlaceholderDash,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _metricBox(
                    'Akıntı',
                    report.currentLabel ?? kPremiumDashPlaceholderDash,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _metricBox(
                    'Dalga',
                    report.waveLabel ?? kPremiumDashPlaceholderDash,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _bullet(String text, {int maxLines = 2}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: AppTextStyles.caption.copyWith(fontSize: 11)),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.caption.copyWith(fontSize: 11),
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricBox(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.borderSoft(alpha: 0.15)),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: AppTextStyles.caption.copyWith(fontSize: 11)),
              Text(
                value,
                style: AppTextStyles.cardTitle.copyWith(fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
