import 'package:deniz_app/api_service.dart';
import 'package:deniz_app/domain/geo_visualization_state.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/map/widgets/hotspot_detail_sheet.dart';
import 'package:deniz_app/map/widgets/premium/calibration_premium_header.dart';
import 'package:deniz_app/map/widgets/premium/chart_debug_overlay_controls.dart';
import 'package:deniz_app/map/widgets/premium/chart_overlay_command_bar.dart';
import 'package:deniz_app/map/widgets/premium/chart_overlay_glass_header.dart';
import 'package:deniz_app/map/widgets/premium/chart_overlay_mini_legend.dart';
import 'package:deniz_app/map/widgets/premium/chart_overlay_premium_marker.dart';
import 'package:deniz_app/map/widgets/premium/image_space_warning_card.dart';
import 'package:deniz_app/map/widgets/premium/map_hotspot_detail_panel.dart';
import 'package:deniz_app/map/widgets/premium/map_premium_legend.dart';
import 'package:deniz_app/map/widgets/premium/photo_analysis_loading_overlay.dart';
import 'package:deniz_app/map/widgets/premium/photo_analysis_premium_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Hotspot _testHotspot() {
  return Hotspot.fromJson({
    'id': 1,
    'feature_type': 'drop_off',
    'rank_by_proximity': 1,
    'rank': 1,
    'rank_overall': 1,
    'rank_by_score_then_distance': 1,
    'latitude': 37.352,
    'longitude': 27.203,
    'geo_coordinate': {'lat': 37.352, 'lon': 27.203},
    'distance_m': 125.4,
    'bearing_deg': 88.2,
    'score': 0.85,
    'classification': 'A',
    'reasoning': <String>[],
    'supporting_metrics': <String, dynamic>{},
    'sea_state': <String, dynamic>{},
    'pixel_centroid': {'x': 100.0, 'y': 200.0},
    'hotspot_pixel_anchor': {'x': 100.0, 'y': 200.0},
    'trust_state': 'trusted',
    'trust_score': 0.9,
    'mapping_trust': 'image_space',
    'is_renderable': true,
    'fishing_advice': <String, dynamic>{
      'species_predictions': <dynamic>[],
      'bait': <dynamic>[],
      'best_times': <dynamic>[],
      'tackle': <dynamic>[],
      'selection_reasons': <dynamic>[],
    },
    'confirmed_depth': <String, dynamic>{'depth_m': 42.0},
    'likely_species': <String, dynamic>{
      'source': 'none',
      'fallback': true,
      'total_records_considered': 0,
      'top_species': <dynamic>[],
    },
  });
}

void main() {
  testWidgets('ChartOverlayPremiumMarker render', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ChartOverlayPremiumMarker(
              scoreText: '82',
              scoreLabel: 'A · #1',
              color: Colors.green,
              focused: false,
              topTier: true,
              pulse: 0.4,
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('82'), findsOneWidget);
  });

  testWidgets('ChartOverlayPremiumMarker compact mode', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChartOverlayPremiumMarker(
            scoreText: '70',
            scoreLabel: 'B',
            color: Colors.amber,
            focused: true,
            topTier: false,
            pulse: 0,
            compact: true,
          ),
        ),
      ),
    );
    expect(find.text('70'), findsOneWidget);
    expect(find.text('B'), findsNothing);
  });

  testWidgets('PhotoAnalysisUploadCard premium render', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PhotoAnalysisUploadCard(
            message: kMapChartOverlayNeedsScreenshotAnalysis,
            onScan: () {},
          ),
        ),
      ),
    );
    expect(find.text(kMapPhotoUploadHint), findsOneWidget);
    expect(find.text(kMapPhotoUploadFormats), findsOneWidget);
    expect(find.text(kMapPhotoUploadDropHint), findsOneWidget);
  });

  testWidgets('ImageSpaceWarningCard render', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ImageSpaceWarningCard(onCalibrate: () {}),
        ),
      ),
    );
    expect(find.text(kMapImageSpaceWarningTitle), findsOneWidget);
    expect(find.text(kMapImageSpaceWarningBody), findsOneWidget);
    expect(find.text(kMapChartOverlayCmdCalibrate), findsOneWidget);
  });

  testWidgets('CalibrationPremiumHeader smoke', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalibrationPremiumHeader(
            currentStep: CalibrationPremiumStep.verify,
            validGeoCount: 2,
            manualPixelCount: 1,
            ready: false,
            reliabilityLabel: kMapCalibReliabilityMedium,
          ),
        ),
      ),
    );
    expect(find.text(kCalibSheetTitle), findsOneWidget);
    expect(find.text(kMapCalibStepVerify), findsOneWidget);
  });

  testWidgets('ChartDebugOverlayControls render', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChartDebugOverlayControls(
            visible: true,
            opacity: 0.5,
            onToggle: (_) {},
            onOpacityChanged: (_) {},
          ),
        ),
      ),
    );
    expect(find.text(kMapChartDebugOverlayTitle), findsOneWidget);
    expect(find.text(kMapChartDebugLegendHot), findsOneWidget);
  });

  testWidgets('ChartOverlayGlassHeader render', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChartOverlayGlassHeader(
            coordinateModeLabel: kMapChartOverlayModeImageSpace,
            hotspotCount: 12,
            calibrationLabel: kMapCalibReliabilityGood,
          ),
        ),
      ),
    );
    expect(find.text(kMapPremiumPhotoTitle), findsOneWidget);
    expect(find.text(kMapChartOverlayHotspotCountFmt(12)), findsOneWidget);
  });

  testWidgets('ChartOverlayCommandBar render', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChartOverlayCommandBar(
            onAnalyze: () {},
            onCalibrate: () {},
            onWorldMap: () {},
            onCaptainAtlas: () {},
            onGpx: () {},
          ),
        ),
      ),
    );
    expect(find.text(kMapChartOverlayCmdAnalyze), findsOneWidget);
    expect(find.text(kMapChartOverlayCmdGpx), findsOneWidget);
  });

  testWidgets('ChartOverlayMiniLegend render', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ChartOverlayMiniLegend(),
        ),
      ),
    );
    expect(find.text(kMapChartOverlayMiniLegendTitle), findsOneWidget);
  });

  testWidgets('PhotoAnalysisLoadingOverlay render', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PhotoAnalysisLoadingOverlay(),
        ),
      ),
    );
    expect(find.text(kMapFabScanning), findsOneWidget);
  });

  testWidgets('MapHotspotDetailPanel embedded chart render', (tester) async {
    final hotspot = _testHotspot();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: SizedBox(
            height: 600,
            child: MapHotspotDetailPanel(
              embedded: true,
              hotspot: hotspot,
              onClose: () {},
              onGo: () {},
              onCompare: () {},
              onSave: () {},
              detailSheet: HotspotDetailSheet(
                hotspot: hotspot,
                slidePanel: true,
                geoVisualization: GeoVisualizationState(
                  coordinateMode: kCoordinateModeImageSpace,
                  reliability: CalibrationReliability.approximate,
                  calibrationQuality: 0.5,
                  transformConfidence: 0.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(kMapPremiumHotspotGo), findsOneWidget);
  });

  testWidgets('MapPremiumLegend world map regression', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MapPremiumLegend(
            visible: true,
            showIntensity: true,
            showCorridor: false,
          ),
        ),
      ),
    );
    expect(find.text(kMapPremiumLegendTitleShort), findsOneWidget);
  });
}
