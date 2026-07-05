import 'package:deniz_app/domain/marine_catch_record.dart';
import 'package:deniz_app/domain/marine_learning_summary.dart';
import 'package:deniz_app/domain/marine_saved_spot.dart';
import 'package:flutter_test/flutter_test.dart';
void main() {
  test('MarineCatchRecord parses fields', () {
    final record = MarineCatchRecord.fromJson({
      'id': 'c1',
      'spot_id': 's1',
      'species': 'Levrek',
      'length_cm': 53,
      'weight_kg': 2.1,
      'bait': 'Silikon',
      'method': 'Spin',
      'caught_at': '2026-07-03T06:42:00Z',
      'notes': 'Sabah',
      'created_at': '2026-07-03T07:00:00Z',
      'updated_at': '2026-07-03T07:00:00Z',
    });
    expect(record.species, 'Levrek');
    expect(record.weightKg, 2.1);
    expect(record.spotId, 's1');
  });

  test('MarineLearningSummary parses fields', () {
    final summary = MarineLearningSummary.fromJson({
      'spot_id': 's1',
      'catch_count': 3,
      'top_species': 'Levrek',
      'last_success_date': '2026-07-03T06:42:00Z',
      'average_weight_kg': 1.7,
      'spot_reputation': 72,
      'spot_level': 'Gold',
      'message_tr': 'Bu spot için birkaç başarılı kayıt oluşmaya başladı.',
    });
    expect(summary.catchCount, 3);
    expect(summary.topSpecies, 'Levrek');
    expect(summary.spotLevel, 'Gold');
    expect(summary.spotReputation, 72);
  });

  test('BulkLearningSummariesResponse parses map', () {
    final resp = BulkLearningSummariesResponse.fromJson({
      'summaries': {
        's1': {
          'spot_id': 's1',
          'catch_count': 2,
          'top_species': 'Levrek',
          'message_tr': 'ok',
        },
        'missing': null,
      },
      'missing_spot_ids': ['missing'],
    });
    expect(resp.summaries['s1']?.catchCount, 2);
    expect(resp.summaries['missing'], isNull);
    expect(resp.missingSpotIds, ['missing']);
  });

  test('MarineSpotDeleteResponse parses deleted_catches', () {
    final resp = MarineSpotDeleteResponse.fromJson({
      'deleted': true,
      'id': 's1',
      'deleted_catches': 3,
    });
    expect(resp.deletedCatches, 3);
  });
}