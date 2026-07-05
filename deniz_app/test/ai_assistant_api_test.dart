import 'dart:convert';

import 'package:deniz_app/api_service.dart';
import 'package:deniz_app/domain/ai_assistant_request.dart';
import 'package:deniz_app/domain/client_identity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

FishingZoneResponse _minimalAnalysis() {
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
    'session_advice': 'Test advice',
    'top_recommendations': [10],
  });
}

void main() {
  test('fetchAiFishingAssistant posts trimmed analysis payload', () async {
    http.Request? capturedRequest;
    final client = MockClient((request) async {
      capturedRequest = request;
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'source': 'ai',
            'model': 'test-model',
            'cache_hit': false,
            'locale': 'tr',
            'trust_note_tr': 'Not',
            'prompt_version': 'v1',
            'summary_tr': 'Özet',
            'confidence': 'medium',
            'recommended_actions': <dynamic>[],
            'hotspot_insights': <dynamic>[],
            'conditions_comment_tr': 'Koşul',
            'species_comment_tr': 'Tür',
            'limitations_tr': <dynamic>[],
            'safety_reminders_tr': <dynamic>[],
            'processing_ms': 10,
          }),
        ),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final api = ApiService(
      serverBaseUrl: 'http://127.0.0.1:8000',
      client: client,
    );
    final result = await api.fetchAiFishingAssistant(
      analysis: _minimalAnalysis(),
      clientRequestId: 'test-client-id',
    );

    expect(result.summaryTr, 'Özet');
    expect(capturedRequest, isNotNull);
    expect(capturedRequest!.url.path, '/api/v1/ai_fishing_assistant');
    final capturedBody =
        jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
    expect(capturedBody['scope'], 'session_summary');
    expect(capturedBody['client_request_id'], 'test-client-id');
    final analysis = capturedBody['analysis'] as Map<String, dynamic>;
    expect(analysis.containsKey('ranked_hotspots'), isFalse);
    expect((analysis['hotspots'] as List).length, 1);
  });

  test('fetchAiFishingAssistant hotspot_detail includes focus_hotspot_id', () async {
    http.Request? capturedRequest;
    final client = MockClient((request) async {
      capturedRequest = request;
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'source': 'ai',
            'prompt_version': 'v1',
            'summary_tr': 'Hotspot özet',
            'confidence': 'medium',
            'recommended_actions': <dynamic>[],
            'hotspot_insights': <dynamic>[],
            'conditions_comment_tr': '',
            'species_comment_tr': '',
            'limitations_tr': <dynamic>[],
            'safety_reminders_tr': <dynamic>[],
          }),
        ),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final api = ApiService(
      serverBaseUrl: 'http://127.0.0.1:8000',
      client: client,
    );
    await api.fetchAiFishingAssistant(
      analysis: _minimalAnalysis(),
      scope: AiAssistantScope.hotspotDetail,
      focusHotspotId: 10,
      clientRequestId: 'hotspot-req',
    );

    final body = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
    expect(body['scope'], AiAssistantScope.hotspotDetail);
    expect(body['focus_hotspot_id'], 10);
    expect(body.containsKey('user_question'), isFalse);
  });

  test('fetchAiFishingAssistant trims user_question to 500 chars', () async {
    http.Request? capturedRequest;
    final client = MockClient((request) async {
      capturedRequest = request;
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'source': 'ai',
            'prompt_version': 'v1',
            'summary_tr': 'Cevap',
            'confidence': 'medium',
            'recommended_actions': <dynamic>[],
            'hotspot_insights': <dynamic>[],
            'conditions_comment_tr': '',
            'species_comment_tr': '',
            'limitations_tr': <dynamic>[],
            'safety_reminders_tr': <dynamic>[],
          }),
        ),
        200,
      );
    });

    final api = ApiService(
      serverBaseUrl: 'http://127.0.0.1:8000',
      client: client,
    );
    final longQuestion = '  ${'x' * 600}  ';
    await api.fetchAiFishingAssistant(
      analysis: _minimalAnalysis(),
      userQuestion: longQuestion,
    );

    final body = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
    final sent = body['user_question'] as String;
    expect(sent.length, kAiAssistantMaxUserQuestionLength);
    expect(sent, 'x' * kAiAssistantMaxUserQuestionLength);
  });

  test('hotspot_detail without focusHotspotId throws', () async {
    final api = ApiService(
      serverBaseUrl: 'http://127.0.0.1:8000',
      client: MockClient((_) async => http.Response('', 500)),
    );
    expect(
      () => api.fetchAiFishingAssistant(
        analysis: _minimalAnalysis(),
        scope: AiAssistantScope.hotspotDetail,
      ),
      throwsArgumentError,
    );
  });

  test('fetchAiFishingAssistant live_context includes live_context body', () async {
    http.Request? capturedRequest;
    final client = MockClient((request) async {
      capturedRequest = request;
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'source': 'ai',
            'prompt_version': 'v1',
            'summary_tr': 'Canlı özet',
            'confidence': 'medium',
            'recommended_actions': <dynamic>[],
            'hotspot_insights': <dynamic>[],
            'conditions_comment_tr': '',
            'species_comment_tr': '',
            'limitations_tr': <dynamic>[],
            'safety_reminders_tr': <dynamic>[],
          }),
        ),
        200,
      );
    });

    final api = ApiService(
      serverBaseUrl: 'http://127.0.0.1:8000',
      client: client,
    );
    final liveContext = {
      'current_lat': 37.0,
      'current_lon': 27.0,
      'live_score': 80,
      'coordinate_mode': 'geo_referenced',
      'nearest_hotspot': 10,
      'distance_to_nearest': 100.0,
    };
    await api.fetchAiFishingAssistant(
      analysis: _minimalAnalysis(),
      scope: AiAssistantScope.liveContext,
      liveContext: liveContext,
    );

    final body = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
    expect(body['scope'], AiAssistantScope.liveContext);
    final live = body['live_context'] as Map<String, dynamic>;
    expect(live['live_score'], 80);
    expect(live['nearest_hotspot'], 10);
  });

  test('invalid scope throws ArgumentError', () async {
    final api = ApiService(
      serverBaseUrl: 'http://127.0.0.1:8000',
      client: MockClient((_) async => http.Response('', 500)),
    );
    expect(
      () => api.fetchAiFishingAssistant(
        analysis: _minimalAnalysis(),
        scope: 'unknown_scope',
      ),
      throwsArgumentError,
    );
  });

  test('fetchAiFishingAssistant without clientIdentity omits field', () async {
    http.Request? capturedRequest;
    final client = MockClient((request) async {
      capturedRequest = request;
      return http.Response(
        jsonEncode({
          'source': 'fallback',
          'prompt_version': 'v1',
          'summary_tr': 'x',
          'confidence': 'low',
          'recommended_actions': [],
          'hotspot_insights': [],
          'conditions_comment_tr': '',
          'species_comment_tr': '',
          'limitations_tr': [],
          'safety_reminders_tr': [],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = ApiService(serverBaseUrl: 'http://127.0.0.1:8000', client: client);
    await api.fetchAiFishingAssistant(analysis: _minimalAnalysis());
    final body = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
    expect(body.containsKey('client_identity'), isFalse);
  });

  test('fetchAiFishingAssistant includes client_identity when provided', () async {
    http.Request? capturedRequest;
    final client = MockClient((request) async {
      capturedRequest = request;
      return http.Response(
        jsonEncode({
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
          'remaining_ai_requests': 7,
          'is_premium_feature': true,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = ApiService(serverBaseUrl: 'http://127.0.0.1:8000', client: client);
    final result = await api.fetchAiFishingAssistant(
      analysis: _minimalAnalysis(),
      clientIdentity: const ClientIdentity(
        deviceId: 'test-device-uuid',
        platform: 'windows',
        appVersion: '1.0.0',
        isPremium: true,
      ),
    );
    final body = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
    final identity = body['client_identity'] as Map<String, dynamic>;
    expect(identity['device_id'], 'test-device-uuid');
    expect(identity['is_premium'], isTrue);
    expect(result.remainingAiRequests, 7);
    expect(result.isPremiumFeature, isTrue);
  });

  test('live_context without liveContext throws', () async {
    final api = ApiService(
      serverBaseUrl: 'http://127.0.0.1:8000',
      client: MockClient((_) async => http.Response('', 500)),
    );
    expect(
      () => api.fetchAiFishingAssistant(
        analysis: _minimalAnalysis(),
        scope: AiAssistantScope.liveContext,
      ),
      throwsArgumentError,
    );
  });
}
