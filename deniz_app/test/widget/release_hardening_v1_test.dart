import 'package:deniz_app/domain/dashboard_overview.dart';
import 'package:deniz_app/domain/premium_performance_mode.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/screens/premium_dashboard_screen.dart';
import 'package:deniz_app/services/app_preferences.dart';
import 'package:deniz_app/widgets/dashboard/mission/mission_control_layout.dart';
import 'package:deniz_app/widgets/premium/navigation/premium_hero_widgets.dart';
import 'package:deniz_app/widgets/dashboard/mission/mission_quick_action_dock.dart';
import 'package:deniz_app/widgets/premium/feedback/premium_error_fallback.dart';
import 'package:deniz_app/widgets/premium/premium_animation_policy.dart';
import 'package:deniz_app/widgets/premium/premium_glass_panel.dart';
import 'package:deniz_app/widgets/premium/premium_performance_scope.dart';
import 'package:deniz_app/widgets/premium/settings/premium_performance_mode_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget child, {PremiumPerformanceMode mode = PremiumPerformanceMode.full}) {
  return MaterialApp(
    home: PremiumPerformanceScope(
      mode: mode,
      onModeChanged: (_) {},
      child: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PremiumPerformanceMode preferences', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to full', () async {
      expect(await AppPreferences.getPerformanceMode(), PremiumPerformanceMode.full);
    });

    test('persists batterySaver', () async {
      await AppPreferences.setPerformanceMode(PremiumPerformanceMode.batterySaver);
      expect(await AppPreferences.getPerformanceMode(), PremiumPerformanceMode.batterySaver);
    });
  });

  group('PremiumAnimationPolicy', () {
    test('batterySaver disables continuous motion by mode', () {
      expect(
        PremiumAnimationPolicy.continuousMotionForMode(
          PremiumPerformanceMode.batterySaver,
        ),
        isFalse,
      );
      expect(
        PremiumAnimationPolicy.motionScaleForMode(
          PremiumPerformanceMode.batterySaver,
        ),
        0,
      );
    });

    test('balanced reduces motion scale', () {
      expect(
        PremiumAnimationPolicy.motionScaleForMode(
          PremiumPerformanceMode.balanced,
        ),
        0.65,
      );
    });

    testWidgets('batterySaver disables continuous motion', (tester) async {
      await tester.pumpWidget(
        _wrap(const SizedBox(), mode: PremiumPerformanceMode.batterySaver),
      );
      expect(
        PremiumAnimationPolicy.continuousMotionEnabled(tester.element(find.byType(SizedBox))),
        isFalse,
      );
      expect(
        PremiumAnimationPolicy.motionScale(tester.element(find.byType(SizedBox))),
        0,
      );
    });

    testWidgets('balanced reduces blur', (tester) async {
      await tester.pumpWidget(
        _wrap(const SizedBox(), mode: PremiumPerformanceMode.balanced),
      );
      final ctx = tester.element(find.byType(SizedBox));
      expect(PremiumAnimationPolicy.effectiveBlur(ctx, 18), lessThan(18));
    });

    testWidgets('batterySaver skips backdrop blur', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const PremiumGlassPanel(child: Text('glass')),
          mode: PremiumPerformanceMode.batterySaver,
        ),
      );
      expect(find.byType(PremiumGlassPanel), findsOneWidget);
      expect(
        PremiumAnimationPolicy.useBackdropBlur(
          tester.element(find.byType(PremiumGlassPanel)),
          18,
        ),
        isFalse,
      );
    });
  });

  group('Performance mode UI', () {
    testWidgets('tile renders three modes', (tester) async {
      await tester.pumpWidget(_wrap(const PremiumPerformanceModeTile()));
      expect(find.text(kPremiumPerformanceModeFull), findsOneWidget);
      expect(find.text(kPremiumPerformanceModeBalanced), findsOneWidget);
      expect(find.text(kPremiumPerformanceModeBattery), findsOneWidget);
    });
  });

  group('Mission Control smoke batterySaver', () {
    testWidgets('layout renders in batterySaver', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MissionControlLayout(
            overview: DashboardOverview.empty,
            serverIp: '127.0.0.1',
            onLiveTap: () {},
            onPhotoTap: () {},
            onMarineTap: () {},
            onCompareTap: () {},
            onCaptainAtlasTap: () {},
            onRefresh: () {},
          ),
          mode: PremiumPerformanceMode.batterySaver,
        ),
      );
      expect(find.text(kMissionControlTitle), findsOneWidget);
      expect(find.text(kPremiumPerformanceModeTitle), findsOneWidget);
    });

    testWidgets('quick action dock semantics', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MissionQuickActionDock(
            onMapTap: () {},
            onMarineTap: () {},
            onLiveTap: () {},
            onCompareTap: () {},
            onCaptainTap: () {},
          ),
          mode: PremiumPerformanceMode.batterySaver,
        ),
      );
      expect(find.text(kMissionDockCaptain), findsOneWidget);
      expect(find.byKey(const Key('btn_live_area')), findsOneWidget);
    });
  });

  group('Premium dashboard smoke batterySaver', () {
    testWidgets('dashboard skeleton then content', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: PremiumPerformanceScope(
            mode: PremiumPerformanceMode.batterySaver,
            onModeChanged: (_) {},
            child: PremiumDashboardScreen(
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
      );
      await tester.pumpAndSettle();
      expect(find.text(kMissionControlTitle), findsNothing);
      expect(find.text(kPremiumDashLiveScoreTitle), findsOneWidget);
    });
  });

  group('Error fallback', () {
    testWidgets('PremiumErrorFallback shows retry', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        _wrap(
          PremiumErrorFallback(
            title: kPremiumSectionErrorTitle,
            message: 'test hata',
            onRetry: () => retried = true,
          ),
        ),
      );
      expect(find.text(kPremiumSectionErrorTitle), findsOneWidget);
      await tester.tap(find.text(kPremiumDashRefresh));
      await tester.pump();
      expect(retried, isTrue);
    });

    testWidgets('PremiumErrorBoundary catches sync build error', (tester) async {
      await tester.pumpWidget(
        _wrap(
          PremiumErrorBoundary(
            sectionTitle: kPremiumSectionErrorTitle,
            builder: (context) {
              throw StateError('boom');
            },
          ),
        ),
      );
      expect(find.text(kPremiumSectionErrorTitle), findsOneWidget);
      expect(find.textContaining('boom'), findsOneWidget);
    });
  });

  group('Accessibility semantics', () {
    testWidgets('Go Score semantics on PremiumHeroGoScore', (tester) async {
      await tester.pumpWidget(
        _wrap(const PremiumHeroGoScore(score: 72, fontSize: 36)),
      );
      final semantics = tester.getSemantics(find.text('72'));
      expect(semantics.label, contains('Go Score'));
      expect(semantics.label, contains('72'));
    });
  });
}
