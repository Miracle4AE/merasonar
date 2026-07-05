import 'dart:io' show Platform;
import 'dart:math';

import 'package:deniz_app/config/app_config.dart';
import 'package:deniz_app/domain/client_identity.dart';
import 'package:deniz_app/services/app_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

/// Cihaz kimliği üretir ve saklar — AI kota/premium altyapısı için.
class ClientIdentityService {
  ClientIdentityService();

  static const _deviceIdKey = 'merasonar_client_device_id';

  ClientIdentity? _cached;

  Future<ClientIdentity> getIdentity() async {
    if (_cached != null) return _cached!;

    final prefs = await SharedPreferences.getInstance();
    var deviceId = prefs.getString(_deviceIdKey)?.trim();
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = _generateUuidV4();
      await prefs.setString(_deviceIdKey, deviceId);
    }

    final isPremium = await AppPreferences.getIsPremiumDev();
    _cached = ClientIdentity(
      deviceId: deviceId,
      userId: null,
      appVersion: AppConfig.appVersion,
      platform: _detectPlatform(),
      isPremium: isPremium,
    );
    return _cached!;
  }

  /// Premium dev flag değişince kimlik önbelleğini yenile.
  Future<void> refreshPremiumFlag() async {
    _cached = null;
    await getIdentity();
  }

  static String _detectPlatform() {
    if (kIsWeb) return 'web';
    try {
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
      if (Platform.isWindows) return 'windows';
      if (Platform.isLinux) return 'linux';
      if (Platform.isMacOS) return 'macos';
    } catch (_) {
      return 'unknown';
    }
    return 'unknown';
  }

  static String _generateUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int n) => n.toRadixString(16).padLeft(2, '0');
    return '${hex(bytes[0])}${hex(bytes[1])}${hex(bytes[2])}${hex(bytes[3])}-'
        '${hex(bytes[4])}${hex(bytes[5])}-'
        '${hex(bytes[6])}${hex(bytes[7])}-'
        '${hex(bytes[8])}${hex(bytes[9])}-'
        '${hex(bytes[10])}${hex(bytes[11])}${hex(bytes[12])}${hex(bytes[13])}'
        '${hex(bytes[14])}${hex(bytes[15])}';
  }
}
