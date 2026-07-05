import 'dart:convert';

import 'package:deniz_app/api_service.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _minimalResponse({
  Object? rankedHotspots,
  String? coordinateMode,
}) {
  return <String, dynamic>{
    'boat': {
      'raw_gps': {'lat': 37.35, 'lon': 27.2},
      'smoothed_gps': {'lat': 37.351, 'lon': 27.201},
    },
    'coordinate_mode': ?coordinateMode,
    'ranked_hotspots':
        rankedHotspots ??
        <Map<String, dynamic>>[
          {
            'id': 9,
            'feature_type': 'drop_off',
            'rank_overall': 1,
            'rank_by_proximity': 3,
            'rank_by_score_then_distance': 1,
            'latitude': 37.352,
            'longitude': 27.203,
            'geo_coordinate': {'lat': 37.352, 'lon': 27.203},
            'classification': 'A',
            'reasoning': <String>['x'],
          },
        ],
    'image_size': {'width': 800, 'height': 600},
    'diagnostics': <String, dynamic>{},
  };
}

void main() {
  test('liveAreaCoordinateModeFromCache: persisted geo sends geo mode', () {
    final r = FishingZoneResponse.fromJson(
      _minimalResponse(coordinateMode: kCoordinateModeGeoReferenced),
    );
    expect(liveAreaCoordinateModeFromCache(r), kCoordinateModeGeoReferenced);
  });

  test('liveAreaCoordinateModeFromCache: persisted image_space sends image_space',
      () {
    final r = FishingZoneResponse.fromJson(
      _minimalResponse(coordinateMode: kCoordinateModeImageSpace),
    );
    expect(liveAreaCoordinateModeFromCache(r), kCoordinateModeImageSpace);
  });

  test('liveAreaCoordinateModeFromCache: missing coordinate_mode is safe (unknown)',
      () {
    final r = FishingZoneResponse.fromJson(_minimalResponse());
    expect(liveAreaCoordinateModeFromCache(r), kCoordinateModeUnknown);
  });

  test('FishingZoneResponse.toJson always writes coordinate_mode', () {
    final base = FishingZoneResponse.fromJson(_minimalResponse());
    final json = base.toJson();
    expect(json.containsKey('coordinate_mode'), isTrue);
    expect(json['coordinate_mode'], kCoordinateModeUnknown);
  });

  test('withEnsuredCoordinateMode keeps server geo_referenced', () {
    final parsed = FishingZoneResponse.fromJson(
      _minimalResponse(coordinateMode: kCoordinateModeGeoReferenced),
    );
    final ensured = FishingZoneResponse.withEnsuredCoordinateMode(parsed);
    expect(ensured.coordinateMode, kCoordinateModeGeoReferenced);
    expect(ensured.toJson()['coordinate_mode'], kCoordinateModeGeoReferenced);
  });

  test('withEnsuredCoordinateMode uses hint when server omits field', () {
    final parsed = FishingZoneResponse.fromJson(_minimalResponse());
    final ensured = FishingZoneResponse.withEnsuredCoordinateMode(
      parsed,
      fallbackCoordinateModeHint: kCoordinateModeImageSpace,
    );
    expect(ensured.coordinateMode, kCoordinateModeImageSpace);
  });

  test(
      'withEnsuredCoordinateMode öncelik: diagnostics.output_coordinate_mode (köksüz)',
      () {
    final parsed = FishingZoneResponse.fromJson(<String, dynamic>{
      'boat': {
        'raw_gps': {'lat': 37.35, 'lon': 27.2},
        'smoothed_gps': {'lat': 37.351, 'lon': 27.201},
      },
      'ranked_hotspots': <Map<String, dynamic>>[
        {
          'id': 9,
          'feature_type': 'drop_off',
          'rank_overall': 1,
          'rank_by_proximity': 3,
          'rank_by_score_then_distance': 1,
          'latitude': 37.352,
          'longitude': 27.203,
          'geo_coordinate': {'lat': 37.352, 'lon': 27.203},
          'classification': 'A',
          'reasoning': <String>['x'],
        },
      ],
      'image_size': {'width': 800, 'height': 600},
      'diagnostics': <String, dynamic>{
        'output_coordinate_mode': kCoordinateModeBoatAnchorEstimated,
      },
    });
    final ensured = FishingZoneResponse.withEnsuredCoordinateMode(parsed);
    expect(ensured.coordinateMode, kCoordinateModeBoatAnchorEstimated);
  });

  test('round-trip jsonEncode preserves coordinate_mode', () {
    final parsed = FishingZoneResponse.fromJson(
      _minimalResponse(coordinateMode: kCoordinateModeGeoReferenced),
    );
    final ensured = FishingZoneResponse.withEnsuredCoordinateMode(parsed);
    final back = FishingZoneResponse.fromJson(
      jsonDecode(jsonEncode(ensured.toJson())) as Map<String, dynamic>,
    );
    expect(back.coordinateMode, kCoordinateModeGeoReferenced);
  });
}
