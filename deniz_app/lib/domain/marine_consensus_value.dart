/// Marine Intelligence consensus değeri — güvenli JSON parse.

library;

class MarineConsensusValue {
  const MarineConsensusValue({
    this.finalValue,
    this.unit,
    this.providerValues = const {},
    this.confidence = 0,
    this.sourceCount = 0,
    this.disagreementLevel = 'unknown',
    this.minValue,
    this.maxValue,
    this.meanValue,
  });

  final double? finalValue;
  final String? unit;
  final Map<String, double?> providerValues;
  final double confidence;
  final int sourceCount;
  final String disagreementLevel;
  final double? minValue;
  final double? maxValue;
  final double? meanValue;

  bool get hasValue => finalValue != null;

  factory MarineConsensusValue.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const MarineConsensusValue();
    final pv = <String, double?>{};
    final raw = json['provider_values'];
    if (raw is Map) {
      for (final e in raw.entries) {
        pv[e.key.toString()] = _asDouble(e.value);
      }
    }
    return MarineConsensusValue(
      finalValue: _asDouble(json['final_value']),
      unit: json['unit'] as String?,
      providerValues: pv,
      confidence: _asDouble(json['confidence']) ?? 0,
      sourceCount: _asInt(json['source_count']) ?? 0,
      disagreementLevel: (json['disagreement_level'] as String?) ?? 'unknown',
      minValue: _asDouble(json['min_value']),
      maxValue: _asDouble(json['max_value']),
      meanValue: _asDouble(json['mean_value']),
    );
  }

  Map<String, dynamic> toJson() => {
        'final_value': finalValue,
        'unit': unit,
        'provider_values': providerValues,
        'confidence': confidence,
        'source_count': sourceCount,
        'disagreement_level': disagreementLevel,
        'min_value': minValue,
        'max_value': maxValue,
        'mean_value': meanValue,
      };
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
