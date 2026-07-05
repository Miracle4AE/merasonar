import 'dart:async';

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'api_service.dart';
import 'config/app_config.dart';
import 'dialogs/server_host_dialog.dart';
import 'local_storage_service.dart';
import 'l10n/app_strings_tr.dart';
import 'services/backend_discovery_service.dart';
import 'utils/android_backend_host_policy.dart';
import 'utils/app_haptics.dart';
import 'domain/live_ai_context.dart';
import 'map_screen.dart';
import 'navigation/captain_atlas_launcher.dart';
import 'widgets/premium/feedback/premium_dialog.dart';
import 'widgets/premium/feedback/premium_toast.dart';
import 'services/ai_assistant_cache.dart';
import 'services/client_identity_service.dart';
import 'services/marine_intelligence_cache.dart';
import 'domain/ai_assistant_request.dart';
import 'map/widgets/live_area/captain_atlas_live_card.dart';
import 'map/widgets/live_area/gps_status_card.dart';
import 'map/widgets/live_area/live_area_header_card.dart';
import 'map/widgets/live_area/live_area_premium_layout.dart';
import 'map/widgets/live_area/live_area_safety_card.dart';
import 'map/widgets/live_area/live_area_timeline_card.dart';
import 'map/widgets/live_area/live_score_premium_card.dart';
import 'map/widgets/live_area/nearest_hotspot_card.dart';
import 'theme/app_colors.dart';
import 'widgets/backend_connection_badge.dart';

export 'l10n/app_strings_tr.dart' show kNearbyModeImageSpace, kNearbyModeUnknown;

/// Real-time assistant using GPS + optional last photo analysis (geo hotspots only).
class LiveAreaScreen extends StatefulWidget {
  const LiveAreaScreen({
    super.key,
    required this.serverIp,
    this.mockPosition,
    this.mockLiveScoreOnly,
    this.cachedAnalysisForTests,
    this.onLiveScoreCoordinateModeForTests,
  });

  final String serverIp;

  /// Tests: skip real GPS and return a fixed [Position].
  final Future<Position?> Function()? mockPosition;

  /// Tests: skip GPS + HTTP and show a fixed score card.
  final Future<LiveFishingScoreResponse> Function()? mockLiveScoreOnly;

  /// Tests: pretend this analysis was restored from disk (no SharedPreferences).
  final FishingZoneResponse? cachedAnalysisForTests;

  /// Tests: notifies which coordinate mode string is sent on [fetchLiveFishingScore].
  final void Function(String coordinateMode)? onLiveScoreCoordinateModeForTests;

  @override
  State<LiveAreaScreen> createState() => _LiveAreaScreenState();
}

class _LiveAreaScreenState extends State<LiveAreaScreen>
    with WidgetsBindingObserver {
  final LocalStorageService _storage = LocalStorageService();
  late ApiService _api;
  final AiAssistantCache _aiAssistantCache = AiAssistantCache();
  final ClientIdentityService _clientIdentityService = ClientIdentityService();

  FishingZoneResponse? _sessionAnalysis;

  LiveFishingScoreResponse? _live;
  bool _loading = false;
  bool _apiFailed = false;
  /// Sunucu döndüğü kısa Türkçe uyarı (ör. 404 → canlı skor yolu yok).
  String? _liveApiErrorHint;
  String? _gpsError;
  PermissionState _permissionState = PermissionState.unknown;

  Position? _lastPosition;
  DateTime? _lastFixTime;

  String _coordinateModeFromAnalysis = kCoordinateModeUnknown;
  Timer? _tick;

  bool _autoRefresh = true;

  bool _liveHealthChecking = false;
  bool? _liveHealthOkLast;
  bool _liveDiscoverBusy = false;

  /// Canlı hotspot API yükünden sonra önbellekten gelen hotspot sayısı (çevrimdışı ileti için).
  int _cachedHotspotPayloadCount = 0;

  bool get _hideConnectionBadge =>
      widget.mockLiveScoreOnly != null ||
      widget.mockPosition != null ||
      widget.cachedAnalysisForTests != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _api = ApiService(
      serverBaseUrl: AppConfig.buildApiBaseUrl(widget.serverIp.trim()),
    );
    if (widget.cachedAnalysisForTests != null) {
      _sessionAnalysis = widget.cachedAnalysisForTests;
      _coordinateModeFromAnalysis =
          liveAreaCoordinateModeFromCache(widget.cachedAnalysisForTests);
    }
    _preloadAnalysisMeta();
    Future<void>.microtask(() async {
      if (!_hideConnectionBadge) {
        await _refreshLiveHealth();
      }
      await _refresh();
      _armTimer();
    });
  }

  Future<void> _refreshLiveHealth() async {
    if (!mounted) return;
    final sip = widget.serverIp.trim();
    if (Platform.isAndroid && shouldBlockAndroidLoopbackHost(sip)) {
      setState(() => _liveHealthOkLast = null);
      return;
    }
    setState(() => _liveHealthChecking = true);
    try {
      final api =
          ApiService(serverBaseUrl: AppConfig.buildApiBaseUrl(sip));
      final r = await api.checkHealth();
      if (!mounted) return;
      setState(() => _liveHealthOkLast = r.ok);
    } catch (e, st) {
      debugPrint('LiveAreaScreen _refreshLiveHealth: $e\n$st');
      if (!mounted) return;
      setState(() => _liveHealthOkLast = false);
    } finally {
      if (mounted) {
        setState(() => _liveHealthChecking = false);
      }
    }
  }

  Future<void> _reloadLiveIncludingHealth() async {
    if (_hideConnectionBadge) {
      await _refresh();
      return;
    }
    await _refreshLiveHealth();
    if (!mounted) return;
    await _refresh();
  }

  Future<void> _openLiveServerSettings() async {
    final badge = resolveBackendConnectionBadge(
      serverIp: widget.serverIp,
      discoveryBusy: _liveDiscoverBusy,
      serverHealthChecking: _liveHealthChecking,
      manualIpRequiredAndroid:
          Platform.isAndroid &&
          shouldBlockAndroidLoopbackHost(widget.serverIp.trim()),
      healthOkLast: _liveHealthOkLast,
    );
    final result = await showMerasonarServerHostDialog(
      context,
      initialHost: widget.serverIp,
      badgeSnapshot: badge,
      autoDiscoverBusy: _liveDiscoverBusy,
      onRequestAutoDiscover: () async {
        await _runLiveAutomaticDiscover();
      },
    );
    if (!mounted) return;
    if (result == null) {
      await _refreshLiveHealth();
      return;
    }
    final trimmed = result.trim();
    if (trimmed.isEmpty) {
      await _refreshLiveHealth();
      return;
    }
    if (trimmed == widget.serverIp.trim()) {
      await _refreshLiveHealth();
      return;
    }
    await _storage.saveServerIp(trimmed);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => LiveAreaScreen(
          serverIp: trimmed,
          mockPosition: widget.mockPosition,
          mockLiveScoreOnly: widget.mockLiveScoreOnly,
          cachedAnalysisForTests: widget.cachedAnalysisForTests,
          onLiveScoreCoordinateModeForTests:
              widget.onLiveScoreCoordinateModeForTests,
        ),
      ),
    );
  }

  Future<void> _runLiveAutomaticDiscover() async {
    if (_liveDiscoverBusy || !mounted) return;
    setState(() => _liveDiscoverBusy = true);
    final svc = BackendDiscoveryService();
    try {
      final outcome = await svc.discoverBackend(
        storage: _storage,
        scanEvenIfSavedWorks: true,
      );
      if (!mounted) return;
      final persist = outcome.persistHost;
      final alt = outcome.alternateSuggestedHost;
      if (persist != null && persist.trim().isNotEmpty) {
        final ip = persist.trim();
        await _storage.saveServerIp(ip);
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => LiveAreaScreen(
              serverIp: ip,
              mockPosition: widget.mockPosition,
              mockLiveScoreOnly: widget.mockLiveScoreOnly,
              cachedAnalysisForTests: widget.cachedAnalysisForTests,
              onLiveScoreCoordinateModeForTests:
                  widget.onLiveScoreCoordinateModeForTests,
            ),
          ),
        );
        return;
      }
      if (alt != null && alt.trim().isNotEmpty) {
        final altTrim = alt.trim();
        final useAlt = await PremiumDialog.showConfirm(
          context,
          title: kDiscoverAlternateSnack,
          message: alternateServerHint(widget.serverIp, altTrim),
          confirmLabel: kDiscoverUseAlternate,
          tone: PremiumDialogTone.info,
        );
        if (useAlt == true && mounted) {
          await _storage.saveServerIp(altTrim);
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => LiveAreaScreen(
                serverIp: altTrim,
                mockPosition: widget.mockPosition,
                mockLiveScoreOnly: widget.mockLiveScoreOnly,
                cachedAnalysisForTests: widget.cachedAnalysisForTests,
                onLiveScoreCoordinateModeForTests:
                    widget.onLiveScoreCoordinateModeForTests,
              ),
            ),
          );
        }
        await _refreshLiveHealth();
        return;
      }
      PremiumToast.offline(context, kDiscoverNotFound);
    } catch (e, st) {
      debugPrint('_runLiveAutomaticDiscover: $e\n$st');
      if (mounted) {
        PremiumToast.offline(context, kDiscoverNotFound);
      }
    } finally {
      svc.close();
      if (mounted) {
        setState(() => _liveDiscoverBusy = false);
      }
    }
    if (!mounted) return;
    await _refreshLiveHealth();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      if (_autoRefresh && mounted && widget.mockLiveScoreOnly == null) {
        _armTimer();
      }
    } else {
      _tick?.cancel();
    }
  }

  void _armTimer() {
    _tick?.cancel();
    if (!mounted || !_autoRefresh) return;
    if (widget.mockLiveScoreOnly != null || widget.mockPosition != null) {
      return;
    }
    _tick = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted && !_loading) {
        _refresh(fromPeriodic: true);
      }
    });
  }

  Future<void> _preloadAnalysisMeta() async {
    final cached =
        widget.cachedAnalysisForTests ??
        await _storage.loadLatestFishingZoneResponse();
    if (!mounted) return;
    setState(() {
      _sessionAnalysis = cached;
      _coordinateModeFromAnalysis =
          liveAreaCoordinateModeFromCache(cached);
    });
  }

  List<Map<String, dynamic>> _hotspotsPayload(FishingZoneResponse? cached) {
    if (cached == null) return const [];
    return cached.hotspots
        .map(
          (h) => <String, dynamic>{
            'id': h.id,
            'latitude': h.latitude,
            'longitude': h.longitude,
            'recommendation_rank': h.recommendationRank >= 999998
                ? null
                : h.recommendationRank,
          },
        )
        .toList(growable: false);
  }

  Future<void> _refresh({bool fromPeriodic = false}) async {
    if (widget.mockLiveScoreOnly != null) {
      setState(() {
        _loading = true;
        _apiFailed = false;
        _liveApiErrorHint = null;
        _gpsError = null;
      });
      try {
        final r = await widget.mockLiveScoreOnly!();
        if (!mounted) return;
        setState(() {
          _live = r;
          _loading = false;
          _liveApiErrorHint = null;
        });
        AppHaptics.analysisComplete();
      } catch (e, st) {
        debugPrint('LiveAreaScreen mockLiveScoreOnly: $e\n$st');
        if (!mounted) return;
        setState(() {
          _apiFailed = true;
          _liveApiErrorHint = e is ApiException ? e.message : null;
          _loading = false;
        });
        AppHaptics.warning();
      }
      return;
    }

    setState(() {
      _loading = true;
      _apiFailed = false;
      _liveApiErrorHint = null;
      _gpsError = null;
    });

    Position? pos;

    if (widget.mockPosition != null) {
      pos = await widget.mockPosition!();
    } else {
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) {
        if (!mounted) return;
        if (!fromPeriodic) AppHaptics.warning();
        setState(() {
          _gpsError = kGpsServiceOff;
          _permissionState = PermissionState.serviceOff;
          _loading = false;
        });
        return;
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied) {
        if (!mounted) return;
        if (!fromPeriodic) AppHaptics.warning();
        setState(() {
          _permissionState = PermissionState.denied;
          _gpsError = kGpsPermissionDenied;
          _loading = false;
        });
        return;
      }
      if (perm == LocationPermission.deniedForever) {
        if (!mounted) return;
        if (!fromPeriodic) AppHaptics.warning();
        setState(() {
          _permissionState = PermissionState.deniedForever;
          _gpsError = kGpsPermissionDeniedForever;
          _loading = false;
        });
        return;
      }

      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
      } catch (e, st) {
        debugPrint('LiveAreaScreen GPS: $e\n$st');
        if (!mounted) return;
        if (!fromPeriodic) AppHaptics.warning();
        setState(() {
          _gpsError = kGpsFixFailed;
          _permissionState = PermissionState.unavailable;
          _loading = false;
        });
        return;
      }
    }

    if (pos == null) {
      if (!mounted) return;
      if (!fromPeriodic) AppHaptics.warning();
      setState(() {
        _gpsError = kGpsUnavailable;
        _loading = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _lastPosition = pos;
      _lastFixTime = DateTime.now();
      _permissionState = PermissionState.granted;
    });

    final cached =
        widget.cachedAnalysisForTests ??
        await _storage.loadLatestFishingZoneResponse();
    final coordForApi =
        liveAreaCoordinateModeFromCache(cached);
    widget.onLiveScoreCoordinateModeForTests?.call(coordForApi);
    final payload = _hotspotsPayload(cached);
    final spotCount = payload.length;

    if (!_hideConnectionBadge && _liveHealthOkLast == false) {
      if (!mounted) return;
      setState(() {
        _sessionAnalysis = cached;
        _cachedHotspotPayloadCount = spotCount;
        _live = null;
        _loading = false;
        _apiFailed = false;
        _liveApiErrorHint = null;
        _coordinateModeFromAnalysis = coordForApi;
      });
      return;
    }

    try {
      final res = await _api.fetchLiveFishingScore(
        currentLat: pos.latitude,
        currentLon: pos.longitude,
        gpsAccuracyM: pos.accuracy.isFinite ? pos.accuracy : null,
        latestHotspots: payload.isEmpty ? null : payload,
        coordinateMode: coordForApi,
      );
      if (!mounted) return;
      setState(() {
        _sessionAnalysis = cached;
        _cachedHotspotPayloadCount = spotCount;
        _live = res;
        _loading = false;
        _apiFailed = false;
        _liveApiErrorHint = null;
        _coordinateModeFromAnalysis = coordForApi;
      });
      unawaited(
        MarineIntelligenceCache().saveLastLiveScore(
          liveScore: res.liveScore,
          rating: res.rating,
          reasoning: res.reasoning,
          trustNote: res.trustNote,
        ),
      );
      if (!fromPeriodic) {
        AppHaptics.analysisComplete();
      }
    } catch (e, st) {
      debugPrint('LiveAreaScreen fetchLiveFishingScore: $e\n$st');
      if (!mounted) return;
      if (!_hideConnectionBadge && _liveHealthOkLast == false) {
        setState(() {
          _cachedHotspotPayloadCount = spotCount;
          _apiFailed = false;
          _liveApiErrorHint = null;
          _loading = false;
          _coordinateModeFromAnalysis = coordForApi;
          _live = null;
        });
        return;
      }
      final hint = e is ApiException ? e.message : null;
      setState(() {
        _cachedHotspotPayloadCount = spotCount;
        _apiFailed = true;
        _liveApiErrorHint = hint;
        _loading = false;
        _coordinateModeFromAnalysis = coordForApi;
      });
      if (!fromPeriodic) {
        AppHaptics.warning();
      }
    }
  }

  LiveAreaPermissionState _mapPermissionState(PermissionState state) {
    switch (state) {
      case PermissionState.granted:
        return LiveAreaPermissionState.granted;
      case PermissionState.denied:
        return LiveAreaPermissionState.denied;
      case PermissionState.deniedForever:
        return LiveAreaPermissionState.deniedForever;
      case PermissionState.serviceOff:
        return LiveAreaPermissionState.serviceOff;
      case PermissionState.unavailable:
        return LiveAreaPermissionState.unavailable;
      case PermissionState.unknown:
        return LiveAreaPermissionState.unknown;
    }
  }

  String? _formatLastFixLabel() {
    final t = _lastFixTime;
    if (t == null) return null;
    return t.toLocal().toIso8601String();
  }

  String? _gpsHeaderStatusLabel() {
    if (_gpsError != null) return kLiveGpsTrustLow;
    if (_lastPosition != null) return kLiveGpsTrustReliable;
    if (_loading) return kPremiumDashConnectionChecking;
    return null;
  }

  String? _cachedLiveAiSummary() {
    final analysis = _sessionAnalysis;
    final live = _live;
    final coords = _resolveLiveLatLon();
    if (analysis == null || live == null || coords == null) return null;
    final liveContext = buildLiveAiContext(
      currentLat: coords.lat,
      currentLon: coords.lon,
      liveScore: live,
      coordinateMode: _coordinateModeFromAnalysis,
      gpsAccuracyM: coords.accuracy,
    );
    final cached = _aiAssistantCache.get(
      analysis,
      scope: AiAssistantScope.liveContext,
      liveContext: liveContext,
    );
    final summary = cached?.summaryTr.trim();
    if (summary == null || summary.isEmpty) return null;
    return summary;
  }

  @override
  Widget build(BuildContext context) {
    final offlineScore =
        !_hideConnectionBadge && _liveHealthOkLast == false;
    final mode = _coordinateModeFromAnalysis;
    final geoMode = mode == kCoordinateModeGeoReferenced;
    String? calibrationMessage;
    if (!geoMode) {
      calibrationMessage = mode == kCoordinateModeImageSpace
          ? kNearbyModeImageSpace
          : kNearbyModeUnknown;
    }

    final noAnalysis = _sessionAnalysis == null ||
        _sessionAnalysis!.hotspots.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      appBar: AppBar(
        title: const Text(kLiveAreaAppBarTitle),
        backgroundColor: AppColors.backgroundNavy,
        actions: [
          IconButton(
            tooltip: kTooltipRefresh,
            onPressed: _loading
                ? null
                : () {
                    unawaited(_reloadLiveIncludingHealth());
                  },
            icon: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: LiveAreaPremiumLayout(
        header: LiveAreaHeaderCard(
          connectionBadge: _hideConnectionBadge
              ? null
              : BackendConnectionBadge(
                  data: resolveBackendConnectionBadge(
                    serverIp: widget.serverIp,
                    discoveryBusy: _liveDiscoverBusy,
                    serverHealthChecking: _liveHealthChecking,
                    manualIpRequiredAndroid: Platform.isAndroid &&
                        shouldBlockAndroidLoopbackHost(
                          widget.serverIp.trim(),
                        ),
                    healthOkLast: _liveHealthOkLast,
                  ),
                  onTap: _openLiveServerSettings,
                ),
          gpsStatusLabel: _gpsHeaderStatusLabel(),
          lastUpdateLabel: _formatLastFixLabel(),
        ),
        scoreCard: LiveScorePremiumCard(
          loading: _loading,
          autoRefresh: _autoRefresh,
          onAutoRefreshChanged: (v) {
            setState(() {
              _autoRefresh = v;
              if (v) {
                _armTimer();
              } else {
                _tick?.cancel();
              }
            });
          },
          live: _live,
          offline: offlineScore,
          offlineHotspotCount: _cachedHotspotPayloadCount,
          apiFailed: _apiFailed,
          apiErrorHint: _liveApiErrorHint,
          lastUpdateLabel: _formatLastFixLabel(),
        ),
        gpsCard: GpsStatusCard(
          gpsError: _gpsError,
          permissionState: _mapPermissionState(_permissionState),
          latitude: _lastPosition?.latitude,
          longitude: _lastPosition?.longitude,
          accuracyM: _lastPosition?.accuracy.isFinite == true
              ? _lastPosition!.accuracy
              : null,
          lastFixLabel: _formatLastFixLabel(),
          loading: _loading && _gpsError == null && _lastPosition == null,
          onOpenLocationSettings: () async {
            await Geolocator.openLocationSettings();
          },
          onRequestPermission: () async {
            await Geolocator.requestPermission();
            if (!mounted) return;
            await _refresh();
          },
          onOpenAppSettings: Geolocator.openAppSettings,
          onRetry: () async {
            await _refresh();
          },
        ),
        hotspotCard: NearestHotspotCard(
          coordinateMode: mode,
          loading: _loading && _live == null && geoMode,
          hotspot: geoMode ? _live?.nearestHotspot : null,
          needsCalibrationMessage: calibrationMessage,
          onCalibrateTap: _openPhotoAnalysisForCalibration,
          onOpenMapTap: () {
            Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => MapScreen(serverIp: widget.serverIp),
              ),
            );
          },
          showEmptyNoAnalysis:
              geoMode && noAnalysis && calibrationMessage == null,
          waitingForScore:
              geoMode && !noAnalysis && _live == null && !_loading,
        ),
        captainCard: CaptainAtlasLiveCard(
          enabled: _canShowLiveAiButton,
          onAsk: _openLiveAiAssistant,
          lastSummary: _cachedLiveAiSummary(),
        ),
        howToReadCard: const LiveAreaTimelineCard(),
        safetyCard: LiveAreaSafetyCard(trustNote: _live?.trustNote),
      ),
    );
  }

  bool get _canShowLiveAiButton =>
      _sessionAnalysis != null &&
      _sessionAnalysis!.hotspots.isNotEmpty &&
      _live != null &&
      !_loading &&
      _gpsError == null &&
      _resolveLiveLatLon() != null;

  ({double lat, double lon, double? accuracy})? _resolveLiveLatLon() {
    final p = _lastPosition;
    if (p != null) {
      return (
        lat: p.latitude,
        lon: p.longitude,
        accuracy: p.accuracy.isFinite ? p.accuracy : null,
      );
    }
    final boat = _sessionAnalysis?.boat.smoothedGps;
    if (boat != null && (boat.lat.abs() > 1e-9 || boat.lon.abs() > 1e-9)) {
      return (lat: boat.lat, lon: boat.lon, accuracy: null);
    }
    return null;
  }

  Future<void> _openLiveAiAssistant() async {
    final analysis = _sessionAnalysis;
    final live = _live;
    final coords = _resolveLiveLatLon();
    if (analysis == null || live == null || coords == null || !mounted) return;
    final liveContext = buildLiveAiContext(
      currentLat: coords.lat,
      currentLon: coords.lon,
      liveScore: live,
      coordinateMode: _coordinateModeFromAnalysis,
      gpsAccuracyM: coords.accuracy,
    );
    await CaptainAtlasLauncher.launch(
      context,
      CaptainAtlasLaunchRequest(
        serverIp: widget.serverIp,
        entryPoint: CaptainAtlasEntryPoint.liveArea,
        analysis: analysis,
        liveContext: liveContext,
        apiService: _api,
        aiCache: _aiAssistantCache,
        clientIdentity: _clientIdentityService,
      ),
    );
    if (mounted) setState(() {});
  }

  void _openPhotoAnalysisForCalibration() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MapScreen(
          serverIp: widget.serverIp,
          openControlPointCalibration: true,
        ),
      ),
    );
  }
}

enum PermissionState {
  unknown,
  granted,
  denied,
  deniedForever,
  serviceOff,
  unavailable,
}
