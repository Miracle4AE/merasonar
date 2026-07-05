import 'package:flutter/material.dart';

/// Splash / Home ile aynı koyu deniz gökyüzü + ufuk bandı — [shouldRepaint] false.
class SkyGradientPainter extends CustomPainter {
  const SkyGradientPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final g = RadialGradient(
      center: const Alignment(-0.1, -0.75),
      radius: 1.15,
      colors: const [
        Color(0xFF0F2338),
        Color(0xFF060F1C),
        Color(0xFF020814),
      ],
      stops: const [0.0, 0.55, 1.0],
    ).createShader(rect);
    canvas.drawRect(rect, Paint()..shader = g);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            const Color(0xFF051018).withValues(alpha: 0.45),
          ],
          stops: const [0.35, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant SkyGradientPainter oldDelegate) => false;
}
