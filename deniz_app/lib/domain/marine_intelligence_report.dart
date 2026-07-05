/// Marine Intelligence coordinate raporu — güvenli JSON parse.

library;

import 'marine_consensus_value.dart';

class MarineCoordinate {
  const MarineCoordinate({required this.lat, required this.lon});

  final double lat;
  final double lon;

  factory MarineCoordinate.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const MarineCoordinate(lat: 0, lon: 0);
    return MarineCoordinate(
      lat: _asDouble(json['lat']) ?? 0,
      lon: _asDouble(json['lon']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {'lat': lat, 'lon': lon};
}

class MarineWeatherBlock {
  const MarineWeatherBlock({
    this.temperatureC,
    this.apparentTemperatureC,
    this.precipitationProbabilityPct,
    this.precipitationMm,
    this.relativeHumidityPct,
    this.surfacePressureHpa,
  });

  final MarineConsensusValue? temperatureC;
  final MarineConsensusValue? apparentTemperatureC;
  final MarineConsensusValue? precipitationProbabilityPct;
  final MarineConsensusValue? precipitationMm;
  final MarineConsensusValue? relativeHumidityPct;
  final MarineConsensusValue? surfacePressureHpa;

  factory MarineWeatherBlock.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const MarineWeatherBlock();
    return MarineWeatherBlock(
      temperatureC: MarineConsensusValue.fromJson(
        _map(json['temperature_c']),
      ),
      apparentTemperatureC: MarineConsensusValue.fromJson(
        _map(json['apparent_temperature_c']),
      ),
      precipitationProbabilityPct: MarineConsensusValue.fromJson(
        _map(json['precipitation_probability_pct']),
      ),
      precipitationMm: MarineConsensusValue.fromJson(
        _map(json['precipitation_mm']),
      ),
      relativeHumidityPct: MarineConsensusValue.fromJson(
        _map(json['relative_humidity_pct']),
      ),
      surfacePressureHpa: MarineConsensusValue.fromJson(
        _map(json['surface_pressure_hpa']),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'temperature_c': temperatureC?.toJson(),
        'apparent_temperature_c': apparentTemperatureC?.toJson(),
        'precipitation_probability_pct': precipitationProbabilityPct?.toJson(),
        'precipitation_mm': precipitationMm?.toJson(),
        'relative_humidity_pct': relativeHumidityPct?.toJson(),
        'surface_pressure_hpa': surfacePressureHpa?.toJson(),
      };
}

class MarineWindBlock {
  const MarineWindBlock({
    this.speedKmh,
    this.directionDeg,
    this.directionText,
    this.gustKmh,
    this.maxGustKmh,
  });

  final MarineConsensusValue? speedKmh;
  final MarineConsensusValue? directionDeg;
  final String? directionText;
  final MarineConsensusValue? gustKmh;
  final MarineConsensusValue? maxGustKmh;

  factory MarineWindBlock.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const MarineWindBlock();
    return MarineWindBlock(
      speedKmh: MarineConsensusValue.fromJson(_map(json['speed_kmh'])),
      directionDeg: MarineConsensusValue.fromJson(_map(json['direction_deg'])),
      directionText: json['direction_text'] as String?,
      gustKmh: MarineConsensusValue.fromJson(_map(json['gust_kmh'])),
      maxGustKmh: MarineConsensusValue.fromJson(_map(json['max_gust_kmh'])),
    );
  }

  Map<String, dynamic> toJson() => {
        'speed_kmh': speedKmh?.toJson(),
        'direction_deg': directionDeg?.toJson(),
        'direction_text': directionText,
        'gust_kmh': gustKmh?.toJson(),
        'max_gust_kmh': maxGustKmh?.toJson(),
      };
}

class MarineSeaBlock {
  const MarineSeaBlock({
    this.waveHeightM,
    this.waveDirectionDeg,
    this.wavePeriodS,
    this.swellHeightM,
    this.swellDirectionDeg,
    this.swellPeriodS,
    this.seaSurfaceTemperatureC,
    this.oceanCurrentVelocityMps,
    this.oceanCurrentDirectionDeg,
  });

  final MarineConsensusValue? waveHeightM;
  final MarineConsensusValue? waveDirectionDeg;
  final MarineConsensusValue? wavePeriodS;
  final MarineConsensusValue? swellHeightM;
  final MarineConsensusValue? swellDirectionDeg;
  final MarineConsensusValue? swellPeriodS;
  final MarineConsensusValue? seaSurfaceTemperatureC;
  final MarineConsensusValue? oceanCurrentVelocityMps;
  final MarineConsensusValue? oceanCurrentDirectionDeg;

  factory MarineSeaBlock.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const MarineSeaBlock();
    return MarineSeaBlock(
      waveHeightM: MarineConsensusValue.fromJson(_map(json['wave_height_m'])),
      waveDirectionDeg:
          MarineConsensusValue.fromJson(_map(json['wave_direction_deg'])),
      wavePeriodS: MarineConsensusValue.fromJson(_map(json['wave_period_s'])),
      swellHeightM: MarineConsensusValue.fromJson(_map(json['swell_height_m'])),
      swellDirectionDeg:
          MarineConsensusValue.fromJson(_map(json['swell_direction_deg'])),
      swellPeriodS: MarineConsensusValue.fromJson(_map(json['swell_period_s'])),
      seaSurfaceTemperatureC: MarineConsensusValue.fromJson(
        _map(json['sea_surface_temperature_c']),
      ),
      oceanCurrentVelocityMps: MarineConsensusValue.fromJson(
        _map(json['ocean_current_velocity_mps']),
      ),
      oceanCurrentDirectionDeg: MarineConsensusValue.fromJson(
        _map(json['ocean_current_direction_deg']),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'wave_height_m': waveHeightM?.toJson(),
        'wave_direction_deg': waveDirectionDeg?.toJson(),
        'wave_period_s': wavePeriodS?.toJson(),
        'swell_height_m': swellHeightM?.toJson(),
        'swell_direction_deg': swellDirectionDeg?.toJson(),
        'swell_period_s': swellPeriodS?.toJson(),
        'sea_surface_temperature_c': seaSurfaceTemperatureC?.toJson(),
        'ocean_current_velocity_mps': oceanCurrentVelocityMps?.toJson(),
        'ocean_current_direction_deg': oceanCurrentDirectionDeg?.toJson(),
      };
}

class MarineAstronomyBlock {
  const MarineAstronomyBlock({
    this.sunrise,
    this.sunset,
    this.moonPhase,
    this.moonIlluminationPct,
    this.moonrise,
    this.moonset,
    this.moonAltitudeDeg,
  });

  final String? sunrise;
  final String? sunset;
  final String? moonPhase;
  final double? moonIlluminationPct;
  final String? moonrise;
  final String? moonset;
  final double? moonAltitudeDeg;

  factory MarineAstronomyBlock.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const MarineAstronomyBlock();
    return MarineAstronomyBlock(
      sunrise: json['sunrise'] as String?,
      sunset: json['sunset'] as String?,
      moonPhase: json['moon_phase'] as String?,
      moonIlluminationPct: _asDouble(json['moon_illumination_pct']),
      moonrise: json['moonrise'] as String?,
      moonset: json['moonset'] as String?,
      moonAltitudeDeg: _asDouble(json['moon_altitude_deg']),
    );
  }

  Map<String, dynamic> toJson() => {
        'sunrise': sunrise,
        'sunset': sunset,
        'moon_phase': moonPhase,
        'moon_illumination_pct': moonIlluminationPct,
        'moonrise': moonrise,
        'moonset': moonset,
        'moon_altitude_deg': moonAltitudeDeg,
      };
}

class MarineFishingScore {
  const MarineFishingScore({
    this.suitabilityScore = 0,
    this.riskScore = 0,
    this.bestHoursTr = '',
    this.windCommentTr = '',
    this.waveCommentTr = '',
    this.swellCommentTr = '',
    this.moonCommentTr = '',
    this.generalAdviceTr = '',
    this.confidence = 0,
  });

  final int suitabilityScore;
  final int riskScore;
  final String bestHoursTr;
  final String windCommentTr;
  final String waveCommentTr;
  final String swellCommentTr;
  final String moonCommentTr;
  final String generalAdviceTr;
  final double confidence;

  factory MarineFishingScore.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const MarineFishingScore();
    return MarineFishingScore(
      suitabilityScore: _asInt(json['suitability_score']) ?? 0,
      riskScore: _asInt(json['risk_score']) ?? 0,
      bestHoursTr: (json['best_hours_tr'] as String?) ?? '',
      windCommentTr: (json['wind_comment_tr'] as String?) ?? '',
      waveCommentTr: (json['wave_comment_tr'] as String?) ?? '',
      swellCommentTr: (json['swell_comment_tr'] as String?) ?? '',
      moonCommentTr: (json['moon_comment_tr'] as String?) ?? '',
      generalAdviceTr: (json['general_advice_tr'] as String?) ?? '',
      confidence: _asDouble(json['confidence']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'suitability_score': suitabilityScore,
        'risk_score': riskScore,
        'best_hours_tr': bestHoursTr,
        'wind_comment_tr': windCommentTr,
        'wave_comment_tr': waveCommentTr,
        'swell_comment_tr': swellCommentTr,
        'moon_comment_tr': moonCommentTr,
        'general_advice_tr': generalAdviceTr,
        'confidence': confidence,
      };
}

class MarineConsensusSummary {
  const MarineConsensusSummary({
    this.overallConfidence = 0,
    this.providerCount = 0,
    this.partialProviders = false,
    this.sourceCountByGroup = const {},
    this.strongestGroup,
    this.weakestGroup,
    this.disagreementGroups = const [],
    this.partialDataReason,
  });

  final double overallConfidence;
  final int providerCount;
  final bool partialProviders;
  final Map<String, int> sourceCountByGroup;
  final String? strongestGroup;
  final String? weakestGroup;
  final List<String> disagreementGroups;
  final String? partialDataReason;

  factory MarineConsensusSummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const MarineConsensusSummary();
    final groups = <String, int>{};
    final raw = json['source_count_by_group'];
    if (raw is Map) {
      for (final e in raw.entries) {
        groups[e.key.toString()] = _asInt(e.value) ?? 0;
      }
    }
    return MarineConsensusSummary(
      overallConfidence: _asDouble(json['overall_confidence']) ?? 0,
      providerCount: _asInt(json['provider_count']) ?? 0,
      partialProviders: json['partial_providers'] == true,
      sourceCountByGroup: groups,
      strongestGroup: json['strongest_group'] as String?,
      weakestGroup: json['weakest_group'] as String?,
      disagreementGroups: _asStringList(json['disagreement_groups']),
      partialDataReason: json['partial_data_reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'overall_confidence': overallConfidence,
        'provider_count': providerCount,
        'partial_providers': partialProviders,
        'source_count_by_group': sourceCountByGroup,
        'strongest_group': strongestGroup,
        'weakest_group': weakestGroup,
        'disagreement_groups': disagreementGroups,
        'partial_data_reason': partialDataReason,
      };
}

class MarineDecision {
  const MarineDecision({
    this.fishingDecision,
    this.goScore,
    this.waitScore,
    this.bestActionTr,
    this.decisionReasonCodes = const [],
    this.shortSummaryTr,
  });

  final String? fishingDecision;
  final int? goScore;
  final int? waitScore;
  final String? bestActionTr;
  final List<String> decisionReasonCodes;
  final String? shortSummaryTr;

  factory MarineDecision.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const MarineDecision();
    return MarineDecision(
      fishingDecision: json['fishing_decision'] as String?,
      goScore: _asInt(json['go_score']),
      waitScore: _asInt(json['wait_score']),
      bestActionTr: json['best_action_tr'] as String?,
      decisionReasonCodes: _asStringList(json['decision_reason_codes']),
      shortSummaryTr: json['short_summary_tr'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'fishing_decision': fishingDecision,
        'go_score': goScore,
        'wait_score': waitScore,
        'best_action_tr': bestActionTr,
        'decision_reason_codes': decisionReasonCodes,
        'short_summary_tr': shortSummaryTr,
      };
}

class MarineDecisionTimelineItem {
  const MarineDecisionTimelineItem({
    required this.time,
    this.goScore,
    this.riskScore,
    this.decision,
    this.reasonTr,
    this.isBestSlot = false,
  });

  final String time;
  final int? goScore;
  final int? riskScore;
  final String? decision;
  final String? reasonTr;
  final bool isBestSlot;

  factory MarineDecisionTimelineItem.fromJson(Map<String, dynamic> json) {
    return MarineDecisionTimelineItem(
      time: (json['time'] as String?) ?? '',
      goScore: _asInt(json['go_score']),
      riskScore: _asInt(json['risk_score']),
      decision: json['decision'] as String?,
      reasonTr: json['reason_tr'] as String?,
      isBestSlot: json['is_best_slot'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'time': time,
        'go_score': goScore,
        'risk_score': riskScore,
        'decision': decision,
        'reason_tr': reasonTr,
        'is_best_slot': isBestSlot,
      };
}

class MarineAiCommentAction {
  const MarineAiCommentAction({
    required this.titleTr,
    this.detailTr = '',
  });

  final String titleTr;
  final String detailTr;

  factory MarineAiCommentAction.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const MarineAiCommentAction(titleTr: '');
    return MarineAiCommentAction(
      titleTr: (json['title_tr'] as String?) ?? '',
      detailTr: (json['detail_tr'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'title_tr': titleTr,
        'detail_tr': detailTr,
      };
}

class MarineAiComment {
  const MarineAiComment({
    this.source = 'fallback',
    this.summaryTr = '',
    this.recommendedActions = const [],
    this.riskNoteTr,
    this.bestTimeWindowTr,
    this.cacheHit = false,
    this.fallbackReason,
    this.assistantName = 'Captain Atlas',
    this.personaVersion = 'captain_atlas_v1',
    this.tone = 'calm_expert',
  });

  final String source;
  final String summaryTr;
  final List<MarineAiCommentAction> recommendedActions;
  final String? riskNoteTr;
  final String? bestTimeWindowTr;
  final bool cacheHit;
  final String? fallbackReason;
  final String assistantName;
  final String personaVersion;
  final String tone;

  bool get isFallback => source == 'fallback';

  factory MarineAiComment.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const MarineAiComment();
    }
    final actionsRaw = json['recommended_actions'];
    final actions = actionsRaw is List
        ? actionsRaw
            .whereType<Map>()
            .map(
              (e) => MarineAiCommentAction.fromJson(
                Map<String, dynamic>.from(e),
              ),
            )
            .toList(growable: false)
        : const <MarineAiCommentAction>[];
    return MarineAiComment(
      source: (json['source'] as String?) ?? 'fallback',
      summaryTr: (json['summary_tr'] as String?) ?? '',
      recommendedActions: actions,
      riskNoteTr: json['risk_note_tr'] as String?,
      bestTimeWindowTr: json['best_time_window_tr'] as String?,
      cacheHit: json['cache_hit'] == true,
      fallbackReason: json['fallback_reason'] as String?,
      assistantName: (json['assistant_name'] as String?) ?? 'Captain Atlas',
      personaVersion: (json['persona_version'] as String?) ?? 'captain_atlas_v1',
      tone: (json['tone'] as String?) ?? 'calm_expert',
    );
  }

  Map<String, dynamic> toJson() => {
        'source': source,
        'summary_tr': summaryTr,
        'recommended_actions':
            recommendedActions.map((e) => e.toJson()).toList(),
        'risk_note_tr': riskNoteTr,
        'best_time_window_tr': bestTimeWindowTr,
        'cache_hit': cacheHit,
        'fallback_reason': fallbackReason,
        'assistant_name': assistantName,
        'persona_version': personaVersion,
        'tone': tone,
      };
}

class MarineScenarioItem {
  const MarineScenarioItem({
    required this.scenarioId,
    required this.titleTr,
    this.changedInputs = const {},
    this.resultingGoScore,
    this.resultingRiskScore,
    this.decision,
    this.deltaGoScore,
    this.deltaRiskScore,
    this.deltaSummaryTr,
  });

  final String scenarioId;
  final String titleTr;
  final Map<String, dynamic> changedInputs;
  final int? resultingGoScore;
  final int? resultingRiskScore;
  final String? decision;
  final int? deltaGoScore;
  final int? deltaRiskScore;
  final String? deltaSummaryTr;

  factory MarineScenarioItem.fromJson(Map<String, dynamic> json) {
    final rawInputs = json['changed_inputs'];
    final inputs = rawInputs is Map
        ? Map<String, dynamic>.from(rawInputs)
        : const <String, dynamic>{};
    return MarineScenarioItem(
      scenarioId: (json['scenario_id'] as String?) ?? '',
      titleTr: (json['title_tr'] as String?) ?? '',
      changedInputs: inputs,
      resultingGoScore: _asInt(json['resulting_go_score']),
      resultingRiskScore: _asInt(json['resulting_risk_score']),
      decision: json['decision'] as String?,
      deltaGoScore: _asInt(json['delta_go_score']),
      deltaRiskScore: _asInt(json['delta_risk_score']),
      deltaSummaryTr: json['delta_summary_tr'] as String?,
    );
  }
}

class MarineScenarioBundle {
  const MarineScenarioBundle({
    this.baseGoScore,
    this.items = const [],
  });

  final int? baseGoScore;
  final List<MarineScenarioItem> items;

  factory MarineScenarioBundle.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const MarineScenarioBundle();
    final raw = json['items'];
    final items = raw is List
        ? raw
            .whereType<Map>()
            .map(
              (e) => MarineScenarioItem.fromJson(
                Map<String, dynamic>.from(e),
              ),
            )
            .toList(growable: false)
        : const <MarineScenarioItem>[];
    return MarineScenarioBundle(
      baseGoScore: _asInt(json['base_go_score']),
      items: items,
    );
  }

  String? get mostSensitiveFactorLabel {
    if (items.isEmpty) return null;
    final ranked = [...items]
      ..sort((a, b) {
        final aImpact = (a.deltaGoScore ?? 0).abs() + (a.deltaRiskScore ?? 0).abs();
        final bImpact = (b.deltaGoScore ?? 0).abs() + (b.deltaRiskScore ?? 0).abs();
        return bImpact.compareTo(aImpact);
      });
    return _scenarioSensitivityLabel(ranked.first.scenarioId);
  }
}

String? _scenarioSensitivityLabel(String scenarioId) {
  switch (scenarioId) {
    case 'wind_plus_5':
      return 'Rüzgar';
    case 'gust_plus_10':
      return 'Ani rüzgar';
    case 'wave_plus_0_5':
      return 'Dalga';
    case 'rain_plus_30':
      return 'Yağış';
    case 'moon_high':
      return 'Ay ışığı';
    default:
      return null;
  }
}

class MarineExplainability {
  const MarineExplainability({
    this.positiveFactors = const [],
    this.negativeFactors = const [],
    this.uncertaintyFactors = const [],
    this.explanationSummaryTr,
    this.mostSensitiveFactorTr,
  });

  final List<String> positiveFactors;
  final List<String> negativeFactors;
  final List<String> uncertaintyFactors;
  final String? explanationSummaryTr;
  final String? mostSensitiveFactorTr;

  factory MarineExplainability.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const MarineExplainability();
    return MarineExplainability(
      positiveFactors: _asStringList(json['positive_factors']),
      negativeFactors: _asStringList(json['negative_factors']),
      uncertaintyFactors: _asStringList(json['uncertainty_factors']),
      explanationSummaryTr: json['explanation_summary_tr'] as String?,
      mostSensitiveFactorTr: json['most_sensitive_factor_tr'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'positive_factors': positiveFactors,
        'negative_factors': negativeFactors,
        'uncertainty_factors': uncertaintyFactors,
        'explanation_summary_tr': explanationSummaryTr,
        'most_sensitive_factor_tr': mostSensitiveFactorTr,
      };
}

class MarineProviderComparisonEntry {
  const MarineProviderComparisonEntry({
    required this.name,
    this.enabled = true,
    this.status = 'unknown',
    this.weight = 0,
    this.confidence = 0,
    this.lastSuccess,
    this.lastFailure,
    this.metricsProvided = const [],
  });

  final String name;
  final bool enabled;
  final String status;
  final double weight;
  final double confidence;
  final String? lastSuccess;
  final String? lastFailure;
  final List<String> metricsProvided;

  factory MarineProviderComparisonEntry.fromJson(Map<String, dynamic> json) {
    return MarineProviderComparisonEntry(
      name: (json['name'] as String?) ?? '',
      enabled: json['enabled'] != false,
      status: (json['status'] as String?) ?? 'unknown',
      weight: _asDouble(json['weight']) ?? 0,
      confidence: _asDouble(json['confidence']) ?? 0,
      lastSuccess: json['last_success'] as String?,
      lastFailure: json['last_failure'] as String?,
      metricsProvided: _asStringList(json['metrics_provided']),
    );
  }
}

class MarineProviderComparison {
  const MarineProviderComparison({
    this.providers = const [],
    this.providerCount = 0,
    this.healthyCount = 0,
    this.overallProviderConfidence = 0,
  });

  final List<MarineProviderComparisonEntry> providers;
  final int providerCount;
  final int healthyCount;
  final double overallProviderConfidence;

  factory MarineProviderComparison.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const MarineProviderComparison();
    final raw = json['providers'];
    final providers = raw is List
        ? raw
            .whereType<Map>()
            .map(
              (e) => MarineProviderComparisonEntry.fromJson(
                Map<String, dynamic>.from(e),
              ),
            )
            .toList(growable: false)
        : const <MarineProviderComparisonEntry>[];
    final summary = _map(json['summary']);
    return MarineProviderComparison(
      providers: providers,
      providerCount: _asInt(summary?['provider_count']) ?? providers.length,
      healthyCount: _asInt(summary?['healthy_count']) ?? 0,
      overallProviderConfidence:
          _asDouble(summary?['overall_provider_confidence']) ?? 0,
    );
  }
}

/// Trim edilmiş last_report snapshot.
class MarineIntelligenceReportSnapshot {
  const MarineIntelligenceReportSnapshot({
    required this.coordinate,
    required this.weather,
    required this.wind,
    required this.marine,
    required this.astronomy,
    required this.fishingScore,
    required this.consensusSummary,
    this.providerComparison,
    this.explainability,
    this.decision,
    this.decisionTimeline = const [],
    this.scenario,
    this.updatedAt = '',
  });

  final MarineCoordinate coordinate;
  final MarineWeatherBlock weather;
  final MarineWindBlock wind;
  final MarineSeaBlock marine;
  final MarineAstronomyBlock astronomy;
  final MarineFishingScore fishingScore;
  final MarineConsensusSummary consensusSummary;
  final MarineProviderComparison? providerComparison;
  final MarineExplainability? explainability;
  final MarineDecision? decision;
  final List<MarineDecisionTimelineItem> decisionTimeline;
  final MarineScenarioBundle? scenario;
  final String updatedAt;

  factory MarineIntelligenceReportSnapshot.fromJson(Map<String, dynamic> json) {
    return MarineIntelligenceReportSnapshot(
      coordinate: MarineCoordinate.fromJson(_map(json['coordinate'])),
      weather: MarineWeatherBlock.fromJson(_map(json['weather'])),
      wind: MarineWindBlock.fromJson(_map(json['wind'])),
      marine: MarineSeaBlock.fromJson(_map(json['marine'])),
      astronomy: MarineAstronomyBlock.fromJson(_map(json['astronomy'])),
      fishingScore: MarineFishingScore.fromJson(_map(json['fishing_score'])),
      consensusSummary:
          MarineConsensusSummary.fromJson(_map(json['consensus_summary'])),
      providerComparison: json['provider_comparison'] != null
          ? MarineProviderComparison.fromJson(
              _map(json['provider_comparison']),
            )
          : null,
      explainability: json['explainability'] != null
          ? MarineExplainability.fromJson(_map(json['explainability']))
          : null,
      decision: json['decision'] != null
          ? MarineDecision.fromJson(_map(json['decision']))
          : null,
      decisionTimeline: _parseDecisionTimeline(json['decision_timeline']),
      scenario: json['scenario'] != null
          ? MarineScenarioBundle.fromJson(_map(json['scenario']))
          : null,
      updatedAt: (json['updated_at'] as String?) ?? '',
    );
  }

  static List<MarineDecisionTimelineItem> _parseDecisionTimeline(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (e) => MarineDecisionTimelineItem.fromJson(
            Map<String, dynamic>.from(e),
          ),
        )
        .toList(growable: false);
  }

  Map<String, dynamic> toJson() => {
        'coordinate': coordinate.toJson(),
        'weather': weather.toJson(),
        'wind': wind.toJson(),
        'marine': marine.toJson(),
        'astronomy': astronomy.toJson(),
        'fishing_score': fishingScore.toJson(),
        'consensus_summary': consensusSummary.toJson(),
        'provider_comparison': providerComparison != null
            ? {'summary': {'overall_provider_confidence': providerComparison!.overallProviderConfidence}}
            : null,
        'explainability': explainability?.toJson(),
        'decision': decision?.toJson(),
        'decision_timeline': decisionTimeline.map((e) => e.toJson()).toList(),
        'scenario': scenario != null
            ? {
                'base_go_score': scenario!.baseGoScore,
                'items': scenario!.items
                    .map(
                      (e) => {
                        'scenario_id': e.scenarioId,
                        'title_tr': e.titleTr,
                        'delta_go_score': e.deltaGoScore,
                        'delta_risk_score': e.deltaRiskScore,
                      },
                    )
                    .toList(),
              }
            : null,
        'updated_at': updatedAt,
      };
}

class MarineIntelligenceReport {
  const MarineIntelligenceReport({
    required this.coordinate,
    required this.weather,
    required this.wind,
    required this.marine,
    required this.astronomy,
    required this.fishingScore,
    required this.consensusSummary,
    this.updatedAt = '',
    this.cacheHit = false,
    this.partialData = false,
    this.providerComparison,
    this.explainability,
    this.tide,
    this.fishActivity,
    this.marineRisk,
    this.marineIndex,
    this.weatherStability,
    this.decision,
    this.scenario,
    this.decisionTimeline = const [],
    this.historical,
    this.trends,
    this.aiComment,
  });

  final MarineCoordinate coordinate;
  final MarineWeatherBlock weather;
  final MarineWindBlock wind;
  final MarineSeaBlock marine;
  final MarineAstronomyBlock astronomy;
  final MarineFishingScore fishingScore;
  final MarineConsensusSummary consensusSummary;
  final String updatedAt;
  final bool cacheHit;
  final bool partialData;
  final MarineProviderComparison? providerComparison;
  final MarineExplainability? explainability;

  final dynamic tide;
  final dynamic fishActivity;
  final dynamic marineRisk;
  final dynamic marineIndex;
  final dynamic weatherStability;
  final MarineDecision? decision;
  final MarineScenarioBundle? scenario;
  final List<MarineDecisionTimelineItem> decisionTimeline;
  final dynamic historical;
  final dynamic trends;
  final MarineAiComment? aiComment;

  factory MarineIntelligenceReport.fromJson(Map<String, dynamic> json) {
    return MarineIntelligenceReport(
      coordinate: MarineCoordinate.fromJson(_map(json['coordinate'])),
      weather: MarineWeatherBlock.fromJson(_map(json['weather'])),
      wind: MarineWindBlock.fromJson(_map(json['wind'])),
      marine: MarineSeaBlock.fromJson(_map(json['marine'])),
      astronomy: MarineAstronomyBlock.fromJson(_map(json['astronomy'])),
      fishingScore: MarineFishingScore.fromJson(_map(json['fishing_score'])),
      consensusSummary:
          MarineConsensusSummary.fromJson(_map(json['consensus_summary'])),
      updatedAt: (json['updated_at'] as String?) ?? '',
      cacheHit: json['cache_hit'] == true,
      partialData: json['partial_data'] == true,
      providerComparison: json['provider_comparison'] != null
          ? MarineProviderComparison.fromJson(
              _map(json['provider_comparison']),
            )
          : null,
      explainability: json['explainability'] != null
          ? MarineExplainability.fromJson(_map(json['explainability']))
          : null,
      tide: json['tide'],
      fishActivity: json['fish_activity'],
      marineRisk: json['marine_risk'],
      marineIndex: json['marine_index'],
      weatherStability: json['weather_stability'],
      decision: json['decision'] != null
          ? MarineDecision.fromJson(_map(json['decision']))
          : null,
      scenario: json['scenario'] != null
          ? MarineScenarioBundle.fromJson(_map(json['scenario']))
          : null,
      decisionTimeline: MarineIntelligenceReportSnapshot._parseDecisionTimeline(
        json['decision_timeline'],
      ),
      historical: json['historical'],
      trends: json['trends'],
      aiComment: json['ai_comment'] != null
          ? MarineAiComment.fromJson(_map(json['ai_comment']))
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'coordinate': coordinate.toJson(),
        'weather': weather.toJson(),
        'wind': wind.toJson(),
        'marine': marine.toJson(),
        'astronomy': astronomy.toJson(),
        'fishing_score': fishingScore.toJson(),
        'consensus_summary': consensusSummary.toJson(),
        'updated_at': updatedAt,
        'cache_hit': cacheHit,
        'partial_data': partialData,
        'explainability': explainability?.toJson(),
        'decision': decision?.toJson(),
        'decision_timeline': decisionTimeline.map((e) => e.toJson()).toList(),
        if (aiComment != null) 'ai_comment': aiComment!.toJson(),
        if (tide != null) 'tide': tide,
        if (historical != null) 'historical': historical,
        if (trends != null) 'trends': trends,
      };

  MarineIntelligenceReportSnapshot toSnapshot() {
    return MarineIntelligenceReportSnapshot(
      coordinate: coordinate,
      weather: weather,
      wind: wind,
      marine: marine,
      astronomy: astronomy,
      fishingScore: fishingScore,
      consensusSummary: consensusSummary,
      providerComparison: providerComparison,
      explainability: explainability,
      decision: decision,
      decisionTimeline: decisionTimeline,
      scenario: scenario,
      updatedAt: updatedAt,
    );
  }
}

Map<String, dynamic>? _map(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return null;
}

double? _asDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

List<String> _asStringList(dynamic v) {
  if (v is! List) return const [];
  return v.map((e) => e.toString()).toList(growable: false);
}
