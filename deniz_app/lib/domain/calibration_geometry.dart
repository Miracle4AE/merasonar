import 'dart:math' as math;

import '../api_service.dart';

/// İstemci tarafı kalibrasyon geometrisi güven seviyesi.
enum CalibrationGeometryLevel {
  valid,
  lowConfidence,
  invalid,
}

/// Harita şeridi / politika için birleşik güven bandı.
enum CalibrationConfidenceLevel {
  valid,
  lowConfidence,
  invalid,
  fallbackBoatEstimated,
  uncalibrated,
}

/// Üçgen / nokta dağılımı analiz sonucu.
class CalibrationGeometryAssessment {
  const CalibrationGeometryAssessment({
    required this.level,
    this.triangleAreaM2,
    this.maxEdgeM,
    this.crossTrackSpreadM,
    this.aspectRatio,
    this.reasonCode,
  });

  final CalibrationGeometryLevel level;
  final double? triangleAreaM2;
  final double? maxEdgeM;
  final double? crossTrackSpreadM;
  final double? aspectRatio;
  final String? reasonCode;

  bool get isValid => level == CalibrationGeometryLevel.valid;
  bool get isLowConfidence => level == CalibrationGeometryLevel.lowConfidence;
  bool get isInvalid => level == CalibrationGeometryLevel.invalid;
}

/// Hotspot coğrafi dağılım uyarısı.
class HotspotAlignmentAssessment {
  const HotspotAlignmentAssessment({
    required this.isStringLike,
    this.crossTrackSpreadM,
    this.alongTrackSpreadM,
    this.sampleCount = 0,
  });

  final bool isStringLike;
  final double? crossTrackSpreadM;
  final double? alongTrackSpreadM;
  final int sampleCount;

  static const none = HotspotAlignmentAssessment(isStringLike: false);
}

/// Piksel noktası (görüntü koordinatı).
typedef PixelPoint = ({double x, double y});

/// Yerel metre düzlemi noktası.
typedef LocalPoint = ({double x, double y});

/// İki nokta arası minimum mesafe (m) — duplicate sayılır.
const double kCalibrationDuplicateThresholdM = 8.0;

/// Üçgen alanı bu altında → geçersiz.
const double kCalibrationInvalidMaxAreaM2 = 5000.0;

/// En uzun kenara göre dik yayılım oranı bu altında → geçersiz.
const double kCalibrationInvalidMinSpreadRatio = 0.025;

/// Düşük güven eşiği — ince/uzun üçgenler.
const double kCalibrationLowConfidenceMinSpreadRatio = 0.16;

/// Düşük güven — en-boy oranı eşiği.
const double kCalibrationLowConfidenceMaxAspectRatio = 5.5;

/// Piksel üçgeni — minimum alan (px²).
const double kCalibrationInvalidMinPixelArea = 900.0;

const double kCalibrationLowConfidenceMinPixelSpreadRatio = 0.14;

/// Hotspot hizalama — minimum örnek.
const int kHotspotAlignmentMinCount = 6;

const double kHotspotAlignmentMinAlongTrackM = 800.0;

const double kHotspotAlignmentMaxCrossTrackM = 140.0;

/// Derece → yerel metre (equirectangular, küçük alanlar için yeterli).
LocalPoint latLonToLocalMeters(LatLon point, {required LatLon center}) {
  const metersPerDegLat = 111320.0;
  final metersPerDegLon =
      111320.0 * math.cos(center.lat * math.pi / 180.0);
  return (
    x: (point.lon - center.lon) * metersPerDegLon,
    y: (point.lat - center.lat) * metersPerDegLat,
  );
}

LatLon centerOfLatLons(Iterable<LatLon> points) {
  var sumLat = 0.0;
  var sumLon = 0.0;
  var n = 0;
  for (final p in points) {
    if (!p.lat.isFinite || !p.lon.isFinite) continue;
    sumLat += p.lat;
    sumLon += p.lon;
    n++;
  }
  if (n == 0) return LatLon(lat: 0, lon: 0);
  return LatLon(lat: sumLat / n, lon: sumLon / n);
}

double triangleAreaM2(List<LocalPoint> pts) {
  if (pts.length < 3) return 0;
  final a = pts[0];
  final b = pts[1];
  final c = pts[2];
  return ((b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y)).abs() / 2.0;
}

double maxEdgeLengthM(List<LocalPoint> pts) {
  if (pts.length < 3) return 0;
  double maxEdge = 0;
  for (var i = 0; i < 3; i++) {
    for (var j = i + 1; j < 3; j++) {
      final dx = pts[j].x - pts[i].x;
      final dy = pts[j].y - pts[i].y;
      maxEdge = math.max(maxEdge, math.sqrt(dx * dx + dy * dy));
    }
  }
  return maxEdge;
}

double crossTrackSpreadM({
  required double areaM2,
  required double maxEdgeM,
}) {
  if (maxEdgeM <= 1e-6) return 0;
  return (2.0 * areaM2) / maxEdgeM;
}

double spreadRatio({
  required double areaM2,
  required double maxEdgeM,
}) {
  if (maxEdgeM <= 1e-6) return 0;
  return crossTrackSpreadM(areaM2: areaM2, maxEdgeM: maxEdgeM) / maxEdgeM;
}

double aspectRatioFromTriangle({
  required double areaM2,
  required double maxEdgeM,
}) {
  final cross = crossTrackSpreadM(areaM2: areaM2, maxEdgeM: maxEdgeM);
  if (cross <= 1e-6) return double.infinity;
  return maxEdgeM / cross;
}

CalibrationGeometryAssessment assessGeoTriangle(Iterable<LatLon> geoPoints) {
  final points = geoPoints
      .where((p) => p.lat.isFinite && p.lon.isFinite)
      .toList(growable: false);
  if (points.length < 3) {
    return const CalibrationGeometryAssessment(
      level: CalibrationGeometryLevel.invalid,
      reasonCode: 'insufficient_points',
    );
  }
  final use = points.take(3).toList(growable: false);
  final center = centerOfLatLons(use);
  final local = use.map((p) => latLonToLocalMeters(p, center: center)).toList();

  for (var i = 0; i < local.length; i++) {
    for (var j = i + 1; j < local.length; j++) {
      final dx = local[j].x - local[i].x;
      final dy = local[j].y - local[i].y;
      if (math.sqrt(dx * dx + dy * dy) < kCalibrationDuplicateThresholdM) {
        return const CalibrationGeometryAssessment(
          level: CalibrationGeometryLevel.invalid,
          reasonCode: 'duplicate_geo',
        );
      }
    }
  }

  final area = triangleAreaM2(local);
  final maxEdge = maxEdgeLengthM(local);
  final cross = crossTrackSpreadM(areaM2: area, maxEdgeM: maxEdge);
  final ratio = spreadRatio(areaM2: area, maxEdgeM: maxEdge);
  final aspect = aspectRatioFromTriangle(areaM2: area, maxEdgeM: maxEdge);

  CalibrationGeometryLevel level;
  String? reason;
  if (area < kCalibrationInvalidMaxAreaM2 || ratio < kCalibrationInvalidMinSpreadRatio) {
    level = CalibrationGeometryLevel.invalid;
    reason = area < kCalibrationInvalidMaxAreaM2 ? 'area_too_small' : 'collinear_geo';
  } else if (ratio < kCalibrationLowConfidenceMinSpreadRatio ||
      aspect > kCalibrationLowConfidenceMaxAspectRatio) {
    level = CalibrationGeometryLevel.lowConfidence;
    reason = 'thin_geo_triangle';
  } else {
    level = CalibrationGeometryLevel.valid;
  }

  return CalibrationGeometryAssessment(
    level: level,
    triangleAreaM2: area,
    maxEdgeM: maxEdge,
    crossTrackSpreadM: cross,
    aspectRatio: aspect.isFinite ? aspect : null,
    reasonCode: reason,
  );
}

CalibrationGeometryAssessment assessPixelTriangle(Iterable<PixelPoint> pixels) {
  final pts = pixels.toList(growable: false);
  if (pts.length < 3) {
    return const CalibrationGeometryAssessment(
      level: CalibrationGeometryLevel.invalid,
      reasonCode: 'insufficient_pixels',
    );
  }
  final use = pts.take(3).toList(growable: false);
  final local = use
      .map((p) => (x: p.x, y: p.y))
      .toList(growable: false);

  for (var i = 0; i < local.length; i++) {
    for (var j = i + 1; j < local.length; j++) {
      final dx = local[j].x - local[i].x;
      final dy = local[j].y - local[i].y;
      if (math.sqrt(dx * dx + dy * dy) < 6.0) {
        return const CalibrationGeometryAssessment(
          level: CalibrationGeometryLevel.invalid,
          reasonCode: 'duplicate_pixel',
        );
      }
    }
  }

  final area = triangleAreaM2(local);
  final maxEdge = maxEdgeLengthM(local);
  final ratio = spreadRatio(areaM2: area, maxEdgeM: maxEdge);
  final aspect = aspectRatioFromTriangle(areaM2: area, maxEdgeM: maxEdge);

  CalibrationGeometryLevel level;
  String? reason;
  if (area < kCalibrationInvalidMinPixelArea || ratio < kCalibrationInvalidMinSpreadRatio) {
    level = CalibrationGeometryLevel.invalid;
    reason = area < kCalibrationInvalidMinPixelArea ? 'pixel_area_too_small' : 'collinear_pixel';
  } else if (ratio < kCalibrationLowConfidenceMinPixelSpreadRatio ||
      aspect > kCalibrationLowConfidenceMaxAspectRatio) {
    level = CalibrationGeometryLevel.lowConfidence;
    reason = 'thin_pixel_triangle';
  } else {
    level = CalibrationGeometryLevel.valid;
  }

  return CalibrationGeometryAssessment(
    level: level,
    triangleAreaM2: area,
    maxEdgeM: maxEdge,
    crossTrackSpreadM: crossTrackSpreadM(areaM2: area, maxEdgeM: maxEdge),
    aspectRatio: aspect.isFinite ? aspect : null,
    reasonCode: reason,
  );
}

CalibrationGeometryAssessment assessControlPoints({
  required Iterable<LatLon> geoPoints,
  Iterable<PixelPoint>? pixelPoints,
}) {
  final geo = assessGeoTriangle(geoPoints);
  if (geo.isInvalid) return geo;
  if (pixelPoints == null) return geo;

  final pixel = assessPixelTriangle(pixelPoints);
  if (pixel.isInvalid) return pixel;
  if (geo.isLowConfidence || pixel.isLowConfidence) {
    return CalibrationGeometryAssessment(
      level: CalibrationGeometryLevel.lowConfidence,
      triangleAreaM2: geo.triangleAreaM2,
      maxEdgeM: geo.maxEdgeM,
      crossTrackSpreadM: geo.crossTrackSpreadM,
      aspectRatio: geo.aspectRatio,
      reasonCode: geo.isLowConfidence ? geo.reasonCode : pixel.reasonCode,
    );
  }
  return geo;
}

CalibrationGeometryAssessment assessImageControlPoints(
  Iterable<ImageControlPoint> points,
) {
  final list = points.toList(growable: false);
  if (list.length < 3) {
    return const CalibrationGeometryAssessment(
      level: CalibrationGeometryLevel.invalid,
      reasonCode: 'insufficient_points',
    );
  }
  return assessControlPoints(
    geoPoints: list.map((p) => p.geo),
    pixelPoints: list
        .take(3)
        .map((p) => (x: p.pixelX, y: p.pixelY))
        .toList(growable: false),
  );
}

HotspotAlignmentAssessment assessHotspotGeoAlignment(Iterable<Hotspot> hotspots) {
  final coords = <LocalPoint>[];
  final geoPoints = <LatLon>[];
  for (final h in hotspots) {
    final lat = h.latitude;
    final lon = h.longitude;
    if (!lat.isFinite || !lon.isFinite) continue;
    if (lat.abs() < 1e-6 && lon.abs() < 1e-6) continue;
    if (lat.abs() > 90 || lon.abs() > 180) continue;
    geoPoints.add(LatLon(lat: lat, lon: lon));
  }
  if (geoPoints.length < kHotspotAlignmentMinCount) {
    return HotspotAlignmentAssessment(
      isStringLike: false,
      sampleCount: geoPoints.length,
    );
  }

  final center = centerOfLatLons(geoPoints);
  for (final p in geoPoints) {
    coords.add(latLonToLocalMeters(p, center: center));
  }

  final spread = _principalAxisSpread(coords);
  final isStringLike = spread.alongTrackM >= kHotspotAlignmentMinAlongTrackM &&
      spread.crossTrackM <= kHotspotAlignmentMaxCrossTrackM;

  return HotspotAlignmentAssessment(
    isStringLike: isStringLike,
    crossTrackSpreadM: spread.crossTrackM,
    alongTrackSpreadM: spread.alongTrackM,
    sampleCount: coords.length,
  );
}

({double crossTrackM, double alongTrackM}) _principalAxisSpread(
  List<LocalPoint> points,
) {
  if (points.isEmpty) {
    return (crossTrackM: 0.0, alongTrackM: 0.0);
  }
  var meanX = 0.0;
  var meanY = 0.0;
  for (final p in points) {
    meanX += p.x;
    meanY += p.y;
  }
  meanX /= points.length;
  meanY /= points.length;

  var sxx = 0.0;
  var syy = 0.0;
  var sxy = 0.0;
  for (final p in points) {
    final dx = p.x - meanX;
    final dy = p.y - meanY;
    sxx += dx * dx;
    syy += dy * dy;
    sxy += dx * dy;
  }
  sxx /= points.length;
  syy /= points.length;
  sxy /= points.length;

  final theta = 0.5 * math.atan2(2 * sxy, sxx - syy);
  final cosT = math.cos(theta);
  final sinT = math.sin(theta);

  var minAlong = double.infinity;
  var maxAlong = -double.infinity;
  var minCross = double.infinity;
  var maxCross = -double.infinity;
  for (final p in points) {
    final dx = p.x - meanX;
    final dy = p.y - meanY;
    final along = dx * cosT + dy * sinT;
    final cross = -dx * sinT + dy * cosT;
    minAlong = math.min(minAlong, along);
    maxAlong = math.max(maxAlong, along);
    minCross = math.min(minCross, cross);
    maxCross = math.max(maxCross, cross);
  }

  return (
    crossTrackM: maxCross - minCross,
    alongTrackM: maxAlong - minAlong,
  );
}

/// Kullanıcı örneği — ince kuzey-güney üçgeni.
List<LatLon> kExampleThinNorthSouthCalibrationCoords() {
  return [
    LatLon(lat: 37 + 23.755 / 60, lon: 27 + 11.657 / 60),
    LatLon(lat: 37 + 25.330 / 60, lon: 27 + 12.277 / 60),
    LatLon(lat: 37 + 26.769 / 60, lon: 27 + 11.839 / 60),
  ];
}
