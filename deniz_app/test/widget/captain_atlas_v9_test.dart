import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/map/widgets/captain/ai_assistant_premium_header.dart';
import 'package:deniz_app/navigation/captain_atlas_launcher.dart';
import 'package:deniz_app/screens/captain_atlas_screen.dart';
import 'package:deniz_app/services/ai_assistant_sheet_controller.dart';
import 'package:deniz_app/utils/premium_haptics.dart';
import 'package:deniz_app/widgets/premium/feedback/premium_dialog.dart';
import 'package:deniz_app/widgets/premium/feedback/premium_toast.dart';
import 'package:deniz_app/widgets/premium/premium_animation_policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  testWidgets('CaptainAtlasLauncher no context modal', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () => CaptainAtlasLauncher.showNoContext(ctx),
                child: const Text('Bağlam yok'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Bağlam yok'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text(kCaptainAtlasNoContextTitle), findsOneWidget);
    expect(find.text(kCaptainAtlasNoContextMessage), findsOneWidget);
  });

  testWidgets('CaptainAtlasScreen smoke test', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CaptainAtlasScreen(serverIp: '127.0.0.1'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text(kCaptainAtlasScreenTitle), findsWidgets);
    expect(find.text(kCaptainAtlasQuickQuestions), findsOneWidget);
  });

  testWidgets('Quick question button render test', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CaptainAtlasScreen(serverIp: '127.0.0.1'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text(kCaptainAtlasQuickWhere), findsOneWidget);
    expect(find.text(kCaptainAtlasQuickRisk), findsOneWidget);
  });

  testWidgets('AiAssistantSheet polished header render test', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiAssistantPremiumHeader(
            title: kAiAssistantTitle,
            phase: AiSheetPhase.ready,
            assistantName: kCaptainAtlasChip,
            onRefresh: () {},
            onCancel: () {},
          ),
        ),
      ),
    );
    expect(find.text(kAiAssistantTitle), findsOneWidget);
    expect(find.text(kCaptainAtlasChip), findsOneWidget);
    expect(find.text(kPremiumCaptainReady), findsOneWidget);
  });

  testWidgets('PremiumToast migration smoke', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () => PremiumToast.success(ctx, 'Başarılı'),
                child: const Text('Toast'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Toast'));
    await tester.pump();
    expect(find.text('Başarılı'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('PremiumDialog migration smoke', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () => PremiumDialog.showAlert(
                  ctx,
                  title: kMarineCatchDeleteConfirmTitle,
                  message: kMarineCatchDeleteConfirmMessage,
                ),
                child: const Text('Dialog'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Dialog'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text(kMarineCatchDeleteConfirmTitle), findsOneWidget);
  });

  testWidgets('PremiumHaptics helper no crash test', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  PremiumHaptics.light();
                  PremiumHaptics.medium();
                  PremiumHaptics.success();
                  PremiumHaptics.warning();
                  PremiumHaptics.error();
                  PremiumHaptics.selection();
                },
                child: const Text('Haptics'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Haptics'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reduce motion policy test', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              expect(PremiumAnimationPolicy.reduceMotion(context), isTrue);
              expect(PremiumAnimationPolicy.motionScale(context), 0);
              expect(
                PremiumAnimationPolicy.continuousMotionEnabled(context),
                isFalse,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  });
}
