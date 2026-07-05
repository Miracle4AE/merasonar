import 'package:deniz_app/domain/dashboard_overview.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/widgets/dashboard/v2/dashboard_v2_helpers.dart';
import 'package:deniz_app/widgets/premium/premium_card.dart';
import 'package:deniz_app/widgets/premium/premium_status_badge.dart';
import 'package:flutter/material.dart';

class DashboardV2CompareCard extends StatelessWidget {
  const DashboardV2CompareCard({
    super.key,
    required this.summary,
    this.onCompareTap,
  });

  final DashboardCompareSummary summary;
  final VoidCallback? onCompareTap;

  bool get _hasContent =>
      summary.hasData ||
      summary.winnerLabel.isNotEmpty ||
      summary.scoreDelta != 0;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tight = constraints.maxHeight < 130;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DashboardV2Helpers.cardHeader(kPremiumDashCompareTitle),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: ClipRect(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: constraints.maxWidth - AppSpacing.lg * 2,
                      child: _hasContent ? _contentView() : _emptyView(),
                    ),
                  ),
                ),
              ),
              if (_hasContent && !tight)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Center(
                    child: DashboardV2Helpers.compactSecondaryButton(
                      label: 'Detaylı Karşılaştırma',
                      onPressed: onCompareTap,
                      icon: Icons.compare_arrows_rounded,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _emptyView() {
    return DashboardV2Helpers.premiumEmpty(
      message: kPremiumDashCompareEmpty,
      ctaLabel: kPremiumDashCompareCta,
      onCta: onCompareTap,
      icon: Icons.compare_arrows,
      pattern: DashboardPlaceholderPattern.compareSplit,
    );
  }

  Widget _contentView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (summary.winnerLabel.isNotEmpty)
          Center(
            child: PremiumStatusBadge(
              label: '$kMissionMapWinner: ${summary.winnerLabel}',
              tone: PremiumStatusTone.success,
            ),
          ),
        if (summary.scoreDelta != 0) ...[
          const SizedBox(height: AppSpacing.xs),
          Center(
            child: Text(
              'Skor farkı: ${summary.scoreDelta.abs()}',
              style: AppTextStyles.caption.copyWith(fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        if (summary.leftLabel.isNotEmpty || summary.rightLabel.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              if (summary.leftLabel.isNotEmpty)
                Expanded(child: _pointChip('A', summary.leftLabel)),
              if (summary.leftLabel.isNotEmpty && summary.rightLabel.isNotEmpty)
                const SizedBox(width: AppSpacing.xs),
              if (summary.rightLabel.isNotEmpty)
                Expanded(child: _pointChip('B', summary.rightLabel)),
            ],
          ),
        ],
        if (summary.summaryTr.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            summary.summaryTr,
            style: AppTextStyles.caption.copyWith(fontSize: 9),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _pointChip(String letter, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.borderSoft(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$letter Noktası',
            style: AppTextStyles.caption.copyWith(
              fontSize: 8,
              color: AppColors.accentTeal,
            ),
          ),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(fontSize: 8),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
