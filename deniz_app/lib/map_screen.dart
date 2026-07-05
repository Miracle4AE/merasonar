import 'dart:async' show StreamSubscription, Timer, unawaited;
import 'dart:developer' show log;

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart' show openAppSettings;

import 'api_service.dart';
import 'domain/app_settings.dart';
import 'services/app_settings_controller.dart';
import 'config/app_config.dart';
import 'domain/calibration_geometry.dart';
import 'domain/geo_visualization_state.dart';
import 'domain/world_map_empty_diagnostics_copy.dart';
import 'domain/world_map_hotspot_layout.dart';
import 'domain/world_map_viewport_state.dart';
import 'map/controllers/map_sheet_controller.dart';
import 'map/hosts/chart_overlay_host.dart';
import 'map/hosts/map_overlay_host.dart';
import 'map/layers/map_marker_layer.dart';
import 'map/map_viewport_bridge.dart';
import 'map/widgets/calibrated_mode_ribbon.dart';
import 'map/widgets/world_map_floating_pills.dart';
import 'services/boat_gps_smoother.dart';
import 'screens/premium_settings_screen.dart';
import 'l10n/app_strings_tr.dart';
import 'local_storage_service.dart';
import 'widgets/backend_connection_badge.dart';
import 'widgets/trust_disclaimer_bar.dart';
import 'map/widgets/control_point_picker_sheet.dart';
import 'map/widgets/hotspot_detail_sheet.dart';
import 'map/widgets/map_control_panel.dart';
import 'navigation/premium_navigator.dart';
import 'screens/marine_intelligence_screen.dart';
import 'map/utils/map_camera_animator.dart';
import 'map/widgets/analysis_history_body.dart';
import 'map/widgets/calibration_profiles_sheet.dart';
import 'map/widgets/premium/map_bottom_chrome.dart';
import 'map/widgets/premium/map_command_bar.dart';
import 'map/widgets/premium/map_hotspot_detail_panel.dart';
import 'map/widgets/premium/map_hotspot_strip.dart';
import 'map/widgets/premium/map_premium_empty_state.dart';
import 'map/widgets/premium/map_premium_legend.dart';
import 'map/widgets/premium/map_premium_toolbox.dart';
import 'map/widgets/premium/map_premium_top_bar.dart';
import 'map/widgets/premium/image_space_warning_card.dart';
import 'map/widgets/premium/photo_analysis_premium_panel.dart';
import 'widgets/premium/navigation/premium_bottom_sheet.dart';
import 'widgets/premium/map_vignette_overlay.dart';
import 'live_area_screen.dart';
import 'screens/marine_compare_screen.dart';
import 'theme/app_colors.dart';
import 'widgets/premium/premium_status_badge.dart';
import 'services/backend_discovery_service.dart';
import 'services/ai_assistant_cache.dart';
import 'services/client_identity_service.dart';
import 'services/chart_image_storage.dart';
import 'services/gpx_share.dart';
import 'services/permissions_helper.dart';
import 'utils/android_backend_host_policy.dart';
import 'utils/app_haptics.dart';
import 'utils/map_world_map_policy.dart';
import 'utils/geo_control_point_layout.dart';
import 'utils/layout_breakpoints.dart';
import 'widgets/premium/feedback/premium_toast.dart';
import 'widgets/premium/feedback/premium_dialog.dart';
import 'navigation/captain_atlas_launcher.dart';

enum VisualizationMode { chartOverlay, worldMap }

/// Ana deneyim: dünya haritası (yetkili) veya fotoğraf üzeri analiz.
enum MerasonarMapExperienceTab { calibratedWorld, photoAnalysis }

bool shouldForceChartOverlay(String? mappingMode) {
  return (mappingMode ?? '').toLowerCase() == 'image_space';
}

Offset hotspotPixelToDisplayedOffset({
  required double hotspotX,
  required double hotspotY,
  required double imageWidth,
  required double imageHeight,
  required double displayedWidth,
  required double displayedHeight,
}) {
  if (imageWidth <= 0 || imageHeight <= 0) return Offset.zero;
  final x = (hotspotX / imageWidth) * displayedWidth;
  final y = (hotspotY / imageHeight) * displayedHeight;
  return Offset(
    x.clamp(0.0, displayedWidth),
    y.clamp(0.0, displayedHeight),
  );
}

class _PhotoAnalysisReference {
  const _PhotoAnalysisReference({
    required this.currentLat,
    required this.currentLon,
    required this.bounds,
    required this.enrichData,
  });

  final double currentLat;
  final double currentLon;
  final ImageGeoBounds bounds;
  final bool enrichData;
}

class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    required this.serverIp,
    this.openControlPointCalibration = false,
  });

  final String serverIp;

  /// When true (e.g. opened from Live Area), bind last chart image if possible,
  /// open control-point picker, and briefly highlight the calibration control in the app bar.
  final bool openControlPointCalibration;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  late ApiService _apiService;
  final LocalStorageService _localStorageService = LocalStorageService();
  final ImagePicker _imagePicker = ImagePicker();
  final MapController _mapController = MapController();
  late final MapCameraAnimator _cameraAnimator;

  bool _isLoading = false;
  bool _showClassA = true;
  bool _showClassB = true;
  bool _showClassC = true;
  bool _showIntensityOverlay = true;
  bool _showCorridorOverlay = false;
  bool _showLegend = true;
  bool _showControls = true;
  final MapSheetController _sheetController = MapSheetController();
  double _minScore = 0.0;
  double _currentZoom = 12;

  double get _mapZoomEffective =>
      _worldMapViewport.value?.zoom ?? _currentZoom;

  /// Oturum kökü / teşhis çıktısı `_geoViz` ile çeliştiğinde bile tekne referanslı modu koru.
  bool get _isEffectiveBoatAnchorEstimatedMode {
    if (_geoViz.isBoatAnchorEstimated) return true;
    if ((_sessionCoordinateMode ?? '').trim() ==
        kCoordinateModeBoatAnchorEstimated) {
      return true;
    }
    final o = (_analysisDiagnostics?.outputCoordinateMode ?? '').trim();
    return o == kCoordinateModeBoatAnchorEstimated;
  }

  String get _firstHotspotLatLonDebugLine {
    for (final h in _hotspots) {
      if (!h.latitude.isFinite || !h.longitude.isFinite) continue;
      if (h.latitude.abs() < 1e-9 && h.longitude.abs() < 1e-9) continue;
      return '${h.latitude.toStringAsFixed(5)},${h.longitude.toStringAsFixed(5)}';
    }
    return '-';
  }

  int get _hiddenByZoomDeclutterCount {
    if (_visualizationMode != VisualizationMode.worldMap || _isImageSpaceMode) {
      return 0;
    }
    final f = _filteredHotspots;
    if (f.isEmpty) return 0;
    final raw = _declutterByZoom(f, _mapZoomEffective);
    return (f.length - raw.length).clamp(0, f.length);
  }

  bool get _showBoatAnchorOffscreenHint =>
      _visualizationMode == VisualizationMode.worldMap &&
      _geoViz.isBoatAnchorEstimated &&
      _geoViz.canRenderWorldMapHotspots &&
      (_analysisDiagnostics?.hotspotGeoCount ?? 0) > 0 &&
      _visibleWorldMapHotspotMarkerCount == 0 &&
      _serverPlausibleGeoHotspotCount > 0;

  String _worldMapExperienceSegmentLabel() {
    return kMapPremiumExperienceMap;
  }

  String _worldMapExperienceSegmentLabelCompact() {
    return kMapPremiumExperienceMap;
  }

  String? _lastError;
  String _serverIp = '127.0.0.1';
  bool _serverDiscoverBusy = false;
  bool _mapHealthChecking = false;
  bool? _mapHealthOkLast;
  /// Çevrimdışıyken kullanıcı "Alanı Tara" ile analiz başlattıysa nazik bildirim.
  bool _offlineAnalyzeAttempt = false;
  String? _lastSelectedChartPath;
  /// Son oturumda JSON önbelleği var, harita dosyası diskte yok / bağlanamıyor.
  bool _cachedAnalysisChartFileMissing = false;
  /// Son kayıtlı yol geçersizken geçmişteki dosya otomatik bağlandı.
  bool _chartFromHistoryFallback = false;
  bool _usingCachedFallback = false;
  HotspotSortMode _sortMode = HotspotSortMode.scoreThenDistance;
  VisualizationMode _visualizationMode = VisualizationMode.chartOverlay;
  MerasonarMapExperienceTab _experienceTab =
      MerasonarMapExperienceTab.photoAnalysis;
  GeoVisualizationState _geoViz = GeoVisualizationState.fallback();
  String? _userWarningTrFromServer;
  int _analyzeGeneration = 0;
  final ValueNotifier<int> _hotspotDataEpoch = ValueNotifier<int>(0);
  final ValueNotifier<WorldMapViewportState?> _worldMapViewport =
      ValueNotifier<WorldMapViewportState?>(null);
  final ValueNotifier<WorldMapHotspotLayoutResult?> _worldHotspotLayout =
      ValueNotifier<WorldMapHotspotLayoutResult?>(null);
  final ValueNotifier<HotspotFocusViewportStatus> _focusViewportStatus =
      ValueNotifier<HotspotFocusViewportStatus>(
    HotspotFocusViewportStatus.none,
  );
  final ValueNotifier<AccuracyAwarePositionState?> _liveGpsState =
      ValueNotifier<AccuracyAwarePositionState?>(null);
  final ValueNotifier<int?> _hotspotFocusId = ValueNotifier<int?>(null);
  final BoatGpsSmoother _boatGpsSmoother = BoatGpsSmoother();
  Timer? _viewportDebounceTimer;
  StreamSubscription<Position>? _gpsStreamSub;
  late final Listenable _worldMapLayersListenable;
  late final Listenable _worldMapMarkersListenable;
  bool _weakGpsSnackShown = false;
  bool _gpsServiceNoticeShown = false;
  bool _gpsPermissionNoticeShown = false;
  bool _gpsStreamErrorShown = false;
  bool _mapReady = false;
  LatLon? _pendingMapCenter;
  double? _pendingMapZoom;
  bool _pendingBoatAnchorBoundsFit = false;
  /// Mobil dünyada runtime debug şeridi varsayılan kapalı; FAB ile açılır.
  final bool _mobileDebugMetricsVisible = false;
  final TransformationController _chartTransformController =
      TransformationController();
  Size _lastChartCanvasSize = Size.zero;
  bool _showDebugOverlay = false;
  double _debugOverlayOpacity = 0.55;

  /// Slow pulse ring for heuristic top-three visit-priority hotspots.
  late AnimationController _recGlow;

  BoatState? _boatState;
  List<Hotspot> _hotspots = const [];
  AnalysisDiagnostics? _analysisDiagnostics;
  /// Son analiz yanıtı kök `coordinate_mode` (teşhis şeridi).
  String? _sessionCoordinateMode;
  /// API’den gelen oturum önerisi paragrafı (olasılıksal yönlendirme).
  String? _sessionAdvice;
  /// Son tam analiz yanıtı — AI asistan isteği için.
  FishingZoneResponse? _lastFishingZoneResponse;
  final AiAssistantCache _aiAssistantCache = AiAssistantCache();
  final ClientIdentityService _clientIdentityService = ClientIdentityService();
  ImageGeoBounds? _lastAnalysisBounds;
  Map<String, int> _lastImageSize = const {'width': 0, 'height': 0};
  Map<String, int> _controlPointsImageSize = const {'width': 0, 'height': 0};
  List<ImageControlPoint> _controlPoints = const [];
  bool _accentCalibrationControls = false;

  @override
  void initState() {
    super.initState();
    _cameraAnimator = MapCameraAnimator(
      controller: _mapController,
      vsync: this,
    );
    _recGlow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1480),
    )..repeat(reverse: true);
    _worldMapLayersListenable = Listenable.merge([
      _worldMapViewport,
      _hotspotDataEpoch,
    ]);
    _worldMapMarkersListenable = Listenable.merge([
      _worldHotspotLayout,
      _liveGpsState,
    ]);
    _worldMapViewport.addListener(_publishWorldMapLayout);
    _hotspotDataEpoch.addListener(_publishWorldMapLayout);
    _hotspotFocusId.addListener(_publishWorldMapLayout);
    final configuredIp = widget.serverIp.trim();
    final normalized = AppConfig.normalizeHost(configuredIp);
    _serverIp = normalized.isEmpty ? '127.0.0.1' : normalized;
    _rebuildApiService();
    _initializeScreen();
  }

  @override
  void dispose() {
    _viewportDebounceTimer?.cancel();
    _gpsStreamSub?.cancel();
    _worldMapViewport.removeListener(_publishWorldMapLayout);
    _hotspotDataEpoch.removeListener(_publishWorldMapLayout);
    _hotspotFocusId.removeListener(_publishWorldMapLayout);
    _hotspotFocusId.dispose();
    _worldMapViewport.dispose();
    _worldHotspotLayout.dispose();
    _focusViewportStatus.dispose();
    _liveGpsState.dispose();
    _hotspotDataEpoch.dispose();
    _cameraAnimator.dispose();
    _mapController.dispose();
    _recGlow.dispose();
    _chartTransformController.dispose();
    super.dispose();
  }

  void _touchHotspotLayoutEpoch() {
    _hotspotDataEpoch.value = _hotspotDataEpoch.value + 1;
  }

  static const int _kBoatAnchorEmergencyMaxMarkers = 14;

  int _compareHotspotsForBoatAnchor(Hotspot a, Hotspot b) {
    if (_sortMode == HotspotSortMode.proximity) {
      return a.rankByProximity.compareTo(b.rankByProximity);
    }
    return a.rankByScoreThenDistance.compareTo(b.rankByScoreThenDistance);
  }

  /// boat_anchor_estimated: doğrudan geo listesi (filtre/küme/viewport yok).
  List<Hotspot> get _boatAnchorEmergencyHotspots =>
      boatAnchorEmergencyWorldMapHotspots(
        _hotspots,
        _kBoatAnchorEmergencyMaxMarkers,
        _compareHotspotsForBoatAnchor,
      );

  LatLon _worldMapFlutterMapCenter() {
    final boat = _boatRenderLatLon;
    if (boat != null &&
        boat.lat.isFinite &&
        boat.lon.isFinite &&
        boat.lat.abs() <= 90 &&
        boat.lon.abs() <= 180 &&
        !(boat.lat.abs() < 1e-9 && boat.lon.abs() < 1e-9)) {
      return boat;
    }
    if (_geoViz.isBoatAnchorEstimated && _boatAnchorEmergencyHotspots.isNotEmpty) {
      final h = _boatAnchorEmergencyHotspots.first;
      return LatLon(lat: h.latitude, lon: h.longitude);
    }
    for (final h in _hotspots) {
      if (hotspotHasPlausibleWorldMapGeo(h)) {
        return LatLon(lat: h.latitude, lon: h.longitude);
      }
    }
    return LatLon(lat: 37.3820, lon: 27.2450);
  }

  void _logWorldMapMarkerPipeline({
    required int backendHotspotCount,
    required int geoValidCount,
    required int layoutInputCount,
    required int clusteredPlacements,
    required int viewportFilteredCount,
    required int finalPlacementCount,
    required String mode,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[MapScreen][WorldMapPipeline] mode=$mode '
      'backend_hotspots=$backendHotspotCount '
      'geo_valid=$geoValidCount '
      'layout_input=$layoutInputCount '
      'clustered_markers=$clusteredPlacements '
      'viewport_filtered=$viewportFilteredCount '
      'final_placements=$finalPlacementCount',
    );
  }

  void _publishWorldMapLayout() {
    if (!mounted) return;
    if (_visualizationMode != VisualizationMode.worldMap) {
      _worldHotspotLayout.value = null;
      _focusViewportStatus.value = HotspotFocusViewportStatus.none;
      return;
    }
    if (!_geoViz.canRenderWorldMapHotspots) {
      _worldHotspotLayout.value = const WorldMapHotspotLayoutResult(
        placements: [],
        focusViewport: HotspotFocusViewportStatus.none,
      );
      _focusViewportStatus.value = HotspotFocusViewportStatus.none;
      return;
    }

    final backendCount = _hotspots.length;
    final geoValidCount = _serverPlausibleGeoHotspotCount;

    final boatAnchor = _geoViz.isBoatAnchorEstimated;
    if (boatAnchor) {
      final forced = _boatAnchorEmergencyHotspots;
      final placements = <WorldMapHotspotPlacement>[
        for (final h in forced) WorldMapHotspotSingle(h),
      ];
      _logWorldMapMarkerPipeline(
        mode: 'boat_anchor_emergency',
        backendHotspotCount: backendCount,
        geoValidCount: geoValidCount,
        layoutInputCount: forced.length,
        clusteredPlacements: 0,
        viewportFilteredCount: 0,
        finalPlacementCount: placements.length,
      );
      _worldHotspotLayout.value = WorldMapHotspotLayoutResult(
        placements: placements,
        focusViewport: HotspotFocusViewportStatus.none,
        inputCandidateCount: forced.length,
        droppedByMinScore: 0,
        hiddenByViewportFilter: 0,
      );
      _focusViewportStatus.value = HotspotFocusViewportStatus.none;

      if (forced.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _scheduleBoatAnchorWorldMapFit();
        });
      }
      return;
    }

    var focus = _hotspotFocusId.value;
    if (focus != null && !_visibleHotspots.any((h) => h.id == focus)) {
      _hotspotFocusId.value = null;
      focus = null;
    }
    final vp = _worldMapViewport.value;
    final pinSingles = <int>{
      ...topGeoHotspotIdsForBoatAnchorPolicy(_filteredHotspots, 3),
      ?focus,
    };
    final layoutInput = _visibleHotspots;
    final res = layoutWorldMapHotspotsResolved(
      candidates: layoutInput,
      mapZoom: vp?.zoom ?? _currentZoom,
      viewportContains: vp?.containsLatLon,
      forceIncludeHotspotIds: pinSingles,
      pinAsSingleHotspotIds: pinSingles,
      focusHotspotId: focus,
      boatAnchorEstimatedPolicy: false,
    );
    var clustered = 0;
    for (final p in res.placements) {
      if (p is WorldMapHotspotCluster) clustered++;
    }
    _logWorldMapMarkerPipeline(
      mode: 'standard_layout',
      backendHotspotCount: backendCount,
      geoValidCount: geoValidCount,
      layoutInputCount: layoutInput.length,
      clusteredPlacements: clustered,
      viewportFilteredCount: res.hiddenByViewportFilter,
      finalPlacementCount: res.placements.length,
    );
    _worldHotspotLayout.value = res;
    _focusViewportStatus.value = res.focusViewport;
  }

  void _scheduleViewportFromMapCamera(MapCamera camera) {
    _currentZoom = camera.zoom;
    _viewportDebounceTimer?.cancel();
    _viewportDebounceTimer = Timer(const Duration(milliseconds: 92), () {
      if (!mounted || !_mapReady) return;
      final now = DateTime.now();
      final next = _mapController.camera.tryToWorldMapViewportState(now);
      if (next == null) return;
      final prev = _worldMapViewport.value;
      if (prev != null && prev.approximatelySameAs(next)) {
        return;
      }
      _worldMapViewport.value = next;
    });
  }

  void _primeWorldMapViewportFromController() {
    if (!mounted || !_mapReady) return;
    final now = DateTime.now();
    final next = _mapController.camera.tryToWorldMapViewportState(now);
    if (next != null) {
      _worldMapViewport.value = next;
    }
  }

  void _safePremiumSnack(
    String message, {
    PremiumToastType type = PremiumToastType.info,
    Duration duration = const Duration(seconds: 5),
  }) {
    if (!mounted) return;
    PremiumToast.show(context, message, type: type, duration: duration);
  }

  Future<void> _ensureLiveGpsStreamStarted() async {
    if (_gpsStreamSub != null) return;
    if (_visualizationMode != VisualizationMode.worldMap) return;
    try {
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!mounted) return;
      if (!serviceOn) {
        if (!_gpsServiceNoticeShown) {
          _gpsServiceNoticeShown = true;
          _safePremiumSnack(kMapGpsServiceDisabledPremium);
        }
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (!mounted) return;
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (!mounted) return;
      if (perm == LocationPermission.deniedForever) {
        if (!_gpsPermissionNoticeShown) {
          _gpsPermissionNoticeShown = true;
          _safePremiumSnack(kMapGpsPermissionForeverPremium);
        }
        return;
      }
      if (perm == LocationPermission.denied) {
        if (!_gpsPermissionNoticeShown) {
          _gpsPermissionNoticeShown = true;
          _safePremiumSnack(kMapGpsPermissionDeniedPremium);
        }
        return;
      }
      _gpsStreamSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 12,
        ),
      ).listen(
        (pos) {
          if (!mounted) return;
          final acc = pos.accuracy;
          final st = _boatGpsSmoother.ingest(
            lat: pos.latitude,
            lon: pos.longitude,
            accuracyM: acc.isFinite ? acc.clamp(1.0, 400.0) : null,
          );
          _liveGpsState.value = st;
          final rel = st.reliability;
          if (rel < 0.38 && !_weakGpsSnackShown) {
            _weakGpsSnackShown = true;
            _safePremiumSnack(
              kMapGpsWeakHint,
              duration: const Duration(seconds: 4),
            );
          }
        },
        onError: (Object _, StackTrace stackTrace) {
          _stopLiveGpsStream();
          if (!mounted) return;
          if (!_gpsStreamErrorShown) {
            _gpsStreamErrorShown = true;
            _safePremiumSnack(kMapGpsStreamDegradedPremium);
          }
        },
        cancelOnError: false,
      );
      _gpsStreamErrorShown = false;
    } catch (_) {
      if (!mounted) return;
      if (!_gpsStreamErrorShown) {
        _gpsStreamErrorShown = true;
        _safePremiumSnack(kMapGpsStreamDegradedPremium);
      }
    }
  }

  void _stopLiveGpsStream() {
    _gpsStreamSub?.cancel();
    _gpsStreamSub = null;
  }

  void _syncLiveGpsStreamWithMode() {
    if (_visualizationMode == VisualizationMode.worldMap) {
      unawaited(_ensureLiveGpsStreamStarted());
    } else {
      _stopLiveGpsStream();
    }
  }

  Future<void> _initializeScreen() async {
    _applyMapSettingsFromApp();
    await _autoDetectServerIp();
    await _loadServerIp();
    await _refreshMapHealthOnce();
    await _loadCachedData();
    _maybeAutoOpenMarkerDetail();
    if (mounted && widget.openControlPointCalibration) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _openCalibrationHighlightFlowFromLiveArea();
      });
    }
  }

  Future<void> _tryBindLatestChartImagePathFromStorage() async {
    if (_lastSelectedChartPath != null &&
        File(_lastSelectedChartPath!).existsSync()) {
      return;
    }
    final fromPrefs = await _localStorageService.loadLatestFishingZoneChartPath();
    if (fromPrefs != null &&
        fromPrefs.isNotEmpty &&
        File(fromPrefs).existsSync()) {
      if (!mounted) return;
      setState(() {
        _lastSelectedChartPath = fromPrefs;
        _chartFromHistoryFallback = false;
      });
      debugPrint(
        '[MapScreen] bind chart from prefs: $fromPrefs exists=true',
      );
      return;
    }
    final entry =
        await _localStorageService.newestHistoryEntryWithExistingChart();
    if (entry == null) return;
    final p = entry.chartImagePath?.trim();
    if (p == null || p.isEmpty) return;
    final w = entry.response.imageSize['width'] ?? 0;
    final h = entry.response.imageSize['height'] ?? 0;
    if (w < 2 || h < 2) return;
    if (!mounted) return;
    setState(() {
      _lastSelectedChartPath = p;
      _lastImageSize = Map<String, int>.from(entry.response.imageSize);
      _chartFromHistoryFallback = true;
    });
    debugPrint('[MapScreen] bind chart from history: $p exists=true');
  }

  Future<void> _openCalibrationHighlightFlowFromLiveArea() async {
    await _tryBindLatestChartImagePathFromStorage();
    if (!mounted) return;
    setState(() => _accentCalibrationControls = true);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (_lastSelectedChartPath != null &&
          File(_lastSelectedChartPath!).existsSync()) {
        await _editControlPointsForLastChart();
      } else {
        _safePremiumSnack(kMapNoChartLinkedLiveCalibSnack, duration: const Duration(seconds: 8));
      }
      Future<void>.delayed(const Duration(seconds: 14), () {
        if (mounted) {
          setState(() => _accentCalibrationControls = false);
        }
      });
    });
  }

  Future<void> _autoDetectServerIp() async {
    // Windows: yerel API (127.0.0.1) korunsun; LAN IP firewall ile saglik kontrolu bozulmasin
    if (Platform.isWindows) return;
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      if (interfaces.isNotEmpty && interfaces.first.addresses.isNotEmpty) {
        final realIp = interfaces.first.addresses.first.address;
        if (!mounted) return;
        setState(() => _serverIp = realIp);
        _rebuildApiService();
      }
    } catch (_) {}
  }

  Future<void> _loadServerIp() async {
    final saved = await _localStorageService.loadServerIp();
    if (!mounted || saved == null) return;
    final normalized = AppConfig.normalizeHost(saved);
    if (normalized.isEmpty ||
        normalized == _serverIp ||
        normalized == 'localhost' ||
        normalized == '127.0.0.1' ||
        normalized == '::1') {
      return;
    }
    setState(() => _serverIp = normalized);
    _rebuildApiService();
  }

  void _rebuildApiService() {
    final port = AppSettingsScope.maybeOf(context)?.settings.serverPort;
    _apiService = ApiService(
      serverBaseUrl: AppConfig.buildApiBaseUrl(_serverIp, port: port),
    );
  }

  void _applyMapSettingsFromApp() {
    final s = AppSettingsScope.maybeOf(context)?.settings;
    if (s == null) return;
    setState(() {
      _showClassA = s.filterClassA;
      _showClassB = s.filterClassB;
      _showClassC = s.filterClassC;
      _showIntensityOverlay = s.intensityOverlayDefault;
      _showCorridorOverlay = s.corridorLinesDefault;
      _showLegend = s.legendDefault;
      _minScore = s.minHotspotScore;
      _sortMode = s.defaultHotspotSort == HotspotSortPreference.proximity
          ? HotspotSortMode.proximity
          : HotspotSortMode.scoreThenDistance;
      _experienceTab = s.defaultMapExperience == DefaultMapExperience.map
          ? MerasonarMapExperienceTab.calibratedWorld
          : MerasonarMapExperienceTab.photoAnalysis;
    });
  }

  void _maybeAutoOpenMarkerDetail() {
    final s = AppSettingsScope.maybeOf(context)?.settings;
    if (s == null || !s.autoOpenMarkerDetail) return;
    final visible = _filteredHotspots;
    if (visible.isEmpty) return;
    _openHotspotDetail(visible.first);
  }

  Future<void> _loadCachedData() async {
    final cached = await _localStorageService.loadLatestFishingZoneResponse();
    if (!mounted) return;

    if (cached == null) return;

    final savedPath = await _localStorageService.loadLatestFishingZoneChartPath();
    debugPrint('[MapScreen] loadCachedData: saved image_path=$savedPath');

    String? resolved = (savedPath != null && savedPath.isNotEmpty)
        ? savedPath
        : null;
    var usedHistoryFallback = false;
    if (resolved != null && resolved.isNotEmpty) {
      if (!File(resolved).existsSync()) {
        debugPrint(
          '[MapScreen] loadCachedData: saved path missing on disk, trying history',
        );
        resolved = await _localStorageService.newestExistingChartPathFromHistory();
        usedHistoryFallback = true;
      }
    } else {
      resolved = await _localStorageService.newestExistingChartPathFromHistory();
      usedHistoryFallback = true;
    }

    final exists =
        resolved != null && resolved.isNotEmpty && File(resolved).existsSync();
    debugPrint(
      '[MapScreen] loadCachedData: resolved=$resolved fileExists=$exists',
    );

    setState(() {
      _applyResponseToScreen(cached, usingCachedFallback: true);
      _lastSelectedChartPath = exists ? resolved : null;
      _cachedAnalysisChartFileMissing = !exists;
      _chartFromHistoryFallback = exists && usedHistoryFallback;
    });

    _centerOnBoat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncLiveGpsStreamWithMode();
    });
  }

  void _applyResponseToScreen(
    FishingZoneResponse response, {
    required bool usingCachedFallback,
  }) {
    final hinted = FishingZoneResponse.withEnsuredCoordinateMode(
      response,
      fallbackCoordinateModeHint: _controlPoints.length >= 3
          ? kCoordinateModeGeoReferenced
          : null,
    );

    _sessionCoordinateMode = hinted.coordinateMode?.trim();
    _boatState = hinted.boat;
    _hotspots = hinted.hotspots;
    _analysisDiagnostics = hinted.diagnostics;
    _sessionAdvice = hinted.sessionAdvice;
    _lastFishingZoneResponse = hinted;
    _lastImageSize = hinted.imageSize;
    _lastError = null;
    _usingCachedFallback = usingCachedFallback;

    _geoViz = GeoVisualizationState.fromFishingZone(
      hinted,
      fallbackCoordinateModeHint: _controlPoints.length >= 3
          ? kCoordinateModeGeoReferenced
          : null,
      clientGeometry: _controlPoints.length >= 3
          ? assessImageControlPoints(_controlPoints)
          : null,
      markerAlignment: assessHotspotGeoAlignment(_hotspots),
    );
    if (kDebugMode) {
      final geom = _geoViz.clientGeometry;
      final align = _geoViz.markerAlignment;
      if (geom != null && !geom.isValid) {
        debugPrint(
          'Map calibration geometry: ${geom.level.name} '
          'area=${geom.triangleAreaM2?.toStringAsFixed(0)}m² '
          'spread=${geom.crossTrackSpreadM?.toStringAsFixed(0)}m '
          'reason=${geom.reasonCode}',
        );
      }
      if (align?.isStringLike == true) {
        debugPrint(
          'Map hotspot alignment warning: cross=${align!.crossTrackSpreadM?.toStringAsFixed(0)}m '
          'along=${align.alongTrackSpreadM?.toStringAsFixed(0)}m n=${align.sampleCount}',
        );
      }
    }
    _userWarningTrFromServer = hinted.userWarningTr;
    if (_boatState != null) {
      _boatGpsSmoother.seedFromBoatState(_boatState!);
      _liveGpsState.value = _boatGpsSmoother.state;
    } else {
      _liveGpsState.value = null;
    }
    _touchHotspotLayoutEpoch();
    _weakGpsSnackShown = false;
    _gpsStreamErrorShown = false;
    _gpsServiceNoticeShown = false;
    _gpsPermissionNoticeShown = false;
    _hotspotFocusId.value = null;

    if (_geoViz.canRenderWorldMapHotspots) {
      _experienceTab = MerasonarMapExperienceTab.calibratedWorld;
      _visualizationMode = VisualizationMode.worldMap;
    } else {
      _experienceTab = MerasonarMapExperienceTab.photoAnalysis;
      _visualizationMode = VisualizationMode.chartOverlay;
    }

    if (_geoViz.canRenderWorldMapHotspots) {
      _scheduleBoatAnchorWorldMapFit();
    }
  }

  void _focusHotspot(int? id, {bool requestRebuild = false}) {
    _hotspotFocusId.value = id;
    if (requestRebuild && mounted) {
      setState(() {});
    }
  }

  void _openHotspotDetail(Hotspot hotspot) {
    if (kDebugMode) {
      debugPrint('Map hotspot tapped: ${hotspot.id}');
    }
    _focusHotspot(hotspot.id);
    _animateCameraToHotspot(hotspot);
    final mobile = useMobileLayout(context);
    if (mobile) {
      if (kDebugMode) {
        debugPrint('Opening hotspot detail bottom sheet');
      }
      _showHotspotDetailBottomSheet(hotspot);
      return;
    }
    if (kDebugMode) {
      debugPrint('Opening hotspot detail panel');
    }
    setState(() => _sheetController.openPanel(hotspot));
  }

  void _showHotspotDetailBottomSheet(Hotspot hotspot) {
    final boat = _boatState;
    final boatPos = boat?.navigationAnchorGeo ?? boat?.smoothedGps ?? boat?.rawGps;
    final summary = hotspot.reasoningText.trim().isNotEmpty
        ? hotspot.reasoningText
        : (_sessionAdvice ?? '').trim();
    showPremiumBottomSheet<void>(
      context: context,
      builder: (ctx) {
        final height = MediaQuery.sizeOf(ctx).height * 0.86;
        return SizedBox(
          height: height,
          child: MapHotspotDetailPanel(
            embedded: true,
            hotspot: hotspot,
            onClose: () => Navigator.of(ctx).pop(),
            captainSummary: summary.isEmpty ? null : summary,
            onGo: () {
              Navigator.of(ctx).pop();
              if (_visualizationMode == VisualizationMode.chartOverlay) {
                _centerChartOnHotspot(hotspot);
              } else {
                _centerMapOnHotspot(hotspot);
              }
            },
            onCompare: () {
              Navigator.of(ctx).pop();
              _openMarineCompareFromMap();
            },
            onSave: () {
              Navigator.of(ctx).pop();
              _saveHotspotFromMap(hotspot);
            },
            detailSheet: HotspotDetailSheet(
              hotspot: hotspot,
              geoVisualization: _geoViz,
              boatPosition: boatPos,
              apiService: _apiService,
              sessionAnalysis: _lastFishingZoneResponse,
              aiAssistantCache: _aiAssistantCache,
              clientIdentityService: _clientIdentityService,
              slidePanel: true,
            ),
          ),
        );
      },
    );
  }

  File? _resolveDebugOverlayFile() {
    final path = _analysisDiagnostics?.imageSpaceDebugOverlayPath;
    if (path == null || path.trim().isEmpty) return null;
    final direct = File(path);
    if (direct.existsSync()) return direct;
    final chartPath = _lastSelectedChartPath;
    if (chartPath != null) {
      final baseName = path.split(Platform.pathSeparator).last;
      final sibling = File('${File(chartPath).parent.path}${Platform.pathSeparator}$baseName');
      if (sibling.existsSync()) return sibling;
    }
    return null;
  }

  String _chartCoordinateModeLabel() {
    if (_isImageSpaceMode) return kMapChartOverlayModeImageSpace;
    if (_controlPoints.length >= 3) return kMapChartOverlayModeGeoReferenced;
    return _geoViz.coordinateMode;
  }

  String? _chartCalibrationChipLabel() {
    final raw = _analysisDiagnostics?.calibrationReliability;
    if (raw == null || raw.trim().isEmpty) return null;
    switch (raw.trim().toLowerCase()) {
      case 'excellent':
      case 'good':
        return kMapCalibReliabilityGood;
      case 'approximate':
      case 'fair':
        return kMapCalibReliabilityMedium;
      case 'unsafe':
      case 'poor':
        return kMapCalibReliabilityLow;
      default:
        return raw;
    }
  }

  PremiumStatusTone _chartCalibrationChipTone() {
    final raw = _analysisDiagnostics?.calibrationReliability;
    if (raw == null) return PremiumStatusTone.neutral;
    switch (raw.trim().toLowerCase()) {
      case 'excellent':
      case 'good':
        return PremiumStatusTone.success;
      case 'approximate':
      case 'fair':
        return PremiumStatusTone.warning;
      case 'unsafe':
      case 'poor':
        return PremiumStatusTone.danger;
      default:
        return PremiumStatusTone.neutral;
    }
  }

  void _centerChartOnHotspot(Hotspot hotspot) {
    final canvas = _lastChartCanvasSize;
    if (canvas.width < 1 || canvas.height < 1) return;
    final anchor = hotspot.hotspotPixelAnchor;
    final offset = _pixelToCanvas(anchor, canvas);
    final scale = 2.2;
    final tx = canvas.width / 2 - offset.dx * scale;
    final ty = canvas.height / 2 - offset.dy * scale;
    _chartTransformController.value = Matrix4.identity()
      ..translateByDouble(tx, ty, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
    _closeHotspotPanel();
  }

  void _switchToWorldMapFromChart() {
    if (!_geoViz.canRenderWorldMapHotspots) return;
    setState(() {
      _experienceTab = MerasonarMapExperienceTab.calibratedWorld;
      _visualizationMode = VisualizationMode.worldMap;
    });
    _syncLiveGpsStreamWithMode();
  }

  void _openChartCalibration() {
    unawaited(_editControlPointsForLastChart());
  }

  void _closeHotspotPanel() {
    setState(() => _sheetController.closePanel());
    _focusHotspot(null);
  }

  void _animateCameraToHotspot(Hotspot hotspot) {
    if (_visualizationMode != VisualizationMode.worldMap || !_mapReady) return;
    if (!hotspot.latitude.isFinite || !hotspot.longitude.isFinite) return;
    _cameraAnimator.animateTo(
      LatLng(hotspot.latitude, hotspot.longitude),
      zoom: _mapController.camera.zoom.clamp(10.0, 16.0),
    );
  }

  void _focusMapContextBeforeNavigation({Hotspot? hotspot}) {
    if (hotspot != null) {
      _animateCameraToHotspot(hotspot);
      return;
    }
    if (_visualizationMode != VisualizationMode.worldMap || !_mapReady) return;
    final boat = _boatRenderLatLon;
    if (boat == null) return;
    _cameraAnimator.animateTo(
      LatLng(boat.lat, boat.lon),
      zoom: _mapController.camera.zoom.clamp(11.0, 14.0),
    );
  }

  void _openLiveAreaFromMap() {
    _focusMapContextBeforeNavigation();
    PremiumNavigator.push<void>(
      context,
      LiveAreaScreen(serverIp: _serverIp),
    );
  }

  void _openMarineCompareFromMap() {
    _focusMapContextBeforeNavigation();
    PremiumNavigator.push<void>(
      context,
      MarineCompareScreen(serverIp: _serverIp),
    );
  }

  void _openMarineIntelligenceFromMap() {
    _focusMapContextBeforeNavigation();
    PremiumNavigator.push<void>(
      context,
      MarineIntelligenceScreen(serverIp: _serverIp),
    );
  }

  void _centerMapOnHotspot(Hotspot hotspot) {
    _animateCameraToHotspot(hotspot);
    _closeHotspotPanel();
  }

  void _saveHotspotFromMap(Hotspot hotspot) {
    _closeHotspotPanel();
    PremiumNavigator.push<void>(
      context,
      MarineIntelligenceScreen(
        serverIp: _serverIp,
        initialLat: hotspot.latitude,
        initialLon: hotspot.longitude,
      ),
    );
  }

  String? _gpsReliabilityLabel() {
    final live = _liveGpsState.value;
    if (live == null) return null;
    final rel = live.reliability;
    if (rel >= 0.68) return kMapGpsPillReliable;
    if (rel >= 0.42) return kMapGpsPillApprox;
    return kMapGpsPillWeak;
  }

  PremiumStatusTone _gpsReliabilityTone() {
    final live = _liveGpsState.value;
    if (live == null) return PremiumStatusTone.neutral;
    final rel = live.reliability;
    if (rel >= 0.68) return PremiumStatusTone.success;
    if (rel >= 0.42) return PremiumStatusTone.warning;
    return PremiumStatusTone.danger;
  }

  void _navigateBackHome() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    navigator.popUntil((route) => route.isFirst);
  }

  String? _mapModeBadgeLabel() {
    if (_visualizationMode != VisualizationMode.worldMap) {
      return kMapPremiumExperiencePhotoHint;
    }
    final cm = _geoViz.coordinateMode;
    if (cm == kCoordinateModeBoatAnchorEstimated) {
      return kMapPremiumExperienceMapHint;
    }
    if (cm == kCoordinateModeImageSpace) {
      return kMapTabCalibrationRequiredWorld;
    }
    return kMapTabCalibratedMap;
  }

  bool get _worldMapHotspotStripVisible =>
      _geoViz.canRenderWorldMapHotspots &&
      _visualizationMode == VisualizationMode.worldMap &&
      _filteredHotspots.isNotEmpty;

  MapPremiumToolbox _buildMapToolbox({
    VoidCallback? onRefreshOverride,
    VoidCallback? onCenterBoatOverride,
  }) {
    return MapPremiumToolbox(
      showClassA: _showClassA,
      showClassB: _showClassB,
      showClassC: _showClassC,
      minScore: _minScore,
      showIntensity: _showIntensityOverlay,
      showCorridor: _showCorridorOverlay,
      showLegend: _showLegend,
      sortMode: _sortMode,
      gpsReliabilityLabel: _gpsReliabilityLabel(),
      gpsReliabilityTone: _gpsReliabilityTone(),
      onToggleClassA: (v) {
        setState(() => _showClassA = v);
        _touchHotspotLayoutEpoch();
      },
      onToggleClassB: (v) {
        setState(() => _showClassB = v);
        _touchHotspotLayoutEpoch();
      },
      onToggleClassC: (v) {
        setState(() => _showClassC = v);
        _touchHotspotLayoutEpoch();
      },
      onMinScoreChanged: (v) {
        setState(() => _minScore = v);
        _touchHotspotLayoutEpoch();
      },
      onToggleIntensity: (v) {
        setState(() => _showIntensityOverlay = v);
        _touchHotspotLayoutEpoch();
      },
      onToggleCorridor: (v) {
        setState(() => _showCorridorOverlay = v);
        _touchHotspotLayoutEpoch();
      },
      onToggleLegend: (v) {
        setState(() => _showLegend = v);
        _touchHotspotLayoutEpoch();
      },
      onSortModeChanged: (v) {
        setState(() => _sortMode = v);
        _touchHotspotLayoutEpoch();
      },
      onRefresh: onRefreshOverride ?? _refreshAnalysis,
      onCenterBoat: onCenterBoatOverride ?? _centerOnBoat,
    );
  }

  MapMarkerLayer _markerLayer() {
    return MapMarkerLayer(
      recGlow: _recGlow,
      hotspotFocusId: _hotspotFocusId,
      geoViz: _geoViz,
      isWorldMapMode: _visualizationMode == VisualizationMode.worldMap,
      boatRenderLatLon: _boatRenderLatLon,
      liveGpsState: _liveGpsState,
      boatAnchorLowConfidence: _boatAnchorLowConfidence,
      isGpsFallbackBoat: _isGpsFallbackBoat,
      classificationColor: _classificationColor,
      markerLabel: _markerLabel,
      markerLabelWithNav: _markerLabelWithNav,
      displayScorePct: _displayScorePct,
      recommendationBadgeLabel: _recommendationBadgeLabel,
      hotspotTooltipExtended: _hotspotTooltipExtended,
      pixelToCanvas: _pixelToCanvas,
      onHotspotTap: _openHotspotDetail,
      onClusterTap: _showClusterSheet,
    );
  }

  Widget _buildHotspotDetailOverlay() {
    final hotspot = _sheetController.panelHotspot;
    if (hotspot == null) return const SizedBox.shrink();
    final boat = _boatState;
    final boatPos = boat?.navigationAnchorGeo ?? boat?.smoothedGps ?? boat?.rawGps;
    final summary = hotspot.reasoningText.trim().isNotEmpty
        ? hotspot.reasoningText
        : (_sessionAdvice ?? '').trim();
    return Positioned.fill(
      child: MapHotspotDetailOverlayHost(
      hotspot: hotspot,
      isChartOverlay: _visualizationMode == VisualizationMode.chartOverlay,
      mobileLayout: useMobileLayout(context),
      geoViz: _geoViz,
      boatPosition: boatPos,
      apiService: _apiService,
      sessionAnalysis: _lastFishingZoneResponse,
      aiCache: _aiAssistantCache,
      clientIdentity: _clientIdentityService,
      captainSummary: summary.isEmpty ? null : summary,
      onClose: _closeHotspotPanel,
      onGo: _visualizationMode == VisualizationMode.chartOverlay
          ? () => _centerChartOnHotspot(hotspot)
          : () => _centerMapOnHotspot(hotspot),
      onCompare: _openMarineCompareFromMap,
      onSave: () => _saveHotspotFromMap(hotspot),
      ),
    );
  }

  void _showClusterSheet(List<Hotspot> members) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xF0121A24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kMapClusterSheetTitle(members.length),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: members.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final h = members[i];
                      return ListTile(
                        textColor: Colors.white70,
                        title: Text(
                          '${h.classification} · #${h.rankByScoreThenDistance}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          kMapClusterRowSubtitle(
                            (h.score * 100).round().clamp(0, 999),
                          ),
                          style: TextStyle(
                            color: Colors.cyanAccent.shade100,
                          ),
                        ),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _openHotspotDetail(h);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _scanArea() async {
    if (_isLoading) return;

    final perm = await ensureChartImagePickerPrepared();
    if (!mounted) return;
    if (perm == PermissionResult.permanentlyDenied) {
      AppHaptics.warning();
      _safePremiumSnack(kMapPhotosPermBlocked);
      return;
    }
    if (perm == PermissionResult.denied) {
      AppHaptics.warning();
      _safePremiumSnack(kMapPhotosDeniedSnack);
      return;
    }

    final selectedImage = await _pickChartImage();
    if (selectedImage == null) return;

    final chartFile = await materializePickedChartImage(selectedImage);
    final imageSize = await _readImageSize(chartFile);
    final reusableControlPoints = _sameImageSize(imageSize, _lastImageSize)
        ? _controlPoints
        : const <ImageControlPoint>[];
    if (!mounted) return;
    setState(() {
      _lastSelectedChartPath = chartFile.path;
      _lastImageSize = imageSize;
      _controlPoints = reusableControlPoints;
      _cachedAnalysisChartFileMissing = false;
      _chartFromHistoryFallback = false;
    });

    final pickedControlPoints = await _showControlPointPicker(
      chartImageFile: chartFile,
      imageSize: imageSize,
      initialPoints: reusableControlPoints,
    );
    if (pickedControlPoints != null) {
      _controlPoints = pickedControlPoints;
      _controlPointsImageSize = Map<String, int>.from(imageSize);
    } else if (reusableControlPoints.isEmpty && mounted) {
      _safePremiumSnack(kMapSnackNoControlPointsAnalysis);
    }
    await _runAnalysis(chartImageFile: chartFile, imageSize: imageSize);
  }

  Future<void> _refreshAnalysis() async {
    if (_isLoading) return;

    if (_lastSelectedChartPath != null &&
        File(_lastSelectedChartPath!).existsSync()) {
      final chartFile = File(_lastSelectedChartPath!);
      final imageSize = await _readImageSize(chartFile);
      await _runAnalysis(chartImageFile: chartFile, imageSize: imageSize);
      return;
    }

    if (!mounted) return;
    _safePremiumSnack(kMapSnackRefreshNeedsChart);
  }

  Future<void> _runAnalysis({
    required File chartImageFile,
    required Map<String, int> imageSize,
  }) async {
    final gen = ++_analyzeGeneration;
    setState(() {
      _isLoading = true;
      _lastError = null;
    });

    var serverReachableForRun = false;
    try {
      final health = await _apiService.checkHealth();
      if (!mounted || gen != _analyzeGeneration) return;
      if (!health.ok) {
        AppHaptics.lightTap();
        setState(() {
          _mapHealthOkLast = false;
          _lastError = null;
          _offlineAnalyzeAttempt = true;
          _usingCachedFallback = _hotspots.isNotEmpty;
        });
        return;
      }
      serverReachableForRun = true;

      final reference = await _buildPhotoAnalysisReference(imageSize);

      final result = await _apiService.analyzeFishingZone(
        currentLat: reference.currentLat,
        currentLon: reference.currentLon,
        bounds: reference.bounds,
        chartImageFile: chartImageFile,
        enrichData: reference.enrichData,
      );

      if (!mounted || gen != _analyzeGeneration) return;
      setState(() {
        _applyResponseToScreen(result, usingCachedFallback: false);
        _mapHealthOkLast = true;
        _offlineAnalyzeAttempt = false;
        _lastAnalysisBounds = reference.bounds;
        final serverSize = result.imageSize;
        if ((serverSize['width'] ?? 0) > 1 && (serverSize['height'] ?? 0) > 1) {
          _lastImageSize = Map<String, int>.from(serverSize);
        } else {
          _lastImageSize = imageSize;
        }
        if (_controlPoints.length >= 3) {
          final synced = _syncControlPointsToImageSize(_lastImageSize);
          _controlPoints = synced;
          _controlPointsImageSize = Map<String, int>.from(_lastImageSize);
        }
        _cachedAnalysisChartFileMissing = false;
        _chartFromHistoryFallback = false;
      });
      AppHaptics.analysisComplete();
      debugPrint(
        '[MapScreen] after analyze, persist chart path: ${chartImageFile.path} '
        'exists=${chartImageFile.existsSync()}',
      );
      final hinted = FishingZoneResponse.withEnsuredCoordinateMode(
        result,
        fallbackCoordinateModeHint: _controlPoints.length >= 3
            ? kCoordinateModeGeoReferenced
            : null,
      );
      await _localStorageService.saveLatestFishingZoneResponse(
        hinted,
        chartImagePath: chartImageFile.path,
        controlPointCount: _controlPoints.length,
      );
      if (!mounted || gen != _analyzeGeneration) return;
      if (_hotspots.isNotEmpty && _geoViz.canRenderWorldMapHotspots) {
        _scheduleBoatAnchorWorldMapFit();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      final muted = _isOfflineLikeApiError(e);
      if (muted && !serverReachableForRun) {
        AppHaptics.lightTap();
        setState(() {
          _mapHealthOkLast = false;
          _lastError = null;
          _offlineAnalyzeAttempt = true;
          _usingCachedFallback = _hotspots.isNotEmpty;
        });
      } else {
        AppHaptics.warning();
        final message = _diagnosticMessage(e, serverReachable: serverReachableForRun);
        setState(() {
          if (!serverReachableForRun) {
            _mapHealthOkLast = false;
          }
          _lastError = message;
          _offlineAnalyzeAttempt = !serverReachableForRun;
          _usingCachedFallback = _hotspots.isNotEmpty;
        });
        _safePremiumSnack(
          _usingCachedFallback
              ? _cachedFallbackErrorText(message)
              : message,
          type: _usingCachedFallback
              ? PremiumToastType.offline
              : PremiumToastType.error,
        );
      }
    } catch (e, st) {
      if (!mounted) return;
      AppHaptics.lightTap();
      log('map_screen analyze unexpected: $e', name: 'MapScreen', stackTrace: st);
      setState(() {
        if (!serverReachableForRun) {
          _mapHealthOkLast = false;
        }
        _lastError = serverReachableForRun
            ? 'Analiz sırasında beklenmeyen bir hata oluştu.\n$kMsgNetworkRetryHint'
            : null;
        _offlineAnalyzeAttempt = !serverReachableForRun;
      });
      if (serverReachableForRun) {
        _safePremiumSnack(_lastError!, type: PremiumToastType.error);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _isOfflineLikeApiError(ApiException e) {
    switch (e.type) {
      case ApiErrorType.invalidResponse:
        return false;
      case ApiErrorType.serverUnreachable:
      case ApiErrorType.timeout:
      case ApiErrorType.invalidAddressOrPort:
      case ApiErrorType.backendUnavailable:
      case ApiErrorType.networkUnavailable:
      case ApiErrorType.unknown:
        return true;
    }
  }

  String _diagnosticMessage(ApiException e, {required bool serverReachable}) {
    log('map_screen ApiException type=${e.type}', name: 'MapScreen');
    if (serverReachable) {
      if (e.message.trim().isNotEmpty &&
          e.message.trim() != kMsgSunucuyaUlasilamiyor) {
        return e.message.trim();
      }
      switch (e.type) {
        case ApiErrorType.invalidResponse:
          return 'Sunucudan beklenmeyen analiz yanıtı alındı.';
        case ApiErrorType.timeout:
          return kMsgAnalysisTimeout;
        case ApiErrorType.backendUnavailable:
          return e.statusCode != null
              ? kMsgAnalysisHttpError(e.statusCode!)
              : 'Analiz sunucuda tamamlanamadı. Tekrar deneyin.';
        default:
          return 'Analiz güncellenemedi. Tekrar deneyin.';
      }
    }
    switch (e.type) {
      case ApiErrorType.invalidResponse:
        return 'Sunucudan beklenmeyen yanıt alındı.\n$kMsgNetworkRetryHint';
      case ApiErrorType.serverUnreachable:
      case ApiErrorType.timeout:
      case ApiErrorType.invalidAddressOrPort:
      case ApiErrorType.backendUnavailable:
      case ApiErrorType.networkUnavailable:
      case ApiErrorType.unknown:
        return '$kMsgSunucuyaUlasilamiyor\n$kMsgNetworkRetryHint';
    }
  }

  String _cachedFallbackErrorText(String message) {
    if (_mapHealthOkLast == true) {
      return '$message\n$kMsgAnalysisCachedWhileServerUp';
    }
    return '$message\nYalnızca önbellek verisi gösteriliyor.';
  }

  void _showMarineLongPressSheet(LatLng point) {
    AppHaptics.lightTap();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF142434),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              kMarineMapLongPressTitle,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => MarineIntelligenceScreen(
                      serverIp: _serverIp,
                      initialLat: point.latitude,
                      initialLon: point.longitude,
                    ),
                  ),
                );
              },
              child: Text(kMarineGoToAnalysis),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshMapHealthOnce() async {
    if (!mounted) return;
    final sip = _serverIp.trim();
    if (Platform.isAndroid && shouldBlockAndroidLoopbackHost(sip)) {
      setState(() => _mapHealthOkLast = null);
      return;
    }
    setState(() => _mapHealthChecking = true);
    try {
      final api = ApiService(
        serverBaseUrl: AppConfig.buildApiBaseUrl(sip),
      );
      final r = await api.checkHealth();
      if (!mounted) return;
      setState(() {
        _mapHealthOkLast = r.ok;
        if (r.ok) {
          _offlineAnalyzeAttempt = false;
          if (_lastError != null &&
              _lastError!.contains(kMsgSunucuyaUlasilamiyor)) {
            _lastError = null;
          }
        }
      });
    } catch (e, st) {
      log('map _refreshMapHealthOnce: $e', name: 'MapScreen', stackTrace: st);
      if (!mounted) return;
      setState(() => _mapHealthOkLast = false);
    } finally {
      if (mounted) {
        setState(() => _mapHealthChecking = false);
      }
    }
  }

  Future<void> _showServerIpDialog() async {
    final badge = resolveBackendConnectionBadge(
      serverIp: _serverIp,
      discoveryBusy: _serverDiscoverBusy,
      serverHealthChecking: _mapHealthChecking,
      manualIpRequiredAndroid:
          Platform.isAndroid && shouldBlockAndroidLoopbackHost(_serverIp.trim()),
      healthOkLast: _mapHealthOkLast,
    );
    final result = await openPremiumSettingsScreen(
      context,
      serverHost: _serverIp,
      badgeSnapshot: badge,
      discoveryBusy: _serverDiscoverBusy,
      onAutoDiscover: () async {
        await _runAutomaticBackendDiscoverFromPhotoAnalysis();
      },
      onSaveConnection: (host, port) async {
        final settingsCtrl = AppSettingsScope.of(context);
        await _localStorageService.saveServerIp(host);
        await settingsCtrl.patch(
          (s) => s.copyWith(serverPort: port),
        );
        if (!mounted) return;
        setState(() => _serverIp = host);
        _rebuildApiService();
        await _refreshMapHealthOnce();
      },
    );
    if (!mounted) return;
    if (result != null && result.trim().isNotEmpty) {
      setState(() => _serverIp = result.trim());
      _rebuildApiService();
    }
    await _refreshMapHealthOnce();
  }

  /// Fotoğraf analizi ekranından: kayıtlı sunucuya öncelik, ardından tam keşif.
  Future<void> _runAutomaticBackendDiscoverFromPhotoAnalysis() async {
    if (_serverDiscoverBusy || !mounted) return;
    setState(() => _serverDiscoverBusy = true);
    final svc = BackendDiscoveryService(
      apiPort: AppSettingsScope.maybeOf(context)?.settings.serverPort ??
          AppConfig.defaultApiPort,
    );
    try {
      final outcome = await svc.discoverBackend(
        storage: _localStorageService,
        scanEvenIfSavedWorks: true,
      );
      if (!mounted) return;
      final persist = outcome.persistHost;
      final alt = outcome.alternateSuggestedHost;
      if (persist != null && persist.trim().isNotEmpty) {
        final ip = persist.trim();
        await _localStorageService.saveServerIp(ip);
        if (!mounted) return;
        setState(() => _serverIp = ip);
        _rebuildApiService();
        _safePremiumSnack(
          discoverFoundLine(ip, AppConfig.defaultApiPort),
          type: PremiumToastType.success,
        );
        await _refreshMapHealthOnce();
        return;
      }
      if (alt != null && alt.trim().isNotEmpty) {
        final altTrim = alt.trim();
        final useAlt = await PremiumDialog.showConfirm(
          context,
          title: kDiscoverAlternateSnack,
          message: alternateServerHint(_serverIp, altTrim),
          confirmLabel: kDiscoverUseAlternate,
          tone: PremiumDialogTone.info,
        );
        if (useAlt == true && mounted) {
          await _localStorageService.saveServerIp(altTrim);
          if (!mounted) return;
          setState(() => _serverIp = altTrim);
          _rebuildApiService();
        }
        await _refreshMapHealthOnce();
        return;
      }
      _safePremiumSnack(kDiscoverNotFound, type: PremiumToastType.offline);
    } catch (e, st) {
      log('PhotoAnalysis auto-discovery: $e', name: 'MapScreen', stackTrace: st);
      if (mounted) {
        _safePremiumSnack(kDiscoverNotFound, type: PremiumToastType.offline);
      }
    } finally {
      svc.close();
      if (mounted) {
        setState(() => _serverDiscoverBusy = false);
      }
    }
    if (!mounted) return;
    await _refreshMapHealthOnce();
  }

  Future<XFile?> _pickChartImage() async {
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );
      if (file == null && mounted) {
        _safePremiumSnack(kMapSnackNoChartPick);
      }
      return file;
    } catch (e, st) {
      if (mounted) {
        log('map_screen gallery pick: $e', name: 'MapScreen', stackTrace: st);
        AppHaptics.warning();
        _safePremiumSnack(kMapSnackGalleryError, type: PremiumToastType.error);
      }
      return null;
    }
  }

  Future<Map<String, int>> _readImageSize(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
      final frame = await codec.getNextFrame();
      return {'width': frame.image.width, 'height': frame.image.height};
    } catch (_) {
      return const {'width': 0, 'height': 0};
    }
  }

  Future<List<ImageControlPoint>?> _showControlPointPicker({
    required File chartImageFile,
    required Map<String, int> imageSize,
    required List<ImageControlPoint> initialPoints,
  }) async {
    if (!mounted) return null;
    return showModalBottomSheet<List<ImageControlPoint>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.92,
        child: ControlPointPickerSheet(
          chartImageFile: chartImageFile,
          imageSize: imageSize,
          initialPoints: initialPoints,
        ),
      ),
    );
  }

  Future<void> _editControlPointsForLastChart() async {
    final path = _lastSelectedChartPath;
    if (path == null) return;
    final file = File(path);
    if (!file.existsSync()) return;
    final size = await _readImageSize(file);
    final hadBefore = _controlPoints.length;
    final picked = await _showControlPointPicker(
      chartImageFile: file,
      imageSize: size,
      initialPoints: _controlPoints,
    );
    if (!mounted) return;
    setState(() => _accentCalibrationControls = false);
    if (picked == null) {
      if (hadBefore < 3) {
        _safePremiumSnack(kCalibIncompleteExitSnack);
      }
      return;
    }
    setState(() {
      _controlPoints = picked;
      _controlPointsImageSize = size;
    });
    if (picked.length >= 3) {
      await _refreshAnalysis();
    }
  }

  bool _sameImageSize(Map<String, int> a, Map<String, int> b) {
    return (a['width'] ?? 0) == (b['width'] ?? 0) &&
        (a['height'] ?? 0) == (b['height'] ?? 0) &&
        (a['width'] ?? 0) > 1 &&
        (a['height'] ?? 0) > 1;
  }

  Future<({double lat, double lon})?> _tryReadDeviceGpsForAnalysis() async {
    try {
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) return null;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          timeLimit: Duration(seconds: 14),
        ),
      );
      return (lat: pos.latitude, lon: pos.longitude);
    } catch (_) {
      return null;
    }
  }

  List<ImageControlPoint> _syncControlPointsToImageSize(
    Map<String, int> imageSize,
  ) {
    if (_controlPoints.length < 3) return _controlPoints;
    final toW = imageSize['width'] ?? 0;
    final toH = imageSize['height'] ?? 0;
    if (toW < 2 || toH < 2) return _controlPoints;

    final fromW = _controlPointsImageSize['width'] ?? toW;
    final fromH = _controlPointsImageSize['height'] ?? toH;
    return scaleControlPointsToImageSize(
      points: _controlPoints,
      fromWidth: fromW,
      fromHeight: fromH,
      toWidth: toW,
      toHeight: toH,
    );
  }

  Future<_PhotoAnalysisReference> _buildPhotoAnalysisReference(
    Map<String, int> imageSize,
  ) async {
    final centerAnchor = _imageCenterAnchor(imageSize);
    if (_controlPoints.length >= 3) {
      final synced = _syncControlPointsToImageSize(imageSize);
      final bounds = _buildBoundsFromControlPoints(synced);
      final center = _boundsCenter(bounds);
      return _PhotoAnalysisReference(
        currentLat: center.lat,
        currentLon: center.lon,
        bounds: ImageGeoBounds(
          topLeft: bounds.topLeft,
          bottomRight: bounds.bottomRight,
          controlPoints: synced,
          boatPixelAnchor: centerAnchor,
          coordinateModeHint: 'geo_referenced',
        ),
        enrichData: true,
      );
    }
    final g = await _tryReadDeviceGpsForAnalysis();
    final lat = g?.lat ?? 0.0;
    final lon = g?.lon ?? 0.0;
    return _PhotoAnalysisReference(
      currentLat: lat,
      currentLon: lon,
      bounds: ImageGeoBounds(
        controlPoints: const [],
        boatPixelAnchor: centerAnchor,
        coordinateModeHint: 'image_space',
      ),
      enrichData: true,
    );
  }

  PixelAnchor _imageCenterAnchor(Map<String, int> imageSize) {
    final width = (imageSize['width'] ?? 0).toDouble();
    final height = (imageSize['height'] ?? 0).toDouble();
    return PixelAnchor(
      x: width > 1 ? (width - 1) / 2 : 0,
      y: height > 1 ? (height - 1) / 2 : 0,
      confidence: 0.25,
      source: 'photo_center_fallback',
    );
  }

  ImageGeoBounds _buildBoundsFromControlPoints(List<ImageControlPoint> points) {
    var minLat = points.first.geo.lat;
    var maxLat = points.first.geo.lat;
    var minLon = points.first.geo.lon;
    var maxLon = points.first.geo.lon;
    for (final point in points.skip(1)) {
      minLat = point.geo.lat < minLat ? point.geo.lat : minLat;
      maxLat = point.geo.lat > maxLat ? point.geo.lat : maxLat;
      minLon = point.geo.lon < minLon ? point.geo.lon : minLon;
      maxLon = point.geo.lon > maxLon ? point.geo.lon : maxLon;
    }

    final latPad = ((maxLat - minLat).abs() * 0.05).clamp(0.0001, 1.0);
    final lonPad = ((maxLon - minLon).abs() * 0.05).clamp(0.0001, 1.0);
    return ImageGeoBounds(
      topLeft: LatLon(
        lat: (maxLat + latPad).clamp(-90.0, 90.0).toDouble(),
        lon: (minLon - lonPad).clamp(-180.0, 180.0).toDouble(),
      ),
      bottomRight: LatLon(
        lat: (minLat - latPad).clamp(-90.0, 90.0).toDouble(),
        lon: (maxLon + lonPad).clamp(-180.0, 180.0).toDouble(),
      ),
    );
  }

  LatLon _boundsCenter(ImageGeoBounds bounds) {
    final topLeft = bounds.topLeft;
    final bottomRight = bounds.bottomRight;
    if (topLeft == null || bottomRight == null) {
      return LatLon(lat: 0, lon: 0);
    }
    return LatLon(
      lat: (topLeft.lat + bottomRight.lat) / 2,
      lon: (topLeft.lon + bottomRight.lon) / 2,
    );
  }

  void _centerOnBoat() {
    final boat = _boatRenderLatLon;
    if (boat == null) return;
    _scheduleWorldMapMove(boat, _currentZoom);
  }

  void _scheduleWorldMapMove(LatLon center, double zoom) {
    _pendingMapCenter = center;
    _pendingMapZoom = zoom;
    if (_visualizationMode != VisualizationMode.worldMap) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _flushPendingMapMove();
    });
  }

  void _flushPendingMapMove() {
    if (!mounted) return;
    if (_visualizationMode != VisualizationMode.worldMap) return;
    if (!_mapReady) return;
    final center = _pendingMapCenter;
    final zoom = _pendingMapZoom;
    if (center == null || zoom == null) return;
    _pendingMapCenter = null;
    _pendingMapZoom = null;
    _mapController.move(LatLng(center.lat, center.lon), zoom);
  }

  void _scheduleBoatAnchorWorldMapFit() {
    _pendingBoatAnchorBoundsFit = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _flushBoatAnchorBoundsFit();
    });
  }

  void _flushBoatAnchorBoundsFit() {
    if (!mounted || !_pendingBoatAnchorBoundsFit) return;
    if (!_geoViz.canRenderWorldMapHotspots) {
      _pendingBoatAnchorBoundsFit = false;
      return;
    }
    if (_visualizationMode != VisualizationMode.worldMap) return;
    if (!_mapReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _flushBoatAnchorBoundsFit();
      });
      return;
    }

    final pts = <LatLng>[];
    final boat = _boatRenderLatLon;
    if (boat != null &&
        boat.lat.isFinite &&
        boat.lon.isFinite &&
        boat.lat.abs() <= 90 &&
        boat.lon.abs() <= 180 &&
        !(boat.lat.abs() < 1e-9 && boat.lon.abs() < 1e-9)) {
      pts.add(LatLng(boat.lat, boat.lon));
    }
    for (final h in _hotspots) {
      if (!h.latitude.isFinite || !h.longitude.isFinite) continue;
      if (h.latitude.abs() < 1e-9 && h.longitude.abs() < 1e-9) continue;
      pts.add(LatLng(h.latitude, h.longitude));
    }

    _pendingBoatAnchorBoundsFit = false;

    if (pts.isEmpty) {
      final live = _boatGpsSmoother.state?.smoothed;
      if (live != null &&
          live.lat.isFinite &&
          live.lon.isFinite &&
          live.lat.abs() <= 90 &&
          live.lon.abs() <= 180) {
        _mapController.move(LatLng(live.lat, live.lon), 13);
      }
      return;
    }
    if (pts.length == 1) {
      _mapController.move(pts.first, 14);
      return;
    }
    try {
      final bounds = LatLngBounds.fromPoints(pts);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(56),
          maxZoom: 17,
        ),
      );
    } catch (_) {
      _mapController.move(pts.first, 13);
    }
  }

  List<Hotspot> get _filteredHotspots {
    final filtered = _trustedHotspots
        .where((h) {
          final c = h.classification.toUpperCase();
          if (c == 'A' && !_showClassA) return false;
          if (c == 'B' && !_showClassB) return false;
          if (c == 'C' && !_showClassC) return false;
          if (h.score < _minScore) return false;
          if (!_isImageSpaceMode &&
              !_isTrustworthyMappingMode &&
              !_geoViz.isBoatAnchorEstimated &&
              !_passesConservativeHotspotPolicy(h)) {
            return false;
          }
          return true;
        })
        .toList(growable: false);

    filtered.sort((a, b) {
      if (_sortMode == HotspotSortMode.proximity) {
        return a.rankByProximity.compareTo(b.rankByProximity);
      }
      return a.rankByScoreThenDistance.compareTo(b.rankByScoreThenDistance);
    });

    return filtered;
  }

  List<Hotspot> get _visibleHotspots {
    if (_geoViz.isBoatAnchorEstimated &&
        _visualizationMode == VisualizationMode.worldMap) {
      if (shouldHideGeoHotspotsOnWorldMap(
        geoMapDisplayAllowed: _geoViz.canRenderWorldMapHotspots,
        isWorldMap: true,
      )) {
        return const [];
      }
      return _boatAnchorEmergencyHotspots;
    }

    List<Hotspot> base;
    if (_isImageSpaceMode) {
      base = _filteredHotspots;
    } else {
      base = _declutterByZoom(_filteredHotspots, _mapZoomEffective);
    }
    if (shouldHideGeoHotspotsOnWorldMap(
      geoMapDisplayAllowed: _geoViz.canRenderWorldMapHotspots,
      isWorldMap: _visualizationMode == VisualizationMode.worldMap,
    )) {
      return const [];
    }
    return base;
  }

  /// Sunucunun döndürdüğü hotspot listesinde geçerli lat/lon sayısı (filtre öncesi).
  int get _serverPlausibleGeoHotspotCount {
    var n = 0;
    for (final h in _hotspots) {
      if (!h.latitude.isFinite || !h.longitude.isFinite) continue;
      if (h.latitude.abs() < 1e-9 && h.longitude.abs() < 1e-9) continue;
      n++;
    }
    return n;
  }

  /// Dünya haritası filtresinden sonra çizilecek işaret sayısı.
  int get _visibleWorldMapHotspotMarkerCount {
    if (_visualizationMode != VisualizationMode.worldMap) return 0;
    var n = 0;
    for (final h in _visibleHotspots) {
      if (!h.latitude.isFinite || !h.longitude.isFinite) continue;
      if (h.latitude.abs() < 1e-9 && h.longitude.abs() < 1e-9) continue;
      n++;
    }
    return n;
  }

  List<Hotspot> get _suspiciousHotspots =>
      _isImageSpaceMode ? const <Hotspot>[] : _hotspots.where(_isSuspiciousHotspot).toList(growable: false);

  List<Hotspot> get _trustedHotspots =>
      _isImageSpaceMode
          ? _hotspots
          : _hotspots.where((h) => !_isSuspiciousHotspot(h)).toList(growable: false);

  bool _isSuspiciousHotspot(Hotspot h) {
    if (_controlPoints.length < 3) return false;
    if (!h.latitude.isFinite || !h.longitude.isFinite) return true;
    if (h.latitude.abs() < 1e-9 && h.longitude.abs() < 1e-9) return true;
    final bounds = _buildBoundsFromControlPoints(_controlPoints);
    return hotspotIsExtremeGeoOutlier(
      lat: h.latitude,
      lon: h.longitude,
      bounds: bounds,
    );
  }

  bool _passesConservativeHotspotPolicy(Hotspot h) {
    if (h.classification.toUpperCase() == 'C') return false;
    if (h.score < 0.45) return false;

    final waterConfidence = _metricAsDouble(
      h.supportingMetrics['water_confidence'],
    );
    if (waterConfidence != null && waterConfidence < 0.72) return false;

    final landDistancePx = _metricAsDouble(
      h.supportingMetrics['land_distance_px'],
    );
    if (landDistancePx != null && landDistancePx < 8.0) return false;

    final coastDistancePx = _metricAsDouble(
      h.supportingMetrics['coast_distance_px'],
    );
    if (coastDistancePx != null && coastDistancePx < 5.0) return false;

    return true;
  }

  double? _metricAsDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  bool get _boatAnchorLowConfidence {
    final d = _analysisDiagnostics;
    if (d == null) return false;
    return d.boatAnchorSource == 'detected' && d.boatAnchorConfidence < 0.55;
  }

  bool get _isGpsFallbackBoat =>
      (_analysisDiagnostics?.boatAnchorSource == 'gps_fallback') ||
      (_boatState?.boatAnchorSource == 'gps_fallback');

  bool get _isPhotoCenterFallbackBoat =>
      (_analysisDiagnostics?.boatAnchorSource == 'photo_center_fallback') ||
      (_boatState?.boatAnchorSource == 'photo_center_fallback');

  bool get _hasNavigationAnchor {
    final nav = _boatState?.navigationAnchorGeo;
    if (nav == null) return false;
    final validLat = nav.lat.isFinite && nav.lat.abs() <= 90;
    final validLon = nav.lon.isFinite && nav.lon.abs() <= 180;
    return validLat && validLon;
  }

  bool get _isTrustworthyMappingMode {
    final d = _analysisDiagnostics;
    if (d == null) return false;
    final mode = d.mappingMode.toLowerCase();
    if (d.screenshotAlignedMappingUsed) return true;
    return mode.contains('affine') ||
        mode.contains('control_point') ||
        mode.contains('screenshot') ||
        mode.contains('boat_anchor');
  }

  bool get _isImageSpaceMode {
    final d = _analysisDiagnostics;
    if (d == null) return _controlPoints.length < 3;
    return shouldForceChartOverlay(d.mappingMode);
  }

  LatLon? get _boatRenderLatLon {
    final boat = _boatState;
    if (boat == null) return null;
    if (_isPhotoCenterFallbackBoat) return null;
    if (_isImageSpaceMode && _visualizationMode == VisualizationMode.worldMap) {
      final live = _boatGpsSmoother.state?.smoothed;
      if (live != null && boatStateHasPlausibleGps(boat)) {
        return live;
      }
      for (final ll in [boat.smoothedGps, boat.rawGps]) {
        if (!ll.lat.isFinite || !ll.lon.isFinite) continue;
        if (ll.lat.abs() > 90 || ll.lon.abs() > 180) continue;
        if (ll.lat.abs() < 1e-8 && ll.lon.abs() < 1e-8) continue;
        return ll;
      }
      return null;
    }
    // 1) navigation_anchor_geo varsa öncelikli kullan.
    if (_hasNavigationAnchor) {
      return boat.navigationAnchorGeo;
    }

    // 2) pixel anchor yalnızca screenshot-aware/affine modunda kullanılır.
    final pixelAnchor = boat.boatPixelAnchor;
    if (pixelAnchor != null && _isTrustworthyMappingMode) {
      final anchorGeo = _pixelAnchorToGeo(pixelAnchor);
      if (anchorGeo != null) {
        return anchorGeo;
      }
    }

    // 3) Canlı süzülmüş GPS veya analiz referansı.
    final smoothedLive = _boatGpsSmoother.state?.smoothed;
    if (smoothedLive != null &&
        boatStateHasPlausibleGps(boat) &&
        _visualizationMode == VisualizationMode.worldMap) {
      return smoothedLive;
    }
    return boat.smoothedGps;
  }

  LatLon? _pixelAnchorToGeo(PixelAnchor anchor) {
    final bounds = _lastAnalysisBounds;
    if (bounds == null) return null;
    final topLeft = bounds.topLeft;
    final bottomRight = bounds.bottomRight;
    if (topLeft == null || bottomRight == null) return null;
    final width = _lastImageSize['width'] ?? 0;
    final height = _lastImageSize['height'] ?? 0;
    if (width <= 1 || height <= 1) return null;

    final nx = (anchor.x / (width - 1)).clamp(0.0, 1.0);
    final ny = (anchor.y / (height - 1)).clamp(0.0, 1.0);
    final latSpan = topLeft.lat - bottomRight.lat;
    final lonSpan = bottomRight.lon - topLeft.lon;
    final lat = topLeft.lat - ny * latSpan;
    final lon = topLeft.lon + nx * lonSpan;
    return LatLon(lat: lat, lon: lon);
  }

  String _mappingModeLabel(String mode) {
    final normalized = mode.toLowerCase();
    final trustworthy =
        _isTrustworthyMappingMode ||
        normalized.contains('affine') ||
        normalized.contains('control_point') ||
        normalized.contains('screenshot');
    return trustworthy
        ? 'Ekran görüntüsü hizalaması kullanıldı'
        : 'Yaklaşık dünya haritası hizalaması kullanılıyor';
  }

  bool get _hasSelectedChartImage {
    final path = _lastSelectedChartPath;
    return path != null && File(path).existsSync();
  }

  File? get _selectedChartFile {
    final path = _lastSelectedChartPath;
    if (path == null) return null;
    final file = File(path);
    return file.existsSync() ? file : null;
  }

  bool get _canRenderChartOverlay {
    final width = _lastImageSize['width'] ?? 0;
    final height = _lastImageSize['height'] ?? 0;
    return _hasSelectedChartImage && width > 1 && height > 1;
  }

  List<Hotspot> get _chartRenderableHotspots => _visibleHotspots
      .where((h) => h.isRenderable && h.trustState == 'trusted')
      .toList(growable: false);

  PixelAnchor? get _boatChartAnchor {
    final source = _boatState?.boatAnchorSource ?? 'gps_fallback';
    if (source == 'gps_fallback' || source == 'photo_center_fallback') {
      return null;
    }
    return _boatState?.boatPixelAnchor;
  }

  Offset _pixelToCanvas(PixelAnchor anchor, Size canvasSize) {
    final rawW = (_lastImageSize['width'] ?? 1).toDouble();
    final rawH = (_lastImageSize['height'] ?? 1).toDouble();
    return hotspotPixelToDisplayedOffset(
      hotspotX: anchor.x,
      hotspotY: anchor.y,
      imageWidth: rawW,
      imageHeight: rawH,
      displayedWidth: canvasSize.width,
      displayedHeight: canvasSize.height,
    );
  }

  List<Hotspot> _declutterByZoom(List<Hotspot> sorted, double zoom) {
    final maxItems = zoom < 9
        ? 10
        : zoom < 11
        ? 24
        : 80;

    final minDelta = zoom < 9
        ? 0.02
        : zoom < 11
        ? 0.008
        : 0.003;

    final accepted = <Hotspot>[];
    for (final h in sorted) {
      if (accepted.length >= maxItems) break;
      final tooClose = accepted.any((a) {
        final dLat = (a.latitude - h.latitude).abs();
        final dLon = (a.longitude - h.longitude).abs();
        return dLat < minDelta && dLon < minDelta;
      });
      if (!tooClose) {
        accepted.add(h);
      }
    }
    return accepted;
  }

  Color _classificationColor(String classification) {
    switch (classification.toUpperCase()) {
      case 'A':
        return const Color(0xFF00E676);
      case 'B':
        return const Color(0xFFFFB300);
      default:
        return const Color(0xFF90A4AE);
    }
  }

  String _markerLabel(Hotspot hotspot) {
    final rank = _sortMode == HotspotSortMode.proximity
        ? hotspot.rankByProximity
        : hotspot.rankByScoreThenDistance;
    return '${hotspot.classification} $rank. sıra';
  }

  String _markerLabelWithNav(Hotspot hotspot) {
    final base = _markerLabel(hotspot);
    if (!_geoViz.canRenderWorldMapHotspots) {
      return base;
    }
    final d = hotspot.distanceM;
    if (!d.isFinite || d < 3.0) {
      return base;
    }
    final approx = _geoViz.isBoatAnchorEstimated ? '≈ ' : '';
    return '$approx$base · ${d.round()} m · ${hotspot.bearingDeg.round()}° · '
        '${kMapTrustFmt(_hotspotTrustLabel(hotspot))}';
  }

  String _hotspotTooltipExtended(Hotspot hotspot) {
    final navTail = !_geoViz.canRenderWorldMapHotspots
        ? ''
        : () {
            final d = hotspot.distanceM;
            if (!d.isFinite || d < 3.0) return '';
            return '${d.round()} m · ${hotspot.bearingDeg.round()}° · '
                '${kMapTrustFmt(_hotspotTrustLabel(hotspot))}';
          }();

    final primaryHead = hotspot.reasoningText.trim().isEmpty
        ? _markerLabel(hotspot)
        : hotspot.reasoningText.trim();
    final merged = navTail.isEmpty
        ? primaryHead
        : (primaryHead.isEmpty ? navTail : '$primaryHead\n$navTail');
    final primary = merged;
    final approxHeader = _geoViz.isBoatAnchorEstimated
        ? '$kHotspotGeoBoatAnchorEstimatedLabel\n'
            '$kHotspotGeoBoatAnchorEstimatedDebugNote\n\n'
        : '';
    final pr = hotspot.recommendationRank;
    if (pr >= 1 && pr <= 5) {
      return '$approxHeader$primary\n\n${kMapHotspotTooltipRankLine(pr)}';
    }
    return '$approxHeader$primary';
  }

  String _recommendationBadgeLabel(Hotspot h) {
    final r = h.recommendationRank;
    if (r == 1) return kMapBadgeRecommendedSpot1;
    if (r == 2) return kMapBadgeSuggestedPriority2;
    if (r == 3) return kMapBadgeSuggestedPriority3;
    return '';
  }

  List<CircleMarker> _buildGpsAccuracyCircles() {
    final boat = _boatRenderLatLon;
    final live = _liveGpsState.value;
    if (boat == null || live == null) return const <CircleMarker>[];
    final acc = live.currentAccuracyM;
    if (acc == null || !acc.isFinite || acc < 10) return const <CircleMarker>[];
    final r = acc.clamp(18.0, 240.0);
    final rel = live.reliability.clamp(0.0, 1.0);
    final fillAlpha = 0.08 + (1.0 - rel) * 0.10;
    final borderAlpha = 0.22 + (1.0 - rel) * 0.18;
    final color = rel >= 0.55
        ? const Color(0xFF4FC3F7)
        : const Color(0xFFFFB74D);
    return [
      CircleMarker(
        point: LatLng(boat.lat, boat.lon),
        radius: r,
        useRadiusInMeter: true,
        color: color.withValues(alpha: fillAlpha),
        borderStrokeWidth: 1.1,
        borderColor: color.withValues(alpha: borderAlpha),
      ),
    ];
  }

  List<Marker> _buildWorldMapMarkers(
    List<WorldMapHotspotPlacement> placements, {
    required bool mobileLayout,
  }) {
    return _markerLayer().buildWorldMapMarkers(
      placements,
      mobileLayout: mobileLayout,
    );
  }

  List<CircleMarker> _buildIntensityOverlay() {
    if (!_showIntensityOverlay) return const <CircleMarker>[];

    final source = _overlayHotspots;
    final offlineLikeMode = _lastError != null || _mapHealthOkLast == false;
    final baseOpacity = offlineLikeMode ? 0.08 : 0.12;

    return source
        .map<CircleMarker>(
          (h) => CircleMarker(
            point: LatLng(h.latitude, h.longitude),
            radius: offlineLikeMode
                ? (5 + (h.score.clamp(0, 1) * 7)).clamp(5, 12).toDouble()
                : (6 + (h.score.clamp(0, 1) * 10)).clamp(6, 16).toDouble(),
            color: _classificationColor(
              h.classification,
            ).withValues(alpha: baseOpacity),
            borderStrokeWidth: 1,
            borderColor: _classificationColor(
              h.classification,
            ).withValues(alpha: 0.22),
            useRadiusInMeter: false,
          ),
        )
        .toList(growable: false);
  }

  List<Hotspot> get _overlayHotspots {
    final ordered = _visibleHotspots;
    if (ordered.isEmpty) return const [];

    final zoom = _mapZoomEffective;
    final offlineLikeMode = _lastError != null || _mapHealthOkLast == false;

    final maxCount = offlineLikeMode
        ? (zoom < 10 ? 6 : 10)
        : (zoom < 9
              ? 8
              : zoom < 11
              ? 14
              : 22);

    final minDelta = zoom < 9
        ? 0.030
        : zoom < 11
        ? 0.015
        : 0.008;

    final selected = <Hotspot>[];
    for (final h in ordered) {
      if (selected.length >= maxCount) break;
      final tooClose = selected.any((s) {
        final dLat = (s.latitude - h.latitude).abs();
        final dLon = (s.longitude - h.longitude).abs();
        return dLat < minDelta && dLon < minDelta;
      });
      if (!tooClose) {
        selected.add(h);
      }
    }
    return selected;
  }

  List<Polyline> _buildConnectionOverlays() {
    if (!_showCorridorOverlay) return const <Polyline>[];

    final lines = <Polyline>[];
    final ordered = _visibleHotspots;
    if (ordered.length >= 2) {
      lines.add(
        Polyline(
          points: ordered
              .take(8)
              .map((h) => LatLng(h.latitude, h.longitude))
              .toList(growable: false),
          color: const Color(0xAA42A5F5),
          strokeWidth: 4,
        ),
      );
    }
    return lines;
  }

  Widget _buildMissingChartRecoveryPanel() {
    final busy = _isLoading;
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: const Color(0xFF081320),
      alignment: Alignment.center,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                kMapChartOverlayJsonButImageMissingTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                kMapChartOverlayJsonButImageMissingHint,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: busy ? null : () => unawaited(_scanArea()),
                  icon: busy
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.onPrimary,
                          ),
                        )
                      : const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(
                    busy ? kMapFabScanning : kMapChartReloadCta,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: busy ? null : () => unawaited(_scanArea()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(kMapChartNewAnalysisCta),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNeedScreenshotAnalysisPanel() {
    return PhotoAnalysisUploadCard(
      message: kMapChartOverlayNeedsScreenshotAnalysis,
      busy: _isLoading,
      previewPath: _lastSelectedChartPath,
      onScan: _isLoading ? null : () => unawaited(_scanArea()),
    );
  }

  Widget _buildChartOverlayView({required bool mobile}) {
    final file = _selectedChartFile;
    final hotspots = _chartRenderableHotspots;
    final compactMarkers = mobile || hotspots.length > 40;
    final debugOverlayFile = _resolveDebugOverlayFile();
    final boatAnchor = _boatChartAnchor;
    final layer = _markerLayer();

    return ChartOverlayHost(
      mobile: mobile,
      canRender: _canRenderChartOverlay && file != null,
      chartFile: file,
      cachedAnalysisChartFileMissing: _cachedAnalysisChartFileMissing,
      chartFromHistoryFallback: _chartFromHistoryFallback,
      isImageSpaceMode: _isImageSpaceMode,
      isLoading: _isLoading,
      coordinateModeLabel: _chartCoordinateModeLabel(),
      hotspotCount: hotspots.length,
      calibrationLabel: _chartCalibrationChipLabel(),
      calibrationTone: _chartCalibrationChipTone(),
      showDebugOverlay: _showDebugOverlay,
      debugOverlayOpacity: _debugOverlayOpacity,
      debugOverlayFile: debugOverlayFile,
      worldMapEnabled: _geoViz.canRenderWorldMapHotspots,
      captainEnabled: _hotspots.isNotEmpty,
      transformController: _chartTransformController,
      onCanvasSizeChanged: (size) {
        if (size != _lastChartCanvasSize) {
          _lastChartCanvasSize = size;
        }
      },
      markerBuilder: (canvasSize) {
        return Stack(
          children: [
            for (final hotspot in hotspots)
              layer.buildChartHotspotMarker(
                hotspot,
                canvasSize,
                mobile: mobile,
                compact: compactMarkers,
              ),
            if (boatAnchor != null)
              layer.buildChartBoatMarker(boatAnchor, canvasSize),
          ],
        );
      },
      onDebugToggle: (v) => setState(() => _showDebugOverlay = v),
      onDebugOpacityChanged: (v) => setState(() => _debugOverlayOpacity = v),
      onAnalyze: _scanArea,
      onCalibrate: _openChartCalibration,
      onWorldMap: _switchToWorldMapFromChart,
      onCaptainAtlas: _openAiAssistant,
      onGpx: _exportGpx,
      missingChartRecovery: _buildMissingChartRecoveryPanel(),
      needScreenshotPanel: _buildNeedScreenshotAnalysisPanel(),
      warningCard: _isImageSpaceMode
          ? ImageSpaceWarningCard(
              compact: mobile,
              onCalibrate: _openChartCalibration,
            )
          : null,
    );
  }

  Widget _buildStatusCard() {
    if (_visualizationMode == VisualizationMode.worldMap &&
        _hotspots.isNotEmpty &&
        !_isLoading &&
        _lastError == null &&
        (_mapHealthOkLast != false)) {
      return const SizedBox.shrink();
    }
    if (_isLoading) {
      return _bottomCard(
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.cyanAccent,
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Analiz sürüyor, sonuçlar hazırlanıyor...',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    if ((_mapHealthOkLast == false) && !_isLoading) {
      final hasSpot = _hotspots.isNotEmpty;
      return _bottomCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              hasSpot ? kOfflineMapShowingCachedBadge : kOfflineMapNeedsServerBanner,
              style: TextStyle(
                color: const Color(0xFFB0BEC5).withValues(alpha: 0.95),
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              kOfflineStateReassurance,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 12.5,
                height: 1.42,
              ),
            ),
            if (_offlineAnalyzeAttempt) ...[
              const SizedBox(height: 10),
              Text(
                kOfflineAnalysisNeedsServer,
                style: TextStyle(
                  color: Colors.lightBlueAccent.withValues(alpha: 0.88),
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (_lastError != null) {
      return _bottomCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _usingCachedFallback
                  ? kMapErrorHeadlineUsingCache
                  : kMapErrorHeadlineUnexpected,
              style: TextStyle(
                color: Colors.orangeAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _usingCachedFallback
                  ? _cachedFallbackErrorText(_lastError!)
                  : _lastError!,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (_hotspots.isEmpty) {
      return _bottomCard(
        child: Text(
          'Henüz analiz verisi yok. Alanı Tara ile harita görseli seçip analiz başlatın.',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    final statusText = _composeSessionStatusBody();
    final advice = (_sessionAdvice ?? '').trim();

    final mobile = useMobileLayout(context);
    if (mobile && _visualizationMode == VisualizationMode.worldMap) {
      if (!_worldMapHotspotStripVisible) {
        return _buildMobileSessionSummaryBar();
      }
      return const SizedBox.shrink();
    }

    return _bottomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (advice.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  color: Color(0xFFB2EBF2),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        kMapSessionHintTitle,
                        style: TextStyle(
                          color: Color(0xFFB2EBF2),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        advice,
                        style: const TextStyle(
                          color: Color(0xEEFFFFFF),
                          height: 1.38,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: Colors.white24),
            const SizedBox(height: 12),
          ],
          Text(statusText, style: const TextStyle(color: Colors.white)),
          _buildAiAssistantButton(),
        ],
      ),
    );
  }

  SeaState? get _primarySeaState {
    for (final hotspot in _hotspots) {
      if (hotspot.seaState.source != 'unknown') {
        return hotspot.seaState;
      }
    }
    return null;
  }

  String? get _analysisSourceSummary {
    final seaState = _primarySeaState;
    if (seaState == null) {
      return null;
    }
    final label = seaState.fallback ? 'tahmini veri' : 'canlı API';
    final source = localizeSeaDataSource(seaState.source);
    return '$label ($source)';
  }

  String _composeSessionStatusBody() {
    final diagnostics = _analysisDiagnostics;
    final suspiciousCount = _suspiciousHotspots.length;
    final rejectedLand = diagnostics?.rejectedLandCandidates ?? 0;
    final filteredHotspots = _filteredHotspots;
    final visibleHotspots = _visibleHotspots;
    final hiddenByZoom = _hiddenByZoomDeclutterCount;
    final buffer = StringBuffer();
    buffer.write(
      '${filteredHotspots.length} filtreye uyan mera | '
      'haritada görünen: ${visibleHotspots.length}\n'
      'A: ${filteredHotspots.where((h) => h.classification == 'A').length} '
      'B: ${filteredHotspots.where((h) => h.classification == 'B').length} '
      'C: ${filteredHotspots.where((h) => h.classification == 'C').length}\n',
    );
    if (hiddenByZoom > 0) {
      buffer.write(
        'Yakın/çakışan noktalar zoom nedeniyle gizlendi: $hiddenByZoom\n',
      );
    }
    if (suspiciousCount > 0) {
      buffer.write('Şüpheli hotspot gizlendi: $suspiciousCount\n');
    }
    if (rejectedLand > 0) {
      buffer.write('Kara yakınındaki adaylar bastırıldı: $rejectedLand\n');
    }
    buffer.write(
      diagnostics != null
          ? _mappingModeLabel(diagnostics.mappingMode)
          : 'Hizalama bilgisi bekleniyor',
    );
    if (diagnostics != null) {
      buffer.write(
        '\nCoğrafi başvuru sapması: '
        '${diagnostics.georeferenceError.toStringAsFixed(2)} m',
      );
      buffer.write(
        '\n$kMapDiagTransformQuality: '
        '${diagnostics.transformQuality.toStringAsFixed(2)}',
      );
    }
    final sourceSummary = _analysisSourceSummary;
    if (sourceSummary != null) {
      buffer.write('\nKaynak: $sourceSummary');
    }
    if (_boatAnchorLowConfidence) {
      buffer.write('\nEkran görüntüsü referansı düşük güvenle eşleşti');
    }
    if (_isPhotoCenterFallbackBoat) {
      buffer.write('\nFotoğraf modu: cihaz GPS’i kullanılmadı');
      if (!_isTrustworthyMappingMode) {
        buffer.write('\nKoordinat/mesafe gerçek harita konumu değildir');
      }
    }
    if (_isGpsFallbackBoat) {
      buffer.write('\nTekne konumu yaklaşık gösteriliyor');
      buffer.write('\nYaklaşık hizalama kullanılıyor');
    }
    if (diagnostics != null) {
      final d = diagnostics.imageSpaceEnrichmentDetail;
      if (d != null && d.isNotEmpty) {
        buffer.write('\n$d');
      }
    }
    return buffer.toString();
  }

  String _mobileSessionModeChip() {
    if (_geoViz.isBoatAnchorEstimated) return 'Yaklaşık';
    if (_geoViz.coordinateMode == kCoordinateModeGeoReferenced) {
      return 'Kalibre';
    }
    return 'Harita';
  }

  String _mobileGpsSummaryLabel() {
    final live = _liveGpsState.value;
    if (live == null) return 'GPS —';
    final r = live.reliability;
    if (!r.isFinite) return 'GPS —';
    if (r >= 0.72) return 'GPS güvenilir';
    if (r >= 0.48) return 'GPS orta';
    return 'GPS zayıf';
  }

  Future<void> _openAiAssistant() async {
    final analysis = _lastFishingZoneResponse;
    if (analysis == null || _hotspots.isEmpty || !mounted) return;
    _focusMapContextBeforeNavigation();
    await CaptainAtlasLauncher.launch(
      context,
      CaptainAtlasLaunchRequest(
        serverIp: _serverIp,
        entryPoint: _visualizationMode == VisualizationMode.chartOverlay
            ? CaptainAtlasEntryPoint.chartOverlay
            : CaptainAtlasEntryPoint.mapCommandBar,
        analysis: analysis,
        apiService: _apiService,
        aiCache: _aiAssistantCache,
        clientIdentity: _clientIdentityService,
      ),
    );
  }

  Widget _buildAiAssistantButton() {
    if (_hotspots.isEmpty || _isLoading || _lastFishingZoneResponse == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.tonalIcon(
          onPressed: _openAiAssistant,
          icon: const Icon(Icons.auto_awesome_rounded, size: 18),
          label: const Text(kAiAssistantButtonLabel),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF114B5F),
            foregroundColor: const Color(0xFF32D9FF),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),
      ),
    );
  }

  Future<void> _openSessionDetailSheet() async {
    if (!mounted) return;
    final advice = (_sessionAdvice ?? '').trim();
    final body = _composeSessionStatusBody();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0A1A2A),
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Oturum bilgisi',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (advice.isNotEmpty) ...[
                    const Text(
                      kMapSessionHintTitle,
                      style: TextStyle(
                        color: Color(0xFFB2EBF2),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      advice,
                      style: const TextStyle(
                        color: Color(0xEEFFFFFF),
                        height: 1.38,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 12),
                  ],
                  SelectableText(
                    body,
                    style: const TextStyle(color: Colors.white, height: 1.35),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openMapControlsSheet() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0A1A2A),
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            child: Align(
              alignment: Alignment.topCenter,
              child: _buildMapToolbox(
                onRefreshOverride: () {
                  Navigator.pop(ctx);
                  unawaited(_refreshAnalysis());
                },
                onCenterBoatOverride: () {
                  Navigator.pop(ctx);
                  _centerOnBoat();
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openMapLegendSheet() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0A1A2A),
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: SingleChildScrollView(
              child: MapPremiumLegend(
                visible: true,
                showIntensity: _showIntensityOverlay,
                showCorridor: _showCorridorOverlay,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileSessionSummaryBar() {
    final n = _filteredHotspots.length;
    final mode = _mobileSessionModeChip();
    final gps = _mobileGpsSummaryLabel();
    return Positioned(
      left: 10,
      right: 10,
      bottom: 10,
      child: SafeArea(
        top: false,
        child: Material(
          color: const Color(0xEE0B1A2A),
          elevation: 8,
          shadowColor: Colors.black54,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _openSessionDetailSheet,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$n mera · $gps · $mode',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: _openSessionDetailSheet,
                    child: const Text('Detay'),
                  ),
                  if (_lastFishingZoneResponse != null && _hotspots.isNotEmpty)
                    IconButton(
                      tooltip: kAiAssistantButtonLabel,
                      onPressed: _openAiAssistant,
                      icon: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFF32D9FF),
                        size: 22,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomCard({required Widget child}) {
    return Positioned(
      left: 12,
      right: 12,
      bottom: 24,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xCC0B1A2A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
        ),
        child: child,
      ),
    );
  }

  Future<void> _showDiagnosticsSheet() async {
    final d = _analysisDiagnostics;
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0A1A2A),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  kMapDiagHeadingAlignment,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                _diagRow(
                  'Hizalama modu',
                  d == null ? 'Veri yok' : _mappingModeLabel(d.mappingMode),
                ),
                _diagRow(
                  kMapDiagMappingTrustState,
                  d == null ? '-' : localizeMappingTrustState(d.mappingTrustState),
                ),
                _diagRow(
                  'Hizalama güveni',
                  _isTrustworthyMappingMode
                      ? 'Ekran görüntüsü hizalaması kullanıldı'
                      : 'Yaklaşık hizalama kullanılıyor',
                ),
                _diagRow(
                  kMapDiagGeorefErrorShort,
                  d == null ? '-' : d.georeferenceError.toStringAsFixed(2),
                ),
                _diagRow(
                  kMapDiagTransformQuality,
                  d == null ? '-' : d.transformQuality.toStringAsFixed(2),
                ),
                _diagRow(
                  'Kıyı güven skoru',
                  d == null ? '-' : d.coastlineConfidence.toStringAsFixed(2),
                ),
                _diagRow(
                  'Kara yakınında reddedilen adaylar',
                  d == null ? '-' : '${d.rejectedLandCandidates}',
                ),
                _diagRow(
                  'Geçerli su adayları',
                  d == null ? '-' : '${d.validWaterCandidates}',
                ),
                _diagRow(
                  'Tekne anchor güveni',
                  d == null ? '-' : d.boatAnchorConfidence.toStringAsFixed(2),
                ),
                _diagRow(
                  'Tekne anchor kaynağı',
                  d == null ? '-' : localizeBoatAnchorSource(d.boatAnchorSource),
                ),
                _diagRow(
                  'GPS/varsayılan yedek hizalama',
                  _isGpsFallbackBoat ? 'Evet' : 'Hayır',
                ),
                _diagRow(
                  'Ekran görüntüsü referanslı hizalama',
                  (d?.screenshotAlignedMappingUsed ?? false) ? 'Evet' : 'Hayır',
                ),
                const SizedBox(height: 8),
                if (_boatAnchorLowConfidence)
                  const Text(
                    'Ekran görüntüsü referansı düşük güvenle eşleşti.',
                    style: TextStyle(color: Colors.orangeAccent),
                  ),
                if (_suspiciousHotspots.isNotEmpty)
                  Text(
                    'Şüpheli hotspot gizlendi: ${_suspiciousHotspots.length}',
                    style: const TextStyle(color: Colors.orangeAccent),
                  ),
                if ((d?.rejectedLandCandidates ?? 0) > 0)
                  Text(
                    'Kara yakınındaki adaylar bastırıldı: ${d!.rejectedLandCandidates}',
                    style: const TextStyle(color: Colors.orangeAccent),
                  ),
                if (_isGpsFallbackBoat)
                  const Text(
                    'Tekne konumu yaklaşık gösteriliyor.',
                    style: TextStyle(color: Colors.orangeAccent),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAnalysisHistorySheet() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0A1A2A),
      builder: (modalContext) {
        final h = MediaQuery.sizeOf(modalContext).height;
        return SizedBox(
          height: h * 0.9,
          child: AnalysisHistoryModal(
            storage: _localStorageService,
            onPickEntry: _restoreHistoryEntry,
          ),
        );
      },
    );
  }

  String? _chartBasenameForProfile() {
    final p = _lastSelectedChartPath;
    if (p == null || p.trim().isEmpty) return null;
    final n = p.replaceAll('\\', '/');
    final seg = n.split('/');
    return seg.isEmpty ? null : seg.last;
  }

  Future<void> _showCalibrationProfilesSheet() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0A1A2A),
      builder: (modalContext) {
        final h = MediaQuery.sizeOf(modalContext).height;
        return SizedBox(
          height: h * 0.86,
          child: CalibrationProfilesSheet(
            storage: _localStorageService,
            currentPointCount: _controlPoints.length,
            currentImageWidth: _lastImageSize['width'] ?? 0,
            currentImageHeight: _lastImageSize['height'] ?? 0,
            chartLabelHint: _chartBasenameForProfile(),
            onApplyProfile: (p) {
              if (!mounted) return;
              setState(() {
                _controlPoints = List<ImageControlPoint>.from(p.controlPoints);
                _controlPointsImageSize = {
                  'width': p.imageWidth,
                  'height': p.imageHeight,
                };
              });
              final w = _lastImageSize['width'] ?? 0;
              final hgt = _lastImageSize['height'] ?? 0;
              if (w > 0 &&
                  hgt > 0 &&
                  (p.imageWidth != w || p.imageHeight != hgt)) {
                _safePremiumSnack(
                  kMapProfileDimensionMismatchSnack(
                    p.imageWidth,
                    p.imageHeight,
                    w,
                    hgt,
                  ),
                  type: PremiumToastType.info,
                );
              } else {
                _safePremiumSnack(kMapSnackCalibProfileApplied, type: PremiumToastType.success);
              }
            },
            onSaveCurrent: (name) async {
              final w = _lastImageSize['width'] ?? 0;
              final hgt = _lastImageSize['height'] ?? 0;
              if (w < 2 || hgt < 2 || _controlPoints.isEmpty) return;
              final id = DateTime.now().toUtc().toIso8601String();
              final prof = ChartCalibrationProfile(
                id: id,
                name: name,
                controlPoints: List<ImageControlPoint>.from(_controlPoints),
                imageWidth: w,
                imageHeight: hgt,
                chartLabel: _chartBasenameForProfile(),
                updatedAt: DateTime.now(),
              );
              await _localStorageService.upsertCalibrationProfile(prof);
            },
          ),
        );
      },
    );
  }

  void _restoreHistoryEntry(AnalysisHistoryEntry entry) {
    if (!mounted) return;
    final raw = entry.chartImagePath?.trim();
    final exists = raw != null &&
        raw.isNotEmpty &&
        File(raw).existsSync();
    debugPrint(
      '[MapScreen] restoreHistoryEntry: image_path=$raw fileExists=$exists',
    );
    setState(() {
      _applyResponseToScreen(entry.response, usingCachedFallback: true);
      _lastSelectedChartPath = exists ? raw : null;
      _cachedAnalysisChartFileMissing = !exists;
      _chartFromHistoryFallback = false;
    });
    _centerOnBoat();
    _safePremiumSnack(kMapHistoryLoadedSaved(_historyTimestampLabel(entry.savedAt)));
  }

  String _historyTimestampLabel(DateTime dateTime) {
    final local = dateTime.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute';
  }

  Future<void> _exportGpx() async {
    if (_isLoading) return;
    if (!mounted) return;
    await GpxShare.shareHotspots(
      context,
      hotspots: _filteredHotspots,
      emptyMessage: kGpxEmptyWithFilterHint,
    );
  }

  Widget _diagRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(color: Colors.white70)),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _showExperienceSwitcher =>
      _hotspots.isNotEmpty || _canRenderChartOverlay;

  void _onExperienceTabChanged(Set<MerasonarMapExperienceTab> next) {
    if (next.isEmpty) return;
    final tab = next.first;
    setState(() {
      _experienceTab = tab;
      _visualizationMode =
          tab == MerasonarMapExperienceTab.calibratedWorld
              ? VisualizationMode.worldMap
              : VisualizationMode.chartOverlay;
      _mapReady = false;
    });
    _syncLiveGpsStreamWithMode();
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_visualizationMode != VisualizationMode.worldMap) return;
      final boat = _boatRenderLatLon;
      if (boat != null) {
        _scheduleWorldMapMove(boat, 13.0);
      }
      _flushPendingMapMove();
      _primeWorldMapViewportFromController();
      _syncLiveGpsStreamWithMode();
    });
  }

  Widget _buildWorldMapFloatingPills() {
    return WorldMapFloatingPills(
      liveGpsState: _liveGpsState,
      focusViewportStatus: _focusViewportStatus,
    );
  }

  Widget _buildExperienceSwitcherBar({required bool mobile}) {
    if (!_showExperienceSwitcher) {
      return const SizedBox.shrink();
    }
    final worldLabel = mobile
        ? _worldMapExperienceSegmentLabelCompact()
        : _worldMapExperienceSegmentLabel();
    final photoLabel = mobile ? kMapPremiumExperiencePhoto : kMapTabPhotoAnalysis;
    final modeHint = _experienceTab == MerasonarMapExperienceTab.calibratedWorld
        ? kMapPremiumExperienceMapHint
        : kMapPremiumExperiencePhotoHint;
    return Material(
      color: const Color(0xFF0B1A2A),
      child: Padding(
        padding: EdgeInsets.fromLTRB(mobile ? 6 : 10, 8, mobile ? 6 : 10, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: SegmentedButton<MerasonarMapExperienceTab>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              backgroundColor: const Color(0xFF162636),
              foregroundColor: Colors.white70,
              selectedForegroundColor: Colors.white,
              selectedBackgroundColor: const Color(0xFF114B5F),
              visualDensity:
                  mobile ? VisualDensity.compact : VisualDensity.standard,
              padding: EdgeInsets.symmetric(
                horizontal: mobile ? 10 : 14,
                vertical: mobile ? 8 : 10,
              ),
            ),
            segments: [
              ButtonSegment(
                value: MerasonarMapExperienceTab.calibratedWorld,
                label: Text(worldLabel),
                icon: Icon(Icons.public_rounded, size: mobile ? 16 : 18),
              ),
              ButtonSegment(
                value: MerasonarMapExperienceTab.photoAnalysis,
                label: Text(photoLabel),
                icon: Icon(Icons.photo_rounded, size: mobile ? 16 : 18),
              ),
            ],
            selected: {_experienceTab},
            onSelectionChanged: _onExperienceTabChanged,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                modeHint,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 10.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalibratedModeRibbon() {
    return CalibratedModeRibbon(
      geoViz: _geoViz,
      showExperienceSwitcher: _showExperienceSwitcher,
    );
  }

  Widget? _buildHotspotStripWidget({
    required bool mobile,
    int? selectedHotspotId,
  }) {
    if (!_worldMapHotspotStripVisible) return null;
    final ranked = [..._filteredHotspots]
      ..sort((a, b) => a.distanceM.compareTo(b.distanceM));
    final top = ranked.take(8).toList(growable: false);
    return MapHotspotStrip(
      hotspots: top,
      mobile: mobile,
      selectedHotspotId: selectedHotspotId,
      onTap: _openHotspotDetail,
      scoreFormatter: _displayScorePct,
    );
  }

  Widget _buildWorldMapBottomChrome({
    required bool mobile,
    int? selectedHotspotId,
  }) {
    final strip = _buildHotspotStripWidget(
      mobile: mobile,
      selectedHotspotId: selectedHotspotId,
    );
    return MapBottomChrome(
      showStrip: strip != null,
      hotspotStrip: strip,
      commandBar: MapCommandBar(
        busy: _isLoading,
        onScanArea: _scanArea,
        onLiveAnalysis: _openLiveAreaFromMap,
        onCoordinate: _openMarineIntelligenceFromMap,
        onCompare: _openMarineCompareFromMap,
        onCaptainAtlas: _hotspots.isEmpty ? null : _openAiAssistant,
      ),
    );
  }

  Widget _buildChartPreviewCornerCard({required bool mobile}) {
    final file = _selectedChartFile;
    if (file == null || _visualizationMode != VisualizationMode.worldMap) {
      return const SizedBox.shrink();
    }
    final base = MapBottomChrome.reservedHeight(
          hasStrip: _worldMapHotspotStripVisible,
        ) +
        24;
    final bottomPad = base + (mobile ? 0 : 0);
    return Positioned(
      right: 10,
      bottom: bottomPad,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 96,
          height: 74,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0x4432D9FF)),
            color: const Color(0xCC081320),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 8,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Image.file(
                  file,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Center(
                    child: Icon(Icons.broken_image,
                        color: Colors.white.withValues(alpha: 0.5)),
                  ),
                ),
              ),
              Container(
                color: const Color(0xFF0B1A2A),
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                child: Text(
                  kMapChartPreviewLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.cyanAccent.shade100,
                    fontSize: 9,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _displayScorePct(double score) {
    final v = (score * 100).round().clamp(0, 999);
    return v;
  }

  String _hotspotTrustLabel(Hotspot h) {
    final mt = h.mappingTrust.toLowerCase();
    if (mt.contains('affine') ||
        mt.contains('precise') ||
        mt == 'chart_aligned') {
      return kMapTrustHigh;
    }
    final t = h.trustScore;
    if (!t.isFinite) return kMapTrustMedium;
    if (t >= 0.72) return kMapTrustHigh;
    if (t >= 0.45) return kMapTrustMedium;
    return kMapTrustLow;
  }

  Future<void> _calibrateFromWorldMapBanner() async {
    if (_lastSelectedChartPath == null) {
      if (!mounted) return;
      _safePremiumSnack(kMapSnackRefreshNeedsChart);
      return;
    }
    if (!mounted) return;
    setState(() {
      _experienceTab = MerasonarMapExperienceTab.photoAnalysis;
      _visualizationMode = VisualizationMode.chartOverlay;
      _accentCalibrationControls = true;
    });
    await _editControlPointsForLastChart();
  }

  Future<void> _worldMapEmptyGpsCta() async {
    final serviceOn = await Geolocator.isLocationServiceEnabled();
    if (!mounted) return;
    if (!serviceOn) {
      await Geolocator.openLocationSettings();
      return;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (!mounted) return;
    if (perm == LocationPermission.deniedForever) {
      await openAppSettings();
      return;
    }
    if (perm == LocationPermission.denied) {
      _safePremiumSnack(kMapGpsPermissionDeniedPremium);
      return;
    }
    _gpsPermissionNoticeShown = false;
    _gpsServiceNoticeShown = false;
    _weakGpsSnackShown = false;
    _syncLiveGpsStreamWithMode();
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          timeLimit: Duration(seconds: 14),
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      final st = _boatGpsSmoother.ingest(
        lat: pos.latitude,
        lon: pos.longitude,
        accuracyM: pos.accuracy.isFinite
            ? pos.accuracy.clamp(1.0, 400.0)
            : null,
      );
      _liveGpsState.value = st;
    } catch (_) {
      if (mounted) {
        _safePremiumSnack(kMapGpsStreamDegradedPremium);
      }
    }
    await _refreshAnalysis();
  }

  Future<void> _worldMapEmptyAnchorCta() async {
    if (!mounted) return;
    if (_lastSelectedChartPath == null ||
        !File(_lastSelectedChartPath!).existsSync()) {
      _safePremiumSnack(kMapSnackRefreshNeedsChart);
      return;
    }
    setState(() {
      _experienceTab = MerasonarMapExperienceTab.photoAnalysis;
      _visualizationMode = VisualizationMode.chartOverlay;
      _accentCalibrationControls = true;
    });
    _safePremiumSnack(
      kMapWorldMapEmptyAnchorSnack,
      duration: const Duration(seconds: 7),
    );
    await _editControlPointsForLastChart();
  }

  /// Ekran uzayında dekoratif ipuçları — gerçek koordinat veya hotspot konumu iddiası yok.
  bool get _showApproxGeoMarkersMissing =>
      _visualizationMode == VisualizationMode.worldMap &&
      _geoViz.isBoatAnchorEstimated &&
      _geoViz.canRenderWorldMapHotspots &&
      _hotspots.isNotEmpty &&
      _serverPlausibleGeoHotspotCount == 0;

  /// Çalışma zamanı E2E teşhis (yalnızca debug).
  Widget _buildWorldMapRuntimeDebugStrip() {
    if (!kDebugMode) return const SizedBox.shrink();
    if (useMobileLayout(context) && !_mobileDebugMetricsVisible) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: _worldMapMarkersListenable,
      builder: (context, _) {
        final d = _analysisDiagnostics;
        final layout = _worldHotspotLayout.value;
        final lines = <String>[
          'coordinate_mode: ${_sessionCoordinateMode ?? '-'}',
          'output_coordinate_mode: ${d?.outputCoordinateMode ?? '-'}',
          'boat_anchor_estimate_reason: ${d?.boatAnchorEstimateReason ?? '-'}',
          'has_current_gps: ${d?.hasCurrentGps}',
          'has_boat_pixel_anchor_detected: ${d?.hasBoatPixelAnchorDetected}',
          'has_bounds_mapper: ${d?.hasBoundsMapper}',
          'hotspot_geo_count: ${d?.hotspotGeoCount}',
          'visible_world_hotspot_count: $_visibleWorldMapHotspotMarkerCount',
          'hidden_by_zoom_count: $_hiddenByZoomDeclutterCount',
          'hidden_by_viewport_count: ${layout?.hiddenByViewportFilter ?? 0}',
          'layout_dropped_min_score: ${layout?.droppedByMinScore ?? 0}',
          'first_hotspot_lat_lon: $_firstHotspotLatLonDebugLine',
        ];
        final chrome = MapBottomChrome.reservedHeight(
          hasStrip: _worldMapHotspotStripVisible,
        );
        return Positioned(
          left: 8,
          right: 8,
          bottom: chrome + 4,
          child: SafeArea(
            top: false,
            child: Material(
              color: const Color(0xCC0D1824),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: SelectableText(
                  lines.join('\n'),
                  style: TextStyle(
                    color: Colors.blueGrey.shade200,
                    fontSize: 10.5,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageSpaceWorldMapGhostLayer() {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, c) {
          final cx = c.maxWidth / 2;
          final cy = c.maxHeight * 0.38;
          const spots = <Offset>[
            Offset(-78, -6),
            Offset(22, 28),
            Offset(-36, 52),
          ];
          return Stack(
            clipBehavior: Clip.none,
            children: spots.map((o) {
              return Positioned(
                left: cx + o.dx - 16,
                top: cy + o.dy - 16,
                child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: 11, sigmaY: 11),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.07),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00BCD4).withValues(
                            alpha: 0.14,
                          ),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildImageSpaceWorldMapEmptyStateOverlay() {
    if (_geoViz.isBoatAnchorEstimated || _isEffectiveBoatAnchorEstimatedMode) {
      return const SizedBox.shrink();
    }
    final copy = resolveWorldMapEmptyDiagnosticsCopy(
      diagnostics: _analysisDiagnostics,
      serverWarningTr: _userWarningTrFromServer,
    );
    return Positioned.fill(
      child: Center(
        child: MapPremiumEmptyState(
          title: copy.title,
          body: copy.body,
          primaryLabel: copy.primaryLabel,
          onPrimary: () {
            switch (copy.primaryAction) {
              case WorldMapEmptyPrimaryAction.gpsRefresh:
                unawaited(_worldMapEmptyGpsCta());
              case WorldMapEmptyPrimaryAction.markBoatAnchor:
                unawaited(_worldMapEmptyAnchorCta());
              case WorldMapEmptyPrimaryAction.calibrate:
                unawaited(_calibrateFromWorldMapBanner());
            }
          },
          secondaryLabel: kMapFabScanArea,
          onSecondary: () => unawaited(_scanArea()),
        ),
      ),
    );
  }

  Widget _calibrateToolbarButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      decoration: _accentCalibrationControls
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.cyanAccent, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.cyanAccent.withValues(alpha: 0.42),
                  blurRadius: 16,
                ),
              ],
            )
          : null,
      child: IconButton(
        onPressed:
            _lastSelectedChartPath == null ? null : _editControlPointsForLastChart,
        icon: const Icon(Icons.my_location_rounded),
        tooltip: kMapTooltipControlPointsCalibrate,
      ),
    );
  }

  List<Widget> _mapAppBarActions(bool mobile) {
    final badge = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: mobile ? 128 : 200),
          child: BackendConnectionBadge(
            data: resolveBackendConnectionBadge(
              serverIp: _serverIp,
              discoveryBusy: _serverDiscoverBusy,
              serverHealthChecking: _mapHealthChecking,
              manualIpRequiredAndroid: Platform.isAndroid &&
                  shouldBlockAndroidLoopbackHost(_serverIp.trim()),
              healthOkLast: _mapHealthOkLast,
            ),
            onTap: _showServerIpDialog,
          ),
        ),
      ),
    );

    if (!mobile) {
      return [
        _calibrateToolbarButton(),
        IconButton(
          onPressed: _showCalibrationProfilesSheet,
          icon: const Icon(Icons.tune_rounded),
          tooltip: 'Kalibrasyon profilleri',
        ),
        IconButton(
          onPressed: _showDiagnosticsSheet,
          icon: Icon(Icons.info_outline_rounded),
          tooltip: kMapDiagHeadingAlignment,
        ),
        IconButton(
          onPressed: _showAnalysisHistorySheet,
          icon: const Icon(Icons.history_rounded),
          tooltip: 'Analiz geçmişi',
        ),
        IconButton(
          onPressed: _exportGpx,
          icon: const Icon(Icons.download_rounded),
          tooltip: 'GPX dışa aktar (haritadaki noktalar)',
        ),
        badge,
      ];
    }

    return [
      _calibrateToolbarButton(),
      PopupMenuButton<String>(
        tooltip: 'Diğer',
        icon: const Icon(Icons.more_vert_rounded),
        color: const Color(0xFF162636),
        onSelected: (value) {
          switch (value) {
            case 'profiles':
              _showCalibrationProfilesSheet();
              break;
            case 'diag':
              _showDiagnosticsSheet();
              break;
            case 'history':
              _showAnalysisHistorySheet();
              break;
            case 'gpx':
              _exportGpx();
              break;
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'profiles',
            child: Text('Kalibrasyon profilleri'),
          ),
          PopupMenuItem(
            value: 'diag',
            child: Text(kMapDiagHeadingAlignment),
          ),
          const PopupMenuItem(
            value: 'history',
            child: Text('Analiz geçmişi'),
          ),
          const PopupMenuItem(
            value: 'gpx',
            child: Text('GPX dışa aktar'),
          ),
        ],
      ),
      badge,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final center = _worldMapFlutterMapCenter();
    final mobile = useMobileLayout(context);
    final bottomChromeLift = _visualizationMode == VisualizationMode.worldMap
        ? MapBottomChrome.reservedHeight(
            hasStrip: _worldMapHotspotStripVisible,
          )
        : 0.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: _visualizationMode == VisualizationMode.worldMap
          ? null
          : AppBar(
              title: Text(AppConfig.mapTitleForHost(_serverIp)),
              backgroundColor: AppColors.backgroundNavy,
              foregroundColor: Colors.white,
              actions: _mapAppBarActions(mobile),
            ),
      extendBodyBehindAppBar:
          _visualizationMode == VisualizationMode.worldMap,
      bottomNavigationBar: const ColoredBox(
        color: Color(0xFF060B12),
        child: TrustDisclaimerBar(),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildExperienceSwitcherBar(mobile: mobile),
          _buildCalibratedModeRibbon(),
          Expanded(
            child: Stack(
              children: [
          if (_visualizationMode == VisualizationMode.chartOverlay)
            _buildChartOverlayView(mobile: mobile)
          else
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(center.lat, center.lon),
                initialZoom: 12,
                onMapReady: () {
                  _mapReady = true;
                  _flushPendingMapMove();
                  _primeWorldMapViewportFromController();
                  if (_geoViz.isBoatAnchorEstimated) {
                    _pendingBoatAnchorBoundsFit = true;
                    _flushBoatAnchorBoundsFit();
                  }
                  _syncLiveGpsStreamWithMode();
                },
                onPositionChanged: (camera, _) {
                  _scheduleViewportFromMapCamera(camera);
                },
                onLongPress: (_, point) => _showMarineLongPressSheet(point),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.deniz.uygulamasi',
                ),
                AnimatedBuilder(
                  animation: _worldMapLayersListenable,
                  builder: (context, _) {
                    if (!_showIntensityOverlay) {
                      return CircleLayer(circles: const <CircleMarker>[]);
                    }
                    return CircleLayer(circles: _buildIntensityOverlay());
                  },
                ),
                AnimatedBuilder(
                  animation: _worldMapLayersListenable,
                  builder: (context, _) {
                    if (!_showCorridorOverlay) {
                      return PolylineLayer(polylines: const <Polyline>[]);
                    }
                    return PolylineLayer(polylines: _buildConnectionOverlays());
                  },
                ),
                AnimatedBuilder(
                  animation: _worldMapMarkersListenable,
                  builder: (context, _) {
                    return CircleLayer(circles: _buildGpsAccuracyCircles());
                  },
                ),
                RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _worldMapMarkersListenable,
                    builder: (context, _) {
                      final layout = _worldHotspotLayout.value;
                      final placements =
                          layout?.placements ?? const <WorldMapHotspotPlacement>[];
                      return MarkerLayer(
                        markers: _buildWorldMapMarkers(
                          placements,
                          mobileLayout: useMobileLayout(context),
                        ),
                      );
                    },
                  ),
                ),
                const SimpleAttributionWidget(
                  source: Text(kMapAttribOpenStreetMap),
                ),
              ],
            ),
          if (_visualizationMode == VisualizationMode.worldMap &&
              !_geoViz.canRenderWorldMapHotspots &&
              !_isEffectiveBoatAnchorEstimatedMode &&
              _hotspots.isEmpty) ...[
            Positioned.fill(child: _buildImageSpaceWorldMapGhostLayer()),
            _buildImageSpaceWorldMapEmptyStateOverlay(),
          ],
          if (_visualizationMode == VisualizationMode.worldMap &&
              _geoViz.isBoatAnchorEstimated)
            Positioned(
              left: 12,
              right: 12,
              bottom: bottomChromeLift + 8,
              child: SafeArea(
                top: false,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xE60D1824),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x66FFB74D)),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFFFFCC80),
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            kMapPremiumApproxLocationShort,
                            style: TextStyle(
                              color: Color(0xFFFFF3E0),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              height: 1.25,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (_visualizationMode == VisualizationMode.worldMap &&
              _showBoatAnchorOffscreenHint)
            Positioned(
              left: 12,
              right: 12,
              bottom: bottomChromeLift + 56,
              child: SafeArea(
                top: false,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xE63E2723),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xAAFFB74D)),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: Color(0xFFFFE082),
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            kMapBoatAnchorApproximateOffscreenHint,
                            style: TextStyle(
                              color: Color(0xFFFFF8E1),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (_visualizationMode == VisualizationMode.worldMap)
            _buildWorldMapRuntimeDebugStrip(),
          if (_visualizationMode == VisualizationMode.worldMap &&
              _showApproxGeoMarkersMissing)
            Positioned(
              left: 12,
              right: 12,
              bottom: bottomChromeLift +
                  (_geoViz.isBoatAnchorEstimated ? 112 : 56),
              child: SafeArea(
                top: false,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xE65D4037),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0x66FFB74D)),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        Icon(
                          Icons.place_outlined,
                          color: Color(0xFFFFE082),
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            kMapApproxHotspotLatLonEmpty,
                            style: TextStyle(
                              color: Color(0xFFFFF8E1),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (_visualizationMode == VisualizationMode.worldMap)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: MapPremiumTopBar(
                onBackHome: _navigateBackHome,
                modeBadgeLabel: _mapModeBadgeLabel(),
                gpsStatusLabel: _gpsReliabilityLabel(),
                gpsStatusTone: _gpsReliabilityTone(),
                dataSourceLabel:
                    (AppSettingsScope.maybeOf(context)?.settings
                            .showMapPreviewSourceInfo ??
                        true)
                    ? _analysisSourceSummary
                    : null,
                healthOk: _mapHealthOkLast,
                busy: _isLoading,
                onRefresh: _refreshAnalysis,
                onDownload: _exportGpx,
                onSettings: _showServerIpDialog,
                onNotifications: _showDiagnosticsSheet,
                onProfile: _showCalibrationProfilesSheet,
              ),
            ),
          if (_visualizationMode == VisualizationMode.worldMap && !mobile)
            Positioned(
              top: 92,
              left: 12,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton.filled(
                    key: const Key('btn_map_filter_toggle'),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surfaceDark.withValues(alpha: 0.85),
                    ),
                    onPressed: () =>
                        setState(() => _showControls = !_showControls),
                    icon: Icon(
                      _showControls ? Icons.tune : Icons.tune_outlined,
                    ),
                    tooltip: kMapPremiumFiltersTitle,
                  ),
                  const SizedBox(width: 8),
                  if (_showControls) _buildMapToolbox(),
                ],
              ),
            ),
          if (_visualizationMode == VisualizationMode.worldMap && mobile)
            Positioned(
              top: 92,
              left: 12,
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    IconButton.filled(
                      key: const Key('btn_map_filter_toggle'),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surfaceDark.withValues(alpha: 0.85),
                      ),
                      onPressed: _openMapControlsSheet,
                      icon: const Icon(Icons.tune_rounded),
                      tooltip: kMapPremiumFiltersTitle,
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surfaceDark.withValues(alpha: 0.85),
                      ),
                      onPressed: _openMapLegendSheet,
                      icon: const Icon(Icons.palette_rounded),
                      tooltip: kMapPremiumLegendTitle,
                    ),
                  ],
                ),
              ),
            ),
          if (_visualizationMode == VisualizationMode.worldMap && !mobile)
            Positioned(
              top: 92,
              right: 12,
              child: MapPremiumLegend(
                visible: _showLegend,
                showIntensity: _showIntensityOverlay,
                showCorridor: _showCorridorOverlay,
              ),
            ),
          if (_visualizationMode == VisualizationMode.worldMap)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ValueListenableBuilder<int?>(
                valueListenable: _hotspotFocusId,
                builder: (context, focusId, _) {
                  return _buildWorldMapBottomChrome(
                    mobile: mobile,
                    selectedHotspotId: focusId,
                  );
                },
              ),
            ),
          _buildHotspotDetailOverlay(),
          if (_visualizationMode == VisualizationMode.worldMap)
            _buildWorldMapFloatingPills(),
          _buildStatusCard(),
          _buildChartPreviewCornerCard(mobile: mobile),
          if (_visualizationMode == VisualizationMode.worldMap ||
              _visualizationMode == VisualizationMode.chartOverlay)
            const Positioned.fill(child: MapVignetteOverlay()),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: null,
    );
  }
}
