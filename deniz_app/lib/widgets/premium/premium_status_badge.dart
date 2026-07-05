import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_text_styles.dart';

enum PremiumStatusTone { success, warning, danger, neutral }

class PremiumStatusBadge extends StatelessWidget {
  const PremiumStatusBadge({
    super.key,
    required this.label,
    this.tone = PremiumStatusTone.neutral,
  });

  final String label;
  final PremiumStatusTone tone;

  Color get _color {
    switch (tone) {
      case PremiumStatusTone.success:
        return AppColors.accentGreen;
      case PremiumStatusTone.warning:
        return AppColors.accentAmber;
      case PremiumStatusTone.danger:
        return AppColors.accentRed;
      case PremiumStatusTone.neutral:
        return AppColors.accentTeal;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: AppRadius.chip,
        border: Border.all(color: _color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: _color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
