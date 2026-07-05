import 'package:deniz_app/api_service.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/map/widgets/live_area/live_area_rating_helpers.dart';
import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/widgets/premium/premium_card.dart';
import 'package:deniz_app/widgets/premium/premium_loading_skeleton.dart';
import 'package:deniz_app/widgets/premium/premium_metric_chip.dart';
import 'package:deniz_app/widgets/premium/premium_status_badge.dart';
import 'package:flutter/material.dart';

class LiveScorePremiumCard extends StatelessWidget {
  const LiveScorePremiumCard({
    super.key,
    required this.loading,
    required this.autoRefresh,
    required this.onAutoRefreshChanged,
    this.live,
    this.offline = false,
    this.offlineHotspotCount = 0,
    this.apiFailed = false,
    this.apiErrorHint,
    this.lastUpdateLabel,
  });

  final bool loading;
  final bool autoRefresh;
  final ValueChanged<bool> onAutoRefreshChanged;
  final LiveFishingScoreResponse? live;
  final bool offline;
  final int offlineHotspotCount;
  final bool apiFailed;
  final String? apiErrorHint;
  final String? lastUpdateLabel;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      glow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(kLiveScoreTitle, style: AppTextStyles.cardTitle),
              ),
              Switch.adaptive(
                value: autoRefresh,
                onChanged: onAutoRefreshChanged,
                activeTrackColor: AppColors.accentTeal.withValues(alpha: 0.45),
                activeThumbColor: AppColors.accentTeal,
              ),
              Text(kAutoRefreshLabel, style: AppTextStyles.caption),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _buildBody(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (offline) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            kOfflineLiveScoreDisabled,
            style: AppTextStyles.cardTitle.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(kOfflineStateReassurance, style: AppTextStyles.caption),
          if (offlineHotspotCount > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(kOfflineLiveScoreHintNearby, style: AppTextStyles.caption),
          ],
        ],
      );
    }

    if (apiFailed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PremiumStatusBadge(
            label: apiErrorHint ?? kMsgSunucuyaUlasilamiyor,
            tone: PremiumStatusTone.warning,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(kMsgNetworkRetryHint, style: AppTextStyles.caption),
        ],
      );
    }

    if (loading && live == null) {
      return const PremiumLoadingSkeleton(height: 160);
    }

    if (live == null) {
      return Text(kScoreEmpty, style: AppTextStyles.caption);
    }

    final l = live!;
    final color = liveAreaRatingColor(l.rating);
    final label = localizeLiveRatingLabel(l.rating);

    return Column(
      children: [
        SizedBox(
          height: 156,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 148,
                height: 148,
                child: CircularProgressIndicator(
                  value: (l.liveScore.clamp(0, 100)) / 100,
                  strokeWidth: 11,
                  backgroundColor: AppColors.surfaceElevated,
                  color: color,
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${l.liveScore}', style: AppTextStyles.metricNumber),
                  const SizedBox(height: 4),
                  PremiumStatusBadge(label: label, tone: _toneForRating(l.rating)),
                ],
              ),
            ],
          ),
        ),
        if (lastUpdateLabel != null) ...[
          PremiumMetricChip(
            label: kPremiumDashUpdatedLabel,
            value: lastUpdateLabel!,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (l.reasoning.trim().isNotEmpty)
          Text(
            l.reasoning,
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
      ],
    );
  }

  PremiumStatusTone _toneForRating(String rating) {
    switch (rating.trim().toLowerCase()) {
      case 'excellent':
      case 'good':
        return PremiumStatusTone.success;
      case 'fair':
        return PremiumStatusTone.warning;
      default:
        return PremiumStatusTone.danger;
    }
  }
}
