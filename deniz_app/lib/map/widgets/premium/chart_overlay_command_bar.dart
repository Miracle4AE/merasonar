import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/widgets/premium/premium_dock_item.dart';
import 'package:deniz_app/widgets/premium/premium_glass_panel.dart';
import 'package:flutter/material.dart';

/// Chart overlay — Apple Dock tarzı command bar V2.
class ChartOverlayCommandBar extends StatelessWidget {
  const ChartOverlayCommandBar({
    super.key,
    required this.onAnalyze,
    required this.onCalibrate,
    required this.onWorldMap,
    required this.onCaptainAtlas,
    required this.onGpx,
    this.busy = false,
    this.worldMapEnabled = true,
    this.captainEnabled = true,
  });

  final VoidCallback? onAnalyze;
  final VoidCallback? onCalibrate;
  final VoidCallback? onWorldMap;
  final VoidCallback? onCaptainAtlas;
  final VoidCallback? onGpx;
  final bool busy;
  final bool worldMapEnabled;
  final bool captainEnabled;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: PremiumGlassPanel(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              blur: 22,
              elevation: 1.2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  PremiumDockItem(
                    icon: Icons.document_scanner_outlined,
                    label: kMapChartOverlayCmdAnalyze,
                    onPressed: busy ? null : onAnalyze,
                  ),
                  PremiumDockItem(
                    icon: Icons.my_location_rounded,
                    label: kMapChartOverlayCmdCalibrate,
                    onPressed: onCalibrate,
                  ),
                  PremiumDockItem(
                    icon: Icons.public_rounded,
                    label: kMapChartOverlayCmdWorldMap,
                    onPressed: worldMapEnabled ? onWorldMap : null,
                  ),
                  PremiumDockItem(
                    icon: Icons.auto_awesome_rounded,
                    label: kMapPremiumCommandCaptain,
                    onPressed: captainEnabled ? onCaptainAtlas : null,
                    accent: true,
                  ),
                  PremiumDockItem(
                    icon: Icons.download_rounded,
                    label: kMapChartOverlayCmdGpx,
                    onPressed: onGpx,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
