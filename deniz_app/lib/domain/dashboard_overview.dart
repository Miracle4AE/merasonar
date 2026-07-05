library;

import 'package:deniz_app/domain/dashboard_map_preview_projection.dart';

enum DashboardConnectionStatus {
  connected,
  disconnected,
  checking,
  unknown,
}

class DashboardLocationSummary {
  const DashboardLocationSummary({
    this.lat,
    this.lon,
    this.label,
  });

  final double? lat;
  final double? lon;
  final String? label;

  bool get hasLocation => lat != null && lon != null;
}

class DashboardLiveScoreSummary {
  const DashboardLiveScoreSummary({
    this.score,
    this.rating = '',
    this.detailLine = '',
    this.suitabilityLabel = '',
    this.savedAt,
    this.weatherMetric,
    this.seaMetric,
    this.tideCurrentMetric,
    this.moonMetric,
    this.fishMetric,
    this.isFromReport = false,
  });

  final int? score;
  final String rating;
  final String detailLine;
  final String suitabilityLabel;
  final DateTime? savedAt;
  final int? weatherMetric;
  final int? seaMetric;
  final int? tideCurrentMetric;
  final int? moonMetric;
  final int? fishMetric;
  final bool isFromReport;

  bool get hasData => score != null;
}

class DashboardMarineReportSummary {
  const DashboardMarineReportSummary({
    this.suitabilityScore,
    this.riskScore,
    this.confidence,
    this.advice = '',
    this.updatedAt,
    this.lat,
    this.lon,
    this.weatherLabel,
    this.windLabel,
    this.moonLabel,
    this.tideLabel,
    this.currentLabel,
    this.waveLabel,
    this.goScore,
    this.decisionLabel,
    this.bestActionTr,
    this.cacheHit,
  });

  final int? suitabilityScore;
  final int? riskScore;
  final double? confidence;
  final String advice;
  final String? updatedAt;
  final double? lat;
  final double? lon;
  final String? weatherLabel;
  final String? windLabel;
  final String? moonLabel;
  final String? tideLabel;
  final String? currentLabel;
  final String? waveLabel;
  final int? goScore;
  final String? decisionLabel;
  final String? bestActionTr;
  final bool? cacheHit;

  bool get hasData =>
      suitabilityScore != null ||
      goScore != null ||
      advice.trim().isNotEmpty ||
      (lat != null && lon != null);

  int? get missionScore => goScore ?? suitabilityScore;
}

class DashboardSavedSpotItem {
  const DashboardSavedSpotItem({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    this.favorite = false,
    this.score,
    this.lastReportAt,
    this.detailLine,
    this.decisionLabel,
    this.reputationScore,
    this.updatedAt,
  });

  final String id;
  final String name;
  final double lat;
  final double lon;
  final bool favorite;
  final int? score;
  final String? lastReportAt;
  final String? detailLine;
  final String? decisionLabel;
  final int? reputationScore;
  final String? updatedAt;
}

class DashboardSavedSpotsSummary {
  const DashboardSavedSpotsSummary({
    this.items = const [],
    this.totalCount = 0,
  });

  final List<DashboardSavedSpotItem> items;
  final int totalCount;

  bool get hasData => items.isNotEmpty;
}

class DashboardCatchItem {
  const DashboardCatchItem({
    required this.species,
    this.spotName = '',
    this.caughtAt = '',
    this.weightKg,
  });

  final String species;
  final String spotName;
  final String caughtAt;
  final double? weightKg;
}

class DashboardRecentCatchesSummary {
  const DashboardRecentCatchesSummary({
    this.items = const [],
  });

  final List<DashboardCatchItem> items;

  bool get hasData => items.isNotEmpty;
}

class DashboardCompareSummary {
  const DashboardCompareSummary({
    this.summaryTr = '',
    this.winnerLabel = '',
    this.leftLabel = '',
    this.rightLabel = '',
    this.updatedAt,
    this.scoreDelta = 0,
    this.captainCommentTr = '',
  });

  final String summaryTr;
  final String winnerLabel;
  final String leftLabel;
  final String rightLabel;
  final String? updatedAt;
  final int scoreDelta;
  final String captainCommentTr;

  bool get hasData => summaryTr.trim().isNotEmpty;
}

class DashboardCaptainAtlasSummary {
  const DashboardCaptainAtlasSummary({
    this.summaryTr = '',
    this.personaVersion = '',
    this.isFallback = false,
  });

  final String summaryTr;
  final String personaVersion;
  final bool isFallback;

  bool get hasData => summaryTr.trim().isNotEmpty;
}

class DashboardTimelineSlot {
  const DashboardTimelineSlot({
    required this.time,
    required this.label,
    this.decision,
    this.goScore,
  });

  final String time;
  final String label;
  final String? decision;
  final int? goScore;
}

/// Gün içi zaman çizelgesi kartının görüntü durumu.
enum DashboardTimelineDisplayState {
  /// Saatlik pencereler dolu.
  hasData,

  /// Arka plan yenileme — anlamlı slot yokken.
  loading,

  /// Koordinat/rapor var ama saatlik pencere yok.
  reportWithoutTimeline,

  /// Son koordinat yok — koordinat analizi CTA.
  noCoordinate,
}

class DashboardTimelineSummary {
  const DashboardTimelineSummary({
    this.slots = const [],
    this.displayState = DashboardTimelineDisplayState.noCoordinate,
    this.isRefreshing = false,
    this.isCached = false,
    this.updatedAgoLabel,
  });

  final List<DashboardTimelineSlot> slots;
  final DashboardTimelineDisplayState displayState;
  final bool isRefreshing;
  final bool isCached;
  final String? updatedAgoLabel;

  /// Slot listesi dolu olsa bile placeholder satırları sayılmaz.
  bool get hasData => hasMeaningfulData;

  bool get hasMeaningfulData =>
      slots.any(DashboardTimelineSummary.isMeaningfulSlot);

  /// Widget yalnızca bu state'e göre karar verir.
  DashboardTimelineDisplayState get resolvedDisplayState {
    if (hasMeaningfulData) return DashboardTimelineDisplayState.hasData;
    if (isRefreshing) return DashboardTimelineDisplayState.loading;
    return displayState;
  }

  /// Eski default-slot satırları (saat + "--") gerçek veri sayılmaz.
  static bool isMeaningfulSlot(DashboardTimelineSlot slot) {
    if (slot.decision != null && slot.decision!.isNotEmpty) return true;
    if (slot.goScore != null) return true;
    final label = slot.label.trim();
    if (label.isEmpty) return false;
    if (label == '--' || label == 'Veri yok') return false;
    if (label.contains('·')) return true;
    return true;
  }

  DashboardTimelineSummary copyWith({
    List<DashboardTimelineSlot>? slots,
    DashboardTimelineDisplayState? displayState,
    bool? isRefreshing,
    bool? isCached,
    String? updatedAgoLabel,
  }) {
    return DashboardTimelineSummary(
      slots: slots ?? this.slots,
      displayState: displayState ?? this.displayState,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isCached: isCached ?? this.isCached,
      updatedAgoLabel: updatedAgoLabel ?? this.updatedAgoLabel,
    );
  }
}

class DashboardTidePoint {
  const DashboardTidePoint({
    required this.time,
    required this.value,
  });

  final String time;
  final double value;
}

class DashboardTideSummary {
  const DashboardTideSummary({
    this.label,
    this.wavePoints = const [],
    this.tidePoints = const [],
    this.tideProviderAvailable = false,
    this.displayMode = DashboardTideDisplayMode.empty,
    this.chartLabel,
    this.contextMessage,
    this.emptyReason,
  });

  final String? label;
  final List<DashboardTidePoint> wavePoints;
  final List<DashboardTidePoint> tidePoints;
  final bool tideProviderAvailable;
  final DashboardTideDisplayMode displayMode;
  final String? chartLabel;
  final String? contextMessage;
  final String? emptyReason;

  List<DashboardTidePoint> get chartPoints =>
      tideProviderAvailable && tidePoints.length >= 2 ? tidePoints : wavePoints;

  bool get hasChartData => chartPoints.length >= 2;

  bool get hasData =>
      hasChartData ||
      (label != null && label!.trim().isNotEmpty) ||
      displayMode == DashboardTideDisplayMode.seaMovement;
}

enum DashboardTideDisplayMode {
  tide,
  seaMovement,
  empty,
}

class DashboardForecastDay {
  const DashboardForecastDay({
    required this.dateLabel,
    this.dayLabel,
    this.tempMaxC,
    this.tempMinC,
    this.precipitationProbabilityPct,
    this.windMaxKmh,
    this.weatherCode,
    this.weatherLabel,
  });

  final String dateLabel;
  final String? dayLabel;
  final int? tempMaxC;
  final int? tempMinC;
  final int? precipitationProbabilityPct;
  final int? windMaxKmh;
  final int? weatherCode;
  final String? weatherLabel;
}

class DashboardForecastSummary {
  const DashboardForecastSummary({
    this.label,
    this.days = const [],
    this.emptyReason,
  });

  final String? label;
  final List<DashboardForecastDay> days;
  final String? emptyReason;

  bool get hasData => days.isNotEmpty;
}

enum DashboardMapMarkerType {
  report,
  savedSpot,
  compareA,
  compareB,
  hotspot,
}

enum DashboardMapPreviewMarkerKind {
  hotspot,
  savedSpot,
  compare,
  boat,
  activeCoordinate,
}

enum DashboardMapPreviewMarkerSource {
  marineReport,
  savedSpot,
  compare,
  unknown,
}

enum DashboardMapPreviewMarkerConfidence {
  high,
  medium,
  low,
}

enum DashboardMapPreviewMode {
  activeReport,
  savedSpots,
  compare,
  empty,
  limited,
}

class DashboardMapMarker {
  const DashboardMapMarker({
    required this.normalizedX,
    required this.normalizedY,
    this.id = '',
    this.label = '',
    this.lat,
    this.lon,
    this.score,
    this.markerType = DashboardMapMarkerType.savedSpot,
    this.markerKind,
    this.markerSource,
    this.confidence,
    this.isPrimary = false,
    this.isSelected = false,
    this.isCompareA = false,
    this.isCompareB = false,
    this.isFavorite = false,
  });

  final double normalizedX;
  final double normalizedY;
  final String id;
  final String label;
  final double? lat;
  final double? lon;
  final int? score;
  final DashboardMapMarkerType markerType;
  final DashboardMapPreviewMarkerKind? markerKind;
  final DashboardMapPreviewMarkerSource? markerSource;
  final DashboardMapPreviewMarkerConfidence? confidence;
  final bool isPrimary;
  final bool isSelected;
  final bool isCompareA;
  final bool isCompareB;
  final bool isFavorite;

  bool get hasGeo => lat != null && lon != null;
  bool get hasScoreOrb => score != null && hasGeo;
}

class DashboardMapPreviewData {
  const DashboardMapPreviewData({
    this.centerLat,
    this.centerLon,
    this.centerLabel,
    this.score,
    this.scoreLabel,
    this.updatedAgoLabel,
    this.markers = const [],
    this.hasComparePair = false,
    this.hotspotCount,
    this.winnerLabel,
    this.hasRealCoordinate = false,
    this.displayMode = DashboardMapPreviewMode.empty,
    this.waveLabel,
    this.currentLabel,
    this.windLabel,
    this.dataSourceLabel,
    this.emptyReason,
    this.selectedMarkerId,
    this.bounds,
    this.depthLegendMinLabel,
    this.depthLegendMaxLabel,
    this.warningLabel,
    this.isLowConfidence = false,
  });

  final double? centerLat;
  final double? centerLon;
  final String? centerLabel;
  final int? score;
  final String? scoreLabel;
  final String? updatedAgoLabel;
  final List<DashboardMapMarker> markers;
  final bool hasComparePair;
  final int? hotspotCount;
  final String? winnerLabel;
  final bool hasRealCoordinate;
  final DashboardMapPreviewMode displayMode;
  final String? waveLabel;
  final String? currentLabel;
  final String? windLabel;
  final String? dataSourceLabel;
  final String? emptyReason;
  final String? selectedMarkerId;
  final DashboardMapPreviewBounds? bounds;
  final String? depthLegendMinLabel;
  final String? depthLegendMaxLabel;
  final String? warningLabel;
  final bool isLowConfidence;

  bool get hasData =>
      displayMode != DashboardMapPreviewMode.empty &&
      displayMode != DashboardMapPreviewMode.limited;

  bool get hasRealData =>
      hasRealCoordinate &&
      markers.any((m) => m.hasScoreOrb);

  DashboardMapMarker? get selectedMarker {
    if (selectedMarkerId == null) return null;
    for (final m in markers) {
      if (m.id == selectedMarkerId) return m;
    }
    return null;
  }
}

class DashboardOverview {
  const DashboardOverview({
    required this.connectionStatus,
    required this.location,
    required this.liveScore,
    required this.marineReport,
    required this.savedSpots,
    required this.recentCatches,
    required this.compare,
    required this.captainAtlas,
    required this.timeline,
    required this.tide,
    required this.forecast,
    required this.mapPreview,
  });

  final DashboardConnectionStatus connectionStatus;
  final DashboardLocationSummary location;
  final DashboardLiveScoreSummary liveScore;
  final DashboardMarineReportSummary marineReport;
  final DashboardSavedSpotsSummary savedSpots;
  final DashboardRecentCatchesSummary recentCatches;
  final DashboardCompareSummary compare;
  final DashboardCaptainAtlasSummary captainAtlas;
  final DashboardTimelineSummary timeline;
  final DashboardTideSummary tide;
  final DashboardForecastSummary forecast;
  final DashboardMapPreviewData mapPreview;

  static const empty = DashboardOverview(
    connectionStatus: DashboardConnectionStatus.unknown,
    location: DashboardLocationSummary(),
    liveScore: DashboardLiveScoreSummary(),
    marineReport: DashboardMarineReportSummary(),
    savedSpots: DashboardSavedSpotsSummary(),
    recentCatches: DashboardRecentCatchesSummary(),
    compare: DashboardCompareSummary(),
    captainAtlas: DashboardCaptainAtlasSummary(),
    timeline: DashboardTimelineSummary(),
    tide: DashboardTideSummary(),
    forecast: DashboardForecastSummary(),
    mapPreview: DashboardMapPreviewData(),
  );

  bool get hasActiveMission =>
      marineReport.hasData ||
      mapPreview.hasData ||
      liveScore.hasData ||
      savedSpots.hasData ||
      compare.hasData;

  DashboardOverview copyWith({
    DashboardConnectionStatus? connectionStatus,
    DashboardLocationSummary? location,
    DashboardLiveScoreSummary? liveScore,
    DashboardMarineReportSummary? marineReport,
    DashboardSavedSpotsSummary? savedSpots,
    DashboardRecentCatchesSummary? recentCatches,
    DashboardCompareSummary? compare,
    DashboardCaptainAtlasSummary? captainAtlas,
    DashboardTimelineSummary? timeline,
    DashboardTideSummary? tide,
    DashboardForecastSummary? forecast,
    DashboardMapPreviewData? mapPreview,
  }) {
    return DashboardOverview(
      connectionStatus: connectionStatus ?? this.connectionStatus,
      location: location ?? this.location,
      liveScore: liveScore ?? this.liveScore,
      marineReport: marineReport ?? this.marineReport,
      savedSpots: savedSpots ?? this.savedSpots,
      recentCatches: recentCatches ?? this.recentCatches,
      compare: compare ?? this.compare,
      captainAtlas: captainAtlas ?? this.captainAtlas,
      timeline: timeline ?? this.timeline,
      tide: tide ?? this.tide,
      forecast: forecast ?? this.forecast,
      mapPreview: mapPreview ?? this.mapPreview,
    );
  }
}
