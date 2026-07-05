import 'package:deniz_app/api_service.dart';

const int _kMaxAiHotspots = 15;
const int _kMaxReasoningItems = 3;
const int _kMaxSpecies = 3;
const int _kMaxMetricKeys = 5;

const _imageSpaceModes = {'image_space', 'unknown'};

/// Backend `AnalysisPayloadModel` ile uyumlu, sadeleştirilmiş analiz JSON'u.
extension FishingZoneAiPayload on FishingZoneResponse {
  Map<String, dynamic> toAiAnalysisJson() {
    final mode = (coordinateMode ?? kCoordinateModeUnknown).trim().toLowerCase();
    final stripGeo = _imageSpaceModes.contains(mode);

    return {
      'coordinate_mode': mode,
      if (calibrationQuality != null)
        'calibration_quality': calibrationQuality,
      if (calibrationReliability != null &&
          calibrationReliability!.trim().isNotEmpty)
        'calibration_reliability': calibrationReliability!.trim(),
      if (userWarningTr != null && userWarningTr!.trim().isNotEmpty)
        'user_warning_tr': userWarningTr!.trim(),
      if (sessionAdvice != null && sessionAdvice!.trim().isNotEmpty)
        'session_advice': sessionAdvice!.trim(),
      if (topRecommendationIds.isNotEmpty)
        'top_recommendations': List<int>.from(topRecommendationIds),
      if (imageSize.isNotEmpty) 'image_size': Map<String, int>.from(imageSize),
      'boat': _boatPayload(boat),
      'diagnostics': _diagnosticsPayload(diagnostics),
      'hotspots': _hotspotsPayload(hotspots, stripGeo: stripGeo),
    };
  }

  /// İstemci önbellek anahtarı — backend fingerprint ile aynı mantık (prompt hariç).
  String aiAnalysisFingerprint({String scope = 'session_summary'}) {
    final payload = toAiAnalysisJson();
    final hotspots = payload['hotspots'];
    final hsList = hotspots is List ? hotspots : const [];
    final buffer = StringBuffer()
      ..write(scope)
      ..write('|')
      ..write(payload['coordinate_mode'])
      ..write('|')
      ..write(payload['session_advice'])
      ..write('|')
      ..write(payload['top_recommendations'])
      ..write('|');
    for (final item in hsList) {
      if (item is Map) {
        buffer
          ..write(item['id'])
          ..write(':')
          ..write(item['score'])
          ..write(':')
          ..write(item['classification'])
          ..write(':')
          ..write(item['recommendation_rank'])
          ..write(';');
      }
    }
    return buffer.toString();
  }
}

Map<String, dynamic>? _boatPayload(BoatState boat) {
  final out = <String, dynamic>{};
  if (boat.smoothedGps.lat != 0 || boat.smoothedGps.lon != 0) {
    out['smoothed_gps'] = boat.smoothedGps.toJson();
  }
  if (boat.boatAnchorConfidence > 0) {
    out['boat_anchor_confidence'] = boat.boatAnchorConfidence;
  }
  return out.isEmpty ? null : out;
}

Map<String, dynamic>? _diagnosticsPayload(AnalysisDiagnostics diag) {
  final out = <String, dynamic>{};
  if (diag.mappingMode.isNotEmpty) {
    out['mapping_mode'] = diag.mappingMode;
  }
  if (diag.enrichmentScope != null && diag.enrichmentScope!.isNotEmpty) {
    out['enrichment_enabled'] = diag.enrichmentScope != 'unavailable_no_gps';
  }
  if (diag.transformQuality.isFinite) {
    out['transform_quality'] = diag.transformQuality;
  }
  if (diag.georeferenceError.isFinite) {
    out['georeference_error_m'] = diag.georeferenceError;
  }
  return out.isEmpty ? null : out;
}

List<Map<String, dynamic>> _hotspotsPayload(
  List<Hotspot> hotspots, {
  required bool stripGeo,
}) {
  final ordered = _orderedHotspots(hotspots);
  return ordered
      .map((h) => _hotspotItem(h, stripGeo: stripGeo))
      .toList(growable: false);
}

List<Hotspot> _orderedHotspots(List<Hotspot> hotspots) {
  if (hotspots.isEmpty) return const [];
  final sorted = List<Hotspot>.from(hotspots)
    ..sort((a, b) {
      final ar = a.recommendationRank;
      final br = b.recommendationRank;
      final cmp = ar.compareTo(br);
      if (cmp != 0) return cmp;
      return b.score.compareTo(a.score);
    });
  return sorted.take(_kMaxAiHotspots).toList(growable: false);
}

Map<String, dynamic> _hotspotItem(Hotspot h, {required bool stripGeo}) {
  final out = <String, dynamic>{
    'id': h.id,
    'classification': h.classification,
    'score': h.score,
    'feature_type': h.featureType,
    'recommendation_rank': h.recommendationRank,
    'final_fishing_score': h.finalFishingScore,
    if (h.distanceM > 0) 'distance_m': h.distanceM,
    if (h.bearingDeg.isFinite) 'bearing_deg': h.bearingDeg,
    'reasoning': h.reasoning.take(_kMaxReasoningItems).toList(growable: false),
    if (h.reasoningText.isNotEmpty) 'reasoning_text': h.reasoningText,
    if (h.fishPrediction.isNotEmpty) 'fish_prediction': h.fishPrediction,
    if (h.speciesMatch.isNotEmpty)
      'species_match': h.speciesMatch
          .take(_kMaxSpecies)
          .map((s) => s.toJson())
          .toList(growable: false),
    'sea_state': _seaStateItem(h.seaState),
    'supporting_metrics': _trimMetrics(h.supportingMetrics),
  };
  if (!stripGeo && h.latitude.isFinite && h.longitude.isFinite) {
    out['latitude'] = h.latitude;
    out['longitude'] = h.longitude;
  }
  return out;
}

Map<String, dynamic> _seaStateItem(SeaState sea) {
  final out = <String, dynamic>{};
  if (sea.waveHeightM != null) out['wave_height_m'] = sea.waveHeightM;
  if (sea.waterTemperatureC != null) {
    out['water_temperature_c'] = sea.waterTemperatureC;
  }
  if (sea.windSpeedKnots != null) out['wind_speed_knots'] = sea.windSpeedKnots;
  if (sea.source.isNotEmpty && sea.source != 'unknown') {
    out['source'] = sea.source;
  }
  return out;
}

Map<String, dynamic> _trimMetrics(Map<String, dynamic> metrics) {
  if (metrics.isEmpty) return const {};
  final numeric = <MapEntry<String, double>>[];
  for (final entry in metrics.entries) {
    final v = entry.value;
    if (v is num) {
      numeric.add(MapEntry(entry.key, v.toDouble()));
    }
  }
  numeric.sort((a, b) => b.value.abs().compareTo(a.value.abs()));
  return Map.fromEntries(numeric.take(_kMaxMetricKeys));
}
