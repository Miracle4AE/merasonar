import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Chart image picker preparation.
///
/// **Android**: No broad storage request here — [ImageSource.gallery] uses the platform
/// flow (often the **system Photo Picker** on Android 13+) which avoids unnecessary
/// `READ_EXTERNAL_STORAGE` / legacy broad access.
///
/// **iOS**: Requests photo-library access when needed.
///
/// Desktop: no-op (file dialog).
Future<PermissionResult> ensureChartImagePickerPrepared() async {
  if (kIsWeb) return PermissionResult.granted;
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    return PermissionResult.granted;
  }

  if (Platform.isAndroid) {
    return PermissionResult.granted;
  }

  if (Platform.isIOS) {
    final s = await Permission.photos.status;
    if (s.isLimited) return PermissionResult.granted;
    if (s.isGranted) return PermissionResult.granted;
    if (s.isPermanentlyDenied) return PermissionResult.permanentlyDenied;
    final r = await Permission.photos.request();
    if (r.isLimited || r.isGranted) return PermissionResult.granted;
    if (r.isPermanentlyDenied) return PermissionResult.permanentlyDenied;
    return PermissionResult.denied;
  }

  return PermissionResult.granted;
}

enum PermissionResult { granted, denied, permanentlyDenied }
