import 'package:deniz_app/theme/app_motion.dart';
import 'package:flutter/material.dart';

/// Kartlara Vision Pro tarzı micro-interaction: parallax, press, glow lift.
class PremiumMicroInteraction extends StatefulWidget {
  const PremiumMicroInteraction({
    super.key,
    required this.child,
    this.onTap,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  State<PremiumMicroInteraction> createState() => _PremiumMicroInteractionState();
}

class _PremiumMicroInteractionState extends State<PremiumMicroInteraction> {
  bool _hovered = false;
  bool _pressed = false;
  Offset _pointer = Offset.zero;

  void _updatePointer(Offset local) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final size = box.size;
    final nx = (local.dx / size.width - 0.5).clamp(-0.5, 0.5);
    final ny = (local.dy / size.height - 0.5).clamp(-0.5, 0.5);
    setState(() => _pointer = Offset(nx, ny));
  }

  @override
  Widget build(BuildContext context) {
    final scale = _pressed
        ? AppMotion.pressScale
        : (_hovered ? AppMotion.hoverLift : 1.0);
    final tiltX = _pointer.dy * AppMotion.parallaxMaxTilt;
    final tiltY = -_pointer.dx * AppMotion.parallaxMaxTilt;
    final liftY = _hovered && !_pressed ? -2.0 : (_pressed ? 1.0 : 0.0);

    final duration = _pressed ? AppMotion.microPress : AppMotion.microRelease;
    final curve = _pressed ? AppMotion.microCurve : AppMotion.releaseCurve;

    final transformed = AnimatedContainer(
      duration: duration,
      curve: curve,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateX(tiltX)
        ..rotateY(tiltY)
        ..translateByDouble(0.0, liftY, 0.0, 1.0)
        ..scaleByDouble(scale, scale, scale, 1.0),
      transformAlignment: Alignment.center,
      child: widget.child,
    );

    if (!widget.enabled || widget.onTap == null) {
      return MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() {
          _hovered = false;
          _pointer = Offset.zero;
        }),
        onHover: (e) => _updatePointer(e.localPosition),
        child: transformed,
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
        _pointer = Offset.zero;
      }),
      onHover: (e) => _updatePointer(e.localPosition),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: transformed,
      ),
    );
  }
}
