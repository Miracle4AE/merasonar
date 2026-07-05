import 'package:deniz_app/config/app_config.dart';

/// Varsayılan harita deneyimi sekmesi.
enum DefaultMapExperience {
  map,
  photoAnalysis,
}

/// Hotspot sıralama tercihi.
enum HotspotSortPreference {
  score,
  proximity,
}

/// Otomatik yenileme aralığı.
enum AutoRefreshInterval {
  oneMinute,
  fiveMinutes,
  fifteenMinutes,
  thirtyMinutes,
}

extension AutoRefreshIntervalX on AutoRefreshInterval {
  Duration get duration => switch (this) {
        AutoRefreshInterval.oneMinute => const Duration(minutes: 1),
        AutoRefreshInterval.fiveMinutes => const Duration(minutes: 5),
        AutoRefreshInterval.fifteenMinutes => const Duration(minutes: 15),
        AutoRefreshInterval.thirtyMinutes => const Duration(minutes: 30),
      };

  String get storageKey => name;

  static AutoRefreshInterval fromStorage(String? raw) {
    return AutoRefreshInterval.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => AutoRefreshInterval.fiveMinutes,
    );
  }
}

/// Koordinat gösterim biçimi.
enum CoordinateDisplayFormat {
  decimal,
  dms,
}

extension CoordinateDisplayFormatX on CoordinateDisplayFormat {
  String get storageKey => name;

  static CoordinateDisplayFormat fromStorage(String? raw) {
    return CoordinateDisplayFormat.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => CoordinateDisplayFormat.dms,
    );
  }
}

/// Premium glow yoğunluğu.
enum GlowIntensityLevel {
  low,
  normal,
  strong,
}

extension GlowIntensityLevelX on GlowIntensityLevel {
  double get multiplier => switch (this) {
        GlowIntensityLevel.low => 0.45,
        GlowIntensityLevel.normal => 1.0,
        GlowIntensityLevel.strong => 1.35,
      };

  String get storageKey => name;

  static GlowIntensityLevel fromStorage(String? raw) {
    return GlowIntensityLevel.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => GlowIntensityLevel.normal,
    );
  }
}

/// Kart yoğunluğu — padding/spacing çarpanı.
enum CardDensityLevel {
  relaxed,
  standard,
  tight,
}

extension CardDensityLevelX on CardDensityLevel {
  double get spacingMultiplier => switch (this) {
        CardDensityLevel.relaxed => 1.18,
        CardDensityLevel.standard => 1.0,
        CardDensityLevel.tight => 0.82,
      };

  double get cardPaddingMultiplier => switch (this) {
        CardDensityLevel.relaxed => 1.15,
        CardDensityLevel.standard => 1.0,
        CardDensityLevel.tight => 0.78,
      };

  String get storageKey => name;

  static CardDensityLevel fromStorage(String? raw) {
    return CardDensityLevel.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => CardDensityLevel.standard,
    );
  }
}

/// Son başarılı bağlantı kaydı.
class LastSuccessfulConnection {
  const LastSuccessfulConnection({
    required this.host,
    required this.port,
    required this.checkedAt,
    this.serviceVersion,
    this.serviceName,
    this.latencyMs,
  });

  final String host;
  final int port;
  final DateTime checkedAt;
  final String? serviceVersion;
  final String? serviceName;
  final int? latencyMs;

  Map<String, dynamic> toJson() => {
        'host': host,
        'port': port,
        'checked_at': checkedAt.toUtc().toIso8601String(),
        if (serviceVersion != null) 'service_version': serviceVersion,
        if (serviceName != null) 'service_name': serviceName,
        if (latencyMs != null) 'latency_ms': latencyMs,
      };

  factory LastSuccessfulConnection.fromJson(Map<String, dynamic> json) {
    return LastSuccessfulConnection(
      host: json['host']?.toString() ?? '',
      port: json['port'] is int
          ? json['port'] as int
          : int.tryParse(json['port']?.toString() ?? '') ??
              AppConfig.defaultApiPort,
      checkedAt: DateTime.tryParse(json['checked_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      serviceVersion: json['service_version']?.toString(),
      serviceName: json['service_name']?.toString(),
      latencyMs: json['latency_ms'] is int
          ? json['latency_ms'] as int
          : int.tryParse(json['latency_ms']?.toString() ?? ''),
    );
  }
}

/// Uygulama ayarları — kalıcı tercihlerin tek modeli.
class AppSettings {
  const AppSettings({
    this.serverPort = AppConfig.defaultApiPort,
    this.refreshLiveDataOnLaunch = true,
    this.showCacheFirstThenRefresh = true,
    this.autoRefreshEnabled = true,
    this.autoRefreshInterval = AutoRefreshInterval.fiveMinutes,
    this.forceRefreshAi = false,
    this.showDataSourceLabels = true,
    this.lastDataSyncAt,
    this.defaultMapExperience = DefaultMapExperience.map,
    this.defaultHotspotSort = HotspotSortPreference.score,
    this.minHotspotScore = 0.0,
    this.filterClassA = true,
    this.filterClassB = true,
    this.filterClassC = true,
    this.intensityOverlayDefault = true,
    this.corridorLinesDefault = false,
    this.legendDefault = true,
    this.autoOpenMarkerDetail = false,
    this.coordinateFormat = CoordinateDisplayFormat.dms,
    this.showMapPreviewSourceInfo = true,
    this.captainAtlasEnabled = true,
    this.alwaysTryLiveAi = false,
    this.useSafeFallbackSummary = true,
    this.showAiSourceBadge = true,
    this.compactView = false,
    this.largeTouchTargets = false,
    this.reduceMotion = false,
    this.glowIntensity = GlowIntensityLevel.normal,
    this.cardDensity = CardDensityLevel.standard,
    this.showStatusChips = true,
    this.showHelperTexts = true,
    this.lastSuccessfulConnection,
    this.lastHealthCheckAt,
    this.lastHealthOk,
    this.lastHealthLatencyMs,
    this.lastHealthServiceVersion,
    this.lastHealthServiceName,
  });

  final int serverPort;
  final bool refreshLiveDataOnLaunch;
  final bool showCacheFirstThenRefresh;
  final bool autoRefreshEnabled;
  final AutoRefreshInterval autoRefreshInterval;
  final bool forceRefreshAi;
  final bool showDataSourceLabels;
  final DateTime? lastDataSyncAt;
  final DefaultMapExperience defaultMapExperience;
  final HotspotSortPreference defaultHotspotSort;
  final double minHotspotScore;
  final bool filterClassA;
  final bool filterClassB;
  final bool filterClassC;
  final bool intensityOverlayDefault;
  final bool corridorLinesDefault;
  final bool legendDefault;
  final bool autoOpenMarkerDetail;
  final CoordinateDisplayFormat coordinateFormat;
  final bool showMapPreviewSourceInfo;
  final bool captainAtlasEnabled;
  final bool alwaysTryLiveAi;
  final bool useSafeFallbackSummary;
  final bool showAiSourceBadge;
  final bool compactView;
  final bool largeTouchTargets;
  final bool reduceMotion;
  final GlowIntensityLevel glowIntensity;
  final CardDensityLevel cardDensity;
  final bool showStatusChips;
  final bool showHelperTexts;
  final LastSuccessfulConnection? lastSuccessfulConnection;
  final DateTime? lastHealthCheckAt;
  final bool? lastHealthOk;
  final int? lastHealthLatencyMs;
  final String? lastHealthServiceVersion;
  final String? lastHealthServiceName;

  static const defaults = AppSettings();

  AppSettings copyWith({
    int? serverPort,
    bool? refreshLiveDataOnLaunch,
    bool? showCacheFirstThenRefresh,
    bool? autoRefreshEnabled,
    AutoRefreshInterval? autoRefreshInterval,
    bool? forceRefreshAi,
    bool? showDataSourceLabels,
    DateTime? lastDataSyncAt,
    bool clearLastDataSyncAt = false,
    DefaultMapExperience? defaultMapExperience,
    HotspotSortPreference? defaultHotspotSort,
    double? minHotspotScore,
    bool? filterClassA,
    bool? filterClassB,
    bool? filterClassC,
    bool? intensityOverlayDefault,
    bool? corridorLinesDefault,
    bool? legendDefault,
    bool? autoOpenMarkerDetail,
    CoordinateDisplayFormat? coordinateFormat,
    bool? showMapPreviewSourceInfo,
    bool? captainAtlasEnabled,
    bool? alwaysTryLiveAi,
    bool? useSafeFallbackSummary,
    bool? showAiSourceBadge,
    bool? compactView,
    bool? largeTouchTargets,
    bool? reduceMotion,
    GlowIntensityLevel? glowIntensity,
    CardDensityLevel? cardDensity,
    bool? showStatusChips,
    bool? showHelperTexts,
    LastSuccessfulConnection? lastSuccessfulConnection,
    bool clearLastSuccessfulConnection = false,
    DateTime? lastHealthCheckAt,
    bool? lastHealthOk,
    int? lastHealthLatencyMs,
    String? lastHealthServiceVersion,
    String? lastHealthServiceName,
    bool clearHealthSnapshot = false,
  }) {
    return AppSettings(
      serverPort: serverPort ?? this.serverPort,
      refreshLiveDataOnLaunch:
          refreshLiveDataOnLaunch ?? this.refreshLiveDataOnLaunch,
      showCacheFirstThenRefresh:
          showCacheFirstThenRefresh ?? this.showCacheFirstThenRefresh,
      autoRefreshEnabled: autoRefreshEnabled ?? this.autoRefreshEnabled,
      autoRefreshInterval: autoRefreshInterval ?? this.autoRefreshInterval,
      forceRefreshAi: forceRefreshAi ?? this.forceRefreshAi,
      showDataSourceLabels: showDataSourceLabels ?? this.showDataSourceLabels,
      lastDataSyncAt: clearLastDataSyncAt
          ? null
          : (lastDataSyncAt ?? this.lastDataSyncAt),
      defaultMapExperience: defaultMapExperience ?? this.defaultMapExperience,
      defaultHotspotSort: defaultHotspotSort ?? this.defaultHotspotSort,
      minHotspotScore: minHotspotScore ?? this.minHotspotScore,
      filterClassA: filterClassA ?? this.filterClassA,
      filterClassB: filterClassB ?? this.filterClassB,
      filterClassC: filterClassC ?? this.filterClassC,
      intensityOverlayDefault:
          intensityOverlayDefault ?? this.intensityOverlayDefault,
      corridorLinesDefault: corridorLinesDefault ?? this.corridorLinesDefault,
      legendDefault: legendDefault ?? this.legendDefault,
      autoOpenMarkerDetail: autoOpenMarkerDetail ?? this.autoOpenMarkerDetail,
      coordinateFormat: coordinateFormat ?? this.coordinateFormat,
      showMapPreviewSourceInfo:
          showMapPreviewSourceInfo ?? this.showMapPreviewSourceInfo,
      captainAtlasEnabled: captainAtlasEnabled ?? this.captainAtlasEnabled,
      alwaysTryLiveAi: alwaysTryLiveAi ?? this.alwaysTryLiveAi,
      useSafeFallbackSummary:
          useSafeFallbackSummary ?? this.useSafeFallbackSummary,
      showAiSourceBadge: showAiSourceBadge ?? this.showAiSourceBadge,
      compactView: compactView ?? this.compactView,
      largeTouchTargets: largeTouchTargets ?? this.largeTouchTargets,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      glowIntensity: glowIntensity ?? this.glowIntensity,
      cardDensity: cardDensity ?? this.cardDensity,
      showStatusChips: showStatusChips ?? this.showStatusChips,
      showHelperTexts: showHelperTexts ?? this.showHelperTexts,
      lastSuccessfulConnection: clearLastSuccessfulConnection
          ? null
          : (lastSuccessfulConnection ?? this.lastSuccessfulConnection),
      lastHealthCheckAt: clearHealthSnapshot
          ? null
          : (lastHealthCheckAt ?? this.lastHealthCheckAt),
      lastHealthOk:
          clearHealthSnapshot ? null : (lastHealthOk ?? this.lastHealthOk),
      lastHealthLatencyMs: clearHealthSnapshot
          ? null
          : (lastHealthLatencyMs ?? this.lastHealthLatencyMs),
      lastHealthServiceVersion: clearHealthSnapshot
          ? null
          : (lastHealthServiceVersion ?? this.lastHealthServiceVersion),
      lastHealthServiceName: clearHealthSnapshot
          ? null
          : (lastHealthServiceName ?? this.lastHealthServiceName),
    );
  }

  Map<String, dynamic> toJson() => {
        'server_port': serverPort,
        'refresh_live_on_launch': refreshLiveDataOnLaunch,
        'cache_first_then_refresh': showCacheFirstThenRefresh,
        'auto_refresh_enabled': autoRefreshEnabled,
        'auto_refresh_interval': autoRefreshInterval.storageKey,
        'force_refresh_ai': forceRefreshAi,
        'show_data_source_labels': showDataSourceLabels,
        if (lastDataSyncAt != null)
          'last_data_sync_at': lastDataSyncAt!.toUtc().toIso8601String(),
        'default_map_experience': defaultMapExperience.name,
        'default_hotspot_sort': defaultHotspotSort.name,
        'min_hotspot_score': minHotspotScore,
        'filter_class_a': filterClassA,
        'filter_class_b': filterClassB,
        'filter_class_c': filterClassC,
        'intensity_overlay_default': intensityOverlayDefault,
        'corridor_lines_default': corridorLinesDefault,
        'legend_default': legendDefault,
        'auto_open_marker_detail': autoOpenMarkerDetail,
        'coordinate_format': coordinateFormat.storageKey,
        'show_map_preview_source': showMapPreviewSourceInfo,
        'captain_atlas_enabled': captainAtlasEnabled,
        'always_try_live_ai': alwaysTryLiveAi,
        'use_safe_fallback_summary': useSafeFallbackSummary,
        'show_ai_source_badge': showAiSourceBadge,
        'compact_view': compactView,
        'large_touch_targets': largeTouchTargets,
        'reduce_motion': reduceMotion,
        'glow_intensity': glowIntensity.storageKey,
        'card_density': cardDensity.storageKey,
        'show_status_chips': showStatusChips,
        'show_helper_texts': showHelperTexts,
        if (lastSuccessfulConnection != null)
          'last_successful_connection': lastSuccessfulConnection!.toJson(),
        if (lastHealthCheckAt != null)
          'last_health_check_at': lastHealthCheckAt!.toUtc().toIso8601String(),
        if (lastHealthOk != null) 'last_health_ok': lastHealthOk,
        if (lastHealthLatencyMs != null)
          'last_health_latency_ms': lastHealthLatencyMs,
        if (lastHealthServiceVersion != null)
          'last_health_service_version': lastHealthServiceVersion,
        if (lastHealthServiceName != null)
          'last_health_service_name': lastHealthServiceName,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    LastSuccessfulConnection? lastConn;
    final rawConn = json['last_successful_connection'];
    if (rawConn is Map) {
      lastConn = LastSuccessfulConnection.fromJson(
        Map<String, dynamic>.from(rawConn),
      );
    }

    DefaultMapExperience mapExp = DefaultMapExperience.map;
    final mapRaw = json['default_map_experience']?.toString();
    if (mapRaw == DefaultMapExperience.photoAnalysis.name) {
      mapExp = DefaultMapExperience.photoAnalysis;
    }

    HotspotSortPreference sortPref = HotspotSortPreference.score;
    if (json['default_hotspot_sort']?.toString() ==
        HotspotSortPreference.proximity.name) {
      sortPref = HotspotSortPreference.proximity;
    }

    return AppSettings(
      serverPort: json['server_port'] is int
          ? json['server_port'] as int
          : int.tryParse(json['server_port']?.toString() ?? '') ??
              AppConfig.defaultApiPort,
      refreshLiveDataOnLaunch: json['refresh_live_on_launch'] as bool? ?? true,
      showCacheFirstThenRefresh:
          json['cache_first_then_refresh'] as bool? ?? true,
      autoRefreshEnabled: json['auto_refresh_enabled'] as bool? ?? true,
      autoRefreshInterval: AutoRefreshIntervalX.fromStorage(
        json['auto_refresh_interval']?.toString(),
      ),
      forceRefreshAi: json['force_refresh_ai'] as bool? ?? false,
      showDataSourceLabels: json['show_data_source_labels'] as bool? ?? true,
      lastDataSyncAt: DateTime.tryParse(
        json['last_data_sync_at']?.toString() ?? '',
      ),
      defaultMapExperience: mapExp,
      defaultHotspotSort: sortPref,
      minHotspotScore: (json['min_hotspot_score'] is num)
          ? (json['min_hotspot_score'] as num).toDouble()
          : 0.0,
      filterClassA: json['filter_class_a'] as bool? ?? true,
      filterClassB: json['filter_class_b'] as bool? ?? true,
      filterClassC: json['filter_class_c'] as bool? ?? true,
      intensityOverlayDefault:
          json['intensity_overlay_default'] as bool? ?? true,
      corridorLinesDefault: json['corridor_lines_default'] as bool? ?? false,
      legendDefault: json['legend_default'] as bool? ?? true,
      autoOpenMarkerDetail: json['auto_open_marker_detail'] as bool? ?? false,
      coordinateFormat: CoordinateDisplayFormatX.fromStorage(
        json['coordinate_format']?.toString(),
      ),
      showMapPreviewSourceInfo:
          json['show_map_preview_source'] as bool? ?? true,
      captainAtlasEnabled: json['captain_atlas_enabled'] as bool? ?? true,
      alwaysTryLiveAi: json['always_try_live_ai'] as bool? ?? false,
      useSafeFallbackSummary:
          json['use_safe_fallback_summary'] as bool? ?? true,
      showAiSourceBadge: json['show_ai_source_badge'] as bool? ?? true,
      compactView: json['compact_view'] as bool? ?? false,
      largeTouchTargets: json['large_touch_targets'] as bool? ?? false,
      reduceMotion: json['reduce_motion'] as bool? ?? false,
      glowIntensity: GlowIntensityLevelX.fromStorage(
        json['glow_intensity']?.toString(),
      ),
      cardDensity: CardDensityLevelX.fromStorage(
        json['card_density']?.toString(),
      ),
      showStatusChips: json['show_status_chips'] as bool? ?? true,
      showHelperTexts: json['show_helper_texts'] as bool? ?? true,
      lastSuccessfulConnection: lastConn,
      lastHealthCheckAt: DateTime.tryParse(
        json['last_health_check_at']?.toString() ?? '',
      ),
      lastHealthOk: json['last_health_ok'] as bool?,
      lastHealthLatencyMs: json['last_health_latency_ms'] is int
          ? json['last_health_latency_ms'] as int
          : int.tryParse(json['last_health_latency_ms']?.toString() ?? ''),
      lastHealthServiceVersion:
          json['last_health_service_version']?.toString(),
      lastHealthServiceName: json['last_health_service_name']?.toString(),
    );
  }
}
