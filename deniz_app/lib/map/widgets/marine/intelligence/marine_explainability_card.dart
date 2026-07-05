import 'package:deniz_app/domain/marine_intelligence_report.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/widgets/premium/premium_card.dart';
import 'package:deniz_app/widgets/premium/premium_status_badge.dart';
import 'package:flutter/material.dart';

class MarineExplainabilityCard extends StatelessWidget {
  const MarineExplainabilityCard({
    super.key,
    required this.explain,
  });

  final MarineExplainability explain;

  bool get _hasContent =>
      explain.positiveFactors.isNotEmpty ||
      explain.negativeFactors.isNotEmpty ||
      explain.uncertaintyFactors.isNotEmpty ||
      (explain.explanationSummaryTr?.isNotEmpty ?? false);

  @override
  Widget build(BuildContext context) {
    if (!_hasContent) return const SizedBox.shrink();

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(kMarineSectionExplain, style: AppTextStyles.cardTitle),
          if (explain.explanationSummaryTr?.isNotEmpty ?? false) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(explain.explanationSummaryTr!, style: AppTextStyles.cardTitle),
          ],
          if (explain.positiveFactors.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(kMarineExplainPositive, style: AppTextStyles.caption),
            const SizedBox(height: AppSpacing.sm),
            _FactorWrap(factors: explain.positiveFactors),
          ],
          if (explain.negativeFactors.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(kMarineExplainNegative, style: AppTextStyles.caption),
            const SizedBox(height: AppSpacing.sm),
            _FactorWrap(factors: explain.negativeFactors),
          ],
          if (explain.uncertaintyFactors.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(kMarineExplainUncertainty, style: AppTextStyles.caption),
            const SizedBox(height: AppSpacing.sm),
            _FactorWrap(factors: explain.uncertaintyFactors),
          ],
        ],
      ),
    );
  }
}

class _FactorWrap extends StatelessWidget {
  const _FactorWrap({required this.factors});

  final List<String> factors;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final f in factors)
          PremiumStatusBadge(
            label: f,
            tone: PremiumStatusTone.neutral,
          ),
      ],
    );
  }
}
