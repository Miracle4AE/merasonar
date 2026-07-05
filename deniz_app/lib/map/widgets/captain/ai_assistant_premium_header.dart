import 'package:deniz_app/l10n/app_strings_tr.dart';
import 'package:deniz_app/services/ai_assistant_sheet_controller.dart';
import 'package:deniz_app/theme/app_colors.dart';
import 'package:deniz_app/theme/app_spacing.dart';
import 'package:deniz_app/theme/app_text_styles.dart';
import 'package:deniz_app/widgets/premium/navigation/premium_hero_widgets.dart';
import 'package:deniz_app/widgets/premium/premium_status_badge.dart';
import 'package:flutter/material.dart';

class AiAssistantPremiumHeader extends StatelessWidget {
  const AiAssistantPremiumHeader({
    super.key,
    required this.title,
    required this.phase,
    required this.assistantName,
    required this.onRefresh,
    required this.onCancel,
    this.refreshing = false,
  });

  final String title;
  final AiSheetPhase phase;
  final String assistantName;
  final VoidCallback onRefresh;
  final VoidCallback onCancel;
  final bool refreshing;

  String get _status {
    switch (phase) {
      case AiSheetPhase.loading:
        return kPremiumCaptainThinking;
      case AiSheetPhase.error:
        return kPremiumCaptainResponding;
      case AiSheetPhase.ready:
        return kPremiumCaptainReady;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.sm, 0),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PremiumHeroCaptainAvatar(size: 44, useHero: false),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.heroTitle),
                    const SizedBox(height: 4),
                    Text(_status, style: AppTextStyles.caption),
                    const SizedBox(height: 6),
                    PremiumStatusBadge(label: assistantName),
                  ],
                ),
              ),
              if (phase == AiSheetPhase.ready)
                IconButton(
                  onPressed: refreshing ? null : onRefresh,
                  icon: refreshing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                  color: AppColors.accentTeal,
                ),
              if (phase == AiSheetPhase.loading)
                TextButton(onPressed: onCancel, child: Text(kAiAssistantCancel)),
            ],
          ),
        ],
      ),
    );
  }
}
