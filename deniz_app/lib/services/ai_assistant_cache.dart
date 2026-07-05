import 'package:deniz_app/api_service.dart';

import 'package:deniz_app/domain/ai_assistant_request.dart';

import 'package:deniz_app/domain/ai_assistant_response.dart';

import 'package:deniz_app/domain/fishing_zone_ai_payload.dart';

import 'package:deniz_app/domain/live_ai_context.dart';



/// Oturum içi bellek önbelleği — aynı analiz/scope/soru/live için tekrar istek azaltır.

class AiAssistantCache {

  AiAssistantCache();



  final Map<String, AiAssistantResponse> _store = {};



  String fingerprint(

    FishingZoneResponse analysis, {

    String scope = AiAssistantScope.sessionSummary,

    int? focusHotspotId,

    String? userQuestion,

    Map<String, dynamic>? liveContext,

  }) {

    final base = analysis.aiAnalysisFingerprint(scope: scope);

    final focus = focusHotspotId?.toString() ?? '';

    final question = normalizeAiUserQuestion(userQuestion);

    final live = liveContext != null && liveContext.isNotEmpty

        ? liveAiContextFingerprint(liveContext)

        : '';

    return '$base|focus:$focus|q:$question|live:$live';

  }



  AiAssistantResponse? get(

    FishingZoneResponse analysis, {

    String scope = AiAssistantScope.sessionSummary,

    int? focusHotspotId,

    String? userQuestion,

    Map<String, dynamic>? liveContext,

    bool forceRefresh = false,

  }) {

    if (forceRefresh) return null;

    final stored = _store[
      fingerprint(
        analysis,
        scope: scope,
        focusHotspotId: focusHotspotId,
        userQuestion: userQuestion,
        liveContext: liveContext,
      )
    ];
    if (stored != null && stored.isFallback) return null;
    return stored;
  }



  AiAssistantResponse? getForRequest(

    FishingZoneResponse analysis,

    AiAssistantRequest request, {

    bool forceRefresh = false,

  }) {

    return get(

      analysis,

      scope: request.scope,

      focusHotspotId: request.focusHotspotId,

      userQuestion: request.userQuestion,

      liveContext: request.liveContext,

      forceRefresh: forceRefresh,

    );

  }



  void put(

    FishingZoneResponse analysis,

    AiAssistantResponse response, {

    String scope = AiAssistantScope.sessionSummary,

    int? focusHotspotId,

    String? userQuestion,

    Map<String, dynamic>? liveContext,

  }) {
    if (response.isFallback) return;
    _store[

      fingerprint(

        analysis,

        scope: scope,

        focusHotspotId: focusHotspotId,

        userQuestion: userQuestion,

        liveContext: liveContext,

      )

    ] = response;

  }



  void putForRequest(

    FishingZoneResponse analysis,

    AiAssistantRequest request,

    AiAssistantResponse response,

  ) {

    put(

      analysis,

      response,

      scope: request.scope,

      focusHotspotId: request.focusHotspotId,

      userQuestion: request.userQuestion,

      liveContext: request.liveContext,

    );

  }



  void clear() => _store.clear();

}


