import 'package:deniz_app/domain/app_settings.dart';
import 'package:deniz_app/services/app_settings_controller.dart';
import 'package:deniz_app/services/app_settings_service.dart';
import 'package:flutter_test/flutter_test.dart';import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppSettingsService', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('load returns defaults when empty', () async {
      final svc = AppSettingsService();
      final settings = await svc.load();
      expect(settings.serverPort, AppSettings.defaults.serverPort);
      expect(settings.autoRefreshEnabled, isTrue);
      expect(settings.captainAtlasEnabled, isTrue);
    });

    test('save and load round-trip', () async {
      final svc = AppSettingsService();
      const custom = AppSettings(
        autoRefreshEnabled: false,
        minHotspotScore: 0.42,
        captainAtlasEnabled: false,
        coordinateFormat: CoordinateDisplayFormat.decimal,
      );
      await svc.save(custom);
      final loaded = await svc.load();
      expect(loaded.autoRefreshEnabled, isFalse);
      expect(loaded.minHotspotScore, 0.42);
      expect(loaded.captainAtlasEnabled, isFalse);
      expect(loaded.coordinateFormat, CoordinateDisplayFormat.decimal);
    });

    test('resetAll clears blob', () async {
      final svc = AppSettingsService();
      await svc.save(
        AppSettings.defaults.copyWith(compactView: true),
      );
      await svc.resetAll();
      final loaded = await svc.load();
      expect(loaded.compactView, isFalse);
    });

    test('corrupt JSON blob returns defaults', () async {
      SharedPreferences.setMockInitialValues({
        'merasonar_app_settings_v1': '{not-json',
      });
      final svc = AppSettingsService();
      final loaded = await svc.load();
      expect(loaded.autoRefreshEnabled, isTrue);
    });

    test('controller merges stored server port', () async {
      SharedPreferences.setMockInitialValues({'server_port': 9090});
      final controller = AppSettingsController();
      await controller.load();
      expect(controller.settings.serverPort, 9090);
    });
  });
  group('AutoRefreshInterval', () {
    test('duration mapping', () {
      expect(
        AutoRefreshInterval.fiveMinutes.duration,
        const Duration(minutes: 5),
      );
    });
  });
}
