import 'package:flutter/foundation.dart';

import '../api_service.dart';
import 'calibration_geometry.dart';

/// Sunucu kalibrasyon güven katmanı — tek kaynaklı UI politikası.
enum CalibrationReliability {
  excellent,
  good,
  approximate,
  unsafe,
}

/// Dünya haritası + fotoğraf modu için immutable politika (scattered bool yerine).
@immutable
class GeoVisualizationState {
  const GeoVisualizationState({
    required this.coordinateMode,
    required this.reliability,
    required this.calibrationQuality,
    required this.transformConfidence,
    this.warningMessage,
    this.reasonCode,
    this.controlPointSpreadM,
    this.clientGeometry,
    this.markerAlignment,
  });

  /// Sunucu `coordinate_mode` (kanonik).
  final String coordinateMode;

  final CalibrationReliability reliability;

  /// OSM üzerinde gerçek koordinatlı mera işaretleri.
  bool get canRenderWorldMapHotspots =>
      reliability != CalibrationReliability.unsafe &&
      (coordinateMode == kCoordinateModeGeoReferenced ||
          coordinateMode == kCoordinateModeBoatAnchorEstimated);

  /// Kontrol noktası yok; tekne referanslı yaklaşık konum (dünya haritasında gösterilebilir
  /// ama güvenilir geo_referenced sayılmaz).
  bool get isBoatAnchorEstimated =>
      coordinateMode == kCoordinateModeBoatAnchorEstimated;

  /// Amber şerit — yaklaşık hizalama.
  bool get showApproximateRibbon =>
      reliability == CalibrationReliability.approximate &&
      canRenderWorldMapHotspots;

  /// Şerit — tekne referanslı yaklaşık konum uyarısı.
  bool get showBoatAnchorEstimatedRibbon => isBoatAnchorEstimated;

  /// Seyir için “yüksek güven” (UI yumuşatma / canlı skor ipuçları).
  bool get isReliableForNavigation =>
      (reliability == CalibrationReliability.excellent ||
          reliability == CalibrationReliability.good) &&
      confidenceLevel == CalibrationConfidenceLevel.valid;

  /// Birleşik kalibrasyon güven bandı (sunucu + istemci geometri + hotspot hizası).
  CalibrationConfidenceLevel get confidenceLevel {
    if (coordinateMode == kCoordinateModeUnknown ||
        coordinateMode == kCoordinateModeImageSpace) {
      return CalibrationConfidenceLevel.uncalibrated;
    }
    if (coordinateMode == kCoordinateModeBoatAnchorEstimated) {
      return CalibrationConfidenceLevel.fallbackBoatEstimated;
    }
    if (clientGeometry?.isInvalid == true) {
      return CalibrationConfidenceLevel.invalid;
    }
    if (clientGeometry?.isLowConfidence == true ||
        markerAlignment?.isStringLike == true ||
        reliability == CalibrationReliability.approximate) {
      return CalibrationConfidenceLevel.lowConfidence;
    }
    if (reliability == CalibrationReliability.unsafe) {
      return CalibrationConfidenceLevel.invalid;
    }
    if (reliability == CalibrationReliability.excellent ||
        reliability == CalibrationReliability.good) {
      return CalibrationConfidenceLevel.valid;
    }
    return CalibrationConfidenceLevel.lowConfidence;
  }

  bool get showLowConfidenceRibbon =>
      confidenceLevel == CalibrationConfidenceLevel.lowConfidence &&
      canRenderWorldMapHotspots;

  bool get showInvalidCalibrationRibbon =>
      confidenceLevel == CalibrationConfidenceLevel.invalid &&
      coordinateMode == kCoordinateModeGeoReferenced;

  bool get showValidCalibrationRibbon =>
      confidenceLevel == CalibrationConfidenceLevel.valid &&
      canRenderWorldMapHotspots;

  bool get showMarkerAlignmentWarning => markerAlignment?.isStringLike == true;

  final double calibrationQuality;
  final double transformConfidence;
  final String? warningMessage;
  final String? reasonCode;
  final double? controlPointSpreadM;
  final CalibrationGeometryAssessment? clientGeometry;
  final HotspotAlignmentAssessment? markerAlignment;

  static CalibrationReliability parseReliability(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'excellent':
        return CalibrationReliability.excellent;
      case 'good':
        return CalibrationReliability.good;
      case 'approximate':
        return CalibrationReliability.approximate;
      case 'unsafe':
        return CalibrationReliability.unsafe;
      default:
        return CalibrationReliability.unsafe;
    }
  }

  /// Eski sunucular: `calibration_reliability` yoksa tanılardan güvenli çıkarım.
  static CalibrationReliability inferLegacy(FishingZoneResponse r) {
    if (!r.resolveGeoMapDisplayAllowed()) {
      return CalibrationReliability.unsafe;
    }
    final e = r.diagnostics.georeferenceError;
    final q = r.diagnostics.transformQuality;
    if (e > 28.0 || q < 0.50) {
      return CalibrationReliability.approximate;
    }
    if (e > 15.0 || q < 0.72) {
      return CalibrationReliability.good;
    }
    return CalibrationReliability.excellent;
  }

  GeoVisualizationState withClientValidation({
    CalibrationGeometryAssessment? geometry,
    HotspotAlignmentAssessment? markerAlignment,
  }) {
    var nextReliability = reliability;
    if (geometry?.isInvalid == true) {
      nextReliability = CalibrationReliability.unsafe;
    } else if (geometry?.isLowConfidence == true ||
        markerAlignment?.isStringLike == true) {
      if (nextReliability == CalibrationReliability.excellent ||
          nextReliability == CalibrationReliability.good) {
        nextReliability = CalibrationReliability.approximate;
      }
    }

    return GeoVisualizationState(
      coordinateMode: coordinateMode,
      reliability: nextReliability,
      calibrationQuality: calibrationQuality,
      transformConfidence: transformConfidence,
      warningMessage: warningMessage,
      reasonCode: reasonCode ?? geometry?.reasonCode,
      controlPointSpreadM: controlPointSpreadM,
      clientGeometry: geometry ?? clientGeometry,
      markerAlignment: markerAlignment ?? this.markerAlignment,
    );
  }

  factory GeoVisualizationState.fromFishingZone(
    FishingZoneResponse response, {
    String? fallbackCoordinateModeHint,
    CalibrationGeometryAssessment? clientGeometry,
    HotspotAlignmentAssessment? markerAlignment,
  }) {
    final hinted = FishingZoneResponse.withEnsuredCoordinateMode(
      response,
      fallbackCoordinateModeHint: fallbackCoordinateModeHint,
    );
    final cm = hinted.coordinateMode ?? kCoordinateModeUnknown;
    final q = hinted.calibrationQuality ??
        hinted.diagnostics.transformQuality;
    final tc = hinted.transformConfidence ??
        hinted.diagnostics.transformQuality;
    final diagMode = hinted.diagnostics.mappingMode.toLowerCase();
    final trustworthyMapping =
        hinted.diagnostics.screenshotAlignedMappingUsed ||
        diagMode.contains('affine') ||
        diagMode.contains('control_point') ||
        diagMode.contains('screenshot');
    final rawRel =
        hinted.calibrationReliability?.trim() ??
        hinted.diagnostics.calibrationReliability?.trim();
    var reliability = rawRel != null && rawRel.isNotEmpty
        ? parseReliability(rawRel)
        : inferLegacy(hinted);

    if (cm == kCoordinateModeImageSpace) {
      reliability = CalibrationReliability.unsafe;
    } else if (cm == kCoordinateModeBoatAnchorEstimated) {
      // Yaklaşık tekne referanslı mod: dünya haritası hotspotları açık; geo_referenced değil.
      reliability = CalibrationReliability.approximate;
    } else if (hinted.geoMapDisplayAllowed == false &&
        (hinted.calibrationReliability?.toLowerCase() != 'approximate')) {
      reliability = CalibrationReliability.unsafe;
    }
    if (cm == kCoordinateModeGeoReferenced) {
      if (!trustworthyMapping) {
        reliability = CalibrationReliability.unsafe;
      } else if (!q.isFinite || q <= 0.0) {
        final serverAllowsDisplay =
            hinted.geoMapDisplayAllowed == true ||
            hinted.calibrationReliability?.toLowerCase() == 'approximate' ||
            hinted.diagnostics.calibrationReliability?.toLowerCase() ==
                'approximate';
        if (serverAllowsDisplay &&
            reliability == CalibrationReliability.unsafe) {
          reliability = CalibrationReliability.approximate;
        } else if (!serverAllowsDisplay) {
          final err = hinted.diagnostics.georeferenceError;
          if (err.isFinite && err > 2500.0) {
            reliability = CalibrationReliability.unsafe;
          } else if (reliability == CalibrationReliability.unsafe) {
            reliability = CalibrationReliability.approximate;
          }
        }
      }
    }

    final base = GeoVisualizationState(
      coordinateMode: cm,
      reliability: reliability,
      calibrationQuality: q,
      transformConfidence: tc,
      warningMessage: _resolveWarning(hinted),
      reasonCode: hinted.diagnostics.calibrationReliabilityReason,
      controlPointSpreadM: hinted.diagnostics.controlPointSpreadM,
      clientGeometry: clientGeometry,
      markerAlignment: markerAlignment,
    );
    if (clientGeometry != null || markerAlignment != null) {
      return base.withClientValidation(
        geometry: clientGeometry,
        markerAlignment: markerAlignment,
      );
    }
    return base;
  }

  static String? _resolveWarning(FishingZoneResponse hinted) {
    final direct = hinted.userWarningTr?.trim();
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }
    return null;
  }

  /// Önbellek / boş oturum.
  factory GeoVisualizationState.fallback() {
    return const GeoVisualizationState(
      coordinateMode: kCoordinateModeUnknown,
      reliability: CalibrationReliability.unsafe,
      calibrationQuality: 0,
      transformConfidence: 0,
    );
  }
}
