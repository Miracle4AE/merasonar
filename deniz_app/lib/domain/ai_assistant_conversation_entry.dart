import 'ai_assistant_response.dart';

/// Oturum içi tek bir AI soru-cevap kaydı.
class AiAssistantConversationEntry {
  const AiAssistantConversationEntry({
    required this.question,
    required this.response,
    required this.createdAt,
    this.cacheHit = false,
  });

  final String question;
  final AiAssistantResponse response;
  final DateTime createdAt;
  final bool cacheHit;

  String get answerSummary => response.summaryTr.trim();
}
