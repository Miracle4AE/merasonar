import 'package:deniz_app/domain/dashboard_overview.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/services/app_settings_controller.dart';
import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/widgets/dashboard/v2/dashboard_map_preview_painter.dart';
import 'package:deniz_app/widgets/dashboard/v2/dashboard_v2_helpers.dart';
import 'package:deniz_app/widgets/premium/premium_animation_policy.dart';
import 'package:deniz_app/widgets/premium/premium_card.dart';
import 'package:deniz_app/widgets/premium/premium_metric_chip.dart';
import 'package:flutter/material.dart';

class DashboardV2MapCard extends StatelessWidget {
  const DashboardV2MapCard({
    super.key,
    required this.data,
    this.onTap,
    this.onMarineTap,
    this.onCompareTap,
    this.onSavedSpotsTap,
  });

  final DashboardMapPreviewData data;
  final VoidCallback? onTap;
  final VoidCallback? onMarineTap;
  final VoidCallback? onCompareTap;
  final VoidCallback? onSavedSpotsTap;

  bool get _showMapContent =>
      data.hasData || data.displayMode == DashboardMapPreviewMode.limited;

  bool get _showEmptyOverlay =>
      data.displayMode == DashboardMapPreviewMode.empty ||
      data.displayMode == DashboardMapPreviewMode.limited;

  @override
  Widget build(BuildContext context) {
    final glowScale = PremiumAnimationPolicy.glowIntensity(context);
    final reduceMotion = PremiumAnimationPolicy.reduceMotion(context);
    final showSource =
        AppSettingsScope.maybeOf(context)?.settings.showDataSourceLabels ?? true;
    final showMapSource = showSource &&
        (AppSettingsScope.maybeOf(context)?.settings.showMapPreviewSourceInfo ??
            true);

    final scorableMarkers =
        data.markers.where((m) => m.hasScoreOrb).take(8).toList(growable: false);

    return PremiumCard(
      glow: true,
      padding: EdgeInsets.zero,
      onTap: _showMapContent ? onTap : onMarineTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: DashboardMapPreviewPainter(
                        markers: scorableMarkers,
                        hasComparePair: data.hasComparePair,
                        hasData: data.hasRealData,
                        selectedMarkerId: data.selectedMarkerId,
                        glowScale: glowScale,
                        reduceMotion: reduceMotion,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                if (data.hasRealData)
                  Positioned(
                    top: AppSpacing.sm,
                    left: AppSpacing.sm,
                    child: _liveScoreChip(context),
                  ),
                if (data.isLowConfidence && _showMapContent)
                  Positioned(
                    top: AppSpacing.sm,
                    right: AppSpacing.sm,
                    child: _lowConfidenceChip(),
                  ),
                if (data.dataSourceLabel != null &&
                    data.hasRealData &&
                    showMapSource)
                  Positioned(
                    top: 40,
                    left: AppSpacing.sm,
                    child: PremiumMetricChip(
                      label: kPremiumDashMapDataSource,
                      value: data.dataSourceLabel!,
                    ),
                  ),
                if (data.winnerLabel != null &&
                    data.displayMode == DashboardMapPreviewMode.compare)
                  Positioned(
                    top: AppSpacing.sm,
                    right: AppSpacing.sm,
                    child: PremiumMetricChip(
                      label: kMissionMapWinner,
                      value: data.winnerLabel!,
                      accentColor: AppColors.accentGreen,
                    ),
                  ),
                if (data.hasRealData && _hasMarineMetrics)
                  Positioned(
                    left: AppSpacing.sm,
                    right: AppSpacing.sm,
                    bottom: data.updatedAgoLabel != null ? 44 : AppSpacing.sm,
                    child: _marineMetricsRow(),
                  ),
                if (_showMapContent)
                  Positioned(
                    left: AppSpacing.sm,
                    bottom: data.updatedAgoLabel != null ? 44 : AppSpacing.sm,
                    child: _depthScale(),
                  ),
                if (data.updatedAgoLabel != null && _showMapContent)
                  Positioned(
                    right: AppSpacing.sm,
                    bottom: AppSpacing.sm,
                    child: _lastUpdateChip(),
                  ),
                if (_showEmptyOverlay) ...[
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            AppColors.surfaceDark.withValues(alpha: 0.62),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: AppSpacing.md,
                    right: AppSpacing.md,
                    top: AppSpacing.lg,
                    child: Text(
                      data.emptyReason ?? kPremiumDashMapEmptyAwaiting,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ),
                  if (data.warningLabel != null)
                    Positioned(
                      left: AppSpacing.md,
                      right: AppSpacing.md,
                      top: 72,
                      child: Text(
                        data.warningLabel!,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 11,
                          color: AppColors.accentAmber.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 36,
                    child: Center(
                      child: DashboardV2Helpers.compactSecondaryButton(
                        label: kMissionScoreCta,
                        onPressed: onMarineTap,
                        icon: Icons.explore_outlined,
                      ),
                    ),
                  ),
                ],
                if (data.hasData &&
                    (data.displayMode == DashboardMapPreviewMode.compare ||
                        data.displayMode == DashboardMapPreviewMode.savedSpots))
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 8,
                    child: Center(child: _modeCta()),
                  ),
              ],
            ),
          ),
          if (data.centerLabel != null && _showMapContent)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Text(
                    '${_centerPrefix()}: ',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      data.centerLabel!,
                      style: AppTextStyles.caption.copyWith(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _liveScoreChip(BuildContext context) {
    final selected = data.selectedMarker;
    final score = selected?.score ?? data.score;
    final label = selected?.score != null
        ? '${selected!.score}'
        : (data.scoreLabel ?? (data.score != null ? '${data.score}' : kPremiumDashNoData));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSoft(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            kPremiumDashScoreLabel,
            style: AppTextStyles.caption.copyWith(
              fontSize: 10,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: score != null
                  ? DashboardV2Helpers.scoreColor(score)
                  : AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 16,
            color: AppColors.textMuted,
          ),
        ],
      ),
    );
  }

  Widget _lowConfidenceChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accentAmber.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.accentAmber.withValues(alpha: 0.45)),
      ),
      child: Text(
        kPremiumDashMapLowConfidence,
        style: AppTextStyles.caption.copyWith(
          fontSize: 10,
          color: AppColors.accentAmber,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _depthScale() {
    final minLabel = data.depthLegendMinLabel ?? kPremiumDashMapDepthMin;
    final maxLabel = data.depthLegendMaxLabel ?? kPremiumDashMapDepthMax;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.borderSoft(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            minLabel,
            style: AppTextStyles.caption.copyWith(fontSize: 10),
          ),
          const SizedBox(width: 6),
          Container(
            width: 48,
            height: 3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: LinearGradient(
                colors: [
                  AppColors.accentTeal.withValues(alpha: 0.35),
                  AppColors.borderCyan.withValues(alpha: 0.85),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            maxLabel,
            style: AppTextStyles.caption.copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _lastUpdateChip() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: AppColors.accentGreen,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.accentGreen.withValues(alpha: 0.45),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        PremiumMetricChip(
          label: kPremiumDashMapLastUpdate,
          value: data.updatedAgoLabel!,
        ),
      ],
    );
  }

  bool get _hasMarineMetrics =>
      data.waveLabel != null ||
      data.currentLabel != null ||
      data.windLabel != null;

  String _centerPrefix() {
    return switch (data.displayMode) {
      DashboardMapPreviewMode.activeReport => kPremiumDashMapLastCoordinate,
      DashboardMapPreviewMode.savedSpots => kPremiumDashMapSavedSpot,
      DashboardMapPreviewMode.compare => kPremiumDashMapComparePoint,
      DashboardMapPreviewMode.limited => kPremiumDashMapLastCoordinate,
      DashboardMapPreviewMode.empty => kPremiumDashMapLastCoordinate,
    };
  }

  Widget _marineMetricsRow() {
    final chips = <Widget>[];
    if (data.waveLabel != null) {
      chips.add(
        PremiumMetricChip(
          label: kPremiumDashMapWave,
          value: data.waveLabel!,
        ),
      );
    }
    if (data.currentLabel != null) {
      if (chips.isNotEmpty) chips.add(const SizedBox(width: 4));
      chips.add(
        PremiumMetricChip(
          label: kPremiumDashMapCurrent,
          value: data.currentLabel!,
        ),
      );
    }
    if (data.windLabel != null) {
      if (chips.isNotEmpty) chips.add(const SizedBox(width: 4));
      chips.add(
        PremiumMetricChip(
          label: kPremiumDashMapWind,
          value: data.windLabel!,
        ),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(mainAxisSize: MainAxisSize.min, children: chips),
    );
  }

  Widget _modeCta() {
    final label = switch (data.displayMode) {
      DashboardMapPreviewMode.compare => kPremiumDashMapCompareCta,
      DashboardMapPreviewMode.savedSpots => kPremiumDashMapSavedSpotsCta,
      DashboardMapPreviewMode.activeReport => kPremiumDashMapCta,
      DashboardMapPreviewMode.limited => kMissionScoreCta,
      DashboardMapPreviewMode.empty => kMissionScoreCta,
    };
    final onPressed = switch (data.displayMode) {
      DashboardMapPreviewMode.compare => onCompareTap ?? onTap,
      DashboardMapPreviewMode.savedSpots => onSavedSpotsTap ?? onTap,
      DashboardMapPreviewMode.activeReport => onTap,
      DashboardMapPreviewMode.limited => onMarineTap,
      DashboardMapPreviewMode.empty => onMarineTap,
    };
    if (onPressed == null) return const SizedBox.shrink();
    return DashboardV2Helpers.compactSecondaryButton(
      label: label,
      onPressed: onPressed,
      icon: switch (data.displayMode) {
        DashboardMapPreviewMode.compare => Icons.compare_arrows,
        DashboardMapPreviewMode.savedSpots => Icons.bookmark_outline,
        DashboardMapPreviewMode.activeReport => Icons.map_outlined,
        DashboardMapPreviewMode.limited => Icons.explore_outlined,
        DashboardMapPreviewMode.empty => Icons.explore_outlined,
      },
    );
  }
}
