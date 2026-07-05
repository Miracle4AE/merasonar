import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Periyodik, çok düşük opaklıkta merkez sonar nabzı — yalnızca kısa animasyon sırasında repaint.
class HomeAmbientPulsePainter extends CustomPainter {
  HomeAmbientPulsePainter({required this.t});

  /// Tek atım 0..1.
  final double t;

  static const _c = Color(0xFF4DD0E1);

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0) return;
    final cx = size.width * 0.5;
    final cy = size.height * 0.5;
    final maxR = math.min(size.width, size.height) * 0.4;
    for (var ring = 0; ring < 3; ring++) {
      final u = ((t * 1.08 + ring * 0.1).clamp(0.0, 1.0));
      final radius = u * maxR;
      if (radius < 6) continue;
      final a = ((1 - u) * 0.095).clamp(0.012, 0.095);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.25
        ..color = _c.withValues(alpha: a);
      canvas.drawCircle(Offset(cx, cy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant HomeAmbientPulsePainter oldDelegate) =>
      oldDelegate.t != t;
}
