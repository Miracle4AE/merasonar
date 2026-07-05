import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:deniz_app/home_screen.dart';
import 'package:deniz_app/live_area_screen.dart';
import 'package:deniz_app/main.dart';
import 'package:deniz_app/map_screen.dart';
import 'package:deniz_app/services/app_preferences.dart';

Future<void> _pumpHomeScreen(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({
    AppPreferences.keyOnboardingV1: true,
  });
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(size: Size(390, 844)),
      child: const DenizApp(
        splashDuration: Duration(milliseconds: 1),
      ),
    ),
  );
  for (var i = 0; i < 60; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (find.byType(HomeScreen).evaluate().isNotEmpty) break;
  }
  expect(find.byType(HomeScreen), findsOneWidget);
  for (var i = 0; i < 60; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (find.byKey(const Key('btn_live_area')).evaluate().isNotEmpty) {
      break;
    }
  }
}

Future<void> _tapHomeAction(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

void main() {
  testWidgets(
    'Onboarding atlanmışsa Splash → Home; Photo Analysis → MapScreen',
    (tester) async {
      await _pumpHomeScreen(tester);
      await _tapHomeAction(tester, const Key('btn_photo_analysis'));
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (find.byType(MapScreen).evaluate().isNotEmpty) break;
      }
      expect(find.byType(MapScreen), findsOneWidget);
    },
  );

  testWidgets(
    'Splash → Home; Live Area → LiveAreaScreen',
    (tester) async {
      await _pumpHomeScreen(tester);
      await _tapHomeAction(tester, const Key('btn_live_area'));
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (find.byType(LiveAreaScreen).evaluate().isNotEmpty) break;
      }
      expect(find.byType(LiveAreaScreen), findsOneWidget);
    },
  );
}
