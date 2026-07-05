import 'dart:ui';



import 'package:deniz_app/theme/app_colors.dart';

import 'package:deniz_app/theme/app_radius.dart';

import 'package:deniz_app/theme/app_spacing.dart';

import 'package:deniz_app/widgets/premium/premium_animation_policy.dart';

import 'package:flutter/material.dart';



/// Glass System V2 — edge lighting, gradient border, inner depth, noise.

class PremiumGlassPanel extends StatelessWidget {

  const PremiumGlassPanel({

    super.key,

    required this.child,

    this.padding,

    this.blur = 18,

    this.borderRadius,

    this.elevation = 1.0,

  });



  final Widget child;

  final EdgeInsetsGeometry? padding;

  final double blur;

  final BorderRadius? borderRadius;

  final double elevation;



  @override

  Widget build(BuildContext context) {

    final radius = borderRadius ?? AppRadius.panel;

    final effectiveBlur = PremiumAnimationPolicy.effectiveBlur(context, blur);

    final useBlur = PremiumAnimationPolicy.useBackdropBlur(context, blur);

    final glowScale = PremiumAnimationPolicy.glowIntensity(context);



    return RepaintBoundary(

      child: DecoratedBox(

        decoration: BoxDecoration(

          borderRadius: radius,

          boxShadow: [

            BoxShadow(

              color: Colors.black.withValues(alpha: 0.38 * elevation),

              blurRadius: 24,

              offset: const Offset(0, 10),

            ),

            if (glowScale > 0.2)

              BoxShadow(

                color: AppColors.glowTeal(alpha: 0.08 * elevation * glowScale),

                blurRadius: 28,

                spreadRadius: -6,

              ),

          ],

        ),

        child: ClipRRect(

          borderRadius: radius,

          child: Stack(

            children: [

              if (useBlur)

                Positioned.fill(

                  child: BackdropFilter(

                    filter: ImageFilter.blur(

                      sigmaX: effectiveBlur,

                      sigmaY: effectiveBlur,

                    ),

                    child: const ColoredBox(color: Colors.transparent),

                  ),

                ),

              DecoratedBox(

                decoration: BoxDecoration(

                  borderRadius: radius,

                  gradient: LinearGradient(

                    begin: Alignment.topLeft,

                    end: Alignment.bottomRight,

                    colors: [

                      AppColors.surfaceGlass(

                        alpha: useBlur ? 0.52 : 0.78,

                      ),

                      AppColors.surfaceGlass(

                        alpha: useBlur ? 0.28 : 0.62,

                      ),

                    ],

                  ),

                  border: Border.all(

                    width: 1,

                    color: AppColors.borderSoft(alpha: 0.32),

                  ),

                ),

                child: Stack(

                  children: [

                    Positioned(

                      top: 0,

                      left: 0,

                      right: 0,

                      height: 1,

                      child: DecoratedBox(

                        decoration: BoxDecoration(

                          gradient: LinearGradient(

                            colors: [

                              Colors.white.withValues(alpha: 0.28),

                              Colors.white.withValues(alpha: 0.04),

                              Colors.transparent,

                            ],

                          ),

                        ),

                      ),

                    ),

                    if (useBlur)

                      Positioned.fill(

                        child: CustomPaint(

                          painter: _GlassNoisePainter(),

                        ),

                      ),

                    Padding(

                      padding: padding ?? const EdgeInsets.all(AppSpacing.lg),

                      child: child,

                    ),

                  ],

                ),

              ),

            ],

          ),

        ),

      ),

    );

  }

}



class _GlassNoisePainter extends CustomPainter {

  static const _points = <(double, double, double)>[

    (0.08, 0.12, 0.04),

    (0.22, 0.34, 0.03),

    (0.41, 0.18, 0.035),

    (0.58, 0.62, 0.03),

    (0.73, 0.28, 0.04),

    (0.86, 0.74, 0.03),

    (0.15, 0.78, 0.035),

    (0.92, 0.12, 0.025),

  ];



  @override

  void paint(Canvas canvas, Size size) {

    final paint = Paint()..color = Colors.white.withValues(alpha: 0.025);

    for (final p in _points) {

      canvas.drawCircle(

        Offset(p.$1 * size.width, p.$2 * size.height),

        p.$3,

        paint,

      );

    }

  }



  @override

  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;

}

