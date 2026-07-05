import 'package:deniz_app/utils/geo_control_point_layout.dart';
import 'package:deniz_app/utils/navionics_coordinate_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deniz_app/api_service.dart';

void main() {
  group('NavionicsCoordinateParser', () {
    test('parses degrees + decimal minutes with hemisphere', () {
      expect(
        parseNavionicsCoordinate("37°24.252' N", isLatitude: true),
        closeTo(37.4042, 0.0001),
      );
      expect(
        parseNavionicsCoordinate("027°13.632' E", isLatitude: false),
        closeTo(27.2272, 0.0001),
      );
    });

    test('parses plain decimal degrees', () {
      expect(
        parseNavionicsCoordinate('37.4042', isLatitude: true),
        closeTo(37.4042, 0.0001),
      );
      expect(
        parseNavionicsCoordinate('27,2272', isLatitude: false),
        closeTo(27.2272, 0.0001),
      );
    });

    test('formats back to Navionics style', () {
      expect(
        formatNavionicsCoordinate(37.4042, isLatitude: true),
        "37°24.252' N",
      );
      expect(
        formatNavionicsCoordinate(27.2272, isLatitude: false),
        "027°13.632' E",
      );
    });

    test('formats digits to Navionics entry text', () {
      expect(
        formatNavionicsEntryFromDigits('3724252', isLatitude: true),
        "37°24.252' N",
      );
      expect(
        formatNavionicsEntryFromDigits('02713632', isLatitude: false),
        "027°13.632' E",
      );
      expect(
        formatNavionicsEntryFromDigits('37', isLatitude: true),
        '37°',
      );
    });

    test('round-trip entry digits from decimal', () {
      final digits = decimalToNavionicsEntryDigits(37.4042, isLatitude: true);
      expect(
        formatNavionicsEntryFromDigits(digits, isLatitude: true),
        "37°24.252' N",
      );
    });

    test('rejects out-of-range latitude', () {
      final result = parseNavionicsCoordinateDetailed('95°00.000\' N', isLatitude: true);
      expect(result.isOk, isFalse);
    });
  });

  group('layoutControlPointsFromGeo', () {
    test('assigns NW/SE corners and spreads third reference', () {
      final points = layoutControlPointsFromGeo(
        geoPoints: [
          LatLon(lat: 37.4042, lon: 27.1975),
          LatLon(lat: 37.3663, lon: 27.2272),
          LatLon(lat: 37.3850, lon: 27.2120),
        ],
        imageWidth: 400,
        imageHeight: 300,
      );
      expect(points.length, 3);
      expect(points[0].pixelX, 0);
      expect(points[0].pixelY, 0);
      expect(points[1].pixelX, 399);
      expect(points[1].pixelY, 299);
      expect(points[2].pixelX, greaterThan(0));
      expect(points[2].pixelX, lessThan(399));
      expect(points[2].pixelY, greaterThan(0));
      expect(points[2].pixelY, lessThan(299));
    });

    test('swapped corner entries map to correct screen corners', () {
      final points = layoutControlPointsFromGeo(
        geoPoints: [
          LatLon(lat: 37.3663, lon: 27.2272),
          LatLon(lat: 37.4042, lon: 27.1975),
          LatLon(lat: 37.3850, lon: 27.2120),
        ],
        imageWidth: 400,
        imageHeight: 300,
      );
      expect(points.length, 3);
      expect(points[0].pixelX, 399);
      expect(points[0].pixelY, 299);
      expect(points[1].pixelX, 0);
      expect(points[1].pixelY, 0);
    });

    test('mergeControlPointsWithManualPixels prefers manual pixels', () {
      final geo = [
        LatLon(lat: 37.4042, lon: 27.1975),
        LatLon(lat: 37.3663, lon: 27.2272),
        LatLon(lat: 37.3850, lon: 27.2120),
      ];
      final merged = mergeControlPointsWithManualPixels(
        geoPoints: geo,
        manualPixels: [
          (pixelX: 42.0, pixelY: 18.0),
          (pixelX: null, pixelY: null),
          (pixelX: 210.0, pixelY: 150.0),
        ],
        imageWidth: 400,
        imageHeight: 300,
      );
      expect(merged[0].pixelX, 42.0);
      expect(merged[0].pixelY, 18.0);
      expect(merged[2].pixelX, 210.0);
    });

    test('scaleControlPointsToImageSize scales pixels', () {
      final scaled = scaleControlPointsToImageSize(
        points: [
          ImageControlPoint(pixelX: 0, pixelY: 0, geo: LatLon(lat: 1, lon: 2)),
          ImageControlPoint(
            pixelX: 399,
            pixelY: 299,
            geo: LatLon(lat: 3, lon: 4),
          ),
        ],
        fromWidth: 400,
        fromHeight: 300,
        toWidth: 800,
        toHeight: 600,
      );
      expect(scaled[1].pixelX, closeTo(799, 0.01));
      expect(scaled[1].pixelY, closeTo(599, 0.01));
    });

    test('hotspotIsExtremeGeoOutlier rejects far outliers only', () {
      final bounds = ImageGeoBounds(
        topLeft: LatLon(lat: 37.41, lon: 27.19),
        bottomRight: LatLon(lat: 37.36, lon: 27.23),
      );
      expect(
        hotspotIsExtremeGeoOutlier(
          lat: 37.38,
          lon: 27.21,
          bounds: bounds,
        ),
        isFalse,
      );
      expect(
        hotspotIsExtremeGeoOutlier(
          lat: 15.0,
          lon: 10.0,
          bounds: bounds,
        ),
        isTrue,
      );
    });

    test('layout error only when corners coincide', () {
      expect(
        layoutControlPointsLayoutError([
          LatLon(lat: 37.40, lon: 27.20),
          LatLon(lat: 37.36, lon: 27.20),
          LatLon(lat: 37.38, lon: 27.21),
        ]),
        isNotNull,
      );
      expect(
        layoutControlPointsLayoutError([
          LatLon(lat: 37.4042, lon: 27.2272),
          LatLon(lat: 37.3663, lon: 27.1975),
          LatLon(lat: 37.3850, lon: 27.2120),
        ]),
        isNull,
      );
    });

    test('screenshot coords: SE lon smaller than NW lon still layouts', () {
      final nwLat = parseNavionicsCoordinate("37°24.345' N", isLatitude: true)!;
      final nwLon = parseNavionicsCoordinate("027°13.376' E", isLatitude: false)!;
      final seLat = parseNavionicsCoordinate("37°21.574' N", isLatitude: true)!;
      final seLon = parseNavionicsCoordinate("027°11.552' E", isLatitude: false)!;
      final refLat = parseNavionicsCoordinate("37°22.540' N", isLatitude: true)!;
      final refLon = parseNavionicsCoordinate("027°11.978' E", isLatitude: false)!;

      expect(seLon, lessThan(nwLon));
      expect(
        layoutControlPointsLayoutError([
          LatLon(lat: nwLat, lon: nwLon),
          LatLon(lat: seLat, lon: seLon),
          LatLon(lat: refLat, lon: refLon),
        ]),
        isNull,
      );

      final points = layoutControlPointsFromGeo(
        geoPoints: [
          LatLon(lat: nwLat, lon: nwLon),
          LatLon(lat: seLat, lon: seLon),
          LatLon(lat: refLat, lon: refLon),
        ],
        imageWidth: 800,
        imageHeight: 600,
      );
      expect(points.length, 3);
      expect(points[0].pixelX, 0);
      expect(points[0].pixelY, 0);
      expect(points[1].pixelX, 799);
      expect(points[1].pixelY, 599);
    });
  });
}
