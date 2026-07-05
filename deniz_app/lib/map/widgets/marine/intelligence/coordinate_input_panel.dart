import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/map/widgets/navionics_coordinate_field.dart';
import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/theme/app_radius.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/widgets/premium/premium_card.dart';
import 'package:deniz_app/widgets/premium/premium_primary_button.dart';
import 'package:flutter/material.dart';

class CoordinateInputPanel extends StatelessWidget {
  const CoordinateInputPanel({
    super.key,
    required this.latController,
    required this.lonController,
    required this.onAnalyze,
    required this.onPickFromMap,
    required this.onCompare,
    this.busy = false,
    this.errorMessage,
  });

  final TextEditingController latController;
  final TextEditingController lonController;
  final VoidCallback onAnalyze;
  final VoidCallback onPickFromMap;
  final VoidCallback onCompare;
  final bool busy;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(kMarinePremiumCoordinateTitle, style: AppTextStyles.cardTitle),
          const SizedBox(height: AppSpacing.md),
          NavionicsCoordinateField(
            key: const Key('field_marine_lat'),
            label: kLabelLatitude,
            hintText: '36.62123',
            isLatitude: true,
            controller: latController,
          ),
          const SizedBox(height: AppSpacing.sm),
          NavionicsCoordinateField(
            key: const Key('field_marine_lon'),
            label: kLabelLongitude,
            hintText: '29.11234',
            isLatitude: false,
            controller: lonController,
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              errorMessage!,
              style: AppTextStyles.caption.copyWith(color: AppColors.accentAmber),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          PremiumPrimaryButton(
            key: const Key('btn_marine_analyze'),
            label: kMarineAnalyzeButton,
            icon: Icons.analytics_outlined,
            onPressed: busy ? null : onAnalyze,
            expanded: true,
          ),
          const SizedBox(height: AppSpacing.sm),
          _SecondaryButton(
            label: kMarinePickFromMap,
            icon: Icons.map_outlined,
            onPressed: busy ? null : onPickFromMap,
          ),
          const SizedBox(height: AppSpacing.sm),
          _SecondaryButton(
            label: kMarineCompareOpenFromAnalysis,
            icon: Icons.compare_arrows,
            onPressed: busy ? null : onCompare,
          ),
        ],
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.label,
    required this.icon,
    this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppRadius.chip,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: AppRadius.chip,
            border: Border.all(color: AppColors.borderSoft(alpha: 0.35)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: AppColors.accentTeal),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: AppTextStyles.buttonLabel,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
