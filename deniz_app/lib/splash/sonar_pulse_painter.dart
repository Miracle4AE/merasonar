import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Merkezi sonar / radar halkaları — hafif, genişleyen nabız.
class SonarPulsePainter extends CustomPainter {
  SonarPulsePainter({required this.pulseT});

  /// 0..1 döngüsel nabız zamanı (üst bileşenden alınır).
  final double pulseT;

  static const _c = Color(0xFF4DD0E1);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.5;
    final cy = size.height * 0.38;
    final maxR = math.min(size.width, size.height) * 0.48;

    for (var ring = 0; ring < 4; ring++) {
      final offset = (ring / 4 + pulseT) % 1.0;
      final radius = offset * maxR;
      if (radius < 8) continue;
      final alpha = ((1 - offset) * 0.22).clamp(0.025, 0.22);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = _c.withValues(alpha: alpha);
      canvas.drawCircle(Offset(cx, cy), radius, paint);
    }

    final corePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = _c.withValues(alpha: 0.095);
    canvas.drawCircle(Offset(cx, cy), 5, corePaint);
  }

  @override
  bool shouldRepaint(covariant SonarPulsePainter oldDelegate) =>
      oldDelegate.pulseT != pulseT;
}
