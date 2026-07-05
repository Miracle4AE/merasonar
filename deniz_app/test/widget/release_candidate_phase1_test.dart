import 'package:deniz_app/domain/dashboard_overview.dart';
import 'package:deniz_app/domain/premium_performance_mode.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/map_screen.dart';
import 'package:deniz_app/screens/captain_atlas_screen.dart';
import 'package:deniz_app/screens/marine_compare_screen.dart';
import 'package:deniz_app/screens/marine_intelligence_screen.dart';
import 'package:deniz_app/screens/premium_dashboard_screen.dart';
import 'package:deniz_app/widgets/dashboard/mission/mission_quick_action_dock.dart';
import 'package:deniz_app/widgets/dashboard/v2/premium_dashboard_v2_layout.dart';
import 'package:deniz_app/widgets/premium/premium_performance_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

DashboardOverview _emptyDisconnected() {
  return DashboardOverview.empty.copyWith(
    connectionStatus: DashboardConnectionStatus.disconnected,
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

Widget _perfWrap(Widget child, {PremiumPerformanceMode mode = PremiumPerformanceMode.full}) {
  return MaterialApp(
    home: PremiumPerformanceScope(
      mode: mode,
      onModeChanged: (_) {},
      child: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RC Phase 1 — startup smoke', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('dashboard no backend empty state smoke', (tester) async {
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
            initialOverview: _emptyDisconnected(),
            connectionStatus: DashboardConnectionStatus.disconnected,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(PremiumDashboardV2Layout), findsOneWidget);
      expect(find.text('Mission Control'), findsNothing);
    });

    testWidgets('batterySaver dashboard smoke', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _perfWrap(
          _wrap(
            PremiumDashboardV2Layout(
              overview: DashboardOverview.empty,
              serverIp: '127.0.0.1',
              onLiveTap: () {},
              onPhotoTap: () {},
              onMarineTap: () {},
              onCompareTap: () {},
              onCaptainAtlasTap: () {},
            ),
          ),
          mode: PremiumPerformanceMode.batterySaver,
        ),
      );
      await tester.pump();
      expect(find.byType(PremiumDashboardV2Layout), findsOneWidget);
    });
  });

  group('RC Phase 1 — screen smoke', () {
    testWidgets('MapScreen builds without crash', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: MapScreen(serverIp: '127.0.0.1')),
      );
      await tester.pump();
      expect(find.byType(MapScreen), findsOneWidget);
    });

    testWidgets('Marine Intelligence screen smoke', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: MarineIntelligenceScreen(serverIp: '127.0.0.1')),
      );
      await tester.pump();
      expect(find.byType(MarineIntelligenceScreen), findsOneWidget);
    });

    testWidgets('Captain Atlas screen smoke', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: CaptainAtlasScreen(serverIp: '127.0.0.1')),
      );
      await tester.pump();
      expect(find.text(kCaptainAtlasScreenTitle), findsWidgets);
    });

    testWidgets('Compare screen smoke', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: MarineCompareScreen(serverIp: '127.0.0.1')),
      );
      await tester.pump();
      expect(find.text(kMarineCompareScreenTitle), findsOneWidget);
    });
  });

  group('RC Phase 1 — regression', () {
    testWidgets('no Mission Control text on premium dashboard', (tester) async {
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

    testWidgets('desktop has no quick dock', (tester) async {
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
      expect(find.byType(MissionQuickActionDock), findsNothing);
    });

    testWidgets('mobile quick dock regression', (tester) async {
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
          size: const Size(390, 844),
        ),
      );
      await tester.pump();
      expect(find.text(kMissionDockLive), findsOneWidget);
      expect(find.byKey(const Key('btn_captain_atlas')), findsWidgets);
      expect(find.byKey(const Key('btn_live_area')), findsOneWidget);
    });
  });

  group('RC Phase 1 — offline copy constants', () {
    test('standard offline strings are defined', () {
      expect(kPremiumNoConnection, isNotEmpty);
      expect(kPremiumLastSavedData, isNotEmpty);
      expect(kPremiumCacheFromLocal, isNotEmpty);
      expect(kPremiumNoDataLabel, isNotEmpty);
      expect(kMarineOfflineCachedBanner, contains('Bağlantı'));
    });
  });
}
