import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/world_map_hotspot_layout.dart';
import '../../l10n/app_strings_tr.dart';
import '../../services/boat_gps_smoother.dart';

/// Dünya haritası: GPS güven pill + odak ekran dışı uyarısı.
class WorldMapFloatingPills extends StatelessWidget {
  const WorldMapFloatingPills({
    super.key,
    required this.liveGpsState,
    required this.focusViewportStatus,
  });

  final ValueNotifier<AccuracyAwarePositionState?> liveGpsState;
  final ValueNotifier<HotspotFocusViewportStatus> focusViewportStatus;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 56,
      left: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ValueListenableBuilder<AccuracyAwarePositionState?>(
            valueListenable: liveGpsState,
            builder: (context, live, _) {
              if (live == null) return const SizedBox.shrink();
              final rel = live.reliability;
              final String label;
              if (rel >= 0.68) {
                label = kMapGpsPillReliable;
              } else if (rel >= 0.42) {
                label = kMapGpsPillApprox;
              } else {
                label = kMapGpsPillWeak;
              }
              final Color accent = rel >= 0.68
                  ? const Color(0xFF34D399)
                  : rel >= 0.42
                  ? const Color(0xFFFBBF24)
                  : const Color(0xFFF87171);
              return ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x66101828),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.42),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.satellite_alt_rounded,
                          size: 15,
                          color: accent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          ValueListenableBuilder<HotspotFocusViewportStatus>(
            valueListenable: focusViewportStatus,
            builder: (context, fs, _) {
              if (fs != HotspotFocusViewportStatus.offScreenPinned) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x66101828),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0x99F59E0B),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.visibility_off_outlined,
                            size: 15,
                            color: Colors.amber.shade200,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            kMapHotspotFocusOffScreen,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
