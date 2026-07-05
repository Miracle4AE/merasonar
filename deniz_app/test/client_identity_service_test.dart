import 'package:deniz_app/services/app_preferences.dart';
import 'package:deniz_app/services/client_identity_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ClientIdentityService', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('generates UUID on first call', () async {
      final service = ClientIdentityService();
      final identity = await service.getIdentity();
      expect(identity.deviceId.length, greaterThanOrEqualTo(32));
      expect(identity.userId, isNull);
      expect(identity.isPremium, isFalse);
      expect(identity.platform, isNotEmpty);
    });

    test('returns same UUID on second call', () async {
      final service = ClientIdentityService();
      final first = await service.getIdentity();
      final second = await service.getIdentity();
      expect(second.deviceId, first.deviceId);
    });

    test('reflects premium dev flag', () async {
      await AppPreferences.setIsPremiumDev(true);
      final service = ClientIdentityService();
      final identity = await service.getIdentity();
      expect(identity.isPremium, isTrue);
    });
  });
}
