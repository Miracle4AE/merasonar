import 'package:deniz_app/domain/dashboard_overview.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/services/dashboard_overview_service.dart';
import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/widgets/premium/premium_metric_chip.dart';
import 'package:deniz_app/widgets/premium/premium_status_badge.dart';
import 'package:flutter/material.dart';

class MissionCommandHeader extends StatelessWidget {
  const MissionCommandHeader({
    super.key,
    required this.overview,
    required this.onRefresh,
    this.offlineMessage,
  });

  final DashboardOverview overview;
  final VoidCallback onRefresh;
  final String? offlineMessage;

  @override
  Widget build(BuildContext context) {
    final mr = overview.marineReport;
    final hasMission = overview.hasActiveMission;
    final location = overview.location.hasLocation
        ? (overview.location.label ?? kPremiumDashPlaceholderDash)
        : kPremiumDashNoLocation;
    final updated = mr.updatedAt != null
        ? DashboardOverviewService.formatRelativeTime(mr.updatedAt)
        : kPremiumDashNoData;
    final captainStatus = overview.captainAtlas.hasData
        ? kPremiumCaptainResponding
        : kPremiumCaptainReady;
    final stale = mr.cacheHit == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(kMissionControlTitle, style: AppTextStyles.heroTitle),
                  const SizedBox(height: 4),
                  Text(kMissionControlSubtitle, style: AppTextStyles.caption),
                ],
              ),
            ),
            IconButton(
              tooltip: kPremiumDashRefresh,
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              color: AppColors.textSecondary,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            PremiumStatusBadge(
              label: DashboardOverviewService.connectionStatusLabel(
                overview.connectionStatus,
              ),
              tone: _connectionTone(overview.connectionStatus),
            ),
            PremiumStatusBadge(
              label: captainStatus,
              tone: overview.captainAtlas.hasData
                  ? PremiumStatusTone.success
                  : PremiumStatusTone.neutral,
            ),
            if (stale)
              PremiumStatusBadge(
                label: kMissionStaleData,
                tone: PremiumStatusTone.warning,
              ),
            if (!hasMission)
              PremiumStatusBadge(
                label: kMissionNoActiveMission,
                tone: PremiumStatusTone.neutral,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            PremiumMetricChip(label: kMissionLastUpdate, value: updated),
            PremiumMetricChip(label: kPremiumHeaderLocation, value: location),
            PremiumMetricChip(
              label: kMissionSystemBackend,
              value: overview.connectionStatus ==
                      DashboardConnectionStatus.connected
                  ? kMissionSystemOnline
                  : kMissionSystemOffline,
            ),
          ],
        ),
        if (offlineMessage != null) ...[
          const SizedBox(height: AppSpacing.sm),
          PremiumStatusBadge(
            label: offlineMessage!,
            tone: PremiumStatusTone.warning,
          ),
        ],
      ],
    );
  }

  PremiumStatusTone _connectionTone(DashboardConnectionStatus status) {
    switch (status) {
      case DashboardConnectionStatus.connected:
        return PremiumStatusTone.success;
      case DashboardConnectionStatus.disconnected:
        return PremiumStatusTone.danger;
      case DashboardConnectionStatus.checking:
      case DashboardConnectionStatus.unknown:
        return PremiumStatusTone.warning;
    }
  }
}
