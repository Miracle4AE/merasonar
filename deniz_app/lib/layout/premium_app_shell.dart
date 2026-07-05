import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../l10n/app_strings_tr.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../utils/layout_breakpoints.dart';
import '../widgets/backend_connection_badge.dart';
import '../navigation/captain_atlas_launcher.dart';
import '../widgets/premium/captain_atlas_hero_card.dart';
import '../widgets/premium/premium_icon_button.dart';
import '../widgets/premium/premium_sidebar_item.dart';
import '../widgets/premium/premium_status_badge.dart';

/// Drawer açma ve shell aksiyonları — dashboard top bar için.
class PremiumShellScope extends InheritedWidget {
  const PremiumShellScope({
    super.key,
    required this.openDrawer,
    required super.child,
  });

  final VoidCallback openDrawer;

  static PremiumShellScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<PremiumShellScope>();
  }

  @override
  bool updateShouldNotify(covariant PremiumShellScope oldWidget) =>
      openDrawer != oldWidget.openDrawer;
}

/// Premium app shell — sidebar, header, content.
class PremiumAppShell extends StatefulWidget {
  const PremiumAppShell({
    super.key,
    required this.child,
    required this.selectedSectionId,
    required this.onSectionSelected,
    required this.serverIp,
    this.connectionBadge,
    this.onConnectionTap,
    this.onSettingsTap,
    this.onPrivacyTap,
    this.healthChecking = false,
    this.hideEnvironmentChips = false,
    this.suppressTopHeader = false,
  });

  final Widget child;
  final String selectedSectionId;
  final ValueChanged<String> onSectionSelected;
  final String serverIp;
  final BackendConnectionBadgeData? connectionBadge;
  final VoidCallback? onConnectionTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onPrivacyTap;
  final bool healthChecking;
  final bool hideEnvironmentChips;
  /// Dashboard modunda shell üst barını gizler (tek status bar).
  final bool suppressTopHeader;

  @override
  State<PremiumAppShell> createState() => _PremiumAppShellState();
}

class _PremiumAppShellState extends State<PremiumAppShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  static const _sections = [
    _NavSection('overview', kPremiumSidebarOverview, Icons.dashboard_outlined),
    _NavSection('live', kPremiumSidebarLive, Icons.navigation_outlined),
    _NavSection('marine', kPremiumSidebarMarine, Icons.waves_outlined),
    _NavSection('map', kPremiumSidebarMap, Icons.map_outlined),
    _NavSection('spots', kPremiumSidebarSpots, Icons.bookmark_outline),
    _NavSection('catches', kPremiumSidebarCatches, Icons.set_meal_outlined),
    _NavSection('compare', kPremiumSidebarCompare, Icons.compare_arrows),
    _NavSection('timeline', kPremiumSidebarTimeline, Icons.schedule_outlined),
    _NavSection('settings', kPremiumSidebarSettings, Icons.settings_outlined),
  ];

  void _select(String id) {
    widget.onSectionSelected(id);
    if (useMobileLayout(context)) {
      _scaffoldKey.currentState?.closeDrawer();
    }
  }

  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();

  Widget _sidebarContent({required bool compact}) {
    return Container(
      color: AppColors.backgroundNavy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xxl,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.radar_rounded,
                  color: AppColors.accentTeal,
                  size: compact ? 22 : 26,
                ),
                if (!compact) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppConfig.productName,
                      style: AppTextStyles.dashboardTitle.copyWith(fontSize: 18),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              children: [
                for (final s in _sections)
                  PremiumSidebarItem(
                    icon: s.icon,
                    label: s.label,
                    iconOnly: compact,
                    selected: widget.selectedSectionId == s.id,
                    onTap: () => _select(s.id),
                  ),
              ],
            ),
          ),
          if (!compact)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.lg,
              ),
              child: CaptainAtlasHeroCard(
                title: kPremiumCaptainCardTitle,
                body: kPremiumCaptainCardMessage,
                actionLabel: kPremiumCaptainAskButton,
                actionKey: const Key('btn_sidebar_captain_atlas'),
                useHeroAvatar: true,
                compactSidebar: true,
                onAsk: () => CaptainAtlasLauncher.openCommandCenter(
                  context,
                  widget.serverIp,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    final mobile = useMobileLayout(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundNavy.withValues(alpha: 0.92),
        border: Border(
          bottom: BorderSide(color: AppColors.borderSoft(alpha: 0.18)),
        ),
      ),
      child: Row(
        children: [
          if (mobile)
            PremiumIconButton(
              icon: Icons.menu,
              onPressed: _openDrawer,
            ),
          if (mobile) const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: widget.hideEnvironmentChips
                ? Text(
                    AppConfig.productName,
                    style: AppTextStyles.dashboardTitle.copyWith(fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  )
                : Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      PremiumStatusBadge(
                        label: '$kPremiumHeaderLocation: ${widget.serverIp}',
                      ),
                      const PremiumStatusBadge(label: '$kPremiumHeaderWeather: 22°C'),
                      const PremiumStatusBadge(label: '$kPremiumHeaderMoon: İlk Hilal'),
                      const PremiumStatusBadge(label: '$kPremiumHeaderTide: Orta'),
                    ],
                  ),
          ),
          if (widget.connectionBadge != null)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: mobile ? 160 : 220),
                child: BackendConnectionBadge(
                  data: widget.connectionBadge!,
                  onTap: widget.onConnectionTap,
                ),
              ),
            ),
          PremiumIconButton(icon: Icons.search, onPressed: () {}),
          PremiumIconButton(icon: Icons.notifications_none, onPressed: () {}),
          PremiumIconButton(
            icon: Icons.privacy_tip_outlined,
            onPressed: widget.onPrivacyTap,
          ),
          PremiumIconButton(
            icon: Icons.settings_outlined,
            onPressed: widget.onSettingsTap,
          ),
          const SizedBox(width: 4),
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.surfaceElevated,
            child: Icon(Icons.person_outline, size: 18, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mobile = useMobileLayout(context);
    final sidebarWidth = useDesktopLayout(context) ? 172.0 : 72.0;

    final body = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!mobile)
          SizedBox(
            width: sidebarWidth,
            child: _sidebarContent(compact: !useDesktopLayout(context)),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget.suppressTopHeader) _header(context),
              Expanded(child: widget.child),
            ],
          ),
        ),
      ],
    );

    return PremiumShellScope(
      openDrawer: _openDrawer,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.transparent,
        drawer: mobile
            ? Drawer(
                backgroundColor: AppColors.backgroundNavy,
                child: _sidebarContent(compact: false),
              )
            : null,
        body: body,
      ),
    );
  }
}

class _NavSection {
  const _NavSection(this.id, this.label, this.icon);
  final String id;
  final String label;
  final IconData icon;
}
