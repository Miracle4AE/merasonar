import 'package:deniz_app/api_service.dart';
import 'package:deniz_app/services/gpx_export_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buildDocument üretir, koordinat ve XML kaçışı doğru', () {
    final h = Hotspot.fromJson({
      'id': 7,
      'feature_type': 'test',
      'rank_by_proximity': 2,
      'rank': 2,
      'rank_overall': 2,
      'rank_by_score_then_distance': 2,
      'geo_coordinate': {'lat': 40.5, 'lon': 28.1},
      'latitude': 40.5,
      'longitude': 28.1,
      'distance_m': 500,
      'bearing_deg': 45,
      'score': 0.88,
      'classification': 'A',
      'reasoning': ['A & B < C > 1'],
      'supporting_metrics': <String, dynamic>{},
      'sea_state': <String, dynamic>{'source': 't'},
      'pixel_centroid': <String, dynamic>{'x': 1, 'y': 2},
      'hotspot_pixel_anchor': <String, dynamic>{'x': 1, 'y': 2},
      'trust_state': 'trusted',
      'fishing_advice': <String, dynamic>{},
      'confirmed_depth': <String, dynamic>{},
      'likely_species': <String, dynamic>{},
    });

    final gpx = GpxExportService.buildDocument([h]);

    expect(gpx, contains('<gpx version="1.1"'));
    expect(gpx, contains('lat="40.5000000"'));
    expect(gpx, contains('lon="28.1000000"'));
    expect(gpx, contains('A &amp; B &lt; C &gt; 1'));
    expect(gpx, contains('M7_A_r2'));
  });

  test('suggestedFileName tekil noktada id ve sınıf içerir', () {
    final h = Hotspot.fromJson({
      'id': 7,
      'feature_type': 'x',
      'rank_by_proximity': 1,
      'rank': 1,
      'rank_overall': 1,
      'rank_by_score_then_distance': 1,
      'geo_coordinate': {'lat': 40.0, 'lon': 28.0},
      'latitude': 40.0,
      'longitude': 28.0,
      'distance_m': 0,
      'bearing_deg': 0,
      'score': 0.5,
      'classification': 'B',
      'reasoning': <String>[],
      'supporting_metrics': <String, dynamic>{},
      'sea_state': <String, dynamic>{},
      'pixel_centroid': <String, dynamic>{'x': 0, 'y': 0},
      'hotspot_pixel_anchor': <String, dynamic>{'x': 0, 'y': 0},
      'trust_state': 'trusted',
      'fishing_advice': <String, dynamic>{},
      'confirmed_depth': <String, dynamic>{},
      'likely_species': <String, dynamic>{},
    });
    final name = GpxExportService.suggestedFileName(single: h);
    expect(name, startsWith('deniz_mera_h7_B_'));
    expect(name, endsWith('.gpx'));
  });
}
