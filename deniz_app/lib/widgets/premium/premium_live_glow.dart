import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/theme/app_motion.dart';
import 'package:deniz_app/widgets/premium/premium_animation_policy.dart';
import 'package:flutter/material.dart';

/// Hafif nefes alan glow — skor, marker, Captain Atlas için.
class PremiumLiveGlow extends StatefulWidget {
  const PremiumLiveGlow({
    super.key,
    required this.child,
    this.color,
    this.enabled = true,
    this.intensity = 1.0,
  });

  final Widget child;
  final Color? color;
  final bool enabled;
  final double intensity;

  @override
  State<PremiumLiveGlow> createState() => _PremiumLiveGlowState();
}

class _PremiumLiveGlowState extends State<PremiumLiveGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.glowBreath,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant PremiumLiveGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  void _syncAnimation() {
    final shouldAnimate = widget.enabled &&
        PremiumAnimationPolicy.continuousMotionEnabled(context);
    if (shouldAnimate) {
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
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
    if (!widget.enabled) return widget.child;
    if (!PremiumAnimationPolicy.continuousMotionEnabled(context)) {
      return widget.child;
    }

    final scale = PremiumAnimationPolicy.motionScale(context);
    if (scale <= 0) return widget.child;

    final glowColor = widget.color ?? AppColors.accentTeal;
    final intensity = widget.intensity * scale * PremiumAnimationPolicy.glowIntensity(context);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(_controller.value);
          final alpha = (0.12 + t * 0.14) * intensity;
          final blur = 10 + t * 14;
          return Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: glowColor.withValues(alpha: alpha),
                  blurRadius: blur,
                  spreadRadius: 0.5 + t * 2,
                ),
              ],
            ),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}
