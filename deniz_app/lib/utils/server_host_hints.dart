import 'dart:io' show Platform;

import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:flutter/foundation.dart';

/// Mobil cihazda `localhost` / `127.0.0.1` klasörüdür — backend genelde görünmez.
String? localhostWarningForMobile(String host) {
  if (kIsWeb) return null;
  final h = host.trim().toLowerCase();
  if (h.isEmpty) return null;
  if (h != 'localhost' && h != '127.0.0.1' && h != '::1') return null;
  if (Platform.isAndroid) {
    return kLocalhostMobileHintAndroid;
  }
  if (Platform.isIOS) {
    return kLocalhostMobileHintIos;
  }
  return null;
}
