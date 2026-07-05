import 'package:deniz_app/domain/marine_consensus_value.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MarineConsensusValue parses and handles null', () {
    final v = MarineConsensusValue.fromJson({
      'final_value': 22.5,
      'unit': '°C',
      'confidence': 0.6,
      'source_count': 1,
      'disagreement_level': 'unknown',
      'provider_values': {'open_meteo': 22.5},
    });
    expect(v.finalValue, 22.5);
    expect(v.hasValue, isTrue);
    expect(MarineConsensusValue.fromJson(null).hasValue, isFalse);
  });
}
