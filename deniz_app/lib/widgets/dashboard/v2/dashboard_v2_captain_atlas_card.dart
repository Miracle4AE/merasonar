import 'package:deniz_app/domain/dashboard_overview.dart';
import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/widgets/dashboard/v2/dashboard_v2_helpers.dart';
import 'package:deniz_app/widgets/premium/premium_card.dart';
import 'package:flutter/material.dart';

class DashboardV2CaptainAtlasCard extends StatelessWidget {
  const DashboardV2CaptainAtlasCard({
    super.key,
    required this.summary,
    this.onCaptainTap,
  });

  final DashboardCaptainAtlasSummary summary;
  final VoidCallback? onCaptainTap;

  static const _quickChips = [
    'Gün batımı avı',
    'Levrek avı',
    'Spin',
  ];

  @override
  Widget build(BuildContext context) {
    final body = summary.hasData
        ? summary.summaryTr
        : kPremiumCaptainCardMessage;
    final badge = summary.personaVersion.isNotEmpty
        ? summary.personaVersion
        : kPremiumCaptainCardBadge;
    final status = summary.hasData ? 'Hazır' : 'Fallback';
    final statusColor =
        summary.hasData ? AppColors.accentGreen : AppColors.accentAmber;

    return PremiumCard(
      glow: summary.hasData,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tight = constraints.maxHeight < 150;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child:
                        DashboardV2Helpers.cardHeader(kPremiumCaptainCardTitle),
                  ),
                  _miniBadge(badge, AppColors.accentTeal),
                  const SizedBox(width: 4),
                  _miniBadge(status, statusColor),
                ],
              ),
              SizedBox(height: tight ? AppSpacing.xs : AppSpacing.sm),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _avatarPanel(tight: tight),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            body,
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 11,
                              height: 1.35,
                            ),
                            maxLines: tight ? 2 : 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (!tight) ...[
                            const SizedBox(height: AppSpacing.xs),
                            SizedBox(
                              height: 24,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                padding: EdgeInsets.zero,
                                itemCount: _quickChips.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(width: 4),
                                itemBuilder: (context, index) {
                                  return ActionChip(
                                    label: Text(
                                      _quickChips[index],
                                      style: AppTextStyles.caption
                                          .copyWith(fontSize: 11),
                                    ),
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor: AppColors.surfaceElevated
                                        .withValues(alpha: 0.5),
                                    side: BorderSide(
                                      color: AppColors.borderSoft(alpha: 0.12),
                                    ),
                                    onPressed: onCaptainTap,
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: tight ? AppSpacing.xs : AppSpacing.sm),
              DashboardV2Helpers.compactGradientButton(
                buttonKey: const Key('btn_dashboard_captain_atlas'),
                label: kPremiumCaptainAskButton,
                onPressed: onCaptainTap,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _miniBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        text,
        style: AppTextStyles.caption.copyWith(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _avatarPanel({required bool tight}) {
    return Container(
      width: tight ? 48 : 62,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accentTeal.withValues(alpha: 0.35),
            AppColors.surfaceElevated.withValues(alpha: 0.9),
            const Color(0xFF082840),
          ],
        ),
        border: Border.all(
          color: AppColors.borderCyan.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentTeal.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: tight ? 30 : 36,
            height: tight ? 30 : 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.backgroundDeep.withValues(alpha: 0.55),
              border: Border.all(
                color: AppColors.borderCyan.withValues(alpha: 0.4),
              ),
            ),
            child: Icon(
              Icons.sailing_rounded,
              color: AppColors.accentTeal,
              size: tight ? 18 : 22,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'AI',
            style: AppTextStyles.caption.copyWith(
              fontSize: 11,
              color: AppColors.accentTeal,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
