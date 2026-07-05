import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/widgets/premium/premium_card.dart';
import 'package:deniz_app/widgets/premium/premium_primary_button.dart';
import 'package:flutter/material.dart';

class MapPremiumEmptyState extends StatelessWidget {
  const MapPremiumEmptyState({
    super.key,
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String title;
  final String body;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: PremiumCard(
          glow: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.map_outlined,
                size: 48,
                color: AppColors.accentTeal.withValues(alpha: 0.85),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(title, style: AppTextStyles.sectionTitle, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.sm),
              Text(body, style: AppTextStyles.caption, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.lg),
              PremiumPrimaryButton(
                label: primaryLabel,
                icon: Icons.radar,
                onPressed: onPrimary,
                expanded: true,
              ),
              if (secondaryLabel != null && onSecondary != null) ...[
                const SizedBox(height: AppSpacing.sm),
                PremiumPrimaryButton(
                  label: secondaryLabel!,
                  icon: Icons.my_location_rounded,
                  onPressed: onSecondary,
                  expanded: true,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
