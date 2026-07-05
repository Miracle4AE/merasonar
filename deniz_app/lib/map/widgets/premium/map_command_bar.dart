import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/widgets/premium/premium_dock_item.dart';
import 'package:deniz_app/widgets/premium/premium_glass_panel.dart';
import 'package:flutter/material.dart';

/// Apple Dock tarzı premium command bar V2.
class MapCommandBar extends StatelessWidget {
  const MapCommandBar({
    super.key,
    required this.onScanArea,
    required this.onLiveAnalysis,
    required this.onCoordinate,
    required this.onCompare,
    required this.onCaptainAtlas,
    this.busy = false,
  });

  final VoidCallback? onScanArea;
  final VoidCallback? onLiveAnalysis;
  final VoidCallback? onCoordinate;
  final VoidCallback? onCompare;
  final VoidCallback? onCaptainAtlas;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: PremiumGlassPanel(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          blur: 22,
          elevation: 1.2,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              PremiumDockItem(
                key: const Key('btn_scan_area'),
                icon: Icons.radar_rounded,
                label: kMapPremiumCommandScan,
                onPressed: busy ? null : onScanArea,
              ),
              PremiumDockItem(
                key: const Key('btn_live_analysis'),
                icon: Icons.sensors_rounded,
                label: kMapPremiumCommandLive,
                onPressed: onLiveAnalysis,
              ),
              PremiumDockItem(
                key: const Key('btn_coordinate_analysis'),
                icon: Icons.pin_drop_rounded,
                label: kMapPremiumCommandCoord,
                onPressed: onCoordinate,
              ),
              PremiumDockItem(
                key: const Key('btn_compare'),
                icon: Icons.compare_arrows_rounded,
                label: kMapPremiumCommandCompare,
                onPressed: onCompare,
              ),
              PremiumDockItem(
                key: const Key('btn_captain_atlas'),
                icon: Icons.auto_awesome_rounded,
                label: kMapPremiumCommandCaptain,
                onPressed: onCaptainAtlas,
                accent: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
