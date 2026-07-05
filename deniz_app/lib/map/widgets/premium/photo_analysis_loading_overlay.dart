import 'dart:async';

import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/widgets/premium/premium_animation_policy.dart';
import 'package:deniz_app/widgets/premium/premium_glass_panel.dart';
import 'package:deniz_app/widgets/premium/premium_live_glow.dart';
import 'package:flutter/material.dart';

class PhotoAnalysisLoadingOverlay extends StatefulWidget {
  const PhotoAnalysisLoadingOverlay({super.key});

  @override
  State<PhotoAnalysisLoadingOverlay> createState() =>
      _PhotoAnalysisLoadingOverlayState();
}

class _PhotoAnalysisLoadingOverlayState extends State<PhotoAnalysisLoadingOverlay> {
  static const _steps = [
    kMapPhotoLoadingReadImage,
    kMapPhotoLoadingBathymetry,
    kMapPhotoLoadingRankHotspots,
    kMapPhotoLoadingFinalize,
  ];

  int _stepIndex = 0;
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _armStepTimer();
  }

  void _armStepTimer() {
    _timer?.cancel();
    if (!PremiumAnimationPolicy.continuousMotionEnabled(context)) return;
    _timer = Timer.periodic(const Duration(milliseconds: 2200), (_) {
      if (!mounted) return;
      setState(() => _stepIndex = (_stepIndex + 1) % _steps.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = PremiumAnimationPolicy.continuousMotionEnabled(context);

    return ColoredBox(
      color: AppColors.backgroundDeep.withValues(alpha: 0.72),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: PremiumLiveGlow(
            enabled: motion,
            intensity: 0.75,
            child: PremiumGlassPanel(
              padding: const EdgeInsets.all(AppSpacing.lg),
              blur: 20,
              elevation: 1.1,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.accentTeal,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    child: Text(
                      _steps[_stepIndex],
                      key: ValueKey(_stepIndex),
                      style: AppTextStyles.cardTitle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    kMapFabScanning,
                    style: AppTextStyles.caption,
                    textAlign: TextAlign.center,
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
