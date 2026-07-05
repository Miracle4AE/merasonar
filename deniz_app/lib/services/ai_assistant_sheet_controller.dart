import 'package:deniz_app/api_service.dart';

import 'package:deniz_app/domain/ai_assistant_request.dart';

import 'package:deniz_app/domain/ai_assistant_response.dart';

import 'package:deniz_app/l10n/app_strings_tr.dart';

import 'package:deniz_app/services/ai_assistant_cache.dart';

import 'package:deniz_app/services/ai_assistant_conversation_history.dart';

import 'package:deniz_app/services/client_identity_service.dart';



enum AiSheetPhase { loading, ready, error }



/// AI sheet yükleme, yenileme ve soru geçmişi mantığı.

class AiAssistantSheetController {

  AiAssistantSheetController({

    required this.apiService,

    required this.analysis,

    required this.cache,

    required this.request,

    required this.clientIdentityService,

    this.forceRefreshOnOpen = false,

    this.allowStaleFallback = true,

  });



  final ApiService apiService;

  final FishingZoneResponse analysis;

  final AiAssistantCache cache;

  final AiAssistantRequest request;

  final ClientIdentityService clientIdentityService;

  final bool forceRefreshOnOpen;

  final bool allowStaleFallback;



  final AiAssistantConversationHistory conversationHistory =

      AiAssistantConversationHistory();



  AiSheetPhase phase = AiSheetPhase.loading;

  AiAssistantResponse? response;

  String? errorMessage;

  String? refreshErrorBanner;

  bool cacheOnlyMode = false;

  bool refreshing = false;

  bool questionLoading = false;



  AiAssistantRequest get baseRequest =>

      request.copyWith(clearUserQuestion: true, clearLiveContext: false);



  Future<void> loadInitial({bool forceRefresh = false}) async {

    final refresh = forceRefresh || forceRefreshOnOpen;

    cacheOnlyMode = false;

    refreshErrorBanner = null;



    final cached = cache.getForRequest(

      analysis,

      baseRequest,

      forceRefresh: refresh,

    );

    if (cached != null) {

      response = cached;

      phase = AiSheetPhase.ready;

      return;

    }



    try {

      final result = await _fetch(baseRequest, forceRefresh: refresh);

      cache.putForRequest(analysis, baseRequest, result);

      response = result;

      phase = AiSheetPhase.ready;

    } on ApiException catch (e) {

      if (allowStaleFallback) {
        final stale = cache.getForRequest(analysis, baseRequest);

        if (stale != null) {

          response = stale;

          cacheOnlyMode = true;

          phase = AiSheetPhase.ready;

          return;

        }
      }

      errorMessage = e.message;

      phase = AiSheetPhase.error;

    } catch (_) {

      if (allowStaleFallback) {
        final stale = cache.getForRequest(analysis, baseRequest);

        if (stale != null) {

          response = stale;

          cacheOnlyMode = true;

          phase = AiSheetPhase.ready;

          return;

        }
      }

      errorMessage = kAiAssistantErrorGeneric;

      phase = AiSheetPhase.error;

    }

  }



  Future<void> refresh() async {

    if (refreshing || phase != AiSheetPhase.ready) return;

    refreshing = true;

    refreshErrorBanner = null;



    try {

      final result = await _fetch(baseRequest, forceRefresh: true);

      cache.putForRequest(analysis, baseRequest, result);

      response = result;

      cacheOnlyMode = false;

    } on ApiException catch (e) {

      refreshErrorBanner = e.message;

    } catch (_) {

      refreshErrorBanner = kAiAssistantErrorGeneric;

    } finally {

      refreshing = false;

    }

  }



  Future<bool> submitQuestion(String rawQuestion) async {

    final question = normalizeAiUserQuestion(rawQuestion);

    if (question.isEmpty || questionLoading) return false;



    final questionRequest = baseRequest.copyWith(userQuestion: question);

    final cached = cache.getForRequest(analysis, questionRequest);

    if (cached != null) {

      conversationHistory.add(

        question: question,

        response: cached,

        cacheHit: cached.cacheHit,

      );

      return true;

    }



    questionLoading = true;

    try {

      final result = await _fetch(questionRequest);

      cache.putForRequest(analysis, questionRequest, result);

      conversationHistory.add(

        question: question,

        response: result,

        cacheHit: result.cacheHit,

      );

      return true;

    } on ApiException {

      return false;

    } catch (_) {

      return false;

    } finally {

      questionLoading = false;

    }

  }



  Future<AiAssistantResponse> _fetch(
    AiAssistantRequest req, {
    bool forceRefresh = false,
  }) async {
    final identity = await clientIdentityService.getIdentity();
    return apiService.fetchAiFishingAssistant(
      analysis: analysis,
      scope: req.scope,
      focusHotspotId: req.focusHotspotId,
      userQuestion: req.hasUserQuestion ? req.normalizedQuestion : null,
      liveContext: req.liveContext,
      clientIdentity: identity,
      forceRefresh: forceRefresh,
    );
  }

}


