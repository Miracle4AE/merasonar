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

class DashboardMapPreviewLayoutAssessment {
  const DashboardMapPreviewLayoutAssessment({
    required this.bounds,
    required this.widthMeters,
    required this.heightMeters,
    required this.markerCount,
    required this.uniqueCoordinateCount,
    required this.screenOverlapCount,
    required this.topRightClusterCount,
    required this.isCompactCluster,
    required this.requiresPreviewSpreadLayout,
  });

  final DashboardMapPreviewBounds bounds;
  final double widthMeters;
  final double heightMeters;
  final int markerCount;
  final int uniqueCoordinateCount;
  final int screenOverlapCount;
  final int topRightClusterCount;
  final bool isCompactCluster;
  final bool requiresPreviewSpreadLayout;

  String get debugSummary =>
      'markers=$markerCount unique=$uniqueCoordinateCount '
      'meters=${widthMeters.toStringAsFixed(1)}x'
      '${heightMeters.toStringAsFixed(1)} overlap=$screenOverlapCount '
      'topRight=$topRightClusterCount compact=$isCompactCluster';
}

class DashboardMapPreviewLayoutResult {
  const DashboardMapPreviewLayoutResult({
    required this.markers,
    required this.assessment,
    required this.hiddenMarkerCount,
  });

  final List<DashboardMapMarker> markers;
  final DashboardMapPreviewLayoutAssessment assessment;
  final int hiddenMarkerCount;
}

/// Lat/lon → normalized card coordinates (0–1), north-up.
abstract final class DashboardMapPreviewProjection {
  static const minPadding = 0.14;
  static const maxPadding = 0.86;
  static const minDegreePad = 0.004;
  static const maxVisibleScoreOrbs = 7;

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

  static DashboardMapPreviewBounds computeRawBounds({
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

  static DashboardMapPreviewLayoutResult buildPreviewLayout({
    required List<DashboardMapMarker> markers,
    required String? selectedMarkerId,
    int maxVisible = maxVisibleScoreOrbs,
  }) {
    final projected = applyProjection(markers)
        .where((m) => m.hasScoreOrb)
        .toList(growable: false);
    if (projected.isEmpty) {
      return DashboardMapPreviewLayoutResult(
        markers: const [],
        hiddenMarkerCount: 0,
        assessment: _assessLayout(const []),
      );
    }

    final selectedId = selectedMarkerId ??
        selectMarkerId(markers: projected, explicitSelectedId: selectedMarkerId);
    final visible = _selectVisibleMarkers(
      markers: projected,
      selectedMarkerId: selectedId,
      maxVisible: maxVisible,
    );
    final assessment = _assessLayout(visible);
    final laidOut = assessment.requiresPreviewSpreadLayout
        ? _spreadCompactCluster(visible, selectedId)
        : visible;

    return DashboardMapPreviewLayoutResult(
      markers: markSelected(laidOut, selectedId: selectedId),
      assessment: assessment,
      hiddenMarkerCount: projected.length - visible.length,
    );
  }

  static DashboardMapPreviewLayoutAssessment assessProjectedMarkers(
    List<DashboardMapMarker> markers,
  ) =>
      _assessLayout(markers.where((m) => m.hasScoreOrb).toList(growable: false));

  static List<DashboardMapMarker> _selectVisibleMarkers({
    required List<DashboardMapMarker> markers,
    required String? selectedMarkerId,
    required int maxVisible,
  }) {
    final selected = <DashboardMapMarker>[];
    final rest = <DashboardMapMarker>[];
    for (final marker in markers) {
      if (marker.id == selectedMarkerId || marker.isSelected || marker.isPrimary) {
        selected.add(marker);
      } else {
        rest.add(marker);
      }
    }
    rest.sort((a, b) {
      final scoreCmp = (b.score ?? -1).compareTo(a.score ?? -1);
      if (scoreCmp != 0) return scoreCmp;
      final typeCmp = _markerPriority(a).compareTo(_markerPriority(b));
      if (typeCmp != 0) return typeCmp;
      return a.id.compareTo(b.id);
    });
    final result = <DashboardMapMarker>[
      if (selected.isNotEmpty) selected.first,
      ...rest,
    ];
    return result.take(maxVisible).toList(growable: false);
  }

  static int _markerPriority(DashboardMapMarker marker) {
    if (marker.markerType == DashboardMapMarkerType.hotspot) return 0;
    if (marker.markerType == DashboardMapMarkerType.report) return 1;
    if (marker.markerType == DashboardMapMarkerType.compareA ||
        marker.markerType == DashboardMapMarkerType.compareB) {
      return 2;
    }
    return 3;
  }

  static DashboardMapPreviewLayoutAssessment _assessLayout(
    List<DashboardMapMarker> markers,
  ) {
    final withCoords = markers.where((m) => m.hasScoreOrb).toList(growable: false);
    if (withCoords.isEmpty) {
      return const DashboardMapPreviewLayoutAssessment(
        bounds: DashboardMapPreviewBounds.empty,
        widthMeters: 0,
        heightMeters: 0,
        markerCount: 0,
        uniqueCoordinateCount: 0,
        screenOverlapCount: 0,
        topRightClusterCount: 0,
        isCompactCluster: false,
        requiresPreviewSpreadLayout: false,
      );
    }

    final bounds = computeRawBounds(
      lats: withCoords.map((m) => m.lat!).toList(growable: false),
      lons: withCoords.map((m) => m.lon!).toList(growable: false),
    );
    final avgLat = (bounds.minLat + bounds.maxLat) / 2;
    final heightMeters = bounds.latSpan * 111320;
    final widthMeters =
        bounds.lonSpan * 111320 * math.cos(avgLat * math.pi / 180).abs();
    final unique = withCoords
        .map((m) => '${m.lat!.toStringAsFixed(6)},${m.lon!.toStringAsFixed(6)}')
        .toSet()
        .length;
    final overlapCount = _screenOverlapCount(withCoords);
    final topRightCount = withCoords
        .where((m) => m.normalizedX > 0.72 && m.normalizedY < 0.28)
        .length;
    final markerCount = withCoords.length;
    final topRightCluster = markerCount >= 3 && topRightCount / markerCount >= 0.5;
    final compactMeters = markerCount >= 3 && widthMeters < 250 && heightMeters < 250;
    final duplicateCluster = markerCount >= 3 && unique <= 2;
    final overlapCluster =
        markerCount >= 3 && overlapCount / markerCount >= 0.6;
    final compact =
        compactMeters || duplicateCluster || overlapCluster || topRightCluster;

    return DashboardMapPreviewLayoutAssessment(
      bounds: bounds,
      widthMeters: widthMeters,
      heightMeters: heightMeters,
      markerCount: markerCount,
      uniqueCoordinateCount: unique,
      screenOverlapCount: overlapCount,
      topRightClusterCount: topRightCount,
      isCompactCluster: compact,
      requiresPreviewSpreadLayout: compact,
    );
  }

  static int _screenOverlapCount(List<DashboardMapMarker> markers) {
    var count = 0;
    for (var i = 0; i < markers.length; i++) {
      for (var j = i + 1; j < markers.length; j++) {
        final dx = (markers[i].normalizedX - markers[j].normalizedX).abs();
        final dy = (markers[i].normalizedY - markers[j].normalizedY).abs();
        if (dx < 0.11 && dy < 0.11) {
          count++;
          break;
        }
      }
    }
    return count;
  }

  static List<DashboardMapMarker> _spreadCompactCluster(
    List<DashboardMapMarker> markers,
    String? selectedMarkerId,
  ) {
    if (markers.isEmpty) return const [];

    final selected = markers.firstWhere(
      (m) => m.id == selectedMarkerId || m.isSelected || m.isPrimary,
      orElse: () => markers.first,
    );
    final others = markers.where((m) => m.id != selected.id).toList();
    others.sort((a, b) {
      final angleA = _angleFrom(selected, a);
      final angleB = _angleFrom(selected, b);
      final cmp = angleA.compareTo(angleB);
      if (cmp != 0) return cmp;
      final scoreCmp = (b.score ?? -1).compareTo(a.score ?? -1);
      if (scoreCmp != 0) return scoreCmp;
      return a.id.compareTo(b.id);
    });

    const selectedSlot = Offset(0.56, 0.46);
    const slots = [
      Offset(0.22, 0.34),
      Offset(0.74, 0.30),
      Offset(0.28, 0.66),
      Offset(0.46, 0.72),
      Offset(0.78, 0.62),
      Offset(0.16, 0.54),
    ];

    return [
      _withPosition(selected, selectedSlot),
      for (var i = 0; i < others.length; i++)
        _withPosition(others[i], slots[i % slots.length]),
    ];
  }

  static double _angleFrom(DashboardMapMarker selected, DashboardMapMarker marker) {
    if (selected.lat == null ||
        selected.lon == null ||
        marker.lat == null ||
        marker.lon == null) {
      return marker.id.hashCode.toDouble();
    }
    return math.atan2(marker.lat! - selected.lat!, marker.lon! - selected.lon!);
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

  static DashboardMapMarker _withPosition(
    DashboardMapMarker m,
    Offset position,
  ) {
    return DashboardMapMarker(
      normalizedX: position.dx,
      normalizedY: position.dy,
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
