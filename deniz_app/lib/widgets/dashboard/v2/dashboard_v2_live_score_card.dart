import 'package:deniz_app/services/dashboard_overview_service.dart';
import 'package:deniz_app/domain/dashboard_overview.dart';

import 'package:deniz_app/l10n/app_strings_tr.dart';

import 'package:deniz_app/theme/app_colors.dart';

import 'package:deniz_app/theme/app_spacing.dart';

import 'package:deniz_app/theme/app_text_styles.dart';

import 'package:deniz_app/utils/layout_breakpoints.dart';

import 'package:deniz_app/widgets/dashboard/v2/dashboard_v2_helpers.dart';

import 'package:deniz_app/widgets/premium/premium_card.dart';

import 'package:flutter/material.dart';



class DashboardV2LiveScoreCard extends StatelessWidget {

  const DashboardV2LiveScoreCard({

    super.key,

    required this.summary,

    required this.marineReport,

    this.onLiveTap,

  });



  final DashboardLiveScoreSummary summary;

  final DashboardMarineReportSummary marineReport;

  final VoidCallback? onLiveTap;



  @override

  Widget build(BuildContext context) {

    final score = summary.score ?? marineReport.missionScore;

    final hasGauge = score != null;

    final rawLabel = summary.rating.isNotEmpty

        ? summary.rating

        : DashboardOverviewService.scoreRatingLabel(score);

    final label = summary.rating.isNotEmpty

        ? localizeLiveRatingLabel(summary.rating)

        : rawLabel;

    final waitScore = marineReport.goScore != null && score != null

        ? marineReport.goScore!.clamp(0, 100)

        : marineReport.goScore;

    final scoreColor = DashboardV2Helpers.scoreColor(score);



    return PremiumCard(

      glow: hasGauge,

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.stretch,

        children: [

          DashboardV2Helpers.cardHeader(kPremiumDashLiveScoreTitle),

          const SizedBox(height: AppSpacing.sm),

          Expanded(

            child: hasGauge

                ? LayoutBuilder(

                    builder: (context, constraints) {

                      final micro = constraints.maxHeight < 100;

                      final tight = constraints.maxHeight < 128;

                      final showMetrics =

                          !tight && constraints.maxWidth > 150;

                      final gaugeSize = micro

                          ? 54.0

                          : tight

                              ? 68.0

                              : 92.0;

                      final stroke = micro ? 5.0 : (tight ? 6.5 : 8.5);



                      final gaugeBlock = Column(

                        mainAxisAlignment: MainAxisAlignment.center,

                        mainAxisSize: MainAxisSize.min,

                        children: [

                          DashboardV2Helpers.scoreGauge(

                            score: score,

                            size: gaugeSize,

                            stroke: stroke,

                            glow: true,

                          ),

                          if (!micro) ...[

                            const SizedBox(height: 6),

                            Text(

                              label,

                              style: AppTextStyles.caption.copyWith(

                                color: scoreColor,

                                fontSize: 12,

                                fontWeight: FontWeight.w700,

                              ),

                              maxLines: 1,

                              overflow: TextOverflow.ellipsis,

                            ),

                            if (waitScore != null && waitScore != score)

                              Text(

                                'Bekle: $waitScore',

                                style: AppTextStyles.caption.copyWith(

                                  fontSize: 11,

                                  color: AppColors.textSecondary,

                                ),

                              ),

                          ],

                        ],

                      );



                      if (tight || !showMetrics) {

                        return Center(

                          child: micro

                              ? FittedBox(

                                  fit: BoxFit.scaleDown,

                                  child: gaugeBlock,

                                )

                              : gaugeBlock,

                        );

                      }



                      return Row(

                        crossAxisAlignment: CrossAxisAlignment.center,

                        children: [

                          gaugeBlock,

                          const SizedBox(width: AppSpacing.sm),

                          Expanded(child: _metricList()),

                        ],

                      );

                    },

                  )

                : DashboardV2Helpers.premiumEmpty(

                    message: kPremiumDashLiveScoreEmpty,

                    ctaLabel: kPremiumDashLiveScoreCta,

                    onCta: onLiveTap,

                    icon: Icons.sensors_rounded,

                    pattern: DashboardPlaceholderPattern.sparkline,

                  ),

          ),

          if (hasGauge) ...[

            const SizedBox(height: AppSpacing.xs),

            SizedBox(

              height: useMobileLayout(context) ? 24 : 32,

              child: DashboardV2Helpers.miniSparkline(

                color: scoreColor,

                height: useMobileLayout(context) ? 24 : 32,

              ),

            ),

          ],

        ],

      ),

    );

  }



  Widget _metricList() {

    const metrics = [

      ('Hava', Icons.wb_sunny_outlined),

      ('Deniz', Icons.waves_outlined),

      ('Gelgit', Icons.water_outlined),

      ('Ay', Icons.nightlight_round),

      ('Balık', Icons.set_meal_outlined),

    ];

    final values = [

      summary.weatherMetric,

      summary.seaMetric,

      summary.tideCurrentMetric,

      summary.moonMetric,

      summary.fishMetric,

    ];

    return Column(

      mainAxisAlignment: MainAxisAlignment.center,

      crossAxisAlignment: CrossAxisAlignment.stretch,

      children: [

        for (var i = 0; i < metrics.length; i++)

          Padding(

            padding: const EdgeInsets.symmetric(vertical: 2),

            child: Row(

              children: [

                Container(

                  width: 22,

                  height: 22,

                  alignment: Alignment.center,

                  decoration: BoxDecoration(

                    color: AppColors.surfaceElevated.withValues(alpha: 0.6),

                    borderRadius: BorderRadius.circular(5),

                    border: Border.all(

                      color: AppColors.borderCyan.withValues(alpha: 0.15),

                    ),

                  ),

                  child: Icon(metrics[i].$2, size: 13, color: AppColors.accentTeal),

                ),

                const SizedBox(width: 8),

                Expanded(

                  child: Text(

                    metrics[i].$1,

                    style: AppTextStyles.caption.copyWith(

                      fontSize: 11,

                      fontWeight: FontWeight.w500,

                    ),

                    maxLines: 1,

                    overflow: TextOverflow.ellipsis,

                  ),

                ),

                SizedBox(

                  width: 28,

                  child: Text(

                    values[i]?.toString() ?? kPremiumDashPlaceholderDash,

                    style: AppTextStyles.caption.copyWith(

                      fontSize: 11,

                      color: values[i] != null

                          ? AppColors.textSecondary

                          : AppColors.textMuted,

                      fontWeight: FontWeight.w700,

                    ),

                    textAlign: TextAlign.right,

                  ),

                ),

              ],

            ),

          ),

      ],

    );

  }

}


