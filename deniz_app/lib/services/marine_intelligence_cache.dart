import 'dart:convert';

import 'package:deniz_app/domain/marine_compare.dart';
import 'package:deniz_app/domain/marine_intelligence_report.dart';
import 'package:deniz_app/domain/marine_saved_spot.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Marine Intelligence yerel önbellek — SharedPreferences.
class MarineIntelligenceCache {
  MarineIntelligenceCache();

  static const _kLastReport = 'marine_intel_last_report_v1';
  static const _kLastReportAt = 'marine_intel_last_report_at_v1';
  static const _kSavedSpots = 'marine_intel_saved_spots_v1';
  static const _kSpotsSyncedAt = 'marine_intel_spots_synced_at_v1';
  static const _kLastLiveScore = 'dashboard_last_live_score_v1';
  static const _kLastCompare = 'dashboard_last_compare_v1';
  static const _kRecentCatches = 'dashboard_recent_catches_v1';

  Future<void> saveLastReport(MarineIntelligenceReport report) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kLastReport, jsonEncode(report.toJson()));
    await p.setString(_kLastReportAt, report.updatedAt);
  }

  Future<MarineIntelligenceReport?> loadLastReport() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kLastReport);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return MarineIntelligenceReport.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<String?> lastReportSyncedAt() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kLastReportAt);
  }

  Future<void> saveSavedSpots(List<MarineSavedSpot> spots) async {
    final p = await SharedPreferences.getInstance();
    final encoded = spots.map((s) => s.toJson()).toList(growable: false);
    await p.setString(_kSavedSpots, jsonEncode(encoded));
    await p.setString(
      _kSpotsSyncedAt,
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  Future<List<MarineSavedSpot>> loadSavedSpots() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kSavedSpots);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map>()
          .map((e) => MarineSavedSpot.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<String?> savedSpotsSyncedAt() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kSpotsSyncedAt);
  }

  Future<void> saveLastLiveScore({
    required int liveScore,
    required String rating,
    String reasoning = '',
    String trustNote = '',
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _kLastLiveScore,
      jsonEncode({
        'live_score': liveScore,
        'rating': rating,
        'reasoning': reasoning,
        'trust_note': trustNote,
        'saved_at': DateTime.now().toUtc().toIso8601String(),
      }),
    );
  }

  Future<Map<String, dynamic>?> loadLastLiveScore() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kLastLiveScore);
    if (raw == null || raw.isEmpty) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveLastCompare(MarineCompareResponse response) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kLastCompare, jsonEncode(response.toJson()));
  }

  Future<MarineCompareResponse?> loadLastCompare() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kLastCompare);
    if (raw == null || raw.isEmpty) return null;
    try {
      return MarineCompareResponse.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveRecentCatchSummaries(
    List<Map<String, dynamic>> entries,
  ) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kRecentCatches, jsonEncode(entries));
  }

  Future<List<Map<String, dynamic>>> loadRecentCatchSummaries() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kRecentCatches);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kLastReport);
    await p.remove(_kLastReportAt);
    await p.remove(_kSavedSpots);
    await p.remove(_kSpotsSyncedAt);
    await p.remove(_kLastLiveScore);
    await p.remove(_kLastCompare);
    await p.remove(_kRecentCatches);
  }
}
