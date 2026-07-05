import 'package:deniz_app/domain/client_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ClientIdentity.toJson', () {
    test('includes core fields with snake_case keys', () {
      const identity = ClientIdentity(
        deviceId: 'dev-123',
        userId: 'user-9',
        appVersion: '1.0.0',
        platform: 'windows',
        isPremium: true,
      );
      final json = identity.toJson();
      expect(json['device_id'], 'dev-123');
      expect(json['user_id'], 'user-9');
      expect(json['app_version'], '1.0.0');
      expect(json['platform'], 'windows');
      expect(json['is_premium'], isTrue);
    });

    test('omits null userId', () {
      const identity = ClientIdentity(
        deviceId: 'dev-123',
        platform: 'android',
      );
      final json = identity.toJson();
      expect(json.containsKey('user_id'), isFalse);
      expect(json['is_premium'], isFalse);
    });
  });
}
