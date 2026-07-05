import 'package:deniz_app/domain/marine_compare.dart';
import 'package:deniz_app/domain/marine_intelligence_report.dart';
import 'package:deniz_app/domain/marine_saved_spot.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/map/widgets/marine/marine_saved_spots_panel.dart';
import 'package:deniz_app/screens/marine_compare_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

MarineIntelligenceReport _sampleReport({int goScore = 75}) {
  return MarineIntelligenceReport.fromJson({
    'coordinate': {'lat': 36.62, 'lon': 29.11},
    'weather': {},
    'wind': {},
    'marine': {},
    'astronomy': {},
    'fishing_score': {
      'suitability_score': goScore,
      'risk_score': 20,
      'confidence': 0.8,
    },
    'consensus_summary': {'overall_confidence': 0.8},
    'decision': {
      'fishing_decision': 'good',
      'go_score': goScore,
      'wait_score': 100 - goScore,
      'short_summary_tr': 'Test',
    },
    'decision_timeline': [
      {
        'time': '06:00',
        'go_score': goScore,
        'risk_score': 15,
        'decision': 'good',
        'reason_tr': 'Sabah uygun',
        'is_best_slot': true,
      },
    ],
    'updated_at': '2026-07-03T06:00:00Z',
  });
}

MarineCompareResponse _sampleCompareResponse({
  String winner = 'left',
  bool withCaptain = true,
}) {
  return MarineCompareResponse(
    leftReport: _sampleReport(goScore: 75),
    rightReport: _sampleReport(goScore: 55),
    comparison: MarineComparison(
      winner: winner,
      winnerLabel: winner == 'left' ? kMarineComparePointA : kMarineComparePointB,
      scoreDelta: winner == 'tie' ? 2 : 20,
      riskDelta: -5,
      confidenceDelta: 8,
      decisionDeltaTr: 'Sol taraf daha uygun görünüyor',
      mainReasons: const ['Go skoru farkı belirgin', 'Risk daha düşük'],
      riskNoteTr: 'Her iki noktada da dalga izlenmeli',
      summaryTr: winner == 'tie'
          ? 'İki nokta benzer görünüyor'
          : 'A noktası daha mantıklı',
    ),
    captainComment: withCaptain
        ? MarineAiComment.fromJson({
            'source': 'fallback',
            'summary_tr': 'Captain Atlas: A noktası bugün bir adım önde.',
            'best_time_window_tr': 'Sabah 06:00–09:00',
            'risk_note_tr': 'Öğleden sonra rüzgar artabilir.',
            'fallback_reason': 'ai_disabled',
          })
        : null,
    updatedAt: '2026-07-03T06:00:00Z',
  );
}

MarineSavedSpot _spot(String id, String name) {
  return MarineSavedSpot.fromJson({
    'id': id,
    'name': name,
    'lat': 36.62,
    'lon': 29.11,
    'favorite': false,
    'created_at': 't',
    'updated_at': 't',
    'visit_count': 0,
    'personal_tags': [],
  });
}

void main() {
  testWidgets('MarineCompareScreen smoke render', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MarineCompareScreen(serverIp: '127.0.0.1'),
      ),
    );
    expect(find.text(kMarineCompareScreenTitle), findsOneWidget);
    expect(find.text(kMarineComparePointA), findsWidgets);
    expect(find.text(kMarineComparePointB), findsWidgets);
    expect(find.text(kMarineCompareButton), findsOneWidget);
  });

  testWidgets('MarineCompareScreen winner card render', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: _ComparePreview(result: _sampleCompareResponse()),
      ),
    );
    expect(find.text(kMarineCompareWinnerTitle), findsOneWidget);
    expect(find.text(kMarineComparePointA), findsWidgets);
    expect(find.text(kMarineCompareMainReasons), findsOneWidget);
    expect(find.text('Go skoru farkı belirgin'), findsOneWidget);
  });

  testWidgets('MarineCompareScreen tie card render', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: _ComparePreview(
          result: _sampleCompareResponse(winner: 'tie', withCaptain: false),
        ),
      ),
    );
    expect(find.text(kMarineCompareTieTitle), findsOneWidget);
    expect(find.text(kMarineCompareCaptainTitle), findsNothing);
  });

  testWidgets('MarineCompareScreen captain comment render', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: _ComparePreview(result: _sampleCompareResponse(withCaptain: true)),
      ),
    );
    expect(find.text(kMarineCompareCaptainTitle), findsOneWidget);
    expect(find.textContaining('bugün bir adım'), findsOneWidget);
  });

  testWidgets('MarineSavedSpotsPanel two selection compare mode', (tester) async {
    MarineSavedSpot? left;
    MarineSavedSpot? right;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MarineSavedSpotsPanel(
            spots: [_spot('s1', 'Spot A'), _spot('s2', 'Spot B')],
            onRefresh: (_) async {},
            onDelete: (_) async {},
            onToggleFavorite: (_) async {},
            onAddCatch: (_) async {},
            onShowCatches: (_) async {},
            onCompareSpots: (l, r) {
              left = l;
              right = r;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text(kMarineCompareSelectMode));
    await tester.pumpAndSettle();

    expect(find.text(kMarineCompareSelectHint), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(2));

    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    await tester.tap(find.byType(Checkbox).last);
    await tester.pump();

    await tester.tap(find.text(kMarineCompareButton));
    await tester.pump();

    expect(left?.id, 's1');
    expect(right?.id, 's2');
  });
}

class _ComparePreview extends StatelessWidget {
  const _ComparePreview({required this.result});

  final MarineCompareResponse result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(result.comparison.summaryTr),
          const SizedBox(height: 16),
          _ComparisonResultPreview(result: result),
        ],
      ),
    );
  }
}

class _ComparisonResultPreview extends StatelessWidget {
  const _ComparisonResultPreview({required this.result});

  final MarineCompareResponse result;

  @override
  Widget build(BuildContext context) {
    final cmp = result.comparison;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(cmp.isTie ? kMarineCompareTieTitle : kMarineCompareWinnerTitle),
        if (!cmp.isTie && cmp.winnerLabel != null) Text(cmp.winnerLabel!),
        Text(cmp.summaryTr),
        Text(kMarineCompareMainReasons),
        for (final r in cmp.mainReasons) Text(r),
        if (result.captainComment != null) ...[
          Text(kMarineCompareCaptainTitle),
          Text(result.captainComment!.summaryTr),
          if (result.captainComment!.bestTimeWindowTr != null)
            Text('$kMarineAiBestTimeLabel: ${result.captainComment!.bestTimeWindowTr}'),
        ],
      ],
    );
  }
}
