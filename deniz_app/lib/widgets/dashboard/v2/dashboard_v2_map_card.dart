import 'dart:math' as math;

import 'package:deniz_app/domain/dashboard_overview.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/widgets/dashboard/v2/dashboard_v2_helpers.dart';
import 'package:deniz_app/widgets/premium/premium_card.dart';
import 'package:deniz_app/widgets/premium/premium_metric_chip.dart';
import 'package:flutter/material.dart';

class DashboardV2MapCard extends StatelessWidget {
  const DashboardV2MapCard({
    super.key,
    required this.data,
    this.onTap,
    this.onMarineTap,
    this.onCompareTap,
    this.onSavedSpotsTap,
  });

  final DashboardMapPreviewData data;
  final VoidCallback? onTap;
  final VoidCallback? onMarineTap;
  final VoidCallback? onCompareTap;
  final VoidCallback? onSavedSpotsTap;

  @override
  Widget build(BuildContext context) {
    final hasData = data.hasData;
    final primaryMarker = data.markers.where((m) => m.isPrimary).toList();

    return PremiumCard(
      glow: true,
      padding: EdgeInsets.zero,
      onTap: hasData ? onTap : onMarineTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _DashboardMapPainter(
                        markers: data.markers.take(8).toList(growable: false),
                        hasComparePair: data.hasComparePair,
                        hasData: hasData,
                        primaryCenter: primaryMarker.isNotEmpty
                            ? Offset(
                                primaryMarker.first.normalizedX,
                                primaryMarker.first.normalizedY,
                              )
                            : null,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                if (data.score != null && hasData)
                  Positioned(
                    top: AppSpacing.sm,
                    left: AppSpacing.sm,
                    child: PremiumMetricChip(
                      label: kPremiumDashScoreLabel,
                      value: data.scoreLabel ?? '${data.score}',
                      accentColor:
                          DashboardV2Helpers.scoreColor(data.score),
                    ),
                  ),
                if (data.dataSourceLabel != null && hasData)
                  Positioned(
                    top: AppSpacing.sm,
                    left: data.score != null ? 88 : AppSpacing.sm,
                    child: PremiumMetricChip(
                      label: kPremiumDashMapDataSource,
                      value: data.dataSourceLabel!,
                    ),
                  ),
                Positioned(
                  top: AppSpacing.sm,
                  right: AppSpacing.sm,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _overlayIcon(Icons.layers_outlined),
                      const SizedBox(width: 4),
                      _overlayIcon(Icons.tune_rounded),
                    ],
                  ),
                ),
                if (data.winnerLabel != null &&
                    data.displayMode == DashboardMapPreviewMode.compare)
                  Positioned(
                    top: 44,
                    right: AppSpacing.sm,
                    child: PremiumMetricChip(
                      label: kMissionMapWinner,
                      value: data.winnerLabel!,
                      accentColor: AppColors.accentGreen,
                    ),
                  ),
                if (hasData && _hasMarineMetrics)
                  Positioned(
                    left: AppSpacing.sm,
                    right: AppSpacing.sm,
                    bottom: data.updatedAgoLabel != null ? 44 : AppSpacing.sm,
                    child: _marineMetricsRow(),
                  ),
                if (data.hasRealCoordinate && hasData)
                  Positioned(
                    left: AppSpacing.sm,
                    bottom: data.updatedAgoLabel != null ? 44 : AppSpacing.sm,
                    child: _scaleBadge(),
                  ),
                if (data.updatedAgoLabel != null && hasData)
                  Positioned(
                    right: AppSpacing.sm,
                    bottom: AppSpacing.sm,
                    child: PremiumMetricChip(
                      label: kPremiumDashMapLastUpdate,
                      value: data.updatedAgoLabel!,
                    ),
                  ),
                if (!hasData) ...[
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            AppColors.surfaceDark.withValues(alpha: 0.55),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: AppSpacing.md,
                    right: AppSpacing.md,
                    top: AppSpacing.lg,
                    child: Text(
                      data.emptyReason ?? kPremiumDashMapEmptyAwaiting,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 36,
                    child: Center(
                      child: DashboardV2Helpers.compactSecondaryButton(
                        label: kMissionScoreCta,
                        onPressed: onMarineTap,
                        icon: Icons.explore_outlined,
                      ),
                    ),
                  ),
                ],
                if (hasData &&
                    (data.displayMode == DashboardMapPreviewMode.compare ||
                        data.displayMode == DashboardMapPreviewMode.savedSpots))
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 8,
                    child: Center(child: _modeCta()),
                  ),
              ],
            ),
          ),
          if (data.centerLabel != null && hasData)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Text(
                    '${_centerPrefix()}: ',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      data.centerLabel!,
                      style: AppTextStyles.caption.copyWith(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  bool get _hasMarineMetrics =>
      data.waveLabel != null ||
      data.currentLabel != null ||
      data.windLabel != null;

  String _centerPrefix() {
    return switch (data.displayMode) {
      DashboardMapPreviewMode.activeReport => kPremiumDashMapLastCoordinate,
      DashboardMapPreviewMode.savedSpots => kPremiumDashMapSavedSpot,
      DashboardMapPreviewMode.compare => kPremiumDashMapComparePoint,
      DashboardMapPreviewMode.empty => kPremiumDashMapLastCoordinate,
    };
  }

  Widget _marineMetricsRow() {
    final chips = <Widget>[];
    if (data.waveLabel != null) {
      chips.add(
        PremiumMetricChip(
          label: kPremiumDashMapWave,
          value: data.waveLabel!,
        ),
      );
    }
    if (data.currentLabel != null) {
      if (chips.isNotEmpty) chips.add(const SizedBox(width: 4));
      chips.add(
        PremiumMetricChip(
          label: kPremiumDashMapCurrent,
          value: data.currentLabel!,
        ),
      );
    }
    if (data.windLabel != null) {
      if (chips.isNotEmpty) chips.add(const SizedBox(width: 4));
      chips.add(
        PremiumMetricChip(
          label: kPremiumDashMapWind,
          value: data.windLabel!,
        ),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(mainAxisSize: MainAxisSize.min, children: chips),
    );
  }

  Widget _modeCta() {
    final label = switch (data.displayMode) {
      DashboardMapPreviewMode.compare => kPremiumDashMapCompareCta,
      DashboardMapPreviewMode.savedSpots => kPremiumDashMapSavedSpotsCta,
      DashboardMapPreviewMode.activeReport => kPremiumDashMapCta,
      DashboardMapPreviewMode.empty => kMissionScoreCta,
    };
    final onPressed = switch (data.displayMode) {
      DashboardMapPreviewMode.compare => onCompareTap ?? onTap,
      DashboardMapPreviewMode.savedSpots => onSavedSpotsTap ?? onTap,
      DashboardMapPreviewMode.activeReport => onTap,
      DashboardMapPreviewMode.empty => onMarineTap,
    };
    if (onPressed == null) return const SizedBox.shrink();
    return DashboardV2Helpers.compactSecondaryButton(
      label: label,
      onPressed: onPressed,
      icon: switch (data.displayMode) {
        DashboardMapPreviewMode.compare => Icons.compare_arrows,
        DashboardMapPreviewMode.savedSpots => Icons.bookmark_outline,
        DashboardMapPreviewMode.activeReport => Icons.map_outlined,
        DashboardMapPreviewMode.empty => Icons.explore_outlined,
      },
    );
  }

  Widget _scaleBadge() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.borderSoft(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 2,
            decoration: BoxDecoration(
              color: AppColors.accentTeal.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            kPremiumDashMapRealData,
            style: AppTextStyles.caption.copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _overlayIcon(IconData icon) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: AppColors.surfaceDark.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.borderSoft(alpha: 0.22)),
      ),
      child: Icon(icon, size: 13, color: AppColors.textSecondary),
    );
  }
}

class _DashboardMapPainter extends CustomPainter {
  _DashboardMapPainter({
    required this.markers,
    required this.hasComparePair,
    required this.hasData,
    this.primaryCenter,
  });

  final List<DashboardMapMarker> markers;
  final bool hasComparePair;
  final bool hasData;
  final Offset? primaryCenter;

  static const _labelOffset = 14.0;
  static const _overlapThreshold = 0.045;

  @override
  void paint(Canvas canvas, Size size) {
    _drawOceanGradient(canvas, size);
    _drawDepthContours(canvas, size);

    if (hasData && primaryCenter != null) {
      _drawSonarRings(
        canvas,
        size,
        Offset(
          size.width * primaryCenter!.dx,
          size.height * primaryCenter!.dy,
        ),
      );
    }

    if (hasData) {
      if (hasComparePair) {
        final a = markers.where((m) => m.isCompareA).toList();
        final b = markers.where((m) => m.isCompareB).toList();
        if (a.isNotEmpty && b.isNotEmpty) {
          canvas.drawLine(
            Offset(
              size.width * a.first.normalizedX,
              size.height * a.first.normalizedY,
            ),
            Offset(
              size.width * b.first.normalizedX,
              size.height * b.first.normalizedY,
            ),
            Paint()
              ..color = AppColors.accentTeal.withValues(alpha: 0.35)
              ..strokeWidth = 1.2,
          );
        }
      }

      final placed = <Offset>[];
      for (final m in markers) {
        var center = Offset(
          size.width * m.normalizedX,
          size.height * m.normalizedY,
        );
        center = _resolveOverlap(center, placed, size);
        placed.add(center);

        final color = _markerColor(m);
        if (m.score != null) {
          _drawScoreBubble(
            canvas,
            center,
            color,
            m.score!,
            large: m.isPrimary || m.isCompareA || m.isCompareB,
          );
        } else {
          _drawGlowDot(canvas, center, color, large: m.isPrimary);
        }

        if (m.isCompareA || m.isCompareB) {
          _drawMarkerLabel(canvas, center, m.isCompareA ? 'A' : 'B');
        } else if (m.isFavorite && !m.isPrimary) {
          _drawMarkerLabel(canvas, center, '★', small: true);
        }
      }
    }
  }

  Offset _resolveOverlap(Offset center, List<Offset> placed, Size size) {
    var resolved = center;
    for (var pass = 0; pass < 4; pass++) {
      for (final other in placed) {
        final delta = resolved - other;
        if (delta.distance < size.shortestSide * _overlapThreshold) {
          resolved += Offset(10 * (pass + 1), -8 * (pass + 1));
        }
      }
    }
    return Offset(
      resolved.dx.clamp(16, size.width - 16),
      resolved.dy.clamp(16, size.height - 16),
    );
  }

  Color _markerColor(DashboardMapMarker m) {
    if (m.isCompareA) return AppColors.accentGreen;
    if (m.isCompareB) return AppColors.accentAmber;
    if (m.markerType == DashboardMapMarkerType.hotspot) {
      return AppColors.borderCyan;
    }
    if (m.isFavorite) return AppColors.borderCyan;
    if (m.isPrimary) return AppColors.accentTeal;
    return AppColors.accentTeal.withValues(alpha: 0.85);
  }

  void _drawOceanGradient(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.25, 0.15),
          radius: 1.35,
          colors: const [
            Color(0xFF0C4568),
            Color(0xFF072A40),
            Color(0xFF041018),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.borderCyan.withValues(alpha: 0.08),
            Colors.transparent,
            AppColors.accentTeal.withValues(alpha: 0.05),
          ],
        ).createShader(Offset.zero & size),
    );
  }

  void _drawSonarRings(Canvas canvas, Size size, Offset center) {
    for (var ring = 1; ring <= 3; ring++) {
      canvas.drawCircle(
        center,
        size.shortestSide * 0.1 * ring,
        Paint()
          ..color =
              AppColors.borderCyan.withValues(alpha: 0.04 + ring * 0.015)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9,
      );
    }
  }

  void _drawDepthContours(Canvas canvas, Size size) {
    for (var depth = 0; depth < 10; depth++) {
      final stroke = depth.isEven ? 1.5 : 0.85;
      final alpha = 0.04 + depth * 0.022;
      final paint = Paint()
        ..color = AppColors.borderCyan.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke;

      final path = Path();
      final baseY = 0.12 + depth * 0.085;
      path.moveTo(0, size.height * baseY);
      for (var x = 0.0; x <= 1.01; x += 0.035) {
        final wave =
            math.sin(x * math.pi * (2.2 + depth * 0.12) + depth) * 0.04;
        final curl =
            math.cos(x * math.pi * 1.05 + depth * 0.45) * 0.02;
        path.lineTo(
          size.width * x,
          size.height * (baseY + wave + curl + depth * 0.012),
        );
      }
      canvas.drawPath(path, paint);
    }

    final channels = [
      (0.48, 0.35, 0.58, 0.52),
      (0.22, 0.45, 0.4, 0.58),
      (0.72, 0.55, 0.82, 0.68),
    ];
    for (final c in channels) {
      final accent = Path()
        ..moveTo(0, size.height * c.$1)
        ..quadraticBezierTo(
          size.width * c.$2,
          size.height * c.$3,
          size.width,
          size.height * c.$4,
        );
      canvas.drawPath(
        accent,
        Paint()
          ..color = AppColors.accentTeal.withValues(alpha: 0.1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }
  }

  void _drawGlowDot(
    Canvas canvas,
    Offset center,
    Color color, {
    required bool large,
  }) {
    final radius = large ? 7.0 : 5.0;
    canvas.drawCircle(
      center,
      radius + 6,
      Paint()
        ..color = color.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = const Color(0xFF071822).withValues(alpha: 0.94),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withValues(alpha: 0.95)
        ..style = PaintingStyle.stroke
        ..strokeWidth = large ? 2.0 : 1.4,
    );
  }

  void _drawScoreBubble(
    Canvas canvas,
    Offset center,
    Color color,
    int score, {
    required bool large,
  }) {
    final radius = large ? 15.0 : 10.5;

    if (large) {
      for (var ring = 1; ring <= 2; ring++) {
        canvas.drawCircle(
          center,
          radius + ring * 6,
          Paint()
            ..color = color.withValues(alpha: 0.14 / ring)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10.0 * ring),
        );
      }
    }

    canvas.drawCircle(
      center,
      radius + (large ? 8 : 5),
      Paint()
        ..color = color.withValues(alpha: large ? 0.32 : 0.18)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, large ? 12 : 7),
    );

    canvas.drawCircle(
      center,
      radius,
      Paint()..color = const Color(0xFF071822).withValues(alpha: 0.94),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = large ? 2.2 : 1.5,
    );

    if (score > 0) {
      final tp = TextPainter(
        text: TextSpan(
          text: '$score',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: large ? 12 : 9,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
    }
  }

  void _drawMarkerLabel(
    Canvas canvas,
    Offset center,
    String text, {
    bool small = false,
  }) {
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
      center + Offset(_labelOffset, -_labelOffset - tp.height),
    );
  }

  @override
  bool shouldRepaint(covariant _DashboardMapPainter oldDelegate) =>
      oldDelegate.markers != markers ||
      oldDelegate.hasComparePair != hasComparePair ||
      oldDelegate.hasData != hasData ||
      oldDelegate.primaryCenter != primaryCenter;
}
