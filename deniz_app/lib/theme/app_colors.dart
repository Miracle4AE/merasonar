import 'package:flutter/material.dart';

/// MeraSonar premium dark marine palette.
abstract final class AppColors {
  static const Color backgroundDeep = Color(0xFF020B14);
  static const Color backgroundNavy = Color(0xFF061827);
  static const Color surfaceDark = Color(0xFF0B1D2E);
  static const Color surfaceElevated = Color(0xFF102A40);

  static const Color borderCyan = Color(0xFF1FD8F5);
  static const Color accentTeal = Color(0xFF00D1C1);
  static const Color accentGreen = Color(0xFF3EE37B);
  static const Color accentAmber = Color(0xFFFFC542);
  static const Color accentRed = Color(0xFFFF5C5C);

  static const Color textPrimary = Color(0xFFF2F7FB);
  static const Color textSecondary = Color(0xFF8FA8BC);
  static const Color textMuted = Color(0xFF5C7389);

  static Color surfaceGlass({double alpha = 0.55}) =>
      surfaceDark.withValues(alpha: alpha);

  static Color borderSoft({double alpha = 0.22}) =>
      borderCyan.withValues(alpha: alpha);

  static Color glowTeal({double alpha = 0.35}) =>
      accentTeal.withValues(alpha: alpha);
}
