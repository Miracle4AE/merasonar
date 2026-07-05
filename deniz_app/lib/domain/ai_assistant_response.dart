/// AI Fishing Assistant API yanıt modelleri — güvenli JSON parse.

library;



class AiRecommendedAction {

  const AiRecommendedAction({

    required this.priority,

    required this.titleTr,

    required this.detailTr,

  });



  final int priority;

  final String titleTr;

  final String detailTr;



  factory AiRecommendedAction.fromJson(Map<String, dynamic>? json) {

    if (json == null) {

      return const AiRecommendedAction(

        priority: 1,

        titleTr: '',

        detailTr: '',

      );

    }

    return AiRecommendedAction(

      priority: _asInt(json['priority']) ?? 1,

      titleTr: (json['title_tr'] as String?)?.trim() ?? '',

      detailTr: (json['detail_tr'] as String?)?.trim() ?? '',

    );

  }

}



class AiHotspotInsight {

  const AiHotspotInsight({

    required this.hotspotId,

    required this.headlineTr,

    required this.detailTr,

  });



  final int hotspotId;

  final String headlineTr;

  final String detailTr;



  factory AiHotspotInsight.fromJson(Map<String, dynamic>? json) {

    if (json == null) {

      return const AiHotspotInsight(

        hotspotId: 0,

        headlineTr: '',

        detailTr: '',

      );

    }

    return AiHotspotInsight(

      hotspotId: _asInt(json['hotspot_id']) ?? 0,

      headlineTr: (json['headline_tr'] as String?)?.trim() ?? '',

      detailTr: (json['detail_tr'] as String?)?.trim() ?? '',

    );

  }

}



class AiAssistantTelemetry {

  const AiAssistantTelemetry({

    this.event,

    this.scope,

    this.source,

    this.model,

    this.latencyMs,

    this.inputTokens,

    this.outputTokens,

    this.totalTokens,

    this.estimatedCostUsd,

    this.processingTimeMs,

    this.promptVersion,

    this.assistantName,

    this.personaVersion,

    this.cacheHit,

    this.fallbackReason,

  });



  final String? event;

  final String? scope;

  final String? source;

  final String? model;

  final double? latencyMs;

  final int? inputTokens;

  final int? outputTokens;

  final int? totalTokens;

  final double? estimatedCostUsd;

  final int? processingTimeMs;

  final String? promptVersion;

  final String? assistantName;

  final String? personaVersion;

  final bool? cacheHit;

  final String? fallbackReason;



  factory AiAssistantTelemetry.fromJson(Map<String, dynamic>? json) {

    if (json == null) {

      return const AiAssistantTelemetry();

    }



    final tokenUsage = json['token_usage'];

    int? inputTokens;

    int? outputTokens;

    int? totalTokens;

    if (tokenUsage is Map) {

      final usage = Map<String, dynamic>.from(tokenUsage);

      inputTokens = _asInt(usage['input']);

      outputTokens = _asInt(usage['output']);

      totalTokens = _asInt(usage['total']);

    }



    return AiAssistantTelemetry(

      event: (json['event'] as String?)?.trim(),

      scope: (json['scope'] as String?)?.trim(),

      source: (json['source'] as String?)?.trim(),

      model: (json['model'] as String?)?.trim(),

      latencyMs: _asDouble(json['latency_ms']),

      inputTokens: inputTokens ?? _asInt(json['input_tokens']),

      outputTokens: outputTokens ?? _asInt(json['output_tokens']),

      totalTokens: totalTokens ?? _asInt(json['total_tokens']),

      estimatedCostUsd:

          _asDouble(json['estimated_cost']) ?? _asDouble(json['estimated_cost_usd']),

      processingTimeMs: _asInt(json['processing_time_ms']),

      promptVersion: (json['prompt_version'] as String?)?.trim(),

      assistantName: (json['assistant_name'] as String?)?.trim(),

      personaVersion: (json['persona_version'] as String?)?.trim(),

      cacheHit: json['cache_hit'] is bool ? json['cache_hit'] as bool : null,

      fallbackReason: () {

        final r = json['fallback_reason'];

        if (r == null) return null;

        final t = r.toString().trim();

        return t.isEmpty ? null : t;

      }(),

    );

  }

}



class AiAssistantResponse {

  const AiAssistantResponse({

    required this.source,

    this.model,

    this.cacheHit = false,

    this.locale = 'tr',

    this.trustNoteTr = '',

    this.promptVersion = '',

    required this.summaryTr,

    this.confidence = 'medium',

    this.recommendedActions = const [],

    this.hotspotInsights = const [],

    this.conditionsCommentTr = '',

    this.speciesCommentTr = '',

    this.limitationsTr = const [],

    this.safetyRemindersTr = const [],

    this.fallbackReason,

    this.processingMs = 0,

    this.telemetry,

    this.mode,

    this.focusHotspotId,

    this.remainingAiRequests,

    this.isPremiumFeature,

    this.assistantName = 'Captain Atlas',

    this.personaVersion = 'captain_atlas_v1',

    this.tone = 'calm_expert',

  });



  final String source;

  final String? model;

  final bool cacheHit;

  final String locale;

  final String trustNoteTr;

  final String promptVersion;

  final String summaryTr;

  final String confidence;

  final List<AiRecommendedAction> recommendedActions;

  final List<AiHotspotInsight> hotspotInsights;

  final String conditionsCommentTr;

  final String speciesCommentTr;

  final List<String> limitationsTr;

  final List<String> safetyRemindersTr;

  final String? fallbackReason;

  final int processingMs;

  final AiAssistantTelemetry? telemetry;

  final String? mode;

  final int? focusHotspotId;

  final int? remainingAiRequests;

  final bool? isPremiumFeature;

  final String assistantName;

  final String personaVersion;

  final String tone;



  bool get isFallback => source == 'fallback';

  bool get isAi => source == 'ai';



  factory AiAssistantResponse.fromJson(Map<String, dynamic> json) {

    final actionsRaw = json['recommended_actions'];

    final insightsRaw = json['hotspot_insights'];

    final limitationsRaw = json['limitations_tr'];

    final safetyRaw = json['safety_reminders_tr'];

    final telemetryRaw = json['telemetry'];



    return AiAssistantResponse(

      source: (json['source'] as String?)?.trim().isNotEmpty == true

          ? (json['source'] as String).trim()

          : 'fallback',

      model: (json['model'] as String?)?.trim(),

      cacheHit: json['cache_hit'] == true,

      locale: (json['locale'] as String?)?.trim().isNotEmpty == true

          ? (json['locale'] as String).trim()

          : 'tr',

      trustNoteTr: (json['trust_note_tr'] as String?)?.trim() ?? '',

      promptVersion: (json['prompt_version'] as String?)?.trim() ?? '',

      summaryTr: (json['summary_tr'] as String?)?.trim() ?? '',

      confidence: _normalizeConfidence(json['confidence']),

      recommendedActions: actionsRaw is List

          ? actionsRaw

              .map(_asMap)

              .whereType<Map<String, dynamic>>()

              .map(AiRecommendedAction.fromJson)

              .where((a) => a.titleTr.isNotEmpty || a.detailTr.isNotEmpty)

              .toList(growable: false)

          : const [],

      hotspotInsights: insightsRaw is List

          ? insightsRaw

              .map(_asMap)

              .whereType<Map<String, dynamic>>()

              .map(AiHotspotInsight.fromJson)

              .where((h) => h.headlineTr.isNotEmpty || h.detailTr.isNotEmpty)

              .toList(growable: false)

          : const [],

      conditionsCommentTr:

          (json['conditions_comment_tr'] as String?)?.trim() ?? '',

      speciesCommentTr: (json['species_comment_tr'] as String?)?.trim() ?? '',

      limitationsTr: limitationsRaw is List

          ? limitationsRaw

              .map((e) => e.toString().trim())

              .where((s) => s.isNotEmpty)

              .toList(growable: false)

          : const [],

      safetyRemindersTr: safetyRaw is List

          ? safetyRaw

              .map((e) => e.toString().trim())

              .where((s) => s.isNotEmpty)

              .toList(growable: false)

          : const [],

      fallbackReason: () {

        final r = json['fallback_reason'];

        if (r == null) return null;

        final t = r.toString().trim();

        return t.isEmpty ? null : t;

      }(),

      processingMs: _asInt(json['processing_ms']) ?? 0,

      telemetry: telemetryRaw is Map<String, dynamic>

          ? AiAssistantTelemetry.fromJson(telemetryRaw)

          : telemetryRaw is Map

              ? AiAssistantTelemetry.fromJson(

                  Map<String, dynamic>.from(telemetryRaw),

                )

              : null,

      mode: (json['mode'] as String?)?.trim(),

      focusHotspotId: _asInt(json['focus_hotspot_id']),

      remainingAiRequests: _asInt(json['remaining_ai_requests']),

      isPremiumFeature: json['is_premium_feature'] is bool

          ? json['is_premium_feature'] as bool

          : null,

      assistantName: () {
        final direct = (json['assistant_name'] as String?)?.trim();
        if (direct != null && direct.isNotEmpty) return direct;
        final telemetry = json['telemetry'];
        if (telemetry is Map) {
          final fromTelemetry = (telemetry['assistant_name'] as String?)?.trim();
          if (fromTelemetry != null && fromTelemetry.isNotEmpty) {
            return fromTelemetry;
          }
        }
        return 'Captain Atlas';
      }(),

      personaVersion: () {
        final direct = (json['persona_version'] as String?)?.trim();
        if (direct != null && direct.isNotEmpty) return direct;
        final telemetry = json['telemetry'];
        if (telemetry is Map) {
          final fromTelemetry = (telemetry['persona_version'] as String?)?.trim();
          if (fromTelemetry != null && fromTelemetry.isNotEmpty) {
            return fromTelemetry;
          }
        }
        return 'captain_atlas_v1';
      }(),

      tone: (json['tone'] as String?)?.trim().isNotEmpty == true
          ? (json['tone'] as String).trim()
          : 'calm_expert',

    );

  }

}



String _normalizeConfidence(Object? raw) {

  final s = (raw?.toString() ?? '').trim().toLowerCase();

  if (s == 'low' || s == 'medium' || s == 'high') return s;

  return 'medium';

}



int? _asInt(Object? value) {

  if (value == null) return null;

  if (value is int) return value;

  if (value is num) return value.round();

  return int.tryParse(value.toString());

}



double? _asDouble(Object? value) {

  if (value == null) return null;

  if (value is double) return value;

  if (value is num) return value.toDouble();

  return double.tryParse(value.toString());

}



Map<String, dynamic>? _asMap(Object? value) {

  if (value is Map<String, dynamic>) return value;

  if (value is Map) return Map<String, dynamic>.from(value);

  return null;

}


