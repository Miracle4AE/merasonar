import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../local_storage_service.dart';
import '../utils/android_backend_host_policy.dart';

/// Beklenen [GET /health] `service` alanı (tam eşleşme).
const String merasonarHealthServiceField = 'MeraSonar API';

/// Ham JSON gövdesi geçerli MeraSonar `/health` yanıtı mı kontrol eder.
bool validateHealthResponse(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map) return false;
    final m = Map<String, dynamic>.from(decoded);
    final status = m['status']?.toString();
    final service = m['service']?.toString();
    final version = m['version'];
    return status == 'ok' &&
        service == merasonarHealthServiceField &&
        version is String &&
        version.isNotEmpty;
  } catch (_) {
    return false;
  }
}

/// Keşif sonucu — kayıt gerekiyorsa [persistHost], alternatif varsa [alternateSuggestedHost].
@immutable
class MeraSonarDiscoverOutcome {
  const MeraSonarDiscoverOutcome({
    this.persistHost,
    this.alternateSuggestedHost,
  });

  final String? persistHost;
  final String? alternateSuggestedHost;
}

/// Kayıtlı adres, yaygın kısayollar ve LAN subnet taraması (paralel) ile `/health` arar.
///
/// Yerel güvenlik: fiziksel Android’de localhost taramayı [shouldBlockAndroidLoopbackHost] ile atlar.
class BackendDiscoveryService {
  BackendDiscoveryService({
    http.Client? httpClient,
    Duration? probeTimeout,
    Duration? overallBudget,
    bool? ownsClient,
    /// Test: emulatorde true — [AppConfig.defaultEmulatorLanHost] denenir.
    bool? androidEmulatorOverride,
    /// Test: masaüstü olarak 127.0.0.1 / localhost deneme.
    bool? flutterDesktopOverride,
    /// Test için subnet üçlüleri. Her eleman `['192','168','1']`.
    Future<List<List<String>>> Function()? subnetPrefixOverride,
  })  : _client = httpClient ?? http.Client(),
        _ownsClient = ownsClient ?? (httpClient == null),
        _probeTimeout = probeTimeout ?? const Duration(milliseconds: 950),
        _overallBudget = overallBudget ?? const Duration(seconds: 13),
        _androidEmuOverride = androidEmulatorOverride,
        _desktopOverride = flutterDesktopOverride,
        _subnetOverride = subnetPrefixOverride;

  final http.Client _client;
  final bool _ownsClient;
  final Duration _probeTimeout;
  final Duration _overallBudget;
  final bool? _androidEmuOverride;
  final bool? _desktopOverride;
  final Future<List<List<String>>> Function()? _subnetOverride;

  static const int _parallelProbes = 36;

  void close() {
    if (_ownsClient) _client.close();
  }

  /// Kayıtlı IP geçerli MeraSonar `/health` dönüyorsa adresi döndürür.
  Future<String?> checkSavedServer(
    LocalStorageService storage, {
    DateTime? deadline,
  }) async {
    final raw = await storage.loadServerIp();
    final host = raw?.trim();
    if (host == null || host.isEmpty) return null;
    final end =
        deadline ?? DateTime.now().add(_overallBudget);
    if (await _probeHealthyHost(host, deadline: end)) return host;
    return null;
  }

  Future<MeraSonarDiscoverOutcome> discoverBackend({
    required LocalStorageService storage,
    bool scanEvenIfSavedWorks = false,
    DateTime? deadline,
  }) async {
    final end = deadline ?? DateTime.now().add(_overallBudget);

    final savedTrim = (await storage.loadServerIp())?.trim();
    final savedHealthy = savedTrim != null &&
        savedTrim.isNotEmpty &&
        await _probeHealthyHost(savedTrim, deadline: end);

    if (!scanEvenIfSavedWorks) {
      if (savedHealthy) return const MeraSonarDiscoverOutcome();
      final found = await _discoverShortcutsThenSubnet(
        end: end,
        excludeHosts: const {},
      );
      if (found != null) {
        return MeraSonarDiscoverOutcome(persistHost: found.trim());
      }
      return const MeraSonarDiscoverOutcome();
    }

    if (savedHealthy) {
      final alt = await _discoverShortcutsThenSubnet(
        end: end,
        excludeHosts: {savedTrim},
      );
      if (alt != null &&
          alt.trim().isNotEmpty &&
          alt.trim() != savedTrim.trim()) {
        return MeraSonarDiscoverOutcome(alternateSuggestedHost: alt.trim());
      }
      return const MeraSonarDiscoverOutcome();
    }

    final found = await _discoverShortcutsThenSubnet(
      end: end,
      excludeHosts: const {},
    );
    if (found != null && found.trim().isNotEmpty) {
      return MeraSonarDiscoverOutcome(persistHost: found.trim());
    }
    return const MeraSonarDiscoverOutcome();
  }

  /// Yalnızca LAN IP’leri üzerinde paralel tarama (subnet keşfi ile aynı mantık).
  Future<String?> scanSubnet({
    DateTime? deadline,
    Set<String> excludeHosts = const {},
  }) async {
    final end = deadline ?? DateTime.now().add(_overallBudget);
    return _scanLanHosts(end: end, excludeHosts: excludeHosts);
  }

  Future<String?> _discoverShortcutsThenSubnet({
    required DateTime end,
    required Set<String> excludeHosts,
  }) async {
    final shortcuts = await orderedShortcutHosts();
    for (final h in shortcuts) {
      if (DateTime.now().isAfter(end)) break;
      final trimmed = h.trim();
      if (trimmed.isEmpty || excludeHosts.contains(trimmed)) continue;
      if (_isAndroidBlockedLoopbackProbe(trimmed)) continue;
      if (await _probeHealthyHost(trimmed, deadline: end)) {
        return trimmed;
      }
    }
    return _scanLanHosts(end: end, excludeHosts: excludeHosts);
  }

  /// Yerel NIC listesi boşsa (nadiren VPN/Windows), tipik ev/ofis /24 blokları yine taranır.
  static List<List<String>> fallbackLanSubnetPrefixes() => const [
        ['192', '168', '1'],
        ['192', '168', '0'],
        ['10', '0', '0'],
        ['172', '16', '0'],
      ];

  Future<String?> _scanLanHosts({
    required DateTime end,
    required Set<String> excludeHosts,
  }) async {
    if (kIsWeb) return null;
    final subnetFn = _subnetOverride;
    final rawPref = subnetFn != null
        ? await subnetFn()
        : await _gatherSubnetPrefixes();
    var normalized = rawPref.where((p) => p.length == 3).toList(growable: false);
    if (_subnetOverride == null && normalized.isEmpty) {
      normalized = fallbackLanSubnetPrefixes();
    }

    for (final parts in normalized) {
      final prefix = '${parts[0]}.${parts[1]}.${parts[2]}';
      var i = 1;
      while (i <= 254 && DateTime.now().isBefore(end)) {
        final batch = <Future<String?>>[];
        while (i <= 254 &&
            batch.length < _parallelProbes &&
            DateTime.now().isBefore(end)) {
          final ip = '$prefix.$i';
          i++;
          if (excludeHosts.contains(ip)) continue;
          batch.add(_probeReturning(ip, deadline: end));
        }
        if (batch.isEmpty) break;
        final merged = await Future.wait(batch);
        for (final h in merged) {
          if (h != null && h.isNotEmpty) return h.trim();
        }
      }
    }
    return null;
  }

  Future<String?> _probeReturning(String ip, {required DateTime deadline}) async {
    if (await _probeHealthyHost(ip, deadline: deadline)) return ip.trim();
    return null;
  }

  Future<List<List<String>>> _gatherSubnetPrefixes() async {
    final prefixes = <String>{};
    try {
      final ifaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final iface in ifaces) {
        for (final addr in iface.addresses) {
          final a = addr.address;
          if (_isBadSubnetSeed(a)) continue;
          final p = a.split('.');
          if (p.length == 4) {
            prefixes.add('${p[0]}.${p[1]}.${p[2]}');
          }
        }
      }
    } catch (_) {
      /* ağ arabirimi yok */
    }
    final out = <List<String>>[];
    for (final s in prefixes) {
      final parts = s.split('.');
      if (parts.length == 3) {
        out.add(parts);
      }
    }
    return out;
  }

  Future<bool> _probeHealthyHost(
    String host, {
    required DateTime deadline,
  }) async {
    if (host.trim().isEmpty) return false;
    if (_isAndroidBlockedLoopbackProbe(host)) return false;

    final left = deadline.difference(DateTime.now());
    final budget = left.isNegative
        ? Duration.zero
        : (left.inMilliseconds > _probeTimeout.inMilliseconds
            ? _probeTimeout
            : left);
    if (budget == Duration.zero) return false;

    final base = AppConfig.buildApiBaseUrl(host.trim());
    final uri = Uri.parse('${base.replaceFirst(RegExp(r'/$'), '')}/health');

    try {
      final resp = await _client.get(uri).timeout(budget);
      if (resp.statusCode < 200 || resp.statusCode >= 300) return false;
      return validateHealthResponse(resp.body);
    } catch (_) {
      return false;
    }
  }

  bool _isBadSubnetSeed(String ip) {
    if (ip.startsWith('127.') || ip == '::1') return true;
    if (ip.startsWith('169.254.')) return true;
    return false;
  }

  bool _isAndroidBlockedLoopbackProbe(String host) {
    if (!Platform.isAndroid) return false;
    if (_androidEmuOverride == true) return false;
    return shouldBlockAndroidLoopbackHost(host);
  }

  bool _isFlutterDesktop() {
    final desktop = _desktopOverride;
    if (desktop != null) return desktop;
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  Future<bool> _isLikelyAndroidEmulator() async {
    final emu = _androidEmuOverride;
    if (emu != null) return emu;
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final android = await DeviceInfoPlugin().androidInfo;
      return !android.isPhysicalDevice;
    } catch (_) {
      return false;
    }
  }

  /// Masaüstü: 127 + localhost. Android emülatör: 10.0.2.2 (fizikselde yok).
  @visibleForTesting
  Future<List<String>> orderedShortcutHosts() async {
    final out = <String>[];
    if (_isFlutterDesktop()) {
      out.add('127.0.0.1');
      out.add('localhost');
      if (!kIsWeb && Platform.isWindows) {
        out.add('host.docker.internal');
      }
    }
    if (!kIsWeb && Platform.isAndroid) {
      if (await _isLikelyAndroidEmulator()) {
        out.add(AppConfig.defaultEmulatorLanHost);
      }
    }
    return out;
  }
}

@visibleForTesting
List<String> orderedShortcutHostsForTest({
  required bool desktop,
  required bool androidEmulatorHost,
}) {
  final o = <String>[];
  if (desktop) {
    o.add('127.0.0.1');
    o.add('localhost');
  }
  if (androidEmulatorHost) o.add(AppConfig.defaultEmulatorLanHost);
  return o;
}
