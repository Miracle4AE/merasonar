import 'package:deniz_app/domain/ai_assistant_conversation_entry.dart';
import 'package:deniz_app/domain/ai_assistant_response.dart';

const int kAiAssistantMaxConversationEntries = 5;

/// Oturum içi soru geçmişi — en yeni üstte, max 5 kayıt.
class AiAssistantConversationHistory {
  AiAssistantConversationHistory();

  final List<AiAssistantConversationEntry> _entries = [];

  List<AiAssistantConversationEntry> get entries =>
      List.unmodifiable(_entries);

  void add({
    required String question,
    required AiAssistantResponse response,
    bool cacheHit = false,
  }) {
    _entries.insert(
      0,
      AiAssistantConversationEntry(
        question: question,
        response: response,
        createdAt: DateTime.now(),
        cacheHit: cacheHit,
      ),
    );
    while (_entries.length > kAiAssistantMaxConversationEntries) {
      _entries.removeLast();
    }
  }

  void clear() => _entries.clear();
}
