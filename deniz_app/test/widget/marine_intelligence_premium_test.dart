import 'package:deniz_app/domain/marine_intelligence_report.dart';
import 'package:deniz_app/domain/marine_saved_spot.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/map/widgets/marine/intelligence/captain_atlas_comment_card.dart';
import 'package:deniz_app/map/widgets/marine/intelligence/coordinate_input_panel.dart';
import 'package:deniz_app/map/widgets/marine/intelligence/marine_conditions_grid.dart';
import 'package:deniz_app/map/widgets/marine/intelligence/marine_decision_overview_card.dart';
import 'package:deniz_app/map/widgets/marine/intelligence/marine_explainability_card.dart';
import 'package:deniz_app/map/widgets/marine/intelligence/marine_scenario_card.dart';
import 'package:deniz_app/map/widgets/marine/intelligence/marine_timeline_premium_card.dart';
import 'package:deniz_app/map/widgets/marine/intelligence/saved_spots_premium_panel.dart';
import 'package:deniz_app/map/widgets/marine/marine_saved_spots_panel.dart';
import 'package:deniz_app/screens/marine_intelligence_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

MarineIntelligenceReport _sampleReport() {
  return MarineIntelligenceReport.fromJson({
    'coordinate': {'lat': 37.0, 'lon': 27.0},
    'weather': {
      'temperature_c': {'final_value': 22.0, 'confidence': 0.6, 'source_count': 1},
    },
    'wind': {
      'speed_kmh': {'final_value': 12.0, 'confidence': 0.6, 'source_count': 1},
    },
    'marine': {
      'wave_height_m': {'final_value': 0.6, 'confidence': 0.6, 'source_count': 1},
      'swell_height_m': {'final_value': 0.4, 'confidence': 0.6, 'source_count': 1},
    },
    'astronomy': {'moon_phase': 'Ilk Hilal'},
    'fishing_score': {
      'suitability_score': 75,
      'risk_score': 20,
      'general_advice_tr': 'Test',
      'confidence': 0.6,
    },
    'consensus_summary': {'overall_confidence': 0.6, 'provider_count': 1},
    'explainability': {
      'positive_factors': ['Olumlu'],
      'negative_factors': ['Dikkat'],
      'uncertainty_factors': ['Belirsiz'],
      'explanation_summary_tr': 'Özet',
    },
    'updated_at': '2024-06-15T06:00:00+00:00',
  });
}

MarineIntelligenceReport _reportWithDecision() {
  return MarineIntelligenceReport.fromJson({
    'coordinate': {'lat': 37.0, 'lon': 27.0},
    'weather': {},
    'wind': {},
    'marine': {},
    'astronomy': {},
    'fishing_score': {
      'suitability_score': 75,
      'risk_score': 20,
      'confidence': 0.6,
    },
    'consensus_summary': {'overall_confidence': 0.6},
    'decision': {
      'fishing_decision': 'good',
      'go_score': 72,
      'wait_score': 28,
      'best_action_tr': 'Denize çıkmak mümkün görünüyor.',
      'short_summary_tr': 'Koşullar uygun görünüyor.',
    },
    'decision_timeline': [
      {
        'time': '06:00',
        'go_score': 80,
        'risk_score': 15,
        'decision': 'good',
        'reason_tr': 'Sabah saatlerinde rüzgar daha uygun görünüyor.',
        'is_best_slot': true,
      },
      {
        'time': '09:00',
        'go_score': 75,
        'risk_score': 18,
        'decision': 'good',
        'reason_tr': 'Sabah geç saatlerinde koşullar kabul edilebilir.',
      },
    ],
    'updated_at': '2024-06-15T06:00:00+00:00',
  });
}

MarineSavedSpot _spotWithDecision() {
  return MarineSavedSpot.fromJson({
    'id': 'spot-1',
    'name': 'Test Spot',
    'lat': 37.0,
    'lon': 27.0,
    'created_at': '2024-01-01T00:00:00Z',
    'updated_at': '2024-01-01T00:00:00Z',
    'last_report': {
      'coordinate': {'lat': 37.0, 'lon': 27.0},
      'weather': {},
      'wind': {},
      'marine': {},
      'astronomy': {},
      'fishing_score': {'suitability_score': 70, 'risk_score': 25},
      'consensus_summary': {},
      'decision': {
        'fishing_decision': 'borderline',
        'go_score': 55,
        'wait_score': 45,
      },
    },
  });
}

void main() {
  testWidgets('MarineIntelligenceScreen premium smoke', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MarineIntelligenceScreen(serverIp: '127.0.0.1'),
      ),
    );
    await tester.pump();
    expect(find.text(kMarineScreenTitle), findsWidgets);
    expect(find.text(kMarinePremiumCoordinateTitle), findsOneWidget);
    expect(find.text(kMarineAnalyzeButton), findsOneWidget);
    expect(find.text(kMarineDecisionEmptyTitle), findsOneWidget);
  });

  testWidgets('Coordinate input panel render', (tester) async {
    final lat = TextEditingController(text: '36.62');
    final lon = TextEditingController(text: '29.11');
    addTearDown(lat.dispose);
    addTearDown(lon.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CoordinateInputPanel(
            latController: lat,
            lonController: lon,
            onAnalyze: () {},
            onPickFromMap: () {},
            onCompare: () {},
          ),
        ),
      ),
    );
    expect(find.text(kLabelLatitude), findsOneWidget);
    expect(find.text(kLabelLongitude), findsOneWidget);
    expect(find.text(kMarineCompareOpenFromAnalysis), findsOneWidget);
  });

  testWidgets('Decision overview empty state', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MarineDecisionOverviewCard(),
        ),
      ),
    );
    expect(find.text(kMarineDecisionEmptyTitle), findsOneWidget);
  });

  testWidgets('Decision overview with report', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarineDecisionOverviewCard(report: _reportWithDecision()),
        ),
      ),
    );
    expect(find.text(kMarineSectionDecision), findsOneWidget);
    expect(find.text(kMarineDecisionGood), findsOneWidget);
    expect(find.textContaining('Denize çıkmak'), findsOneWidget);
  });

  testWidgets('Timeline premium render', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarineTimelinePremiumCard(
            items: _reportWithDecision().decisionTimeline,
          ),
        ),
      ),
    );
    expect(find.text(kMarineSectionDecisionTimeline), findsOneWidget);
    expect(find.text('06:00'), findsOneWidget);
    expect(find.text(kMarineTimelineBestSlot), findsOneWidget);
  });

  testWidgets('Conditions grid render', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarineConditionsGrid(report: _sampleReport()),
        ),
      ),
    );
    expect(find.text(kMarinePremiumConditionsTitle), findsOneWidget);
    expect(find.text(kMarineSectionWeather), findsOneWidget);
    expect(find.text(kMarineSectionWind), findsOneWidget);
  });

  testWidgets('Captain Atlas card render', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CaptainAtlasCommentCard(
            comment: const MarineAiComment(
              source: 'ai',
              summaryTr: 'Bugün av için koşullar uygun.',
              bestTimeWindowTr: 'Saat 08:00',
            ),
            onAskCaptain: () {},
          ),
        ),
      ),
    );
    expect(find.text(kMarineCaptainAtlasChip), findsOneWidget);
    expect(find.text(kMarineFetchAiCommentButton), findsOneWidget);
    expect(find.textContaining('uygun'), findsOneWidget);
  });

  testWidgets('Explainability card render', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarineExplainabilityCard(
            explain: _sampleReport().explainability!,
          ),
        ),
      ),
    );
    expect(find.text(kMarineSectionExplain), findsOneWidget);
    expect(find.text(kMarineExplainPositive), findsOneWidget);
    expect(find.text('Olumlu'), findsOneWidget);
  });

  testWidgets('Scenario card render', (tester) async {
    final report = MarineIntelligenceReport.fromJson({
      'coordinate': {'lat': 37.0, 'lon': 27.0},
      'weather': {},
      'wind': {},
      'marine': {},
      'astronomy': {},
      'fishing_score': {'suitability_score': 75, 'risk_score': 20},
      'consensus_summary': {},
      'scenario': {
        'items': [
          {
            'scenario_id': 'wind_plus_5',
            'title_tr': 'Rüzgar 5 km/h artsa?',
            'delta_go_score': -12,
            'delta_risk_score': 8,
            'decision': 'borderline',
          },
        ],
      },
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarineScenarioCard(scenario: report.scenario!),
        ),
      ),
    );
    expect(find.text(kMarineSectionScenario), findsOneWidget);
    expect(find.text('Rüzgar 5 km/h artsa?'), findsOneWidget);
  });

  testWidgets('Saved spots premium panel render', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SavedSpotsPremiumPanel(
            spots: [_spotWithDecision()],
            onRefresh: (_) async {},
            onDelete: (_) async {},
            onToggleFavorite: (_) async {},
            onAddCatch: (_) async {},
            onShowCatches: (_) async {},
          ),
        ),
      ),
    );
    expect(find.text(kMarineSavedSpotsTitle), findsOneWidget);
    expect(find.text(kMarineAddCatchButton), findsOneWidget);
  });

  testWidgets('Compare selection regression in saved spots', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarineSavedSpotsPanel(
            spots: [
              _spotWithDecision(),
              MarineSavedSpot.fromJson({
                'id': 'spot-2',
                'name': 'Spot B',
                'lat': 37.1,
                'lon': 27.1,
                'created_at': '2024-01-01T00:00:00Z',
                'updated_at': '2024-01-01T00:00:00Z',
              }),
            ],
            onRefresh: (_) async {},
            onDelete: (_) async {},
            onToggleFavorite: (_) async {},
            onAddCatch: (_) async {},
            onShowCatches: (_) async {},
            onCompareSpots: (left, right) {},
          ),
        ),
      ),
    );
    await tester.tap(find.text(kMarineCompareSelectMode));
    await tester.pumpAndSettle();
    expect(find.text(kMarineCompareSelectHint), findsOneWidget);
  });
}
