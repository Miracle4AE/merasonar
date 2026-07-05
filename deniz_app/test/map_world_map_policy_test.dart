import 'package:flutter_test/flutter_test.dart';

import 'package:deniz_app/api_service.dart';
import 'package:deniz_app/utils/map_world_map_policy.dart';

void main() {
  test('boatStateHasPlausibleGps rejects null island', () {
    final boatBad = BoatState(
      rawGps: LatLon(lat: 0, lon: 0),
      smoothedGps: LatLon(lat: 0, lon: 0),
      navigationAnchorGeo: null,
      boatPixelAnchor: null,
      boatAnchorConfidence: 0,
      boatAnchorSource: 'image_center',
    );
    expect(boatStateHasPlausibleGps(boatBad), isFalse);
    final boatOk = BoatState(
      rawGps: LatLon(lat: 0, lon: 0),
      smoothedGps: LatLon(lat: 37.4, lon: 27.2),
      navigationAnchorGeo: null,
      boatPixelAnchor: null,
      boatAnchorConfidence: 0,
      boatAnchorSource: 'image_center',
    );
    expect(boatStateHasPlausibleGps(boatOk), isTrue);
  });

  test('world map hides hotspots when geo display not allowed', () {
    expect(
      shouldHideGeoHotspotsOnWorldMap(
        geoMapDisplayAllowed: false,
        isWorldMap: true,
      ),
      isTrue,
    );
    expect(
      shouldHideGeoHotspotsOnWorldMap(
        geoMapDisplayAllowed: false,
        isWorldMap: false,
      ),
      isFalse,
    );
    expect(
      shouldHideGeoHotspotsOnWorldMap(
        geoMapDisplayAllowed: true,
        isWorldMap: true,
      ),
      isFalse,
    );
  });
}
