import 'package:deniz_app/domain/ai_assistant_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeAiUserQuestion', () {
    test('trims whitespace', () {
      expect(normalizeAiUserQuestion('  Levrek?  '), 'Levrek?');
    });

    test('empty and null return empty', () {
      expect(normalizeAiUserQuestion(null), '');
      expect(normalizeAiUserQuestion('   '), '');
    });

    test('truncates to 500 characters', () {
      final long = 'a' * 600;
      final normalized = normalizeAiUserQuestion(long);
      expect(normalized.length, kAiAssistantMaxUserQuestionLength);
      expect(normalized, 'a' * kAiAssistantMaxUserQuestionLength);
    });
  });

  group('AiAssistantRequest', () {
    test('normalizedQuestion uses helper', () {
      const req = AiAssistantRequest(userQuestion: '  Sabah mı?  ');
      expect(req.normalizedQuestion, 'Sabah mı?');
      expect(req.hasUserQuestion, isTrue);
    });
  });
}
