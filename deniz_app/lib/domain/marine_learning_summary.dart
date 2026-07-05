/// Spot öğrenme özeti (Catch Intelligence).

library;

class MarineLearningSummary {
  const MarineLearningSummary({
    required this.spotId,
    this.catchCount = 0,
    this.topSpecies,
    this.lastSuccessDate,
    this.averageWeightKg,
    this.spotReputation,
    this.spotLevel,
    this.messageTr = '',
  });

  final String spotId;
  final int catchCount;
  final String? topSpecies;
  final String? lastSuccessDate;
  final double? averageWeightKg;
  final int? spotReputation;
  final String? spotLevel;
  final String messageTr;

  factory MarineLearningSummary.fromJson(Map<String, dynamic> json) {
    return MarineLearningSummary(
      spotId: (json['spot_id'] as String?) ?? '',
      catchCount: _asInt(json['catch_count']) ?? 0,
      topSpecies: json['top_species'] as String?,
      lastSuccessDate: json['last_success_date'] as String?,
      averageWeightKg: _asDouble(json['average_weight_kg']),
      spotReputation: _asInt(json['spot_reputation']),
      spotLevel: json['spot_level'] as String?,
      messageTr: (json['message_tr'] as String?) ?? '',
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
