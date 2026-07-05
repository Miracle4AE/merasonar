import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../l10n/app_strings_tr.dart';
/// True for **physical / all** Android installs when target is loopback —
/// localhost never reaches a development machine on USB Wi‑Fi.
///
/// **`10.0.2.2`** is explicitly allowed — standard Android emulator routing to host.
bool shouldBlockAndroidLoopbackHost(String host) {
  if (kIsWeb || !Platform.isAndroid) return false;
  final h = host.trim().toLowerCase();
  if (h.isEmpty) return false;
  if (h == '10.0.2.2') return false;
  return h == 'localhost' || h == '127.0.0.1' || h == '::1';
}

String androidLoopbackHostBlockedExplanation() =>
    kAndroidLoopbackBlocked(
      '${AppConfig.defaultLanHostExample}:${AppConfig.defaultApiPort}',
      '${AppConfig.defaultEmulatorLanHost}:${AppConfig.defaultApiPort}',
    );