import 'package:deniz_app/api_service.dart';
import 'package:deniz_app/domain/dashboard_overview.dart';
import 'package:deniz_app/domain/geo_visualization_state.dart';
import 'package:deniz_app/domain/marine_intelligence_report.dart';
import 'package:deniz_app/domain/premium_performance_mode.dart';
import 'package:deniz_app/home_screen.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/live_area_screen.dart';
import 'package:deniz_app/map/controllers/map_sheet_controller.dart';
import 'package:deniz_app/map/hosts/chart_overlay_host.dart';
import 'package:deniz_app/map/hosts/map_overlay_host.dart';
import 'package:deniz_app/map/layers/map_marker_layer.dart';
import 'package:deniz_app/map/widgets/premium/chart_overlay_premium_marker.dart';
import 'package:deniz_app/map/widgets/marine/intelligence/marine_decision_overview_card.dart';
import 'package:deniz_app/map/widgets/marine/marine_report_cards.dart';
import 'package:deniz_app/map_screen.dart';
import 'package:deniz_app/navigation/captain_atlas_launcher.dart';
import 'package:deniz_app/navigation/premium_navigator.dart';
import 'package:deniz_app/screens/captain_atlas_screen.dart';
import 'package:deniz_app/screens/marine_intelligence_screen.dart';
import 'package:deniz_app/services/ai_assistant_cache.dart';
import 'package:deniz_app/services/boat_gps_smoother.dart';
import 'package:deniz_app/services/client_identity_service.dart';
import 'package:deniz_app/widgets/dashboard/mission/mission_control_layout.dart';
import 'package:deniz_app/widgets/premium/premium_performance_scope.dart';
import 'package:deniz_app/widgets/premium/premium_status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Hotspot _testHotspot({int id = 1}) {
  return Hotspot.fromJson({
    'id': id,
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

Widget _perfWrap(Widget child, {PremiumPerformanceMode mode = PremiumPerformanceMode.full}) {
  return MaterialApp(
    home: PremiumPerformanceScope(
      mode: mode,
      onModeChanged: (_) {},
      child: child,
    ),
  );
}

Future<void> _waitForMissionDock(WidgetTester tester) async {
  for (var i = 0; i < 60; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (find.byKey(const Key('btn_live_area')).evaluate().isNotEmpty) {
      return;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MapSheetController', () {
    test('panel open/close helpers', () {
      final sheet = MapSheetController();
      final hotspot = _testHotspot();

      expect(sheet.isPanelOpen, isFalse);
      sheet.openPanel(hotspot);
      expect(sheet.isPanelOpen, isTrue);
      expect(sheet.selectedHotspot, same(hotspot));

      sheet.closePanel();
      expect(sheet.isPanelOpen, isFalse);
    });

    test('shouldUseInlinePanel respects chart mobile rule', () {
      final sheet = MapSheetController()..openPanel(_testHotspot());

      expect(
        sheet.shouldUseInlinePanel(isChartOverlay: true, mobileLayout: true),
        isFalse,
      );
      expect(
        sheet.shouldUseInlinePanel(isChartOverlay: true, mobileLayout: false),
        isTrue,
      );
      expect(
        sheet.shouldUseInlinePanel(isChartOverlay: false, mobileLayout: true),
        isTrue,
      );
    });
  });

  group('MapMarkerLayer smoke', () {
    testWidgets('world map markers include semantics label', (tester) async {
      final focus = ValueNotifier<int?>(null);
      addTearDown(focus.dispose);
      final controller = AnimationController(
        vsync: tester,
        duration: const Duration(seconds: 1),
      );
      addTearDown(controller.dispose);

      Hotspot? tapped;
      final layer = MapMarkerLayer(
        recGlow: controller,
        hotspotFocusId: focus,
        geoViz: GeoVisualizationState.fallback(),
        isWorldMapMode: true,
        boatRenderLatLon: null,
        liveGpsState: ValueNotifier<AccuracyAwarePositionState?>(null),
        boatAnchorLowConfidence: false,
        isGpsFallbackBoat: false,
        classificationColor: (_) => Colors.red,
        markerLabel: (h) => h.classification,
        markerLabelWithNav: (h) => h.classification,
        displayScorePct: (s) => (s * 100).round(),
        recommendationBadgeLabel: (_) => '',
        hotspotTooltipExtended: (_) => 'tooltip',
        pixelToCanvas: (a, s) => Offset(a.x, a.y),
        onHotspotTap: (h) => tapped = h,
        onClusterTap: (_) {},
      );

      final markers = layer.buildWorldMapMarkers(
        [],
        mobileLayout: false,
      );
      expect(markers, isEmpty);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                layer.buildChartHotspotMarker(
                  _testHotspot(),
                  const Size(400, 300),
                  mobile: false,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      final semanticsFinder = find.bySemanticsLabel(
        RegExp('Chart hotspot'),
      );
      expect(semanticsFinder, findsWidgets);
      final semantics = tester.getSemantics(semanticsFinder.first);
      expect(semantics.label, contains('Chart hotspot'));

      await tester.tap(find.byType(ChartOverlayPremiumMarker));
      await tester.pump();
      expect(tapped, isNotNull);
    });
  });

  group('ChartOverlayHost smoke', () {
    testWidgets('shows need screenshot panel when chart missing', (tester) async {
      final transform = TransformationController();
      addTearDown(transform.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChartOverlayHost(
              mobile: false,
              canRender: false,
              chartFile: null,
              cachedAnalysisChartFileMissing: false,
              chartFromHistoryFallback: false,
              isImageSpaceMode: false,
              isLoading: false,
              coordinateModeLabel: 'test',
              hotspotCount: 0,
              calibrationLabel: null,
              calibrationTone: PremiumStatusTone.neutral,
              showDebugOverlay: false,
              debugOverlayOpacity: 0.5,
              debugOverlayFile: null,
              worldMapEnabled: false,
              captainEnabled: false,
              onCanvasSizeChanged: (_) {},
              markerBuilder: (_) => const SizedBox.shrink(),
              transformController: transform,
              onDebugToggle: (_) {},
              onDebugOpacityChanged: (_) {},
              onAnalyze: () {},
              onCalibrate: () {},
              onWorldMap: () {},
              onCaptainAtlas: () {},
              onGpx: () {},
              missingChartRecovery: const Text('recovery'),
              needScreenshotPanel: const Text('screenshot-needed'),
              warningCard: null,
            ),
          ),
        ),
      );

      expect(find.text('screenshot-needed'), findsOneWidget);
      expect(find.byType(RepaintBoundary), findsWidgets);
    });
  });

  group('MapOverlayHost smoke', () {
    testWidgets('returns shrink when hotspot null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapHotspotDetailOverlayHost(
              hotspot: null,
              isChartOverlay: false,
              mobileLayout: false,
              geoViz: GeoVisualizationState.fallback(),
              boatPosition: null,
              apiService: ApiService(serverBaseUrl: 'http://127.0.0.1'),
              sessionAnalysis: null,
              aiCache: AiAssistantCache(),
              clientIdentity: ClientIdentityService(),
              captainSummary: null,
              onClose: _noop,
              onGo: _noop,
              onCompare: _noop,
              onSave: _noop,
            ),
          ),
        ),
      );
      expect(find.byType(SizedBox), findsWidgets);
    });
  });

  group('Integration navigation smoke', () {
    Widget missionNavHarness({
      required void Function(BuildContext ctx) onLiveTap,
      required void Function(BuildContext ctx) onPhotoTap,
      required void Function(BuildContext ctx) onMarineTap,
      required void Function(BuildContext ctx) onCaptainTap,
    }) {
      return MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: SingleChildScrollView(
              child: MissionControlLayout(
                overview: DashboardOverview.empty,
                serverIp: '127.0.0.1',
                onLiveTap: () => onLiveTap(ctx),
                onPhotoTap: () => onPhotoTap(ctx),
                onMarineTap: () => onMarineTap(ctx),
                onCompareTap: () {},
                onCaptainAtlasTap: () => onCaptainTap(ctx),
                onRefresh: () {},
              ),
            ),
          ),
        ),
      );
    }

    Future<void> tapDock(WidgetTester tester, Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      for (var i = 0; i < 24; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('Mission Control to Marine Intelligence', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        missionNavHarness(
          onLiveTap: (_) {},
          onPhotoTap: (_) {},
          onMarineTap: (ctx) => PremiumNavigator.push<void>(
            ctx,
            const MarineIntelligenceScreen(serverIp: '127.0.0.1'),
          ),
          onCaptainTap: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      await tapDock(tester, find.byKey(const Key('btn_marine_analysis')));

      expect(find.byType(MarineIntelligenceScreen), findsOneWidget);
      expect(find.text(kMarineScreenTitle), findsWidgets);
    });

    testWidgets('Mission Control to Map', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        missionNavHarness(
          onLiveTap: (_) {},
          onPhotoTap: (ctx) => PremiumNavigator.push<void>(
            ctx,
            const MapScreen(serverIp: '127.0.0.1'),
          ),
          onMarineTap: (_) {},
          onCaptainTap: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      await tapDock(tester, find.byKey(const Key('btn_photo_analysis')));

      expect(find.byType(MapScreen), findsOneWidget);
    });

    testWidgets('Mission Control to Live Area', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        missionNavHarness(
          onLiveTap: (ctx) => PremiumNavigator.push<void>(
            ctx,
            const LiveAreaScreen(serverIp: '127.0.0.1'),
          ),
          onPhotoTap: (_) {},
          onMarineTap: (_) {},
          onCaptainTap: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      await tapDock(tester, find.byKey(const Key('btn_live_area')));

      expect(find.byType(LiveAreaScreen), findsOneWidget);
      expect(find.text(kLiveAreaAppBarTitle), findsWidgets);
    });

    testWidgets('Mission Control to Captain Atlas command center', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        missionNavHarness(
          onLiveTap: (_) {},
          onPhotoTap: (_) {},
          onMarineTap: (_) {},
          onCaptainTap: (ctx) =>
              CaptainAtlasLauncher.openCommandCenter(ctx, '127.0.0.1'),
        ),
      );
      await tester.pumpAndSettle();

      await tapDock(tester, find.byKey(const Key('btn_captain_atlas')));

      expect(find.byType(CaptainAtlasScreen), findsOneWidget);
      expect(find.text(kCaptainAtlasScreenTitle), findsWidgets);
    });

    testWidgets('HomeScreen mission dock visible on mobile', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(390, 844)),
            child: const HomeScreen(),
          ),
        ),
      );
      await _waitForMissionDock(tester);

      expect(find.byKey(const Key('btn_marine_analysis')), findsWidgets);
      expect(find.byKey(const Key('btn_captain_atlas')), findsWidgets);
      expect(find.text(kMissionControlTitle), findsNothing);
      expect(find.text(kPremiumDashLiveScoreTitle), findsOneWidget);
    });
  });

  group('BatterySaver smoke', () {
    testWidgets('MapScreen renders in batterySaver', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _perfWrap(
          const MapScreen(serverIp: '127.0.0.1'),
          mode: PremiumPerformanceMode.batterySaver,
        ),
      );
      await tester.pump();
      expect(find.byType(MapScreen), findsOneWidget);
    });

    testWidgets('MarineIntelligenceScreen renders in batterySaver', (tester) async {
      await tester.pumpWidget(
        _perfWrap(
          const MarineIntelligenceScreen(serverIp: '127.0.0.1'),
          mode: PremiumPerformanceMode.batterySaver,
        ),
      );
      await tester.pump();
      expect(find.text(kMarineScreenTitle), findsWidgets);
    });
  });

  group('Captain Atlas sheet smoke', () {
    testWidgets('launcher opens command center sheet', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: ElevatedButton(
                onPressed: () => CaptainAtlasLauncher.openCommandCenter(ctx, '127.0.0.1'),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(CaptainAtlasScreen), findsOneWidget);
      expect(find.text(kCaptainAtlasQuickQuestions), findsOneWidget);
    });
  });

  group('Legacy MarineReportCards migration', () {
    testWidgets('premium decision card mirrors legacy label helper', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarineDecisionOverviewCard(
              report: MarineIntelligenceReport.fromJson({
                'coordinate': {'lat': 37.0, 'lon': 27.0},
                'weather': {},
                'wind': {},
                'marine': {},
                'astronomy': {},
                'fishing_score': {
                  'suitability_score': 75,
                  'risk_score': 20,
                  'confidence': 0.6,
                },
                'consensus_summary': {},
                'decision': {
                  'fishing_decision': 'good',
                  'go_score': 72,
                  'wait_score': 28,
                },
                'updated_at': '2024-06-15T06:00:00+00:00',
              }),
            ),
          ),
        ),
      );

      expect(find.text(kMarineDecisionGood), findsWidgets);
      expect(marineDecisionLabelTr('good'), kMarineDecisionGood);
    });

    test('MarineReportCards remains deprecated export surface', () {
      expect(marineDecisionBadgeLabelTr('borderline'), kMarineLastDecisionBorderline);
    });
  });
}

void _noop() {}
