import 'package:deniz_app/map/widgets/premium/map_premium_legend.dart';
import 'package:flutter/material.dart';

/// Geriye dönük uyumluluk — premium legend sarmalayıcısı.
class MapLegendCard extends StatelessWidget {
  const MapLegendCard({
    super.key,
    required this.visible,
    required this.showIntensity,
    required this.showCorridor,
  });

  final bool visible;
  final bool showIntensity;
  final bool showCorridor;

  @override
  Widget build(BuildContext context) {
    return MapPremiumLegend(
      visible: visible,
      showIntensity: showIntensity,
      showCorridor: showCorridor,
    );
  }
}
