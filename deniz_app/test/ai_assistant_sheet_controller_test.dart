import 'dart:convert';

import 'package:deniz_app/api_service.dart';
import 'package:deniz_app/domain/ai_assistant_request.dart';
import 'package:deniz_app/domain/ai_assistant_response.dart';
import 'package:deniz_app/services/ai_assistant_cache.dart';
import 'package:deniz_app/services/ai_assistant_sheet_controller.dart';
import 'package:deniz_app/services/client_identity_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

FishingZoneResponse _analysis() {
  return FishingZoneResponse.fromJson({
    'boat': {
      'raw_gps': {'lat': 37.0, 'lon': 27.0},
      'smoothed_gps': {'lat': 37.0, 'lon': 27.0},
    },
    'ranked_hotspots': [
      {
        'id': 1,
        'feature_type': 'drop_off',
        'rank_by_proximity': 1,
        'rank': 1,
        'rank_overall': 1,
        'rank_by_score_then_distance': 1,
        'score': 0.7,
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
      },
    ],
    'coordinate_mode': 'geo_referenced',
    'session_advice': 'Oturum',
  });
}

http.Response _okJson(String summary) {
  return http.Response.bytes(
    utf8.encode(
      jsonEncode({
        'source': 'ai',
        'prompt_version': 'v1',
        'summary_tr': summary,
        'confidence': 'medium',
        'recommended_actions': [],
        'hotspot_insights': [],
        'conditions_comment_tr': '',
        'species_comment_tr': '',
        'limitations_tr': [],
        'safety_reminders_tr': [],
      }),
    ),
    200,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AiAssistantSheetController', () {
    test('refresh bypasses cache and replaces response', () async {
      final cache = AiAssistantCache();
      final analysis = _analysis();
      var callCount = 0;
      final api = ApiService(
        serverBaseUrl: 'http://127.0.0.1:8000',
        client: MockClient((_) async {
          callCount++;
          return _okJson(callCount == 1 ? 'İlk' : 'Yeni');
        }),
      );
      final controller = AiAssistantSheetController(
        apiService: api,
        analysis: analysis,
        cache: cache,
        request: const AiAssistantRequest(),
        clientIdentityService: ClientIdentityService(),
      );

      await controller.loadInitial();
      expect(controller.response?.summaryTr, 'İlk');

      await controller.refresh();
      expect(controller.response?.summaryTr, 'Yeni');
      expect(controller.refreshErrorBanner, isNull);
      expect(callCount, 2);
    });

    test('refresh failure keeps previous response', () async {
      final cache = AiAssistantCache();
      final analysis = _analysis();
      var callCount = 0;
      final api = ApiService(
        serverBaseUrl: 'http://127.0.0.1:8000',
        client: MockClient((_) async {
          callCount++;
          if (callCount == 1) return _okJson('Korunan');
          return http.Response('', 503);
        }),
      );
      final controller = AiAssistantSheetController(
        apiService: api,
        analysis: analysis,
        cache: cache,
        request: const AiAssistantRequest(),
        clientIdentityService: ClientIdentityService(),
      );

      await controller.loadInitial();
      await controller.refresh();

      expect(controller.response?.summaryTr, 'Korunan');
      expect(controller.refreshErrorBanner, isNotNull);
    });

    test('loadInitial shows cache-only when API fails but cache exists', () async {
      final cache = AiAssistantCache();
      final analysis = _analysis();
      cache.put(
        analysis,
        AiAssistantResponse.fromJson({
          'source': 'ai',
          'prompt_version': 'v1',
          'summary_tr': 'Önbellek',
          'confidence': 'medium',
          'recommended_actions': [],
          'hotspot_insights': [],
          'conditions_comment_tr': '',
          'species_comment_tr': '',
          'limitations_tr': [],
          'safety_reminders_tr': [],
        }),
      );

      final api = ApiService(
        serverBaseUrl: 'http://127.0.0.1:8000',
        client: MockClient((_) async => http.Response('', 503)),
      );
      final controller = AiAssistantSheetController(
        apiService: api,
        analysis: analysis,
        cache: cache,
        request: const AiAssistantRequest(),
        clientIdentityService: ClientIdentityService(),
        forceRefreshOnOpen: true,
      );

      await controller.loadInitial();

      expect(controller.phase, AiSheetPhase.ready);
      expect(controller.cacheOnlyMode, isTrue);
      expect(controller.response?.summaryTr, 'Önbellek');
    });
  });
}
