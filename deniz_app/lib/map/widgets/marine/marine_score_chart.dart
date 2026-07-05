import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:flutter/material.dart';

/// Gelecek faz — skor grafiği placeholder.
class MarineScoreChart extends StatelessWidget {
  const MarineScoreChart({super.key, this.score = 0});

  final int score;

  @override
  Widget build(BuildContext context) {
    return Text('$kMarineSuitabilityLabel: $score ($kMarinePlaceholderFuture)');
  }
}
