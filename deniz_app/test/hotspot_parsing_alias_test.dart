import 'package:deniz_app/api_service.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _baseHotspotJson() => {
  'id': 1,
  'feature_type': 'drop_off',
  'rank_by_proximity': 1,
  'rank': 1,
  'rank_overall': 1,
  'rank_by_score_then_distance': 1,
  'geo_coordinate': {'lat': 36.12345, 'lon': 28.54321},
  'score': 0.85,
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
  'confirmed_depth': <String, dynamic>{},
  'likely_species': <String, dynamic>{
    'source': 'none',
    'fallback': true,
    'total_records_considered': 0,
    'top_species': <dynamic>[],
  },
};

void main() {
  group('Hotspot.fromJson alias parsing', () {
    test('lat/lon + distanceMeters/bearingDegrees + alternate fishing_advice keys', () {
      final json = _baseHotspotJson()
        ..remove('geo_coordinate')
        ..addAll({
          'lat': 36.11111,
          'lon': 28.22222,
          'distanceMeters': 321.5,
          'bearingDegrees': 12.3,
          'fishing_advice': <String, dynamic>{
            'possible_species': [
              {'species': 'Levrek', 'probability': 'high'},
            ],
            'bait_recommendation': ['Sardalya parçası'],
            'best_fishing_times': ['Gün doğumu civarı'],
            'tackle_recommendation': ['Dip oltası'],
            'species_reasoning': ['Kırık hattı kenarı'],
          },
        });

      final h = Hotspot.fromJson(json);
      expect(h.latitude, closeTo(36.11111, 1e-9));
      expect(h.longitude, closeTo(28.22222, 1e-9));
      expect(h.distanceM, closeTo(321.5, 1e-9));
      expect(h.bearingDeg, closeTo(12.3, 1e-9));
      expect(h.fishingAdvice.speciesPredictions, isNotEmpty);
      expect(h.fishingAdvice.bait, contains('Sardalya parçası'));
      expect(h.fishingAdvice.bestTimes, contains('Gün doğumu civarı'));
      expect(h.fishingAdvice.tackle, contains('Dip oltası'));
      expect(h.fishingAdvice.selectionReasons, contains('Kırık hattı kenarı'));
    });
  });
}

