import 'package:flutter/foundation.dart';

/// flutter_map [MapCamera] görünür alanının domain tarafı (SDK bağımsız).
@immutable
class WorldMapViewportState {
  const WorldMapViewportState({
    required this.north,
    required this.south,
    required this.east,
    required this.west,
    required this.zoom,
    required this.centerLat,
    required this.centerLon,
    required this.lastUpdatedAt,
  });

  final double north;
  final double south;
  final double east;
  final double west;
  final double zoom;
  final double centerLat;
  final double centerLon;
  final DateTime lastUpdatedAt;

  bool containsLatLon(double lat, double lon) {
    if (!lat.isFinite || !lon.isFinite) return false;
    if (lat > north || lat < south) return false;
    if (west <= east) {
      return lon >= west && lon <= east;
    }
    return lon >= west || lon <= east;
  }

  /// Hotspot layout imzası — gereksiz yeniden kümelemeyi azaltmak için.
  int layoutSignature({
    required int hotspotDataEpoch,
    required int? focusHotspotId,
    required bool canRenderWorldMapHotspots,
  }) {
    return Object.hash(
      hotspotDataEpoch,
      focusHotspotId,
      canRenderWorldMapHotspots,
      (zoom * 1000).round(),
      (north * 5e4).round(),
      (south * 5e4).round(),
      (east * 5e4).round(),
      (west * 5e4).round(),
    );
  }

  bool approximatelySameAs(WorldMapViewportState other, {
    double edgeEpsilonDeg = 0.00012,
    double zoomEpsilon = 0.035,
  }) {
    return (north - other.north).abs() <= edgeEpsilonDeg &&
        (south - other.south).abs() <= edgeEpsilonDeg &&
        (east - other.east).abs() <= edgeEpsilonDeg &&
        (west - other.west).abs() <= edgeEpsilonDeg &&
        (zoom - other.zoom).abs() <= zoomEpsilon;
  }
}
