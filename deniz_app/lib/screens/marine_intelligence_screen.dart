import 'dart:async' show unawaited;

import 'package:deniz_app/api_service.dart';
import 'package:deniz_app/config/app_config.dart';
import 'package:deniz_app/controllers/marine_intelligence_controller.dart';
import 'package:deniz_app/domain/marine_compare.dart';
import 'package:deniz_app/domain/marine_intelligence_report.dart';
import 'package:deniz_app/domain/marine_learning_summary.dart';
import 'package:deniz_app/domain/marine_saved_spot.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/map/widgets/marine/intelligence/captain_atlas_comment_card.dart';
import 'package:deniz_app/map/widgets/marine/intelligence/coordinate_input_panel.dart';
import 'package:deniz_app/map/widgets/marine/intelligence/marine_action_bar.dart';
import 'package:deniz_app/map/widgets/marine/intelligence/marine_conditions_grid.dart';
import 'package:deniz_app/map/widgets/marine/intelligence/marine_decision_overview_card.dart';
import 'package:deniz_app/map/widgets/marine/intelligence/marine_explainability_card.dart';
import 'package:deniz_app/map/widgets/marine/intelligence/marine_intelligence_header.dart';
import 'package:deniz_app/map/widgets/marine/intelligence/marine_intelligence_premium_layout.dart';
import 'package:deniz_app/map/widgets/marine/intelligence/marine_scenario_card.dart';
import 'package:deniz_app/map/widgets/marine/intelligence/marine_timeline_premium_card.dart';
import 'package:deniz_app/map/widgets/marine/intelligence/coordinate_picker_map_sheet.dart';
import 'package:deniz_app/map/widgets/marine/intelligence/saved_spots_premium_panel.dart';
import 'package:deniz_app/map/widgets/marine/marine_catch_dialog.dart';
import 'package:deniz_app/map/widgets/marine/provider_comparison_panel.dart';
import 'package:deniz_app/screens/marine_compare_screen.dart';
import 'package:deniz_app/services/dashboard_overview_service.dart';
import 'package:deniz_app/services/marine_intelligence_cache.dart';
import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/utils/navionics_coordinate_parser.dart';
import 'package:deniz_app/widgets/premium/premium_card.dart';
import 'package:deniz_app/widgets/premium/premium_empty_state.dart';
import 'package:deniz_app/widgets/premium/premium_loading_skeleton.dart';
import 'package:deniz_app/navigation/captain_atlas_launcher.dart';
import 'package:deniz_app/navigation/premium_navigator.dart';
import 'package:deniz_app/widgets/premium/feedback/premium_dialog.dart';
import 'package:deniz_app/widgets/premium/feedback/premium_error_fallback.dart';
import 'package:deniz_app/widgets/premium/feedback/premium_toast.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class MarineIntelligenceScreen extends StatefulWidget {
  const MarineIntelligenceScreen({
    super.key,
    required this.serverIp,
    this.initialLat,
    this.initialLon,
  });

  final String serverIp;
  final double? initialLat;
  final double? initialLon;

  @override
  State<MarineIntelligenceScreen> createState() =>
      _MarineIntelligenceScreenState();
}

class _MarineIntelligenceScreenState extends State<MarineIntelligenceScreen> {
  final _latCtrl = TextEditingController();
  final _lonCtrl = TextEditingController();
  final _cache = MarineIntelligenceCache();
  final _controller = MarineIntelligenceController();

  MarineIntelligenceReport? _report;
  List<MarineSavedSpot> _spots = [];
  Map<String, MarineLearningSummary> _learningSummaries = {};
  bool _analyzing = false;
  bool _loadingAiComment = false;
  bool _offlineCached = false;
  String? _busySpotId;
  String? _error;
  String? _spotsSyncedAt;
  bool _refreshIncludeAiComment = false;

  ApiService get _api => ApiService(
        serverBaseUrl: AppConfig.buildApiBaseUrl(widget.serverIp.trim()),
      );

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null) {
      _latCtrl.text = widget.initialLat!.toStringAsFixed(5);
    }
    if (widget.initialLon != null) {
      _lonCtrl.text = widget.initialLon!.toStringAsFixed(5);
    }
    unawaited(_bootstrapFromCache());
  }

  Future<void> _bootstrapFromCache() async {
    final cachedReport = await _cache.loadLastReport();
    final cachedSpots = await _cache.loadSavedSpots();
    final synced = await _cache.savedSpotsSyncedAt();
    if (!mounted) return;
    _controller.applyCachedBootstrap(
      cachedReport: cachedReport,
      cachedSpots: cachedSpots,
      syncedAt: synced,
    );
    setState(() {
      if (_report == null && _controller.report != null) {
        _report = _controller.report;
        _offlineCached = _controller.offlineCached;
      }
      if (_spots.isEmpty && _controller.spots.isNotEmpty) {
        _spots = _controller.spots;
      }
      _spotsSyncedAt = _controller.spotsSyncedAt;
    });
    unawaited(_loadSpots(silent: true));
  }

  @override
  void dispose() {
    _latCtrl.dispose();
    _lonCtrl.dispose();
    _controller.dispose();
    super.dispose();
  }

  double? _parseCoord(TextEditingController c, {required bool lat}) {
    final raw = c.text.trim();
    if (raw.isEmpty) return null;
    final parsed = parseNavionicsCoordinate(raw, isLatitude: lat);
    if (parsed != null) return parsed;
    return double.tryParse(raw.replaceAll(',', '.'));
  }

  Future<void> _analyze({bool forceRefresh = false}) async {
    final lat = _parseCoord(_latCtrl, lat: true);
    final lon = _parseCoord(_lonCtrl, lat: false);
    if (lat == null || lon == null) {
      setState(() => _error = kMarineCoordValidationError);
      return;
    }
    setState(() {
      _analyzing = true;
      _error = null;
      _offlineCached = false;
    });
    try {
      final report = await _api.fetchMarineCoordinateReport(
        lat: lat,
        lon: lon,
        forceRefresh: forceRefresh,
      );
      await _cache.saveLastReport(report);
      if (!mounted) return;
      setState(() {
        _report = report;
        _analyzing = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _analyzing = false;
        _error = e.message;
        _offlineCached = _report != null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _analyzing = false;
        _error = kMsgSunucuyaUlasilamiyor;
        _offlineCached = _report != null;
      });
    }
  }

  Future<void> _openCaptainCommandCenter() {
    return CaptainAtlasLauncher.launch(
      context,
      CaptainAtlasLaunchRequest(
        serverIp: widget.serverIp,
        entryPoint: CaptainAtlasEntryPoint.marineIntelligence,
      ),
    );
  }

  Future<void> _fetchAiComment() async {
    if (_report == null) return;
    final lat = _report!.coordinate.lat;
    final lon = _report!.coordinate.lon;
    setState(() {
      _loadingAiComment = true;
      _error = null;
    });
    try {
      final updated = await _api.fetchMarineCoordinateReport(
        lat: lat,
        lon: lon,
        includeAiComment: true,
        forceRefresh: false,
      );
      if (!mounted) return;
      setState(() {
        _report = MarineIntelligenceReport(
          coordinate: _report!.coordinate,
          weather: _report!.weather,
          wind: _report!.wind,
          marine: _report!.marine,
          astronomy: _report!.astronomy,
          fishingScore: _report!.fishingScore,
          consensusSummary: _report!.consensusSummary,
          updatedAt: _report!.updatedAt,
          cacheHit: updated.cacheHit,
          partialData: _report!.partialData,
          providerComparison: _report!.providerComparison,
          explainability: _report!.explainability,
          tide: _report!.tide,
          fishActivity: _report!.fishActivity,
          marineRisk: _report!.marineRisk,
          marineIndex: _report!.marineIndex,
          weatherStability: _report!.weatherStability,
          decision: _report!.decision,
          scenario: _report!.scenario,
          decisionTimeline: _report!.decisionTimeline,
          historical: _report!.historical,
          trends: _report!.trends,
          aiComment: updated.aiComment,
        );
        _loadingAiComment = false;
      });
      if (_report != null) {
        await _cache.saveLastReport(_report!);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingAiComment = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingAiComment = false;
        _error = kMsgSunucuyaUlasilamiyor;
      });
    }
  }

  Future<void> _loadSpots({bool silent = false}) async {
    try {
      final resp = await _api.fetchMarineSavedSpots();
      await _cache.saveSavedSpots(resp.spots);
      if (!mounted) return;
      setState(() {
        _spots = resp.spots;
        _spotsSyncedAt = DateTime.now().toUtc().toIso8601String();
      });
      await _loadLearningSummaries();
    } on ApiException catch (e) {
      if (!silent && mounted) {
        context.showPremiumError(e.message);
      }
    } catch (_) {
      if (!silent && mounted) {
        context.showPremiumOffline(kMsgMarineSpotsLoadFailed);
      }
    }
  }

  Future<void> _loadLearningSummaries() async {
    if (_spots.isEmpty) {
      if (mounted) setState(() => _learningSummaries = {});
      return;
    }
    try {
      final resp = await _api.fetchLearningSummaries(
        _spots.map((s) => s.id).toList(growable: false),
      );
      final summaries = <String, MarineLearningSummary>{};
      for (final entry in resp.summaries.entries) {
        if (entry.value != null) {
          summaries[entry.key] = entry.value!;
        }
      }
      if (!mounted) return;
      setState(() => _learningSummaries = summaries);
    } catch (_) {
      // Bulk özet yüklenemezse spot kartları yine çalışır.
    }
  }

  void _applyLearningSummary(MarineLearningSummary summary) {
    setState(() {
      _learningSummaries = {..._learningSummaries, summary.spotId: summary};
    });
  }

  Future<void> _addCatch(MarineSavedSpot spot) async {
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const MarineCatchAddDialog(),
    );
    if (data == null) return;
    try {
      final resp = await _api.createCatchForSpot(
        spot.id,
        species: data['species'] as String,
        caughtAt: data['caught_at'] as String,
        lengthCm: data['length_cm'] as double?,
        weightKg: data['weight_kg'] as double?,
        bait: data['bait'] as String?,
        method: data['method'] as String?,
        notes: data['notes'] as String?,
      );
      _applyLearningSummary(resp.summary);
      await _loadSpots();
      final listResp = await _api.fetchCatchesForSpot(spot.id);
      await mergeRecentCatchSummariesForDashboard(
        cache: _cache,
        spotId: spot.id,
        spotName: spot.name,
        catches: listResp.catches
            .map(
              (c) => {
                'species': c.species,
                'caught_at': c.caughtAt,
                'weight_kg': c.weightKg,
              },
            )
            .toList(),
      );
      if (mounted) {
        context.showPremiumSuccess('Av kaydı eklendi.');
      }
    } on ApiException catch (e) {
      if (mounted) {
        context.showPremiumError(e.message);
      }
    }
  }

  Future<void> _showCatches(MarineSavedSpot spot) async {
    try {
      var resp = await _api.fetchCatchesForSpot(spot.id);
      if (!mounted) return;
      await mergeRecentCatchSummariesForDashboard(
        cache: _cache,
        spotId: spot.id,
        spotName: spot.name,
        catches: resp.catches
            .map(
              (c) => {
                'species': c.species,
                'caught_at': c.caughtAt,
                'weight_kg': c.weightKg,
              },
            )
            .toList(),
      );
      if (!mounted) return;
      await showMarineCatchListSheet(
        context,
        catches: resp.catches,
        onDelete: (id) async {
          final deleted = await _api.deleteCatch(id);
          if (deleted.summary != null) {
            _applyLearningSummary(deleted.summary!);
          }
          resp = await _api.fetchCatchesForSpot(spot.id);
        },
        onEdit: (record) async {
          final data = await showDialog<Map<String, dynamic>>(
            context: context,
            builder: (_) => MarineCatchAddDialog(initial: record),
          );
          if (data == null) return;
          final updated = await _api.updateCatch(
            record.id,
            species: data['species'] as String,
            lengthCm: data['length_cm'] as double?,
            weightKg: data['weight_kg'] as double?,
            bait: data['bait'] as String?,
            method: data['method'] as String?,
            caughtAt: data['caught_at'] as String,
            notes: data['notes'] as String?,
          );
          _applyLearningSummary(updated.summary);
          resp = await _api.fetchCatchesForSpot(spot.id);
        },
      );
      await _loadSpots(silent: true);
    } on ApiException catch (e) {
      if (mounted) {
        context.showPremiumError(e.message);
      }
    }
  }

  Future<void> _saveSpot() async {
    if (_report == null) return;
    final lat = _report!.coordinate.lat;
    final lon = _report!.coordinate.lon;
    final nameCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final tagsCtrl = TextEditingController();
    var favorite = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: const Color(0xFF142434),
          title: Text(kMarineSaveDialogTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(labelText: kMarineSpotNameHint),
              ),
              TextField(
                controller: noteCtrl,
                decoration: InputDecoration(labelText: kMarineSpotNoteHint),
              ),
              TextField(
                controller: tagsCtrl,
                decoration: InputDecoration(labelText: kMarineSpotTagsHint),
              ),
              CheckboxListTile(
                value: favorite,
                onChanged: (v) => setLocal(() => favorite = v ?? false),
                title: Text(kMarineFavoriteToggle),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(kDialogClose)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kaydet')),
          ],
        ),
      ),
    );
    if (ok != true || nameCtrl.text.trim().isEmpty) return;
    final tags = tagsCtrl.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    try {
      await _api.createMarineSavedSpot(
        name: nameCtrl.text.trim(),
        lat: lat,
        lon: lon,
        note: noteCtrl.text.trim(),
        favorite: favorite,
        personalTags: tags,
      );
      await _loadSpots();
      if (mounted) {
        context.showPremiumSuccess('Nokta kaydedildi.');
      }
    } on ApiException catch (e) {
      if (mounted) {
        context.showPremiumError(e.message);
      }
    }
  }

  Future<void> _refreshSpot(MarineSavedSpot spot) async {
    setState(() => _busySpotId = spot.id);
    try {
      final resp = await _api.refreshMarineSavedSpot(
        spot.id,
        includeAiComment: _refreshIncludeAiComment,
      );
      await _cache.saveLastReport(resp.report);
      await _loadSpots();
      if (!mounted) return;
      setState(() {
        _report = resp.report;
        _latCtrl.text = spot.lat.toStringAsFixed(5);
        _lonCtrl.text = spot.lon.toStringAsFixed(5);
        _offlineCached = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        context.showPremiumError(e.message);
      }
    } finally {
      if (mounted) setState(() => _busySpotId = null);
    }
  }

  Future<void> _deleteSpot(MarineSavedSpot spot) async {
    final ok = await PremiumDialog.showConfirm(
      context,
      title: kMarineDeleteSpotConfirmTitle,
      message: kMarineDeleteSpotConfirmMessage,
      confirmLabel: kMarineDeleteSpot,
      tone: PremiumDialogTone.danger,
      destructive: true,
    );
    if (ok != true || !mounted) return;
    try {
      await _api.deleteMarineSavedSpot(spot.id);
      await _loadSpots();
      if (mounted) context.showPremiumSuccess('Nokta silindi.');
    } on ApiException catch (e) {
      if (mounted) context.showPremiumError(e.message);
    }
  }

  Future<void> _toggleFavorite(MarineSavedSpot spot) async {
    try {
      await _api.updateMarineSavedSpot(
        spot.id,
        favorite: !spot.favorite,
      );
      await _loadSpots();
    } on ApiException catch (e) {
      if (mounted) {
        context.showPremiumError(e.message);
      }
    }
  }

  Future<void> _openMapPicker() async {
    final currentLat = _parseCoord(_latCtrl, lat: true) ?? widget.initialLat;
    final currentLon = _parseCoord(_lonCtrl, lat: false) ?? widget.initialLon;
    final initialPoint = currentLat != null && currentLon != null
        ? LatLng(currentLat, currentLon)
        : null;
    final picked = await showModalBottomSheet<LatLng>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0B1A2A),
      builder: (ctx) => CoordinatePickerMapSheet(
        initialPoint: initialPoint,
        fallbackCenter: const LatLng(36.8, 28.2),
      ),
    );
    if (picked != null) {
      setState(() {
        _latCtrl.text = picked.latitude.toStringAsFixed(6);
        _lonCtrl.text = picked.longitude.toStringAsFixed(6);
      });
    }
  }

  void _openCompareScreen({
    MarineCompareSide? initialLeft,
    MarineCompareSide? initialRight,
  }) {
    PremiumNavigator.push<void>(
      context,
      MarineCompareScreen(
        serverIp: widget.serverIp,
        initialLeft: initialLeft,
        initialRight: initialRight,
      ),
    );
  }

  void _openCompareFromCurrentCoordinate() {
    final lat = _parseCoord(_latCtrl, lat: true);
    final lon = _parseCoord(_lonCtrl, lat: false);
    MarineCompareSide? left;
    if (lat != null && lon != null) {
      left = MarineCompareSide(
        lat: lat,
        lon: lon,
        label: kMarineComparePointA,
      );
    }
    _openCompareScreen(initialLeft: left);
  }

  void _openCompareFromSpots(MarineSavedSpot left, MarineSavedSpot right) {
    _openCompareScreen(
      initialLeft: MarineCompareSide(
        spotId: left.id,
        lat: left.lat,
        lon: left.lon,
        label: left.name,
      ),
      initialRight: MarineCompareSide(
        spotId: right.id,
        lat: right.lat,
        lon: right.lon,
        label: right.name,
      ),
    );
  }

  Widget _buildCenterColumn() {
    if (_analyzing) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PremiumLoadingSkeleton(height: 160),
          SizedBox(height: AppSpacing.gridGap),
          PremiumLoadingSkeleton(height: 120),
          SizedBox(height: AppSpacing.gridGap),
          PremiumLoadingSkeleton(height: 200),
        ],
      );
    }

    if (_error != null && _report == null) {
      return PremiumEmptyState(
        title: _error!,
        icon: Icons.cloud_off_outlined,
        actionLabel: kMarineAnalyzeButton,
        onAction: _analyze,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_report != null) ...[
          MarineActionBar(
            onSaveSpot: _saveSpot,
            onAskCaptain: _fetchAiComment,
            onCompare: _openCompareFromCurrentCoordinate,
            onRefresh: () => _analyze(forceRefresh: true),
            loadingAi: _loadingAiComment,
            busy: _analyzing,
          ),
          const SizedBox(height: AppSpacing.gridGap),
        ],
        MarineDecisionOverviewCard(report: _report),
        if (_report != null) ...[
          const SizedBox(height: AppSpacing.gridGap),
          if (_report!.decisionTimeline.isNotEmpty)
            MarineTimelinePremiumCard(items: _report!.decisionTimeline),
          if (_report!.decisionTimeline.isNotEmpty)
            const SizedBox(height: AppSpacing.gridGap),
          MarineConditionsGrid(report: _report!),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.gridGap),
            PremiumCard(
              child: Text(
                _error!,
                style: TextStyle(color: AppColors.accentAmber),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildRightColumn() {
    if (_report == null || _analyzing) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CaptainAtlasCommentCard(
          comment: _report!.aiComment,
          onAskCaptain: _openCaptainCommandCenter,
          loading: _loadingAiComment,
          enabled: !_analyzing,
        ),
        if (_report!.explainability != null) ...[
          const SizedBox(height: AppSpacing.gridGap),
          MarineExplainabilityCard(explain: _report!.explainability!),
        ],
        if (_report!.scenario != null && _report!.scenario!.items.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.gridGap),
          MarineScenarioCard(
            scenario: _report!.scenario!,
            mostSensitiveFactorTr:
                _report!.explainability?.mostSensitiveFactorTr,
          ),
        ],
      ],
    );
  }

  Widget? _buildBottomSection() {
    final comparison = _report?.providerComparison;
    if (_report == null ||
        comparison == null ||
        comparison.providers.isEmpty) {
      return null;
    }

    return PremiumCard(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(
            kMarineProviderExpandTitle,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          children: [
            ProviderComparisonPanel(comparison: comparison),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(kMarineScreenTitle),
        backgroundColor: AppColors.backgroundNavy,
      ),
      body: MarineIntelligencePremiumLayout(
        header: MarineIntelligenceHeader(
          offlineCached: _offlineCached,
          spotsSyncedAt: _spotsSyncedAt,
          reportUpdatedAt: _report?.updatedAt,
          cacheHit: _report?.cacheHit ?? false,
          partialData: _report?.partialData ?? false,
        ),
        coordinatePanel: CoordinateInputPanel(
          latController: _latCtrl,
          lonController: _lonCtrl,
          onAnalyze: _analyze,
          onPickFromMap: _openMapPicker,
          onCompare: _openCompareFromCurrentCoordinate,
          busy: _analyzing,
          errorMessage: _error != null && _report == null ? _error : null,
        ),
        savedSpots: PremiumErrorBoundary(
          sectionTitle: kMissionSpotsStripTitle,
          builder: (context) => SavedSpotsPremiumPanel(
            spots: _spots,
            busyId: _busySpotId,
            learningSummaries: _learningSummaries,
            onRefresh: _refreshSpot,
            onDelete: _deleteSpot,
            onToggleFavorite: _toggleFavorite,
            onAddCatch: _addCatch,
            onShowCatches: _showCatches,
            onCompareSpots: _openCompareFromSpots,
          ),
        ),
        centerColumn: PremiumErrorBoundary(
          sectionTitle: kMarineScreenTitle,
          builder: (context) => _buildCenterColumn(),
        ),
        rightColumn: PremiumErrorBoundary(
          sectionTitle: kMarineScreenTitle,
          builder: (context) => _buildRightColumn(),
        ),
        bottomSection: _buildBottomSection(),
        refreshAiToggle: SwitchListTile(
          value: _refreshIncludeAiComment,
          onChanged: (v) => setState(() => _refreshIncludeAiComment = v),
          title: Text(
            kMarineRefreshIncludeAiComment,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
