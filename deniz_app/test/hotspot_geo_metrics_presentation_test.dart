import 'package:deniz_app/api_service.dart';
import 'package:deniz_app/domain/geo_visualization_state.dart';
import 'package:deniz_app/domain/hotspot_geo_metrics_presentation.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:flutter_test/flutter_test.dart';

Hotspot _minimalHotspot({required String mappingTrust}) {
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
    'mapping_trust': mappingTrust,
    'is_renderable': true,
    'fishing_advice': <String, dynamic>{
      'species_predictions': <dynamic>[],
      'bait': <dynamic>[],
      'best_times': <dynamic>[],
      'tackle': <dynamic>[],
      'selection_reasons': <dynamic>[],
    },
    'confirmed_depth': <String, dynamic>{},
    'likely_species': <String, dynamic>{
      'source': 'none',
      'fallback': true,
      'total_records_considered': 0,
      'top_species': <dynamic>[],
    },
  });
}

GeoVisualizationState _viz({
  required String coordinateMode,
  required CalibrationReliability reliability,
}) {
  return GeoVisualizationState(
    coordinateMode: coordinateMode,
    reliability: reliability,
    calibrationQuality: 0.85,
    transformConfidence: 0.85,
  );
}

void main() {
  group('HotspotGeoMetricsPresentation', () {
    test('geo_referenced + güvenilir → gerçek sayılar', () {
      final h = _minimalHotspot(mappingTrust: 'chart_aligned');
      final p = HotspotGeoMetricsPresentation.fromHotspot(
        h,
        geoVisualization: _viz(
          coordinateMode: kCoordinateModeGeoReferenced,
          reliability: CalibrationReliability.excellent,
        ),
      );
      expect(p.isNumericContext, isTrue);
      expect(p.latitudeText, "37°21.120' N");
      expect(p.longitudeText, "027°12.180' E");
      expect(p.distanceText, '125.4 m');
      expect(p.bearingText, '88.2°');
    });

    test('image_space → yer tutucular', () {
      final h = _minimalHotspot(mappingTrust: 'image_space');
      final p = HotspotGeoMetricsPresentation.fromHotspot(
        h,
        geoVisualization: _viz(
          coordinateMode: kCoordinateModeImageSpace,
          reliability: CalibrationReliability.unsafe,
        ),
      );
      expect(p.isNumericContext, isFalse);
      expect(p.latitudeText, '—');
      expect(p.longitudeText, '—');
      expect(p.distanceText, 'Hesaplanamıyor');
      expect(p.bearingText, 'Kullanılamıyor');
    });

    test('unsafe kalibrasyon → yer tutucular', () {
      final h = _minimalHotspot(mappingTrust: 'approximate_world_fallback');
      final p = HotspotGeoMetricsPresentation.fromHotspot(
        h,
        geoVisualization: _viz(
          coordinateMode: kCoordinateModeGeoReferenced,
          reliability: CalibrationReliability.unsafe,
        ),
      );
      expect(p.isNumericContext, isFalse);
      expect(p.latitudeText, '—');
      expect(p.distanceText, 'Hesaplanamıyor');
    });

    test('geo_referenced + güvenilir ama 0/0 sentinel → lat/lon yer tutucu', () {
      final h = Hotspot.fromJson({
        ..._minimalHotspot(mappingTrust: 'chart_aligned').toJson(),
        'latitude': 0.0,
        'longitude': 0.0,
        'geo_coordinate': {'lat': 0.0, 'lon': 0.0},
      });
      final p = HotspotGeoMetricsPresentation.fromHotspot(
        h,
        geoVisualization: _viz(
          coordinateMode: kCoordinateModeGeoReferenced,
          reliability: CalibrationReliability.good,
        ),
      );
      expect(p.isNumericContext, isFalse);
      expect(p.latitudeText, '—');
      expect(p.longitudeText, '—');
    });

    test('distance/bearing yok ama boatPosition varsa hesaplanır', () {
      final h = Hotspot.fromJson({
        ..._minimalHotspot(mappingTrust: 'chart_aligned').toJson(),
        'distance_m': null,
        'bearing_deg': null,
      });
      final p = HotspotGeoMetricsPresentation.fromHotspot(
        h,
        geoVisualization: _viz(
          coordinateMode: kCoordinateModeGeoReferenced,
          reliability: CalibrationReliability.excellent,
        ),
        boatPosition: LatLon(lat: 37.351, lon: 27.202),
      );
      expect(p.latitudeText, "37°21.120' N");
      expect(p.longitudeText, "027°12.180' E");
      expect(p.distanceText, isNot(kHotspotGeoDistanceUnavailable));
      expect(p.bearingText, isNot(kHotspotGeoBearingUnavailable));
    });

    test('viz null + mapping_trust image_space → yer tutucu', () {
      final h = _minimalHotspot(mappingTrust: 'image_space');
      final p = HotspotGeoMetricsPresentation.fromHotspot(h);
      expect(p.isNumericContext, isFalse);
    });

    test('viz null + geo mapping_trust → sayısal', () {
      final h = _minimalHotspot(mappingTrust: 'approximate_world_fallback');
      final p = HotspotGeoMetricsPresentation.fromHotspot(h);
      expect(p.isNumericContext, isTrue);
      expect(p.latitudeText, contains('37'));
    });

    test('yaklaşık güven ama geo_referenced → sayısal', () {
      final h = _minimalHotspot(mappingTrust: 'approximate_world_fallback');
      final p = HotspotGeoMetricsPresentation.fromHotspot(
        h,
        geoVisualization: _viz(
          coordinateMode: kCoordinateModeGeoReferenced,
          reliability: CalibrationReliability.approximate,
        ),
      );
      expect(p.isNumericContext, isTrue);
      expect(p.distanceText, '125.4 m');
    });
  });
}
