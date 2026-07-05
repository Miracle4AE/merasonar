import 'dart:convert';

import 'package:deniz_app/domain/dashboard_overview.dart';
import 'package:deniz_app/domain/marine_intelligence_report.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/services/dashboard_overview_service.dart';
import 'package:deniz_app/services/marine_intelligence_cache.dart';
import 'package:deniz_app/widgets/dashboard/v2/dashboard_v2_forecast_card.dart';
import 'package:deniz_app/widgets/dashboard/v2/dashboard_v2_live_score_card.dart';
import 'package:deniz_app/widgets/dashboard/v2/dashboard_v2_tide_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

MarineIntelligenceReport _reportWithExtras() {
  return MarineIntelligenceReport.fromJson({
    'coordinate': {'lat': 41.01, 'lon': 29.0},
    'weather': {
      'temperature_c': {'final_value': 22, 'confidence': 0.8, 'source_count': 1},
    },
    'wind': {
      'speed_kmh': {'final_value': 12, 'confidence': 0.8, 'source_count': 1},
      'direction_text': 'KD',
    },
    'marine': {
      'wave_height_m': {'final_value': 0.8, 'confidence': 0.8, 'source_count': 1},
      'ocean_current_velocity_mps': {
        'final_value': 0.35,
        'confidence': 0.8,
        'source_count': 1,
      },
    },
    'astronomy': {'moon_illumination_pct': 42},
    'fishing_score': {
      'suitability_score': 65,
      'risk_score': 20,
      'confidence': 0.7,
      'general_advice_tr': 'Koşullar orta.',
    },
    'consensus_summary': {'overall_confidence': 0.7},
    'decision': {'fishing_decision': 'marginal', 'go_score': 58},
    'decision_timeline': [
      {'time': '06:00', 'go_score': 60, 'decision': 'marginal'},
    ],
    'historical': {
      'day_count': 7,
      'days': [
        for (var d = 4; d <= 10; d++)
          {
            'date': '2026-07-${d.toString().padLeft(2, '0')}',
            'day_label': d == 4 ? 'Bugün' : 'Pzt',
            'temp_max_c': 28 - (d - 4),
            'temp_min_c': 18,
            'precipitation_probability_pct': 10 * d,
            'wind_max_kmh': 14,
            'weather_code': 0,
            'weather_label_tr': 'Açık',
          },
      ],
    },
    'tide': {
      'tide_provider_available': false,
      'display_mode': 'sea_movement',
      'chart_label_tr': 'Dalga (m)',
      'summary_tr': 'Dalga 0.8 m · Akıntı 0.35 m/s',
      'context_tr': 'Gelgit sağlayıcısı bağlı değil.',
      'ocean_current_velocity_mps': 0.35,
      'wave_height_m': 0.8,
      'hourly_wave_points': [
        {'time': '06:00', 'wave_height_m': 0.6},
        {'time': '12:00', 'wave_height_m': 0.9},
      ],
    },
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DashboardOverviewService fresh data', () {
    test('live score uses report when live cache missing', () async {
      SharedPreferences.setMockInitialValues({});
      final cache = MarineIntelligenceCache();
      await cache.saveLastReport(_reportWithExtras());

      final overview = await DashboardOverviewService(marineCache: cache).load();
      expect(overview.liveScore.hasData, isTrue);
      expect(overview.liveScore.score, 58);
      expect(overview.liveScore.weatherMetric, isNotNull);
      expect(overview.liveScore.seaMetric, isNotNull);
      expect(overview.liveScore.tideCurrentMetric, isNotNull);
    });

    test('summary includes current and wave labels', () async {
      SharedPreferences.setMockInitialValues({});
      final cache = MarineIntelligenceCache();
      await cache.saveLastReport(_reportWithExtras());

      final overview = await DashboardOverviewService(marineCache: cache).load();
      expect(overview.marineReport.currentLabel, contains('m/s'));
      expect(overview.marineReport.waveLabel, contains('m'));
      expect(overview.marineReport.windLabel, contains('km/s'));
    });

    test('forecast parses daily days', () async {
      SharedPreferences.setMockInitialValues({});
      final cache = MarineIntelligenceCache();
      await cache.saveLastReport(_reportWithExtras());

      final overview = await DashboardOverviewService(marineCache: cache).load();
      expect(overview.forecast.hasData, isTrue);
      expect(overview.forecast.days.length, 7);
    });

    test('tide parses wave points', () async {
      SharedPreferences.setMockInitialValues({});
      final cache = MarineIntelligenceCache();
      await cache.saveLastReport(_reportWithExtras());

      final overview = await DashboardOverviewService(marineCache: cache).load();
      expect(overview.tide.hasChartData, isTrue);
      expect(overview.tide.displayMode, DashboardTideDisplayMode.seaMovement);
      expect(overview.tide.wavePoints.length, 2);
    });

    test('cache roundtrip preserves forecast and tide', () async {
      SharedPreferences.setMockInitialValues({});
      final cache = MarineIntelligenceCache();
      final report = _reportWithExtras();
      await cache.saveLastReport(report);

      final raw = (await SharedPreferences.getInstance())
          .getString('marine_intel_last_report_v1');
      final decoded = jsonDecode(raw!) as Map<String, dynamic>;
      expect(decoded['historical'], isA<Map>());
      expect(decoded['tide'], isA<Map>());

      final loaded = await cache.loadLastReport();
      expect(loaded?.historical, isA<Map>());
      expect(loaded?.tide, isA<Map>());
    });

    test('auto refresh includeAiComment false via fetcher', () async {
      SharedPreferences.setMockInitialValues({});
      final cache = MarineIntelligenceCache();
      await cache.saveLastReport(_reportWithExtras());

      var called = false;
      final svc = DashboardOverviewService(
        marineCache: cache,
        fetchMarineReport: ({
          required double lat,
          required double lon,
          bool forceRefresh = false,
        }) async {
          called = true;
          return _reportWithExtras();
        },
      );

      final result = await svc.refreshTimelineReport();
      expect(called, isTrue);
      expect(result.fetchCalled, isTrue);
    });
  });

  group('Dashboard cards fresh data UI', () {
    Widget wrap(Widget child, {double height = 320, double width = 400}) =>
        MaterialApp(
          home: Scaffold(
            body: SizedBox(height: height, width: width, child: child),
          ),
        );

    testWidgets('live score card shows metric values not all dash', (tester) async {
      await tester.pumpWidget(
        wrap(
          DashboardV2LiveScoreCard(
            summary: const DashboardLiveScoreSummary(
              score: 58,
              rating: 'Orta',
              weatherMetric: 85,
              seaMetric: 82,
              tideCurrentMetric: 80,
              moonMetric: 58,
              fishMetric: 58,
            ),
            marineReport: const DashboardMarineReportSummary(
              suitabilityScore: 65,
              goScore: 58,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hava'), findsOneWidget);
      expect(find.text('85'), findsOneWidget);
      expect(find.text(kPremiumDashPlaceholderDash), findsNothing);
    });

    testWidgets('forecast card renders 7 day data when present', (tester) async {
      await tester.pumpWidget(
        wrap(
          DashboardV2ForecastCard(
            summary: DashboardForecastSummary(
              days: List.generate(
                7,
                (i) => DashboardForecastDay(
                  dateLabel: '0${4 + i}.07',
                  dayLabel: i == 0 ? 'Bugün' : 'Pzt',
                  tempMaxC: 28 - i,
                  tempMinC: 18,
                ),
              ),
              label: '7 günlük veri mevcut',
            ),
          ),
        ),
      );
      expect(find.text('Bugün'), findsOneWidget);
      expect(find.textContaining('18–28°'), findsOneWidget);
    });

    testWidgets('forecast card hides waiting message when days present', (tester) async {
      await tester.pumpWidget(
        wrap(
          DashboardV2ForecastCard(
            summary: DashboardForecastSummary(
              days: const [
                DashboardForecastDay(dateLabel: '04.07', dayLabel: 'Bugün', tempMaxC: 25),
              ],
            ),
          ),
        ),
      );
      expect(find.text(kPremiumDashForecastWaitingProvider), findsNothing);
      expect(find.text(kPremiumDashForecastFetchFailed), findsNothing);
    });

    testWidgets('tide card shows sea movement mode when no provider', (tester) async {
      await tester.pumpWidget(
        wrap(
          DashboardV2TideCard(
            summary: DashboardTideSummary(
              label: 'Dalga 0.8 m',
              wavePoints: const [
                DashboardTidePoint(time: '06:00', value: 0.6),
                DashboardTidePoint(time: '12:00', value: 0.9),
              ],
              displayMode: DashboardTideDisplayMode.seaMovement,
              chartLabel: kPremiumDashTideWaveChartLabel,
            ),
          ),
        ),
      );
      expect(find.textContaining('Deniz Hareketi'), findsOneWidget);
      expect(find.textContaining('Dalga (m)'), findsOneWidget);
    });
  });
}
