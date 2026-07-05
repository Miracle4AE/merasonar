import 'package:flutter/animation.dart';

/// UI-7 motion tokens — tutarlı AAA animasyon süreleri ve eğrileri.
abstract final class AppMotion {
  static const Duration microPress = Duration(milliseconds: 16);
  static const Duration microRelease = Duration(milliseconds: 180);
  static const Duration hover = Duration(milliseconds: 220);
  static const Duration glowBreath = Duration(milliseconds: 2800);
  static const Duration shimmer = Duration(milliseconds: 1800);
  static const Duration pageTransition = Duration(milliseconds: 380);
  static const Duration dockBounce = Duration(milliseconds: 260);
  static const Duration cameraMove = Duration(milliseconds: 720);
  static const Duration cinematicStagger = Duration(milliseconds: 120);
  static const Duration panelSlide = Duration(milliseconds: 420);
  static const Duration toastVisible = Duration(milliseconds: 3200);

  static const Curve microCurve = Curves.easeOutCubic;
  static const Curve releaseCurve = Curves.easeOutBack;
  static const Curve pageCurve = Curves.easeInOutCubic;

  static const double parallaxMaxTilt = 0.012;
  static const double pressScale = 0.982;
  static const double hoverLift = 1.012;
  static const double dockIconActiveScale = 1.14;
}
