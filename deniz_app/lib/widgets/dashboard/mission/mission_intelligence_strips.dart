import 'package:deniz_app/domain/dashboard_overview.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/utils/premium_offline_copy.dart';
import 'package:deniz_app/widgets/premium/settings/premium_performance_mode_tile.dart';
import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/widgets/premium/premium_card.dart';
import 'package:deniz_app/widgets/premium/premium_empty_state.dart';
import 'package:deniz_app/widgets/premium/premium_status_badge.dart';
import 'package:flutter/material.dart';

class MissionIntelligenceStrip extends StatelessWidget {
  const MissionIntelligenceStrip({
    super.key,
    required this.title,
    required this.child,
    this.onTap,
  });

  final String title;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.cardTitle),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

class MissionSavedSpotsStrip extends StatelessWidget {
  const MissionSavedSpotsStrip({
    super.key,
    required this.summary,
    required this.onMarineTap,
  });

  final DashboardSavedSpotsSummary summary;
  final VoidCallback onMarineTap;

  @override
  Widget build(BuildContext context) {
    if (!summary.hasData) {
      return MissionIntelligenceStrip(
        title: kMissionSpotsStripTitle,
        onTap: onMarineTap,
        child: PremiumEmptyState(
          title: kPremiumDashSpotsTitle,
          subtitle: kPremiumDashSpotsEmpty,
          icon: Icons.bookmark_outline,
          actionLabel: kPremiumDashSpotsCta,
          onAction: onMarineTap,
        ),
      );
    }

    return MissionIntelligenceStrip(
      title: kMissionSpotsStripTitle,
      onTap: onMarineTap,
      child: Column(
        children: [
          for (final spot in summary.items.take(4)) ...[
            _SpotRow(spot: spot),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _SpotRow extends StatelessWidget {
  const _SpotRow({required this.spot});

  final DashboardSavedSpotItem spot;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          spot.favorite ? Icons.star_rounded : Icons.place_outlined,
          size: 16,
          color: spot.favorite ? AppColors.accentAmber : AppColors.textMuted,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(spot.name, style: AppTextStyles.caption, maxLines: 1),
              if (spot.decisionLabel != null)
                Text(
                  spot.decisionLabel!,
                  style: AppTextStyles.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        if (spot.score != null)
          Text('${spot.score}', style: AppTextStyles.caption),
      ],
    );
  }
}

class MissionCatchStrip extends StatelessWidget {
  const MissionCatchStrip({
    super.key,
    required this.summary,
    required this.onMarineTap,
  });

  final DashboardRecentCatchesSummary summary;
  final VoidCallback onMarineTap;

  @override
  Widget build(BuildContext context) {
    if (!summary.hasData) {
      return MissionIntelligenceStrip(
        title: kMissionCatchStripTitle,
        onTap: onMarineTap,
        child: PremiumEmptyState(
          title: kPremiumDashCatchesTitle,
          subtitle: kPremiumDashCatchesEmptyLong,
          icon: Icons.set_meal_outlined,
          actionLabel: kPremiumDashCatchesCta,
          onAction: onMarineTap,
        ),
      );
    }

    final topSpecies = summary.items.map((e) => e.species).toSet().take(2).join(', ');

    return MissionIntelligenceStrip(
      title: kMissionCatchStripTitle,
      onTap: onMarineTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PremiumStatusBadge(
            label: '$kMissionCatchCountLabel: ${summary.items.length}',
            tone: PremiumStatusTone.neutral,
          ),
          if (topSpecies.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(topSpecies, style: AppTextStyles.caption),
          ],
          const SizedBox(height: AppSpacing.sm),
          for (final item in summary.items.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${item.species}${item.spotName.isNotEmpty ? ' · ${item.spotName}' : ''}',
                style: AppTextStyles.caption,
                maxLines: 1,
              ),
            ),
        ],
      ),
    );
  }
}

class MissionCompareSnapshotStrip extends StatelessWidget {
  const MissionCompareSnapshotStrip({
    super.key,
    required this.summary,
    required this.onCompareTap,
  });

  final DashboardCompareSummary summary;
  final VoidCallback onCompareTap;

  @override
  Widget build(BuildContext context) {
    if (!summary.hasData) {
      return MissionIntelligenceStrip(
        title: kMissionCompareStripTitle,
        onTap: onCompareTap,
        child: PremiumEmptyState(
          title: kPremiumDashCompareTitle,
          subtitle: kPremiumDashCompareEmpty,
          icon: Icons.compare_arrows,
          actionLabel: kPremiumDashCompareCta,
          onAction: onCompareTap,
        ),
      );
    }

    return MissionIntelligenceStrip(
      title: kMissionCompareStripTitle,
      onTap: onCompareTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (summary.winnerLabel.isNotEmpty)
            Semantics(
              label: kMarineCompareWinnerTitle,
              value: summary.winnerLabel,
              child: PremiumStatusBadge(
                label: summary.winnerLabel,
                tone: PremiumStatusTone.success,
              ),
            ),
          if (summary.scoreDelta != 0) ...[
            const SizedBox(height: 6),
            Text(
              '$kMarineCompareScoreDelta: ${summary.scoreDelta > 0 ? '+' : ''}${summary.scoreDelta}',
              style: AppTextStyles.caption,
            ),
          ],
          const SizedBox(height: 6),
          Text(summary.summaryTr, style: AppTextStyles.caption, maxLines: 3),
          if (summary.captainCommentTr.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(summary.captainCommentTr, style: AppTextStyles.caption, maxLines: 2),
          ],
        ],
      ),
    );
  }
}

class MissionSystemStatusStrip extends StatelessWidget {
  const MissionSystemStatusStrip({super.key, required this.overview});

  final DashboardOverview overview;

  @override
  Widget build(BuildContext context) {
    final online = overview.connectionStatus == DashboardConnectionStatus.connected;
    final cacheHit = overview.marineReport.cacheHit == true;
    final cacheLabel = PremiumOfflineCopy.cacheBanner(
      cacheHit: cacheHit,
      offline: !online,
    );

    return MissionIntelligenceStrip(
      title: kMissionSystemStatusTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              PremiumStatusBadge(
                label: '$kMissionSystemBackend: ${online ? kMissionSystemOnline : kPremiumNoConnection}',
                tone: online ? PremiumStatusTone.success : PremiumStatusTone.danger,
              ),
              PremiumStatusBadge(
                label: '$kMissionSystemMarine: ${overview.marineReport.hasData ? kMissionSystemOnline : kPremiumNoDataLabel}',
                tone: overview.marineReport.hasData
                    ? PremiumStatusTone.success
                    : PremiumStatusTone.neutral,
              ),
              PremiumStatusBadge(
                label: '$kMissionSystemAi: ${overview.captainAtlas.hasData ? kMissionSystemReady : kMissionSystemReady}',
                tone: PremiumStatusTone.neutral,
              ),
              if (cacheLabel.isNotEmpty)
                PremiumStatusBadge(
                  label: cacheLabel,
                  tone: cacheHit ? PremiumStatusTone.warning : PremiumStatusTone.neutral,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const PremiumPerformanceModeTile(),
        ],
      ),
    );
  }
}

class MissionLiveIndexCard extends StatelessWidget {
  const MissionLiveIndexCard({
    super.key,
    required this.summary,
    required this.onLiveTap,
  });

  final DashboardLiveScoreSummary summary;
  final VoidCallback onLiveTap;

  @override
  Widget build(BuildContext context) {
    if (!summary.hasData) {
      return MissionIntelligenceStrip(
        title: kMissionLiveIndexTitle,
        onTap: onLiveTap,
        child: PremiumEmptyState(
          title: kPremiumDashLiveScoreTitle,
          subtitle: kPremiumDashLiveScoreEmpty,
          icon: Icons.navigation_rounded,
          actionLabel: kPremiumDashLiveScoreCta,
          onAction: onLiveTap,
        ),
      );
    }

    return MissionIntelligenceStrip(
      title: kMissionLiveIndexTitle,
      onTap: onLiveTap,
      child: Row(
        children: [
          Text('${summary.score}', style: AppTextStyles.metricNumber),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              summary.detailLine.isNotEmpty ? summary.detailLine : summary.rating,
              style: AppTextStyles.caption,
              maxLines: 3,
            ),
          ),
        ],
      ),
    );
  }
}
