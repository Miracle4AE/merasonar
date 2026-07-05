import 'package:deniz_app/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Harita kenarlarında hafif vignette — derinlik hissi.
class MapVignetteOverlay extends StatelessWidget {
  const MapVignetteOverlay({super.key, this.intensity = 0.45});

  final double intensity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.05,
            colors: [
              Colors.transparent,
              AppColors.backgroundDeep.withValues(alpha: intensity * 0.35),
            ],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}
