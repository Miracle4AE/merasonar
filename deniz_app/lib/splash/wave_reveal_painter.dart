import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Alttan yükselen deniz yüzeyi — sinüs ile yumuşak dalga sırtı.
class WaveRevealPainter extends CustomPainter {
  WaveRevealPainter({
    required this.revealProgress,
    required this.waveTravel,
  });

  /// Dalganın dip–üst yüzeye kadar çıkması 0..1.
  final double revealProgress;

  /// Yatay dalga fazı kaydırması 0..1.
  final double waveTravel;

  static const _waterTop = Color(0xFF0C2844);
  static const _waterDeep = Color(0xFF040C18);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final t = revealProgress.clamp(0.0, 1.0);

    final baseFrac = 1.0 - t * 0.52;
    final baselineY = h * baseFrac.clamp(0.22, 1.0);
    final amp = math.max(4.0, h * 0.018);

    final path = Path()..moveTo(0, h);
    final steps = math.max(32, (w / 14).ceil());
    final phase = waveTravel * math.pi * 2;

    for (var i = 0; i <= steps; i++) {
      final x = w * (i / steps);
      final y =
          baselineY +
          amp * math.sin(2 * math.pi * x / w * 2.8 + phase) +
          amp * 0.45 * math.sin(2 * math.pi * x / w * 5.5 - phase * 1.4);
      path.lineTo(x, y);
    }
    path.lineTo(w, h);
    path.lineTo(0, h);
    path.close();

    final lg = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [_waterTop.withValues(alpha: 0.94), _waterDeep],
    ).createShader(Rect.fromLTWH(0, baselineY - 30, w, h));

    canvas.drawPath(path, Paint()..shader = lg);
    final crest = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFF54C8E8).withValues(alpha: 0.38);
    var first = true;
    final crestPath = Path();
    for (var i = 0; i <= steps; i++) {
      final x = w * (i / steps);
      final y =
          baselineY +
          amp * math.sin(2 * math.pi * x / w * 2.8 + phase) +
          amp * 0.45 * math.sin(2 * math.pi * x / w * 5.5 - phase * 1.4);
      if (first) {
        crestPath.moveTo(x, y);
        first = false;
      } else {
        crestPath.lineTo(x, y);
      }
    }
    canvas.drawPath(crestPath, crest);
  }

  @override
  bool shouldRepaint(covariant WaveRevealPainter oldDelegate) =>
      oldDelegate.revealProgress != revealProgress ||
      oldDelegate.waveTravel != waveTravel;
}
