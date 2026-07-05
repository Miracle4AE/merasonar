import 'dart:io';
import 'dart:ui' as ui;

import 'package:deniz_app/domain/dashboard_overview.dart';
import 'package:deniz_app/domain/premium_performance_mode.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/layout/premium_app_shell.dart';
import 'package:deniz_app/navigation/captain_atlas_launcher.dart';
import 'package:deniz_app/screens/captain_atlas_screen.dart';
import 'package:deniz_app/map/widgets/marine/marine_catch_dialog.dart';
import 'package:deniz_app/map/widgets/marine/marine_saved_spots_panel.dart';
import 'package:deniz_app/domain/marine_saved_spot.dart';
import 'package:deniz_app/services/app_preferences.dart';
import 'package:deniz_app/widgets/dashboard/v2/premium_dashboard_v2_layout.dart';
import 'package:deniz_app/widgets/premium/premium_animation_policy.dart';
import 'package:deniz_app/widgets/premium/premium_performance_scope.dart';
import 'package:deniz_app/widgets/premium/settings/premium_performance_mode_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

DashboardOverview _overview() {
  return DashboardOverview(
    connectionStatus: DashboardConnectionStatus.connected,
    location: const DashboardLocationSummary(
      lat: 41.01,
      lon: 29.0,
      label: '41.0100, 29.0000',
    ),
    liveScore: const DashboardLiveScoreSummary(
      score: 82,
      rating: 'Good',
      detailLine: 'Rüzgar düşük',
      suitabilityLabel: 'Good',
    ),
    marineReport: const DashboardMarineReportSummary(
      suitabilityScore: 75,
      goScore: 78,
      riskScore: 22,
      confidence: 0.82,
      decisionLabel: 'Uygun',
      bestActionTr: 'Sabah erken saatte dene.',
      advice: 'Koşullar uygun.',
      weatherLabel: '18°C',
      moonLabel: 'Dolunay',
      tideLabel: 'Gelgit orta',
    ),
    savedSpots: DashboardSavedSpotsSummary(
      totalCount: 1,
      items: const [
        DashboardSavedSpotItem(
          id: 's1',
          name: 'Koy A',
          lat: 41.0,
          lon: 29.0,
          favorite: true,
          score: 80,
          detailLine: 'Levrek · Skor: 80',
          decisionLabel: 'Uygun',
          reputationScore: 88,
        ),
      ],
    ),
    recentCatches: const DashboardRecentCatchesSummary(
      items: [
        DashboardCatchItem(
          species: 'Levrek',
          spotName: 'Koy A',
          caughtAt: '2026-07-01',
        ),
      ],
    ),
    compare: const DashboardCompareSummary(
      summaryTr: 'A daha sakin · B daha derin',
      winnerLabel: 'A',
      leftLabel: '41.01, 29.00',
      rightLabel: '41.02, 29.01',
      scoreDelta: 12,
    ),
    captainAtlas: const DashboardCaptainAtlasSummary(
      summaryTr: 'Bugün levrek için uygun saatler var.',
      personaVersion: 'v9',
    ),
    timeline: const DashboardTimelineSummary(
      slots: [
        DashboardTimelineSlot(time: '06:00–09:00', label: 'Uygun · 78', decision: 'good'),
      ],
    ),
    tide: const DashboardTideSummary(label: 'Yükselen'),
    forecast: const DashboardForecastSummary(label: '7 günlük veri mevcut'),
    mapPreview: DashboardMapPreviewData(
      centerLat: 41.01,
      centerLon: 29.0,
      centerLabel: '41.0100, 29.0000',
      score: 75,
      updatedAgoLabel: '2 dk',
      hotspotCount: 3,
      hasRealCoordinate: true,
      displayMode: DashboardMapPreviewMode.activeReport,
      markers: const [
        DashboardMapMarker(
          normalizedX: 0.4,
          normalizedY: 0.5,
          label: 'Koy A',
          lat: 41.01,
          lon: 29.0,
          score: 75,
          isFavorite: true,
          isPrimary: true,
          markerType: DashboardMapMarkerType.report,
        ),
      ],
    ),
  );
}

Widget _dashboardHarness({
  required VoidCallback onCaptainAtlasTap,
  PremiumPerformanceMode mode = PremiumPerformanceMode.balanced,
}) {
  return MaterialApp(
    home: PremiumPerformanceScope(
      mode: mode,
      onModeChanged: (_) {},
      child: MediaQuery(
        data: const MediaQueryData(size: Size(1600, 1000)),
        child: Scaffold(
          body: PremiumDashboardV2Layout(
            overview: _overview(),
            serverIp: '127.0.0.1',
            onLiveTap: () {},
            onPhotoTap: () {},
            onMarineTap: () {},
            onCompareTap: () {},
            onCaptainAtlasTap: onCaptainAtlasTap,
          ),
        ),
      ),
    ),
  );
}

Future<void> _savePng(WidgetTester tester, String path) async {
  await tester.pumpAndSettle();
  await tester.binding.runAsync(() async {
    final boundary = tester.renderObject(
      find.byKey(const Key('rc7_screenshot_root')),
    ) as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(byteData!.buffer.asUint8List());
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RC7 Captain Atlas navigation', () {
    testWidgets('sidebar Captain Atlas tap opens CaptainAtlasScreen', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1600, 1000)),
            child: PremiumAppShell(
              selectedSectionId: 'overview',
              onSectionSelected: (_) {},
              serverIp: '127.0.0.1',
              hideEnvironmentChips: true,
              child: const SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_sidebar_captain_atlas')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('screen_captain_atlas')), findsOneWidget);
      expect(find.text(kCaptainAtlasScreenTitle), findsWidgets);
    });

    testWidgets('dashboard Captain Atlas CTA opens CaptainAtlasScreen', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => _dashboardHarness(
              onCaptainAtlasTap: () =>
                  CaptainAtlasLauncher.openCommandCenter(ctx, '127.0.0.1'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('btn_dashboard_captain_atlas')), findsOneWidget);
      await tester.tap(find.byKey(const Key('btn_dashboard_captain_atlas')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('screen_captain_atlas')), findsOneWidget);
      expect(find.text(kCaptainAtlasQuickQuestions), findsOneWidget);
    });
  });

  group('RC7 Dashboard V2 performance mode', () {
    testWidgets('performance mode control renders', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_dashboardHarness(onCaptainAtlasTap: () {}));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('btn_performance_mode')), findsOneWidget);
    });

    testWidgets('battery saver selection persists', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_dashboardHarness(onCaptainAtlasTap: () {}));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('btn_performance_mode')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(PremiumPerformanceModeTile.labelFor(
          PremiumPerformanceMode.batterySaver,
        )),
      );
      await tester.pumpAndSettle();

      expect(
        await AppPreferences.getPerformanceMode(),
        PremiumPerformanceMode.batterySaver,
      );
    });

    testWidgets('dashboard batterySaver smoke', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _dashboardHarness(
          onCaptainAtlasTap: () {},
          mode: PremiumPerformanceMode.batterySaver,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('btn_performance_mode')), findsOneWidget);
      expect(
        PremiumAnimationPolicy.continuousMotionEnabled(
          tester.element(find.byType(PremiumDashboardV2Layout)),
        ),
        isFalse,
      );
    });
  });

  group('RC7 screenshot export', () {
    testWidgets('export captain atlas screenshot when enabled', (tester) async {
      const exportFlag = bool.fromEnvironment('EXPORT_RC_SCREENSHOTS');
      if (!exportFlag) return;

      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: RepaintBoundary(
            key: const Key('rc7_screenshot_root'),
            child: CaptainAtlasScreen(serverIp: '127.0.0.1'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      final root = Platform.environment['RC_SCREENSHOT_ROOT'] ??
          '../../docs/screenshots/rc1';
      await _savePng(
        tester,
        '$root/captain-atlas.png',
      );
    });

    testWidgets('export battery saver dashboard screenshot when enabled', (tester) async {
      const exportFlag = bool.fromEnvironment('EXPORT_RC_SCREENSHOTS');
      if (!exportFlag) return;

      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: RepaintBoundary(
            key: const Key('rc7_screenshot_root'),
            child: _dashboardHarness(
              onCaptainAtlasTap: () {},
              mode: PremiumPerformanceMode.batterySaver,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final root = Platform.environment['RC_SCREENSHOT_ROOT'] ??
          '../../docs/screenshots/rc1';
      await _savePng(
        tester,
        '$root/battery-saver-dashboard.png',
      );
    });

    testWidgets('export catch dialog screenshot when enabled', (tester) async {
      const exportFlag = bool.fromEnvironment('EXPORT_RC_SCREENSHOTS');
      if (!exportFlag) return;

      await tester.binding.setSurfaceSize(const Size(480, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: RepaintBoundary(
            key: const Key('rc7_screenshot_root'),
            child: const MarineCatchAddDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final root = Platform.environment['RC_SCREENSHOT_ROOT'] ??
          '../../docs/screenshots/rc1';
      await _savePng(tester, '$root/catch-dialog.png');
    });

    testWidgets('export saved spot panel screenshot when enabled', (tester) async {
      const exportFlag = bool.fromEnvironment('EXPORT_RC_SCREENSHOTS');
      if (!exportFlag) return;

      final spot = MarineSavedSpot.fromJson({
        'id': 'spot-rc7',
        'name': 'RC7 Koy',
        'lat': 37.0,
        'lon': 27.0,
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-01T00:00:00Z',
        'favorite': true,
      });

      await tester.binding.setSurfaceSize(const Size(520, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: RepaintBoundary(
            key: const Key('rc7_screenshot_root'),
            child: MarineSavedSpotsPanel(
              spots: [spot],
              onRefresh: (_) async {},
              onDelete: (_) async {},
              onToggleFavorite: (_) async {},
              onAddCatch: (_) async {},
              onShowCatches: (_) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final root = Platform.environment['RC_SCREENSHOT_ROOT'] ??
          '../../docs/screenshots/rc1';
      await _savePng(tester, '$root/saved-spot-crud.png');
    });
  });
}
