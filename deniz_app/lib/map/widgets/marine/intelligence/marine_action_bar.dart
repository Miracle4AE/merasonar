import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/theme/app_radius.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/widgets/premium/premium_card.dart';
import 'package:flutter/material.dart';

class MarineActionBar extends StatelessWidget {
  const MarineActionBar({
    super.key,
    required this.onSaveSpot,
    required this.onAskCaptain,
    required this.onCompare,
    required this.onRefresh,
    this.loadingAi = false,
    this.busy = false,
  });

  final VoidCallback? onSaveSpot;
  final VoidCallback? onAskCaptain;
  final VoidCallback? onCompare;
  final VoidCallback? onRefresh;
  final bool loadingAi;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          _ActionChip(
            key: const Key('btn_marine_save_spot'),
            icon: Icons.bookmark_add_outlined,
            label: kMarineSaveSpot,
            onPressed: busy ? null : onSaveSpot,
          ),
          _ActionChip(
            icon: Icons.auto_awesome_outlined,
            label: kMarineFetchAiCommentButton,
            onPressed: (busy || loadingAi) ? null : onAskCaptain,
            loading: loadingAi,
          ),
          _ActionChip(
            icon: Icons.compare_arrows,
            label: kMarineCompareButton,
            onPressed: busy ? null : onCompare,
          ),
          _ActionChip(
            icon: Icons.refresh,
            label: kMarineActionRefresh,
            onPressed: busy ? null : onRefresh,
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.loading = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceElevated.withValues(alpha: 0.5),
      borderRadius: AppRadius.chip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppRadius.chip,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(icon, size: 16, color: AppColors.accentTeal),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: AppTextStyles.buttonLabel,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
