import 'package:deniz_app/api_service.dart';
import 'package:deniz_app/domain/live_ai_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buildLiveAiContext includes required fields', () {
    final ctx = buildLiveAiContext(
      currentLat: 37.0,
      currentLon: 27.0,
      gpsAccuracyM: 8.5,
      coordinateMode: kCoordinateModeGeoReferenced,
      liveScore: LiveFishingScoreResponse(
        liveScore: 75,
        rating: 'Good',
        reasoning: 'Canlı skor test',
        trustNote: 'Not',
        nearestHotspot: LiveNearestHotspot(
          id: 10,
          distanceM: 120.0,
          recommendationRank: 1,
          latitude: 37.01,
          longitude: 27.01,
        ),
      ),
    );

    expect(ctx['current_lat'], 37.0);
    expect(ctx['current_lon'], 27.0);
    expect(ctx['gps_accuracy_m'], 8.5);
    expect(ctx['live_score'], 75);
    expect(ctx['nearest_hotspot'], 10);
    expect(ctx['distance_to_nearest'], 120.0);
    expect(ctx['coordinate_mode'], kCoordinateModeGeoReferenced);
    expect(ctx.containsKey('bearing_to_nearest'), isTrue);
  });
}
