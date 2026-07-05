import 'package:deniz_app/domain/dashboard_overview.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/widgets/dashboard/v2/dashboard_v2_helpers.dart';
import 'package:deniz_app/widgets/premium/premium_card.dart';
import 'package:flutter/material.dart';

const _defaultSlotIcons = [
  Icons.wb_twilight,
  Icons.wb_sunny_outlined,
  Icons.light_mode_outlined,
  Icons.wb_cloudy_outlined,
  Icons.nights_stay_outlined,
  Icons.dark_mode_outlined,
];

class DashboardV2DayTimelineCard extends StatelessWidget {
  const DashboardV2DayTimelineCard({
    super.key,
    required this.summary,
    this.onMarineTap,
    this.onRefreshTap,
  });

  final DashboardTimelineSummary summary;
  final VoidCallback? onMarineTap;
  final VoidCallback? onRefreshTap;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DashboardV2Helpers.cardHeader(
            kPremiumDashTimelineTitle,
            trailing: _headerTrailing(),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget? _headerTrailing() {
    if (summary.isRefreshing) {
      return _statusChip(
        kPremiumDashTimelineRefreshing,
        color: AppColors.accentTeal,
        showSpinner: true,
      );
    }
    if (summary.isCached && summary.hasMeaningfulData) {
      return _statusChip(
        kPremiumDashTimelineCachedBadge,
        color: AppColors.textMuted,
      );
    }
    if (summary.hasMeaningfulData &&
        summary.updatedAgoLabel != null &&
        summary.updatedAgoLabel!.isNotEmpty &&
        summary.updatedAgoLabel != kPremiumDashNoData) {
      return _statusChip(
        summary.updatedAgoLabel!,
        color: AppColors.accentTeal,
      );
    }
    return null;
  }

  Widget _statusChip(
    String label, {
    required Color color,
    bool showSpinner = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showSpinner) ...[
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: color,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTextStyles.caption.copyWith(fontSize: 9, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _body() {
    switch (summary.resolvedDisplayState) {
      case DashboardTimelineDisplayState.hasData:
        return _timelineView();
      case DashboardTimelineDisplayState.loading:
        return summary.hasMeaningfulData ? _timelineView() : _loadingView();
      case DashboardTimelineDisplayState.reportWithoutTimeline:
        return _missingTimelineView();
      case DashboardTimelineDisplayState.noCoordinate:
        return _noCoordinateView();
    }
  }

  Widget _loadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accentTeal.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            kPremiumDashTimelineRefreshing,
            style: AppTextStyles.caption.copyWith(
              fontSize: 11,
              color: AppColors.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _noCoordinateView() {
    return DashboardV2Helpers.premiumEmpty(
      message: kPremiumDashTimelineNoCoordinate,
      ctaLabel: kPremiumDashTimelineAnalyzeCta,
      onCta: onMarineTap,
      icon: Icons.schedule_outlined,
      pattern: DashboardPlaceholderPattern.dottedBaseline,
    );
  }

  Widget _missingTimelineView() {
    return DashboardV2Helpers.premiumEmpty(
      message: kPremiumDashTimelineNoHourlyWindow,
      ctaLabel: kPremiumDashTimelineRefreshCta,
      onCta: onRefreshTap ?? onMarineTap,
      icon: Icons.update_outlined,
      pattern: DashboardPlaceholderPattern.sparkline,
    );
  }

  Widget _timelineView() {
    final slots =
        summary.slots.where(DashboardTimelineSummary.isMeaningfulSlot).toList();
    if (slots.isEmpty) {
      return _missingTimelineView();
    }

    final bestIndex = slots.indexWhere(
      (s) =>
          s.decision == 'good' ||
          s.decision == 'excellent' ||
          s.label.toLowerCase().contains('uygun'),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxItems = (constraints.maxHeight / 22).floor().clamp(3, 6);
        final visible = slots.take(maxItems).toList(growable: false);
        final showBest =
            bestIndex >= 0 && constraints.maxHeight > 88 && bestIndex < visible.length;

        return Column(
          children: [
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: visible.length,
                separatorBuilder: (context, index) => const SizedBox(height: 2),
                itemBuilder: (context, index) {
                  final slot = visible[index];
                  final highlight = index == bestIndex;
                  final scoreText = _slotScore(slot);
                  final statusText = _slotStatus(slot);

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: highlight
                          ? AppColors.accentTeal.withValues(alpha: 0.14)
                          : AppColors.surfaceElevated.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(6),
                      border: highlight
                          ? Border.all(
                              color: AppColors.accentTeal.withValues(alpha: 0.4),
                            )
                          : Border.all(
                              color: AppColors.borderSoft(alpha: 0.08),
                            ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _defaultSlotIcons[index.clamp(0, 5)],
                          size: 13,
                          color: highlight
                              ? AppColors.accentTeal
                              : AppColors.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          flex: 3,
                          child: Text(
                            slot.time,
                            style: AppTextStyles.caption.copyWith(fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          scoreText,
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: highlight
                                ? DashboardV2Helpers.scoreColor(
                                    slot.goScore ?? _parseScore(scoreText),
                                  )
                                : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: Text(
                            statusText,
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 11,
                              color: highlight
                                  ? AppColors.accentGreen
                                  : AppColors.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            if (showBest)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentTeal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$kMissionTimelineBestWindow: ${slots[bestIndex].time}',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 11,
                      color: AppColors.accentTeal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  String _slotScore(DashboardTimelineSlot slot) {
    if (slot.goScore != null) return '${slot.goScore}';
    if (slot.label.contains('·')) {
      final parts = slot.label.split('·');
      if (parts.length > 1) return parts.last.trim();
    }
    final digits = RegExp(r'\d+').firstMatch(slot.label);
    return digits?.group(0) ?? kPremiumDashPlaceholderDash;
  }

  String _slotStatus(DashboardTimelineSlot slot) {
    if (slot.label.contains('·')) {
      return slot.label.split('·').first.trim();
    }
    final label = slot.label.trim();
    if (label.isNotEmpty && label != kPremiumDashPlaceholderDash) {
      return label;
    }
    return kPremiumDashPlaceholderDash;
  }

  int? _parseScore(String text) => int.tryParse(text);
}
