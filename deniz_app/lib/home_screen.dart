import 'dart:async' show unawaited;
import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import 'api_service.dart';
import 'config/app_config.dart';
import 'dialogs/server_host_dialog.dart';
import 'l10n/app_strings_tr.dart';
import 'legal/in_app_privacy_notice.dart';
import 'live_area_screen.dart';
import 'local_storage_service.dart';
import 'map_screen.dart';
import 'navigation/captain_atlas_launcher.dart';
import 'navigation/premium_navigator.dart';
import 'screens/marine_intelligence_screen.dart';
import 'services/app_preferences.dart';
import 'services/backend_discovery_service.dart';
import 'utils/android_backend_host_policy.dart';
import 'utils/app_haptics.dart';
import 'layout/premium_app_shell.dart';
import 'screens/marine_compare_screen.dart';
import 'screens/premium_dashboard_screen.dart';
import 'services/dashboard_overview_service.dart';
import 'widgets/backend_connection_badge.dart';
import 'widgets/premium/feedback/premium_toast.dart';

/// RFC1918 yerel aÄŸ IPâ€™si mi (Snackbar metnini ayÄ±rmak iÃ§in).
bool _looksLikePrivateLanHostIpv4(String raw) {
  final parts = raw.trim().split('.');
  if (parts.length != 4) return false;
  final a = int.tryParse(parts[0]);
  final b = int.tryParse(parts[1]);
  if (a == null ||
      b == null ||
      a < 0 ||
      a > 255 ||
      b < 0 ||
      b > 255) {
    return false;
  }
  for (final p in parts.skip(2)) {
    final o = int.tryParse(p);
    if (o == null || o < 0 || o > 255) return false;
  }
  if (a == 192 && b == 168) return true;
  if (a == 10) return true;
  if (a == 172 && b >= 16 && b <= 31) return true;
  return false;
}

/// Ä°lk ana ekran: Live Area veya Photo Analysis â€” premium kart dÃ¼zeni.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final LocalStorageService _storage = LocalStorageService();
  String _serverIp = '127.0.0.1';
  bool _discoveryBusy = false;
  String? _discoveryHint;
  bool _healthChecking = false;
  bool? _healthOkLast;
  /// /health 200 ama MeraSonar gÃ¶vdesi deÄŸil â€” aynÄ± portta baÅŸka sÃ¼reÃ§ olabilir.
  bool _healthWrongServiceBody = false;
  bool _shownLocalServerNotRunningHint = false;
  bool _highlightPhotoGuide = false;
  String _selectedSectionId = 'overview';

  late final AnimationController _liveHaloCtrl;
  late final AnimationController _photoHaloCtrl;
  late final AnimationController _marineHaloCtrl;
  late final AnimationController _photoGuidePulse;

  static const Duration _preNavigationPulse = Duration(milliseconds: 175);

  Future<void> _pulseThenNavigate(VoidCallback pushRoute) async {
    await Future<void>.delayed(_preNavigationPulse);
    if (!mounted) return;
    pushRoute();
  }

  Future<void> _onLiveTap() async {
    AppHaptics.lightTap();
    if (Platform.isAndroid && shouldBlockAndroidLoopbackHost(_serverIp)) {
      AppHaptics.warning();
      if (!mounted) return;
      context.showPremiumToast(
        androidLoopbackHostBlockedExplanation(),
        type: PremiumToastType.info,
        duration: const Duration(seconds: 7),
      );
      return;
    }
    _fireTapHalo(_liveHaloCtrl);
    await _pulseThenNavigate(() {
      PremiumNavigator.push<void>(
        context,
        LiveAreaScreen(serverIp: _serverIp),
      );
    });
  }

  Future<void> _onMarineTap() async {
    AppHaptics.lightTap();
    _fireTapHalo(_marineHaloCtrl);
    await _pulseThenNavigate(() {
      PremiumNavigator.push<void>(
        context,
        MarineIntelligenceScreen(serverIp: _serverIp),
      );
    });
  }

  Future<void> _onCompareTap() async {
    AppHaptics.lightTap();
    await _pulseThenNavigate(() {
      PremiumNavigator.push<void>(
        context,
        MarineCompareScreen(serverIp: _serverIp),
      );
    });
  }

  void _onCaptainAtlasTap() {
    AppHaptics.lightTap();
    unawaited(
      CaptainAtlasLauncher.openCommandCenter(context, _serverIp),
    );
  }

  void _onSidebarSection(String sectionId) {
    if (sectionId == 'overview') {
      setState(() => _selectedSectionId = sectionId);
      return;
    }
    switch (sectionId) {
      case 'live':
        unawaited(_onLiveTap());
      case 'marine':
      case 'spots':
      case 'catches':
      case 'timeline':
        unawaited(_onMarineTap());
      case 'map':
        unawaited(_onPhotoTap());
      case 'compare':
        unawaited(_onCompareTap());
      case 'settings':
        unawaited(_openServerSettings());
    }
  }

  String? get _offlineBannerMessage {
    if (_healthWrongServiceBody && !_discoveryBusy && !_healthChecking) {
      return kHealthPortWrongServiceHint;
    }
    if (_healthOkLast == false && !_discoveryBusy && !_healthChecking) {
      return kOfflineStateReassurance;
    }
    return null;
  }

  Future<void> _onPhotoTap() async {
    AppHaptics.lightTap();
    if (_highlightPhotoGuide) {
      unawaited(AppPreferences.setPhotoGuideHighlightPending(false));
      _photoGuidePulse.stop();
      if (mounted) {
        setState(() => _highlightPhotoGuide = false);
      }
    }
    _fireTapHalo(_photoHaloCtrl);
    await _pulseThenNavigate(() {
      PremiumNavigator.push<void>(
        context,
        MapScreen(serverIp: _serverIp),
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _liveHaloCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) _liveHaloCtrl.reset();
      });
    _photoHaloCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) _photoHaloCtrl.reset();
      });
    _marineHaloCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) _marineHaloCtrl.reset();
      });

    _photoGuidePulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrapNetworking());
      unawaited(_restorePhotoGuideFromPrefs());
    });
  }

  Future<void> _bootstrapNetworking() async {
    await _loadServerIp();
    if (!mounted) return;
    await _runStartupDiscovery();
    if (!mounted) return;
    await _maybePromptServerWizard();
  }

  Future<void> _restorePhotoGuideFromPrefs() async {
    final want = await AppPreferences.isPhotoGuideHighlightPending();
    if (!mounted) return;
    if (!want) return;
    setState(() => _highlightPhotoGuide = true);
    _photoGuidePulse.repeat(reverse: true);
  }

  Future<void> _maybePromptServerWizard() async {
    if (_healthOkLast == true) {
      await AppPreferences.clearDeferredWizardWhenConnected();
      return;
    }
    final deferred = await AppPreferences.isServerWizardDeferredByUser();
    if (deferred || !mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (!mounted) return;
    if (_healthOkLast == true) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF142434),
        title: Text(
          kServerWizardTitle,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.96),
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          kServerWizardBody,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.76),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await AppPreferences.setServerWizardDeferredByUser(true);
            },
            child: const Text(kServerWizardLater),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              unawaited(_runManualBackendDiscovery());
            },
            icon: const Icon(Icons.travel_explore_rounded, size: 18),
            label: const Text(kServerWizardBtnAuto),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              unawaited(_openServerSettings());
            },
            icon: const Icon(Icons.dns_rounded, size: 18),
            label: const Text(kServerWizardBtnIp),
          ),
        ],
      ),
    );
    if (!mounted) return;
  }

  Future<void> _applyFirstHealthyConnectionRewards() async {
    await AppPreferences.clearDeferredWizardWhenConnected();
    if (!mounted) return;
    final celebrated = await AppPreferences.hasCelebratedFirstConnection();
    if (!mounted) return;
    if (celebrated) {
      final wantHighlight = await AppPreferences.isPhotoGuideHighlightPending();
      if (!mounted) return;
      if (wantHighlight && !_highlightPhotoGuide) {
        setState(() => _highlightPhotoGuide = true);
        _photoGuidePulse.repeat(reverse: true);
      }
      return;
    }
    await AppPreferences.markFirstConnectionCelebrated();
    if (!mounted) return;
    await AppPreferences.setPhotoGuideHighlightPending(true);
    if (!mounted) return;
    setState(() => _highlightPhotoGuide = true);
    _photoGuidePulse.repeat(reverse: true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(kFirstConnectionOk),
        duration: const Duration(seconds: 3),
        backgroundColor: const Color(0xFF1E5631),
      ),
    );
  }

  Future<void> _runStartupDiscovery() async {
    if (!mounted) return;
    setState(() {
      _discoveryBusy = true;
      _discoveryHint = kDiscoverSearching;
    });
    final svc = BackendDiscoveryService();
    try {
      var outcome = await svc.discoverBackend(
        storage: _storage,
        scanEvenIfSavedWorks: false,
      );
      if (!mounted) return;
      if (outcome.persistHost == null) {
        await Future<void>.delayed(const Duration(seconds: 3));
        if (!mounted) return;
        outcome = await svc.discoverBackend(
          storage: _storage,
          scanEvenIfSavedWorks: false,
        );
      }
      if (!mounted) return;
      final persist = outcome.persistHost;
      if (persist != null && persist.trim().isNotEmpty) {
        await _storage.saveServerIp(persist.trim());
        setState(() {
          _serverIp = persist.trim();
          _discoveryHint = discoverFoundLine(
            persist.trim(),
            AppConfig.defaultApiPort,
          );
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              discoverFoundLine(persist.trim(), AppConfig.defaultApiPort),
            ),
          ),
        );
      } else if (mounted) {
        setState(() => _discoveryHint = null);
      }
    } catch (e, st) {
      debugPrint('_runStartupDiscovery: $e\n$st');
      if (!mounted) return;
      setState(() => _discoveryHint = null);
    } finally {
      svc.close();
      if (mounted) {
        setState(() => _discoveryBusy = false);
      }
    }
    if (!mounted) return;
    Future<void>.delayed(const Duration(seconds: 6), () {
      if (mounted) {
        setState(() => _discoveryHint = null);
      }
    });
    await _refreshConnectionHealth();
  }

  Future<void> _refreshConnectionHealth() async {
    if (!mounted) return;
    if (Platform.isAndroid && shouldBlockAndroidLoopbackHost(_serverIp.trim())) {
      setState(() {
        _healthOkLast = null;
        _healthWrongServiceBody = false;
      });
      return;
    }
    final previous = _healthOkLast;
    setState(() => _healthChecking = true);
    try {
      final api = ApiService(
        serverBaseUrl: AppConfig.buildApiBaseUrl(_serverIp.trim()),
      );
      final r = await api.checkHealth();
      if (!mounted) return;
      final okNow = r.ok;
      setState(() {
        _healthOkLast = okNow;
        _healthWrongServiceBody =
            !okNow && r.receivedNonMerasonarResponse;
      });
      final normalizedHost = AppConfig.normalizeHost(_serverIp);
      final isLoopback =
          normalizedHost == '127.0.0.1' ||
          normalizedHost == 'localhost' ||
          normalizedHost == '::1';
      if (!okNow &&
          !_healthWrongServiceBody &&
          !_shownLocalServerNotRunningHint &&
          Platform.isWindows &&
          isLoopback) {
        _shownLocalServerNotRunningHint = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(kServerNotRunningLocalHint)),
        );
      }
      if (previous != true && okNow) {
        unawaited(_applyFirstHealthyConnectionRewards());
      }
    } catch (e, st) {
      debugPrint('_refreshConnectionHealth: $e\n$st');
      if (!mounted) return;
      setState(() {
        _healthOkLast = false;
        _healthWrongServiceBody = false;
      });
    } finally {
      if (mounted) {
        setState(() => _healthChecking = false);
      }
    }
  }

  Future<void> _openServerSettings() async {
    final badge = resolveBackendConnectionBadge(
      serverIp: _serverIp,
      discoveryBusy: _discoveryBusy,
      serverHealthChecking: _healthChecking,
      manualIpRequiredAndroid:
          Platform.isAndroid && shouldBlockAndroidLoopbackHost(_serverIp.trim()),
      healthOkLast: _healthOkLast,
    );
    final result = await showMerasonarServerHostDialog(
      context,
      initialHost: _serverIp,
      badgeSnapshot: badge,
      autoDiscoverBusy: _discoveryBusy,
      onRequestAutoDiscover: () async {
        await _runManualBackendDiscovery();
      },
    );
    if (!mounted) return;
    if (result == null) {
      await _refreshConnectionHealth();
      return;
    }
    final trimmed = result.trim();
    if (trimmed.isEmpty) {
      await _refreshConnectionHealth();
      return;
    }
    await _storage.saveServerIp(trimmed);
    setState(() => _serverIp = trimmed);
    await _refreshConnectionHealth();
    if (!mounted) return;
    if (_healthOkLast != true &&
        !(Platform.isAndroid &&
            shouldBlockAndroidLoopbackHost(trimmed))) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 9),
          content: Text(
            _looksLikePrivateLanHostIpv4(trimmed)
                ? kServerHealthFailedLanShapeHint
                : kWrongIpFriendlyHint,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.94),
              height: 1.38,
            ),
          ),
          backgroundColor: const Color(0xFF37474F),
        ),
      );
    }
  }

  Future<void> _runManualBackendDiscovery() async {
    if (_discoveryBusy) return;
    setState(() {
      _discoveryBusy = true;
      _discoveryHint = kDiscoverSearching;
    });
    final svc = BackendDiscoveryService();
    try {
      final outcome = await svc.discoverBackend(
        storage: _storage,
        scanEvenIfSavedWorks: true,
      );
      if (!mounted) return;
      final alternate = outcome.alternateSuggestedHost;
      final persist = outcome.persistHost;

      if (persist != null && persist.trim().isNotEmpty) {
        await _storage.saveServerIp(persist.trim());
        if (!mounted) return;
        setState(() => _serverIp = persist.trim());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              discoverFoundLine(persist.trim(), AppConfig.defaultApiPort),
            ),
          ),
        );
        await _refreshConnectionHealth();
        return;
      }

      if (alternate != null && alternate.trim().isNotEmpty) {
        final altTrim = alternate.trim();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 10),
            content: Text(
              '$kDiscoverAlternateSnack\n'
              '${alternateServerHint(_serverIp, altTrim)}',
            ),
            action: SnackBarAction(
              label: kDiscoverUseAlternate,
              onPressed: () async {
                await _storage.saveServerIp(altTrim);
                if (!mounted) return;
                setState(() => _serverIp = altTrim);
              },
            ),
          ),
        );
        await _refreshConnectionHealth();
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(kDiscoverNotFound)),
      );
    } catch (e, st) {
      debugPrint('_runManualBackendDiscovery: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(kDiscoverNotFound)),
      );
    } finally {
      svc.close();
      if (mounted) {
        setState(() {
          _discoveryBusy = false;
          _discoveryHint = null;
        });
      }
    }
    if (!mounted) return;
    await _refreshConnectionHealth();
  }

  @override
  void dispose() {
    _liveHaloCtrl.dispose();
    _photoHaloCtrl.dispose();
    _marineHaloCtrl.dispose();
    _photoGuidePulse.dispose();
    super.dispose();
  }

  void _showPrivacyDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(InAppPrivacyNotice.dialogTitle),
        content: SingleChildScrollView(
          child: Text(
            InAppPrivacyNotice.bodyTextBlock(),
            style: const TextStyle(height: 1.38),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(kDialogClose),
          ),
        ],
      ),
    );
  }

  Future<void> _loadServerIp() async {
    final saved = await _storage.loadServerIp();
    if (!mounted) return;
    final t = saved == null ? null : AppConfig.normalizeHost(saved);
    if (t != null && t.isNotEmpty) {
      setState(() => _serverIp = t);
    }
  }

  void _fireTapHalo(AnimationController c) {
    c.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return PremiumAppShell(
      selectedSectionId: _selectedSectionId,
      onSectionSelected: _onSidebarSection,
      serverIp: _serverIp,
      suppressTopHeader: true,
      hideEnvironmentChips: true,
      healthChecking: _healthChecking,
      onConnectionTap: _openServerSettings,
      onSettingsTap: _openServerSettings,
      onPrivacyTap: _showPrivacyDialog,
      connectionBadge: resolveBackendConnectionBadge(
        serverIp: _serverIp,
        discoveryBusy: _discoveryBusy,
        serverHealthChecking: _healthChecking,
        manualIpRequiredAndroid:
            Platform.isAndroid && shouldBlockAndroidLoopbackHost(_serverIp.trim()),
        healthOkLast: _healthOkLast,
      ),
      child: PremiumDashboardScreen(
        serverIp: _serverIp,
        onLiveTap: _onLiveTap,
        onPhotoTap: _onPhotoTap,
        onMarineTap: _onMarineTap,
        onCompareTap: _onCompareTap,
        onCaptainAtlasTap: _onCaptainAtlasTap,
        discoveryHint: _discoveryHint,
        discoveryBusy: _discoveryBusy,
        offlineMessage: _offlineBannerMessage,
        connectionBadge: resolveBackendConnectionBadge(
          serverIp: _serverIp,
          discoveryBusy: _discoveryBusy,
          serverHealthChecking: _healthChecking,
          manualIpRequiredAndroid:
              Platform.isAndroid && shouldBlockAndroidLoopbackHost(_serverIp.trim()),
          healthOkLast: _healthOkLast,
        ),
        onConnectionTap: _openServerSettings,
        onSettingsTap: _openServerSettings,
        onPrivacyTap: _showPrivacyDialog,
        connectionStatus: DashboardOverviewService.mapHealthStatus(
          healthOk: _healthOkLast,
          healthChecking: _healthChecking || _discoveryBusy,
        ),
      ),
    );
  }
}
