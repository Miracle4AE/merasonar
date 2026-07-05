import 'package:deniz_app/domain/ai_assistant_response.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiAssistantResponse.fromJson', () {
    test('parses full AI response', () {
      final r = AiAssistantResponse.fromJson({
        'source': 'ai',
        'model': 'test-model',
        'cache_hit': true,
        'locale': 'tr',
        'trust_note_tr': 'Feragat metni',
        'prompt_version': 'v1',
        'summary_tr': 'Özet metin',
        'confidence': 'high',
        'recommended_actions': [
          {
            'priority': 1,
            'title_tr': 'Adım 1',
            'detail_tr': 'Detay 1',
          },
        ],
        'hotspot_insights': [
          {
            'hotspot_id': 10,
            'headline_tr': 'Başlık',
            'detail_tr': 'Detay',
          },
        ],
        'conditions_comment_tr': 'Dalga düşük',
        'species_comment_tr': 'Levrek olası',
        'limitations_tr': ['Limit 1'],
        'safety_reminders_tr': ['Güvenlik 1'],
        'processing_ms': 1200,
      });

      expect(r.isAi, isTrue);
      expect(r.cacheHit, isTrue);
      expect(r.summaryTr, 'Özet metin');
      expect(r.confidence, 'high');
      expect(r.recommendedActions, hasLength(1));
      expect(r.hotspotInsights.first.hotspotId, 10);
    });

    test('fallback source with missing optional fields', () {
      final r = AiAssistantResponse.fromJson({
        'source': 'fallback',
        'prompt_version': 'v1',
        'summary_tr': 'Yedek özet',
        'confidence': 'unknown_value',
        'recommended_actions': null,
        'hotspot_insights': 'invalid',
        'conditions_comment_tr': null,
        'species_comment_tr': null,
        'limitations_tr': null,
        'safety_reminders_tr': null,
        'fallback_reason': 'ai_disabled',
      });

      expect(r.isFallback, isTrue);
      expect(r.confidence, 'medium');
      expect(r.recommendedActions, isEmpty);
      expect(r.hotspotInsights, isEmpty);
      expect(r.fallbackReason, 'ai_disabled');
    });

    test('parses assistant persona fields with defaults', () {
      final r = AiAssistantResponse.fromJson({
        'source': 'ai',
        'prompt_version': 'v1',
        'summary_tr': 'Özet',
        'confidence': 'medium',
        'conditions_comment_tr': '',
        'species_comment_tr': '',
      });
      expect(r.assistantName, 'Captain Atlas');
      expect(r.personaVersion, 'captain_atlas_v1');
      expect(r.tone, 'calm_expert');
    });

    test('parses assistant persona fields from telemetry fallback', () {
      final r = AiAssistantResponse.fromJson({
        'source': 'ai',
        'prompt_version': 'v1',
        'summary_tr': 'Özet',
        'confidence': 'medium',
        'conditions_comment_tr': '',
        'species_comment_tr': '',
        'telemetry': {
          'assistant_name': 'Captain Atlas',
          'persona_version': 'captain_atlas_v2',
        },
      });
      expect(r.assistantName, 'Captain Atlas');
      expect(r.personaVersion, 'captain_atlas_v2');
    });

    test('telemetry optional parse', () {
      final r = AiAssistantResponse.fromJson({
        'source': 'ai',
        'prompt_version': 'v1',
        'summary_tr': 'x',
        'confidence': 'low',
        'conditions_comment_tr': '',
        'species_comment_tr': '',
        'telemetry': {
          'input_tokens': 100,
          'output_tokens': 50,
          'estimated_cost_usd': 0.002,
        },
      });
      expect(r.telemetry?.inputTokens, 100);
      expect(r.telemetry?.outputTokens, 50);
      expect(r.telemetry?.estimatedCostUsd, closeTo(0.002, 0.0001));
    });

    test('parses quota and premium fields', () {
      final r = AiAssistantResponse.fromJson({
        'source': 'ai',
        'prompt_version': 'v2',
        'summary_tr': 'x',
        'confidence': 'high',
        'conditions_comment_tr': '',
        'species_comment_tr': '',
        'remaining_ai_requests': 5,
        'is_premium_feature': true,
        'mode': 'live_context',
      });
      expect(r.remainingAiRequests, 5);
      expect(r.isPremiumFeature, isTrue);
      expect(r.mode, 'live_context');
    });
  });
}
