import 'package:deniz_app/domain/marine_saved_spot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MarineSavedSpot parses with optional fields', () {
    final spot = MarineSavedSpot.fromJson({
      'id': 'abc-123',
      'name': 'Test Spot',
      'lat': 36.6,
      'lon': 29.1,
      'favorite': true,
      'created_at': '2024-01-01T00:00:00Z',
      'updated_at': '2024-01-02T00:00:00Z',
      'visit_count': 2,
      'personal_tags': ['levrek'],
      'last_report': null,
    });
    expect(spot.id, 'abc-123');
    expect(spot.favorite, isTrue);
    expect(spot.personalTags, ['levrek']);
    expect(spot.lastReport, isNull);
  });
}
