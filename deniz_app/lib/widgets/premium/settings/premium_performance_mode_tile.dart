import 'package:deniz_app/domain/premium_performance_mode.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/widgets/premium/premium_performance_scope.dart';
import 'package:flutter/material.dart';

/// Performans modu seçici — Mission Control sistem şeridinde.
class PremiumPerformanceModeTile extends StatelessWidget {
  const PremiumPerformanceModeTile({super.key});

  static String labelFor(PremiumPerformanceMode mode) {
    return switch (mode) {
      PremiumPerformanceMode.full => kPremiumPerformanceModeFull,
      PremiumPerformanceMode.balanced => kPremiumPerformanceModeBalanced,
      PremiumPerformanceMode.batterySaver => kPremiumPerformanceModeBattery,
    };
  }

  static String hintFor(PremiumPerformanceMode mode) {
    return switch (mode) {
      PremiumPerformanceMode.full => kPremiumPerformanceModeFullHint,
      PremiumPerformanceMode.balanced => kPremiumPerformanceModeBalancedHint,
      PremiumPerformanceMode.batterySaver => kPremiumPerformanceModeBatteryHint,
    };
  }

  @override
  Widget build(BuildContext context) {
    final mode = PremiumPerformanceScope.of(context);

    return Material(
      type: MaterialType.transparency,
      child: Semantics(
        label: kPremiumPerformanceModeTitle,
        value: labelFor(mode),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(kPremiumPerformanceModeTitle, style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: PremiumPerformanceMode.values.map((m) {
              return FilterChip(
                key: Key('performance_mode_${m.name}'),
                selected: mode == m,
                label: Text(labelFor(m)),
                onSelected: (_) => PremiumPerformanceScope.setMode(context, m),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(hintFor(mode), style: AppTextStyles.caption),
        ],
      ),
      ),
    );
  }
}
