import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Tek dokunuşta yumuşak sonar halkası — küçük bölgelerde kısa süreli repaint.
class SonarTapRingPainter extends CustomPainter {
  SonarTapRingPainter(this.t);

  /// 0..1 tek atım.
  final double t;

  static const _c = Color(0xFF4DD0E1);

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0) return;
    final cx = size.width * 0.5;
    final cy = size.height * 0.5;
    final m = math.min(size.width, size.height) * 0.52;
    for (var ring = 0; ring < 2; ring++) {
      final u = ((t * 1.05 + ring * 0.14).clamp(0.0, 1.0));
      final radius = u * m;
      if (radius < 4) continue;
      final a = ((1 - u) * 0.1).clamp(0.015, 0.1);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.25
        ..color = _c.withValues(alpha: a);
      canvas.drawCircle(Offset(cx, cy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant SonarTapRingPainter oldDelegate) =>
      oldDelegate.t != t;
}
