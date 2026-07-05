import 'dart:async' show unawaited;

import 'package:deniz_app/api_service.dart';
import 'package:deniz_app/config/app_config.dart';
import 'package:deniz_app/domain/dashboard_overview.dart';
import 'package:deniz_app/services/dashboard_overview_service.dart';
import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/utils/layout_breakpoints.dart';
import 'package:deniz_app/widgets/backend_connection_badge.dart';
import 'package:deniz_app/widgets/dashboard/v2/premium_dashboard_v2_layout.dart';
import 'package:deniz_app/widgets/premium/feedback/safe_async_section.dart';
import 'package:flutter/material.dart';

/// Premium ana sayfa — kompakt Dashboard V2 düzeni.
class PremiumDashboardScreen extends StatefulWidget {
  const PremiumDashboardScreen({
    super.key,
    required this.serverIp,
    required this.onLiveTap,
    required this.onPhotoTap,
    required this.onMarineTap,
    required this.onCompareTap,
    required this.onCaptainAtlasTap,
    this.discoveryHint,
    this.discoveryBusy = false,
    this.offlineMessage,
    this.connectionStatus = DashboardConnectionStatus.unknown,
    this.connectionBadge,
    this.onConnectionTap,
    this.onSettingsTap,
    this.onPrivacyTap,
    this.overviewService,
    this.initialOverview,
  });

  final String serverIp;
  final VoidCallback onLiveTap;
  final VoidCallback onPhotoTap;
  final VoidCallback onMarineTap;
  final VoidCallback onCompareTap;
  final VoidCallback onCaptainAtlasTap;
  final String? discoveryHint;
  final bool discoveryBusy;
  final String? offlineMessage;
  final DashboardConnectionStatus connectionStatus;
  final BackendConnectionBadgeData? connectionBadge;
  final VoidCallback? onConnectionTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onPrivacyTap;
  final DashboardOverviewService? overviewService;
  final DashboardOverview? initialOverview;

  @override
  State<PremiumDashboardScreen> createState() => _PremiumDashboardScreenState();
}

class _PremiumDashboardScreenState extends State<PremiumDashboardScreen> {
  DashboardOverview _overview = DashboardOverview.empty;
  bool _loading = true;

  DashboardOverviewService get _service =>
      widget.overviewService ??
      DashboardOverviewService(
        apiService: ApiService(
          serverBaseUrl: AppConfig.buildApiBaseUrl(widget.serverIp.trim()),
        ),
      );

  @override
  void initState() {
    super.initState();
    if (widget.initialOverview != null) {
      _overview = widget.initialOverview!.copyWith(
        connectionStatus: widget.connectionStatus,
      );
      _loading = false;
      unawaited(_refreshTimelineInBackground());
    } else {
      unawaited(_reload(showSkeleton: true));
    }
  }

  @override
  void didUpdateWidget(covariant PremiumDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.connectionStatus != widget.connectionStatus &&
        widget.initialOverview == null) {
      setState(() {
        _overview = _overview.copyWith(connectionStatus: widget.connectionStatus);
      });
    }
    if (oldWidget.connectionStatus != widget.connectionStatus &&
        widget.initialOverview != null) {
      setState(() {
        _overview = widget.initialOverview!.copyWith(
          connectionStatus: widget.connectionStatus,
        );
      });
    }
  }

  Future<void> _reload({
    bool showSkeleton = false,
    bool forceTimelineRefresh = false,
  }) async {
    if (showSkeleton && mounted) {
      setState(() => _loading = true);
    }
    final next = await _service.load(
      connectionStatus: widget.connectionStatus,
    );
    if (!mounted) return;
    setState(() {
      _overview = next;
      _loading = false;
    });
    if (next.timeline.displayState !=
        DashboardTimelineDisplayState.noCoordinate) {
      unawaited(
        _refreshTimelineInBackground(forceRefresh: forceTimelineRefresh),
      );
    }
  }

  Future<void> _refreshTimelineInBackground({bool forceRefresh = false}) async {
    if (!_service.canRefreshTimeline || !mounted) return;

    setState(() {
      _overview = _overview.copyWith(
        timeline: _overview.timeline.copyWith(isRefreshing: true),
      );
    });

    final refreshResult =
        await _service.refreshTimelineReport(forceRefresh: forceRefresh);

    if (!mounted) return;
    final next = await _service.load(
      connectionStatus: widget.connectionStatus,
    );
    if (!mounted) return;

    DashboardTimelineDebug.logRefresh(
      lastCoordinateExists: refreshResult.coordinateExists,
      fetchCalled: refreshResult.fetchCalled,
      decisionTimelineLength: refreshResult.decisionTimelineLength,
      cacheSaved: refreshResult.cacheSaved,
      timelineState: next.timeline.resolvedDisplayState,
      slotCount: next.timeline.slots.length,
    );

    setState(() => _overview = next);
  }

  @override
  Widget build(BuildContext context) {
    final mobile = useMobileLayout(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final content = SafeAsyncSection(
          loading: _loading,
          loadingHeight: constraints.maxHeight.clamp(320.0, 720.0),
          child: PremiumDashboardV2Layout(
            overview: _overview,
            serverIp: widget.serverIp,
            onLiveTap: widget.onLiveTap,
            onPhotoTap: widget.onPhotoTap,
            onMarineTap: widget.onMarineTap,
            onCompareTap: widget.onCompareTap,
            onCaptainAtlasTap: widget.onCaptainAtlasTap,
            onTimelineRefresh: () =>
                _refreshTimelineInBackground(forceRefresh: true),
            discoveryHint: widget.discoveryHint,
            discoveryBusy: widget.discoveryBusy,
            offlineMessage: widget.offlineMessage,
            connectionBadge: widget.connectionBadge,
            onConnectionTap: widget.onConnectionTap,
            onSettingsTap: widget.onSettingsTap,
            onPrivacyTap: widget.onPrivacyTap,
          ),
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            RefreshIndicator(
              onRefresh: () => _reload(
                showSkeleton: false,
                forceTimelineRefresh: true,
              ),
              color: AppColors.accentTeal,
              child: content,
            ),
            if (mobile)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: DashboardV2StickyDock(
                  onMapTap: widget.onPhotoTap,
                  onMarineTap: widget.onMarineTap,
                  onLiveTap: widget.onLiveTap,
                  onCompareTap: widget.onCompareTap,
                  onCaptainTap: widget.onCaptainAtlasTap,
                ),
              ),
          ],
        );
      },
    );
  }
}
