import 'package:deniz_app/api_service.dart';
import 'package:deniz_app/domain/world_map_hotspot_layout.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

Hotspot _hs(
  int id,
  double lat,
  double lon,
  double score, {
  int recommendationRank = 999999,
}) {
  return Hotspot.fromJson(<String, dynamic>{
    'id': id,
    'feature_type': 'drop_off',
    'rank_overall': id,
    'rank_by_proximity': id,
    'rank_by_score_then_distance': id,
    'latitude': lat,
    'longitude': lon,
    'geo_coordinate': {'lat': lat, 'lon': lon},
    'classification': 'A',
    'reasoning': <String>['x'],
    'score': score,
    'recommendation_rank': recommendationRank,
  });
}

void main() {
  group('topGeoHotspotIdsForBoatAnchorPolicy', () {
    test('ilk üç geçerli geo id döner', () {
      final list = [
        _hs(1, 36.0, 27.0, 0.9),
        _hs(2, 36.01, 27.01, 0.85),
        _hs(3, 36.02, 27.02, 0.8),
        _hs(4, 36.03, 27.03, 0.7),
      ];
      final ids = topGeoHotspotIdsForBoatAnchorPolicy(list, 3);
      expect(ids.length, 3);
      expect(ids.contains(1), isTrue);
      expect(ids.contains(2), isTrue);
      expect(ids.contains(3), isTrue);
    });
  });

  group('layoutWorldMapHotspotsResolved boat_anchor_estimatedPolicy', () {
    test(
        'boat_anchor_estimatedPolicy: viewport dışında kalsa da ilk 3 tekil kalır',
        () {
      final candidates = [
        _hs(10, 41.0, 29.0, 0.35, recommendationRank: 99),
        _hs(11, 41.02, 29.02, 0.34, recommendationRank: 99),
        _hs(12, 41.04, 29.04, 0.33, recommendationRank: 99),
      ];
      final pin = topGeoHotspotIdsForBoatAnchorPolicy(candidates, 3);
      bool vp(double lat, double lon) =>
          lat > 39 && lat < 40 && lon > 28 && lon < 30;

      final res = layoutWorldMapHotspotsResolved(
        candidates: candidates,
        mapZoom: 8,
        viewportContains: vp,
        pinAsSingleHotspotIds: pin,
        forceIncludeHotspotIds: pin,
        boatAnchorEstimatedPolicy: true,
      );

      expect(res.placements.length, greaterThanOrEqualTo(3));
      expect(res.hiddenByViewportFilter, 0);
      expect(res.droppedByMinScore, 0);
    });

    test('min skor düşük olsa bile boat_anchorPolicy ile elenmez', () {
      final candidates = [
        _hs(20, 40.1, 28.9, 0.05),
      ];
      final pin = <int>{20};
      final res = layoutWorldMapHotspotsResolved(
        candidates: candidates,
        mapZoom: 8,
        viewportContains: null,
        pinAsSingleHotspotIds: pin,
        forceIncludeHotspotIds: pin,
        boatAnchorEstimatedPolicy: true,
      );
      expect(res.placements.length, 1);
      expect(res.droppedByMinScore, 0);
    });
  });

  group('boatAnchorEmergencyWorldMapHotspots', () {
    test('hotspot_geo_count > 0 => listed en az bir geo (render > 0)', () {
      final list = [_hs(1, 40.2, 28.4, 0.1)];
      final out = boatAnchorEmergencyWorldMapHotspots(
        list,
        14,
        (a, b) => a.id.compareTo(b.id),
      );
      expect(out.length, 1);
      expect(hotspotHasPlausibleWorldMapGeo(out.single), isTrue);
    });

    test('en fazla 14 marker adayı', () {
      final list = List.generate(
        20,
        (i) => _hs(i, 40.0 + i * 0.02, 28.0 + i * 0.02, 0.5),
      );
      final out = boatAnchorEmergencyWorldMapHotspots(
        list,
        14,
        (a, b) => a.id.compareTo(b.id),
      );
      expect(out.length, 14);
    });

    test('camera fit: bounds geo noktalarını kapsar', () {
      final pts = [
        LatLng(40.0, 28.0),
        LatLng(41.0, 29.0),
      ];
      final b = LatLngBounds.fromPoints(pts);
      expect(b.contains(pts.first), isTrue);
      expect(b.contains(pts.last), isTrue);
    });
  });

}
