import 'dart:io';

import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/map/widgets/premium/chart_debug_overlay_controls.dart';
import 'package:deniz_app/map/widgets/premium/chart_overlay_command_bar.dart';
import 'package:deniz_app/map/widgets/premium/chart_overlay_glass_header.dart';
import 'package:deniz_app/map/widgets/premium/chart_overlay_mini_legend.dart';
import 'package:deniz_app/map/widgets/premium/photo_analysis_loading_overlay.dart';
import 'package:deniz_app/map/widgets/premium/photo_analysis_premium_panel.dart';
import 'package:deniz_app/widgets/premium/premium_status_badge.dart';
import 'package:flutter/material.dart';

/// Chart overlay görünümü — marker render dışarıdan callback ile gelir.
class ChartOverlayHost extends StatelessWidget {
  const ChartOverlayHost({
    super.key,
    required this.mobile,
    required this.canRender,
    required this.chartFile,
    required this.cachedAnalysisChartFileMissing,
    required this.chartFromHistoryFallback,
    required this.isImageSpaceMode,
    required this.isLoading,
    required this.coordinateModeLabel,
    required this.hotspotCount,
    required this.calibrationLabel,
    required this.calibrationTone,
    required this.showDebugOverlay,
    required this.debugOverlayOpacity,
    required this.debugOverlayFile,
    required this.worldMapEnabled,
    required this.captainEnabled,
    required this.onCanvasSizeChanged,
    required this.markerBuilder,
    required this.transformController,
    required this.onDebugToggle,
    required this.onDebugOpacityChanged,
    required this.onAnalyze,
    required this.onCalibrate,
    required this.onWorldMap,
    required this.onCaptainAtlas,
    required this.onGpx,
    required this.missingChartRecovery,
    required this.needScreenshotPanel,
    required this.warningCard,
  });

  final bool mobile;
  final bool canRender;
  final File? chartFile;
  final bool cachedAnalysisChartFileMissing;
  final bool chartFromHistoryFallback;
  final bool isImageSpaceMode;
  final bool isLoading;
  final String coordinateModeLabel;
  final int hotspotCount;
  final String? calibrationLabel;
  final PremiumStatusTone calibrationTone;
  final bool showDebugOverlay;
  final double debugOverlayOpacity;
  final File? debugOverlayFile;
  final bool worldMapEnabled;
  final bool captainEnabled;
  final ValueChanged<Size> onCanvasSizeChanged;
  final Widget Function(Size canvasSize) markerBuilder;
  final TransformationController transformController;
  final ValueChanged<bool> onDebugToggle;
  final ValueChanged<double> onDebugOpacityChanged;
  final VoidCallback onAnalyze;
  final VoidCallback onCalibrate;
  final VoidCallback onWorldMap;
  final VoidCallback onCaptainAtlas;
  final VoidCallback onGpx;
  final Widget missingChartRecovery;
  final Widget needScreenshotPanel;
  final Widget? warningCard;

  @override
  Widget build(BuildContext context) {
    if (!canRender || chartFile == null) {
      if (cachedAnalysisChartFileMissing) {
        return missingChartRecovery;
      }
      return needScreenshotPanel;
    }

    return RepaintBoundary(
      child: PhotoAnalysisPremiumPanel(
        showHeader: true,
        historyNote: chartFromHistoryFallback ? kMapChartFromHistoryNote : null,
        header: ChartOverlayGlassHeader(
          coordinateModeLabel: coordinateModeLabel,
          hotspotCount: hotspotCount,
          calibrationLabel: calibrationLabel,
          calibrationTone: calibrationTone,
          compact: mobile,
        ),
        warning: warningCard,
        child: Stack(
          fit: StackFit.expand,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final canvasSize = Size(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );
                onCanvasSizeChanged(canvasSize);
                return InteractiveViewer(
                  transformationController: transformController,
                  minScale: 0.45,
                  maxScale: 8,
                  child: SizedBox(
                    width: canvasSize.width,
                    height: canvasSize.height,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Image.file(chartFile!, fit: BoxFit.fill),
                        ),
                        if (debugOverlayFile != null && showDebugOverlay)
                          Positioned.fill(
                            child: Opacity(
                              opacity: debugOverlayOpacity,
                              child: Image.file(
                                debugOverlayFile!,
                                fit: BoxFit.fill,
                              ),
                            ),
                          ),
                        markerBuilder(canvasSize),
                      ],
                    ),
                  ),
                );
              },
            ),
            if (isLoading) const PhotoAnalysisLoadingOverlay(),
            Positioned(
              top: mobile ? 8 : 12,
              right: mobile ? 8 : 12,
              child: const ChartOverlayMiniLegend(),
            ),
            if (debugOverlayFile != null)
              Positioned(
                top: mobile ? 8 : 12,
                left: mobile ? 8 : 12,
                width: mobile ? 220 : 260,
                child: ChartDebugOverlayControls(
                  compact: mobile,
                  visible: showDebugOverlay,
                  opacity: debugOverlayOpacity,
                  onToggle: onDebugToggle,
                  onOpacityChanged: onDebugOpacityChanged,
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: mobile ? 8 : 12,
              child: RepaintBoundary(
                child: ChartOverlayCommandBar(
                  busy: isLoading,
                  worldMapEnabled: worldMapEnabled,
                  captainEnabled: captainEnabled,
                  onAnalyze: onAnalyze,
                  onCalibrate: onCalibrate,
                  onWorldMap: onWorldMap,
                  onCaptainAtlas: onCaptainAtlas,
                  onGpx: onGpx,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
