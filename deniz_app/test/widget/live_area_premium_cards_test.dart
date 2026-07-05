import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/map/widgets/live_area/captain_atlas_live_card.dart';
import 'package:deniz_app/map/widgets/live_area/gps_status_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('GpsStatusCard render test', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GpsStatusCard(
            latitude: 41.0082,
            longitude: 28.9784,
            accuracyM: 8,
            lastFixLabel: '2026-07-03',
          ),
        ),
      ),
    );
    expect(find.textContaining(kLiveGpsTrustReliable), findsOneWidget);
    expect(find.textContaining('41.008200'), findsOneWidget);
  });

  testWidgets('CaptainAtlasLiveCard button render test', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CaptainAtlasLiveCard(
            enabled: true,
            onAsk: () {},
            lastSummary: 'Kısa özet',
          ),
        ),
      ),
    );
    expect(find.text(kAiAssistantLiveTitle), findsOneWidget);
    expect(find.text(kPremiumCaptainAskButton), findsOneWidget);
    expect(find.text('Kısa özet'), findsOneWidget);
  });
}
