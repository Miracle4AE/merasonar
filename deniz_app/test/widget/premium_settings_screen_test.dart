import 'package:deniz_app/domain/app_settings.dart';
import 'package:deniz_app/domain/premium_performance_mode.dart';
import 'package:deniz_app/screens/premium_settings_screen.dart';
import 'package:deniz_app/services/app_settings_controller.dart';
import 'package:deniz_app/services/app_settings_service.dart';
import 'package:deniz_app/theme/app_theme.dart';
import 'package:deniz_app/widgets/premium/premium_performance_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  Widget wrap(Widget child, AppSettingsController controller) {
    return MaterialApp(
      theme: AppTheme.darkMarine(),
      home: AppSettingsScope(
        controller: controller,
        child: PremiumPerformanceScope(
          mode: PremiumPerformanceMode.full,
          onModeChanged: (_) {},
          child: child,
        ),
      ),
    );
  }

  testWidgets('premium settings screen renders sections', (tester) async {
    final controller = AppSettingsController(
      service: AppSettingsService(),
    );
    await controller.load();

    await tester.pumpWidget(
      wrap(
        PremiumSettingsScreen(
          serverHost: '127.0.0.1',
          onSaveConnection: (host, port) async {},
          onAutoDiscover: () async {},
        ),
        controller,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ayarlar'), findsOneWidget);
    expect(find.text('Bağlantı'), findsWidgets);
    expect(find.text('Kaydet'), findsOneWidget);
  });

  test('auto refresh toggle persists through controller', () async {
    final service = AppSettingsService();
    final controller = AppSettingsController(service: service);
    await controller.load();
    expect(controller.settings.autoRefreshEnabled, isTrue);

    await controller.update(
      controller.settings.copyWith(autoRefreshEnabled: false),
    );

    final reloaded = AppSettingsController(service: service);
    await reloaded.load();
    expect(reloaded.settings.autoRefreshEnabled, isFalse);
  });

  testWidgets('connection test updates status badge', (tester) async {
    final controller = AppSettingsController(
      service: AppSettingsService(),
    );
    await controller.load();

    await tester.pumpWidget(
      wrap(
        PremiumSettingsScreen(
          serverHost: '127.0.0.1',
          onSaveConnection: (host, port) async {},
          onAutoDiscover: () async {},
        ),
        controller,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings_connection_status_badge')), findsOneWidget);
    expect(find.text('Bağlantıyı test et'), findsOneWidget);
  });

  testWidgets('reset all restores defaults', (tester) async {
    final service = AppSettingsService();
    final controller = AppSettingsController(service: service);
    await controller.load();
    await controller.update(
      AppSettings.defaults.copyWith(compactView: true, reduceMotion: true),
    );

    await controller.resetAllSettings();
    expect(controller.settings.compactView, isFalse);
    expect(controller.settings.reduceMotion, isFalse);
  });
}
