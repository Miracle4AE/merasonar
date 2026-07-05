import 'dart:convert';

import 'package:deniz_app/api_service.dart';
import 'package:deniz_app/domain/ai_assistant_response.dart';
import 'package:deniz_app/domain/fishing_zone_ai_payload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('toAiAnalysisJson omits heavy fields and limits hotspots', () {
    final hotspots = List<Map<String, dynamic>>.generate(20, (i) {
      return {
        'id': i + 1,
        'feature_type': 'drop_off',
        'rank_by_proximity': i,
        'rank': i,
        'rank_overall': i,
        'rank_by_score_then_distance': i,
        'score': 0.5,
        'classification': 'C',
        'reasoning': ['r'],
        'supporting_metrics': {'slope': 0.1},
        'sea_state': {},
        'pixel_centroid': {'x': 0, 'y': 0},
        'hotspot_pixel_anchor': {'x': 0, 'y': 0},
        'trust_state': 'trusted',
        'trust_score': 1,
        'mapping_trust': 'image_space',
        'is_renderable': true,
        'recommendation_rank': i + 1,
      };
    });

    final response = FishingZoneResponse.fromJson({
      'boat': {
        'raw_gps': {'lat': 0, 'lon': 0},
        'smoothed_gps': {'lat': 0, 'lon': 0},
      },
      'ranked_hotspots': hotspots,
      'coordinate_mode': 'image_space',
    });

    final json = response.toAiAnalysisJson();
    expect(json.containsKey('ranked_hotspots'), isFalse);
    expect((json['hotspots'] as List).length, lessThanOrEqualTo(15));
    final first = (json['hotspots'] as List).first as Map<String, dynamic>;
    expect(first.containsKey('latitude'), isFalse);
    expect(first.containsKey('fishing_advice'), isFalse);
  });

  test('toAiAnalysisJson is JSON encodable', () {
    final response = FishingZoneResponse.fromJson({
      'boat': {
        'raw_gps': {'lat': 37.0, 'lon': 27.0},
        'smoothed_gps': {'lat': 37.0, 'lon': 27.0},
      },
      'ranked_hotspots': [
        {
          'id': 10,
          'feature_type': 'drop_off',
          'rank_by_proximity': 1,
          'rank': 1,
          'rank_overall': 1,
          'rank_by_score_then_distance': 1,
          'latitude': 37.01,
          'longitude': 27.01,
          'geo_coordinate': {'lat': 37.01, 'lon': 27.01},
          'score': 0.8,
          'classification': 'A',
          'reasoning': ['test'],
          'supporting_metrics': {'slope': 0.5},
          'sea_state': {'source': 'unknown'},
          'pixel_centroid': {'x': 1, 'y': 2},
          'hotspot_pixel_anchor': {'x': 1, 'y': 2},
          'trust_state': 'trusted',
          'trust_score': 1,
          'mapping_trust': 'geo_referenced',
          'is_renderable': true,
          'recommendation_rank': 1,
        },
      ],
      'coordinate_mode': 'geo_referenced',
    });
    expect(
      () => jsonEncode({'analysis': response.toAiAnalysisJson()}),
      returnsNormally,
    );
    final parsed = AiAssistantResponse.fromJson({
      'source': 'ai',
      'prompt_version': 'v1',
      'summary_tr': 'x',
      'confidence': 'medium',
      'recommended_actions': [],
      'hotspot_insights': [],
      'conditions_comment_tr': '',
      'species_comment_tr': '',
      'limitations_tr': [],
      'safety_reminders_tr': [],
    });
    expect(parsed.summaryTr, 'x');
  });
}
