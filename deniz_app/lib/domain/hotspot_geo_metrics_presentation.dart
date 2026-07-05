import 'dart:math' as math;

import '../api_service.dart';
import '../l10n/app_strings_tr.dart';
import 'package:deniz_app/domain/app_settings.dart';
import '../utils/navionics_coordinate_parser.dart';
import 'geo_visualization_state.dart';

/// Hotspot detayında Enlem / Boylam / Mesafe / Kerteriz metinleri — tek politika noktası.
///
/// [coordinate_mode] ve kalibrasyon güvenine göre saysal gösterim veya yer tutucu üretir.
class HotspotGeoMetricsPresentation {
  const HotspotGeoMetricsPresentation({
    required this.latitudeText,
    required this.longitudeText,
    required this.distanceText,
    required this.bearingText,
    required this.isNumericContext,
  });

  final String latitudeText;
  final String longitudeText;
  final String distanceText;
  final String bearingText;

  /// Sunucu/geo politikası saysal değerleri güvenilir sayıyorsa true.
  final bool isNumericContext;

  /// [geoVisualization] harita oturumundan gelir; null ise yalnızca hotspot alanları kullanılır (test/widget).
  factory HotspotGeoMetricsPresentation.fromHotspot(
    Hotspot hotspot, {
    GeoVisualizationState? geoVisualization,
    LatLon? boatPosition,
    CoordinateDisplayFormat coordinateFormat = CoordinateDisplayFormat.dms,
  }) {
    final allowGeo = _geoNumericAllowed(hotspot, geoVisualization);
    final hasLatLon = allowGeo && _hasPlausibleLatLon(hotspot.latitude, hotspot.longitude);

    if (!allowGeo) {
      return HotspotGeoMetricsPresentation(
        latitudeText: kHotspotGeoPlaceholderDash,
        longitudeText: kHotspotGeoPlaceholderDash,
        distanceText: kHotspotGeoDistanceUnavailable,
        bearingText: kHotspotGeoBearingUnavailable,
        isNumericContext: false,
      );
    }

    final latText = hasLatLon
        ? formatCoordinate(hotspot.latitude, isLatitude: true, format: coordinateFormat)
        : kHotspotGeoPlaceholderDash;
    final lonText = hasLatLon
        ? formatCoordinate(hotspot.longitude, isLatitude: false, format: coordinateFormat)
        : kHotspotGeoPlaceholderDash;
    final directDistance = _isPlausibleDistanceMeters(hotspot.distanceM) ? hotspot.distanceM : double.nan;
    final directBearing = _isPlausibleBearingDeg(hotspot.bearingDeg) ? hotspot.bearingDeg : double.nan;

    final boat = boatPosition;
    final canComputeFromBoat =
        hasLatLon && boat != null && _hasPlausibleLatLon(boat.lat, boat.lon);

    final computed = canComputeFromBoat
        ? _distanceAndBearingMetersDeg(
            fromLat: boat.lat,
            fromLon: boat.lon,
            toLat: hotspot.latitude,
            toLon: hotspot.longitude,
          )
        : null;

    final resolvedDistance =
        directDistance.isFinite ? directDistance : (computed?.distanceM ?? double.nan);
    final resolvedBearing =
        directBearing.isFinite ? directBearing : (computed?.bearingDeg ?? double.nan);

    return HotspotGeoMetricsPresentation(
      latitudeText: latText,
      longitudeText: lonText,
      distanceText: formatDistanceMeters(resolvedDistance),
      bearingText: formatBearingDegrees(resolvedBearing),
      isNumericContext: hasLatLon,
    );
  }

  static bool _geoNumericAllowed(
    Hotspot hotspot,
    GeoVisualizationState? geoVisualization,
  ) {
    if (geoVisualization != null) {
      final cm = geoVisualization.coordinateMode;
      if (cm == kCoordinateModeGeoReferenced) {
        if (geoVisualization.reliability == CalibrationReliability.unsafe) {
          return false;
        }
        return true;
      }
      if (cm == kCoordinateModeBoatAnchorEstimated) {
        return true;
      }
      return false;
    }
    return hotspot.mappingTrust != kCoordinateModeImageSpace;
  }

  static String formatLatitudeLongitude(
    double value, {
    required bool isLatitude,
    CoordinateDisplayFormat format = CoordinateDisplayFormat.dms,
  }) =>
      value.isFinite
          ? formatCoordinate(value, isLatitude: isLatitude, format: format)
          : kHotspotGeoPlaceholderDash;

  static String formatCoordinate(
    double value, {
    required bool isLatitude,
    CoordinateDisplayFormat format = CoordinateDisplayFormat.dms,
  }) {
    if (!value.isFinite) return kHotspotGeoPlaceholderDash;
    if (format == CoordinateDisplayFormat.decimal) {
      return '${value.toStringAsFixed(6)}°';
    }
    return formatNavionicsCoordinate(value, isLatitude: isLatitude);
  }
  static String formatDistanceMeters(double meters) => meters.isFinite
      ? '${meters.toStringAsFixed(1)} m'
      : kHotspotGeoDistanceUnavailable;

  static String formatBearingDegrees(double deg) =>
      deg.isFinite ? '${deg.toStringAsFixed(1)}°' : kHotspotGeoBearingUnavailable;

  static bool _hasPlausibleLatLon(double lat, double lon) {
    if (!lat.isFinite || !lon.isFinite) return false;
    if (lat.abs() < 1e-9 && lon.abs() < 1e-9) return false; // 0/0 sentinel
    if (lat < -90 || lat > 90) return false;
    if (lon < -180 || lon > 180) return false;
    return true;
  }

  static bool _isPlausibleDistanceMeters(double m) =>
      m.isFinite && m >= 0.0 && m < 10000000.0;

  static bool _isPlausibleBearingDeg(double d) =>
      d.isFinite && d >= 0.0 && d < 360.0;

  static _DistanceBearing _distanceAndBearingMetersDeg({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
  }) {
    const r = 6371000.0; // meters
    final phi1 = fromLat * math.pi / 180.0;
    final phi2 = toLat * math.pi / 180.0;
    final dPhi = (toLat - fromLat) * math.pi / 180.0;
    final dLambda = (toLon - fromLon) * math.pi / 180.0;

    final a = math.sin(dPhi / 2) * math.sin(dPhi / 2) +
        math.cos(phi1) *
            math.cos(phi2) *
            math.sin(dLambda / 2) *
            math.sin(dLambda / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final distanceM = r * c;

    final y = math.sin(dLambda) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(dLambda);
    var brng = math.atan2(y, x) * 180.0 / math.pi;
    brng = (brng + 360.0) % 360.0;

    return _DistanceBearing(distanceM: distanceM, bearingDeg: brng);
  }
}

class _DistanceBearing {
  const _DistanceBearing({required this.distanceM, required this.bearingDeg});
  final double distanceM;
  final double bearingDeg;
}
