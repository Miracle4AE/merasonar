import 'dart:convert';

import 'package:deniz_app/local_storage_service.dart';
import 'package:deniz_app/services/backend_discovery_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('validateHealthResponse', () {
    test('geçerli MeraSonar yanıtı kabul edilir', () {
      expect(
        validateHealthResponse(
          jsonEncode(
            const <String, dynamic>{
              'status': 'ok',
              'service': 'MeraSonar API',
              'version': '1.0.0',
            },
          ),
        ),
        isTrue,
      );
    });

    test('servis adı uyumsuzsa reddedilir', () {
      expect(
        validateHealthResponse(
          jsonEncode(
            const <String, dynamic>{
              'status': 'ok',
              'service': 'Other',
              'version': '1.0.0',
            },
          ),
        ),
        isFalse,
      );
    });

    test('yalnızca 200 / eski gövde yeterli değildir', () {
      expect(
        validateHealthResponse(
          '{"status":"online"}',
        ),
        isFalse,
      );
    });
  });

  group('orderedShortcutHostsForTest', () {
    test('fiziksel Android masaüstü değil — localhost shortcut yok', () {
      final h = orderedShortcutHostsForTest(
        desktop: false,
        androidEmulatorHost: false,
      );
      expect(h.any((x) => x == '127.0.0.1' || x == 'localhost'), isFalse);
    });

    test('masaüstünde localhost kısayolları eklenir', () {
      final h = orderedShortcutHostsForTest(
        desktop: true,
        androidEmulatorHost: false,
      );
      expect(h.contains('127.0.0.1'), isTrue);
      expect(h.contains('localhost'), isTrue);
    });
  });

  group('BackendDiscoveryService', () {
    test('kayıtlı sunucu sağlıklıysa aynı adres döner', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = LocalStorageService();
      await storage.saveServerIp('203.0.113.77');

      final client = MockClient((request) async {
        if (request.url.host != '203.0.113.77') {
          return http.Response('err', 500);
        }
        return http.Response(
          '{"status":"ok","service":"MeraSonar API","version":"1.0.0"}',
          200,
        );
      });

      final svc = BackendDiscoveryService(
        httpClient: client,
        ownsClient: false,
        overallBudget: const Duration(seconds: 2),
      );
      expect(await svc.checkSavedServer(storage), '203.0.113.77');
      svc.close();
    });

    test('sıkı bütçe ve boş LAN — keşif null döner', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = LocalStorageService();

      final client = MockClient(
        (request) async => http.Response('err', 503),
      );
      final svc = BackendDiscoveryService(
        httpClient: client,
        ownsClient: false,
        flutterDesktopOverride: true,
        androidEmulatorOverride: false,
        subnetPrefixOverride: () async => <List<String>>[],
        overallBudget: const Duration(milliseconds: 120),
        probeTimeout: const Duration(milliseconds: 20),
      );
      final o = await svc.discoverBackend(
        storage: storage,
        scanEvenIfSavedWorks: false,
      );
      expect(o.persistHost, isNull);
      svc.close();
    });
  });
}
