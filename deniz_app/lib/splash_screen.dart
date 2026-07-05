import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'splash/contour_lines_painter.dart';
import 'splash/sky_gradient_painter.dart';
import 'splash/sonar_pulse_painter.dart';
import 'splash/splash_brand.dart';
import 'splash/wave_reveal_painter.dart';

/// Varsayılan toplam süre (~2.5 s). Test / CI: `DenizApp(splashDuration: …)` veya
/// `--dart-define=MERASONAR_SPLASH_MS=50` ile kısaltılabilir.
Duration _resolveSplashTotalDuration(Duration? override) {
  if (override != null) return override;
  const env = int.fromEnvironment('MERASONAR_SPLASH_MS', defaultValue: -1);
  if (env >= 0) {
    return Duration(milliseconds: env.clamp(0, 60000));
  }
  return const Duration(milliseconds: 2500);
}

/// Premium marine splash — Android & Windows uyumlu, CustomPainter ağırlıklı.
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.onFinished,
    this.duration,
  });

  final VoidCallback onFinished;

  /// Verilmezse [_resolveSplashTotalDuration] (varsayılan ~2.5 s veya dart-define).
  final Duration? duration;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  late final Animation<double> _waveReveal;
  late final Animation<double> _titleOpacity;
  late final Animation<double> _titleDy;
  late final Animation<double> _sloganOpacity;

  bool _completed = false;

  @override
  void initState() {
    super.initState();
    final total = _resolveSplashTotalDuration(widget.duration);
    _ctrl = AnimationController(vsync: this, duration: total);

    _waveReveal = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.52, curve: Curves.easeOutCubic),
    );
    _titleOpacity = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.24, 0.72, curve: Curves.easeOutCubic),
    );
    _titleDy = Tween<double>(begin: 22, end: 0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.24, 0.72, curve: Curves.easeOutCubic),
      ),
    );
    _sloganOpacity = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.55, 0.92, curve: Curves.easeOut),
    );

    _ctrl.addStatusListener((s) {
      if (s != AnimationStatus.completed || _completed || !mounted) return;
      _completed = true;
      widget.onFinished();
    });

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final shortest = math.min(size.width, size.height);
    // Küçük ekranlarda okunabilir alt sınır; dar ekranda harf aralığını kısalt.
    final titleSize = (shortest * 0.14).clamp(22.0, 48.0);
    final sloganSize = (shortest * 0.038).clamp(11.0, 16.0);
    final titleLetterSpacing = math.min(1.8, shortest * 0.004);
    // Üst inset SafeArea ile; burada ek dikey boşluk (notch altında çift padding yok).
    final topGap = math.max(shortest * 0.05, size.height * 0.095);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF020814),
        body: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          final travel = (_ctrl.value * 6) % 1.0;
          final pulsePhase = (_ctrl.value * 2.2) % 1.0;
          final contourPhase = _ctrl.value * 0.5;

          return Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              CustomPaint(
                painter: SkyGradientPainter(),
                child: const SizedBox.expand(),
              ),
              RepaintBoundary(
                child: CustomPaint(
                  painter: ContourLinesPainter(phase: contourPhase),
                  child: const SizedBox.expand(),
                ),
              ),
              RepaintBoundary(
                child: CustomPaint(
                  painter: SonarPulsePainter(pulseT: pulsePhase),
                  child: const SizedBox.expand(),
                ),
              ),
              RepaintBoundary(
                child: CustomPaint(
                  painter: WaveRevealPainter(
                    revealProgress: _waveReveal.value,
                    waveTravel: travel,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
              IgnorePointer(
                child: SafeArea(
                  minimum: const EdgeInsets.symmetric(horizontal: 4),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: shortest * 0.05),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        SizedBox(height: topGap),
                        Opacity(
                          opacity: _titleOpacity.value,
                          child: Transform.translate(
                            offset: Offset(0, _titleDy.value),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: ShaderMask(
                                shaderCallback: (bounds) => LinearGradient(
                                  colors: [
                                    const Color(0xFFE0F7FF)
                                        .withValues(alpha: 0.98),
                                    const Color(0xFF4FC3F7)
                                        .withValues(alpha: 0.92),
                                    const Color(0xFF1565C0)
                                        .withValues(alpha: 0.95),
                                  ],
                                  stops: const [0, 0.45, 1],
                                ).createShader(bounds),
                                blendMode: BlendMode.srcIn,
                                child: Text(
                                  SplashBrand.appName,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.visible,
                                  style: TextStyle(
                                    fontSize: titleSize,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: titleLetterSpacing,
                                    height: 1.05,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: shortest * 0.024),
                        Opacity(
                          opacity: _sloganOpacity.value,
                          child: Text(
                            SplashBrand.slogan,
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.fade,
                            style: TextStyle(
                              fontSize: sloganSize,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withValues(alpha: 0.72),
                              letterSpacing: 0.35,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: shortest * 0.04 + MediaQuery.paddingOf(context).bottom,
                left: 0,
                right: 0,
                child: Center(
                  child: SizedBox(
                    width: math.min(size.width * 0.42, 220),
                    height: 3,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: _ctrl.value,
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          const Color(0xFF4DD0E1).withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      ),
    );
  }
}
