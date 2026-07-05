import 'dart:math' as math;



import 'package:deniz_app/theme/app_colors.dart';

import 'package:deniz_app/widgets/premium/premium_animation_policy.dart';

import 'package:flutter/material.dart';



/// GPU-dostu yavaş hareket eden marine ambient arka plan.

class AmbientMarineBackground extends StatefulWidget {

  const AmbientMarineBackground({

    super.key,

    required this.child,

    this.enabled = true,

  });



  final Widget child;

  final bool enabled;



  @override

  State<AmbientMarineBackground> createState() => _AmbientMarineBackgroundState();

}



class _AmbientMarineBackgroundState extends State<AmbientMarineBackground>

    with SingleTickerProviderStateMixin {

  AnimationController? _controller;



  @override

  void didChangeDependencies() {

    super.didChangeDependencies();

    _syncController();

  }



  void _syncController() {

    final animated = widget.enabled &&

        PremiumAnimationPolicy.ambientAnimated(context);

    if (!animated) {

      _controller?.stop();

      return;

    }

    final duration = PremiumAnimationPolicy.ambientDuration(context);

    if (_controller == null) {

      _controller = AnimationController(vsync: this, duration: duration);

    } else if (_controller!.duration != duration) {

      _controller!.duration = duration;

    }

    if (!_controller!.isAnimating) {

      _controller!.repeat();

    }

  }



  @override

  void dispose() {

    _controller?.dispose();

    super.dispose();

  }



  Widget _staticBackground() {

    return RepaintBoundary(

      child: CustomPaint(

        painter: _AmbientMarinePainter(phase: 0),

        child: const SizedBox.expand(),

      ),

    );

  }



  @override

  Widget build(BuildContext context) {

    if (!widget.enabled) return widget.child;



    final animated = PremiumAnimationPolicy.ambientAnimated(context);

    if (!animated) {

      return Stack(

        fit: StackFit.expand,

        children: [

          _staticBackground(),

          widget.child,

        ],

      );

    }



    final controller = _controller;

    if (controller == null) {

      return Stack(

        fit: StackFit.expand,

        children: [

          _staticBackground(),

          widget.child,

        ],

      );

    }



    return Stack(

      fit: StackFit.expand,

      children: [

        RepaintBoundary(

          child: AnimatedBuilder(

            animation: controller,

            builder: (context, _) {

              return CustomPaint(

                painter: _AmbientMarinePainter(phase: controller.value),

                child: const SizedBox.expand(),

              );

            },

          ),

        ),

        widget.child,

      ],

    );

  }

}



class _AmbientMarinePainter extends CustomPainter {

  _AmbientMarinePainter({required this.phase});



  final double phase;



  @override

  void paint(Canvas canvas, Size size) {

    canvas.drawRect(

      Offset.zero & size,

      Paint()..color = AppColors.backgroundDeep,

    );



    final blobs = [

      (

        color: AppColors.accentTeal.withValues(alpha: 0.14),

        cx: 0.22 + math.sin(phase * math.pi * 2) * 0.08,

        cy: 0.18 + math.cos(phase * math.pi * 2) * 0.06,

        r: size.shortestSide * 0.42,

      ),

      (

        color: AppColors.borderCyan.withValues(alpha: 0.1),

        cx: 0.78 + math.cos(phase * math.pi * 2 + 1.2) * 0.07,

        cy: 0.62 + math.sin(phase * math.pi * 2 + 0.8) * 0.05,

        r: size.shortestSide * 0.36,

      ),

      (

        color: AppColors.accentGreen.withValues(alpha: 0.06),

        cx: 0.48 + math.sin(phase * math.pi * 2 + 2.1) * 0.05,

        cy: 0.82 + math.cos(phase * math.pi * 2 + 1.6) * 0.04,

        r: size.shortestSide * 0.28,

      ),

    ];



    for (final b in blobs) {

      final center = Offset(b.cx * size.width, b.cy * size.height);

      final paint = Paint()

        ..shader = RadialGradient(

          colors: [b.color, b.color.withValues(alpha: 0)],

        ).createShader(Rect.fromCircle(center: center, radius: b.r));

      canvas.drawCircle(center, b.r, paint);

    }



    final vignette = Paint()

      ..shader = RadialGradient(

        center: Alignment.center,

        radius: 1.05,

        colors: [

          Colors.transparent,

          AppColors.backgroundDeep.withValues(alpha: 0.55),

        ],

      ).createShader(Offset.zero & size);

    canvas.drawRect(Offset.zero & size, vignette);

  }



  @override

  bool shouldRepaint(covariant _AmbientMarinePainter oldDelegate) {

    return oldDelegate.phase != phase;

  }

}

