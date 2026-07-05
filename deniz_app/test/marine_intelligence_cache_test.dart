import 'package:deniz_app/domain/marine_intelligence_report.dart';
import 'package:deniz_app/services/marine_intelligence_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('MarineIntelligenceCache save and load', () async {
    SharedPreferences.setMockInitialValues({});
    final cache = MarineIntelligenceCache();
    final report = MarineIntelligenceReport.fromJson({
      'coordinate': {'lat': 37.0, 'lon': 27.0},
      'weather': {},
      'wind': {},
      'marine': {},
      'astronomy': {},
      'fishing_score': {'suitability_score': 70, 'risk_score': 10},
      'consensus_summary': {},
      'updated_at': '2024-06-15T06:00:00+00:00',
    });
    await cache.saveLastReport(report);
    final loaded = await cache.loadLastReport();
    expect(loaded?.coordinate.lat, 37.0);
    expect(await cache.lastReportSyncedAt(), isNotNull);
  });
}
