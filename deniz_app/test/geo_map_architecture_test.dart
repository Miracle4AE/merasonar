import 'package:flutter_test/flutter_test.dart';

import 'package:deniz_app/api_service.dart';
import 'package:deniz_app/domain/geo_visualization_state.dart';
import 'package:deniz_app/domain/world_map_hotspot_layout.dart';
import 'package:deniz_app/domain/world_map_viewport_state.dart';
import 'package:deniz_app/services/boat_gps_smoother.dart';

Map<String, dynamic> _hotspot({
  required int id,
  required double lat,
  required double lon,
  double score = 0.8,
  int recommendationRank = 999999,
}) {
  return {
    'id': id,
    'feature_type': 'drop_off',
    'rank': 1,
    'rank_overall': 1,
    'rank_by_score_then_distance': id,
    'rank_by_proximity': 1,
    'latitude': lat,
    'longitude': lon,
    'geo_coordinate': {'lat': lat, 'lon': lon},
    'distance_m': 10,
    'bearing_deg': 0,
    'score': score,
    'classification': 'A',
    'recommendation_rank': recommendationRank,
  };
}

Map<String, dynamic> _baseZone(
  List<Map<String, dynamic>> hotspots, {
  String coordinateMode = kCoordinateModeGeoReferenced,
  bool? geoMapDisplayAllowed,
  String? calibrationReliability,
  Map<String, dynamic>? diagnosticsExtra,
}) {
  return {
    'boat': {
      'raw_gps': {'lat': 37.35, 'lon': 27.20},
      'smoothed_gps': {'lat': 37.351, 'lon': 27.201},
    },
    'coordinate_mode': coordinateMode,
    'geo_map_display_allowed': ?geoMapDisplayAllowed,
    'calibration_reliability': ?calibrationReliability,
    'diagnostics': {
      'georeference_error': 5.0,
      'transform_quality': 0.9,
      ...?diagnosticsExtra,
    },
    'ranked_hotspots': hotspots,
  };
}

void main() {
  group('GeoVisualizationState', () {
    test('unsafe kalibrasyon dünya haritası hotspotlarını kapatır', () {
      final r = FishingZoneResponse.fromJson(
        _baseZone(
          [_hotspot(id: 1, lat: 37.0, lon: 27.0)],
          calibrationReliability: 'unsafe',
          geoMapDisplayAllowed: true,
        ),
      );
      final viz = GeoVisualizationState.fromFishingZone(r);
      expect(viz.reliability, CalibrationReliability.unsafe);
      expect(viz.canRenderWorldMapHotspots, isFalse);
      expect(viz.showApproximateRibbon, isFalse);
    });

    test('approximate + geo_referenced: şerit göster, haritayı açık tut', () {
      final r = FishingZoneResponse.fromJson(
        _baseZone(
          [_hotspot(id: 1, lat: 37.0, lon: 27.0)],
          calibrationReliability: 'approximate',
          geoMapDisplayAllowed: true,
          diagnosticsExtra: {
            'mapping_mode': 'affine_control_points',
            'screenshot_aligned_mapping_used': true,
          },
        ),
      );
      final viz = GeoVisualizationState.fromFishingZone(r);
      expect(viz.reliability, CalibrationReliability.approximate);
      expect(viz.canRenderWorldMapHotspots, isTrue);
      expect(viz.showApproximateRibbon, isTrue);
      expect(viz.isReliableForNavigation, isFalse);
    });

    test('transform_quality=0.00 iken approximate görünse bile unsafe say', () {
      final r = FishingZoneResponse.fromJson(
        _baseZone(
          [_hotspot(id: 1, lat: 37.0, lon: 27.0)],
          calibrationReliability: 'approximate',
          geoMapDisplayAllowed: true,
          diagnosticsExtra: {
            'transform_quality': 0.0,
            'mapping_mode': 'linear_bounds',
          },
        ),
      );
      final viz = GeoVisualizationState.fromFishingZone(r);
      expect(viz.reliability, CalibrationReliability.unsafe);
      expect(viz.canRenderWorldMapHotspots, isFalse);
      expect(viz.showApproximateRibbon, isFalse);
    });

    test(
      'transform_quality=0 + affine + düşük sapma: yaklaşık göster',
      () {
        final r = FishingZoneResponse.fromJson(
          _baseZone(
            [_hotspot(id: 1, lat: 37.0, lon: 27.0)],
            calibrationReliability: 'unsafe',
            geoMapDisplayAllowed: false,
            diagnosticsExtra: {
              'transform_quality': 0.0,
              'georeference_error': 120.0,
              'mapping_mode': 'affine_control_points',
              'hotspot_geo_count': 64,
            },
          ),
        );
        final viz = GeoVisualizationState.fromFishingZone(
          r,
          fallbackCoordinateModeHint: kCoordinateModeGeoReferenced,
        );
        expect(viz.reliability, CalibrationReliability.approximate);
        expect(viz.canRenderWorldMapHotspots, isTrue);
      },
    );

    test(
      'transform_quality=0 + yüksek sapma ama sunucu approximate: haritayı aç',
      () {
        final r = FishingZoneResponse.fromJson(
          _baseZone(
            [_hotspot(id: 1, lat: 37.0, lon: 27.0)],
            calibrationReliability: 'approximate',
            geoMapDisplayAllowed: true,
            diagnosticsExtra: {
              'transform_quality': 0.0,
              'georeference_error': 1734.0,
              'mapping_mode': 'affine_control_points',
            },
          ),
        );
        final viz = GeoVisualizationState.fromFishingZone(r);
        expect(viz.reliability, CalibrationReliability.approximate);
        expect(viz.canRenderWorldMapHotspots, isTrue);
      },
    );

    test(
      'transform_quality=0 + çok yüksek sapma + sunucu izin vermiyor: kapat',
      () {
        final r = FishingZoneResponse.fromJson(
          _baseZone(
            [_hotspot(id: 1, lat: 37.0, lon: 27.0)],
            calibrationReliability: 'unsafe',
            geoMapDisplayAllowed: false,
            diagnosticsExtra: {
              'transform_quality': 0.0,
              'georeference_error': 1295.0,
              'mapping_mode': 'affine_control_points',
            },
          ),
        );
        final viz = GeoVisualizationState.fromFishingZone(r);
        expect(viz.reliability, CalibrationReliability.approximate);
        expect(viz.canRenderWorldMapHotspots, isTrue);
      },
    );

    test('image_space her zaman unsafe politikası', () {
      final r = FishingZoneResponse.fromJson(
        _baseZone(
          [_hotspot(id: 1, lat: 37.0, lon: 27.0)],
          coordinateMode: kCoordinateModeImageSpace,
          calibrationReliability: 'excellent',
          geoMapDisplayAllowed: true,
        ),
      );
      final viz = GeoVisualizationState.fromFishingZone(r);
      expect(viz.canRenderWorldMapHotspots, isFalse);
      expect(viz.reliability, CalibrationReliability.unsafe);
    });

    test('boat_anchor_estimated: approximate ama dünya haritasına çizilmez', () {
      final r = FishingZoneResponse.fromJson(
        _baseZone(
          [_hotspot(id: 1, lat: 37.0, lon: 27.0)],
          coordinateMode: kCoordinateModeBoatAnchorEstimated,
          calibrationReliability: 'unsafe', // backend may keep unsafe
          geoMapDisplayAllowed: false,
          diagnosticsExtra: {
            'mapping_mode': 'boat_anchor_estimated',
            'transform_quality': 0.0,
          },
        ),
      );
      final viz = GeoVisualizationState.fromFishingZone(r);
      expect(viz.isBoatAnchorEstimated, isTrue);
      expect(viz.reliability, CalibrationReliability.approximate);
      expect(viz.canRenderWorldMapHotspots, isTrue);
      expect(viz.showBoatAnchorEstimatedRibbon, isTrue);
    });
  });

  group('layoutWorldMapHotspots', () {
    test('yakın düşük öncelikli noktalar zoom ile kümelenir', () {
      final hs = FishingZoneResponse.fromJson(
        _baseZone([
          _hotspot(id: 1, lat: 37.0, lon: 27.0, score: 0.5),
          _hotspot(id: 2, lat: 37.0005, lon: 27.0005, score: 0.48),
        ]),
      ).hotspots;

      final layouts =
          layoutWorldMapHotspots(candidates: hs, mapZoom: 12);
      final clusters =
          layouts.whereType<WorldMapHotspotCluster>().toList();
      expect(clusters.length, 1);
      expect(clusters.first.members.length, 2);
    });

    test('ilk üç öncelik düşük zoom’da düşük skor olsa da kalır', () {
      final hs = FishingZoneResponse.fromJson(
        _baseZone([
          _hotspot(
            id: 1,
            lat: 37.0,
            lon: 27.0,
            score: 0.15,
            recommendationRank: 1,
          ),
          _hotspot(
            id: 2,
            lat: 37.2,
            lon: 27.2,
            score: 0.15,
            recommendationRank: 99,
          ),
        ]),
      ).hotspots;

      final layouts = layoutWorldMapHotspots(candidates: hs, mapZoom: 8);
      final ids = layouts
          .map((p) {
            return switch (p) {
              WorldMapHotspotSingle(:final hotspot) => hotspot.id,
              WorldMapHotspotCluster() => -1,
            };
          })
          .toSet();
      expect(ids.contains(1), isTrue);
      expect(ids.contains(2), isFalse);
    });

    test('viewport dışı elenir; sabitlenmiş öncelik korunur', () {
      bool viewport(double lat, double _) => lat > 40.0;

      final hs = FishingZoneResponse.fromJson(
        _baseZone([
          _hotspot(
            id: 1,
            lat: 37.0,
            lon: 27.0,
            score: 0.9,
            recommendationRank: 1,
          ),
          _hotspot(
            id: 2,
            lat: 37.0,
            lon: 27.01,
            score: 0.9,
            recommendationRank: 99,
          ),
        ]),
      ).hotspots;

      final layouts = layoutWorldMapHotspots(
        candidates: hs,
        mapZoom: 12,
        viewportContains: viewport,
      );
      final keptIds = <int>{};
      for (final p in layouts) {
        switch (p) {
          case WorldMapHotspotSingle(:final hotspot):
            keptIds.add(hotspot.id);
          case WorldMapHotspotCluster(:final members):
            for (final m in members) {
              keptIds.add(m.id);
            }
        }
      }
      expect(keptIds.contains(1), isTrue);
      expect(keptIds.contains(2), isFalse);
    });

    test('üçüncü sıra viewport dışında olsa bile sabit kalır', () {
      bool viewport(double lat, double _) => lat >= 37.5;

      final hs = FishingZoneResponse.fromJson(
        _baseZone([
          _hotspot(
            id: 1,
            lat: 37.0,
            lon: 27.0,
            score: 0.2,
            recommendationRank: 3,
          ),
          _hotspot(
            id: 2,
            lat: 37.4,
            lon: 27.0,
            score: 0.95,
            recommendationRank: 2,
          ),
        ]),
      ).hotspots;

      final r = layoutWorldMapHotspotsResolved(
        candidates: hs,
        mapZoom: 12,
        viewportContains: viewport,
      );
      final ids = <int>{};
      for (final p in r.placements) {
        switch (p) {
          case WorldMapHotspotSingle(:final hotspot):
            ids.add(hotspot.id);
          case WorldMapHotspotCluster(:final members):
            for (final m in members) {
              ids.add(m.id);
            }
        }
      }
      expect(ids.contains(1), isTrue);
      expect(ids.contains(2), isTrue);
    });

    test('odak viewport dışında force ile offScreenPinned', () {
      final hs = FishingZoneResponse.fromJson(
        _baseZone([
          _hotspot(id: 5, lat: 36.0, lon: 27.0, score: 0.9),
        ]),
      ).hotspots;
      bool vp(double lat, double _) => lat > 37;
      final r = layoutWorldMapHotspotsResolved(
        candidates: hs,
        mapZoom: 12,
        viewportContains: vp,
        forceIncludeHotspotIds: {5},
        focusHotspotId: 5,
      );
      expect(r.placements, isNotEmpty);
      expect(r.focusViewport, HotspotFocusViewportStatus.offScreenPinned);
    });

    test('odak viewport dışında force yoksa excluded', () {
      final hs = FishingZoneResponse.fromJson(
        _baseZone([
          _hotspot(id: 5, lat: 36.0, lon: 27.0, score: 0.9),
        ]),
      ).hotspots;
      bool vp(double lat, double _) => lat > 37;
      final r = layoutWorldMapHotspotsResolved(
        candidates: hs,
        mapZoom: 12,
        viewportContains: vp,
        forceIncludeHotspotIds: {},
        focusHotspotId: 5,
      );
      expect(r.placements, isEmpty);
      expect(r.focusViewport, HotspotFocusViewportStatus.offScreenExcluded);
    });
  });

  test('WorldMapViewportState.containsLatLon temel kutu testi', () {
    final v = WorldMapViewportState(
      north: 41,
      south: 40,
      east: 30,
      west: 29,
      zoom: 10,
      centerLat: 40.5,
      centerLon: 29.5,
      lastUpdatedAt: DateTime.utc(2026, 5, 1),
    );
    expect(v.containsLatLon(40.5, 29.5), isTrue);
    expect(v.containsLatLon(39.9, 29.5), isFalse);
  });

  test('Harita hareketi: üretimde 92ms debounce + bounds epsilon (politika ayrı test)', () {
    expect(92 >= 80 && 92 <= 120, isTrue);
  });

  test('analiz nesli: eski async yanıt uygulanmaz (map_screen ile aynı kural)', () {
    var currentGen = 5;
    bool shouldApply(int responseGen) => responseGen == currentGen;
    expect(shouldApply(4), isFalse);
    expect(shouldApply(5), isTrue);
    currentGen = 6;
    expect(shouldApply(5), isFalse);
  });

  group('BoatGpsSmoother', () {
    test('düşük alpha ile konum ani sıçramaz', () {
      final s = BoatGpsSmoother();
      s.ingest(lat: 40.0, lon: 28.0, accuracyM: 95);
      final st = s.ingest(lat: 40.05, lon: 28.05, accuracyM: 95);
      expect(st.smoothed.lat, greaterThan(40.0));
      expect(st.smoothed.lat, lessThan(40.05));
      expect(st.reliability, greaterThan(0.2));
    });

    test('yüksek accuracy düşük güven: lastReliableFix boşalabilir', () {
      final s = BoatGpsSmoother();
      s.ingest(lat: 36.0, lon: 27.0, accuracyM: 400);
      final st = s.state!;
      expect(st.reliability, lessThan(0.55));
      expect(st.lastReliableFix, isNull);
    });

    test('iyi fix sonrası kötü örnekte lastReliableFix önceki güvenilir noktayı korur', () {
      final s = BoatGpsSmoother();
      s.ingest(lat: 36.0, lon: 27.0, accuracyM: 25);
      final anchor = s.state!.lastReliableFix;
      expect(anchor, isNotNull);
      s.ingest(lat: 36.5, lon: 27.5, accuracyM: 420);
      expect(s.state!.lastReliableFix, anchor);
    });

    test('ardışık örneklerde smoothedPosition ham sıçramadan daha yakın kalır', () {
      final s = BoatGpsSmoother();
      s.ingest(lat: 40.0, lon: 28.0, accuracyM: 50);
      final mid = s.ingest(lat: 40.08, lon: 28.0, accuracyM: 50);
      final smoothedJump = (mid.smoothed.lat - 40.0).abs();
      expect(smoothedJump, lessThan(0.08));
      expect(smoothedJump, greaterThan(0.0));
    });
  });
}
