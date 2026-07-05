import 'dart:convert';

import 'package:deniz_app/api_service.dart';
import 'package:deniz_app/domain/ai_assistant_response.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/map/widgets/ai_assistant_sheet.dart';
import 'package:deniz_app/services/ai_assistant_cache.dart';
import 'package:deniz_app/services/client_identity_service.dart';
import 'package:flutter/material.dart';
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
        'mapping_trust': 'image_space',
        'is_renderable': true,
      },
    ],
    'coordinate_mode': 'image_space',
    'session_advice': 'Oturum ipucu',
  });
}

Map<String, dynamic> _fallbackJson() => {
      'source': 'fallback',
      'prompt_version': 'v1',
      'summary_tr': 'Yedek özet metni',
      'confidence': 'low',
      'recommended_actions': [
        {
          'priority': 1,
          'title_tr': 'Plan',
          'detail_tr': 'Detay',
        },
      ],
      'hotspot_insights': [],
      'conditions_comment_tr': 'Koşullar',
      'species_comment_tr': 'Türler',
      'limitations_tr': ['Limit'],
      'safety_reminders_tr': ['Güvenlik'],
      'fallback_reason': 'missing_api_key',
      'processing_ms': 1,
    };

MockClient _fallbackApiClient() {
  return MockClient(
    (_) async => http.Response.bytes(utf8.encode(jsonEncode(_fallbackJson())), 200),
  );
}

AiAssistantResponse _cachedAiResponse() {
  return AiAssistantResponse.fromJson({
    'source': 'ai',
    'model': 'm',
    'cache_hit': true,
    'prompt_version': 'v1',
    'summary_tr': 'AI özet',
    'confidence': 'medium',
    'recommended_actions': [],
    'hotspot_insights': [],
    'conditions_comment_tr': 'c',
    'species_comment_tr': 's',
    'limitations_tr': [],
    'safety_reminders_tr': [],
    'processing_ms': 5,
  });
}

AiAssistantResponse _quotaPremiumResponse() {
  return AiAssistantResponse.fromJson({
    'source': 'ai',
    'model': 'test-model',
    'cache_hit': false,
    'prompt_version': 'v1',
    'summary_tr': 'Kota özet',
    'confidence': 'medium',
    'recommended_actions': [],
    'hotspot_insights': [],
    'conditions_comment_tr': 'c',
    'species_comment_tr': 's',
    'limitations_tr': [],
    'safety_reminders_tr': [],
    'remaining_ai_requests': 8,
    'is_premium_feature': true,
  });
}

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData.dark(useMaterial3: true),
    home: Scaffold(
      body: SizedBox(
        width: 400,
        height: 900,
        child: child,
      ),
    ),
  );
}

ClientIdentityService _identityService() => ClientIdentityService();

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('AiAssistantSheet smoke — fallback banner', (tester) async {
    final cache = AiAssistantCache();

    await tester.pumpWidget(
      _wrap(
        AiAssistantSheet(
          apiService: ApiService(
            serverBaseUrl: 'http://127.0.0.1:8000',
            client: _fallbackApiClient(),
          ),
          analysis: _analysis(),
          cache: cache,
          clientIdentityService: _identityService(),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle(const Duration(milliseconds: 200));

    expect(find.text(kAiAssistantTitle), findsOneWidget);
    expect(find.text(kCaptainAtlasChip), findsOneWidget);
    expect(find.text(kAiAssistantFallbackBanner), findsOneWidget);
    expect(find.text('Yedek özet metni'), findsOneWidget);
    expect(find.text(kAiAssistantSectionSummary), findsOneWidget);
  });

  testWidgets('AiAssistantSheet shows cache badge', (tester) async {
    final cache = AiAssistantCache();
    cache.put(_analysis(), _cachedAiResponse());

    await tester.pumpWidget(
      _wrap(
        AiAssistantSheet(
          apiService: ApiService(
            serverBaseUrl: 'http://127.0.0.1:8000',
            client: MockClient((_) async => http.Response('', 500)),
          ),
          analysis: _analysis(),
          cache: cache,
          clientIdentityService: _identityService(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text(kAiAssistantCacheBadge), findsOneWidget);
    expect(find.text('AI özet'), findsOneWidget);
  });

  testWidgets('AiAssistantSheet shows quota and AI Pro chips', (tester) async {
    final cache = AiAssistantCache();
    cache.put(_analysis(), _quotaPremiumResponse());

    await tester.pumpWidget(
      _wrap(
        AiAssistantSheet(
          apiService: ApiService(
            serverBaseUrl: 'http://127.0.0.1:8000',
            client: MockClient((_) async => http.Response('', 500)),
          ),
          analysis: _analysis(),
          cache: cache,
          clientIdentityService: _identityService(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text(kAiAssistantProBadge), findsOneWidget);
    expect(find.text(kAiAssistantQuotaBadgeFmt(8)), findsOneWidget);
    expect(find.text('test-model'), findsOneWidget);
  });

  testWidgets('AiAssistantSheet shows question field when ready', (tester) async {
    final cache = AiAssistantCache();

    await tester.pumpWidget(
      _wrap(
        AiAssistantSheet(
          apiService: ApiService(
            serverBaseUrl: 'http://127.0.0.1:8000',
            client: _fallbackApiClient(),
          ),
          analysis: _analysis(),
          cache: cache,
          clientIdentityService: _identityService(),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle(const Duration(milliseconds: 200));

    expect(find.text(kAiAssistantQuestionHint), findsOneWidget);
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    expect(find.text(kAiAssistantSectionHistory), findsNothing);
    expect(find.text('Yedek özet metni'), findsOneWidget);
  });

  testWidgets('AiAssistantSheet submits question and shows history', (
    tester,
  ) async {
    final cache = AiAssistantCache();

    http.Request? questionRequest;
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      if (body.containsKey('user_question')) {
        questionRequest = request;
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'source': 'ai',
              'prompt_version': 'v1',
              'summary_tr': 'Levrek için uygun görünüyor.',
              'confidence': 'medium',
              'recommended_actions': [
                {
                  'priority': 1,
                  'title_tr': 'Sabah dene',
                  'detail_tr': 'Gün doğumu',
                },
              ],
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
      return http.Response.bytes(utf8.encode(jsonEncode(_fallbackJson())), 200);
    });

    await tester.pumpWidget(
      _wrap(
        AiAssistantSheet(
          apiService: ApiService(
            serverBaseUrl: 'http://127.0.0.1:8000',
            client: client,
          ),
          analysis: _analysis(),
          cache: cache,
          clientIdentityService: _identityService(),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle(const Duration(milliseconds: 200));

    await tester.enterText(find.byType(TextField), 'Levrek için mantıklı mı?');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(questionRequest, isNotNull);
    final qBody = jsonDecode(questionRequest!.body) as Map<String, dynamic>;
    expect(qBody['user_question'], 'Levrek için mantıklı mı?');
    expect(qBody['client_identity'], isNotNull);
    expect(find.text(kAiAssistantSectionHistory), findsOneWidget);
    expect(find.text('Levrek için uygun görünüyor.'), findsOneWidget);
    expect(find.text('Yedek özet metni'), findsOneWidget);
    expect(find.text('Levrek için mantıklı mı?'), findsOneWidget);
  });

  testWidgets('AiAssistantSheet cache-only banner when API fails with stale cache', (
    tester,
  ) async {
    final cache = AiAssistantCache();
    cache.put(_analysis(), _cachedAiResponse());

    await tester.pumpWidget(
      _wrap(
        AiAssistantSheet(
          apiService: ApiService(
            serverBaseUrl: 'http://127.0.0.1:8000',
            client: MockClient((_) async => http.Response('', 503)),
          ),
          analysis: _analysis(),
          cache: cache,
          clientIdentityService: _identityService(),
          forceRefresh: true,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(kAiAssistantCacheOnlyBanner), findsOneWidget);
    expect(find.text('AI özet'), findsOneWidget);
  });
}
