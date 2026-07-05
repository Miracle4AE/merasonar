import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/utils/layout_breakpoints.dart';
import 'package:deniz_app/widgets/premium/premium_glass_panel.dart';
import 'package:deniz_app/widgets/premium/premium_icon_button.dart';
import 'package:deniz_app/widgets/premium/premium_status_badge.dart';
import 'package:flutter/material.dart';

class MapPremiumTopBar extends StatelessWidget {
  const MapPremiumTopBar({
    super.key,
    required this.dataSourceLabel,
    required this.healthOk,
    required this.onRefresh,
    required this.onDownload,
    required this.onSettings,
    required this.onBackHome,
    this.modeBadgeLabel,
    this.gpsStatusLabel,
    this.gpsStatusTone = PremiumStatusTone.neutral,
    this.onNotifications,
    this.onProfile,
    this.busy = false,
  });

  final String? dataSourceLabel;
  final bool? healthOk;
  final VoidCallback onRefresh;
  final VoidCallback onDownload;
  final VoidCallback onSettings;
  final VoidCallback onBackHome;
  final String? modeBadgeLabel;
  final String? gpsStatusLabel;
  final PremiumStatusTone gpsStatusTone;
  final VoidCallback? onNotifications;
  final VoidCallback? onProfile;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final mobile = useMobileLayout(context);

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.sm,
          0,
        ),
        child: PremiumGlassPanel(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  children: [
                    PremiumIconButton(
                      key: const Key('btn_map_back_home'),
                      icon: Icons.arrow_back_rounded,
                      tooltip: kMapPremiumBackHome,
                      onPressed: onBackHome,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            kMapPremiumMapHeaderTitle,
                            style: AppTextStyles.sectionTitle.copyWith(
                              fontSize: mobile ? 14 : 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (modeBadgeLabel != null)
                            Text(
                              modeBadgeLabel!,
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 10,
                                color: AppColors.textMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    if (!mobile) ...[
                      if (gpsStatusLabel != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: PremiumStatusBadge(
                            label: gpsStatusLabel!,
                            tone: gpsStatusTone,
                          ),
                        ),
                      PremiumIconButton(
                        icon: Icons.refresh_rounded,
                        tooltip: kMarineActionRefresh,
                        onPressed: busy ? null : onRefresh,
                      ),
                      PremiumIconButton(
                        icon: Icons.download_rounded,
                        tooltip: kMapPremiumDownloadTooltip,
                        onPressed: onDownload,
                      ),
                      if (onNotifications != null)
                        PremiumIconButton(
                          icon: Icons.notifications_none_rounded,
                          tooltip: kMapPremiumNotificationsTooltip,
                          onPressed: onNotifications,
                        ),
                      PremiumIconButton(
                        icon: Icons.settings_outlined,
                        tooltip: kMapPremiumSettingsTooltip,
                        onPressed: onSettings,
                      ),
                      if (onProfile != null)
                        PremiumIconButton(
                          icon: Icons.person_outline_rounded,
                          tooltip: kMapPremiumProfileTooltip,
                          onPressed: onProfile,
                        ),
                    ] else
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded, size: 20),
                        onSelected: (value) {
                          switch (value) {
                            case 'refresh':
                              if (!busy) onRefresh();
                            case 'download':
                              onDownload();
                            case 'settings':
                              onSettings();
                            case 'notifications':
                              onNotifications?.call();
                            case 'profile':
                              onProfile?.call();
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'refresh',
                            enabled: !busy,
                            child: Text(kMarineActionRefresh),
                          ),
                          PopupMenuItem(
                            value: 'download',
                            child: Text(kMapPremiumDownloadTooltip),
                          ),
                          if (onNotifications != null)
                            PopupMenuItem(
                              value: 'notifications',
                              child: Text(kMapPremiumNotificationsTooltip),
                            ),
                          PopupMenuItem(
                            value: 'settings',
                            child: Text(kMapPremiumSettingsTooltip),
                          ),
                          if (onProfile != null)
                            PopupMenuItem(
                              value: 'profile',
                              child: Text(kMapPremiumProfileTooltip),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
              if (mobile && gpsStatusLabel != null) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: PremiumStatusBadge(
                    label: gpsStatusLabel!,
                    tone: gpsStatusTone,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              _DataSourceStrip(
                label: dataSourceLabel,
                healthOk: healthOk,
                compact: mobile,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DataSourceStrip extends StatelessWidget {
  const _DataSourceStrip({
    required this.label,
    required this.healthOk,
    required this.compact,
  });

  final String? label;
  final bool? healthOk;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: 4,
      alignment: WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          kMapPremiumDataSource,
          style: AppTextStyles.caption.copyWith(fontSize: compact ? 10 : 11),
        ),
        PremiumStatusBadge(
          label: label ?? kMapPremiumLiveApi,
          tone: PremiumStatusTone.neutral,
        ),
        if (healthOk != null)
          PremiumStatusBadge(
            label: healthOk!
                ? kMapPremiumProviderHealthy
                : kMapPremiumProviderOffline,
            tone: healthOk!
                ? PremiumStatusTone.success
                : PremiumStatusTone.danger,
          ),
      ],
    );
  }
}
