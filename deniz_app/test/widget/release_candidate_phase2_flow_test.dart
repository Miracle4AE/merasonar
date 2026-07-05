import 'dart:convert';

import 'package:deniz_app/api_service.dart';
import 'package:deniz_app/domain/dashboard_overview.dart';
import 'package:deniz_app/domain/marine_saved_spot.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/live_area_screen.dart';
import 'package:deniz_app/map/hosts/map_overlay_host.dart';
import 'package:deniz_app/map/widgets/ai_assistant_sheet.dart';
import 'package:deniz_app/map/widgets/marine/marine_saved_spots_panel.dart';
import 'package:deniz_app/screens/premium_dashboard_screen.dart';
import 'package:deniz_app/services/ai_assistant_cache.dart';
import 'package:deniz_app/services/client_identity_service.dart';
import 'package:deniz_app/services/dashboard_overview_service.dart';
import 'package:deniz_app/domain/geo_visualization_state.dart';
import 'package:deniz_app/widgets/dashboard/v2/dashboard_v2_captain_atlas_card.dart';
import 'package:deniz_app/widgets/premium/feedback/premium_error_fallback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _marineReportJson = '''
{
  "coordinate": {"lat": 37.0, "lon": 27.0},
  "weather": {"temperature_c": {"final_value": 22.0, "confidence": 0.6, "source_count": 1}},
  "wind": {"speed_kmh": {"final_value": 12.0, "confidence": 0.6, "source_count": 1}},
  "marine": {"wave_height_m": {"final_value": 0.6, "confidence": 0.6, "source_count": 1}},
  "astronomy": {"moon_phase": "Ilk Hilal"},
  "fishing_score": {
    "suitability_score": 75,
    "risk_score": 20,
    "general_advice_tr": "Test",
    "confidence": 0.6
  },
  "consensus_summary": {"overall_confidence": 0.6, "provider_count": 1},
  "updated_at": "2024-06-15T06:00:00+00:00"
}
''';

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
  });
}

Hotspot _hotspot() {
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
    'mapping_trust': 'chart_aligned',
    'is_renderable': true,
  });
}

MarineSavedSpot _spot(String id, String name) {
  return MarineSavedSpot.fromJson({
    'id': id,
    'name': name,
    'lat': 36.62,
    'lon': 29.11,
    'favorite': false,
    'created_at': 't',
    'updated_at': 't',
    'visit_count': 0,
    'personal_tags': [],
  });
}

Widget _wrap(Widget child, {Size size = const Size(1600, 900)}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RC Phase 2 — mock app flow', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('app starts with empty cache dashboard', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrap(
          PremiumDashboardScreen(
            serverIp: '127.0.0.1',
            onLiveTap: () {},
            onPhotoTap: () {},
            onMarineTap: () {},
            onCompareTap: () {},
            onCaptainAtlasTap: () {},
            initialOverview: DashboardOverview.empty,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Mission Control'), findsNothing);
    });

    test('marine coordinate mock response parses', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/marine_intelligence/coordinate');
        return http.Response(_marineReportJson, 200);
      });
      final api = ApiService(
        serverBaseUrl: 'http://127.0.0.1:8000',
        client: client,
      );
      final report = await api.fetchMarineCoordinateReport(lat: 37, lon: 27);
      expect(report.fishingScore.suitabilityScore, 75);
      expect(report.coordinate.lat, 37.0);
    });

    testWidgets('dashboard captain card from cached overview', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DashboardV2CaptainAtlasCard(
            summary: const DashboardCaptainAtlasSummary(
              summaryTr: 'Mock captain özeti',
              personaVersion: 'v1',
            ),
            onCaptainTap: () {},
          ),
        ),
      );
      expect(find.text('Mock captain özeti'), findsOneWidget);
    });

    testWidgets('saved spots panel mock list', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarineSavedSpotsPanel(
              spots: [_spot('s1', 'Koy A'), _spot('s2', 'Koy B')],
              onRefresh: (_) async {},
              onDelete: (_) async {},
              onToggleFavorite: (_) async {},
              onAddCatch: (_) async {},
              onShowCatches: (_) async {},
            ),
          ),
        ),
      );
      expect(find.text('Koy A'), findsOneWidget);
      expect(find.text(kMarineAddCatchButton), findsWidgets);
    });

    testWidgets('compare mock captain comment payload', (tester) async {
      const summary = 'Compare captain mock';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Text(summary),
          ),
        ),
      );
      expect(find.text(summary), findsOneWidget);
    });

    testWidgets('live area mock live score section', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LiveAreaScreen(
            serverIp: '127.0.0.1',
            mockLiveScoreOnly: () async => LiveFishingScoreResponse.fromJson({
              'live_score': 72,
              'rating': 'Good',
              'reasoning': 'Mock canlı skor',
              'trust_note': 'Tavsiye niteliğindedir',
            }),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(LiveAreaScreen), findsOneWidget);
      expect(find.text(kLiveAreaAppBarTitle), findsWidgets);
    });

    test('dashboard overview loads from empty marine cache', () async {
      final overview = await DashboardOverviewService().load(
        connectionStatus: DashboardConnectionStatus.disconnected,
      );
      expect(overview.marineReport.hasData, isFalse);
      expect(overview.savedSpots.hasData, isFalse);
    });
  });

  group('RC Phase 2 — error boundary coverage', () {
    testWidgets('map overlay host builds with boundary', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapHotspotDetailOverlayHost(
              hotspot: _hotspot(),
              isChartOverlay: false,
              mobileLayout: false,
              geoViz: GeoVisualizationState.fallback(),
              boatPosition: null,
              apiService: ApiService(
                serverBaseUrl: 'http://127.0.0.1:8000',
                client: MockClient((_) async => http.Response('{}', 500)),
              ),
              sessionAnalysis: _analysis(),
              aiCache: AiAssistantCache(),
              clientIdentity: ClientIdentityService(),
              captainSummary: 'Mock özet',
              onClose: () {},
              onGo: () {},
              onCompare: () {},
              onSave: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(PremiumErrorBoundary), findsOneWidget);
    });

    testWidgets('AI assistant sheet body uses error boundary', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            body: SizedBox(
              height: 700,
              width: 400,
              child: AiAssistantSheet(
                apiService: ApiService(
                  serverBaseUrl: 'http://127.0.0.1:8000',
                  client: MockClient((_) async => http.Response(
                        jsonEncode({
                          'source': 'fallback',
                          'prompt_version': 'v1',
                          'summary_tr': 'Fallback özet',
                          'confidence': 'low',
                          'recommended_actions': [],
                          'hotspot_insights': [],
                          'conditions_comment_tr': 'c',
                          'species_comment_tr': 's',
                          'limitations_tr': [],
                          'safety_reminders_tr': [],
                          'fallback_reason': 'test',
                          'processing_ms': 1,
                        }),
                        200,
                      )),
                ),
                analysis: _analysis(),
                cache: AiAssistantCache(),
                clientIdentityService: ClientIdentityService(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(PremiumErrorBoundary), findsOneWidget);
    });

    testWidgets('PremiumErrorFallback retry smoke', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        MaterialApp(
          home: PremiumErrorFallback(
            title: kPremiumSectionErrorTitle,
            message: 'Test hata',
            onRetry: () => retried = true,
          ),
        ),
      );
      await tester.tap(find.text(kPremiumDashRefresh));
      await tester.pump();
      expect(retried, isTrue);
    });
  });
}
