import 'package:deniz_app/domain/dashboard_overview.dart';
import 'package:deniz_app/domain/premium_performance_mode.dart';
import 'package:deniz_app/screens/captain_atlas_screen.dart';
import 'package:deniz_app/screens/premium_dashboard_screen.dart';
import 'package:deniz_app/services/crash_reporter.dart';
import 'package:deniz_app/widgets/dashboard/mission/mission_quick_action_dock.dart';
import 'package:deniz_app/widgets/dashboard/v2/premium_dashboard_v2_layout.dart';
import 'package:deniz_app/widgets/premium/premium_performance_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  group('RC Phase 3 — smoke', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      installCrashReporting(reporter: NoopCrashReporter());
    });

    testWidgets('crash reporter hook smoke', (tester) async {
      installCrashReporting(reporter: NoopCrashReporter());
      expect(CrashReporter.instance, isA<NoopCrashReporter>());
    });

    testWidgets('dashboard smoke empty overview', (tester) async {
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
      expect(find.byType(PremiumDashboardV2Layout), findsOneWidget);
    });

    testWidgets('Captain Atlas screen smoke', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: CaptainAtlasScreen(serverIp: '127.0.0.1')),
      );
      await tester.pump();
      expect(find.byType(CaptainAtlasScreen), findsOneWidget);
    });

    testWidgets('performance mode batterySaver smoke', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PremiumPerformanceScope(
            mode: PremiumPerformanceMode.batterySaver,
            onModeChanged: (_) {},
            child: _wrap(
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
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(PremiumDashboardV2Layout), findsOneWidget);
    });
  });

  group('RC Phase 3 — regression', () {
    testWidgets('no Mission Control text', (tester) async {
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

    testWidgets('desktop no quick dock', (tester) async {
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

    testWidgets('mobile quick dock present', (tester) async {
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
      expect(find.byType(MissionQuickActionDock), findsOneWidget);
    });
  });
}
