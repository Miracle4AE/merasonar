import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/widgets/premium/premium_card.dart';
import 'package:deniz_app/widgets/premium/premium_status_badge.dart';
import 'package:flutter/material.dart';

class LiveAreaHeaderCard extends StatelessWidget {
  const LiveAreaHeaderCard({
    super.key,
    this.connectionBadge,
    this.gpsStatusLabel,
    this.lastUpdateLabel,
  });

  final Widget? connectionBadge;
  final String? gpsStatusLabel;
  final String? lastUpdateLabel;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      glow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(kLiveAreaAppBarTitle, style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.sm),
          Text(kHomeCardLiveSubtitle, style: AppTextStyles.caption),
          if (connectionBadge != null) ...[
            const SizedBox(height: AppSpacing.md),
            connectionBadge!,
          ],
          if (gpsStatusLabel != null || lastUpdateLabel != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (gpsStatusLabel != null)
                  PremiumStatusBadge(label: gpsStatusLabel!),
                if (lastUpdateLabel != null)
                  PremiumStatusBadge(
                    label: '$kPremiumDashUpdatedLabel: $lastUpdateLabel',
                    tone: PremiumStatusTone.neutral,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
