import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/widgets/premium/premium_glass_panel.dart';
import 'package:deniz_app/widgets/premium/premium_primary_button.dart';
import 'package:flutter/material.dart';

enum PremiumDialogTone { info, warning, danger, success }

/// Premium onay / bilgi dialog sistemi.
abstract final class PremiumDialog {
  static Future<bool?> showConfirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Tamam',
    String cancelLabel = 'İptal',
    PremiumDialogTone tone = PremiumDialogTone.info,
    bool destructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      builder: (ctx) => _PremiumDialogFrame(
        title: title,
        message: message,
        tone: tone,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(cancelLabel, style: AppTextStyles.caption),
          ),
          PremiumPrimaryButton(
            label: confirmLabel,
            onPressed: () => Navigator.of(ctx).pop(true),
            expanded: false,
          ),
        ],
      ),
    );
  }

  static Future<void> showAlert(
    BuildContext context, {
    required String title,
    required String message,
    String okLabel = 'Tamam',
    PremiumDialogTone tone = PremiumDialogTone.info,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      builder: (ctx) => _PremiumDialogFrame(
        title: title,
        message: message,
        tone: tone,
        actions: [
          PremiumPrimaryButton(
            label: okLabel,
            onPressed: () => Navigator.of(ctx).pop(),
            expanded: false,
          ),
        ],
      ),
    );
  }
}

class _PremiumDialogFrame extends StatelessWidget {
  const _PremiumDialogFrame({
    required this.title,
    required this.message,
    required this.tone,
    required this.actions,
  });

  final String title;
  final String message;
  final PremiumDialogTone tone;
  final List<Widget> actions;

  IconData get _icon {
    switch (tone) {
      case PremiumDialogTone.warning:
        return Icons.warning_amber_rounded;
      case PremiumDialogTone.danger:
        return Icons.error_outline_rounded;
      case PremiumDialogTone.success:
        return Icons.check_circle_outline_rounded;
      case PremiumDialogTone.info:
        return Icons.info_outline_rounded;
    }
  }

  Color get _accent {
    switch (tone) {
      case PremiumDialogTone.warning:
        return AppColors.accentAmber;
      case PremiumDialogTone.danger:
        return AppColors.accentRed;
      case PremiumDialogTone.success:
        return AppColors.accentGreen;
      case PremiumDialogTone.info:
        return AppColors.accentTeal;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Material(
          color: Colors.transparent,
          child: PremiumGlassPanel(
            padding: const EdgeInsets.all(AppSpacing.lg),
            blur: 22,
            elevation: 1.3,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_icon, color: _accent, size: 22),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(title, style: AppTextStyles.heroTitle),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(message, style: AppTextStyles.bodyPremium),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  alignment: WrapAlignment.end,
                  children: actions,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
