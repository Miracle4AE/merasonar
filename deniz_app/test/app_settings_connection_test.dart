import 'package:deniz_app/config/app_config.dart';
import 'package:deniz_app/local_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalStorageService server port', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('save and load server port', () async {
      final storage = LocalStorageService();
      await storage.saveServerPort(9090);
      expect(await storage.loadServerPort(), 9090);
    });
  });

  group('AppConfig port', () {
    test('buildApiBaseUrl uses custom port', () {
      expect(
        AppConfig.buildApiBaseUrl('192.168.1.2', port: 9090),
        'http://192.168.1.2:9090',
      );
    });

    test('normalizePort clamps invalid', () {
      expect(AppConfig.normalizePort(null), AppConfig.defaultApiPort);
      expect(AppConfig.normalizePort(0), AppConfig.defaultApiPort);
      expect(AppConfig.normalizePort(70000), AppConfig.defaultApiPort);
      expect(AppConfig.normalizePort(3000), 3000);
    });
  });
}
