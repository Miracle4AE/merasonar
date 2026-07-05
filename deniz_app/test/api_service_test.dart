import 'package:deniz_app/api_service.dart';
import 'package:deniz_app/domain/marine_compare.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('ApiService.checkHealth', () {
    test('2xx yanıtında sunucu erişilebilir', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/health');
        return http.Response(
          '{"status":"ok","service":"MeraSonar API","version":"1.0.0"}',
          200,
        );
      });
      final api = ApiService(
        serverBaseUrl: 'http://127.0.0.1:8000',
        client: client,
      );
      final r = await api.checkHealth();
      expect(r.ok, isTrue);
      expect(r.message, 'Sunucu erişilebilir.');
      expect(r.receivedNonMerasonarResponse, isFalse);
    });

    test('4xx yanıtında sağlıklı değil', () async {
      final client = MockClient(
        (request) async => http.Response('err', 503),
      );
      final api = ApiService(
        serverBaseUrl: 'http://127.0.0.1:8000',
        client: client,
      );
      final r = await api.checkHealth();
      expect(r.ok, isFalse);
      expect(r.message, 'Sunucu beklenenden farklı yanıt verdi.');
      expect(r.receivedNonMerasonarResponse, isFalse);
    });

    test('2xx ancak gövde MeraSonar değil — başarısız', () async {
      final client = MockClient(
        (request) async =>
            http.Response('{"status":"online","modules_loaded":true}', 200),
      );
      final api = ApiService(
        serverBaseUrl: 'http://127.0.0.1:8000',
        client: client,
      );
      final r = await api.checkHealth();
      expect(r.ok, isFalse);
      expect(r.message, 'Sunucu MeraSonar API doğrulanamadı.');
      expect(r.receivedNonMerasonarResponse, isTrue);
    });
  });

  test(
      'FishingZoneResponse: geo_map_display_allowed ve is_geo_referenced esnek parse',
      () {
    final r = FishingZoneResponse.fromJson({
      'boat': {
        'raw_gps': {'lat': 37.0, 'lon': 27.0},
        'smoothed_gps': {'lat': 37.0, 'lon': 27.0},
      },
      'ranked_hotspots': <dynamic>[],
      'geo_map_display_allowed': 1,
      'is_geo_referenced': 'true',
      'calibration_quality': '0.88',
      'transform_confidence': 0.91,
      'user_warning_tr': '  ',
    });
    expect(r.geoMapDisplayAllowed, isTrue);
    expect(r.isGeoReferenced, isTrue);
    expect(r.calibrationQuality, closeTo(0.88, 0.001));
    expect(r.transformConfidence, closeTo(0.91, 0.001));
    expect(r.userWarningTr, isNull);
  });

  group('Marine Intelligence API', () {
    const sampleReport = '''
{
  "coordinate": {"lat": 37.0, "lon": 27.0},
  "weather": {},
  "wind": {},
  "marine": {},
  "astronomy": {},
  "fishing_score": {"suitability_score": 70, "risk_score": 15, "confidence": 0.6},
  "consensus_summary": {"overall_confidence": 0.6},
  "provider_status": {"providers": {}},
  "updated_at": "2024-06-15T06:00:00+00:00",
  "cache_hit": false,
  "partial_data": false
}
''';

    test('fetchMarineCoordinateReport mock', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/marine_intelligence/coordinate');
        return http.Response(sampleReport, 200);
      });
      final api = ApiService(
        serverBaseUrl: 'http://127.0.0.1:8000',
        client: client,
      );
      final report = await api.fetchMarineCoordinateReport(lat: 37, lon: 27);
      expect(report.fishingScore.suitabilityScore, 70);
    });

    test('saved spots CRUD mock', () async {
      var deleted = false;
      final client = MockClient((request) async {
        final path = request.url.path;
        if (path == '/api/v1/marine_intelligence/saved_spots' &&
            request.method == 'POST') {
          return http.Response(
            '{"id":"s1","name":"Spot","lat":37,"lon":27,"favorite":false,'
            '"created_at":"t","updated_at":"t","visit_count":0,"personal_tags":[]}',
            200,
          );
        }
        if (path == '/api/v1/marine_intelligence/saved_spots' &&
            request.method == 'GET') {
          return http.Response(
            '{"spots":[{"id":"s1","name":"Spot","lat":37,"lon":27,'
            '"favorite":false,"created_at":"t","updated_at":"t","visit_count":0}],'
            '"count":1}',
            200,
          );
        }
        if (path.endsWith('/refresh') && request.method == 'POST') {
          return http.Response(
            '{"spot":{"id":"s1","name":"Spot","lat":37,"lon":27,'
            '"favorite":false,"created_at":"t","updated_at":"t","visit_count":1},'
            '"report":$sampleReport}',
            200,
          );
        }
        if (request.method == 'DELETE') {
          deleted = true;
          return http.Response('{"deleted":true,"id":"s1"}', 200);
        }
        return http.Response('not found', 404);
      });
      final api = ApiService(
        serverBaseUrl: 'http://127.0.0.1:8000',
        client: client,
      );
      final created = await api.createMarineSavedSpot(
        name: 'Spot',
        lat: 37,
        lon: 27,
      );
      expect(created.id, 's1');
      final list = await api.fetchMarineSavedSpots();
      expect(list.count, 1);
      final refreshed = await api.refreshMarineSavedSpot('s1');
      expect(refreshed.spot.visitCount, 1);
      await api.deleteMarineSavedSpot('s1');
      expect(deleted, isTrue);
    });

    test('catch intelligence mock', () async {
      final client = MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/catch') && request.method == 'POST') {
          return http.Response(
            '{"catch":{"id":"c1","spot_id":"s1","species":"Levrek","caught_at":"t",'
            '"created_at":"t","updated_at":"t"},'
            '"spot":{"id":"s1","name":"Spot","lat":37,"lon":27,"favorite":false,'
            '"created_at":"t","updated_at":"t","visit_count":0,"personal_tags":[]},'
            '"learning_summary":{"spot_id":"s1","catch_count":1,"top_species":"Levrek",'
            '"spot_reputation":58,"spot_level":"Silver","message_tr":"ilk"}}',
            200,
          );
        }
        if (path.endsWith('/catches') && request.method == 'GET') {
          return http.Response(
            '{"catches":[{"id":"c1","spot_id":"s1","species":"Levrek","caught_at":"t",'
            '"created_at":"t","updated_at":"t"}],"count":1,'
            '"summary":{"spot_id":"s1","catch_count":1,"message_tr":"ok"}}',
            200,
          );
        }
        if (path.contains('/catches/') && request.method == 'PATCH') {
          return http.Response(
            '{"catch":{"id":"c1","spot_id":"s1","species":"Cupura","caught_at":"t",'
            '"created_at":"t","updated_at":"t"},'
            '"learning_summary":{"spot_id":"s1","catch_count":1,"top_species":"Cupura",'
            '"message_tr":"ok"}}',
            200,
          );
        }
        if (path.contains('/catches/') && request.method == 'DELETE') {
          return http.Response(
            '{"deleted":true,"id":"c1","spot_id":"s1",'
            '"learning_summary":{"spot_id":"s1","catch_count":0,"message_tr":"ok"}}',
            200,
          );
        }
        if (path.endsWith('/learning_summaries') && request.method == 'POST') {
          return http.Response(
            '{"summaries":{"s1":{"spot_id":"s1","catch_count":1,"top_species":"Levrek",'
            '"message_tr":"ok"}},"missing_spot_ids":[]}',
            200,
          );
        }
        if (path.endsWith('/learning_summary')) {
          return http.Response(
            '{"spot_id":"s1","catch_count":1,"top_species":"Levrek","spot_reputation":58,'
            '"spot_level":"Silver","message_tr":"ok"}',
            200,
          );
        }
        return http.Response('not found', 404);
      });
      final api = ApiService(
        serverBaseUrl: 'http://127.0.0.1:8000',
        client: client,
      );
      final created = await api.createCatchForSpot(
        's1',
        species: 'Levrek',
        caughtAt: '2026-07-03T06:42:00Z',
      );
      expect(created.catchRecord.species, 'Levrek');
      final list = await api.fetchCatchesForSpot('s1');
      expect(list.count, 1);
      final summary = await api.fetchLearningSummary('s1');
      expect(summary.topSpecies, 'Levrek');
      final bulk = await api.fetchLearningSummaries(['s1']);
      expect(bulk.summaries['s1']?.topSpecies, 'Levrek');
      final updated = await api.updateCatch('c1', species: 'Cupura');
      expect(updated.catchRecord.species, 'Cupura');
      final deleted = await api.deleteCatch('c1');
      expect(deleted.deleted, isTrue);
      expect(deleted.summary?.catchCount, 0);
    });

    test('fetchMarineCompare mock', () async {
      const compareBody = '''
{
  "left_report": {
    "coordinate": {"lat": 37.0, "lon": 27.0},
    "weather": {}, "wind": {}, "marine": {}, "astronomy": {},
    "fishing_score": {"suitability_score": 70, "risk_score": 15, "confidence": 0.6},
    "consensus_summary": {"overall_confidence": 0.6},
    "updated_at": "2024-06-15T06:00:00+00:00"
  },
  "right_report": {
    "coordinate": {"lat": 37.1, "lon": 27.1},
    "weather": {}, "wind": {}, "marine": {}, "astronomy": {},
    "fishing_score": {"suitability_score": 55, "risk_score": 25, "confidence": 0.5},
    "consensus_summary": {"overall_confidence": 0.5},
    "updated_at": "2024-06-15T06:00:00+00:00"
  },
  "comparison": {
    "winner": "left",
    "winner_label": "A",
    "score_delta": 20,
    "risk_delta": -10,
    "confidence_delta": 10,
    "decision_delta_tr": "Sol daha uygun",
    "main_reasons": ["Go skoru farki"],
    "summary_tr": "A onde"
  },
  "captain_comment": null,
  "updated_at": "2026-07-03T06:00:00Z"
}
''';
      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/marine_intelligence/compare') {
          return http.Response(compareBody, 200);
        }
        return http.Response('not found', 404);
      });
      final api = ApiService(
        serverBaseUrl: 'http://127.0.0.1:8000',
        client: client,
      );
      final resp = await api.fetchMarineCompare(
        left: const MarineCompareSide(lat: 36.62, lon: 29.11, label: 'A'),
        right: const MarineCompareSide(lat: 36.64, lon: 29.14, label: 'B'),
      );
      expect(resp.comparison.winner, 'left');
      expect(resp.comparison.scoreDelta, 20);
      expect(resp.captainComment, isNull);
    });
  });
}
