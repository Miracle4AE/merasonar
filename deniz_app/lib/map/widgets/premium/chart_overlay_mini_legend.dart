import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/widgets/premium/premium_glass_panel.dart';
import 'package:flutter/material.dart';

class ChartOverlayMiniLegend extends StatefulWidget {
  const ChartOverlayMiniLegend({super.key});

  @override
  State<ChartOverlayMiniLegend> createState() => _ChartOverlayMiniLegendState();
}

class _ChartOverlayMiniLegendState extends State<ChartOverlayMiniLegend> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return PremiumGlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  kMapChartOverlayMiniLegendTitle,
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: AppSpacing.sm),
            _LegendRow(color: const Color(0xFF00E676), label: 'A'),
            _LegendRow(color: const Color(0xFFFFB300), label: 'B'),
            _LegendRow(color: const Color(0xFF90A4AE), label: 'C'),
            _LegendRow(
              color: AppColors.accentTeal,
              label: kMapPremiumLegendBoat,
              icon: Icons.directions_boat_filled_rounded,
            ),
          ],
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    this.icon,
  });

  final Color color;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.85),
              border: Border.all(color: color),
            ),
            child: icon != null
                ? Icon(icon, size: 7, color: AppColors.textPrimary)
                : null,
          ),
          const SizedBox(width: 6),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
