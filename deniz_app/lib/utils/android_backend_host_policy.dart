import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../l10n/app_strings_tr.dart';
/// True for **physical / all** Android installs when target is loopback —
/// loopback never reaches a development machine on USB Wi‑Fi.
///
/// Emulator host is explicitly allowed — standard Android emulator routing to host.
bool shouldBlockAndroidLoopbackHost(String host) {
  if (kIsWeb || !Platform.isAndroid) return false;
  final h = host.trim().toLowerCase();
  if (h.isEmpty) return false;
  if (h == AppConfig.defaultEmulatorLanHost) return false;
  return AppConfig.isLoopbackHost(h);
}

String androidLoopbackHostBlockedExplanation() =>
    kAndroidLoopbackBlocked(
      '${AppConfig.defaultLanHostExample}:${AppConfig.defaultApiPort}',
      '${AppConfig.defaultEmulatorLanHost}:${AppConfig.defaultApiPort}',
    );