import 'package:deniz_app/domain/dashboard_overview.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/utils/layout_breakpoints.dart';
import 'package:deniz_app/widgets/dashboard/mission/mission_captain_command_card.dart';
import 'package:deniz_app/widgets/dashboard/mission/mission_command_header.dart';
import 'package:deniz_app/widgets/dashboard/mission/mission_decision_timeline_panel.dart';
import 'package:deniz_app/widgets/dashboard/mission/mission_intelligence_strips.dart';
import 'package:deniz_app/widgets/dashboard/mission/mission_map_preview_panel.dart';
import 'package:deniz_app/widgets/dashboard/mission/mission_quick_action_dock.dart';
import 'package:deniz_app/widgets/dashboard/mission/mission_score_card.dart';
import 'package:deniz_app/widgets/dashboard/mission/mission_stagger_reveal.dart';
import 'package:deniz_app/widgets/premium/feedback/premium_error_fallback.dart';
import 'package:flutter/material.dart';

/// Mission Control responsive layout — desktop 3 / tablet 2 / mobile 1 kolon.
class MissionControlLayout extends StatelessWidget {
  const MissionControlLayout({
    super.key,
    required this.overview,
    required this.serverIp,
    required this.onLiveTap,
    required this.onPhotoTap,
    required this.onMarineTap,
    required this.onCompareTap,
    required this.onCaptainAtlasTap,
    required this.onRefresh,
    this.discoveryHint,
    this.discoveryBusy = false,
    this.offlineMessage,
  });

  final DashboardOverview overview;
  final String serverIp;
  final VoidCallback onLiveTap;
  final VoidCallback onPhotoTap;
  final VoidCallback onMarineTap;
  final VoidCallback onCompareTap;
  final VoidCallback onCaptainAtlasTap;
  final VoidCallback onRefresh;
  final String? discoveryHint;
  final bool discoveryBusy;
  final String? offlineMessage;

  @override
  Widget build(BuildContext context) {
    final desktop = useDesktopLayout(context);
    final mobile = useMobileLayout(context);

    final header = MissionStaggerReveal(
      index: 0,
      child: MissionCommandHeader(
        overview: overview,
        onRefresh: onRefresh,
        offlineMessage: offlineMessage,
      ),
    );

    if (discoveryHint != null) {
      // discovery hint shown below header via wrapper
    }

    final score = MissionStaggerReveal(
      index: 1,
      child: MissionScoreCard(
        report: overview.marineReport,
        onMarineTap: onMarineTap,
      ),
    );

    final map = MissionStaggerReveal(
      index: 2,
      child: MissionMapPreviewPanel(
        data: overview.mapPreview,
        onMapTap: onPhotoTap,
        onCompareTap: onCompareTap,
        onMarineTap: onMarineTap,
      ),
    );

    final timeline = MissionStaggerReveal(
      index: 3,
      child: MissionDecisionTimelinePanel(
        summary: overview.timeline,
        onMarineTap: onMarineTap,
      ),
    );

    final captain = MissionStaggerReveal(
      index: 4,
      child: MissionCaptainCommandCard(
        overview: overview,
        serverIp: serverIp,
        onMarineTap: onMarineTap,
        onLiveTap: onLiveTap,
        onCompareTap: onCompareTap,
      ),
    );

    final strips = MissionStaggerReveal(
      index: 5,
      child: Column(
        children: [
          MissionSavedSpotsStrip(
            summary: overview.savedSpots,
            onMarineTap: onMarineTap,
          ),
          const SizedBox(height: AppSpacing.gridGap),
          MissionCatchStrip(
            summary: overview.recentCatches,
            onMarineTap: onMarineTap,
          ),
          const SizedBox(height: AppSpacing.gridGap),
          MissionCompareSnapshotStrip(
            summary: overview.compare,
            onCompareTap: onCompareTap,
          ),
        ],
      ),
    );

    final leftColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MissionLiveIndexCard(summary: overview.liveScore, onLiveTap: onLiveTap),
        const SizedBox(height: AppSpacing.gridGap),
        MissionSystemStatusStrip(overview: overview),
      ],
    );

    final centerColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        score,
        const SizedBox(height: AppSpacing.gridGap),
        map,
        const SizedBox(height: AppSpacing.gridGap),
        timeline,
        if (!desktop) ...[
          const SizedBox(height: AppSpacing.gridGap),
          strips,
        ],
      ],
    );

    final rightColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        captain,
        const SizedBox(height: AppSpacing.gridGap),
        if (desktop) strips else ...[
          MissionSavedSpotsStrip(
            summary: overview.savedSpots,
            onMarineTap: onMarineTap,
          ),
          const SizedBox(height: AppSpacing.gridGap),
          MissionCompareSnapshotStrip(
            summary: overview.compare,
            onCompareTap: onCompareTap,
          ),
        ],
      ],
    );

    final body = desktop
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: leftColumn),
              const SizedBox(width: AppSpacing.gridGap),
              Expanded(flex: 2, child: centerColumn),
              const SizedBox(width: AppSpacing.gridGap),
              Expanded(child: rightColumn),
            ],
          )
        : useTabletLayout(context)
            ? Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: centerColumn),
                      const SizedBox(width: AppSpacing.gridGap),
                      Expanded(child: rightColumn),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.gridGap),
                  leftColumn,
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  centerColumn,
                  const SizedBox(height: AppSpacing.gridGap),
                  rightColumn,
                  const SizedBox(height: AppSpacing.gridGap),
                  leftColumn,
                ],
              );

    final dock = MissionQuickActionDock(
      onMapTap: onPhotoTap,
      onMarineTap: onMarineTap,
      onLiveTap: onLiveTap,
      onCompareTap: onCompareTap,
      onCaptainTap: onCaptainAtlasTap,
      sticky: false,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        if (discoveryHint != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              if (discoveryBusy)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              if (discoveryBusy) const SizedBox(width: 8),
              Expanded(child: Text(discoveryHint!, style: Theme.of(context).textTheme.bodySmall)),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.sectionGap),
        PremiumErrorBoundary(
          sectionTitle: kMissionControlTitle,
          builder: (context) => body,
        ),
        if (!mobile) dock,
        if (mobile) const SizedBox(height: 88),
      ],
    );
  }
}

/// Mobil sticky dock — PremiumDashboardScreen Stack içinde kullanılır.
class MissionStickyQuickDock extends StatelessWidget {
  const MissionStickyQuickDock({
    super.key,
    required this.onMapTap,
    required this.onMarineTap,
    required this.onLiveTap,
    required this.onCompareTap,
    required this.onCaptainTap,
  });

  final VoidCallback onMapTap;
  final VoidCallback onMarineTap;
  final VoidCallback onLiveTap;
  final VoidCallback onCompareTap;
  final VoidCallback onCaptainTap;

  @override
  Widget build(BuildContext context) {
    return MissionQuickActionDock(
      onMapTap: onMapTap,
      onMarineTap: onMarineTap,
      onLiveTap: onLiveTap,
      onCompareTap: onCompareTap,
      onCaptainTap: onCaptainTap,
      sticky: true,
    );
  }
}
