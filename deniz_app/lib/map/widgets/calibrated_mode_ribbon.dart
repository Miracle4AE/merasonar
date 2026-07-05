import 'package:flutter/material.dart';

import '../../domain/geo_visualization_state.dart';
import '../../l10n/app_strings_tr.dart';

/// Kalibre dünya haritası üst şeridi (yaklaşık / doğrulanmış).
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
    if (geoViz.showBoatAnchorEstimatedRibbon) {
      return Padding(
        padding: const EdgeInsets.only(left: 12, right: 12, bottom: 6),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0x331565C0),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0x6642A5F5)),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Icon(Icons.anchor_rounded, color: Color(0xFFBBDEFB), size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    kMapBoatAnchorEstimatedRibbon,
                    style: TextStyle(
                      color: Color(0xFFE3F2FD),
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
    if (!geoViz.canRenderWorldMapHotspots) {
      return const SizedBox.shrink();
    }
    if (geoViz.showApproximateRibbon) {
      return Padding(
        padding: const EdgeInsets.only(left: 12, right: 12, bottom: 6),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0x33E65100),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0x66FFCC80)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Colors.amber.shade200, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    kMapApproximateRibbon,
                    style: TextStyle(
                      color: Colors.amber.shade50,
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
    if (!geoViz.isReliableForNavigation) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0x3327AE60),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x5527AE60)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              const Icon(Icons.verified_rounded,
                  color: Color(0xFF69F0AE), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  kMapModeBannerCalibrated,
                  style: TextStyle(
                    color: Colors.tealAccent.shade100,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
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
