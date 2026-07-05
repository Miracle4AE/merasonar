import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/theme/app_motion.dart';
import 'package:deniz_app/theme/app_radius.dart';
import 'package:deniz_app/theme/app_shadows.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/widgets/premium/premium_animation_policy.dart';
import 'package:deniz_app/widgets/premium/motion/premium_micro_interaction.dart';
import 'package:deniz_app/widgets/premium/premium_live_glow.dart';
import 'package:flutter/material.dart';

class PremiumCard extends StatelessWidget {
  const PremiumCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.glow = false,
    this.height,
    this.width,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final bool glow;
  final double? height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final cardBody = AnimatedContainer(
      duration: AppMotion.hover,
      curve: AppMotion.microCurve,
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark.withValues(alpha: 0.94),
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.borderSoft(alpha: 0.24)),
        boxShadow: glow ? AppShadows.cardGlow : AppShadows.softDepth,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceElevated.withValues(alpha: 0.35),
            AppColors.surfaceDark.withValues(alpha: 0.05),
          ],
        ),
      ),
      child: child,
    );

    final interactive = PremiumMicroInteraction(
      onTap: onTap,
      enabled: onTap != null,
      child: cardBody,
    );

    if (!glow || PremiumAnimationPolicy.glowIntensity(context) < 0.2) {
      return interactive;
    }

    return PremiumLiveGlow(
      enabled: glow,
      intensity: 0.85 * PremiumAnimationPolicy.glowIntensity(context),
      child: interactive,
    );
  }
}
