import 'package:deniz_app/domain/dashboard_overview.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/widgets/premium/premium_map_preview_card.dart';
import 'package:deniz_app/widgets/premium/premium_primary_button.dart';
import 'package:deniz_app/widgets/premium/premium_status_badge.dart';
import 'package:flutter/material.dart';

class MissionMapPreviewPanel extends StatelessWidget {
  const MissionMapPreviewPanel({
    super.key,
    required this.data,
    required this.onMapTap,
    required this.onCompareTap,
    required this.onMarineTap,
  });

  final DashboardMapPreviewData data;
  final VoidCallback onMapTap;
  final VoidCallback onCompareTap;
  final VoidCallback onMarineTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(kMissionMapActiveTitle, style: AppTextStyles.sectionTitle),
            ),
            if (data.hotspotCount != null && data.hotspotCount! > 0)
              PremiumStatusBadge(
                label: '${data.hotspotCount} $kMissionMapHotspots',
                tone: PremiumStatusTone.neutral,
              ),
            if (data.winnerLabel != null && data.winnerLabel!.isNotEmpty) ...[
              const SizedBox(width: AppSpacing.sm),
              PremiumStatusBadge(
                label: '$kMissionMapWinner: ${data.winnerLabel}',
                tone: PremiumStatusTone.success,
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        PremiumMapPreviewCard(data: data, onExpandTap: onMapTap),
        const SizedBox(height: AppSpacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              PremiumPrimaryButton(
                label: kPremiumDashMapCta,
                icon: Icons.map_outlined,
                onPressed: onMapTap,
              ),
              const SizedBox(width: AppSpacing.sm),
              PremiumPrimaryButton(
                label: kMarineCompareButton,
                icon: Icons.compare_arrows,
                onPressed: onCompareTap,
              ),
              const SizedBox(width: AppSpacing.sm),
              PremiumPrimaryButton(
                label: kMissionScoreCta,
                icon: Icons.analytics_outlined,
                onPressed: onMarineTap,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
