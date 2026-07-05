import 'dart:async' show unawaited;

import 'package:deniz_app/api_service.dart';
import 'package:deniz_app/config/app_config.dart';
import 'package:deniz_app/domain/app_settings.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/services/ai_assistant_cache.dart';
import 'package:deniz_app/services/app_settings_controller.dart';
import 'package:deniz_app/services/backend_discovery_service.dart';
import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/utils/android_backend_host_policy.dart';
import 'package:deniz_app/utils/layout_breakpoints.dart';
import 'package:deniz_app/utils/server_host_hints.dart';
import 'package:deniz_app/widgets/backend_connection_badge.dart';
import 'package:deniz_app/widgets/premium/premium_performance_scope.dart';
import 'package:deniz_app/widgets/premium/settings/premium_performance_mode_tile.dart';
import 'package:deniz_app/widgets/premium/settings/settings_ui_widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum SettingsSection {
  connection,
  dataSync,
  mapAnalysis,
  captainAtlas,
  appearance,
  maintenance,
}

extension SettingsSectionX on SettingsSection {
  String get title => switch (this) {
        SettingsSection.connection => 'Bağlantı',
        SettingsSection.dataSync => 'Veri ve Senkronizasyon',
        SettingsSection.mapAnalysis => 'Harita ve Analiz',
        SettingsSection.captainAtlas => 'Captain Atlas',
        SettingsSection.appearance => 'Görünüm ve Deneyim',
        SettingsSection.maintenance => 'Gelişmiş / Bakım',
      };

  IconData get icon => switch (this) {
        SettingsSection.connection => Icons.link_rounded,
        SettingsSection.dataSync => Icons.sync_rounded,
        SettingsSection.mapAnalysis => Icons.map_rounded,
        SettingsSection.captainAtlas => Icons.psychology_alt_outlined,
        SettingsSection.appearance => Icons.palette_outlined,
        SettingsSection.maintenance => Icons.build_circle_outlined,
      };
}

enum ConnectionTestState {
  notTested,
  testing,
  connected,
  unreachable,
}

/// Premium ayarlar — kategorili tam ekran / geniş dialog.
class PremiumSettingsScreen extends StatefulWidget {
  const PremiumSettingsScreen({
    super.key,
    required this.serverHost,
    required this.onSaveConnection,
    required this.onAutoDiscover,
    this.discoveryBusy = false,
    this.badgeSnapshot,
  });

  final String serverHost;
  final Future<void> Function(String host, int port) onSaveConnection;
  final Future<void> Function() onAutoDiscover;
  final bool discoveryBusy;
  final BackendConnectionBadgeData? badgeSnapshot;

  @override
  State<PremiumSettingsScreen> createState() => _PremiumSettingsScreenState();
}

class _PremiumSettingsScreenState extends State<PremiumSettingsScreen> {
  AppSettings _draft = AppSettings.defaults;
  late TextEditingController _hostController;
  late TextEditingController _portController;
  SettingsSection _section = SettingsSection.connection;
  ConnectionTestState _testState = ConnectionTestState.notTested;
  String? _testError;
  HealthCheckResult? _lastTestResult;
  bool _saving = false;
  bool _draftLoaded = false;

  AppSettingsController get _controller => AppSettingsScope.of(context);

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController(text: widget.serverHost.trim());
    _portController = TextEditingController(
      text: AppConfig.defaultApiPort.toString(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_draftLoaded) return;
    _draft = _controller.settings;
    _portController.text = _draft.serverPort.toString();
    _hydrateTestStateFromSettings();
    _draftLoaded = true;
  }

  void _hydrateTestStateFromSettings() {
    if (_draft.lastHealthOk == true) {
      _testState = ConnectionTestState.connected;
    } else if (_draft.lastHealthOk == false) {
      _testState = ConnectionTestState.unreachable;
    }
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  int get _parsedPort {
    return AppConfig.normalizePort(int.tryParse(_portController.text.trim()));
  }

  String get _normalizedHost => AppConfig.normalizeHost(_hostController.text);

  Future<void> _applyDraft(AppSettings next) async {
    setState(() => _draft = next);
    await _controller.update(next);
  }

  Future<void> _saveAndClose() async {
    final host = _normalizedHost;
    if (host.isEmpty) return;
    if (shouldBlockAndroidLoopbackHost(host)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(androidLoopbackHostBlockedExplanation())),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final port = _parsedPort;
      await _applyDraft(_draft.copyWith(serverPort: port));
      await widget.onSaveConnection(host, port);
      if (!mounted) return;
      Navigator.pop(context, host);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _resetConnectionDefaults() async {
    _hostController.text = '127.0.0.1';
    _portController.text = AppConfig.defaultApiPort.toString();
    await _applyDraft(
      _draft.copyWith(serverPort: AppConfig.defaultApiPort),
    );
    setState(() {
      _testState = ConnectionTestState.notTested;
      _testError = null;
      _lastTestResult = null;
    });
  }

  Future<void> _testConnection() async {
    final host = _normalizedHost;
    if (host.isEmpty) return;
    setState(() {
      _testState = ConnectionTestState.testing;
      _testError = null;
    });
    final api = ApiService(
      serverBaseUrl: AppConfig.buildApiBaseUrl(host, port: _parsedPort),
    );
    final result = await api.checkHealth();
    if (!mounted) return;
    setState(() {
      _lastTestResult = result;
      _testState =
          result.ok ? ConnectionTestState.connected : ConnectionTestState.unreachable;
      _testError = result.ok ? null : result.message;
    });
    await _controller.recordHealthSnapshot(
      ok: result.ok,
      latencyMs: result.latencyMs ?? 0,
      serviceVersion: result.serviceVersion,
      serviceName: result.serviceName,
      onSuccess: result.ok
          ? LastSuccessfulConnection(
              host: host,
              port: _parsedPort,
              checkedAt: DateTime.now(),
              serviceVersion: result.serviceVersion,
              serviceName: result.serviceName,
              latencyMs: result.latencyMs,
            )
          : null,
    );
    if (mounted) {
      setState(() => _draft = _controller.settings);
    }
  }

  Future<void> _resetAllSettings() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tüm ayarları sıfırla'),
        content: const Text(
          'Bağlantı dışındaki tüm tercihler varsayılana döner. Sunucu IP ayrı kayıtlı kalır.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sıfırla'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _controller.resetAllSettings();
    setState(() {
      _draft = _controller.settings;
      _portController.text = _draft.serverPort.toString();
    });
  }

  Future<void> _clearDataCache() async {
    await SettingsCacheMaintenance().clearDataCaches();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Yerel veri önbelleği temizlendi.')),
    );
  }

  Future<void> _clearAllStorage() async {
    await SettingsCacheMaintenance().clearAllLocalStorage();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Yerel depolama temizlendi.')),
    );
  }

  Future<void> _clearCaptainAtlasCache() async {
    AiAssistantCache.clearAllSessions();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Captain Atlas oturum önbelleği temizlendi.')),
    );
  }

  Future<void> _copyDiagnostics() async {
    final s = _draft;
    final host = _normalizedHost.isEmpty ? widget.serverHost : _normalizedHost;
    final buffer = StringBuffer()
      ..writeln('MeraSonar Tanılama')
      ..writeln('app_version: ${AppConfig.appVersion}')
      ..writeln('build: ${AppConfig.buildNumber}')
      ..writeln('server: $host:${s.serverPort}')
      ..writeln('health_ok: ${s.lastHealthOk}')
      ..writeln('health_latency_ms: ${s.lastHealthLatencyMs}')
      ..writeln('service_version: ${s.lastHealthServiceVersion ?? '-'}')
      ..writeln('service_name: ${s.lastHealthServiceName ?? merasonarHealthServiceField}')
      ..writeln('last_sync: ${s.lastDataSyncAt?.toIso8601String() ?? '-'}')
      ..writeln('captain_atlas_enabled: ${s.captainAtlasEnabled}')
      ..writeln('performance_mode: ${PremiumPerformanceScope.of(context).name}');
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tanılama bilgisi panoya kopyalandı.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      appBar: AppBar(
        title: const Text('Ayarlar'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _resetConnectionDefaults,
            child: const Text('Varsayılana dön'),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilledButton(
            onPressed: _saving ? null : _saveAndClose,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Kaydet'),
          ),
          const SizedBox(width: AppSpacing.md),
        ],
      ),
      body: wide ? _buildWideLayout() : _buildNarrowLayout(),
    );
  }

  Widget _buildNarrowLayout() {
    return Column(
      children: [
        _sectionTabs(compact: true),
        Expanded(child: _sectionBody()),
      ],
    );
  }

  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: 240, child: _sectionNav(compact: false)),
        const VerticalDivider(width: 1),
        Expanded(child: _sectionBody()),
      ],
    );
  }

  Widget _sectionTabs({required bool compact}) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: SettingsSection.values.map((s) {
          final selected = _section == s;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: FilterChip(
              key: Key('settings_tab_${s.name}'),
              selected: selected,
              avatar: Icon(s.icon, size: 18),
              label: Text(s.title),
              onSelected: (_) => setState(() => _section = s),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _sectionNav({required bool compact}) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: SettingsSection.values.map((s) {
        final selected = _section == s;
        return ListTile(
          key: Key('settings_nav_${s.name}'),
          leading: Icon(s.icon, color: selected ? AppColors.accentTeal : null),
          title: Text(s.title),
          selected: selected,
          onTap: () => setState(() => _section = s),
        );
      }).toList(),
    );
  }

  Widget _sectionBody() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(
        useMobileLayout(context) ? AppSpacing.md : AppSpacing.xl,
      ),
      child: switch (_section) {
        SettingsSection.connection => _connectionSection(),
        SettingsSection.dataSync => _dataSyncSection(),
        SettingsSection.mapAnalysis => _mapSection(),
        SettingsSection.captainAtlas => _captainAtlasSection(),
        SettingsSection.appearance => _appearanceSection(),
        SettingsSection.maintenance => _maintenanceSection(),
      },
    );
  }

  Widget _connectionSection() {
    final badge = widget.badgeSnapshot;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSectionCard(
          title: 'Bağlantı durumu',
          subtitle: 'Anlık sunucu erişimi ve sağlık bilgisi',
          children: [
            if (badge != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: BackendConnectionBadge(data: badge, tooltip: ''),
              ),
            _connectionStatusBadge(),
            const SizedBox(height: AppSpacing.md),
            if (_draft.lastSuccessfulConnection != null) ...[
              SettingsInfoRow(
                label: 'Son başarılı bağlantı',
                value:
                    '${_draft.lastSuccessfulConnection!.host}:${_draft.lastSuccessfulConnection!.port}',
              ),
              if (_draft.lastSuccessfulConnection!.serviceVersion != null)
                SettingsInfoRow(
                  label: 'Servis sürümü',
                  value: _draft.lastSuccessfulConnection!.serviceVersion!,
                ),
            ],
            if (_draft.lastHealthLatencyMs != null)
              SettingsInfoRow(
                label: 'Son gecikme',
                value: '${_draft.lastHealthLatencyMs} ms',
              ),
          ],
        ),
        SettingsSectionCard(
          title: 'Sunucu yapılandırması',
          subtitle: 'MeraSonar API adresi',
          children: [
            TextField(
              controller: _hostController,
              decoration: const InputDecoration(
                labelText: 'Sunucu adresi',
                hintText: 'Örn: 192.168.1.20',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _portController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Port',
                hintText: AppConfig.defaultApiPort.toString(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (localhostWarningForMobile(_hostController.text) != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                localhostWarningForMobile(_hostController.text)!,
                style: TextStyle(color: Colors.orange.shade300, fontSize: 12),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                OutlinedButton.icon(
                  onPressed: widget.discoveryBusy
                      ? null
                      : () => unawaited(widget.onAutoDiscover()),
                  icon: widget.discoveryBusy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.travel_explore_rounded),
                  label: Text(kDiscoverManualButton),
                ),
                FilledButton.icon(
                  onPressed: _testState == ConnectionTestState.testing
                      ? null
                      : () => unawaited(_testConnection()),
                  icon: const Icon(Icons.network_check_rounded),
                  label: const Text('Bağlantıyı test et'),
                ),
              ],
            ),
            if (_testError != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(_testError!, style: TextStyle(color: Colors.red.shade300)),
            ],
            if (_lastTestResult?.ok == true &&
                _lastTestResult?.serviceVersion != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'API ${_lastTestResult!.serviceVersion} • ${_lastTestResult!.latencyMs ?? '-'} ms',
                style: AppTextStyles.caption,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _connectionStatusBadge() {
    final (label, color) = switch (_testState) {
      ConnectionTestState.connected => ('Bağlı', AppColors.accentTeal),
      ConnectionTestState.testing => ('Bağlanıyor…', AppColors.accentAmber),
      ConnectionTestState.unreachable => ('Ulaşılamıyor', Colors.redAccent),
      ConnectionTestState.notTested => ('Test edilmedi', Colors.grey),
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        key: const Key('settings_connection_status_badge'),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _dataSyncSection() {
    return SettingsSectionCard(
      title: 'Veri ve senkronizasyon',
      subtitle: 'Dashboard yenileme ve önbellek davranışı',
      children: [
        SettingsSwitchTile(
          title: 'Açılışta canlı veri yenile',
          subtitle: 'Dashboard açıldığında arka planda timeline güncellenir',
          value: _draft.refreshLiveDataOnLaunch,
          onChanged: (v) => unawaited(
            _applyDraft(_draft.copyWith(refreshLiveDataOnLaunch: v)),
          ),
        ),
        SettingsSwitchTile(
          title: 'Önce önbellek göster',
          subtitle: 'Kayıtlı veriyi hemen göster, sonra arka planda yenile',
          value: _draft.showCacheFirstThenRefresh,
          onChanged: (v) => unawaited(
            _applyDraft(_draft.copyWith(showCacheFirstThenRefresh: v)),
          ),
        ),
        SettingsSwitchTile(
          title: 'Otomatik yenileme',
          value: _draft.autoRefreshEnabled,
          onChanged: (v) => unawaited(
            _applyDraft(_draft.copyWith(autoRefreshEnabled: v)),
          ),
        ),
        SettingsSegmentedControl<AutoRefreshInterval>(
          label: 'Otomatik yenileme aralığı',
          options: AutoRefreshInterval.values,
          selected: _draft.autoRefreshInterval,
          labelBuilder: (v) => switch (v) {
            AutoRefreshInterval.oneMinute => '1 dk',
            AutoRefreshInterval.fiveMinutes => '5 dk',
            AutoRefreshInterval.fifteenMinutes => '15 dk',
            AutoRefreshInterval.thirtyMinutes => '30 dk',
          },
          onSelected: (v) => unawaited(
            _applyDraft(_draft.copyWith(autoRefreshInterval: v)),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SettingsSwitchTile(
          title: 'AI için force refresh',
          subtitle: 'Captain Atlas çağrılarında önbelleği atla',
          value: _draft.forceRefreshAi,
          onChanged: (v) => unawaited(
            _applyDraft(_draft.copyWith(forceRefreshAi: v)),
          ),
        ),
        SettingsSwitchTile(
          title: 'Veri kaynağı etiketleri',
          subtitle: 'Dashboard kartlarında kaynak chip\'lerini göster',
          value: _draft.showDataSourceLabels,
          onChanged: (v) => unawaited(
            _applyDraft(_draft.copyWith(showDataSourceLabels: v)),
          ),
        ),
        SettingsInfoRow(
          label: 'Son senkron',
          value: _draft.lastDataSyncAt != null
              ? _draft.lastDataSyncAt!.toLocal().toString().substring(0, 19)
              : 'Henüz yok',
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: () => unawaited(_clearDataCache()),
          icon: const Icon(Icons.cleaning_services_outlined),
          label: const Text('Yerel cache\'i temizle'),
        ),
      ],
    );
  }

  Widget _mapSection() {
    return SettingsSectionCard(
      title: 'Harita ve analiz',
      subtitle: 'Harita ekranı varsayılan filtreleri',
      children: [
        SettingsSegmentedControl<DefaultMapExperience>(
          label: 'Varsayılan harita modu',
          options: DefaultMapExperience.values,
          selected: _draft.defaultMapExperience,
          labelBuilder: (v) => switch (v) {
            DefaultMapExperience.map => 'Harita',
            DefaultMapExperience.photoAnalysis => 'Fotoğraf analizi',
          },
          onSelected: (v) => unawaited(
            _applyDraft(_draft.copyWith(defaultMapExperience: v)),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SettingsSegmentedControl<HotspotSortPreference>(
          label: 'Hotspot sıralama',
          options: HotspotSortPreference.values,
          selected: _draft.defaultHotspotSort,
          labelBuilder: (v) => switch (v) {
            HotspotSortPreference.score => 'Skor',
            HotspotSortPreference.proximity => 'Yakınlık',
          },
          onSelected: (v) => unawaited(
            _applyDraft(_draft.copyWith(defaultHotspotSort: v)),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Minimum hotspot skoru: ${_draft.minHotspotScore.toStringAsFixed(2)}'),
        Slider(
          value: _draft.minHotspotScore.clamp(0.0, 1.0),
          min: 0,
          max: 1,
          divisions: 20,
          label: _draft.minHotspotScore.toStringAsFixed(2),
          onChanged: (v) => setState(
            () => _draft = _draft.copyWith(minHotspotScore: v),
          ),
          onChangeEnd: (v) => unawaited(
            _applyDraft(_draft.copyWith(minHotspotScore: v)),
          ),
        ),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            FilterChip(
              label: const Text('A'),
              selected: _draft.filterClassA,
              onSelected: (v) => unawaited(
                _applyDraft(_draft.copyWith(filterClassA: v)),
              ),
            ),
            FilterChip(
              label: const Text('B'),
              selected: _draft.filterClassB,
              onSelected: (v) => unawaited(
                _applyDraft(_draft.copyWith(filterClassB: v)),
              ),
            ),
            FilterChip(
              label: const Text('C'),
              selected: _draft.filterClassC,
              onSelected: (v) => unawaited(
                _applyDraft(_draft.copyWith(filterClassC: v)),
              ),
            ),
          ],
        ),
        SettingsSwitchTile(
          title: 'Yoğunluk katmanı varsayılan açık',
          value: _draft.intensityOverlayDefault,
          onChanged: (v) => unawaited(
            _applyDraft(_draft.copyWith(intensityOverlayDefault: v)),
          ),
        ),
        SettingsSwitchTile(
          title: 'Hotspot bağlantı çizgileri',
          value: _draft.corridorLinesDefault,
          onChanged: (v) => unawaited(
            _applyDraft(_draft.copyWith(corridorLinesDefault: v)),
          ),
        ),
        SettingsSwitchTile(
          title: 'Lejant varsayılan açık',
          value: _draft.legendDefault,
          onChanged: (v) => unawaited(
            _applyDraft(_draft.copyWith(legendDefault: v)),
          ),
        ),
        SettingsSwitchTile(
          title: 'Marker detay panelini otomatik aç',
          value: _draft.autoOpenMarkerDetail,
          onChanged: (v) => unawaited(
            _applyDraft(_draft.copyWith(autoOpenMarkerDetail: v)),
          ),
        ),
        SettingsSegmentedControl<CoordinateDisplayFormat>(
          label: 'Koordinat formatı',
          options: CoordinateDisplayFormat.values,
          selected: _draft.coordinateFormat,
          labelBuilder: (v) => switch (v) {
            CoordinateDisplayFormat.decimal => 'Decimal',
            CoordinateDisplayFormat.dms => 'DMS',
          },
          onSelected: (v) => unawaited(
            _applyDraft(_draft.copyWith(coordinateFormat: v)),
          ),
        ),
        SettingsSwitchTile(
          title: 'Harita önizleme kaynak bilgisi',
          value: _draft.showMapPreviewSourceInfo,
          onChanged: (v) => unawaited(
            _applyDraft(_draft.copyWith(showMapPreviewSourceInfo: v)),
          ),
        ),
      ],
    );
  }

  Widget _captainAtlasSection() {
    return SettingsSectionCard(
      title: 'Captain Atlas',
      subtitle: 'AI asistan tercihleri',
      children: [
        SettingsSwitchTile(
          title: 'Captain Atlas aktif',
          subtitle: 'Kapalıyken giriş noktaları devre dışı kalır',
          value: _draft.captainAtlasEnabled,
          onChanged: (v) => unawaited(
            _applyDraft(_draft.copyWith(captainAtlasEnabled: v)),
          ),
        ),
        SettingsSwitchTile(
          title: 'Her zaman canlı AI dene',
          subtitle: 'Açılışta önbelleği atlayarak canlı istek dener',
          value: _draft.alwaysTryLiveAi,
          onChanged: (v) => unawaited(
            _applyDraft(_draft.copyWith(alwaysTryLiveAi: v)),
          ),
        ),
        SettingsSwitchTile(
          title: 'Güvenli özet fallback',
          subtitle: 'AI kullanılamazsa oturum önbelleğinden güvenli özet',
          value: _draft.useSafeFallbackSummary,
          onChanged: (v) => unawaited(
            _applyDraft(_draft.copyWith(useSafeFallbackSummary: v)),
          ),
        ),
        SettingsSwitchTile(
          title: 'Canlı/fallback kaynak rozeti',
          value: _draft.showAiSourceBadge,
          onChanged: (v) => unawaited(
            _applyDraft(_draft.copyWith(showAiSourceBadge: v)),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: () => unawaited(_clearCaptainAtlasCache()),
          icon: const Icon(Icons.delete_outline_rounded),
          label: const Text('Captain Atlas oturum/cache temizle'),
        ),
      ],
    );
  }

  Widget _appearanceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSectionCard(
          title: 'Görünüm ve deneyim',
          subtitle: 'Arayüz yoğunluğu ve animasyon',
          children: [
            SettingsSwitchTile(
              title: 'Kompakt görünüm',
              subtitle: 'Sidebar ve üst alanlarda daha sıkı düzen',
              value: _draft.compactView,
              onChanged: (v) => unawaited(
                _applyDraft(_draft.copyWith(compactView: v)),
              ),
            ),
            SettingsSwitchTile(
              title: 'Büyük dokunma alanları',
              value: _draft.largeTouchTargets,
              onChanged: (v) => unawaited(
                _applyDraft(_draft.copyWith(largeTouchTargets: v)),
              ),
            ),
            SettingsSwitchTile(
              title: 'Animasyonları azalt',
              value: _draft.reduceMotion,
              onChanged: (v) => unawaited(
                _applyDraft(_draft.copyWith(reduceMotion: v)),
              ),
            ),
            SettingsSegmentedControl<GlowIntensityLevel>(
              label: 'Premium glow yoğunluğu',
              options: GlowIntensityLevel.values,
              selected: _draft.glowIntensity,
              labelBuilder: (v) => switch (v) {
                GlowIntensityLevel.low => 'Düşük',
                GlowIntensityLevel.normal => 'Normal',
                GlowIntensityLevel.strong => 'Güçlü',
              },
              onSelected: (v) => unawaited(
                _applyDraft(_draft.copyWith(glowIntensity: v)),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SettingsSegmentedControl<CardDensityLevel>(
              label: 'Kart yoğunluğu',
              options: CardDensityLevel.values,
              selected: _draft.cardDensity,
              labelBuilder: (v) => switch (v) {
                CardDensityLevel.relaxed => 'Rahat',
                CardDensityLevel.standard => 'Standart',
                CardDensityLevel.tight => 'Sıkı',
              },
              onSelected: (v) => unawaited(
                _applyDraft(_draft.copyWith(cardDensity: v)),
              ),
            ),
            SettingsSwitchTile(
              title: 'Durum chip\'lerini göster',
              value: _draft.showStatusChips,
              onChanged: (v) => unawaited(
                _applyDraft(_draft.copyWith(showStatusChips: v)),
              ),
            ),
            SettingsSwitchTile(
              title: 'İpucu / helper metinleri',
              value: _draft.showHelperTexts,
              onChanged: (v) => unawaited(
                _applyDraft(_draft.copyWith(showHelperTexts: v)),
              ),
            ),
          ],
        ),
        SettingsSectionCard(
          title: 'Performans modu',
          subtitle: 'Pil ve animasyon dengesi',
          children: const [PremiumPerformanceModeTile()],
        ),
      ],
    );
  }

  Widget _maintenanceSection() {
    return SettingsSectionCard(
      title: 'Gelişmiş / Bakım',
      subtitle: 'Sürüm bilgisi ve tanılama',
      children: [
        SettingsInfoRow(label: 'Uygulama sürümü', value: AppConfig.appVersion),
        SettingsInfoRow(label: 'Build', value: AppConfig.buildNumber),
        SettingsInfoRow(
          label: 'API servis sürümü',
          value: _draft.lastHealthServiceVersion ?? '-',
        ),
        SettingsInfoRow(
          label: 'Son health check',
          value: _draft.lastHealthCheckAt != null
              ? _draft.lastHealthCheckAt!.toLocal().toString().substring(0, 19)
              : '-',
        ),
        if (kDebugMode) ...[
          const Divider(),
          Text('Debug modu aktif', style: AppTextStyles.caption),
        ],
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            OutlinedButton.icon(
              onPressed: () => unawaited(_copyDiagnostics()),
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Tanılama bilgisi kopyala'),
            ),
            OutlinedButton.icon(
              onPressed: () => unawaited(_resetAllSettings()),
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('Tüm ayarları sıfırla'),
            ),
            OutlinedButton.icon(
              onPressed: () => unawaited(_clearAllStorage()),
              icon: const Icon(Icons.storage_rounded),
              label: const Text('Local cache/storage temizle'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Ayarlar ekranını açar.
Future<String?> openPremiumSettingsScreen(
  BuildContext context, {
  required String serverHost,
  required Future<void> Function(String host, int port) onSaveConnection,
  required Future<void> Function() onAutoDiscover,
  bool discoveryBusy = false,
  BackendConnectionBadgeData? badgeSnapshot,
}) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      builder: (ctx) => PremiumSettingsScreen(
        serverHost: serverHost,
        onSaveConnection: onSaveConnection,
        onAutoDiscover: onAutoDiscover,
        discoveryBusy: discoveryBusy,
        badgeSnapshot: badgeSnapshot,
      ),
    ),
  );
}
