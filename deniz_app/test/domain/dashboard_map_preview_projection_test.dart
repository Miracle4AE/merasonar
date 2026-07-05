import 'package:deniz_app/domain/dashboard_map_preview_projection.dart';
import 'package:deniz_app/domain/dashboard_overview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DashboardMapPreviewProjection', () {
    test('normalizeLatLon spreads five distinct coordinates in viewport', () {
      final lats = [37.20, 37.22, 37.24, 37.26, 37.28];
      final lons = [27.10, 27.12, 27.14, 27.16, 27.18];
      final bounds = DashboardMapPreviewProjection.computeBounds(
        lats: lats,
        lons: lons,
      );

      final xs = <double>[];
      final ys = <double>[];
      for (var i = 0; i < lats.length; i++) {
        final pos = DashboardMapPreviewProjection.normalizeLatLon(
          lats[i],
          lons[i],
          bounds,
        );
        xs.add(pos.$1);
        ys.add(pos.$2);
      }

      expect(xs.toSet().length, greaterThan(2));
      expect(ys.toSet().length, greaterThan(2));
      for (final x in xs) {
        expect(x, inInclusiveRange(0.14, 0.86));
      }
      for (final y in ys) {
        expect(y, inInclusiveRange(0.14, 0.86));
      }
    });

    test('computeBounds pads tiny bounding box', () {
      final bounds = DashboardMapPreviewProjection.computeBounds(
        lats: [41.0, 41.0001],
        lons: [29.0, 29.0001],
      );
      expect(bounds.latSpan, greaterThan(0.004));
      expect(bounds.lonSpan, greaterThan(0.004));
    });

    test('same lat/lon does not crash normalize', () {
      final bounds = DashboardMapPreviewProjection.computeBounds(
        lats: [41.0, 41.0],
        lons: [29.0, 29.0],
      );
      final pos = DashboardMapPreviewProjection.normalizeLatLon(41.0, 29.0, bounds);
      expect(pos.$1.isFinite, isTrue);
      expect(pos.$2.isFinite, isTrue);
    });

    test('applyProjection never fabricates markers', () {
      const raw = [
        DashboardMapMarker(
          normalizedX: 0,
          normalizedY: 0,
          id: 'a',
          lat: 37.2,
          lon: 27.1,
          score: 78,
        ),
        DashboardMapMarker(
          normalizedX: 0,
          normalizedY: 0,
          id: 'b',
          lat: null,
          lon: null,
          score: 99,
        ),
      ];
      final projected = DashboardMapPreviewProjection.applyProjection(raw);
      expect(projected.length, 1);
      expect(projected.first.id, 'a');
    });

    test('selectMarkerId prefers explicit then highest score', () {
      const markers = [
        DashboardMapMarker(
          normalizedX: 0.3,
          normalizedY: 0.5,
          id: 'low',
          lat: 1,
          lon: 1,
          score: 40,
        ),
        DashboardMapMarker(
          normalizedX: 0.7,
          normalizedY: 0.5,
          id: 'high',
          lat: 2,
          lon: 2,
          score: 91,
        ),
      ];
      expect(
        DashboardMapPreviewProjection.selectMarkerId(
          markers: markers,
          explicitSelectedId: 'low',
        ),
        'low',
      );
      expect(
        DashboardMapPreviewProjection.selectMarkerId(markers: markers),
        'high',
      );
    });

    test('scoreColor buckets', () {
      expect(
        DashboardMapPreviewProjection.scoreColor(85),
        const Color(0xFF2EE6A8),
      );
      expect(
        DashboardMapPreviewProjection.scoreColor(70),
        const Color(0xFFE6C84A),
      );
      expect(
        DashboardMapPreviewProjection.scoreColor(50),
        const Color(0xFFE8944A),
      );
      expect(
        DashboardMapPreviewProjection.scoreColor(30),
        const Color(0xFFE85A5A),
      );
    });

    test('resolveScreenOverlap pushes markers apart not only to corner', () {
      const size = Size(300, 200);
      final a = const Offset(150, 100);
      final b = DashboardMapPreviewProjection.resolveScreenOverlap(
        center: const Offset(152, 101),
        placed: [a],
        minDistance: 28,
        size: size,
      );
      expect((b - a).distance, greaterThanOrEqualTo(27));
      expect(b.dx, lessThan(280));
      expect(b.dy, lessThan(180));
    });

    test('compact cluster detector catches right-top clustered projection', () {
      const markers = [
        DashboardMapMarker(
          normalizedX: 0.78,
          normalizedY: 0.18,
          id: 'a',
          lat: 37.390000,
          lon: 27.190000,
          score: 37,
        ),
        DashboardMapMarker(
          normalizedX: 0.80,
          normalizedY: 0.20,
          id: 'b',
          lat: 37.390001,
          lon: 27.190001,
          score: 1,
        ),
        DashboardMapMarker(
          normalizedX: 0.82,
          normalizedY: 0.19,
          id: 'c',
          lat: 37.390002,
          lon: 27.190002,
          score: 1,
        ),
      ];
      final assessment =
          DashboardMapPreviewProjection.assessProjectedMarkers(markers);
      expect(assessment.isCompactCluster, isTrue);
      expect(assessment.requiresPreviewSpreadLayout, isTrue);
      expect(assessment.topRightClusterCount, 3);
    });

    test('runtime-like score 37 cluster uses spread layout and caps low scores', () {
      final raw = _runtimeLikeClusterMarkers();
      final layout = DashboardMapPreviewProjection.buildPreviewLayout(
        markers: raw,
        selectedMarkerId: 'selected',
      );

      expect(layout.assessment.isCompactCluster, isTrue);
      expect(layout.markers.length, 7);
      expect(layout.hiddenMarkerCount, 3);
      expect(layout.markers.map((m) => m.id), contains('selected'));

      final selected = layout.markers.firstWhere((m) => m.id == 'selected');
      expect(selected.score, 37);
      expect(selected.lat, raw.first.lat);
      expect(selected.lon, raw.first.lon);
      expect(selected.normalizedX, closeTo(0.56, 0.001));
      expect(selected.normalizedY, closeTo(0.46, 0.001));

      final topRightCount = layout.markers
          .where((m) => m.normalizedX > 0.72 && m.normalizedY < 0.28)
          .length;
      expect(topRightCount / layout.markers.length, lessThan(0.5));
    });

    test('spread layout preserves marker ids scores and coordinates', () {
      final raw = _runtimeLikeClusterMarkers();
      final layout = DashboardMapPreviewProjection.buildPreviewLayout(
        markers: raw,
        selectedMarkerId: 'selected',
      );

      for (final marker in layout.markers) {
        final original = raw.firstWhere((m) => m.id == marker.id);
        expect(marker.score, original.score);
        expect(marker.lat, original.lat);
        expect(marker.lon, original.lon);
      }
      expect(layout.markers.length, lessThanOrEqualTo(raw.length));
    });
  });
}

List<DashboardMapMarker> _runtimeLikeClusterMarkers() {
  const baseLat = 37.390000;
  const baseLon = 27.190000;
  return [
    const DashboardMapMarker(
      normalizedX: 0,
      normalizedY: 0,
      id: 'selected',
      lat: baseLat,
      lon: baseLon,
      score: 37,
      isSelected: true,
    ),
    for (var i = 1; i <= 9; i++)
      DashboardMapMarker(
        normalizedX: 0,
        normalizedY: 0,
        id: 'low_$i',
        lat: baseLat + i * 0.000001,
        lon: baseLon + i * 0.000001,
        score: 1,
      ),
  ];
}
