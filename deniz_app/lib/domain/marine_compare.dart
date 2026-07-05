/// Marine Compare — iki nokta karşılaştırma modelleri.

library;

import 'marine_intelligence_report.dart';

class MarineCompareSide {
  const MarineCompareSide({
    this.lat,
    this.lon,
    this.spotId,
    this.label,
  });

  final double? lat;
  final double? lon;
  final String? spotId;
  final String? label;

  Map<String, dynamic> toJson() => {
        if (spotId != null) 'spot_id': spotId,
        if (lat != null) 'lat': lat,
        if (lon != null) 'lon': lon,
        if (label != null && label!.trim().isNotEmpty) 'label': label!.trim(),
      };
}

class MarineComparison {
  const MarineComparison({
    required this.winner,
    this.winnerLabel,
    this.scoreDelta = 0,
    this.riskDelta = 0,
    this.confidenceDelta = 0,
    this.decisionDeltaTr = '',
    this.mainReasons = const [],
    this.riskNoteTr,
    this.summaryTr = '',
  });

  final String winner;
  final String? winnerLabel;
  final int scoreDelta;
  final int riskDelta;
  final int confidenceDelta;
  final String decisionDeltaTr;
  final List<String> mainReasons;
  final String? riskNoteTr;
  final String summaryTr;

  bool get isTie => winner == 'tie';

  factory MarineComparison.fromJson(Map<String, dynamic> json) {
    final reasonsRaw = json['main_reasons'];
    final reasons = reasonsRaw is List
        ? reasonsRaw.map((e) => e.toString()).toList(growable: false)
        : const <String>[];
    return MarineComparison(
      winner: (json['winner'] as String?) ?? 'tie',
      winnerLabel: json['winner_label'] as String?,
      scoreDelta: _asInt(json['score_delta']) ?? 0,
      riskDelta: _asInt(json['risk_delta']) ?? 0,
      confidenceDelta: _asInt(json['confidence_delta']) ?? 0,
      decisionDeltaTr: (json['decision_delta_tr'] as String?) ?? '',
      mainReasons: reasons,
      riskNoteTr: json['risk_note_tr'] as String?,
      summaryTr: (json['summary_tr'] as String?) ?? '',
    );
  }
}

class MarineCompareResponse {
  const MarineCompareResponse({
    required this.leftReport,
    required this.rightReport,
    required this.comparison,
    this.captainComment,
    required this.updatedAt,
  });

  final MarineIntelligenceReport leftReport;
  final MarineIntelligenceReport rightReport;
  final MarineComparison comparison;
  final MarineAiComment? captainComment;
  final String updatedAt;

  factory MarineCompareResponse.fromJson(Map<String, dynamic> json) {
    MarineAiComment? captain;
    final rawCaptain = json['captain_comment'];
    if (rawCaptain is Map) {
      captain = MarineAiComment.fromJson(Map<String, dynamic>.from(rawCaptain));
    }
    return MarineCompareResponse(
      leftReport: MarineIntelligenceReport.fromJson(
        Map<String, dynamic>.from(json['left_report'] as Map? ?? {}),
      ),
      rightReport: MarineIntelligenceReport.fromJson(
        Map<String, dynamic>.from(json['right_report'] as Map? ?? {}),
      ),
      comparison: MarineComparison.fromJson(
        Map<String, dynamic>.from(json['comparison'] as Map? ?? {}),
      ),
      captainComment: captain,
      updatedAt: (json['updated_at'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'left_report': leftReport.toJson(),
        'right_report': rightReport.toJson(),
        'comparison': {
          'winner': comparison.winner,
          'winner_label': comparison.winnerLabel,
          'score_delta': comparison.scoreDelta,
          'risk_delta': comparison.riskDelta,
          'confidence_delta': comparison.confidenceDelta,
          'decision_delta_tr': comparison.decisionDeltaTr,
          'main_reasons': comparison.mainReasons,
          'risk_note_tr': comparison.riskNoteTr,
          'summary_tr': comparison.summaryTr,
        },
        if (captainComment != null) 'captain_comment': captainComment!.toJson(),
        'updated_at': updatedAt,
      };
}

int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}
