import 'package:deniz_app/domain/dashboard_overview.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/services/dashboard_overview_service.dart';
import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/utils/layout_breakpoints.dart';
import 'package:deniz_app/widgets/backend_connection_badge.dart';
import 'package:deniz_app/widgets/dashboard/v2/dashboard_v2_performance_mode_button.dart';
import 'package:deniz_app/widgets/premium/premium_icon_button.dart';
import 'package:deniz_app/widgets/premium/premium_status_badge.dart';
import 'package:flutter/material.dart';

/// Kompakt üst durum şeridi — konum, hava, ay, gelgit, aksiyonlar.
class DashboardV2TopStatusBar extends StatelessWidget {
  const DashboardV2TopStatusBar({
    super.key,
    required this.overview,
    this.serverIp = '',
    this.connectionBadge,
    this.onConnectionTap,
    this.onSettingsTap,
    this.onPrivacyTap,
    this.onMenuTap,
  });

  final DashboardOverview overview;
  final String serverIp;
  final BackendConnectionBadgeData? connectionBadge;
  final VoidCallback? onConnectionTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onPrivacyTap;
  final VoidCallback? onMenuTap;

  @override
  Widget build(BuildContext context) {
    final mobile = useMobileLayout(context);
    final loc = overview.location.hasLocation
        ? (overview.location.label ?? kPremiumDashNoLocation)
        : (serverIp.isNotEmpty ? serverIp : kPremiumDashNoLocation);
    final weather =
        overview.marineReport.weatherLabel ?? kPremiumDashPlaceholderDash;
    final moon = overview.marineReport.moonLabel ?? kPremiumDashPlaceholderDash;
    final tide = overview.marineReport.tideLabel ??
        overview.tide.label ??
        kPremiumDashPlaceholderDash;
    final connection = DashboardOverviewService.connectionStatusLabel(
      overview.connectionStatus,
    );

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundNavy.withValues(alpha: 0.9),
        border: Border(
          bottom: BorderSide(color: AppColors.borderSoft(alpha: 0.14)),
        ),
      ),
      child: Row(
        children: [
          if (mobile && onMenuTap != null) ...[
            PremiumIconButton(icon: Icons.menu, onPressed: onMenuTap),
            const SizedBox(width: 2),
          ],
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _statusChip('$kPremiumHeaderLocation: $loc'),
                  const SizedBox(width: 6),
                  _statusChip('$kPremiumHeaderWeather: $weather'),
                  const SizedBox(width: 6),
                  _statusChip('$kPremiumHeaderMoon: $moon'),
                  const SizedBox(width: 6),
                  _statusChip('$kPremiumHeaderTide: $tide'),
                  const SizedBox(width: 6),
                  PremiumStatusBadge(
                    label: connection,
                    tone: overview.connectionStatus ==
                            DashboardConnectionStatus.connected
                        ? PremiumStatusTone.success
                        : overview.connectionStatus ==
                                DashboardConnectionStatus.disconnected
                            ? PremiumStatusTone.warning
                            : PremiumStatusTone.neutral,
                  ),
                ],
              ),
            ),
          ),
          if (connectionBadge != null && !mobile)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: BackendConnectionBadge(
                  data: connectionBadge!,
                  onTap: onConnectionTap,
                ),
              ),
            ),
          const DashboardV2PerformanceModeButton(),
          PremiumIconButton(icon: Icons.search, onPressed: () {}),
          PremiumIconButton(icon: Icons.notifications_none, onPressed: () {}),
          if (onPrivacyTap != null)
            PremiumIconButton(
              icon: Icons.privacy_tip_outlined,
              onPressed: onPrivacyTap,
            ),
          if (onSettingsTap != null)
            PremiumIconButton(
              icon: Icons.settings_outlined,
              onPressed: onSettingsTap,
            ),
          const SizedBox(width: 2),
          CircleAvatar(
            radius: 13,
            backgroundColor: AppColors.surfaceElevated,
            child: Icon(Icons.person_outline, size: 15, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String label) {
    return PremiumStatusBadge(label: label);
  }
}
