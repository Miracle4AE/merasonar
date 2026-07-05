import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Hafif batimetri / derinlik izlenimi — çok düşük opaklık, ince çizgiler.
class ContourLinesPainter extends CustomPainter {
  ContourLinesPainter({
    required this.phase,
    this.opacityScale = 1.0,
  });

  /// 0..1 yavaş kayma (radyan benzeri).
  final double phase;

  /// Home arka planı gibi daha soluk katmanlar için (ör. 0.4).
  final double opacityScale;

  static const _baseColor = Color(0xFF4FC3F7);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = _baseColor.withValues(alpha: 0.055 * opacityScale);

    // Merkez etrafında birkaç kapalı eğri (elips + sinüs bozulması)
    final cx = w * 0.48;
    final cy = h * 0.42;
    for (var i = 0; i < 3; i++) {
      final path = Path();
      final a = 0.12 * w + i * w * 0.075;
      final b = 0.08 * h + i * h * 0.06;
      final rot = i * 0.35 + phase * math.pi * 2;
      const steps = 36;
      for (var s = 0; s <= steps; s++) {
        final t = (s / steps) * math.pi * 2;
        final wx = math.cos(t) * a * (1 + 0.05 * math.sin(t * 3 + phase * 4));
        final wy = math.sin(t) * b * (1 + 0.04 * math.cos(t * 2 - phase * 3));
        final x = cx + wx * math.cos(rot) - wy * math.sin(rot);
        final y = cy + wx * math.sin(rot) + wy * math.cos(rot);
        if (s == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant ContourLinesPainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.opacityScale != opacityScale;
}
