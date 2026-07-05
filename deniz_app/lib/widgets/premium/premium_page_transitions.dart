import 'package:deniz_app/theme/app_motion.dart';
import 'package:deniz_app/widgets/premium/premium_animation_policy.dart';
import 'package:flutter/material.dart';

/// Fade-through + hafif scale — premium ekran geçişleri.
class PremiumFadePageRoute<T> extends PageRouteBuilder<T> {
  PremiumFadePageRoute({
    required Widget page,
    super.settings,
  }) : super(
          transitionDuration: AppMotion.pageTransition,
          reverseTransitionDuration: AppMotion.pageTransition,
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            if (PremiumAnimationPolicy.reduceMotion(context)) {
              return child;
            }
            final curved = CurvedAnimation(
              parent: animation,
              curve: AppMotion.pageCurve,
              reverseCurve: AppMotion.pageCurve,
            );
            return FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
                child: child,
              ),
            );
          },
        );
}

/// MaterialApp pageTransitionsTheme builder.
class PremiumPageTransitionsBuilder extends PageTransitionsBuilder {
  const PremiumPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (PremiumAnimationPolicy.reduceMotion(context)) {
      return child;
    }
    final curved = CurvedAnimation(
      parent: animation,
      curve: AppMotion.pageCurve,
    );
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.97, end: 1.0).animate(curved),
        child: child,
      ),
    );
  }
}
