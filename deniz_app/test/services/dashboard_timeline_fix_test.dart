import 'dart:convert';

import 'package:deniz_app/domain/dashboard_overview.dart';
import 'package:deniz_app/domain/marine_intelligence_report.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/services/dashboard_overview_service.dart';
import 'package:deniz_app/services/marine_intelligence_cache.dart';
import 'package:deniz_app/widgets/dashboard/v2/dashboard_v2_day_timeline_card.dart';
import 'package:deniz_app/widgets/dashboard/v2/premium_dashboard_v2_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

MarineIntelligenceReport _sampleReport({
  List<Map<String, dynamic>>? timeline,
  bool cacheHit = false,
}) {
  return MarineIntelligenceReport.fromJson({
    'coordinate': {'lat': 41.01, 'lon': 29.0},
    'weather': {},
    'wind': {},
    'marine': {},
    'astronomy': {},
    'fishing_score': {
      'suitability_score': 75,
      'risk_score': 20,
      'confidence': 0.6,
    },
    'consensus_summary': {'overall_confidence': 0.6},
    'decision': {
      'fishing_decision': 'good',
      'go_score': 70,
    },
    'decision_timeline': timeline ??
        [
          {
            'time': '06:00–09:00',
            'go_score': 78,
            'decision': 'good',
          },
          {
            'time': '09:00–12:00',
            'go_score': 55,
            'decision': 'marginal',
          },
        ],
    'cache_hit': cacheHit,
    'updated_at': '2026-07-04T10:00:00Z',
  });
}

/// Eski release'teki sahte 6 satır (saat + "--").
List<DashboardTimelineSlot> _legacyFakeSlots() {
  const times = [
    '06:00–09:00',
    '09:00–12:00',
    '12:00–15:00',
    '15:00–18:00',
    '18:00–21:00',
    '21:00–00:00',
  ];
  return [
    for (final t in times)
      DashboardTimelineSlot(time: t, label: kPremiumDashPlaceholderDash),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DashboardOverviewService timeline', () {
    test('uses cached report decisionTimeline', () async {
      SharedPreferences.setMockInitialValues({});
      final cache = MarineIntelligenceCache();
      await cache.saveLastReport(_sampleReport());

      final svc = DashboardOverviewService(marineCache: cache);
      final overview = await svc.load();

      expect(overview.timeline.hasData, isTrue);
      expect(overview.timeline.displayState, DashboardTimelineDisplayState.hasData);
      expect(overview.timeline.slots.length, 2);
      expect(overview.timeline.slots.first.time, '06:00–09:00');
    });

    test('auto refresh calls fetch when coordinate exists', () async {
      SharedPreferences.setMockInitialValues({});
      final cache = MarineIntelligenceCache();
      await cache.saveLastReport(_sampleReport(timeline: []));

      var fetchCalled = false;

      final svc = DashboardOverviewService(
        marineCache: cache,
        fetchMarineReport: ({
          required double lat,
          required double lon,
          bool forceRefresh = false,
        }) async {
          fetchCalled = true;
          expect(lat, 41.01);
          expect(lon, 29.0);
          return _sampleReport();
        },
      );

      final refreshed = await svc.refreshTimelineReport();
      expect(fetchCalled, isTrue);
      expect(refreshed.fetchCalled, isTrue);
      expect(refreshed.cacheSaved, isTrue);
      expect(refreshed.decisionTimelineLength, 2);

      final cached = await cache.loadLastReport();
      expect(cached?.decisionTimeline.length, 2);

      final overview = await svc.load();
      expect(overview.timeline.hasData, isTrue);
      expect(overview.timeline.slots.length, 2);
    });

    test('auto refresh does NOT call fetch when no coordinate', () async {
      SharedPreferences.setMockInitialValues({});
      var fetchCalled = false;

      final svc = DashboardOverviewService(
        fetchMarineReport: ({
          required double lat,
          required double lon,
          bool forceRefresh = false,
        }) async {
          fetchCalled = true;
          return _sampleReport();
        },
      );

      final result = await svc.refreshTimelineReport();
      expect(fetchCalled, isFalse);
      expect(result.coordinateExists, isFalse);
      expect(result.fetchCalled, isFalse);
    });

    test('report without timeline shows reportWithoutTimeline state', () async {
      SharedPreferences.setMockInitialValues({});
      final cache = MarineIntelligenceCache();
      await cache.saveLastReport(_sampleReport(timeline: []));

      final svc = DashboardOverviewService(marineCache: cache);
      final overview = await svc.load();

      expect(overview.timeline.hasData, isFalse);
      expect(
        overview.timeline.resolvedDisplayState,
        DashboardTimelineDisplayState.reportWithoutTimeline,
      );
    });

    test('no coordinate shows noCoordinate state', () async {
      SharedPreferences.setMockInitialValues({});
      final svc = DashboardOverviewService();
      final overview = await svc.load();

      expect(
        overview.timeline.resolvedDisplayState,
        DashboardTimelineDisplayState.noCoordinate,
      );
    });

    test('legacy placeholder slots are not meaningful', () {
      expect(DashboardTimelineSummary.isMeaningfulSlot(
        const DashboardTimelineSlot(time: '06:00–09:00', label: '--'),
      ), isFalse);
      expect(_legacyFakeSlots().every(
        (s) => !DashboardTimelineSummary.isMeaningfulSlot(s),
      ), isTrue);
    });
  });

  group('MarineIntelligenceCache decisionTimeline', () {
    test('preserves decisionTimeline through toJson/fromJson', () async {
      SharedPreferences.setMockInitialValues({});
      final cache = MarineIntelligenceCache();
      final report = _sampleReport();
      await cache.saveLastReport(report);

      final raw = (await SharedPreferences.getInstance())
          .getString('marine_intel_last_report_v1');
      expect(raw, isNotNull);
      final decoded = jsonDecode(raw!) as Map<String, dynamic>;
      expect(decoded['decision_timeline'], isA<List>());
      expect((decoded['decision_timeline'] as List).length, 2);

      final loaded = await cache.loadLastReport();
      expect(loaded?.decisionTimeline.length, 2);
      expect(loaded?.decisionTimeline.first.decision, 'good');
    });
  });

  group('DashboardV2DayTimelineCard', () {
    Widget wrapCard(Widget child) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 280,
            width: 360,
            child: child,
          ),
        ),
      );
    }

    testWidgets('with data does not show Veri yok', (tester) async {
      await tester.pumpWidget(
        wrapCard(
          DashboardV2DayTimelineCard(
            summary: DashboardTimelineSummary(
              displayState: DashboardTimelineDisplayState.hasData,
              slots: const [
                DashboardTimelineSlot(
                  time: '06:00–09:00',
                  label: 'Uygun · 78',
                  decision: 'good',
                  goScore: 78,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text(kPremiumDashNoData), findsNothing);
      expect(find.text('06:00–09:00'), findsOneWidget);
      expect(find.text('78'), findsOneWidget);
    });

    testWidgets('empty + no coordinate: no repeated Veri yok rows', (tester) async {
      await tester.pumpWidget(
        wrapCard(
          DashboardV2DayTimelineCard(
            summary: const DashboardTimelineSummary(
              displayState: DashboardTimelineDisplayState.noCoordinate,
            ),
            onMarineTap: () {},
          ),
        ),
      );

      expect(find.text(kPremiumDashNoData), findsNothing);
      expect(find.text('06:00–09:00'), findsNothing);
      expect(find.text(kPremiumDashTimelineNoCoordinate), findsOneWidget);
      expect(find.text(kPremiumDashTimelineAnalyzeCta), findsOneWidget);
    });

    testWidgets('empty + report exists: no Veri yok, shows Güncelle', (tester) async {
      await tester.pumpWidget(
        wrapCard(
          DashboardV2DayTimelineCard(
            summary: const DashboardTimelineSummary(
              displayState: DashboardTimelineDisplayState.reportWithoutTimeline,
            ),
            onRefreshTap: () {},
          ),
        ),
      );

      expect(find.text(kPremiumDashNoData), findsNothing);
      expect(find.text('06:00–09:00'), findsNothing);
      expect(find.text(kPremiumDashTimelineNoHourlyWindow), findsOneWidget);
      expect(find.text(kPremiumDashTimelineRefreshCta), findsOneWidget);
    });

    testWidgets('legacy fake 6 slots render placeholder not Veri yok rows',
        (tester) async {
      await tester.pumpWidget(
        wrapCard(
          DashboardV2DayTimelineCard(
            summary: DashboardTimelineSummary(
              displayState: DashboardTimelineDisplayState.hasData,
              slots: _legacyFakeSlots(),
            ),
          ),
        ),
      );

      expect(find.text(kPremiumDashNoData), findsNothing);
      expect(find.text('06:00–09:00'), findsNothing);
      expect(find.text(kPremiumDashTimelineNoHourlyWindow), findsOneWidget);
    });

    testWidgets('loading without data shows Güncelleniyor not Veri yok',
        (tester) async {
      await tester.pumpWidget(
        wrapCard(
          const DashboardV2DayTimelineCard(
            summary: DashboardTimelineSummary(
              displayState: DashboardTimelineDisplayState.loading,
              isRefreshing: true,
            ),
          ),
        ),
      );

      expect(find.text(kPremiumDashNoData), findsNothing);
      expect(find.text(kPremiumDashTimelineRefreshing), findsWidgets);
    });
  });

  group('Dashboard smoke timeline', () {
    testWidgets('empty overview timeline has no Veri yok', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1600, 1000)),
            child: Scaffold(
              body: PremiumDashboardV2Layout(
                overview: DashboardOverview.empty,
                serverIp: '127.0.0.1',
                onLiveTap: () {},
                onPhotoTap: () {},
                onMarineTap: () {},
                onCompareTap: () {},
                onCaptainAtlasTap: () {},
              ),
            ),
          ),
        ),
      );

      final timelineCard = find.byType(DashboardV2DayTimelineCard);
      expect(timelineCard, findsOneWidget);
      expect(find.descendant(of: timelineCard, matching: find.text(kPremiumDashNoData)),
          findsNothing);
      expect(find.descendant(of: timelineCard, matching: find.text('06:00–09:00')),
          findsNothing);
    });
  });
}
