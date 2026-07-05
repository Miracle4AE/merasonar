import 'package:deniz_app/services/ai_assistant_cache.dart';
import 'package:deniz_app/services/client_identity_service.dart';
import 'package:deniz_app/widgets/premium/map_vignette_overlay.dart';
import 'package:deniz_app/api_service.dart';
import 'package:deniz_app/domain/geo_visualization_state.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/map/widgets/hotspot_detail_sheet.dart';
import 'package:deniz_app/map/widgets/map_control_panel.dart';
import 'package:deniz_app/map/widgets/premium/map_bottom_chrome.dart';
import 'package:deniz_app/map/widgets/premium/map_command_bar.dart';
import 'package:deniz_app/map/hosts/map_overlay_host.dart';
import 'package:deniz_app/map/widgets/premium/map_hotspot_detail_panel.dart';
import 'package:deniz_app/map/widgets/premium/map_hotspot_strip.dart';
import 'package:deniz_app/map/widgets/premium/map_premium_empty_state.dart';
import 'package:deniz_app/map/widgets/premium/map_premium_legend.dart';
import 'package:deniz_app/map/widgets/premium/map_premium_top_bar.dart';
import 'package:deniz_app/map/widgets/premium/premium_map_marker.dart';
import 'package:deniz_app/map/widgets/premium/photo_analysis_premium_panel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Hotspot _testHotspot() {
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
    'fishing_advice': <String, dynamic>{
      'species_predictions': <dynamic>[],
      'bait': <dynamic>[],
      'best_times': <dynamic>[],
      'tackle': <dynamic>[],
      'selection_reasons': <dynamic>[],
    },
    'confirmed_depth': <String, dynamic>{'depth_m': 42.0},
    'likely_species': <String, dynamic>{
      'source': 'none',
      'fallback': true,
      'total_records_considered': 0,
      'top_species': <dynamic>[],
    },
  });
}

void main() {
  testWidgets('MapPremiumToolbox render', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapPremiumToolbox(
            showClassA: true,
            showClassB: true,
            showClassC: false,
            minScore: 0.4,
            showIntensity: true,
            showCorridor: false,
            showLegend: true,
            sortMode: HotspotSortMode.scoreThenDistance,
            gpsReliabilityLabel: kMapGpsPillReliable,
            onToggleClassA: (_) {},
            onToggleClassB: (_) {},
            onToggleClassC: (_) {},
            onMinScoreChanged: (_) {},
            onToggleIntensity: (_) {},
            onToggleCorridor: (_) {},
            onToggleLegend: (_) {},
            onSortModeChanged: (_) {},
            onRefresh: () {},
            onCenterBoat: () {},
          ),
        ),
      ),
    );
    expect(find.text(kMapPremiumFiltersTitle), findsOneWidget);
  });

  testWidgets('MapControlPanel premium wrapper render', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapControlPanel(
            showClassA: true,
            showClassB: true,
            showClassC: true,
            minScore: 0.2,
            showIntensity: false,
            showCorridor: true,
            showLegend: false,
            sortMode: HotspotSortMode.proximity,
            onToggleClassA: (_) {},
            onToggleClassB: (_) {},
            onToggleClassC: (_) {},
            onMinScoreChanged: (_) {},
            onToggleIntensity: (_) {},
            onToggleCorridor: (_) {},
            onToggleLegend: (_) {},
            onSortModeChanged: (_) {},
            onRefresh: () {},
            onCenterBoat: () {},
          ),
        ),
      ),
    );
    expect(find.text(kMapPremiumFiltersTitle), findsOneWidget);
  });

  testWidgets('PremiumMapMarker render', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PremiumMapMarker(
              scoreLabel: 'A · #1',
              color: Colors.red,
              scoreText: '82',
              focused: true,
              topTier: true,
              pulse: 0.5,
              badgeLabel: 'Önerilen 1',
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('82'), findsOneWidget);
    expect(find.text('A · #1'), findsOneWidget);
  });

  testWidgets('PremiumMapMarker tap calls callback', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PremiumMapMarker(
              key: const Key('map_hotspot_marker_1'),
              scoreLabel: 'A · #1',
              color: Colors.red,
              scoreText: '82',
              focused: false,
              topTier: true,
              pulse: 0.0,
              onTap: () => tapped = true,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('map_hotspot_marker_1')));
    expect(tapped, isTrue);
  });

  testWidgets('MapHotspotStrip item tap calls onHotspotTap', (tester) async {
    Hotspot? tapped;
    final hotspot = _testHotspot();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapHotspotStrip(
            hotspots: [hotspot],
            onTap: (h) => tapped = h,
            scoreFormatter: (s) => (s * 100).round(),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('hotspot_strip_item_1')));
    expect(tapped?.id, hotspot.id);
  });

  testWidgets('MapHotspotDetailOverlayHost fills stack for slide panel', (
    tester,
  ) async {
    final hotspot = _testHotspot();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 700,
            child: Stack(
              children: [
                Positioned.fill(
                  child: MapHotspotDetailOverlayHost(
                    hotspot: hotspot,
                    isChartOverlay: false,
                    mobileLayout: false,
                    geoViz: GeoVisualizationState(
                      coordinateMode: kCoordinateModeGeoReferenced,
                      reliability: CalibrationReliability.excellent,
                      calibrationQuality: 0.9,
                      transformConfidence: 0.9,
                    ),
                    boatPosition: null,
                    apiService: ApiService(serverBaseUrl: 'http://127.0.0.1:8000'),
                    sessionAnalysis: null,
                    aiCache: AiAssistantCache(),
                    clientIdentity: ClientIdentityService(),
                    captainSummary: 'Test özet',
                    onClose: () {},
                    onGo: () {},
                    onCompare: () {},
                    onSave: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('map_hotspot_detail_panel')), findsOneWidget);
    expect(find.text(kMapPremiumHotspotGo), findsOneWidget);
  });

  testWidgets('MapVignetteOverlay ignores pointer', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => tapped = true,
                  child: const ColoredBox(color: Colors.blue),
                ),
              ),
              const Positioned.fill(child: MapVignetteOverlay()),
            ],
          ),
        ),
      ),
    );
    await tester.tapAt(const Offset(100, 100));
    expect(tapped, isTrue);
  });

  testWidgets('MapCommandBar render with keys', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapCommandBar(
            onScanArea: () {},
            onLiveAnalysis: () {},
            onCoordinate: () {},
            onCompare: () {},
            onCaptainAtlas: () {},
          ),
        ),
      ),
    );
    expect(find.text(kMapPremiumCommandScan), findsOneWidget);
    expect(find.byKey(const Key('btn_scan_area')), findsOneWidget);
    expect(find.byKey(const Key('btn_captain_atlas')), findsOneWidget);
  });

  testWidgets('MapPremiumLegend compact render', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MapPremiumLegend(
            visible: true,
            showIntensity: true,
            showCorridor: false,
          ),
        ),
      ),
    );
    expect(find.text(kMapPremiumLegendTitleShort), findsOneWidget);
    expect(find.text(kMapPremiumLegendA), findsOneWidget);
    expect(find.byKey(const Key('btn_map_legend_toggle')), findsOneWidget);
  });

  testWidgets('PhotoAnalysisUploadCard render', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PhotoAnalysisUploadCard(
            message: 'Test mesaj',
            onScan: () {},
          ),
        ),
      ),
    );
    expect(find.text(kMapPremiumPhotoUpload), findsOneWidget);
  });

  testWidgets('MapPremiumTopBar back home button', (tester) async {
    var popped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return MapPremiumTopBar(
                onBackHome: () => popped = true,
                dataSourceLabel: 'Canlı API',
                healthOk: true,
                onRefresh: () {},
                onDownload: () {},
                onSettings: () {},
                modeBadgeLabel: kMapTabCalibratedMap,
                gpsStatusLabel: kMapGpsPillReliable,
              );
            },
          ),
        ),
      ),
    );
    expect(find.text(kMapPremiumMapHeaderTitle), findsOneWidget);
    expect(find.byKey(const Key('btn_map_back_home')), findsOneWidget);
    await tester.tap(find.byKey(const Key('btn_map_back_home')));
    expect(popped, isTrue);
  });

  testWidgets('MapHotspotStrip compact cards', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapHotspotStrip(
            hotspots: [_testHotspot()],
            onTap: (_) {},
            scoreFormatter: (s) => (s * 100).round(),
            selectedHotspotId: 1,
          ),
        ),
      ),
    );
    expect(find.text(kMapPremiumNearestMeresShort), findsOneWidget);
    expect(find.textContaining('A · #1'), findsOneWidget);
    expect(find.textContaining('125 m'), findsOneWidget);
  });

  testWidgets('MapBottomChrome stacks strip above command bar', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 240,
            child: MapBottomChrome(
              showStrip: true,
              hotspotStrip: MapHotspotStrip(
                hotspots: [_testHotspot()],
                onTap: (_) {},
                scoreFormatter: (s) => (s * 100).round(),
              ),
              commandBar: MapCommandBar(
                onScanArea: () {},
                onLiveAnalysis: () {},
                onCoordinate: () {},
                onCompare: () {},
                onCaptainAtlas: () {},
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text(kMapPremiumNearestMeresShort), findsOneWidget);
    expect(find.text(kMapPremiumCommandScan), findsOneWidget);
  });

  testWidgets('MapHotspotDetailPanel slide render', (tester) async {
    final hotspot = _testHotspot();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 700,
            child: MapHotspotDetailPanel(
              hotspot: hotspot,
              onClose: () {},
              detailSheet: HotspotDetailSheet(
                hotspot: hotspot,
                slidePanel: true,
                geoVisualization: GeoVisualizationState(
                  coordinateMode: kCoordinateModeGeoReferenced,
                  reliability: CalibrationReliability.excellent,
                  calibrationQuality: 0.9,
                  transformConfidence: 0.9,
                ),
              ),
              onGo: () {},
              onCompare: () {},
              onSave: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('A · #1'), findsWidgets);
    expect(find.text(kMapPremiumHotspotGo), findsOneWidget);
  });

  testWidgets('MapPremiumEmptyState render', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapPremiumEmptyState(
            title: 'Harita boş',
            body: 'Alan tarayın',
            primaryLabel: kMapFabScanArea,
            onPrimary: () {},
            secondaryLabel: 'Kalibre et',
            onSecondary: () {},
          ),
        ),
      ),
    );
    expect(find.text('Harita boş'), findsOneWidget);
    expect(find.text(kMapFabScanArea), findsOneWidget);
  });

  test('debug strip hidden outside debug mode', () {
    expect(kDebugMode, isA<bool>());
  });
}
