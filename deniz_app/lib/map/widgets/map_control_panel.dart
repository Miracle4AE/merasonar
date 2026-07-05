import 'package:deniz_app/map/widgets/premium/map_premium_toolbox.dart';
import 'package:deniz_app/widgets/premium/premium_status_badge.dart';
import 'package:flutter/material.dart';

export 'package:deniz_app/map/widgets/premium/map_premium_toolbox.dart'
    show HotspotSortMode, MapPremiumToolbox;

/// Geriye dönük uyumluluk — premium toolbox sarmalayıcısı.
class MapControlPanel extends StatelessWidget {
  const MapControlPanel({
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
    return MapPremiumToolbox(
      showClassA: showClassA,
      showClassB: showClassB,
      showClassC: showClassC,
      minScore: minScore,
      showIntensity: showIntensity,
      showCorridor: showCorridor,
      showLegend: showLegend,
      sortMode: sortMode,
      gpsReliabilityLabel: gpsReliabilityLabel,
      gpsReliabilityTone: gpsReliabilityTone,
      onToggleClassA: onToggleClassA,
      onToggleClassB: onToggleClassB,
      onToggleClassC: onToggleClassC,
      onMinScoreChanged: onMinScoreChanged,
      onToggleIntensity: onToggleIntensity,
      onToggleCorridor: onToggleCorridor,
      onToggleLegend: onToggleLegend,
      onSortModeChanged: onSortModeChanged,
      onRefresh: onRefresh,
      onCenterBoat: onCenterBoat,
    );
  }
}
