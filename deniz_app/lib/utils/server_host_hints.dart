import 'dart:io' show Platform;

import 'package:deniz_app/config/app_config.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:flutter/foundation.dart';

/// Mobil cihazda loopback adresleri backend geliştirme makinesine ulaşmaz.
String? loopbackWarningForMobile(String host) {
  if (kIsWeb) return null;
  final h = host.trim().toLowerCase();
  if (h.isEmpty) return null;
  if (!AppConfig.isLoopbackHost(h)) return null;
  if (Platform.isAndroid) {
    return kLocalhostMobileHintAndroid;
  }
  if (Platform.isIOS) {
    return kLocalhostMobileHintIos;
  }
  return null;
}
