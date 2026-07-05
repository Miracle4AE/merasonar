import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:flutter/material.dart';

/// Gelecek faz — basit güven göstergesi.
class MarineConfidenceGauge extends StatelessWidget {
  const MarineConfidenceGauge({super.key, required this.confidence});

  final double confidence;

  @override
  Widget build(BuildContext context) {
    final pct = (confidence.clamp(0, 1) * 100).toStringAsFixed(0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$kMarineConfidenceLabel: %$pct'),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: confidence.clamp(0, 1),
          backgroundColor: Colors.white12,
          color: const Color(0xFF4DD0E1),
        ),
      ],
    );
  }
}
