import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:flutter/material.dart';

/// Gelecek faz — spot ziyaret / başarı zaman çizelgesi placeholder.
class SpotIntelligenceTimeline extends StatelessWidget {
  const SpotIntelligenceTimeline({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(kMarinePlaceholderFuture, style: const TextStyle(color: Colors.white54));
  }
}
