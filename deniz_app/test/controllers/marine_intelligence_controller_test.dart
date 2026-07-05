import 'package:deniz_app/controllers/marine_intelligence_controller.dart';
import 'package:deniz_app/domain/marine_intelligence_report.dart';
import 'package:deniz_app/domain/marine_saved_spot.dart';
import 'package:flutter_test/flutter_test.dart';

MarineIntelligenceReport _sampleReport() {
  return MarineIntelligenceReport.fromJson({
    'coordinate': {'lat': 37.0, 'lon': 27.0},
    'weather': {},
    'wind': {},
    'marine': {},
    'astronomy': {},
    'fishing_score': {
      'suitability_score': 75,
      'risk_score': 20,
      'confidence': 0.6,
    },
    'consensus_summary': {},
    'updated_at': '2024-06-15T06:00:00+00:00',
  });
}

MarineSavedSpot _sampleSpot() {
  return MarineSavedSpot.fromJson({
    'id': 'spot-1',
    'name': 'Test Spot',
    'lat': 37.0,
    'lon': 27.0,
    'created_at': '2024-01-01T00:00:00Z',
    'updated_at': '2024-01-01T00:00:00Z',
  });
}

void main() {
  group('MarineIntelligenceController', () {
    test('starts empty', () {
      final c = MarineIntelligenceController();
      expect(c.hasReport, isFalse);
      expect(c.spots, isEmpty);
      expect(c.isBusy, isFalse);
      expect(c.error, isNull);
    });

    test('setCoordinates stores lat/lon', () {
      final c = MarineIntelligenceController();
      c.setCoordinates(lat: 36.62, lon: 29.11);
      expect(c.selectedLat, 36.62);
      expect(c.selectedLon, 29.11);
    });

    test('applyCachedBootstrap fills report and spots once', () {
      final c = MarineIntelligenceController();
      final report = _sampleReport();
      final spots = [_sampleSpot()];

      c.applyCachedBootstrap(
        cachedReport: report,
        cachedSpots: spots,
        syncedAt: '2024-01-01',
      );

      expect(c.report, same(report));
      expect(c.offlineCached, isTrue);
      expect(c.spots, spots);
      expect(c.spotsSyncedAt, '2024-01-01');

      c.applyCachedBootstrap(
        cachedReport: _sampleReport(),
        cachedSpots: [_sampleSpot(), _sampleSpot()],
      );
      expect(c.spots.length, 1);
    });

    test('clearError and dispose reset state', () {
      final c = MarineIntelligenceController()
        ..error = 'hata'
        ..report = _sampleReport()
        ..spots = [_sampleSpot()];

      c.clearError();
      expect(c.error, isNull);

      c.dispose();
      expect(c.report, isNull);
      expect(c.spots, isEmpty);
      expect(c.error, isNull);
    });
  });
}
