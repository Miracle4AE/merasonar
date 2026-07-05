import 'package:flutter/foundation.dart';

import '../api_service.dart';

/// GPS doğruluğuna göre yumuşatma — ani tekne sıçramasını azaltır.
@immutable
class AccuracyAwarePositionState {
  const AccuracyAwarePositionState({
    required this.smoothed,
    this.lastRaw,
    this.currentAccuracyM,
    this.reliability = 1.0,
    this.lastReliableFix,
  });

  final LatLon smoothed;
  final LatLon? lastRaw;
  final double? currentAccuracyM;

  /// 0..1 (1 = yüksek güven).
  final double reliability;
  final LatLon? lastReliableFix;

  AccuracyAwarePositionState copyWith({
    LatLon? smoothed,
    LatLon? lastRaw,
    double? currentAccuracyM,
    double? reliability,
    LatLon? lastReliableFix,
  }) {
    return AccuracyAwarePositionState(
      smoothed: smoothed ?? this.smoothed,
      lastRaw: lastRaw ?? this.lastRaw,
      currentAccuracyM: currentAccuracyM ?? this.currentAccuracyM,
      reliability: reliability ?? this.reliability,
      lastReliableFix: lastReliableFix ?? this.lastReliableFix,
    );
  }
}

class BoatGpsSmoother {
  AccuracyAwarePositionState? _state;

  AccuracyAwarePositionState? get state => _state;

  /// Sunucudan gelen süzülmüş GPS ile başlat (analiz sonrası sıçrama yok).
  void seedFromBoatState(BoatState boat) {
    final s = boat.smoothedGps;
    if (!_plausible(s)) {
      return;
    }
    _state = AccuracyAwarePositionState(
      smoothed: s,
      lastRaw: boat.rawGps,
      currentAccuracyM: null,
      reliability: 1.0,
      lastReliableFix: s,
    );
  }

  /// Cihazdan yeni örnek (accuracy m — düşükse güçlü süzme).
  AccuracyAwarePositionState ingest({
    required double lat,
    required double lon,
    double? accuracyM,
  }) {
    final raw = LatLon(lat: lat, lon: lon);
    if (!_plausible(raw)) {
      return _state ??
          AccuracyAwarePositionState(
            smoothed: raw,
            lastRaw: raw,
            currentAccuracyM: accuracyM,
            reliability: 0.0,
          );
    }

    final prev = _state?.smoothed;
    final acc = accuracyM;
    final alpha = _alphaForAccuracy(acc);
    final rel = _reliabilityFromAccuracy(acc);

    if (prev == null) {
      final next = AccuracyAwarePositionState(
        smoothed: raw,
        lastRaw: raw,
        currentAccuracyM: acc,
        reliability: rel,
        lastReliableFix: rel >= 0.55 ? raw : null,
      );
      _state = next;
      return next;
    }

    final slat = prev.lat + alpha * (lat - prev.lat);
    final slon = prev.lon + alpha * (lon - prev.lon);
    final sm = LatLon(lat: slat, lon: slon);

    final lastRel =
        rel >= 0.55 ? sm : _state?.lastReliableFix;

    final next = AccuracyAwarePositionState(
      smoothed: sm,
      lastRaw: raw,
      currentAccuracyM: acc,
      reliability: rel,
      lastReliableFix: lastRel,
    );
    _state = next;
    return next;
  }

  void reset() {
    _state = null;
  }

  static bool _plausible(LatLon ll) {
    if (!ll.lat.isFinite || !ll.lon.isFinite) return false;
    if (ll.lat.abs() > 90 || ll.lon.abs() > 180) return false;
    if (ll.lat.abs() < 1e-8 && ll.lon.abs() < 1e-8) return false;
    return true;
  }

  static double _alphaForAccuracy(double? accuracyM) {
    if (accuracyM == null || !accuracyM.isFinite || accuracyM <= 0) {
      return 0.22;
    }
    final a = (accuracyM / 85.0).clamp(0.06, 0.38);
    return a;
  }

  static double _reliabilityFromAccuracy(double? accuracyM) {
    if (accuracyM == null || !accuracyM.isFinite) return 0.75;
    return (1.0 - (accuracyM / 120.0)).clamp(0.15, 1.0);
  }
}
