import 'dart:io';
import 'dart:ui' as ui;

import 'package:deniz_app/api_service.dart';
import 'package:deniz_app/domain/calibration_geometry.dart';
import 'package:deniz_app/domain/geo_visualization_state.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/map/widgets/calibrated_mode_ribbon.dart';
import 'package:deniz_app/map/widgets/premium/map_hotspot_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// RC1 Build9.6 — calibration confidence manual QA PNG exports.
/// Run: flutter test test/widget/calibration_confidence_manual_qa_test.dart

Directory _outDir() {
  const fromEnv = String.fromEnvironment('CALIB_QA_OUT');
  if (fromEnv.isNotEmpty) {
    final dir = Directory(fromEnv);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }
  final cwd = Directory.current;
  final root = cwd.path.endsWith('deniz_app') ? cwd.parent : cwd;
  final out = Directory(p.join(root.path, 'docs', 'screenshots', 'rc1'));
  if (!out.existsSync()) out.createSync(recursive: true);
  return out;
}

Future<void> _savePng(WidgetTester tester, String fileName) async {
  await tester.pump();
  final boundary = tester.renderObject(
    find.byType(RepaintBoundary).first,
  ) as RenderRepaintBoundary;
  final outPath = p.join(_outDir().path, fileName);
  await tester.binding.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(outPath).writeAsBytes(bytes!.buffer.asUint8List());
  });
  expect(File(outPath).existsSync(), isTrue, reason: 'PNG not written: $outPath');
}

List<ImageControlPoint> _thinUserControlPoints() {
  final geos = kExampleThinNorthSouthCalibrationCoords();
  const pixels = [
    (x: 195.0, y: 20.0),
    (x: 210.0, y: 280.0),
    (x: 205.0, y: 560.0),
  ];
  return List<ImageControlPoint>.generate(
    3,
    (i) => ImageControlPoint(
      pixelX: pixels[i].x,
      pixelY: pixels[i].y,
      geo: geos[i],
    ),
  );
}

GeoVisualizationState _lowConfidenceMapViz() {
  final thin = assessGeoTriangle(kExampleThinNorthSouthCalibrationCoords());
  final stringHotspots = List<Hotspot>.generate(8, (i) {
    final lat = 37.395 + i * 0.0018;
    return Hotspot.fromJson({
      'id': i + 1,
      'feature_type': 'drop_off',
      'rank_by_proximity': i + 1,
      'rank': 1,
      'rank_overall': 1,
      'rank_by_score_then_distance': i + 1,
      'latitude': lat,
      'longitude': 27.195,
      'geo_coordinate': {'lat': lat, 'lon': 27.195},
      'distance_m': 100 + i * 50,
      'bearing_deg': 180,
      'score': 0.76,
      'classification': 'A',
      'reasoning': <String>[],
      'supporting_metrics': <String, dynamic>{},
      'sea_state': <String, dynamic>{},
      'pixel_centroid': {'x': 100.0, 'y': 200.0},
      'hotspot_pixel_anchor': {'x': 100.0, 'y': 200.0},
      'trust_state': 'trusted',
      'trust_score': 0.9,
      'mapping_trust': 'chart_aligned',
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
  });
  final align = assessHotspotGeoAlignment(stringHotspots);
  return GeoVisualizationState.fromFishingZone(
    FishingZoneResponse.fromJson({
      'coordinate_mode': kCoordinateModeGeoReferenced,
      'geo_map_display_allowed': true,
      'calibration_reliability': 'excellent',
      'diagnostics': {
        'georeference_error': 5.0,
        'transform_quality': 0.9,
        'mapping_mode': 'affine_control_points',
        'screenshot_aligned_mapping_used': true,
      },
      'ranked_hotspots': stringHotspots.map((h) => {
            'id': h.id,
            'latitude': h.latitude,
            'longitude': h.longitude,
            'geo_coordinate': {'lat': h.latitude, 'lon': h.longitude},
            'score': h.score,
          }).toList(),
    }),
    clientGeometry: thin,
    markerAlignment: align,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('export map-calibration-low-confidence-warning.png', (tester) async {
    final viz = _lowConfidenceMapViz();
    expect(viz.confidenceLevel, CalibrationConfidenceLevel.lowConfidence);
    expect(viz.showValidCalibrationRibbon, isFalse);

    final hotspots = List<Hotspot>.generate(4, (i) {
      final lat = 37.395 + i * 0.0018;
      return Hotspot.fromJson({
        'id': i + 1,
        'feature_type': 'drop_off',
        'rank_by_proximity': i + 1,
        'rank': 1,
        'rank_overall': 1,
        'rank_by_score_then_distance': i + 1,
        'latitude': lat,
        'longitude': 27.195,
        'geo_coordinate': {'lat': lat, 'lon': 27.195},
        'distance_m': 253 + i * 40,
        'bearing_deg': 282,
        'score': 0.76,
        'classification': 'A',
        'reasoning': <String>[],
        'supporting_metrics': <String, dynamic>{},
        'sea_state': <String, dynamic>{},
        'pixel_centroid': {'x': 100.0, 'y': 200.0},
        'hotspot_pixel_anchor': {'x': 100.0, 'y': 200.0},
        'trust_state': 'trusted',
        'trust_score': 0.9,
        'mapping_trust': 'chart_aligned',
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
    });

    await tester.binding.setSurfaceSize(const Size(1280, 720));
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          backgroundColor: const Color(0xFF071624),
          body: RepaintBoundary(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                CalibratedModeRibbon(
                  geoViz: viz,
                  showExperienceSwitcher: true,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'MeraSonar Map — RC1 Build9.6 thin triangle QA',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
                const Spacer(),
                MapHotspotStrip(
                  hotspots: hotspots,
                  mobile: false,
                  scoreFormatter: (s) => (s * 100).round(),
                  onTap: (_) {},
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('düşük güvenilirlikte'), findsOneWidget);
    expect(find.textContaining('gerçek konuma oturmuş'), findsNothing);
    await _savePng(tester, 'map-calibration-low-confidence-warning.png');
  });

  testWidgets('export map-calibration-picker-thin-warning.png', (tester) async {
    final thin = assessGeoTriangle(kExampleThinNorthSouthCalibrationCoords());
    expect(thin.isLowConfidence, isTrue);

    await tester.binding.setSurfaceSize(const Size(420, 520));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF071624),
          body: RepaintBoundary(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(kCalibSheetTitle, style: ThemeData.dark().textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0x33E65100),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFFCC80)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Icon(Icons.warning_amber_rounded, color: Colors.amber),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            kCalibReadyLowConfidence,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    kCalibLowConfidenceHelper,
                    style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.35),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Koordinatlar: 37°23.755\'N · 37°25.330\'N · 37°26.769\'N (thin triangle)',
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await _savePng(tester, 'map-calibration-picker-thin-warning.png');
  });

  testWidgets('export map-calibration-valid-wide-triangle.png', (tester) async {
    final wide = assessGeoTriangle([
      LatLon(lat: 36.04, lon: 29.00),
      LatLon(lat: 36.00, lon: 29.05),
      LatLon(lat: 36.04, lon: 29.05),
    ]);
    expect(wide.level, CalibrationGeometryLevel.valid);

    final viz = GeoVisualizationState.fromFishingZone(
      FishingZoneResponse.fromJson({
        'coordinate_mode': kCoordinateModeGeoReferenced,
        'geo_map_display_allowed': true,
        'calibration_reliability': 'excellent',
        'diagnostics': {
          'georeference_error': 5.0,
          'transform_quality': 0.9,
          'mapping_mode': 'affine_control_points',
          'screenshot_aligned_mapping_used': true,
        },
        'ranked_hotspots': [
          {
            'id': 1,
            'latitude': 36.02,
            'longitude': 29.02,
            'geo_coordinate': {'lat': 36.02, 'lon': 29.02},
            'score': 0.8,
          },
        ],
      }),
      clientGeometry: wide,
    );
    expect(viz.showValidCalibrationRibbon, isTrue);

    await tester.binding.setSurfaceSize(const Size(1280, 200));
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          backgroundColor: const Color(0xFF071624),
          body: RepaintBoundary(
            child: Column(
              children: [
                CalibratedModeRibbon(
                  geoViz: viz,
                  showExperienceSwitcher: true,
                ),
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Wide triangle geometry — valid calibration (synthetic QA panel)',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text(kMapModeBannerCalibrated), findsOneWidget);
    await _savePng(tester, 'map-calibration-valid-wide-triangle.png');
  });
}
