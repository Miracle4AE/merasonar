/// Av kaydı (Catch Intelligence) modeli.

library;

import 'marine_learning_summary.dart';

class MarineCatchRecord {
  const MarineCatchRecord({
    required this.id,
    required this.spotId,
    required this.species,
    this.lengthCm,
    this.weightKg,
    this.bait,
    this.method,
    required this.caughtAt,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String spotId;
  final String species;
  final double? lengthCm;
  final double? weightKg;
  final String? bait;
  final String? method;
  final String caughtAt;
  final String? notes;
  final String createdAt;
  final String updatedAt;

  factory MarineCatchRecord.fromJson(Map<String, dynamic> json) {
    return MarineCatchRecord(
      id: (json['id'] as String?) ?? '',
      spotId: (json['spot_id'] as String?) ?? '',
      species: (json['species'] as String?) ?? '',
      lengthCm: _asDouble(json['length_cm']),
      weightKg: _asDouble(json['weight_kg']),
      bait: json['bait'] as String?,
      method: json['method'] as String?,
      caughtAt: (json['caught_at'] as String?) ?? '',
      notes: json['notes'] as String?,
      createdAt: (json['created_at'] as String?) ?? '',
      updatedAt: (json['updated_at'] as String?) ?? '',
    );
  }
}

class MarineCatchListResponse {
  const MarineCatchListResponse({
    required this.catches,
    required this.count,
    required this.summary,
  });

  final List<MarineCatchRecord> catches;
  final int count;
  final MarineLearningSummary summary;

  factory MarineCatchListResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['catches'];
    final catches = raw is List
        ? raw
            .whereType<Map>()
            .map((e) => MarineCatchRecord.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false)
        : const <MarineCatchRecord>[];
    return MarineCatchListResponse(
      catches: catches,
      count: _asInt(json['count']) ?? catches.length,
      summary: MarineLearningSummary.fromJson(
        Map<String, dynamic>.from(json['summary'] as Map? ?? {}),
      ),
    );
  }
}

class MarineCreateCatchResponse {
  const MarineCreateCatchResponse({
    required this.catchRecord,
    required this.summary,
  });

  final MarineCatchRecord catchRecord;
  final MarineLearningSummary summary;

  factory MarineCreateCatchResponse.fromJson(Map<String, dynamic> json) {
    return MarineCreateCatchResponse(
      catchRecord: MarineCatchRecord.fromJson(
        Map<String, dynamic>.from(json['catch'] as Map? ?? {}),
      ),
      summary: MarineLearningSummary.fromJson(
        Map<String, dynamic>.from(json['learning_summary'] as Map? ?? {}),
      ),
    );
  }
}

class MarineUpdateCatchResponse {
  const MarineUpdateCatchResponse({
    required this.catchRecord,
    required this.summary,
  });

  final MarineCatchRecord catchRecord;
  final MarineLearningSummary summary;

  factory MarineUpdateCatchResponse.fromJson(Map<String, dynamic> json) {
    return MarineUpdateCatchResponse(
      catchRecord: MarineCatchRecord.fromJson(
        Map<String, dynamic>.from(json['catch'] as Map? ?? {}),
      ),
      summary: MarineLearningSummary.fromJson(
        Map<String, dynamic>.from(json['learning_summary'] as Map? ?? {}),
      ),
    );
  }
}

class MarineCatchDeleteResponse {
  const MarineCatchDeleteResponse({
    required this.deleted,
    required this.id,
    this.spotId,
    this.summary,
  });

  final bool deleted;
  final String id;
  final String? spotId;
  final MarineLearningSummary? summary;

  factory MarineCatchDeleteResponse.fromJson(Map<String, dynamic> json) {
    MarineLearningSummary? summary;
    final rawSummary = json['learning_summary'];
    if (rawSummary is Map) {
      summary = MarineLearningSummary.fromJson(Map<String, dynamic>.from(rawSummary));
    }
    return MarineCatchDeleteResponse(
      deleted: json['deleted'] == true,
      id: (json['id'] as String?) ?? '',
      spotId: json['spot_id'] as String?,
      summary: summary,
    );
  }
}

class BulkLearningSummariesResponse {
  const BulkLearningSummariesResponse({
    required this.summaries,
    this.missingSpotIds = const [],
  });

  final Map<String, MarineLearningSummary?> summaries;
  final List<String> missingSpotIds;

  factory BulkLearningSummariesResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['summaries'];
    final summaries = <String, MarineLearningSummary?>{};
    if (raw is Map) {
      for (final entry in raw.entries) {
        if (entry.value == null) {
          summaries[entry.key.toString()] = null;
        } else if (entry.value is Map) {
          summaries[entry.key.toString()] = MarineLearningSummary.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          );
        }
      }
    }
    final missingRaw = json['missing_spot_ids'];
    final missing = missingRaw is List
        ? missingRaw.map((e) => e.toString()).toList(growable: false)
        : const <String>[];
    return BulkLearningSummariesResponse(
      summaries: summaries,
      missingSpotIds: missing,
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
