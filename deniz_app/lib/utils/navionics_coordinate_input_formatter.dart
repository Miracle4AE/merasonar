import 'package:flutter/services.dart';

import 'navionics_coordinate_parser.dart';

/// Yalnızca rakam kabul eder; °, ' ve N/E harflerini otomatik ekler.
class NavionicsCoordinateInputFormatter extends TextInputFormatter {
  NavionicsCoordinateInputFormatter({required this.isLatitude});

  final bool isLatitude;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = extractNavionicsEntryDigits(newValue.text);
    final maxTotal = maxNavionicsEntryDigits(isLatitude: isLatitude);
    final clipped =
        digits.length > maxTotal ? digits.substring(0, maxTotal) : digits;
    final formatted = formatNavionicsEntryFromDigits(
      clipped,
      isLatitude: isLatitude,
    );
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
