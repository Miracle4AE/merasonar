import 'package:deniz_app/config/app_config.dart';
import 'package:deniz_app/domain/app_settings.dart';
import 'package:deniz_app/local_storage_service.dart';
import 'package:deniz_app/services/ai_assistant_cache.dart';
import 'package:deniz_app/services/app_settings_service.dart';
import 'package:deniz_app/services/marine_intelligence_cache.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Uygulama ayarları — ChangeNotifier + kalıcılık.
class AppSettingsController extends ChangeNotifier {
  AppSettingsController({
    AppSettingsService? service,
    LocalStorageService? storage,
  })  : _service = service ?? AppSettingsService(),
        _storage = storage ?? LocalStorageService();

  final AppSettingsService _service;
  final LocalStorageService _storage;

  AppSettings _settings = AppSettings.defaults;
  bool _loaded = false;

  AppSettings get settings => _settings;
  bool get isLoaded => _loaded;

  int get serverPort => _settings.serverPort;

  Future<void> load() async {
    _settings = await _service.load();
    final storedPort = await _storage.loadServerPort();
    if (storedPort != null && storedPort != _settings.serverPort) {
      _settings = _settings.copyWith(serverPort: storedPort);
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> update(AppSettings next) async {
    _settings = next;
    await _service.save(_settings);
    await _storage.saveServerPort(_settings.serverPort);
    notifyListeners();
  }

  Future<void> patch(AppSettings Function(AppSettings current) transform) async {
    await update(transform(_settings));
  }

  Future<void> recordDataSync({DateTime? at}) async {
    await patch(
      (s) => s.copyWith(lastDataSyncAt: at ?? DateTime.now()),
    );
  }

  Future<void> recordHealthSnapshot({
    required bool ok,
    required int latencyMs,
    String? serviceVersion,
    String? serviceName,
    LastSuccessfulConnection? onSuccess,
  }) async {
    await patch(
      (s) => s.copyWith(
        lastHealthCheckAt: DateTime.now(),
        lastHealthOk: ok,
        lastHealthLatencyMs: latencyMs,
        lastHealthServiceVersion: serviceVersion,
        lastHealthServiceName: serviceName,
        lastSuccessfulConnection: onSuccess ?? s.lastSuccessfulConnection,
      ),
    );
  }

  Future<void> resetAllSettings() async {
    await _service.resetAll();
    _settings = AppSettings.defaults;
    await _storage.saveServerPort(AppConfig.defaultApiPort);
    notifyListeners();
  }

  static String buildBaseUrl(String host, AppSettings settings) {
    return AppConfig.buildApiBaseUrl(host, port: settings.serverPort);
  }
}

/// InheritedWidget — ayarlara erişim.
class AppSettingsScope extends InheritedNotifier<AppSettingsController> {
  const AppSettingsScope({
    super.key,
    required AppSettingsController controller,
    required super.child,
  }) : super(notifier: controller);

  /// Widget testlerinde scope olmadan pump edilen ekranlar için güvenli varsayılan.
  static AppSettingsController ambientFallback = AppSettingsController();

  @visibleForTesting
  static void resetAmbientFallbackForTests() {
    ambientFallback = AppSettingsController();
  }

  static AppSettingsController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppSettingsScope>();
    if (scope?.notifier != null) return scope!.notifier!;
    return ambientFallback;
  }

  static AppSettingsController? maybeOf(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppSettingsScope>();
    return scope?.notifier ?? ambientFallback;
  }

  static AppSettings read(BuildContext context) {
    return of(context).settings;
  }
}

/// Yerel veri/cache temizliği.
class SettingsCacheMaintenance {
  SettingsCacheMaintenance({
    MarineIntelligenceCache? marineCache,
  }) : _marineCache = marineCache ?? MarineIntelligenceCache();

  final MarineIntelligenceCache _marineCache;

  Future<void> clearDataCaches() async {
    await _marineCache.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('latest_fishing_zone_response');
    await prefs.remove('latest_fishing_zone_chart_image_path');
    await prefs.remove('analysis_history');
  }

  Future<void> clearAllLocalStorage() async {
    await clearDataCaches();
    await _marineCache.clear();
    AiAssistantCache.clearAllSessions();
  }
}
