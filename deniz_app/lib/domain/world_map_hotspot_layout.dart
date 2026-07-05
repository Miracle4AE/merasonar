import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../api_service.dart';

/// Tekil veya küme — OSM marker katmanı için ara temsil.
@immutable
sealed class WorldMapHotspotPlacement {
  const WorldMapHotspotPlacement();
}

@immutable
class WorldMapHotspotSingle extends WorldMapHotspotPlacement {
  const WorldMapHotspotSingle(this.hotspot);

  final Hotspot hotspot;
}

@immutable
class WorldMapHotspotCluster extends WorldMapHotspotPlacement {
  const WorldMapHotspotCluster({
    required this.center,
    required this.members,
    required this.bestScore,
  });

  final ({double latitude, double longitude}) center;
  final List<Hotspot> members;
  final double bestScore;
}

/// Odaklanan hotspot'un görünür alanla ilişkisi (UI şerit / pill için).
enum HotspotFocusViewportStatus {
  none,
  viewportUnknown,
  onScreen,
  offScreenPinned,
  offScreenExcluded,
}

@immutable
class WorldMapHotspotLayoutResult {
  const WorldMapHotspotLayoutResult({
    required this.placements,
    required this.focusViewport,
    this.inputCandidateCount = 0,
    this.droppedByMinScore = 0,
    this.hiddenByViewportFilter = 0,
  });

  final List<WorldMapHotspotPlacement> placements;
  final HotspotFocusViewportStatus focusViewport;

  /// [layoutWorldMapHotspotsResolved] girdi adayı sayısı.
  final int inputCandidateCount;

  /// Yakın zoom eşiği ([_minScoreForZoom]) ile elenen adaylar.
  final int droppedByMinScore;

  /// Görünür alan süzgeci ile elenen adaylar (sabitlenenler hariç).
  final int hiddenByViewportFilter;
}

/// Zoom'a bağlı kümeleme: ilk 3 öncelik sabit; düşük zoom'da düşük skor elenir.
WorldMapHotspotLayoutResult layoutWorldMapHotspotsResolved({
  required List<Hotspot> candidates,
  required double mapZoom,
  bool Function(double lat, double lon)? viewportContains,
  Set<int> forceIncludeHotspotIds = const <int>{},
  Set<int> pinAsSingleHotspotIds = const <int>{},
  int? focusHotspotId,
  bool boatAnchorEstimatedPolicy = false,
}) {
  final inputCount = candidates.length;
  if (candidates.isEmpty) {
    return const WorldMapHotspotLayoutResult(
      placements: [],
      focusViewport: HotspotFocusViewportStatus.none,
      inputCandidateCount: 0,
    );
  }

  final pinned = <Hotspot>{};
  for (final h in candidates) {
    final pr = h.recommendationRank;
    if (pr >= 1 && pr <= 3) {
      pinned.add(h);
    }
  }
  for (final h in candidates) {
    if (pinAsSingleHotspotIds.contains(h.id)) {
      pinned.add(h);
    }
  }

  final minScore =
      boatAnchorEstimatedPolicy ? 0.0 : _minScoreForZoom(mapZoom);
  var work = candidates.where((h) {
    if (pinned.contains(h)) return true;
    if (h.score < minScore) return false;
    return true;
  }).toList();

  final droppedByMinScore = inputCount - work.length;

  final inside = viewportContains;
  final beforeViewport = work.length;
  if (inside != null) {
    work = work.where((h) {
      if (pinned.contains(h)) return true;
      final lat = h.latitude;
      final lon = h.longitude;
      if (!lat.isFinite || !lon.isFinite) return false;
      return inside(lat, lon);
    }).toList();
  }

  final hiddenByViewportFilter =
      inside == null ? 0 : (beforeViewport - work.length).clamp(0, beforeViewport);

  if (forceIncludeHotspotIds.isNotEmpty) {
    final have = work.map((h) => h.id).toSet();
    for (final h in candidates) {
      if (forceIncludeHotspotIds.contains(h.id) && !have.contains(h.id)) {
        work.add(h);
        have.add(h.id);
      }
    }
  }

  work.sort((a, b) {
    final c = b.score.compareTo(a.score);
    if (c != 0) return c;
    return a.id.compareTo(b.id);
  });

  final clusters = <_ClusterAcc>[];
  final singles = <Hotspot>[];

  for (final h in work) {
    if (pinned.contains(h)) {
      singles.add(h);
      continue;
    }
    _ClusterAcc? hit;
    for (final c in clusters) {
      if (_haversineMeters(c.centerLat, c.centerLon, h.latitude, h.longitude) <=
          _epsMetersFromZoom(mapZoom)) {
        hit = c;
        break;
      }
    }
    if (hit == null) {
      clusters.add(
        _ClusterAcc(
          centerLat: h.latitude,
          centerLon: h.longitude,
          members: [h],
        ),
      );
    } else {
      hit.add(h);
    }
  }

  final out = <WorldMapHotspotPlacement>[];
  for (final h in singles) {
    out.add(WorldMapHotspotSingle(h));
  }
  for (final c in clusters) {
    if (c.members.length == 1) {
      out.add(WorldMapHotspotSingle(c.members.first));
    } else {
      final lat = c.centerLat;
      final lon = c.centerLon;
      c.members.sort((a, b) => b.score.compareTo(a.score));
      out.add(
        WorldMapHotspotCluster(
          center: (latitude: lat, longitude: lon),
          members: List<Hotspot>.unmodifiable(c.members),
          bestScore: c.members.first.score,
        ),
      );
    }
  }

  out.sort((a, b) {
    int rankOf(WorldMapHotspotPlacement p) {
      switch (p) {
        case WorldMapHotspotSingle(:final hotspot):
          final pr = hotspot.recommendationRank;
          if (pr >= 1 && pr <= 3) return pr;
          return 99;
        case WorldMapHotspotCluster():
          return 50;
      }
    }

    final ra = rankOf(a);
    final rb = rankOf(b);
    if (ra != rb) return ra.compareTo(rb);
    if (a is WorldMapHotspotSingle && b is WorldMapHotspotSingle) {
      return b.hotspot.score.compareTo(a.hotspot.score);
    }
    if (a is WorldMapHotspotCluster && b is WorldMapHotspotCluster) {
      return b.bestScore.compareTo(a.bestScore);
    }
    return 0;
  });

  final focusStatus = _resolveFocusViewport(
    candidates: candidates,
    viewportContains: viewportContains,
    focusHotspotId: focusHotspotId,
    forceIncludeHotspotIds: forceIncludeHotspotIds,
  );

  return WorldMapHotspotLayoutResult(
    placements: out,
    focusViewport: focusStatus,
    inputCandidateCount: inputCount,
    droppedByMinScore: droppedByMinScore,
    hiddenByViewportFilter: hiddenByViewportFilter,
  );
}

HotspotFocusViewportStatus _resolveFocusViewport({
  required List<Hotspot> candidates,
  required bool Function(double lat, double lon)? viewportContains,
  required int? focusHotspotId,
  required Set<int> forceIncludeHotspotIds,
}) {
  if (focusHotspotId == null) {
    return HotspotFocusViewportStatus.none;
  }
  if (viewportContains == null) {
    return HotspotFocusViewportStatus.viewportUnknown;
  }
  Hotspot? focus;
  for (final h in candidates) {
    if (h.id == focusHotspotId) {
      focus = h;
      break;
    }
  }
  if (focus == null) {
    return HotspotFocusViewportStatus.none;
  }
  final lat = focus.latitude;
  final lon = focus.longitude;
  if (!lat.isFinite || !lon.isFinite) {
    return HotspotFocusViewportStatus.none;
  }
  final onMap = viewportContains(lat, lon);
  if (onMap) {
    return HotspotFocusViewportStatus.onScreen;
  }
  if (forceIncludeHotspotIds.contains(focusHotspotId)) {
    return HotspotFocusViewportStatus.offScreenPinned;
  }
  return HotspotFocusViewportStatus.offScreenExcluded;
}

/// Geriye dönük: yalnızca yerleşim listesi.
List<WorldMapHotspotPlacement> layoutWorldMapHotspots({
  required List<Hotspot> candidates,
  required double mapZoom,
  bool Function(double lat, double lon)? viewportContains,
  Set<int> forceIncludeHotspotIds = const <int>{},
  int? focusHotspotId,
}) {
  return layoutWorldMapHotspotsResolved(
    candidates: candidates,
    mapZoom: mapZoom,
    viewportContains: viewportContains,
    forceIncludeHotspotIds: forceIncludeHotspotIds,
    focusHotspotId: focusHotspotId,
  ).placements;
}

/// Geçerli dünya lat/lon (sentinel 0,0 hariç).
bool hotspotHasPlausibleWorldMapGeo(Hotspot h) {
  if (!h.latitude.isFinite || !h.longitude.isFinite) return false;
  if (h.latitude.abs() < 1e-9 && h.longitude.abs() < 1e-9) return false;
  return true;
}

/// ``boat_anchor_estimated`` acil modu: kümeleme / viewport / zoom süzgeci yok;
/// sunucu listesinden en fazla [maxMarkers] geo geçerli nokta (sıralı).
List<Hotspot> boatAnchorEmergencyWorldMapHotspots(
  List<Hotspot> source,
  int maxMarkers,
  int Function(Hotspot a, Hotspot b) compare,
) {
  if (maxMarkers <= 0) return const [];
  final geo = source.where(hotspotHasPlausibleWorldMapGeo).toList();
  geo.sort(compare);
  if (geo.length <= maxMarkers) return geo;
  return geo.sublist(0, maxMarkers);
}

/// Tekne referanslı yaklaşık mod: ilk [take] adet geçerli lat/lon id’si (sıralı liste).
Set<int> topGeoHotspotIdsForBoatAnchorPolicy(
  List<Hotspot> sortedCandidates,
  int take,
) {
  if (take <= 0) return const <int>{};
  final out = <int>{};
  for (final h in sortedCandidates) {
    if (!h.latitude.isFinite || !h.longitude.isFinite) continue;
    if (h.latitude.abs() < 1e-9 && h.longitude.abs() < 1e-9) continue;
    out.add(h.id);
    if (out.length >= take) break;
  }
  return out;
}

double _minScoreForZoom(double z) {
  if (z < 9.5) return 0.42;
  if (z < 11.5) return 0.32;
  return 0.0;
}

double _epsMetersFromZoom(double z) {
  if (z < 9) return 2200;
  if (z < 11) return 900;
  if (z < 13) return 380;
  return 160;
}

double _haversineMeters(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371000.0;
  final p1 = lat1 * math.pi / 180;
  final p2 = lat2 * math.pi / 180;
  final dp = (lat2 - lat1) * math.pi / 180;
  final dl = (lon2 - lon1) * math.pi / 180;
  final a = math.sin(dp / 2) * math.sin(dp / 2) +
      math.cos(p1) * math.cos(p2) * math.sin(dl / 2) * math.sin(dl / 2);
  return 2 * r * math.asin(math.min(1.0, math.sqrt(a)));
}

class _ClusterAcc {
  _ClusterAcc({
    required this.centerLat,
    required this.centerLon,
    required this.members,
  });

  double centerLat;
  double centerLon;
  final List<Hotspot> members;

  void add(Hotspot h) {
    final n = members.length + 1;
    centerLat =
        (centerLat * members.length + h.latitude) / n;
    centerLon =
        (centerLon * members.length + h.longitude) / n;
    members.add(h);
  }
}
