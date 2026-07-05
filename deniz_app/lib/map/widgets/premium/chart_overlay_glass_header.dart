import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/widgets/premium/premium_glass_panel.dart';
import 'package:deniz_app/widgets/premium/premium_status_badge.dart';
import 'package:flutter/material.dart';

class ChartOverlayGlassHeader extends StatelessWidget {
  const ChartOverlayGlassHeader({
    super.key,
    required this.coordinateModeLabel,
    required this.hotspotCount,
    this.calibrationLabel,
    this.calibrationTone = PremiumStatusTone.neutral,
    this.compact = false,
  });

  final String coordinateModeLabel;
  final int hotspotCount;
  final String? calibrationLabel;
  final PremiumStatusTone calibrationTone;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return PremiumGlassPanel(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 6 : 8,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              kMapPremiumPhotoTitle,
              style: AppTextStyles.cardTitle.copyWith(
                fontSize: compact ? 13 : 15,
              ),
            ),
          ),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            alignment: WrapAlignment.end,
            children: [
              PremiumStatusBadge(
                label: coordinateModeLabel,
                tone: coordinateModeLabel.contains('image')
                    ? PremiumStatusTone.warning
                    : PremiumStatusTone.success,
              ),
              PremiumStatusBadge(
                label: kMapChartOverlayHotspotCountFmt(hotspotCount),
                tone: PremiumStatusTone.neutral,
              ),
              if (calibrationLabel != null)
                PremiumStatusBadge(
                  label: calibrationLabel!,
                  tone: calibrationTone,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
