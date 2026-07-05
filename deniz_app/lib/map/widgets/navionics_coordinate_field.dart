import 'package:flutter/material.dart';

import '../../utils/navionics_coordinate_input_formatter.dart';

/// Navionics koordinat girişi — kullanıcı yalnızca rakam yazar; biçim otomatik oluşur.
class NavionicsCoordinateField extends StatelessWidget {
  const NavionicsCoordinateField({
    super.key,
    required this.controller,
    required this.label,
    required this.hintText,
    required this.isLatitude,
    this.errorText,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final bool isLatitude;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      autocorrect: false,
      enableSuggestions: false,
      inputFormatters: [
        NavionicsCoordinateInputFormatter(isLatitude: isLatitude),
      ],
      style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        errorText: errorText,
        isDense: true,
        helperText: isLatitude
            ? 'Sadece rakam — ör. 3724252 → 37°24.252\' N'
            : 'Sadece rakam — ör. 02713632 → 027°13.632\' E',
        helperMaxLines: 2,
      ),
    );
  }
}
