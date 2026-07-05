import 'package:flutter/services.dart';

import 'app_haptics.dart';

/// Premium haptic katmanı — platform desteklemezse sessizce no-op.
abstract final class PremiumHaptics {
  static void light() => AppHaptics.lightTap();

  static void medium() => AppHaptics.analysisComplete();

  static void success() {
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  static void warning() => AppHaptics.warning();

  static void error() {
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  static void selection() {
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
  }
}
