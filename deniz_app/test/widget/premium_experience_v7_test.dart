import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/map/widgets/premium/map_command_bar.dart';
import 'package:deniz_app/theme/app_motion.dart';
import 'package:deniz_app/widgets/premium/ambient/ambient_marine_background.dart';
import 'package:deniz_app/widgets/premium/captain_atlas_hero_card.dart';
import 'package:deniz_app/widgets/premium/map_vignette_overlay.dart';
import 'package:deniz_app/widgets/premium/motion/premium_micro_interaction.dart';
import 'package:deniz_app/widgets/premium/premium_card.dart';
import 'package:deniz_app/widgets/premium/premium_glass_panel.dart';
import 'package:deniz_app/widgets/premium/premium_live_glow.dart';
import 'package:deniz_app/widgets/premium/premium_loading_skeleton.dart';
import 'package:deniz_app/widgets/premium/premium_empty_state.dart';
import 'package:deniz_app/widgets/premium/premium_page_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AmbientMarineBackground render', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AmbientMarineBackground(
          child: SizedBox(width: 200, height: 200),
        ),
      ),
    );
    expect(find.byType(AmbientMarineBackground), findsOneWidget);
  });

  testWidgets('PremiumGlassPanel V2 render', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PremiumGlassPanel(child: Text('Glass')),
        ),
      ),
    );
    expect(find.text('Glass'), findsOneWidget);
  });

  testWidgets('PremiumCard micro interaction tap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PremiumCard(
            onTap: () => tapped = true,
            child: const Text('Kart'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Kart'));
    expect(tapped, isTrue);
  });

  testWidgets('PremiumLiveGlow render', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PremiumLiveGlow(
            child: Container(width: 40, height: 40, color: Colors.blue),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(PremiumLiveGlow), findsOneWidget);
  });

  testWidgets('PremiumLoadingSkeleton shimmer', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PremiumLoadingSkeleton(height: 40)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(PremiumLoadingSkeleton), findsOneWidget);
  });

  testWidgets('CaptainAtlasHeroCard ready state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CaptainAtlasHeroCard(
            title: kPremiumCaptainCardTitle,
            body: kPremiumCaptainCardMessage,
            actionLabel: kPremiumCaptainAskButton,
            onAsk: () {},
          ),
        ),
      ),
    );
    expect(find.text(kPremiumCaptainCardTitle), findsOneWidget);
    expect(find.text(kPremiumCaptainReady), findsOneWidget);
  });

  testWidgets('CaptainAtlasHeroCard thinking state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CaptainAtlasHeroCard(
            title: kPremiumCaptainCardTitle,
            body: 'Test',
            presence: CaptainAtlasPresence.thinking,
            loading: true,
          ),
        ),
      ),
    );
    expect(find.text(kPremiumCaptainThinking), findsOneWidget);
  });

  testWidgets('MapCommandBar dock V2 render', (tester) async {
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
    expect(find.text(kMapPremiumCommandCaptain), findsOneWidget);
  });

  testWidgets('MapVignetteOverlay render', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MapVignetteOverlay()),
      ),
    );
    expect(find.byType(MapVignetteOverlay), findsOneWidget);
  });

  testWidgets('PremiumEmptyState animated render', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PremiumEmptyState(
            title: 'Boş',
            subtitle: 'Veri yok',
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('Boş'), findsOneWidget);
  });

  testWidgets('PremiumMicroInteraction tap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PremiumMicroInteraction(
            onTap: () => tapped = true,
            child: const Text('Micro'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Micro'));
    expect(tapped, isTrue);
  });

  test('AppMotion tokens defined', () {
    expect(AppMotion.microPress.inMilliseconds, 16);
    expect(AppMotion.pageTransition.inMilliseconds, 380);
  });

  testWidgets('PremiumFadePageRoute smoke', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) => PremiumFadePageRoute(
          page: const Scaffold(body: Text('Hedef')),
        ),
        initialRoute: '/',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hedef'), findsOneWidget);
  });
}
