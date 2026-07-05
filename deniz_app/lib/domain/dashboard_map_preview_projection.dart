import 'dart:math' as math;

import 'package:deniz_app/domain/dashboard_overview.dart';
import 'package:flutter/material.dart';

/// Geo bounds for dashboard map preview viewport.
class DashboardMapPreviewBounds {
  const DashboardMapPreviewBounds({
    required this.minLat,
    required this.maxLat,
    required this.minLon,
    required this.maxLon,
  });

  final double minLat;
  final double maxLat;
  final double minLon;
  final double maxLon;

  double get latSpan => (maxLat - minLat).abs().clamp(1e-9, double.infinity);
  double get lonSpan => (maxLon - minLon).abs().clamp(1e-9, double.infinity);

  static const empty = DashboardMapPreviewBounds(
    minLat: 0,
    maxLat: 1,
    minLon: 0,
    maxLon: 1,
  );
}

/// Lat/lon → normalized card coordinates (0–1), north-up.
abstract final class DashboardMapPreviewProjection {
  static const minPadding = 0.14;
  static const maxPadding = 0.86;
  static const minDegreePad = 0.004;

  static DashboardMapPreviewBounds computeBounds({
    required List<double> lats,
    required List<double> lons,
  }) {
    if (lats.isEmpty || lons.isEmpty) {
      return DashboardMapPreviewBounds.empty;
    }
    var minLat = lats.first;
    var maxLat = lats.first;
    var minLon = lons.first;
    var maxLon = lons.first;
    for (var i = 0; i < lats.length; i++) {
      if (lats[i] < minLat) minLat = lats[i];
      if (lats[i] > maxLat) maxLat = lats[i];
      if (lons[i] < minLon) minLon = lons[i];
      if (lons[i] > maxLon) maxLon = lons[i];
    }
    if ((maxLat - minLat).abs() < minDegreePad) {
      minLat -= minDegreePad;
      maxLat += minDegreePad;
    }
    if ((maxLon - minLon).abs() < minDegreePad) {
      minLon -= minDegreePad;
      maxLon += minDegreePad;
    }
    return DashboardMapPreviewBounds(
      minLat: minLat,
      maxLat: maxLat,
      minLon: minLon,
      maxLon: maxLon,
    );
  }

  static (double x, double y) normalizeLatLon(
    double lat,
    double lon,
    DashboardMapPreviewBounds bounds,
  ) {
    final x = (lon - bounds.minLon) / bounds.lonSpan;
    final y = 1 - (lat - bounds.minLat) / bounds.latSpan;
    return (
      x.clamp(minPadding, maxPadding),
      y.clamp(minPadding, maxPadding),
    );
  }

  /// Screen-space collision avoidance — does not alter lat/lon.
  static Offset resolveScreenOverlap({
    required Offset center,
    required List<Offset> placed,
    required double minDistance,
    required Size size,
  }) {
    var resolved = center;
    for (var pass = 0; pass < 6; pass++) {
      for (var i = 0; i < placed.length; i++) {
        final other = placed[i];
        final delta = resolved - other;
        final dist = delta.distance;
        if (dist < minDistance) {
          if (dist > 0.5) {
            resolved = other + (delta / dist) * minDistance;
          } else {
            final angle = (i + pass + 1) * 2.399963;
            resolved = other +
                Offset(
                  math.cos(angle) * minDistance,
                  math.sin(angle) * minDistance,
                );
          }
        }
      }
    }
    return Offset(
      resolved.dx.clamp(18, size.width - 18),
      resolved.dy.clamp(18, size.height - 18),
    );
  }

  static List<DashboardMapMarker> applyProjection(
    List<DashboardMapMarker> markers,
  ) {
    final withCoords = markers
        .where((m) => m.lat != null && m.lon != null)
        .toList(growable: false);
    if (withCoords.isEmpty) return const [];

    final bounds = computeBounds(
      lats: withCoords.map((m) => m.lat!).toList(growable: false),
      lons: withCoords.map((m) => m.lon!).toList(growable: false),
    );

    return [
      for (final m in withCoords)
        _withNormalized(m, bounds),
    ];
  }

  static DashboardMapMarker _withNormalized(
    DashboardMapMarker m,
    DashboardMapPreviewBounds bounds,
  ) {
    final pos = normalizeLatLon(m.lat!, m.lon!, bounds);
    return DashboardMapMarker(
      normalizedX: pos.$1,
      normalizedY: pos.$2,
      id: m.id,
      label: m.label,
      lat: m.lat,
      lon: m.lon,
      score: m.score,
      markerType: m.markerType,
      markerKind: m.markerKind,
      markerSource: m.markerSource,
      confidence: m.confidence,
      isPrimary: m.isPrimary,
      isSelected: m.isSelected,
      isCompareA: m.isCompareA,
      isCompareB: m.isCompareB,
      isFavorite: m.isFavorite,
    );
  }

  /// Score orb color buckets — does not alter score values.
  static Color scoreColor(int score) {
    if (score >= 80) return const Color(0xFF2EE6A8);
    if (score >= 60) return const Color(0xFFE6C84A);
    if (score >= 40) return const Color(0xFFE8944A);
    return const Color(0xFFE85A5A);
  }

  static String? selectMarkerId({
    required List<DashboardMapMarker> markers,
    String? explicitSelectedId,
    double? centerLat,
    double? centerLon,
  }) {
    final scorable = markers
        .where((m) => m.lat != null && m.lon != null && m.score != null)
        .toList(growable: false);
    if (scorable.isEmpty) return null;

    if (explicitSelectedId != null &&
        scorable.any((m) => m.id == explicitSelectedId)) {
      return explicitSelectedId;
    }

    final primary = scorable.where((m) => m.isPrimary).toList();
    if (primary.isNotEmpty) return primary.first.id;

    scorable.sort((a, b) => (b.score ?? 0).compareTo(a.score ?? 0));
    if (scorable.first.score != null) return scorable.first.id;

    if (centerLat != null && centerLon != null) {
      DashboardMapMarker? nearest;
      var bestDist = double.infinity;
      for (final m in scorable) {
        final dLat = m.lat! - centerLat;
        final dLon = m.lon! - centerLon;
        final dist = dLat * dLat + dLon * dLon;
        if (dist < bestDist) {
          bestDist = dist;
          nearest = m;
        }
      }
      if (nearest != null) return nearest.id;
    }

    return scorable.first.id;
  }

  static List<DashboardMapMarker> markSelected(
    List<DashboardMapMarker> markers, {
    required String? selectedId,
  }) {
    if (selectedId == null) return markers;
    return [
      for (final m in markers)
        DashboardMapMarker(
          normalizedX: m.normalizedX,
          normalizedY: m.normalizedY,
          id: m.id,
          label: m.label,
          lat: m.lat,
          lon: m.lon,
          score: m.score,
          markerType: m.markerType,
          markerKind: m.markerKind,
          markerSource: m.markerSource,
          confidence: m.confidence,
          isPrimary: m.id == selectedId,
          isSelected: m.id == selectedId,
          isCompareA: m.isCompareA,
          isCompareB: m.isCompareB,
          isFavorite: m.isFavorite,
        ),
    ];
  }

  static bool hasScorableMarkers(List<DashboardMapMarker> markers) =>
      markers.any((m) => m.lat != null && m.lon != null && m.score != null);

  static bool coordValid(double lat, double lon) =>
      lat.abs() > 1e-6 || lon.abs() > 1e-6;
}
