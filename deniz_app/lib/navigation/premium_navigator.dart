import 'package:deniz_app/widgets/premium/premium_page_transitions.dart';
import 'package:flutter/material.dart';

/// Premium fade+scale route push — Hero uyumlu.
abstract final class PremiumNavigator {
  static Future<T?> push<T>(
    BuildContext context,
    Widget page, {
    RouteSettings? settings,
  }) {
    return Navigator.of(context).push<T>(
      PremiumFadePageRoute<T>(page: page, settings: settings),
    );
  }

  static Future<T?> pushReplacement<T, TO>(
    BuildContext context,
    Widget page, {
    RouteSettings? settings,
  }) {
    return Navigator.of(context).pushReplacement<T, TO>(
      PremiumFadePageRoute<T>(page: page, settings: settings),
    );
  }
}
