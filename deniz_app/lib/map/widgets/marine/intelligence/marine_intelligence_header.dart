import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/widgets/premium/premium_card.dart';
import 'package:deniz_app/widgets/premium/premium_status_badge.dart';
import 'package:flutter/material.dart';

class MarineIntelligenceHeader extends StatelessWidget {
  const MarineIntelligenceHeader({
    super.key,
    this.offlineCached = false,
    this.spotsSyncedAt,
    this.reportUpdatedAt,
    this.cacheHit = false,
    this.partialData = false,
  });

  final bool offlineCached;
  final String? spotsSyncedAt;
  final String? reportUpdatedAt;
  final bool cacheHit;
  final bool partialData;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      glow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(kMarineScreenTitle, style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.sm),
          Text(kHomeCardMarineSubtitle, style: AppTextStyles.caption),
          if (offlineCached) ...[
            const SizedBox(height: AppSpacing.md),
            PremiumStatusBadge(
              label: kMarineOfflineCachedBanner,
              tone: PremiumStatusTone.warning,
            ),
          ],
          if (spotsSyncedAt != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '$kMarineStaleBanner $spotsSyncedAt',
              style: AppTextStyles.caption,
            ),
          ],
          if (reportUpdatedAt != null && reportUpdatedAt!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '$kPremiumDashUpdatedLabel: $reportUpdatedAt',
              style: AppTextStyles.caption,
            ),
          ],
          if (cacheHit || partialData) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (cacheHit)
                  const PremiumStatusBadge(label: kMarineCacheHitBadge),
                if (partialData)
                  PremiumStatusBadge(
                    label: kMarinePartialDataBadge,
                    tone: PremiumStatusTone.warning,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
