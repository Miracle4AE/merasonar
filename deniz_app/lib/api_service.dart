import 'dart:async';
import 'dart:convert';
import 'dart:developer' show log;
import 'dart:io';

import 'package:deniz_app/domain/marine_catch_record.dart';
import 'package:deniz_app/domain/marine_compare.dart';
import 'package:deniz_app/domain/marine_intelligence_report.dart';
import 'package:deniz_app/domain/marine_learning_summary.dart';
import 'package:deniz_app/domain/marine_saved_spot.dart';
import 'package:deniz_app/domain/ai_assistant_request.dart';
import 'package:deniz_app/domain/ai_assistant_response.dart';
import 'package:deniz_app/domain/client_identity.dart';
import 'package:deniz_app/domain/fishing_zone_ai_payload.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/utils/log_sanitize.dart';
import 'package:deniz_app/utils/performance_trace.dart';
import 'package:http/http.dart' as http;

import 'services/health_response_details.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final ApiErrorType type;

  ApiException(
    this.message, {
    this.statusCode,
    this.type = ApiErrorType.unknown,
  });

  /// Arayüzde gösterilir; teknik bilgi için [log]'a yazın.
  @override
  String toString() => message;
}

enum ApiErrorType {
  serverUnreachable,
  timeout,
  invalidAddressOrPort,
  backendUnavailable,
  networkUnavailable,
  invalidResponse,
  unknown,
}

/// Values aligned with backend ``coordinate_mode`` /[/api/v1/live_fishing_score].
const String kCoordinateModeImageSpace = 'image_space';
const String kCoordinateModeGeoReferenced = 'geo_referenced';
/// No control points, but bounds + boat anchor allow approximate boat-referenced estimates.
const String kCoordinateModeBoatAnchorEstimated = 'boat_anchor_estimated';

/// Cache or client could not determine chart ↔ world alignment — safe (no distance math).
const String kCoordinateModeUnknown = 'unknown';

/// Eski sunucular için dünya haritası geo eşikleri (`maritime_orchestrator`).
const double kGeoWorldMapMinTransformQuality = 0.28;
const double kGeoWorldMapMaxGeorefErrorM = 42.0;

String _canonicalStoredCoordinateMode(String raw) {
  final s = raw.trim().toLowerCase();
  if (s.isEmpty) return kCoordinateModeUnknown;
  if (s == kCoordinateModeImageSpace) return kCoordinateModeImageSpace;
  if (s == kCoordinateModeGeoReferenced) return kCoordinateModeGeoReferenced;
  if (s == kCoordinateModeBoatAnchorEstimated) return kCoordinateModeBoatAnchorEstimated;
  if (s == kCoordinateModeUnknown) return kCoordinateModeUnknown;
  if (s == 'calibrated') return kCoordinateModeGeoReferenced;
  return kCoordinateModeUnknown;
}

/// Mode for Live Area UI and [ApiService.fetchLiveFishingScore].
///
/// If [cached] omits persisted [coordinate_mode], returns [kCoordinateModeUnknown],
/// unless every hotspot carries unambiguous ``image_space`` mapping (legacy payloads).
///
/// Anything ambiguous without an explicit geo tag stays [kCoordinateModeUnknown] so the
/// server never computes hotspot distance without calibrated chart alignment.
String liveAreaCoordinateModeFromCache(FishingZoneResponse? cached) {
  if (cached == null) return kCoordinateModeUnknown;
  final cm = cached.coordinateMode?.trim();
  if (cm != null && cm.isNotEmpty) {
    return _canonicalStoredCoordinateMode(cm);
  }
  if (cached.hotspots.isEmpty) return kCoordinateModeUnknown;
  if (cached.hotspots.every((e) => e.mappingTrust == 'image_space')) {
    return kCoordinateModeImageSpace;
  }
  return kCoordinateModeUnknown;
}

class HealthCheckResult {
  const HealthCheckResult({
    required this.ok,
    required this.message,
    this.receivedNonMerasonarResponse = false,
    this.latencyMs,
    this.serviceVersion,
    this.serviceName,
  });

  final bool ok;
  final String message;
  /// HTTP 200 alındı ancak /health gövdesi MeraSonar şemasında değil (genelde port 8000 başka süreç).
  final bool receivedNonMerasonarResponse;
  final int? latencyMs;
  final String? serviceVersion;
  final String? serviceName;
}

class ApiService {
  ApiService({required this.serverBaseUrl, http.Client? client})
    : _client = client ?? http.Client();

  final String serverBaseUrl;
  final http.Client _client;

  Future<HealthCheckResult> checkHealth() async {
    final uri = Uri.parse('$serverBaseUrl/health');
    final started = DateTime.now();
    try {
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 6));
      final latencyMs =
          DateTime.now().difference(started).inMilliseconds;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final details = HealthResponseDetails.fromBody(response.body);
        if (!details.valid) {
          log(
            'health mismatch body=${truncateLogBody(response.body)}',
            name: 'ApiService',
          );
          return HealthCheckResult(
            ok: false,
            message: 'Sunucu MeraSonar API doğrulanamadı.',
            receivedNonMerasonarResponse: true,
            latencyMs: latencyMs,
          );
        }
        return HealthCheckResult(
          ok: true,
          message: 'Sunucu erişilebilir.',
          latencyMs: latencyMs,
          serviceVersion: details.version,
          serviceName: details.service,
        );
      }
      log(
        'health unexpected status=${response.statusCode} body=${truncateLogBody(response.body)}',
        name: 'ApiService',
      );
      return HealthCheckResult(
        ok: false,
        message: 'Sunucu beklenenden farklı yanıt verdi.',
        latencyMs: latencyMs,
      );
    } on TimeoutException {
      return HealthCheckResult(
        ok: false,
        message: kMsgSunucuyaUlasilamiyor,
        latencyMs: DateTime.now().difference(started).inMilliseconds,
      );
    } on SocketException catch (e) {
      return HealthCheckResult(
        ok: false,
        message: _socketMessage(e),
        latencyMs: DateTime.now().difference(started).inMilliseconds,
      );
    } catch (e, st) {
      log('health failed: $e', name: 'ApiService', stackTrace: st);
      return HealthCheckResult(
        ok: false,
        message: kMsgSunucuyaUlasilamiyor,
        latencyMs: DateTime.now().difference(started).inMilliseconds,
      );
    }
  }

  Future<FishingZoneResponse> analyzeFishingZone({
    required double currentLat,
    required double currentLon,
    required ImageGeoBounds bounds,
    required File chartImageFile,
    bool enrichData = true,
  }) async {
    final uri = Uri.parse('$serverBaseUrl/api/v1/analyze_fishing_zone');
    final request = http.MultipartRequest('POST', uri);

    request.fields['current_lat'] = currentLat.toStringAsFixed(6);
    request.fields['current_lon'] = currentLon.toStringAsFixed(6);
    request.fields['image_geo_bounds'] = jsonEncode(
      bounds.ensureCornersForAnalysis().toJson(),
    );
    request.fields['enrich_data'] = enrichData.toString();

    if (!chartImageFile.existsSync()) {
      throw ApiException(
        'Seçilen harita görseli bulunamadı.',
        type: ApiErrorType.invalidResponse,
      );
    }
    request.files.add(
      await http.MultipartFile.fromPath('chart_image', chartImageFile.path),
    );

    http.StreamedResponse streamed;
    try {
      streamed = await _client
          .send(request)
          .timeout(const Duration(seconds: 120));
    } on TimeoutException {
      throw ApiException(
        kMsgAnalysisTimeout,
        type: ApiErrorType.timeout,
      );
    } on SocketException catch (e) {
      throw ApiException(_socketMessage(e), type: _socketType(e));
    } catch (e, st) {
      log('analyze_fishing_zone send failed: $e', name: 'ApiService', stackTrace: st);
      throw ApiException(kMsgSunucuyaUlasilamiyor, type: ApiErrorType.unknown);
    }

    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      log(
        'analyze_fishing_zone HTTP ${response.statusCode} ${response.body}',
        name: 'ApiService',
      );
      final type = response.statusCode >= 500
          ? ApiErrorType.backendUnavailable
          : ApiErrorType.invalidResponse;
      throw ApiException(
        _analyzeHttpFailureMessage(response.statusCode, response.body),
        statusCode: response.statusCode,
        type: type,
      );
    }

    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final parsed = FishingZoneResponse.fromJson(data);
      return FishingZoneResponse.withEnsuredCoordinateMode(
        parsed,
        fallbackCoordinateModeHint: bounds.coordinateModeHint,
      );
    } catch (e, st) {
      log('analyze_fishing_zone parse failed: $e', name: 'ApiService', stackTrace: st);
      throw ApiException(
        'Geçersiz yanıt alındı.',
        type: ApiErrorType.invalidResponse,
      );
    }
  }

  Future<LiveFishingScoreResponse> fetchLiveFishingScore({
    required double currentLat,
    required double currentLon,
    double? gpsAccuracyM,
    List<Map<String, dynamic>>? latestHotspots,
    String? coordinateMode,
  }) async {
    final uri = Uri.parse('$serverBaseUrl/api/v1/live_fishing_score');
    final payload = <String, dynamic>{
      'current_lat': currentLat,
      'current_lon': currentLon,
      'coordinate_mode': coordinateMode ?? kCoordinateModeUnknown,
    };
    if (gpsAccuracyM != null) {
      payload['gps_accuracy_m'] = gpsAccuracyM;
    }
    if (latestHotspots != null) {
      payload['latest_hotspots'] = latestHotspots;
    }
    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        log(
          'live_fishing_score HTTP ${response.statusCode} ${response.body}',
          name: 'ApiService',
        );
        final msg = response.statusCode == 404
            ? kMsgLiveScoreEndpointMissing
            : kMsgSunucuyaUlasilamiyor;
        throw ApiException(
          msg,
          statusCode: response.statusCode,
          type: response.statusCode >= 500
              ? ApiErrorType.backendUnavailable
              : ApiErrorType.invalidAddressOrPort,
        );
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return LiveFishingScoreResponse.fromJson(data);
    } on TimeoutException {
      throw ApiException(
        kMsgSunucuyaUlasilamiyor,
        type: ApiErrorType.timeout,
      );
    } on SocketException catch (e) {
      throw ApiException(_socketMessage(e), type: _socketType(e));
    } catch (e, st) {
      if (e is ApiException) rethrow;
      log('live_fishing_score unexpected: $e', name: 'ApiService', stackTrace: st);
      throw ApiException(kMsgSunucuyaUlasilamiyor, type: ApiErrorType.unknown);
    }
  }

  /// POST /api/v1/marine_intelligence/coordinate
  Future<MarineIntelligenceReport> fetchMarineCoordinateReport({
    required double lat,
    required double lon,
    bool includeAiComment = false,
    bool forceRefresh = false,
  }) {
    return PerformanceTrace.measureAsync('marine_coordinate_report', () async {
    final uri = Uri.parse('$serverBaseUrl/api/v1/marine_intelligence/coordinate');
    final payload = {
      'lat': lat,
      'lon': lon,
      'include_ai_comment': includeAiComment,
      'force_refresh': forceRefresh,
    };
    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          kMsgMarineReportFailed,
          statusCode: response.statusCode,
          type: response.statusCode >= 500
              ? ApiErrorType.backendUnavailable
              : ApiErrorType.invalidResponse,
        );
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return MarineIntelligenceReport.fromJson(data);
    } on TimeoutException {
      throw ApiException(kMsgMarineReportTimeout, type: ApiErrorType.timeout);
    } on SocketException catch (e) {
      throw ApiException(_socketMessage(e), type: _socketType(e));
    } catch (e, st) {
      if (e is ApiException) rethrow;
      log('marine_coordinate unexpected: $e', name: 'ApiService', stackTrace: st);
      throw ApiException(kMsgSunucuyaUlasilamiyor, type: ApiErrorType.unknown);
    }
    });
  }

  /// POST /api/v1/marine_intelligence/compare
  Future<MarineCompareResponse> fetchMarineCompare({
    required MarineCompareSide left,
    required MarineCompareSide right,
    bool includeAiComment = false,
    bool forceRefresh = false,
  }) async {
    final uri = Uri.parse('$serverBaseUrl/api/v1/marine_intelligence/compare');
    final payload = {
      'left': left.toJson(),
      'right': right.toJson(),
      'include_ai_comment': includeAiComment,
      'force_refresh': forceRefresh,
    };
    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 45));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          kMsgMarineCompareFailed,
          statusCode: response.statusCode,
          type: response.statusCode >= 500
              ? ApiErrorType.backendUnavailable
              : ApiErrorType.invalidResponse,
        );
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return MarineCompareResponse.fromJson(data);
    } on TimeoutException {
      throw ApiException(kMsgMarineCompareTimeout, type: ApiErrorType.timeout);
    } on SocketException catch (e) {
      throw ApiException(_socketMessage(e), type: _socketType(e));
    } catch (e, st) {
      if (e is ApiException) rethrow;
      log('marine_compare unexpected: $e', name: 'ApiService', stackTrace: st);
      throw ApiException(kMsgSunucuyaUlasilamiyor, type: ApiErrorType.unknown);
    }
  }

  /// POST /api/v1/marine_intelligence/saved_spots
  Future<MarineSavedSpot> createMarineSavedSpot({
    required String name,
    required double lat,
    required double lon,
    String? note,
    bool favorite = false,
    List<String> personalTags = const [],
  }) async {
    final uri = Uri.parse('$serverBaseUrl/api/v1/marine_intelligence/saved_spots');
    final payload = {
      'name': name,
      'lat': lat,
      'lon': lon,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      'favorite': favorite,
      'personal_tags': personalTags,
    };
    return _marineSpotMutation(
      uri: uri,
      method: 'POST',
      body: payload,
      parser: (m) => MarineSavedSpot.fromJson(m),
    );
  }

  /// GET /api/v1/marine_intelligence/saved_spots
  Future<MarineSavedSpotListResponse> fetchMarineSavedSpots({bool? favorite}) async {
    final query = favorite == null ? '' : '?favorite=$favorite';
    final uri = Uri.parse(
      '$serverBaseUrl/api/v1/marine_intelligence/saved_spots$query',
    );
    try {
      final response = await _client.get(uri).timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          kMsgMarineSpotsLoadFailed,
          statusCode: response.statusCode,
          type: ApiErrorType.invalidResponse,
        );
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return MarineSavedSpotListResponse.fromJson(data);
    } on TimeoutException {
      throw ApiException(kMsgMarineReportTimeout, type: ApiErrorType.timeout);
    } on SocketException catch (e) {
      throw ApiException(_socketMessage(e), type: _socketType(e));
    } catch (e, st) {
      if (e is ApiException) rethrow;
      log('marine_saved_spots list: $e', name: 'ApiService', stackTrace: st);
      throw ApiException(kMsgSunucuyaUlasilamiyor, type: ApiErrorType.unknown);
    }
  }

  /// PATCH /api/v1/marine_intelligence/saved_spots/{id}
  Future<MarineSavedSpot> updateMarineSavedSpot(
    String id, {
    String? name,
    String? note,
    bool? favorite,
    List<String>? personalTags,
  }) async {
    final uri = Uri.parse(
      '$serverBaseUrl/api/v1/marine_intelligence/saved_spots/$id',
    );
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (note != null) payload['note'] = note;
    if (favorite != null) payload['favorite'] = favorite;
    if (personalTags != null) payload['personal_tags'] = personalTags;
    return _marineSpotMutation(
      uri: uri,
      method: 'PATCH',
      body: payload,
      parser: (m) => MarineSavedSpot.fromJson(m),
    );
  }

  /// DELETE /api/v1/marine_intelligence/saved_spots/{id}
  Future<MarineSpotDeleteResponse> deleteMarineSavedSpot(String id) async {
    final uri = Uri.parse(
      '$serverBaseUrl/api/v1/marine_intelligence/saved_spots/$id',
    );
    try {
      final response = await _client.delete(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode == 404) {
        throw ApiException(kMsgMarineSpotNotFound, type: ApiErrorType.invalidResponse);
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          kMsgMarineSpotDeleteFailed,
          statusCode: response.statusCode,
          type: ApiErrorType.invalidResponse,
        );
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return MarineSpotDeleteResponse.fromJson(data);
    } on TimeoutException {
      throw ApiException(kMsgMarineReportTimeout, type: ApiErrorType.timeout);
    } on SocketException catch (e) {
      throw ApiException(_socketMessage(e), type: _socketType(e));
    } catch (e, st) {
      if (e is ApiException) rethrow;
      log('marine_saved_spots delete: $e', name: 'ApiService', stackTrace: st);
      throw ApiException(kMsgSunucuyaUlasilamiyor, type: ApiErrorType.unknown);
    }
  }

  /// POST /api/v1/marine_intelligence/saved_spots/{id}/refresh
  Future<MarineSpotRefreshResponse> refreshMarineSavedSpot(
    String id, {
    bool forceRefresh = false,
    bool includeAiComment = false,
  }) async {
    final uri = Uri.parse(
      '$serverBaseUrl/api/v1/marine_intelligence/saved_spots/$id/refresh',
    );
    final payload = {
      'force_refresh': forceRefresh,
      'include_ai_comment': includeAiComment,
    };
    return _marineSpotMutation(
      uri: uri,
      method: 'POST',
      body: payload,
      parser: (m) => MarineSpotRefreshResponse.fromJson(m),
    );
  }

  /// POST /api/v1/marine_intelligence/saved_spots/{id}/catch
  Future<MarineCreateCatchResponse> createCatchForSpot(
    String spotId, {
    required String species,
    required String caughtAt,
    double? lengthCm,
    double? weightKg,
    String? bait,
    String? method,
    String? notes,
  }) async {
    final uri = Uri.parse(
      '$serverBaseUrl/api/v1/marine_intelligence/saved_spots/$spotId/catch',
    );
    final payload = <String, dynamic>{
      'species': species,
      'caught_at': caughtAt,
      'length_cm': ?lengthCm,
      'weight_kg': ?weightKg,
      if (bait != null && bait.trim().isNotEmpty) 'bait': bait.trim(),
      if (method != null && method.trim().isNotEmpty) 'method': method.trim(),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    };
    return _marineSpotMutation(
      uri: uri,
      method: 'POST',
      body: payload,
      parser: (m) => MarineCreateCatchResponse.fromJson(m),
    );
  }

  /// GET /api/v1/marine_intelligence/saved_spots/{id}/catches
  Future<MarineCatchListResponse> fetchCatchesForSpot(String spotId) async {
    final uri = Uri.parse(
      '$serverBaseUrl/api/v1/marine_intelligence/saved_spots/$spotId/catches',
    );
    try {
      final response = await _client.get(uri).timeout(const Duration(seconds: 20));
      if (response.statusCode == 404) {
        throw ApiException(kMsgMarineSpotNotFound, type: ApiErrorType.invalidResponse);
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          kMsgMarineCatchLoadFailed,
          statusCode: response.statusCode,
          type: ApiErrorType.invalidResponse,
        );
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return MarineCatchListResponse.fromJson(data);
    } on TimeoutException {
      throw ApiException(kMsgMarineReportTimeout, type: ApiErrorType.timeout);
    } on SocketException catch (e) {
      throw ApiException(_socketMessage(e), type: _socketType(e));
    } catch (e, st) {
      if (e is ApiException) rethrow;
      log('marine_catch list: $e', name: 'ApiService', stackTrace: st);
      throw ApiException(kMsgSunucuyaUlasilamiyor, type: ApiErrorType.unknown);
    }
  }

  /// DELETE /api/v1/marine_intelligence/catches/{id}
  Future<MarineCatchDeleteResponse> deleteCatch(String id) async {
    final uri = Uri.parse('$serverBaseUrl/api/v1/marine_intelligence/catches/$id');
    try {
      final response = await _client.delete(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode == 404) {
        throw ApiException(kMsgMarineCatchNotFound, type: ApiErrorType.invalidResponse);
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          kMsgMarineCatchDeleteFailed,
          statusCode: response.statusCode,
          type: ApiErrorType.invalidResponse,
        );
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return MarineCatchDeleteResponse.fromJson(data);
    } on TimeoutException {
      throw ApiException(kMsgMarineReportTimeout, type: ApiErrorType.timeout);
    } on SocketException catch (e) {
      throw ApiException(_socketMessage(e), type: _socketType(e));
    } catch (e, st) {
      if (e is ApiException) rethrow;
      log('marine_catch delete: $e', name: 'ApiService', stackTrace: st);
      throw ApiException(kMsgSunucuyaUlasilamiyor, type: ApiErrorType.unknown);
    }
  }

  /// PATCH /api/v1/marine_intelligence/catches/{id}
  Future<MarineUpdateCatchResponse> updateCatch(
    String id, {
    String? species,
    double? lengthCm,
    double? weightKg,
    String? bait,
    String? method,
    String? caughtAt,
    String? notes,
  }) async {
    final uri = Uri.parse('$serverBaseUrl/api/v1/marine_intelligence/catches/$id');
    final payload = <String, dynamic>{};
    if (species != null) payload['species'] = species;
    if (lengthCm != null) payload['length_cm'] = lengthCm;
    if (weightKg != null) payload['weight_kg'] = weightKg;
    if (bait != null) payload['bait'] = bait;
    if (method != null) payload['method'] = method;
    if (caughtAt != null) payload['caught_at'] = caughtAt;
    if (notes != null) payload['notes'] = notes;
    try {
      final response = await _client
          .patch(
            uri,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 35));
      if (response.statusCode == 404) {
        throw ApiException(kMsgMarineCatchNotFound, type: ApiErrorType.invalidResponse);
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          kMsgMarineCatchUpdateFailed,
          statusCode: response.statusCode,
          type: ApiErrorType.invalidResponse,
        );
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return MarineUpdateCatchResponse.fromJson(data);
    } on TimeoutException {
      throw ApiException(kMsgMarineReportTimeout, type: ApiErrorType.timeout);
    } on SocketException catch (e) {
      throw ApiException(_socketMessage(e), type: _socketType(e));
    } catch (e, st) {
      if (e is ApiException) rethrow;
      log('marine_catch update: $e', name: 'ApiService', stackTrace: st);
      throw ApiException(kMsgSunucuyaUlasilamiyor, type: ApiErrorType.unknown);
    }
  }

  /// POST /api/v1/marine_intelligence/saved_spots/learning_summaries
  Future<BulkLearningSummariesResponse> fetchLearningSummaries(
    List<String> spotIds,
  ) async {
    final uri = Uri.parse(
      '$serverBaseUrl/api/v1/marine_intelligence/saved_spots/learning_summaries',
    );
    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode({'spot_ids': spotIds}),
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          kMsgMarineCatchLoadFailed,
          statusCode: response.statusCode,
          type: ApiErrorType.invalidResponse,
        );
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return BulkLearningSummariesResponse.fromJson(data);
    } on TimeoutException {
      throw ApiException(kMsgMarineReportTimeout, type: ApiErrorType.timeout);
    } on SocketException catch (e) {
      throw ApiException(_socketMessage(e), type: _socketType(e));
    } catch (e, st) {
      if (e is ApiException) rethrow;
      log('marine_bulk_learning: $e', name: 'ApiService', stackTrace: st);
      throw ApiException(kMsgSunucuyaUlasilamiyor, type: ApiErrorType.unknown);
    }
  }

  /// GET /api/v1/marine_intelligence/saved_spots/{id}/learning_summary
  Future<MarineLearningSummary> fetchLearningSummary(String spotId) async {
    final uri = Uri.parse(
      '$serverBaseUrl/api/v1/marine_intelligence/saved_spots/$spotId/learning_summary',
    );
    try {
      final response = await _client.get(uri).timeout(const Duration(seconds: 20));
      if (response.statusCode == 404) {
        throw ApiException(kMsgMarineSpotNotFound, type: ApiErrorType.invalidResponse);
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          kMsgMarineCatchLoadFailed,
          statusCode: response.statusCode,
          type: ApiErrorType.invalidResponse,
        );
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return MarineLearningSummary.fromJson(data);
    } on TimeoutException {
      throw ApiException(kMsgMarineReportTimeout, type: ApiErrorType.timeout);
    } on SocketException catch (e) {
      throw ApiException(_socketMessage(e), type: _socketType(e));
    } catch (e, st) {
      if (e is ApiException) rethrow;
      log('marine_learning_summary: $e', name: 'ApiService', stackTrace: st);
      throw ApiException(kMsgSunucuyaUlasilamiyor, type: ApiErrorType.unknown);
    }
  }

  Future<T> _marineSpotMutation<T>({
    required Uri uri,
    required String method,
    required Map<String, dynamic> body,
    required T Function(Map<String, dynamic>) parser,
  }) async {
    try {
      final Future<http.Response> req;
      final headers = {'Content-Type': 'application/json; charset=utf-8'};
      final encoded = jsonEncode(body);
      switch (method) {
        case 'POST':
          req = _client.post(uri, headers: headers, body: encoded);
        case 'PATCH':
          req = _client.patch(uri, headers: headers, body: encoded);
        default:
          throw ArgumentError('Unsupported method: $method');
      }
      final response = await req.timeout(const Duration(seconds: 35));
      if (response.statusCode == 404) {
        throw ApiException(kMsgMarineSpotNotFound, type: ApiErrorType.invalidResponse);
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          kMsgMarineSpotsSaveFailed,
          statusCode: response.statusCode,
          type: ApiErrorType.invalidResponse,
        );
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return parser(data);
    } on TimeoutException {
      throw ApiException(kMsgMarineReportTimeout, type: ApiErrorType.timeout);
    } on SocketException catch (e) {
      throw ApiException(_socketMessage(e), type: _socketType(e));
    } catch (e, st) {
      if (e is ApiException) rethrow;
      log('marine_spot mutation: $e', name: 'ApiService', stackTrace: st);
      throw ApiException(kMsgSunucuyaUlasilamiyor, type: ApiErrorType.unknown);
    }
  }

  /// POST /api/v1/ai_fishing_assistant — mevcut analiz özetini yorumlar.
  Future<AiAssistantResponse> fetchAiFishingAssistant({
    required FishingZoneResponse analysis,
    String scope = AiAssistantScope.sessionSummary,
    int? focusHotspotId,
    String? userQuestion,
    Map<String, dynamic>? liveContext,
    String? clientRequestId,
    ClientIdentity? clientIdentity,
    bool forceRefresh = false,
  }) async {
    assertValidAiAssistantScope(scope);

    if (scope == AiAssistantScope.hotspotDetail && focusHotspotId == null) {
      throw ArgumentError.value(
        focusHotspotId,
        'focusHotspotId',
        'hotspot_detail scope için zorunludur',
      );
    }
    if (scope == AiAssistantScope.liveContext &&
        (liveContext == null || liveContext.isEmpty)) {
      throw ArgumentError.value(
        liveContext,
        'liveContext',
        'live_context scope için zorunludur',
      );
    }

    final normalizedQuestion = normalizeAiUserQuestion(userQuestion);
    final uri = Uri.parse('$serverBaseUrl/api/v1/ai_fishing_assistant');
    final payload = <String, dynamic>{
      'scope': scope,
      'locale': 'tr',
      'analysis': analysis.toAiAnalysisJson(),
      'client_request_id': clientRequestId ?? _newClientRequestId(),
    };
    if (focusHotspotId != null) {
      payload['focus_hotspot_id'] = focusHotspotId;
    }
    if (normalizedQuestion.isNotEmpty) {
      payload['user_question'] = normalizedQuestion;
    }
    if (liveContext != null && liveContext.isNotEmpty) {
      payload['live_context'] = liveContext;
    }
    if (clientIdentity != null) {
      payload['client_identity'] = clientIdentity.toJson();
    }
    if (forceRefresh) {
      payload['force_refresh'] = true;
    }

    try {
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 35));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        log(
          'ai_fishing_assistant HTTP ${response.statusCode} ${truncateLogBody(response.body)}',
          name: 'ApiService',
        );
        throw ApiException(
          kMsgAiAssistantUnavailable,
          statusCode: response.statusCode,
          type: response.statusCode >= 500
              ? ApiErrorType.backendUnavailable
              : ApiErrorType.invalidResponse,
        );
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return AiAssistantResponse.fromJson(data);
    } on TimeoutException {
      throw ApiException(
        kMsgAiAssistantTimeout,
        type: ApiErrorType.timeout,
      );
    } on SocketException catch (e) {
      throw ApiException(_socketMessage(e), type: _socketType(e));
    } catch (e, st) {
      if (e is ApiException) rethrow;
      log('ai_fishing_assistant unexpected: $e', name: 'ApiService', stackTrace: st);
      throw ApiException(kMsgAiAssistantUnavailable, type: ApiErrorType.unknown);
    }
  }

  static String _newClientRequestId() {
    final ms = DateTime.now().millisecondsSinceEpoch;
    final micro = DateTime.now().microsecondsSinceEpoch % 1000000;
    return 'ms-$ms-$micro';
  }
}

class FishingZoneResponse {
  FishingZoneResponse({
    required this.boat,
    required this.hotspots,
    required this.imageSize,
    required this.diagnostics,
    this.topRecommendationIds = const [],
    this.sessionAdvice,
    this.coordinateMode,
    this.geoMapDisplayAllowed,
    this.isGeoReferenced,
    this.calibrationQuality,
    this.transformConfidence,
    this.userWarningTr,
    this.calibrationReliability,
  });

  final BoatState boat;
  final List<Hotspot> hotspots;
  final Map<String, int> imageSize;
  final AnalysisDiagnostics diagnostics;
  /// Best-first hotspot IDs (up to five) from backend ``top_recommendations``.
  final List<int> topRecommendationIds;
  /// Session-level coaching copy (English), probabilistic—not guarantees.
  final String? sessionAdvice;
  /// Server ``coordinate_mode`` (e.g. ``geo_referenced``, ``image_space``).
  final String? coordinateMode;

  /// True when hotspots may be drawn on OSM/FOM with real-world trust.
  final bool? geoMapDisplayAllowed;
  final bool? isGeoReferenced;
  /// 0..1 kalibrasyon kalitesi özeti (`transform_quality` ile aynı aile).
  final double? calibrationQuality;
  final double? transformConfidence;
  final String? userWarningTr;
  /// ``excellent`` | ``good`` | ``approximate`` | ``unsafe`` (sunucu).
  final String? calibrationReliability;

  /// Açık sunucu bayrağı yoksa eski yanıtları [diagnostics] eşikleriyle güvenli çözümle.
  bool resolveGeoMapDisplayAllowed() {
    final explicit = geoMapDisplayAllowed;
    if (explicit != null) {
      return explicit;
    }
    final diagFlag = diagnostics.geoMapDisplayAllowedFromDiagnostics;
    if (diagFlag != null) {
      return diagFlag;
    }
    final cm = (coordinateMode ?? '').trim();
    if (cm == kCoordinateModeBoatAnchorEstimated) {
      return true;
    }
    if (cm != kCoordinateModeGeoReferenced) {
      return false;
    }
    final dm = diagnostics.mappingMode.toLowerCase();
    final affineOk =
        diagnostics.screenshotAlignedMappingUsed ||
        dm.contains('affine') ||
        dm.contains('control_point');
    if (!affineOk) {
      return false;
    }
    return diagnostics.transformQuality >= kGeoWorldMapMinTransformQuality &&
        diagnostics.georeferenceError <= kGeoWorldMapMaxGeorefErrorM;
  }

  /// Photo analysis cache should always persist a non-empty [coordinateMode]; use this
  /// when merging server JSON with the request ``coordinate_mode_hint``.
  factory FishingZoneResponse.withEnsuredCoordinateMode(
    FishingZoneResponse response, {
    String? fallbackCoordinateModeHint,
  }) {
    final server = response.coordinateMode?.trim();
    final String resolved;
    if (server != null && server.isNotEmpty) {
      resolved = _canonicalStoredCoordinateMode(server);
    } else {
      final diagOut = response.diagnostics.outputCoordinateMode?.trim();
      if (diagOut != null && diagOut.isNotEmpty) {
        resolved = _canonicalStoredCoordinateMode(diagOut);
      } else {
        final h = fallbackCoordinateModeHint?.trim();
        if (h != null && h.isNotEmpty) {
          resolved = _canonicalStoredCoordinateMode(h);
        } else if (response.hotspots.isEmpty) {
          resolved = kCoordinateModeUnknown;
        } else if (response.hotspots.every((e) => e.mappingTrust == 'image_space')) {
          resolved = kCoordinateModeImageSpace;
        } else {
          resolved = kCoordinateModeUnknown;
        }
      }
    }
    return response.copyWith(coordinateMode: resolved);
  }

  FishingZoneResponse copyWith({
    BoatState? boat,
    List<Hotspot>? hotspots,
    Map<String, int>? imageSize,
    AnalysisDiagnostics? diagnostics,
    List<int>? topRecommendationIds,
    String? sessionAdvice,
    String? coordinateMode,
    bool? geoMapDisplayAllowed,
    bool? isGeoReferenced,
    double? calibrationQuality,
    double? transformConfidence,
    String? userWarningTr,
    String? calibrationReliability,
  }) {
    return FishingZoneResponse(
      boat: boat ?? this.boat,
      hotspots: hotspots ?? this.hotspots,
      imageSize: imageSize ?? this.imageSize,
      diagnostics: diagnostics ?? this.diagnostics,
      topRecommendationIds: topRecommendationIds ?? this.topRecommendationIds,
      sessionAdvice: sessionAdvice ?? this.sessionAdvice,
      coordinateMode: coordinateMode ?? this.coordinateMode,
      geoMapDisplayAllowed: geoMapDisplayAllowed ?? this.geoMapDisplayAllowed,
      isGeoReferenced: isGeoReferenced ?? this.isGeoReferenced,
      calibrationQuality: calibrationQuality ?? this.calibrationQuality,
      transformConfidence: transformConfidence ?? this.transformConfidence,
      userWarningTr: userWarningTr ?? this.userWarningTr,
      calibrationReliability:
          calibrationReliability ?? this.calibrationReliability,
    );
  }

  factory FishingZoneResponse.fromJson(Map<String, dynamic> json) {
    final rankedRaw = json['ranked_hotspots'];
    final rankedList = rankedRaw is List ? rankedRaw : const <dynamic>[];
    final list = rankedList
        .map(_asMap)
        .whereType<Map<String, dynamic>>()
        .map(Hotspot.fromJson)
        .toList(growable: false);
    final imageSizeJson =
        _asMap(json['image_size']) ?? const <String, dynamic>{};
    final imageSize = <String, int>{
      'width': _asInt(imageSizeJson['width']) ?? 0,
      'height': _asInt(imageSizeJson['height']) ?? 0,
    };

    final topRaw = json['top_recommendations'];
    final topIds = topRaw is List
        ? topRaw.map((e) => _asInt(e)).whereType<int>().toList(growable: false)
        : const <int>[];

    final sa = json['session_advice'];
    final sessionAdvice = sa == null
        ? null
        : sa.toString().trim().isEmpty
            ? null
            : sa.toString().trim();

    final cmRoot = json['coordinate_mode'] as String?;
    final diagMapParsed = _asMap(json['diagnostics']);
    final cmDiag = diagMapParsed != null
        ? diagMapParsed['coordinate_mode'] as String?
        : null;

    bool? geoAllow = _asBool(json['geo_map_display_allowed']);

    return FishingZoneResponse(
      boat: BoatState.fromJson(_asMap(json['boat']) ?? const {}),
      hotspots: list,
      imageSize: imageSize,
      diagnostics: AnalysisDiagnostics.fromJson(
        _asMap(json['diagnostics']) ?? const {},
      ),
      topRecommendationIds: topIds,
      sessionAdvice: sessionAdvice,
      coordinateMode: cmRoot ?? cmDiag,
      geoMapDisplayAllowed: geoAllow,
      isGeoReferenced: _asBool(json['is_geo_referenced']),
      calibrationQuality: _asDouble(json['calibration_quality']),
      transformConfidence: _asDouble(json['transform_confidence']),
      userWarningTr: () {
        final w = json['user_warning_tr'];
        if (w == null) return null;
        final t = w.toString().trim();
        return t.isEmpty ? null : t;
      }(),
      calibrationReliability: () {
        final r = json['calibration_reliability'] as String?;
        if (r == null) return null;
        final t = r.trim();
        return t.isEmpty ? null : t;
      }(),
    );
  }

  Map<String, dynamic> toJson() => {
    'boat': boat.toJson(),
    'ranked_hotspots': hotspots.map((e) => e.toJson()).toList(),
    'image_size': imageSize,
    'diagnostics': diagnostics.toJson(),
    if (topRecommendationIds.isNotEmpty)
      'top_recommendations': List<int>.from(topRecommendationIds),
    if (sessionAdvice != null && sessionAdvice!.trim().isNotEmpty)
      'session_advice': sessionAdvice,
    'coordinate_mode': coordinateMode != null && coordinateMode!.trim().isNotEmpty
        ? coordinateMode!.trim()
        : kCoordinateModeUnknown,
    if (geoMapDisplayAllowed != null)
      'geo_map_display_allowed': geoMapDisplayAllowed,
    if (isGeoReferenced != null) 'is_geo_referenced': isGeoReferenced,
    if (calibrationQuality != null)
      'calibration_quality': calibrationQuality,
    if (transformConfidence != null)
      'transform_confidence': transformConfidence,
    if (userWarningTr != null && userWarningTr!.trim().isNotEmpty)
      'user_warning_tr': userWarningTr,
    if (calibrationReliability != null &&
        calibrationReliability!.trim().isNotEmpty)
      'calibration_reliability': calibrationReliability!.trim(),
  };
}

/// Nearest chart hotspot from [/api/v1/live_fishing_score].
class LiveNearestHotspot {
  const LiveNearestHotspot({
    required this.id,
    required this.distanceM,
    required this.recommendationRank,
    required this.latitude,
    required this.longitude,
  });

  final int? id;
  final double distanceM;
  final int? recommendationRank;
  final double latitude;
  final double longitude;

  factory LiveNearestHotspot.fromJson(Map<String, dynamic> json) {
    return LiveNearestHotspot(
      id: _asInt(json['id']),
      distanceM: _asDouble(json['distance_m']) ?? 0,
      recommendationRank: _asInt(json['recommendation_rank']),
      latitude: _asDouble(json['latitude']) ?? 0,
      longitude: _asDouble(json['longitude']) ?? 0,
    );
  }
}

/// Response body for [/api/v1/live_fishing_score].
class LiveFishingScoreResponse {
  const LiveFishingScoreResponse({
    required this.liveScore,
    required this.rating,
    required this.reasoning,
    required this.trustNote,
    this.nearestHotspot,
  });

  final int liveScore;
  final String rating;
  final String reasoning;
  final String trustNote;
  final LiveNearestHotspot? nearestHotspot;

  factory LiveFishingScoreResponse.fromJson(Map<String, dynamic> json) {
    final nhRaw = _asMap(json['nearest_hotspot']);
    final nh =
        nhRaw != null && nhRaw.isNotEmpty ? nhRaw : null;
    return LiveFishingScoreResponse(
      liveScore: (_asInt(json['live_score']) ?? 0).clamp(0, 100),
      rating: (json['rating'] as String?)?.trim() ?? 'Low',
      reasoning: (json['reasoning'] as String?)?.trim() ?? '',
      trustNote:
          (json['trust_note'] as String?)?.trim() ?? kTrustAlways,
      nearestHotspot:
          nh == null ? null : LiveNearestHotspot.fromJson(nh),
    );
  }
}

class AnalysisHistoryEntry {
  AnalysisHistoryEntry({
    required this.id,
    required this.savedAt,
    required this.response,
    required this.chartImageLabel,
    this.chartImagePath,
    required this.controlPointCount,
    required this.isFavorite,
  });

  final String id;
  final DateTime savedAt;
  final FishingZoneResponse response;
  final String? chartImageLabel;

  /// Geçmiş önizleme; dosya silinirse arayüzde ikon gösterilir.
  final String? chartImagePath;
  final int controlPointCount;
  final bool isFavorite;

  factory AnalysisHistoryEntry.fromJson(Map<String, dynamic> json) {
    final rawSavedAt = json['saved_at'] as String?;
    final savedAt = rawSavedAt == null
        ? null
        : DateTime.tryParse(rawSavedAt)?.toLocal();
    return AnalysisHistoryEntry(
      id:
          (json['id'] as String?) ??
          (rawSavedAt ?? DateTime.now().toIso8601String()),
      savedAt: savedAt ?? DateTime.now(),
      response: FishingZoneResponse.fromJson(
        _asMap(json['response']) ?? const <String, dynamic>{},
      ),
      chartImageLabel: json['chart_image_label'] as String?,
      chartImagePath: json['chart_image_path'] as String?,
      controlPointCount: _asInt(json['control_point_count']) ?? 0,
      isFavorite: _asBool(json['is_favorite']) ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'saved_at': savedAt.toIso8601String(),
    'response': response.toJson(),
    'chart_image_label': chartImageLabel,
    'chart_image_path': chartImagePath,
    'control_point_count': controlPointCount,
    'is_favorite': isFavorite,
  };

  AnalysisHistoryEntry copyWith({
    String? id,
    DateTime? savedAt,
    FishingZoneResponse? response,
    String? chartImageLabel,
    String? chartImagePath,
    int? controlPointCount,
    bool? isFavorite,
  }) {
    return AnalysisHistoryEntry(
      id: id ?? this.id,
      savedAt: savedAt ?? this.savedAt,
      response: response ?? this.response,
      chartImageLabel: chartImageLabel ?? this.chartImageLabel,
      chartImagePath: chartImagePath ?? this.chartImagePath,
      controlPointCount: controlPointCount ?? this.controlPointCount,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}

class BoatState {
  BoatState({
    required this.rawGps,
    required this.smoothedGps,
    required this.navigationAnchorGeo,
    required this.boatPixelAnchor,
    required this.boatAnchorConfidence,
    required this.boatAnchorSource,
  });

  final LatLon rawGps;
  final LatLon smoothedGps;
  final LatLon? navigationAnchorGeo;
  final PixelAnchor? boatPixelAnchor;
  final double boatAnchorConfidence;
  final String boatAnchorSource;

  factory BoatState.fromJson(Map<String, dynamic> json) {
    return BoatState(
      rawGps: LatLon.fromJson(_asMap(json['raw_gps']) ?? const {}),
      smoothedGps: LatLon.fromJson(_asMap(json['smoothed_gps']) ?? const {}),
      navigationAnchorGeo: _optionalLatLon(
        _asMap(json['navigation_anchor_geo']),
      ),
      boatPixelAnchor: PixelAnchor.fromNullableJson(
        _asMap(json['boat_pixel_anchor']),
      ),
      boatAnchorConfidence: _asDouble(json['boat_anchor_confidence']) ?? 0,
      boatAnchorSource:
          (json['boat_anchor_source'] as String?) ?? 'gps_fallback',
    );
  }

  Map<String, dynamic> toJson() => {
    'raw_gps': rawGps.toJson(),
    'smoothed_gps': smoothedGps.toJson(),
    'navigation_anchor_geo': navigationAnchorGeo?.toJson(),
    'boat_pixel_anchor': boatPixelAnchor?.toJson(),
    'boat_anchor_confidence': boatAnchorConfidence,
    'boat_anchor_source': boatAnchorSource,
  };
}

class AnalysisDiagnostics {
  AnalysisDiagnostics({
    required this.mappingMode,
    required this.screenshotAlignedMappingUsed,
    required this.mappingTrustState,
    required this.chartReferencePrimary,
    required this.renderModeRecommendation,
    required this.georeferenceError,
    required this.transformQuality,
    required this.coastlineConfidence,
    required this.rejectedLandCandidates,
    required this.validWaterCandidates,
    required this.suspiciousHotspotCount,
    required this.boatAnchorConfidence,
    required this.boatAnchorSource,
    required this.boatRenderRecommendation,
    this.imageSpaceEnrichmentDetail,
    this.enrichmentScope,
    this.geoMapDisplayAllowedFromDiagnostics,
    this.calibrationReliability,
    this.calibrationReliabilityReason,
    this.controlPointSpreadM,
    this.attemptedBoatAnchorEstimate,
    this.boatAnchorEstimateReason,
    this.hasCurrentGps,
    this.hasBoatPixelAnchorRequest,
    this.hasBoatPixelAnchorDetected,
    this.hasBoundsRequest,
    this.hasBoundsMapper,
    this.outputCoordinateMode,
    this.hotspotGeoCount,
    this.pixelHotspotCandidates,
    this.boatAnchorResolution,
    this.imageSpaceDebugOverlayPath,
  });

  final String mappingMode;
  final bool screenshotAlignedMappingUsed;
  final String mappingTrustState;
  final bool chartReferencePrimary;
  final String renderModeRecommendation;
  final double georeferenceError;
  final double transformQuality;
  final double coastlineConfidence;
  final int rejectedLandCandidates;
  final int validWaterCandidates;
  final int suspiciousHotspotCount;
  final double boatAnchorConfidence;
  final String boatAnchorSource;
  final String boatRenderRecommendation;
  /// Backend açıklaması: image_space + ``enrich_data`` için neden derinlik/tür yok.
  final String? imageSpaceEnrichmentDetail;
  /// ``boat_gps`` / ``unavailable_no_gps`` (image_space zenginleştirme kapsamı).
  final String? enrichmentScope;
  /// Diagnostics gövdesindeki ``geo_map_display_allowed`` (köke yedek).
  final bool? geoMapDisplayAllowedFromDiagnostics;
  final String? calibrationReliability;
  final String? calibrationReliabilityReason;
  final double? controlPointSpreadM;

  /// boat_anchor_estimated debug (image-space path).
  final bool? attemptedBoatAnchorEstimate;
  final String? boatAnchorEstimateReason;
  final bool? hasCurrentGps;
  final bool? hasBoatPixelAnchorRequest;
  final bool? hasBoatPixelAnchorDetected;
  final bool? hasBoundsRequest;
  final bool? hasBoundsMapper;
  final String? outputCoordinateMode;
  final int? hotspotGeoCount;
  final int? pixelHotspotCandidates;
  final String? boatAnchorResolution;
  /// Opsiyonel debug overlay PNG yolu (sunucu diagnostics alanı).
  final String? imageSpaceDebugOverlayPath;

  factory AnalysisDiagnostics.fromJson(Map<String, dynamic> json) {
    final bath = _asMap(json['bathymetry']) ?? const <String, dynamic>{};
    final candidateStats =
        _asMap(bath['candidate_stats']) ?? const <String, dynamic>{};
    final detail = json['image_space_enrichment_detail'];
    return AnalysisDiagnostics(
      mappingMode: (json['mapping_mode'] as String?) ?? 'linear_bounds',
      screenshotAlignedMappingUsed:
          (json['screenshot_aligned_mapping_used'] as bool?) ?? false,
      mappingTrustState:
          (json['mapping_trust_state'] as String?) ??
          'approximate_bounds_fallback',
      chartReferencePrimary: (json['chart_reference_primary'] as bool?) ?? true,
      renderModeRecommendation:
          (json['render_mode_recommendation'] as String?) ??
          'chart_overlay_primary_with_world_fallback',
      georeferenceError: _asDouble(json['georeference_error']) ?? 0,
      transformQuality: _asDouble(json['transform_quality']) ?? 0,
      coastlineConfidence: _asDouble(bath['coastline_confidence']) ?? 0,
      rejectedLandCandidates:
          _asInt(candidateStats['rejected_land_candidates']) ?? 0,
      validWaterCandidates:
          _asInt(candidateStats['valid_water_candidates']) ?? 0,
      suspiciousHotspotCount: _asInt(json['suspicious_hotspot_count']) ?? 0,
      boatAnchorConfidence: _asDouble(json['boat_anchor_confidence']) ?? 0,
      boatAnchorSource:
          (json['boat_anchor_source'] as String?) ?? 'gps_fallback',
      boatRenderRecommendation:
          (json['boat_render_recommendation'] as String?) ??
          'gps_fallback_approximate',
      imageSpaceEnrichmentDetail:
          detail == null
              ? null
              : detail.toString().trim().isEmpty
                  ? null
                  : detail.toString().trim(),
      enrichmentScope: () {
        final s = json['enrichment_scope'] as String?;
        if (s == null) return null;
        final t = s.trim();
        return t.isEmpty ? null : t;
      }(),
      geoMapDisplayAllowedFromDiagnostics:
          _asBool(json['geo_map_display_allowed']),
      calibrationReliability: () {
        final s = json['calibration_reliability'] as String?;
        if (s == null) return null;
        final t = s.trim();
        return t.isEmpty ? null : t;
      }(),
      calibrationReliabilityReason: () {
        final s = json['calibration_reliability_reason'] as String?;
        if (s == null) return null;
        final t = s.trim();
        return t.isEmpty ? null : t;
      }(),
      controlPointSpreadM: _asDouble(json['control_point_spread_m']),
      attemptedBoatAnchorEstimate:
          _asBool(json['attempted_boat_anchor_estimate']),
      boatAnchorEstimateReason: () {
        final s = json['boat_anchor_estimate_reason'] as String?;
        if (s == null) return null;
        final t = s.trim();
        return t.isEmpty ? null : t;
      }(),
      hasCurrentGps: _asBool(json['has_current_gps']),
      hasBoatPixelAnchorRequest: _asBool(json['has_boat_pixel_anchor_request']),
      hasBoatPixelAnchorDetected: _asBool(json['has_boat_pixel_anchor_detected']),
      hasBoundsRequest: _asBool(json['has_bounds_request']),
      hasBoundsMapper: _asBool(json['has_bounds_mapper']),
      outputCoordinateMode: () {
        final s = json['output_coordinate_mode'] as String?;
        if (s == null) return null;
        final t = s.trim();
        return t.isEmpty ? null : t;
      }(),
      hotspotGeoCount: _asInt(json['hotspot_geo_count']),
      pixelHotspotCandidates: _asInt(json['pixel_hotspot_candidates']),
      boatAnchorResolution: () {
        final s = json['boat_anchor_resolution'] as String?;
        if (s == null) return null;
        final t = s.trim();
        return t.isEmpty ? null : t;
      }(),
      imageSpaceDebugOverlayPath: () {
        final s = json['image_space_debug_overlay_path'] as String?;
        if (s == null) return null;
        final t = s.trim();
        return t.isEmpty ? null : t;
      }(),
    );
  }

  Map<String, dynamic> toJson() => {
    'mapping_mode': mappingMode,
    'screenshot_aligned_mapping_used': screenshotAlignedMappingUsed,
    'mapping_trust_state': mappingTrustState,
    'chart_reference_primary': chartReferencePrimary,
    'render_mode_recommendation': renderModeRecommendation,
    'georeference_error': georeferenceError,
    'transform_quality': transformQuality,
    'coastline_confidence': coastlineConfidence,
    'rejected_land_candidates': rejectedLandCandidates,
    'valid_water_candidates': validWaterCandidates,
    'suspicious_hotspot_count': suspiciousHotspotCount,
    'boat_anchor_confidence': boatAnchorConfidence,
    'boat_anchor_source': boatAnchorSource,
    'boat_render_recommendation': boatRenderRecommendation,
    if (imageSpaceEnrichmentDetail != null)
      'image_space_enrichment_detail': imageSpaceEnrichmentDetail,
    if (enrichmentScope != null) 'enrichment_scope': enrichmentScope,
    if (geoMapDisplayAllowedFromDiagnostics != null)
      'geo_map_display_allowed': geoMapDisplayAllowedFromDiagnostics,
    if (calibrationReliability != null)
      'calibration_reliability': calibrationReliability,
    if (calibrationReliabilityReason != null)
      'calibration_reliability_reason': calibrationReliabilityReason,
    if (controlPointSpreadM != null)
      'control_point_spread_m': controlPointSpreadM,
    if (attemptedBoatAnchorEstimate != null)
      'attempted_boat_anchor_estimate': attemptedBoatAnchorEstimate,
    if (boatAnchorEstimateReason != null)
      'boat_anchor_estimate_reason': boatAnchorEstimateReason,
    if (hasCurrentGps != null) 'has_current_gps': hasCurrentGps,
    if (hasBoatPixelAnchorRequest != null)
      'has_boat_pixel_anchor_request': hasBoatPixelAnchorRequest,
    if (hasBoatPixelAnchorDetected != null)
      'has_boat_pixel_anchor_detected': hasBoatPixelAnchorDetected,
    if (hasBoundsRequest != null) 'has_bounds_request': hasBoundsRequest,
    if (hasBoundsMapper != null) 'has_bounds_mapper': hasBoundsMapper,
    if (outputCoordinateMode != null) 'output_coordinate_mode': outputCoordinateMode,
    if (hotspotGeoCount != null) 'hotspot_geo_count': hotspotGeoCount,
    if (pixelHotspotCandidates != null)
      'pixel_hotspot_candidates': pixelHotspotCandidates,
    if (boatAnchorResolution != null)
      'boat_anchor_resolution': boatAnchorResolution,
    if (imageSpaceDebugOverlayPath != null)
      'image_space_debug_overlay_path': imageSpaceDebugOverlayPath,
  };
}

class PixelAnchor {
  PixelAnchor({required this.x, required this.y, this.confidence, this.source});

  final double x;
  final double y;
  final double? confidence;
  final String? source;

  static PixelAnchor? fromNullableJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    return PixelAnchor(
      x: _asDouble(json['x']) ?? 0,
      y: _asDouble(json['y']) ?? 0,
      confidence: _asDouble(json['confidence']),
      source: json['source'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final out = <String, dynamic>{'x': x, 'y': y};
    final c = confidence;
    if (c != null) out['confidence'] = c;
    final s = source;
    if (s != null && s.trim().isNotEmpty) out['source'] = s;
    return out;
  }
}

LatLon? _optionalLatLon(Map<String, dynamic>? json) {
  if (json == null) return null;
  final lat = _asDouble(json['lat']);
  final lon = _asDouble(json['lon']);
  if (lat == null || lon == null) return null;
  return LatLon(lat: lat, lon: lon);
}

class SpeciesMatch {
  const SpeciesMatch({
    required this.species,
    required this.confidence,
    required this.reason,
  });

  final String species;
  final String confidence;
  final String reason;

  factory SpeciesMatch.fromJson(Map<String, dynamic> json) {
    return SpeciesMatch(
      species: (json['species'] as String?)?.trim() ?? '',
      confidence: (json['confidence'] as String?)?.trim() ?? 'low',
      reason: (json['reason'] as String?)?.trim() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'species': species,
    'confidence': confidence,
    'reason': reason,
  };
}

class Hotspot {
  Hotspot({
    required this.id,
    required this.featureType,
    required this.rankByProximity,
    required this.rank,
    required this.rankOverall,
    required this.rankByScoreThenDistance,
    required this.geoCoordinate,
    required this.latitude,
    required this.longitude,
    required this.distanceM,
    required this.bearingDeg,
    required this.score,
    required this.classification,
    required this.reasoning,
    this.reasoningText = '',
    this.fishPrediction = '',
    this.regionalSpeciesContext,
    this.speciesMatch = const [],
    required this.supportingMetrics,
    required this.seaState,
    required this.pixelCentroid,
    required this.hotspotPixelAnchor,
    required this.trustState,
    required this.trustScore,
    required this.mappingTrust,
    required this.isRenderable,
    required this.fishingAdvice,
    required this.confirmedDepth,
    required this.likelySpecies,
    this.finalFishingScore = 0,
    this.recommendationRank = 999999,
  });

  final int id;
  final String featureType;
  final int rankByProximity;
  final int rank;
  final int rankOverall;
  final int rankByScoreThenDistance;
  final LatLon geoCoordinate;
  final double latitude;
  final double longitude;
  final double distanceM;
  final double bearingDeg;
  final double score;
  final String classification;
  final List<String> reasoning;
  /// Human-friendly 1–2 sentence fishing insight (English, from backend ``reasoning_text``).
  final String reasoningText;
  /// Generic species-style hint (English, from backend ``fish_prediction``).
  final String fishPrediction;
  /// OBIS-first cautious regional occurrence summary (English), or null without calibrated geo.
  final String? regionalSpeciesContext;
  /// Structure × regional compatibility hints (English), max three items.
  final List<SpeciesMatch> speciesMatch;
  final Map<String, dynamic> supportingMetrics;
  final SeaState seaState;
  final Map<String, double> pixelCentroid;
  final PixelAnchor hotspotPixelAnchor;
  final String trustState;
  final double trustScore;
  final String mappingTrust;
  final bool isRenderable;
  final FishingAdvice fishingAdvice;
  final ConfirmedDepth confirmedDepth;
  final BiodiversityInfo likelySpecies;
  /// Ensemble priority score (0–100), heuristic—not a certainty measure.
  final int finalFishingScore;
  /// 1 = best suggested visit priority within this chart (ties broken by hotspot id ordering).
  final int recommendationRank;

  factory Hotspot.fromJson(Map<String, dynamic> json) {
    final geoJson = _asMap(json['geo_coordinate']) ?? const {};
    final geo = LatLon.fromJson(geoJson);
    // Backend ana alanlar: latitude/longitude. Alias destekleri: lat/lon, geo_lat/geo_lon, worldLat/worldLon.
    final latitude =
        _asDouble(json['latitude']) ??
        _asDouble(json['lat']) ??
        _asDouble(json['geo_lat']) ??
        _asDouble(json['worldLat']) ??
        geo.lat;
    final longitude =
        _asDouble(json['longitude']) ??
        _asDouble(json['lon']) ??
        _asDouble(json['geo_lon']) ??
        _asDouble(json['worldLon']) ??
        geo.lon;

    final reasoningDynamic = json['reasoning'];
    final reasoning = reasoningDynamic is List
        ? reasoningDynamic.map((e) => e.toString()).toList(growable: false)
        : <String>[];

    final supportingMetrics =
        _asMap(json['supporting_metrics']) ?? <String, dynamic>{};
    final pixelCentroidJson =
        _asMap(json['pixel_centroid']) ?? const <String, dynamic>{};
    final pixelCentroid = <String, double>{
      'x': _asDouble(pixelCentroidJson['x']) ?? 0,
      'y': _asDouble(pixelCentroidJson['y']) ?? 0,
    };
    final hotspotAnchor =
        PixelAnchor.fromNullableJson(_asMap(json['hotspot_pixel_anchor'])) ??
        PixelAnchor(x: pixelCentroid['x'] ?? 0, y: pixelCentroid['y'] ?? 0);

    return Hotspot(
      id: _asInt(json['id']) ?? -1,
      featureType: (json['feature_type'] as String?) ?? 'unknown',
      rankByProximity: _asInt(json['rank_by_proximity']) ?? 9999,
      rank: _asInt(json['rank']) ?? _asInt(json['rank_overall']) ?? 9999,
      rankOverall: _asInt(json['rank_overall']) ?? _asInt(json['rank']) ?? 9999,
      rankByScoreThenDistance:
          _asInt(json['rank_by_score_then_distance']) ??
          _asInt(json['rank']) ??
          9999,
      geoCoordinate: geo,
      latitude: latitude,
      longitude: longitude,
      distanceM:
          _asDouble(json['distance_m']) ??
          _asDouble(json['distanceMeters']) ??
          _asDouble(json['distance_meters']) ??
          0,
      bearingDeg:
          _asDouble(json['bearing_deg']) ??
          _asDouble(json['bearingDegrees']) ??
          _asDouble(json['bearing_degrees']) ??
          0,
      score: _asDouble(json['score']) ?? 0,
      classification: ((json['classification'] as String?) ?? 'C')
          .toUpperCase(),
      reasoning: reasoning,
      reasoningText:
          (json['reasoning_text'] as String?)?.trim() ?? '',
      fishPrediction:
          (json['fish_prediction'] as String?)?.trim() ?? '',
      regionalSpeciesContext:
          () {
            final raw = json['regional_species_context'];
            if (raw == null) return null;
            final s = raw.toString().trim();
            return s.isEmpty ? null : s;
          }(),
      speciesMatch:
          () {
            final raw = json['species_match'];
            if (raw is! List) return const <SpeciesMatch>[];
            return raw
                .map(_asMap)
                .whereType<Map<String, dynamic>>()
                .map(SpeciesMatch.fromJson)
                .where((s) => s.species.isNotEmpty)
                .take(3)
                .toList(growable: false);
          }(),
      supportingMetrics: supportingMetrics,
      seaState: SeaState.fromJson(_asMap(json['sea_state']) ?? const {}),
      pixelCentroid: pixelCentroid,
      hotspotPixelAnchor: hotspotAnchor,
      trustState: (json['trust_state'] as String?) ?? 'trusted',
      trustScore: _asDouble(json['trust_score']) ?? 1.0,
      mappingTrust:
          (json['mapping_trust'] as String?) ?? 'approximate_world_fallback',
      isRenderable: (json['is_renderable'] as bool?) ?? true,
      fishingAdvice: FishingAdvice.fromJson(
        _asMap(json['fishing_advice']) ??
            _asMap(json['bait_recommendation']) ?? // legacy / alternate payloads
            const <String, dynamic>{},
      ),
      confirmedDepth: ConfirmedDepth.fromJson(
        _asMap(json['confirmed_depth']) ??
            _asMap(json['depth_confirmation']) ??
            const <String, dynamic>{},
      ),
      likelySpecies: BiodiversityInfo.fromJson(
        _asMap(json['likely_species']) ??
            _asMap(json['biodiversity_signal']) ??
            _asMap(json['biodiversity']) ??
            const <String, dynamic>{},
      ),
      finalFishingScore: () {
        final v = json['final_fishing_score'];
        if (v is num) return v.round().clamp(0, 100);
        final i = _asInt(v);
        return (i ?? 0).clamp(0, 100);
      }(),
      recommendationRank: () {
        final i = _asInt(json['recommendation_rank']);
        return i ?? 999999;
      }(),
    );
  }

  LatLon get point => LatLon(lat: latitude, lon: longitude);

  Map<String, dynamic> toJson() => {
    'id': id,
    'feature_type': featureType,
    'rank_by_proximity': rankByProximity,
    'rank': rank,
    'rank_overall': rankOverall,
    'rank_by_score_then_distance': rankByScoreThenDistance,
    'geo_coordinate': geoCoordinate.toJson(),
    'latitude': latitude,
    'longitude': longitude,
    'distance_m': distanceM,
    'bearing_deg': bearingDeg,
    'score': score,
    'classification': classification,
    'reasoning': reasoning,
    'reasoning_text': reasoningText,
    'fish_prediction': fishPrediction,
    if (regionalSpeciesContext != null)
      'regional_species_context': regionalSpeciesContext,
    if (speciesMatch.isNotEmpty)
      'species_match': speciesMatch.map((e) => e.toJson()).toList(),
    'supporting_metrics': supportingMetrics,
    'sea_state': seaState.toJson(),
    'pixel_centroid': pixelCentroid,
    'hotspot_pixel_anchor': hotspotPixelAnchor.toJson(),
    'trust_state': trustState,
    'trust_score': trustScore,
    'mapping_trust': mappingTrust,
    'is_renderable': isRenderable,
    'fishing_advice': fishingAdvice.toJson(),
    'confirmed_depth': confirmedDepth.toJson(),
    'likely_species': likelySpecies.toJson(),
    'final_fishing_score': finalFishingScore,
    'recommendation_rank': recommendationRank,
  };
}

class FishingAdvice {
  FishingAdvice({
    required this.speciesPredictions,
    required this.bait,
    required this.bestTimes,
    required this.tackle,
    required this.selectionReasons,
  });

  final List<FishPrediction> speciesPredictions;
  final List<String> bait;
  final List<String> bestTimes;
  final List<String> tackle;
  final List<String> selectionReasons;

  factory FishingAdvice.fromJson(Map<String, dynamic> json) {
    final speciesRaw =
        json['species_predictions'] ??
        json['possible_species'] ??
        json['likely_species'] ??
        json['species'];
    final speciesList = speciesRaw is List
        ? speciesRaw
              .map(_asMap)
              .whereType<Map<String, dynamic>>()
              .map(FishPrediction.fromJson)
              .toList(growable: false)
        : <FishPrediction>[];
    return FishingAdvice(
      speciesPredictions: speciesList,
      bait: _asStringList(json['bait'] ?? json['bait_recommendation'] ?? json['baitAdvice']),
      bestTimes: _asStringList(
        json['best_times'] ?? json['best_fishing_times'] ?? json['timingAdvice'],
      ),
      tackle:
          _asStringList(json['tackle'] ?? json['tackle_recommendation'] ?? json['tackleAdvice']),
      selectionReasons: _asStringList(
        json['selection_reasons'] ?? json['species_reasoning'] ?? json['reasons'],
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'species_predictions': speciesPredictions.map((e) => e.toJson()).toList(),
    'bait': bait,
    'best_times': bestTimes,
    'tackle': tackle,
    'selection_reasons': selectionReasons,
  };
}

class FishPrediction {
  FishPrediction({required this.species, required this.probability});

  final String species;
  final String probability;

  factory FishPrediction.fromJson(Map<String, dynamic> json) {
    return FishPrediction(
      species: (json['species'] as String?)?.trim() ?? '',
      probability: (json['probability'] as String?) ?? 'düşük',
    );
  }

  Map<String, dynamic> toJson() => {
    'species': species,
    'probability': probability,
  };
}

class SeaState {
  SeaState({
    required this.waveHeightM,
    required this.waterTemperatureC,
    required this.windSpeedKnots,
    required this.windDirectionDeg,
    required this.currentSpeedKnots,
    required this.currentDirectionDeg,
    required this.pressureHpa,
    required this.oceanCurrentVelocityMps,
    required this.source,
    required this.fallback,
    required this.reason,
    required this.simulatedComponents,
    this.marineAtBoatPosition = false,
  });

  final double? waveHeightM;
  final double? waterTemperatureC;
  final double? windSpeedKnots;
  final double? windDirectionDeg;
  final double? currentSpeedKnots;
  final double? currentDirectionDeg;
  final double? pressureHpa;
  final double? oceanCurrentVelocityMps;
  final String source;
  final bool fallback;
  final String? reason;
  final List<String> simulatedComponents;
  /// Sunucu: deniz durumu tekne GPS konumundan alındı (image_space).
  final bool marineAtBoatPosition;

  factory SeaState.fromJson(Map<String, dynamic> json) {
    return SeaState(
      waveHeightM: _asDouble(json['wave_height_m']),
      waterTemperatureC: _asDouble(json['water_temperature_c']),
      windSpeedKnots: _asDouble(json['wind_speed_knots']),
      windDirectionDeg: _asDouble(json['wind_direction_deg']),
      currentSpeedKnots: _asDouble(json['current_speed_knots']),
      currentDirectionDeg: _asDouble(json['current_direction_deg']),
      pressureHpa: _asDouble(json['pressure_hpa']),
      oceanCurrentVelocityMps: _asDouble(json['ocean_current_velocity_mps']),
      source: (json['source'] as String?) ?? 'unknown',
      fallback: _asBool(json['fallback']) ?? false,
      reason: json['reason'] as String?,
      simulatedComponents: _asStringList(json['simulated_components']),
      marineAtBoatPosition: _asBool(json['marine_at_boat_position']) ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'wave_height_m': waveHeightM,
    'water_temperature_c': waterTemperatureC,
    'wind_speed_knots': windSpeedKnots,
    'wind_direction_deg': windDirectionDeg,
    'current_speed_knots': currentSpeedKnots,
    'current_direction_deg': currentDirectionDeg,
    'pressure_hpa': pressureHpa,
    'ocean_current_velocity_mps': oceanCurrentVelocityMps,
    'source': source,
    'fallback': fallback,
    'reason': reason,
    'simulated_components': simulatedComponents,
    'marine_at_boat_position': marineAtBoatPosition,
  };
}

class ConfirmedDepth {
  ConfirmedDepth({
    required this.depthM,
    required this.rawElevationM,
    required this.dataset,
    required this.source,
    required this.fallback,
    required this.reason,
    required this.error,
  });

  final double? depthM;
  final double? rawElevationM;
  final String? dataset;
  final String source;
  final bool fallback;
  final String? reason;
  final String? error;

  factory ConfirmedDepth.fromJson(Map<String, dynamic> json) {
    return ConfirmedDepth(
      depthM: _asDouble(json['depth_m']),
      rawElevationM: _asDouble(json['raw_elevation_m']),
      dataset: json['dataset'] as String?,
      source: (json['source'] as String?) ?? 'unknown',
      fallback: _asBool(json['fallback']) ?? false,
      reason: json['reason'] as String?,
      error: json['error'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'depth_m': depthM,
    'raw_elevation_m': rawElevationM,
    'dataset': dataset,
    'source': source,
    'fallback': fallback,
    'reason': reason,
    'error': error,
  };
}

class BiodiversityInfo {
  BiodiversityInfo({
    required this.radiusKm,
    required this.queryGeometryWkt,
    required this.topSpecies,
    required this.totalRecordsConsidered,
    required this.source,
    this.confidence,
    required this.fallback,
    required this.reason,
    required this.error,
  });

  final double? radiusKm;
  final String? queryGeometryWkt;
  final List<SpeciesOccurrence> topSpecies;
  final int totalRecordsConsidered;
  final String source;
  /// Backend: "approximate" gibi sinyal güven katmanı (fallback için).
  final String? confidence;
  final bool fallback;
  final String? reason;
  final String? error;

  factory BiodiversityInfo.fromJson(Map<String, dynamic> json) {
    final rawTopSpecies = json['top_species'];
    final topSpecies = rawTopSpecies is List
        ? rawTopSpecies
              .map(_asMap)
              .whereType<Map<String, dynamic>>()
              .map(SpeciesOccurrence.fromJson)
              .toList(growable: false)
        : const <SpeciesOccurrence>[];
    return BiodiversityInfo(
      radiusKm: _asDouble(json['radius_km']),
      queryGeometryWkt: json['query_geometry_wkt'] as String?,
      topSpecies: topSpecies,
      totalRecordsConsidered: _asInt(json['total_records_considered']) ?? 0,
      source: (json['source'] as String?) ?? 'unknown',
      confidence: (json['confidence'] as String?)?.trim().isEmpty == true
          ? null
          : (json['confidence'] as String?)?.trim(),
      fallback: _asBool(json['fallback']) ?? false,
      reason: json['reason'] as String?,
      error: json['error'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'radius_km': radiusKm,
    'query_geometry_wkt': queryGeometryWkt,
    'top_species': topSpecies.map((e) => e.toJson()).toList(),
    'total_records_considered': totalRecordsConsidered,
    'source': source,
    if (confidence != null) 'confidence': confidence,
    'fallback': fallback,
    'reason': reason,
    'error': error,
  };
}

class SpeciesOccurrence {
  SpeciesOccurrence({required this.species, required this.occurrenceCount});

  final String species;
  final int occurrenceCount;

  factory SpeciesOccurrence.fromJson(Map<String, dynamic> json) {
    return SpeciesOccurrence(
      species: (json['species'] as String?)?.trim() ?? '',
      occurrenceCount: _asInt(json['occurrence_count']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'species': species,
    'occurrence_count': occurrenceCount,
  };
}

class LatLon {
  LatLon({required this.lat, required this.lon});

  final double lat;
  final double lon;

  factory LatLon.fromJson(Map<String, dynamic> json) {
    return LatLon(
      lat: _asDouble(json['lat']) ?? 0,
      lon: _asDouble(json['lon']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {'lat': lat, 'lon': lon};
}

class ImageGeoBounds {
  ImageGeoBounds({
    this.topLeft,
    this.bottomRight,
    this.controlPoints,
    this.boatPixelAnchor,
    this.coordinateModeHint,
  });

  final LatLon? topLeft;
  final LatLon? bottomRight;
  final List<ImageControlPoint>? controlPoints;
  final PixelAnchor? boatPixelAnchor;
  final String? coordinateModeHint;

  Map<String, dynamic> toJson() {
    final out = <String, dynamic>{};
    final tl = topLeft;
    if (tl != null) out['top_left'] = tl.toJson();
    final br = bottomRight;
    if (br != null) out['bottom_right'] = br.toJson();
    final points = controlPoints;
    if (points != null && points.isNotEmpty) {
      out['control_points'] = points
          .map((e) => e.toJson())
          .toList(growable: false);
    }
    final boatAnchor = boatPixelAnchor;
    if (boatAnchor != null) {
      out['boat_pixel_anchor'] = boatAnchor.toJson();
    }
    final hint = coordinateModeHint;
    if (hint != null && hint.trim().isNotEmpty) {
      out['coordinate_mode_hint'] = hint;
    }
    return out;
  }

  /// Kalibrasyon noktalarından köşe sınırlarını türetir (sunucu 500 önlemi).
  ImageGeoBounds ensureCornersForAnalysis() {
    final points = controlPoints;
    if (points == null || points.length < 3) return this;

    final primary = points;

    var tl = topLeft;
    var br = bottomRight;
    if (tl == null || br == null) {
      var minLat = primary.first.geo.lat;
      var maxLat = primary.first.geo.lat;
      var minLon = primary.first.geo.lon;
      var maxLon = primary.first.geo.lon;
      for (final point in primary.skip(1)) {
        minLat = point.geo.lat < minLat ? point.geo.lat : minLat;
        maxLat = point.geo.lat > maxLat ? point.geo.lat : maxLat;
        minLon = point.geo.lon < minLon ? point.geo.lon : minLon;
        maxLon = point.geo.lon > maxLon ? point.geo.lon : maxLon;
      }
      final latPad = ((maxLat - minLat).abs() * 0.05).clamp(0.0001, 1.0);
      final lonPad = ((maxLon - minLon).abs() * 0.05).clamp(0.0001, 1.0);
      tl = LatLon(
        lat: (maxLat + latPad).clamp(-90.0, 90.0).toDouble(),
        lon: (minLon - lonPad).clamp(-180.0, 180.0).toDouble(),
      );
      br = LatLon(
        lat: (minLat - latPad).clamp(-90.0, 90.0).toDouble(),
        lon: (maxLon + lonPad).clamp(-180.0, 180.0).toDouble(),
      );
    }

    return ImageGeoBounds(
      topLeft: tl,
      bottomRight: br,
      controlPoints: primary,
      boatPixelAnchor: boatPixelAnchor,
      coordinateModeHint: coordinateModeHint,
    );
  }
}

class ImageControlPoint {
  ImageControlPoint({
    required this.pixelX,
    required this.pixelY,
    required this.geo,
  });

  final double pixelX;
  final double pixelY;
  final LatLon geo;

  Map<String, dynamic> toJson() => {
    'pixel': {'x': pixelX, 'y': pixelY},
    'geo': geo.toJson(),
  };

  factory ImageControlPoint.fromJson(Map<String, dynamic> json) {
    final pixel = _asMap(json['pixel']) ?? <String, dynamic>{};
    return ImageControlPoint(
      pixelX: _asDouble(pixel['x']) ?? 0.0,
      pixelY: _asDouble(pixel['y']) ?? 0.0,
      geo: LatLon.fromJson(_asMap(json['geo']) ?? const <String, dynamic>{}),
    );
  }
}

/// Aynı chart / çözünürlükte tekrar kullanılmak üzere kayıtlı kontrol noktaları.
class ChartCalibrationProfile {
  ChartCalibrationProfile({
    required this.id,
    required this.name,
    required this.controlPoints,
    required this.imageWidth,
    required this.imageHeight,
    this.chartLabel,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final List<ImageControlPoint> controlPoints;
  final int imageWidth;
  final int imageHeight;
  final String? chartLabel;
  final DateTime updatedAt;

  factory ChartCalibrationProfile.fromJson(Map<String, dynamic> json) {
    final pointsRaw = json['control_points'];
    final points = pointsRaw is List
        ? pointsRaw
              .map(_asMap)
              .whereType<Map<String, dynamic>>()
              .map(ImageControlPoint.fromJson)
              .toList(growable: false)
        : <ImageControlPoint>[];
    final rawTime = json['updated_at'] as String?;
    return ChartCalibrationProfile(
      id: (json['id'] as String?) ?? DateTime.now().toIso8601String(),
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? (json['name'] as String).trim()
          : 'Profil',
      controlPoints: points,
      imageWidth: _asInt(json['image_width']) ?? 0,
      imageHeight: _asInt(json['image_height']) ?? 0,
      chartLabel: json['chart_label'] as String?,
      updatedAt: DateTime.tryParse(rawTime ?? '')?.toLocal() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'control_points': controlPoints.map((e) => e.toJson()).toList(),
    'image_width': imageWidth,
    'image_height': imageHeight,
    'chart_label': chartLabel,
    'updated_at': updatedAt.toIso8601String(),
  };
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double? _asDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

bool? _asBool(dynamic value) {
  if (value is bool) return value;
  if (value is int) return value != 0;
  if (value is num) return value != 0;
  if (value is String) {
    final t = value.trim().toLowerCase();
    if (t == 'true' || t == '1' || t == 'yes') return true;
    if (t == 'false' || t == '0' || t == 'no') return false;
  }
  return null;
}

Map<String, dynamic>? _asMap(dynamic value) {
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

List<String> _asStringList(dynamic value) {
  if (value is List) {
    return value.map((e) => e.toString()).toList(growable: false);
  }
  return const <String>[];
}

String? _extractFastApiDetail(String body) {
  if (body.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      final detail = decoded['detail'];
      if (detail is String && detail.trim().isNotEmpty) {
        return detail.trim();
      }
      if (detail is List && detail.isNotEmpty) {
        final parts = <String>[];
        for (final item in detail) {
          if (item is Map && item['msg'] != null) {
            parts.add(item['msg'].toString());
          }
        }
        if (parts.isNotEmpty) return parts.join(' ');
      }
    }
  } catch (_) {}
  return null;
}

String _analyzeHttpFailureMessage(int statusCode, String body) {
  final detail = _extractFastApiDetail(body);
  if (statusCode >= 500) {
    if (detail != null && detail.isNotEmpty) {
      return 'Analiz tamamlanamadı: $detail';
    }
    return kMsgAnalysisHttpError(statusCode);
  }
  if (statusCode == 400) {
    return detail ?? 'Geçersiz analiz isteği (HTTP 400).';
  }
  return detail ?? kMsgAnalysisHttpError(statusCode);
}

ApiErrorType _socketType(SocketException e) {
  final msg = e.message.toLowerCase();
  if (msg.contains('timed out')) {
    return ApiErrorType.timeout;
  }
  if (msg.contains('nodename nor servname provided') ||
      msg.contains('name or service not known') ||
      msg.contains('no such host') ||
      msg.contains('failed host lookup')) {
    return ApiErrorType.invalidAddressOrPort;
  }
  if (msg.contains('connection refused')) {
    return ApiErrorType.backendUnavailable;
  }
  if (msg.contains('network is unreachable') ||
      msg.contains('no route to host')) {
    return ApiErrorType.networkUnavailable;
  }
  return ApiErrorType.serverUnreachable;
}

String _socketMessage(SocketException e) {
  switch (_socketType(e)) {
    case ApiErrorType.invalidAddressOrPort:
    case ApiErrorType.backendUnavailable:
    case ApiErrorType.networkUnavailable:
    case ApiErrorType.timeout:
    case ApiErrorType.serverUnreachable:
      return kMsgSunucuyaUlasilamiyor;
    default:
      return kMsgSunucuyaUlasilamiyor;
  }
}
