import 'package:flutter/material.dart';

import '../../domain/calibration_geometry.dart';
import '../../domain/geo_visualization_state.dart';
import '../../l10n/app_strings_tr.dart';

/// Kalibre dünya haritası üst şeridi (güven seviyesine göre).
class CalibratedModeRibbon extends StatelessWidget {
  const CalibratedModeRibbon({
    super.key,
    required this.geoViz,
    required this.showExperienceSwitcher,
  });

  final GeoVisualizationState geoViz;
  final bool showExperienceSwitcher;

  @override
  Widget build(BuildContext context) {
    if (!showExperienceSwitcher) {
      return const SizedBox.shrink();
    }

    final level = geoViz.confidenceLevel;
    if (level == CalibrationConfidenceLevel.fallbackBoatEstimated) {
      return _ribbon(
        icon: Icons.anchor_rounded,
        text: kMapModeBannerBoatAnchorFallback,
        fill: const Color(0x331565C0),
        border: const Color(0x6642A5F5),
        iconColor: const Color(0xFFBBDEFB),
        textColor: const Color(0xFFE3F2FD),
      );
    }

    if (!geoViz.canRenderWorldMapHotspots) {
      if (level == CalibrationConfidenceLevel.uncalibrated) {
        return _ribbon(
          icon: Icons.info_outline_rounded,
          text: kMapModeBannerUncalibrated,
          fill: const Color(0x33445566),
          border: const Color(0x668899AA),
          iconColor: Colors.white70,
          textColor: Colors.white70,
        );
      }
      return const SizedBox.shrink();
    }

    if (geoViz.showInvalidCalibrationRibbon) {
      return _ribbon(
        icon: Icons.error_outline_rounded,
        text: kMapModeBannerInvalidCalibration,
        fill: const Color(0x44B71C1C),
        border: const Color(0x66EF5350),
        iconColor: const Color(0xFFFFCDD2),
        textColor: const Color(0xFFFFEBEE),
      );
    }

    if (geoViz.showLowConfidenceRibbon || geoViz.showApproximateRibbon) {
      final text = geoViz.showMarkerAlignmentWarning
          ? '$kMapModeBannerLowConfidence $kMapModeBannerMarkerAlignment'
          : kMapModeBannerLowConfidence;
      return _ribbon(
        icon: Icons.warning_amber_rounded,
        text: text,
        fill: const Color(0x33E65100),
        border: const Color(0x66FFCC80),
        iconColor: Colors.amber.shade200,
        textColor: Colors.amber.shade50,
      );
    }

    if (geoViz.showValidCalibrationRibbon) {
      return _ribbon(
        icon: Icons.verified_rounded,
        text: kMapModeBannerCalibrated,
        fill: const Color(0x3327AE60),
        border: const Color(0x5527AE60),
        iconColor: const Color(0xFF69F0AE),
        textColor: Colors.tealAccent.shade100,
      );
    }

    return const SizedBox.shrink();
  }

  Widget _ribbon({
    required IconData icon,
    required String text,
    required Color fill,
    required Color border,
    required Color iconColor,
    required Color textColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
