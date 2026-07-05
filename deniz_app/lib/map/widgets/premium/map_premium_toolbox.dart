import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/map/widgets/premium/premium_map_controls.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/widgets/premium/premium_glass_panel.dart';
import 'package:deniz_app/widgets/premium/premium_icon_button.dart';
import 'package:deniz_app/widgets/premium/premium_status_badge.dart';
import 'package:flutter/material.dart';

enum HotspotSortMode {
  scoreThenDistance,
  proximity,
}

/// Sol floating glass toolbox — compact premium filtre paneli.
class MapPremiumToolbox extends StatelessWidget {
  const MapPremiumToolbox({
    super.key,
    required this.showClassA,
    required this.showClassB,
    required this.showClassC,
    required this.minScore,
    required this.showIntensity,
    required this.showCorridor,
    required this.showLegend,
    required this.sortMode,
    required this.onToggleClassA,
    required this.onToggleClassB,
    required this.onToggleClassC,
    required this.onMinScoreChanged,
    required this.onToggleIntensity,
    required this.onToggleCorridor,
    required this.onToggleLegend,
    required this.onSortModeChanged,
    required this.onRefresh,
    required this.onCenterBoat,
    this.gpsReliabilityLabel,
    this.gpsReliabilityTone = PremiumStatusTone.neutral,
  });

  final bool showClassA;
  final bool showClassB;
  final bool showClassC;
  final double minScore;
  final bool showIntensity;
  final bool showCorridor;
  final bool showLegend;
  final HotspotSortMode sortMode;
  final ValueChanged<bool> onToggleClassA;
  final ValueChanged<bool> onToggleClassB;
  final ValueChanged<bool> onToggleClassC;
  final ValueChanged<double> onMinScoreChanged;
  final ValueChanged<bool> onToggleIntensity;
  final ValueChanged<bool> onToggleCorridor;
  final ValueChanged<bool> onToggleLegend;
  final ValueChanged<HotspotSortMode> onSortModeChanged;
  final VoidCallback onRefresh;
  final VoidCallback onCenterBoat;
  final String? gpsReliabilityLabel;
  final PremiumStatusTone gpsReliabilityTone;

  @override
  Widget build(BuildContext context) {
    return PremiumGlassPanel(
      child: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    kMapPremiumFiltersTitle,
                    style: AppTextStyles.cardTitle.copyWith(fontSize: 13),
                  ),
                ),
                PremiumIconButton(
                  icon: Icons.refresh_rounded,
                  tooltip: kMarineActionRefresh,
                  onPressed: onRefresh,
                ),
                PremiumIconButton(
                  icon: Icons.my_location_rounded,
                  tooltip: kMapPremiumCenterBoatTooltip,
                  onPressed: onCenterBoat,
                ),
              ],
            ),
            if (gpsReliabilityLabel != null) ...[
              const SizedBox(height: AppSpacing.xs),
              PremiumStatusBadge(
                label: gpsReliabilityLabel!,
                tone: gpsReliabilityTone,
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text(kMapPremiumCategory, style: AppTextStyles.caption),
            const SizedBox(height: 4),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                PremiumMapCategoryChip(
                  label: 'A',
                  color: const Color(0xFFFF5252),
                  selected: showClassA,
                  onChanged: onToggleClassA,
                ),
                PremiumMapCategoryChip(
                  label: 'B',
                  color: const Color(0xFFFFB300),
                  selected: showClassB,
                  onChanged: onToggleClassB,
                ),
                PremiumMapCategoryChip(
                  label: 'C',
                  color: const Color(0xFF66BB6A),
                  selected: showClassC,
                  onChanged: onToggleClassC,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            PremiumMapSlider(
              label: kMapPremiumMinScore,
              value: minScore,
              min: 0,
              max: 1,
              divisions: 20,
              onChanged: onMinScoreChanged,
              valueLabel: (v) => v.toStringAsFixed(2),
            ),
            const SizedBox(height: AppSpacing.xs),
            PremiumMapSwitch(
              label: kMapPremiumDensityLayer,
              value: showIntensity,
              onChanged: onToggleIntensity,
            ),
            PremiumMapSwitch(
              label: kMapPremiumConnectionLines,
              value: showCorridor,
              onChanged: onToggleCorridor,
            ),
            PremiumMapSwitch(
              label: kMapPremiumLegendToggle,
              value: showLegend,
              onChanged: onToggleLegend,
            ),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<HotspotSortMode>(
              style: ButtonStyle(
                foregroundColor:
                    WidgetStateProperty.all(AppTextStyles.caption.color),
                visualDensity: VisualDensity.compact,
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const Color(0x331FD8F5);
                  }
                  return Colors.transparent;
                }),
              ),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: HotspotSortMode.scoreThenDistance,
                  label: Text('Skor'),
                ),
                ButtonSegment(
                  value: HotspotSortMode.proximity,
                  label: Text('Yakın'),
                ),
              ],
              selected: {sortMode},
              onSelectionChanged: (selection) {
                if (selection.isNotEmpty) onSortModeChanged(selection.first);
              },
            ),
          ],
        ),
      ),
    );
  }
}
