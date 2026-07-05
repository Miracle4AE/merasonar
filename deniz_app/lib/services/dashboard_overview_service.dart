import 'package:deniz_app/api_service.dart';
import 'package:deniz_app/domain/dashboard_overview.dart';
import 'package:deniz_app/domain/marine_compare.dart';
import 'package:deniz_app/domain/marine_intelligence_report.dart';
import 'package:deniz_app/domain/marine_saved_spot.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/utils/performance_trace.dart';
import 'package:deniz_app/local_storage_service.dart';
import 'package:deniz_app/map/widgets/marine/intelligence/marine_intelligence_helpers.dart';
import 'package:deniz_app/services/marine_intelligence_cache.dart';
import 'package:flutter/foundation.dart';

/// Son koordinat çözümlemesi sonucu.
class DashboardLastCoordinate {
  const DashboardLastCoordinate({required this.lat, required this.lon});

  final double lat;
  final double lon;
}

/// Arka plan timeline yenileme sonucu (PII yok).
class DashboardTimelineRefreshResult {
  const DashboardTimelineRefreshResult({
    this.coordinateExists = false,
    this.fetchCalled = false,
    this.decisionTimelineLength = 0,
    this.cacheSaved = false,
  });

  final bool coordinateExists;
  final bool fetchCalled;
  final int decisionTimelineLength;
  final bool cacheSaved;
}

/// Sanitize dashboard timeline debug çıktısı.
abstract final class DashboardTimelineDebug {
  static void logRefresh({
    required bool lastCoordinateExists,
    required bool fetchCalled,
    required int decisionTimelineLength,
    required bool cacheSaved,
    required DashboardTimelineDisplayState timelineState,
    required int slotCount,
  }) {
    debugPrint(
      'DashboardTimeline: coord=$lastCoordinateExists '
      'fetch=$fetchCalled '
      'timelineLen=$decisionTimelineLength '
      'cacheSaved=$cacheSaved '
      'state=$timelineState '
      'slots=$slotCount',
    );
  }
}

/// Dashboard verilerini yerel cache ve depolardan birleştirir.
/// İsteğe bağlı arka plan marine report yenilemesi destekler.
class DashboardOverviewService {
  DashboardOverviewService({
    MarineIntelligenceCache? marineCache,
    LocalStorageService? localStorage,
    ApiService? apiService,
    Future<MarineIntelligenceReport> Function({
      required double lat,
      required double lon,
      bool forceRefresh,
    })? fetchMarineReport,
  })  : _marineCache = marineCache ?? MarineIntelligenceCache(),
        _localStorage = localStorage ?? LocalStorageService(),
        _fetchMarineReport = fetchMarineReport ??
            (apiService != null
                ? ({
                    required double lat,
                    required double lon,
                    bool forceRefresh = false,
                  }) =>
                    apiService.fetchMarineCoordinateReport(
                      lat: lat,
                      lon: lon,
                      forceRefresh: forceRefresh,
                      includeAiComment: false,
                    )
                : null);

  final MarineIntelligenceCache _marineCache;
  final LocalStorageService _localStorage;
  final Future<MarineIntelligenceReport> Function({
    required double lat,
    required double lon,
    bool forceRefresh,
  })? _fetchMarineReport;

  /// Test ve ekran katmanı için marine fetch erişimi.
  bool get canRefreshTimeline => _fetchMarineReport != null;
  Future<DashboardOverview> load({
    DashboardConnectionStatus connectionStatus =
        DashboardConnectionStatus.unknown,
    bool timelineRefreshing = false,
  }) {
    return PerformanceTrace.measureAsync('dashboard_overview_load', () async {
    final report = await _marineCache.loadLastReport();
    final spots = await _marineCache.loadSavedSpots();
    final liveScoreRaw = await _marineCache.loadLastLiveScore();
    final compareRaw = await _marineCache.loadLastCompare();
    final catchEntries = await _marineCache.loadRecentCatchSummaries();
    final fishingZone = await _localStorage.loadLatestFishingZoneResponse();
    final reportSyncedAt = await _marineCache.lastReportSyncedAt();

    final lastCoordinate = resolveLastCoordinate(
      report: report,
      spots: spots,
      fishingZone: fishingZone,
    );
    final location = _buildLocation(report, fishingZone);
    final marineReport = _buildMarineReport(report, reportSyncedAt);
    final liveScore = _buildLiveScore(liveScoreRaw, report);
    final savedSpots = _buildSavedSpots(spots);
    final recentCatches = _buildRecentCatches(catchEntries, spots);
    final compare = _buildCompare(compareRaw);
    final captainAtlas = _buildCaptainAtlas(report, compareRaw);
    final timeline = _buildTimeline(
      report: report,
      spots: spots,
      reportSyncedAt: reportSyncedAt,
      hasCoordinate: lastCoordinate != null,
      isRefreshing: timelineRefreshing,
    );
    final tide = _buildTide(report);
    final forecast = _buildForecast(report);
    final mapPreview = _buildMapPreview(
      report: report,
      spots: spots,
      compare: compareRaw,
      fishingZone: fishingZone,
      reportSyncedAt: reportSyncedAt,
    );

    return DashboardOverview(
      connectionStatus: connectionStatus,
      location: location,
      liveScore: liveScore,
      marineReport: marineReport,
      savedSpots: savedSpots,
      recentCatches: recentCatches,
      compare: compare,
      captainAtlas: captainAtlas,
      timeline: timeline,
      tide: tide,
      forecast: forecast,
      mapPreview: mapPreview,
    );
    });
  }

  /// Son koordinatı cache, kayıtlı nokta ve canlı alan kaynaklarından çözer.
  static DashboardLastCoordinate? resolveLastCoordinate({
    MarineIntelligenceReport? report,
    List<MarineSavedSpot> spots = const [],
    FishingZoneResponse? fishingZone,
    DashboardMapPreviewData? mapPreview,
  }) {
    if (report != null) {
      return DashboardLastCoordinate(
        lat: report.coordinate.lat,
        lon: report.coordinate.lon,
      );
    }
    if (mapPreview?.centerLat != null && mapPreview?.centerLon != null) {
      return DashboardLastCoordinate(
        lat: mapPreview!.centerLat!,
        lon: mapPreview.centerLon!,
      );
    }
    for (final spot in _sortedSpots(spots)) {
      if (spot.lastReport != null) {
        return DashboardLastCoordinate(
          lat: spot.lastReport!.coordinate.lat,
          lon: spot.lastReport!.coordinate.lon,
        );
      }
      if (spot.lat != 0 || spot.lon != 0) {
        return DashboardLastCoordinate(lat: spot.lat, lon: spot.lon);
      }
    }
    if (fishingZone != null) {
      final gps = fishingZone.boat.smoothedGps;
      if (gps.lat != 0 || gps.lon != 0) {
        return DashboardLastCoordinate(lat: gps.lat, lon: gps.lon);
      }
    }
    return null;
  }

  /// Son koordinat için marine report yeniler; başarılı olursa cache'e yazar.
  Future<DashboardTimelineRefreshResult> refreshTimelineReport({
    bool forceRefresh = false,
  }) async {
    final fetch = _fetchMarineReport;
    if (fetch == null) {
      return const DashboardTimelineRefreshResult();
    }

    final report = await _marineCache.loadLastReport();
    final spots = await _marineCache.loadSavedSpots();
    final fishingZone = await _localStorage.loadLatestFishingZoneResponse();
    final coordinate = resolveLastCoordinate(
      report: report,
      spots: spots,
      fishingZone: fishingZone,
    );
    if (coordinate == null) {
      return const DashboardTimelineRefreshResult(coordinateExists: false);
    }

    try {
      final fresh = await fetch(
        lat: coordinate.lat,
        lon: coordinate.lon,
        forceRefresh: forceRefresh,
      );
      await _marineCache.saveLastReport(fresh);
      return DashboardTimelineRefreshResult(
        coordinateExists: true,
        fetchCalled: true,
        decisionTimelineLength: fresh.decisionTimeline.length,
        cacheSaved: true,
      );
    } catch (_) {
      return const DashboardTimelineRefreshResult(
        coordinateExists: true,
        fetchCalled: true,
        cacheSaved: false,
      );
    }
  }

  DashboardLocationSummary _buildLocation(
    MarineIntelligenceReport? report,
    FishingZoneResponse? fishingZone,
  ) {
    if (report != null) {
      final lat = report.coordinate.lat;
      final lon = report.coordinate.lon;
      return DashboardLocationSummary(
        lat: lat,
        lon: lon,
        label: _formatCoordinate(lat, lon),
      );
    }
    if (fishingZone != null) {
      final gps = fishingZone.boat.smoothedGps;
      if (gps.lat != 0 || gps.lon != 0) {
        return DashboardLocationSummary(
          lat: gps.lat,
          lon: gps.lon,
          label: _formatCoordinate(gps.lat, gps.lon),
        );
      }
    }
    return const DashboardLocationSummary();
  }

  DashboardMarineReportSummary _buildMarineReport(
    MarineIntelligenceReport? report,
    String? syncedAt,
  ) {
    if (report == null) return const DashboardMarineReportSummary();
    final fs = report.fishingScore;
    final decision = report.decision;
    return DashboardMarineReportSummary(
      suitabilityScore: fs.suitabilityScore,
      riskScore: fs.riskScore,
      confidence: fs.confidence,
      advice: fs.generalAdviceTr.trim(),
      updatedAt: syncedAt ?? report.updatedAt,
      lat: report.coordinate.lat,
      lon: report.coordinate.lon,
      weatherLabel: _weatherLabel(report.weather),
      windLabel: _windLabel(report.wind),
      moonLabel: _moonLabel(report.astronomy),
      tideLabel: _tideLabelFromDynamic(report.tide),
      currentLabel: _currentLabel(report.marine, report.tide),
      waveLabel: _waveLabel(report.marine),
      goScore: decision?.goScore ?? fs.suitabilityScore,
      decisionLabel: decision?.fishingDecision != null
          ? marineDecisionBadgeLabelTr(decision!.fishingDecision)
          : null,
      bestActionTr: decision?.bestActionTr,
      cacheHit: report.cacheHit,
    );
  }

  DashboardLiveScoreSummary _buildLiveScore(
    Map<String, dynamic>? raw,
    MarineIntelligenceReport? report,
  ) {
    if (raw != null) {
      final score = _asInt(raw['live_score']);
      final rating = (raw['rating'] as String?)?.trim() ?? '';
      if (score != null) {
        final detail = [
          if (((raw['reasoning'] as String?)?.trim() ?? '').isNotEmpty)
            (raw['reasoning'] as String).trim(),
          if (((raw['trust_note'] as String?)?.trim() ?? '').isNotEmpty)
            (raw['trust_note'] as String).trim(),
        ].join(' · ');
        final metrics = report != null ? _liveMetricsFromReport(report) : null;
        return DashboardLiveScoreSummary(
          score: score,
          rating: rating,
          detailLine: detail,
          suitabilityLabel: rating.isNotEmpty ? rating : kMarineNoData,
          savedAt: _parseDate(raw['saved_at'] as String?),
          weatherMetric: metrics?.$1,
          seaMetric: metrics?.$2,
          tideCurrentMetric: metrics?.$3,
          moonMetric: metrics?.$4,
          fishMetric: metrics?.$5,
        );
      }
    }

    if (report != null) {
      final decision = report.decision;
      final fs = report.fishingScore;
      final score = decision?.goScore ?? fs.suitabilityScore;
      final metrics = _liveMetricsFromReport(report);
      final decisionLabel = decision?.fishingDecision != null
          ? marineDecisionBadgeLabelTr(decision!.fishingDecision)
          : DashboardOverviewService.scoreRatingLabel(score);
      return DashboardLiveScoreSummary(
        score: score,
        rating: decisionLabel,
        suitabilityLabel: decisionLabel,
        detailLine: fs.generalAdviceTr.trim(),
        weatherMetric: metrics.$1,
        seaMetric: metrics.$2,
        tideCurrentMetric: metrics.$3,
        moonMetric: metrics.$4,
        fishMetric: metrics.$5,
        isFromReport: true,
      );
    }

    return const DashboardLiveScoreSummary();
  }

  static String scoreRatingLabel(int? score) {
    if (score == null) return kPremiumDashPlaceholderDash;
    if (score >= 80) return 'Mükemmel';
    if (score >= 60) return 'İyi';
    if (score >= 40) return 'Orta';
    return 'Düşük';
  }

  (int?, int?, int?, int?, int?) _liveMetricsFromReport(
    MarineIntelligenceReport report,
  ) {
    final wind = report.wind.speedKmh?.finalValue;
    final wave = report.marine.waveHeightM?.finalValue;
    final current = report.marine.oceanCurrentVelocityMps?.finalValue ??
        _currentMpsFromTide(report.tide);
    final moon = report.astronomy.moonIlluminationPct;
    final fish = report.decision?.goScore ?? report.fishingScore.suitabilityScore;
    return (
      _metricFromWind(wind),
      _metricFromWave(wave),
      _metricFromCurrent(current),
      _metricFromMoon(moon),
      fish,
    );
  }

  static int? _metricFromWind(double? kmh) {
    if (kmh == null) return null;
    if (kmh <= 15) return 85;
    if (kmh <= 30) return 55;
    return 25;
  }

  static int? _metricFromWave(double? meters) {
    if (meters == null) return null;
    if (meters <= 0.8) return 82;
    if (meters <= 1.5) return 52;
    return 28;
  }

  static int? _metricFromCurrent(double? mps) {
    if (mps == null) return null;
    if (mps <= 0.3) return 80;
    if (mps <= 0.8) return 55;
    return 30;
  }

  static int? _metricFromMoon(double? illuminationPct) {
    if (illuminationPct == null) return null;
    if (illuminationPct <= 35) return 82;
    if (illuminationPct <= 70) return 58;
    return 35;
  }

  DashboardSavedSpotsSummary _buildSavedSpots(List<MarineSavedSpot> spots) {
    if (spots.isEmpty) {
      return const DashboardSavedSpotsSummary();
    }
    final sorted = [...spots]
      ..sort((a, b) {
        if (a.favorite != b.favorite) return a.favorite ? -1 : 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
    final top = sorted.take(4).map((s) {
      final score = s.lastReport?.fishingScore.suitabilityScore ??
          s.aiLearningScore?.round();
      final detailParts = <String>[];
      if (s.lastSuccessSpecies != null && s.lastSuccessSpecies!.isNotEmpty) {
        detailParts.add(s.lastSuccessSpecies!);
      }
      if (score != null) {
        detailParts.add('$kPremiumDashScoreLabel: $score');
      }
      final lastDecision = s.lastReport?.decision?.fishingDecision;
      return DashboardSavedSpotItem(
        id: s.id,
        name: s.name,
        lat: s.lat,
        lon: s.lon,
        favorite: s.favorite,
        score: score,
        lastReportAt: s.lastReportAt,
        detailLine: detailParts.isEmpty ? null : detailParts.join(' · '),
        decisionLabel: lastDecision != null
            ? marineDecisionBadgeLabelTr(lastDecision)
            : null,
        reputationScore: s.spotReputation != null
            ? (s.spotReputation! * 100).round().clamp(0, 100)
            : null,
        updatedAt: s.updatedAt,
      );
    }).toList(growable: false);
    return DashboardSavedSpotsSummary(
      items: top,
      totalCount: spots.length,
    );
  }

  DashboardRecentCatchesSummary _buildRecentCatches(
    List<Map<String, dynamic>> cached,
    List<MarineSavedSpot> spots,
  ) {
    if (cached.isNotEmpty) {
      final items = cached.take(3).map((e) {
        return DashboardCatchItem(
          species: (e['species'] as String?) ?? '',
          spotName: (e['spot_name'] as String?) ?? '',
          caughtAt: (e['caught_at'] as String?) ?? '',
          weightKg: _asDouble(e['weight_kg']),
        );
      }).where((e) => e.species.isNotEmpty).toList(growable: false);
      if (items.isNotEmpty) {
        return DashboardRecentCatchesSummary(items: items);
      }
    }

    final fromSpots = <DashboardCatchItem>[];
    for (final s in spots) {
      if (s.lastSuccessSpecies != null && s.lastSuccessSpecies!.isNotEmpty) {
        fromSpots.add(
          DashboardCatchItem(
            species: s.lastSuccessSpecies!,
            spotName: s.name,
            caughtAt: s.lastSuccessDate ?? '',
            weightKg: s.lastSuccessWeight,
          ),
        );
      }
    }
    fromSpots.sort((a, b) => b.caughtAt.compareTo(a.caughtAt));
    return DashboardRecentCatchesSummary(
      items: fromSpots.take(3).toList(growable: false),
    );
  }

  DashboardCompareSummary _buildCompare(MarineCompareResponse? raw) {
    if (raw == null) return const DashboardCompareSummary();
    final c = raw.comparison;
    final captain = raw.captainComment?.summaryTr.trim() ?? '';
    return DashboardCompareSummary(
      summaryTr: c.summaryTr.trim().isNotEmpty
          ? c.summaryTr
          : c.mainReasons.join(' · '),
      winnerLabel: c.winnerLabel ?? c.winner,
      leftLabel: _compareSideLabel(raw.leftReport),
      rightLabel: _compareSideLabel(raw.rightReport),
      updatedAt: raw.updatedAt,
      scoreDelta: c.scoreDelta,
      captainCommentTr: captain,
    );
  }

  DashboardCaptainAtlasSummary _buildCaptainAtlas(
    MarineIntelligenceReport? report,
    MarineCompareResponse? compare,
  ) {
    MarineAiComment? comment = report?.aiComment;
    if (comment == null || comment.summaryTr.trim().isEmpty) {
      comment = compare?.captainComment;
    }
    if (comment == null || comment.summaryTr.trim().isEmpty) {
      return const DashboardCaptainAtlasSummary();
    }
    return DashboardCaptainAtlasSummary(
      summaryTr: comment.summaryTr,
      personaVersion: _shortPersonaVersion(comment.personaVersion),
      isFallback: comment.isFallback,
    );
  }

  DashboardTimelineSummary _buildTimeline({
    required MarineIntelligenceReport? report,
    required List<MarineSavedSpot> spots,
    required String? reportSyncedAt,
    required bool hasCoordinate,
    bool isRefreshing = false,
  }) {
    final items = _collectDecisionTimelineItems(report, spots);
    final updatedLabel = formatRelativeTime(reportSyncedAt ?? report?.updatedAt);

    if (items.isNotEmpty) {
      final slots = items.take(6).map((item) {
        final decisionLabel = item.decision != null
            ? marineDecisionBadgeLabelTr(item.decision!)
            : kPremiumDashPlaceholderDash;
        final scorePart = item.goScore != null ? ' · ${item.goScore}' : '';
        return DashboardTimelineSlot(
          time: item.time,
          label: '$decisionLabel$scorePart',
          decision: item.decision,
          goScore: item.goScore,
        );
      }).toList(growable: false);
      return DashboardTimelineSummary(
        slots: slots,
        displayState: DashboardTimelineDisplayState.hasData,
        isRefreshing: isRefreshing,
        isCached: report?.cacheHit == true ||
            (reportSyncedAt != null && reportSyncedAt.isNotEmpty),
        updatedAgoLabel: updatedLabel,
      );
    }

    if (isRefreshing) {
      return DashboardTimelineSummary(
        displayState: DashboardTimelineDisplayState.loading,
        isRefreshing: true,
        isCached: report != null,
      );
    }

    if (report != null || hasCoordinate) {
      return DashboardTimelineSummary(
        displayState: DashboardTimelineDisplayState.reportWithoutTimeline,
        isRefreshing: isRefreshing,
        isCached: report != null,
        updatedAgoLabel: report != null ? updatedLabel : null,
      );
    }

    return DashboardTimelineSummary(
      displayState: DashboardTimelineDisplayState.noCoordinate,
      isRefreshing: isRefreshing,
    );
  }

  static List<MarineDecisionTimelineItem> _collectDecisionTimelineItems(
    MarineIntelligenceReport? report,
    List<MarineSavedSpot> spots,
  ) {
    if (report != null && report.decisionTimeline.isNotEmpty) {
      return report.decisionTimeline;
    }
    for (final spot in _sortedSpots(spots)) {
      final snapshot = spot.lastReport;
      if (snapshot != null && snapshot.decisionTimeline.isNotEmpty) {
        return snapshot.decisionTimeline;
      }
    }
    return const [];
  }

  static List<MarineSavedSpot> _sortedSpots(List<MarineSavedSpot> spots) {
    final sorted = [...spots]
      ..sort((a, b) {
        if (a.favorite != b.favorite) return a.favorite ? -1 : 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
    return sorted;
  }

  DashboardTideSummary _buildTide(MarineIntelligenceReport? report) {
    if (report == null) {
      return const DashboardTideSummary(
        emptyReason: kPremiumDashTideEmpty,
      );
    }
    final tide = report.tide;
    if (tide is! Map) {
      return const DashboardTideSummary(
        emptyReason: kPremiumDashTideNoProvider,
      );
    }

    final map = Map<String, dynamic>.from(tide);
    final providerAvailable = map['tide_provider_available'] == true;
    final displayModeRaw = (map['display_mode'] as String?)?.trim() ?? '';
    final displayMode = switch (displayModeRaw) {
      'tide' => DashboardTideDisplayMode.tide,
      'sea_movement' => DashboardTideDisplayMode.seaMovement,
      _ => providerAvailable
          ? DashboardTideDisplayMode.tide
          : DashboardTideDisplayMode.empty,
    };
    final context = (map['context_tr'] as String?)?.trim();
    final summary = (map['summary_tr'] as String?)?.trim();
    final chartLabel = (map['chart_label_tr'] as String?)?.trim();

    final wavePoints = _parseTidePoints(map['hourly_wave_points'], 'wave_height_m');
    final tidePoints = _parseTidePoints(map['points'], 'height_m');

    if (displayMode == DashboardTideDisplayMode.tide &&
        (tidePoints.length >= 2 || (summary != null && summary.isNotEmpty))) {
      return DashboardTideSummary(
        label: summary,
        tidePoints: tidePoints,
        tideProviderAvailable: true,
        displayMode: DashboardTideDisplayMode.tide,
        chartLabel: chartLabel ?? 'Gelgit (m)',
      );
    }

    if (displayMode == DashboardTideDisplayMode.seaMovement ||
        wavePoints.length >= 2 ||
        (summary != null && summary.isNotEmpty)) {
      return DashboardTideSummary(
        label: summary,
        wavePoints: wavePoints,
        tideProviderAvailable: false,
        displayMode: DashboardTideDisplayMode.seaMovement,
        chartLabel: chartLabel ?? kPremiumDashTideWaveChartLabel,
        contextMessage: context ?? kPremiumDashTideSeaMovementNote,
      );
    }

    return DashboardTideSummary(
      tideProviderAvailable: providerAvailable,
      displayMode: DashboardTideDisplayMode.empty,
      contextMessage: context ?? kPremiumDashTideNoDataNote,
      emptyReason: kPremiumDashTideNoDataNote,
    );
  }

  List<DashboardTidePoint> _parseTidePoints(dynamic raw, String valueKey) {
    final points = <DashboardTidePoint>[];
    if (raw is! List) return points;
    for (final item in raw) {
      if (item is! Map) continue;
      final time = (item['time'] as String?)?.trim() ?? '';
      final value = _asDouble(item[valueKey]);
      if (time.isNotEmpty && value != null) {
        points.add(DashboardTidePoint(time: time, value: value));
      }
    }
    return points;
  }

  DashboardForecastSummary _buildForecast(MarineIntelligenceReport? report) {
    if (report == null) {
      return const DashboardForecastSummary(
        emptyReason: kPremiumDashForecastEmptyHint,
      );
    }

    final days = _parseForecastDays(report.historical);
    if (days.isNotEmpty) {
      return DashboardForecastSummary(
        days: days,
        label: kPremiumDashForecastDaysAvailable.replaceAll(
          '{count}',
          '${days.length}',
        ),
      );
    }

    final label = _forecastLabel(report.historical, report.trends);
    if (label != null && label.trim().isNotEmpty) {
      return DashboardForecastSummary(label: label);
    }

    return const DashboardForecastSummary(
      emptyReason: kPremiumDashForecastFetchFailed,
    );
  }

  List<DashboardForecastDay> _parseForecastDays(dynamic historical) {
    if (historical is! Map) return const [];
    final daysRaw = historical['days'];
    if (daysRaw is! List) return const [];
    final out = <DashboardForecastDay>[];
    for (final item in daysRaw) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final date = (map['date'] as String?)?.trim() ?? '';
      if (date.isEmpty) continue;
      out.add(
        DashboardForecastDay(
          dateLabel: _shortDateLabel(date),
          dayLabel: (map['day_label'] as String?)?.trim(),
          tempMaxC: _asInt(map['temp_max_c']),
          tempMinC: _asInt(map['temp_min_c']),
          precipitationProbabilityPct:
              _asInt(map['precipitation_probability_pct']),
          windMaxKmh: _asInt(map['wind_max_kmh']),
          weatherCode: _asInt(map['weather_code']),
          weatherLabel: (map['weather_label_tr'] as String?)?.trim(),
        ),
      );
    }
    return out;
  }

  String _shortDateLabel(String isoDate) {
    final parts = isoDate.split('-');
    if (parts.length >= 3) {
      return '${parts[2]}.${parts[1]}';
    }
    return isoDate;
  }

  DashboardMapPreviewData _buildMapPreview({
    required MarineIntelligenceReport? report,
    required List<MarineSavedSpot> spots,
    required MarineCompareResponse? compare,
    required FishingZoneResponse? fishingZone,
    required String? reportSyncedAt,
  }) {
    bool coordValid(double lat, double lon) =>
        lat.abs() > 1e-6 || lon.abs() > 1e-6;

    final sortedSpots = _sortedSpots(spots);
    final markers = <DashboardMapMarker>[];
    final allLats = <double>[];
    final allLons = <double>[];

    void trackCoord(double lat, double lon) {
      if (coordValid(lat, lon)) {
        allLats.add(lat);
        allLons.add(lon);
      }
    }

    double? centerLat;
    double? centerLon;
    String? centerLabel;
    int? score;
    String? scoreLabel;
    String? waveLabel;
    String? currentLabel;
    String? windLabel;
    String? dataSourceLabel;
    String? updatedAgoLabel;
    var hasComparePair = false;
    String? winnerLabel;
    int? hotspotCount;
    MarineIntelligenceReport? compareLeft;
    MarineIntelligenceReport? compareRight;

    if (report != null &&
        coordValid(report.coordinate.lat, report.coordinate.lon)) {
      centerLat = report.coordinate.lat;
      centerLon = report.coordinate.lon;
      centerLabel = _formatCoordinate(centerLat, centerLon);
      score = report.decision?.goScore ?? report.fishingScore.suitabilityScore;
      if (report.decision?.goScore != null) {
        scoreLabel = 'GO ${report.decision!.goScore}';
      }
      waveLabel = _waveLabel(report.marine);
      currentLabel = _currentLabel(report.marine, report.tide);
      windLabel = _windLabel(report.wind);
      updatedAgoLabel = formatRelativeTime(reportSyncedAt ?? report.updatedAt);
      dataSourceLabel = kPremiumDashMapSourceReport;
      trackCoord(centerLat, centerLon);
    }

    if (compare != null) {
      compareLeft = compare.leftReport;
      compareRight = compare.rightReport;
      final left = compareLeft.coordinate;
      final right = compareRight.coordinate;
      if (coordValid(left.lat, left.lon) && coordValid(right.lat, right.lon)) {
        hasComparePair = true;
        winnerLabel = !compare.comparison.isTie
            ? (compare.comparison.winnerLabel ?? compare.comparison.winner)
            : null;
        trackCoord(left.lat, left.lon);
        trackCoord(right.lat, right.lon);
      }
    }

    final validSpots = sortedSpots
        .where((s) => coordValid(s.lat, s.lon))
        .take(6)
        .toList(growable: false);
    for (final s in validSpots) {
      trackCoord(s.lat, s.lon);
    }

    final geoHotspots = <Hotspot>[];
    if (fishingZone != null && fishingZone.resolveGeoMapDisplayAllowed()) {
      for (final h in fishingZone.hotspots) {
        if (coordValid(h.latitude, h.longitude)) {
          geoHotspots.add(h);
          trackCoord(h.latitude, h.longitude);
        }
      }
      if (geoHotspots.isNotEmpty) {
        hotspotCount = geoHotspots.length;
      }
    }

    if (centerLat == null && validSpots.isNotEmpty) {
      final primary = validSpots.first;
      centerLat = primary.lat;
      centerLon = primary.lon;
      centerLabel = primary.name;
      dataSourceLabel = kPremiumDashMapSourceSavedSpot;
      final lr = primary.lastReport;
      if (lr != null) {
        score ??= lr.decision?.goScore ?? lr.fishingScore.suitabilityScore;
        waveLabel ??= _waveLabel(lr.marine);
        currentLabel ??= _currentLabel(lr.marine, null);
        windLabel ??= _windLabel(lr.wind);
        updatedAgoLabel ??=
            formatRelativeTime(primary.lastReportAt ?? lr.updatedAt);
      }
    }

    if (centerLat == null &&
        hasComparePair &&
        compareLeft != null &&
        compareRight != null) {
      centerLat =
          (compareLeft.coordinate.lat + compareRight.coordinate.lat) / 2;
      centerLon =
          (compareLeft.coordinate.lon + compareRight.coordinate.lon) / 2;
      centerLabel = _formatCoordinate(centerLat, centerLon);
      dataSourceLabel = kPremiumDashMapSourceCompare;
    }

    if (centerLat == null && geoHotspots.isNotEmpty) {
      var sumLat = 0.0;
      var sumLon = 0.0;
      for (final h in geoHotspots) {
        sumLat += h.latitude;
        sumLon += h.longitude;
      }
      centerLat = sumLat / geoHotspots.length;
      centerLon = sumLon / geoHotspots.length;
      centerLabel = _formatCoordinate(centerLat, centerLon);
      dataSourceLabel = kPremiumDashMapRealData;
    }

    final bounds = _computeBounds(lats: allLats, lons: allLons);

    if (report != null &&
        coordValid(report.coordinate.lat, report.coordinate.lon)) {
      final pos =
          _normalizeLatLon(report.coordinate.lat, report.coordinate.lon, bounds);
      markers.add(
        DashboardMapMarker(
          normalizedX: pos.$1,
          normalizedY: pos.$2,
          id: 'report',
          label: centerLabel ?? '',
          lat: report.coordinate.lat,
          lon: report.coordinate.lon,
          score: report.decision?.goScore ??
              report.fishingScore.suitabilityScore,
          markerType: DashboardMapMarkerType.report,
          isPrimary: true,
        ),
      );
    }

    for (final s in validSpots) {
      final pos = _normalizeLatLon(s.lat, s.lon, bounds);
      final isPrimarySpot =
          report == null && centerLat == s.lat && centerLon == s.lon;
      markers.add(
        DashboardMapMarker(
          normalizedX: pos.$1,
          normalizedY: pos.$2,
          id: s.id,
          label: s.name,
          lat: s.lat,
          lon: s.lon,
          score: s.lastReport?.decision?.goScore ??
              s.lastReport?.fishingScore.suitabilityScore,
          markerType: DashboardMapMarkerType.savedSpot,
          isFavorite: s.favorite,
          isPrimary: isPrimarySpot && !markers.any((m) => m.isPrimary),
        ),
      );
    }

    if (hasComparePair && compareLeft != null && compareRight != null) {
      final left = compareLeft.coordinate;
      final right = compareRight.coordinate;
      final leftPos = _normalizeLatLon(left.lat, left.lon, bounds);
      final rightPos = _normalizeLatLon(right.lat, right.lon, bounds);
      markers.add(
        DashboardMapMarker(
          normalizedX: leftPos.$1,
          normalizedY: leftPos.$2,
          id: 'compare_a',
          label: kMarineComparePointA,
          lat: left.lat,
          lon: left.lon,
          score: compareLeft.fishingScore.suitabilityScore,
          markerType: DashboardMapMarkerType.compareA,
          isCompareA: true,
        ),
      );
      markers.add(
        DashboardMapMarker(
          normalizedX: rightPos.$1,
          normalizedY: rightPos.$2,
          id: 'compare_b',
          label: kMarineComparePointB,
          lat: right.lat,
          lon: right.lon,
          score: compareRight.fishingScore.suitabilityScore,
          markerType: DashboardMapMarkerType.compareB,
          isCompareB: true,
        ),
      );
    }

    for (final h in geoHotspots.take(4)) {
      final pos = _normalizeLatLon(h.latitude, h.longitude, bounds);
      markers.add(
        DashboardMapMarker(
          normalizedX: pos.$1,
          normalizedY: pos.$2,
          id: 'hotspot_${h.id}',
          label: kPremiumDashMapRealData,
          lat: h.latitude,
          lon: h.longitude,
          score: h.score.round(),
          markerType: DashboardMapMarkerType.hotspot,
        ),
      );
    }

    DashboardMapPreviewMode displayMode;
    if (hasComparePair) {
      displayMode = DashboardMapPreviewMode.compare;
    } else if (report != null &&
        coordValid(report.coordinate.lat, report.coordinate.lon)) {
      displayMode = DashboardMapPreviewMode.activeReport;
    } else if (validSpots.isNotEmpty) {
      displayMode = DashboardMapPreviewMode.savedSpots;
    } else if (centerLat != null && geoHotspots.isNotEmpty) {
      displayMode = DashboardMapPreviewMode.activeReport;
    } else {
      displayMode = DashboardMapPreviewMode.empty;
    }

    final hasRealCoordinate = centerLat != null &&
        centerLon != null &&
        coordValid(centerLat, centerLon);

    if (!hasRealCoordinate) {
      displayMode = DashboardMapPreviewMode.empty;
      centerLat = null;
      centerLon = null;
      centerLabel = null;
      score = null;
      scoreLabel = null;
      markers.clear();
      hasComparePair = false;
      winnerLabel = null;
      hotspotCount = null;
      waveLabel = null;
      currentLabel = null;
      windLabel = null;
      dataSourceLabel = null;
      updatedAgoLabel = null;
    }

    return DashboardMapPreviewData(
      centerLat: centerLat,
      centerLon: centerLon,
      centerLabel: centerLabel,
      score: score,
      scoreLabel: scoreLabel,
      updatedAgoLabel: updatedAgoLabel,
      markers: markers,
      hasComparePair:
          hasComparePair && displayMode == DashboardMapPreviewMode.compare,
      hotspotCount: hotspotCount,
      winnerLabel: winnerLabel,
      hasRealCoordinate: hasRealCoordinate,
      displayMode: displayMode,
      waveLabel: waveLabel,
      currentLabel: currentLabel,
      windLabel: windLabel,
      dataSourceLabel: dataSourceLabel,
      emptyReason: hasRealCoordinate ? null : kPremiumDashMapEmptyAwaiting,
    );
  }

  static DashboardConnectionStatus mapHealthStatus({
    required bool? healthOk,
    required bool healthChecking,
  }) {
    if (healthChecking) return DashboardConnectionStatus.checking;
    if (healthOk == true) return DashboardConnectionStatus.connected;
    if (healthOk == false) return DashboardConnectionStatus.disconnected;
    return DashboardConnectionStatus.unknown;
  }

  static String connectionStatusLabel(DashboardConnectionStatus status) {
    switch (status) {
      case DashboardConnectionStatus.connected:
        return kPremiumDashConnectionOk;
      case DashboardConnectionStatus.disconnected:
        return kPremiumDashConnectionOff;
      case DashboardConnectionStatus.checking:
        return kPremiumDashConnectionChecking;
      case DashboardConnectionStatus.unknown:
        return kPremiumDashConnectionUnknown;
    }
  }

  static String formatRelativeTime(String? iso) {
    if (iso == null || iso.trim().isEmpty) return kPremiumDashNoData;
    final dt = DateTime.tryParse(iso.trim());
    if (dt == null) return iso;
    final diff = DateTime.now().toUtc().difference(dt.toUtc());
    if (diff.inMinutes < 1) return kPremiumDashJustNow;
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk';
    if (diff.inHours < 24) return '${diff.inHours} sa';
    return '${diff.inDays} gün';
  }

  String _compareSideLabel(MarineIntelligenceReport report) {
    return _formatCoordinate(report.coordinate.lat, report.coordinate.lon);
  }

  String _formatCoordinate(double lat, double lon) {
    return '${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}';
  }

  String? _windLabel(MarineWindBlock wind) {
    final speed = wind.speedKmh?.finalValue;
    if (speed == null) return null;
    final rounded = speed.round();
    final dir = wind.directionText?.trim();
    if (dir != null && dir.isNotEmpty) {
      return '$rounded km/s $dir';
    }
    return '$rounded km/s';
  }

  String? _waveLabel(MarineSeaBlock marine) {
    final wave = marine.waveHeightM?.finalValue;
    if (wave == null) return null;
    return '${wave.toStringAsFixed(1)} m';
  }

  String? _currentLabel(MarineSeaBlock marine, dynamic tide) {
    final mps = marine.oceanCurrentVelocityMps?.finalValue ??
        _currentMpsFromTide(tide);
    if (mps == null) return null;
    return '${mps.toStringAsFixed(2)} m/s';
  }

  double? _currentMpsFromTide(dynamic tide) {
    if (tide is Map) {
      final v = tide['ocean_current_velocity_mps'];
      if (v is num) return v.toDouble();
    }
    return null;
  }

  String? _weatherLabel(MarineWeatherBlock weather) {
    final temp = weather.temperatureC?.finalValue;
    if (temp == null) return null;
    final rounded = temp.round();
    return '$rounded°C';
  }

  String? _moonLabel(MarineAstronomyBlock astronomy) {
    final phase = astronomy.moonPhase?.trim();
    if (phase != null && phase.isNotEmpty) return phase;
    final pct = astronomy.moonIlluminationPct;
    if (pct != null) return '%${pct.round()}';
    return null;
  }

  String? _tideLabelFromDynamic(dynamic tide) {
    if (tide == null) return null;
    if (tide is Map) {
      for (final key in ['state_tr', 'summary_tr', 'current_state', 'phase']) {
        final v = tide[key];
        if (v != null && v.toString().trim().isNotEmpty) {
          return v.toString().trim();
        }
      }
      if (tide['height_m'] != null) {
        return '${tide['height_m']} m';
      }
    }
    return null;
  }

  String? _forecastLabel(dynamic historical, dynamic trends) {
    if (trends is Map) {
      final summary = trends['summary_tr'] ?? trends['outlook_tr'];
      if (summary != null && summary.toString().trim().isNotEmpty) {
        return summary.toString().trim();
      }
    }
    if (historical is Map) {
      final days = historical['days'];
      if (days is List && days.isNotEmpty) {
        return kPremiumDashForecastDaysAvailable.replaceAll(
          '{count}',
          '${days.length}',
        );
      }
    }
    return null;
  }

  String _shortPersonaVersion(String version) {
    final trimmed = version.trim();
    if (trimmed.isEmpty) return kPremiumCaptainCardBadge;
    if (trimmed.length <= 8) return trimmed;
    return trimmed.split('_').last;
  }

  ({double minLat, double maxLat, double minLon, double maxLon}) _computeBounds({
    required List<double> lats,
    required List<double> lons,
  }) {
    if (lats.isEmpty || lons.isEmpty) {
      return (minLat: 0, maxLat: 1, minLon: 0, maxLon: 1);
    }
    var minLat = lats.first;
    var maxLat = lats.first;
    var minLon = lons.first;
    var maxLon = lons.first;
    for (var i = 0; i < lats.length; i++) {
      minLat = lats[i] < minLat ? lats[i] : minLat;
      maxLat = lats[i] > maxLat ? lats[i] : maxLat;
      minLon = lons[i] < minLon ? lons[i] : minLon;
      maxLon = lons[i] > maxLon ? lons[i] : maxLon;
    }
    if ((maxLat - minLat).abs() < 0.001) {
      minLat -= 0.01;
      maxLat += 0.01;
    }
    if ((maxLon - minLon).abs() < 0.001) {
      minLon -= 0.01;
      maxLon += 0.01;
    }
    return (minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon);
  }

  (double, double) _normalizeLatLon(
    double lat,
    double lon,
    ({double minLat, double maxLat, double minLon, double maxLon}) bounds,
  ) {
    final x = (lon - bounds.minLon) / (bounds.maxLon - bounds.minLon);
    final y = 1 - (lat - bounds.minLat) / (bounds.maxLat - bounds.minLat);
    return (x.clamp(0.08, 0.92), y.clamp(0.12, 0.88));
  }

  DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}

/// Av kaydı özetlerini dashboard cache'e yazar (marine intelligence ekranından).
Future<void> mergeRecentCatchSummariesForDashboard({
  required MarineIntelligenceCache cache,
  required String spotId,
  required String spotName,
  required List<dynamic> catches,
}) async {
  final existing = await cache.loadRecentCatchSummaries();
  final merged = <Map<String, dynamic>>[
    for (final c in catches)
      if (c is Map<String, dynamic> || c is Map)
        {
          'species': _catchField(c, 'species'),
          'spot_id': spotId,
          'spot_name': spotName,
          'caught_at': _catchField(c, 'caught_at'),
          'weight_kg': _catchField(c, 'weight_kg'),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
    ...existing,
  ];
  await cache.saveRecentCatchSummaries(merged.take(12).toList(growable: false));
}

dynamic _catchField(dynamic c, String key) {
  if (c is Map) return c[key];
  return null;
}
