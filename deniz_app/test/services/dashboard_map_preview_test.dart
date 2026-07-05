import 'package:deniz_app/domain/dashboard_overview.dart';
import 'package:deniz_app/domain/marine_compare.dart';
import 'package:deniz_app/domain/marine_intelligence_report.dart';
import 'package:deniz_app/domain/marine_saved_spot.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/services/dashboard_overview_service.dart';
import 'package:deniz_app/services/marine_intelligence_cache.dart';
import 'package:deniz_app/widgets/dashboard/v2/dashboard_v2_map_card.dart';
import 'package:deniz_app/widgets/dashboard/v2/premium_dashboard_v2_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

MarineIntelligenceReport _reportAt({
  required double lat,
  required double lon,
  int goScore = 58,
  int suitability = 65,
}) {
  return MarineIntelligenceReport.fromJson({
    'coordinate': {'lat': lat, 'lon': lon},
    'weather': {
      'temperature_c': {'final_value': 22, 'confidence': 0.8, 'source_count': 1},
    },
    'wind': {
      'speed_kmh': {'final_value': 12, 'confidence': 0.8, 'source_count': 1},
      'direction_text': 'KD',
    },
    'marine': {
      'wave_height_m': {'final_value': 0.8, 'confidence': 0.8, 'source_count': 1},
      'ocean_current_velocity_mps': {
        'final_value': 0.35,
        'confidence': 0.8,
        'source_count': 1,
      },
    },
    'astronomy': {'moon_illumination_pct': 42},
    'fishing_score': {
      'suitability_score': suitability,
      'risk_score': 20,
      'confidence': 0.7,
      'general_advice_tr': 'Koşullar orta.',
    },
    'consensus_summary': {'overall_confidence': 0.7},
    'decision': {'fishing_decision': 'marginal', 'go_score': goScore},
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  });
}

MarineSavedSpot _spot({
  required String id,
  required String name,
  required double lat,
  required double lon,
  bool favorite = false,
  int? goScore,
}) {
  return MarineSavedSpot(
    id: id,
    name: name,
    lat: lat,
    lon: lon,
    favorite: favorite,
    createdAt: '2026-01-01T00:00:00Z',
    updatedAt: '2026-07-01T00:00:00Z',
    lastReport: goScore != null
        ? MarineIntelligenceReportSnapshot.fromJson(
            _reportAt(lat: lat, lon: lon, goScore: goScore).toJson(),
          )
        : null,
    lastReportAt: goScore != null
        ? DateTime.now().toUtc().toIso8601String()
        : null,
  );
}

Future<void> _saveCompare(MarineIntelligenceCache cache) async {
  final left = _reportAt(lat: 41.0, lon: 29.0, goScore: 70);
  final right = _reportAt(lat: 41.02, lon: 29.05, goScore: 55);
  await cache.saveLastCompare(
    MarineCompareResponse(
      leftReport: left,
      rightReport: right,
      comparison: const MarineComparison(
        winner: 'left',
        winnerLabel: 'A Noktası',
        scoreDelta: 15,
      ),
      updatedAt: DateTime.now().toUtc().toIso8601String(),
    ),
  );
}

Widget _mapCardHarness(DashboardMapPreviewData data) {
  return MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(size: Size(400, 280)),
      child: Scaffold(
        body: SizedBox(
          height: 240,
          child: DashboardV2MapCard(
            data: data,
            onMarineTap: () {},
            onTap: () {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DashboardMapPreview service binding', () {
    test('no coordinate => hasRealCoordinate false and empty mode', () async {
      SharedPreferences.setMockInitialValues({});
      final overview =
          await DashboardOverviewService(marineCache: MarineIntelligenceCache())
              .load();
      expect(overview.mapPreview.hasRealCoordinate, isFalse);
      expect(overview.mapPreview.displayMode, DashboardMapPreviewMode.empty);
      expect(overview.mapPreview.hasData, isFalse);
      expect(overview.mapPreview.markers, isEmpty);
      expect(overview.mapPreview.score, isNull);
    });

    test('report coordinate populates map preview metrics', () async {
      SharedPreferences.setMockInitialValues({});
      final cache = MarineIntelligenceCache();
      await cache.saveLastReport(_reportAt(lat: 41.01, lon: 29.0));

      final overview = await DashboardOverviewService(marineCache: cache).load();
      expect(overview.mapPreview.hasRealCoordinate, isTrue);
      expect(overview.mapPreview.hasRealData, isTrue);
      expect(overview.mapPreview.displayMode, DashboardMapPreviewMode.activeReport);
      expect(overview.mapPreview.centerLat, closeTo(41.01, 0.001));
      expect(overview.mapPreview.score, 58);
      expect(overview.mapPreview.selectedMarkerId, isNotNull);
      expect(overview.mapPreview.waveLabel, contains('m'));
      expect(overview.mapPreview.currentLabel, contains('m/s'));
      expect(overview.mapPreview.windLabel, contains('km/s'));
      expect(
        overview.mapPreview.markers.any((m) => m.markerType == DashboardMapMarkerType.report),
        isTrue,
      );
    });

    test('saved spots fallback when no report', () async {
      SharedPreferences.setMockInitialValues({});
      final cache = MarineIntelligenceCache();
      await cache.saveSavedSpots([
        _spot(id: 's1', name: 'Koy A', lat: 40.5, lon: 28.9, favorite: true, goScore: 72),
        _spot(id: 's2', name: 'Koy B', lat: 40.52, lon: 28.95, goScore: 58),
      ]);

      final overview = await DashboardOverviewService(marineCache: cache).load();
      expect(overview.mapPreview.displayMode, DashboardMapPreviewMode.savedSpots);
      expect(overview.mapPreview.hasRealCoordinate, isTrue);
      expect(overview.mapPreview.hasRealData, isTrue);
      expect(overview.mapPreview.markers.length, 2);
      expect(
        overview.mapPreview.markers.every(
          (m) => m.markerType == DashboardMapMarkerType.savedSpot,
        ),
        isTrue,
      );
    });

    test('compare mode with A/B markers', () async {
      SharedPreferences.setMockInitialValues({});
      final cache = MarineIntelligenceCache();
      await _saveCompare(cache);

      final overview = await DashboardOverviewService(marineCache: cache).load();
      expect(overview.mapPreview.displayMode, DashboardMapPreviewMode.compare);
      expect(overview.mapPreview.hasComparePair, isTrue);
      expect(
        overview.mapPreview.markers.where((m) => m.isCompareA).length,
        1,
      );
      expect(
        overview.mapPreview.markers.where((m) => m.isCompareB).length,
        1,
      );
      expect(overview.mapPreview.winnerLabel, isNotNull);
    });
  });

  group('DashboardV2MapCard widget', () {
    testWidgets('empty state shows CTA without score chip', (tester) async {
      await tester.pumpWidget(
        _mapCardHarness(const DashboardMapPreviewData()),
      );
      await tester.pump();

      expect(find.text(kMissionScoreCta), findsOneWidget);
      expect(find.text(kPremiumDashMapEmptyAwaiting), findsOneWidget);
      expect(find.text(kPremiumDashScoreLabel), findsNothing);
    });

    testWidgets('report coordinate shows live score chip and painter', (tester) async {
      await tester.pumpWidget(
        _mapCardHarness(
          DashboardMapPreviewData(
            centerLat: 41.01,
            centerLon: 29.0,
            centerLabel: '41.0100, 29.0000',
            score: 75,
            updatedAgoLabel: '2 dk',
            hasRealCoordinate: true,
            displayMode: DashboardMapPreviewMode.activeReport,
            selectedMarkerId: 'report',
            waveLabel: '0.8 m',
            windLabel: '12 km/s',
            dataSourceLabel: kPremiumDashMapSourceReport,
            depthLegendMinLabel: kPremiumDashMapDepthMin,
            depthLegendMaxLabel: kPremiumDashMapDepthMax,
            markers: const [
              DashboardMapMarker(
                normalizedX: 0.5,
                normalizedY: 0.5,
                id: 'report',
                lat: 41.01,
                lon: 29.0,
                score: 75,
                isPrimary: true,
                isSelected: true,
                markerType: DashboardMapMarkerType.report,
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(find.text(kPremiumDashScoreLabel), findsOneWidget);
      expect(find.text(kPremiumDashMapDepthMin), findsOneWidget);
      expect(find.text(kPremiumDashMapLastUpdate), findsOneWidget);
      expect(find.text(kPremiumDashMapWave), findsOneWidget);
      expect(find.textContaining('Son koordinat'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('low confidence chip renders when flagged', (tester) async {
      await tester.pumpWidget(
        _mapCardHarness(
          DashboardMapPreviewData(
            centerLat: 41.01,
            centerLon: 29.0,
            hasRealCoordinate: true,
            isLowConfidence: true,
            displayMode: DashboardMapPreviewMode.activeReport,
            markers: const [
              DashboardMapMarker(
                normalizedX: 0.5,
                normalizedY: 0.5,
                id: 'report',
                lat: 41.01,
                lon: 29.0,
                score: 75,
                isSelected: true,
                markerType: DashboardMapMarkerType.report,
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      expect(find.text(kPremiumDashMapLowConfidence), findsOneWidget);
    });

    testWidgets('limited mode shows honest empty message without score chip', (tester) async {
      await tester.pumpWidget(
        _mapCardHarness(
          DashboardMapPreviewData(
            centerLat: 41.01,
            centerLon: 29.0,
            centerLabel: '41.0100, 29.0000',
            hasRealCoordinate: true,
            displayMode: DashboardMapPreviewMode.limited,
            emptyReason: kPremiumDashMapEmptyNeedsAnalysis,
          ),
        ),
      );
      await tester.pump();
      expect(find.text(kPremiumDashMapEmptyNeedsAnalysis), findsOneWidget);
      expect(find.text(kPremiumDashScoreLabel), findsNothing);
    });

    testWidgets('saved spots mode lists coordinate footer', (tester) async {
      await tester.pumpWidget(
        _mapCardHarness(
          DashboardMapPreviewData(
            centerLat: 40.5,
            centerLon: 28.9,
            centerLabel: 'Koy A',
            hasRealCoordinate: true,
            displayMode: DashboardMapPreviewMode.savedSpots,
            markers: const [
              DashboardMapMarker(
                normalizedX: 0.4,
                normalizedY: 0.5,
                label: 'Koy A',
                lat: 40.5,
                lon: 28.9,
                markerType: DashboardMapMarkerType.savedSpot,
                isPrimary: true,
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Kayıtlı nokta'), findsOneWidget);
      expect(find.text('Koy A'), findsOneWidget);
    });

    testWidgets('compare mode shows winner chip', (tester) async {
      await tester.pumpWidget(
        _mapCardHarness(
          DashboardMapPreviewData(
            centerLat: 41.01,
            centerLon: 29.025,
            centerLabel: '41.0100, 29.0250',
            hasRealCoordinate: true,
            displayMode: DashboardMapPreviewMode.compare,
            hasComparePair: true,
            winnerLabel: 'A Noktası',
            markers: const [
              DashboardMapMarker(
                normalizedX: 0.35,
                normalizedY: 0.5,
                isCompareA: true,
                markerType: DashboardMapMarkerType.compareA,
                score: 70,
              ),
              DashboardMapMarker(
                normalizedX: 0.65,
                normalizedY: 0.5,
                isCompareB: true,
                markerType: DashboardMapMarkerType.compareB,
                score: 55,
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(find.text(kMissionMapWinner), findsOneWidget);
      expect(find.text(kPremiumDashMapCompareCta), findsOneWidget);
    });

    testWidgets('1366x768 dashboard smoke without overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1366, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1366, 768)),
            child: Scaffold(
              body: PremiumDashboardV2Layout(
                overview: DashboardOverview(
                  connectionStatus: DashboardConnectionStatus.connected,
                  location: const DashboardLocationSummary(label: 'Test'),
                  liveScore: const DashboardLiveScoreSummary(score: 70),
                  marineReport: const DashboardMarineReportSummary(
                    waveLabel: '0.8 m',
                  ),
                  savedSpots: const DashboardSavedSpotsSummary(totalCount: 1),
                  recentCatches: const DashboardRecentCatchesSummary(),
                  compare: const DashboardCompareSummary(),
                  captainAtlas: const DashboardCaptainAtlasSummary(),
                  timeline: const DashboardTimelineSummary(),
                  tide: const DashboardTideSummary(),
                  forecast: const DashboardForecastSummary(),
                  mapPreview: const DashboardMapPreviewData(),
                ),
                serverIp: '127.0.0.1',
                onLiveTap: () {},
                onPhotoTap: () {},
                onMarineTap: () {},
                onCompareTap: () {},
                onCaptainAtlasTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(DashboardV2MapCard), findsOneWidget);
    });
  });
}
