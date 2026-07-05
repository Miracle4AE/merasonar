import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_text_styles.dart';

class PremiumPrimaryButton extends StatelessWidget {
  const PremiumPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expanded = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment:
          expanded ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: AppColors.backgroundDeep),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            label,
            style: AppTextStyles.buttonLabel.copyWith(
              color: AppColors.backgroundDeep,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
    return Material(
      color: onPressed == null
          ? AppColors.accentTeal.withValues(alpha: 0.4)
          : AppColors.accentTeal,
      borderRadius: AppRadius.chip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppRadius.chip,
        hoverColor: AppColors.accentGreen.withValues(alpha: 0.25),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: child,
        ),
      ),
    );
  }
}
