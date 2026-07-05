import 'package:deniz_app/home_screen.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _waitForDashboardActions(WidgetTester tester) async {
  for (var i = 0; i < 60; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (find.byKey(const Key('btn_live_area')).evaluate().isNotEmpty) {
      return;
    }
  }
}

void main() {
  testWidgets('Home screen shows Live Area and Photo Analysis buttons',
      (tester) async {
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
    await _waitForDashboardActions(tester);
    expect(find.byKey(const Key('btn_live_area')), findsOneWidget);
    expect(find.byKey(const Key('btn_photo_analysis')), findsOneWidget);
    expect(find.byKey(const Key('btn_marine_analysis')), findsOneWidget);
    expect(find.text(kMissionControlTitle), findsNothing);
    expect(find.text(kPremiumDashLiveScoreTitle), findsOneWidget);
    expect(find.text(kMissionDockLive), findsOneWidget);
    expect(find.text(kMissionDockMap), findsOneWidget);
    expect(find.text(kMissionDockMarine), findsOneWidget);
  });
}
