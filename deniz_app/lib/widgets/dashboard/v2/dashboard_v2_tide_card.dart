import 'package:deniz_app/domain/dashboard_overview.dart';

import 'package:deniz_app/l10n/app_strings_tr.dart';

import 'package:deniz_app/theme/app_colors.dart';

import 'package:deniz_app/theme/app_spacing.dart';

import 'package:deniz_app/theme/app_text_styles.dart';

import 'package:deniz_app/widgets/dashboard/v2/dashboard_v2_helpers.dart';

import 'package:deniz_app/widgets/premium/premium_card.dart';

import 'package:flutter/material.dart';



class DashboardV2TideCard extends StatelessWidget {

  const DashboardV2TideCard({

    super.key,

    required this.summary,

    this.onMarineTap,

  });



  final DashboardTideSummary summary;

  final VoidCallback? onMarineTap;



  String get _title => summary.displayMode == DashboardTideDisplayMode.seaMovement

      ? kPremiumDashTideSeaMovementTitle

      : kPremiumDashTideTitle;



  @override

  Widget build(BuildContext context) {

    return PremiumCard(

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.stretch,

        children: [

          Row(

            children: [

              Expanded(child: DashboardV2Helpers.cardHeader(_title)),

              if (summary.hasChartData && onMarineTap != null)

                TextButton(

                  onPressed: onMarineTap,

                  style: TextButton.styleFrom(

                    padding: EdgeInsets.zero,

                    minimumSize: Size.zero,

                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,

                  ),

                  child: Text(

                    'Tümünü',

                    style: AppTextStyles.caption.copyWith(

                      color: AppColors.accentTeal,

                      fontSize: 10,

                    ),

                  ),

                ),

            ],

          ),

          const SizedBox(height: AppSpacing.sm),

          Expanded(

            child: summary.hasData ? _dataView() : _emptyView(),

          ),

        ],

      ),

    );

  }



  Widget _emptyView() {

    return DashboardV2Helpers.premiumEmpty(

      message: summary.emptyReason ?? kPremiumDashTideNoDataNote,

      ctaLabel: onMarineTap != null ? kPremiumDashTimelineRefreshCta : null,

      onCta: onMarineTap,

      icon: Icons.water_outlined,

      pattern: DashboardPlaceholderPattern.tideWave,

    );

  }



  Widget _dataView() {

    return LayoutBuilder(

      builder: (context, constraints) {

        final tight = constraints.maxHeight < 72;

        final points = summary.chartPoints;

        return Column(

          children: [

            if (summary.label != null && summary.label!.trim().isNotEmpty)

              Text(

                summary.label!,

                style: AppTextStyles.caption.copyWith(fontSize: 9),

                maxLines: 1,

                overflow: TextOverflow.ellipsis,

              ),

            if (!summary.tideProviderAvailable)

              Padding(

                padding: const EdgeInsets.only(top: 2),

                child: Container(

                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),

                  decoration: BoxDecoration(

                    color: AppColors.surfaceElevated.withValues(alpha: 0.5),

                    borderRadius: BorderRadius.circular(4),

                  ),

                  child: Text(

                    kPremiumDashTideSeaMovementNote,

                    style: AppTextStyles.caption.copyWith(

                      fontSize: 8,

                      color: AppColors.textMuted,

                    ),

                    maxLines: 2,

                    overflow: TextOverflow.ellipsis,

                    textAlign: TextAlign.center,

                  ),

                ),

              ),

            if (summary.chartLabel != null && summary.chartLabel!.trim().isNotEmpty)

              Padding(

                padding: const EdgeInsets.only(top: 2),

                child: Text(

                  summary.chartLabel!,

                  style: AppTextStyles.caption.copyWith(

                    fontSize: 8,

                    color: AppColors.accentTeal,

                    fontWeight: FontWeight.w600,

                  ),

                ),

              ),

            if (!tight) const SizedBox(height: AppSpacing.xs),

            Expanded(

              child: summary.hasChartData

                  ? RepaintBoundary(

                      child: CustomPaint(

                        painter: _TideChartPainter(points: points),

                        child: const SizedBox.expand(),

                      ),

                    )

                  : DashboardV2Helpers.decorativePattern(

                      DashboardPlaceholderPattern.tideWave,

                      height: constraints.maxHeight.clamp(24, 48),

                    ),

            ),

          ],

        );

      },

    );

  }

}



class _TideChartPainter extends CustomPainter {

  _TideChartPainter({required this.points});



  final List<DashboardTidePoint> points;



  @override

  void paint(Canvas canvas, Size size) {

    if (points.length < 2) return;



    final gridPaint = Paint()

      ..color = AppColors.borderSoft(alpha: 0.08)

      ..strokeWidth = 0.8;

    for (var i = 1; i < 4; i++) {

      final y = size.height * i / 4;

      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);

    }



    final values = points.map((p) => p.value).toList();

    final minV = values.reduce((a, b) => a < b ? a : b);

    final maxV = values.reduce((a, b) => a > b ? a : b);

    final span = (maxV - minV).abs() < 0.01 ? 0.01 : (maxV - minV);



    final curvePaint = Paint()

      ..color = AppColors.accentTeal.withValues(alpha: 0.85)

      ..strokeWidth = 2

      ..style = PaintingStyle.stroke;



    final path = Path();

    for (var i = 0; i < points.length; i++) {

      final x = size.width * (i / (points.length - 1));

      final norm = (points[i].value - minV) / span;

      final y = size.height * (0.85 - norm * 0.7);

      if (i == 0) {

        path.moveTo(x, y);

      } else {

        path.lineTo(x, y);

      }

    }

    canvas.drawPath(path, curvePaint);



    var bestIdx = 0;

    var bestVal = points.first.value;

    var lowIdx = 0;

    var lowVal = points.first.value;

    for (var i = 0; i < points.length; i++) {

      if (points[i].value > bestVal) {

        bestVal = points[i].value;

        bestIdx = i;

      }

      if (points[i].value < lowVal) {

        lowVal = points[i].value;

        lowIdx = i;

      }

    }

    _markPoint(canvas, size, bestIdx, points.length, minV, span, true);

    _markPoint(canvas, size, lowIdx, points.length, minV, span, false);

  }



  void _markPoint(

    Canvas canvas,

    Size size,

    int index,

    int count,

    double minV,

    double span,

    bool high,

  ) {

    if (count <= 1) return;

    final x = size.width * (index / (count - 1));

    final norm = (points[index].value - minV) / span;

    final y = size.height * (0.85 - norm * 0.7);

    canvas.drawCircle(

      Offset(x, y),

      4,

      Paint()..color = high ? AppColors.accentGreen : AppColors.accentAmber,

    );

  }



  @override

  bool shouldRepaint(covariant _TideChartPainter oldDelegate) =>

      oldDelegate.points != points;

}


