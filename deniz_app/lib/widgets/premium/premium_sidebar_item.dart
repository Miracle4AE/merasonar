import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_text_styles.dart';

class PremiumSidebarItem extends StatelessWidget {
  const PremiumSidebarItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.iconOnly = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final content = iconOnly
        ? Center(
            child: Icon(
              icon,
              size: 20,
              color: selected ? AppColors.accentTeal : AppColors.textMuted,
            ),
          )
        : Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? AppColors.accentTeal : AppColors.textMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.sidebarLabel.copyWith(
                    color: selected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Semantics(
        button: true,
        label: label,
        selected: selected,
        child: Tooltip(
          message: iconOnly ? label : '',
          child: Material(
            color: selected
                ? AppColors.accentTeal.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: AppRadius.chip,
            child: InkWell(
              onTap: onTap,
              borderRadius: AppRadius.chip,
              hoverColor: AppColors.accentTeal.withValues(alpha: 0.08),
              child: Container(
                decoration: selected
                    ? BoxDecoration(
                        borderRadius: AppRadius.chip,
                        border: Border(
                          left: BorderSide(
                            color: AppColors.accentTeal.withValues(alpha: 0.85),
                            width: 2,
                          ),
                        ),
                      )
                    : null,
                padding: EdgeInsets.symmetric(
                  horizontal: iconOnly ? 8 : 10,
                  vertical: 8,
                ),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
