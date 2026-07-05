import 'package:deniz_app/domain/marine_intelligence_report.dart';
import 'package:deniz_app/domain/marine_learning_summary.dart';
import 'package:deniz_app/domain/marine_saved_spot.dart';
import 'package:deniz_app/services/marine_intelligence_cache.dart';

/// Marine Intelligence ekran state'i — düşük riskli controller skeleton.
class MarineIntelligenceController {
  MarineIntelligenceController({MarineIntelligenceCache? cache})
      : cache = cache ?? MarineIntelligenceCache();

  final MarineIntelligenceCache cache;

  MarineIntelligenceReport? report;
  List<MarineSavedSpot> spots = [];
  Map<String, MarineLearningSummary> learningSummaries = {};

  bool analyzing = false;
  bool loadingAiComment = false;
  bool offlineCached = false;
  String? busySpotId;
  String? error;
  String? spotsSyncedAt;
  bool refreshIncludeAiComment = false;

  double? selectedLat;
  double? selectedLon;

  bool get hasReport => report != null;
  bool get isBusy => analyzing || loadingAiComment;

  void setCoordinates({double? lat, double? lon}) {
    selectedLat = lat;
    selectedLon = lon;
  }

  void applyCachedBootstrap({
    MarineIntelligenceReport? cachedReport,
    List<MarineSavedSpot>? cachedSpots,
    String? syncedAt,
  }) {
    if (report == null && cachedReport != null) {
      report = cachedReport;
      offlineCached = true;
    }
    if (spots.isEmpty && cachedSpots != null && cachedSpots.isNotEmpty) {
      spots = cachedSpots;
    }
    spotsSyncedAt = syncedAt;
  }

  void clearError() => error = null;

  void dispose() {
    report = null;
    spots = [];
    learningSummaries = {};
    busySpotId = null;
    error = null;
  }
}
