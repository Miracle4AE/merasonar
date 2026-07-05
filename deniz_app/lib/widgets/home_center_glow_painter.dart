import 'package:flutter/material.dart';

/// Orta sahne için yumuşak derinlik ışığı (statik).
class HomeCenterGlowPainter extends CustomPainter {
  const HomeCenterGlowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final g = RadialGradient(
      center: const Alignment(0.0, -0.1),
      radius: 0.75,
      colors: [
        const Color(0xFF5EB8DD).withValues(alpha: 0.14),
        const Color(0xFF1E4B63).withValues(alpha: 0.06),
        Colors.transparent,
      ],
      stops: const [0.0, 0.45, 1.0],
    ).createShader(rect);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = g
        ..blendMode = BlendMode.plus,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
