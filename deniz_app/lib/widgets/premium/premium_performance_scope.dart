import 'package:deniz_app/domain/premium_performance_mode.dart';
import 'package:deniz_app/services/app_preferences.dart';
import 'package:flutter/material.dart';

/// Uygulama geneli performans modu — InheritedWidget.
class PremiumPerformanceScope extends InheritedWidget {
  const PremiumPerformanceScope({
    super.key,
    required this.mode,
    required this.onModeChanged,
    required super.child,
  });

  final PremiumPerformanceMode mode;
  final ValueChanged<PremiumPerformanceMode> onModeChanged;

  static PremiumPerformanceMode of(BuildContext context) {
    return maybeOf(context)?.mode ?? PremiumPerformanceMode.full;
  }

  static PremiumPerformanceScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<PremiumPerformanceScope>();
  }

  static Future<void> setMode(
    BuildContext context,
    PremiumPerformanceMode mode,
  ) async {
    await AppPreferences.setPerformanceMode(mode);
    if (!context.mounted) return;
    maybeOf(context)?.onModeChanged(mode);
  }

  @override
  bool updateShouldNotify(PremiumPerformanceScope oldWidget) {
    return oldWidget.mode != mode;
  }
}
