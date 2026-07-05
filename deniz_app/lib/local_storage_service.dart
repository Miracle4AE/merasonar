import 'dart:convert';
import 'dart:developer' show log;
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

class LocalStorageService {
  static const String _latestFishingZoneKey = 'latest_fishing_zone_response';
  static const String _latestFishingZoneChartPathKey =
      'latest_fishing_zone_chart_image_path';
  static const String _analysisHistoryKey = 'analysis_history';
  static const String _calibrationProfilesKey = 'calibration_profiles';
  static const String _serverIpKey = 'server_ip';
  static const int _maxHistoryEntries = 12;
  static const int _maxCalibrationProfiles = 8;

  Future<void> saveLatestFishingZoneResponse(
    FishingZoneResponse response, {
    String? chartImagePath,
    int controlPointCount = 0,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(response.toJson());
    await prefs.setString(_latestFishingZoneKey, encoded);

    final trimmedPath = (chartImagePath ?? '').trim();
    await prefs.setString(_latestFishingZoneChartPathKey, trimmedPath);
    final pathExists =
        trimmedPath.isNotEmpty && File(trimmedPath).existsSync();
    log(
      'saveLatestFishingZoneResponse: chartImagePath=$trimmedPath fileExists=$pathExists',
      name: 'LocalStorageService',
    );

    final history = await loadAnalysisHistory();
    final now = DateTime.now();
    final updated = <AnalysisHistoryEntry>[
      AnalysisHistoryEntry(
        id: now.toIso8601String(),
        savedAt: now,
        response: response,
        chartImageLabel: _basename(chartImagePath),
        chartImagePath: chartImagePath,
        controlPointCount: controlPointCount,
        isFavorite: false,
      ),
      ...history,
    ];
    final trimmed = updated.take(_maxHistoryEntries).toList(growable: false);
    await _persistAnalysisHistory(trimmed);
  }

  Future<FishingZoneResponse?> loadLatestFishingZoneResponse() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_latestFishingZoneKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return FishingZoneResponse.fromJson(decoded);
    } catch (e, st) {
      log(
        'loadLatestFishingZoneResponse: JSON parse failed: $e',
        name: 'LocalStorageService',
        stackTrace: st,
      );
      return null;
    }
  }

  /// Son başarılı analizle birlikte kaydedilen harita dosyası yolu (uygulama belgeleri altında).
  Future<String?> loadLatestFishingZoneChartPath() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_latestFishingZoneChartPathKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    return raw.trim();
  }

  /// Diskte dosyası hâlâ var olan en yeni geçmiş kaydı (tercihen kayıtlı son analiz yolu silinmişse).
  Future<AnalysisHistoryEntry?> newestHistoryEntryWithExistingChart() async {
    final history = await loadAnalysisHistory();
    AnalysisHistoryEntry? newest;
    for (final e in history) {
      final p = e.chartImagePath?.trim();
      if (p == null || p.isEmpty) continue;
      if (!File(p).existsSync()) continue;
      if (newest == null || e.savedAt.isAfter(newest.savedAt)) {
        newest = e;
      }
    }
    return newest;
  }

  Future<String?> newestExistingChartPathFromHistory() async =>
      (await newestHistoryEntryWithExistingChart())?.chartImagePath?.trim();

  Future<List<AnalysisHistoryEntry>> loadAnalysisHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_analysisHistoryKey);
    if (raw == null || raw.isEmpty) {
      return const <AnalysisHistoryEntry>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <AnalysisHistoryEntry>[];
      }
      return decoded
          .map(_asHistoryMap)
          .whereType<Map<String, dynamic>>()
          .map(AnalysisHistoryEntry.fromJson)
          .toList(growable: false)
        ..sort((a, b) {
          if (a.isFavorite != b.isFavorite) {
            return a.isFavorite ? -1 : 1;
          }
          return b.savedAt.compareTo(a.savedAt);
        });
    } catch (_) {
      return const <AnalysisHistoryEntry>[];
    }
  }

  Future<void> toggleAnalysisHistoryFavorite(String entryId) async {
    final history = await loadAnalysisHistory();
    final updated =
        history
            .map(
              (entry) => entry.id == entryId
                  ? entry.copyWith(isFavorite: !entry.isFavorite)
                  : entry,
            )
            .toList(growable: false);
    await _persistAnalysisHistory(updated);
  }

  Future<void> deleteAnalysisHistoryEntry(String entryId) async {
    final history = await loadAnalysisHistory();
    final updated =
        history.where((entry) => entry.id != entryId).toList(growable: false);
    await _persistAnalysisHistory(updated);
  }

  Future<void> saveServerIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverIpKey, ip);
  }

  Future<String?> loadServerIp() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_serverIpKey);
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  Future<List<ChartCalibrationProfile>> loadCalibrationProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_calibrationProfilesKey);
    if (raw == null || raw.isEmpty) {
      return const <ChartCalibrationProfile>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <ChartCalibrationProfile>[];
      }
      return decoded
          .map(_asHistoryMap)
          .whereType<Map<String, dynamic>>()
          .map(ChartCalibrationProfile.fromJson)
          .toList(growable: false)
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (_) {
      return const <ChartCalibrationProfile>[];
    }
  }

  /// Yeni veya aynı [id] ile günceller; en fazla [_maxCalibrationProfiles] kayıt.
  Future<void> upsertCalibrationProfile(ChartCalibrationProfile profile) async {
    final list = await loadCalibrationProfiles();
    final others = list.where((p) => p.id != profile.id).toList(growable: false);
    final merged = <ChartCalibrationProfile>[profile, ...others]
        .take(_maxCalibrationProfiles)
        .toList(growable: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _calibrationProfilesKey,
      jsonEncode(merged.map((e) => e.toJson()).toList(growable: false)),
    );
  }

  Future<void> deleteCalibrationProfile(String id) async {
    final list = await loadCalibrationProfiles();
    final next = list.where((p) => p.id != id).toList(growable: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _calibrationProfilesKey,
      jsonEncode(next.map((e) => e.toJson()).toList(growable: false)),
    );
  }

  Map<String, dynamic>? _asHistoryMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      try {
        return Map<String, dynamic>.from(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<void> _persistAnalysisHistory(List<AnalysisHistoryEntry> history) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _analysisHistoryKey,
      jsonEncode(history.map((e) => e.toJson()).toList(growable: false)),
    );
  }

  String? _basename(String? path) {
    if (path == null || path.trim().isEmpty) {
      return null;
    }
    final normalized = path.replaceAll('\\', '/');
    final segments = normalized.split('/');
    return segments.isEmpty ? null : segments.last;
  }
}
