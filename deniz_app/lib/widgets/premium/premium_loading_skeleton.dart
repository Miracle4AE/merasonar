import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/theme/app_motion.dart';
import 'package:deniz_app/theme/app_radius.dart';
import 'package:deniz_app/widgets/premium/premium_animation_policy.dart';
import 'package:flutter/material.dart';

/// Glass shimmer skeleton — premium loading deneyimi.
class PremiumLoadingSkeleton extends StatefulWidget {
  const PremiumLoadingSkeleton({
    super.key,
    this.height = 88,
    this.width,
    this.borderRadius,
  });

  final double height;
  final double? width;
  final BorderRadius? borderRadius;

  @override
  State<PremiumLoadingSkeleton> createState() => _PremiumLoadingSkeletonState();
}

class _PremiumLoadingSkeletonState extends State<PremiumLoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.shimmer,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (PremiumAnimationPolicy.continuousMotionEnabled(context)) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!PremiumAnimationPolicy.continuousMotionEnabled(context)) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius ?? AppRadius.card,
          color: AppColors.surfaceDark,
          border: Border.all(color: AppColors.borderSoft(alpha: 0.14)),
        ),
      );
    }

    final radius = widget.borderRadius ?? AppRadius.card;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: AppColors.borderSoft(alpha: 0.14)),
              gradient: LinearGradient(
                begin: Alignment(-1 + _controller.value * 2, 0),
                end: Alignment(_controller.value * 2, 0),
                colors: [
                  AppColors.surfaceDark,
                  AppColors.surfaceElevated.withValues(alpha: 0.85),
                  AppColors.borderCyan.withValues(alpha: 0.08),
                  AppColors.surfaceDark,
                ],
                stops: const [0.0, 0.42, 0.52, 1.0],
              ),
            ),
          );
        },
      ),
    );
  }
}
