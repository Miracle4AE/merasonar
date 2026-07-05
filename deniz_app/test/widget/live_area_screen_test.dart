import 'package:deniz_app/api_service.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/live_area_screen.dart';
import 'package:deniz_app/map/widgets/live_area/gps_status_card.dart';
import 'package:deniz_app/map/widgets/live_area/live_score_premium_card.dart';
import 'package:deniz_app/map/widgets/live_area/nearest_hotspot_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  testWidgets('LiveAreaScreen smoke render', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: LiveAreaScreen(
          serverIp: '127.0.0.1',
          mockLiveScoreOnly: () async => LiveFishingScoreResponse(
            liveScore: 82,
            rating: 'Excellent',
            reasoning: 'Örnek test açıklaması.',
            trustNote: kTrustAlways,
            nearestHotspot: null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(kLiveAreaAppBarTitle), findsWidgets);
    expect(find.byType(LiveScorePremiumCard), findsOneWidget);
  });

  testWidgets('live score card renders rating and score', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LiveAreaScreen(
          serverIp: '127.0.0.1',
          mockLiveScoreOnly: () async => LiveFishingScoreResponse(
            liveScore: 82,
            rating: 'Excellent',
            reasoning: 'Örnek test açıklaması.',
            trustNote: kTrustAlways,
            nearestHotspot: null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mükemmel'), findsOneWidget);
    expect(find.text('82'), findsOneWidget);
  });

  testWidgets('GPS status card render test', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: LiveAreaScreen(
          serverIp: '127.0.0.1',
          cachedAnalysisForTests: FishingZoneResponse.fromJson({
            'coordinate_mode': kCoordinateModeGeoReferenced,
            'boat': {
              'raw_gps': {'lat': 41.0, 'lon': 29.0},
              'smoothed_gps': {'lat': 41.0, 'lon': 29.0},
            },
            'ranked_hotspots': <Map<String, dynamic>>[],
            'image_size': {'width': 10, 'height': 10},
            'diagnostics': <String, dynamic>{},
          }),
          mockPosition: () async => Position(
            latitude: 41.0082,
            longitude: 28.9784,
            timestamp: DateTime.now(),
            accuracy: 8,
            altitude: 0,
            altitudeAccuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: 0,
            speedAccuracy: 0,
          ),
          mockLiveScoreOnly: () async => LiveFishingScoreResponse(
            liveScore: 70,
            rating: 'Good',
            reasoning: 'Test',
            trustNote: kTrustAlways,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GpsStatusCard), findsOneWidget);
  });

  testWidgets('Nearest hotspot empty state test', (tester) async {
    final cached = FishingZoneResponse.fromJson({
      'coordinate_mode': kCoordinateModeGeoReferenced,
      'boat': {
        'raw_gps': {'lat': 37.0, 'lon': 27.0},
        'smoothed_gps': {'lat': 37.0, 'lon': 27.0},
      },
      'ranked_hotspots': <Map<String, dynamic>>[],
      'image_size': {'width': 10, 'height': 10},
      'diagnostics': <String, dynamic>{},
    });

    await tester.pumpWidget(
      MaterialApp(
        home: LiveAreaScreen(
          serverIp: '127.0.0.1',
          cachedAnalysisForTests: cached,
          mockLiveScoreOnly: () async => LiveFishingScoreResponse(
            liveScore: 48,
            rating: 'Fair',
            reasoning: kUxCalibratedRequired,
            trustNote: kTrustAlways,
            nearestHotspot: null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NearestHotspotCard), findsOneWidget);
    expect(find.text(kLiveHotspotEmptyTitle), findsOneWidget);
  });

  testWidgets('Captain Atlas live card button render test', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final cached = FishingZoneResponse.fromJson({
      'coordinate_mode': kCoordinateModeGeoReferenced,
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
          'latitude': 37.01,
          'longitude': 27.01,
          'geo_coordinate': {'lat': 37.01, 'lon': 27.01},
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
        },
      ],
      'image_size': {'width': 10, 'height': 10},
      'diagnostics': <String, dynamic>{},
    });

    await tester.pumpWidget(
      MaterialApp(
        home: LiveAreaScreen(
          serverIp: '127.0.0.1',
          cachedAnalysisForTests: cached,
          mockLiveScoreOnly: () async => LiveFishingScoreResponse(
            liveScore: 82,
            rating: 'Excellent',
            reasoning: 'Canlı test',
            trustNote: kTrustAlways,
            nearestHotspot: LiveNearestHotspot(
              id: 1,
              distanceM: 50,
              recommendationRank: 1,
              latitude: 37.01,
              longitude: 27.01,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('btn_live_ai_assistant')));

    expect(find.text(kAiAssistantLiveTitle), findsOneWidget);
    expect(find.byKey(const Key('btn_live_ai_assistant')), findsOneWidget);
  });

  testWidgets('Auto refresh toggle regression test', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LiveAreaScreen(
          serverIp: '127.0.0.1',
          mockLiveScoreOnly: () async => LiveFishingScoreResponse(
            liveScore: 82,
            rating: 'Excellent',
            reasoning: 'Test',
            trustNote: kTrustAlways,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(kAutoRefreshLabel), findsOneWidget);
    final toggle = find.byType(Switch);
    expect(toggle, findsOneWidget);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
  });

  testWidgets('image_space live response shows calibrated coordinates warning',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LiveAreaScreen(
          serverIp: '127.0.0.1',
          mockLiveScoreOnly: () async => LiveFishingScoreResponse(
            liveScore: 48,
            rating: 'Fair',
            reasoning: kUxCalibratedRequired,
            trustNote: kTrustAlways,
            nearestHotspot: null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('kalibre'),
      findsWidgets,
    );
  });

  testWidgets('cached image_space response shows Nearby hotspot calibration warning',
      (tester) async {
    final cached = FishingZoneResponse.fromJson({
      'coordinate_mode': kCoordinateModeImageSpace,
      'boat': {
        'raw_gps': {'lat': 1.0, 'lon': 2.0},
        'smoothed_gps': {'lat': 1.0, 'lon': 2.0},
      },
      'ranked_hotspots': <Map<String, dynamic>>[],
      'image_size': {'width': 10, 'height': 10},
      'diagnostics': <String, dynamic>{},
    });

    await tester.pumpWidget(
      MaterialApp(
        home: LiveAreaScreen(
          serverIp: '127.0.0.1',
          cachedAnalysisForTests: cached,
          mockPosition: () async => Position(
            latitude: 37.0,
            longitude: 27.0,
            timestamp: DateTime.now(),
            accuracy: 10,
            altitude: 0,
            altitudeAccuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: 0,
            speedAccuracy: 0,
          ),
          mockLiveScoreOnly: () async => const LiveFishingScoreResponse(
            liveScore: 48,
            rating: 'Fair',
            reasoning: kUxCalibratedRequired,
            trustNote: kTrustAlways,
            nearestHotspot: null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(kNearbyModeImageSpace), findsOneWidget);
    expect(find.byKey(const Key('btn_calibrate_map')), findsOneWidget);
  });

  testWidgets('missing cached coordinate_mode uses safe fallback and warns',
      (tester) async {
    final cached = FishingZoneResponse.fromJson({
      'boat': {
        'raw_gps': {'lat': 1.0, 'lon': 2.0},
        'smoothed_gps': {'lat': 1.0, 'lon': 2.0},
      },
      'ranked_hotspots': <Map<String, dynamic>>[],
      'image_size': {'width': 10, 'height': 10},
      'diagnostics': <String, dynamic>{},
    });

    await tester.pumpWidget(
      MaterialApp(
        home: LiveAreaScreen(
          serverIp: '127.0.0.1',
          cachedAnalysisForTests: cached,
          mockLiveScoreOnly: () async => const LiveFishingScoreResponse(
            liveScore: 48,
            rating: 'Fair',
            reasoning: kUxCalibratedRequired,
            trustNote: kTrustAlways,
            nearestHotspot: null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(kNearbyModeUnknown), findsOneWidget);
    expect(find.byKey(const Key('btn_calibrate_map')), findsOneWidget);
  });

  testWidgets('AI Canlı Değerlendirme butonu analiz ve skor varken görünür', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final cached = FishingZoneResponse.fromJson({
      'coordinate_mode': kCoordinateModeGeoReferenced,
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
          'latitude': 37.01,
          'longitude': 27.01,
          'geo_coordinate': {'lat': 37.01, 'lon': 27.01},
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
        },
      ],
      'image_size': {'width': 10, 'height': 10},
      'diagnostics': <String, dynamic>{},
    });

    await tester.pumpWidget(
      MaterialApp(
        home: LiveAreaScreen(
          serverIp: '127.0.0.1',
          cachedAnalysisForTests: cached,
          mockLiveScoreOnly: () async => LiveFishingScoreResponse(
            liveScore: 82,
            rating: 'Excellent',
            reasoning: 'Canlı test',
            trustNote: kTrustAlways,
            nearestHotspot: LiveNearestHotspot(
              id: 1,
              distanceM: 50,
              recommendationRank: 1,
              latitude: 37.01,
              longitude: 27.01,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('btn_live_ai_assistant')));

    expect(find.text(kAiAssistantLiveTitle), findsOneWidget);
    expect(find.byKey(const Key('btn_live_ai_assistant')), findsOneWidget);
  });
}
