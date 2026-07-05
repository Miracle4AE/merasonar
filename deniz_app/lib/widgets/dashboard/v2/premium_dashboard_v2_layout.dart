import 'package:deniz_app/domain/dashboard_overview.dart';
import 'package:deniz_app/layout/premium_app_shell.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/utils/layout_breakpoints.dart';
import 'package:deniz_app/widgets/backend_connection_badge.dart';
import 'package:deniz_app/widgets/dashboard/mission/mission_control_layout.dart';
import 'package:deniz_app/widgets/dashboard/v2/dashboard_v2_captain_atlas_card.dart';
import 'package:deniz_app/widgets/dashboard/v2/dashboard_v2_compare_card.dart';
import 'package:deniz_app/widgets/dashboard/v2/dashboard_v2_day_timeline_card.dart';
import 'package:deniz_app/widgets/dashboard/v2/dashboard_v2_forecast_card.dart';
import 'package:deniz_app/widgets/dashboard/v2/dashboard_v2_helpers.dart';
import 'package:deniz_app/widgets/dashboard/v2/dashboard_v2_live_score_card.dart';
import 'package:deniz_app/widgets/dashboard/v2/dashboard_v2_map_card.dart';
import 'package:deniz_app/widgets/dashboard/v2/dashboard_v2_recent_catches_card.dart';
import 'package:deniz_app/widgets/dashboard/v2/dashboard_v2_saved_spots_card.dart';
import 'package:deniz_app/widgets/dashboard/v2/dashboard_v2_summary_card.dart';
import 'package:deniz_app/widgets/dashboard/v2/dashboard_v2_tide_card.dart';
import 'package:deniz_app/widgets/dashboard/v2/dashboard_v2_top_status_bar.dart';
import 'package:deniz_app/widgets/premium/feedback/premium_error_fallback.dart';
import 'package:flutter/material.dart';

/// Premium Dashboard V2 — kompakt referans grid düzeni.
class PremiumDashboardV2Layout extends StatelessWidget {
  const PremiumDashboardV2Layout({
    super.key,
    required this.overview,
    required this.serverIp,
    required this.onLiveTap,
    required this.onPhotoTap,
    required this.onMarineTap,
    required this.onCompareTap,
    required this.onCaptainAtlasTap,
    this.onTimelineRefresh,
    this.discoveryHint,
    this.discoveryBusy = false,
    this.offlineMessage,
    this.connectionBadge,
    this.onConnectionTap,
    this.onSettingsTap,
    this.onPrivacyTap,
  });

  final DashboardOverview overview;
  final String serverIp;
  final VoidCallback onLiveTap;
  final VoidCallback onPhotoTap;
  final VoidCallback onMarineTap;
  final VoidCallback onCompareTap;
  final VoidCallback onCaptainAtlasTap;
  final VoidCallback? onTimelineRefresh;
  final String? discoveryHint;
  final bool discoveryBusy;
  final String? offlineMessage;
  final BackendConnectionBadgeData? connectionBadge;
  final VoidCallback? onConnectionTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onPrivacyTap;

  @override
  Widget build(BuildContext context) {
    final mobile = useMobileLayout(context);
    final tablet = useTabletLayout(context);
    final shell = PremiumShellScope.maybeOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DashboardV2TopStatusBar(
          overview: overview,
          serverIp: serverIp,
          connectionBadge: connectionBadge,
          onConnectionTap: onConnectionTap,
          onSettingsTap: onSettingsTap,
          onPrivacyTap: onPrivacyTap,
          onMenuTap: shell?.openDrawer,
        ),
        if (offlineMessage != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DashboardV2Helpers.outerPadding,
              AppSpacing.sm,
              DashboardV2Helpers.outerPadding,
              0,
            ),
            child: Text(
              offlineMessage!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (discoveryHint != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DashboardV2Helpers.outerPadding,
              AppSpacing.sm,
              DashboardV2Helpers.outerPadding,
              0,
            ),
            child: Row(
              children: [
                if (discoveryBusy)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                if (discoveryBusy) const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    discoveryHint!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(DashboardV2Helpers.outerPadding),
            child: PremiumErrorBoundary(
              sectionTitle: kPremiumDashTitle,
              builder: (context) => LayoutBuilder(
                builder: (context, constraints) {
                  if (mobile) return _mobileLayout(context);
                  if (tablet) return _tabletLayout(context, constraints);
                  return _desktopLayout(context, constraints);
                },
              ),
            ),
          ),
        ),
        if (mobile) const SizedBox(height: 72),
      ],
    );
  }

  Widget _desktopLayout(BuildContext context, BoxConstraints constraints) {
    final gap = DashboardV2Helpers.gridGap;

    return Column(
      children: [
        Expanded(
          flex: 46,
          child: _gridRow([
            (6, _mapCard()),
            (3, _liveScoreCard()),
            (3, _timelineCard()),
          ], gap: gap),
        ),
        SizedBox(height: gap),
        Expanded(
          flex: 32,
          child: _gridRow([
            (3, _summaryCard()),
            (2, _savedSpotsCard()),
            (3, _recentCatchesCard()),
            (4, _captainAtlasCard()),
          ], gap: gap),
        ),
        SizedBox(height: gap),
        Expanded(
          flex: 22,
          child: _gridRow([
            (3, _compareCard()),
            (5, DashboardV2ForecastCard(summary: overview.forecast)),
            (4, _tideCard()),
          ], gap: gap),
        ),
      ],
    );
  }

  Widget _tabletLayout(BuildContext context, BoxConstraints constraints) {
    final gap = DashboardV2Helpers.gridGap;
    final rowH = (constraints.maxHeight / 4.2).clamp(180.0, 240.0);

    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(height: rowH, child: _mapCard()),
          SizedBox(height: gap),
          SizedBox(
            height: rowH,
            child: Row(
              children: [
                Expanded(child: _liveScoreCard()),
                SizedBox(width: gap),
                Expanded(child: _captainAtlasCard()),
              ],
            ),
          ),
          SizedBox(height: gap),
          SizedBox(height: rowH * 0.9, child: _timelineCard()),
          SizedBox(height: gap),
          SizedBox(
            height: rowH,
            child: Row(
              children: [
                Expanded(child: _summaryCard()),
                SizedBox(width: gap),
                Expanded(child: _savedSpotsCard()),
              ],
            ),
          ),
          SizedBox(height: gap),
          SizedBox(
            height: rowH,
            child: Row(
              children: [
                Expanded(child: _recentCatchesCard()),
                SizedBox(width: gap),
                Expanded(child: _compareCard()),
              ],
            ),
          ),
          SizedBox(height: gap),
          SizedBox(
            height: rowH,
            child: Row(
              children: [
                Expanded(child: DashboardV2ForecastCard(summary: overview.forecast)),
                SizedBox(width: gap),
                Expanded(child: _tideCard()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileLayout(BuildContext context) {
    final gap = DashboardV2Helpers.gridGap;
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              children: [
                SizedBox(height: 200, child: _mapCard()),
                SizedBox(height: gap),
                SizedBox(height: 220, child: _liveScoreCard()),
                SizedBox(height: gap),
                SizedBox(height: 240, child: _timelineCard()),
                SizedBox(height: gap),
                SizedBox(height: 200, child: _captainAtlasCard()),
                SizedBox(height: gap),
                SizedBox(height: 180, child: _summaryCard()),
                SizedBox(height: gap),
                SizedBox(height: 160, child: _savedSpotsCard()),
                SizedBox(height: gap),
                SizedBox(height: 160, child: _recentCatchesCard()),
                SizedBox(height: gap),
                SizedBox(height: 180, child: _compareCard()),
                SizedBox(height: gap),
                SizedBox(
                  height: 160,
                  child: DashboardV2ForecastCard(summary: overview.forecast),
                ),
                SizedBox(height: gap),
                SizedBox(height: 160, child: _tideCard()),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _gridRow(List<(int cols, Widget child)> items, {required double gap}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          Expanded(flex: items[i].$1, child: items[i].$2),
        ],
      ],
    );
  }

  Widget _mapCard() => DashboardV2MapCard(
        data: overview.mapPreview,
        onTap: onPhotoTap,
        onMarineTap: onMarineTap,
      );

  Widget _liveScoreCard() => DashboardV2LiveScoreCard(
        summary: overview.liveScore,
        marineReport: overview.marineReport,
        onLiveTap: onLiveTap,
      );

  Widget _timelineCard() => DashboardV2DayTimelineCard(
        summary: overview.timeline,
        onMarineTap: onMarineTap,
        onRefreshTap: onTimelineRefresh,
      );

  Widget _summaryCard() => DashboardV2SummaryCard(
        report: overview.marineReport,
        onMarineTap: onMarineTap,
      );

  Widget _savedSpotsCard() => DashboardV2SavedSpotsCard(
        summary: overview.savedSpots,
        onMarineTap: onMarineTap,
      );

  Widget _recentCatchesCard() => DashboardV2RecentCatchesCard(
        summary: overview.recentCatches,
        onMarineTap: onMarineTap,
      );

  Widget _captainAtlasCard() => DashboardV2CaptainAtlasCard(
        summary: overview.captainAtlas,
        onCaptainTap: onCaptainAtlasTap,
      );

  Widget _compareCard() => DashboardV2CompareCard(
        summary: overview.compare,
        onCompareTap: onCompareTap,
      );

  Widget _tideCard() => DashboardV2TideCard(
        summary: overview.tide,
        onMarineTap: onMarineTap,
      );
}

/// Mobil sticky dock — PremiumDashboardScreen Stack içinde kullanılır.
typedef DashboardV2StickyDock = MissionStickyQuickDock;
