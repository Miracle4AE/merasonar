import 'package:deniz_app/domain/dashboard_overview.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/layout/premium_app_shell.dart';
import 'package:deniz_app/screens/premium_dashboard_screen.dart';
import 'package:deniz_app/widgets/dashboard/mission/mission_quick_action_dock.dart';
import 'package:deniz_app/widgets/dashboard/v2/dashboard_v2_captain_atlas_card.dart';
import 'package:deniz_app/widgets/dashboard/v2/dashboard_v2_compare_card.dart';
import 'package:deniz_app/widgets/dashboard/v2/dashboard_v2_day_timeline_card.dart';
import 'package:deniz_app/widgets/dashboard/v2/dashboard_v2_forecast_card.dart';
import 'package:deniz_app/widgets/dashboard/v2/dashboard_v2_live_score_card.dart';
import 'package:deniz_app/widgets/dashboard/v2/dashboard_v2_map_card.dart';
import 'package:deniz_app/widgets/dashboard/v2/dashboard_v2_tide_card.dart';
import 'package:deniz_app/widgets/dashboard/v2/premium_dashboard_v2_layout.dart';
import 'package:deniz_app/widgets/premium/captain_atlas_hero_card.dart';
import 'package:deniz_app/services/dashboard_overview_service.dart';
import 'package:deniz_app/services/marine_intelligence_cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

DashboardOverview _emptyOverview() {
  return DashboardOverview.empty.copyWith(
    connectionStatus: DashboardConnectionStatus.disconnected,
    forecast: const DashboardForecastSummary(
      emptyReason: kPremiumDashForecastEmptyHint,
    ),
    tide: const DashboardTideSummary(
      emptyReason: kPremiumDashTideNoProvider,
    ),
  );
}

DashboardOverviewService _staticOverviewService() {
  return DashboardOverviewService(
    marineCache: MarineIntelligenceCache(),
    fetchMarineReport: null,
  );
}

/// Premium dashboard ekranı — arka plan refresh kapalı (initialOverview sabit kalır).
Widget _dashboardScreen({
  required String serverIp,
  required VoidCallback onLiveTap,
  required VoidCallback onPhotoTap,
  required VoidCallback onMarineTap,
  required VoidCallback onCompareTap,
  required VoidCallback onCaptainAtlasTap,
  DashboardOverview? initialOverview,
  DashboardConnectionStatus connectionStatus =
      DashboardConnectionStatus.unknown,
}) {
  return PremiumDashboardScreen(
    serverIp: serverIp,
    onLiveTap: onLiveTap,
    onPhotoTap: onPhotoTap,
    onMarineTap: onMarineTap,
    onCompareTap: onCompareTap,
    onCaptainAtlasTap: onCaptainAtlasTap,
    initialOverview: initialOverview,
    connectionStatus: connectionStatus,
    overviewService: _staticOverviewService(),
  );
}

DashboardOverview _populatedOverview() {
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
      totalCount: 2,
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
      summaryTr: 'Bugün öğleden sonra daha sakin.',
      personaVersion: 'v1',
    ),
    timeline: const DashboardTimelineSummary(
      slots: [
        DashboardTimelineSlot(time: '06:00–09:00', label: 'Uygun · 78', decision: 'good'),
        DashboardTimelineSlot(time: '09:00–12:00', label: 'Orta · 55'),
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
      waveLabel: '0.8 m',
      currentLabel: '0.35 m/s',
      windLabel: '12 km/s KD',
      dataSourceLabel: kPremiumDashMapSourceReport,
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

Widget _wrap(Widget child, {Size size = const Size(1600, 1000)}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('Dashboard V2 smoke test', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        _dashboardScreen(
          serverIp: '127.0.0.1',
          onLiveTap: () {},
          onPhotoTap: () {},
          onMarineTap: () {},
          onCompareTap: () {},
          onCaptainAtlasTap: () {},
          initialOverview: _populatedOverview(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(kMissionControlTitle), findsNothing);
    expect(find.byType(PremiumDashboardV2Layout), findsOneWidget);
    expect(find.text(kPremiumDashLiveScoreTitle), findsOneWidget);
    expect(find.text(kPremiumDashTimelineTitle), findsOneWidget);
  });

  testWidgets('Desktop layout renders map/live/timeline first row', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        _dashboardScreen(
          serverIp: '127.0.0.1',
          onLiveTap: () {},
          onPhotoTap: () {},
          onMarineTap: () {},
          onCompareTap: () {},
          onCaptainAtlasTap: () {},
          initialOverview: _populatedOverview(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(DashboardV2MapCard), findsOneWidget);
    expect(find.byType(DashboardV2LiveScoreCard), findsOneWidget);
    expect(find.byType(DashboardV2DayTimelineCard), findsOneWidget);
  });

  testWidgets('Dashboard does not render Mission Control', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        _dashboardScreen(
          serverIp: '127.0.0.1',
          onLiveTap: () {},
          onPhotoTap: () {},
          onMarineTap: () {},
          onCompareTap: () {},
          onCaptainAtlasTap: () {},
          initialOverview: _populatedOverview(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(kMissionControlTitle), findsNothing);
    expect(find.text(kMissionScoreTitle), findsNothing);
    expect(find.text(kMissionCaptainCommandTitle), findsNothing);
    expect(find.text(kMissionNoActiveMission), findsNothing);
  });

  testWidgets('Sidebar active item Genel Bakış test', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1366, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1366, 768)),
          child: PremiumAppShell(
            selectedSectionId: 'overview',
            onSectionSelected: (_) {},
            serverIp: '127.0.0.1',
            hideEnvironmentChips: true,
            child: const SizedBox(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(kPremiumSidebarOverview), findsWidgets);
  });

  testWidgets('Empty state compact test', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        _dashboardScreen(
          serverIp: '127.0.0.1',
          onLiveTap: () {},
          onPhotoTap: () {},
          onMarineTap: () {},
          onCompareTap: () {},
          onCaptainAtlasTap: () {},
          connectionStatus: DashboardConnectionStatus.disconnected,
          initialOverview: _emptyOverview(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(kMissionControlTitle), findsNothing);
    expect(find.text(kPremiumDashSpotsEmpty), findsOneWidget);
    expect(find.text(kPremiumDashCompareEmpty), findsOneWidget);
    expect(find.text(kPremiumDashConnectionOff), findsOneWidget);
    expect(find.text('78'), findsNothing);
    expect(find.text('82'), findsNothing);
  });

  testWidgets('Captain Atlas card render test', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        _dashboardScreen(
          serverIp: '127.0.0.1',
          onLiveTap: () {},
          onPhotoTap: () {},
          onMarineTap: () {},
          onCompareTap: () {},
          onCaptainAtlasTap: () {},
          initialOverview: _populatedOverview(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(DashboardV2CaptainAtlasCard), findsOneWidget);
    expect(find.text('Bugün öğleden sonra daha sakin.'), findsOneWidget);
    expect(find.text(kPremiumCaptainAskButton), findsOneWidget);
  });

  testWidgets('Compare card render test', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        _dashboardScreen(
          serverIp: '127.0.0.1',
          onLiveTap: () {},
          onPhotoTap: () {},
          onMarineTap: () {},
          onCompareTap: () {},
          onCaptainAtlasTap: () {},
          initialOverview: _populatedOverview(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(DashboardV2CompareCard), findsOneWidget);
    expect(find.text('Detaylı Karşılaştırma'), findsOneWidget);
  });

  testWidgets('Compare no-score does not render broken gauge', (tester) async {
    await tester.pumpWidget(
      _wrap(
        _dashboardScreen(
          serverIp: '127.0.0.1',
          onLiveTap: () {},
          onPhotoTap: () {},
          onMarineTap: () {},
          onCompareTap: () {},
          onCaptainAtlasTap: () {},
          initialOverview: _emptyOverview(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(kPremiumDashCompareEmpty), findsOneWidget);
    expect(find.text(kPremiumDashCompareCta), findsOneWidget);
    expect(find.text('Detaylı Karşılaştırma'), findsNothing);
    expect(find.text('A Noktası'), findsNothing);
  });

  testWidgets('Desktop does not show quick dock', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        _dashboardScreen(
          serverIp: '127.0.0.1',
          onLiveTap: () {},
          onPhotoTap: () {},
          onMarineTap: () {},
          onCompareTap: () {},
          onCaptainAtlasTap: () {},
          initialOverview: _populatedOverview(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(MissionQuickActionDock), findsNothing);
    expect(find.text(kMissionDockLive), findsNothing);
  });

  testWidgets('Mobile shows quick dock', (tester) async {
    await tester.pumpWidget(
      _wrap(
        _dashboardScreen(
          serverIp: '127.0.0.1',
          onLiveTap: () {},
          onPhotoTap: () {},
          onMarineTap: () {},
          onCompareTap: () {},
          onCaptainAtlasTap: () {},
          initialOverview: _populatedOverview(),
        ),
        size: const Size(390, 844),
      ),
    );
    await tester.pump();

    expect(find.text(kMissionDockLive), findsOneWidget);
  });

  testWidgets('Sidebar Captain title not broken / maxLines', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1366, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1366, 768)),
          child: PremiumAppShell(
            selectedSectionId: 'overview',
            onSectionSelected: (_) {},
            serverIp: '127.0.0.1',
            hideEnvironmentChips: true,
            child: const SizedBox(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CaptainAtlasHeroCard), findsOneWidget);
    final title = tester.widget<Text>(
      find.descendant(
        of: find.byType(CaptainAtlasHeroCard),
        matching: find.text(kPremiumCaptainCardTitle),
      ),
    );
    expect(title.maxLines, 1);
    expect(title.overflow, TextOverflow.ellipsis);
  });

  testWidgets('Map card renders premium contour painter', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        _dashboardScreen(
          serverIp: '127.0.0.1',
          onLiveTap: () {},
          onPhotoTap: () {},
          onMarineTap: () {},
          onCompareTap: () {},
          onCaptainAtlasTap: () {},
          initialOverview: _populatedOverview(),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.descendant(
        of: find.byType(DashboardV2MapCard),
        matching: find.byType(CustomPaint),
      ),
      findsWidgets,
    );
    expect(find.byType(RepaintBoundary), findsWidgets);
  });

  testWidgets('Live score uses Turkish rating labels', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        _dashboardScreen(
          serverIp: '127.0.0.1',
          onLiveTap: () {},
          onPhotoTap: () {},
          onMarineTap: () {},
          onCompareTap: () {},
          onCaptainAtlasTap: () {},
          initialOverview: _populatedOverview(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('İyi'), findsWidgets);
    expect(find.text('Good'), findsNothing);
  });

  testWidgets('Dashboard CTA compact render', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        _dashboardScreen(
          serverIp: '127.0.0.1',
          onLiveTap: () {},
          onPhotoTap: () {},
          onMarineTap: () {},
          onCompareTap: () {},
          onCaptainAtlasTap: () {},
          initialOverview: _emptyOverview(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(OutlinedButton), findsWidgets);
  });

  testWidgets('Captain card compact render', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1366, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        _dashboardScreen(
          serverIp: '127.0.0.1',
          onLiveTap: () {},
          onPhotoTap: () {},
          onMarineTap: () {},
          onCompareTap: () {},
          onCaptainAtlasTap: () {},
          initialOverview: _populatedOverview(),
        ),
        size: const Size(1366, 768),
      ),
    );
    await tester.pump();

    expect(find.byType(DashboardV2CaptainAtlasCard), findsOneWidget);
    expect(find.text('Hazır'), findsOneWidget);
  });

  testWidgets('Forecast no-data placeholder test', (tester) async {
    await tester.pumpWidget(
      _wrap(
        _dashboardScreen(
          serverIp: '127.0.0.1',
          onLiveTap: () {},
          onPhotoTap: () {},
          onMarineTap: () {},
          onCompareTap: () {},
          onCaptainAtlasTap: () {},
          initialOverview: _emptyOverview(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(DashboardV2ForecastCard), findsOneWidget);
    expect(find.byType(DashboardV2TideCard), findsOneWidget);
    expect(find.textContaining('7 günlük tahmin'), findsOneWidget);
    expect(find.textContaining('Gelgit sağlayıcısı'), findsOneWidget);
  });

  testWidgets('Tide no-data placeholder test', (tester) async {
    await tester.pumpWidget(
      _wrap(
        _dashboardScreen(
          serverIp: '127.0.0.1',
          onLiveTap: () {},
          onPhotoTap: () {},
          onMarineTap: () {},
          onCompareTap: () {},
          onCaptainAtlasTap: () {},
          initialOverview: _emptyOverview(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(DashboardV2TideCard), findsOneWidget);
    expect(find.textContaining('Gelgit sağlayıcısı'), findsOneWidget);
  });

  testWidgets('1920x1080 layout smoke test', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1920, 1080));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        _dashboardScreen(
          serverIp: '127.0.0.1',
          onLiveTap: () {},
          onPhotoTap: () {},
          onMarineTap: () {},
          onCompareTap: () {},
          onCaptainAtlasTap: () {},
          initialOverview: _populatedOverview(),
        ),
        size: const Size(1920, 1080),
      ),
    );
    await tester.pump();

    expect(find.byType(DashboardV2MapCard), findsOneWidget);
    expect(find.byType(DashboardV2LiveScoreCard), findsOneWidget);
    expect(find.byType(DashboardV2DayTimelineCard), findsOneWidget);
  });

  testWidgets('Tablet 1024x768 layout smoke test', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        _dashboardScreen(
          serverIp: '127.0.0.1',
          onLiveTap: () {},
          onPhotoTap: () {},
          onMarineTap: () {},
          onCompareTap: () {},
          onCaptainAtlasTap: () {},
          initialOverview: _populatedOverview(),
        ),
        size: const Size(1024, 768),
      ),
    );
    await tester.pump();

    expect(find.byType(DashboardV2MapCard), findsOneWidget);
    expect(find.text(kMissionControlTitle), findsNothing);
  });

  testWidgets('1366x768 layout smoke test', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1366, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        _dashboardScreen(
          serverIp: '127.0.0.1',
          onLiveTap: () {},
          onPhotoTap: () {},
          onMarineTap: () {},
          onCompareTap: () {},
          onCaptainAtlasTap: () {},
          initialOverview: _populatedOverview(),
        ),
        size: const Size(1366, 768),
      ),
    );
    await tester.pump();

    expect(find.byType(DashboardV2MapCard), findsOneWidget);
    expect(find.byType(DashboardV2LiveScoreCard), findsOneWidget);
    expect(find.text('82'), findsWidgets);
  });

  testWidgets('Mobile layout smoke test', (tester) async {
    await tester.pumpWidget(
      _wrap(
        _dashboardScreen(
          serverIp: '127.0.0.1',
          onLiveTap: () {},
          onPhotoTap: () {},
          onMarineTap: () {},
          onCompareTap: () {},
          onCaptainAtlasTap: () {},
          initialOverview: _populatedOverview(),
        ),
        size: const Size(390, 844),
      ),
    );
    await tester.pump();

    expect(find.text(kMissionControlTitle), findsNothing);
    expect(find.text(kPremiumDashLiveScoreTitle), findsOneWidget);
    expect(find.text('82'), findsWidgets);
  });

  testWidgets('Existing HomeScreen navigation regression', (tester) async {
    await tester.pumpWidget(
      _wrap(
        _dashboardScreen(
          serverIp: '127.0.0.1',
          onLiveTap: () {},
          onPhotoTap: () {},
          onMarineTap: () {},
          onCompareTap: () {},
          onCaptainAtlasTap: () {},
          initialOverview: _populatedOverview(),
        ),
        size: const Size(390, 844),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('btn_live_area')), findsOneWidget);
    expect(find.byKey(const Key('btn_photo_analysis')), findsOneWidget);
    expect(find.byKey(const Key('btn_marine_analysis')), findsOneWidget);
  });

  testWidgets('Mission score with report test', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        _dashboardScreen(
          serverIp: '127.0.0.1',
          onLiveTap: () {},
          onPhotoTap: () {},
          onMarineTap: () {},
          onCompareTap: () {},
          onCaptainAtlasTap: () {},
          initialOverview: _populatedOverview(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('78'), findsWidgets);
    expect(find.textContaining('Sabah erken'), findsOneWidget);
  });

  testWidgets('Saved spots strip render test', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        _dashboardScreen(
          serverIp: '127.0.0.1',
          onLiveTap: () {},
          onPhotoTap: () {},
          onMarineTap: () {},
          onCompareTap: () {},
          onCaptainAtlasTap: () {},
          initialOverview: _populatedOverview(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Koy A'), findsWidgets);
    expect(find.text('80'), findsWidgets);
  });

  testWidgets('Dashboard V2 final smoke at 1600x900', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        _dashboardScreen(
          serverIp: '127.0.0.1',
          onLiveTap: () {},
          onPhotoTap: () {},
          onMarineTap: () {},
          onCompareTap: () {},
          onCaptainAtlasTap: () {},
          initialOverview: _populatedOverview(),
        ),
        size: const Size(1600, 900),
      ),
    );
    await tester.pump();

    expect(find.byType(PremiumDashboardV2Layout), findsOneWidget);
    expect(find.byType(DashboardV2MapCard), findsOneWidget);
    expect(find.byType(DashboardV2LiveScoreCard), findsOneWidget);
    expect(find.byType(DashboardV2CaptainAtlasCard), findsOneWidget);
    expect(find.byType(MissionQuickActionDock), findsNothing);
  });

  testWidgets('Map card hero painter render', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        _dashboardScreen(
          serverIp: '127.0.0.1',
          onLiveTap: () {},
          onPhotoTap: () {},
          onMarineTap: () {},
          onCompareTap: () {},
          onCaptainAtlasTap: () {},
          initialOverview: _populatedOverview(),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.descendant(
        of: find.byType(DashboardV2MapCard),
        matching: find.byType(CustomPaint),
      ),
      findsWidgets,
    );
    expect(find.text(kPremiumDashMapRealData), findsOneWidget);
  });

  testWidgets('Live score card dense render with Turkish Medium label', (tester) async {
    final overview = _populatedOverview().copyWith(
      liveScore: const DashboardLiveScoreSummary(
        score: 55,
        rating: 'Medium',
      ),
    );
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        _dashboardScreen(
          serverIp: '127.0.0.1',
          onLiveTap: () {},
          onPhotoTap: () {},
          onMarineTap: () {},
          onCompareTap: () {},
          onCaptainAtlasTap: () {},
          initialOverview: overview,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Orta'), findsWidgets);
    expect(find.text('Medium'), findsNothing);
    expect(find.text('55'), findsWidgets);
  });

  testWidgets('Captain Atlas card balanced render', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1366, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        _dashboardScreen(
          serverIp: '127.0.0.1',
          onLiveTap: () {},
          onPhotoTap: () {},
          onMarineTap: () {},
          onCompareTap: () {},
          onCaptainAtlasTap: () {},
          initialOverview: _populatedOverview(),
        ),
        size: const Size(1366, 768),
      ),
    );
    await tester.pump();

    expect(find.byType(DashboardV2CaptainAtlasCard), findsOneWidget);
    expect(find.text('Hazır'), findsOneWidget);
    expect(find.text('v1'), findsOneWidget);
    expect(find.byKey(const Key('btn_dashboard_captain_atlas')), findsOneWidget);
  });

  testWidgets('Empty states compact render with decorative patterns', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        _dashboardScreen(
          serverIp: '127.0.0.1',
          onLiveTap: () {},
          onPhotoTap: () {},
          onMarineTap: () {},
          onCompareTap: () {},
          onCaptainAtlasTap: () {},
          initialOverview: _emptyOverview(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(kPremiumDashSpotsEmpty), findsOneWidget);
    expect(find.text(kPremiumDashCompareEmpty), findsOneWidget);
    expect(find.text(kPremiumDashCatchesEmptyLong), findsOneWidget);
    expect(find.byType(OutlinedButton), findsWidgets);
  });
}
