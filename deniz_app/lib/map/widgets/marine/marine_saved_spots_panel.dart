import 'package:deniz_app/domain/marine_learning_summary.dart';
import 'package:deniz_app/domain/marine_saved_spot.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/map/widgets/marine/marine_catch_dialog.dart';
import 'package:deniz_app/map/widgets/marine/marine_report_cards.dart';
import 'package:deniz_app/widgets/premium/feedback/premium_error_fallback.dart';
import 'package:deniz_app/widgets/premium/navigation/premium_hero_widgets.dart';
import 'package:flutter/material.dart';

class MarineSavedSpotsPanel extends StatefulWidget {
  const MarineSavedSpotsPanel({
    super.key,
    required this.spots,
    required this.onRefresh,
    required this.onDelete,
    required this.onToggleFavorite,
    required this.onAddCatch,
    required this.onShowCatches,
    this.learningSummaries = const {},
    this.busyId,
    this.onCompareSpots,
    this.embedded = false,
  });

  final List<MarineSavedSpot> spots;
  final Future<void> Function(MarineSavedSpot spot) onRefresh;
  final Future<void> Function(MarineSavedSpot spot) onDelete;
  final Future<void> Function(MarineSavedSpot spot) onToggleFavorite;
  final Future<void> Function(MarineSavedSpot spot) onAddCatch;
  final Future<void> Function(MarineSavedSpot spot) onShowCatches;
  final Map<String, MarineLearningSummary> learningSummaries;
  final String? busyId;
  final void Function(MarineSavedSpot left, MarineSavedSpot right)? onCompareSpots;
  final bool embedded;

  @override
  State<MarineSavedSpotsPanel> createState() => _MarineSavedSpotsPanelState();
}

class _MarineSavedSpotsPanelState extends State<MarineSavedSpotsPanel> {
  bool _compareMode = false;
  final List<String> _selectedIds = [];

  void _toggleCompareMode() {
    setState(() {
      _compareMode = !_compareMode;
      _selectedIds.clear();
    });
  }

  void _toggleSpotSelection(MarineSavedSpot spot) {
    setState(() {
      if (_selectedIds.contains(spot.id)) {
        _selectedIds.remove(spot.id);
        return;
      }
      if (_selectedIds.length >= 2) {
        _selectedIds.removeAt(0);
      }
      _selectedIds.add(spot.id);
    });
  }

  void _launchCompare() {
    if (_selectedIds.length != 2 || widget.onCompareSpots == null) return;
    final left = widget.spots.firstWhere((s) => s.id == _selectedIds[0]);
    final right = widget.spots.firstWhere((s) => s.id == _selectedIds[1]);
    widget.onCompareSpots!(left, right);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.spots.isEmpty) {
      final empty = Text(
        'Henüz kayıtlı nokta yok.',
        style: TextStyle(
          color: Colors.white.withValues(alpha: widget.embedded ? 0.55 : 0.7),
        ),
      );
      if (widget.embedded) return empty;
      return Card(
        color: const Color(0xFF142434),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: empty,
        ),
      );
    }

    final sorted = [...widget.spots]
      ..sort((a, b) {
        if (a.favorite != b.favorite) return a.favorite ? -1 : 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.embedded)
          Row(
            children: [
              Expanded(
                child: Text(
                  kMarineSavedSpotsTitle,
                  style: const TextStyle(
                    color: Color(0xFF80DEEA),
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              if (widget.onCompareSpots != null)
                TextButton.icon(
                  onPressed: _toggleCompareMode,
                  icon: Icon(
                    _compareMode ? Icons.close : Icons.compare_arrows,
                    size: 18,
                  ),
                  label: Text(
                    _compareMode ? kDialogClose : kMarineCompareSelectMode,
                  ),
                ),
            ],
          )
        else if (widget.onCompareSpots != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _toggleCompareMode,
              icon: Icon(
                _compareMode ? Icons.close : Icons.compare_arrows,
                size: 18,
              ),
              label: Text(
                _compareMode ? kDialogClose : kMarineCompareSelectMode,
              ),
            ),
          ),
        if (_compareMode) ...[
          Text(
            kMarineCompareSelectHint,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _selectedIds.length == 2 ? _launchCompare : null,
            icon: const Icon(Icons.compare),
            label: Text(kMarineCompareButton),
          ),
          const SizedBox(height: 8),
        ] else
          const SizedBox(height: 8),
        for (final spot in sorted)
          _SpotTile(
            spot: spot,
            busy: widget.busyId == spot.id,
            learning: widget.learningSummaries[spot.id],
            compareMode: _compareMode,
            selected: _selectedIds.contains(spot.id),
            onSelectToggle: () => _toggleSpotSelection(spot),
            onRefresh: () => widget.onRefresh(spot),
            onDelete: () => widget.onDelete(spot),
            onToggleFavorite: () => widget.onToggleFavorite(spot),
            onAddCatch: () => widget.onAddCatch(spot),
            onShowCatches: () => widget.onShowCatches(spot),
          ),
      ],
    );
  }
}

class _SpotTile extends StatefulWidget {
  const _SpotTile({
    required this.spot,
    required this.busy,
    required this.learning,
    required this.compareMode,
    required this.selected,
    required this.onSelectToggle,
    required this.onRefresh,
    required this.onDelete,
    required this.onToggleFavorite,
    required this.onAddCatch,
    required this.onShowCatches,
  });

  final MarineSavedSpot spot;
  final bool busy;
  final MarineLearningSummary? learning;
  final bool compareMode;
  final bool selected;
  final VoidCallback onSelectToggle;
  final VoidCallback onRefresh;
  final VoidCallback onDelete;
  final VoidCallback onToggleFavorite;
  final VoidCallback onAddCatch;
  final VoidCallback onShowCatches;

  @override
  State<_SpotTile> createState() => _SpotTileState();
}

class _SpotTileState extends State<_SpotTile> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _onFavorite() async {
    await _pulse.forward(from: 0);
    widget.onToggleFavorite();
    if (mounted) _pulse.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final spot = widget.spot;
    final summary = _spotSummary(spot.lastReport);
    return Semantics(
      label: spot.name,
      selected: widget.selected,
      child: AnimatedScale(
      scale: widget.selected ? 1.02 : 1.0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: widget.selected ? const Color(0xFF1B3A4B) : const Color(0xFF142434),
          border: Border.all(
            color: widget.selected
                ? const Color(0xFF32D9FF).withValues(alpha: 0.45)
                : Colors.transparent,
          ),
        ),
        child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (widget.compareMode)
                  Checkbox(
                    value: widget.selected,
                    onChanged: (_) => widget.onSelectToggle(),
                    activeColor: const Color(0xFF80DEEA),
                  ),
                Expanded(
                  child: Text(
                    spot.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (!widget.compareMode)
                  ScaleTransition(
                    scale: Tween<double>(begin: 1, end: 1.28).animate(
                      CurvedAnimation(parent: _pulse, curve: Curves.easeOutBack),
                    ),
                    child: Semantics(
                      button: true,
                      label: kMarineFavoriteToggle,
                      selected: spot.favorite,
                      child: IconButton(
                        tooltip: kMarineFavoriteToggle,
                        onPressed: _onFavorite,
                        icon: PremiumHeroSavedSpotIcon(
                          spotId: spot.id,
                          favorite: spot.favorite,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Text(
              '${spot.lat.toStringAsFixed(4)}, ${spot.lon.toStringAsFixed(4)}',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
            if (spot.lastReportAt != null)
              Text(
                '$kMarineLastReport: ${spot.lastReportAt}',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            if (summary != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(summary, style: const TextStyle(color: Colors.white70)),
              ),
            if (spot.lastReport?.decision?.fishingDecision != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _DecisionBadge(
                  decision: spot.lastReport!.decision!.fishingDecision,
                ),
              ),
            if (spot.lastReport?.scenario?.mostSensitiveFactorLabel != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '$kMarineMostSensitivePrefix ${spot.lastReport!.scenario!.mostSensitiveFactorLabel}',
                  style: const TextStyle(color: Colors.amber, fontSize: 11),
                ),
              ),
            if (widget.learning != null && widget.learning!.catchCount > 0) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (widget.learning!.spotReputation != null)
                    _ReputationBadge(reputation: widget.learning!.spotReputation!),
                  if (widget.learning!.spotLevel != null)
                    _LevelBadge(level: widget.learning!.spotLevel!),
                  if (widget.learning!.topSpecies != null)
                    Text(
                      '$kMarineTopSpeciesPrefix ${widget.learning!.topSpecies}',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  Text(
                    '$kMarineCatchCountLabel: ${widget.learning!.catchCount}',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ],
            Text(
              '$kMarineVisitCount: ${spot.visitCount}',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
            if (!widget.compareMode) ...[
              const SizedBox(height: 8),
              PremiumErrorBoundary(
                sectionTitle: kMarineSavedSpotsTitle,
                builder: (context) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Semantics(
                    button: true,
                    label: kMarineRefreshSpot,
                    child: FilledButton.tonal(
                      onPressed: widget.busy ? null : widget.onRefresh,
                      child: widget.busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(kMarineRefreshSpot),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: kMarineAddCatchButton,
                    child: OutlinedButton(
                      onPressed: widget.onAddCatch,
                      child: Text(kMarineAddCatchButton),
                    ),
                  ),
                  if (widget.learning != null && widget.learning!.catchCount > 0)
                    Semantics(
                      button: true,
                      label: kMarineViewCatchesButton,
                      child: TextButton(
                        onPressed: widget.onShowCatches,
                        child: Text(kMarineViewCatchesButton),
                      ),
                    ),
                  Semantics(
                    button: true,
                    label: kMarineDeleteSpot,
                    child: TextButton(
                      onPressed: widget.onDelete,
                      child: Text(kMarineDeleteSpot),
                    ),
                  ),
                ],
              ),
              ),
            ],
          ],
        ),
        ),
      ),
    ),
    );
  }

  static String? _spotSummary(dynamic snap) {
    if (snap == null) return null;
    final score = snap.fishingScore?.suitabilityScore;
    if (score == null) return null;
    final wind = snap.wind?.speedKmh?.finalValue;
    final wave = snap.marine?.waveHeightM?.finalValue;
    final parts = <String>['Uygunluk $score/100'];
    if (wind != null) parts.add('Rüzgar ${wind.toStringAsFixed(0)} km/h');
    if (wave != null) parts.add('Dalga ${wave.toStringAsFixed(1)} m');
    return parts.join(' · ');
  }
}

class _ReputationBadge extends StatelessWidget {
  const _ReputationBadge({required this.reputation});

  final int reputation;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF26A69A).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF26A69A).withValues(alpha: 0.4)),
      ),
      child: Text(
        '$kMarineSpotReputationLabel $reputation',
        style: const TextStyle(
          color: Color(0xFF80CBC4),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level});

  final String level;

  @override
  Widget build(BuildContext context) {
    final color = marineSpotLevelColor(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        marineSpotLevelLabelTr(level),
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _DecisionBadge extends StatelessWidget {
  const _DecisionBadge({required this.decision});

  final String? decision;

  @override
  Widget build(BuildContext context) {
    final label = marineDecisionBadgeLabelTr(decision);
    final color = marineDecisionColor(decision);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$kMarineLastDecisionPrefix $label',
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
