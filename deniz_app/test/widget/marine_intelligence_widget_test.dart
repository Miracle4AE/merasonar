import 'package:deniz_app/domain/marine_catch_record.dart';
import 'package:deniz_app/domain/marine_intelligence_report.dart';
import 'package:deniz_app/domain/marine_learning_summary.dart';
import 'package:deniz_app/domain/marine_saved_spot.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/map/widgets/marine/marine_catch_dialog.dart';
import 'package:deniz_app/map/widgets/marine/marine_forecast_timeline.dart';
import 'package:deniz_app/map/widgets/marine/marine_report_cards.dart';
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
      'negative_factors': [],
      'uncertainty_factors': [],
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

MarineIntelligenceReport _reportWithScenario() {
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
      'best_action_tr': 'Test',
      'short_summary_tr': 'Özet',
    },
    'scenario': {
      'base_go_score': 72,
      'items': [
        {
          'scenario_id': 'wind_plus_5',
          'title_tr': 'Rüzgar 5 km/h artsa?',
          'delta_go_score': -12,
          'delta_risk_score': 8,
          'decision': 'borderline',
          'delta_summary_tr': 'Sınırda seviyesine düşebilir.',
        },
      ],
    },
    'decision_timeline': List.generate(
      6,
      (i) => {
        'time': '${(6 + i * 2).toString().padLeft(2, '0')}:00',
        'go_score': 70 + i,
        'risk_score': 20 + i,
        'decision': 'good',
        'reason_tr': 'Saat $i',
        'is_best_slot': i == 5,
      },
    ),
    'updated_at': '2024-06-15T06:00:00+00:00',
  });
}

MarineSavedSpot _spotWithScenario() {
  return MarineSavedSpot.fromJson({
    'id': 'spot-2',
    'name': 'Scenario Spot',
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
      'decision': {'fishing_decision': 'good', 'go_score': 70},
      'scenario': {
        'base_go_score': 70,
        'items': [
          {
            'scenario_id': 'gust_plus_10',
            'title_tr': 'Ani rüzgar 10 km/h artsa?',
            'delta_go_score': -15,
            'delta_risk_score': 12,
            'decision': 'borderline',
          },
        ],
      },
    },
  });
}

void main() {
  testWidgets('MarineIntelligenceScreen smoke', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MarineIntelligenceScreen(serverIp: '127.0.0.1'),
      ),
    );
    await tester.pump();
    expect(find.text(kMarineScreenTitle), findsWidgets);
    expect(find.text(kMarineAnalyzeButton), findsOneWidget);
  });

  testWidgets('MarineReportCards conditional render', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MarineReportCards(report: _sampleReport()),
          ),
        ),
      ),
    );
    expect(find.text(kMarineSectionWeather), findsOneWidget);
    expect(find.text(kMarineSectionExplain), findsOneWidget);
  });

  testWidgets('MarineReportCards decision card render', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MarineReportCards(report: _reportWithDecision()),
          ),
        ),
      ),
    );
    expect(find.text(kMarineSectionDecision), findsOneWidget);
    expect(find.text(kMarineDecisionGood), findsWidgets);
    expect(find.text(kMarineSectionDecisionTimeline), findsOneWidget);
    expect(find.text('06:00'), findsOneWidget);
  });

  testWidgets('MarineReportCards scenario card render', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MarineReportCards(report: _reportWithScenario()),
          ),
        ),
      ),
    );
    expect(find.text(kMarineSectionScenario), findsOneWidget);
    expect(find.text('Rüzgar 5 km/h artsa?'), findsOneWidget);
    expect(find.textContaining('Go Score: -12'), findsOneWidget);
    expect(find.textContaining('Risk: +8'), findsOneWidget);
    expect(find.text(kMarineDecisionBorderline), findsWidgets);
  });

  testWidgets('MarineReportCards Captain Atlas card title render', (tester) async {
    final report = MarineIntelligenceReport.fromJson({
      'coordinate': {'lat': 37.0, 'lon': 27.0},
      'weather': {},
      'wind': {},
      'marine': {},
      'astronomy': {},
      'fishing_score': {'suitability_score': 75, 'risk_score': 20, 'confidence': 0.6},
      'consensus_summary': {'overall_confidence': 0.6},
      'ai_comment': {
        'source': 'ai',
        'summary_tr': 'Bugün av için koşullar uygun görünüyor.',
        'best_time_window_tr': 'Saat 08:00 UTC civarı.',
        'risk_note_tr': 'Ani rüzgar artışına dikkat.',
        'recommended_actions': [
          {'title_tr': 'Erken çık', 'detail_tr': 'Sabah penceresi daha sakin.'},
        ],
      },
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MarineReportCards(report: report),
          ),
        ),
      ),
    );
    expect(find.text(kMarineSectionAiComment), findsOneWidget);
    expect(find.text(kMarineCaptainAtlasChip), findsOneWidget);
    expect(find.textContaining('uygun görünüyor'), findsOneWidget);
    expect(find.textContaining('Saat 08:00'), findsOneWidget);
  });

  testWidgets('MarineReportCards AI fallback banner render', (tester) async {
    final report = MarineIntelligenceReport.fromJson({
      'coordinate': {'lat': 37.0, 'lon': 27.0},
      'weather': {},
      'wind': {},
      'marine': {},
      'astronomy': {},
      'fishing_score': {'suitability_score': 75, 'risk_score': 20, 'confidence': 0.6},
      'consensus_summary': {'overall_confidence': 0.6},
      'ai_comment': {
        'source': 'fallback',
        'summary_tr': 'Kural tabanlı özet',
      },
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MarineReportCards(report: report),
          ),
        ),
      ),
    );
    expect(find.text(kMarineAiCommentFallbackBanner), findsOneWidget);
  });

  testWidgets("Captain Atlas'a Sor button text render", (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MarineIntelligenceScreen(serverIp: '127.0.0.1'),
      ),
    );
    await tester.pump();
    expect(find.text(kMarineFetchAiCommentButton), findsNothing);
    expect(find.text(kMarineAnalyzeButton), findsOneWidget);
  });

  testWidgets('MarineForecastTimeline renders six items', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarineForecastTimeline(
            items: _reportWithScenario().decisionTimeline,
          ),
        ),
      ),
    );
    expect(find.text('06:00'), findsOneWidget);
    expect(find.text('16:00'), findsOneWidget);
    expect(find.text(kMarineTimelineBestSlot), findsOneWidget);
  });

  testWidgets('MarineSavedSpotsPanel scenario sensitivity badge', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarineSavedSpotsPanel(
            spots: [_spotWithScenario()],
            onRefresh: (_) async {},
            onDelete: (_) async {},
            onToggleFavorite: (_) async {},
            onAddCatch: (_) async {},
            onShowCatches: (_) async {},
          ),
        ),
      ),
    );
    expect(find.text('$kMarineMostSensitivePrefix Ani rüzgar'), findsOneWidget);
  });

  testWidgets('MarineSavedSpotsPanel last decision badge', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarineSavedSpotsPanel(
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
    expect(
      find.text('$kMarineLastDecisionPrefix $kMarineLastDecisionBorderline'),
      findsOneWidget,
    );
  });

  testWidgets('MarineSavedSpotsPanel empty state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarineSavedSpotsPanel(
            spots: const [],
            onRefresh: (_) async {},
            onDelete: (_) async {},
            onToggleFavorite: (_) async {},
            onAddCatch: (_) async {},
            onShowCatches: (_) async {},
          ),
        ),
      ),
    );
    expect(find.textContaining('kayıtlı nokta'), findsOneWidget);
  });

  testWidgets('MarineSavedSpotsPanel Av Kaydı Ekle button render', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarineSavedSpotsPanel(
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
    expect(find.text(kMarineAddCatchButton), findsOneWidget);
  });

  testWidgets('MarineSavedSpotsPanel learning badge render', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarineSavedSpotsPanel(
            spots: [_spotWithDecision()],
            learningSummaries: const {
              'spot-1': MarineLearningSummary(
                spotId: 'spot-1',
                catchCount: 2,
                topSpecies: 'Levrek',
                spotReputation: 72,
                spotLevel: 'Gold',
                messageTr: 'Test',
              ),
            },
            onRefresh: (_) async {},
            onDelete: (_) async {},
            onToggleFavorite: (_) async {},
            onAddCatch: (_) async {},
            onShowCatches: (_) async {},
          ),
        ),
      ),
    );
    expect(find.textContaining('İtibar 72'), findsOneWidget);
    expect(find.text(kMarineSpotLevelGold), findsOneWidget);
    expect(find.textContaining('Levrek'), findsOneWidget);
  });

  testWidgets('MarineCatchAddDialog smoke test', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => FilledButton(
              onPressed: () => showDialog<void>(
                context: ctx,
                builder: (_) => const MarineCatchAddDialog(),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text(kMarineCatchDialogTitle), findsOneWidget);
    expect(find.text(kMarineCatchSpeciesHint), findsOneWidget);
  });

  testWidgets('MarineCatchAddDialog edit mode smoke test', (tester) async {
    const record = MarineCatchRecord(
      id: 'c1',
      spotId: 's1',
      species: 'Levrek',
      weightKg: 2.1,
      caughtAt: '2026-07-03T06:42:00Z',
      createdAt: 't',
      updatedAt: 't',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => FilledButton(
              onPressed: () => showDialog<void>(
                context: ctx,
                builder: (_) => const MarineCatchAddDialog(initial: record),
              ),
              child: const Text('edit'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('edit'));
    await tester.pumpAndSettle();
    expect(find.text(kMarineCatchEditDialogTitle), findsOneWidget);
    expect(find.text('Levrek'), findsOneWidget);
  });

  testWidgets('MarineSavedSpotsPanel bulk summary render', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarineSavedSpotsPanel(
            spots: [_spotWithDecision(), _spotWithScenario()],
            learningSummaries: {
              'spot-1': const MarineLearningSummary(
                spotId: 'spot-1',
                catchCount: 3,
                topSpecies: 'Levrek',
                spotReputation: 80,
                spotLevel: 'Elite',
                messageTr: 'Test',
              ),
            },
            onRefresh: (_) async {},
            onDelete: (_) async {},
            onToggleFavorite: (_) async {},
            onAddCatch: (_) async {},
            onShowCatches: (_) async {},
          ),
        ),
      ),
    );
    expect(find.textContaining('İtibar 80'), findsOneWidget);
    expect(find.text(kMarineSpotLevelElite), findsOneWidget);
  });
}
