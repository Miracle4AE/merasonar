import 'package:deniz_app/domain/marine_learning_summary.dart';
import 'package:deniz_app/domain/marine_saved_spot.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/map/widgets/marine/marine_saved_spots_panel.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/widgets/premium/premium_card.dart';
import 'package:flutter/material.dart';

/// Kayıtlı noktalar paneli — mevcut iş mantığını koruyarak premium sarmalayıcı.
class SavedSpotsPremiumPanel extends StatelessWidget {
  const SavedSpotsPremiumPanel({
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

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(kMarineSavedSpotsTitle, style: AppTextStyles.cardTitle),
          const SizedBox(height: AppSpacing.md),
          MarineSavedSpotsPanel(
            spots: spots,
            busyId: busyId,
            learningSummaries: learningSummaries,
            onRefresh: onRefresh,
            onDelete: onDelete,
            onToggleFavorite: onToggleFavorite,
            onAddCatch: onAddCatch,
            onShowCatches: onShowCatches,
            onCompareSpots: onCompareSpots,
            embedded: true,
          ),
        ],
      ),
    );
  }
}
