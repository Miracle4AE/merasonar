import 'package:flutter_test/flutter_test.dart';

import 'package:deniz_app/api_service.dart';

void main() {
  test('Hotspot parse dayanıklı: map tipleri ve eksik opsiyonel alanlar', () {
    final response = FishingZoneResponse.fromJson({
      'boat': {
        'raw_gps': {'lat': 37.35, 'lon': 27.20},
        'smoothed_gps': {'lat': 37.351, 'lon': 27.201},
      },
      'ranked_hotspots': [
        {
          'id': 1,
          'feature_type': 'drop_off',
          'rank': 1,
          'rank_overall': 1,
          'rank_by_score_then_distance': 1,
          'rank_by_proximity': 3,
          'latitude': 37.352,
          'longitude': 27.203,
          'distance_m': 120.5,
          'bearing_deg': 45.2,
          'score': 0.81,
          'classification': 'A',
          'reasoning': ['High contour density'],
          'supporting_metrics': {'slope': 0.62},
          'geo_coordinate': {'lat': 37.352, 'lon': 27.203},
          'sea_state': {
            'wave_height_m': 0.8,
            'source': 'open_meteo_marine',
            'fallback': false,
          },
          'confirmed_depth': {
            'depth_m': 42.5,
            'source': 'opentopodata_gebco2020',
            'fallback': false,
          },
          'likely_species': {
            'source': 'obis_occurrence',
            'fallback': false,
            'top_species': [
              {'species': 'Sparus aurata', 'occurrence_count': 4},
            ],
          },
        },
        {
          'id': 2,
          'feature_type': 'ridge_spur',
          'distance_m': '98.2',
          'bearing_deg': '10.1',
          'score': '0.55',
          'classification': 'b',
          'geo_coordinate': {'lat': 37.353, 'lon': 27.204},
          // reasoning/supporting_metrics intentionally absent
        },
      ],
    });

    expect(response.hotspots.length, 2);

    final h1 = response.hotspots.first;
    expect(h1.classification, 'A');
    expect(h1.reasoning, isNotEmpty);
    expect(h1.supportingMetrics['slope'], 0.62);
    expect(h1.seaState.source, 'open_meteo_marine');
    expect(h1.confirmedDepth.depthM, closeTo(42.5, 0.0001));
    expect(h1.likelySpecies.topSpecies.first.species, 'Sparus aurata');

    final h2 = response.hotspots[1];
    expect(h2.classification, 'B');
    expect(h2.reasoning, isEmpty);
    expect(h2.supportingMetrics, isEmpty);
    expect(h2.distanceM, closeTo(98.2, 0.0001));
    expect(h2.score, closeTo(0.55, 0.0001));
    expect(h2.seaState.fallback, false);
    expect(h2.likelySpecies.topSpecies, isEmpty);
  });
}
