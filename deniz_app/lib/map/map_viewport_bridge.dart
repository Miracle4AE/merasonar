import 'package:flutter_map/flutter_map.dart';

import '../domain/world_map_viewport_state.dart';

extension MapCameraWorldViewport on MapCamera {
  /// Geçersiz kamera/bounds durumunda `null` (layout güncellemesi atlanır).
  WorldMapViewportState? tryToWorldMapViewportState(DateTime timestamp) {
    try {
      final b = visibleBounds;
      if (!b.north.isFinite ||
          !b.south.isFinite ||
          !b.east.isFinite ||
          !b.west.isFinite) {
        return null;
      }
      if (b.north < b.south) return null;
      final z = zoom;
      if (!z.isFinite || z < 0.5 || z > 25) return null;
      final clat = center.latitude;
      final clon = center.longitude;
      if (!clat.isFinite || !clon.isFinite) return null;
      if (clat.abs() > 90 || clon.abs() > 180) return null;
      return WorldMapViewportState(
        north: b.north,
        south: b.south,
        east: b.east,
        west: b.west,
        zoom: z,
        centerLat: clat,
        centerLon: clon,
        lastUpdatedAt: timestamp,
      );
    } catch (_) {
      return null;
    }
  }
}
