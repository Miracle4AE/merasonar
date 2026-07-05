import 'dart:math' as math;

import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:flutter/material.dart';

/// Dekoratif boş durum desenleri — fake veri üretmez.
enum DashboardPlaceholderPattern {
  none,
  sparkline,
  dottedBaseline,
  tideWave,
  compareSplit,
}

/// Dashboard V2 ortak yardımcılar — kompakt kart başlığı, gauge, boş durum.
abstract final class DashboardV2Helpers {
  static const double gridGap = 14;
  static const double outerPadding = 14;
  static const double cardPadding = 16;

  static Widget cardHeader(String title, {Widget? trailing}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.cardTitle.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (trailing != null)
          Flexible(
            fit: FlexFit.loose,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: trailing,
            ),
          ),
      ],
    );
  }

  static Color scoreColor(int? score) {
    if (score == null) return AppColors.textMuted;
    if (score >= 80) return AppColors.accentGreen;
    if (score >= 60) return AppColors.accentTeal;
    if (score >= 40) return AppColors.accentAmber;
    return AppColors.accentRed;
  }

  static String scoreLabel(int? score) {
    if (score == null) return kPremiumDashPlaceholderDash;
    if (score >= 80) return 'Mükemmel';
    if (score >= 60) return 'İyi';
    if (score >= 40) return 'Orta';
    return 'Düşük';
  }

  static Widget decorativePattern(
    DashboardPlaceholderPattern pattern, {
    Color? color,
    double height = 32,
  }) {
    if (pattern == DashboardPlaceholderPattern.none) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _PlaceholderPatternPainter(
          pattern: pattern,
          color: color ?? AppColors.accentTeal.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  /// Outline / glass CTA — neon dolgu yerine dengeli ikincil aksiyon.
  static Widget compactSecondaryButton({
    required String label,
    VoidCallback? onPressed,
    IconData? icon,
    Key? buttonKey,
  }) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: OutlinedButton.icon(
        key: buttonKey,
        onPressed: onPressed,
        icon: Icon(icon ?? Icons.arrow_forward_rounded, size: 14),
        label: Text(
          label,
          style: AppTextStyles.caption.copyWith(fontSize: 11),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accentTeal,
          side: BorderSide(color: AppColors.borderCyan.withValues(alpha: 0.35)),
          backgroundColor: AppColors.surfaceElevated.withValues(alpha: 0.35),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }

  /// Captain Atlas gibi ana aksiyonlar için dengeli gradient CTA (~34px).
  static Widget compactGradientButton({
    required String label,
    VoidCallback? onPressed,
    Key? buttonKey,
    IconData icon = Icons.auto_awesome_rounded,
  }) {
    return Material(
      key: buttonKey,
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              colors: [
                AppColors.accentTeal.withValues(alpha: 0.85),
                AppColors.accentTeal.withValues(alpha: 0.55),
              ],
            ),
            border: Border.all(
              color: AppColors.borderCyan.withValues(alpha: 0.35),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: AppColors.backgroundDeep),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.backgroundDeep,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget premiumEmpty({
    required String message,
    String? ctaLabel,
    VoidCallback? onCta,
    IconData icon = Icons.info_outline,
    DashboardPlaceholderPattern pattern = DashboardPlaceholderPattern.none,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tight = constraints.maxHeight < 72;
        return ClipRect(
          child: Align(
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: constraints.maxWidth > 0 ? constraints.maxWidth : 120,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (pattern != DashboardPlaceholderPattern.none)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: decorativePattern(
                          pattern,
                          height: tight ? 24 : 30,
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: tight ? 14 : 16, color: AppColors.textMuted),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            message,
                            style: AppTextStyles.caption.copyWith(
                              fontSize: tight ? 10 : 11,
                              height: 1.3,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: tight ? 2 : 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (ctaLabel != null && onCta != null) ...[
                      SizedBox(height: tight ? AppSpacing.xs : AppSpacing.sm),
                      Center(
                        child: compactSecondaryButton(
                          label: ctaLabel,
                          onPressed: onCta,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Geriye uyumluluk.
  static Widget compactEmpty({
    required String message,
    String? ctaLabel,
    VoidCallback? onCta,
    IconData icon = Icons.info_outline,
  }) =>
      premiumEmpty(
        message: message,
        ctaLabel: ctaLabel,
        onCta: onCta,
        icon: icon,
      );

  static Widget scoreGauge({
    required int? score,
    double size = 88,
    double stroke = 7,
    bool glow = false,
  }) {
    final value = score != null ? (score / 100).clamp(0.0, 1.0) : 0.0;
    final color = scoreColor(score);
    final gauge = SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (glow)
            Container(
              width: size * 0.92,
              height: size * 0.92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: size * 0.18,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: score != null ? value : null,
              strokeWidth: stroke,
              backgroundColor: AppColors.surfaceElevated.withValues(alpha: 0.9),
              color: color,
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                score?.toString() ?? kPremiumDashPlaceholderDash,
                style: AppTextStyles.heroTitle.copyWith(
                  fontSize: size * 0.28,
                  fontWeight: FontWeight.w700,
                  color: score != null ? color : AppColors.textMuted,
                  height: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return gauge;
  }

  static Widget miniSparkline({Color? color, int points = 12, double height = 32}) {
    return CustomPaint(
      size: Size(double.infinity, height),
      painter: _SparklinePainter(
        color: color ?? AppColors.accentTeal.withValues(alpha: 0.7),
        points: points,
      ),
    );
  }

  static Widget metricBox(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderSoft(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: AppTextStyles.caption.copyWith(fontSize: 11)),
            const SizedBox(height: 2),
            Text(
              value,
              style: AppTextStyles.cardTitle.copyWith(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderPatternPainter extends CustomPainter {
  _PlaceholderPatternPainter({required this.pattern, required this.color});

  final DashboardPlaceholderPattern pattern;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    switch (pattern) {
      case DashboardPlaceholderPattern.sparkline:
        _SparklinePainter(color: color, points: 10).paint(canvas, size);
      case DashboardPlaceholderPattern.dottedBaseline:
        _drawDottedBaseline(canvas, size);
      case DashboardPlaceholderPattern.tideWave:
        _drawTideWave(canvas, size);
      case DashboardPlaceholderPattern.compareSplit:
        _drawCompareSplit(canvas, size);
      case DashboardPlaceholderPattern.none:
        break;
    }
  }

  void _drawDottedBaseline(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.45)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    final y = size.height * 0.62;
    for (var i = 0; i < 7; i++) {
      final x = size.width * (i + 0.5) / 7;
      canvas.drawLine(Offset(x - 4, y), Offset(x + 4, y), paint);
      canvas.drawCircle(
        Offset(x, y - 10),
        2,
        Paint()..color = color.withValues(alpha: 0.25),
      );
    }
  }

  void _drawTideWave(Canvas canvas, Size size) {
    final path = Path();
    for (var i = 0; i <= 20; i++) {
      final t = i / 20;
      final x = size.width * t;
      final y = size.height * (0.55 - 0.28 * math.sin(t * math.pi * 2));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  void _drawCompareSplit(Canvas canvas, Size size) {
    final cy = size.height * 0.5;
    final dashPaint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    const dash = 4.0;
    final startX = size.width * 0.22;
    final endX = size.width * 0.78;
    for (var x = startX; x < endX; x += dash * 2) {
      canvas.drawLine(
        Offset(x, cy),
        Offset(math.min(x + dash, endX), cy),
        dashPaint,
      );
    }
    for (final x in [size.width * 0.22, size.width * 0.78]) {
      canvas.drawCircle(
        Offset(x, cy),
        8,
        Paint()
          ..color = AppColors.surfaceElevated.withValues(alpha: 0.8)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        Offset(x, cy),
        8,
        Paint()
          ..color = color.withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }
    canvas.drawCircle(
      Offset(size.width / 2, cy),
      4,
      Paint()..color = color.withValues(alpha: 0.5),
    );
  }

  @override
  bool shouldRepaint(covariant _PlaceholderPatternPainter oldDelegate) =>
      oldDelegate.pattern != pattern || oldDelegate.color != color;
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.color, required this.points});

  final Color color;
  final int points;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.28),
          color.withValues(alpha: 0.02),
        ],
      ).createShader(Offset.zero & size);

    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final fillPath = Path();
    for (var i = 0; i < points; i++) {
      final t = i / (points - 1);
      final x = size.width * t;
      final wave =
          0.5 + 0.32 * math.sin(t * math.pi * 1.6 + 0.4) * (i.isEven ? 1 : 0.75);
      final y = size.height * wave.clamp(0.12, 0.88);
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, strokePaint);

    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.38),
      3.5,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.color != color;
}
