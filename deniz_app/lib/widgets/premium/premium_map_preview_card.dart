import 'package:flutter/material.dart';

import '../../domain/dashboard_overview.dart';
import '../../l10n/app_strings_tr.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/layout_breakpoints.dart';
import 'premium_card.dart';
import 'premium_empty_state.dart';
import 'premium_metric_chip.dart';

class PremiumMapPreviewCard extends StatelessWidget {
  const PremiumMapPreviewCard({
    super.key,
    this.data = const DashboardMapPreviewData(),
    this.onExpandTap,
  });

  final DashboardMapPreviewData data;
  final VoidCallback? onExpandTap;

  @override
  Widget build(BuildContext context) {
    if (!data.hasData) {
      return PremiumEmptyState(
        title: kPremiumDashMapTitle,
        subtitle: kPremiumDashMapEmpty,
        icon: Icons.map_outlined,
        actionLabel: kPremiumDashMapCta,
        onAction: onExpandTap,
      );
    }

    final scoreLabel = data.score?.toString() ?? kPremiumDashNoData;
    final updatedLabel = data.updatedAgoLabel ?? kPremiumDashNoData;

    return PremiumCard(
      glow: true,
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final defaultMapHeight = useMobileLayout(context) ? 112.0 : 140.0;
          const headerReserve = 56.0;
          const footerReserve = 84.0;
          final tight = constraints.hasBoundedHeight &&
              constraints.maxHeight.isFinite &&
              constraints.maxHeight < headerReserve + defaultMapHeight + footerReserve;
          final mapHeight = tight
              ? (constraints.maxHeight - headerReserve - footerReserve).clamp(64.0, defaultMapHeight)
              : defaultMapHeight;
          final footerPadding = tight ? AppSpacing.md : AppSpacing.lg;

          return Column(
            mainAxisSize: tight ? MainAxisSize.max : MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  tight ? AppSpacing.xs : AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        kPremiumDashMapTitle,
                        style: AppTextStyles.cardTitle,
                      ),
                    ),
                    PremiumMetricChip(
                      label: kPremiumDashScoreLabel,
                      value: scoreLabel,
                      accentColor: data.score != null
                          ? AppColors.accentGreen
                          : AppColors.textMuted,
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: mapHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CustomPaint(
                      painter: _MarineMapPreviewPainter(
                        markers: data.markers,
                        centerLabel: data.centerLabel,
                        hasComparePair: data.hasComparePair,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(footerPadding),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PremiumMetricChip(
                            label: kPremiumDashUpdatedLabel,
                            value: updatedLabel,
                          ),
                          if (!tight &&
                              data.centerLabel != null &&
                              data.centerLabel!.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              data.centerLabel!,
                              style: AppTextStyles.caption,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: kPremiumDashZoomIn,
                      onPressed: onExpandTap,
                      icon: const Icon(Icons.add, size: 18),
                      color: AppColors.textSecondary,
                      visualDensity: tight ? VisualDensity.compact : VisualDensity.standard,
                    ),
                    IconButton(
                      tooltip: kPremiumDashZoomOut,
                      onPressed: null,
                      icon: const Icon(Icons.remove, size: 18),
                      color: AppColors.textMuted,
                      visualDensity: tight ? VisualDensity.compact : VisualDensity.standard,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MarineMapPreviewPainter extends CustomPainter {
  _MarineMapPreviewPainter({
    required this.markers,
    this.centerLabel,
    this.hasComparePair = false,
  });

  final List<DashboardMapMarker> markers;
  final String? centerLabel;
  final bool hasComparePair;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = AppColors.backgroundDeep;
    canvas.drawRect(Offset.zero & size, bg);

    final grid = Paint()
      ..color = AppColors.borderCyan.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (var i = 0; i < 8; i++) {
      final y = size.height * (i + 1) / 9;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
      final x = size.width * (i + 1) / 9;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }

    if (markers.isEmpty) {
      final center = Offset(size.width * 0.5, size.height * 0.5);
      _drawMarker(canvas, center, AppColors.accentTeal, radius: 6);
    } else {
      for (final m in markers) {
        final center = Offset(
          size.width * m.normalizedX,
          size.height * m.normalizedY,
        );
        final color = m.isCompareA
            ? AppColors.accentGreen
            : m.isCompareB
                ? AppColors.accentAmber
                : m.isFavorite
                    ? AppColors.borderCyan
                    : AppColors.accentTeal;
        _drawMarker(canvas, center, color, radius: m.isCompareA || m.isCompareB ? 7 : 5);
        if (m.isCompareA || m.isCompareB) {
          final tp = TextPainter(
            text: TextSpan(
              text: m.isCompareA ? 'A' : 'B',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(
            canvas,
            center - Offset(tp.width / 2, tp.height / 2),
          );
        }
      }
    }

    if (centerLabel != null && centerLabel!.trim().isNotEmpty) {
      final label = centerLabel!.trim();
      final short = label.length > 22 ? '${label.substring(0, 22)}…' : label;
      final tp = TextPainter(
        text: TextSpan(
          text: short,
          style: TextStyle(
            color: AppColors.textSecondary.withValues(alpha: 0.9),
            fontSize: 10,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width * 0.75);
      tp.paint(
        canvas,
        Offset((size.width - tp.width) / 2, size.height * 0.08),
      );
    }

    if (hasComparePair) {
      final a = markers.where((m) => m.isCompareA).toList();
      final b = markers.where((m) => m.isCompareB).toList();
      if (a.isNotEmpty && b.isNotEmpty) {
        final p1 = Offset(size.width * a.first.normalizedX, size.height * a.first.normalizedY);
        final p2 = Offset(size.width * b.first.normalizedX, size.height * b.first.normalizedY);
        canvas.drawLine(
          p1,
          p2,
          Paint()
            ..color = AppColors.accentTeal.withValues(alpha: 0.25)
            ..strokeWidth = 1.2,
        );
      }
    }

    final coast = Path()
      ..moveTo(0, size.height * 0.72)
      ..quadraticBezierTo(
        size.width * 0.35,
        size.height * 0.58,
        size.width * 0.55,
        size.height * 0.68,
      )
      ..quadraticBezierTo(
        size.width * 0.85,
        size.height * 0.82,
        size.width,
        size.height * 0.62,
      );
    canvas.drawPath(
      coast,
      Paint()
        ..color = AppColors.borderCyan.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _drawMarker(Canvas canvas, Offset center, Color color, {required double radius}) {
    final glow = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(center, radius + 8, glow);
    canvas.drawCircle(center, radius, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _MarineMapPreviewPainter oldDelegate) {
    return oldDelegate.markers != markers ||
        oldDelegate.centerLabel != centerLabel ||
        oldDelegate.hasComparePair != hasComparePair;
  }
}
