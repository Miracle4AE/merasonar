/// Kayıtlı Spot Intelligence modeli.

library;

import 'marine_intelligence_report.dart';

class MarineSavedSpot {
  const MarineSavedSpot({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    this.note,
    this.favorite = false,
    required this.createdAt,
    required this.updatedAt,
    this.lastReport,
    this.lastReportAt,
    this.visitCount = 0,
    this.personalTags = const [],
    this.aiLearningScore,
    this.lastSuccessDate,
    this.lastSuccessSpecies,
    this.lastSuccessWeight,
    this.preferredFishingStyle,
    this.bottomType,
    this.estimatedDepth,
    this.spotReputation,
    this.spotReputationUpdatedAt,
    this.spotReputationFactors,
  });

  final String id;
  final String name;
  final double lat;
  final double lon;
  final String? note;
  final bool favorite;
  final String createdAt;
  final String updatedAt;
  final MarineIntelligenceReportSnapshot? lastReport;
  final String? lastReportAt;
  final int visitCount;
  final List<String> personalTags;

  final double? aiLearningScore;
  final String? lastSuccessDate;
  final String? lastSuccessSpecies;
  final double? lastSuccessWeight;
  final String? preferredFishingStyle;
  final String? bottomType;
  final double? estimatedDepth;
  final double? spotReputation;
  final String? spotReputationUpdatedAt;
  final List<String>? spotReputationFactors;

  factory MarineSavedSpot.fromJson(Map<String, dynamic> json) {
    MarineIntelligenceReportSnapshot? snapshot;
    final lr = json['last_report'];
    if (lr is Map<String, dynamic>) {
      snapshot = MarineIntelligenceReportSnapshot.fromJson(lr);
    }
    return MarineSavedSpot(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      lat: _asDouble(json['lat']) ?? 0,
      lon: _asDouble(json['lon']) ?? 0,
      note: json['note'] as String?,
      favorite: json['favorite'] == true,
      createdAt: (json['created_at'] as String?) ?? '',
      updatedAt: (json['updated_at'] as String?) ?? '',
      lastReport: snapshot,
      lastReportAt: json['last_report_at'] as String?,
      visitCount: _asInt(json['visit_count']) ?? 0,
      personalTags: _asStringList(json['personal_tags']),
      aiLearningScore: _asDouble(json['ai_learning_score']),
      lastSuccessDate: json['last_success_date'] as String?,
      lastSuccessSpecies: json['last_success_species'] as String?,
      lastSuccessWeight: _asDouble(json['last_success_weight']),
      preferredFishingStyle: json['preferred_fishing_style'] as String?,
      bottomType: json['bottom_type'] as String?,
      estimatedDepth: _asDouble(json['estimated_depth']),
      spotReputation: _asDouble(json['spot_reputation']),
      spotReputationUpdatedAt: json['spot_reputation_updated_at'] as String?,
      spotReputationFactors: _asStringListNullable(json['spot_reputation_factors']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'lat': lat,
        'lon': lon,
        'note': note,
        'favorite': favorite,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'last_report': lastReport?.toJson(),
        'last_report_at': lastReportAt,
        'visit_count': visitCount,
        'personal_tags': personalTags,
        'ai_learning_score': aiLearningScore,
        'last_success_date': lastSuccessDate,
        'last_success_species': lastSuccessSpecies,
        'last_success_weight': lastSuccessWeight,
        'preferred_fishing_style': preferredFishingStyle,
        'bottom_type': bottomType,
        'estimated_depth': estimatedDepth,
        'spot_reputation': spotReputation,
        'spot_reputation_updated_at': spotReputationUpdatedAt,
        'spot_reputation_factors': spotReputationFactors,
      };
}

class MarineSavedSpotListResponse {
  const MarineSavedSpotListResponse({
    required this.spots,
    required this.count,
  });

  final List<MarineSavedSpot> spots;
  final int count;

  factory MarineSavedSpotListResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['spots'];
    final spots = raw is List
        ? raw
            .whereType<Map>()
            .map((e) => MarineSavedSpot.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false)
        : const <MarineSavedSpot>[];
    return MarineSavedSpotListResponse(
      spots: spots,
      count: _asInt(json['count']) ?? spots.length,
    );
  }
}

class MarineSpotRefreshResponse {
  const MarineSpotRefreshResponse({
    required this.spot,
    required this.report,
  });

  final MarineSavedSpot spot;
  final MarineIntelligenceReport report;

  factory MarineSpotRefreshResponse.fromJson(Map<String, dynamic> json) {
    return MarineSpotRefreshResponse(
      spot: MarineSavedSpot.fromJson(
        Map<String, dynamic>.from(json['spot'] as Map? ?? {}),
      ),
      report: MarineIntelligenceReport.fromJson(
        Map<String, dynamic>.from(json['report'] as Map? ?? {}),
      ),
    );
  }
}

class MarineSpotDeleteResponse {
  const MarineSpotDeleteResponse({
    required this.deleted,
    required this.id,
    this.deletedCatches = 0,
  });

  final bool deleted;
  final String id;
  final int deletedCatches;

  factory MarineSpotDeleteResponse.fromJson(Map<String, dynamic> json) {
    return MarineSpotDeleteResponse(
      deleted: json['deleted'] == true,
      id: (json['id'] as String?) ?? '',
      deletedCatches: _asInt(json['deleted_catches']) ?? 0,
    );
  }
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

List<String>? _asStringListNullable(dynamic v) {
  if (v == null) return null;
  if (v is! List) return const [];
  return v.map((e) => e.toString()).toList(growable: false);
}
