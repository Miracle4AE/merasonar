import '../domain/world_map_viewport_state.dart';

/// Harita hareketinde tamponlama — setState fırtınası yerine kontrollü güncelleme.
class MapCameraUpdatePolicy {
  MapCameraUpdatePolicy({
    this.minInterval = const Duration(milliseconds: 110),
    this.zoomEpsilon = 0.045,
    this.boundsEpsilonDeg = 0.00015,
  });

  final Duration minInterval;
  final double zoomEpsilon;
  final double boundsEpsilonDeg;

  DateTime? _lastEmitAt;
  WorldMapViewportState? _lastEmitted;

  /// [true]: hemen yayınla; [false]: sadece zamanlayıcı ile kuyruğa alınmış olabilir.
  bool shouldEmitNow({
    required DateTime now,
    required WorldMapViewportState candidate,
  }) {
    final prev = _lastEmitted;
    final lastAt = _lastEmitAt;

    if (prev == null || lastAt == null) {
      _commit(now, candidate);
      return true;
    }

    final dt = now.difference(lastAt);
    final zoomJump = (candidate.zoom - prev.zoom).abs() >= zoomEpsilon;
    final boundsJump = !candidate.approximatelySameAs(
      prev,
      edgeEpsilonDeg: boundsEpsilonDeg,
      zoomEpsilon: zoomEpsilon,
    );

    if (zoomJump || boundsJump) {
      _commit(now, candidate);
      return true;
    }

    if (dt >= minInterval) {
      _commit(now, candidate);
      return true;
    }

    return false;
  }

  void forceEmit({
    required DateTime now,
    required WorldMapViewportState candidate,
  }) {
    _commit(now, candidate);
  }

  void _commit(DateTime now, WorldMapViewportState candidate) {
    _lastEmitAt = now;
    _lastEmitted = candidate;
  }

  WorldMapViewportState? get lastEmitted => _lastEmitted;

  void reset() {
    _lastEmitAt = null;
    _lastEmitted = null;
  }
}
