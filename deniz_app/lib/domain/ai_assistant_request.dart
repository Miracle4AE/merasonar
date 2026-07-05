// AI Fishing Assistant istek parametreleri ve yardımcılar.

class AiAssistantScope {

  AiAssistantScope._();



  static const sessionSummary = 'session_summary';

  static const hotspotDetail = 'hotspot_detail';

  static const liveContext = 'live_context';



  static const validScopes = {

    sessionSummary,

    hotspotDetail,

    liveContext,

  };

}



const int kAiAssistantMaxUserQuestionLength = 500;



/// Geçersiz scope için hata fırlatır.

void assertValidAiAssistantScope(String scope) {

  if (!AiAssistantScope.validScopes.contains(scope)) {

    throw ArgumentError.value(scope, 'scope', 'Geçersiz AI scope: $scope');

  }

}



/// Kullanıcı sorusunu API/cache için normalize eder (trim + max uzunluk).

String normalizeAiUserQuestion(String? question) {

  if (question == null) return '';

  final trimmed = question.trim();

  if (trimmed.isEmpty) return '';

  if (trimmed.length <= kAiAssistantMaxUserQuestionLength) return trimmed;

  return trimmed.substring(0, kAiAssistantMaxUserQuestionLength);

}



/// Tek bir AI isteğini tanımlar — cache anahtarı ve API çağrısı için.

class AiAssistantRequest {

  const AiAssistantRequest({

    this.scope = AiAssistantScope.sessionSummary,

    this.focusHotspotId,

    this.userQuestion,

    this.liveContext,

  });



  final String scope;

  final int? focusHotspotId;

  final String? userQuestion;

  final Map<String, dynamic>? liveContext;



  String get normalizedQuestion => normalizeAiUserQuestion(userQuestion);



  bool get hasUserQuestion => normalizedQuestion.isNotEmpty;



  AiAssistantRequest copyWith({

    String? scope,

    int? focusHotspotId,

    String? userQuestion,

    Map<String, dynamic>? liveContext,

    bool clearUserQuestion = false,

    bool clearLiveContext = false,

  }) {

    return AiAssistantRequest(

      scope: scope ?? this.scope,

      focusHotspotId: focusHotspotId ?? this.focusHotspotId,

      userQuestion: clearUserQuestion ? null : (userQuestion ?? this.userQuestion),

      liveContext: clearLiveContext ? null : (liveContext ?? this.liveContext),

    );

  }

}


