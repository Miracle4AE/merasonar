import 'package:deniz_app/domain/dashboard_overview.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/navigation/captain_atlas_launcher.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/widgets/premium/captain_atlas_hero_card.dart';
import 'package:deniz_app/widgets/premium/premium_card.dart';
import 'package:deniz_app/widgets/premium/premium_metric_chip.dart';
import 'package:deniz_app/widgets/premium/premium_primary_button.dart';
import 'package:deniz_app/widgets/premium/premium_status_badge.dart';
import 'package:flutter/material.dart';

class MissionCaptainCommandCard extends StatelessWidget {
  const MissionCaptainCommandCard({
    super.key,
    required this.overview,
    required this.serverIp,
    required this.onMarineTap,
    required this.onLiveTap,
    required this.onCompareTap,
  });

  final DashboardOverview overview;
  final String serverIp;
  final VoidCallback onMarineTap;
  final VoidCallback onLiveTap;
  final VoidCallback onCompareTap;

  @override
  Widget build(BuildContext context) {
    final captain = overview.captainAtlas;
    final body = captain.hasData
        ? captain.summaryTr
        : kPremiumDashCaptainEmpty;
    final presence = captain.hasData
        ? (captain.isFallback
            ? CaptainAtlasPresence.thinking
            : CaptainAtlasPresence.responding)
        : CaptainAtlasPresence.ready;

    return PremiumCard(
      glow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RepaintBoundary(
            child: CaptainAtlasHeroCard(
              title: kMissionCaptainCommandTitle,
              body: body,
              presence: presence,
              actionLabel: kPremiumCaptainAskButton,
              onAsk: () => CaptainAtlasLauncher.openCommandCenter(context, serverIp),
              badges: [
                if (captain.isFallback)
                  PremiumStatusBadge(
                    label: kPremiumDashCaptainFallbackBadge,
                    tone: PremiumStatusTone.warning,
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(kMissionCaptainContext, style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              PremiumMetricChip(
                label: kCaptainAtlasContextReport,
                value: overview.marineReport.hasData
                    ? '${overview.marineReport.missionScore ?? '—'}'
                    : kCaptainAtlasContextEmpty,
              ),
              PremiumMetricChip(
                label: kCaptainAtlasContextLive,
                value: overview.liveScore.hasData
                    ? '${overview.liveScore.score}'
                    : kCaptainAtlasContextEmpty,
              ),
              PremiumMetricChip(
                label: kCaptainAtlasContextCompare,
                value: overview.compare.hasData
                    ? overview.compare.winnerLabel
                    : kCaptainAtlasContextEmpty,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          PremiumPrimaryButton(
            label: kCaptainAtlasCtaMarine,
            icon: Icons.analytics_outlined,
            onPressed: onMarineTap,
            expanded: true,
          ),
          const SizedBox(height: AppSpacing.sm),
          PremiumPrimaryButton(
            label: kCaptainAtlasCtaLive,
            icon: Icons.sensors_rounded,
            onPressed: onLiveTap,
            expanded: true,
          ),
          const SizedBox(height: AppSpacing.sm),
          PremiumPrimaryButton(
            label: kCaptainAtlasCtaCompare,
            icon: Icons.compare_arrows_rounded,
            onPressed: onCompareTap,
            expanded: true,
          ),
        ],
      ),
    );
  }
}
