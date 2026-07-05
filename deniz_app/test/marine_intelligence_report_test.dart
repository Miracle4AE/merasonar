import 'package:deniz_app/domain/marine_intelligence_report.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MarineDecision parses decision payload', () {
    final decision = MarineDecision.fromJson({
      'fishing_decision': 'good',
      'go_score': 72,
      'wait_score': 28,
      'best_action_tr': 'Denize çıkın',
      'decision_reason_codes': ['low_wind', 'moderate_wave'],
      'short_summary_tr': 'Koşullar uygun görünüyor',
    });
    expect(decision.fishingDecision, 'good');
    expect(decision.goScore, 72);
    expect(decision.decisionReasonCodes, contains('low_wind'));
  });

  test('MarineDecisionTimelineItem parses timeline', () {
    final item = MarineDecisionTimelineItem.fromJson({
      'time': '06:00',
      'go_score': 78,
      'risk_score': 25,
      'decision': 'good',
      'reason_tr': 'Sabah saatlerinde rüzgar daha uygun görünüyor.',
    });
    expect(item.time, '06:00');
    expect(item.goScore, 78);
    expect(item.decision, 'good');
  });

  test('MarineIntelligenceReport parses decision and timeline', () {
    final report = MarineIntelligenceReport.fromJson({
      'coordinate': {'lat': 37.0, 'lon': 27.0},
      'weather': {},
      'wind': {},
      'marine': {},
      'astronomy': {},
      'fishing_score': {'suitability_score': 75, 'risk_score': 20, 'confidence': 0.6},
      'consensus_summary': {'overall_confidence': 0.6},
      'decision': {
        'fishing_decision': 'good',
        'go_score': 70,
        'wait_score': 30,
        'best_action_tr': 'Test',
        'decision_reason_codes': [],
        'short_summary_tr': 'Özet',
      },
      'decision_timeline': [
        {
          'time': '06:00',
          'go_score': 78,
          'risk_score': 20,
          'decision': 'good',
          'reason_tr': 'Sabah',
        },
      ],
    });
    expect(report.decision?.fishingDecision, 'good');
    expect(report.decisionTimeline.length, 1);
    expect(report.decisionTimeline.first.time, '06:00');
  });

  test('MarineAiComment parses assistantName default', () {
    final comment = MarineAiComment.fromJson({
      'source': 'ai',
      'summary_tr': 'Test',
    });
    expect(comment.assistantName, 'Captain Atlas');
    expect(comment.personaVersion, 'captain_atlas_v1');
    expect(comment.tone, 'calm_expert');
  });

  test('MarineAiComment parses ai_comment payload', () {
    final comment = MarineAiComment.fromJson({
      'source': 'ai',
      'summary_tr': 'Koordinat bugün av için uygun görünüyor.',
      'best_time_window_tr': 'Saat 08:00 UTC civarı.',
      'risk_note_tr': 'Dalga artışı izlenmeli.',
      'recommended_actions': [
        {'title_tr': 'Sabah çık', 'detail_tr': 'Rüzgar daha düşük.'},
      ],
      'cache_hit': false,
      'fallback_reason': null,
    });
    expect(comment.source, 'ai');
    expect(comment.summaryTr, contains('uygun'));
    expect(comment.bestTimeWindowTr, isNotNull);
    expect(comment.recommendedActions.length, 1);
    expect(comment.isFallback, isFalse);
  });

  test('MarineDecisionTimelineItem parses is_best_slot', () {
    final item = MarineDecisionTimelineItem.fromJson({
      'time': '08:00',
      'go_score': 82,
      'is_best_slot': true,
    });
    expect(item.isBestSlot, isTrue);
  });

  test('MarineIntelligenceReport parses ai_comment', () {
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
        'summary_tr': 'Yedek özet',
        'fallback_reason': 'quota_exceeded',
      },
    });
    expect(report.aiComment?.source, 'fallback');
    expect(report.aiComment?.summaryTr, 'Yedek özet');
    expect(report.aiComment?.isFallback, isTrue);
  });

  test('MarineIntelligenceReport parses sample payload', () {
    final report = MarineIntelligenceReport.fromJson({
      'coordinate': {'lat': 37.0, 'lon': 27.0},
      'weather': {
        'temperature_c': {'final_value': 22.0, 'confidence': 0.6, 'source_count': 1},
      },
      'wind': {
        'speed_kmh': {'final_value': 12.0, 'confidence': 0.6, 'source_count': 1},
      },
      'marine': {
        'wave_height_m': {'final_value': 0.6, 'confidence': 0.6, 'source_count': 1},
      },
      'astronomy': {'moon_phase': 'Ilk Hilal', 'moon_illumination_pct': 40},
      'fishing_score': {
        'suitability_score': 75,
        'risk_score': 20,
        'general_advice_tr': 'Test',
        'confidence': 0.6,
      },
      'consensus_summary': {'overall_confidence': 0.6, 'provider_count': 1},
      'updated_at': '2024-06-15T06:00:00+00:00',
      'cache_hit': false,
      'partial_data': false,
      'tide': null,
      'decision': null,
      'explainability': {
        'positive_factors': ['Olumlu'],
        'negative_factors': [],
        'uncertainty_factors': [],
        'explanation_summary_tr': 'Özet',
      },
    });
    expect(report.coordinate.lat, 37.0);
    expect(report.weather.temperatureC?.finalValue, 22.0);
    expect(report.fishingScore.suitabilityScore, 75);
    expect(report.explainability?.positiveFactors.first, 'Olumlu');
    expect(report.tide, isNull);
  });

  test('MarineScenarioBundle parses scenario payload', () {
    final bundle = MarineScenarioBundle.fromJson({
      'base_go_score': 76,
      'items': [
        {
          'scenario_id': 'wind_plus_5',
          'title_tr': 'Rüzgar 5 km/h artsa?',
          'changed_inputs': {'wind_speed_kmh': '+5'},
          'resulting_go_score': 64,
          'resulting_risk_score': 38,
          'decision': 'borderline',
          'delta_go_score': -12,
          'delta_risk_score': 8,
          'delta_summary_tr': 'Rüzgar artışı kararı sınırda seviyesine çekebilir.',
        },
      ],
    });
    expect(bundle.baseGoScore, 76);
    expect(bundle.items.first.deltaGoScore, -12);
    expect(bundle.items.first.changedInputs['wind_speed_kmh'], '+5');
    expect(bundle.mostSensitiveFactorLabel, 'Rüzgar');
  });
}
