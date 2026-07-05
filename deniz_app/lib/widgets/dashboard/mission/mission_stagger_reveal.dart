import 'package:deniz_app/theme/app_motion.dart';
import 'package:deniz_app/widgets/premium/premium_animation_policy.dart';
import 'package:flutter/material.dart';

/// Dashboard bölümleri için hafif staggered reveal.
class MissionStaggerReveal extends StatefulWidget {
  const MissionStaggerReveal({
    super.key,
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  @override
  State<MissionStaggerReveal> createState() => _MissionStaggerRevealState();
}

class _MissionStaggerRevealState extends State<MissionStaggerReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: AppMotion.pageCurve);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: AppMotion.pageCurve));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!PremiumAnimationPolicy.continuousMotionEnabled(context)) {
      _ctrl.value = 1;
      return;
    }
    if (_ctrl.isCompleted) return;
    Future<void>.delayed(Duration(milliseconds: 40 * widget.index), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!PremiumAnimationPolicy.continuousMotionEnabled(context)) {
      return widget.child;
    }
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
