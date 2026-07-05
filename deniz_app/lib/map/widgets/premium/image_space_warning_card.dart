import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/widgets/premium/premium_glass_panel.dart';
import 'package:flutter/material.dart';

class ImageSpaceWarningCard extends StatelessWidget {
  const ImageSpaceWarningCard({
    super.key,
    this.onCalibrate,
    this.compact = false,
  });

  final VoidCallback? onCalibrate;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return PremiumGlassPanel(
      padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: AppColors.accentAmber,
            size: compact ? 20 : 22,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  kMapImageSpaceWarningTitle,
                  style: AppTextStyles.cardTitle.copyWith(
                    color: AppColors.accentAmber,
                    fontSize: compact ? 13 : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  kMapImageSpaceWarningBody,
                  style: AppTextStyles.caption,
                ),
                if (onCalibrate != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  TextButton.icon(
                    onPressed: onCalibrate,
                    icon: const Icon(Icons.my_location_rounded, size: 16),
                    label: Text(kMapChartOverlayCmdCalibrate),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.accentAmber,
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
