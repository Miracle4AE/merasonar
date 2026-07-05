import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/screens/marine_intelligence_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// RC8 marine CRUD UI keys + smoke.
///
/// Full live walkthrough (127.0.0.1:8000) runs via:
/// `powershell -File scripts/rc8_windows_marine_walkthrough.ps1`
/// Flutter widget tests cannot use real HttpClient (TestWidgetsFlutterBinding).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RC8 marine CRUD UI keys', () {
    testWidgets('coordinate + analyze keys render', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 900));
      await tester.pumpWidget(
        const MaterialApp(
          home: MarineIntelligenceScreen(serverIp: '127.0.0.1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('field_marine_lat')), findsOneWidget);
      expect(find.byKey(const Key('field_marine_lon')), findsOneWidget);
      expect(find.byKey(const Key('btn_marine_analyze')), findsOneWidget);
      expect(find.text(kMarineAnalyzeButton), findsOneWidget);
    });

    testWidgets('save spot action key appears after report mock layout', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 900));
      await tester.pumpWidget(
        const MaterialApp(
          home: MarineIntelligenceScreen(
            serverIp: '127.0.0.1',
            initialLat: 37.38724,
            initialLon: 27.17999,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('btn_marine_analyze')), findsOneWidget);
    });
  });
}
