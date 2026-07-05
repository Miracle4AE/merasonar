import 'dart:math' as math;

import '../api_service.dart';

/// Canlı alan ekranından AI isteği için `live_context` JSON'u üretir.
Map<String, dynamic> buildLiveAiContext({
  required double currentLat,
  required double currentLon,
  required LiveFishingScoreResponse liveScore,
  required String coordinateMode,
  double? gpsAccuracyM,
}) {
  final nearest = liveScore.nearestHotspot;
  final bearing = nearest != null && nearest.latitude.isFinite && nearest.longitude.isFinite
      ? _bearingDeg(
          fromLat: currentLat,
          fromLon: currentLon,
          toLat: nearest.latitude,
          toLon: nearest.longitude,
        )
      : null;

  return {
    'current_lat': currentLat,
    'current_lon': currentLon,
    if (gpsAccuracyM != null && gpsAccuracyM.isFinite)
      'gps_accuracy_m': gpsAccuracyM,
    'live_score': liveScore.liveScore,
    'rating': liveScore.rating,
    if (liveScore.reasoning.trim().isNotEmpty) 'reasoning': liveScore.reasoning.trim(),
    'coordinate_mode': coordinateMode.trim(),
    if (nearest?.id != null) 'nearest_hotspot': nearest!.id,
    if (nearest != null) 'distance_to_nearest': nearest.distanceM,
    if (bearing != null && bearing.isFinite) 'bearing_to_nearest': bearing,
  };
}

/// Cache anahtarı için stabil live_context özeti.
String liveAiContextFingerprint(Map<String, dynamic> liveContext) {
  final keys = liveContext.keys.toList()..sort();
  final buffer = StringBuffer();
  for (final k in keys) {
    buffer
      ..write(k)
      ..write('=')
      ..write(liveContext[k])
      ..write(';');
  }
  return buffer.toString();
}

double _bearingDeg({
  required double fromLat,
  required double fromLon,
  required double toLat,
  required double toLon,
}) {
  final phi1 = fromLat * math.pi / 180.0;
  final phi2 = toLat * math.pi / 180.0;
  final dLambda = (toLon - fromLon) * math.pi / 180.0;
  final y = math.sin(dLambda) * math.cos(phi2);
  final x = math.cos(phi1) * math.sin(phi2) -
      math.sin(phi1) * math.cos(phi2) * math.cos(dLambda);
  var brng = math.atan2(y, x) * 180.0 / math.pi;
  return (brng + 360.0) % 360.0;
}
