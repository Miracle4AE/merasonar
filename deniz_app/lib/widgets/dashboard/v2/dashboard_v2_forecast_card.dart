import 'package:deniz_app/domain/dashboard_overview.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/widgets/dashboard/v2/dashboard_v2_helpers.dart';
import 'package:deniz_app/widgets/premium/premium_card.dart';
import 'package:flutter/material.dart';

const _dayNames = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

class DashboardV2ForecastCard extends StatelessWidget {
  const DashboardV2ForecastCard({
    super.key,
    required this.summary,
  });

  final DashboardForecastSummary summary;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DashboardV2Helpers.cardHeader(kPremiumDashForecastTitle),
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
      message: summary.emptyReason ?? kPremiumDashForecastEmptyHint,
      icon: Icons.calendar_month_outlined,
      pattern: DashboardPlaceholderPattern.dottedBaseline,
    );
  }

  Widget _dataView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final micro = constraints.maxHeight < 48;
        final days = summary.days;
        if (days.isEmpty) {
          return Center(
            child: Text(
              summary.label ?? kPremiumDashForecastEmptyHint,
              style: AppTextStyles.caption.copyWith(fontSize: 9),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          );
        }

        final visible = days.take(7).toList(growable: false);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < visible.length; i++) ...[
                    if (i > 0) const SizedBox(width: 3),
                    Expanded(
                      child: _dayCell(
                        visible[i],
                        index: i,
                        compact: constraints.maxHeight < 72 || micro,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (summary.label != null && summary.label!.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  summary.label!,
                  style: AppTextStyles.caption.copyWith(fontSize: 9),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _dayCell(
    DashboardForecastDay day, {
    required int index,
    required bool compact,
  }) {
    final label = (day.dayLabel != null && day.dayLabel!.trim().isNotEmpty)
        ? day.dayLabel!
        : (day.dateLabel.isNotEmpty ? day.dateLabel : _dayNames[index % 7]);
    final tempLabel = day.tempMaxC != null && day.tempMinC != null
        ? '${day.tempMinC}–${day.tempMaxC}°'
        : day.tempMaxC != null
            ? '${day.tempMaxC}°'
            : kPremiumDashPlaceholderDash;
    final rainy = (day.precipitationProbabilityPct ?? 0) >= 50;
    final icon = rainy ? Icons.grain : Icons.wb_sunny_outlined;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight < 28) {
          return Center(
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(fontSize: 8),
            ),
          );
        }

        return Container(
          padding: EdgeInsets.symmetric(
            vertical: compact ? 2 : 4,
            horizontal: 1,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.borderSoft(alpha: 0.1)),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(fontSize: 9),
                ),
                if (!compact) ...[
                  const SizedBox(height: 2),
                  Icon(icon, size: 12, color: AppColors.accentAmber),
                ],
                Text(
                  tempLabel,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: compact ? 8 : 9,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!compact &&
                    day.windMaxKmh != null &&
                    day.windMaxKmh! > 0)
                  Text(
                    '${day.windMaxKmh} km/s',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 7,
                      color: AppColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
