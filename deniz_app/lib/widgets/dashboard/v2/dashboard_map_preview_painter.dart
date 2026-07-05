import 'dart:math' as math;

import 'package:deniz_app/domain/dashboard_map_preview_projection.dart';
import 'package:deniz_app/domain/dashboard_overview.dart';
import 'package:deniz_app/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Premium geo score map painter for dashboard map preview cards.
class DashboardMapPreviewPainter extends CustomPainter {
  DashboardMapPreviewPainter({
    required this.markers,
    required this.hasComparePair,
    required this.hasData,
    required this.selectedMarkerId,
    this.glowScale = 1.0,
    this.reduceMotion = false,
  });

  final List<DashboardMapMarker> markers;
  final bool hasComparePair;
  final bool hasData;
  final String? selectedMarkerId;
  final double glowScale;
  final bool reduceMotion;

  static const _overlapMinPx = 28.0;

  @override
  void paint(Canvas canvas, Size size) {
    _drawOceanBase(canvas, size);
    _drawDepthContours(canvas, size);
    _drawCoastHint(canvas, size);

    if (!hasData) return;

    if (hasComparePair) {
      final a = markers.where((m) => m.isCompareA).toList();
      final b = markers.where((m) => m.isCompareB).toList();
      if (a.isNotEmpty && b.isNotEmpty) {
        canvas.drawLine(
          _toOffset(a.first, size),
          _toOffset(b.first, size),
          Paint()
            ..color = AppColors.accentTeal.withValues(alpha: 0.35)
            ..strokeWidth = 1.2,
        );
      }
    }

    final placed = <Offset>[];
    final scorable = markers.where((m) => m.hasScoreOrb).toList(growable: false);

    for (final m in scorable) {
      var center = _toOffset(m, size);
      center = DashboardMapPreviewProjection.resolveScreenOverlap(
        center: center,
        placed: placed,
        minDistance: _overlapMinPx,
        size: size,
      );
      placed.add(center);

      final isSelected =
          m.isSelected || m.isPrimary || m.id == selectedMarkerId;
      final color = DashboardMapPreviewProjection.scoreColor(m.score!);

      if (isSelected) {
        _drawFocusReticle(canvas, center, color, size);
      }

      _drawScoreOrb(
        canvas,
        center,
        color,
        m.score!,
        large: isSelected,
        glowScale: glowScale,
        reduceMotion: reduceMotion,
      );

      if (m.isCompareA || m.isCompareB) {
        _drawMarkerLabel(canvas, center, m.isCompareA ? 'A' : 'B');
      } else if (m.isFavorite && !isSelected) {
        _drawMarkerLabel(canvas, center, '★', small: true);
      }
    }
  }

  Offset _toOffset(DashboardMapMarker m, Size size) =>
      Offset(size.width * m.normalizedX, size.height * m.normalizedY);

  void _drawOceanBase(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0.1, 0.2),
          radius: 1.25,
          colors: [
            Color(0xFF0E4A6E),
            Color(0xFF083550),
            Color(0xFF041018),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1A6088).withValues(alpha: 0.18),
            Colors.transparent,
            const Color(0xFF020810).withValues(alpha: 0.35),
          ],
        ).createShader(Offset.zero & size),
    );
  }

  void _drawCoastHint(Canvas canvas, Size size) {
    final land = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.42, 0)
      ..quadraticBezierTo(
        size.width * 0.55,
        size.height * 0.08,
        size.width * 0.38,
        size.height * 0.16,
      )
      ..lineTo(0, size.height * 0.12)
      ..close();
    canvas.drawPath(
      land,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A2830).withValues(alpha: 0.55),
            const Color(0xFF0A1218).withValues(alpha: 0.25),
          ],
        ).createShader(Offset.zero & size),
    );
  }

  void _drawDepthContours(Canvas canvas, Size size) {
    for (var depth = 0; depth < 8; depth++) {
      final path = Path();
      final baseY = 0.16 + depth * 0.095;
      path.moveTo(-size.width * 0.05, size.height * baseY);
      for (var x = 0.0; x <= 1.01; x += 0.04) {
        final wave = math.sin(
              x * math.pi * (1.35 + depth * 0.12) + depth * 0.72,
            ) *
            0.024;
        final shelf = math.cos(x * math.pi * 2.1 + depth) * 0.012;
        path.lineTo(size.width * x, size.height * (baseY + wave + shelf));
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.borderCyan.withValues(alpha: 0.035 + depth * 0.01)
          ..style = PaintingStyle.stroke
          ..strokeWidth = depth.isEven ? 1.0 : 0.65,
      );
    }

    final shelfLines = [
      (0.18, 0.32, 0.34, 0.44, 0.82, 0.38),
      (0.06, 0.62, 0.38, 0.52, 0.95, 0.68),
      (0.22, 0.82, 0.50, 0.70, 1.04, 0.80),
    ];
    for (final s in shelfLines) {
      final path = Path()
        ..moveTo(size.width * s.$1, size.height * s.$2)
        ..cubicTo(
          size.width * s.$3,
          size.height * s.$4,
          size.width * 0.62,
          size.height * (s.$4 - 0.08),
          size.width * s.$5,
          size.height * s.$6,
        );
      canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.accentTeal.withValues(alpha: 0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
  }

  void _drawFocusReticle(Canvas canvas, Offset center, Color color, Size size) {
    final arm = size.shortestSide * 0.055;
    final gap = size.shortestSide * 0.038;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    void corner(double dx, double dy) {
      canvas.drawLine(
        center + Offset(dx * gap, dy * gap),
        center + Offset(dx * (gap + arm), dy * gap),
        paint,
      );
      canvas.drawLine(
        center + Offset(dx * gap, dy * gap),
        center + Offset(dx * gap, dy * (gap + arm)),
        paint,
      );
    }

    corner(-1, -1);
    corner(1, -1);
    corner(-1, 1);
    corner(1, 1);
  }

  void _drawScoreOrb(
    Canvas canvas,
    Offset center,
    Color color,
    int score, {
    required bool large,
    required double glowScale,
    required bool reduceMotion,
  }) {
    final radius = large ? 16.0 : 11.0;
    final glowAlpha = (reduceMotion ? 0.12 : 0.28) * glowScale;

    if (glowScale > 0.15 && !reduceMotion) {
      canvas.drawCircle(
        center,
        radius + (large ? 10 : 6),
        Paint()
          ..color = color.withValues(alpha: glowAlpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, large ? 10 : 6),
      );
    }

    canvas.drawCircle(
      center,
      radius,
      Paint()..color = const Color(0xFF071822).withValues(alpha: 0.94),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withValues(alpha: 0.92)
        ..style = PaintingStyle.stroke
        ..strokeWidth = large ? 2.4 : 1.6,
    );

    final tp = TextPainter(
      text: TextSpan(
        text: '$score',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: large ? 13 : 9.5,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _drawMarkerLabel(
    Canvas canvas,
    Offset center,
    String text, {
    bool small = false,
  }) {
    const labelOffset = 14.0;
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: small ? 8 : 10,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      center + Offset(labelOffset, -labelOffset - tp.height),
    );
  }

  @override
  bool shouldRepaint(covariant DashboardMapPreviewPainter oldDelegate) =>
      oldDelegate.markers != markers ||
      oldDelegate.hasComparePair != hasComparePair ||
      oldDelegate.hasData != hasData ||
      oldDelegate.selectedMarkerId != selectedMarkerId ||
      oldDelegate.glowScale != glowScale ||
      oldDelegate.reduceMotion != reduceMotion;
}
