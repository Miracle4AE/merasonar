import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deniz_app/api_service.dart';
import 'package:deniz_app/domain/calibration_geometry.dart';
import 'package:deniz_app/domain/geo_visualization_state.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/map/widgets/calibrated_mode_ribbon.dart';

void main() {
  group('assessGeoTriangle', () {
    test('3 duplicate coordinate -> invalid', () {
      final p = LatLon(lat: 37.4, lon: 27.2);
      final r = assessGeoTriangle([p, p, p]);
      expect(r.level, CalibrationGeometryLevel.invalid);
      expect(r.reasonCode, 'duplicate_geo');
    });

    test('3 exactly collinear coordinate -> invalid', () {
      final r = assessGeoTriangle([
        LatLon(lat: 37.0, lon: 27.0),
        LatLon(lat: 37.1, lon: 27.0),
        LatLon(lat: 37.2, lon: 27.0),
      ]);
      expect(r.level, CalibrationGeometryLevel.invalid);
    });

    test('user thin north-south triangle -> lowConfidence', () {
      final r = assessGeoTriangle(kExampleThinNorthSouthCalibrationCoords());
      expect(r.level, CalibrationGeometryLevel.lowConfidence);
      expect(r.reasonCode, 'thin_geo_triangle');
      expect(r.maxEdgeM, greaterThan(4000));
      expect(r.crossTrackSpreadM, lessThan(1200));
    });

    test('3 wide triangle coordinate -> valid', () {
      final r = assessGeoTriangle([
        LatLon(lat: 36.00, lon: 27.00),
        LatLon(lat: 36.02, lon: 27.00),
        LatLon(lat: 36.00, lon: 27.04),
      ]);
      expect(r.level, CalibrationGeometryLevel.valid);
    });
  });

  group('assessPixelTriangle', () {
    test('pixel points thin triangle -> lowConfidence', () {
      final r = assessPixelTriangle([
        (x: 0.0, y: 0.0),
        (x: 500.0, y: 0.0),
        (x: 495.0, y: 60.0),
      ]);
      expect(r.level, CalibrationGeometryLevel.lowConfidence);
    });

    test('pixel points wide triangle -> valid', () {
      final r = assessPixelTriangle([
        (x: 0.0, y: 0.0),
        (x: 400.0, y: 0.0),
        (x: 200.0, y: 300.0),
      ]);
      expect(r.level, CalibrationGeometryLevel.valid);
    });
  });

  group('assessHotspotGeoAlignment', () {
    List<Hotspot> stringHotspots() {
      return List<Hotspot>.generate(10, (i) {
        final lat = 37.40 + i * 0.001;
        return Hotspot(
          id: i,
          featureType: 'drop_off',
          rankByProximity: i,
          rank: 1,
          rankOverall: 1,
          rankByScoreThenDistance: i,
          geoCoordinate: LatLon(lat: lat, lon: 27.20),
          latitude: lat,
          longitude: 27.20,
          distanceM: 100,
          bearingDeg: 0,
          score: 0.8,
          classification: 'A',
          reasoning: const [],
          supportingMetrics: const {},
          seaState: SeaState.fromJson(const {}),
          pixelCentroid: const {},
          hotspotPixelAnchor: PixelAnchor(x: 0, y: 0),
          trustState: 'ok',
          trustScore: 0.8,
          mappingTrust: 'ok',
          isRenderable: true,
          fishingAdvice: FishingAdvice.fromJson(const {}),
          confirmedDepth: ConfirmedDepth.fromJson(const {}),
          likelySpecies: BiodiversityInfo.fromJson(const {}),
        );
      });
    }

    Hotspot makeHotspot(int id, double lat, double lon) {
      return Hotspot(
        id: id,
        featureType: 'drop_off',
        rankByProximity: id,
        rank: 1,
        rankOverall: 1,
        rankByScoreThenDistance: id,
        geoCoordinate: LatLon(lat: lat, lon: lon),
        latitude: lat,
        longitude: lon,
        distanceM: 100,
        bearingDeg: 0,
        score: 0.8,
        classification: 'A',
        reasoning: const [],
        supportingMetrics: const {},
        seaState: SeaState.fromJson(const {}),
        pixelCentroid: const {},
        hotspotPixelAnchor: PixelAnchor(x: 0, y: 0),
        trustState: 'ok',
        trustScore: 0.8,
        mappingTrust: 'ok',
        isRenderable: true,
        fishingAdvice: FishingAdvice.fromJson(const {}),
        confirmedDepth: ConfirmedDepth.fromJson(const {}),
        likelySpecies: BiodiversityInfo.fromJson(const {}),
      );
    }

    test('marker alignment detector catches string-like output', () {
      final r = assessHotspotGeoAlignment(stringHotspots());
      expect(r.isStringLike, isTrue);
      expect(r.sampleCount, 10);
    });

    test('valid spread markers do not trigger warning', () {
      final spread = [
        makeHotspot(1, 37.40, 27.20),
        makeHotspot(2, 37.41, 27.22),
        makeHotspot(3, 37.39, 27.24),
        makeHotspot(4, 37.42, 27.21),
        makeHotspot(5, 37.38, 27.23),
        makeHotspot(6, 37.41, 27.25),
      ];
      final r = assessHotspotGeoAlignment(spread);
      expect(r.isStringLike, isFalse);
    });
  });

  group('GeoVisualizationState client validation', () {
    Map<String, dynamic> baseZone() => {
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
              'latitude': 37.0,
              'longitude': 27.0,
              'geo_coordinate': {'lat': 37.0, 'lon': 27.0},
              'score': 0.8,
            },
          ],
        };

    test('thin client geometry downgrades excellent to approximate ribbon', () {
      final r = FishingZoneResponse.fromJson(baseZone());
      final thin = assessGeoTriangle(kExampleThinNorthSouthCalibrationCoords());
      final viz = GeoVisualizationState.fromFishingZone(
        r,
        clientGeometry: thin,
      );
      expect(viz.confidenceLevel, CalibrationConfidenceLevel.lowConfidence);
      expect(viz.showLowConfidenceRibbon, isTrue);
      expect(viz.showValidCalibrationRibbon, isFalse);
      expect(viz.isReliableForNavigation, isFalse);
    });
  });

  group('CalibratedModeRibbon', () {
    testWidgets('low confidence banner text renders', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalibratedModeRibbon(
              showExperienceSwitcher: true,
              geoViz: GeoVisualizationState(
                coordinateMode: kCoordinateModeGeoReferenced,
                reliability: CalibrationReliability.approximate,
                calibrationQuality: 0.9,
                transformConfidence: 0.9,
                clientGeometry: assessGeoTriangle(
                  kExampleThinNorthSouthCalibrationCoords(),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.textContaining('düşük güvenilirlikte'), findsOneWidget);
    });

    testWidgets('valid calibration banner text renders', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalibratedModeRibbon(
              showExperienceSwitcher: true,
              geoViz: const GeoVisualizationState(
                coordinateMode: kCoordinateModeGeoReferenced,
                reliability: CalibrationReliability.excellent,
                calibrationQuality: 0.9,
                transformConfidence: 0.9,
              ),
            ),
          ),
        ),
      );
      expect(find.text(kMapModeBannerCalibrated), findsOneWidget);
      expect(
        find.textContaining('gerçek konuma oturmuş'),
        findsNothing,
      );
    });
  });
}
