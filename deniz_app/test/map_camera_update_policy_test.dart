import 'package:flutter_test/flutter_test.dart';

import 'package:deniz_app/domain/world_map_viewport_state.dart';
import 'package:deniz_app/services/map_camera_update_policy.dart';

void main() {
  test('MapCameraUpdatePolicy: ilk örnek her zaman yayınlanır', () {
    final p = MapCameraUpdatePolicy();
    final t0 = DateTime.utc(2026, 1, 1, 12);
    final v = WorldMapViewportState(
      north: 40.1,
      south: 40.0,
      east: 29.1,
      west: 29.0,
      zoom: 12,
      centerLat: 40.05,
      centerLon: 29.05,
      lastUpdatedAt: t0,
    );
    expect(p.shouldEmitNow(now: t0, candidate: v), isTrue);
  });

  test('MapCameraUpdatePolicy: mikro pan aynı minInterval içinde bastırılır', () {
    final p = MapCameraUpdatePolicy(minInterval: const Duration(milliseconds: 200));
    final t0 = DateTime.utc(2026, 1, 1, 12);
    final t1 = t0.add(const Duration(milliseconds: 30));
    final a = WorldMapViewportState(
      north: 40.10001,
      south: 40.00001,
      east: 29.10001,
      west: 29.00001,
      zoom: 12.001,
      centerLat: 40.05,
      centerLon: 29.05,
      lastUpdatedAt: t0,
    );
    final b = WorldMapViewportState(
      north: 40.10002,
      south: 40.00002,
      east: 29.10002,
      west: 29.00002,
      zoom: 12.002,
      centerLat: 40.05001,
      centerLon: 29.05001,
      lastUpdatedAt: t1,
    );
    expect(p.shouldEmitNow(now: t0, candidate: a), isTrue);
    expect(p.shouldEmitNow(now: t1, candidate: b), isFalse);
  });

  test('MapCameraUpdatePolicy: zoom sıçraması minInterval\'ı bypass eder', () {
    final p = MapCameraUpdatePolicy(minInterval: const Duration(seconds: 1));
    final t0 = DateTime.utc(2026, 1, 1, 12);
    final t1 = t0.add(const Duration(milliseconds: 50));
    final a = WorldMapViewportState(
      north: 40.1,
      south: 40.0,
      east: 29.1,
      west: 29.0,
      zoom: 11,
      centerLat: 40.05,
      centerLon: 29.05,
      lastUpdatedAt: t0,
    );
    final b = WorldMapViewportState(
      north: 40.1,
      south: 40.0,
      east: 29.1,
      west: 29.0,
      zoom: 14.5,
      centerLat: 40.05,
      centerLon: 29.05,
      lastUpdatedAt: t1,
    );
    expect(p.shouldEmitNow(now: t0, candidate: a), isTrue);
    expect(p.shouldEmitNow(now: t1, candidate: b), isTrue);
  });
}
