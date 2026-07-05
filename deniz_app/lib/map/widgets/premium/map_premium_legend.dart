import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/widgets/premium/premium_glass_panel.dart';
import 'package:deniz_app/widgets/premium/premium_icon_button.dart';
import 'package:flutter/material.dart';

class MapPremiumLegend extends StatefulWidget {
  const MapPremiumLegend({
    super.key,
    required this.visible,
    required this.showIntensity,
    required this.showCorridor,
  });

  final bool visible;
  final bool showIntensity;
  final bool showCorridor;

  @override
  State<MapPremiumLegend> createState() => _MapPremiumLegendState();
}

class _MapPremiumLegendState extends State<MapPremiumLegend> {
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();

    return PremiumGlassPanel(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: SizedBox(
        width: 220,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    kMapPremiumLegendTitleShort,
                    style: AppTextStyles.cardTitle.copyWith(fontSize: 12),
                  ),
                ),
                PremiumIconButton(
                  key: const Key('btn_map_legend_toggle'),
                  icon: _collapsed ? Icons.expand_more : Icons.expand_less,
                  onPressed: () => setState(() => _collapsed = !_collapsed),
                ),
              ],
            ),
            if (!_collapsed) ...[
              const SizedBox(height: 4),
              _row(const Color(0xFF00E5FF), kMapPremiumLegendBoatShort),
              _row(const Color(0xFFFF5252), kMapPremiumLegendA),
              _row(const Color(0xFFFFB300), kMapPremiumLegendB),
              _row(const Color(0xFF66BB6A), kMapPremiumLegendC),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}
