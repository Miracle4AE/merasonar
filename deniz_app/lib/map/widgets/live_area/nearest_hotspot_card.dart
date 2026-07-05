import 'package:deniz_app/api_service.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/widgets/premium/premium_card.dart';
import 'package:deniz_app/widgets/premium/premium_empty_state.dart';
import 'package:deniz_app/widgets/premium/premium_metric_chip.dart';
import 'package:deniz_app/widgets/premium/premium_primary_button.dart';
import 'package:flutter/material.dart';

class NearestHotspotCard extends StatelessWidget {
  const NearestHotspotCard({
    super.key,
    required this.coordinateMode,
    required this.loading,
    this.hotspot,
    this.needsCalibrationMessage,
    this.onCalibrateTap,
    this.onOpenMapTap,
    this.showEmptyNoAnalysis = false,
    this.waitingForScore = false,
  });

  final String coordinateMode;
  final bool loading;
  final LiveNearestHotspot? hotspot;
  final String? needsCalibrationMessage;
  final VoidCallback? onCalibrateTap;
  final VoidCallback? onOpenMapTap;
  final bool showEmptyNoAnalysis;
  final bool waitingForScore;

  static const geoReferenced = 'geo_referenced';

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      onTap: hotspot != null ? onOpenMapTap : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(kNearbyHotspotTitle, style: AppTextStyles.cardTitle),
          const SizedBox(height: AppSpacing.md),
          _buildContent(),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (needsCalibrationMessage != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(needsCalibrationMessage!, style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.md),
          PremiumPrimaryButton(
            key: const Key('btn_calibrate_map'),
            label: kCalibrateMapButton,
            icon: Icons.map_outlined,
            onPressed: onCalibrateTap,
            expanded: true,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(kCalibrateMapMicroExplanation, style: AppTextStyles.caption),
        ],
      );
    }

    if (waitingForScore) {
      return Text(kNearbyNeedsGpsScore, style: AppTextStyles.caption);
    }

    if (showEmptyNoAnalysis) {
      return PremiumEmptyState(
        title: kLiveHotspotEmptyTitle,
        subtitle: kLiveHotspotEmptyBody,
        icon: Icons.radar_outlined,
        actionLabel: kLiveHotspotCtaScan,
        onAction: onCalibrateTap ?? onOpenMapTap,
      );
    }

    if (loading && hotspot == null) {
      return Text(kNearbyLoadingMatch, style: AppTextStyles.caption);
    }

    if (hotspot == null) {
      return PremiumEmptyState(
        title: kLiveHotspotEmptyTitle,
        subtitle: kNearbyNoHotspotAlign,
        icon: Icons.place_outlined,
        actionLabel: kLiveHotspotCtaMap,
        onAction: onOpenMapTap,
      );
    }

    final n = hotspot!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PremiumMetricChip(
          label: kNearestMarkId,
          value: '${n.id ?? "—"}',
        ),
        const SizedBox(height: AppSpacing.sm),
        PremiumMetricChip(
          label: kDistanceM,
          value: '${n.distanceM.toStringAsFixed(1)} m',
        ),
        if (n.recommendationRank != null) ...[
          const SizedBox(height: AppSpacing.sm),
          PremiumMetricChip(
            label: kRecommendationRank,
            value: '${n.recommendationRank}',
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        PremiumMetricChip(
          label: kLiveHotspotTrustLabel,
          value: kLiveHotspotTrustFromAnalysis,
        ),
        if (onOpenMapTap != null) ...[
          const SizedBox(height: AppSpacing.md),
          PremiumPrimaryButton(
            label: kLiveHotspotCtaMap,
            icon: Icons.map_outlined,
            onPressed: onOpenMapTap,
            expanded: true,
          ),
        ],
      ],
    );
  }
}
