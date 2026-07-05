import 'dart:async';

import 'package:flutter/material.dart';

import '../splash/contour_lines_painter.dart';
import '../splash/sky_gradient_painter.dart';
import 'home_ambient_pulse_painter.dart';
import 'home_center_glow_painter.dart';

/// Splash ile aynı gökyüzü + çok yavaş kontür + ~7 saniyede bir soluk sonar nabzı.
/// Katmanlar ayrı [RepaintBoundary]; kontür setState ~2 s’de bir, nabız yalnız ~400 ms animasyonda.
class MerasonarHomeAmbient extends StatefulWidget {
  const MerasonarHomeAmbient({super.key});

  @override
  State<MerasonarHomeAmbient> createState() => _MerasonarHomeAmbientState();
}

class _MerasonarHomeAmbientState extends State<MerasonarHomeAmbient>
    with SingleTickerProviderStateMixin {
  double _contourPhase = 0;
  Timer? _driftTimer;
  Timer? _firstPulseTimer;
  Timer? _pulseScheduleTimer;
  late AnimationController _pulseAnim;

  void _triggerPulse() {
    if (!mounted || _pulseAnim.isAnimating) return;
    _pulseAnim.forward(from: 0);
  }

  @override
  void initState() {
    super.initState();
    _pulseAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _pulseAnim.reset();
        }
      });
    _driftTimer = Timer.periodic(const Duration(milliseconds: 2400), (_) {
      if (!mounted) return;
      setState(() => _contourPhase += 0.0055);
    });
    _firstPulseTimer = Timer(const Duration(seconds: 4), _triggerPulse);
    _pulseScheduleTimer = Timer.periodic(const Duration(seconds: 7), (_) {
      _triggerPulse();
    });
  }

  @override
  void dispose() {
    _driftTimer?.cancel();
    _firstPulseTimer?.cancel();
    _pulseScheduleTimer?.cancel();
    _pulseAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const RepaintBoundary(
          child: CustomPaint(
            painter: SkyGradientPainter(),
            child: SizedBox.expand(),
          ),
        ),
        RepaintBoundary(
          child: CustomPaint(
            painter: ContourLinesPainter(
              phase: _contourPhase,
              opacityScale: 0.38,
            ),
            child: const SizedBox.expand(),
          ),
        ),
        const RepaintBoundary(
          child: CustomPaint(
            painter: HomeCenterGlowPainter(),
            child: SizedBox.expand(),
          ),
        ),
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _pulseAnim,
            builder: (context, _) {
              if (_pulseAnim.value <= 0) {
                return const SizedBox.expand();
              }
              return CustomPaint(
                painter: HomeAmbientPulsePainter(t: _pulseAnim.value),
                child: const SizedBox.expand(),
              );
            },
          ),
        ),
      ],
    );
  }
}
