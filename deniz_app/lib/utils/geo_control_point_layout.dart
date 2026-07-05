import 'dart:math' as math;

import '../api_service.dart';

/// Kalibrasyonda en fazla kaç referans noktası (köşeler + ek referanslar).
const int kMaxCalibrationControlPoints = 8;

/// Ekran görüntüsü köşe koordinatlarından kontrol noktası pikselleri üretir.
///
/// Sıra (UI):
/// 1. Sol üst köşe koordinatı (coğrafi olarak kuzeybatıya en yakın)
/// 2. Sağ alt köşe koordinatı (coğrafi olarak güneydoğuya en yakın)
/// 3+. Ek referans noktaları
///
/// İlk iki giriş yanlış sırada olsa bile coğrafi konuma göre doğru piksel köşesine
/// eşlenir (Navionics ekranında boylam azalabilir).
List<ImageControlPoint> layoutControlPointsFromGeo({
  required List<LatLon> geoPoints,
  required int imageWidth,
  required int imageHeight,
}) {
  if (geoPoints.length < 3) return const [];
  if (imageWidth < 2 || imageHeight < 2) return const [];

  final g0 = geoPoints[0];
  final g1 = geoPoints[1];

  // g0 kuzeybatı, g1 güneydoğu tarafında mı?
  final g0NorthWestScore = (g0.lat - g1.lat) + (g1.lon - g0.lon);
  final g0IsNorthWest = g0NorthWestScore >= 0;
  final topLeftGeo = g0IsNorthWest ? g0 : g1;
  final bottomRightGeo = g0IsNorthWest ? g1 : g0;

  final lonSpan = bottomRightGeo.lon - topLeftGeo.lon;
  final latSpan = topLeftGeo.lat - bottomRightGeo.lat;
  if (lonSpan.abs() < 1e-9 || latSpan.abs() < 1e-9) {
    return const [];
  }

  final maxX = (imageWidth - 1).toDouble();
  final maxY = (imageHeight - 1).toDouble();

  double pixelX(LatLon geo) =>
      ((geo.lon - topLeftGeo.lon) / lonSpan).clamp(0.0, 1.0) * maxX;

  double pixelY(LatLon geo) =>
      ((topLeftGeo.lat - geo.lat) / latSpan).clamp(0.0, 1.0) * maxY;

  final out = <ImageControlPoint>[
    ImageControlPoint(
      pixelX: g0IsNorthWest ? 0 : maxX,
      pixelY: g0IsNorthWest ? 0 : maxY,
      geo: g0,
    ),
    ImageControlPoint(
      pixelX: g0IsNorthWest ? maxX : 0,
      pixelY: g0IsNorthWest ? maxY : 0,
      geo: g1,
    ),
  ];

  for (final geo in geoPoints.skip(2)) {
    out.add(
      ImageControlPoint(
        pixelX: pixelX(geo),
        pixelY: pixelY(geo),
        geo: geo,
      ),
    );
  }
  return out;
}

/// İki köşe koordinatı piksel dönüşümü için yeterince ayrık mı?
String? layoutControlPointsLayoutError(List<LatLon> geoPoints) {
  if (geoPoints.length < 3) return null;
  final g0 = geoPoints[0];
  final g1 = geoPoints[1];
  final g0NorthWestScore = (g0.lat - g1.lat) + (g1.lon - g0.lon);
  final topLeftGeo = g0NorthWestScore >= 0 ? g0 : g1;
  final bottomRightGeo = g0NorthWestScore >= 0 ? g1 : g0;
  if ((bottomRightGeo.lon - topLeftGeo.lon).abs() < 1e-9) {
    return 'Sol üst ve sağ alt boylamı aynı olamaz; farklı köşeler seçin.';
  }
  if ((topLeftGeo.lat - bottomRightGeo.lat).abs() < 1e-9) {
    return 'Sol üst ve sağ alt enlemı aynı olamaz; farklı köşeler seçin.';
  }
  return null;
}

/// Otomatik köşe yerleşimi ile elle seçilmiş pikselleri birleştirir.
List<ImageControlPoint> mergeControlPointsWithManualPixels({
  required List<LatLon> geoPoints,
  required List<({double? pixelX, double? pixelY})> manualPixels,
  required int imageWidth,
  required int imageHeight,
}) {
  if (geoPoints.length < 3) return const [];
  final auto = layoutControlPointsFromGeo(
    geoPoints: geoPoints,
    imageWidth: imageWidth,
    imageHeight: imageHeight,
  );
  if (auto.length < 3) return const [];

  final out = <ImageControlPoint>[];
  for (var i = 0; i < geoPoints.length; i++) {
    final manual = i < manualPixels.length ? manualPixels[i] : null;
    final fallback = i < auto.length ? auto[i] : auto.last;
    out.add(
      ImageControlPoint(
        pixelX: manual?.pixelX ?? fallback.pixelX,
        pixelY: manual?.pixelY ?? fallback.pixelY,
        geo: geoPoints[i],
      ),
    );
  }
  return out;
}

/// Görüntü boyutu değişince kontrol noktası piksellerini ölçekler (geo sabit).
List<ImageControlPoint> scaleControlPointsToImageSize({
  required List<ImageControlPoint> points,
  required int fromWidth,
  required int fromHeight,
  required int toWidth,
  required int toHeight,
}) {
  if (points.isEmpty) return points;
  if (fromWidth < 2 ||
      fromHeight < 2 ||
      toWidth < 2 ||
      toHeight < 2 ||
      (fromWidth == toWidth && fromHeight == toHeight)) {
    return points;
  }
  final sx = (toWidth - 1) / (fromWidth - 1);
  final sy = (toHeight - 1) / (fromHeight - 1);
  return points
      .map(
        (p) => ImageControlPoint(
          pixelX: (p.pixelX * sx).clamp(0.0, (toWidth - 1).toDouble()),
          pixelY: (p.pixelY * sy).clamp(0.0, (toHeight - 1).toDouble()),
          geo: p.geo,
        ),
      )
      .toList(growable: false);
}

/// Hotspot açıkça hatalı coğrafi konumda mı? (kıta ölçeğinde sapma)
bool hotspotIsExtremeGeoOutlier({
  required double lat,
  required double lon,
  required ImageGeoBounds bounds,
  double maxDistanceKm = 120.0,
}) {
  final tl = bounds.topLeft;
  final br = bounds.bottomRight;
  if (tl == null || br == null) return false;
  if (!lat.isFinite || !lon.isFinite) return true;
  if (lat.abs() > 90 || lon.abs() > 180) return true;
  if (lat.abs() < 1e-9 && lon.abs() < 1e-9) return true;

  final centerLat = (tl.lat + br.lat) / 2;
  final centerLon = (tl.lon + br.lon) / 2;
  return _haversineKm(centerLat, centerLon, lat, lon) > maxDistanceKm;
}

double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  final p1 = lat1 * math.pi / 180;
  final p2 = lat2 * math.pi / 180;
  final dp = (lat2 - lat1) * math.pi / 180;
  final dl = (lon2 - lon1) * math.pi / 180;
  final a = math.sin(dp / 2) * math.sin(dp / 2) +
      math.cos(p1) * math.cos(p2) * math.sin(dl / 2) * math.sin(dl / 2);
  return 2 * r * math.asin(math.min(1.0, math.sqrt(a)));
}
