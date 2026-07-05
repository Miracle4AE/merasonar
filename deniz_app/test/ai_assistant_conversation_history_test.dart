import 'package:deniz_app/domain/ai_assistant_response.dart';
import 'package:deniz_app/services/ai_assistant_conversation_history.dart';
import 'package:flutter_test/flutter_test.dart';

AiAssistantResponse _response(String summary) {
  return AiAssistantResponse.fromJson({
    'source': 'ai',
    'prompt_version': 'v1',
    'summary_tr': summary,
    'confidence': 'medium',
    'recommended_actions': [],
    'hotspot_insights': [],
    'conditions_comment_tr': '',
    'species_comment_tr': '',
    'limitations_tr': [],
    'safety_reminders_tr': [],
  });
}

void main() {
  test('keeps newest first and max 5 entries', () {
    final history = AiAssistantConversationHistory();
    for (var i = 1; i <= 7; i++) {
      history.add(
        question: 'Soru $i',
        response: _response('Cevap $i'),
      );
    }
    expect(history.entries.length, kAiAssistantMaxConversationEntries);
    expect(history.entries.first.question, 'Soru 7');
    expect(history.entries.last.question, 'Soru 3');
  });
}
