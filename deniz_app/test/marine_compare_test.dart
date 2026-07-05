import 'package:deniz_app/domain/marine_compare.dart';
import 'package:flutter_test/flutter_test.dart';

const _sampleReportJson = {
  'coordinate': {'lat': 36.62, 'lon': 29.11},
  'weather': {},
  'wind': {},
  'marine': {},
  'astronomy': {},
  'fishing_score': {
    'suitability_score': 75,
    'risk_score': 20,
    'confidence': 0.8,
  },
  'consensus_summary': {'overall_confidence': 0.8},
  'decision': {
    'fishing_decision': 'good',
    'go_score': 75,
    'wait_score': 25,
    'short_summary_tr': 'Sol uygun',
  },
  'updated_at': '2026-07-03T06:00:00Z',
};

const _rightReportJson = {
  'coordinate': {'lat': 36.64, 'lon': 29.14},
  'weather': {},
  'wind': {},
  'marine': {},
  'astronomy': {},
  'fishing_score': {
    'suitability_score': 55,
    'risk_score': 35,
    'confidence': 0.7,
  },
  'consensus_summary': {'overall_confidence': 0.7},
  'decision': {
    'fishing_decision': 'borderline',
    'go_score': 55,
    'wait_score': 45,
    'short_summary_tr': 'Sağ sınırda',
  },
  'updated_at': '2026-07-03T06:00:00Z',
};

void main() {
  test('MarineCompareSide toJson with coordinates', () {
    const side = MarineCompareSide(
      lat: 36.62,
      lon: 29.11,
      label: 'A Noktası',
    );
    final json = side.toJson();
    expect(json['lat'], 36.62);
    expect(json['lon'], 29.11);
    expect(json['label'], 'A Noktası');
    expect(json.containsKey('spot_id'), isFalse);
  });

  test('MarineCompareSide toJson with spot_id', () {
    const side = MarineCompareSide(spotId: 'spot-1', label: 'Kayalık');
    final json = side.toJson();
    expect(json['spot_id'], 'spot-1');
    expect(json['label'], 'Kayalık');
  });

  test('MarineComparison parses winner left', () {
    final cmp = MarineComparison.fromJson({
      'winner': 'left',
      'winner_label': 'A Noktası',
      'score_delta': 20,
      'risk_delta': -5,
      'confidence_delta': 10,
      'decision_delta_tr': 'Sol taraf daha uygun',
      'main_reasons': ['Go skoru daha yüksek'],
      'risk_note_tr': 'Risk farkı düşük',
      'summary_tr': 'A noktası öne çıkıyor',
    });
    expect(cmp.winner, 'left');
    expect(cmp.isTie, isFalse);
    expect(cmp.scoreDelta, 20);
    expect(cmp.mainReasons, contains('Go skoru daha yüksek'));
  });

  test('MarineComparison parses tie', () {
    final cmp = MarineComparison.fromJson({'winner': 'tie'});
    expect(cmp.isTie, isTrue);
  });

  test('MarineCompareResponse parses full payload', () {
    final resp = MarineCompareResponse.fromJson({
      'left_report': _sampleReportJson,
      'right_report': _rightReportJson,
      'comparison': {
        'winner': 'left',
        'winner_label': 'A Noktası',
        'score_delta': 20,
        'risk_delta': -15,
        'confidence_delta': 10,
        'decision_delta_tr': 'Sol daha uygun',
        'main_reasons': ['Go skoru farkı belirgin'],
        'summary_tr': 'A noktası daha mantıklı',
      },
      'captain_comment': {
        'source': 'fallback',
        'summary_tr': 'Captain Atlas kısa karşılaştırma',
        'fallback_reason': 'ai_disabled',
      },
      'updated_at': '2026-07-03T06:00:00Z',
    });
    expect(resp.leftReport.decision?.goScore, 75);
    expect(resp.rightReport.decision?.goScore, 55);
    expect(resp.comparison.winner, 'left');
    expect(resp.captainComment?.summaryTr, contains('karşılaştırma'));
    expect(resp.updatedAt, isNotEmpty);
  });

  test('MarineCompareResponse null captain_comment', () {
    final resp = MarineCompareResponse.fromJson({
      'left_report': _sampleReportJson,
      'right_report': _rightReportJson,
      'comparison': {'winner': 'tie', 'summary_tr': 'Benzer'},
      'captain_comment': null,
      'updated_at': '2026-07-03T06:00:00Z',
    });
    expect(resp.captainComment, isNull);
  });
}
