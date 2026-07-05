import 'package:deniz_app/api_service.dart';
import 'package:deniz_app/domain/ai_assistant_request.dart';
import 'package:deniz_app/domain/ai_assistant_response.dart';
import 'package:deniz_app/services/ai_assistant_cache.dart';
import 'package:flutter_test/flutter_test.dart';

FishingZoneResponse _analysis() {
  return FishingZoneResponse.fromJson({
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
        'score': 0.8,
        'classification': 'A',
        'reasoning': [],
        'supporting_metrics': {},
        'sea_state': {},
        'pixel_centroid': {'x': 0, 'y': 0},
        'hotspot_pixel_anchor': {'x': 0, 'y': 0},
        'trust_state': 'trusted',
        'trust_score': 1,
        'mapping_trust': 'geo_referenced',
        'is_renderable': true,
        'recommendation_rank': 1,
      },
    ],
    'coordinate_mode': 'geo_referenced',
    'session_advice': 'Test',
  });
}

AiAssistantResponse _response(String summary, {String source = 'ai'}) {
  return AiAssistantResponse.fromJson({
    'source': source,
    'prompt_version': 'v1',
    'summary_tr': summary,
    'confidence': 'medium',
    'recommended_actions': [],
    'hotspot_insights': [],
    'conditions_comment_tr': '',
    'species_comment_tr': '',
    'limitations_tr': [],
    'safety_reminders_tr': [],
    if (source == 'fallback') 'fallback_reason': 'missing_api_key',
  });
}

void main() {
  group('AiAssistantCache', () {
    test('different scope/focus/question produce different keys', () {
      final cache = AiAssistantCache();
      final analysis = _analysis();

      cache.put(
        analysis,
        _response('session'),
        scope: AiAssistantScope.sessionSummary,
      );
      cache.put(
        analysis,
        _response('hotspot'),
        scope: AiAssistantScope.hotspotDetail,
        focusHotspotId: 10,
      );
      cache.put(
        analysis,
        _response('question'),
        scope: AiAssistantScope.hotspotDetail,
        focusHotspotId: 10,
        userQuestion: 'Levrek?',
      );

      expect(
        cache.get(analysis, scope: AiAssistantScope.sessionSummary)?.summaryTr,
        'session',
      );
      expect(
        cache.get(
          analysis,
          scope: AiAssistantScope.hotspotDetail,
          focusHotspotId: 10,
        )?.summaryTr,
        'hotspot',
      );
      expect(
        cache.get(
          analysis,
          scope: AiAssistantScope.hotspotDetail,
          focusHotspotId: 10,
          userQuestion: 'Levrek?',
        )?.summaryTr,
        'question',
      );
    });

    test('forceRefresh bypasses cache', () {
      final cache = AiAssistantCache();
      final analysis = _analysis();
      cache.put(analysis, _response('cached'));

      expect(cache.get(analysis), isNotNull);
      expect(cache.get(analysis, forceRefresh: true), isNull);
      expect(
        cache.getForRequest(
          analysis,
          const AiAssistantRequest(),
          forceRefresh: true,
        ),
        isNull,
      );
    });

    test('normalized question in fingerprint ignores outer whitespace', () {
      final cache = AiAssistantCache();
      final analysis = _analysis();
      cache.put(
        analysis,
        _response('q'),
        userQuestion: '  Sabah mı?  ',
      );

      expect(
        cache.get(analysis, userQuestion: 'Sabah mı?')?.summaryTr,
        'q',
      );
    });

    test('fallback responses are not stored or returned from cache', () {
      final cache = AiAssistantCache();
      final analysis = _analysis();
      cache.put(analysis, _response('fallback summary', source: 'fallback'));

      expect(cache.get(analysis), isNull);
    });
  });
}
