import '../api_service.dart';

/// Dünya haritasında tekne göstermek için anlamlı GPS (0,0 ve sapkınlık dışında).
bool boatStateHasPlausibleGps(BoatState? boat) {
  if (boat == null) return false;
  for (final ll in [boat.smoothedGps, boat.rawGps]) {
    if (!ll.lat.isFinite || !ll.lon.isFinite) continue;
    if (ll.lat.abs() > 90 || ll.lon.abs() > 180) continue;
    if (ll.lat.abs() < 1e-8 && ll.lon.abs() < 1e-8) continue;
    return true;
  }
  return false;
}

/// Piksel çıktıların dünya haritasında çizimi: güvenilir geo eşlemesi olmadan gizlenir.
bool shouldHideGeoHotspotsOnWorldMap({
  required bool geoMapDisplayAllowed,
  required bool isWorldMap,
}) {
  return isWorldMap && !geoMapDisplayAllowed;
}
