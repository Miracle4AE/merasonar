import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/map/widgets/live_area/live_area_rating_helpers.dart';
import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/widgets/premium/premium_card.dart';
import 'package:deniz_app/widgets/premium/premium_empty_state.dart';
import 'package:deniz_app/widgets/premium/premium_loading_skeleton.dart';
import 'package:deniz_app/widgets/premium/premium_metric_chip.dart';
import 'package:deniz_app/widgets/premium/premium_status_badge.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// GPS durumu — [PermissionState] live_area_screen ile uyumlu.
enum LiveAreaPermissionState {
  unknown,
  granted,
  denied,
  deniedForever,
  serviceOff,
  unavailable,
}

class GpsStatusCard extends StatelessWidget {
  const GpsStatusCard({
    super.key,
    this.gpsError,
    this.permissionState = LiveAreaPermissionState.unknown,
    this.latitude,
    this.longitude,
    this.accuracyM,
    this.lastFixLabel,
    this.loading = false,
    this.onOpenLocationSettings,
    this.onRequestPermission,
    this.onOpenAppSettings,
    this.onRetry,
  });

  final String? gpsError;
  final LiveAreaPermissionState permissionState;
  final double? latitude;
  final double? longitude;
  final double? accuracyM;
  final String? lastFixLabel;
  final bool loading;
  final VoidCallback? onOpenLocationSettings;
  final VoidCallback? onRequestPermission;
  final VoidCallback? onOpenAppSettings;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(kLiveCurrentPositionTitle, style: AppTextStyles.cardTitle),
          const SizedBox(height: AppSpacing.md),
          if (loading && gpsError == null && latitude == null)
            const PremiumLoadingSkeleton(height: 88)
          else if (gpsError != null)
            _buildError(context)
          else if (latitude == null || longitude == null)
            PremiumEmptyState(
              title: kLiveGpsEmptyTitle,
              subtitle: kGpsWaiting,
              icon: Icons.gps_not_fixed_rounded,
            )
          else
            _buildFix(context),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PremiumEmptyState(
          title: kLiveGpsEmptyTitle,
          subtitle: gpsError,
          icon: Icons.location_off_outlined,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (permissionState == LiveAreaPermissionState.serviceOff)
          TextButton.icon(
            onPressed: onOpenLocationSettings ?? Geolocator.openLocationSettings,
            icon: const Icon(Icons.location_searching_rounded, size: 18),
            label: const Text(kOpenLocationSettings),
          ),
        if (permissionState == LiveAreaPermissionState.denied)
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: onRequestPermission,
                child: const Text(kRequestLocationAgain),
              ),
              TextButton(
                onPressed: onOpenAppSettings ?? Geolocator.openAppSettings,
                child: const Text(kAppSettings),
              ),
            ],
          ),
        if (permissionState == LiveAreaPermissionState.deniedForever)
          TextButton.icon(
            onPressed: onOpenAppSettings ?? Geolocator.openAppSettings,
            icon: const Icon(Icons.settings_outlined, size: 18),
            label: const Text(kOpenAppSettingsLocationDenied),
          ),
        if (permissionState == LiveAreaPermissionState.unavailable)
          TextButton(
            onPressed: onRetry,
            child: const Text(kRetry),
          ),
      ],
    );
  }

  Widget _buildFix(BuildContext context) {
    final trust = liveAreaGpsTrustLabel(accuracyM);
    final trustColor = liveAreaGpsTrustColor(accuracyM);
    final poorAccuracy = accuracyM != null && accuracyM!.isFinite && accuracyM! > 50;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            PremiumMetricChip(label: kLabelLatitude, value: latitude!.toStringAsFixed(6)),
            PremiumMetricChip(label: kLabelLongitude, value: longitude!.toStringAsFixed(6)),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (accuracyM != null && accuracyM!.isFinite)
          PremiumMetricChip(
            label: kLabelGpsAccuracy,
            value: '${accuracyM!.toStringAsFixed(1)} m',
            accentColor: trustColor,
          ),
        const SizedBox(height: AppSpacing.sm),
        PremiumStatusBadge(
          label: '$kLiveGpsTrustTitle: $trust',
          tone: poorAccuracy
              ? PremiumStatusTone.warning
              : PremiumStatusTone.success,
        ),
        if (poorAccuracy) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            kGpsAccuracyHighSuffix,
            style: AppTextStyles.caption.copyWith(color: AppColors.accentAmber),
          ),
        ],
        if (lastFixLabel != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            '$kLabelLastUpdate: $lastFixLabel',
            style: AppTextStyles.caption,
          ),
        ],
      ],
    );
  }
}
