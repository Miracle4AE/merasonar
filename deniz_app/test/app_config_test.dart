import 'package:deniz_app/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buildApiBaseUrl host ve port birleştirir', () {
    expect(
      AppConfig.buildApiBaseUrl('192.168.1.5'),
      'http://192.168.1.5:${AppConfig.defaultApiPort}',
    );
    expect(
      AppConfig.buildApiBaseUrl('192.168.1.5', port: 9090),
      'http://192.168.1.5:9090',
    );
    expect(
      AppConfig.buildApiBaseUrl(''),
      AppConfig.productionApiBaseUrl,
    );
  });

  test('production default API base URL VPS adresidir', () {
    expect(AppConfig.defaultApiHost, AppConfig.productionApiHost);
    expect(
      AppConfig.defaultApiBaseUrl,
      'http://187.124.183.138:${AppConfig.defaultApiPort}',
    );
  });
}
