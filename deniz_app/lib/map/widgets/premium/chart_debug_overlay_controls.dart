import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/map/widgets/premium/premium_map_controls.dart';
import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/widgets/premium/premium_glass_panel.dart';
import 'package:flutter/material.dart';

class ChartDebugOverlayControls extends StatelessWidget {
  const ChartDebugOverlayControls({
    super.key,
    required this.visible,
    required this.opacity,
    required this.onToggle,
    required this.onOpacityChanged,
    this.compact = false,
  });

  final bool visible;
  final double opacity;
  final ValueChanged<bool> onToggle;
  final ValueChanged<double> onOpacityChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return PremiumGlassPanel(
      padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(kMapChartDebugOverlayTitle, style: AppTextStyles.cardTitle),
          const SizedBox(height: AppSpacing.sm),
          PremiumMapSwitch(
            label: kMapChartDebugOverlayToggle,
            value: visible,
            onChanged: onToggle,
          ),
          if (visible) ...[
            const SizedBox(height: AppSpacing.sm),
            PremiumMapSlider(
              label: kMapChartDebugOverlayOpacity,
              value: opacity,
              min: 0.15,
              max: 0.95,
              divisions: 16,
              onChanged: onOpacityChanged,
              valueLabel: (v) => '${(v * 100).round()}%',
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(kMapChartDebugOverlayLegendTitle, style: AppTextStyles.caption),
            const SizedBox(height: AppSpacing.xs),
            _LegendItem(color: AppColors.accentAmber, label: kMapChartDebugLegendHot),
            _LegendItem(color: AppColors.accentTeal, label: kMapChartDebugLegendContour),
            _LegendItem(color: const Color(0xFF00E676), label: kMapChartDebugLegendDropOff),
            _LegendItem(color: AppColors.textMuted, label: kMapChartDebugLegendWeak),
          ],
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: color),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(label, style: AppTextStyles.caption)),
        ],
      ),
    );
  }
}
