import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'config/app_config.dart';
import 'domain/premium_performance_mode.dart';
import 'home_screen.dart';
import 'onboarding/onboarding_screen.dart';
import 'services/app_preferences.dart';
import 'services/app_settings_controller.dart';
import 'services/crash_reporter.dart';
import 'splash_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/premium/navigation/premium_ambient_shell.dart';
import 'widgets/premium/premium_performance_scope.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  installCrashReporting();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0xFF060B12),
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFF060B12),
      systemNavigationBarDividerColor: Color(0xFF060B12),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const DenizApp());
}

class DenizApp extends StatefulWidget {
  const DenizApp({
    super.key,
    this.splashDuration,
  });

  /// Widget testlerinde splash’i kısaltmak için; üretimde genelde `null`.
  final Duration? splashDuration;

  @override
  State<DenizApp> createState() => _DenizAppState();
}

class _DenizAppState extends State<DenizApp> {
  bool? _bootReady;
  bool _showOnboarding = true;
  bool _splashComplete = false;
  PremiumPerformanceMode _performanceMode = PremiumPerformanceMode.full;
  final AppSettingsController _settingsController = AppSettingsController();

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final results = await Future.wait([
      AppPreferences.isOnboardingComplete(),
      AppPreferences.getPerformanceMode(),
      _settingsController.load(),
    ]);
    if (!mounted) return;
    setState(() {
      _bootReady = true;
      _showOnboarding = !(results[0] as bool);
      _performanceMode = results[1] as PremiumPerformanceMode;
      _splashComplete = false;
    });
  }

  void _onPerformanceModeChanged(PremiumPerformanceMode mode) {
    if (!mounted) return;
    setState(() => _performanceMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF060B12),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Color(0xFF060B12),
        systemNavigationBarDividerColor: Color(0xFF060B12),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkMarine(),
        builder: (context, child) => AppSettingsScope(
          controller: _settingsController,
          child: PremiumPerformanceScope(
            mode: _performanceMode,
            onModeChanged: _onPerformanceModeChanged,
            child: PremiumAmbientShell(
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
        home: _bootReady != true
            ? const Scaffold(
                backgroundColor: Color(0xFF060B12),
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        color: Color(0xFF32D9FF),
                      ),
                      SizedBox(height: 16),
                      Text(
                        AppConfig.productName,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : !_splashComplete
                ? SplashScreen(
                    duration: widget.splashDuration,
                    onFinished: () {
                      if (mounted) {
                        setState(() => _splashComplete = true);
                      }
                    },
                  )
                : _showOnboarding
                    ? OnboardingScreen(
                        onFinished: () async {
                          if (mounted) {
                            setState(() => _showOnboarding = false);
                          }
                        },
                      )
                    : const HomeScreen(),
      ),
    );
  }
}
