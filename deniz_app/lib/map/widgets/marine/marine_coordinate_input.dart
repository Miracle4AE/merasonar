import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/map/widgets/navionics_coordinate_field.dart';
import 'package:flutter/material.dart';

class MarineCoordinateInput extends StatelessWidget {
  const MarineCoordinateInput({
    super.key,
    required this.latController,
    required this.lonController,
    required this.onAnalyze,
    required this.onPickFromMap,
    this.busy = false,
  });

  final TextEditingController latController;
  final TextEditingController lonController;
  final VoidCallback onAnalyze;
  final VoidCallback onPickFromMap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF142434),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NavionicsCoordinateField(
              label: kLabelLatitude,
              hintText: '36.62123',
              isLatitude: true,
              controller: latController,
            ),
            const SizedBox(height: 10),
            NavionicsCoordinateField(
              label: kLabelLongitude,
              hintText: '29.11234',
              isLatitude: false,
              controller: lonController,
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: busy ? null : onAnalyze,
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.analytics_outlined),
              label: Text(kMarineAnalyzeButton),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: busy ? null : onPickFromMap,
              icon: const Icon(Icons.map_outlined),
              label: Text(kMarinePickFromMap),
            ),
          ],
        ),
      ),
    );
  }
}
