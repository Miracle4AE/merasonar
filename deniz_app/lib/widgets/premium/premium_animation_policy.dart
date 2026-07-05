import 'package:deniz_app/domain/app_settings.dart';
import 'package:deniz_app/domain/premium_performance_mode.dart';
import 'package:deniz_app/services/app_settings_controller.dart';
import 'package:deniz_app/widgets/premium/premium_performance_scope.dart';
import 'package:flutter/widgets.dart';
abstract final class PremiumAnimationPolicy {
  static bool reduceMotion(BuildContext context) {
    final userPref = AppSettingsScope.maybeOf(context)?.settings.reduceMotion;
    if (userPref == true) return true;
    return MediaQuery.disableAnimationsOf(context);
  }

  static PremiumPerformanceMode performanceMode(BuildContext context) {
    return PremiumPerformanceScope.of(context);
  }

  static bool continuousMotionEnabled(BuildContext context) {
    if (reduceMotion(context)) return false;
    if (_isWidgetTestBinding) return false;
    if (performanceMode(context) == PremiumPerformanceMode.batterySaver) {
      return false;
    }
    return true;
  }

  /// 0 = animasyon yok, 1 = tam animasyon.
  static double motionScale(BuildContext context) {
    if (reduceMotion(context)) return 0;
    if (_isWidgetTestBinding) return 0;
    return switch (performanceMode(context)) {
      PremiumPerformanceMode.full => 1,
      PremiumPerformanceMode.balanced => 0.65,
      PremiumPerformanceMode.batterySaver => 0,
    };
  }

  static bool ambientEnabled(BuildContext context) {
    if (reduceMotion(context)) return false;
    return performanceMode(context) != PremiumPerformanceMode.batterySaver;
  }

  static bool ambientAnimated(BuildContext context) {
    if (!ambientEnabled(context)) return false;
    return performanceMode(context) == PremiumPerformanceMode.full;
  }

  static double glowIntensity(BuildContext context) {
    final settings = AppSettingsScope.maybeOf(context)?.settings;
    final userScale = settings?.glowIntensity.multiplier ?? 1.0;
    if (reduceMotion(context)) return 0.2 * userScale;
    final base = switch (performanceMode(context)) {
      PremiumPerformanceMode.full => 1,
      PremiumPerformanceMode.balanced => 0.55,
      PremiumPerformanceMode.batterySaver => 0.15,
    };
    return base * userScale;
  }

  static double effectiveBlur(BuildContext context, double requested) {
    if (performanceMode(context) == PremiumPerformanceMode.batterySaver) {
      return 0;
    }
    var scaled = requested;
    if (performanceMode(context) == PremiumPerformanceMode.balanced) {
      scaled *= 0.55;
    }
    if (reduceMotion(context)) {
      scaled *= 0.5;
    }
    return scaled;
  }

  static bool useBackdropBlur(BuildContext context, double requested) {
    return effectiveBlur(context, requested) >= 2;
  }

  static Duration ambientDuration(BuildContext context) {
    return performanceMode(context) == PremiumPerformanceMode.balanced
        ? const Duration(seconds: 48)
        : const Duration(seconds: 24);
  }

  static bool get _isWidgetTestBinding {
    final binding = WidgetsBinding.instance;
    final name = binding.runtimeType.toString();
    return name.contains('TestWidgets') || name.contains('AutomatedTest');
  }

  /// Widget test dışında mod bazlı animasyon politikası.
  @visibleForTesting
  static bool continuousMotionForMode(PremiumPerformanceMode mode) {
    return mode != PremiumPerformanceMode.batterySaver;
  }

  @visibleForTesting
  static double motionScaleForMode(PremiumPerformanceMode mode) {
    return switch (mode) {
      PremiumPerformanceMode.full => 1,
      PremiumPerformanceMode.balanced => 0.65,
      PremiumPerformanceMode.batterySaver => 0,
    };
  }
}
