import 'package:deniz_app/widgets/premium/settings/settings_ui_widgets.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
class PremiumIconButton extends StatelessWidget {
  const PremiumIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.selected = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final btn = Material(
      color: selected
          ? AppColors.accentTeal.withValues(alpha: 0.15)
          : AppColors.surfaceElevated.withValues(alpha: 0.6),
      borderRadius: AppRadius.chip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppRadius.chip,
        hoverColor: AppColors.accentTeal.withValues(alpha: 0.08),
        child: SizedBox(
          width: settingsTouchTargetSize(context),
          height: settingsTouchTargetSize(context),
          child: Icon(
            icon,
            size: 18,
            color: selected ? AppColors.accentTeal : AppColors.textSecondary,
          ),
        ),
      ),
    );
    if (tooltip == null) return btn;
    return Tooltip(message: tooltip!, child: btn);
  }
}
