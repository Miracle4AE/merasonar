import 'dart:convert';

import 'package:deniz_app/domain/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AppSettings kalıcılık — SharedPreferences JSON blob.
class AppSettingsService {
  AppSettingsService({SharedPreferences? prefs}) : _prefs = prefs;

  SharedPreferences? _prefs;
  static const _kSettingsBlob = 'merasonar_app_settings_v1';

  Future<SharedPreferences> _ensurePrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<AppSettings> load() async {
    final p = await _ensurePrefs();
    final raw = p.getString(_kSettingsBlob);
    if (raw == null || raw.isEmpty) {
      return AppSettings.defaults;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return AppSettings.defaults;
      return AppSettings.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return AppSettings.defaults;
    }
  }

  Future<void> save(AppSettings settings) async {
    final p = await _ensurePrefs();
    await p.setString(_kSettingsBlob, jsonEncode(settings.toJson()));
  }

  Future<void> resetAll() async {
    final p = await _ensurePrefs();
    await p.remove(_kSettingsBlob);
  }
}
