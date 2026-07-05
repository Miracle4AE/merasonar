import 'package:deniz_app/domain/marine_consensus_value.dart';
import 'package:deniz_app/domain/marine_intelligence_report.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/theme/app_radius.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/widgets/premium/premium_card.dart';
import 'package:deniz_app/widgets/premium/premium_metric_chip.dart';
import 'package:flutter/material.dart';

class MarineConditionsGrid extends StatelessWidget {
  const MarineConditionsGrid({
    super.key,
    required this.report,
  });

  final MarineIntelligenceReport report;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _ConditionTileData(
        icon: Icons.wb_sunny_outlined,
        title: kMarineSectionWeather,
        value: _formatValue(report.weather.temperatureC, suffix: '°C'),
        subtitle: _weatherSubtitle(report),
        confidence: report.weather.temperatureC?.confidence,
      ),
      _ConditionTileData(
        icon: Icons.air,
        title: kMarineSectionWind,
        value: _formatValue(report.wind.speedKmh, suffix: ' km/h'),
        subtitle: report.wind.directionText ?? kMarineNoData,
        confidence: report.wind.speedKmh?.confidence,
      ),
      _ConditionTileData(
        icon: Icons.waves,
        title: kMarineSectionSea,
        value: _formatValue(report.marine.waveHeightM, suffix: ' m'),
        subtitle: _formatValue(report.marine.wavePeriodS, suffix: ' s periyot'),
        confidence: report.marine.waveHeightM?.confidence,
      ),
      _ConditionTileData(
        icon: Icons.water_outlined,
        title: kMarineSectionSwell,
        value: _formatValue(report.marine.swellHeightM, suffix: ' m'),
        subtitle: _formatValue(report.marine.swellPeriodS, suffix: ' s'),
        confidence: report.marine.swellHeightM?.confidence,
      ),
      _ConditionTileData(
        icon: Icons.nightlight_round,
        title: kMarineSectionAstronomy,
        value: report.astronomy.moonPhase ?? kMarineNoData,
        subtitle: report.astronomy.moonIlluminationPct != null
            ? 'Aydınlanma %${report.astronomy.moonIlluminationPct!.toStringAsFixed(0)}'
            : kMarineNoData,
      ),
      _ConditionTileData(
        icon: Icons.wb_twilight,
        title: kMarinePremiumSunLabel,
        value: report.astronomy.sunrise ?? kMarineNoData,
        subtitle: report.astronomy.sunset != null
            ? 'Batım ${report.astronomy.sunset}'
            : kMarineNoData,
      ),
    ];

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(kMarinePremiumConditionsTitle, style: AppTextStyles.cardTitle),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossCount = constraints.maxWidth >= 520 ? 3 : 2;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: tiles.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossCount,
                  mainAxisSpacing: AppSpacing.sm,
                  crossAxisSpacing: AppSpacing.sm,
                  childAspectRatio: crossCount == 3 ? 1.35 : 1.2,
                ),
                itemBuilder: (_, i) => _ConditionMiniCard(data: tiles[i]),
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatValue(MarineConsensusValue? value, {String suffix = ''}) {
    final v = value?.finalValue;
    if (v == null) return kMarineNoData;
    return '${v.toStringAsFixed(1)}$suffix';
  }

  String _weatherSubtitle(MarineIntelligenceReport report) {
    final precip = report.weather.precipitationProbabilityPct?.finalValue;
    if (precip == null) return kMarineNoData;
    return 'Yağış %${precip.toStringAsFixed(0)}';
  }
}

class _ConditionTileData {
  const _ConditionTileData({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    this.confidence,
  });

  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final double? confidence;
}

class _ConditionMiniCard extends StatelessWidget {
  const _ConditionMiniCard({required this.data});

  final _ConditionTileData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withValues(alpha: 0.35),
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.borderSoft(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(data.icon, size: 18, color: AppColors.accentTeal),
          const SizedBox(height: 4),
          Text(data.title, style: AppTextStyles.caption, maxLines: 1),
          const Spacer(),
          Text(
            data.value,
            style: AppTextStyles.cardTitle.copyWith(fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            data.subtitle,
            style: AppTextStyles.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (data.confidence != null && data.confidence! > 0) ...[
            const SizedBox(height: 4),
            PremiumMetricChip(
              label: kMarineConfidenceLabel,
              value: '${(data.confidence! * 100).toStringAsFixed(0)}%',
            ),
          ],
        ],
      ),
    );
  }
}
